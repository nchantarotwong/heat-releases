# MCP Server Builder V1 Demo

This directory shows the V1 wedge: tool response contracts become compile-time
policy and audit-manifest evidence.

Commands:

```bash
heatc check examples/demos/mcp_server_builder/unsafe_public_ticket_tool.heat
heatc build examples/demos/mcp_server_builder/safe_public_ticket_tool.heat -o /tmp/mcp_safe --emit-audit-manifest
heatc build examples/demos/mcp_server_builder/customer_data_ticket_tool.heat -o /tmp/mcp_customer --emit-audit-manifest
```

Expected behavior:

- `unsafe_public_ticket_tool.heat` refuses with `NL-MCP-OUT-NL-GDPR-32`.
- The safe examples build and write `<out>.audit.json`.
- The audit manifest includes `tool_output_contracts`, so a buyer can inspect
  which tools return `@public` versus `@customer_data`.
- `usage_event_schema.json` is the billing-later event contract. V1 does not
  meter or invoice, but the stable `tool` and `output_contract` fields line up
  with the audit manifest.
