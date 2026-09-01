"""Synthetic fixture generator for deterministic tests.

Fixtures are self-created signals with known ground truth — no licensed or
copyrighted audio. See spec section 3/15.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import soundfile as sf


def steady_sine(rate: int = 48000, duration_s: float = 0.3, frequency_hz: float = 440.0) -> np.ndarray:
    t = np.arange(int(rate * duration_s)) / rate
    env = np.minimum(t / 0.01, 1.0) * np.exp(-t * 2.0)
    return (np.sin(2.0 * np.pi * frequency_hz * t) * env).astype(np.float32)


def harmonic_stack(rate: int = 48000, duration_s: float = 0.4, fundamental_hz: float = 220.0) -> np.ndarray:
    t = np.arange(int(rate * duration_s)) / rate
    env = np.minimum(t / 0.005, 1.0) * np.exp(-t * 1.5)
    signal = np.zeros_like(t)
    for harmonic, gain in ((1, 1.0), (2, 0.6), (3, 0.4), (4, 0.2)):
        signal += gain * np.sin(2.0 * np.pi * fundamental_hz * harmonic * t)
    return (signal * env).astype(np.float32)


def rising_chirp(rate: int = 48000, duration_s: float = 0.3, start_hz: float = 200.0, end_hz: float = 1200.0) -> np.ndarray:
    t = np.arange(int(rate * duration_s)) / rate
    phase = 2.0 * np.pi * (start_hz * t + (end_hz - start_hz) * t * t / 2.0)
    env = np.minimum(t / 0.01, 1.0) * np.exp(-t * 3.0)
    return (np.sin(phase) * env).astype(np.float32)


def click_plus_body(rate: int = 48000, duration_s: float = 0.4) -> np.ndarray:
    size = int(rate * duration_s)
    t = np.arange(size) / rate
    click = np.exp(-t * 400.0) * np.random.default_rng(7).normal(0.0, 1.0, size)
    body = np.sin(2.0 * np.pi * 880.0 * t) * np.exp(-t * 4.0)
    return ((click * 0.5 + body * 0.5)).astype(np.float32)


FIXTURES = {
    "steady_sine": steady_sine,
    "harmonic_stack": harmonic_stack,
    "rising_chirp": rising_chirp,
    "click_plus_body": click_plus_body,
}


def generate(output_dir: str | Path) -> dict:
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    created: dict = {}
    for name, generator in FIXTURES.items():
        path = output_dir / f"{name}.wav"
        sf.write(str(path), generator(), 48000)
        created[name] = str(path)
    return created


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate synthetic SFX lab fixtures")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    created = generate(args.output)
    for name, path in created.items():
        print(f"{name}: {path}")