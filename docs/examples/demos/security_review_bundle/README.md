# Security Review Bundle Demo

This is the buyer-facing security review workflow in one command.

It ties together four things a security reviewer cares about:

- unsafe AI-draft flows are refused before build
- reviewed MCP tool authority is generated as a review bundle
- runtime calls produce usage events
- usage events link back to the exact reviewed build hashes

Run:

```bash
bash examples/demos/security_review_bundle/run_demo.sh
```

Optional:

```bash
HEATC=/tmp/heatc bash examples/demos/security_review_bundle/run_demo.sh
```

The runner writes:

```text
examples/demos/security_review_bundle/out/security-review.html
```

That HTML is intentionally review-oriented: tool surface, effects,
capabilities, output contracts, refusal evidence, artifact hashes, and runtime
event linkage.

Use this when a security-minded reviewer asks, "what authority does this AI
tool have, and how do I know the running server is the reviewed one?" The demo
does not ask the reviewer to trust a slide: it generates the review bundle,
executes a live call, and shows the usage event hashes that join the runtime
call back to the reviewed artifact set.
