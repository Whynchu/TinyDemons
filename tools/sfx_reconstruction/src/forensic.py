"""Deep, confidence-tagged forensic analysis for one-shot SFX."""

from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np

from .audio_io import mono, read_wav, resample_linear
from .analyze import ANALYSIS_RATE
from .recipe import validate_recipe


def _trim(signal: np.ndarray) -> tuple[np.ndarray, int, int]:
    threshold = max(1e-8, float(np.max(np.abs(signal))) * 0.002)
    active = np.flatnonzero(np.abs(signal) >= threshold)
    if not active.size:
        return signal[:0], 0, 0
    first, last = int(active[0]), int(active[-1]) + 1
    return signal[first:last], first, last


def _stft(signal: np.ndarray, size: int, hop: int) -> tuple[np.ndarray, np.ndarray]:
    if signal.size < size:
        signal = np.pad(signal, (0, size - signal.size))
    starts = np.arange(0, max(1, signal.size - size + 1), hop)
    frames = np.lib.stride_tricks.sliding_window_view(signal, size)[starts]
    return np.fft.rfft(frames * np.hanning(size), axis=1), starts


def _peak_frame(spectrum: np.ndarray, rate: int, size: int, limit: int = 12) -> list[dict]:
    magnitude = np.abs(spectrum)
    if magnitude.size < 3:
        return []
    candidates = np.flatnonzero((magnitude[1:-1] > magnitude[:-2]) & (magnitude[1:-1] >= magnitude[2:])) + 1
    candidates = candidates[np.argsort(magnitude[candidates])[::-1]]
    selected: list[dict] = []
    maximum = max(float(np.max(magnitude)), 1e-12)
    for index in candidates:
        if index < 2 or float(magnitude[index] / maximum) < 0.025 or any(abs(int(index) - int(item["bin"])) < 3 for item in selected):
            continue
        left = np.log(max(float(magnitude[index - 1]), 1e-12))
        center = np.log(max(float(magnitude[index]), 1e-12))
        right = np.log(max(float(magnitude[index + 1]), 1e-12))
        denominator = left - 2.0 * center + right
        offset = 0.0 if abs(denominator) < 1e-9 else 0.5 * (left - right) / denominator
        selected.append({
            "bin": int(index),
            "frequency_hz": round(float((index + offset) * rate / size), 5),
            "magnitude": round(float(magnitude[index] / maximum), 8),
            "phase_radians": round(float(np.angle(spectrum[index])), 8),
        })
        if len(selected) >= limit:
            break
    return selected


