# Script Role Map 2026

Status: Stage 1 migration complete (235 original scripts and UID sidecars moved)

Scope: Stage 1 of [`composition-plan-2026.md`](composition-plan-2026.md) - assign every
tracked `scripts/*.gd` file to exactly one of the eight Stage 1 role folders, with runtime subfolders for responsibility

Owner: repository architecture and gameplay systems

Current code: the 235-file Stage 1 inventory plus 44 post-migration modules (279 scripts total); all remain distributed across the declared role roots and runtime subfolders

Verification: all 235 destinations and UID sidecars reconciled against the migration
map; live resource references rewritten; generated index refreshed.

Supersedes: nothing. Implements the Stage 1 layout table in
[`composition-plan-2026.md`](composition-plan-2026.md)

Updated: 2026-10-04 (Stage 3.1 Hub render owners recorded)

Baseline: version `0.3.32`, commit `45db00b`

---

## What this document is

This is the role assignment and migration record for Stage 1. Every row keeps the
original flat source path and records the current role-folder path. All 235 scripts
and their 235 UID sidecars have moved; the live resource paths and generated script
index have been updated in the same migration slice.

## Summary

| Folder | Files | Share | Role |
| - | ---: | ---: | - |
| `scripts/runtime/` | 76 | 32.3% | Feature execution and composition, subdivided by responsibility. |
| `scripts/components/` | 26 | 11.1% | Local behaviour and state attached to one entity. |
| `scripts/content/` | 45 | 19.1% | Authored definitions, catalogs, tuning, and generated content data. |
| `scripts/ui/` | 18 | 7.7% | Screen-space views, menus, HUD, and input surfaces. |
| `scripts/actors/` | 10 | 4.3% | World-space actor entities and actor-specific presentation/behaviour. |
| `scripts/algorithms/` | 28 | 11.9% | Pure computation and solving without node lifetime or side effects. |
| `scripts/editor/` | 19 | 8.1% | Authoring, preview, debug, and editor-facing tooling. |
| `scripts/services/` | 13 | 5.5% | Process-wide shared services instantiated by GameplayBootstrap; not Godot autoloads. |
| **Total** | **235** | **100%** | |

Runtime subfolders: `runtime/contexts/` (32), `runtime/controllers/` (27), `runtime/services/` (8), `runtime/state/` (4), `runtime/world/` (5).

## Folder definitions and assignment rules

Assignments are based on ownership and lifetime, with coordinate space deciding presentation ownership:

1. Entity-local behaviour and state attached to one entity belongs in `components/`.
2. Authored definitions, catalogs, tuning resources, and generated content data belong in `content/`. Mutable profile and active-run state belongs in `runtime/state/`.
3. Screen-anchored or `CanvasLayer` presentation belongs in `ui/`. World-positioned actor entities and their overlays belong in `actors/`; world substrate and cross-cutting rendering systems belong in `runtime/world/`.
4. Pure computation with no node lifetime or side effects belongs in `algorithms/`.
5. Authoring, preview, editor debug, and authoring diagnostics belong in `editor/`.
6. Shared process-wide systems instantiated by `GameplayBootstrap` belong in `services/`. This name does not imply Godot autoload registration.
7. Feature execution belongs under `runtime/`, subdivided into `controllers/`, `contexts/`, `state/`, `services/`, or `world/` according to responsibility.

## `scripts/runtime/` - 76 files

