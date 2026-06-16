#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
import os
import select
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


IDENTITY_META = {
    "heat_tenant_id": "tenant-demo",
    "heat_user_id": "user-demo",
    "heat_agent_id": "agent-demo",
}


def run(cmd: list[str], *, cwd: Path, timeout: float = 20.0, expect_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, timeout=timeout)
    if expect_success and result.returncode != 0:
        raise AssertionError(f"command failed: {' '.join(cmd)}\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}")
    if not expect_success and result.returncode == 0:
        raise AssertionError(f"command unexpectedly succeeded: {' '.join(cmd)}\nstdout:\n{result.stdout}")
    return result


def combined(result: subprocess.CompletedProcess[str]) -> str:
    return result.stdout + result.stderr


def frame(message: dict[str, object]) -> bytes:
    body = json.dumps(message, separators=(",", ":")).encode("utf-8")
    return b"Content-Length: " + str(len(body)).encode("ascii") + b"\r\n\r\n" + body


def read_exact(proc: subprocess.Popen[bytes], count: int, label: str, timeout: float = 10.0) -> bytes:
    assert proc.stdout is not None
    stdout_fd = proc.stdout.fileno()
    deadline = time.monotonic() + timeout
    chunks: list[bytes] = []
    remaining = count
    while remaining > 0:
        wait = deadline - time.monotonic()
        if wait <= 0:
            raise AssertionError(f"{label}: timed out reading server stdout")
        ready, _, _ = select.select([stdout_fd], [], [], wait)
        if not ready:
            raise AssertionError(f"{label}: timed out reading server stdout")
        chunk = os.read(stdout_fd, remaining)
        if not chunk:
            raise AssertionError(f"{label}: server closed stdout")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def read_frame(proc: subprocess.Popen[bytes], label: str) -> dict[str, object]:
    header = b""
    while b"\r\n\r\n" not in header:
        header += read_exact(proc, 1, label)
    header_text = header.decode("ascii")
    length = None
    for line in header_text.split("\r\n"):
        if line.lower().startswith("content-length:"):
            length = int(line.split(":", 1)[1].strip())
    if length is None:
        raise AssertionError(f"{label}: missing Content-Length header {header_text!r}")
    body = read_exact(proc, length, label)
    payload = json.loads(body.decode("utf-8"))
    if not isinstance(payload, dict):
        raise AssertionError(f"{label}: JSON-RPC payload is not an object {payload!r}")
    return payload


def send(proc: subprocess.Popen[bytes], message: dict[str, object]) -> None:
    assert proc.stdin is not None
    proc.stdin.write(frame(message))
    proc.stdin.flush()


def copy_demo_project(src: Path, dst: Path) -> None:
    def ignore(_dir: str, names: list[str]) -> set[str]:
        return {"generated", "mcp-usage.jsonl", "mcp-runtime.jsonl", "__pycache__"}.intersection(names)

    shutil.copytree(src, dst, ignore=ignore)


def require_contains(label: str, text: str, needles: list[str]) -> None:
    missing = [needle for needle in needles if needle not in text]
    if missing:
        raise AssertionError(f"{label}: missing {missing!r}\n{text}")


