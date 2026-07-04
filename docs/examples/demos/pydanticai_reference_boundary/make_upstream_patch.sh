#!/usr/bin/env bash
# Generate an applyable patch for the upstream-shaped PydanticAI example.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
CANDIDATE_DIR="$DEMO_DIR/upstream_candidate"
UPSTREAM_REPO="${1:-$DEMO_DIR/../../../../pydantic-ai}"
PATCH_PATH="${PATCH_PATH:-$DEMO_DIR/pydanticai_heat_boundary_example.patch}"

[ -d "$CANDIDATE_DIR" ] || { echo "error: missing $CANDIDATE_DIR" >&2; exit 1; }
[ -d "$UPSTREAM_REPO/.git" ] || {
  echo "error: upstream repo not found at $UPSTREAM_REPO" >&2
  echo "usage: $0 [path/to/pydantic-ai]" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

work="$tmp_dir/work"
mkdir -p "$work"

candidate_files() {
  cd "$CANDIDATE_DIR"
  find examples -type f \
    ! -path '*/__pycache__/*' \
    ! -name '*.pyc' \
    ! -name '*.pyo' \
    | sort
}

copy_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

while IFS= read -r rel; do
  upstream_file="$UPSTREAM_REPO/$rel"
  if [ -f "$upstream_file" ]; then
    copy_file "$upstream_file" "$work/$rel"
  fi
done < <(candidate_files)

(
  cd "$work"
  git init -q
  git add .
  git -c user.name="Heat Demo" -c user.email="heat-demo@example.invalid" \
    commit -q --allow-empty -m "upstream baseline"
)

while IFS= read -r rel; do
  copy_file "$CANDIDATE_DIR/$rel" "$work/$rel"
done < <(candidate_files)

(
  cd "$work"
  git add .
  git diff --cached --binary --no-ext-diff HEAD > "$PATCH_PATH"
)

if [ ! -s "$PATCH_PATH" ]; then
  echo "error: generated patch is empty" >&2
  exit 1
fi

echo "wrote $PATCH_PATH"
echo "validate with: git -C '$UPSTREAM_REPO' apply --check '$PATCH_PATH'"
