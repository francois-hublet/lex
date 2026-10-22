#!/usr/bin/env bash
# RQ3 — aggregate the benchmark CSVs written by artifact/rq3_benchmark.sh into
# the layout of Table 4 (also saved to artifact/out/rq3/table4.txt).
# Runs inside the GDPRSocial image, so no Python is needed on the host.
set -euo pipefail
cd "$(dirname "$0")/.."

IMG_SOCIAL="${IMG_SOCIAL:-gdprsocial:latest}"

echo "════════════════════════════════════════════════════════════════"
echo " Table 4 comparison (mean latency; paper values on the right)"
echo "════════════════════════════════════════════════════════════════"
docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd)/artifact:/artifact" "$IMG_SOCIAL" \
  python3 /artifact/rq3_table4.py /artifact/out/rq3
