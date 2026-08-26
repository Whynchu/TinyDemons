"""Validation for numerical analysis reports consumed by synthesis."""
from __future__ import annotations

REQUIRED_SOURCE = ("sha256", "source_rate", "active_duration_seconds", "peak", "rms")
REQUIRED_ANALYSIS = ("analysis_rate", "envelope", "spectral_flux", "events", "transient_markers", "transient", "layers")

def validate_analysis_report(report: dict) -> None:
    if report.get("format") != "tiny_demons_sfx_analysis":
        raise ValueError("unsupported analysis report format")
    source = report.get("source", {})
    analysis = report.get("analysis", {})
    missing_source = [key for key in REQUIRED_SOURCE if key not in source]
    missing_analysis = [key for key in REQUIRED_ANALYSIS if key not in analysis]
    if missing_source or missing_analysis:
        raise ValueError(f"incomplete analysis report: source={missing_source}, analysis={missing_analysis}")
    if float(source["active_duration_seconds"]) <= 0 or float(source["source_rate"]) <= 0:
        raise ValueError("invalid source duration or rate")
    for marker in analysis["transient_markers"]:
        for key in ("time_seconds", "strength", "confidence"):
            if key not in marker or not isinstance(marker[key], (int, float)):
                raise ValueError(f"transient marker missing numeric {key}")
    for layer in analysis["layers"]:
        if not isinstance(layer.get("energy_share"), (int, float)) or not isinstance(layer.get("frequency_band_hz"), list):
            raise ValueError("layer lacks numeric energy or frequency band")
