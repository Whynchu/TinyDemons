# Gameplay Tuning Index

> Purpose: a single index of every gameplay tuning knob and where to change it
> in the Godot editor. If it affects feel, difficulty, or economy, it should be
> here. Values marked `inspector` are `@export` fields editable on the
> resource in the editor; values marked `const` are hardcoded and need a code
> change (candidates for future export).

## Tuning resources

The six typed tuning resources are attached to the gameplay root and are the
primary editor surface. Open any one and edit values in the inspector; the
game reads them at runtime with no code change.

### `scripts/player_tuning.gd` — player feel (81 exports, all `inspector`)

| Group | Fields |
| --- | --- |
| Movement | `speed` 36, `run_speed` 64.8, `speed_scale` 0.012, `speed_low_scale` 0.15 (below-AGI-reference penalty), `roll_scale` 0.015, `attack_scale` 0.010, `speed_effect_min` -0.5, `speed_effect_max` 1.0 |
| Hit reaction | `hit_flash_time` 0.12, `hitstun_time` 1/30, `hit_knockback` 10, `hit_knockback_duration` 0.12 |
| Idle/walk/run | `idle_frame_time` 0.22, `walk_frame_time` 0.18, `run_frame_time` 0.10 |
| Attack | `attack_frame_time` 0.09, `attack_hit_frame` 2, `attack2_hit_frame` 2, `combo_window` 0.18, `between_attack_time` 0.12, `attack2_cooldown` 0.16 |
| Spin gesture / timing | `spin_circle_min_magnitude` 0.55, `spin_circle_max_duration` 0.50, `spin_circle_required_turn` 0.80τ, `spin_circle_arm_duration` 0.28, `spin_frame_time` 0.075, `spin_recovery_frame_time` 0.14, active frames 3–6 |
| Spin balance | `spin_damage_multiplier` 0.90, `spin_knockback_multiplier` 2.0, `spin_lunge_distance` 14.0, `spin_lunge_duration` 0.73; travel eases out through frame 5, spin uses eight authored body frames, snapshots input direction, and does not split damage across multiple targets |
| Charge balance | `charge_minimum_time` 0.25, `charge_maximum_time` 0.65, `charged_attack2_frame_time_multiplier` 0.90, `charged_attack2_damage_multiplier` 1.60, `charged_attack2_knockback_multiplier` 1.50 |
| Charge aura | `charge_aura_start_interval` 0.16 -> `charge_aura_peak_interval` 0.055, launch speed 8 -> 24, rise 12 -> 26, spread 2 -> 7, curl 8 -> 52, `charge_aura_particle_lifetime` 0.28; foot-level pixels ramp into short air streaks at the charge cap |
| Roll | `roll_frame_time` 0.05, `roll_distance` 24.3, `roll_duration` 0.30 |
| Lunge/knockback | `attack_lunge_distance` 8, `attack_lunge_duration` 0.18, `charged_attack_lunge_multiplier` 1.75 (14px), `attack_knockback` 16, `attack1_knockback_multiplier` 0.60 |
| Running attack | `run_attack_lunge_multiplier` 2.0 (16px from the 8px base), original `attack_lunge_duration`, `run_attack_damage_multiplier` 1.10, `run_attack_knockback_multiplier` 1.25, `run_attack_hitstop_multiplier` 1.20, `run_attack_extra_cooldown_frames` 1.5; a live run starts directly at Attack 2 and consumes the run state |
| Damage | `attack2_damage_multiplier` 1.25, `attack2_multi_target_damage_multiplier` 1.10 |
| Regen | `regen_delay` 2.0, `regen_interval` 1.0, `regen_amount` 1.0 |
| Death/hitstop | `death_particle_lifetime` 1.8, `death_fade_time` 0.7, `death_particle_delay` 0.7, `hitstop_duration` 1/40, `death_observe_time` 1.4, `health_damage_hang_time` 0.14 |

### `scripts/slime_tuning.gd` — enemy behavior (41 exports, all `inspector`)

