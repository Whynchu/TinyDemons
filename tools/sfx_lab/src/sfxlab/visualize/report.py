"""Static HTML report generation for an analysis workspace."""

from __future__ import annotations

from pathlib import Path

import numpy as np


def write_report(workspace: Path, source: np.ndarray, reconstruction: np.ndarray, metrics: dict, tracks: int, components: int) -> None:
    loss = float(metrics.get("envelope_loss", float("nan")))
    stft = metrics.get("stft_errors", {})
    rows = "".join(
        f"<tr><td>{name}</td><td>{value:.4f}</td></tr>" for name, value in sorted(stft.items())
    )
    html = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>SFX Lab report</title>
<style>body{{font-family:monospace;background:#0d0f14;color:#dfe4f0;padding:24px}}
table{{border-collapse:collapse}}td,th{{border:1px solid #3a4156;padding:4px 10px;text-align:left}}
h1{{color:#7fd0ff}}</style></head><body>
<h1>SFX Lab — analysis report</h1>
<p>tracks={tracks} components={components} envelope_loss={loss:.4f}</p>
<table><tr><th>STFT size</th><th>error</th></tr>{rows}</table>
</body></html>"""
    path = workspace / "evaluation" / "report.html"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(html, encoding="utf-8")