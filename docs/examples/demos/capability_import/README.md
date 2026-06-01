# Import Capability Demo

This demo shows Heat's import guard: adding a dependency does not give that
dependency unlimited network access.

The app grants the `payments` dependency one network destination:
`api.stripe.com`. A later dependency release keeps the same `charge()` API, but
adds a hidden call to `evil.example`. In Python, that import would run with the
process's normal network authority. Heat checks the imported code against the
grant and refuses the build before it can ship.

Run:

```bash
heatc check examples/demos/capability_import/refused/app.heat
heatc check examples/demos/capability_import/clean/app.heat
```
