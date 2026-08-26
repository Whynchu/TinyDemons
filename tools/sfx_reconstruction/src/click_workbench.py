"""High-resolution, click-specific analysis and recipe fitting."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .analyze import ANALYSIS_RATE
from .audio_io import mono, read_wav, resample_linear
from .recipe import validate_recipe


def _trim(signal: np.ndarray) -> tuple[np.ndarray, int]:
    threshold = max(1e-7, float(np.max(np.abs(signal))) * 0.003)
    active = np.flatnonzero(np.abs(signal) >= threshold)
    if not active.size:
        return signal[:0], 0
    first, last = int(active[0]), int(active[-1]) + 1
    return signal[first:last], first


def _frames(signal: np.ndarray, frame: int = 256, hop: int = 32) -> tuple[np.ndarray, np.ndarray]:
    if signal.size < frame:
        signal = np.pad(signal, (0, frame - signal.size))
    starts = np.arange(0, max(1, signal.size - frame + 1), hop)
    window = np.hanning(frame)
    framed = np.lib.stride_tricks.sliding_window_view(signal, frame)[starts] * window
    return framed, starts


def _peaks(spectrum: np.ndarray, rate: int, fft_size: int, count: int = 8) -> list[dict]:
    magnitude = np.abs(spectrum)
    if magnitude.size < 3:
        return []
    candidates = np.flatnonzero((magnitude[1:-1] > magnitude[:-2]) & (magnitude[1:-1] >= magnitude[2:])) + 1
    candidates = candidates[np.argsort(magnitude[candidates])[::-1]]
    selected: list[dict] = []
    for index in candidates:
        if index <= 1 or index >= magnitude.size - 1:
            continue
        if any(abs(int(index) - int(item["bin"])) < 4 for item in selected):
            continue
        left = np.log(max(float(magnitude[index - 1]), 1e-12))
        center = np.log(max(float(magnitude[index]), 1e-12))
        right = np.log(max(float(magnitude[index + 1]), 1e-12))
        denominator = left - 2.0 * center + right
        offset = 0.0 if abs(denominator) < 1e-9 else 0.5 * (left - right) / denominator
        selected.append({
            "bin": int(index),
            "frequency_hz": round(float((index + offset) * rate / fft_size), 4),
            "gain": round(float(magnitude[index] / max(float(np.max(magnitude)), 1e-9)), 6),
        })
        if len(selected) >= count:
            break
    return selected


def analyze_click(path: str | Path) -> dict:
    path = Path(path)
    channels, source_rate = read_wav(path)
    signal = resample_linear(mono(channels), source_rate, ANALYSIS_RATE)
    active, first = _trim(signal)
    frame_size, hop, fft_size = 256, 32, 2048
    frames, starts = _frames(active, frame_size, hop)
    spectra = np.fft.rfft(frames, n=fft_size, axis=1)
    magnitudes = np.abs(spectra)
    rms = np.sqrt(np.mean(np.square(frames), axis=1))
    flux = np.concatenate(([0.0], np.sqrt(np.mean(np.square(np.diff(magnitudes / np.maximum(np.sum(magnitudes, axis=1, keepdims=True), 1e-9), axis=0)), axis=1))))
    threshold = max(float(np.max(rms)) * 0.012, 1e-7)
    active_frames = rms >= threshold
    events: list[dict] = []
    run_start: int | None = None
    for index, is_active in enumerate(active_frames):
        if is_active and run_start is None:
            run_start = index
        elif not is_active and run_start is not None:
            events.append({"first_frame": run_start, "last_frame": index})
            run_start = None
    if run_start is not None:
        events.append({"first_frame": run_start, "last_frame": len(active_frames)})
    minimum_gap = max(1, int(round(0.018 * ANALYSIS_RATE / hop)))
    merged_events: list[dict] = []
    for event in events:
        if merged_events and int(event["first_frame"]) - int(merged_events[-1]["last_frame"]) < minimum_gap:
            merged_events[-1]["last_frame"] = event["last_frame"]
        else:
            merged_events.append(event)
    return {
        "format": "tiny_demons_click_analysis",
        "version": 1,
        "source": {"filename": path.name, "source_rate": int(source_rate), "sha256": _sha256(path)},
        "analysis": {
            "analysis_rate": ANALYSIS_RATE,
            "active_start_seconds": round(first / ANALYSIS_RATE, 6),
            "active_duration_seconds": round(active.size / ANALYSIS_RATE, 6),
            "frame_size": frame_size,
            "hop_size": hop,
            "fft_size": fft_size,
            "events": merged_events,
            "frames": [
                {
                    "time_seconds": round(float((first + starts[i]) / ANALYSIS_RATE), 6),
                    "rms": round(float(rms[i]), 8),
                    "flux": round(float(flux[i]), 8),
                    "peaks": _peaks(spectra[i], ANALYSIS_RATE, fft_size),
                }
                for i in range(len(frames))
            ],
        },
    }


def fit_click_recipe(analysis: dict, source_path: str | Path | None = None, recipe_id: str = "sys-click_workbench") -> dict:
    info = analysis["analysis"]
    frames = info["frames"]
    duration = max(0.02, float(info["active_duration_seconds"]))
    source_signal = None
    if source_path is not None:
        channels, source_rate = read_wav(source_path)
        source_signal = resample_linear(mono(channels), source_rate, ANALYSIS_RATE)
        source_signal, _ = _trim(source_signal)
    events = []
    source_events = info.get("events") or [{"first_frame": 0, "last_frame": len(frames)}]
    for event in source_events:
        first_frame = int(event["first_frame"])
        last_frame = min(len(frames), int(event["last_frame"]))
        local_frames = frames[first_frame:last_frame]
        if not local_frames:
            continue
        # The first few frames are attack-heavy. Initialize modal body from a
        # later stable frame so the transient does not become the tonal model.
        first_peaks = local_frames[min(8, len(local_frames) - 1)]["peaks"]
        modes = []
        for rank, peak in enumerate(first_peaks[:4]):
            if float(peak["frequency_hz"]) < 80.0:
                continue
            mode = {
                "frequency_hz": peak["frequency_hz"],
                "gain": min(1.0, max(0.02, float(peak["gain"]) * (0.75 ** rank))),
                "phase": 0.0,
                "attack_seconds": 0.0006 + rank * 0.00025,
                "decay_seconds": max(0.012, duration * (0.20 - rank * 0.012)),
                "drift_hz_per_second": 0.0,
            }
            modes.append(mode)
        start_time = float(local_frames[0]["time_seconds"]) - float(info["active_start_seconds"])
        event_duration = max(0.02, float(local_frames[-1]["time_seconds"]) - float(local_frames[0]["time_seconds"]) + 0.02)
        if source_signal is not None and modes:
            modes = _fit_body_modes(source_signal, start_time, event_duration, modes)
        events.append({
            "start_seconds": max(0.0, start_time),
            "duration_seconds": min(duration, event_duration),
            "gain_db": 0.0,
            "pan": 0.0,
            "envelope": [[0.0, 0.0], [0.0015, 1.0], [event_duration, 0.0]],
            "transient": {"type": "filtered_noise_impulse", "duration_seconds": 0.009, "decay_seconds": 0.0028, "gain": 0.16},
            "modes": modes,
            "residual": {"type": "procedural_filtered_noise", "gain": 0.015, "decay_seconds": min(0.4, duration * 0.55)},
            "processing": {},
        })
    recipe = {
        "format": "tiny_demons_sfx_recipe",
        "version": 1,
        "id": recipe_id,
        "source_role": "ui_click_faithful_reconstruction",
        "render": {"sample_rate": ANALYSIS_RATE, "channels": 1, "duration_seconds": duration, "seed": 18427},
        "events": events,
        "processing": {"drive": 1.0, "quantization_bits": 12},
        "fit": {"method": "frame_tracked_spectral_peaks", "analysis_source": analysis["source"]["sha256"]},
    }
    validate_recipe(recipe)
    return recipe


def _fit_body_modes(signal: np.ndarray, start_time: float, duration: float, modes: list[dict]) -> list[dict]:
    """Fit sine/cosine coefficients so recipe phase and gain match the body."""
    first = max(0, int(round(start_time * ANALYSIS_RATE)))
    last = min(signal.size, first + int(round(min(duration, 0.14) * ANALYSIS_RATE)))
    if last - first < 64:
        return modes
    local = np.arange(last - first, dtype=np.float64) / ANALYSIS_RATE
    decay = max(0.02, min(0.3, duration * 0.20))
    columns = []
    for mode in modes:
        phase = 2.0 * np.pi * float(mode["frequency_hz"]) * local
        envelope = np.exp(-local / decay)
        columns.extend((np.sin(phase) * envelope, np.cos(phase) * envelope))
    matrix = np.column_stack(columns)
    coefficients, _, _, _ = np.linalg.lstsq(matrix, signal[first:last], rcond=None)
    for index, mode in enumerate(modes):
        sine_coefficient = float(coefficients[index * 2])
        cosine_coefficient = float(coefficients[index * 2 + 1])
        gain = float(np.hypot(sine_coefficient, cosine_coefficient))
        mode["gain"] = round(float(np.clip(gain * 4.0, 0.005, 1.0)), 6)
        mode["phase"] = round(float(np.arctan2(cosine_coefficient, sine_coefficient)), 6)
        mode["decay_seconds"] = round(decay, 6)
    return modes


def _sha256(path: Path) -> str:
    import hashlib
    return hashlib.sha256(path.read_bytes()).hexdigest()
