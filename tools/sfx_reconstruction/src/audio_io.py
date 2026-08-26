"""Small dependency-light PCM WAV reader/writer helpers."""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np


def read_wav(path: str | Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as handle:
        channels = handle.getnchannels()
        sample_width = handle.getsampwidth()
        rate = handle.getframerate()
        frame_count = handle.getnframes()
        raw = handle.readframes(frame_count)
    if sample_width != 2:
        raise ValueError(f"only 16-bit PCM WAV is supported, got {sample_width * 8}-bit")
    values = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    values = values.reshape(-1, channels)
    return values, rate


def mono(samples: np.ndarray) -> np.ndarray:
    if samples.ndim == 1:
        return samples.astype(np.float32, copy=False)
    return np.mean(samples, axis=1, dtype=np.float32)


def resample_linear(samples: np.ndarray, source_rate: int, target_rate: int) -> np.ndarray:
    if source_rate == target_rate:
        return samples.astype(np.float32, copy=True)
    output_count = max(1, int(round(samples.shape[0] * target_rate / source_rate)))
    source_positions = np.arange(output_count, dtype=np.float64) * source_rate / target_rate
    left = np.minimum(source_positions.astype(np.int64), samples.shape[0] - 1)
    right = np.minimum(left + 1, samples.shape[0] - 1)
    fraction = source_positions - left
    if samples.ndim == 1:
        return ((1.0 - fraction) * samples[left] + fraction * samples[right]).astype(np.float32)
    return ((1.0 - fraction[:, None]) * samples[left] + fraction[:, None] * samples[right]).astype(np.float32)
