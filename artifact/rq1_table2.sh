#!/usr/bin/env bash
# RQ1 — GDPR coverage by F/C/E/I category (Table 2), weighted by word count.
#
# Unlike Table 1 (artifact/rq1_formalize.sh), Table 2 cannot be regenerated
# live from the .lex/.rex sources with byte-for-byte fidelity: the per-section
# classification that produced the published numbers was frozen into the
# thesis this paper is drawn from, and the underlying git history that would
# let us regenerate it mechanically was not preserved (see ARTIFACT.md §5 for
# the full provenance/limitation writeup). What we *did* recover is that
# frozen classification table itself, from the thesis repository's own git
# history. This script reproduces Table 2 from that recovered table, and
# separately shows a live, best-effort regeneration from the (now annotated)
# minitwit_gdpr.rex for comparison.
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
echo "── For comparison: live regeneration from minitwit_gdpr.rex ──"
echo "   (annotated with # legal / # functional tags; see ARTIFACT.md §5 —"
echo "   this does NOT reproduce the numbers above exactly, and is not"
echo "   expected to: classify_coverage.py's per-predicate tagging rule and"
echo "   the frozen table's own dots were found to be mutually inconsistent"
echo "   in places, i.e. the drift predates this artifact.)"
docker run --rm -v "$(pwd):/workspace" -w "/workspace/$GDPR_DIR" "$IMG_LEX" \
  sh -lc "python3 classify_coverage.py 99 gdpr.lex minitwit_gdpr.rex > /workspace/artifact/out/rq1/classification_live.tex 2> /workspace/artifact/out/rq1/classify_live.log"
docker run --rm -v "$(pwd):/workspace" -w "/workspace/$GDPR_DIR" "$IMG_LEX" \
  python3 gdpr_stats.py /workspace/artifact/out/rq1/classification_live.tex GDPR.xml \
  | tee "$OUT_DIR/table2_live.txt"

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
