#!/usr/bin/env bash
# Compile the two case-study refinements (.rex) into the MFOTL policies
# (.mfotl/.sig) that the applications enforce, and install them into the
# applications' policy folders. `make artifact-build` runs this after building
# the Lex image and before building the application images, so the images
# always enforce policies compiled from the .lex/.rex sources.
#
#   GDPRSocial: GDPRSocial/policies/minitwit_gdpr.rex  (refines gdpr.lex)
#   GDPRFS:     GDPRFS/gdprfs/policies/gdprfs.rex      (refines gdpr.lex)
#
# Run from the repository root, after the Lex image has been built.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG_LEX="${IMG_LEX:-lex:latest}"
CS_DIR="evaluation/02_case_studies"
OUT_DIR="artifact/out/policies"
mkdir -p "$OUT_DIR"

# compile NAME SRC_DIR REX FLAGS [EXTRA_FILE...]
#   Copies SRC_DIR/REX, SRC_DIR/gdpr.lex and EXTRA_FILEs into a scratch folder
#   inside the container, compiles REX there with FLAGS, and writes
#   OUT_DIR/NAME.{mfotl,sig} (compiler trace: OUT_DIR/NAME.compile.log).
compile() {
  local name="$1" src="$2" rex="$3" flags="$4"; shift 4
  local extra=""
  for f in "$@"; do extra="$extra /workspace/$f"; done
  echo "── Compiling ${src}/${rex} ──"
  docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd):/workspace" "$IMG_LEX" \
    sh -lc "set -e; w=\$(mktemp -d); cp /workspace/${src}/${rex} /workspace/${src}/gdpr.lex${extra} \$w/; cd \$w; \
            /home/opam/lex/_build/default/bin/main.exe ${rex} ${flags} -o /workspace/${OUT_DIR}/${name}" \
    > "$OUT_DIR/${name}.compile.log" 2>&1
}

# install NAME DEST_DIR: copy the compiled policy into the application.
install_policy() {
  local name="$1" dest="$2"
  for ext in mfotl sig; do
    if cmp -s "$OUT_DIR/${name}.${ext}" "${dest}/${name}.${ext}"; then
      echo "   ${dest}/${name}.${ext}: unchanged"
    else
      cp "$OUT_DIR/${name}.${ext}" "${dest}/${name}.${ext}"
      echo "   ${dest}/${name}.${ext}: updated"
    fi
  done
}

echo "════════════════════════════════════════════════════════════════"
echo " Compiling the case-study refinements into enforceable policies"
echo "════════════════════════════════════════════════════════════════"

compile minitwit_gdpr "$CS_DIR/GDPRSocial/policies" minitwit_gdpr.rex -label \
  evaluation/01_formalization/GDPR.xml
install_policy minitwit_gdpr "$CS_DIR/GDPRSocial/policies"

compile gdprfs "$CS_DIR/GDPRFS/gdprfs/policies" gdprfs.rex ""
install_policy gdprfs "$CS_DIR/GDPRFS/gdprfs/policies"
