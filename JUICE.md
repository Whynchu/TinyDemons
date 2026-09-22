# Tiny Demons — Juice and Player-Facing Feel

Status: current authority for player-facing feel and feedback direction
Scope: pickup delivery, HUD reactions, combat impact, menu and touch motion,
camera, transitions, and audio hierarchy
Owner: presentation owners named per system below; coordinated through
`effects_spawner.gd`, `hud_controller.gd`, and `gameplay_frame_controller.gd`
Current code: the feedback systems are code-built. `effects_spawner.gd` is the
single VFX owner; the HUD is authored in `scenes/player_hud.tscn` and driven by
`hud_controller.gd`; the explicit frame schedule in `gameplay_frame_controller.gd`
owns update order
Verification: see [`docs/juice-roadmap.md`](docs/juice-roadmap.md); this document
records direction and inventory, not a test result
Supersedes: none

This is the authority referenced by
[`docs/DOCUMENTATION_MAP.md`](docs/DOCUMENTATION_MAP.md) for the question "What
is the player-facing feel and feedback direction?". The active work that closes
the gaps recorded here lives in
[`docs/juice-roadmap.md`](docs/juice-roadmap.md). The external presentation
review framing is in
[`docs/review/04-presentation-and-player-experience-brief.md`](docs/review/04-presentation-and-player-experience-brief.md).

## Purpose

The game is a compact pixel-art isometric action game. Its feel must read as
intentional minimalism, not as missing animation, audio, hierarchy, or feedback.
The review brief already names the failure mode: the minimalist style should
"communicate confidence" rather than "expose missing animation, audio, visual
hierarchy, or feedback."

This document defines the response contract for every repeated player-facing
event, records which contracts are currently met, and lists the holes. Code and
tuning values remain the source of truth for numbers; this document is the
source of truth for *what response must exist*.

## Feel principles

1. **Cause is immediate; reward is legible.** Every input and world event gets a
   visual and/or audio response within one frame of the frame schedule. Nothing
   that matters resolves silently.
2. **Currency is delivered, not incremented.** Gold, Chroma, Souls, and items
   visibly travel from the world to the HUD before the number changes.
3. **The HUD acknowledges its own change.** The specific readout that changed
   reacts: counters count up and punch, bars tween and never snap, the affected
   element acknowledges affordability.
4. **Impact has weight.** A landed hit layers flash, particle burst, damage
   number, knockback, sound, haptics, and a micro-freeze. Removing any layer
   should be a deliberate choice, not an omission.
5. **Motion is authored, not instant.** State changes and screen changes
   transition. Instant swaps are reserved for moments where abruptness is the
   point.
6. **Feedback is layered and hierarchical.** Moment-to-moment feedback outranks
   run-level feedback, which outranks meta feedback. Audio follows the same
   hierarchy: gameplay-critical > reward > ambience.
7. **Minimalism is a choice, not an absence.** A missing response is a bug in
   feel even when the pixels are correct.
