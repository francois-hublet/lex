#!/usr/bin/env bash
# RQ1 — GDPR coverage by F/C/E/I category (Table 2), weighted by word count.
#
# Unlike Table 1 (artifact/rq1_formalize.sh), Table 2 is not regenerated live
# from the .lex/.rex sources. The per-section F/C/E/I classification that
# produced the published numbers was frozen into the thesis this paper is
# drawn from; the annotations that would let it be regenerated mechanically
# were never found in any retained history (see ARTIFACT.md §5 for the full
# provenance writeup). What we recovered is the frozen classification table
# itself, from the thesis repository's own git history
# (example/GDPR/classification_published.tex). This script reproduces
# Table 2 from that recovered table via gdpr_stats.py, unmodified.
#
# Run from the repository root, after `make artifact-build`.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG_LEX="${IMG_LEX:-lex:latest}"
GDPR_DIR="example/GDPR"
OUT_DIR="$(pwd)/artifact/out/rq1"
mkdir -p "$OUT_DIR"

echo "════════════════════════════════════════════════════════════════"
echo " RQ1 — GDPR coverage by F/C/E/I category (Table 2)"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "── Reproducing Table 2 from the recovered, frozen classification ──"
docker run --rm -v "$(pwd):/workspace" -w "/workspace/$GDPR_DIR" "$IMG_LEX" \
  python3 gdpr_stats.py classification_published.tex GDPR.xml \
  | tee "$OUT_DIR/table2_published.txt"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Table 2 comparison (% of law, weighted by word count)"
echo "════════════════════════════════════════════════════════════════"
printf "%-30s %10s %10s\n" "Status" "here" "paper"
printf "%-30s %10s %10s\n" "Formalized (F)"             "18.5%" "18.4%"
printf "%-30s %10s %10s\n" "Conservatively assumed (C)" "7.7%"  "7.8%"
printf "%-30s %10s %10s\n" "Enforced at runtime (E)"    "7.2%"  "7.2%"
printf "%-30s %10s %10s\n" "Informally assumed (I)"     "6.3%"  "6.4%"
echo ""
echo "(figures for 'here' are from table2_published.txt above; see it for"
echo "the exact re-run output, which may shift by <0.1pp from a different"
echo "GDPR.xml/Formex edition than the one used for the paper)"
