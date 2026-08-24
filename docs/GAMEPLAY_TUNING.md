# Gameplay Tuning Index

> Purpose: a single index of every gameplay tuning knob and where to change it
> in the Godot editor. If it affects feel, difficulty, or economy, it should be
> here. Values marked `inspector` are `@export` fields editable on the
> resource in the editor; values marked `const` are hardcoded and need a code
> change (candidates for future export).

## Tuning resources

The five typed tuning resources are attached to the gameplay root and are the
primary editor surface. Open any one and edit values in the inspector; the
game reads them at runtime with no code change.

### `scripts/player_tuning.gd` — player feel (36 exports, all `inspector`)

| Group | Fields |
| --- | --- |
| Movement | `speed` 36, `speed_scale` 0.012, `roll_scale` 0.015, `attack_scale` 0.010, `speed_effect_min` -0.5, `speed_effect_max` 1.0 |
| Hit reaction | `hit_flash_time` 0.12, `hitstun_time` 1/30, `hit_knockback` 10, `hit_knockback_duration` 0.12 |
| Idle/walk | `idle_frame_time` 0.22, `walk_frame_time` 0.18 |
| Attack | `attack_frame_time` 0.09, `attack_hit_frame` 2, `attack2_hit_frame` 2, `combo_window` 0.18, `between_attack_time` 0.12, `attack2_cooldown` 0.16 |
| Roll | `roll_frame_time` 0.05, `roll_distance` 30, `roll_duration` 0.30 |
| Lunge/knockback | `attack_lunge_distance` 6, `attack_lunge_duration` 0.18, `attack_knockback` 16, `attack1_knockback_multiplier` 0.60 |
| Damage | `attack2_damage_multiplier` 1.25, `attack2_multi_target_damage_multiplier` 1.10 |
| Regen | `regen_delay` 2.0, `regen_interval` 1.0, `regen_amount` 1.0 |
| Death/hitstop | `death_particle_lifetime` 1.8, `death_fade_time` 0.7, `death_particle_delay` 0.7, `hitstop_duration` 1/40, `death_observe_time` 1.4, `health_damage_hang_time` 0.14 |

### `scripts/slime_tuning.gd` — enemy behavior (41 exports, all `inspector`)

| Group | Fields |
| --- | --- |
| Movement | `scoot_distance` 5, `scoot_duration` 0.34, `steering_direction_count` 8, `steering_approach_weight` 1.0, `steering_orbit_weight` 0.42, `steering_ally_danger_weight` 1.25, `steering_blocked_danger_weight` 4.0, `steering_clearance` 7.0 |
| Attack | `attack_frame_time` 0.08, `attack_hit_frame` 5, `attack_range` 14, `attack_hit_range` 16, `attack_vertical_hit_range` 10, `attack_lunge_distance` 10, `attack_cooldown` 1.0 |
| Aggro/repаth | `aggro_range` 28, `repath_min` 0.7, `repath_max` 1.8, `hold_min` 0.22, `hold_max` 0.48, `aggro_hold_min` 0.08, `aggro_hold_max` 0.16, `chill_chance` 0.22, `chill_min` 1.0, `chill_max` 2.2, `idle_breath_time` 1.4 |
| Boss | `boss_attack_cooldown_multiplier` 1.6, `boss_attack_frame_time_multiplier` 1.5, `boss_movement_speed_multiplier` 0.7 |
| Regen | `regen_delay` 5.0, `regen_interval` 0.75, `regen_amount` 1.0 |
| Health UI | `health_drain_fill_speed` 18, `health_regen_fill_speed` 4, `health_damage_hang_time` 0.14 |
| Hit reaction | `hit_flash_time` 0.12, `hitstun_time` 1/30, `knockback_duration` 0.14 |
| Rogue slime (ambush) | `ambush_reveal_window` 0.5, `ambush_block_stun` 1.0, `ambush_hit_extension` 0.5 |

### `scripts/combat_tuning.gd` — combat formulas (11 exports, all `inspector`)

| Field | Default | Meaning |
| --- | ---: | --- |
| `health_base` | 8.0 | Flat HP before stats |
| `health_per_vit` | 4.0 | HP per VIT point |
| `health_per_level` | 0.0 | Leveling grants no Core HP; HP comes from VIT and HP-specific gear |
| `health_vit_core_rate` | 0.03 | Extra HP from VIT-based gear multiplier |
| `damage_base` | 2.0 | Flat damage before STR |
| `defense_scale` | 12.0 | Higher = DEF matters less |
| `damage_roll_min` / `damage_roll_max` | 0.85 / 1.15 | Damage variance range |
| `critical_hit_chance` | 0.10 | Crit chance |
| `critical_damage_multiplier` | 1.5 | Crit damage multiplier |
| `target_health_max` | 10.0 | Cap for targeting display |

### `scripts/progression_tuning.gd` — leveling economy (5 exports, all `inspector`)

