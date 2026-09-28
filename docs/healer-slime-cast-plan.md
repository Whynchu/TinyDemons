# Tiny Demons — Healer Slime Cast Plan

Status: implemented; focused verification fixture added

Updated: 2026-09-27

Scope: one support-role enemy that channels an interruptible, bounded
single-primary-ally heal with a visible cast bar and heal VFX, plus the minimal
behavior-selection and tuning seams it needs. The healer can recover itself
while another ally is alive, and it can join combat when a nearby ally is
aggroed or showing its notice reaction. Companion to the combat-role slice from
the 2026-09-27 advisor pass.

The successful heal plays the authored `Healing.ogg` cue through the sound mix
profile. Chroma resource pickups play the existing `manapickup.wav` cue.

Owner: enemy family / factory (`scripts/slime_*`, `scripts/enemy_factory.gd`,
`scripts/enemy_definition.gd`)

Implementation: the cast component extends the BossJumpSlam pattern
(`scripts/boss_jump_slam_component.gd`), reuses the damage-number pop and pixel
particle systems (`scripts/effects_spawner.gd`), the world-space meter pattern
(`scripts/player_guard_component.gd`), and the context-steering movement in
(`scripts/slime_brain.gd`). No behavior selector exists on `EnemyDefinition`;
`type_id` selects the actor family only.

Verification: the support smoke and definition validator passed before the
2026-09-27 animation-phase correction. The smoke now covers separate casting
and spell preview states; rerun it with an in-game readability playtest before
calling this refinement verified. The audio mix fixture passed with both new
cues registered. The arc/self-heal/ally-notice refinement is implemented; an
MCP playtest is still needed to confirm its visual readability and combat feel.
Planned checks include
`tools/dev.ps1 verify`, `tools/dev.ps1 test -Suite content`,
`tools/validate_definitions.ps1`, and an MCP playtest/screenshot at 240×160.
Do **not** run `tests/run_all_smoke.ps1` from an editor session
(`AGENTS.md` MCP-first rule).

Supersedes: none. Operationalizes the support-role recommendation in the
2026-09-27 Thorn/Hexley/Pip pass and `docs/combat-and-dungeon-design-principles.md`
§4.1–4.3, §7.

Related: `docs/combat-and-dungeon-design-principles.md`,
`docs/authoring-system-plan.md`, `docs/CONTENT_AUTHORING.md`,
`docs/GAMEPLAY_TUNING.md`.

## 1. Feature contract (acceptance criteria)

- A `support` slime channels a **~2.0 s cast** and **cannot walk while casting**.
- Damage **cancels** the channel (a real cancel, not a hitstun pause).
- The **Casting** animation loops while the cast bar fills.
- When loading ends, the **Spell Cast** animation starts. The heal resolves once
  on its configured impact frame (default index 4, where the authored sheet
  blooms), then the animation plays through before the slime returns to idle.
- Runtime copies of the Casting and Spell Cast sheets live in
  `assets/artwork/` and load through packed Godot resources. Frame extraction
  must work inside an exported web PCK and must not depend on `FileAccess` paths
  to the desktop-only, Godot-ignored `Artwork/` source folder.
- During cast: a **green charge aura** plays on the caster (sword-beam-charge-like).
- During cast: a slightly transparent, green curved target arc starts at the
  caster's shared body-geometry edge and ends at the target's edge. It outlines
  the target in the same single-pixel style, and its glimmers travel over pixels
  in the trail. Keep the existing sparkle around the target.
- On resolve: **green "+" particles** drift upward, per-particle speed driven by
  noise, with varying sizes.
- A **cast bar below the caster** fills, changes color at full, pops slightly,
  then vanishes when the spell resolves.
- Healing potency is **10 HP plus 2 HP per healer INT**, so enemy stat growth
  makes later-run healers restore more health.
