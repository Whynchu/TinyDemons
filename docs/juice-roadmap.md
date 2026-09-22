# Tiny Demons — Juice Roadmap

Status: active plan
Scope: player-facing feel and feedback across collection, HUD, combat impact,
camera, transitions, audio, haptics, accessibility, and VFX scaling
Owner: presentation owners per slice; `effects_spawner.gd` owns VFX, with
`hud_controller.gd` on HUD reactions and `gameplay_frame_controller.gd` on
schedule and hitstop
Current code: feedback is code-built; see the inventory in [`../JUICE.md`](../JUICE.md).
The strict composition scorecard is at 100% and the explicit frame schedule is
centralized.
Verification: focused smokes per slice plus the curated gate; record results
before marking a slice complete. No slice is verified by source presence alone.
Supersedes: none

## Intent

Close the feedback holes inventoried in [`../JUICE.md`](../JUICE.md) so the game
reads as confident minimalism rather than missing polish. The work raises the
*ceiling* of feedback without disturbing the refactor's ownership, the explicit
frame schedule, or the native/web renderer parity that the web-export smoke
guards.

## Non-goals

- No rewrite of `gameplay.gd` or `gameplay_state.gd`.
- No combat balance changes mixed into structural feedback work.
- No change to save identity, room generation, or content definitions.
- No process-per-effect or `_process()`-driven feedback that bypasses the frame
  schedule.

## Constraints

- **Frame schedule.** Feedback is wired into `gameplay_frame_controller.gd` or
  ticked by its owner. Hitstop is a frame-scheduled timer, not
  `Engine.time_scale`.
- **Ownership.** Add behavior to the narrowest owner from `AGENTS.md`. Cross-owner
  feedback uses a typed result/signal at the boundary.
- **Renderer parity.** Native `mobile`, web `gl_compatibility`. Every change must
  behave on both.
- **Measured scenario rule.** Per
  [`review/03-production-and-architecture-state.md`](review/03-production-and-architecture-state.md),
  do not prescribe renderer or pooling changes without an identified measured
  scenario. Slice J0 exists to satisfy this before J2 and J6.
- **Determinism.** Feedback that focused tests characterize stays deterministic.
  Decorative layers may use GPU work only behind the quality gate below.

## VFX scaling decision

**Decision: commit to `GPUParticles2D` for new burst and trail effects**, owned
by `effects_spawner.gd`, subject to the following gates:

1. **Baseline first.** Slice J0 records frame time, memory, and render cost for
   dense combat, boss combat, effects-heavy rooms, and web export before any
   particle change lands.
2. **Quality tier.** A particle-quality setting caps emitter `amount` and
   disables non-critical emitters on the low tier. The low tier is the default
   on detected low-end devices and web until measured otherwise.
3. **Pixel-art material.** Nearest filtering, no mipmaps, palette shader
   integration so particle color follows the existing palette path. No blurry
   additive quads.
4. **Parity check.** The web-export smoke and a web/browser playtest must stay
   green; native and web must not diverge in behavior.
5. **Escalation gate.** If the A17 or web measurement regresses, the fallback is
   a pooled CPU `MultiMeshInstance2D` emitter for decorative layers, with
   gameplay-critical effects retained in the deterministic sprite system.

Rationale for the ceiling: the current per-node `Sprite2D` system caps particles
(20 damage numbers, 90 particles) because each particle is a node with script
math. `GPUParticles2D` removes that ceiling. The accepted risk is device variance
on the compatibility/web path, mitigated by the baseline, the quality tier, and
the parity check above.

## Slices

Work each slice in the roadmap's five-step shape: characterize, document the
owner and boundary, make the smallest change, run focused verification and a
manual check, then record the result.

### J0 — Feedback measurement baseline

Establish the measured scenario the boundary requires. Capture frame time,
memory, and render cost in title, Hub, ordinary room, dense combat, boss combat,
transitions, effects-heavy rooms, web export, and touch input, on desktop and
the Samsung A17 profile if available. Record the numbers in
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) or the performance plan. This slice gates
J2 and J6.

Evidence: captured measurements and a written baseline; no code behavior change.

### J1 — Collection and currency feedback (first slice)

The selected first slice. Highest visibility, no new architecture.

- **Delivery-to-HUD.** On collection, a transient icon arcs from the world
  position to the target HUD node's screen position, then fires the HUD
  acknowledgment. Applies to Chroma, Souls, and items.
- **Gold becomes a world collectable.** The chest rolls its total from
  `_chest_gold_reward`, then decomposes it into denomination coins that arc out,
  rest, bob, and auto-collect on proximity, reusing the chroma pickup path and
  the `GoldFresh2.png` spin frames (`hud_controller.gd:815`) as the world sprite.
