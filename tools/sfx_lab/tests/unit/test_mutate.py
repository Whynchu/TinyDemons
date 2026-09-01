"""Tests for the mutation engine (spec section 11)."""

from __future__ import annotations

import pytest

from sfxlab.mutate.operations import (
    OPERATIONS,
    apply_mutation_plan,
    apply_operation,
    mutation_distance,
)
from sfxlab.mutate.plans import load_plan, validate_plan
from sfxlab.recipe.models import Component, PartialSpec, Recipe, validate_recipe
from sfxlab.recipe.validate_io import dump_recipe, load_recipe


def make_recipe() -> Recipe:
    return Recipe(
        source_sha256="abc",
        duration_s=0.4,
        components=[
            Component(
                id="body",
                type="tonal_cluster",
                start_s=0.0,
                duration_s=0.3,
                fundamental_hz=440.0,
                gain_db=-6.0,
                partials=[
                    PartialSpec(ratio=1.0, gain=1.0, decay_scale=1.0),
                    PartialSpec(ratio=2.0, gain=0.6, decay_scale=0.9),
                ],
                pitch_curve=[[0.0, 1.0], [1.0, 1.5]],
                amplitude_curve=[[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]],
            ),
            Component(
                id="spray",
                type="noise_burst",
                start_s=0.0,
                duration_s=0.2,
                fundamental_hz=3000.0,
            ),
        ],
    )


def test_every_operation_is_registered_and_has_bounds() -> None:
    assert OPERATIONS
    for name, spec in OPERATIONS.items():
        assert spec.compatible_types
        assert name in ("transpose_component", "stretch_component", "shift_component", "scale_component_gain", "scale_partial", "remove_partial", "change_partial_ratio", "reverse_pitch_contour", "warp_pitch_contour", "scale_inharmonicity", "move_noise_band", "change_decay", "duplicate_component", "replace_transient")


def test_transpose_raises_fundamental() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "transpose_component", "target": "body", "arguments": {"cents": 1200}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.fundamental_hz == pytest.approx(880.0)


def test_stretch_scales_duration() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "stretch_component", "target": "body", "arguments": {"factor": 2.0}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.duration_s == pytest.approx(0.6)


def test_shift_moves_start() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "shift_component", "target": "body", "arguments": {"seconds": 0.1}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.start_s == pytest.approx(0.1)


def test_scale_gain_offsets_db() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "scale_component_gain", "target": "body", "arguments": {"db": 6.0}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.gain_db == pytest.approx(0.0)


def test_scale_and_remove_partial() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "scale_partial", "target": "body", "arguments": {"partial_index": 1, "gain": 2.0}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.partials[1].gain == pytest.approx(1.2)
    apply_operation(recipe, {"operation": "remove_partial", "target": "body", "arguments": {"partial_index": 1}})
    body = next(c for c in recipe.components if c.id == "body")
    assert len(body.partials) == 1


def test_change_partial_ratio() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "change_partial_ratio", "target": "body", "arguments": {"partial_index": 1, "ratio": 3.0}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.partials[1].ratio == pytest.approx(3.0)


def test_reverse_and_warp_pitch_contour() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "reverse_pitch_contour", "target": "body", "arguments": {}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.pitch_curve[1][1] == pytest.approx(1.0 / 1.5)
    apply_operation(recipe, {"operation": "warp_pitch_contour", "target": "body", "arguments": {"amount": 0.5}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.pitch_curve[1][1] == pytest.approx((1.0 / 1.5) * 1.5)


def test_scale_inharmonicity() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "scale_inharmonicity", "target": "body", "arguments": {"factor": 1.5}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.partials[1].ratio == pytest.approx((2.0 - 1.0) * 1.5 + 1.0)


def test_move_noise_band() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "move_noise_band", "target": "spray", "arguments": {"cents": 1200}})
    spray = next(c for c in recipe.components if c.id == "spray")
    assert spray.fundamental_hz == pytest.approx(6000.0)


def test_change_decay() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "change_decay", "target": "body", "arguments": {"factor": 2.0}})
    body = next(c for c in recipe.components if c.id == "body")
    assert body.partials[0].decay_scale == pytest.approx(2.0)


def test_duplicate_component() -> None:
    recipe = make_recipe()
    apply_operation(recipe, {"operation": "duplicate_component", "target": "body", "arguments": {"offset_s": 0.1}})
    ids = [c.id for c in recipe.components]
    assert "body-dup" in ids


def test_plan_rejects_unknown_operation() -> None:
    with pytest.raises(Exception):
        validate_plan({"operations": [{"operation": "not_real", "target": "body", "arguments": {}}]})


def test_apply_mutation_plan_copies_and_provenances() -> None:
    recipe = make_recipe()
    plan = {"operations": [{"operation": "transpose_component", "target": "body", "arguments": {"cents": 100}}]}
    mutated = apply_mutation_plan(recipe, plan)
    validate_recipe(mutated)
    assert mutated.parent_recipe_id == recipe.recipe_id
    assert mutated.recipe_id != recipe.recipe_id
    assert len(mutated.operations) == 1
    assert mutated.operations[0]["operation"] == "transpose_component"
    # Original unchanged
    assert next(c for c in recipe.components if c.id == "body").fundamental_hz == pytest.approx(440.0)


def test_mutation_distance() -> None:
    recipe = make_recipe()
    mutated = apply_mutation_plan(recipe, {"operations": [{"operation": "scale_component_gain", "target": "body", "arguments": {"db": 12}}]})
    distance = mutation_distance(recipe, mutated)
    assert distance["operation_count"] == 1
    assert distance["mutation_distance"] > 0.0


def test_plan_round_trip() -> None:
    import json
    import tempfile

    plan = {"operations": [{"operation": "change_decay", "target": "body", "arguments": {"factor": 1.5}}]}
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as handle:
        json.dump(plan, handle)
        handle.flush()
        loaded = load_plan(handle.name)
    assert loaded["operations"][0]["operation"] == "change_decay"


def test_recipe_round_trip_after_mutation() -> None:
    recipe = make_recipe()
    mutated = apply_mutation_plan(recipe, {"operations": [{"operation": "transpose_component", "target": "body", "arguments": {"cents": -200}}]})
    data = dump_recipe(mutated)
    restored = load_recipe(_write_tmp_json(data))
    assert restored.components[0].fundamental_hz == pytest.approx(mutated.components[0].fundamental_hz)


def _write_tmp_json(data: dict) -> str:
    import json
    import tempfile

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as handle:
        json.dump(data, handle)
        return handle.name