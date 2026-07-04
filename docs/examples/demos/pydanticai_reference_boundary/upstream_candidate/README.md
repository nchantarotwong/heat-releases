# PydanticAI Upstream Candidate

These files are laid out exactly as an optional PydanticAI example could be
proposed upstream.

Copy or patch the contents of this directory into the root of a
`pydantic/pydantic-ai` checkout:

```text
examples/pydantic_ai_examples/heat_boundary_bank_support.py
examples/pydantic_ai_examples/heat_boundary/
  bank_support_boundary.heat
  bank_support_boundary_fixed.heat
  bank_support_helper_bypass.heat
  bank_support_webhook.heat
  bank_support_webhook_fixed.heat
  capture.sh
  proof.json
examples/pydantic_ai_examples/boundary_contract.json
examples/pydantic_ai_examples/validate_proof.py
```

The example is intentionally optional. It does not change PydanticAI core and
does not make Heat a dependency for normal PydanticAI users.
