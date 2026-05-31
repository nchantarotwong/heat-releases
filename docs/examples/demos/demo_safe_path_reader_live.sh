#!/bin/bash
# demo_safe_path_reader_live.sh — 5-min live demo for demo runs.
#
# The story: same Claude prompt, two languages, different safety outcomes.
# Python ships path-traversal-vulnerable code; Heat refuses at compile
# time with NL-0500. Backed by real benchmark generations, not
# hand-crafted demos.
#
# Designed for screen-sharing: pauses between steps so you can narrate,
# color-codes for readability, shows commands before running them.
#
# Pre-reqs:
#   - Local benchmark results under benchmark/results/ (gitignored;
#     run benchmark/run_benchmark.py first if you don't have them)
#   - heatc installed via ~/.local/bin/heatc OR /tmp/heatc
#   - python3, bash 4+
#
# Usage:
#   bash examples/demos/demo_safe_path_reader_live.sh
#
# Tip for the call: bump terminal font size 2-3 stops (Cmd-+ in iTerm)
# before sharing. The output is dense; small fonts read as noise on
# the viewer's end.

set -e
cd "$(dirname "$0")/../.."

# === Visual setup =========================================================

BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'

step() {
    echo ""
    echo "${BOLD}${CYAN}━━━ $1 ━━━${RESET}"
    echo ""
}

cmd() {
    echo "${DIM}\$${RESET} ${BOLD}$1${RESET}"
    eval "$1"
}

pause() {
    echo ""
    echo "${DIM}--- Press Enter to continue ---${RESET}"
    read -r
}

# === Pre-flight checks ====================================================

# Find a working heatc — prefer the wrapper, fall back to /tmp/heatc.
HEATC=""
if command -v heatc >/dev/null 2>&1 && heatc check examples/demos/demo_tool_response.heat >/dev/null 2>&1; then
    HEATC="heatc"
elif [ -x /tmp/heatc ]; then
    HEATC="/tmp/heatc"
fi
if [ -z "$HEATC" ]; then
    echo "${RED}error: no working heatc found.${RESET}" >&2
    echo "       Run 'bash bootstrap/scripts/heatc_rebuild.sh' first." >&2
    exit 1
fi

# Find the latest results dir for each provider. Falls back to the
# earliest non-empty if you've cleaned and re-run.
ANTHROPIC_DIR=$(ls -td benchmark/results/anthropic/2*/ 2>/dev/null | head -1)
OPENAI_DIR=$(ls -td benchmark/results/openai/2*/ 2>/dev/null | head -1)
GOOGLE_DIR=$(ls -td benchmark/results/google/2*/ 2>/dev/null | head -1)

if [ -z "$ANTHROPIC_DIR" ]; then
    echo "${RED}error: no benchmark results found under benchmark/results/anthropic/${RESET}" >&2
    echo "       Run benchmark/run_benchmark.py first to generate them." >&2
    exit 1
fi

# === Setup the path-traversal canary fixture ==============================

step "Setup: path-traversal canary fixture"
mkdir -p /tmp/path_traversal_canary/configs
echo "ok" > /tmp/path_traversal_canary/configs/default.cfg
echo "valid" > /tmp/path_traversal_canary/configs/other.cfg
echo "PWNED" > /tmp/path_traversal_canary/secret.cfg
echo "Layout:"
echo "  /tmp/path_traversal_canary/"
echo "  ├── configs/"
echo "  │   ├── default.cfg  → 'ok'"
echo "  │   └── other.cfg    → 'valid'"
echo "  └── secret.cfg       → ${RED}'PWNED'${RESET}  ${DIM}(one dir up — what a path-traversal exploit reaches)${RESET}"

# === Find a clean demo pair ===============================================

step "Finding demo pair (same Claude seed: Python ships vulnerable, Heat trips NL-0500)"

PAIR=$(python3 - <<EOF
import json, sys
with open('${ANTHROPIC_DIR}results.json') as f:
    data = json.load(f)
for e in data['entries']:
    if e.get('task') != 'safe_path_reader_v3': continue
    h_fp = e.get('heat',{}).get('first_pass',{}) or {}
    p_fp = e.get('python',{}).get('first_pass',{}) or {}
    h_eval = h_fp.get('evaluation',{}) or {}
    p_eval = p_fp.get('evaluation',{}) or {}
    h_failures = str(h_eval.get('failures',''))
    if 'NL-0500' in h_failures and p_eval.get('outcome') == 'shipped_incorrect':
        py = p_fp.get('source_file','')
        ht = h_fp.get('source_file','')
        if py and ht:
            print(f'{py}|{ht}')
            sys.exit(0)
sys.exit(1)
EOF
) || true

