# Procedural SFX Reconstruction Plan

## Purpose

Build a fast offline tool that analyzes a reference sound effect, describes its
audible construction in JSON, and renders a new sound from that description.

The immediate target is the imported *Kingdom Hearts: Chain of Memories*
system-click family. The imported audio is reference material only. Do not copy
it into shipping assets and do not encode its samples into JSON.

The work has two separate outcomes:

1. A reasonably accurate procedural reconstruction used to understand the
   reference's construction.
2. A later Tiny Demons adaptation derived from editable synthesis parameters.

Do not combine those stages. First make the reconstruction credible. Adapt its
style only after the reconstruction has been accepted by listening.

## Non-goals

- Do not train on the full imported sound library.
- Do not embed PCM, base64 audio, sample tables, phase-complete spectrograms, or
  residual reference audio in JSON.
- Do not use Godot/GDScript for heavy analysis or parameter fitting.
- Do not modify `SoundManager` or live game mappings during this project.
- Do not process all 547 files initially.
- Do not treat an automated similarity score as final approval.

## Initial reference set

Process these in order:

1. `SYS-CLICK`
2. `SYS-CLICK102`
3. `SYS-CLICK104`
4. `SYS-CLICK104B`
5. `SYS-BEEP`

The files are under the workspace-level `sfx examples/` directory, outside the
Godot project directory.

## Required architecture

Keep analysis and fitting outside Godot:

```text
reference MP3/WAV
    -> decode and normalize
    -> detect events and regions
    -> extract structural features
    -> fit procedural layers
    -> write recipe JSON
    -> render only from recipe JSON
    -> compare render with reference
    -> write diagnostic report
```

Use Python with vectorized libraries where available:

- NumPy
- SciPy
- librosa or torchaudio
- PyTorch only where differentiable refinement materially helps
- `jsonschema` for recipe validation

Do not install dependencies until the environment audit milestone explicitly
identifies what is missing and installation is approved.

## Directory layout

Create this layout inside the Godot project:

```text
tools/sfx_reconstruction/
    README.md
    requirements.txt
    schema/
        sfx_recipe.schema.json
    src/
        audio_io.py
        segment.py
        analyze.py
        modal_fit.py
        transient_fit.py
        residual_fit.py
        render.py
        compare.py
        pipeline.py
    tests/
        test_schema.py
        test_renderer.py
        test_invariance.py
        test_no_embedded_audio.py

assets/sounds/reconstructed_ui/
    # Generated WAVs and reports only. Do not place references here.

analysis/sfx_recipes/
    # JSON recipes and compact analysis reports.
```

Generated caches and temporary decoded reference WAVs must stay outside
shipping assets. Add ignore rules when necessary, but preserve recipe JSON,
diagnostic reports, and accepted generated WAVs.

## Recipe model

Every sound is organized as:

```text
sound
├── metadata
├── events
│   ├── transient excitation
│   ├── modal/tonal body
│   ├── procedural noise residual
│   └── event-local processing
└── final processing
```

### Required top-level fields

```json
{
  "format": "tiny_demons_sfx_recipe",
  "version": 1,
  "id": "sys_click_reconstruction",
  "source_role": "ui_click",
  "render": {},
  "events": [],
  "processing": {},
  "fit": {}
}
```

### Render fields

- `sample_rate`
- `channels`
- `duration_seconds`
- `seed`

### Event fields

- `start_seconds`
- `duration_seconds`
- `gain_db`
- `pan`
- `envelope`
- `transient`
- `modes`
- `residual`
- `processing`

### Modal fields

Each mode may contain:

- `frequency_hz`
- `gain`
- `phase`
- `attack_seconds`
- `decay_seconds`
- `drift_hz_per_second`
- `modulation_hz`
- `modulation_depth`

### Residual fields

The residual must remain generative:

- procedural seed
- distribution type
- filter bands or filter coefficients
- band-gain envelopes
- attack and decay parameters
- optional modulation

Never store residual waveform samples.

### Processing fields

- high-pass and low-pass filters
- parametric or shelving filters
- drive/saturation
- amplitude quantization
- sample-rate coloration
- short procedural delay taps
- stereo width

## Analysis requirements

For each reference, write a compact analysis report containing:

### Metadata

- input filename and hash
- sample rate and channels
- container and active durations
- peak, RMS, and loudness estimates
- stereo correlation
- leading and trailing silence

### Segmentation

