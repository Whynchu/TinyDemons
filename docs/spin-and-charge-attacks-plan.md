# Spin and Charge Attacks

Status: implemented; current combat follow-up is being integrated on the active
gear/combat branch.

This slice adds two physical attack options while preserving the existing
directional Attack 1 → Attack 2 combo:

- A fast circular movement on the merged left-stick/D-pad/keyboard/touch
  movement stream arms Spin Attack. Pressing Attack while it is armed performs
  the spin; clockwise and counter-clockwise circles are accepted. The spin
  snapshots the movement direction at activation and applies only a small,
  fixed lunge so the gesture has directional influence without becoming a
  second dodge.
- Holding Attack performs Attack 1, enters the existing post-Attack 1 pose, and
  waits in a charge state. Releasing after the minimum charge starts a slower,
  stronger charged Attack 2. Releasing before the threshold cancels the charge.
  A normal second Attack press still performs the existing regular Attack 2.

## Spin animation and editor hitboxes

The supplied eight-frame sheets are imported under `assets/artwork/` and baked
for every player palette. The scene contains:

`Actors/TinyDemon/SpinAttackHitboxShape`

Its `AttackHitboxGuide` has `use_frame_hitboxes` enabled and exposes these
editable `Polygon2D` children:

`HitboxFrame0`, `HitboxFrame1`, `HitboxFrame2`, `HitboxFrame3`,
`HitboxFrame4`, `HitboxFrame5`, `HitboxFrame6`, and `HitboxFrame7`.

Select `SpinAttackHitboxShape` in the Godot editor, change `frame_index` to
preview each art frame, and edit that frame's child polygon. The runtime asks
the guide for the polygon matching `player_anim_frame`; horizontal facing is
mirrored using the same guide transform as the existing attacks.

Frames 3–6 are the active attack window and are checked one at a time. A
target can only be registered once per spin, so the per-frame polygons allow
the active arc to be tuned without multi-hitting an enemy. Frames 6–7 are the
slower recovery tail, with frame 7 being the clean recovery pose.

## Tuning contract

All feel and balance values live on `scripts/player_tuning.gd`:

- Spin requires at least `0.55` movement magnitude, approximately `288°` of
  signed turn, and must complete within `0.50s`. Recognition arms the move for
  `0.28s`.
- Spin uses `0.075s` frame timing, slows to `0.14s` from frame 6, applies
  `0.90x` damage and `1.10x` knockback, and does not split damage across
  multiple enemies. Its `spin_lunge_distance`/`spin_lunge_duration` provide a
  small input-direction impulse. This makes its single-target hit slightly
  weaker than a normal Attack 1 while rewarding a clean multi-target spin.
- Charge begins after `0.35s`, caps at `1.00s`, and uses Attack 2's art with a
  `1.35x` frame-time multiplier, `1.60x` damage, and `1.50x` knockback.
- While charging, a foot-level air aura emits sparse palette-tinted pixels. Its
  cadence, outward speed, rise, curl, and streak length ramp toward the charge
  cap; the peak reads as whipping air rather than a Chroma or hurt flash.
- A run attack skips Attack 1 and starts the regular Attack 2 animation as a
  dedicated variant. It captures the run state, uses separate
  damage/knockback/hitstop tuning, and adds `1.5` Attack 2 frame times to
  recovery. Starting it consumes the roll-continuation run state.

These are starting values, not a promise that the final combat balance is
locked. The frame ranges and coefficients are intentionally inspector-editable.

## Priority and integration rules

1. Spin has priority over a normal first swing when its gesture is armed and
   Attack is pressed.
2. Spin uses a small snapshot-direction lunge. Normal Attack 1/2 lunge behavior
   remains unchanged unless the run Attack 2 route explicitly owns the swing.
3. Both attacks snapshot the current weapon element at their actual attack
   start, so elemental weaknesses, orb reactions, damage colors, and Imbue all
   use the same combat path.
4. Charged Attack 2 uses the existing finisher telemetry and transmutation
   hooks. Spin is recorded as a primary swing for compatibility with existing
   combo/equipment hooks.
5. Any room reaction, hitstun, roll, death, or scene interruption clears the
   gesture/charge state through the existing attack cancellation path.

## Verification

The focused checks are:

```powershell
& $godot --headless --path TinyDemons -s res://tests/circular_input_smoke.gd
& $godot --headless --path TinyDemons -s res://tests/spin_charge_scene_smoke.gd
```

`tests/run_all_smoke.ps1` includes both checks and the existing attack shadow,
elemental, equipment, touch, display, and web-export checks.

The spin balance regression is covered by:

```powershell
& $godot --headless --path TinyDemons -s res://tests/spin_damage_smoke.gd
```

It compares a normal Attack 1 against a one-target spin, verifies the spin's
reduced coefficient, and verifies that two spin targets each receive the full
undivided spin amount while a two-target normal attack is split. Running Attack
2 routing, directional lunge, extra recovery, and the charge aura are covered
by `run_locomotion_smoke.gd` and `spin_charge_scene_smoke.gd`.
