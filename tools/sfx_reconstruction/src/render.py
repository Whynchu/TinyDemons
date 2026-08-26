"""Deterministic recipe renderer; reference audio is never read here."""

from __future__ import annotations

import json
import wave
from pathlib import Path

import numpy as np


def _envelope(points: list[list[float]], times: np.ndarray) -> np.ndarray:
    if not points:
        return np.ones_like(times)
    ordered = sorted((float(t), float(v)) for t, v in points)
    return np.interp(times, [p[0] for p in ordered], [p[1] for p in ordered], left=ordered[0][1], right=ordered[-1][1])


def _pan_gains(pan: float) -> tuple[float, float]:
    angle = (float(np.clip(pan, -1.0, 1.0)) + 1.0) * np.pi / 4.0
    return float(np.cos(angle)), float(np.sin(angle))


def render_recipe(recipe: dict) -> np.ndarray:
    render = recipe["render"]
    rate = int(render["sample_rate"])
    channels = int(render["channels"])
    frame_count = int(round(float(render["duration_seconds"]) * rate))
    rng = np.random.default_rng(int(render.get("seed", 0)))
    output = np.zeros((frame_count, channels), dtype=np.float64)
    time = np.arange(frame_count, dtype=np.float64) / rate

    for event in recipe.get("events", []):
        start = max(0.0, float(event.get("start_seconds", 0.0)))
        duration = max(1e-5, float(event.get("duration_seconds", 0.1)))
        first = int(round(start * rate))
        last = min(frame_count, first + int(round(duration * rate)))
        if first >= last:
            continue
        local = time[first:last] - start
        gain = 10.0 ** (float(event.get("gain_db", 0.0)) / 20.0)
        env = _envelope(event.get("envelope", [[0.0, 0.0], [0.005, 1.0], [duration, 0.0]]), local)
        signal = np.zeros(last - first, dtype=np.float64)

        transient = event.get("transient", {})
        transient_decay = max(1e-5, float(transient.get("decay_seconds", 0.008)))
        transient_duration = max(1e-5, float(transient.get("duration_seconds", 0.015)))
        transient_env = np.exp(-local / transient_decay) * (local <= transient_duration)
        signal += rng.normal(0.0, 1.0, local.size) * transient_env * float(transient.get("gain", 0.25))

        for mode in event.get("modes", []):
            frequency = max(1.0, float(mode.get("frequency_hz", 440.0)))
            drift = float(mode.get("drift_hz_per_second", 0.0))
            phase = float(mode.get("phase", 0.0))
            mode_start = float(mode.get("start_seconds", 0.0))
            mode_local = local - mode_start
            mode_active = mode_local >= 0.0
            mode_local = np.maximum(mode_local, 0.0)
            mode_attack = max(1e-5, float(mode.get("attack_seconds", 0.001)))
            mode_decay = max(1e-5, float(mode.get("decay_seconds", duration)))
            mode_env = (1.0 - np.exp(-mode_local / mode_attack)) * np.exp(-mode_local / mode_decay) * mode_active
            trajectory = mode.get("trajectory")
            if trajectory:
                points = sorted(trajectory, key=lambda point: float(point[0]))
                point_times = np.array([float(point[0]) for point in points])
                point_freqs = np.array([float(point[1]) for point in points])
                frequency_curve = np.interp(mode_local, point_times, point_freqs, left=point_freqs[0], right=point_freqs[-1])
                phase_curve = 2.0 * np.pi * np.cumsum(frequency_curve) / rate + phase
                mode_signal = np.sin(phase_curve)
            else:
                mode_phase = 2.0 * np.pi * (frequency * mode_local + 0.5 * drift * mode_local * mode_local) + phase
                mode_signal = np.sin(mode_phase)
            signal += mode_signal * mode_env * float(mode.get("gain", 0.0))

        for layer in event.get("layers", []):
            layer_env = _envelope(layer.get("envelope", []), local)
            kind = layer.get("kind", "band_noise")
            if kind == "sine":
                frequency = max(1.0, float(layer.get("frequency_hz", 440.0)))
                decay = max(1e-5, float(layer.get("decay_seconds", duration)))
                signal += np.sin(2.0 * np.pi * frequency * local + float(layer.get("phase", 0.0))) * np.exp(-local / decay) * layer_env * float(layer.get("gain", 0.0))
            elif kind == "band_noise":
                noise = rng.normal(0.0, 1.0, local.size)
                if local.size > 8:
                    spectrum = np.fft.rfft(noise)
                    frequencies = np.fft.rfftfreq(local.size, 1.0 / rate)
                    spectrum[(frequencies < float(layer.get("low_hz", 20.0))) | (frequencies > float(layer.get("high_hz", rate / 2.0)))] = 0.0
                    noise = np.fft.irfft(spectrum, n=local.size)
                    noise /= max(1e-9, float(np.std(noise)))
                signal += noise * layer_env * float(layer.get("gain", 0.0))
            elif kind == "glow_tail":
                density = max(1, int(layer.get("density", 12)))
                low = float(layer.get("low_hz", 1800.0))
                high = float(layer.get("high_hz", 8500.0))
                decay = max(1e-5, float(layer.get("decay_seconds", 0.35)))
                onset = max(0.0, float(layer.get("onset_seconds", 0.025)))
                taps = max(1, int(layer.get("taps", 4)))
                shimmer = np.zeros_like(local)
                for tap in range(taps):
                    tap_onset = onset + tap * float(layer.get("tap_spacing_seconds", 0.006))
                    active = local >= tap_onset
                    tail_time = np.maximum(local - tap_onset, 0.0)
                    tap_decay = decay * (1.0 - 0.08 * tap)
                    tail_env = np.exp(-tail_time / max(1e-5, tap_decay)) * active * layer_env
                    tap_high = high * (1.0 - 0.10 * tap)
                    frequencies = rng.uniform(low, max(low + 1.0, tap_high), density)
                    phases = rng.uniform(-np.pi, np.pi, density)
                    cloud = np.zeros_like(local)
                    for frequency, phase in zip(frequencies, phases):
                        cloud += np.sin(2.0 * np.pi * frequency * tail_time + phase)
                    shimmer += cloud / np.sqrt(float(density)) * tail_env / np.sqrt(float(taps))
                signal += shimmer * float(layer.get("gain", 0.0))

        residual = event.get("residual", {})
        residual_decay = max(1e-5, float(residual.get("decay_seconds", duration)))
        residual_env = np.exp(-local / residual_decay)
        if residual.get("envelope"):
            residual_env *= _envelope(residual["envelope"], local)
        residual_noise = rng.normal(0.0, 1.0, local.size)
        if residual.get("type") == "band_limited_noise" and local.size > 8:
            spectrum = np.fft.rfft(residual_noise)
            frequencies = np.fft.rfftfreq(local.size, 1.0 / rate)
            low = float(residual.get("low_hz", 20.0))
            high = float(residual.get("high_hz", rate / 2.0))
            spectrum[(frequencies < low) | (frequencies > high)] = 0.0
            residual_noise = np.fft.irfft(spectrum, n=local.size)
            residual_noise /= max(1e-9, float(np.std(residual_noise)))
        signal += residual_noise * residual_env * float(residual.get("gain", 0.0))
        signal *= env * gain
        left_gain, right_gain = _pan_gains(float(event.get("pan", 0.0)))
        if channels == 1:
            output[first:last, 0] += signal
        else:
            output[first:last, 0] += signal * left_gain
            output[first:last, 1] += signal * right_gain

    processing = recipe.get("processing", {})
    drive = max(0.0, float(processing.get("drive", 1.0)))
    if drive != 1.0:
        output = np.tanh(output * drive) / max(1e-12, np.tanh(drive))
    quantization_bits = processing.get("quantization_bits")
    if quantization_bits is not None:
        steps = float(2 ** int(quantization_bits - 1) - 1)
        output = np.round(np.clip(output, -1.0, 1.0) * steps) / steps
    peak = float(np.max(np.abs(output)))
    if peak > 0.98:
        output *= 0.98 / peak
    return output.astype(np.float32)


def write_wav(path: str | Path, samples: np.ndarray, sample_rate: int) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if samples.ndim == 1:
        samples = samples[:, None]
    pcm = np.clip(samples, -1.0, 1.0)
    pcm = np.rint(pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(samples.shape[1])
        handle.setsampwidth(2)
        handle.setframerate(int(sample_rate))
        handle.writeframes(pcm.tobytes())


def render_json(recipe_path: str | Path, output_path: str | Path) -> None:
    recipe = json.loads(Path(recipe_path).read_text(encoding="utf-8"))
    samples = render_recipe(recipe)
    write_wav(output_path, samples, int(recipe["render"]["sample_rate"]))
