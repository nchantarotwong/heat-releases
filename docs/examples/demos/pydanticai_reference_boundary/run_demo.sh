#!/usr/bin/env bash
# One-command proof for the PydanticAI-shaped Heat boundary demo.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../../.." && pwd)"
ATTACK_EXPORT="/tmp/heat_pydanticai_public_case.txt"
SAFE_EXPORT="/tmp/heat_pydanticai_safe_exports/case_4142.txt"

cd "$REPO_ROOT"

echo "== capture Heat proof =="
bash examples/demos/pydanticai_reference_boundary/heat_boundary/capture.sh
python3 examples/demos/pydanticai_reference_boundary/validate_proof.py

echo
echo "== before: Python tool egress runs =="
rm -f "$ATTACK_EXPORT"
python3 examples/demos/pydanticai_reference_boundary/before_bank_support.py
[ -f "$ATTACK_EXPORT" ] || { echo "error: before demo did not create $ATTACK_EXPORT" >&2; exit 1; }

echo
echo "== after: same egress class is stopped at the boundary =="
rm -f "$ATTACK_EXPORT"
python3 examples/demos/pydanticai_reference_boundary/after_bank_support.py
[ ! -f "$ATTACK_EXPORT" ] || { echo "error: after demo unexpectedly created $ATTACK_EXPORT" >&2; exit 1; }

echo
echo "== pydanticai-shaped slice: same guarded tool adapter =="
rm -f "$ATTACK_EXPORT"
python3 examples/demos/pydanticai_reference_boundary/pydanticai_bank_support.py
[ ! -f "$ATTACK_EXPORT" ] || { echo "error: pydanticai slice unexpectedly created $ATTACK_EXPORT" >&2; exit 1; }

echo
echo "== repaired slice: laundered path is allowed =="
rm -f "$SAFE_EXPORT"
python3 examples/demos/pydanticai_reference_boundary/pydanticai_bank_support.py --repaired
[ -f "$SAFE_EXPORT" ] || { echo "error: repaired slice did not create $SAFE_EXPORT" >&2; exit 1; }

echo
echo "== proof summary =="
python3 examples/demos/pydanticai_reference_boundary/summarize_proof.py
