#!/usr/bin/env bash
set -euo pipefail

# Axiom gate driver for physlib.
# Runs AxiomGate.lean via lake env lean and interprets the verdict line.
# Exit 0 on PASS, exit 1 on FAIL or missing verdict.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

echo "--- axiom gate: running AxiomGate.lean ---"
output="$(lake env lean scripts/gate/AxiomGate.lean 2>&1)"
echo "${output}"
echo "--- axiom gate: done ---"

if echo "${output}" | grep -q "AXIOM-GATE-VERDICT PASS"; then
  echo "axiom gate: PASS"
  exit 0
else
  echo "axiom gate: FAIL — sorryAx, native_decide, or unauthorized axiom detected (see QUARANTINE lines above)"
  exit 1
fi
