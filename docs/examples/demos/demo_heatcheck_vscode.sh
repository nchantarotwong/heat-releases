#!/bin/bash
# demo_heatcheck_vscode.sh — semi-automated VS Code + heatcheck demo.
#
# Stages a deterministic editor state for screen recording:
#   - opens VS Code at examples/demos/heatcheck_demo.py
#   - cursor placed on the HC-005 violation line
#   - on macOS, sizes/positions the window to a known frame
#   - prints the click sequence to follow while recording
#
# The recording itself is manual (QuickTime / OBS / Cmd-Shift-5).
# Automation handles only the deterministic-state part — what
# changes per release (Heat / heatcheck versions, hover content)
# rebuilds itself; what doesn't (window chrome, cursor blink, hover
# delay) stays in the recorder's hands.
#
# Pre-reqs:
#   - heatcheck binary built (see Step 0 below — script self-checks)
#   - VS Code extension installed (run install_vscode_ext.sh if not)
#   - VS Code's `code` CLI on PATH
#
# Usage: bash examples/demos/demo_heatcheck_vscode.sh

set -e
cd "$(dirname "$0")/../.."

DEMO="examples/demos/heatcheck_demo.py"
DEMO_LINE=13   # the cur.execute(...) line — where the cursor lands
DEMO_COL=8

BOLD=$'\033[1m'
DIM=$'\033[2m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
RESET=$'\033[0m'

err() { echo "${RED}error: $1${RESET}" >&2; }
ok()  { echo "${GREEN}✓${RESET} $1"; }
note(){ echo "${DIM}    $1${RESET}"; }
step(){ echo ""; echo "${BOLD}${CYAN}━━━ $1 ━━━${RESET}"; }

# === Step 0 — pre-flight ====================================================

step "Step 0 — pre-flight"

# heatcheck binary. Prefer /tmp/heatcheck (the dev rebuild target)
# over PATH so the demo always shows the latest hover messages,
# auto-fix patterns, etc. — independent of whatever older version
# the user might have globally installed via heatcheck/install.sh.
HEATCHECK=""
if [ -x /tmp/heatcheck ]; then
    HEATCHECK="/tmp/heatcheck"
elif command -v heatcheck >/dev/null 2>&1; then
    HEATCHECK="$(command -v heatcheck)"
else
    err "no heatcheck binary found (/tmp/heatcheck or PATH)"
    note "Build with:"
    note "    bash bootstrap/scripts/heatc_rebuild.sh"
    note "    /tmp/heatc heatcheck/heatcheck.heat -o /tmp/heatcheck"
    exit 1
fi
ok "heatcheck:  $HEATCHECK ($("$HEATCHECK" --version 2>&1))"

# VS Code CLI
if ! command -v code >/dev/null 2>&1; then
    err "VS Code's \`code\` CLI not found on PATH"
    note "Open VS Code, then run \"Shell Command: Install 'code' command in PATH\""
    note "from the Command Palette."
    exit 1
fi
ok "code:       $(command -v code)"

# Extension installed
if ! code --list-extensions 2>/dev/null | grep -qx "nchantarotwong.heatcheck"; then
    err "heatcheck VS Code extension not installed"
    note "Install with:"
    note "    bash bootstrap/scripts/install_vscode_ext.sh"
    exit 1
fi
ok "extension:  nchantarotwong.heatcheck installed"

# Demo fixture
if [ ! -f "$DEMO" ]; then
    err "demo fixture missing: $DEMO"
    exit 1
fi
ok "fixture:    $DEMO"

# Confirm heatcheck flags it (so we know the squigglies will show)
VIO_COUNT=$("$HEATCHECK" "$DEMO" 2>&1 | grep -c "^.*:[0-9]*:[0-9]*  HC-" || true)
if [ "$VIO_COUNT" -lt 1 ]; then
    err "heatcheck found no violations in the demo fixture — something changed"
    note "Re-check $DEMO; the demo expects 1 HC-005 violation."
    exit 1
fi
ok "violations: $VIO_COUNT (expected ≥1)"

# === Step 1 — stage workspace settings =====================================

step "Step 1 — stage workspace VS Code settings"

# A workspace .vscode/settings.json so the extension picks up the
# locally-built /tmp/heatcheck binary (no PATH dependency for the
# demo). Idempotent — overwrites if present.
mkdir -p .vscode
cat > .vscode/settings.json <<JSON
{
  "heatcheck.binary": "$HEATCHECK",
  "editor.fontSize": 16,
  "workbench.colorTheme": "Default Dark Modern",
  "editor.minimap.enabled": false,
  "editor.lineNumbers": "on",
  "explorer.openEditors.visible": 0,
  "editor.inlayHints.enabled": "on",
  "editor.inlayHints.fontSize": 13,
  "editor.inlayHints.padding": true
}
JSON
ok "wrote .vscode/settings.json"
note "extension will spawn $HEATCHECK lsp"
note "font + theme + minimap tuned for screen recording"