| Group | Fields |
| --- | --- |
| Movement | `scoot_distance` 5, `scoot_duration` 0.34, `steering_direction_count` 8, `steering_approach_weight` 1.0, `steering_orbit_weight` 0.42, `steering_ally_danger_weight` 1.25, `steering_blocked_danger_weight` 4.0, `steering_clearance` 7.0 |
| Attack | `attack_frame_time` 0.08, `attack_hit_frame` 5, `attack_range` 14, `attack_hit_range` 16, `attack_vertical_hit_range` 10, `attack_lunge_distance` 8, `attack_cooldown` 1.0 |
| Aggro/repаth | `aggro_range` 28, `repath_min` 0.7, `repath_max` 1.8, `hold_min` 0.22, `hold_max` 0.48, `aggro_hold_min` 0.08, `aggro_hold_max` 0.16, `chill_chance` 0.22, `chill_min` 1.0, `chill_max` 2.2, `idle_breath_time` 1.4 |
| Boss | `boss_attack_cooldown_multiplier` 1.6, `boss_attack_frame_time_multiplier` 1.5, `boss_movement_speed_multiplier` 0.7 |
| Regen | `regen_delay` 5.0, `regen_interval` 0.75, `regen_amount` 1.0 |
| Health UI | `health_drain_fill_speed` 18, `health_regen_fill_speed` 4, `health_damage_hang_time` 0.14 |
| Hit reaction | `hit_flash_time` 0.12, `hitstun_time` 1/30, `knockback_duration` 0.14 |
| Shadow slime (ambush) | `ambush_reveal_window` 0.5, `ambush_block_stun` 1.0, `ambush_hit_extension` 0.5 |

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

Enemy XP rewards use a global `2.0x` multiplier in addition to the encounter
and boss reward formulas (`combat_runtime_controller.gd:XP_REWARD_MULTIPLIER`).

| Field | Default | Meaning |
| --- | ---: | --- |
| `xp_base` | 100.0 | XP for level 1->2 |
| `xp_scale` | 20.0 | XP growth per level |
| `xp_exponent` | 1.5 | XP curve exponent |
| `point_band_max_levels` | [5,10,20,35,99] | Level bands for stat points |
| `point_band_awards` | [1,2,3,4,5] | Points awarded per band |

### `scripts/effects_tuning.gd` — particles/numbers (9 exports, all `inspector`)

`resolution_scale` 2 (web runtime uses 1 to cap the occlusion pixel workload),
`roll_dust_frame_time` 0.05, `damage_number_lifetime` 0.65,
`damage_number_pop_time` 0.10, `damage_number_float_speed` 12.0,
`slime_death_particle_count` 26, `slime_death_particle_lifetime` 0.7,
`slime_death_particle_speed_min` 14, `slime_death_particle_speed_max` 38.

### `scripts/chroma_tuning.gd` — Chroma pickups (6 exports, all `inspector`)

`pickup_value` 20, `enemy_drop_chance` 0.35, `pickup_collection_distance` 10,
`pickup_air_time` 0.38, `pickup_launch_speed` 18, and `pickup_launch_spread`
10. Resource drops use a damped launch with a gentle wall bounce so Chroma and
Souls settle inside the room without snapping or flying too far from the enemy.

## Elemental slime definitions

The stateless catalogs are the source of truth for enemy identity and typed
damage. `scripts/slime_variant_catalog.gd` owns the visual variant, display
name, element, level-one base stats, and growth weights. `StatsComponent`
replays its existing deterministic growth rolls with the variant token folded
into the seed.

| Variant | Element | VIT / STR / DEF / SPD | Growth weights (VIT / STR / DEF / SPD) |
| --- | --- | --- | --- |
| Normal | Neutral | 2 / 2 / 2 / 2 | 0.25 / 0.25 / 0.25 / 0.25 |
| Red | Fire | 1 / 4 / 2 / 1 | 0.10 / 0.55 / 0.20 / 0.15 |
| Blue | Water | 2 / 1 / 4 / 1 | 0.20 / 0.10 / 0.55 / 0.15 |
| Yellow | Electric | 2 / 2 / 1 / 3 | 0.20 / 0.15 / 0.10 / 0.55 |
| Green | Grass | 4 / 1 / 2 / 1 | 0.55 / 0.10 / 0.20 / 0.15 |
| Shadow | Shadow | 1 / 3 / 1 / 3 | 0.08 / 0.42 / 0.08 / 0.42 |
| Orange | Ground | 3 / 1 / 3 / 1 | 0.35 / 0.10 / 0.45 / 0.10 |
| Aquamarine | Ice | 2 / 2 / 1 / 3 | 0.15 / 0.20 / 0.15 / 0.50 |

