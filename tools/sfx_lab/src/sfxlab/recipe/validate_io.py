"""Recipe JSON serialization/deserialization and validation entry points."""

from __future__ import annotations

import json
from pathlib import Path

from .models import Component, PartialSpec, Recipe, validate_recipe


def dump_recipe(recipe: Recipe) -> dict:
    return {
        "schema_version": recipe.schema_version,
        "recipe_id": recipe.recipe_id,
        "source_sha256": recipe.source_sha256,
        "analysis_run_id": recipe.analysis_run_id,
        "sample_rate_hz": recipe.sample_rate_hz,
        "channels": recipe.channels,
        "duration_s": recipe.duration_s,
        "peak_target_dbfs": recipe.peak_target_dbfs,
        "limiter_enabled": recipe.limiter_enabled,
        "parent_recipe_id": recipe.parent_recipe_id,
        "operations": recipe.operations,
        "components": [
            {
                "id": c.id,
                "type": c.type,
                "start_s": c.start_s,
                "duration_s": c.duration_s,
                "gain_db": c.gain_db,
                "fundamental_hz": c.fundamental_hz,
                "partials": [{"ratio": p.ratio, "gain": p.gain, "decay_scale": p.decay_scale} for p in c.partials],
                "pitch_curve": c.pitch_curve,
                "amplitude_curve": c.amplitude_curve,
                "analysis_refs": c.analysis_refs,
                "confidence": c.confidence,
            }
            for c in recipe.components
        ],
    }


def load_recipe(path: str | Path) -> Recipe:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    recipe = Recipe(
        schema_version=data["schema_version"],
        recipe_id=data.get("recipe_id", ""),
        source_sha256=data.get("source_sha256", ""),
        analysis_run_id=data.get("analysis_run_id", ""),
        sample_rate_hz=data.get("sample_rate_hz", 48000),
        channels=data.get("channels", 1),
        duration_s=data.get("duration_s", 0.0),
        peak_target_dbfs=data.get("peak_target_dbfs", -1.0),
        limiter_enabled=data.get("limiter_enabled", False),
        parent_recipe_id=data.get("parent_recipe_id"),
        operations=data.get("operations", []),
    )
    for component_data in data.get("components", []):
        recipe.components.append(
            Component(
                id=component_data["id"],
                type=component_data["type"],
                start_s=component_data.get("start_s", 0.0),
                duration_s=component_data.get("duration_s", 0.05),
                gain_db=component_data.get("gain_db", 0.0),
                fundamental_hz=component_data.get("fundamental_hz", 440.0),
                partials=[PartialSpec(**partial) for partial in component_data.get("partials", [])],
                pitch_curve=component_data.get("pitch_curve", []),
                amplitude_curve=component_data.get("amplitude_curve", []),
                analysis_refs=component_data.get("analysis_refs", []),
                confidence=component_data.get("confidence", 1.0),
            )
        )
    validate_recipe(recipe)
    return recipe