- The heal can reach an ally within 52 pixels. If another living enemy ally is
  present, the healer can target itself. At or below 45% health, it prioritizes
  a self-heal at 25% potency; successful heals on another ally also heal the
  caster for 25% of that cast's potency. If no ally needs healing, it may
  self-heal at that potency while another ally lives.
- Healing may begin when the caster is aggroed or a nearby living ally is
  aggroed or in its notice/shock reaction. This is a read-only local check: the
  healer does not change its neighbors' aggro or notice state.
- AI: the caster keeps a **gap from the player** and prefers positions with an
  **ally between it and the player**.
- The primary heal is bounded and never targets the player. Self-healing is
  available only while another living enemy ally remains.
- A second `support` definition requires **zero code edits** (data-only proof).
- Each group of up to three regular Slimes independently gets a **50% chance**
  to add one healer; a partial final group also gets a roll, so four Slimes get
  two chances. Healers add slots and never replace a non-support enemy.

## 2. Extension points (observed; cite before changing)

| Need | Existing mechanism | Cite |
| --- | --- | --- |
| Add a behavior component | `ensure_components()` / `tick_components()` / `tick_runtime()` | `scripts/slime_actor.gd:56-65,81-94,119-143` |
| Pre-empt normal attack, state-gated | BossJumpSlam template | `scripts/boss_jump_slam_component.gd:46-48,77-130,171-211` |
| Intercept attack decision | `update_slime_attack` before `combat.tick_attack` | `scripts/slime_runtime_controller.gd:388-396` |
| Fire on an animation frame | `attack_hit_frame_override` meta + `frame_index >= hit_frame` | `scripts/slime_combat_component.gd:95-139`; `scripts/enemy_factory.gd:58-59` |
| Cancel-on-damage signal | `HealthComponent.damaged` | `scripts/health_component.gd:8`; wired `scripts/gameplay_bootstrap.gd:544`, `scripts/room_controller.gd:1524` |
| Player-block cancel precedent | zeroes `combat.active/timer` | `scripts/slime_actor.gd:315-318` |
| Charge aura VFX | procedural `Sprite2D` aura | `scripts/effects_spawner.gd:304-346,349-386,389-426` |
| Rising + noise particles | fire sparks + `FastNoiseLite` | `scripts/effects_spawner.gd:510-535,994-1043` |
| A "+" texture | `gearplus3x5.png` preloaded | `scripts/effects_spawner.gd:5` |
| World-space meter | `region_rect` fill + hide/fade | `scripts/player_guard_component.gd:43-66,200-228` |
| Bar attached to an enemy | overhead bar parented to enemy | `scripts/hud_controller.gd:1324-1376,508-588` |
| Pop-then-vanish | damage-number pop/hold/fade | `scripts/effects_spawner.gd:923-962,1046-1104` |
| Color change on fill | `self_modulate` | `scripts/targeting_runtime_controller.gd:167-172` |
| Movement / preferred range | context steering | `scripts/slime_brain.gd:183,207,231-252` |
| Nearby-ally query | `slime_grid_candidates` | `scripts/actor_collision_system.gd:116` |
| Locomotion lock | `combat.active` early-return | `scripts/slime_actor.gd:126-143` |
| Visual frame sets | `Array[Texture2D]` on `SlimeVisualComponent` | `scripts/slime_visual_component.gd:7-23,112-127` |
| Shadow state selection | `sync_slime_shadow` by `animation_name` | `scripts/actor_presentation_runtime_controller.gd:191-230` |
| Data-authorable tuning | `SlimeTuning` + `resources/tuning/slime_default.tres` | `scripts/slime_tuning.gd`; `scripts/gameplay_state.gd:19,358` |

**Missing seams to add:** (a) a behavior selector on `EnemyDefinition`; (b) an
enemy-side `cancel_cast(reason)` (today only the player-block path cancels).

## 3. Design decisions