`scripts/element_catalog.gd` owns the eight-element matchup matrix. Neutral is
the player defender in this slice. Weakness is `1.25x`, resistance is `0.8x`,
and Neutral is immune to Shadow while Shadow damages Neutral at `1.0x`;
Shadow into Shadow is `1.25x`. Ground
is immune to Electric, while Ice is strong against Ground and Grass.
Regular encounters include Gray at weight 1.0 immediately; Yellow joins at
room depth 2 with weight 1.0, Ground joins at depth 3, and Ice joins at depth 4.
Purple remains the rare `0.12` regular-encounter variant and `0.04` boss-minor
conversion.

## Item / stat economy

The live six-slot gear model is documented in
[`gear-system-rework.md`](gear-system-rework.md). It contains 12 Plain/Basic
baseline pieces and 54 pieces across nine complete sets. The older catalogue
records remain loadable for save compatibility but are excluded from new drops,
shop stock, and authored gear choices. `armor` remains a Body save alias.

These are code values (not inspector-exposed) that drive gear value:

| Knob | Value | Location |
| --- | --- | --- |
| Gear primary-stat contribution | Authored package + 2 flat points per rarity rank + 0.1 tier-stat point per fusion enhancement | `item_catalog.gd:bonuses` |
| Rarity player-stat buff | Retired from live gear; all live gear uses flat points | `item_catalog.gd:RARITY_PLAYER_STAT_RATES`, `equipment_component.gd` |
| Starter loadout | Six Basic pieces; every new character starts at VIT/STR/DEF/AGI/INT/MND 2/2/2/2/2/2 | `item_catalog.gd:starter_item`, `screen_state_controller.gd` |
| Drop tier weights | Plain 6.0, Basic 5.0, Set 0.5; Plain and Basic are the common majority | `item_catalog.gd:_gear_drop_weight` |
| Random `+` package | Weighted: Common 0–1 (~6% +1), Rare 0–2 (~60/32/8), Epic 0–3 (~38/34/21/7), Legendary 1–3 (~45/37/18), Mythic 2–3 (~55/45); any of six stats | `item_catalog.gd:_roll_random_stat_points`, `item_instance.gd` |
| Cloaked Demon premium slot | Rare floor with `plus_rarity_scale` 0.35, so plussed finds there are rarer than normal loot | `run_state.gd:ensure_shop_stock` |
| Gear shop value | `price = base × rarity multiplier × plus multiplier × enhancement multiplier × quality`; `+` adds ~1.6x, `++` ~4.4x, `+++` ~8.8x before rarity, enhancement +22% per level | `item_catalog.gd:price` |
| Live catalogue | 66 definitions: 12 Plain/Basic baseline pieces plus 54 set pieces | `item_catalog.gd:live_definition_ids` |
| Set scope | Swift, Soldier, Guard, Blood, Arcane, Soul, Edge, Oath, Rune; one Weapon/Head/Body/Arm/Shield/Accessory each | `item_catalog.gd:SET_DEFINITIONS` |
| Weapon scope | Swords and Blades only | `item_catalog.gd:SET_DEFINITIONS`, `LIVE_BASE_DEFINITIONS` |
| Shield primary trade-offs | SPD penalties are part of the visible flat package; no hidden STR/SPD subtraction | `item_catalog.gd:DEFINITIONS`, `equipment_component.gd` |
| Shield guard package | Guard values are fixed by the definition and grow only with the +10%/fusion enhancement factor | `item_catalog.gd:shield_bonuses` |
| Gear scaling floor | Not used by the current flat-point model | `combat_stat_snapshot.gd` |
| Health/damage rate package | Not currently part of the primary gear snapshot | `combat_stat_snapshot.gd` |
| Enhancement flat point | 0.1 tier-stat point per level; 1 point at +10 | `item_catalog.gd:enhancement_flat_points` |
| Max enhancement | +10 | `player_profile.gd` |
| Rarity flat points | 0 / 2 / 4 / 6 / 8 for common through mythic | `item_catalog.gd:RARITY_FLAT_POINTS_PER_RANK` |
| Random primary affixes | Retired; random `+` points are independent, visible, and capped at three total | `item_catalog.gd:bonuses`, `item_instance.gd` |
| Legacy catalogue | 44 authored records remain readable for old saves but are not live drop candidates | `item_catalog.gd:DEFINITIONS`, `item_catalog.gd:definitions_for_slot` |
| Initial gear economy exclusions | No direct Souls, gold, global drop-rate, or Style multipliers in live gear | `docs/gear-system-rework.md` |
| Fusion common +0 step | 1 Soul for +0 -> +1 | `player_profile.gd:FUSION_START_COST` |
| Fusion cost progression | +1 Soul per enhancement; each rarity adds 10 Souls; common +10 -> rare costs 10 and rare +0 -> +1 costs 11 | `player_profile.gd:fusion_step_cost` |
| Fusion matching | Same base definition and rarity; random `+` package, affixes, transmutations, and target fusion level do not block a match | `player_profile.gd:_is_fusion_match` |
| Base stats | VIT/STR/DEF/AGI/INT/MND all start at 2 for new players; old saved values are preserved | `player_profile.gd`, `stats_component.gd`, `screen_state_controller.gd` |
| SPD scale | 0.012 per point (see player_tuning) | `player_tuning.gd` |

