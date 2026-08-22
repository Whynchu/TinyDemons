# SFX Analysis-to-Production Toolchain

## Mission

Turn short reference WAVs into editable, deterministic procedural recipes that reproduce their perceptual construction closely enough to become useful starting points for original Tiny Demons sounds.

The toolchain must explain layered sounds, generate them without source PCM, compare candidates quickly, and promote only results that survive both objective and listening validation.

## Core rules

1. Analysis data, synthesis recipes, rendered candidates, scores, and approved game assets are separate artifacts.
2. Reference audio is read only by analysis and evaluation. The production renderer reads recipes only.
3. Every measurement records its method, resolution, confidence, and analyzer version.
4. A sound may contain overlapping transient, resonant, noisy, tonal, tail, and nonlinear layers.
5. A scalar score is a search aid, not proof of perceptual similarity.
6. SYS-CLICK remains the calibration target until the complete loop is demonstrably reliable.

## End-to-end flow

```text
reference WAV
  -> ingest and canonicalize
  -> multiresolution measurements
  -> event and layer hypotheses
  -> candidate model bank
  -> independent layer fitting
  -> joint refinement
  -> deterministic rendering
  -> objective scoring
  -> listening gate
  -> approved procedural recipe
  -> derived Tiny Demons variants
  -> Godot import and runtime validation
```

## 1. Ingestion and canonicalization

Preserve the original file and hash. Decode once to lossless PCM, retain source rate/channel metadata, detect channel relationships, and create a canonical mono or stereo analysis signal at a declared rate. Do not normalize destructively; record gain and DC offset separately.

Outputs:

- immutable source hash and decode provenance;
- container and active durations;
- leading/trailing silence;
- peak, RMS, DC offset, polarity, bit-depth clues, and clipping evidence;
- canonical analysis WAV used only as a cache.

## 2. Multiresolution analysis

No single window can resolve both a millisecond click and a sustained resonance. Analyze each source using several synchronized views:

- sample-domain waveform and Hilbert/envelope views;
- short STFT for transient timing;
- medium STFT for texture and brief resonances;
- long STFT for stable partials and tail modes;
- constant-Q or logarithmic filterbank for perceptual band structure;
- optional reassigned spectrum/wavelet pass for rapidly changing partials.

Every frame may store RMS, peak, spectral flux, centroid, bandwidth, rolloff, flatness, zero-crossing rate, phase, and band energies. JSON should contain compact control points and summaries; dense arrays belong in versioned cache files.

## 3. Segmentation and layer hypotheses

Detect onset, attack, body, release, secondary events, and tail using agreement between energy, spectral flux, spectral change, and change-point evidence. Boundaries carry uncertainty rather than pretending to be exact.

Propose overlapping layers:

- broadband attack impulse;
- low-frequency body/thump;
- narrow resonant or tonal partials;
- band-limited stochastic texture;
- delayed or sustained ringing tail;
- nonlinear/quantized coloration.

Each hypothesis records onset, offset, envelope, frequency support, energy share, confidence, and how much residual error it removes when synthesized and subtracted. A layer is retained because it explains distinct energy, not merely because a detector found a peak.

## 4. Model bank

The system should fit several interpretable model families and rank them per layer:

- shaped impulse and filtered click;
- damped resonator/modal bank;
- phase-continuous sinusoidal partial tracks;
- chirped or frequency-drifting partials;
- multiband filtered noise with time-varying envelopes;
- convolution with a short procedurally described resonator kernel;
- bounded waveshaping, quantization, and sample-rate coloration.

Recipes may combine families. Source PCM, copied waveform arrays, and opaque residual audio are prohibited.

## 5. Fitting strategy

Use a staged fit so parameters remain identifiable:

1. Align and fit global duration, silence, gain, and polarity.
2. Fit the attack using the first 5–30 ms and freeze its broad shape.
3. Fit low body and deterministic resonances to the attack-removed signal.
4. Fit stochastic band envelopes to the remaining residual.
5. Fit tail resonances and delayed events.
6. Jointly refine gains, phases, timings, decays, and nonlinear color within bounded ranges.

Use analytic least-squares where possible and bounded coordinate/CMA-style search for nonlinear parameters. Cache reference features and render only affected regions during local searches. Keep a diverse top-candidate bank rather than one fragile winner.