def require_dict(value: object, label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise AssertionError(f"{label}: expected object, got {value!r}")
    return value


def require_list(value: object, label: str) -> list[object]:
    if not isinstance(value, list):
        raise AssertionError(f"{label}: expected list, got {value!r}")
    return value


def assert_security_refusals(heatc: str, repo: Path, workspace: Path) -> list[dict[str, str]]:
    refusals: list[dict[str, str]] = []

    support_src = repo / "examples" / "mcp" / "support-readonly"
    unsafe = workspace / "unsafe-public-ticket"
    copy_demo_project(support_src, unsafe)
    shutil.copyfile(unsafe / "unsafe_public_ticket_tool.heat", unsafe / "server.heat")

    source_result = run([heatc, "check", str(unsafe / "server.heat")], cwd=repo, expect_success=False)
    source_out = combined(source_result)
    require_contains("MCP unsafe output source", source_out, ["NL-MCP-OUT", "allows '@public'", "carries '@customer_data'"])
    project_result = run([heatc, "mcp", "check", str(unsafe)], cwd=repo, expect_success=False)
    require_contains("MCP unsafe output project", combined(project_result), ["MCP server source does not check clean"])
    refusals.append({
        "class": "MCP output contract",
        "command": "heatc mcp check <unsafe support tool>",
        "signal": "NL-MCP-OUT",
        "meaning": "@customer_data cannot be returned as @public tool output",
    })

    cap_app = repo / "examples" / "demos" / "capability_import" / "refused" / "app.heat"
    cap_result = run([heatc, "check", str(cap_app)], cwd=repo, expect_success=False)
    require_contains("capability import", combined(cap_result), ["NL-CAP-5", "evil.example"])
    refusals.append({
        "class": "Dependency capability",
        "command": "heatc check examples/demos/capability_import/refused/app.heat",
        "signal": "NL-CAP-5",
        "meaning": "imported code cannot add an unreviewed network host",
    })

    compliance = repo / "examples" / "demos" / "compliance_evidence_workers" / "unsafe_worker.heat"
    comp_result = run([heatc, "check", str(compliance)], cwd=repo, expect_success=False)
    comp_out = combined(comp_result)
    require_contains("compliance worker", comp_out, ["NL-PCI-3.4", "NL-HIPAA-164", "NL-GDPR-32"])
    refusals.append({
        "class": "Regulated data egress",
        "command": "heatc check examples/demos/compliance_evidence_workers/unsafe_worker.heat",
        "signal": "NL-PCI-3.4 / NL-HIPAA-164 / NL-GDPR-32",
        "meaning": "PAN, PHI, and PII cannot reach audit sinks raw",
    })

    return refusals


def assert_review_artifacts(project: Path) -> tuple[str, str, dict[str, object], dict[str, object], dict[str, object]]:
    generated = project / "manifests" / "generated"
    required = [
        "tools-list.json",
        "call-dispatch.json",
        "usage-manifest.json",
        "usage-event-schema.json",
        "context-budget.json",
        "runtime-authority.json",
        "runtime-ops.json",
        "protocol-manifest.json",
        "host-config.json",
        "claude-desktop-config.json",
        "gateway-launch.json",
        "build-manifest.json",
        "review-bundle.json",
    ]
    for name in required:
        if not (generated / name).exists():
            raise AssertionError(f"missing generated review artifact: {name}")

    dispatch = require_dict(json.loads((generated / "call-dispatch.json").read_text(encoding="utf-8")), "call-dispatch.json")
    dispatch_entries = require_list(dispatch.get("dispatch"), "call-dispatch.dispatch")
    dispatch_objects = [require_dict(entry, "call-dispatch.dispatch[]") for entry in dispatch_entries]
    if [entry.get("tool") for entry in dispatch_objects] != ["get_ticket_context"]:
        raise AssertionError(f"call-dispatch exposed wrong tools: {dispatch_entries!r}")
    dispatch_entry = dispatch_objects[0]
    if dispatch_entry.get("effects") != ["io"] or dispatch_entry.get("capabilities") != ["runtime.io"]:
        raise AssertionError(f"dispatch omitted authority metadata: {dispatch_entry!r}")
    if dispatch_entry.get("outputContract") != "customer_data":
        raise AssertionError(f"dispatch omitted output contract: {dispatch_entry!r}")

    tools = require_dict(json.loads((generated / "tools-list.json").read_text(encoding="utf-8")), "tools-list.json")
    tool_entries = [require_dict(tool, "tools-list.tools[]") for tool in require_list(tools.get("tools"), "tools-list.tools")]
    if [tool.get("name") for tool in tool_entries] != ["get_ticket_context"]:
        raise AssertionError(f"tools/list exposed wrong tools: {tools!r}")

    runtime_authority = require_dict(json.loads((generated / "runtime-authority.json").read_text(encoding="utf-8")), "runtime-authority.json")
    bundle = require_dict(json.loads((generated / "review-bundle.json").read_text(encoding="utf-8")), "review-bundle.json")
    artifacts = require_dict(bundle.get("artifacts"), "review-bundle.artifacts")
    build_hash = artifacts.get("buildManifestHash")
    tool_hash = artifacts.get("toolManifestHash")
    if not isinstance(build_hash, str) or len(build_hash) != 64:
        raise AssertionError(f"review bundle omitted build hash: {bundle!r}")
    if not isinstance(tool_hash, str) or len(tool_hash) != 64:
        raise AssertionError(f"review bundle omitted tool hash: {bundle!r}")
    return build_hash, tool_hash, tools, dispatch, runtime_authority


def assert_runtime_call(heatc: str, repo: Path, project: Path, build_hash: str, tool_hash: str) -> tuple[str, dict[str, object], dict[str, object]]:
    proc: subprocess.Popen[bytes] | None = None
    try:
        proc = subprocess.Popen(
            [heatc, "mcp", "serve", str(project)],
            cwd=repo,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        send(proc, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}})
        init = read_frame(proc, "initialize")
        if init.get("result", {}).get("capabilities") != {"tools": {}}:
            raise AssertionError(f"wrong initialize result: {init!r}")

        send(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tools = read_frame(proc, "tools/list")
        listed = tools.get("result", {}).get("tools")
        if not isinstance(listed, list) or len(listed) != 1 or listed[0].get("name") != "get_ticket_context":
            raise AssertionError(f"wrong tools/list result: {tools!r}")

        send(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {
                    "name": "get_ticket_context",
                    "_meta": IDENTITY_META,
                    "arguments": {"ticket_id": "T-123", "limit": 3, "include_closed": False},
                },
            },
        )
        call = read_frame(proc, "tools/call")
        content = call.get("result", {}).get("content")
        expected_text = "support_context: invoice dispute for T-123"
        if not isinstance(content, list) or len(content) != 1 or not isinstance(content[0], dict) or content[0].get("text") != expected_text:
            raise AssertionError(f"wrong tools/call result: {call!r}")

        send(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 4,
                "method": "tools/call",
                "params": {
                    "name": "helper_unregistered_context",
                    "_meta": IDENTITY_META,
                    "arguments": {"ticket_id": "T-123"},
                },
            },
        )
        helper = read_frame(proc, "tools/call helper")
        helper_error = helper.get("error")
        if not isinstance(helper_error, dict) or "unknown MCP tool" not in str(helper_error.get("message")):
            raise AssertionError(f"unregistered helper was not refused: {helper!r}")

        send(proc, {"jsonrpc": "2.0", "id": 5, "method": "shutdown", "params": {}})
        _shutdown = read_frame(proc, "shutdown")
        send(proc, {"jsonrpc": "2.0", "method": "exit"})
        rc = proc.wait(timeout=5)
        if rc != 0:
            stderr = proc.stderr.read().decode("utf-8", errors="replace") if proc.stderr is not None else ""
            raise AssertionError(f"MCP server exited {rc}\nstderr:\n{stderr}")
    finally:
        if proc is not None and proc.poll() is None:
            proc.kill()
            proc.wait(timeout=5)

    event_path = project / "events" / "mcp-usage.jsonl"
    events = [json.loads(line) for line in event_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    by_request = {event.get("request_id"): event for event in events}
    event = by_request.get("3")
    if not isinstance(event, dict):
        raise AssertionError(f"missing successful call usage event: {events!r}")
    expected = {
        "status": "ok",
        "tool_name": "get_ticket_context",
        "tenant_id": "tenant-demo",
        "user_id": "user-demo",
        "agent_id": "agent-demo",
        "effects_used": ["io"],
        "capabilities_used": ["runtime.io"],
        "data_classes_touched": ["customer_data"],
        "data_classes_returned": ["customer_data"],
    }
    for key, value in expected.items():
        if event.get(key) != value:
            raise AssertionError(f"usage event wrong {key}: {event!r}")
    if event.get("build_manifest_hash") != build_hash:
        raise AssertionError(f"usage event build hash does not match review bundle: {event!r}")
    if event.get("tool_manifest_hash") != tool_hash:
        raise AssertionError(f"usage event tool hash does not match review bundle: {event!r}")
    helper_event = by_request.get("4")
    if not isinstance(helper_event, dict):
        raise AssertionError(f"missing helper refusal usage event: {events!r}")
    if helper_event.get("status") != "rejected" or helper_event.get("error_code") != "unknown_tool":
        raise AssertionError(f"helper refusal usage event wrong: {helper_event!r}")
    return expected_text, event, helper_event


def html_table(rows: list[dict[str, str]], columns: list[tuple[str, str]]) -> str:
    header = "".join(f"<th>{html.escape(label)}</th>" for _key, label in columns)
    body = []
    for row in rows:
        cells = "".join(f"<td>{html.escape(str(row.get(key, '')))}</td>" for key, _label in columns)
        body.append(f"<tr>{cells}</tr>")
    return f"<table><thead><tr>{header}</tr></thead><tbody>{''.join(body)}</tbody></table>"


def write_review_html(
    out_path: Path,
    refusals: list[dict[str, str]],
    build_hash: str,
    tool_hash: str,
    tools: dict[str, object],
    dispatch: dict[str, object],
    runtime_authority: dict[str, object],
    call_text: str,
    usage_event: dict[str, object],
    helper_event: dict[str, object],
) -> None:
    tool_entries = [require_dict(tool, "tools-list.tools[]") for tool in require_list(tools.get("tools"), "tools-list.tools")]
    tool_names = ", ".join(str(tool.get("name", "")) for tool in tool_entries)
    dispatch_rows = []
    dispatch_entries = [require_dict(entry, "call-dispatch.dispatch[]") for entry in require_list(dispatch.get("dispatch"), "call-dispatch.dispatch")]
    for entry in dispatch_entries:
        dispatch_rows.append({
            "tool": str(entry.get("tool", "")),
            "effects": ", ".join(entry.get("effects", [])),
            "capabilities": ", ".join(entry.get("capabilities", [])),
            "returns": entry.get("outputContract", ""),
        })
    refusal_table = html_table(refusals, [("class", "Class"), ("signal", "Signal"), ("meaning", "Reviewer meaning")])
    dispatch_table = html_table(dispatch_rows, [("tool", "Tool"), ("effects", "Effects"), ("capabilities", "Capabilities"), ("returns", "Output contract")])
    usage_json = html.escape(json.dumps(usage_event, indent=2, sort_keys=True))
    helper_json = html.escape(json.dumps(helper_event, indent=2, sort_keys=True))
    authority_json = html.escape(json.dumps(runtime_authority, indent=2, sort_keys=True))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Heat Security Review Bundle</title>
<style>
body {{ margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #0f1216; color: #e9edf2; }}
main {{ max-width: 1040px; margin: 0 auto; padding: 40px 24px 64px; }}
h1 {{ font-size: 34px; line-height: 1.12; margin: 0 0 12px; }}
h2 {{ margin-top: 34px; border-bottom: 1px solid #33404d; padding-bottom: 8px; font-size: 18px; }}
p {{ color: #b7c1cc; line-height: 1.55; }}
code {{ color: #ffb15c; }}
table {{ width: 100%; border-collapse: collapse; margin: 14px 0 20px; }}
th, td {{ border: 1px solid #33404d; padding: 10px 12px; text-align: left; vertical-align: top; }}
th {{ background: #171d24; color: #ffb15c; font-weight: 650; }}
td {{ background: #121820; }}
pre {{ overflow: auto; background: #080b0f; border: 1px solid #33404d; border-radius: 6px; padding: 14px; color: #cfd7df; }}
.hash {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; overflow-wrap: anywhere; }}
.ok {{ color: #77d68a; font-weight: 700; }}
</style>
</head>
<body>
<main>
<h1>AI Tool Security Review: source to runtime evidence</h1>
<p>This artifact was generated by <code>examples/demos/security_review_bundle/run_demo.sh</code>. It is not a slide: it is the review packet tying compiler refusals, reviewed MCP authority, and live usage events together.</p>

<h2>1. AI draft refused</h2>
{refusal_table}

<h2>2. Fixed build accepted</h2>
<p class="ok">Reviewed MCP project checked, built with <code>--emit-review-bundle</code>, and validated.</p>
<p>Exposed tool surface: <code>{html.escape(tool_names)}</code></p>
{dispatch_table}

<h2>3. Review bundle hashes</h2>
<p>Build manifest hash:</p>
<pre class="hash">{html.escape(build_hash)}</pre>
<p>Tool manifest hash:</p>
<pre class="hash">{html.escape(tool_hash)}</pre>

<h2>4. Runtime call linked to reviewed bundle</h2>
<p>Successful tool result: <code>{html.escape(call_text)}</code></p>
<pre>{usage_json}</pre>
<p>Unregistered helper invocation was rejected and audited:</p>
<pre>{helper_json}</pre>

<h2>Runtime authority boundary</h2>
<pre>{authority_json}</pre>
</main>
</body>
</html>
""", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Heat security review bundle demo.")
    parser.add_argument("--heatc", default=os.environ.get("HEATC", "/tmp/heatc"), help="path to heatc")
    parser.add_argument("--out", default=str(Path(__file__).resolve().parent / "out" / "security-review.html"), help="HTML review artifact path")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[3]
    support_src = repo / "examples" / "mcp" / "support-readonly"
    out_path = Path(args.out)

    with tempfile.TemporaryDirectory(prefix="heat-security-review-demo-") as tmp:
        workspace = Path(tmp)
        safe = workspace / "support-readonly"
        copy_demo_project(support_src, safe)

        refusals = assert_security_refusals(args.heatc, repo, workspace)
        run([args.heatc, "mcp", "check", str(safe)], cwd=repo)
        run([args.heatc, "mcp", "build", str(safe), "--emit-review-bundle"], cwd=repo)
        run([args.heatc, "mcp", "validate", str(safe)], cwd=repo)
        build_hash, tool_hash, tools, dispatch, runtime_authority = assert_review_artifacts(safe)
        call_text, usage_event, helper_event = assert_runtime_call(args.heatc, repo, safe, build_hash, tool_hash)

        write_review_html(out_path, refusals, build_hash, tool_hash, tools, dispatch, runtime_authority, call_text, usage_event, helper_event)

    print("1. AI draft refused")
    for refusal in refusals:
        print(f"   {refusal['signal']}: {refusal['meaning']}")
    print("2. Fixed build accepted")
    print("   heatc mcp check/build/validate: ok")
    print("3. Review bundle generated")
    print(f"   build_manifest_hash={build_hash[:12]}...")
    print(f"   tool_manifest_hash={tool_hash[:12]}...")
    print("4. Runtime call linked to reviewed bundle")
    print(f"   tools/call result: {call_text}")
    print(f"   usage event: status={usage_event['status']} tool={usage_event['tool_name']} data={json.dumps(usage_event['data_classes_returned'], separators=(',', ':'))}")
    print(f"   unregistered helper: {helper_event['status']} / {helper_event['error_code']}")
    print(f"   review artifact: {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
