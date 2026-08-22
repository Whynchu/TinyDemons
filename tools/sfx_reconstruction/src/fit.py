"""Analysis-guided first-pass fitting of modal/transient recipe parameters."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .analyze import ANALYSIS_RATE, analyze_wav
from .audio_io import mono, read_wav, resample_linear
from .recipe import validate_recipe


def _unique_peak_bins(magnitude: np.ndarray, count: int = 8, separation: int = 8) -> list[int]:
    candidates = np.argsort(magnitude[1:])[::-1] + 1
    selected: list[int] = []
    for candidate in candidates:
        if all(abs(int(candidate) - existing) >= separation for existing in selected):
            selected.append(int(candidate))
        if len(selected) >= count:
            break
    return selected


def _decay_seconds(signal: np.ndarray, rate: int) -> float:
    envelope = np.abs(signal)
    frame = max(16, int(rate * 0.004))
    usable = envelope[: max(frame, int(rate * 0.25))]
    if usable.size < frame * 3:
        return 0.08
    values = np.sqrt(np.mean(np.square(np.lib.stride_tricks.sliding_window_view(usable, frame)), axis=1))
    values = np.maximum(values, np.max(values) * 1e-4)
    times = np.arange(values.size) * frame / rate
    keep = (times > 0.008) & (values > np.max(values) * 0.03)
    if np.count_nonzero(keep) < 3:
        return 0.08
    slope = float(np.polyfit(times[keep], np.log(values[keep]), 1)[0])
    return float(np.clip(-1.0 / slope if slope < -1e-5 else 0.08, 0.015, 1.2))


def fit_wav(path: str | Path, recipe_id: str | None = None) -> dict:
    path = Path(path)
    channels, source_rate = read_wav(path)
    signal = resample_linear(mono(channels), source_rate, ANALYSIS_RATE)
    analysis = analyze_wav(path)
    active_start = int(round(analysis["source"]["leading_silence_seconds"] * ANALYSIS_RATE))
    active_count = max(1, int(round(analysis["source"]["active_duration_seconds"] * ANALYSIS_RATE)))
    active = signal[active_start:active_start + active_count]
    duration = max(0.02, active.size / ANALYSIS_RATE)

    fft_size = 1 << int(np.ceil(np.log2(max(1024, min(active.size, ANALYSIS_RATE // 2)))))
    spectrum = np.abs(np.fft.rfft(active[:fft_size] * np.hanning(min(active.size, fft_size)), n=fft_size))
    peak_bins = _unique_peak_bins(spectrum, count=8, separation=7)
    peak_floor = max(float(np.max(spectrum)) * 0.015, 1e-8)
    decay = _decay_seconds(active, ANALYSIS_RATE)
    modes = []
    for rank, bin_index in enumerate(peak_bins):
        magnitude = float(spectrum[bin_index])
        if magnitude < peak_floor:
            continue
        frequency = float(bin_index * ANALYSIS_RATE / fft_size)
        if frequency < 60.0 or frequency > ANALYSIS_RATE * 0.47:
            continue
        modes.append({
            "frequency_hz": round(frequency, 5),
            "gain": round(float(np.clip(magnitude / max(float(spectrum[peak_bins[0]]), 1e-8) * (0.9 ** rank), 0.02, 1.0)), 6),
            "phase": 0.0,
            "attack_seconds": 0.0015 + rank * 0.0004,
            "decay_seconds": round(float(np.clip(decay * (1.0 - rank * 0.06), 0.02, 1.2)), 6),
            "drift_hz_per_second": 0.0,
        })

    envelope = analysis["analysis"]["envelope"]
    event_end = float(envelope[-1][0]) if envelope else duration
    event_duration = max(duration, event_end)
    recipe = {
        "format": "tiny_demons_sfx_recipe",
        "version": 1,
        "id": recipe_id or f"{path.stem.lower()}_reconstruction",
        "source_role": "ui_system_reference_reconstruction",
        "render": {
            "sample_rate": ANALYSIS_RATE,
            "channels": 1,
            "duration_seconds": round(event_duration, 6),
            "seed": int.from_bytes(path.name.encode("utf-8")[:4].ljust(4, b"_"), "little"),
        },
        "events": [{
            "start_seconds": 0.0,
            "duration_seconds": round(event_duration, 6),
            "gain_db": 0.0,
            "pan": 0.0,
            "envelope": envelope or [[0.0, 0.0], [0.003, 1.0], [event_duration, 0.0]],
            "transient": {
                "type": "filtered_noise_impulse",
                "duration_seconds": 0.012,
                "decay_seconds": 0.004,
                "gain": 0.12,
            },
            "modes": modes,
            "residual": {
                "type": "procedural_filtered_noise",
                "gain": 0.018,
                "decay_seconds": round(float(np.clip(decay * 0.8, 0.02, 0.8)), 6),
            },
            "processing": {},
        }],
        "processing": {"drive": 1.0, "quantization_bits": 12},
        "fit": {
            "method": "fft_peak_and_decay_initialization",
            "source_analysis": analysis["source"]["sha256"],
            "mode_count": len(modes),
        },
    }
    validate_recipe(recipe)
    return recipe


def fit_to_json(input_path: str | Path, output_path: str | Path) -> dict:
    recipe = fit_wav(input_path)
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(recipe, indent=2), encoding="utf-8")
    return recipe
