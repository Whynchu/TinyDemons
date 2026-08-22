"""Fast deterministic multiscale audio comparison for reconstruction fitting."""
from __future__ import annotations

import json
from pathlib import Path
import numpy as np
from .audio_io import mono, read_wav, resample_linear

RATE = 22050

def _features(signal: np.ndarray, frame: int, hop: int) -> tuple[np.ndarray, np.ndarray]:
    if signal.size < frame:
        signal = np.pad(signal, (0, frame - signal.size))
    count = max(1, 1 + (signal.size - frame) // hop)
    starts = np.arange(count) * hop
    windows = np.lib.stride_tricks.sliding_window_view(signal, frame)[starts] * np.hanning(frame)
    spec = np.abs(np.fft.rfft(windows, axis=1))
    spec /= np.maximum(np.sum(spec, axis=1, keepdims=True), 1e-9)
    rms = np.sqrt(np.mean(np.square(windows), axis=1))
    return rms, np.log1p(spec * 100.0)

def _compare_arrays(ref: np.ndarray, cand: np.ndarray) -> dict:
    n = max(ref.size, cand.size)
    ref = np.pad(ref, (0, n - ref.size)); cand = np.pad(cand, (0, n - cand.size))
    # Compare morphology rather than export gain or a few samples of padding.
    cand *= np.sqrt(np.sum(ref * ref) / max(np.sum(cand * cand), 1e-12))
    search = min(int(0.02 * RATE), n - 1)
    correlation = np.correlate(ref[: min(n, int(0.12 * RATE))], cand[: min(n, int(0.12 * RATE))], mode="full")
    lag = int(np.argmax(correlation) - (min(n, int(0.12 * RATE)) - 1))
    lag = int(np.clip(lag, -search, search))
    if lag > 0: cand = np.pad(cand[lag:], (0, lag))
    elif lag < 0: cand = np.pad(cand[:lag], (-lag, 0))
    waveform = float(np.mean(np.abs(ref - cand)) / max(np.mean(np.abs(ref)), 1e-9))
    components = {}
    losses = []
    for frame, hop in ((128, 32), (512, 128), (2048, 512)):
        rr, rs = _features(ref, frame, hop); cr, cs = _features(cand, frame, hop)
        envelope = float(np.mean(np.abs(rr - cr)) / max(np.mean(rr), 1e-9))
        spectral = float(np.mean(np.abs(rs - cs)))
        losses.extend((envelope, spectral))
        components[f"stft_{frame}"] = {"envelope_loss": envelope, "spectral_loss": spectral}
    # Give the attack extra weight: UI clicks are perceived primarily by onset.
    attack_n = min(n, int(0.08 * RATE))
    attack = float(np.mean(np.abs(ref[:attack_n] - cand[:attack_n])) / max(np.mean(np.abs(ref[:attack_n])), 1e-9))
    body_start, body_end = int(0.08 * RATE), min(n, int(0.30 * RATE))
    tail_start = min(n, int(0.30 * RATE))
    body = float(np.mean(np.abs(ref[body_start:body_end] - cand[body_start:body_end])) / max(np.mean(np.abs(ref[body_start:body_end])), 1e-9)) if body_end > body_start else 0.0
    tail = float(np.mean(np.abs(ref[tail_start:] - cand[tail_start:])) / max(np.mean(np.abs(ref[tail_start:])), 1e-9)) if tail_start < n else 0.0
    loss = 0.28 * attack + 0.18 * waveform + 0.54 * float(np.mean(losses))
    score = float(np.clip(100.0 * np.exp(-loss), 0.0, 100.0))
    return {"score": round(score, 5), "loss": round(loss, 7), "attack_loss": round(attack, 7),
            "body_loss": round(body, 7), "tail_loss": round(tail, 7),
            "waveform_loss": round(waveform, 7), "components": components}

def compare(reference: str | Path, candidate: str | Path) -> dict:
    ref_ch, ref_rate = read_wav(reference); cand_ch, cand_rate = read_wav(candidate)
    ref = resample_linear(mono(ref_ch), ref_rate, RATE)
    cand = resample_linear(mono(cand_ch), cand_rate, RATE)
    return _compare_arrays(ref, cand)

def compare_to_json(reference: str | Path, candidate: str | Path, output: str | Path) -> None:
    Path(output).write_text(json.dumps(compare(reference, candidate), indent=2), encoding="utf-8")
