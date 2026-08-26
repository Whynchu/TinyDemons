"""Compact structural analysis for short procedural SFX references."""

from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np

from .audio_io import mono, read_wav, resample_linear


ANALYSIS_RATE = 22050


def _rms(signal: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(signal), dtype=np.float64))) if signal.size else 0.0


def _trim(signal: np.ndarray, threshold_ratio: float = 0.006) -> tuple[np.ndarray, int, int]:
    if not signal.size:
        return signal, 0, 0
    threshold = max(1e-7, float(np.max(np.abs(signal))) * threshold_ratio)
    active = np.flatnonzero(np.abs(signal) >= threshold)
    if not active.size:
        return signal[:0], 0, 0
    first, last = int(active[0]), int(active[-1]) + 1
    return signal[first:last], first, last


def _windowed_rms(signal: np.ndarray, frame: int = 256, hop: int = 64) -> np.ndarray:
    if not signal.size:
        return np.zeros(0, dtype=np.float32)
    padded = np.pad(signal, (0, max(0, frame - signal.size % hop)))
    starts = np.arange(0, max(1, padded.size - frame + 1), hop)
    windows = np.lib.stride_tricks.sliding_window_view(padded, frame)[starts]
    return np.sqrt(np.mean(np.square(windows), axis=1)).astype(np.float32)


def _control_points(values: np.ndarray, rate: int, hop: int, count: int = 32) -> list[list[float]]:
    if not values.size:
        return []
    positions = np.linspace(0, values.size - 1, min(count, values.size)).astype(int)
    return [[round(float(position * hop / rate), 6), round(float(values[position]), 7)] for position in positions]


def _spectral_flux(signal: np.ndarray, frame: int = 512, hop: int = 128) -> np.ndarray:
    if signal.size < 2:
        return np.zeros(0, dtype=np.float32)
    padded = np.pad(signal, (0, max(0, frame - signal.size % hop)))
    starts = np.arange(0, max(1, padded.size - frame + 1), hop)
    window = np.hanning(frame)
    spectra = np.abs(np.fft.rfft(np.lib.stride_tricks.sliding_window_view(padded, frame)[starts] * window, axis=1))
    spectra /= np.maximum(np.sum(spectra, axis=1, keepdims=True), 1e-9)
    flux = np.sqrt(np.mean(np.square(np.diff(spectra, axis=0)), axis=1))
    return np.concatenate(([0.0], flux)).astype(np.float32)


def _transient_descriptors(signal: np.ndarray, frame: int = 256) -> dict:
    """Summarize attack texture without embedding source audio."""
    if not signal.size:
        return {"zero_crossing_rate": 0.0, "crest_factor": 0.0, "spectral_centroid_hz": 0.0,
                "spectral_bandwidth_hz": 0.0, "spectral_flatness": 0.0}
    window = np.hanning(min(frame, signal.size))
    chunk = signal[:window.size]
    spectrum = np.abs(np.fft.rfft(chunk * window)) + 1e-12
    frequencies = np.fft.rfftfreq(window.size, 1.0 / ANALYSIS_RATE)
    weights = spectrum / np.sum(spectrum)
    centroid = float(np.sum(frequencies * weights))
    bandwidth = float(np.sqrt(np.sum(np.square(frequencies - centroid) * weights)))
    flatness = float(np.exp(np.mean(np.log(spectrum))) / np.mean(spectrum))
    zcr = float(np.mean(np.abs(np.diff(np.signbit(chunk))))) if chunk.size > 1 else 0.0
    rms = _rms(chunk)
    return {"zero_crossing_rate": round(zcr, 7),
            "crest_factor": round(float(np.max(np.abs(chunk)) / max(rms, 1e-9)), 7),
            "spectral_centroid_hz": round(centroid, 4),
            "spectral_bandwidth_hz": round(bandwidth, 4),
            "spectral_flatness": round(flatness, 7)}


def _layer_proposals(signal: np.ndarray) -> list[dict]:
    """Return compact, overlapping layer evidence for hybrid resynthesis."""
    if not signal.size:
        return []
    spectrum = np.abs(np.fft.rfft(signal * np.hanning(signal.size))) ** 2
    frequencies = np.fft.rfftfreq(signal.size, 1.0 / ANALYSIS_RATE)
    total = max(float(np.sum(spectrum)), 1e-12)
    bands = [("low_body", 20.0, 700.0), ("mid_resonance", 700.0, 3500.0),
             ("high_attack_texture", 3500.0, 10000.0), ("air_texture", 10000.0, ANALYSIS_RATE / 2.0)]
    proposals = []
    frame, hop = 256, 64
    padded = np.pad(signal, (0, max(0, frame - signal.size % hop)))
    starts = np.arange(0, max(1, padded.size - frame + 1), hop)
    frames = np.lib.stride_tricks.sliding_window_view(padded, frame)[starts] * np.hanning(frame)
    frame_spectra = np.abs(np.fft.rfft(frames, axis=1)) ** 2
    frame_freqs = np.fft.rfftfreq(frame, 1.0 / ANALYSIS_RATE)
    for name, low, high in bands:
        mask = (frequencies >= low) & (frequencies < high)
        energy = float(np.sum(spectrum[mask]) / total) if np.any(mask) else 0.0
        frame_mask = (frame_freqs >= low) & (frame_freqs < high)
        temporal = np.sqrt(np.mean(frame_spectra[:, frame_mask], axis=1)) if np.any(frame_mask) else np.zeros(len(frames))
        temporal /= max(float(np.max(temporal)), 1e-12)
        proposals.append({"id": name, "frequency_band_hz": [low, high],
                          "energy_share": round(energy, 7),
                          "active": energy >= 0.002,
                          "confidence": round(float(min(1.0, energy * 4.0)), 7),
                          "envelope": _control_points(temporal.astype(np.float32), ANALYSIS_RATE, hop, count=24)})
    return proposals