## 6. Evaluation

The Python evaluator is authoritative for optimization. Godot is used only for final playback and import checks.

Report a scorecard rather than only one number:

- onset and event-timing error;
- attack waveform and transient-spectrum similarity;
- body multiscale log-spectrum similarity;
- envelope and decay similarity;
- per-band energy-envelope similarity;
- deterministic partial-track error;
- tail similarity;
- loudness-normalized waveform similarity;
- nonlinear/color descriptors.

The aggregate score must be calibrated with invariance tests: identical audio scores 100; gain, padding, and tiny alignment changes remain high; unrelated clicks remain low. A reported 85–90 target is meaningful only after this calibration and a listening correlation study.

Promotion requires:

- aggregate target met on the calibrated metric;
- no important region/layer regresses beyond its tolerance;
- no clipping, unstable randomness, or recipe validation failure;
- deterministic byte-identical rerender;
- human A/B approval against the reference and previous champion.

## 7. Optimization loop

Each run records the parent recipe, mutated parameters, seed, scorecard, runtime, and output hash. Search proceeds in passes:

1. structural search: add/remove model families and layers;
2. coarse bounded parameter search;
3. independent per-layer refinement;
4. joint fine refinement;
5. robustness check across deterministic seeds where noise is present;
6. plateau diagnosis identifying which score component blocks progress.

Stop conditions:

- calibrated score and regional gates are met;
- improvement remains below 0.1 points for three complete passes;
- the model lacks coverage, in which case return to structural search rather than endlessly tuning gains.

## 8. Artifact layout

```text
analysis/sfx_sources/            canonical source manifests
analysis/sfx_features/           dense versioned feature caches
analysis/sfx_recipes/            editable procedural recipes
analysis/sfx_runs/<run_id>/      optimizer history and scorecards
assets/sounds/reconstructed_ui/  audition candidates
assets/sounds/approved_ui/       human-approved production renders
tools/sfx_reconstruction/        analyzer, renderer, evaluator, optimizer
```

No generated candidate becomes a live SoundManager mapping automatically.

## 9. Validation fixtures

Before trusting analysis results, recover known parameters from synthetic fixtures:

- impulses and filtered impulses;
- pure and decaying tones;
- two close partials;
- chirps and drifting modes;
- multiband noise envelopes;
- transient-plus-tail composites;
- clipped, quantized, and downsampled signals;
- overlapping multilayer clicks.

Track frequency, phase, onset, decay, band-energy, and layer-count recovery errors. Regression tests must cover renderer determinism and the prohibition on embedded audio.

## 10. Production stages

### Stage A: trustworthy measurement

Finish schema versioning, dense feature caching, boundary confidence, multiband temporal envelopes, short-lived phase-aware tracks, and synthetic recovery tests.

### Stage B: expressive renderer

Complete explicit transient, body, partial, texture, tail, and nonlinear layers with independent envelopes and filters.

### Stage C: calibrated evaluator

Implement regional/per-layer scorecards, invariance tests, feature caching, and listening calibration. Replace the current provisional score scale.

### Stage D: automated fitting

Generate layer hypotheses from analysis, fit them independently, jointly optimize, preserve run history, and diagnose plateaus.

### Stage E: SYS-CLICK acceptance

Reach the calibrated target, pass listening review, rerender deterministically, and freeze a champion recipe.

### Stage F: family generalization

Process the remaining click family first, then cancel/close/save/item/money sounds. Reuse shared layer templates while fitting sound-specific parameters.

### Stage G: Tiny Demons adaptation

Fork approved reconstruction recipes into original variants by changing intervals, decay, texture bands, timing, and coloration. Only these reviewed variants enter the game asset mapping.

## Immediate implementation queue

1. Replace the provisional scalar Python metric with a calibrated regional scorecard and invariance tests.
2. Add dense feature-cache files and schema/version fingerprints.
3. Convert analyzed band envelopes and partial tracks into explicit recipe layer hypotheses.
4. Expand optimization from gains/decays to timing, bands, frequency drift, phase, and structural add/remove mutations.
5. Add run manifests, champion retention, plateau reports, and the 85–90 promotion gate.

This order matters: optimizing aggressively before the evaluator is calibrated can produce a high number that does not sound closer.
