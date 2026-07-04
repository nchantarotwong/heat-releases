#!/usr/bin/env bash
# Verify the committed upstream patch matches upstream_candidate/.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCH_PATH="$DEMO_DIR/pydanticai_heat_boundary_example.patch"
UPSTREAM_REPO="${1:-$DEMO_DIR/../../../../pydantic-ai}"
tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

[ -f "$PATCH_PATH" ] || { echo "error: missing committed patch: $PATCH_PATH" >&2; exit 1; }

fresh_patch="$tmp_dir/pydanticai_heat_boundary_example.patch"
PATCH_PATH="$fresh_patch" bash "$DEMO_DIR/make_upstream_patch.sh" "$UPSTREAM_REPO" >/dev/null

if ! diff -u "$PATCH_PATH" "$fresh_patch"; then
  echo "error: committed upstream patch is stale" >&2
  echo "fix: bash $DEMO_DIR/make_upstream_patch.sh ${1:-}" >&2
  exit 1
fi

if [ -d "$UPSTREAM_REPO/.git" ]; then
  git -C "$UPSTREAM_REPO" apply --check "$PATCH_PATH"
fi

echo "upstream patch is fresh"
