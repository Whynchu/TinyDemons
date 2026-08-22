"""Small deterministic coordinate-search optimizer for procedural SFX recipes."""
from __future__ import annotations
import copy, json
from pathlib import Path
from .render import render_recipe, write_wav
from .metric import compare

def optimize(recipe_path: str, reference: str, output_recipe: str, output_wav: str, rounds: int = 4) -> dict:
    base = json.loads(Path(recipe_path).read_text(encoding="utf-8"))
    best = copy.deepcopy(base)
    work = Path(output_wav).with_suffix("")
    best_path = work.with_name(work.name + "_best.wav")
    def evaluate(recipe):
        write_wav(best_path, render_recipe(recipe), int(recipe["render"]["sample_rate"]))
        return compare(reference, best_path)
    result = evaluate(best)
    for _ in range(rounds):
        improved = False
        for event_index, event in enumerate(best.get("events", [])):
            for key, values in (("gain", (0.7, 0.85, 1.15, 1.3)),):
                old = float(event.get("transient", {}).get(key, 0.0))
                for scale in values:
                    candidate = copy.deepcopy(best)
                    candidate_event = candidate["events"][event_index]
                    candidate_event["transient"][key] = old * scale
                    score = evaluate(candidate)
                    if score["score"] > result["score"]:
                        best, result, improved = candidate, score, True
            residual = event.get("residual", {})
            for key, scales in (("gain", (0.65, 0.8, 1.2, 1.45)), ("decay_seconds", (0.7, 0.85, 1.15, 1.35))):
                old = float(residual.get(key, 0.0))
                for scale in scales:
                    candidate = copy.deepcopy(best)
                    candidate["events"][event_index]["residual"][key] = max(1e-5, old * scale)
                    score = evaluate(candidate)
                    if score["score"] > result["score"]:
                        best, result, improved = candidate, score, True
            for layer_index, layer in enumerate(event.get("layers", [])):
                if layer.get("kind") != "glow_tail":
                    continue
                for key, scales in (("gain", (0.6, 0.8, 1.2, 1.5)), ("decay_seconds", (0.65, 0.85, 1.2, 1.45)), ("onset_seconds", (0.7, 0.9, 1.1, 1.3))):
                    old = float(layer.get(key, 0.02))
                    for scale in scales:
                        candidate = copy.deepcopy(best)
                        candidate["events"][event_index]["layers"][layer_index][key] = max(1e-5, old * scale)
                        score = evaluate(candidate)
                        if score["score"] > result["score"]:
                            best, result, improved = candidate, score, True
            old_decay = float(event.get("transient", {}).get("decay_seconds", 0.008))
            for scale in (0.65, 0.8, 1.2, 1.4):
                candidate = copy.deepcopy(best)
                candidate["events"][event_index]["transient"]["decay_seconds"] = old_decay * scale
                score = evaluate(candidate)
                if score["score"] > result["score"]:
                    best, result, improved = candidate, score, True
            for mode_index, mode in enumerate(event.get("modes", [])):
                old = float(mode.get("gain", 0.0))
                for scale in (0.8, 0.9, 1.1, 1.25):
                    candidate = copy.deepcopy(best)
                    candidate["events"][event_index]["modes"][mode_index]["gain"] = old * scale
                    score = evaluate(candidate)
                    if score["score"] > result["score"]:
                        best, result, improved = candidate, score, True
                old_decay = float(mode.get("decay_seconds", event.get("duration_seconds", 0.1)))
                for scale in (0.6, 0.8, 1.25, 1.6):
                    candidate = copy.deepcopy(best)
                    candidate["events"][event_index]["modes"][mode_index]["decay_seconds"] = max(0.002, old_decay * scale)
                    score = evaluate(candidate)
                    if score["score"] > result["score"]:
                        best, result, improved = candidate, score, True
                old_start = float(mode.get("start_seconds", 0.0))
                for offset in (-0.002, -0.001, 0.001, 0.002, 0.004):
                    candidate = copy.deepcopy(best)
                    candidate["events"][event_index]["modes"][mode_index]["start_seconds"] = max(0.0, old_start + offset)
                    score = evaluate(candidate)
                    if score["score"] > result["score"]:
                        best, result, improved = candidate, score, True
        if not improved:
            break
    Path(output_recipe).write_text(json.dumps(best, indent=2), encoding="utf-8")
    write_wav(output_wav, render_recipe(best), int(best["render"]["sample_rate"]))
    return result