- **Payout invariant.** Coins sum to exactly the value `_chest_gold_reward`
  returns today. No economy change, no save migration. Value is granted per
  coin on collection; to keep the payout identical when a player leaves coins
  behind, remaining coins are vacuum-collected or granted on room exit.
- **Denomination ladder.** Value maps to color, rupee-style, calibrated to the
  observed total range (base `CHEST_REWARD_GOLD = 100`, rolled ×0.75–1.30,
  ×run-rank/loot up to 1.90, ×0.50 regular treasure → roughly 40–250). Proposed
  tiers: copper = 1, blue = 5, red = 10, purple = 25, gold = 50.
- **Decomposition rule.** Bias toward a satisfying coin count (roughly 4–10)
  rather than pure largest-first, so a chest sprinkles coins instead of dropping
  two. Sum must remain exact; cap total coins spawned at 12–16 so a large chest
  does not flood the room.
- **Burst parity.** Souls gain a collection burst matching Chroma.
- **HUD acknowledgment.** Gold and soul counters count up and scale-punch;
  the Chroma/MP fill tweens instead of snapping.

Owner: `pickup_runtime_controller.gd`, `chest_controller.gd`,
`effects_spawner.gd`, `hud_controller.gd`.
Acceptance: the chest visibly drops colored coins instead of granting gold
instantly; coins auto-collect on proximity; the sum collected equals the current
payout; the gold counter counts up after delivery lands; no counter snaps;
Chroma fill tweens; layer order is correct over the world and under menus;
native and web match.

Resolved decision: gold auto-collects on proximity, chroma-consistent.

### J2 — Combat impact

Particle work follows the **information vs texture** split: particles add
*texture* (sparks, embers, dust, trails, debris) while information (flash,
damage number, crit outline, bars, knockback) stays deterministic.

- Regular-hit particle burst (first use of the new emitter path).
- Damage-number scale pop.
- Screen-shake via the camera node introduced in J4, or a temporary
  world-layer offset if J2 lands first. Shake is a decaying value driven by the
  frame schedule, not a new `_process()`.
- Critical-hit distinction by weight and camera, not color alone.
- Hitstop duration/curve tuning review (no balance change to damage).

Owner: `combat_runtime_controller.gd`, `effects_spawner.gd`,
`player_attack_component.gd`, `display_controller.gd`, `gameplay_frame_controller.gd`.
Acceptance: every landed hit bursts; damage numbers pop; shake scales with
impact and decays; crits feel heavier than normal hits; particle density does
not obscure telegraphs or hitboxes at 240×160; no frame-schedule regression.

Resolved decision: screen shake is owned by a real camera node (see J4), not a
CanvasLayer offset.

### J3 — Bars and affordability

- Tween Chroma and XP fills using the existing health-bar model.
- Counter punch for combo and any remaining instant counters.
- Unaffordable-cost visual on HUD costs and shop rows, layered on the existing
  deny sound.

Owner: `hud_controller.gd`, `magic_runtime_controller.gd`, shop layouts.

### J4 — Transitions and camera

- Introduce a real gameplay `Camera2D` as the single owner of screen shake,
  lookahead, and impact zoom. This is a **display-layer restructure**: the world
  currently renders through `BackgroundCanvas`/`InterfaceCanvas` with no camera
  (`main.tscn`), so characterize the current layer/offset behavior before
  moving the world under a camera.
- Room-to-room wipe or fade replacing the instant swap.
- Large-room camera lookahead; optional subtle impact zoom.

Owner: `room_controller.gd`, `gameplay_frame_controller.gd`,
`room_geometry_controller.gd`, display/layout owners.
Risk: highest-risk slice; changes the presentation foundation. Requires
characterization coverage of existing world placement before the move.
Resolved decision: camera node is the end state, not a CanvasLayer offset.

### J5 — Audio hierarchy

- Dedicated SFX and Music buses; route players off `Master`.
- Music ducking on high-priority reward and impact moments.
- Extend random-variant and pitch-variation coverage to pickups, footsteps, and
  menu confirms.

Owner: `sound_manager.gd`, `sound_mix_profile.gd`, `sound_clip_catalog.gd`.

### J6 — VFX scaling

Land the committed `GPUParticles2D` path under the gates above: emitter
infrastructure in `effects_spawner.gd`, palette material, quality-tier setting,
and the web/A17 measurement that confirms the escalation gate did not trip.
Texture-layer effects migrate first; information-layer effects stay
deterministic.

Combat texture-layer candidates (split by role, not "decorative vs critical"):

- melee hit sparks and impact dust;
- elemental hit signatures: embers, ice shards, lightning crackle, poison
  bubbles;
