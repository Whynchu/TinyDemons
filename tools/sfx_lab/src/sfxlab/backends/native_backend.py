"""Native NumPy/SciPy sinusoidal analysis backend.

Implements a deterministic STFT peak-picking + greedy partial tracker and a
simple residual region estimator. No AGPL dependency; fully reproducible from a
seed. This is the first backend behind the AnalysisBackend boundary.
"""

from __future__ import annotations

import numpy as np

from ..analysis.models import PartialFrame, PartialTrack, ResidualRegion, SinusoidalAnalysis

ANALYSIS_RATE = 48000
FFT_SIZE = 2048
HOP_SIZE = 256
MAGNITUDE_FLOOR_DB = -80.0
MAX_TRACKS = 160
MIN_TRACK_DURATION_MS = 12.0
PEAK_DETECTION_RADIUS = 2


class NativeBackend:
    name = "native"
    version = "0.1.0"

    def analyze(self, samples: np.ndarray, sample_rate: int) -> SinusoidalAnalysis:
        rate = sample_rate
        spec, times = _stft_magnitude(samples, rate)
        peaks = _peak_pick(spec)
        tracks = _track_partials(peaks, times, rate)
        residual_regions = _estimate_residual(spec, peaks, times)
        duration = samples.size / rate if samples.size else 0.0
        return SinusoidalAnalysis(
            tracks=tracks,
            transients=[],
            residual_regions=residual_regions,
            analysis_rate_hz=rate,
            sample_rate_hz=rate,
            backend=self.name,
            backend_version=self.version,
            duration_s=duration,
        )

    def synthesize(self, analysis: SinusoidalAnalysis, sample_rate: int) -> np.ndarray:
        return synthesize_partials(analysis.tracks, sample_rate, analysis.duration_s)

    def extract_residual(self, samples: np.ndarray, sample_rate: int, analysis: SinusoidalAnalysis) -> np.ndarray:
        synth = self.synthesize(analysis, sample_rate)
        length = min(samples.size, synth.size)
        if length <= 0:
            return np.zeros(0, dtype=np.float32)
        return np.asarray(samples[:length] - synth[:length], dtype=np.float32)


def _stft_magnitude(samples: np.ndarray, rate: int) -> tuple[np.ndarray, np.ndarray]:
    from scipy.signal import get_window, stft

    if samples.size == 0:
        return np.zeros((FFT_SIZE // 2 + 1, 1), dtype=np.float64), np.array([0.0])
    window = get_window("hann", FFT_SIZE, fftbins=True)
    _, times, spec = stft(samples, fs=rate, window=window, nperseg=FFT_SIZE, noverlap=FFT_SIZE - HOP_SIZE, padded=True)
    magnitude = np.abs(spec)
    magnitude = 20.0 * np.log10(magnitude + 1e-10)
    return magnitude, times


def _peak_pick(spec_db: np.ndarray) -> np.ndarray:
    """Boolean mask of local spectral peaks above the floor."""
    floor = np.max(spec_db) + MAGNITUDE_FLOOR_DB
    mask = spec_db >= floor
    result = np.zeros_like(mask, dtype=bool)
    for frame in range(spec_db.shape[1]):
        mag = spec_db[:, frame]
        for bin_index in range(PEAK_DETECTION_RADIUS, mag.size - PEAK_DETECTION_RADIUS):
            if not mask[bin_index, frame]:
                continue
            local = mag[bin_index - PEAK_DETECTION_RADIUS : bin_index + PEAK_DETECTION_RADIUS + 1]
            if mag[bin_index] == local.max():
                result[bin_index, frame] = True
    return result


def _track_partials(peaks: np.ndarray, times: np.ndarray, rate: int) -> list[PartialTrack]:
    """Greedy nearest-neighbor frequency tracking across frames."""
    freq_bins = np.arange(peaks.shape[0], dtype=np.float64) * rate / FFT_SIZE
    tracks: list[list[PartialFrame]] = []
    active: list[list[PartialFrame]] = []

    for frame_index, time_s in enumerate(times):
        active_bins = np.flatnonzero(peaks[:, frame_index])
        if active_bins.size == 0:
            continue
        candidate_freqs = freq_bins[active_bins]
        next_active: list[list[PartialFrame]] = []

        if active:
            for track in active:
                last_freq = track[-1].frequency_hz
                distances = np.abs(candidate_freqs - last_freq)
                nearest = int(np.argmin(distances))
                min_gap = 0.20 * last_freq + 30.0
                if distances[nearest] <= min_gap and peaks[active_bins[nearest], frame_index]:
                    track.append(PartialFrame(time_s=float(time_s), frequency_hz=float(candidate_freqs[nearest]), magnitude_db=0.0, phase_rad=0.0))
                    peaks[active_bins[nearest], frame_index] = False
                    next_active.append(track)
                else:
                    tracks.append(track)

        for bin_index in active_bins:
            if peaks[bin_index, frame_index]:
                next_active.append([PartialFrame(time_s=float(time_s), frequency_hz=float(freq_bins[bin_index]), magnitude_db=0.0, phase_rad=0.0)])
        active = next_active
        if len(active) > MAX_TRACKS:
            break

    tracks.extend(active)

    min_frames = max(1, int(MIN_TRACK_DURATION_MS / 1000.0 * rate / HOP_SIZE))
    return [
        PartialTrack(id=f"partial-{index}", frames=[f for f in track])
        for index, track in enumerate(tracks)
        if len(track) >= min_frames
    ]


def _estimate_residual(spec_db: np.ndarray, peaks: np.ndarray, times: np.ndarray) -> list[ResidualRegion]:
    """Estimate broadband residual regions where few partials dominate."""
    regions: list[ResidualRegion] = []
    energy = spec_db - np.where(peaks, spec_db, -100.0)
    for frame_index, time_s in enumerate(times):
        col = energy[:, frame_index]
        hot = np.flatnonzero(col > (np.max(col) - 12.0))
        if hot.size == 0:
            continue
        regions.append(
            ResidualRegion(
                id=f"residual-{frame_index}",
                start_s=float(time_s),
                end_s=float(time_s) + HOP_SIZE / 48000.0,
                low_hz=float(hot[0] * 48000.0 / FFT_SIZE),
                high_hz=float(hot[-1] * 48000.0 / FFT_SIZE),
                center_hz=float(np.mean(hot) * 48000.0 / FFT_SIZE),
                energy_db=float(np.max(col)),
            )
        )
    return regions[:80]


def synthesize_partials(tracks: list[PartialTrack], sample_rate: int, duration_s: float) -> np.ndarray:
    """Additive re-synthesis from tracked partials (deterministic)."""
    count = max(1, int(round(duration_s * sample_rate)))
    out = np.zeros(count, dtype=np.float64)
    for track in tracks:
        if not track.frames:
            continue
        times = track.times()
        freqs = track.frequencies()
        starts = (times * sample_rate).astype(np.int64)
        ends = np.concatenate([starts[1:], [count - 1]])
        for start, end in zip(starts, ends):
            segment = np.arange(start, min(end, count), dtype=np.int64)
            if segment.size == 0:
                continue
            t = segment / sample_rate
            freq = float(freqs[np.clip(np.searchsorted(times, t[0]), 0, len(times) - 1)])
            out[segment] += np.sin(2.0 * np.pi * freq * t) * 0.5
    return np.asarray(out / max(1.0, float(np.max(np.abs(out)))), dtype=np.float32) * 0.5