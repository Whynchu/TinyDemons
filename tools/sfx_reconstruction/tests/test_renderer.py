import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from sfx_reconstruction.src.render import render_recipe, write_wav
from sfx_reconstruction.src.recipe import validate_recipe


def synthetic_recipe() -> dict:
    return {
        "format": "tiny_demons_sfx_recipe",
        "version": 1,
        "id": "synthetic_test",
        "source_role": "test",
        "render": {"sample_rate": 22050, "channels": 1, "duration_seconds": 0.12, "seed": 7},
        "events": [{
            "start_seconds": 0.0,
            "duration_seconds": 0.10,
            "gain_db": -3.0,
            "pan": 0.0,
            "envelope": [[0.0, 0.0], [0.003, 1.0], [0.10, 0.0]],
            "transient": {"duration_seconds": 0.01, "decay_seconds": 0.003, "gain": 0.1},
            "modes": [{"frequency_hz": 880.0, "gain": 0.7, "decay_seconds": 0.07}],
            "residual": {"gain": 0.02, "decay_seconds": 0.02},
            "processing": {}
        }],
        "processing": {"drive": 1.0},
        "fit": {}
    }


class RendererTests(unittest.TestCase):
    def test_repeat_is_byte_identical(self):
        recipe = synthetic_recipe()
        first = render_recipe(recipe)
        second = render_recipe(recipe)
        self.assertEqual(hashlib.sha256(first.tobytes()).digest(), hashlib.sha256(second.tobytes()).digest())

    def test_wav_is_written(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.wav"
            recipe = synthetic_recipe()
            write_wav(path, render_recipe(recipe), recipe["render"]["sample_rate"])
            self.assertTrue(path.exists())
            self.assertGreater(path.stat().st_size, 44)

    def test_embedded_audio_is_rejected(self):
        recipe = synthetic_recipe()
        recipe["events"][0]["samples"] = [0.0, 0.1]
        with self.assertRaises(ValueError):
            validate_recipe(recipe)


if __name__ == "__main__":
    unittest.main()
