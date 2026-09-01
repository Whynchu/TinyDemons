"""Workspace layout and manifest helpers (spec section 7)."""

from __future__ import annotations

import json
import time
from pathlib import Path

from ..exceptions import WorkspaceConflictError

WORKSPACE_ROOT = Path(__file__).resolve().parents[4] / "workspaces"


def run_id(prefix: str = "") -> str:
    stamp = time.strftime("%Y-%m-%dT%H%M%SZ", time.gmtime())
    return f"{stamp}-{prefix or 'run'}".rstrip("-")


def create_run(sound_id: str, overwrite: bool = False, parent: Path | None = None) -> Path:
    base = Path(parent) if parent is not None else WORKSPACE_ROOT
    run_path = base / sound_id / run_id(sound_id)
    if run_path.exists() and not overwrite:
        raise WorkspaceConflictError(f"workspace run already exists: {run_path}")
    for sub in ("input", "analysis", "components", "recipes", "renders", "evaluation", "plots"):
        (run_path / sub).mkdir(parents=True, exist_ok=True)
    return run_path


def write_manifest(run_path: Path, entries: dict) -> None:
    payload = {"created_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), **entries}
    (run_path / "manifest.json").write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")