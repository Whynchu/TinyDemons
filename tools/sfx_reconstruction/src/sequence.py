from __future__ import annotations
import copy, json
from pathlib import Path

def fit_sequence_recipe(workbench_path: str, analysis_path: str, output_path: str) -> dict:
    recipe = json.loads(Path(workbench_path).read_text(encoding="utf-8"))
    analysis = json.loads(Path(analysis_path).read_text(encoding="utf-8"))
    source_event = recipe["events"][0]
    markers = analysis["analysis"].get("transient_markers", [])
    events = []
    for marker in markers:
        start = float(marker["time_seconds"])
        strength = min(1.5, max(0.25, float(marker["strength"]) / 0.004))
        event = copy.deepcopy(source_event)
        event["start_seconds"] = start
        event["duration_seconds"] = min(0.18, max(0.035, float(source_event.get("duration_seconds", 0.1)) * 0.22))
        event["gain_db"] = -3.0
        event["transient"]["gain"] = float(event["transient"].get("gain", 0.15)) * strength
        event["modes"] = [dict(mode, gain=float(mode.get("gain", 0.0)) * 0.28) for mode in event.get("modes", [])]
        event["residual"]["gain"] = float(event["residual"].get("gain", 0.01)) * 0.35
        events.append(event)
    if not events:
        events = [source_event]
    recipe["render"]["duration_seconds"] = max(float(recipe["render"].get("duration_seconds", 0.1)), max(float(e["start_seconds"]) + float(e["duration_seconds"]) for e in events))
    recipe["events"] = events
    recipe["id"] = "sys-click102_sequence"
    recipe["source_role"] = "ui_click_sequence_reconstruction"
    recipe["fit"] = {"method": "transient_marker_sequence_plus_resonant_body", "marker_count": len(markers)}
    Path(output_path).write_text(json.dumps(recipe, indent=2), encoding="utf-8")
    return recipe
