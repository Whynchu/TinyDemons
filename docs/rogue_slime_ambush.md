# Shadow Slime (Purple Variant) — Design & Implementation

## Objective

The purple **Shadow Slime** uses the same
purple colors the player can choose, and forces a change in combat habits via a
sneak/ambush mechanic:

- While hiding/sneaking: **transparent + darker** (partial opacity, darkened
  `self_modulate`), **untargetable** (cannot be lock-on targeted) and
  **unhittable** (player attacks pass through).
- The slime stays hidden through the attack windup and only reveals on the
  **strike frame** (the frame it can actually hit the player). This forces the
  player to dodge or block rather than hit it out of the swing with knockback.
- Revealed Shadow Slimes are **hittable for only 0.5s after the strike**, then they
  re-hide and stalk again.
- If the player **blocks** the Shadow Slime's attack, it is **stunned for 1 second**
  (stays revealed/hittable, cannot act) before continuing its routine.
- **Being hit extends the time until it re-hides** slightly.
- Stats profile: **very strong STR and DEF, very low VIT** (a new
  `FAVOR_STR_DEF` allocation profile).

## New Files

- `scripts/slime_ambush_component.gd` — `SlimeAmbushComponent` (extends Node)
  attached only to purple slimes. Owns the sneak state machine:
  - `active`, `hidden`, `reveal_timer`, `reveal_window`, `block_stun`
  - `configure(active, reveal_window, block_stun, hit_extension)`
  - `apply_hidden(actor)` / `reveal(actor)` / `begin_rehide(actor, window)` /
    `begin_block_stun(actor)` / `extend_rehide(actor, amount)` /
    `tick(actor, delta)`
  - Hidden visual: `Color(0.55, 0.55, 0.62, 0.5)` via `self_modulate`
    (transparent + darker). Revealed: `Color.WHITE`.

## Modified Files

### `scripts/slime_visual_component.gd`
- `_palette_color()`: added `"purple"` mapping
  `{"257179": Color8(67,47,102), "38B764": Color8(118,78,142), "A7F070": Color8(200,184,210)}`
  — dark/mid colors match the player purple palette; the `A7F070` highlight is a
  lighter lavender (a blend of the purple tones) rather than the near-white used
  by the other palettes, so the highlight reads as a shaded purple instead of a
  stark white cap. The tiny `F4F4F4` specular glint stays white (same as every
  other palette).
- `build_attack_frame_library()`: added `"purple"` recolored attack frame set.
- `build_shocked_frame_library()`: added `"purple"` recolored shocked frames.
- `recolor_direction_textures(slimes, palette, cache)` and
  `recolor_direction_texture(source, palette, cache)`: generate purple left/right
  idle textures by recoloring the green ones (no `SlimePurpleLeft.png` artwork).

### `scripts/stats_component.gd`
- `AllocationProfile`: appended `FAVOR_STR_DEF` (index 4 — existing scene ints
  3/1/2 for blue/green/red are unchanged).
- Base profile: `{VIT:1, STR:3, DEF:3}`. Growth weights: `{VIT:0.12, STR:0.44, DEF:0.44}`.

### `scripts/slime_tuning.gd`
- `ambush_reveal_window := 0.5` — seconds a revealed Shadow Slime stays hittable after
  its strike before re-hiding.
- `ambush_block_stun := 1.0` — seconds a blocked Shadow Slime is stunned and stays
  revealed before continuing its routine.
- `ambush_hit_extension := 0.5` — added to the reveal window on each player hit.

### `scripts/slime_actor.gd`
- `@export_enum("blue","green","red","purple")` for `variant`.
- `tick_components(delta)` now ticks the `Ambush` node if present.
- `apply_attack_hit()`: on a blocked swing, a Shadow Slime (Ambush node present) gets
  `begin_block_stun()` plus its hitstun/cooldown extended to `block_stun`, so it
  is stunned for the full second and cannot resume attacking immediately.

### `scripts/gameplay.gd`
- `_configure_slime_variant()`: accepts `"purple"`, sets `FAVOR_STR_DEF`, calls
  `_configure_slime_ambush()`.
- `_configure_slime_ambush(slime, palette)`: adds/activates the `Ambush` node for
  purple (starts hidden); deactivates and resets `self_modulate` for other palettes.
- `_slime_ambush()` / `_is_slime_hidden()` / `_is_slime_targetable()` helpers.
- `_damage_slime()`: calls `ambush.extend_rehide()` before applying damage.
- `_start_slime_attack()`: **no reveal** — the rogue stays hidden through the
  windup so the player cannot knock it out of the swing.
- `_apply_slime_attack_hit()`: `ambush.reveal()` + `begin_rehide(window)` on the
  strike frame — this is the exact frame it can hit the player.
- `_update_slime_attack()`: no re-hide hook; the reveal window from the strike
  governs the re-hide timing.
- `_prepare_slime_frame_cache()`: hidden slimes skip the notice "!" burst (they
  sneak silently) but still aggro/approach.
- `_closest_target()`: passes `_is_slime_targetable` to target lock.
- `_slime_display_name()`: `"Shadow Slime"` for purple.
- `_build_slime_direction_textures()`: purple sources the green idle textures then
  recolors them to purple.

### `scripts/interaction_component.gd`
- `closest_target()`: new optional `is_targetable` callable (skips hidden slimes).
- `update_targeting()`: clears target if it is no longer targetable (e.g. re-hides).

### `scripts/player_attack_component.gd`
- `apply_hitbox()`: uses `_is_slime_targetable` so hidden rogues are unhittable.

### `scripts/hud_controller.gd`
- `update_overhead_bars()`: new optional `is_hidden_for` callable — hidden rogues
  show no overhead HP bar/aggro marker.
- `update_overworld()` passes `_is_slime_hidden`.

### `scripts/room_controller.gd`
- `_generate_enemy_encounter()`: purple joins the normal-room variant pool with a
  reduced weight (0.6 vs 1.0) starting at room depth 3. Boss encounters
  (`_generate_boss_encounter`) keep `["blue","green","red"]` — no purple boss.

## Behavior Summary

1. Room spawn: purple Shadow Slimes start hidden (faint, dark purple, ~50% alpha).
2. Hidden slimes aggro by range and sneak toward the player — no notice burst.
3. When within attack reach, the attack windup starts — the Shadow Slime is **still
   hidden** through the windup, so the player must dodge or block, not punish it
   with knockback.
4. On the **strike frame** (the frame it can hit the player) the Shadow Slime reveals.
5. It stays revealed/hittable for 0.5s (`ambush_reveal_window`), then re-hides
   and the loop repeats.
6. Player hits during the revealed window extend it (+0.5s each).
7. If the player **blocks** the strike, the Shadow Slime is stunned for 1s
   (`ambush_block_stun`): it stays revealed (hittable) and cannot act, then
   re-hides and continues its routine.

## Verification

- `Godot --headless --check-only` — no script errors.
- `tests\run_all_smoke.ps1` — run_grade / progression / item_economy /
  **rogue_slime** / 30s main scene headless all PASSED.
- `tests\rogue_slime_smoke.gd` (added to the suite): verifies `FAVOR_STR_DEF`
  base stats and that VIT stays relatively lower than the balanced profile,
  that the purple recolor introduces purple mid tones and removes green tones,
  and the full ambush state machine (hidden -> strike reveal -> 0.5s window ->
  block stun 1s -> re-hide -> hit extension).

## Notes

- Editor note: the open editor predates these changes — reload the project
  (Project → Reload Current Project) so the new `SlimeAmbushComponent` class and
  cache updates are picked up.