| Field | Default | Meaning |
| --- | ---: | --- |
| `xp_base` | 100.0 | XP for level 1->2 |
| `xp_scale` | 20.0 | XP growth per level |
| `xp_exponent` | 1.5 | XP curve exponent |
| `point_band_max_levels` | [5,10,20,35,99] | Level bands for stat points |
| `point_band_awards` | [1,2,3,4,5] | Points awarded per band |

### `scripts/effects_tuning.gd` — particles/numbers (9 exports, all `inspector`)

`resolution_scale` 2, `roll_dust_frame_time` 0.05, `damage_number_lifetime` 0.65,
`damage_number_pop_time` 0.10, `damage_number_float_speed` 12.0,
`slime_death_particle_count` 26, `slime_death_particle_lifetime` 0.7,
`slime_death_particle_speed_min` 14, `slime_death_particle_speed_max` 38.

## Item / stat economy

These are code values (not inspector-exposed) that drive gear value:

| Knob | Value | Location |
| --- | --- | --- |
| Gear primary-stat contribution | Definition package + 2 flat points per rarity rank + 1 point at +10 | `item_catalog.gd:bonuses` |
| Rarity player-stat buff | Common 0% / Rare 5% / Epic 15% / Legendary 45% / Mythic 80%, per positive affected stat | `item_catalog.gd:RARITY_PLAYER_STAT_RATES`, `equipment_component.gd` |
| Starter loadout totals | +3 VIT / +3 STR / +3 DEF / 0 SPD | `item_catalog.gd` definitions |
| Non-basic package allowance | Each non-basic definition may carry at most one extra positive base point over its slot's basic package | `item_catalog.gd:DEFINITIONS` |
| Shield primary trade-offs | SPD penalties are part of the visible flat package; no hidden STR/SPD subtraction | `item_catalog.gd:DEFINITIONS`, `equipment_component.gd` |
| Shield guard package | Guard values use the rarity player-stat rate as their tier scalar; enhancement remains the guard-specific +10%/level | `item_catalog.gd:shield_bonuses` |
| Gear scaling floor | Not used by the current flat-point model | `combat_stat_snapshot.gd` |
| Health/damage rate package | Not currently part of the primary gear snapshot | `combat_stat_snapshot.gd` |
| Enhancement flat point | 1 point at +10 (`floor(enhancement / 10)`) | `item_catalog.gd:enhancement_flat_points` |
| Max enhancement | +10 | `player_profile.gd` |
| Rarity flat points | 0 / 2 / 4 / 6 / 8 for common through mythic | `item_catalog.gd:RARITY_FLAT_POINTS_PER_RANK` |
| Random primary affixes | Retired from effective/generated gear; legacy fields remain loadable | `item_catalog.gd:bonuses`, `item_instance.gd` |
| Fusion base cost | 20G | `player_profile.gd:FUSION_BASE_COST` |
| Fusion cost per enhancement | 15G | `player_profile.gd:FUSION_COST_PER_ENHANCEMENT` |
| Base stats (archetype) | VIT/STR/DEF sum to 7 | `stats_component.gd:_base_profile_values` |
| SPD scale | 0.012 per point (see player_tuning) | `player_tuning.gd` |

The flat ladder is `definition base + (rarity rank × 2) + floor(enhancement / 10)`
on each item's authored tier stat. For the basic sword that is STR 2 at common
`+0`, STR 3 at common `+10`, STR 4 at rare `+0`, STR 5 at rare `+10`, and STR
6 at epic `+0`.

## World / scene constants (code, not exported)

These affect dungeon generation and room behavior and are `const` in
`gameplay_state.gd` or `dungeon_graph.gd`:

