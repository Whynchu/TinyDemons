"""Unit + integration tests for the sfx lab vertical slice."""

from __future__ import annotations

import numpy as np
import pytest

from sfxlab.analysis.models import PartialTrack
from sfxlab.backends.native_backend import NativeBackend, synthesize_partials
from sfxlab.componentize.tonal_rules import componentize_tracks, edge_score
from sfxlab.recipe.models import Component, PartialSpec, Recipe, validate_recipe
from sfxlab.recipe.validate_io import dump_recipe, load_recipe
from sfxlab.audio.io import canonicalize
from tests.fixtures.synthetic.generate import harmonic_stack, rising_chirp, steady_sine


def test_native_backend_tracks_steady_sine() -> None:
    samples = steady_sine()
    backend = NativeBackend()
    analysis = backend.analyze(samples, 48000)
    assert analysis.tracks, "steady sine should produce at least one tracked partial"
    freqs = np.concatenate([track.frequencies() for track in analysis.tracks])
    assert np.median(freqs) > 400.0 and np.median(freqs) < 480.0


def test_native_backend_synthesis_is_deterministic() -> None:
    samples = steady_sine()
    backend = NativeBackend()
    analysis = backend.analyze(samples, 48000)
    a = backend.synthesize(analysis, 48000)
    b = backend.synthesize(analysis, 48000)
    assert np.array_equal(a, b)


def test_partial_synthesis_length_matches_duration() -> None:
    track = PartialTrack(id="t", frames=[])
    out = synthesize_partials([track], 48000, 0.1)
    assert out.size == 4800


def test_componentizer_groups_harmonic_stack() -> None:
    samples = harmonic_stack()
    backend = NativeBackend()
    analysis = backend.analyze(samples, 48000)
    groups = componentize_tracks(analysis.tracks)
    assert groups, "harmonic stack should produce at least one tonal group"


def test_edge_score_similar_tracks_is_high() -> None:
    track_a = PartialTrack(id="a", frames=[])
    track_b = PartialTrack(id="b", frames=[])
    track_a.frames = track_a.frames  # placeholders
    from sfxlab.analysis.models import PartialFrame

    def make(id_: str, freq: float, start: float, end: float) -> PartialTrack:
        frames = [
            PartialFrame(time_s=start, frequency_hz=freq, magnitude_db=-10.0, phase_rad=0.0),
            PartialFrame(time_s=end, frequency_hz=freq, magnitude_db=-12.0, phase_rad=0.1),
        ]
        return PartialTrack(id=id_, frames=frames)

    a = make("a", 440.0, 0.0, 0.2)
    b = make("b", 880.0, 0.01, 0.21)
    assert edge_score(a, b) > 0.6


def test_recipe_validation_rejects_bad_type() -> None:
    recipe = Recipe(duration_s=0.1, components=[Component(id="c1", type="not_a_type", start_s=0.0, duration_s=0.1)])
    with pytest.raises(Exception):
        validate_recipe(recipe)


def test_recipe_round_trip() -> None:
    recipe = Recipe(
        source_sha256="abc",
        duration_s=0.3,
        components=[Component(id="c1", type="tonal_cluster", start_s=0.0, duration_s=0.3, fundamental_hz=440.0, partials=[PartialSpec(ratio=1.0, gain=1.0)])],
    )
    data = dump_recipe(recipe)
    restored = load_recipe(_write_tmp_json(data))
    assert restored.recipe_id == recipe.recipe_id
    assert restored.components[0].type == "tonal_cluster"


def _write_tmp_json(data: dict) -> str:
    import json
    import tempfile

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as handle:
        json.dump(data, handle)
        return handle.name


def test_canonicalize_mono_48k() -> None:
    samples = np.random.default_rng(3).normal(0.0, 0.1, (48000, 2)).astype(np.float32)
    canonical, record = canonicalize(samples, 48000)
    assert canonical.ndim == 1
    assert record["sample_rate_hz"] == 48000
    assert float(np.max(np.abs(canonical))) <= 1.0