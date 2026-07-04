#!/usr/bin/env python3
"""Validate the PydanticAI boundary proof and contract artifacts."""

from __future__ import annotations

import json
import sys
import tempfile
from dataclasses import dataclass
from json import JSONDecodeError
from pathlib import Path
from typing import Any


DEMO_DIR = Path(__file__).resolve().parent
PROOF_PATH = DEMO_DIR / "heat_boundary" / "proof.json"
CONTRACT_PATH = DEMO_DIR / "boundary_contract.json"

EXPECTED_TARGET = "pydantic/pydantic-ai"
EXPECTED_DIAGNOSTIC = "NL-OBL-001"
EXPECTED_GENERATED_BY = "heatc via capture.sh"
PROOF_KEYS = {
    "generated_by",
    "target",
    "expected_diagnostic",
    "bad_verdict",
    "diagnostic",
    "fixed_verdict",
    "flows",
}
CONTRACT_KEYS = {"target", "boundary", "proof_path", "tools"}
TOOL_KEYS = {"name", "args", "sink", "expected_refusal", "generated_adapter"}
ARG_KEYS = {"name", "type", "source_tag"}
SINK_KEYS = {"class", "function", "required_tag"}
REFUSAL_KEYS = {"flow_id", "diagnostic"}
ADAPTER_KEYS = {"method", "allow_when", "fail_closed"}

EXPECTED_FLOWS = {
    "filesystem_boundary": {
        "bad_verdict": "REFUSED",
        "diagnostic": "NL-OBL-001",
        "fixed_verdict": "BUILT",
    },
    "missed_helper": {
        "bad_verdict": "REFUSED",
        "diagnostic": "NL-OBL-001",
    },
    "webhook_egress": {
        "bad_verdict": "REFUSED",
        "diagnostic": "NL-0500",
        "fixed_verdict": "BUILT",
    },
}

EXPECTED_TOOLS = {
    "export_case_file": {
        "args": {"path": "@user_input", "content": "@user_input"},
        "sink_class": "filesystem",
        "sink_function": "write_file",
        "required_tag": "@path_safe",
        "flow_id": "filesystem_boundary",
        "diagnostic": "NL-OBL-001",
        "method": "check_export_case_file",
    },
    "notify_webhook": {
        "args": {"url": "@user_input", "body": "@user_input"},
        "sink_class": "network",
        "sink_function": "http_post",
        "required_tag": "@audit_safe",
        "flow_id": "webhook_egress",
        "diagnostic": "NL-0500",
        "method": "check_notify_webhook",
    },
}


@dataclass(frozen=True)
class BoundaryProof:
    diagnostic: str
    fixed_verdict: str


