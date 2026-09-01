"""Deterministic componentizer: group partial tracks into tonal clusters.

Phase A of the spec's component grouping: build a weighted similarity graph
and form connected groups above a conservative threshold. Everything is
explicit and explainable; no clustering research in the first slice.
"""

from __future__ import annotations

import numpy as np

from ..analysis.models import PartialTrack


def track_features(track: PartialTrack) -> dict:
    freqs = track.frequencies()
    mags = track.magnitudes()
    times = track.times()
    if freqs.size == 0:
        return {"median_frequency_hz": 0.0, "start_s": track.start_s, "end_s": track.end_s, "duration_s": 0.0, "decay_constant_s": 0.0}
    duration = max(track.end_s - track.start_s, 1e-6)
    mean = float(np.mean(freqs))
    decay = float(np.std(freqs) / max(mean, 1.0))
    return {
        "median_frequency_hz": float(np.median(freqs)),
        "start_s": track.start_s,
        "end_s": track.end_s,
        "duration_s": float(duration),
        "decay_constant_s": decay,
    }


def onset_similarity(a: PartialTrack, b: PartialTrack) -> float:
    return max(0.0, 1.0 - abs(a.start_s - b.start_s) / 0.05)


def frequency_ratio_similarity(a: PartialTrack, b: PartialTrack) -> float:
    fa = np.median(a.frequencies())
    fb = np.median(b.frequencies())
    if fa <= 0.0 or fb <= 0.0:
        return 0.0
    ratio = max(fa, fb) / min(fa, fb)
    nearest_integer = round(ratio)
    if nearest_integer < 1:
        return 0.0
    closeness = 1.0 - min(1.0, abs(ratio - nearest_integer) / 0.06)
    return float(closeness)


def edge_score(a: PartialTrack, b: PartialTrack) -> float:
    onset = onset_similarity(a, b)
    ratio = frequency_ratio_similarity(a, b)
    duration_penalty = max(0.0, 1.0 - abs(a.end_s - b.end_s) / 0.1)
    return 0.45 * onset + 0.40 * ratio + 0.15 * duration_penalty


def componentize_tracks(tracks: list[PartialTrack], group_score_min: float = 0.55) -> list[list[PartialTrack]]:
    """Return lists of tracks grouped into tonal clusters (Phase A graph)."""
    groups: list[list[PartialTrack]] = []
    assigned: set[int] = set()

    # Weighted graph edges above threshold.
    edges: dict[int, list[tuple[int, float]]] = {i: [] for i in range(len(tracks))}
    for i in range(len(tracks)):
        for j in range(i + 1, len(tracks)):
            score = edge_score(tracks[i], tracks[j])
            if score >= group_score_min:
                edges[i].append((j, score))
                edges[j].append((i, score))

    for start_index in range(len(tracks)):
        if start_index in assigned:
            continue
        group = [start_index]
        assigned.add(start_index)
        frontier = [start_index]
        while frontier:
            current = frontier.pop()
            for neighbor, _score in sorted(edges[current], key=lambda item: item[1], reverse=True):
                if neighbor in assigned:
                    continue
                assigned.add(neighbor)
                group.append(neighbor)
                frontier.append(neighbor)
        groups.append([tracks[index] for index in group])

    return groups