# === Step 2 — open VS Code at the demo file ================================

step "Step 2 — open VS Code"

# --new-window so the demo doesn't pollute (or get polluted by) any
# existing VS Code session.
code --new-window --goto "${DEMO}:${DEMO_LINE}:${DEMO_COL}" "$(pwd)"
ok "VS Code opening at $DEMO line $DEMO_LINE"

# Give VS Code a moment to launch + LSP to attach (extension activates
# onLanguage:python; first hover/diagnostic takes ~300ms after open).
sleep 2

# === Step 3 — best-effort window positioning (macOS only) ==================

if [[ "$OSTYPE" == "darwin"* ]]; then
    step "Step 3 — position VS Code window (macOS)"
    osascript >/dev/null 2>&1 <<APPLESCRIPT || true
tell application "Visual Studio Code" to activate
delay 0.3
tell application "System Events"
    tell process "Code"
        try
            set position of window 1 to {120, 80}
            set size of window 1 to {1280, 800}
        end try
    end tell
end tell
APPLESCRIPT
    ok "window positioned at (120, 80) size 1280×800 (best-effort)"
    note "if nothing happened, grant System Events accessibility permission"
    note "(System Settings → Privacy & Security → Accessibility)"
else
    step "Step 3 — window positioning (skipped on non-macOS)"
fi

# === Step 4 — recording instructions =======================================

step "Step 4 — recording instructions"

cat <<EOF

${BOLD}Open your screen recorder${RESET} (QuickTime ⇧⌘5 → "Record Selected
Portion", or OBS, or Loom).

Then click through this sequence — pause 2-3 seconds after each
hover so the popup is fully visible on the recording:

  ${BOLD}1.${RESET} ${YELLOW}Wait 2-3s${RESET} for the LSP to attach. Two things appear:

     a) ${BOLD}Inlay hints${RESET} (v0.6.12+) — faint ${CYAN}@user_input${RESET}
        annotations drawn next to ${BOLD}\`user_id\`${RESET} on line 11
        (binding) AND on line 13 (reference inside the f-string).
        ${DIM}This is the visceral moment — provenance is a thing
        you can see drawn on top of your Python, not an abstract
        property of the language.${RESET}

     b) Red squiggle on ${RED}cur.execute(...)${RESET}, line 13.
        Problems tab badge increments to "1".

  ${BOLD}2.${RESET} Hover on ${BOLD}\`request.args\`${RESET} (line 11, around col 18).
     → "${CYAN}**\`request.args\`** — tainted multi-key bag.${RESET}"

  ${BOLD}3.${RESET} Hover on ${BOLD}\`user_id\`${RESET} inside the f-string (line 13, around col 49).
     → "${CYAN}\`user_id\`: \`String @user_input\`${RESET}"
     → "${CYAN}Last assigned at line 11 via \`request.args[...]\`.${RESET}"

  ${BOLD}4.${RESET} Hover on ${BOLD}\`cur.execute\`${RESET} (line 13, col 8).
     → "${CYAN}**Sink (HC-005)** — requires \`@sql_safe\`.${RESET}"

  ${BOLD}5.${RESET} Open the Problems panel (${BOLD}⇧⌘M${RESET} on macOS, ${BOLD}Ctrl+Shift+M${RESET} elsewhere).
     The HC-005 entry shows the source → sink flow narrative.

  ${BOLD}6.${RESET} ${BOLD}Quick-fix${RESET}: with the cursor on the squiggled line,
     press ${BOLD}⌘.${RESET} (macOS) / ${BOLD}Ctrl+.${RESET} (elsewhere). The
     "${CYAN}heatcheck (HC-005): apply auto-fix${RESET}" lightbulb appears.
     Press Enter to apply — the f-string converts to parameterized SQL.
     ${DIM}Notice: after the fix, the @user_input inlay hints stay
     (the variable is still tainted), but the squiggle disappears
     because the value now flows to the parameters slot, not the
     SQL string itself.${RESET}

  ${BOLD}7.${RESET} (Optional) Switch to a terminal pane (${BOLD}⌃ \`${RESET}) and run:
     ${DIM}\$${RESET} ${BOLD}$HEATCHECK --fix $DEMO${RESET}
     → unified-diff preview of the same parameterized fix.

${GREEN}When you're done, stop the recording and ⌘Q the demo VS Code window.${RESET}
${DIM}The .vscode/settings.json this script created is gitignored —
it's a per-machine staging artifact. Re-run this script anytime to
regenerate it (it overwrites without prompting).${RESET}

EOF
