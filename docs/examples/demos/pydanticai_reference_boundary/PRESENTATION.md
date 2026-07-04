# Presentation Capture

This demo is meant to be shown in two panes:

1. Browser: `examples/demos/pydanticai_reference_boundary/index.html`
2. Terminal: `bash examples/demos/pydanticai_reference_boundary/run_demo.sh`

The committed `terminal_capture.txt` is a stable transcript from the runner.
Use it for PR descriptions, emails, or slides when a live run would distract
from the point.

## Talk Track

1. Start with the current Python-only behavior: the model-shaped tool call
   writes `/tmp/heat_pydanticai_public_case.txt`.
2. Point out the helper bypass: a future helper can forget the Python guard
   convention and still write the file.
3. Show the Heat-mediated path: the same egress class is blocked with a real
   `NL-OBL-001` diagnostic.
4. Show the PydanticAI-shaped path: `TestModel` invokes the registered
   `@agent.tool`, and the tool returns the Heat refusal instead of writing.
5. Show repaired flow: laundered path builds and writes under
   `/tmp/heat_pydanticai_safe_exports/`.
6. Show second sink class: `proof.json` also records webhook URL/body refusal
   at `http_post(... @audit_safe)`.

## One-Sentence Close

PydanticAI keeps the agent ergonomics; Heat makes the high-risk egress boundary
fail closed when a tool, helper, or webhook path forgets the policy.
