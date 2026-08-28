# Tiny Demons — Architecture

Companion to `AUDIT.md` (current/desired state, findings, plan) and
`GAMEPLAY_TUNING.md` (the balance surface). This file is the component map and
the "where does my feature go" guide.

## Runtime topology

```
main.tscn (GameplayState, extends Node2D)
 └── Map/FloorTiles            isometric room grid (isometric_room_layer)
 └── Actors/
 │    ├── Player               player_controller, actor_motor, roll/attack/
 │    │                        guard/animation/equipment-visual components
 │    ├── SlimeBlue/Green/Red  slime_actor + brain/combat/animation/visual/
 │    │                        health-presenter/ambush components
 │    ├── Chest                chest_controller
 │    └── CloakedDemon         npc_controller
 ├── RestFire                  rest_fire_controller
 ├── DisplayController         logical view, void/frame, and settings apply
 └── InterfaceCanvas/UI        HUD (player_hud, hud_controller), screen
                              overlays (screen_state_controller), effects
                              layer (effects_spawner)
```

The `gameplay.gd` coordinator owns the run loop and wires all of the above
together through the shared `gameplay_state.gd` state bag. Components are
created at runtime by `gameplay_bootstrap.gd`; `gameplay_frame_controller.gd`
orders the per-frame update.

This describes the current implementation, not the desired endpoint. The active
migration keeps one explicit frame schedule while replacing shared-state reach-ins
and string dispatch one feature slice at a time. See
[`refactor-route.md`](refactor-route.md).

## Scripts by responsibility

- **Player**: `player_controller`, `actor_motor`, `player_roll_component`,
  `player_attack_component`, `player_guard_component`,
  `player_animation_component`, `player_equipment_visual_component`,
  `player_hud`.
- **Enemies**: `slime_actor`, `slime_brain`, `slime_combat_component`,
  `slime_animation_component`, `slime_visual_component`,
  `slime_health_presenter`, `slime_ambush_component`,
  `enemy_tactics_component`.
- **World**: `room_controller`, `dungeon_graph`, `dungeon_socket`,
  `isometric_room_layer`, `walkable_area`, `actor_collision_system`,
  `depth_sorter`, `shadow_controller`, `occlusion_renderer`.
- **Interaction**: `interaction_component`, `chest_controller`,
  `npc_controller`, `rest_fire_controller`, `attack_hitbox_guide`.
- **Meta/progression**: `player_profile`, `profile_save_service`,
  `run_state`, `run_grade`, `run_settlement`, `item_catalog`,
  `item_instance`, `equipment_component`, `equipment_transmutation_component`,
  `stats_component`, `combat_stat_snapshot`, `combat_calculator`.
- **Presentation**: `hud_controller`, `effects_spawner`,
  `screen_state_controller`, `sprite_frame_library`, `display_controller`,
  `display_layout`.
- **Settings/audio**: `settings_service` owns device-wide persisted options;
  `sound_manager` consumes the live music/SFX values and applies their dB
  offsets to the Master bus.
- **Web/input**: `input_device_tracker` (last deliberate device and prompt
  labels), `touch_controls_layer` (virtual stick and touch buttons), and
  `input_router` (the single merged input snapshot).
- **Infra**: `gameplay` (coordinator), `gameplay_state` (state),
  `gameplay_bootstrap`, `gameplay_frame_controller`,
  `editor_collision_guide`, `editor_polygon_guide`, `ui_layout_guide`.

## Tuning resources (all `@export`-driven, in-editor editable)

| Resource | Focus |
| --- | --- |
| `player_tuning.gd` | Movement, attack frames/combos, stats |
| `slime_tuning.gd` | Enemy health, speed, aggro, attack ranges |
| `combat_tuning.gd` | Global combat constants, contact/gap rules |
| `progression_tuning.gd` | XP curve, depth scaling, milestones |
| `effects_tuning.gd` | Damage numbers, particles, screen effects |

Balance data lives in these resources, not in `gameplay.gd`. See
`GAMEPLAY_TUNING.md` for the full export index and the remaining hardcoded
magic-number gap list.

## Input