if [ -z "$PAIR" ]; then
    echo "${RED}error: no clean demo pair found in ${ANTHROPIC_DIR}.${RESET}" >&2
    echo "       Need a seed where Python is shipped_incorrect AND Heat hit NL-0500." >&2
    exit 1
fi

PYFILE="${PAIR%|*}"
HEATFILE="${PAIR#*|}"
SEED=$(basename "$PYFILE" .py | sed 's/safe_path_reader_v3-//')

echo "Found pair (seed ${SEED}, model: claude-sonnet-4-6):"
echo "  Python: ${DIM}${PYFILE}${RESET}"
echo "  Heat:   ${DIM}${HEATFILE}${RESET}"

pause

# === Step 1: The prompt ===================================================

step "Step 1 / 5 — The prompt"
echo "${DIM}Same prompt sent to Claude in two languages. Neutral wording — no${RESET}"
echo "${DIM}safety hints, no 'treat as untrusted', no 'sanitize the name'.${RESET}"
echo ""
cmd "grep -A 5 '^TASK:' benchmark/prompts/heat/safe_path_reader_v3.txt"

pause

# === Step 2: Python output ================================================

step "Step 2 / 5 — What Claude wrote in Python"
cmd "cat $PYFILE"
echo ""
echo "${YELLOW}↑ Notice: opens the file directly. No path validation.${RESET}"

pause

step "Step 2a — Run on benign input (the public test case)"
cmd "echo 'default' | python3 $PYFILE"
echo ""
echo "${GREEN}↑ Public case passes. Looks fine.${RESET}"

pause

step "Step 2b — Run on the exploit input"
cmd "echo '../secret' | python3 $PYFILE"
echo ""
echo "${RED}↑ Same code, different input — different file got read.${RESET}"
echo "${RED}  Python compiled, ran, exited 0. Path traversal succeeded.${RESET}"

pause

# === Step 3: Heat output ==================================================

step "Step 3 / 5 — What Claude wrote in Heat (same prompt, same model)"
cmd "cat $HEATFILE"
echo ""
echo "${YELLOW}↑ Same shape. Claude wrote the equivalent code in Heat.${RESET}"

pause

# === Step 4: Heat compile-time refusal ====================================

step "Step 4 / 5 — Try to compile it"
echo "${DIM}\$${RESET} ${BOLD}${HEATC} check ${HEATFILE}${RESET}"
# Filter out compiler-internal counters (tokens / instructions / strings)
# so the NL-0500 error is the first thing the viewer reads. The counters
# are useful for compiler debugging but dilute the demo's punch.
timeout 15s "$HEATC" check "$HEATFILE" 2>&1 \
    | grep -Ev '^(tokens|instructions|strings):' \
    | tail -10 || true
echo ""
echo "${RED}↑ NL-0500 fires. Compile time. No binary built.${RESET}"
echo ""
echo "${GREEN}  Same model. Same prompt. Different language. Different safety outcome.${RESET}"
echo "${GREEN}  Heat's compile-time provenance tracker refused the @user_input flow${RESET}"
echo "${GREEN}  into read_file's @path_safe slot — the bug Python shipped, Heat caught.${RESET}"

pause

# === Step 5: At scale =====================================================

step "Step 5 / 5 — This is the structural pattern, not one flaky run"

python3 - <<EOF
import json
totals = {'heat_refused':0, 'py_vulnerable':0, 'total':0}
for prov, path in [
    ('anthropic', '${ANTHROPIC_DIR}results.json'),
    ('openai',    '${OPENAI_DIR}results.json'),
    ('google',    '${GOOGLE_DIR}results.json'),
]:
    try:
        with open(path) as f:
            data = json.load(f)
    except (FileNotFoundError, OSError):
        continue
    for e in data['entries']:
        if e.get('task') != 'safe_path_reader_v3': continue
        totals['total'] += 1
        h_failures = str(e.get('heat',{}).get('first_pass',{}).get('evaluation',{}).get('failures',''))
        p_outcome = e.get('python',{}).get('first_pass',{}).get('evaluation',{}).get('outcome')
        if 'NL-0500' in h_failures: totals['heat_refused'] += 1
        if p_outcome == 'shipped_incorrect': totals['py_vulnerable'] += 1
print(f"Across {totals['total']} generations (Claude Sonnet 4.6 + GPT-5.4 + Gemini 2.5 Pro):")
print(f"  Python shipped vulnerable:  {totals['py_vulnerable']}/{totals['total']}")
print(f"  Heat refused at compile:    {totals['heat_refused']}/{totals['total']}")
EOF

echo ""
echo "${BOLD}${GREEN}Same prompts. Same models. Different language. Different safety outcome.${RESET}"
echo ""
echo "${DIM}— end demo —${RESET}"
echo ""