def _track_peaks(
    frames: list[list[dict]],
    hop: int,
    max_jump_hz: float = 180.0,
    min_points: int = 8,
) -> list[dict]:
    tracks: list[dict] = []
    active: dict[int, dict] = {}
    next_id = 0
    for frame_index, peaks in enumerate(frames):
        used: set[int] = set()
        for track_id, track in list(active.items()):
            if not peaks:
                continue
            distances = [abs(float(peak["frequency_hz"]) - float(track["last_frequency_hz"])) if index not in used else 1e9 for index, peak in enumerate(peaks)]
            nearest = int(np.argmin(distances))
            if distances[nearest] <= max_jump_hz:
                peak = peaks[nearest]
                used.add(nearest)
                track["points"].append({"frame": frame_index, **peak})
                track["last_frequency_hz"] = peak["frequency_hz"]
            else:
                track["last_seen_frame"] = frame_index - 1
                tracks.append(track)
                del active[track_id]
        for index, peak in enumerate(peaks):
            if index in used:
                continue
            active[next_id] = {
                "track_id": next_id,
                "first_frame": frame_index,
                "last_seen_frame": frame_index,
                "last_frequency_hz": peak["frequency_hz"],
                "points": [{"frame": frame_index, **peak}],
            }
            next_id += 1
    tracks.extend(active.values())
    # Long FFT windows can yield only a handful of frames for short UI sounds.
    # Keep those tracks when they are supported by at least three observations;
    # callers can still demand a stricter threshold for long recordings.
    useful = [track for track in tracks if len(track["points"]) >= min_points]
    for track in useful:
        frequencies = np.array([point["frequency_hz"] for point in track["points"]], dtype=np.float64)
        magnitudes = np.array([point["magnitude"] for point in track["points"]], dtype=np.float64)
        phases = np.unwrap(np.array([point["phase_radians"] for point in track["points"]], dtype=np.float64))
        track["summary"] = {
            "duration_frames": len(frequencies),
            "start_frequency_hz": round(float(frequencies[0]), 5),
            "end_frequency_hz": round(float(frequencies[-1]), 5),
            "frequency_span_hz": round(float(np.max(frequencies) - np.min(frequencies)), 5),
            "peak_magnitude": round(float(np.max(magnitudes)), 8),
            "mean_magnitude": round(float(np.mean(magnitudes)), 8),
            "phase_start_radians": round(float(phases[0]), 6),
            "phase_end_radians": round(float(phases[-1]), 6),
            "instantaneous_frequency_hz": round(float(np.median(np.diff(phases)) / (2.0 * np.pi) * 22050.0 / hop), 5) if len(phases) > 1 else round(float(frequencies[0]), 5),
            "confidence": round(float(min(1.0, len(frequencies) / 24.0) * (1.0 - min(1.0, np.std(np.diff(frequencies)) / 120.0)) * (1.0 - min(1.0, np.std(np.diff(phases)) / 2.0))), 6),
        }
        track.pop("last_frequency_hz", None)
        track.pop("last_seen_frame", None)
    return useful


def _cross_resolution_agreement(resolutions: dict) -> list[dict]:
    reference_tracks = resolutions.get("4096", {}).get("tracks", [])
    agreement = []
    for track in reference_tracks:
        summary = track["summary"]
        matches = []
        for resolution_name, resolution in resolutions.items():
            if resolution_name == "4096":
                continue
            for candidate in resolution.get("tracks", []):
                candidate_summary = candidate["summary"]
                if abs(float(candidate_summary["start_frequency_hz"]) - float(summary["start_frequency_hz"])) < 90.0 and abs(float(candidate_summary["end_frequency_hz"]) - float(summary["end_frequency_hz"])) < 120.0:
                    matches.append({"resolution": resolution_name, "track_id": candidate["track_id"]})
                    break
        agreement.append({
            "track_id": track["track_id"],
            "frequency_hz": summary["start_frequency_hz"],
            "matches": matches,
            "agreement_count": len(matches),
            "confidence": round(float(min(1.0, (len(matches) + 1) / 3.0) * summary["confidence"]), 6),
        })
    return agreement


def _region_labels(rms: np.ndarray, flux: np.ndarray, hop: int, rate: int) -> list[dict]:
    if not rms.size:
        return []
    peak = float(np.max(rms))
    peak_index = int(np.argmax(rms))
    after_peak = np.flatnonzero(rms[peak_index:] <= peak * 0.8)
    attack_end = peak_index + int(after_peak[0]) if after_peak.size else min(len(rms) - 1, peak_index + 1)
    tail_candidates = np.flatnonzero(rms[max(attack_end, 0):] <= peak * 0.2)
    tail_start = attack_end + int(tail_candidates[0]) if tail_candidates.size else max(attack_end + 1, len(rms) - 1)
    return [
        {"label": "attack", "start_seconds": 0.0, "end_seconds": round(attack_end * hop / rate, 6), "confidence": 0.82, "method": "rms_80_percent"},
        {"label": "body", "start_seconds": round(attack_end * hop / rate, 6), "end_seconds": round(tail_start * hop / rate, 6), "confidence": 0.68, "method": "rms_between_80_and_20_percent"},
        {"label": "tail", "start_seconds": round(tail_start * hop / rate, 6), "end_seconds": round(len(rms) * hop / rate, 6), "confidence": 0.78, "method": "rms_below_20_percent"},
    ]


