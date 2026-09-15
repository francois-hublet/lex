#!/usr/bin/env bash
# RQ1 — compile the three legal formalizations (GDPR, BGG, IRC) with the Lex
# compiler and report their line counts, reproducing Table 1 of the paper.
#
# Run from the repository root, after `make artifact-build`.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG_LEX="${IMG_LEX:-lex:latest}"
OUT_DIR="$(pwd)/artifact/out/rq1"
mkdir -p "$OUT_DIR"

echo "════════════════════════════════════════════════════════════════"
echo " RQ1 — Legal expressivity: compiling GDPR / BGG / IRC formalizations"
echo "════════════════════════════════════════════════════════════════"

run() {
  local name="$1" src="$2"
  echo ""
  echo "── Compiling ${name} (${src}) ──"
  # The compiler prints a verbose per-rule debug trace to stdout; keep the
  # terminal readable by redirecting it to a log file alongside the output.
  docker run --rm -v "$(pwd):/workspace" -w /workspace "$IMG_LEX" \
    sh -lc "dune exec -- ./bin/main.exe '${src}' -o /workspace/artifact/out/rq1/${name}" \
    > "$OUT_DIR/${name}.compile.log" 2>&1
  ls -lh "$OUT_DIR/${name}."* 2>/dev/null || true
}

run gdpr evaluation/01_formalization/gdpr.lex
run bgg  evaluation/01_formalization/bgg.lex
run irc  evaluation/01_formalization/irc.lex

run minitwit_gdpr evaluation/01_formalization/minitwit_gdpr.rex

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " Table 1 comparison (lines of code)"
echo "════════════════════════════════════════════════════════════════"
printf "%-8s %10s %10s\n" "Law" "LOC (here)" "LOC (paper)"
for pair in "gdpr:evaluation/01_formalization/gdpr.lex:3221" \
            "bgg:evaluation/01_formalization/bgg.lex:234" \
            "irc:evaluation/01_formalization/irc.lex:131"; do
  IFS=: read -r name src paper <<<"$pair"
  loc=$(wc -l < "$src")
  printf "%-8s %10s %10s\n" "$name" "$loc" "$paper"
done

echo ""
echo "Compiled .sig/.mfotl artifacts are under artifact/out/rq1/."
