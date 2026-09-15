#!/usr/bin/env bash
#
# run_benchmark.sh — Prepare databases then run the full performance benchmark.
#
# Usage:
#   ./benchmark/privacy_testsuite/run_benchmark.sh <policy> [<enfguard_exe>]
#
# For enforced policies supply the enfguard executable:
#   ./benchmark/privacy_testsuite/run_benchmark.sh minitwit_gdpr /opt/whyenf/enfguard
#
# For the un-instrumented baseline no enforcer argument is required:
#   ./benchmark/privacy_testsuite/run_benchmark.sh baseline
#
set -euo pipefail
cd "$(dirname "$0")/../.."   # → miniTwitter_gdpr/

POLICY="${1:?Usage: $0 <policy> [<enfguard_exe>]}"

# EXE is only required for enforced policies.
if [[ "${POLICY}" == "baseline" ]]; then
    EXE=""
else
    EXE="${2:?Enforced policy '${POLICY}' requires an <enfguard_exe> argument.}"
fi
OUTPUT_DIR="output"

echo "══════════════════════════════════════════════════════════"
echo "  Step 1 – Preparing database snapshots"
echo "══════════════════════════════════════════════════════════"
python3 benchmark/privacy_testsuite/prepare_databases.py

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Step 2 – Running benchmark  (policy=${POLICY})"
echo "══════════════════════════════════════════════════════════"
python3 benchmark/privacy_testsuite/privacy_test.py minitwitter \
    -f "${OUTPUT_DIR}" \
    -p "${POLICY}" \
    -e "${EXE}"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "  Done — results in ${OUTPUT_DIR}/"
echo "══════════════════════════════════════════════════════════"