def load_json_object(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"missing {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise SystemExit(f"{path} is malformed JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{path} must be a JSON object")
    return data


def require_string(data: dict[str, Any], key: str, *, context: str) -> str:
    value = data.get(key)
    if not isinstance(value, str):
        raise SystemExit(f"{context} field {key!r} is missing or not a string")
    return value


def require_dict(data: dict[str, Any], key: str, *, context: str) -> dict[str, Any]:
    value = data.get(key)
    if not isinstance(value, dict):
        raise SystemExit(f"{context} field {key!r} is missing or not an object")
    return value


def require_list(data: dict[str, Any], key: str, *, context: str) -> list[Any]:
    value = data.get(key)
    if not isinstance(value, list):
        raise SystemExit(f"{context} field {key!r} is missing or not a list")
    return value


def require_bool(data: dict[str, Any], key: str, *, context: str) -> bool:
    value = data.get(key)
    if not isinstance(value, bool):
        raise SystemExit(f"{context} field {key!r} is missing or not a bool")
    return value


def require_exact_keys(data: dict[str, Any], expected_keys: set[str], *, context: str) -> None:
    if set(data) != expected_keys:
        raise SystemExit(
            f"{context} keys drifted: expected {sorted(expected_keys)}, got {sorted(data)}"
        )


def validate_proof(proof_path: Path = PROOF_PATH) -> BoundaryProof:
    proof = load_json_object(proof_path)
    context = proof_path.name

    require_exact_keys(proof, PROOF_KEYS, context="proof top-level")
    if require_string(proof, "generated_by", context=context) != EXPECTED_GENERATED_BY:
        raise SystemExit("proof generator drifted")
    if require_string(proof, "target", context=context) != EXPECTED_TARGET:
        raise SystemExit("proof target does not match this demo")
    if require_string(proof, "expected_diagnostic", context=context) != EXPECTED_DIAGNOSTIC:
        raise SystemExit("proof expected diagnostic does not match this demo")
    if require_string(proof, "bad_verdict", context=context) != "REFUSED":
        raise SystemExit("proof did not refuse the unsafe boundary")
    fixed_verdict = require_string(proof, "fixed_verdict", context=context)
    if fixed_verdict != "BUILT":
        raise SystemExit("proof did not build the repaired boundary")
    diagnostic = require_string(proof, "diagnostic", context=context)
    if EXPECTED_DIAGNOSTIC not in diagnostic:
        raise SystemExit("proof did not contain the expected obligation diagnostic")

    flows = require_list(proof, "flows", context=context)
    by_id: dict[str, dict[str, Any]] = {}
    for index, flow in enumerate(flows):
        if not isinstance(flow, dict):
            raise SystemExit(f"proof flow #{index} is not an object")
        flow_id = require_string(flow, "id", context=f"proof flow #{index}")
        if flow_id in by_id:
            raise SystemExit(f"duplicate proof flow id: {flow_id}")
        by_id[flow_id] = flow

    if set(by_id) != set(EXPECTED_FLOWS):
        raise SystemExit(
            f"proof flow ids drifted: expected {sorted(EXPECTED_FLOWS)}, got {sorted(by_id)}"
        )

    for flow_id, expected in EXPECTED_FLOWS.items():
        flow = by_id[flow_id]
        expected_keys = {"id", "label", "bad_verdict", "diagnostic"}
        if "fixed_verdict" in expected:
            expected_keys.add("fixed_verdict")
        if set(flow) != expected_keys:
            raise SystemExit(f"{flow_id} keys drifted: {sorted(flow)}")
        if require_string(flow, "label", context=flow_id).strip() == "":
            raise SystemExit(f"{flow_id} label is empty")
        if require_string(flow, "bad_verdict", context=flow_id) != expected["bad_verdict"]:
            raise SystemExit(f"{flow_id} bad verdict drifted")
        flow_diag = require_string(flow, "diagnostic", context=flow_id)
        if expected["diagnostic"] not in flow_diag:
            raise SystemExit(f"{flow_id} diagnostic drifted")
        expected_fixed = expected.get("fixed_verdict")
        if expected_fixed is not None:
            if require_string(flow, "fixed_verdict", context=flow_id) != expected_fixed:
                raise SystemExit(f"{flow_id} fixed verdict drifted")

    return BoundaryProof(diagnostic=diagnostic, fixed_verdict=fixed_verdict)


def validate_contract(contract_path: Path = CONTRACT_PATH) -> None:
    contract = load_json_object(contract_path)
    context = contract_path.name

    require_exact_keys(contract, CONTRACT_KEYS, context="contract top-level")
    if require_string(contract, "target", context=context) != EXPECTED_TARGET:
        raise SystemExit("contract target does not match this demo")
    if require_string(contract, "boundary", context=context) != "heat_boundary":
        raise SystemExit("contract boundary name drifted")
    if require_string(contract, "proof_path", context=context) != "heat_boundary/proof.json":
        raise SystemExit("contract proof path drifted")

    tools = require_list(contract, "tools", context=context)
    by_name: dict[str, dict[str, Any]] = {}
    for index, tool in enumerate(tools):
        if not isinstance(tool, dict):
            raise SystemExit(f"contract tool #{index} is not an object")
        name = require_string(tool, "name", context=f"contract tool #{index}")
        if name in by_name:
            raise SystemExit(f"duplicate contract tool name: {name}")
        by_name[name] = tool

    if set(by_name) != set(EXPECTED_TOOLS):
        raise SystemExit(
            f"contract tools drifted: expected {sorted(EXPECTED_TOOLS)}, got {sorted(by_name)}"
        )

    for name, expected in EXPECTED_TOOLS.items():
        tool = by_name[name]
        require_exact_keys(tool, TOOL_KEYS, context=f"{name} tool")
        arg_tags: dict[str, str] = {}
        for arg in require_list(tool, "args", context=name):
            if not isinstance(arg, dict):
                raise SystemExit(f"{name} arg entry is not an object")
            require_exact_keys(arg, ARG_KEYS, context=f"{name} arg")
            arg_tags[require_string(arg, "name", context=f"{name} arg")] = require_string(
                arg, "source_tag", context=f"{name} arg"
            )
            if require_string(arg, "type", context=f"{name} arg") != "str":
                raise SystemExit(f"{name} arg type drifted")
        if arg_tags != expected["args"]:
            raise SystemExit(f"{name} arg tags drifted")

        sink = require_dict(tool, "sink", context=name)
        require_exact_keys(sink, SINK_KEYS, context=f"{name} sink")
        if require_string(sink, "class", context=f"{name} sink") != expected["sink_class"]:
            raise SystemExit(f"{name} sink class drifted")
        if require_string(sink, "function", context=f"{name} sink") != expected["sink_function"]:
            raise SystemExit(f"{name} sink function drifted")
        if require_string(sink, "required_tag", context=f"{name} sink") != expected["required_tag"]:
            raise SystemExit(f"{name} sink tag drifted")

        refusal = require_dict(tool, "expected_refusal", context=name)
        require_exact_keys(refusal, REFUSAL_KEYS, context=f"{name} refusal")
        if require_string(refusal, "flow_id", context=f"{name} refusal") != expected["flow_id"]:
            raise SystemExit(f"{name} refusal flow drifted")
        if require_string(refusal, "diagnostic", context=f"{name} refusal") != expected["diagnostic"]:
            raise SystemExit(f"{name} refusal diagnostic drifted")

        adapter = require_dict(tool, "generated_adapter", context=name)
        require_exact_keys(adapter, ADAPTER_KEYS, context=f"{name} adapter")
        if require_string(adapter, "method", context=f"{name} adapter") != expected["method"]:
            raise SystemExit(f"{name} adapter method drifted")
        if not require_bool(adapter, "fail_closed", context=f"{name} adapter"):
            raise SystemExit(f"{name} adapter must fail closed")
        require_string(adapter, "allow_when", context=f"{name} adapter")


def write_contract_case(contract: dict[str, Any], temp_dir: Path) -> Path:
    path = temp_dir / "boundary_contract.json"
    path.write_text(json.dumps(contract, indent=2, sort_keys=True), encoding="utf-8")
    return path


def expect_contract_failure(name: str, contract: dict[str, Any], expected_text: str) -> None:
    with tempfile.TemporaryDirectory() as temp_name:
        contract_path = write_contract_case(contract, Path(temp_name))
        try:
            validate_contract(contract_path)
        except SystemExit as exc:
            message = str(exc)
            if expected_text not in message:
                raise SystemExit(
                    f"self-test {name} failed with unexpected message: {message}"
                ) from exc
            return
    raise SystemExit(f"self-test {name} unexpectedly passed")


def run_self_tests() -> None:
    contract = load_json_object(CONTRACT_PATH)

    with_top_level_extra = dict(contract)
    with_top_level_extra["notes"] = "hand edited"
    expect_contract_failure(
        "top-level extra key",
        with_top_level_extra,
        "contract top-level keys drifted",
    )

    with_tool_extra = json.loads(json.dumps(contract))
    with_tool_extra["tools"][0]["python_guard"] = "decorator"
    expect_contract_failure(
        "tool extra key",
        with_tool_extra,
        "export_case_file tool keys drifted",
    )

    with_arg_extra = json.loads(json.dumps(contract))
    with_arg_extra["tools"][0]["args"][0]["optional"] = False
    expect_contract_failure(
        "arg extra key",
        with_arg_extra,
        "export_case_file arg keys drifted",
    )

    with_sink_extra = json.loads(json.dumps(contract))
    with_sink_extra["tools"][0]["sink"]["runtime_hook"] = "python"
    expect_contract_failure(
        "sink extra key",
        with_sink_extra,
        "export_case_file sink keys drifted",
    )

    with_refusal_extra = json.loads(json.dumps(contract))
    with_refusal_extra["tools"][0]["expected_refusal"]["source"] = "manual"
    expect_contract_failure(
        "refusal extra key",
        with_refusal_extra,
        "export_case_file refusal keys drifted",
    )

    with_adapter_extra = json.loads(json.dumps(contract))
    with_adapter_extra["tools"][0]["generated_adapter"]["fallback"] = "allow"
    expect_contract_failure(
        "adapter extra key",
        with_adapter_extra,
        "export_case_file adapter keys drifted",
    )

    print("proof validator self-tests passed")


def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        run_self_tests()
        return
    if len(sys.argv) != 1:
        raise SystemExit("usage: validate_proof.py [--self-test]")
    validate_contract()
    validate_proof()
    print("proof and boundary contract are valid")


if __name__ == "__main__":
    main()
