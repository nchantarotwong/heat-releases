#!/usr/bin/env bash
# Capture real heatc output for the PydanticAI-shaped boundary demo.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../../../.." && pwd)"
HEATC="${HEATC:-/tmp/heatc}"
EXPECTED_CODE="NL-OBL-001"

[ -x "$HEATC" ] || { echo "error: $HEATC not executable; rebuild heatc first" >&2; exit 1; }

json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

capture_refusal() {
  local file="$1"
  local code="$2"
  local bin="$3"
  local out
  out="$(cd "$DEMO_DIR" && timeout 30s "$HEATC" "$file" -o "$bin" 2>/dev/null || true)"
  if echo "$out" | grep -q "error\\[$code\\]"; then
    printf 'REFUSED\n'
    echo "$out" | grep -m1 "error\\[$code\\]"
    return 0
  fi
  echo "error: $file did not produce expected $code refusal" >&2
  echo "$out" >&2
  return 1
}

capture_build() {
  local file="$1"
  local bin="$2"
  local out
  rm -f "$bin"
  out="$(
    cd "$REPO_ROOT"
    timeout 40s "$HEATC" "examples/demos/pydanticai_reference_boundary/heat_boundary/$file" -o "$bin" 2>&1 || true
  )"
  if [ -x "$bin" ]; then
    printf 'BUILT'
    return 0
  fi
  echo "error: repaired boundary did not build" >&2
  echo "$out" >&2
  return 1
}

bad_res="$(capture_refusal bank_support_boundary.heat "$EXPECTED_CODE" /tmp/heat_pydanticai_boundary)"
bad_verdict="$(echo "$bad_res" | head -1)"
bad_diag="$(echo "$bad_res" | tail -n +2)"
fix_verdict="$(capture_build bank_support_boundary_fixed.heat /tmp/heat_pydanticai_boundary_fixed)"

helper_res="$(capture_refusal bank_support_helper_bypass.heat "$EXPECTED_CODE" /tmp/heat_pydanticai_helper_bypass)"
helper_verdict="$(echo "$helper_res" | head -1)"
helper_diag="$(echo "$helper_res" | tail -n +2)"

webhook_res="$(capture_refusal bank_support_webhook.heat NL-0500 /tmp/heat_pydanticai_webhook)"
webhook_verdict="$(echo "$webhook_res" | head -1)"
webhook_diag="$(echo "$webhook_res" | tail -n +2)"
webhook_fix_verdict="$(capture_build bank_support_webhook_fixed.heat /tmp/heat_pydanticai_webhook_fixed)"

{
  echo "{"
  echo "  \"generated_by\": \"heatc via capture.sh\","
  echo "  \"target\": \"pydantic/pydantic-ai\","
  echo "  \"expected_diagnostic\": \"$EXPECTED_CODE\","
  echo "  \"bad_verdict\": \"$bad_verdict\","
  echo "  \"diagnostic\": $(printf '%s' "$bad_diag" | json_escape),"
  echo "  \"fixed_verdict\": \"$fix_verdict\","
  echo "  \"flows\": ["
  echo "    {"
  echo "      \"id\": \"filesystem_boundary\","
  echo "      \"label\": \"Model-controlled file export\","
  echo "      \"bad_verdict\": \"$bad_verdict\","
  echo "      \"diagnostic\": $(printf '%s' "$bad_diag" | json_escape),"
  echo "      \"fixed_verdict\": \"$fix_verdict\""
  echo "    },"
  echo "    {"
  echo "      \"id\": \"missed_helper\","
  echo "      \"label\": \"Helper bypasses Python guard convention\","
  echo "      \"bad_verdict\": \"$helper_verdict\","
  echo "      \"diagnostic\": $(printf '%s' "$helper_diag" | json_escape)"
  echo "    },"
  echo "    {"
  echo "      \"id\": \"webhook_egress\","
  echo "      \"label\": \"Model-controlled webhook URL/body\","
  echo "      \"bad_verdict\": \"$webhook_verdict\","
  echo "      \"diagnostic\": $(printf '%s' "$webhook_diag" | json_escape),"
  echo "      \"fixed_verdict\": \"$webhook_fix_verdict\""
  echo "    }"
  echo "  ]"
  echo "}"
} > "$DEMO_DIR/proof.json"

echo "wrote examples/demos/pydanticai_reference_boundary/heat_boundary/proof.json"