1. **Behavior selection — a field, not a new family.** Add
   `behavior_id: StringName` (default `&""`) to `EnemyDefinition`
   (`scripts/enemy_definition.gd:14-51`) and a `&"support_caster"` branch in
   `EnemyFactory.configure_actor` (`scripts/enemy_factory.gd:40-67`). This avoids
   a new `type_id` and actor subclass. Fold in the earlier `combat_role` field so
   melee/ranged/support is typed once.
2. **One dedicated component**, `slime_support_component.gd`, modeled on
   `boss_jump_slam_component.gd`. Do **not** overload `SlimeCombatComponent`.
3. **Two animation phases:** the component loops the authored Casting frames
   during the cast timer. At completion it switches to Spell Cast frame 0 and
   resolves the heal once at `support_heal_frame` (default index 4, the authored
   bloom frame), then plays the rest of that authored sequence before returning
   to idle. The sheets describe phases, never facing directions.
4. **Interruption is a cancel.** `tick_runtime` returns early during hitstun
   (`scripts/slime_actor.gd:126-130`), which would only *pause* a channel.
   Subscribe to `Health.damaged` and knockback → `cancel_cast("damaged")`.
5. **Cast bar** copies `player_guard_component`'s self-contained world-space meter
   (fill via `region_rect`), parented to the caster with a **below-actor
   (negative-Y) offset**, matching that component's default bar placement,
   `z_index = overworld_ui_z` (`scripts/gameplay_state.gd:34`), color via
   `self_modulate`, pop via the damage-number pop curve.
6. **Per-particle "+" size:** sizes are currently baked into textures
   (`scripts/gameplay_state.gd:1496-1502`). Add a per-particle `scale` (and
   optional `rotation`) key to the particle dictionary and apply it in
   `update_pixel_particles` (`scripts/effects_spawner.gd:1006-1040`).
7. **Shadow:** map the cast state to the **idle shadow** (the spell does not
   translate). Add a `"cast"` branch in `sync_slime_shadow`
   (`scripts/actor_presentation_runtime_controller.gd:208-220`) that reuses
   `shadow_idle_texture`. The casting-shadow frame set stays available if frame
   variation is wanted later.

## 4. Implementation phases

**Phase 0 — data + characterization (first)**
- Add `behavior_id` to `enemy_definition.gd`, validated + round-tripped; focused
  test that existing definitions default to empty and still materialize.
- Add cast/heal fields to `SlimeTuning`: `support_cast_time=2.0`,
  `support_heal_frame=4`, `support_animation_frame_time=0.08`,
  `support_heal_amount=10`, `support_heal_per_intelligence=2`,
  `support_heal_radius`, `support_heal_cooldown`, `support_preferred_range`,
  `support_ally_bias`.

**Phase 1 — cast state machine (no VFX)**
- `slime_support_component.gd`: target select (most-damaged living ally in range;
  allow self only when another living ally remains, prioritize self at the
  configured low-health threshold, and never target the player), cast timer,
  cooldown, `start_cast()` / `cancel_cast(reason)`, movement lock.
- Hook in `ensure_components()` + `tick_components()`; intercept in
  `update_slime_attack` (`scripts/slime_runtime_controller.gd:388-396`) beside
  BossJumpSlam; gate like `BossJumpSlamComponent._can_begin`.
- Wire `cancel_cast` to `Health.damaged` and knockback; reset in
  `reset_runtime_state` (`scripts/slime_actor.gd:340-402`).
- Fixture: heal fires once on the configured Spell Cast frame; a hit cancels;
  no self/player target;
  bounded and repeatable.

**Phase 2 — animation + shadow**
- Add separate `support_casting_frames` and `support_spell_frames` arrays to
  `SlimeVisualComponent`; assign the authored sheets beside attack frames in
  `actor_presentation_runtime_controller.gd`.
- Loop Casting frames while loading, then start the one-shot Spell Cast sequence;
  apply the heal on its configured resolve frame. Both phases use the idle shadow.

