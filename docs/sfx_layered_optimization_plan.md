# Layered SYS-CLICK Optimization Plan

## Target

Reach an 85–90 procedural similarity score without embedding source audio. Promote candidates only when overall, attack, body, and tail scores improve together.

## Sequence

1. Add explicit event layers: transient, low body, resonant partials, texture bands, tail, and nonlinear processing.
2. Extract each layer’s envelope, band energy, onset/offset, centroid, bandwidth, and confidence from multi-resolution analysis.
3. Fit transient and resonant layers independently, then jointly fit gains/phases; fit stochastic bands to residual energy.
4. Cache reference features and report attack/body/tail, waveform, multiscale spectrum, flux, and per-band losses.
5. Run bounded coordinate search, then local least-squares over timing, gain, decay, drift, filter bands, drive, and quantization.
6. Keep a candidate bank, stop at score >=85, and require no regional regression over 3%.

## Immediate implementation

Add `layers[]` to each event. Each layer has `kind`, `gain`, `envelope`, and kind-specific parameters. Legacy fields remain renderable.
