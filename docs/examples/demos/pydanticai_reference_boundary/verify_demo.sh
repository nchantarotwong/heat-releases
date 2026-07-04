#!/usr/bin/env bash
# Verify the PydanticAI reference-boundary demo artifacts.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../../.." && pwd)"

cd "$REPO_ROOT"

cleanup_python_caches() {
  rm -rf \
    examples/demos/pydanticai_reference_boundary/__pycache__ \
    examples/demos/pydanticai_reference_boundary/upstream_candidate/examples/pydantic_ai_examples/__pycache__
}

cleanup_python_caches
trap cleanup_python_caches EXIT

echo "== shell syntax =="
bash -n \
  examples/demos/pydanticai_reference_boundary/run_demo.sh \
  examples/demos/pydanticai_reference_boundary/heat_boundary/capture.sh \
  examples/demos/pydanticai_reference_boundary/make_upstream_patch.sh \
  examples/demos/pydanticai_reference_boundary/check_upstream_patch.sh \
  examples/demos/pydanticai_reference_boundary/upstream_candidate/examples/pydantic_ai_examples/heat_boundary/capture.sh

echo
echo "== python syntax =="
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile \
  examples/demos/pydanticai_reference_boundary/validate_proof.py \
  examples/demos/pydanticai_reference_boundary/boundary_adapter.py \
  examples/demos/pydanticai_reference_boundary/summarize_proof.py \
  examples/demos/pydanticai_reference_boundary/capture_visuals.py \
  examples/demos/pydanticai_reference_boundary/pydanticai_bank_support.py \
  examples/demos/pydanticai_reference_boundary/upstream_candidate/examples/pydantic_ai_examples/validate_proof.py \
  examples/demos/pydanticai_reference_boundary/upstream_candidate/examples/pydantic_ai_examples/heat_boundary_bank_support.py

echo
echo "== proof and contract schema =="
python3 examples/demos/pydanticai_reference_boundary/validate_proof.py
python3 examples/demos/pydanticai_reference_boundary/validate_proof.py --self-test

echo
echo "== upstream patch freshness =="
bash examples/demos/pydanticai_reference_boundary/check_upstream_patch.sh

echo
echo "== end-to-end demo =="
bash examples/demos/pydanticai_reference_boundary/run_demo.sh

echo
echo "pydanticai reference-boundary demo verified"