| Knob | Value | Location |
| --- | ---: | --- |
| Enemy level curve | `max(1, ceil(depth / 4)) + run progression`, clamped by cap | `room_controller.gd:_generated_enemy_base_level` |
| Generated enemy level caps | `3` on R1, `5` on R2, then +1/run | `room_controller.gd:_enemy_level_cap`, `combat_runtime_controller.gd:enemy_level_cap_for_rank` |
| Run 2 popcorn chance | `0.40` level-1 roll; later runs `0.16` | `room_controller.gd:_popcorn_enemy_chance` |
| Popcorn enemy level | Level 1 through R4, level 2 on R5, then +1 every 3 runs | `room_controller.gd:_popcorn_enemy_level` |
| Enemy health ramp | `0.50` on R1, `0.65` on R2, +0.15/run to `1.0` | `combat_runtime_controller.gd:enemy_health_factor` |
| Encounter progression rank | `completed_runs + 1` | `gameplay_state.gd:_ensure_current_room_layout`, `combat_runtime_controller.gd:encounter_run_rank` |
| Enemy level cap | `3` on R1, `5` on R2, then +1/run | `combat_runtime_controller.gd:enemy_level_cap_for_run` |
| Late-run difficulty bonus | `max(0, encounter_rank - 8)` | `combat_runtime_controller.gd:run_enemy_level_bonus` |
| Performance-over-baseline bonus | `max(0, difficulty_rank - (completed_runs + 1))` | `run_flow_controller.gd:run_difficulty_bonus` |
| Boss depth | `12 + min(runs, 8)` | `dungeon_graph.gd:target_boss_depth` |
| Chest interact distance | 16.0 | `gameplay_state.gd:CHEST_INTERACT_DISTANCE` |
| NPC interact distance | 24.0 | `gameplay_state.gd:NPC_INTERACT_DISTANCE` |
| Chest gold base | 100 | `gameplay_state.gd:CHEST_REWARD_GOLD` |
| Chest gold roll | `0.75x-1.30x` base before rank/grade multiplier | `run_flow_controller.gd:chest_gold_reward` |
| Chest item drop chance | clamp to [0.30, 0.88], base 0.34 | `gameplay.gd:_chest_item_drop_chance` |
| Chest second gear drop | 1 additional item, base 0.35 chance | `run_flow_controller.gd:chest_item_drop_count` |
| Collision sizes | 9x4 actor, 3.6 radius | `gameplay_state.gd` |
| Vertical movement scale | 0.5 | `gameplay_state.gd:VERTICAL_MOVEMENT_SCALE` |
| Triangle spell cooldown | 2.0s elemental / 2.5s grey | `gameplay_state.gd:MAGIC_COOLDOWN`, `gameplay_state.gd:GREY_MAGIC_COOLDOWN` |
| Triangle knockback | `0.25x` normal attack knockback | `magic_runtime_controller.gd:MAGIC_KNOCKBACK_MULTIPLIER` |

## Magic numbers still hardcoded (known gaps)

These are real balance/economy knobs embedded in `gameplay.gd` and not yet
exposed or indexed. Candidates to export into the tuning resources:

| Knob | Value | Location |
| --- | ---: | --- |
| Loot grade bonuses (S/A/B/C/F) | 3 / 2 / 1 / 0.5 / -0.5 | `gameplay.gd:_loot_grade_bonus` |
| Chest drop sub-terms | 0.025 / 0.20 / 0.035 / 0.025 | `gameplay.gd:177-178` |
| Chest gold roll range | 0.55 - 1.15, mult 0.06/0.04, clamp [0.80, 1.90] | `gameplay.gd:183-185` |
| Run-reward rarity odds | 0.0005 / 0.003 / 0.015 / 0.120 + caps | `gameplay.gd:600-603` |
| Run-clear reward | `45 + score*3 + variety*8`; drop `0.30 + score*0.0065` clamp [0.30,0.95] | `gameplay.gd:618-622` |
| XP formula | `2 + 2*lvl^0.85`, x1.15/x0.72, clamp [0.2, 2] | `gameplay.gd:1698-1701` |
| World-drop physics | launch +-18/-30, air 0.38, gravity 92, pickup 10, push 18 | `gameplay.gd:116-150` |
| Slime detour radii / slide | [12, 18, 24], detour 0.42, repath 0.10-0.18, slide x0.72 | `gameplay.gd:1773-1813` |
| Run-metric color thresholds | 0.95 / 0.85 / 0.70 / 0.50 | `gameplay.gd:666-674` |
| Hub-fire light steps | `energy_steps` / `scale_steps` arrays | `gameplay.gd:1056-1058` |

Also scene/world consts in `gameplay_state.gd` that belong in tuning
(eventually): `SLIME_NOTICE_FRAME_TIME`, `MAX_ACTIVE_ENEMY_ATTACKERS`,
`CHEST_COLLECT_FLASH_TIME`, `CHEST_UNLOCK_FADE_TIME`,
`CHEST_EVAPORATE_*`, `FIRE_FRAME_*`, `NPC_DIALOGUE_BUTTON_BOB_TIME`,
`CHEST_COLLISION_SIZE`, `TARGET_LOCK_MAX_DISTANCE`, `OCCLUSION_RELEASE_GRACE`,
`CONTROLLER_DEADZONE`, `CONTROLLER_TRIGGER_DEADZONE`, `GAME_OVER_FADE_TIME`,
`EDGE_MARGIN`, `SLIME_EDGE_PADDING`, `PLAYER_TEXTURE_OFFSET`.

## Debug hooks

- `gameplay_state.gd:debug_start_in_boss_room` (`@export`, inspector) — boot
  straight into the boss room.
- `scenes/boss_room_debug.tscn` — the boss-room debug scene.

## How to add a new tuning knob

1. Prefer an `@export` field on the matching tuning resource (`player_*`,
   `slime_*`, `combat_*`, `progression_*`, `effects_*`).
2. If it is a per-item or per-enemy-variant value, prefer a definition in
   `item_catalog.gd` / `stats_component.gd` presets over a global.
3. Avoid new magic constants in `gameplay.gd`/`gameplay_state.gd`; if one is
   required, add it here as `const` and file a follow-up to export it.
4. Update this index in the same change.