**Phase 3 — cast bar**
- New `enemy_cast_bar.gd`: the `Sprite2D` triad lifecycle from
  `player_guard_component.gd`, positioned below the caster; fill → color
  change at full → pop → vanish on resolve/cancel.

**Phase 4 — VFX**
- `effects_spawner.spawn_heal_charge_from_root(actor)` — green aura during cast,
  decoupled from player internals (do **not** reach into `player_*` the way
  `update_charge_aura_from_root` does, `scripts/effects_spawner.gd:305-311`).
- `effects_spawner.spawn_heal_burst_from_root(pos, ...)` — green "+" sprites rising
  with per-particle `scale` and noise-varied speed (a noise member like
  `scripts/effects_spawner.gd:37,519-520`; cf. `scripts/screen_state_controller.gd:958-960`).
  Reuse `gearplus3x5.png` or the new asset.

**Phase 5 — movement AI (behind allies, gap from player)**
- In `context_steering_direction` (`scripts/slime_brain.gd:183-252`), add a
  support-caster interest term: reward positions where an ally lies between caster
  and player (query `ActorCollisionSystem.slime_grid_candidates`,
  `scripts/actor_collision_system.gd:116`) and raise preferred range above
  `attack_range*0.72`.
- Locomotion lock while casting: extend the `combat.active` early-return in
  `tick_runtime` (`scripts/slime_actor.gd:126-143`) to also cover cast-active;
  re-snap position because contact/player push can displace a stationary caster
  (`scripts/slime_runtime_controller.gd:262-267`, `separate_slime_from_player`).
- Keep bounded: a steering bias + preferred range first; **not** a cover/graph
  system (design contract: reuse through composition,
  `combat-and-dungeon-design-principles.md` §6).

**Phase 6 — preview + verification**
- Show Support Casting and Support Spell as separate states in the enemy preview
  workbench (`scripts/enemy_preview_workbench.gd`).
- Register a focused fixture in `tests/manifest.csv`; a second `support`
  definition with zero code edits proves data-only.

## 5. Asset / data contract

- New art lands flat in `assets/artwork/` (existing convention; the effect
  spawner preloads by path).
- Loading animation: `Artwork/SlimeGreen_Casting.png` → looping
  `support_casting_frames`.
- Heal animation: `Artwork/SlimeGreen_Spell_Cast.png` → one-shot
  `support_spell_frames` after healing resolves.
- Cast bar: reuse `HpOverhead.png` + a bar fill texture, or a new meter texture.
- Heal "+": reuse `gearplus3x5.png` or the new asset; per-particle scale gives
  size variation.
- Cast/heal/bias values live in `SlimeTuning` (`.tres`), **not** code constants —
  avoid the `dungeon_generation_policy.tres` trap where authored values are
  validated but ignored.

## 6. Risks and open decisions

- **"Behind allies" is the novel piece.** A steering bias is recommended over a
  new movement system.
- **Per-enemy tuning is not honored** by the brain today (it reads
  `root.get("slime_tuning")`, not `actor.tuning`); decide global vs per-enemy
  support values.
- **Interrupt semantics:** confirm "any damage cancels" vs a hitstun/threshold.
- **Cast-bar space:** below the caster may collide with the floor shadow or
  adjacent rooms; confirm offset/clamp behavior.
- **Heal strength/cooldown:** pick first-pass numbers in tuning, not code.
- **Ownership/coordination:** codex holds `scripts/enemy_preview_workbench.gd`,
  `docs/authoring-system-plan.md`, and `docs/KNOWN_ISSUES.md`. Phase 6 preview
  work and any issue-doc updates are codex's.

## 7. Independent verification expectations

- Focused fixtures in `tests/manifest.csv` (role `owner`, explicit state +
  evidence when green).
- `tools/dev.ps1 verify`, `tools/dev.ps1 test -Suite content`,
  `tools/validate_definitions.ps1`.
- MCP playtest + native 240×160 screenshot for readability.
- No edits to `GameplayState` feature coordinators, the release gate, or
  count-pinned tests.
