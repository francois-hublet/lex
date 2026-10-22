#!/usr/bin/env bash
# RQ1 — GDPR coverage by F/C/E/I category (Table 2), weighted by word count.
#
# Table 2 is computed from the per-provision F/C/E/I classification of the
# GDPR (example/GDPR/classification_published.tex) and the GDPR's official
# Formex text (example/GDPR/GDPR.xml): gdpr_stats.py weights every classified
# provision by its word count and aggregates the weights into Table 2.
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
echo "── Computing Table 2 from the provision classification ──"
docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd):/workspace" -w "/workspace/$GDPR_DIR" "$IMG_LEX" \
  python3 gdpr_stats.py classification_published.tex GDPR.xml \
  | tee "$OUT_DIR/table2_published.txt"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Table 2 comparison (% of law, weighted by word count)"
echo "════════════════════════════════════════════════════════════════"
# Extract the "% of law" column from the gdpr_stats.py output above.
here() { awk -v s="$1" 'index($0, s) { for (i = 1; i <= NF; i++) if ($i ~ /%$/) { print $i; exit } }' "$OUT_DIR/table2_published.txt"; }
printf "%-30s %10s %10s\n" "Status" "here" "paper"
printf "%-30s %10s %10s\n" "Formalized (F)"             "$(here 'Formalized (F)')"             "18.4%"
printf "%-30s %10s %10s\n" "Conservatively assumed (C)" "$(here 'Conservatively assumed (C)')" "7.8%"
printf "%-30s %10s %10s\n" "Enforced at runtime (E)"    "$(here 'Enforced at runtime (E)')"    "7.2%"
printf "%-30s %10s %10s\n" "Informally assumed (I)"     "$(here 'Informally assumed (I)')"     "6.4%"
echo ""
echo "('here' is computed by gdpr_stats.py from the provision classification"
echo "example/GDPR/classification_published.tex and the GDPR text"
echo "example/GDPR/GDPR.xml. It may differ by <0.1pp from the paper because of a"
echo "different GDPR.xml/Formex edition.)"