def analyze_forensic(path: str | Path) -> dict:
    path = Path(path)
    channels, source_rate = read_wav(path)
    source = mono(channels)
    normalized = resample_linear(source, source_rate, ANALYSIS_RATE)
    active, first, last = _trim(normalized)
    resolutions = {}
    for size, hop in ((256, 32), (1024, 128), (4096, 512)):
        spectra, starts = _stft(active, size, hop)
        magnitudes = np.abs(spectra)
        power = np.square(magnitudes)
        rms = np.sqrt(np.mean(np.square(np.lib.stride_tricks.sliding_window_view(np.pad(active, (0, max(0, size - active.size % hop))), size)[starts]), axis=1))
        normalized_power = power / np.maximum(np.sum(power, axis=1, keepdims=True), 1e-12)
        flux = np.concatenate(([0.0], np.sqrt(np.mean(np.square(np.diff(normalized_power, axis=0)), axis=1))))
        centroid = np.sum(normalized_power * np.arange(normalized_power.shape[1])[None, :], axis=1) * ANALYSIS_RATE / size
        flatness = np.exp(np.mean(np.log(np.maximum(magnitudes, 1e-12)), axis=1)) / np.maximum(np.mean(magnitudes, axis=1), 1e-12)
        frame_peaks = [_peak_frame(spectra[index], ANALYSIS_RATE, size) for index in range(len(spectra))]
        resolutions[str(size)] = {
            "frame_size": size,
            "hop_size": hop,
            "frames": [
                {
                    "time_seconds": round(float((first + starts[index]) / ANALYSIS_RATE), 6),
                    "rms": round(float(rms[index]), 8),
                    "spectral_flux": round(float(flux[index]), 8),
                    "spectral_centroid_hz": round(float(centroid[index]), 5),
                    "spectral_flatness": round(float(flatness[index]), 8),
                    "peaks": frame_peaks[index],
                }
                for index in range(len(spectra))
            ],
            "tracks": _track_peaks(
                frame_peaks,
                hop,
                min_points=max(3, min(8, len(frame_peaks) // 3)),
            ),
            "regions": _region_labels(rms, flux, hop, ANALYSIS_RATE),
        }
    cross_resolution = _cross_resolution_agreement(resolutions)
    return {
        "format": "tiny_demons_forensic_analysis",
        "version": 1,
        "source": {
            "filename": path.name,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "source_rate": int(source_rate),
            "source_channels": int(channels.shape[1] if channels.ndim == 2 else 1),
            "container_duration_seconds": round(float(source.size / source_rate), 6),
            "active_start_seconds": round(float(first / ANALYSIS_RATE), 6),
            "active_duration_seconds": round(float(active.size / ANALYSIS_RATE), 6),
        },
        "method": {
            "analysis_rate": ANALYSIS_RATE,
            "resolutions": [256, 1024, 4096],
            "phase": "complex_stft_bin_phase",
            "peak_interpolation": "quadratic_log_magnitude",
            "track_linking": "greedy_frequency_continuity",
        },
        "semantic_regions": resolutions["1024"]["regions"],
        "cross_resolution_tracks": cross_resolution,
        "resolutions": resolutions,
    }


def fit_forensic_recipe(analysis: dict, source_path: str | Path, recipe_id: str = "sys-click_forensic") -> dict:
    """Fit a recipe from persistent 4096-resolution tracks only."""
    channels, source_rate = read_wav(source_path)
    signal = resample_linear(mono(channels), source_rate, ANALYSIS_RATE)
    active, _, _ = _trim(signal)
    resolution = analysis["resolutions"]["4096"]
    candidates = []
    for track in resolution["tracks"]:
        summary = track["summary"]
        # 4096-point windows are sparse on short UI sounds; three coherent
        # observations are enough when confidence is still strong.
        if summary["confidence"] < 0.18 or summary["duration_frames"] < 3:
            continue
        candidates.append(track)
    candidates.sort(key=lambda item: (float(item["summary"]["mean_magnitude"]), item["summary"]["duration_frames"]), reverse=True)
    candidates = candidates[:5]
    modes = []
    for track in candidates:
        points = track["points"]
        frequencies = np.array([float(point["frequency_hz"]) for point in points], dtype=np.float64)
        magnitudes = np.array([float(point["magnitude"]) for point in points], dtype=np.float64)
        times = np.array([float(point["frame"]) * resolution["hop_size"] / ANALYSIS_RATE for point in points], dtype=np.float64)
        drift = float(np.polyfit(times, frequencies, 1)[0]) if len(points) >= 2 else 0.0
        mode_start = float(times[0])
        mode_end = float(times[-1])
        decay = max(0.012, min(0.5, (mode_end - mode_start) * 0.8))
        instantaneous = max(40.0, float(frequencies[0]))
        gain, phase = float(np.max(magnitudes)), 0.0
        modes.append({
            "start_seconds": round(mode_start, 6),
            "frequency_hz": round(instantaneous, 5),
            "gain": round(float(np.clip(gain * 5.0, 0.004, 1.0)), 6),
            "phase": round(phase, 6),
            "attack_seconds": 0.001,
            "decay_seconds": round(decay, 6),
            "drift_hz_per_second": round(drift, 5),
            "trajectory": [[round(float(time_value - mode_start), 6), round(float(freq), 5)] for time_value, freq in zip(times, frequencies) if float(time_value - mode_start) >= 0.0],
        })
    if modes:
        # Jointly fit all modes so correlated resonances share the error budget
        # instead of each independently explaining the same body energy.
        fit_count = min(active.size, int(0.22 * ANALYSIS_RATE))
        fit_time = np.arange(fit_count, dtype=np.float64) / ANALYSIS_RATE
        columns = []
        for mode in modes:
            local = fit_time - float(mode["start_seconds"])
            active_mode = local >= 0.0
            local = np.maximum(local, 0.0)
            decay = max(0.012, float(mode["decay_seconds"]))
            envelope = np.exp(-local / decay) * active_mode
            phase_base = 2.0 * np.pi * (float(mode["frequency_hz"]) * local + 0.5 * float(mode["drift_hz_per_second"]) * local * local)
            columns.extend((np.sin(phase_base) * envelope, np.cos(phase_base) * envelope))
        matrix = np.column_stack(columns)
        coefficients, _, _, _ = np.linalg.lstsq(matrix, active[:fit_count], rcond=None)
        for index, mode in enumerate(modes):
            sine_coefficient = float(coefficients[index * 2])
            cosine_coefficient = float(coefficients[index * 2 + 1])
            mode["gain"] = round(float(np.clip(np.hypot(sine_coefficient, cosine_coefficient) * 5.0, 0.004, 1.0)), 6)
            mode["phase"] = round(float(np.arctan2(cosine_coefficient, sine_coefficient)), 6)
    duration = float(analysis["source"]["active_duration_seconds"])
    recipe = {
        "format": "tiny_demons_sfx_recipe",
        "version": 1,
        "id": recipe_id,
        "source_role": "ui_click_forensic_reconstruction",
        "render": {"sample_rate": ANALYSIS_RATE, "channels": 1, "duration_seconds": duration, "seed": 18427},
        "events": [{
            "start_seconds": 0.0,
            "duration_seconds": duration,
            "gain_db": 0.0,
            "pan": 0.0,
            "envelope": [[0.0, 1.0], [duration, 0.0]],
            "transient": {"type": "filtered_noise_impulse", "duration_seconds": 0.010, "decay_seconds": 0.003, "gain": 0.12},
            "modes": modes,
            "residual": {"type": "procedural_filtered_noise", "gain": 0.012, "decay_seconds": min(0.5, duration * 0.55)},
            "processing": {},
        }],
        "processing": {"drive": 1.0, "quantization_bits": 12},
        "fit": {"method": "persistent_4096_stft_tracks_and_least_squares", "analysis_source": analysis["source"]["sha256"], "mode_count": len(modes)},
    }
    validate_recipe(recipe)
    return recipe
