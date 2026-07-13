#!/usr/bin/env bash
set -euo pipefail

# Axiom gate driver for physlib.
# Runs the compiled axiom_gate lake exe and interprets the verdict line.
# Exit 0 on PASS, exit 1 on FAIL or missing verdict.
#
# Usage: bash scripts/gate/run-axiom-gate.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

echo "--- axiom gate: building axiom_gate exe ---"
lake build axiom_gate 2>&1

echo "--- axiom gate: running ---"
output="$(lake exe axiom_gate 2>&1)"
echo "${output}"
echo "--- axiom gate: done ---"

if echo "${output}" | grep -q "AXIOM-GATE-VERDICT PASS"; then
  echo "axiom gate: PASS"
  exit 0
else
  echo "axiom gate: FAIL — sorryAx, native_decide, or unauthorized axiom detected (see QUARANTINE lines above)"
  exit 1
fi
