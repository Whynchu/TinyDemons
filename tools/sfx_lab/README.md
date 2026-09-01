# SMS Component SFX Lab

A component-based spectral modeling synthesis toolkit for the Tiny Demons SFX
pipeline. It converts a reference sound effect into a measured, inspectable,
component-based recipe that can be reconstructed, edited, mutated, and rendered
without inventing DSP from prose.

This is the first vertical slice of
[`../../sfx analysis/SMS_SFX_REPO_ARCHITECTURE.md`](../../sfx%20analysis/SMS_SFX_REPO_ARCHITECTURE.md),
implemented inside the game repo per the "inside the game repo" decision.

## What the slice does

```text
reference.wav
  -> canonicalize (mono float32 @ 48k, trim, normalize)
  -> native STFT sinusoidal analysis (partial tracks)
  -> residual region estimation
  -> deterministic tonal componentizer
  -> versioned recipe (schema 1.0.0)
  -> component stems + summed reconstruction
  -> multi-resolution STFT evaluation + HTML report
```

The backend boundary (`backends/base.py`) keeps the AGPL `sms-tools` out of the
core. The first backend is a native NumPy/SciPy implementation with no AGPL
dependency; a future `sms-tools` adapter can sit behind the same protocol.

## Run

```powershell
$env:PYTHONPATH = "tools\sfx_lab\src"
$py = "tools\sfx_reconstruction\.venv311\Scripts\python.exe"

& $py -m sfxlab.cli analyze `
  --input "assets\sounds\generated_ui\ui_confirm.wav" `
  --output-workspace "tools\sfx_lab\workspaces" --json
```

Artifacts land in `tools/sfx_lab/workspaces/<sound>/<run>/`:
`input/original.wav`, `input/canonical.wav`, `analysis/`, `components/*.wav`
(stems), `recipes/reconstruction.recipe.json`, `renders/reconstruction.wav`,
`evaluation/metrics.json` + `report.html`, and `manifest.json`.

Validate a recipe:

```powershell
& $py -m sfxlab.cli validate --recipe "tools\sfx_lab\workspaces\ui_confirm\<run>\recipes\reconstruction.recipe.json"
```

## Tests

```powershell
& $py -m pytest tools\sfx_lab\tests -q
```

Fixtures are synthetic signals only (steady sine, harmonic stack, rising chirp,
click+body). No licensed or copyrighted audio is used as a fixture or committed
to the repo. `workspaces/` is gitignored.

## Licensing boundary

Per the architecture plan: fixtures must be authorized audio; commercial game
assets are not committed, shipped, or used as public regression fixtures. The
`assets/sounds/FFsounds/` recordings (Square Enix Final Fantasy sounds) stay
excluded from this pipeline. `sms-tools`, if ever adopted, is AGPL and must
remain a replaceable backend behind `backends/base.py` with legal review before
distribution.