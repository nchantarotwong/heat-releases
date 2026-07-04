# PydanticAI Reference Boundary

This is the adopter-shaped version of the Heat reference-boundary demo.

The point is not to port PydanticAI to Heat. The point is to show where an
adopter would use Heat: the external-action boundary where a model-selected
tool call becomes a filesystem, network, database, payment, email, or logging
effect.

## Shape

The Python files model a small PydanticAI-style bank support agent. The agent
receives untrusted customer/ticket text, selects a tool, and crosses an egress
boundary.

| File | Role |
| --- | --- |
| `index.html` | Maintainer-facing visual: what changes, what it buys, and the real compiler proof. |
| `UPSTREAM_PR_NOTE.md` | Draft maintainer-facing PR note and scope guard. |
| `PRESENTATION.md` / `terminal_capture.txt` | Stable demo talk track and terminal transcript. |
| `screenshots/index.png` / `screenshots/terminal_capture.png` | Committed visual captures of the page and terminal proof. |
| `capture_visuals.py` | Regenerates the committed screenshots with Playwright. |
| `GENERATED_ADAPTER.md` | Explains the demo adapter vs a production generated boundary adapter. |
| `boundary_contract.json` | Tiny reusable-boundary contract: tools, args, sinks, expected tags, and adapter behavior. |
| `validate_proof.py` | Strict proof/contract validator for stable flow IDs, diagnostics, and fixed verdicts. |
| `upstream_candidate/` | PydanticAI repo-shaped file layout for a potential upstream example. |
| `make_upstream_patch.sh` / `pydanticai_heat_boundary_example.patch` | Generates and stores an applyable patch against a sibling `pydantic-ai` checkout. |
| `check_upstream_patch.sh` | Regenerates the upstream patch to a temp file and fails if the committed patch drifted. |
| `verify_demo.sh` | Runs syntax checks, proof validation, patch freshness, and the end-to-end demo. |
| `run_demo.sh` | One command: capture Heat proof, assert before writes, assert after does not write. |
| `before_bank_support.py` | Deterministic "before" run: model-shaped tool args reach a file export tool directly. |
| `after_bank_support.py` | Deterministic "after" run: the app consults the Heat proof before allowing the same egress class. |
| `pydanticai_bank_support.py` | PydanticAI `Agent` / `RunContext` / `@tool` registration when `pydantic_ai` is installed, with a dependency-free static tool-call path for this repo. |
| `summarize_proof.py` | Prints a concise maintainer-facing proof summary from `proof.json`. |
| `heat_boundary/bank_support_boundary.heat` | Unsafe boundary: `@user_input` reaches a filesystem sink and is refused. |
| `heat_boundary/bank_support_helper_bypass.heat` | Missed-helper proof: a helper forgets the Python guard convention, but the Heat sink still refuses. |
| `heat_boundary/bank_support_boundary_fixed.heat` | Repaired boundary: path is laundered before reaching the sink. |
| `heat_boundary/bank_support_webhook.heat` / `_fixed` | Second sink class: model-controlled webhook URL/body reaching `http_post(... @audit_safe)`. |
| `heat_boundary/capture.sh` | Captures real `heatc` output into `proof.json`. |

## Demo Line

We changed the egress edge, not the agent.

## Reproduce

From the repo root:

```bash
bash bootstrap/scripts/heatc_rebuild.sh
bash examples/demos/pydanticai_reference_boundary/verify_demo.sh
bash examples/demos/pydanticai_reference_boundary/run_demo.sh
python3 examples/demos/pydanticai_reference_boundary/pydanticai_bank_support.py
```

The before script demonstrates the current class of failure: a model-shaped
tool call reaches the external-action tool. The Heat boundary demonstrates the
compile-time refusal an adopter gets by routing that egress edge through Heat.
The runner removes the attack output between phases and fails if the after
phase recreates it.

The proof covers three bad paths:

- model-controlled file export reaches `write_file`
- a future helper bypasses the Python guard convention
- model-controlled webhook URL/body reaches `http_post`

If `pydantic_ai` is installed, this registers the same guarded tool using the
public PydanticAI API. It can also run PydanticAI's `TestModel` through the
registered tool without API keys:

```bash
python3 examples/demos/pydanticai_reference_boundary/pydanticai_bank_support.py --register-agent
python3 examples/demos/pydanticai_reference_boundary/pydanticai_bank_support.py --run-agent
python3 examples/demos/pydanticai_reference_boundary/pydanticai_bank_support.py --repaired
```

## Upstream Pitch

This should be proposed as an optional example or cookbook entry, not as a
PydanticAI core dependency.

Cheap value for maintainers:

- no framework rewrite
- no required runtime dependency for normal users
- one high-risk tool boundary made explicit
- real compiler refusal attached as proof
- two sink classes: filesystem and network/webhook egress
- missed-helper proof for why this is stronger than a Python convention
- a clear place for teams to encode local egress policy

## Why This Is Not Just A Python Guard

Python can add a decorator, a callback, or a runtime policy function. That is
useful, but it only works on paths that remember to call it.

The Heat value is different: inside the boundary, the policy is attached to the
sink type. Any new function that tries to pass `@user_input` into a filesystem
path fails the build, even when the author forgot the guard. The failure is not
"a test happened to cover the bad case." It is "the unsafe binary was never
emitted."

That is the adopter-shaped wedge:

```text
Python framework: validates agent structure and orchestrates tools.
Heat boundary: proves untrusted/model-controlled values cannot reach selected sinks.
```

Suggested upstream title:

```text
examples: add optional Heat reference-boundary tool egress demo
```

Generate the attachable upstream patch from this repo:

```bash
bash examples/demos/pydanticai_reference_boundary/make_upstream_patch.sh
bash examples/demos/pydanticai_reference_boundary/check_upstream_patch.sh
git -C ../pydantic-ai apply --check \
  ../Heat/examples/demos/pydanticai_reference_boundary/pydanticai_heat_boundary_example.patch
```
