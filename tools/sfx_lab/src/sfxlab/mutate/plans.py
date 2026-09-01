"""Mutation plan schema validation."""

from __future__ import annotations

import json
from pathlib import Path

from ..exceptions import SfxLabError
from .operations import OPERATIONS, validate_operation


def load_plan(path: str | Path) -> dict:
    plan = json.loads(Path(path).read_text(encoding="utf-8"))
    validate_plan(plan)
    return plan


def validate_plan(plan: dict) -> None:
    operations = plan.get("operations")
    if not isinstance(operations, list):
        raise SfxLabError("mutation plan must contain an operations array")
    for operation in operations:
        name = operation.get("operation")
        if name not in OPERATIONS:
            raise SfxLabError(f"unknown operation {name}")
        validate_operation(name, operation.get("arguments", {}))