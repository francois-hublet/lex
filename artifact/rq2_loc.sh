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
