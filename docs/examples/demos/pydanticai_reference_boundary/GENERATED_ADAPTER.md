# Generated Adapter Shape

The demo adapter is intentionally small:

```python
allowed, reason = boundary.check_export_case_file(path=path, content=content)
```

In this repository, `boundary_adapter.py` validates `proof.json` and mirrors
the checked boundary's allow/refuse decision so the demo has no packaging or
runtime dependency beyond `heatc`.

In a production integration, this file is the generated artifact. The generated
adapter would:

- call the Heat-built boundary binary/library for the tool class
- pass named arguments matching the PydanticAI tool schema
- return a structured allow/refuse result
- include the exact `heatc` diagnostic when refusing
- fail closed if the boundary artifact or proof metadata is missing

The important adoption point is stable across both versions: PydanticAI tools
call one boundary object at the egress edge; Heat owns the sink proof.