8. **Determinism is not sacrificed for juice.** Feedback that focused tests
   characterize stays deterministic and inspectable. Decorative layers may use
   GPU work when measured and gated (see the roadmap's VFX decision).

## Response contracts

### Pickup delivery

Every collectable follows the same chain: spawn → world motion (arc, bob,
scale pulse) → proximity collection → **delivery to the HUD** → HUD
acknowledgment. The delivery and acknowledgment legs are the current gap.

- Chroma: world arc, bob, scale pulse, burst, floating text, and sound exist.
  Delivery to the HUD does not.
- Souls: world arc and bob exist. Burst, delivery, and HUD acknowledgment do
  not.
- Items: chest drop arc and "acquired" text exist. Delivery to the HUD does
  not.
- Gold: **currently has no world pickup** — it is granted instantly from chests.
  The agreed direction is rupee-style: chests roll a total, decompose it into
  denomination coins (value = color = denomination), and drop them as
  auto-collecting pickups that arc, rest, bob, and deliver to the gold readout.
  The world sprite reuses the HUD `GoldFresh2.png` spin frames. The **payout
  total is unchanged** — coins only present the same value that chests grant
  today, so there is no economy or save migration. Value is granted per coin as
  it is collected.

### HUD reactions

- Health: drain animation with a damage hang exists and is the model for other
  bars.
- Chroma/MP: fill **snaps** to the new value; it must tween.
- XP/level: fill snaps; it must tween.
- Currency counters: gold and souls update by **texture swap only**; they must
  count up and scale-punch on change.
- Combo: updates texture and fill with no punch; it must acknowledge the change.
- Affordability: no HUD cost feedback exists. Ability cooldown icons carry an
  unavailable/flash shader; shop rows only play a deny sound. Costs the player
  cannot afford should read visually.

### Combat impact

- Hit flash: exists for enemies and the player.
- Hitstop: exists as a custom timer in `gameplay_frame_controller.gd`; it is not
  `Engine.time_scale` and must stay frame-scheduled.
- Knockback: exists for player and enemies.
- Damage numbers: exist with shadow and critical outline; they do **not** scale
  pop.
- Death: enemy pixel-debris and player death sequence exist.
- Regular-hit particle burst: **missing.** Particles fire only for pickups,
  chests, deaths, ambient fire, charge aura, and roll dust.
- Screen shake: **missing** everywhere.
- Critical hits: differentiated by color, outline, number, and audio; not by
  weight or camera.

Combat feedback splits into two roles. The **information layer** — hit flash,
damage number, critical outline, health bars, knockback, and hitstop — stays
deterministic and readable at 240×160. The **texture layer** — sparks, elemental
signatures, crit flourishes, trails, auras, dust, and debris — may use GPU
particles. Particle density must never obscure telegraphs or hitboxes; counts
are capped for readability, not only performance.

### Menu and touch motion

- Cursor: tweened glide with a looping bob exists.
- Button press: prompt brightening and touch haptics exist.
- Deny/invalid: sound only; no visual rejection.
- Disabled/unaffordable commands: cooldown-shader feedback only in gameplay.

### Audio hierarchy

- Event coverage is broad (`sound_clip_catalog.gd`); enemy hits have random
  variants; critical and imbue use Perlin pitch variation; music fades exist.
- Music ducking and dedicated SFX/Music buses are **missing**; every player
  currently routes through `Master`.

### Haptics

There are two haptic channels and they should share one decision seam.

- Mobile handheld vibration: exists for discrete touch button presses
  (`touch_controls_layer.gd`), gated by the `vibration` setting.
- Controller rumble: **missing** — no `Input.start_joy_vibration` usage exists.

Contract: a single haptics seam drives both channels, gated by the existing
`vibration` setting, with weak/strong magnitude chosen by event weight and a
cooldown or merge that prevents continuous buzz on rapid multi-hits. Device
enumeration reuses `input_router.gd`, and web rumble is feature-detected because
Gamepad API support is inconsistent.

**Combat haptics are part of impact weight.** The same resolution points that
already set hitstop, hit flash, and hit SFX must also request haptics, so the
pulse lands in sync with the freeze and the sound. Mapped events:

| Event | Weak | Strong | Duration |
|---|---|---|---|
| Menu confirm / light press | low | none | short |
| Player melee/projectile connects | low | low | short |
| Critical hit lands | medium | medium | short |
| Enemy killed | medium | medium | short |
| Block or guard impact | low | medium | short |
| **Enemy hits the player** | none | **high** | **medium** |
| Player death | medium | high | long |
| Boss / level-up / floor clear | medium | high | long |
| Low-health heartbeat | low | none | periodic |

"Enemy hits the player" is the highest-priority pulse: it must be unmistakable
even when the player's attention is on the attacking enemy rather than their own
health. Rapid multi-hits merge into one pulse rather than stacking.

### Camera and transitions

- Scene reload fade, loading fade, and the title pixel-breakup intro exist.
- Room-to-room transitions are an **instant swap** with no wipe or fade.
- Follow smoothing exists only for large rooms. There is no gameplay camera in
  normal rooms, so screen shake, lookahead, and impact zoom need a new seam.

## Current inventory

| System | Status | Owner |
|---|---|---|
| Chroma pickup world life + burst + text + sound | Exists | `pickup_runtime_controller.gd`, `effects_spawner.gd` |
| Soul pickup world life | Exists | `pickup_runtime_controller.gd` |
| Soul pickup burst | Missing | `pickup_runtime_controller.gd` |
| Pickups fly to HUD | Missing | `pickup_runtime_controller.gd`, `hud_controller.gd` |
| Gold world pickup | Missing | `chest_controller.gd`, `pickup_runtime_controller.gd` |
| Currency count-up / HUD punch | Missing | `hud_controller.gd`, `gameplay_state.gd` |
| Enemy/player hit flash | Exists | `combat_runtime_controller.gd`, `slime_actor.gd` |
| Hitstop | Exists | `gameplay_frame_controller.gd` |
| Knockback | Exists | `actor_motor.gd`, `combat_runtime_controller.gd` |
| Damage numbers with crit outline | Exists | `effects_spawner.gd` |
| Damage-number scale pop | Partial | `effects_spawner.gd` |
| Regular-hit particle burst | Missing | `combat_runtime_controller.gd` |
| Screen shake | Missing | `display_controller.gd` (seam needed) |
| Health bar drain + hang | Exists | `hud_controller.gd` |
| Chroma / XP bar tween | Missing | `magic_runtime_controller.gd`, `hud_controller.gd` |
| Cost-affordability visual | Partial | `hud_controller.gd`, shop layouts |
| Menu cursor tween + bob | Exists | `menu_cursor.gd` |
| Touch haptics / press feel | Exists | `touch_controls_layer.gd`, `hud_controller.gd` |
| Controller rumble | Missing | `input_router.gd`, feedback seam |
| Unified haptics event mapping | Missing | feedback seam |
| Scene / loading fade | Exists | `gameplay_state.gd`, `screen_state_controller.gd` |
| Room-to-room transition | Missing | `room_controller.gd` |
| Audio event coverage + variants | Exists | `sound_manager.gd`, `sound_clip_catalog.gd` |
| Music ducking / audio buses | Missing | `sound_manager.gd`, `sound_mix_profile.gd` |
| Large-room camera follow | Exists | `room_geometry_controller.gd` |
| Camera shake / lookahead | Missing | `room_geometry_controller.gd` (seam needed) |

## Boundaries

- The explicit frame schedule is preserved. Feedback updates are wired into the
  scheduler or ticked by their owner; do not add `_process()` solely to animate
  a response.
- Feedback lives with the narrowest owner. Cross-owner feedback uses a typed
  command/result or signal at the boundary.
- `effects_spawner.gd` remains the single VFX owner unless a new effect is
  explicitly assigned elsewhere.
- Native presentation uses the `mobile` renderer; web overrides to
  `gl_compatibility`. Any feedback change must preserve behavior on both.
- Do not prescribe particle, pooling, or renderer changes without a measured
  scenario. See the review boundary in
  [`docs/review/03-production-and-architecture-state.md`](docs/review/03-production-and-architecture-state.md).

## Related documents

- [`docs/juice-roadmap.md`](docs/juice-roadmap.md) — active sequenced plan.
- [`docs/GAMEPLAY_TUNING.md`](docs/GAMEPLAY_TUNING.md) — balance and timing
  values.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
  [`docs/FEATURE_MAP.md`](docs/FEATURE_MAP.md) — ownership.
- [`docs/peak-performance-plan.md`](docs/peak-performance-plan.md) — device
  budgets and A17/web gates.
