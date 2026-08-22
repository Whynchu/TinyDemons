# System SFX Reference Atlas

This document treats the imported *Kingdom Hearts: Chain of Memories* sounds as
private design references. They must not be copied into the game, transformed
into derivative shipping assets, or used as training data. Tiny Demons sounds
should be synthesized from elementary waveforms and original note gestures.

## Curated reference set

The full import contains 547 MP3 files. There are 67 files named `SYS-*`, but
many of those are footsteps, movement, props, or character cues. These 22 files
are the useful system/UI subset.

| Reference family | Files | Tiny Demons question |
|---|---|---|
| Navigation | `SYS-CLICK`, `CLICK102`, `CLICK104`, `CLICK104B`, `BEEP` | What timbre makes all routine input feel related? |
| Reverse/exit | `SYS-CANSEL`, `CLOSE` | How are cancel and close distinguished from confirmation? |
| State changes | `SYS-CHAGE`, `CHAGEF1`, `CHAGEF2`, `DECKSET`, `DROW` | How much musical information can a frequent action carry? |
| Persistence | `SYS-SAVELOAD` | How does the interface signal safe completion without sounding like loot? |
| Rewards | `SYS-ITEMGET`, `MONEY-GET`, `POWER-GET`, `TRESURE` | How does reward scale from routine to important? |
| Progression | `SYS-LVUP` | What is the largest gesture that still belongs to the UI family? |
| Transitions | `SYS-START`, `WORLDSELECT`, `WORLDSTART` | How does a system cue grow into a scene-level cue? |
| Warning | `SYS-ALART` | What repetition and tension communicate urgency? |

## Measured source inventory

Durations below are decoded container lengths. The files appear to contain
padded tails, so these are useful for inventory and sizing, not as recommended
envelope lengths. All 22 files have distinct SHA-256 hashes.

| Reference | Seconds | Reference | Seconds |
|---|---:|---|---:|
| `SYS-CLICK` | 1.333 | `SYS-CLICK102` | 1.854 |
| `SYS-CLICK104` | 1.438 | `SYS-CLICK104B` | 1.313 |
| `SYS-BEEP` | 1.417 | `SYS-CANSEL` | 1.333 |
| `SYS-CLOSE` | 1.333 | `SYS-CHAGE` | 2.917 |
| `SYS-CHAGEF1` | 1.625 | `SYS-CHAGEF2` | 1.750 |
| `SYS-DECKSET` | 1.208 | `SYS-DROW` | 1.438 |
| `SYS-SAVELOAD` | 2.083 | `SYS-ITEMGET` | 2.083 |
| `SYS-MONEY-GET` | 1.250 | `SYS-POWER-GET` | 1.250 |
| `SYS-TRESURE` | 1.250 | `SYS-LVUP` | 4.558 |
| `SYS-START` | 2.521 | `SYS-WORLDSELECT` | 1.750 |
| `SYS-WORLDSTART` | 2.250 | `SYS-ALART` | 9.000 |

## Working Tiny Demons grammar

This is an original design hypothesis to validate by audition, not a claim
about the precise construction of the references.

- One shared voice: a dry key/glass tone plus a very short noisy transient.
- Navigation stays below 100 ms; it acknowledges input without becoming a tune.
- Positive actions rise. Reverse actions fall. Denial repeats a tense low shape.
- Routine confirmation uses two events; save/reward/progression use three or four.
- Importance increases through duration and register span, not simply loudness.
- Tails remain dry and short so rapid menu input stays legible.
- A 44.1 kHz stereo render, mild saturation, and 12-bit amplitude quantization
  retain layered detail while providing deliberate handheld texture.

## First candidate pack

`res://tools/generate_ui_sfx.gd` deterministically creates ten original WAVs in
`res://assets/sounds/generated_ui/`:

| Candidate | Intended use |
|---|---|
| `ui_hover` | Cursor movement and focus changes |
| `ui_confirm` | Ordinary acceptance |
| `ui_cancel` | Back/cancel |
| `ui_denied` | Invalid or unaffordable action |
| `ui_open`, `ui_close` | Panels and pause layers |
| `ui_save` | Completed persistence operation |
| `ui_item_get` | Gear/item reward |
| `ui_money_get` | Routine gold reward |
| `ui_level_up` | Major progression |

These candidates are intentionally not wired into `SoundManager` yet. Audition
them against actual menu cadence first; then revise the synthesis recipes and
replace the current stock mappings as a single coherent pass.

### Second-pass layering

The first render established the gesture vocabulary but sounded too sparse. The
current generator gives each cue up to six independently shaped components:

1. A noisy/mechanical key attack with a short resonant knock.
2. A low octave body that gives confirmation physical weight.
3. A pitched fundamental with a small initial pitch snap.
4. Harmonic and inharmonic glass partials with different decay rates.
5. Seeded stereo sparkle grains distributed through the gesture.
6. A quiet high-passed air tail that prevents the tone from feeling isolated.

The generator remains deterministic: the same recipe always produces the same
asset, so individual layers can be tuned reliably after audition.

### Reference-timing correction

PCM envelope analysis showed that the references are longer and more strongly
articulated than the first candidates. Their identity is not merely a bright
timbre; it also comes from discrete micro-events separated by breathing room.

