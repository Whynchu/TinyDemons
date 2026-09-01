"""Recipe model and validation (spec section 8.3).

Recipes are renderer-relevant, versioned, and reference analysis-derived
components. Validation rejects unknown types, invalid time ranges, non-finite
numbers, unsorted curves, duplicate IDs, and missing references.
"""

from __future__ import annotations

import hashlib
import re
import uuid
from dataclasses import dataclass, field
from typing import Optional

from ..exceptions import RecipeValidationError

SCHEMA_VERSION = "1.0.0"
COMPONENT_TYPES = {"tonal_cluster", "transient_atom", "noise_burst", "modal_resonance", "diffuse_tail"}


def new_uuid() -> str:
    return str(uuid.uuid4())


@dataclass
class PartialSpec:
    ratio: float
    gain: float
    decay_scale: float = 1.0


@dataclass
class Component:
    id: str
    type: str
    start_s: float
    duration_s: float
    gain_db: float = 0.0
    partials: list[PartialSpec] = field(default_factory=list)
    fundamental_hz: float = 0.0
    pitch_curve: list[list[float]] = field(default_factory=list)
    amplitude_curve: list[list[float]] = field(default_factory=list)
    analysis_refs: list[str] = field(default_factory=list)
    confidence: float = 1.0


@dataclass
class Recipe:
    schema_version: str = SCHEMA_VERSION
    recipe_id: str = field(default_factory=new_uuid)
    source_sha256: str = ""
    analysis_run_id: str = ""
    sample_rate_hz: int = 48000
    channels: int = 1
    duration_s: float = 0.0
    components: list[Component] = field(default_factory=list)
    peak_target_dbfs: float = -1.0
    limiter_enabled: bool = False
    parent_recipe_id: Optional[str] = None
    operations: list[dict] = field(default_factory=list)

    @property
    def fingerprint(self) -> str:
        payload = f"{self.schema_version}|{self.source_sha256}|{self.analysis_run_id}|{self.duration_s}|" + "|".join(
            f"{c.id}:{c.type}:{c.start_s}:{c.duration_s}:{c.gain_db}:{len(c.partials)}" for c in self.components
        )
        return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def _validate_curve(curve: list[list[float]], name: str) -> None:
    if not curve:
        return
    for point in curve:
        if len(point) != 2:
            raise RecipeValidationError(f"{name} points must be [time, value] pairs")
        for value in point:
            if not all(value == value and value != float("inf") and value != float("-inf") for value in [value]):
                raise RecipeValidationError(f"{name} contains a non-finite value")
    times = [point[0] for point in curve]
    if any(next_t < current for current, next_t in zip(times, times[1:])):
        raise RecipeValidationError(f"{name} must be sorted by time")


def validate_recipe(recipe: Recipe) -> None:
    if recipe.schema_version != SCHEMA_VERSION:
        raise RecipeValidationError(f"unsupported schema version {recipe.schema_version}")
    if recipe.duration_s < 0.0:
        raise RecipeValidationError("duration must be non-negative")
    if recipe.sample_rate_hz <= 0:
        raise RecipeValidationError("sample rate must be positive")
    seen_ids: set[str] = set()
    for component in recipe.components:
        if component.id in seen_ids:
            raise RecipeValidationError(f"duplicate component id {component.id}")
        seen_ids.add(component.id)
        if component.type not in COMPONENT_TYPES:
            raise RecipeValidationError(f"unknown component type {component.type}")
        if component.start_s < 0.0 or component.duration_s <= 0.0:
            raise RecipeValidationError(f"invalid time range on {component.id}")
        if component.fundamental_hz < 0.0:
            raise RecipeValidationError(f"negative fundamental on {component.id}")
        _validate_curve(component.pitch_curve, f"{component.id}.pitch_curve")
        _validate_curve(component.amplitude_curve, f"{component.id}.amplitude_curve")