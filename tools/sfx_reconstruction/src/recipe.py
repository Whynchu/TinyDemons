"""Dependency-free safety and shape checks for procedural recipes."""

from __future__ import annotations

from collections.abc import Mapping


FORBIDDEN_AUDIO_KEYS = {
    "pcm", "samples", "waveform", "audio_base64", "base64_audio",
    "residual_audio", "reference_audio", "embedded_audio", "audio_bytes",
}


def validate_recipe(recipe: Mapping) -> None:
    required = {"format", "version", "id", "source_role", "render", "events", "processing", "fit"}
    missing = required.difference(recipe)
    if missing:
        raise ValueError(f"recipe missing required fields: {sorted(missing)}")
    if recipe["format"] != "tiny_demons_sfx_recipe":
        raise ValueError("unsupported recipe format")
    render = recipe["render"]
    for key in ("sample_rate", "channels", "duration_seconds", "seed"):
        if key not in render:
            raise ValueError(f"render missing required field: {key}")
    if int(render["channels"]) not in (1, 2):
        raise ValueError("channels must be 1 or 2")
    _reject_embedded_audio(recipe)


def _reject_embedded_audio(value: object, path: str = "recipe") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            if str(key).lower() in FORBIDDEN_AUDIO_KEYS:
                raise ValueError(f"embedded audio data is not allowed at {path}.{key}")
            _reject_embedded_audio(child, f"{path}.{key}")
    elif isinstance(value, (list, tuple)):
        for index, child in enumerate(value):
            _reject_embedded_audio(child, f"{path}[{index}]")