The flat ladder is `definition base + (rarity rank × 2) + (fusion enhancement ×
0.1)` on the authored tier stat. Each random `+` point is an additional stat
lane that receives the same rarity and fusion growth. For the Basic Sword,
that is STR 2.0 at Common F0, STR 2.1 at Common F1, STR 3.0 at Common F10,
STR 4.0 at Rare F0, STR 5.0 at Rare F10, and STR 6.0 at Epic F0. The `+` marker
is the random drop package; `F` is the separate fusion level.

## Display and settings (not gameplay tuning)

Display and audio preferences are intentionally excluded from this gameplay
tuning index. `settings_service.gd` owns the device-wide
`user://settings.cfg` values (`fullscreen`, `aspect`, `pixel_perfect`,
`music_volume`, and `sfx_volume`), while `display_controller.gd` applies the
logical view (`FULL` adaptive landscape default, or fixed 3:2/16:10/16:9)
and `sound_manager.gd` applies volume changes. They are user preferences
rather than balance knobs and require no additional tuning resource exports.

## World / scene constants (code, not exported)

These affect dungeon generation and room behavior and are `const` in
`gameplay_state.gd` or `dungeon_graph.gd`:

| Knob | Value | Location |
| --- | ---: | --- |
| Enemy level curve | `max(1, ceil(depth / 4)) + run progression`, clamped by cap | `room_controller.gd:_generated_enemy_base_level` |
| Generated enemy level caps | `3` on R1, `5` on R2, then +1/run | `room_controller.gd:_enemy_level_cap`, `combat_runtime_controller.gd:enemy_level_cap_for_rank` |
| Run 2 popcorn chance | `0.40` level-1 roll; later runs `0.16` | `room_controller.gd:_popcorn_enemy_chance` |
| Popcorn enemy level | `max(1, player level - 5)`; deliberately ignores the normal run cap/bonus | `room_controller.gd:_popcorn_enemy_level`, `_spawn_enemy_slot` |
| Shadow/boss roster safety | Shadow encounters guarantee at least one Normal Slime popcorn slot; boss rooms use 2 neutral popcorn supports on R1–R2, 3 on R3–R6, and 4 from R7 onward; mixed minor slimes begin with 1 on R5, 2 on R6–R9, then add 1 every 3 runs from R10; defeated popcorn slots respawn until the Shadow/scaled boss is gone | `room_controller.gd:_generate_enemy_encounter`, `_generate_boss_encounter`, `_boss_minor_count`, `_boss_support_popcorn_count`, `record_popcorn_enemy_death`, `update_popcorn_respawns` |
| Popcorn respawn delay | 5.0 seconds before a defeated support slime returns; temporary blocked spawns retry after 0.25 seconds | `room_controller.gd:POPCORN_RESPAWN_DELAY`, `POPCORN_RESPAWN_RETRY_DELAY` |
| Enemy health ramp | `0.50` on R1, `0.65` on R2, +0.15/run to `1.0` | `combat_runtime_controller.gd:enemy_health_factor` |
| Encounter progression rank | `completed_runs + 1` | `gameplay_state.gd:_ensure_current_room_layout`, `combat_runtime_controller.gd:encounter_run_rank` |
| Enemy level cap | `3` on R1, `5` on R2, then +1/run | `combat_runtime_controller.gd:enemy_level_cap_for_run` |
| Late-run difficulty bonus | `max(0, encounter_rank - 8)` | `combat_runtime_controller.gd:run_enemy_level_bonus` |
| Performance-over-baseline bonus | `max(0, difficulty_rank - (completed_runs + 1))` | `run_flow_controller.gd:run_difficulty_bonus` |
| Generated room pacing | Authored R1/R2 remain 18/24 rooms; generated targets are 22 on R3, 23 on R4, 24 on R5–R9, then `25 + floor((run - 10) / 2)` from R10; optional branches stay within a small variance budget | `dungeon_layout_generator.gd:generated_room_target_for_run` |
| Generated boss depth | `13` on R3, `14` on R4, `15` on R5–R9, then `16 + floor((run - 10) / 2)` from R10 | `dungeon_layout_generator.gd:generated_boss_depth_for_run` |
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
| Enemy Soul drop | 1 Soul per defeated ordinary enemy; scaled bosses drop 5 Souls on Run 1 and +2 Souls per completed run, with +1 per encounter-scale step above the authored 3.0 boss scale | `combat_runtime_controller.gd:soul_drop_value_for_slime` |
| Soul pickup | Authored 5x5 `Souls.png` sprite with `#A73BA7` soul-purple body (matching the Square-button icon) and a lighter highlight outline derived from that base; 10.0 collection distance, 0.38s launch arc | `soul_visuals.gd`, `pickup_runtime_controller.gd`, `gameplay_state.gd` |
| Fire use / Swap | Full HP, full active Chroma, and earned element attunement for 5 Souls; first starter use is also paid | `gameplay_state.gd:FLAME_SWAP_SOUL_COST` |
| Fire passive recovery | None; HP and Chroma restoration happen only after an explicit paid fire interaction | `combat_runtime_controller.gd:update_player_health_regen`, `gameplay_state.gd:_interact_with_fire` |
| Starter Soul grant | 5-Soul grant from the Cloaked Demon whenever the player is out of Souls (a conditional bailout, not one-time) | `npc_controller.gd`, `player_profile.gd` |
| Flame interaction gesture | Quick press swaps on release; holding for 0.35 seconds fuses | `chest_controller.gd`, `gameplay_state.gd:FLAME_FUSION_HOLD_THRESHOLD` |
| Flame Fusion | 5 Souls; uses current element plus the contacted flame and produces an unbound recipe result | `gameplay_state.gd:FLAME_FUSION_SOUL_COST` |
| Permanent Binding | 50 Souls at the Cloaked Demon for every new bound element; same-element bind is free | `gameplay_state.gd:ELEMENT_BIND_SOUL_COST` |
| Hub flame identity | The selected starter flame remains the hub fire until an explicit permanent Bind; temporary run attunements/fusions do not replace it | `player_profile.gd:hub_flame`, `run_flow_controller.gd`, `room_controller.gd` |

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
 | XP formula | `2 + 2*lvl^0.85`, x1.15/x0.72, clamp [0.30, 2], global x2 | `combat_runtime_controller.gd:xp_reward_for_slime` |
| Gear sale | 25% of `ItemCatalog.price()` plus 75% of recorded fusion steps as Souls | `item_catalog.gd`, `player_profile.gd` |

Shop selling is nested under the Shop page: left/right switches BUY and SELL,
SELL lists unequipped gear only, and the selected sale requires a second confirm
press. BACK cancels a pending sale or returns from SELL to BUY.

BUY and SELL are shown as docked shop controls. Shop entry focuses those controls
first; confirming one opens its list, and selling rebuilds the list immediately
with the selection reset to the first remaining item.
Moving to another sell item cancels the pending sale and updates the detail
prompt for the newly selected item.
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
