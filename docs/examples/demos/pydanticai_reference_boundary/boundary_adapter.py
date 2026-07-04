"""Generated-boundary shaped adapter for the PydanticAI demo.

Today this adapter validates `proof.json` and mirrors the checked boundary's
allow/refuse decision. A production integration would replace this file with
generated code that calls the Heat-built boundary artifact directly.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from validate_proof import PROOF_PATH, validate_proof


DEMO_DIR = Path(__file__).resolve().parent
ATTACK_EXPORT_PATH = "/tmp/heat_pydanticai_public_case.txt"
SAFE_EXPORT_PATH = "/tmp/heat_pydanticai_safe_exports/case_4142.txt"


@dataclass(frozen=True)
class BoundaryProof:
    diagnostic: str
    fixed_verdict: str


class GeneratedHeatBoundary:
    """Small stand-in for generated boundary code."""

    def __init__(self, proof_path: Path = PROOF_PATH) -> None:
        self.proof_path = proof_path

    def check_export_case_file(self, *, path: str, content: str) -> tuple[bool, str]:
        _ = content
        proof = load_heat_boundary_proof(self.proof_path)
        if path.startswith("/tmp/heat_pydanticai_safe_exports/"):
            return True, proof.fixed_verdict
        return False, proof.diagnostic


HeatBoundary = GeneratedHeatBoundary


def load_heat_boundary_proof(proof_path: Path = PROOF_PATH) -> BoundaryProof:
    proof = validate_proof(proof_path)
    return BoundaryProof(diagnostic=proof.diagnostic, fixed_verdict=proof.fixed_verdict)