def _events(envelope: np.ndarray, flux: np.ndarray, rate: int, hop: int) -> list[dict]:
    if not envelope.size:
        return []
    threshold = max(float(np.max(envelope)) * 0.035, 1e-7)
    active = envelope >= threshold
    # Build contiguous audible runs first. Spectral flux in a decaying tail can
    # spike repeatedly; it must not manufacture dozens of fake events.
    runs: list[list[int]] = []
    start: int | None = None
    for index, is_active in enumerate(active):
        if is_active and start is None:
            start = index
        elif not is_active and start is not None:
            runs.append([start, index])
            start = None
    if start is not None:
        runs.append([start, len(active)])
    minimum_gap = max(1, int(round(0.018 * rate / hop)))
    merged: list[list[int]] = []
    for run in runs:
        if merged and run[0] - merged[-1][1] < minimum_gap:
            merged[-1][1] = run[1]
        else:
            merged.append(run)
    if not merged:
        index = int(np.argmax(envelope))
        merged = [[index, min(len(envelope), index + 1)]]
    onsets = [run[0] for run in merged]
    result = []
    for index, onset in enumerate(onsets):
        end = merged[index][1]
        result.append({
            "start_seconds": round(onset * hop / rate, 6),
            "end_seconds": round(end * hop / rate, 6),
            "peak_rms": round(float(np.max(envelope[onset:end])), 7),
        })
    return result


def _transient_markers(flux: np.ndarray, envelope: np.ndarray, rate: int, hop: int) -> list[dict]:
    """Detect repeated attacks inside one continuous active region."""
    if flux.size < 3:
        return []
    baseline = float(np.median(flux))
    spread = float(np.median(np.abs(flux - baseline))) + 1e-9
    threshold = max(float(np.max(flux)) * 0.12, baseline + 2.5 * spread)
    minimum_distance = max(1, int(round(0.012 * rate / hop)))
    candidates = [i for i in range(1, len(flux) - 1)
                  if flux[i] >= threshold and flux[i] >= flux[i - 1] and flux[i] > flux[i + 1]]
    selected: list[int] = []
    for index in sorted(candidates, key=lambda i: float(flux[i]), reverse=True):
        if all(abs(index - prior) >= minimum_distance for prior in selected):
            selected.append(index)
    selected.sort()
    return [{
        "time_seconds": round(float(index * hop / rate), 6),
        "strength": round(float(flux[index]), 7),
        "local_rms": round(float(envelope[min(index, len(envelope) - 1)]), 7),
        "confidence": round(float(min(1.0, flux[index] / max(threshold, 1e-9))), 7),
    } for index in selected]


def analyze_wav(path: str | Path) -> dict:
    path = Path(path)
    channels, source_rate = read_wav(path)
    signal = mono(channels)
    normalized = resample_linear(signal, source_rate, ANALYSIS_RATE)
    active, first, last = _trim(normalized)
    envelope_hop = 128
    envelope = _windowed_rms(active, frame=512, hop=envelope_hop)
    flux = _spectral_flux(active, frame=512, hop=envelope_hop)
    source_hash = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        "format": "tiny_demons_sfx_analysis",
        "version": 2,
        "source": {
            "filename": path.name,
            "sha256": source_hash,
            "source_rate": int(source_rate),
            "source_channels": int(channels.shape[1] if channels.ndim == 2 else 1),
            "container_duration_seconds": round(float(signal.size / source_rate), 6),
            "active_duration_seconds": round(float(active.size / ANALYSIS_RATE), 6),
            "leading_silence_seconds": round(float(first / ANALYSIS_RATE), 6),
            "trailing_silence_seconds": round(float((normalized.size - last) / ANALYSIS_RATE), 6),
            "peak": round(float(np.max(np.abs(active))) if active.size else 0.0, 7),
            "rms": round(_rms(active), 7),
        },
        "analysis": {
            "analysis_rate": ANALYSIS_RATE,
            "envelope": _control_points(envelope, ANALYSIS_RATE, envelope_hop),
            "spectral_flux": _control_points(flux, ANALYSIS_RATE, envelope_hop),
            "events": _events(envelope, flux, ANALYSIS_RATE, envelope_hop),
            "transient_markers": _transient_markers(flux, envelope, ANALYSIS_RATE, envelope_hop),
            "transient": _transient_descriptors(active),
            "layers": _layer_proposals(active),
        },
    }
