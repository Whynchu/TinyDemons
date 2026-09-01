"""Audio I/O and canonicalization helpers.

The canonical working format is mono float32 at 48 kHz. The original file is
never modified; all transforms are recorded as a small canonicalization record.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
import soundfile as sf

from ..exceptions import SfxLabError

CANONICAL_RATE = 48000


def read_wav(path: str | Path) -> tuple[np.ndarray, int]:
    """Return (samples, sample_rate). Samples are float in [-1, 1]."""
    path = Path(path)
    if not path.exists():
        raise SfxLabError(f"audio file not found: {path}")
    data, rate = sf.read(str(path), always_2d=True)
    if data.shape[0] == 0:
        raise SfxLabError(f"audio file is empty: {path}")
    return np.asarray(data, dtype=np.float32), int(rate)


def mono(samples: np.ndarray) -> np.ndarray:
    """Mid channel: average stereo to mono without dropping phase content."""
    if samples.ndim == 1 or samples.shape[1] == 1:
        return samples.reshape(-1).astype(np.float32, copy=True)
    return np.mean(samples, axis=1, dtype=np.float32)


def resample(samples: np.ndarray, source_rate: int, target_rate: int) -> np.ndarray:
    if source_rate == target_rate:
        return samples.astype(np.float32, copy=True)
    from scipy.signal import resample_poly

    gcd = int(np.gcd(source_rate, target_rate))
    return resample_poly(samples, target_rate // gcd, source_rate // gcd).astype(np.float32)


def trim_silence(samples: np.ndarray, threshold_ratio: float = 0.006, pad_samples: int = 32) -> tuple[np.ndarray, int, int]:
    """Trim leading/trailing near-silence. Returns (trimmed, first, last)."""
    if samples.size == 0:
        return samples, 0, 0
    threshold = max(1e-7, float(np.max(np.abs(samples))) * threshold_ratio)
    active = np.flatnonzero(np.abs(samples) >= threshold)
    if active.size == 0:
        return samples[:0], 0, 0
    first = max(0, int(active[0]) - pad_samples)
    last = min(samples.size, int(active[-1]) + 1 + pad_samples)
    return samples[first:last], first, last


def canonicalize(samples: np.ndarray, rate: int) -> tuple[np.ndarray, dict]:
    """Return (mono-float32 at 48k, canonicalization record)."""
    record: dict = {"source_rate_hz": rate, "channels_before_mono": samples.shape[1] if samples.ndim > 1 else 1}
    mono_samples = mono(samples)
    if rate != CANONICAL_RATE:
        mono_samples = resample(mono_samples, rate, CANONICAL_RATE)
        record["resampled_to_hz"] = CANONICAL_RATE
    trimmed, first, _ = trim_silence(mono_samples)
    record["trimmed_from"] = first
    record["trimmed_to"] = first + trimmed.size
    if float(np.max(np.abs(trimmed))) > 0.0:
        peak = float(np.max(np.abs(trimmed)))
        record["peak_normalize_dbfs"] = -1.0
        trimmed = trimmed * (10.0 ** (-1.0 / 20.0) / peak)
    record["duration_s"] = round(trimmed.size / CANONICAL_RATE, 6)
    record["sample_rate_hz"] = CANONICAL_RATE
    return np.asarray(trimmed, dtype=np.float32), record


def write_wav(path: str | Path, samples: np.ndarray, rate: int) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(samples, -1.0, 1.0)
    sf.write(str(path), np.asarray(clipped, dtype=np.float32), rate)


def file_sha256(path: str | Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 16), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path: str | Path, value) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True), encoding="utf-8")