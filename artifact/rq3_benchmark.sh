#!/usr/bin/env bash
# RQ3 — runtime overhead benchmarks (cf. Table 4).
#
# Usage:
#   ./artifact/rq3_benchmark.sh fast   # baseline + enforced (no LLM), default
#   ./artifact/rq3_benchmark.sh full   # also exercises GDPRFS's LLM analyzer
#
# "fast" needs no secrets, but GDPRFS's enforced mode needs a FUSE-capable
# privileged container (--privileged --device /dev/fuse), which this script
# passes automatically. "full" additionally requires OPENAI_API_KEY to be set
# in the environment, or a GDPRFS/openai.secret file (OPENAI_API_KEY=sk-...).
#
# Expected runtime: GDPRSocial's two runs take ~5-7 minutes each (n up to
# 10,000, cf. paper Section RQ3); GDPRFS's runs take well under a minute.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-fast}"
CS_DIR="evaluation/02_case_studies"
IMG_SOCIAL="${IMG_SOCIAL:-gdprsocial:latest}"
IMG_FS="${IMG_FS:-gdprfs:latest}"
OUT_DIR="$(pwd)/artifact/out/rq3"
mkdir -p "$OUT_DIR/gdprsocial" "$OUT_DIR/gdprfs"

echo "════════════════════════════════════════════════════════════════"
echo " RQ3 — Runtime performance (mode: ${MODE})"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "── GDPRSocial: baseline ──"
docker run --rm -v "$OUT_DIR/gdprsocial:/app/output" "$IMG_SOCIAL" \
  bash benchmark/privacy_testsuite/run_benchmark.sh baseline

echo ""
echo "── GDPRSocial: enforced (gdpr policy) ──"
docker run --rm -v "$OUT_DIR/gdprsocial:/app/output" "$IMG_SOCIAL" \
  bash benchmark/privacy_testsuite/run_benchmark.sh gdpr /opt/whyenf/enfguard

echo ""
echo "── GDPRFS: baseline (no FUSE) ──"
docker run --rm -v "$OUT_DIR/gdprfs:/app/benchmark/results" "$IMG_FS" \
  python3 -m benchmark.simple --mode baseline --n 3

echo ""
echo "── GDPRFS: enforced, no LLM (requires --privileged + /dev/fuse) ──"
# Bounded as a safety net; a healthy run finishes in well under a minute.
if ! timeout 300 docker run --rm --privileged --device /dev/fuse \
  -v "$OUT_DIR/gdprfs:/app/benchmark/results" "$IMG_FS" \
  python3 -m benchmark.simple --mode gdpr_no_llm --n 3; then
  echo ""
  echo "!! GDPRFS enforced-mode run did not complete within 5 minutes and was"
  echo "!! aborted. Check that /dev/fuse is available and that the container"
  echo "!! ran with --privileged; see ARTIFACT.md §7 (Troubleshooting)."
  echo "!! RQ1/RQ2 and GDPRSocial's RQ3 results above are unaffected."
fi

if [[ "$MODE" == "full" ]]; then
  KEY="${OPENAI_API_KEY:-}"
  if [[ -z "$KEY" && -f "$CS_DIR/GDPRFS/openai.secret" ]]; then
    KEY=$(grep -v '^#' "$CS_DIR/GDPRFS/openai.secret" | head -1 | sed 's/OPENAI_API_KEY=//')
  fi
  if [[ -z "$KEY" ]]; then
    echo ""
    echo "!! MODE=full requires an OpenAI API key. Set OPENAI_API_KEY or create"
    echo "!! $CS_DIR/GDPRFS/openai.secret (OPENAI_API_KEY=sk-...). Skipping the LLM run."
  else
    echo ""
    echo "── GDPRFS: enforced, with LLM analyzer (gpt-5.4-mini) ──"
    docker run --rm --privileged --device /dev/fuse \
      -e OPENAI_API_KEY="$KEY" \
      -v "$OUT_DIR/gdprfs:/app/benchmark/results" "$IMG_FS" \
      python3 -m benchmark.simple --mode gdpr_with_llm --n 3
  fi
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Results written to:"
echo "   $OUT_DIR/gdprsocial/minitwitter_<timestamp>/  (per-request latency CSVs)"
echo "   $OUT_DIR/gdprfs/simple_perf_results*.csv"
echo ""
echo "Compare against Table 4 in the paper. Absolute latencies depend on host"
echo "hardware (the paper uses a 2.4 GHz Intel i5, 32 GB RAM, 20 repetitions);"
echo "expect the same qualitative pattern (moderate enforcement overhead,"
echo "most requests near-instantaneous) rather than identical numbers."