Runtime feature execution, separated into controllers, contexts/results, mutable state, shared runtime services, and world rendering.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/actor_presentation_runtime_controller.gd` | `scripts/runtime/controllers/actor_presentation_runtime_controller.gd` | Shared actor visual frame and effect selection. | - |
| `scripts/chest_controller.gd` | `scripts/runtime/controllers/chest_controller.gd` | Chest open, claim, and reward workflow. | - |
| `scripts/chroma_pickup_controller.gd` | `scripts/runtime/controllers/chroma_pickup_controller.gd` | Chroma pickup collection. | - |
| `scripts/combat_runtime_controller.gd` | `scripts/runtime/controllers/combat_runtime_controller.gd` | Combat resolution, damage, momentum, and progression awards. | - |
| `scripts/gameplay_frame_controller.gd` | `scripts/runtime/controllers/gameplay_frame_controller.gd` | Explicit ordered gameplay tick schedule. | - |
| `scripts/gold_pickup_controller.gd` | `scripts/runtime/controllers/gold_pickup_controller.gd` | Gold pickup collection. | - |
| `scripts/hub_flow_controller.gd` | `scripts/runtime/controllers/hub_flow_controller.gd` | Hub and pause transactions: shop, fusion, gear, stats, binding. | - |
| `scripts/magic_projectile_controller.gd` | `scripts/runtime/controllers/magic_projectile_controller.gd` | Projectile lifecycle and hit resolution. | - |
| `scripts/magic_runtime_controller.gd` | `scripts/runtime/controllers/magic_runtime_controller.gd` | Spell casting, delivery dispatch, and procedural spell visuals. | - |
| `scripts/npc_controller.gd` | `scripts/runtime/controllers/npc_controller.gd` | NPC dialogue and presence. | - |
| `scripts/pickup_runtime_controller.gd` | `scripts/runtime/controllers/pickup_runtime_controller.gd` | Pickup spawning, flight, and collection workflow. | - |
| `scripts/player_controller.gd` | `scripts/runtime/controllers/player_controller.gd` | Player top-level movement coordination. | - |
| `scripts/profile_runtime_controller.gd` | `scripts/runtime/controllers/profile_runtime_controller.gd` | Applies the loaded profile to runtime state. | - |
| `scripts/progression_controller.gd` | `scripts/runtime/controllers/progression_controller.gd` | XP, level, and stat progression rules. | - |
| `scripts/rest_fire_controller.gd` | `scripts/runtime/controllers/rest_fire_controller.gd` | Rest fire interaction and state. | - |
| `scripts/room_controller.gd` | `scripts/runtime/controllers/room_controller.gd` | Room activation, transitions, encounter spawning, and clear detection. | - |
| `scripts/room_puzzle_controller.gd` | `scripts/runtime/controllers/room_puzzle_controller.gd` | Puzzle room interaction and state. | - |
| `scripts/run_flow_controller.gd` | `scripts/runtime/controllers/run_flow_controller.gd` | Run lifecycle: start, advance, transition between rooms. | - |
| `scripts/save_flow_controller.gd` | `scripts/runtime/controllers/save_flow_controller.gd` | Title, archetype, name entry, and save-slot flow. | - |
| `scripts/slime_runtime_controller.gd` | `scripts/runtime/controllers/slime_runtime_controller.gd` | Enemy movement, aggro, attack sequencing, and walkable queries. | - |
| `scripts/soul_pickup_controller.gd` | `scripts/runtime/controllers/soul_pickup_controller.gd` | Soul pickup collection. | - |
| `scripts/status_transmission_controller.gd` | `scripts/runtime/controllers/status_transmission_controller.gd` | Bidirectional contact status transmission. | - |
| `scripts/targeting_runtime_controller.gd` | `scripts/runtime/controllers/targeting_runtime_controller.gd` | Target acquisition and targeting state. | - |
| `scripts/active_run_save_service.gd` | `scripts/runtime/services/active_run_save_service.gd` | Reads and writes active-run snapshot files. | - |
| `scripts/bubble_visuals.gd` | `scripts/runtime/services/bubble_visuals.gd` | Procedural water bubble sprite construction. | - |
| `scripts/combat_stat_snapshot.gd` | `scripts/runtime/contexts/combat_stat_snapshot.gd` | Immutable derived-stat snapshot value object. | - |
| `scripts/boss_jump_slam_context.gd` | `scripts/runtime/contexts/boss_jump_slam_context.gd` | Typed context for the boss slam. | - |
| `scripts/chest_reward_context.gd` | `scripts/runtime/contexts/chest_reward_context.gd` | Typed context for chest reward resolution. | - |
| `scripts/interaction_context.gd` | `scripts/runtime/contexts/interaction_context.gd` | Typed context for interaction resolution. | - |
| `scripts/magic_runtime_context.gd` | `scripts/runtime/contexts/magic_runtime_context.gd` | Typed context that makes magic_runtime_controller seam-free. | - |
| `scripts/player_animation_context.gd` | `scripts/runtime/contexts/player_animation_context.gd` | Typed context for player animation. | - |
| `scripts/player_equipment_visual_context.gd` | `scripts/runtime/contexts/player_equipment_visual_context.gd` | Typed context for worn-equipment visuals. | - |
| `scripts/player_guard_context.gd` | `scripts/runtime/contexts/player_guard_context.gd` | Typed context for player guard state. | - |
| `scripts/player_roll_context.gd` | `scripts/runtime/contexts/player_roll_context.gd` | Typed context for player roll state. | - |
| `scripts/room_activation_context.gd` | `scripts/runtime/contexts/room_activation_context.gd` | Typed context for room activation. | - |
| `scripts/room_checkpoint_context.gd` | `scripts/runtime/contexts/room_checkpoint_context.gd` | Typed context for checkpoint capture. | - |
| `scripts/room_clear_context.gd` | `scripts/runtime/contexts/room_clear_context.gd` | Typed context for room clear detection. | - |
| `scripts/room_enemy_context.gd` | `scripts/runtime/contexts/room_enemy_context.gd` | Typed context for enemy spawn work. | - |
| `scripts/room_enemy_runtime_context.gd` | `scripts/runtime/contexts/room_enemy_runtime_context.gd` | Typed context for enemy runtime state capture. | - |
| `scripts/room_entry_context.gd` | `scripts/runtime/contexts/room_entry_context.gd` | Typed context for room entry. | - |
| `scripts/room_respawn_context.gd` | `scripts/runtime/contexts/room_respawn_context.gd` | Typed context for enemy respawn scheduling. | - |
| `scripts/room_spawn_context.gd` | `scripts/runtime/contexts/room_spawn_context.gd` | Typed context for a room spawn pass. | - |
| `scripts/run_checkpoint_context.gd` | `scripts/runtime/contexts/run_checkpoint_context.gd` | Typed context for run checkpointing. | - |
| `scripts/run_settlement_context.gd` | `scripts/runtime/contexts/run_settlement_context.gd` | Typed context for settlement. | - |
| `scripts/slime_support_context.gd` | `scripts/runtime/contexts/slime_support_context.gd` | Typed context for slime support behaviour. | - |
| `scripts/depth_sorter.gd` | `scripts/runtime/world/depth_sorter.gd` | Y-sort assignment for actors and their sprites. | - |
| `scripts/effects_spawner.gd` | `scripts/runtime/services/effects_spawner.gd` | Effect and particle orchestration plus procedural pixel-text synthesis. | - |
| `scripts/gameplay_bootstrap.gd` | `scripts/runtime/controllers/gameplay_bootstrap.gd` | Composition root: constructs and wires every runtime node. | - |
| `scripts/gameplay_state.gd` | `scripts/runtime/state/gameplay_state.gd` | Shared run state bag and legacy controller bridge. | - |
| `scripts/gameplay.gd` | `scripts/runtime/controllers/gameplay.gd` | Main scene root; holds the node graph and dispatches the frame. | - |
| `scripts/hub_progression_draft.gd` | `scripts/runtime/state/hub_progression_draft.gd` | Pending hub stat allocation draft. | - |
| `scripts/hub_stone_accent_layer.gd` | `scripts/runtime/world/hub_stone_accent_layer.gd` | Procedural decorative stone accents in the hub. | - |
| `scripts/isometric_room_layer.gd` | `scripts/runtime/world/isometric_room_layer.gd` | TileMapLayer that renders the room floor in isometric projection. | - |
| `scripts/mouse_input_snapshot.gd` | `scripts/runtime/contexts/mouse_input_snapshot.gd` | Immutable per-frame mouse state value shared by input consumers. | - |
| `scripts/occlusion_renderer.gd` | `scripts/runtime/world/occlusion_renderer.gd` | Per-pixel occlusion compositing for actors and walls. | - |
| `scripts/player_profile.gd` | `scripts/runtime/state/player_profile.gd` | Persistent player profile data and its migration. | - |
| `scripts/chest_reward_result.gd` | `scripts/runtime/contexts/chest_reward_result.gd` | Chest reward resolution result. | - |
| `scripts/pickup_acquisition_result.gd` | `scripts/runtime/contexts/pickup_acquisition_result.gd` | Pickup acquisition result value object. | - |
| `scripts/room_activation_result.gd` | `scripts/runtime/contexts/room_activation_result.gd` | Room activation result. | - |
| `scripts/room_checkpoint_result.gd` | `scripts/runtime/contexts/room_checkpoint_result.gd` | Checkpoint capture result. | - |
| `scripts/room_clear_result.gd` | `scripts/runtime/contexts/room_clear_result.gd` | Room clear detection result. | - |
| `scripts/room_enemy_runtime_result.gd` | `scripts/runtime/contexts/room_enemy_runtime_result.gd` | Enemy runtime state capture result. | - |
| `scripts/room_entry_result.gd` | `scripts/runtime/contexts/room_entry_result.gd` | Room entry result. | - |
| `scripts/room_spawn_result.gd` | `scripts/runtime/contexts/room_spawn_result.gd` | Room spawn result. | - |
| `scripts/room_transition_result.gd` | `scripts/runtime/contexts/room_transition_result.gd` | Room transition result. | - |
| `scripts/run_checkpoint_result.gd` | `scripts/runtime/contexts/run_checkpoint_result.gd` | Run checkpoint result. | - |
| `scripts/run_settlement_result.gd` | `scripts/runtime/contexts/run_settlement_result.gd` | Settlement result. | - |
| `scripts/room_activation_services.gd` | `scripts/runtime/services/room_activation_services.gd` | Services required by room activation. | - |
| `scripts/room_enemy_spawn_services.gd` | `scripts/runtime/services/room_enemy_spawn_services.gd` | Field bag of services passed into room spawn work. | - |
| `scripts/room_entry_services.gd` | `scripts/runtime/services/room_entry_services.gd` | Services required by room entry. | - |
| `scripts/room_prefab_host.gd` | `scripts/runtime/controllers/room_prefab_host.gd` | Mounts and unmounts authored room prefab scenes. | - |
| `scripts/run_checkpoint_service.gd` | `scripts/runtime/services/run_checkpoint_service.gd` | Forces profile flushes around run snapshots. | - |
| `scripts/run_settlement.gd` | `scripts/runtime/controllers/run_settlement.gd` | End-of-run settlement workflow. | - |
| `scripts/run_state.gd` | `scripts/runtime/state/run_state.gd` | Mutable run progression state for the active run. | - |
| `scripts/shadow_controller.gd` | `scripts/runtime/world/shadow_controller.gd` | Shadow sprite placement for actors. | - |
| `scripts/soul_visuals.gd` | `scripts/runtime/services/soul_visuals.gd` | Procedural soul pickup sprite construction. | - |

## `scripts/components/` - 26 files

Entity-local behaviour and state under the component contract.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/boss_jump_slam_component.gd` | `scripts/components/boss_jump_slam_component.gd` | Boss slam attack state attached to the boss actor. | - |
| `scripts/combat_momentum_component.gd` | `scripts/components/combat_momentum_component.gd` | Focus/combo momentum accumulation for one entity. | - |
| `scripts/element_aura_component.gd` | `scripts/components/element_aura_component.gd` | Elemental aura, innate affinity, and imbue presentation for one entity. | - |
| `scripts/enemy_chroma_component.gd` | `scripts/components/enemy_chroma_component.gd` | Enemy Chroma storage and palette application. | - |
| `scripts/enemy_tactics_component.gd` | `scripts/components/enemy_tactics_component.gd` | Enemy tactic selection policy attached to an enemy. | - |
| `scripts/equipment_component.gd` | `scripts/components/equipment_component.gd` | Equipped gear resolution attached to the player. | - |
| `scripts/equipment_transmutation_component.gd` | `scripts/components/equipment_transmutation_component.gd` | Per-hit gear transmutation reactions on the player. | - |
| `scripts/health_component.gd` | `scripts/components/health_component.gd` | Health and shield state for one attached entity; emits damaged/healed/died. | - |
| `scripts/interaction_component.gd` | `scripts/components/interaction_component.gd` | Interactable surface and prompt for one entity. | - |
| `scripts/player_animation_component.gd` | `scripts/components/player_animation_component.gd` | Player animation state machine and frame selection. | - |
| `scripts/player_aspect_ability_component.gd` | `scripts/components/player_aspect_ability_component.gd` | Player spell-form selection and casting entry. | - |
| `scripts/player_attack_component.gd` | `scripts/components/player_attack_component.gd` | Player melee swing, hitbox window, and attack frames. | - |
| `scripts/player_chroma_component.gd` | `scripts/components/player_chroma_component.gd` | Player Chroma resource, gain, and palette selection. | - |
| `scripts/player_equipment_visual_component.gd` | `scripts/components/player_equipment_visual_component.gd` | Weapon/armour outline, flash, and worn-item presentation. | - |
| `scripts/player_guard_component.gd` | `scripts/components/player_guard_component.gd` | Player blocking and guard state. | - |
| `scripts/player_roll_component.gd` | `scripts/components/player_roll_component.gd` | Roll and backflip movement state. | - |
| `scripts/slime_ambush_component.gd` | `scripts/components/slime_ambush_component.gd` | Hidden ambush behaviour attached to a slime. | - |
| `scripts/slime_animation_component.gd` | `scripts/components/slime_animation_component.gd` | Slime animation frame selection. | - |
| `scripts/slime_brain.gd` | `scripts/components/slime_brain.gd` | Slime AI decision-making: aggro, approach, attack choice. | - |
| `scripts/slime_combat_component.gd` | `scripts/components/slime_combat_component.gd` | Slime attack resolution and damage intake. | - |
| `scripts/slime_health_presenter.gd` | `scripts/components/slime_health_presenter.gd` | Slime health bar presentation attached to the slime. | - |
| `scripts/slime_spawn_component.gd` | `scripts/components/slime_spawn_component.gd` | Slime spawn-animation lock during entry. | - |
| `scripts/slime_support_component.gd` | `scripts/components/slime_support_component.gd` | Slime support/cast behaviour attached to the slime. | - |
| `scripts/slime_visual_component.gd` | `scripts/components/slime_visual_component.gd` | Slime sprite, tint, and flash presentation. | - |
| `scripts/stats_component.gd` | `scripts/components/stats_component.gd` | Derived combat and movement stat aggregation for one entity. | - |
| `scripts/status_component.gd` | `scripts/components/status_component.gd` | Status record ownership and ticking for one entity. | - |

