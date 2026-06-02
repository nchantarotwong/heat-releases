# Compliance Evidence Workers Demo

An auditor asks for repeatable evidence:

- SOC 2: prove production cloud logging and database backups are enabled.
- PCI: prove payment evidence never exports the full card number.
- HIPAA: prove patient encounter evidence is de-identified before audit logging.
- GDPR: prove user evidence is redacted before it leaves the worker.

The unsafe worker models the LLM's first draft: it collects the right facts, then
tries to put raw card, PHI, and PII values into the audit channel. Heat refuses
those flows at compile time with framework-named diagnostics.

The fixed worker keeps the same business workflow but emits only reviewed
metadata and sanitized audit evidence. Building it with `--emit-audit-manifest`
produces the artifact a reviewer can tie back to the source and binary.

Run:

```bash
heatc check examples/demos/compliance_evidence_workers/unsafe_worker.heat
heatc build examples/demos/compliance_evidence_workers/fixed_worker.heat -o /tmp/compliance_worker --emit-audit-manifest
timeout 10s /tmp/compliance_worker
cat /tmp/compliance_worker.audit.json
```
