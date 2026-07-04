"""Bank-support example with an optional Heat egress boundary.

Run with:

    uv run -m pydantic_ai_examples.heat_boundary_bank_support

This mirrors the public `bank_support.py` example shape: `Agent`,
`RunContext`, dependency injection, and `@support_agent.tool`. The only new
idea is that a high-risk tool calls a small boundary adapter before side
effects.

The adapter is deliberately tiny in this example. A production integration
would replace it with generated/checked boundary code.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from pydantic_ai import Agent, RunContext
from pydantic_ai.models.test import TestModel
from pydantic_ai_examples.validate_proof import validate_proof


PROOF_PATH = Path(__file__).resolve().parent / "heat_boundary" / "proof.json"
ATTACK_EXPORT_PATH = "/tmp/heat_pydanticai_public_case.txt"
SAFE_EXPORT_PATH = "/tmp/heat_pydanticai_safe_exports/case_4142.txt"


@dataclass
class SupportDependencies:
    customer_id: int
    export_root: Path


class HeatBoundary:
    """Minimal proof-backed boundary adapter for the example."""

    def __init__(self, proof_path: Path = PROOF_PATH) -> None:
        self.proof_path = proof_path

    def check_export_case_file(self, *, path: str, content: str) -> tuple[bool, str]:
        _ = content
        proof = load_heat_proof(self.proof_path)
        if path.startswith("/tmp/heat_pydanticai_safe_exports/"):
            return True, "BUILT"
        return False, proof["diagnostic"]


def load_heat_proof(proof_path: Path) -> dict[str, str]:
    proof = validate_proof(proof_path)
    return {"diagnostic": proof.diagnostic}


def create_support_agent(*, call_tools: list[str] | str = "none") -> Agent[SupportDependencies, str]:
    if call_tools == "none":
        test_model = TestModel(call_tools=[])
    else:
        test_model = TestModel(call_tools=call_tools)

    support_agent = Agent(
        model=test_model,
        deps_type=SupportDependencies,
        instructions=(
            "You are a bank support agent. Use tools for external actions. "
            "High-risk egress must go through the Heat boundary."
        ),
    )

    @support_agent.instructions
    async def add_customer_id(ctx: RunContext[SupportDependencies]) -> str:
        return f"The customer's id is {ctx.deps.customer_id}."

    @support_agent.tool
    async def export_case_file(
        ctx: RunContext[SupportDependencies], path: str, content: str
    ) -> str:
        """Export a support case file after Heat boundary validation."""
        allowed, reason = HeatBoundary().check_export_case_file(
            path=path, content=content
        )
        if not allowed:
            return "blocked by Heat boundary: " + reason
        target = ctx.deps.export_root / Path(path).name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
        return f"allowed by Heat boundary ({reason}): wrote {target}"

    return support_agent


def run_agent_tool_call() -> str:
    agent = create_support_agent(call_tools=["export_case_file"])
    deps = SupportDependencies(customer_id=4142, export_root=Path("/tmp"))
    result = agent.run_sync(
        "Export the current support case to the requested path.", deps=deps
    )
    return str(result.output)


def run_repaired_tool_call() -> str:
    allowed, reason = HeatBoundary().check_export_case_file(
        path=SAFE_EXPORT_PATH, content="customer_id=4142"
    )
    if not allowed:
        return "blocked by Heat boundary: " + reason
    deps = SupportDependencies(
        customer_id=4142, export_root=Path("/tmp/heat_pydanticai_safe_exports")
    )
    target = deps.export_root / Path(SAFE_EXPORT_PATH).name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("customer_id=4142", encoding="utf-8")
    return f"allowed by Heat boundary ({reason}): wrote {target}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repaired", action="store_true")
    args = parser.parse_args()

    if args.repaired:
        print(run_repaired_tool_call())
    else:
        print(run_agent_tool_call())


if __name__ == "__main__":
    main()
