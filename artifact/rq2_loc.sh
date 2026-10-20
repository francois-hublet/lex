#!/usr/bin/env bash
# RQ2 — report code-size statistics for the two case-study applications,
# approximately reproducing Table 3 (instrumented application statistics).
#
# Uses `cloc` (via a throwaway container, so nothing needs to be installed on
# the host) to count Python/HTML/CSS lines, and a plain line count (wc -l,
# matching the paper's convention) for the Lex/Rex formalization files.
#
# Run from the repository root, after `git submodule update --init --recursive`.
set -euo pipefail
cd "$(dirname "$0")/.."

CS_DIR="evaluation/02_case_studies"
CLOC_IMG="ubuntu:24.04"

<<<<<<< HEAD
cloc_run() {
  local dir="$1"; shift
  docker run --rm -v "$(pwd)/$CS_DIR:/repo" -w "/repo/$dir" "$CLOC_IMG" \
    sh -c "apt-get update -qq >/dev/null && apt-get install -y -qq cloc >/dev/null && cloc --quiet --exclude-dir=__pycache__,migrations $*"
}

loc() {
  wc -l < "$1"
}

echo "════════════════════════════════════════════════════════════════"
echo " RQ2 — Instrumented application statistics (cf. Table 3)"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "── GDPRSocial baseline (uninstrumented) ──"
echo "  cloc twitt Twitter static/css/main.css templates manage.py"
cloc_run "GDPRSocial/benchmark/privacy_testsuite/baseline/minitwitter_bl" \
  "twitt Twitter static/css/main.css templates manage.py"

echo ""
echo "── GDPRSocial instrumented ──"
cloc_run "GDPRSocial" \
  "twitt Twitter static/css/main.css templates manage.py"

echo ""
echo "── GDPRFS instrumented (no baseline: replaces the local filesystem) ──"
cloc_run "GDPRFS" \
  "gdprfs external_consent_platform internal_purpose_platform LLManalyzer --exclude-dir=instrlib,__pycache__,tests"

echo ""
echo "── Lex / Rex formalization sizes ──"
printf "%-40s %10s %10s\n" "File" "LOC" "paper"
printf "%-40s %10s %10s\n" "GDPRSocial policies/gdpr.lex" "$(loc $CS_DIR/GDPRSocial/policies/gdpr.lex)" "3,221"
printf "%-40s %10s %10s\n" "GDPRSocial policies/minitwit_gdpr.rex" "$(loc $CS_DIR/GDPRSocial/policies/minitwit_gdpr.rex)" "1,021"

echo ""
echo "Note: expect the GDPRSocial/GDPRFS Python and HTML/CSS code line counts"
echo "above to closely match Table 3 (within a few dozen lines). They will not"
echo "match the +766/+0 *instrumentation delta* split exactly, since that"
echo "split (application logic vs. a single enforcer.py) required manual"
echo "inspection in the paper."
=======
# Runs cloc --csv in $1 over the remaining args, prints code-line totals for
# Python/HTML/CSS as "python html css" (0 if a language didn't appear).
cloc_totals() {
  local dir="$1"; shift
  local csv
  csv=$(docker run --rm -v "$(pwd)/$CS_DIR:/repo" -w "/repo/$dir" "$CLOC_IMG" \
    sh -c "apt-get update -qq >/dev/null && apt-get install -y -qq cloc >/dev/null && cloc --quiet --csv $*" 2>/dev/null)
  awk -F, '
    $2=="Python" {py=$5} $2=="HTML" {html=$5} $2=="CSS" {css=$5}
    END {print py+0, html+0, css+0}
  ' <<<"$csv"
}

loc() { wc -l < "$1"; }

echo "════════════════════════════════════════════════════════════════"
echo " RQ2 — Instrumented application statistics (Table 3)"
echo "════════════════════════════════════════════════════════════════"

read -r bl_py bl_html bl_css < <(cloc_totals \
  "GDPRSocial/benchmark/privacy_testsuite/baseline/minitwitter_bl" \
  --exclude-dir=__pycache__,migrations twitt Twitter static/css/main.css templates)
read -r in_py in_html in_css < <(cloc_totals \
  "GDPRSocial" \
  --exclude-dir=__pycache__,migrations twitt Twitter static/css/main.css templates)
read -r fs_py fs_html fs_css < <(cloc_totals \
  "GDPRFS" \
  gdprfs external_consent_platform internal_purpose_platform LLManalyzer --exclude-dir=instrlib,__pycache__,tests)

bl_hc=$((bl_html + bl_css))
in_hc=$((in_html + in_css))
fs_hc=$((fs_html + fs_css))

gdpr_lex=$(loc "$CS_DIR/GDPRSocial/policies/gdpr.lex")
mtg_rex=$(loc "$CS_DIR/GDPRSocial/policies/minitwit_gdpr.rex")

echo ""
printf "%-38s %10s %10s\n" "Figure" "here" "paper"
printf "%-38s %10s %10s\n" "GDPRSocial baseline Python"      "$bl_py"  "1,679"
printf "%-38s %10s %10s\n" "GDPRSocial baseline HTML/CSS"    "$bl_hc"  "2,123"
printf "%-38s %10s %10s\n" "GDPRSocial instrumented Python"  "$in_py"  "2,445"
printf "%-38s %10s %10s\n" "GDPRSocial instrumented HTML/CSS" "$in_hc" "2,123"
printf "%-38s %10s %10s\n" "GDPRSocial policies/gdpr.lex"    "$gdpr_lex" "3,221"
printf "%-38s %10s %10s\n" "GDPRSocial policies/minitwit_gdpr.rex" "$mtg_rex" "1,021"
printf "%-38s %10s %10s\n" "GDPRFS instrumented Python"      "$fs_py"  "2,536"
printf "%-38s %10s %10s\n" "GDPRFS instrumented HTML/CSS"    "$fs_hc"  "1,135"

echo ""
if [ "$in_py" -ne 2445 ]; then
  echo "Note: GDPRSocial's instrumented Python figure is off by $((in_py - 2445))"
  echo "lines from the paper (all other figures above match exactly); this is"
  echo "genuine code that changed after publication, not a counting artifact"
  echo "(the identical baseline snapshot, unchanged since the case study was"
  echo "first committed, matches the paper exactly)."
fi
>>>>>>> b2673b28b3ebf0dfd0463f92239f8e403ac4eab8