All binds live in the **Input Map** (Project Settings > Input Map), defined in
`project.godot` under `[input]`. `player_controller.gd` and the coordinator's
`_is_*_input_pressed` helpers poll named actions; the trigger-axis check for
target/guard stays in `player_controller.gd` because axes are not map entries.
Remap freely in the editor without touching code. `InputRouter` is the only
per-frame snapshot boundary: desktop actions are read from the Input Map and
the optional `touch_controls_layer` provider is merged there. The
`input_device_tracker` owns last-device classification and prompt labels; it
ignores emulated mouse echoes and sub-threshold gamepad drift.

The display controller applies the active logical view size (adaptive `FULL`
at a live width×160, or fixed 240×160, 256×160, and 284×160 presets) and emits
`view_size_changed`; layout consumers use `display_layout.gd` so wide modes add
horizontal space without changing the native world coordinates. Normal-room
centering is camera-owned, so aspect changes never translate Map/Actors or
their collision data. `settings_service.gd` stores display/audio preferences
in device-wide `user://settings.cfg`, separate from slot profile data.

Menu intent is owned by `InputRouter`: Circle/Xbox B confirms and Cross/Xbox A
backs out, while only the visible full-screen route is polled. Touch menu taps
are scoped to that route and gameplay touch controls are disabled while a menu
is active.

## Extension guide

### Add a player capability (e.g. a new action)

1. Add the bind in the Input Map and route it through the existing input boundary.
   Until the contextual input slice is complete, follow the established helper path
   and do not add a new direct `Input` polling site.
2. Own the new state in a new component (`player_*_component.gd`) attached by
   `gameplay_bootstrap.gd`; do **not** add fields to `gameplay_state.gd` unless
   two systems genuinely share them.
3. Wire the capability into the frame loop from `gameplay_frame_controller.gd`
   or the component's own `tick`.
4. Add a smoke assertion to `tests/` and run `tests/run_all_smoke.ps1`.

### Add an enemy variant

1. Add variant data to `slime_tuning.gd` (or a new `*_tuning.gd`) and an
   archetype entry in the runtime spawn table inside `gameplay.gd`.
2. Reuse the `slime_*` components; extend `enemy_tactics_component` only for
   genuinely new tactical state. Encounter rules stay in the coordinator.
3. See `docs/rogue_slime_ambush.md` and `docs/speed_stat_design.md` for the
   two most recent variant additions as worked examples.

### Add a room interaction

1. Model the new interaction as a `Node` with an `interaction_component`
   pattern: build the prompt, expose a `_can_interact_*` helper on the
   coordinator, and resolve the effect (chest/gold/npc/rest-fire are the
   existing examples).
2. Add the object to `main.tscn` under `Actors/` and register it in
   `occluder_sprites`/`collision_sprites` from `gameplay_bootstrap.gd` if it
   blocks or occludes.

### Add a HUD presenter

1. Extend `hud_controller.gd` (or add a `*_presenter` node under the HUD) and
   drive it from a `_update_*_ui` helper in the coordinator.
2. Build pixel text through `effects_spawner.number_texture`/`name_texture`
   (cached by text+color) rather than new per-frame texture code.
3. Keep bar/value updates on the existing `set_health_bar_values`/
   `set_fill_ratio` path so damage-hold animation stays consistent.

## Rules of the road

- **New feature wiring goes in a component or controller.** `gameplay.gd` only
  gains orchestrator calls, not new behavior blocks.
- **One owner per value.** State that belongs to a component lives in that
  component; `gameplay_state.gd` holds only genuinely shared run state.
- **Preserve explicit update order.** Controllers expose scheduled phase methods;
  they do not acquire independent `_process()` methods just to avoid wiring.
- **Prefer typed references and signals.** A string-created `Callable` remains a
  transitional seam, not the target architecture.
- **Balance through tuning resources**, not literals in `gameplay.gd`.
- **Run the smoke suite before every commit**:
  `pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1`
- **Keep source art out of the import path.** Loose images in `Artwork/`,
  `Mockups/`, and `screenshots/` are `.gdignore`-marked; only `assets/` is
  imported.