## `scripts/content/` - 45 files

Authored and generated content definitions, data, catalogs, and compilers.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/active_run_snapshot_context.gd` | `scripts/content/active_run_snapshot_context.gd` | Typed context for run snapshot capture. | - |
| `scripts/active_run_snapshot.gd` | `scripts/content/active_run_snapshot.gd` | Saveable snapshot of the active run. | - |
| `scripts/aspect_catalog.gd` | `scripts/content/aspect_catalog.gd` | Validated lookup of authored aspect definitions. | - |
| `scripts/authoring_placement_catalog.gd` | `scripts/content/authoring_placement_catalog.gd` | Authored placement data for content authoring. | - |
| `scripts/chroma_costs.gd` | `scripts/content/chroma_costs.gd` | Authored Chroma cost table. | - |
| `scripts/chroma_tuning.gd` | `scripts/content/chroma_tuning.gd` | Chroma tuning resource. | - |
| `scripts/combat_damage_request.gd` | `scripts/content/combat_damage_request.gd` | Typed damage request value object. | - |
| `scripts/combat_tuning.gd` | `scripts/content/combat_tuning.gd` | Combat tuning resource. | - |
| `scripts/content_definition_manifest_data.gd` | `scripts/content/content_definition_manifest_data.gd` | Generated manifest payload resource. | - |
| `scripts/content_definition_manifest_service.gd` | `scripts/content/content_definition_manifest_service.gd` | Manifest freshness and discovery logic. | - |
| `scripts/effects_tuning.gd` | `scripts/content/effects_tuning.gd` | Effects tuning resource. | - |
| `scripts/element_catalog_data.gd` | `scripts/content/element_catalog_data.gd` | Authored element catalog data. | - |
| `scripts/element_catalog.gd` | `scripts/content/element_catalog.gd` | Validated lookup of authored element definitions. | - |
| `scripts/encounter_definition.gd` | `scripts/content/encounter_definition.gd` | Authored encounter composition and weighted variant selection. | - |
| `scripts/enemy_definition.gd` | `scripts/content/enemy_definition.gd` | Authored enemy content contract. | - |
| `scripts/enemy_factory.gd` | `scripts/content/enemy_factory.gd` | Builds enemy actors and components from an EnemyDefinition. | - |
| `scripts/enemy_geometry_profile.gd` | `scripts/content/enemy_geometry_profile.gd` | Authored enemy geometry profile resource. | - |
| `scripts/item_catalog_data.gd` | `scripts/content/item_catalog_data.gd` | Authored item catalog data. | - |
| `scripts/item_catalog.gd` | `scripts/content/item_catalog.gd` | Validated lookup of authored item definitions. | - |
| `scripts/item_definition.gd` | `scripts/content/item_definition.gd` | Authored item content contract. | - |
| `scripts/item_instance.gd` | `scripts/content/item_instance.gd` | A concrete item instance derived from a definition. | - |
| `scripts/item_visual_resolver.gd` | `scripts/content/item_visual_resolver.gd` | Resolves an item definition to its icon and drop art. | - |
| `scripts/palette_library_data.gd` | `scripts/content/palette_library_data.gd` | Authored palette data resource. | - |
| `scripts/player_tuning.gd` | `scripts/content/player_tuning.gd` | Player tuning resource. | - |
| `scripts/progression_tuning.gd` | `scripts/content/progression_tuning.gd` | Progression tuning resource. | - |
| `scripts/puzzle_plan_data.gd` | `scripts/content/puzzle_plan_data.gd` | Authored puzzle plan data resource. | - |
| `scripts/reward_definition.gd` | `scripts/content/reward_definition.gd` | Authored reward definition. | - |
| `scripts/room_definition.gd` | `scripts/content/room_definition.gd` | Authored room content contract. | - |
| `scripts/room_prefab_definition.gd` | `scripts/content/room_prefab_definition.gd` | Authored room prefab contract. | - |
| `scripts/room_prefab_factory.gd` | `scripts/content/room_prefab_factory.gd` | materializes a room prefab from its definition. | - |
| `scripts/room_prefab_mount_result.gd` | `scripts/content/room_prefab_mount_result.gd` | Room prefab mount result value object. | - |
| `scripts/slime_tuning.gd` | `scripts/content/slime_tuning.gd` | Slime tuning resource. | - |
| `scripts/slime_variant_catalog_data.gd` | `scripts/content/slime_variant_catalog_data.gd` | Authored slime variant catalog data. | - |
| `scripts/slime_variant_catalog.gd` | `scripts/content/slime_variant_catalog.gd` | Validated lookup of authored slime variants. | - |
| `scripts/sound_clip_catalog.gd` | `scripts/content/sound_clip_catalog.gd` | Validated lookup of authored sound clips. | - |
| `scripts/sound_mix_profile.gd` | `scripts/content/sound_mix_profile.gd` | Authored mix profile data. | - |
| `scripts/spell_form_catalog.gd` | `scripts/content/spell_form_catalog.gd` | Validated lookup of authored spell forms. | - |
| `scripts/spell_form_definition.gd` | `scripts/content/spell_form_definition.gd` | Authored spell form contract. | - |
| `scripts/status_application_request.gd` | `scripts/content/status_application_request.gd` | Status application request value object. | - |
| `scripts/status_application.gd` | `scripts/content/status_application.gd` | Status application result value object. | - |
| `scripts/status_contact_pair.gd` | `scripts/content/status_contact_pair.gd` | Per-pair contact transmission cooldown record. | - |
| `scripts/status_effect_definition.gd` | `scripts/content/status_effect_definition.gd` | Authored status effect contract. | - |
| `scripts/status_record.gd` | `scripts/content/status_record.gd` | A single applied status record. | - |
| `scripts/status_tick_result.gd` | `scripts/content/status_tick_result.gd` | Status tick result value object. | - |
| `scripts/touch_controls_layout_profile.gd` | `scripts/content/touch_controls_layout_profile.gd` | Authored touch control layout profile. | - |

## `scripts/ui/` - 18 files

Screen-space presentation and UI controls.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/bind_menu_layout.gd` | `scripts/ui/bind_menu_layout.gd` | Elemental binding menu layout. | - |
| `scripts/bind_menu_model.gd` | `scripts/ui/bind_menu_model.gd` | Binding menu selection model. | - |
| `scripts/cloud_save_panel.gd` | `scripts/ui/cloud_save_panel.gd` | Cloud-save UI panel controller used from the save flow. | - |
| `scripts/dungeon_map_controller.gd` | `scripts/ui/dungeon_map_controller.gd` | Full-screen dungeon map screen, its layout, and its state. | - |
| `scripts/dungeon_minimap_controller.gd` | `scripts/ui/dungeon_minimap_controller.gd` | In-run minimap rendering and landmark display. | - |
| `scripts/equipment_menu_layout.gd` | `scripts/ui/equipment_menu_layout.gd` | Authored equipment menu scene layout. | - |
| `scripts/fusion_menu_layout.gd` | `scripts/ui/fusion_menu_layout.gd` | Fusion menu layout; extends ShopMenuLayout. | - |
| `scripts/fusion_menu_model.gd` | `scripts/ui/fusion_menu_model.gd` | Fusion menu selection model. | - |
| `scripts/hud_controller.gd` | `scripts/ui/hud_controller.gd` | In-run HUD: health, MP, target frame, counters, cooldowns. | - |
| `scripts/menu_command_list.gd` | `scripts/ui/menu_command_list.gd` | Shared command-list model for menu footers and prompts. | - |
| `scripts/menu_cursor.gd` | `scripts/ui/menu_cursor.gd` | Shared animated menu cursor sprite. | - |
| `scripts/menu_panel_8_piece.gd` | `scripts/ui/menu_panel_8_piece.gd` | Nine-patch-style menu panel frame piece. | - |
| `scripts/menu_player_context.gd` | `scripts/ui/menu_player_context.gd` | Typed data handed to menu presenters instead of the root. | - |
| `scripts/menu_responsive_layout.gd` | `scripts/ui/menu_responsive_layout.gd` | Menu scaling math for the native 240x160 target. | - |
| `scripts/pause_menu_layout.gd` | `scripts/ui/pause_menu_layout.gd` | Pause menu layout construction. | - |
| `scripts/screen_state_controller.gd` | `scripts/ui/screen_state_controller.gd` | Screen-state facade, compatibility properties, and rendering coordination behind typed screen owners. | - |
| `scripts/shop_menu_layout.gd` | `scripts/ui/shop_menu_layout.gd` | Authored shop menu scene layout and cursor model. | - |
| `scripts/touch_controls_layer.gd` | `scripts/ui/touch_controls_layer.gd` | Touch input surface and virtual controls. | - |

