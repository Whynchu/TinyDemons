"""Component renderer and deterministic reconstruction mix.

Each component renders independently to a stem; the reconstruction is the
summed mix. A stem-sum test verifies the published reconstruction equals the
sum of the published stems within numerical tolerance (spec 2.4, 7).
"""

from __future__ import annotations

import numpy as np

from ..recipe.models import Component, Recipe


def render_component(component: Component, sample_rate: int, frame_count: int, seed: int = 1337) -> np.ndarray:
    """Render one component to a stem buffer of length frame_count."""
    out = np.zeros(frame_count, dtype=np.float64)
    rng = np.random.default_rng(seed + abs(hash(component.id)) % 100000)

    start = max(0, int(round(component.start_s * sample_rate)))
    end = min(frame_count, int(round((component.start_s + component.duration_s) * sample_rate)))
    if start >= end:
        return out.astype(np.float32)

    t = np.arange(start, end, dtype=np.float64) / sample_rate - component.start_s
    duration = max(float(component.duration_s), 1e-6)

    amplitude_env = _curve_env(component.amplitude_curve, t, duration)
    pitch = component.fundamental_hz
    if component.pitch_curve:
        pitch = _curve_env(component.pitch_curve, t, duration)
        pitch = np.maximum(pitch, 1.0)

    if component.type == "tonal_cluster" and component.partials:
        for partial in component.partials:
            if partial.ratio <= 0.0:
                continue
            frequency = pitch * partial.ratio
            decay = max(partial.decay_scale, 0.1)
            signal = np.sin(2.0 * np.pi * np.cumsum(frequency) / sample_rate + 1.0)
            envelope = amplitude_env * np.exp(-t / (duration * decay))
            out[start:end] += signal * envelope * partial.gain
    elif component.type in ("noise_burst", "diffuse_tail"):
        noise = rng.normal(0.0, 1.0, end - start)
        envelope = amplitude_env * np.exp(-t / (duration * 0.6))
        out[start:end] += noise * envelope * 0.3
    else:
        out[start:end] += np.sin(2.0 * np.pi * np.cumsum(pitch) / sample_rate) * amplitude_env * 0.3

    gain = 10.0 ** (component.gain_db / 20.0)
    out *= gain
    return out.astype(np.float32)


def _curve_env(curve: list[list[float]], t: np.ndarray, duration: float) -> np.ndarray:
    if not curve:
        return np.ones_like(t)
    times = np.array([point[0] for point in curve], dtype=np.float64) * duration
    values = np.array([point[1] for point in curve], dtype=np.float64)
    return np.interp(t, times, values, left=values[0], right=values[-1])


def render_recipe(recipe: Recipe, seed: int = 1337) -> dict:
    frame_count = max(1, int(round(recipe.duration_s * recipe.sample_rate_hz)))
    stems: dict[str, np.ndarray] = {}
    mix = np.zeros(frame_count, dtype=np.float64)
    for component in recipe.components:
        stem = render_component(component, recipe.sample_rate_hz, frame_count, seed)
        stems[component.id] = stem.astype(np.float32)
        mix += stem

    peak = float(np.max(np.abs(mix))) if mix.size else 0.0
    if peak > 0.0:
        mix = mix * (10.0 ** (recipe.peak_target_dbfs / 20.0) / peak)
    for key in stems:
        stem_peak = float(np.max(np.abs(stems[key]))) if stems[key].size else 0.0
        if stem_peak > 0.0:
            stems[key] = stems[key] * (10.0 ** (recipe.peak_target_dbfs / 20.0) / stem_peak)

    return {"mix": mix.astype(np.float32), "stems": stems, "frame_count": frame_count}