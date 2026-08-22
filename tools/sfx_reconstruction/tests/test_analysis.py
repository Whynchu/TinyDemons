import tempfile
import unittest
from pathlib import Path

import numpy as np

from sfx_reconstruction.src.analyze import analyze_wav
from sfx_reconstruction.src.render import write_wav
from sfx_reconstruction.src.fit import fit_wav
from sfx_reconstruction.src.forensic import analyze_forensic
from sfx_reconstruction.src.metric import compare


class AnalysisTests(unittest.TestCase):
    def test_analysis_is_compact_and_structural(self):
        rate = 22050
        time = np.arange(int(rate * 0.2)) / rate
        samples = (np.sin(2 * np.pi * 880.0 * time) * np.exp(-time / 0.04)).astype(np.float32)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.wav"
            write_wav(path, samples, rate)
            result = analyze_wav(path)
        self.assertEqual(result["format"], "tiny_demons_sfx_analysis")
        self.assertGreater(result["source"]["active_duration_seconds"], 0.0)
        self.assertIn("events", result["analysis"])
        self.assertNotIn("samples", str(result).lower())

    def test_fit_contains_procedural_modes_only(self):
        rate = 22050
        time = np.arange(int(rate * 0.2)) / rate
        samples = (np.sin(2 * np.pi * 880.0 * time) * np.exp(-time / 0.04)).astype(np.float32)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.wav"
            write_wav(path, samples, rate)
            recipe = fit_wav(path)
        self.assertGreater(len(recipe["events"][0]["modes"]), 0)
        self.assertNotIn("samples", str(recipe).lower())

    def test_forensic_analysis_has_multiple_resolutions(self):
        rate = 22050
        time = np.arange(int(rate * 0.2)) / rate
        samples = (np.sin(2 * np.pi * 880.0 * time) * np.exp(-time / 0.04)).astype(np.float32)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "synthetic.wav"
            write_wav(path, samples, rate)
            result = analyze_forensic(path)
        self.assertEqual(set(result["resolutions"]), {"256", "1024", "4096"})
        self.assertIn("semantic_regions", result)
        self.assertNotIn("samples", str(result).lower())

    def test_forensic_tracks_known_tone(self):
        rate = 22050
        time = np.arange(int(rate * 0.3)) / rate
        samples = (0.7 * np.sin(2 * np.pi * 1200.0 * time) * np.exp(-time / 0.12)).astype(np.float32)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "known_tone.wav"
            write_wav(path, samples, rate)
            result = analyze_forensic(path)
        tracks = result["resolutions"]["4096"]["tracks"]
        frequencies = [track["summary"]["start_frequency_hz"] for track in tracks]
        self.assertTrue(any(abs(float(frequency) - 1200.0) < 30.0 for frequency in frequencies))

    def test_metric_invariance_and_regional_scorecard(self):
        rate = 22050
        time = np.arange(int(rate * 0.2)) / rate
        samples = (np.sin(2 * np.pi * 880.0 * time) * np.exp(-time / 0.04)).astype(np.float32)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            reference = root / "reference.wav"
            gain = root / "gain.wav"
            padded = root / "padded.wav"
            write_wav(reference, samples, rate)
            write_wav(gain, samples * 0.5, rate)
            write_wav(padded, np.pad(samples, (200, 0)), rate)
            self_score = compare(reference, reference)
            gain_score = compare(reference, gain)
            padded_score = compare(reference, padded)
        self.assertGreater(self_score["score"], 99.0)
        self.assertGreater(gain_score["score"], 90.0)
        self.assertGreater(padded_score["score"], 50.0)
        self.assertIn("body_loss", self_score)
        self.assertIn("tail_loss", self_score)
