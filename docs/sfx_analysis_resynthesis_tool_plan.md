# SFX Analysis/Resynthesis Tool Plan

## Objective

Build a measurement-first analyzer that produces enough structured, editable data to rebuild short system sounds closely in concept, while keeping every parameter procedural and safe to modify later. The analyzer must describe *what the sound does over time*, not merely list a few FFT peaks.

## Lessons from established systems

- McAulay–Quatieri sinusoidal modeling and SPEAR/IRCAM-style partial analysis use time-linked sinusoidal partials with frequency, amplitude, and phase trajectories. This is the right representation for pitched or resonant bodies, but short clicks need relaxed track lifetimes and explicit birth/death events. [McAulay–Quatieri overview](https://www.ll.mit.edu/r-d/publications/speech-transformations-based-sinusoidal-representation), [IRCAM partial analysis](https://support.ircam.fr/docs/AudioSculpt/3.0/co/Presentation.html)
- Spectral Modelling Synthesis separates deterministic partials, stochastic/noise energy, and transients. We should preserve that separation instead of forcing every peak into a modal oscillator. [IRCAM SMS discussion](https://discussion.forum.ircam.fr/t/spectral-modelling-synthesis/2259)
- Phase-vocoder tooling emphasizes oversampled FFTs, transient markers, and phase-aware analysis. We need multiple windows because no single FFT resolves both a 2 ms attack and a 100 ms resonance. [CNMAT AudioSculpt support](https://cnmat.berkeley.edu/content/ircam-audiosculpt-support)
- DDSP demonstrates that interpretable DSP parameters can be optimized directly against audio. We can use the same idea with a small deterministic optimizer before considering neural models. [DDSP paper](https://arxiv.org/abs/2001.04643), [DDSP-SFX](https://arxiv.org/abs/2309.08060)

## Layered-sound principle

These references are often deliberately constructed composites: a sharp click may contain a broadband attack, one or more short resonances, a filtered scrape/noise layer, a low body thump, and a quantized or saturated finish. The analyzer must therefore avoid one global label such as “tonal” or “noise.” Every descriptor below is stored per layer and per time region, with overlap allowed.

The first layer pass should propose, rather than assume, these components:

- **attack/transient**: sub-20 ms broadband onset and polarity;
- **low body**: short low-frequency impulse or resonator;
- **tonal/resonant partials**: narrow peaks with linked frequency and phase;
- **texture/noise**: broadband or band-limited stochastic energy;
- **tail/ringing**: decaying resonances after the main onset;
- **nonlinear/color**: distortion, bit reduction, alias-like high-frequency residue.

Layers may overlap in time. Each must carry an energy share, frequency bands, onset/offset confidence, and a residual-after-subtraction score so we can tell whether it explains genuinely distinct source energy.

## Analysis record

Each WAV produces one JSON record with these groups:

1. **Provenance**: source hash, sample rate, channels, peak/RMS, trim thresholds, analyzer version, and all FFT/hop settings.
2. **Segmentation**: onset, attack, body, release, silence, transient markers, and confidence for every boundary.
3. **Loudness/envelope**: sample envelope plus smoothed amplitude, attack time, peak time, decay constants, crest factor, and dynamic range.
4. **Transient descriptors**: broadband impulse energy, spectral-flux curve, zero-crossing rate, attack centroid, bandwidth, flatness, polarity, and pre/post ringing.
5. **Partial tracks**: for each linked component, time samples of frequency, amplitude, phase, bandwidth, confidence, birth/death, frequency slope, amplitude slope, and phase residual. Track linking must allow short lifetimes.
6. **Spectral snapshots**: reassigned/interpolated peaks and bands at attack, peak, body, and tail, including harmonicity and inharmonicity estimates.
7. **Stochastic residual**: per-band noise energy, spectral envelope, time-varying flatness, autocorrelation, and deterministic-vs-stochastic energy ratio.
8. **Nonlinear evidence**: estimated saturation/drive, asymmetry, aliasing indicators, and optional waveshaper candidates. These are measurements, not assumptions.
9. **Layer decomposition**: overlapping layer proposals, per-layer band envelopes, energy shares, cross-resolution support, and residual reduction after subtractive tests.
10. **Resynthesis hints**: ranked model candidates (transient, partial, resonator, filtered noise, residual), parameter bounds, and confidence—not a single unquestioned recipe.

## Required model families

The renderer should support a hybrid model:

- transient layer: shaped impulse, band-limited click, or measured attack kernel;
- deterministic layer: short additive partials with interpolated frequency/amplitude/phase trajectories;
- resonator layer: damped band-pass/modal responses for body or tail energy;
- stochastic layer: reproducible filtered noise driven by measured envelopes and spectral bands;
- optional nonlinear layer: bounded waveshaper/bit-depth/alias character;
- final envelope and exact sample-rate/quantization controls.

No embedded source PCM is permitted in recipes. A measured residual may be represented only by compact procedural descriptors or an explicitly approved derived kernel.

## Fitting strategy

1. Analyze at 4–6 resolutions (short attack, mid body, long tail) with oversampling.
2. Detect boundaries independently from energy, flux, and spectral change; combine them with confidence.
3. Extract peaks using quadratic interpolation and phase; link tracks with frequency, phase-prediction, amplitude continuity, and gap tolerance.
4. Propose overlapping layers using band-limited energy, partial tracks, transient markers, and residual analysis; classify each component as transient, partial, resonator, or stochastic using duration, bandwidth, harmonicity, and cross-resolution agreement.
5. Fit each layer independently first, then jointly refine gains, timing, masking, and nonlinear color. Optimize multiscale losses: waveform, log-magnitude STFT, spectral flux, envelope, onset timing, inter-band energy, and residual-band energy.
6. Keep the top N layer stacks and their metrics. Never discard the analysis just because one recipe scores poorly.
7. Validate against synthetic fixtures: pure tones, chirps, impulses, layered tones, filtered noise, transient-plus-tail composites, and known nonlinear signals. Report per-layer recovery error.

## Acceptance gates

- Analyzer output is deterministic and JSON-schema validated.
- Known-tone frequency error <1%; chirp slope error <5%; onset error <1 ms at 22.05 kHz.
- Re-rendered synthetic fixtures preserve the intended feature within defined tolerances.
- SYS-CLICK candidates are judged with both objective metrics and listening, with attack/body/tail scores reported separately.
- A candidate is not promoted unless it improves the relevant score without making the transient or residual materially worse.

## Implementation order

1. Formalize schema and provenance.
2. Add robust segmentation and transient descriptors.
3. Upgrade short-lived partial tracking and phase prediction.
4. Add deterministic/stochastic classification and residual bands.
5. Implement hybrid renderer and multiscale optimizer.
6. Build SYS-CLICK fixture suite and candidate bank.
7. Only after SYS-CLICK is stable, generalize to save, cancel, close, item-get, and other SYS families.

## Out of scope for the first milestone

Neural generation, automatic source separation, perceptual embedding models, and live game integration. Those can follow once the analysis record reliably explains and resynthesizes the reference.
