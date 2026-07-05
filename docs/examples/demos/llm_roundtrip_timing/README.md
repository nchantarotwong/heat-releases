# LLM Roundtrip Timing

This demo captures one real AI-authored Heat loop:

- Claude Opus 4.8 via Claude Code CLI took `76.94s` for the authoring round trip.
- The generated Heat program compiled in `0.05s`.
- The compiled binary ran in `<0.01s`.
- Manual edits to the Heat program: `0`.

The point is not that Claude is slow. LLM response time is live, variable, and
not a guaranteed SLA. Heat compile/run time is local and deterministic.

The point is to need fewer model round trips.

## Files

| File | Role |
| --- | --- |
| `index.html` | Browser-ready visual for the timing comparison. |
| `social_card.svg` | Red/green graphic for a short LinkedIn post. |
| `social_card.png` | Rasterized share card for LinkedIn upload. |
| `prompt.txt` | Prompt sent to Claude Code CLI. |
| `claude_response_raw.txt` | Raw Claude Code CLI response, including the prose preface. |
| `claude_response.heat` | Generated Heat program extracted from the response and compiled unchanged. |
| `capture.txt` | Human-readable timing capture. |
| `results.json` | Machine-readable timing facts used by the page. |

## Reproduce The Compile/Run Path

From the repo root:

```bash
bash bootstrap/scripts/heatc_rebuild.sh
timeout 10s /tmp/heatc examples/demos/llm_roundtrip_timing/claude_response.heat -o /tmp/heat_llm_roundtrip_demo
timeout 10s /tmp/heat_llm_roundtrip_demo
```

Use `/usr/bin/time -p` around the compile and run commands to refresh the
numbers. The Claude timing is intentionally treated as a capture, not a
benchmark, because client, network, provider, and model latency are outside
Heat's control.

## LinkedIn Draft

Measured a real AI-authored Heat loop.

Claude Opus 4.8 via Claude Code CLI:
76.94s round trip

Generated Heat program:
0.05s compile
<0.01s run

Manual edits:
0

That is the distinction Heat is built around.

The LLM authoring step is live, variable, and not a guaranteed SLA.
The Heat compile/run step is local, deterministic, and boring.

The goal is not to make the model faster.
The goal is to need fewer model round trips.