- detected event count
- onset times
- event durations
- gaps
- attack/body/tail boundaries

### Amplitude

- whole-event envelope control points
- per-band envelope control points
- relative event gains

### Tonal/modal structure

- fundamental candidates
- dominant spectral peaks
- fitted modal frequencies
- modal gains
- modal phases
- modal decay constants
- pitch or frequency drift

### Transient

- duration
- tonal/noise ratio
- spectral slope
- brightness
- resonant peaks

### Residual

- time-varying band energies
- noise color
- spectral envelope
- autocorrelation summary
- modulation estimates

Reports may contain compact feature summaries. They must not contain
full-resolution waveform or reversible spectrogram data.

## Fitting strategy

Do not begin with broad random search.

Fit parameters in this order:

1. Silence trimming, event boundaries, and onset positions.
2. Overall and per-event amplitude envelopes.
3. Transient duration and frequency distribution.
4. Dominant modal frequencies.
5. Modal amplitudes, phases, and decay constants.
6. Pitch drift and modulation.
7. Procedural residual-noise filters and envelopes.
8. Final filtering, saturation, and quantization.
9. Joint local refinement of continuous parameters.

Use direct estimation wherever possible:

- spectral flux for onset detection
- short-time RMS for envelopes
- peak tracking for spectral trajectories
- Prony, matrix-pencil, ESPRIT-style, or constrained damped-sinusoid fitting
  for modal estimates
- least squares or non-negative least squares for modal amplitudes
- LPC/AR or filter-bank summaries for procedural noise coloration

Evolutionary search is allowed only for discrete topology decisions such as
event count, mode count, or optional delay presence. Continuous values should
use least-squares or gradient-based refinement from analyzed starting values.

## Renderer requirements

The renderer must:

- accept one recipe JSON path
- validate it against the schema
- render deterministically from the recipe and its seeds
- use no reference audio at render time
- output PCM WAV
- support mono and stereo
- run headlessly
- fail clearly on invalid or unsupported fields

Rendering the same recipe twice must produce byte-identical WAV output.

## Comparison requirements

Use the validated ideas from `tools/validate_audio_match_metric.gd`, implemented
efficiently with vectorized Python operations:

- silence trimming
- loudness/RMS normalization
- small alignment search
- multi-resolution STFT loss
- log-magnitude loss
- spectral convergence
- separate attack/body/tail losses
- envelope loss
- onset timing error
- modal-frequency error
- residual-spectrum error
- low-weight waveform correlation

Report all components. Do not return only one opaque score.

The score must pass these tests before it is used for fitting:

- exact self-match is 100
- gain changes have negligible effect
- silence padding has negligible effect
- small alignment changes have negligible effect
- unrelated game audio scores low
- each click scores 100 against itself
- different click references score lower than self-match

## Human evaluation

Automated scores rank candidates; they do not accept them.

For each reference, render three labeled outputs:

- `faithful`: strongest structural reconstruction
- `hybrid`: reference structure with restrained original changes
- `tiny_demons`: more clearly customized version

During the reconstruction phase, only the `faithful` output determines whether
the extractor/fitter is working. Do not optimize the faithful version for game
taste prematurely.

Current practical expectation: a validated score around 50–60 may be reasonable
if listening confirms a convincing relationship. Do not force a higher score by
encoding source samples or reversible source data.

## Performance requirements

The prior GDScript brute-force optimizer was too slow. Require these targets for
`SYS-CLICK` before scaling:

- decode and analysis: under 10 seconds
- initial parameter fitting: under 20 seconds
- local refinement: under 60 seconds
- render: under 2 seconds
- complete faithful result and report: under 2 minutes

If the pipeline misses these targets, profile and vectorize it before processing
the remaining click family.

## Milestones

Complete milestones sequentially. Do not begin a later milestone until the
current milestone's acceptance checks pass.

### Milestone 0: Stop and audit

Tasks:

1. Check whether optimizer processes from earlier interrupted runs are active.
2. Stop only processes clearly launched by the reconstruction tools.
3. Do not stop the user's Godot editor.
4. Inventory available Python runtimes and installed audio libraries.
5. Record findings in `tools/sfx_reconstruction/README.md`.

Acceptance:

- no task-owned orphan optimizer remains
- no user process was stopped
- runtime and dependency availability are documented

Stop condition:

- If process ownership cannot be established, do not stop it.

### Milestone 1: Schema and deterministic renderer

Tasks:

