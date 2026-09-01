"""Mutation operations for recipes.

Named, typed commands per spec section 11. Each operation declares its target
component types, parameter bounds, and which aspect it changes (timing,
spectrum, topology, loudness). Operations never mutate the source recipe in
place; they build a new recipe and append provenance.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Callable

from ..exceptions import SfxLabError
from ..recipe.models import Component, PartialSpec, Recipe


@dataclass(frozen=True)
class OperationSpec:
    name: str
    affects: str  # "timing" | "spectrum" | "topology" | "loudness"
    compatible_types: tuple[str, ...]
    parameter_bounds: dict[str, tuple[float, float]] = field(default_factory=dict)


class MutationError(SfxLabError):
    """A mutation operation could not be applied."""


# Affinity labels for which sound aspect a component represents.
TONAL_TYPES = ("tonal_cluster", "modal_resonance")
NOISE_TYPES = ("noise_burst", "diffuse_tail")


OPERATIONS: dict[str, OperationSpec] = {
    "transpose_component": OperationSpec("transpose_component", "spectrum", TONAL_TYPES, {"cents": (-2400.0, 2400.0)}),
    "stretch_component": OperationSpec("stretch_component", "timing", TONAL_TYPES + NOISE_TYPES, {"factor": (0.2, 5.0)}),
    "shift_component": OperationSpec("shift_component", "timing", TONAL_TYPES + NOISE_TYPES, {"seconds": (-2.0, 2.0)}),
    "scale_component_gain": OperationSpec("scale_component_gain", "loudness", TONAL_TYPES + NOISE_TYPES, {"db": (-24.0, 24.0)}),
    "scale_partial": OperationSpec("scale_partial", "spectrum", TONAL_TYPES, {"partial_index": (0.0, 100.0), "gain": (0.0, 4.0)}),
    "remove_partial": OperationSpec("remove_partial", "topology", TONAL_TYPES, {"partial_index": (0.0, 100.0)}),
    "change_partial_ratio": OperationSpec("change_partial_ratio", "spectrum", TONAL_TYPES, {"partial_index": (0.0, 100.0), "ratio": (0.25, 8.0)}),
    "reverse_pitch_contour": OperationSpec("reverse_pitch_contour", "spectrum", TONAL_TYPES, {}),
    "warp_pitch_contour": OperationSpec("warp_pitch_contour", "spectrum", TONAL_TYPES, {"amount": (-2.0, 2.0)}),
    "scale_inharmonicity": OperationSpec("scale_inharmonicity", "spectrum", TONAL_TYPES, {"factor": (0.0, 3.0)}),
    "move_noise_band": OperationSpec("move_noise_band", "spectrum", NOISE_TYPES, {"cents": (-1200.0, 1200.0)}),
    "change_decay": OperationSpec("change_decay", "timing", TONAL_TYPES + NOISE_TYPES, {"factor": (0.1, 4.0)}),
    "duplicate_component": OperationSpec("duplicate_component", "topology", TONAL_TYPES + NOISE_TYPES, {"offset_s": (0.0, 2.0)}),
    "replace_transient": OperationSpec("replace_transient", "topology", ("transient_atom",), {}),
}

OP_HANDLERS: dict[str, Callable] = {}


def register(name: str) -> Callable:
    def decorator(handler: Callable) -> Callable:
        OP_HANDLERS[name] = handler
        return handler

    return decorator


def validate_operation(name: str, arguments: dict) -> None:
    spec = OPERATIONS.get(name)
    if spec is None:
        raise MutationError(f"unknown operation {name}")
    for key, (minimum, maximum) in spec.parameter_bounds.items():
        if key not in arguments:
            continue
        value = float(arguments[key])
        if value < minimum or value > maximum:
            raise MutationError(f"{name}.{key}={value} out of bounds [{minimum}, {maximum}]")


def _clone_component(component: Component) -> Component:
    return Component(
        id=component.id,
        type=component.type,
        start_s=component.start_s,
        duration_s=component.duration_s,
        gain_db=component.gain_db,
        fundamental_hz=component.fundamental_hz,
        partials=[PartialSpec(ratio=p.ratio, gain=p.gain, decay_scale=p.decay_scale) for p in component.partials],
        pitch_curve=[list(point) for point in component.pitch_curve],
        amplitude_curve=[list(point) for point in component.amplitude_curve],
        analysis_refs=list(component.analysis_refs),
        confidence=component.confidence,
    )


def _find(recipe: Recipe, target: str) -> Component:
    for component in recipe.components:
        if component.id == target:
            return component
    raise MutationError(f"component {target} not found in recipe")


def _replace(recipe: Recipe, original: Component, replacement: Component) -> None:
    for index, component in enumerate(recipe.components):
        if component.id == original.id:
            recipe.components[index] = replacement
            return


@register("transpose_component")
def transpose_component(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    semitones = float(arguments["cents"]) / 100.0
    replacement.fundamental_hz = component.fundamental_hz * (2.0 ** (semitones / 12.0))
    replacement.pitch_curve = [[point[0], point[1] * (2.0 ** (semitones / 12.0))] for point in component.pitch_curve]
    _replace(recipe, component, replacement)


@register("stretch_component")
def stretch_component(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    factor = float(arguments["factor"])
    replacement.start_s = component.start_s
    replacement.duration_s = component.duration_s * factor
    replacement.pitch_curve = [[point[0] / factor, point[1]] for point in component.pitch_curve]
    replacement.amplitude_curve = [[point[0] / factor, point[1]] for point in component.amplitude_curve]
    _replace(recipe, component, replacement)


@register("shift_component")
def shift_component(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    replacement.start_s = max(0.0, component.start_s + float(arguments["seconds"]))
    _replace(recipe, component, replacement)


@register("scale_component_gain")
def scale_component_gain(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    replacement.gain_db = component.gain_db + float(arguments["db"])
    _replace(recipe, component, replacement)


@register("scale_partial")
def scale_partial(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    index = int(arguments["partial_index"])
    if index < 0 or index >= len(component.partials):
        raise MutationError(f"partial index {index} out of range for {target}")
    replacement = _clone_component(component)
    partial = replacement.partials[index]
    replacement.partials[index] = PartialSpec(ratio=partial.ratio, gain=partial.gain * float(arguments["gain"]), decay_scale=partial.decay_scale)
    _replace(recipe, component, replacement)


@register("remove_partial")
def remove_partial(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    index = int(arguments["partial_index"])
    if index < 0 or index >= len(component.partials):
        raise MutationError(f"partial index {index} out of range for {target}")
    replacement = _clone_component(component)
    del replacement.partials[index]
    _replace(recipe, component, replacement)


@register("change_partial_ratio")
def change_partial_ratio(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    index = int(arguments["partial_index"])
    if index < 0 or index >= len(component.partials):
        raise MutationError(f"partial index {index} out of range for {target}")
    replacement = _clone_component(component)
    partial = replacement.partials[index]
    replacement.partials[index] = PartialSpec(ratio=float(arguments["ratio"]), gain=partial.gain, decay_scale=partial.decay_scale)
    _replace(recipe, component, replacement)


@register("reverse_pitch_contour")
def reverse_pitch_contour(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    replacement.pitch_curve = [[point[0], 1.0 / max(point[1], 0.01)] for point in component.pitch_curve]
    _replace(recipe, component, replacement)


@register("warp_pitch_contour")
def warp_pitch_contour(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    amount = float(arguments["amount"])
    replacement.pitch_curve = [[point[0], point[1] * (1.0 + amount * point[0])] for point in component.pitch_curve]
    _replace(recipe, component, replacement)


@register("scale_inharmonicity")
def scale_inharmonicity(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    factor = float(arguments["factor"])
    replacement.partials = [
        PartialSpec(
            ratio=(p.ratio - 1.0) * factor + 1.0 if p.ratio > 0.0 else p.ratio,
            gain=p.gain,
            decay_scale=p.decay_scale,
        )
        for p in component.partials
    ]
    _replace(recipe, component, replacement)


@register("move_noise_band")
def move_noise_band(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    cents = float(arguments["cents"])
    replacement.fundamental_hz = component.fundamental_hz * (2.0 ** (cents / 1200.0)) if component.fundamental_hz > 0.0 else component.fundamental_hz
    _replace(recipe, component, replacement)


@register("change_decay")
def change_decay(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    factor = float(arguments["factor"])
    replacement.partials = [PartialSpec(ratio=p.ratio, gain=p.gain, decay_scale=p.decay_scale * factor) for p in component.partials]
    _replace(recipe, component, replacement)


@register("duplicate_component")
def duplicate_component(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    duplicate = _clone_component(component)
    duplicate.id = f"{component.id}-dup"
    duplicate.start_s = component.start_s + float(arguments["offset_s"])
    recipe.components.append(duplicate)


@register("replace_transient")
def replace_transient(recipe: Recipe, target: str, arguments: dict) -> None:
    component = _find(recipe, target)
    replacement = _clone_component(component)
    replacement.analysis_refs.append(f"authorized-atom:{arguments.get('atom_ref', '')}")
    _replace(recipe, component, replacement)


def apply_operation(recipe: Recipe, operation: dict) -> None:
    name = str(operation.get("operation"))
    target = str(operation.get("target"))
    arguments = operation.get("arguments", {})
    spec = OPERATIONS.get(name)
    if spec is None:
        raise MutationError(f"unknown operation {name}")
    component = _find(recipe, target)
    if component.type not in spec.compatible_types:
        raise MutationError(f"{name} not compatible with component type {component.type}")
    validate_operation(name, arguments)
    handler = OP_HANDLERS[name]
    handler(recipe, target, arguments)
    recipe.operations.append(
        {
            "operation": name,
            "target": target,
            "arguments": {k: v for k, v in arguments.items()},
        }
    )


def apply_mutation_plan(recipe: Recipe, plan: dict) -> Recipe:
    """Copy the source recipe, apply every operation, return a new recipe."""
    import copy

    mutated = copy.deepcopy(recipe)
    mutated.parent_recipe_id = recipe.recipe_id
    mutated.recipe_id = _new_id()
    mutated.operations = []
    for operation in plan.get("operations", []):
        apply_operation(mutated, operation)
    return mutated


def _new_id() -> str:
    import uuid

    return str(uuid.uuid4())


def mutation_distance(recipe: Recipe, mutated: Recipe) -> dict:
    """Normalized engineering distance between a recipe and its mutation.

    Not a legal guarantee; a navigation aid only (spec 11).
    """
    from ..recipe.validate_io import dump_recipe

    source = dump_recipe(recipe)
    target = dump_recipe(mutated)
    parameter_delta = 0.0
    component_delta = abs(len(target["components"]) - len(source["components"]))
    for index, component in enumerate(source["components"]):
        if index >= len(target["components"]):
            continue
        current = target["components"][index]
        partial_delta = abs(len(current["partials"]) - len(component["partials"]))
        gain_delta = abs(float(current.get("gain_db", 0.0)) - float(component.get("gain_db", 0.0))) / 24.0
        parameter_delta = max(parameter_delta, partial_delta / 6.0, gain_delta)
    return {
        "parameter_displacement": round(parameter_delta, 4),
        "component_topology_changes": int(component_delta),
        "mutation_distance": round(parameter_delta + min(component_delta, 2.0), 4),
        "operation_count": len(mutated.operations),
    }