| Tiny Demons cue | Primary anchor | Measured active shape |
|---|---|---|
| Hover | `SYS-CLICK` | About 0.40 s, two articulated bursts |
| Open | `SYS-CLICK104` | About 0.68 s, three bursts |
| Cancel | `SYS-CANSEL` | About 0.46 s, three descending bursts |
| Close | `SYS-CLOSE` | About 0.70 s, five descending bursts |
| Confirm | `SYS-CHAGEF1` | About 0.48 s, one connected gesture |
| Save | `SYS-SAVELOAD` | About 0.90 s, one resolved gesture |
| Item get | `SYS-ITEMGET` | About 0.92 s, two phrases |
| Money get | `SYS-MONEY-GET` | About 0.48 s, four light ticks |

The recipes now follow these event counts and active durations. Texture layers
are kept inside each event, while the quieter continuous air layer was reduced
so it does not fill the intentional gaps.

## Evolutionary click matching

`res://tools/optimize_click_match.gd` is the experimental target-matching path.
It evolves sixteen synthesis parameters covering oscillators, pitch sweep,
envelopes, inharmonic partials, noise, body, delay, drive, and quantization.

Candidates are peak-normalized and compared using weighted envelope, transient,
zero-crossing, full-spectrum, and early-spectrum losses. The displayed score is
calibrated such that 0 is no better than silence and 100 is feature-identical;
it is an engineering ranking, not a claim of perceptual identity. Every output
includes JSON parameters and generation history for reproducible iteration.

Initial 18-generation results:

| Target | Calibrated score |
|---|---:|
| `SYS-CLICK` | 91.47 |
| `SYS-CLICK102` | 48.34 |
| `SYS-CLICK104` | 80.68 |
| `SYS-CLICK104B` | 87.29 |

`CLICK102` is a useful model-capacity failure: the optimizer improved it, but
the current oscillator/noise/delay topology cannot reproduce enough of its
measured structure. The next synthesis expansion should be justified against
that failure rather than added generically to every sound.

## Validated multi-resolution metric

The coarse evolutionary score above is retired. Its global spectral buckets
discarded when frequencies occurred and could award a strong number to an
obviously incorrect sound.

`res://tools/validate_audio_match_metric.gd` implements the replacement:

- Hann-windowed STFT comparisons at 128, 512, and 2048 samples.
- Log-magnitude and spectral-convergence losses at every resolution.
- Independently weighted attack, body, and tail regions.
- A 96-bin compressed loudness-envelope loss.
- A low-weight, alignment-sensitive waveform-correlation loss.
- RMS normalization, silence trimming, and a ±25 ms alignment search.
- Score calibration based on actual cross-click distances.

The metric passed its initial invariance and discrimination suite:

| Validation | Score |
|---|---:|
| Exact self-match | 100.00 |
| Gain reduced to 35% | 100.00 |
| 20 ms front padding | 100.00 |
| 4 ms time shift | 100.00 |
| Unrelated generated level-up cue | 4.92 |

All four reference clicks score 100 against themselves. Cross-click scores are
lower and preserve meaningful family resemblance: for example, `CLICK` versus
`CLICK104B` scores 45.2, while `CLICK` versus the more distinct `CLICK102`
scores 1.5. Full component results and the cross-click matrix are stored in
`res://tools/audio_match_metric_report.json`.

### Staged search result

The second optimizer topology expands the search to multiple timed events, FM,
colored noise, resonant excitation, inharmonic partials, body tone, echo, drive,
and quantization. A 36-member population ran for 24 generations and retained
eight `SYS-CLICK` finalists.

The cheap exploration proxy improved from 50.58 to 92.13, but the validated
multi-resolution reranker scored the finalists from 30.07 to only 35.14. The
proxy winner actually ranked last under the accurate metric. This is a useful
negative result: the staged system prevents a coarse optimization signal from
being mistaken for perceptual similarity.

`sys-click_proxy_02.wav` is the current selected diagnostic candidate. A score
of 35.14 is not sufficient for adoption; its component losses and complete
ranking are stored beside it in `sys-click_rerank.json`.

### Practical reconstruction target

Audition feedback establishes 50–60 as a reasonable working range for an
original but convincingly related reconstruction. Scores remain a ranking aid;
acceptance still requires listening.

The 35.14 `SYS-CLICK` candidate's losses identify the next modeling priority:

| Component | Loss | Interpretation |
|---|---:|---|
| Attack | 0.5780 | Directionally useful, still improvable |
| Body | 1.7975 | Primary mismatch |
| Tail | 0.5560 | Directionally useful |
| Envelope | 0.2809 | Broad loudness shape is relatively close |
| Waveform | 0.9993 | Fine structure remains substantially different |

The next topology should replace the shared exponential body with a modal bank:
independently tuned resonances, separate decay constants, deterministic phase,
spectral tilt, slight frequency drift, and a short excitation signal. This can
produce an evolving struck/sampled texture while remaining original synthesis.

### Modal-body result

The modal bank was implemented with seven independently decaying resonances per
event. Evolution controls modal spacing, spectral tilt, base decay, per-mode
decay spread, drift, inharmonic oddity, excitation decay, and overall modal mix.

The validated `SYS-CLICK` score improved from 35.14 to **51.89**, reaching the
practical reconstruction range. The body loss fell from 1.7975 to 0.7689; attack
improved from 0.5780 to 0.5356, tail from 0.5560 to 0.4676, and envelope from
0.2809 to 0.2485. This confirms that evolving resonant texture—not additional
generic layering—was the missing synthesis capability.
