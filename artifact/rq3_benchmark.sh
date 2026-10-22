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
# 10,000, cf. paper Section RQ3). GDPRFS is benchmarked at the paper's preload
# sizes (10^2, 10^3, 10^4 files); preloading 10^4 files dominates its runtime.
# Environment overrides: FS_PRELOAD (default 100,1000,10000), FS_N (iterations
# per setup, default 3; the paper uses 20), FS_TIMEOUT (seconds per GDPRFS run).
#
# Finally, artifact/rq3_table4.sh aggregates all CSVs into Table 4's layout.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-fast}"
CS_DIR="evaluation/02_case_studies"
IMG_SOCIAL="${IMG_SOCIAL:-gdprsocial:latest}"
IMG_FS="${IMG_FS:-gdprfs:latest}"
OUT_DIR="$(pwd)/artifact/out/rq3"
# GDPRFS: preloaded file counts (Table 4 rows) and iterations per setup.
FS_PRELOAD="${FS_PRELOAD:-100,1000,10000}"
FS_N="${FS_N:-3}"
FS_TIMEOUT="${FS_TIMEOUT:-7200}"
mkdir -p "$OUT_DIR/gdprsocial/baseline" "$OUT_DIR/gdprsocial/enforced" \
         "$OUT_DIR/gdprfs/baseline" "$OUT_DIR/gdprfs/gdpr_no_llm" "$OUT_DIR/gdprfs/gdpr_with_llm"

echo "════════════════════════════════════════════════════════════════"
echo " RQ3 — Runtime performance (mode: ${MODE})"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "── GDPRSocial: baseline ──"
docker run --rm -v "$OUT_DIR/gdprsocial/baseline:/app/output" "$IMG_SOCIAL" \
  bash benchmark/privacy_testsuite/run_benchmark.sh baseline

echo ""
echo "── GDPRSocial: enforced (minitwit_gdpr policy) ──"
docker run --rm -v "$OUT_DIR/gdprsocial/enforced:/app/output" "$IMG_SOCIAL" \
  bash benchmark/privacy_testsuite/run_benchmark.sh minitwit_gdpr /opt/whyenf/enfguard

# GDPRFS: each mode is benchmarked at every preload size in FS_PRELOAD. Preloading
# writes files through the FUSE mount, so every run needs --privileged + /dev/fuse.
fs_run() {
  local mode="$1"; shift
  echo ""
  echo "── GDPRFS: ${mode} (preload ${FS_PRELOAD}, ${FS_N} iterations) ──"
  if ! timeout "$FS_TIMEOUT" docker run --rm --privileged --device /dev/fuse "$@" \
    -v "$OUT_DIR/gdprfs/${mode}:/app/benchmark/results" "$IMG_FS" \
    python3 -m benchmark.simple --mode "$mode" --n "$FS_N" --preload "$FS_PRELOAD"; then
    echo ""
    echo "!! GDPRFS ${mode} run failed or did not complete within ${FS_TIMEOUT}s."
    echo "!! Check that /dev/fuse is available and that the container ran with"
    echo "!! --privileged; see ARTIFACT.md (Troubleshooting). A shorter run:"
    echo "!!   FS_PRELOAD=100 make artifact-rq3-fast"
  fi
}

fs_run baseline
fs_run gdpr_no_llm

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
    fs_run gdpr_with_llm -e OPENAI_API_KEY="$KEY"
  fi
fi

echo ""
./artifact/rq3_table4.sh

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Results written to:"
echo "   $OUT_DIR/gdprsocial/{baseline,enforced}/minitwitter_<timestamp>/report.csv"
echo "   $OUT_DIR/gdprfs/<mode>/simple_perf_results_preload<sizes>.csv"
echo "   $OUT_DIR/table4.txt  (Table 4 layout, printed above)"
echo ""
echo "Compare against Table 4 in the paper. Absolute latencies depend on host"
echo "hardware (the paper uses a 2.4 GHz Intel i5, 32 GB RAM, 20 repetitions);"
echo "expect the same qualitative pattern (moderate enforcement overhead,"
echo "most requests near-instantaneous) rather than identical numbers."
