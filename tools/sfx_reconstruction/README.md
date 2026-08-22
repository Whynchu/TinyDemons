# SFX reconstruction tools

## Repeatable SYS-CLICK workflow

From the TinyDemons project directory:

```powershell
$env:PYTHONPATH = "tools"
$py = "C:\Users\Samue\AppData\Local\Python\bin\python.exe"

& $py -m sfx_reconstruction.src.pipeline forensic `
  --input "..\sfx analysis\SYS-CLICK.wav" `
  --output analysis/sfx_recipes/sys-click.forensic.json

& $py -m sfx_reconstruction.src.pipeline optimize `
  --recipe analysis/sfx_recipes/sys-click.workbench.recipe.json `
  --reference "..\sfx analysis\SYS-CLICK.wav" `
  --output-recipe analysis/sfx_recipes/sys-click.optimized.recipe.json `
  --output-wav assets/sounds/reconstructed_ui/sys-click.optimized.wav `
  --rounds 4

& $py -m sfx_reconstruction.src.pipeline score `
  --reference "..\sfx analysis\SYS-CLICK.wav" `
  --candidate assets/sounds/reconstructed_ui/sys-click.optimized.wav `
  --output analysis/sfx_recipes/sys-click.optimized.scorecard.json
```

The scorecard is an optimization aid. Promotion still requires deterministic rerendering, regional gates, and listening approval.

This package analyzes reference sounds into compact procedural recipes and
renders original WAV files from those recipes. It must never read reference
audio while rendering, and recipes must not contain embedded audio data.

Current environment audit (2026-08-21): Python 3.14.3 and NumPy are available
at `C:\Users\Samue\AppData\Local\Python\bin\python.exe`. SciPy, librosa,
PyTorch, torchaudio, and jsonschema are not currently installed.

Milestone 1 intentionally uses only NumPy and the Python standard library.

Milestone 2 now provides WAV ingestion and compact structural analysis through
`python -m sfx_reconstruction.src.pipeline analyze`. The first prepared subset
contains ten decoded system references under `analysis/sfx_recipes/`. MP3
decoding remains a separate bridge task; the analyzer currently accepts 16-bit
PCM WAV so its output can be tested independently of codec behavior.
