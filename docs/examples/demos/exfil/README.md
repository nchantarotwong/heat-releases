# Exfiltration Demo

This directory is the demo fixture for sensitive-data exfiltration:
values that should not leave the process are sent to network egress or
logs. The Python files are comparison inputs for Semgrep / CodeQL. The
Heat files are the same shapes expressed with provenance contracts.

The checked-in demo page captures the Heat output directly. The Semgrep and
CodeQL columns below are comparison expectations for common/default
tooling unless otherwise noted; use the included Python fixtures to
reproduce or replace those columns with pinned tool output.

## Matrix

| Flow | Semgrep | CodeQL | Heat |
| --- | --- | --- | --- |
| env API key -> `requests.post` | expected clean | expected clean | captured: refuses `NL-0500` |
| PAN from request -> `requests.post` | expected clean | expected clean | captured: refuses `NL-PCI-3.4` |
| secret -> `requests.post` over `http` | included demo rules: hygiene-only | expected clean | captured: refuses `NL-OBL-001` |
| secret -> log calibration | included demo rules: flags | commonly flags | captured: refuses `NL-OBL-001` |

## Run Heat Checks

```bash
heatc check examples/demos/exfil/heat/env_api_key_to_http_body.heat
heatc check examples/demos/exfil/heat/pan_request_to_http_body.heat
heatc check examples/demos/exfil/heat/secret_to_http_body.heat
heatc check examples/demos/exfil/heat/secret_to_log_calibration.heat
```

The first row uses Heat's current `env(key:) -> String @user_input`
boundary. Heat refuses because `http_post` requires `@audit_safe` for
the body. The `secret` rows use Heat's built-in `@secret` source tag via
`secret_env(key:)`, plus a project-local refusal contract:

```heat
obligation NoSecretDisclosure:
    forbid @secret -> @audit_safe
```

That keeps this demo honest while letting the project decide whether secrets
must be redacted, replaced by a digest, or handled through a service-local
capability before disclosure.

## Optional Semgrep Check

The included Semgrep config is intentionally tiny: it demonstrates the
calibration log catch and the HTTP hygiene warning, not semantic
exfiltration tracking.

```bash
semgrep --config examples/demos/exfil/semgrep/rules.yml examples/demos/exfil/python
```
