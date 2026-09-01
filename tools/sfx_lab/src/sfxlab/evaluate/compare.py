"""Evaluation: multi-resolution STFT comparison between source and reconstruction."""

from __future__ import annotations

import numpy as np

from ..recipe.models import Recipe
from ..synthesis.renderer import render_recipe


def _stft_error(source: np.ndarray, candidate: np.ndarray, rate: int, fft_size: int) -> float:
    from scipy.signal import get_window, stft

    length = min(source.size, candidate.size)
    if length <= 0:
        return float("inf")
    window = get_window("hann", fft_size, fftbins=True)
    _, _, src = stft(source[:length], fs=rate, window=window, nperseg=fft_size, noverlap=fft_size // 2, padded=True)
    _, _, cand = stft(candidate[:length], fs=rate, window=window, nperseg=fft_size, noverlap=fft_size // 2, padded=True)
    return float(np.mean(np.abs(np.abs(src) - np.abs(cand))))


def compare(source: np.ndarray, recipe: Recipe, seed: int = 1337) -> dict:
    render = render_recipe(recipe, seed)
    candidate = render["mix"]
    lengths = min(source.size, candidate.size)
    a, b = source[:lengths], candidate[:lengths]
    if lengths == 0:
        return {"error": float("inf"), "stft_errors": {}, "stem_sum_error": None}

    envelope_loss = float(np.mean(np.abs(np.abs(a) - np.abs(b))))
    stft_errors = {str(size): _stft_error(a, b, recipe.sample_rate_hz, size) for size in (256, 1024, 4096)}

    stems = render["stems"]
    stem_sum = np.zeros_like(candidate, dtype=np.float64)
    for stem in stems.values():
        stem_sum += stem
    stem_sum_error = float(np.max(np.abs(stem_sum[:lengths] - candidate[:lengths]))) if lengths else 0.0

    return {"envelope_loss": envelope_loss, "stft_errors": stft_errors, "stem_sum_error": stem_sum_error, "candidate": candidate}