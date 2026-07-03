#!/usr/bin/env bash
# Capture REAL heatc output for every gateway flow into proof.json.
# The viewer (index.html) embeds this so every "bounce" in the animation
# maps to an actual compiler diagnostic — nothing is mocked.
#
# Usage: bash capture.sh   (expects a fresh /tmp/heatc; see CLAUDE.md rebuild)
set -euo pipefail
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../../.." && pwd)"   # runtime .o files link relative to repo root

HEATC="${HEATC:-/tmp/heatc}"
[ -x "$HEATC" ] || { echo "error: $HEATC not executable — rebuild heatc first" >&2; exit 1; }

# id | class label | bad file | fixed file
FLOWS=(
  "injected_arg|Injected tool argument|01_injected_tool_arg|01_injected_tool_arg_fixed"
  "call_order|Out-of-order tool call|02_tool_call_order|02_tool_call_order_fixed"
  "policy|Project egress policy|03_policy_obligation|03_policy_obligation_fixed"
)

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

# Capture the refusal diagnostic from the demo dir so paths stay short.
refuse_diag() { # <file> -> "REFUSED\n<diag>" or "COMPILED"
  local out; out="$(cd "$DEMO_DIR" && timeout 30s "$HEATC" "$1.heat" -o "/tmp/rb_$1" 2>/dev/null || true)"
  if echo "$out" | grep -q 'not emitting'; then printf 'REFUSED\n'; echo "$out" | grep -m1 'error\[NL'
  else printf 'COMPILED\n'; fi
}

# A fixed flow "passes" only if it truly links to a runnable binary (from
# repo root, where the runtime .o files resolve) — not merely 0 analyzer errors.
truly_builds() { # <file> -> "BUILT" | "FAILED"
  local bin="/tmp/rb_$1"; rm -f "$bin"
  ( cd "$REPO_ROOT" && timeout 40s "$HEATC" "examples/demos/reference_boundary/$1.heat" -o "$bin" >/dev/null 2>&1 || true )
  [ -x "$bin" ] && printf 'BUILT' || printf 'FAILED'
}

{
  echo "{"
  echo "  \"generated_by\": \"heatc via capture.sh\","
  echo "  \"flows\": ["
  first=1
  for row in "${FLOWS[@]}"; do
    IFS='|' read -r id label bad fixed <<< "$row"
    bad_res="$(refuse_diag "$bad")"; bad_verdict="$(echo "$bad_res" | head -1)"; bad_diag="$(echo "$bad_res" | tail -n +2)"
    fix_verdict="$(truly_builds "$fixed")"
    [ $first -eq 1 ] || echo "    ,"
    first=0
    echo "    {"
    echo "      \"id\": \"$id\","
    echo "      \"label\": $(printf '%s' "$label" | json_escape),"
    echo "      \"bad_verdict\": \"$bad_verdict\","
    echo "      \"diagnostic\": $(printf '%s' "$bad_diag" | json_escape),"
    echo "      \"fixed_verdict\": \"$fix_verdict\""
    echo "    }"
  done
  echo "  ]"
  echo "}"
} > proof.json

echo "wrote proof.json"