- critical-hit flourish and shockwave ring;
- projectile trails (replacing the current 1-pixel/beam-stamp trail);
- charge-up aura and status auras (burn, frozen, shocked);
- roll/landing dust and enemy death debris.

Information layer that stays deterministic sprite: hit flash, damage number,
critical outline, health bars, knockback, and hitstop. Cap particle counts for
readability at 240×160, not only for performance.

Owner: `effects_spawner.gd`, settings/display owners for the quality tier.

### J7 — Haptics

Add controller rumble alongside the existing mobile handheld haptics through a
single decision seam, so one feedback event drives visuals, audio, and both
haptic channels.

- Route rumble via `Input.start_joy_vibration` using the connected-pad
  enumeration in `input_router.gd`; skip cleanly when no pad is connected.
- Choose weak/strong magnitude and duration by event weight: player connects,
  crit, enemy kill, block/guard, **enemy hits player**, player death,
  boss/level-up, low-health heartbeat. See the JUICE.md mapping table.
- Combat pulses fire from the same resolution points that set hitstop, hit
  flash, and hit SFX (`combat_runtime_controller.gd`, `slime_actor.gd`) so the
  pulse is synchronized with the freeze and sound.
- "Enemy hits player" is the highest-priority pulse and must read clearly.
- Cooldown or merge rapid multi-hits so rumble does not buzz continuously.
- Reuse the existing `vibration` setting as the gate; feature-detect web rumble.
- The seam is the natural first consumer of the feedback event bus (see tooling
  follow-ups).

Owner: `input_router.gd`, `touch_controls_layer.gd`, `settings_service.gd`, and
the feedback seam.
Acceptance: connected pads rumble on the mapped events with distinct
magnitudes; mobile handheld vibration is unchanged; the `vibration` toggle
suppresses both channels; no pad connected produces no error; web degrades
gracefully when rumble is unsupported.

### J8 — Accessibility and comfort

Modern-standard comfort controls, especially because J2/J4 add shake and flash.

- Reduced-motion / screen-shake toggle and intensity.
- Flash-intensity cap for photosensitivity.
- Colorblind-safe elemental and status tells that never rely on color alone
  (fits the information vs texture split).
- Haptic intensity or on/off; per-bus volume once J5 lands.
- Surface all of these in the settings screen through `settings_service.gd`.

Owner: `settings_service.gd`, `screen_state_controller.gd`, display/effects
owners.

## Verification

- Each slice adds or updates focused coverage before it is marked complete, and
  `tests/manifest.csv` is updated when tests are added or retired.
- Run the relevant focused smoke, then the curated gate; record the result in
  [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) or [`AUDIT.md`](AUDIT.md).
- Manual checks cover native 240×160, a wider browser view, and touch, matching
  the discipline in
  [`ui-consistency-and-touch-polish-plan.md`](ui-consistency-and-touch-polish-plan.md).
- J0, J2, and J6 additionally require device-backed timing evidence.

## Documentation follow-ups

- After J1 lands, consider recording a bounded feedback phase in
  [`ROADMAP.md`](ROADMAP.md); Phase 0.70 covers feedback *test* infrastructure,
  not game feel, so this plan is the game-feel authority.
- Regenerate [`SCRIPT_INDEX.md`](SCRIPT_INDEX.md) with
  `tools/generate_script_index.ps1` whenever feedback scripts are added or
  materially split.

## Resolved decisions

1. Gold is a world collectable: chests drop denomination coins (J1).
2. Screen shake is owned by a real `Camera2D`, not a CanvasLayer offset (J2/J4).
3. `GPUParticles2D` covers both texture layers, split by information vs texture
   role rather than decorative vs critical (J2/J6).
4. Feedback animation uses a **shared frame-driven animator**, not raw
   `create_tween()`, so timing stays under the frame schedule and respects
   hitstop/pause (spans J1–J4). `create_tween()` remains for pure menu chrome,
   as in `menu_cursor.gd`.

## Animation mechanics contract

Gameplay feedback animation (count-ups, HUD punches, delivery arcs, shake
decay, scale pops) is ticked once per frame from `gameplay_frame_controller.gd`
through a shared registry, mirroring how `effects_spawner.gd` already hand-rolls
particle state. This keeps one timing authority and avoids SceneTree tweens
continuing to run during hitstop.

## Open decisions

1. Confirm the proposed denomination ladder (1 / 5 / 10 / 25 / 50) and
   coin-spawn cap as tuning values during J1; they are presentational and can
   change without touching the payout.
2. Confirm the room-exit safeguard (vacuum remaining coins vs grant remainder)
   that preserves the current payout when a player leaves coins behind (J1).
3. Haptics control: keep the existing on/off `vibration` toggle, or add a
   magnitude/intensity setting for both channels (J7).