1. Create the directory structure.
2. Define `sfx_recipe.schema.json`.
3. Implement a minimal renderer supporting one event, one transient, modes,
   procedural residual noise, envelope, and final filtering.
4. Create a synthetic test recipe not based on reference audio.
5. Add schema and deterministic-render tests.

Acceptance:

- schema rejects embedded audio fields
- valid synthetic recipe renders successfully
- repeated renders are byte-identical
- no reference file is opened by the renderer

### Milestone 2: Audio ingestion and segmentation

Tasks:

1. Decode MP3/WAV into normalized floating-point PCM.
2. Extract metadata.
3. Trim silence.
4. Detect events and attack/body/tail boundaries.
5. Write compact analysis JSON.

Acceptance using `SYS-CLICK`:

- active duration agrees with visual/listening inspection
- detected event count and onset positions are plausible
- report contains no PCM or reversible spectrogram data
- analysis completes within 10 seconds

### Milestone 3: Transient and modal fitting

Tasks:

1. Fit the initial transient model.
2. Estimate dominant damped modes.
3. Fit modal amplitudes and decay constants.
4. Write these parameters into a valid recipe.
5. Render an initial reconstruction.

Acceptance:

- rendered attack begins at the correct time
- dominant frequency peaks broadly correspond to the reference
- modal body decays in a comparable manner
- fitting is analysis-guided, not broad random search

### Milestone 4: Procedural residual and processing

Tasks:

1. Model residual noise using filter bands or LPC/AR parameters.
2. Add time-varying residual envelopes.
3. Estimate final filtering, saturation, and quantization.
4. Re-render from recipe only.

Acceptance:

- reference audio is not accessed during rendering
- residual contains no copied waveform data
- reconstruction texture improves by listening and component metrics

### Milestone 5: Efficient comparison and refinement

Tasks:

1. Implement the vectorized comparison metric.
2. Add invariance and discrimination tests.
3. Refine continuous recipe parameters locally.
4. Write before/after component reports.

Acceptance:

- all metric validation tests pass
- refinement improves the accurate metric, not merely a proxy
- complete run remains under two minutes
- faithful reconstruction is ready for listening

### Milestone 6: Click-family processing

Tasks:

1. Accept or revise the `SYS-CLICK` faithful recipe.
2. Process `CLICK102`, `CLICK104`, `CLICK104B`, and `BEEP` independently.
3. Identify shared transient/modal/processing components.
4. Store shared components as explicit recipe presets, not copied audio.

Acceptance:

- five valid recipes exist
- every recipe renders without reference files
- sounds are related but not simple pitch-shifted duplicates
- each has a component report and human verdict

### Milestone 7: Tiny Demons adaptations

Tasks:

1. Freeze accepted faithful recipes.
2. Derive hybrid recipes.
3. Derive Tiny Demons recipes.
4. Adjust pitch language, timing, texture, brightness, and importance.
5. Export candidate WAVs without changing live mappings.

Acceptance:

- reconstruction and adaptation remain separate files
- adapted sounds form a coherent family
- no reference audio ships with the project
- integration waits for explicit approval

## Commands

The final CLI should converge on commands shaped like:

```powershell
python -m sfx_reconstruction.pipeline analyze --input <reference> --output <analysis.json>
python -m sfx_reconstruction.pipeline fit --input <reference> --analysis <analysis.json> --recipe <recipe.json>
python -m sfx_reconstruction.pipeline render --recipe <recipe.json> --output <sound.wav>
python -m sfx_reconstruction.pipeline compare --reference <reference> --candidate <sound.wav> --report <report.json>
```

Exact executable names may change after the environment audit. Document any
changes in the tool README and keep commands non-interactive.

## Per-task working rules

These rules are intended to keep implementation manageable for a smaller model:

1. Work on one milestone at a time.
2. Read this complete document before editing.
3. Inspect existing files before creating replacements.
4. Keep each code change narrowly scoped to the active milestone.
5. Add or update tests in the same change.
6. Run only the relevant tests before reporting completion.
7. Report exact files changed and commands run.
8. Preserve unrelated worktree changes.
9. Do not modify game integration files without explicit authorization.
10. Stop and report if a dependency install, network access, or destructive
    operation would be required.

## Definition of success

This project succeeds when a compact, readable JSON recipe can recreate the
audible concept and construction of a reference system sound without containing
or accessing its waveform, renders quickly and deterministically, and provides
parameters that can later be reshaped into a distinct Tiny Demons sound family.
