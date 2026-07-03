# Heat AI Tool Gateway — the reference boundary demo

**One small compiler-checked boundary mediates every action your agent takes.**
Unsafe ones — injected arguments, out-of-order calls, policy violations — are
refused *before the binary is built*, each with a real compiler diagnostic as
proof. Your app doesn't move.

One claim, made visual and defensible: **Heat owns the high-consequence egress
edge, not the whole app.**

## What's here

| File | Role |
| --- | --- |
| `index.html` | The viewer-facing visual. Animated data flow; unsafe tool calls bounce off the membrane; the proof terminal shows the **real** `heatc` diagnostic. Opens offline via `file://`. |
| `01_injected_tool_arg.heat` / `_fixed` | Prompt-injected tool argument → SQL sink. Refused `NL-0500`; fix launders with `escape_sql`. |
| `02_tool_call_order.heat` / `_fixed` | Agent calls `charge()` before `authorize()`. Refused `NL-PROTO-1`; fix orders the calls. |
| `03_policy_obligation.heat` / `_fixed` | Team's own egress policy: `@user_input` must not reach the filesystem. Refused `NL-OBL-001`; fix launders with `escape_path`. |
| `capture.sh` | Compiles every flow with `heatc` and writes `proof.json`. |
| `proof.json` | The captured, real compiler output the visual embeds. Regenerable — nothing is mocked. |

## Three refusal classes, all real

Each maps to an enforcement Heat does at compile time today:

- **Provenance** (`NL-0500`) — injectable input can't reach a sensitive sink.
- **Protocol** (`NL-PROTO-1`) — tools are called in a legal order.
- **Obligation** (`NL-OBL-001`) — a project-declared egress policy is a compile error.

## Reproduce the proof

```bash
# from repo root, ensure a fresh compiler (see CLAUDE.md if it refuses as stale)
bash bootstrap/scripts/heatc_rebuild.sh
bash examples/demos/reference_boundary/capture.sh   # rewrites proof.json
open examples/demos/reference_boundary/index.html
```

Every "bounce" in the animation is a line `capture.sh` pulled straight from
`heatc`. Every "pass" is a `_fixed` flow that actually compiles.

## Where this lives

The boundary sits at the **egress edge of an agent framework** — the point
where model decisions become real actions. It's a compile-time reference
monitor: every outbound tool call is mediated, unsafe ones refused before the
binary is built. The same engine generalizes to PCI / egress (raw PAN or
`@secret` provably can't reach a webhook or log) by swapping the provenance
tags — one boundary, many blast radii.
