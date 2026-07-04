#!/usr/bin/env python3
"""Print a concise maintainer-facing summary from proof.json."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from validate_proof import validate_contract, validate_proof


DEMO_DIR = Path(__file__).resolve().parent
PROOF_PATH = DEMO_DIR / "heat_boundary" / "proof.json"


def require_string(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if not isinstance(value, str):
        raise SystemExit(f"proof field {key!r} is missing or not a string")
    return value


def main() -> None:
    validate_contract()
    validate_proof(PROOF_PATH)
    proof = json.loads(PROOF_PATH.read_text(encoding="utf-8"))
    if not isinstance(proof, dict):
        raise SystemExit("proof.json must be a JSON object")

    print("Heat + PydanticAI boundary proof")
    print("--------------------------------")
    print(f"target: {require_string(proof, 'target')}")
    print(f"unsafe boundary: {require_string(proof, 'bad_verdict')}")
    print(f"repaired boundary: {require_string(proof, 'fixed_verdict')}")
    print(f"diagnostic: {require_string(proof, 'diagnostic')}")
    flows = proof.get("flows")
    if isinstance(flows, list):
        print()
        print("flows:")
        for flow in flows:
            if not isinstance(flow, dict):
                continue
            label = require_string(flow, "label")
            verdict = require_string(flow, "bad_verdict")
            fixed = flow.get("fixed_verdict")
            suffix = f", fixed={fixed}" if isinstance(fixed, str) else ""
            print(f"- {label}: {verdict}{suffix}")
    print()
    print("claim: one PydanticAI tool boundary can reject unsafe egress before")
    print("the unsafe binary is emitted, while the repaired flow still builds.")


if __name__ == "__main__":
    main()
