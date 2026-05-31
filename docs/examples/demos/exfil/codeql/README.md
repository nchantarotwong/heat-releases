# CodeQL Notes

These Python fixtures are intended for the default CodeQL Python security
suite as a comparison input. The deck captures Heat output directly; this
file documents expected CodeQL behavior so the comparison can be replaced
with pinned CodeQL output later.

Expected behavior for the demo table:

- `secret_to_log_calibration.py`: commonly flagged by clear-text logging
  style rules.
- `env_api_key_to_requests_post.py`: typically clean without a custom source
  and sink model connecting environment secrets to `requests.post(data=...)`.
- `pan_request_to_requests_post.py`: typically clean without a custom Flask
  request-field model that knows `card_number` is PAN.
- `secret_to_requests_post_http.py`: may flag the plaintext HTTP hygiene
  issue depending on the enabled suite, but not the semantic secret
  exfiltration without a custom model.