## `scripts/actors/` - 10 files

World-space actor entities and actor-specific presentation.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/actor_collision_system.gd` | `scripts/actors/actor_collision_system.gd` | Shared swept collision resolution for any actor. | - |
| `scripts/actor_motor.gd` | `scripts/actors/actor_motor.gd` | Actor movement and displacement resolution; operates against its host actor and collision substrate. | - |
| `scripts/actor_palette_material.gd` | `scripts/actors/actor_palette_material.gd` | Per-actor palette material instance. | - |
| `scripts/dungeon_socket.gd` | `scripts/actors/dungeon_socket.gd` | World-space door/entrance socket node. | - |
| `scripts/enemy_cast_bar.gd` | `scripts/actors/enemy_cast_bar.gd` | World-space cast bar drawn above an enemy. | - |
| `scripts/enemy_target_arc.gd` | `scripts/actors/enemy_target_arc.gd` | World-space targeting indicator drawn on the target actor. | - |
| `scripts/player_hud.gd` | `scripts/actors/player_hud.gd` | Player overhead world-space bars and labels. | - |
| `scripts/room_geometry_controller.gd` | `scripts/actors/room_geometry_controller.gd` | Room polygon, socket, and walkability geometry queries. | - |
| `scripts/skeleton_actor.gd` | `scripts/actors/skeleton_actor.gd` | Skeleton enemy entity root; extends SlimeActor. | - |
| `scripts/slime_actor.gd` | `scripts/actors/slime_actor.gd` | Slime entity root; composes slime components and owns actor geometry. | - |

## `scripts/algorithms/` - 28 files

Pure computation and data transformations.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/actor_geometry.gd` | `scripts/algorithms/actor_geometry.gd` | Shared geometry math: body polygon, foot offset, scaled centres. | - |
| `scripts/circular_input_recognizer.gd` | `scripts/algorithms/circular_input_recognizer.gd` | Recognises circular directional input gestures. | - |
| `scripts/combat_calculator.gd` | `scripts/algorithms/combat_calculator.gd` | Pure combat damage and stat arithmetic. | - |
| `scripts/dungeon_generation_policy.gd` | `scripts/algorithms/dungeon_generation_policy.gd` | Generation constraint values (caps, ratios) as data. | - |
| `scripts/dungeon_graph.gd` | `scripts/algorithms/dungeon_graph.gd` | Room graph structure and traversal queries. | - |
| `scripts/dungeon_layout_definition.gd` | `scripts/algorithms/dungeon_layout_definition.gd` | Authored layout data shape in code. | - |
| `scripts/dungeon_layout_generator.gd` | `scripts/algorithms/dungeon_layout_generator.gd` | Route generation and reachability validation; pure, no node or resource authoring. | - |
| `scripts/dungeon_layout_run1.gd` | `scripts/algorithms/dungeon_layout_run1.gd` | Authored run-1 layout data. | - |
| `scripts/dungeon_layout_run2.gd` | `scripts/algorithms/dungeon_layout_run2.gd` | Authored run-2 layout data. | - |
| `scripts/dungeon_layout_run3.gd` | `scripts/algorithms/dungeon_layout_run3.gd` | Authored run-3 layout data. | - |
| `scripts/dungeon_layout_run4.gd` | `scripts/algorithms/dungeon_layout_run4.gd` | Authored run-4 layout data. | - |
| `scripts/dungeon_layout_run5.gd` | `scripts/algorithms/dungeon_layout_run5.gd` | Authored run-5 layout data. | - |
| `scripts/dungeon_layout_run6.gd` | `scripts/algorithms/dungeon_layout_run6.gd` | Authored run-6 layout data. | - |
| `scripts/dungeon_map_state.gd` | `scripts/algorithms/dungeon_map_state.gd` | Map projection state derived from the room graph. | - |
| `scripts/dungeon_run_definition.gd` | `scripts/algorithms/dungeon_run_definition.gd` | Per-run generation definition resource. | - |
| `scripts/display_layout.gd` | `scripts/algorithms/display_layout.gd` | Pure responsive-layout math consumed by display and by screen layout. | - |
| `scripts/puzzle_map_grid.gd` | `scripts/algorithms/puzzle_map_grid.gd` | Puzzle grid structure and neighbour queries. | - |
| `scripts/puzzle_map_layout_compiler.gd` | `scripts/algorithms/puzzle_map_layout_compiler.gd` | Compiles authored puzzle data into a playable map. | - |
| `scripts/puzzle_map_r3_new.gd` | `scripts/algorithms/puzzle_map_r3_new.gd` | Authored puzzle map r3 data. | - |
| `scripts/puzzle_map_r4.gd` | `scripts/algorithms/puzzle_map_r4.gd` | Authored puzzle map r4 data. | - |
| `scripts/puzzle_map_r5.gd` | `scripts/algorithms/puzzle_map_r5.gd` | Authored puzzle map r5 data. | - |
| `scripts/puzzle_progression_planner.gd` | `scripts/algorithms/puzzle_progression_planner.gd` | Chooses puzzle variants across a run. | - |
| `scripts/puzzle_route_generator.gd` | `scripts/algorithms/puzzle_route_generator.gd` | Puzzle route construction. | - |
| `scripts/puzzle_route_plan.gd` | `scripts/algorithms/puzzle_route_plan.gd` | Puzzle route value object. | - |
| `scripts/puzzle_route_solver.gd` | `scripts/algorithms/puzzle_route_solver.gd` | Puzzle route solving. | - |
| `scripts/room_enemy_placement.gd` | `scripts/algorithms/room_enemy_placement.gd` | Chooses valid enemy spawn positions. | - |
| `scripts/run_grade.gd` | `scripts/algorithms/run_grade.gd` | Run score and grade computation. | - |
| `scripts/walkable_area.gd` | `scripts/algorithms/walkable_area.gd` | Builds and queries walkable polygons and outlines from floor tiles. | - |

## `scripts/editor/` - 19 files

Editor authoring, previews, and diagnostic tools.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/actor_geometry_debug_drawer.gd` | `scripts/editor/actor_geometry_debug_drawer.gd` | Editor debug draw of actor collision and body geometry. | - |
| `scripts/attack_hitbox_guide.gd` | `scripts/editor/attack_hitbox_guide.gd` | Editor visualisation of attack hitboxes. | - |
| `scripts/debug_menu_layout.gd` | `scripts/editor/debug_menu_layout.gd` | Debug menu page construction. | - |
| `scripts/debug_session_controller.gd` | `scripts/editor/debug_session_controller.gd` | Debug menu dispatch and debug session state. | - |
| `scripts/demon_hub_menu_preview.gd` | `scripts/editor/demon_hub_menu_preview.gd` | Editor preview of the hub menu screen. | - |
| `scripts/editor_collision_guide.gd` | `scripts/editor/editor_collision_guide.gd` | Editor-only collision guide overlay. | - |
| `scripts/editor_polygon_guide.gd` | `scripts/editor/editor_polygon_guide.gd` | Editor-only polygon guide overlay. | - |
| `scripts/enemy_preview_workbench.gd` | `scripts/editor/enemy_preview_workbench.gd` | Editor enemy preview with mode switching and loop control. | - |
| `scripts/generated_puzzle_map_preview.gd` | `scripts/editor/generated_puzzle_map_preview.gd` | Editor preview of a generated puzzle map. | - |
| `scripts/hub_world_preview.gd` | `scripts/editor/hub_world_preview.gd` | Editor preview of the hub world scene. | - |
| `scripts/item_preview_workbench.gd` | `scripts/editor/item_preview_workbench.gd` | Editor item preview workbench. | - |
| `scripts/pause_menu_preview.gd` | `scripts/editor/pause_menu_preview.gd` | Editor preview of the pause menu. | - |
| `scripts/placement_root_2d.gd` | `scripts/editor/placement_root_2d.gd` | Editor placement helper root for authored content. | - |
| `scripts/preview_session_runtime.gd` | `scripts/editor/preview_session_runtime.gd` | Runtime node backing an authoring preview session. | - |
| `scripts/preview_session.gd` | `scripts/editor/preview_session.gd` | Isolated preview session state for authoring previews. | - |
| `scripts/puzzle_map_preview.gd` | `scripts/editor/puzzle_map_preview.gd` | Editor preview of a puzzle map. | - |
| `scripts/shop_preview.gd` | `scripts/editor/shop_preview.gd` | Editor preview of the shop menu. | - |
| `scripts/touch_controls_authoring.gd` | `scripts/editor/touch_controls_authoring.gd` | Editor authoring aid for touch control placement. | - |
| `scripts/ui_layout_guide.gd` | `scripts/editor/ui_layout_guide.gd` | Editor-only UI layout guide overlay. | - |

## `scripts/services/` - 13 files

Process-wide services instantiated during gameplay bootstrap; none are declared as game autoloads.

| Original path | Current path | Reason | Uncertainty |
| - | - | - | - |
| `scripts/cloud_save_service.gd` | `scripts/services/cloud_save_service.gd` | Encrypted cloud save transport; shared by profile and run services. | - |
| `scripts/display_controller.gd` | `scripts/services/display_controller.gd` | Window/viewport/scaling ownership; single instance for the whole process. | - |
| `scripts/feedback_animation_registry.gd` | `scripts/services/feedback_animation_registry.gd` | Shared registry of feedback animation sets. | - |
| `scripts/input_device_tracker.gd` | `scripts/services/input_device_tracker.gd` | Keyboard/controller/touch device detection; drives prompt glyph selection. | - |
| `scripts/input_router.gd` | `scripts/services/input_router.gd` | Central input mapping and just-pressed semantics for every consumer. | - |
| `scripts/palette_library.gd` | `scripts/services/palette_library.gd` | Global palette-name to colour/texture resolution. | - |
| `scripts/performance_capture_service.gd` | `scripts/services/performance_capture_service.gd` | Frame-time capture behind the perf harness and F9 overlay. | - |
| `scripts/profile_save_service.gd` | `scripts/services/profile_save_service.gd` | Owns the on-disk profile write queue, verification, and rate limiting. | - |
| `scripts/settings_service.gd` | `scripts/services/settings_service.gd` | Persistent display/audio/input settings; read by display, audio, and input alike. | - |
| `scripts/sound_manager.gd` | `scripts/services/sound_manager.gd` | Audio bus ownership and one-shot/music playback; one instance shared by every feature. | - |
| `scripts/sprite_frame_library.gd` | `scripts/services/sprite_frame_library.gd` | Shared sprite-sheet slicing and cache; every actor and UI view reads frames from it. | - |
| `scripts/web_run_diagnostics.gd` | `scripts/services/web_run_diagnostics.gd` | Web-only runtime diagnostic capture for debugging browser builds. | - |
| `scripts/web_save_crypto.gd` | `scripts/services/web_save_crypto.gd` | Web-platform encryption helper for save payloads. | - |

## `.gd.uid` sidecars

All 235 UID sidecars moved with their matching scripts and retained their UID contents.
Scene and resource references still resolve by UID, and serialized resource paths now
name the destination role folder.

---

## Resolved assignment decisions

These decisions close the prior 29-item ambiguity list and are reflected in the current paths above. Actor movement stays in actors/ because it owns actor-host movement resolution rather than a pure calculation.

| Decision | Applied rule | Representative assignments |
| - | - | - |
| Shared services | Use services/ for process-wide services instantiated by GameplayBootstrap; these are not Godot autoloads. | cloud_save_service.gd, settings_service.gd, sound_manager.gd |
| Screen and world presentation | ui/ owns screen-anchored and CanvasLayer presentation. actors/ owns actor entities and actor-attached world overlays. runtime/world/ owns room substrate and cross-cutting world rendering. | player_hud.gd to actors/; enemy_cast_bar.gd to actors/; isometric_room_layer.gd to runtime/world/ |
| Mutable player/run state | Mutable profile and active-run state belongs in runtime/state/. | player_profile.gd, run_state.gd, gameplay_state.gd |
| Runtime data contracts | Typed contexts/results live in runtime/contexts/; transfer bags and persistence/runtime services live in runtime/services/. | room_enemy_spawn_services.gd to runtime/services/ (temporary until Stage 3.2); combat_stat_snapshot.gd to runtime/contexts/ |
| Runtime responsibility layout | Controllers and composition roots live in runtime/controllers/; shared runtime services and procedural effects live in runtime/services/; world layers/render systems live in runtime/world/. | gameplay_bootstrap.gd, effects_spawner.gd, depth_sorter.gd |
| Pure computation | Keep node-free deterministic computation in algorithms/, even when consumed by one feature. Actor-host movement stays with actors/. | actor_geometry.gd, walkable_area.gd, circular_input_recognizer.gd, display_layout.gd |
| Tooling versus runtime UI | Authoring/debug-only interfaces remain in editor/; runtime panels and screens use ui/. | debug_menu_layout.gd to editor/; cloud_save_panel.gd to ui/ |

## Verification performed

| Check | Result |
| - | - |
| Tracked source scripts assigned | 235 of 235 |
| Current script files at mapped destinations | 235 of 235 |
| Duplicate source assignments | 0 |
| Duplicate destinations | 0 |
| Missing or unassigned scripts | 0 |
| Tracked `.gd.uid` sidecars | 235 |
| UID pairing mismatches | 0 |
| Script files left directly under `scripts/` | 0 |
| Resolved role decisions remaining | 0 |
| Role-folder counts | Match the summary above |

The source basename set matches the pre-migration tracked inventory. Current paths and
UID sidecars were checked against every map row. `tools/generate_script_index.ps1`
now recurses through role folders, so the generated links include each current path.

## Scope boundary

This document records the Stage 1 role assignment and migration outcome. The companion
reference audit is in [`../coord/script-role-reference-audit.md`](../coord/script-role-reference-audit.md).
The map retains each original flat path alongside its current path for traceability.

## Post-migration additions

These forty-two modules were added after the 235-script Stage 1 inventory. They
use the same folder roles and are included in the generated script index.

| Current path | Role | Reason |
|---|---|---|
| `scripts/runtime/controllers/hub_economy_controller.gd` | `runtime/controllers/` | Owns hub binding, inventory, shop, equipment, fusion, salvage, and stat-allocation transactions as a subcontroller of HubFlowController. |
| `scripts/ui/hub_menu_state.gd` | `ui/` | Owns shared Hub page/mode constants and mutable navigation, equipment, shop, fusion, and binding state with compatibility transition helpers. |
| `scripts/runtime/services/pixel_text_texture_factory.gd` | `runtime/services/` | Builds and caches pixel text, name, and keyboard-prompt textures behind the EffectsSpawner facade. |
| `scripts/runtime/controllers/slime_geometry_queries.gd` | `runtime/controllers/` | Owns typed collision, actor-foot, and walkability queries behind the SlimeRuntimeController facade. |
| `scripts/runtime/controllers/actor_status_runtime_controller.gd` | `runtime/controllers/` | Owns typed status application and actor status ticking behind the CombatRuntimeController facade. |
| `scripts/runtime/controllers/combat_feedback_presenter.gd` | `runtime/controllers/` | Owns typed combat damage/healing number layout and spawning behind the CombatRuntimeController facade. |
| `scripts/ui/title_particle_controller.gd` | `ui/` | Owns title particle creation, frame updates, and cleanup behind the ScreenStateController facade. |
| `scripts/ui/menu_widget_factory.gd` | `ui/` | Builds shared menu buttons, overlays, sprites, frames, and cards behind the ScreenStateController facade. |
| `scripts/ui/menu_cursor_animator.gd` | `ui/` | Owns menu cursor target motion, idle bob, and tween cleanup behind the ScreenStateController facade. |
| `scripts/ui/loading_screen_presenter.gd` | `ui/` | Builds the loading overlay and owns its label/fade visuals behind the ScreenStateController facade. |
| `scripts/ui/menu_prompt_texture_factory.gd` | `ui/` | Composes, caches, and lays out shared face-button prompt textures and icons behind the ScreenStateController facade. |
| `scripts/ui/name_entry_widget_presenter.gd` | `ui/` | Builds and positions the Name Entry widget tree; its references are held by the Name Entry screen owner and exposed through ScreenStateController compatibility properties. |
| `scripts/ui/name_entry_screen_controller.gd` | `ui/` | Owns Name Entry text, selection, input, visual refresh, callbacks, and pending-slot lifecycle behind ScreenStateController's stable interface. |
| `scripts/ui/save_select_screen_presenter.gd` | `ui/` | Builds and responsively positions the Save Select view behind ScreenStateController's overlay and footer accessors; save transactions remain in SaveFlowController. |
| `scripts/ui/title_screen_presenter.gd` | `ui/` | Builds and lays out the title overlay and its profile-sensitive command rows behind ScreenStateController's stable state and transition interface. |
| `scripts/ui/archetype_screen_presenter.gd` | `ui/` | Builds and responsively positions the character-creation screen controls behind ScreenStateController's selection and transition interface. |
| `scripts/ui/settings_screen_presenter.gd` | `ui/` | Owns the Settings widget tree, responsive layout, selection/cursor state, option presentation, and typed setting changes behind ScreenStateController's input and transition facade. |
| `scripts/ui/game_over_screen_presenter.gd` | `ui/` | Owns the Game Over widget tree, responsive layout, row state, and fade visuals behind ScreenStateController; defeat settlement and shared menu input remain in their existing owners. |
| `scripts/ui/run_complete_screen_presenter.gd` | `ui/` | Owns the Run Complete widget tree and responsive positioning; run scoring and results remain in RunFlowController, with ScreenStateController exposing the observation handles. |
| `scripts/ui/pause_debug_menu_context.gd` | `ui/` | Typed read-only presentation snapshot for Pause debug values; transient debug overrides and lifecycle remain in DebugSessionController. |
| `scripts/ui/pause_screen_presenter.gd` | `ui/` | Owns Pause widget construction, typed view references, responsive layout, page/command visibility, command prompts/cursor, and read-only page rendering behind ScreenStateController; route transitions and cross-screen state stay in ScreenStateController. |
| `scripts/ui/hub_screen_actions.gd` | `ui/` | Typed named callback set for Hub and Pause screen construction; removes a positional callback list from the screen builder API. |
| `scripts/ui/hub_command_shell_presenter.gd` | `ui/` | Owns Hub command buttons, Back button, cursor anchoring, and command cursor presentation while delegating tween lifetime to MenuCursorAnimator. |
| `scripts/ui/hub_input_controller.gd` | `ui/` | Routes Hub input through named Back, command-rail, and page-specific handlers using typed GameplayState, HubMenuState, and screen presenters. |
| `scripts/ui/hub_page_visibility_presenter.gd` | `ui/` | Owns Hub page-root lookup, title/chrome visibility, and authored Equipment/Shop/Fusion route visibility and Back hit-target routing behind typed collaborators. |
| `scripts/ui/hub_stats_screen_presenter.gd` | `ui/` | Owns Hub stats and allocation UI nodes, status/allocation rendering, and preview presentation behind ScreenStateController's typed compatibility properties. |
| `scripts/ui/hub_responsive_layout_context.gd` | `ui/` | Typed input for Hub responsive positioning: viewport, menu state, collaborating presenters, cursor animator, and tween owner. |
| `scripts/ui/hub_responsive_layout_presenter.gd` | `ui/` | Builds Hub shell chrome, updates footer prompts, and owns responsive geometry and legacy cursor anchoring while delegating page, stats, command, and tween behavior to their typed owners. |
| `scripts/ui/hub_item_visibility_context.gd` | `ui/` | Typed Hub route and focus state for legacy item, equipment, shop, and fusion visibility. |
| `scripts/ui/hub_item_visibility_presenter.gd` | `ui/` | Applies legacy equipment, shop, and fusion control visibility and input filters using the responsive presenter's typed widget references. |
| `scripts/ui/hub_stats_interaction_presenter.gd` | `ui/` | Owns stat cursor, allocation focus, and stats-page widget visibility through the typed HubStatsScreenPresenter node owner. |
| `scripts/ui/hub_equipment_menu_context.gd` | `ui/` | Typed render inputs shared by the authored Hub and Pause Equipment views. |
| `scripts/ui/hub_equipment_menu_presenter.gd` | `ui/` | Builds Equipment slot, candidate, stat-preview, and item-detail presentation behind ScreenStateController's compatibility facade. |
| `scripts/ui/hub_transaction_menu_context.gd` | `ui/` | Typed Shop and Fusion presentation inputs, including item rows, selection state, and economy details gathered by their existing owners. |
| `scripts/ui/shop_menu_model.gd` | `ui/` | Typed row, stat-comparison, quantity, and scroll model consumed by the authored ShopMenuLayout. |
| `scripts/ui/hub_transaction_menu_presenter.gd` | `ui/` | Builds Shop and Fusion render models and shared equipment-stat comparison data without owning transactions or mutable menu state. |
| `scripts/ui/hub_menu_signal_binder.gd` | `ui/` | Connects typed Equipment, Shop, Fusion, and Bind view signals to HubScreenActions while keeping menu construction and state in ScreenStateController. |
| `scripts/ui/hub_legacy_widget_visibility_presenter.gd` | `ui/` | Suppresses legacy Hub inventory widgets beneath the active authored Equipment and Shop views while retaining their input, layout, and fallback readers. |
| `scripts/ui/hub_legacy_widget_scroll_presenter.gd` | `ui/` | Positions legacy Hub item, price, touch-row, and gear-choice widgets from scroll state without owning input or selection. |
| `scripts/ui/hub_legacy_widget_action_presenter.gd` | `ui/` | Activates an enabled legacy Equipment or Shop action button behind a typed capability used by HubInputController. |
| `scripts/ui/pause_menu_state.gd` | `ui/` | Owns Pause page, menu/debug selection, command-list, and Pause input-latch state behind ScreenStateController compatibility properties. |
| `scripts/ui/pause_menu_input_controller.gd` | `ui/` | Owns Pause command-row and Debug-page input; ScreenStateController retains page transitions and the shared Hub Equipment transaction. |
| `scripts/ui/hub_screen_render_controller.gd` | `ui/` | Owns the Hub frame-to-view presentation pipeline behind ScreenStateController's stable update entry point. |
| `scripts/ui/hub_legacy_inventory_presenter.gd` | `ui/` | Owns compatibility inventory, equipment, and gear-comparison rendering for legacy Hub widget paths. |

## Migration result

- All mapped `.gd` files and `.gd.uid` sidecars are in their role folders.
- Live resource paths were rewritten across scripts, scenes, resources, tests, and tools.
- `docs/SCRIPT_INDEX.md` was regenerated from the new folder structure.
- The composition validator recognizes `services/` and recursively scans scripts; the baseline's per-file path labels now match the current destinations.
- No gameplay behavior was changed.
