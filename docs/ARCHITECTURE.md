# Tiny Demons — Architecture

Status: current ownership and extension guide for the `0.2.x` baseline

Updated: 2026-09-22

Authority: [`AUDIT.md`](AUDIT.md) records measured findings; this document
defines the intended runtime boundaries and safe extension rules.

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

Encrypted-vault deployment and operational verification are documented in
[`cloud-save-deployment.md`](cloud-save-deployment.md).

## Scripts by responsibility

- **Player**: `player_controller`, `actor_motor`, `player_roll_component`,
  `player_attack_component`, `player_guard_component`,
  `player_animation_component`, `player_equipment_visual_component`,
  `player_hud`.
- **Enemies**: `slime_actor`, `slime_brain`, `slime_combat_component`,
  `slime_animation_component`, `slime_visual_component`,
  `slime_health_presenter`, `slime_ambush_component`,
  `enemy_tactics_component`. The shared Normal and eight-element boss behavior,
  presentation, performance, and verification contract is defined in
  [`boss-slime-implementation-plan.md`](boss-slime-implementation-plan.md).
- **World**: `room_controller`, `room_transition_result`, `dungeon_graph`, `dungeon_socket`,
  `isometric_room_layer`, `walkable_area`, `actor_collision_system`,
  `depth_sorter`, `shadow_controller`, `occlusion_renderer`.
- **Interaction**: `interaction_component`, `chest_controller`,
  `npc_controller`, `rest_fire_controller`, `attack_hitbox_guide`.
- **Meta/progression**: `player_profile`, `profile_save_service`,
  `run_state`, `run_grade`, `run_settlement`, `item_catalog`,
  `item_instance`, `equipment_component`, `equipment_transmutation_component`,
  `stats_component`, `combat_stat_snapshot`, `combat_calculator`.
- **Save durability**: `profile_save_service` owns validated permanent slot
  serialization; `active_run_snapshot` owns the JSON-safe in-progress boundary;
  `active_run_save_service` owns slot-scoped atomic/localStorage checkpoints;
  `web_run_diagnostics` owns the bounded browser lifecycle ring;
  `web_save_crypto` owns browser HKDF/AES-GCM operations; `cloud_save_service`
  owns recovery-vault transport; and `cloud_save_panel` owns the title-screen
  recovery workflow. Supabase receives ciphertext, never profile JSON.
- **Presentation**: `hud_controller`, `effects_spawner`,
  `screen_state_controller`, `dungeon_minimap_controller`,
  `sprite_frame_library`, `display_controller`, `display_layout`,
  `hub_stone_accent_layer`.
- **Editor preview**: `hub_world_preview.gd` owns the design-time Hub view in
  `scenes/hub_world_preview.tscn`; it reuses the authored `main.tscn`
  composition without booting profile, run, input, or save services.
  `authoring_placement_catalog.gd` is the editor-neutral placement discovery
  and lifecycle contract, and `addons/tiny_demons_authoring/` owns the small
  navigator/action dock that selects and edits those roots in the native editor.
- **Palette presentation**: `actor_palette_material` owns the shared GPU
  palette-swap materials (`shaders/palette_swap.gdshader`), one per palette.
  `player_animation_component` serves raw fullsheet source frames plus the baked
  grey MP-reference set instead of a texture per palette, and
  `shaders/mp_desaturation.gdshader` carries the swap alongside MP desaturation.
  `player_equipment_visual_component` builds palettes lazily (`ensure_palette`).
  `slime_visual_component` likewise shares the authored green source frames and
  applies one cached GPU palette material to the slime body and floor shadow.
- **Settings/audio**: `settings_service` owns device-wide persisted options;
  `sound_manager` consumes the live music/SFX values and applies their dB
  offsets to the Master bus.
- **Web/input**: `input_device_tracker` (last deliberate device and prompt
  labels), `touch_controls_layer` (virtual stick and touch buttons), and
  `input_router` (the single merged input snapshot).
- **Infra**: `gameplay` (coordinator), `gameplay_state` (state),
  `gameplay_bootstrap`, `gameplay_frame_controller`,
  `editor_collision_guide`, `editor_polygon_guide`, `ui_layout_guide`.

Equipment content authority is documented in
[`gear-catalogue-spec.md`](gear-catalogue-spec.md). `item_catalog` owns stable
authored definitions and generation; `player_profile` owns persistent item
instances and equipped IDs; `equipment_component` produces the runtime
snapshot; and combat/effect owners consume that snapshot. New slot, drop, or
passive behavior must not be implemented as an item-name branch in
`gameplay.gd`.

Dungeon topology and difficulty authority are documented in
[`procedural-dungeon-design.md`](procedural-dungeon-design.md) and
[`run1-dungeon-map-design.md`](run1-dungeon-map-design.md). `dungeon_graph`
owns the in-memory topology and socket pairing; `dungeon_layout_definition`
plus the run/generated layout builders own the authored and procedural room
sets; `dungeon_map_controller` owns gates, engagement, and shared orb/fire
state and visited flame landmarks; `room_controller` owns per-room content and
enemy encounter generation. The active route keeps authored R1–R5 and selects
the deterministic generated layout path from R6 onward. Generated R6+ layouts
carry typed route role, encounter tier, reward tier, vault identity, and
safe/risk choice metadata from layout definition through graph, room state, and
minimap projection. Generated difficulty is flat per run and keyed off
`difficulty_rank`, not room depth; local encounter tiers are the explicit
exception for dangerous shortcuts and elemental vaults.

Room traversal uses `RoomTransitionResult` as the typed handoff between route
selection and runtime entry. `RoomController.plan_connected_room_transition`
validates graph/source/destination identity and carries departure, arrival, and
destination room type. `RoomController.enter_connected_room` owns the side
effects and preserves the explicit frame schedule. New room-entry behavior
should extend this result or add a focused result beside it rather than adding
another loose destination/arrival argument to the coordinator.

## Tuning classes and default resources

The tuning classes expose typed exported fields and have inspector-facing
defaults under `resources/tuning/`. `GameplayState` loads and deep-duplicates
one default resource per runtime, so a test, debug scene, or future designer
override cannot mutate the cached default used by another runtime.

| Resource | Focus |
| --- | --- |
| `resources/tuning/player_default.tres` / `player_tuning.gd` | Movement, attack frames/combos, stats |
| `resources/tuning/slime_default.tres` / `slime_tuning.gd` | Enemy health, speed, aggro, attack ranges |
| `resources/tuning/combat_default.tres` / `combat_tuning.gd` | Global combat constants, contact/gap rules |
| `resources/tuning/progression_default.tres` / `progression_tuning.gd` | XP curve, depth scaling, milestones |
| `resources/tuning/effects_default.tres` / `effects_tuning.gd` | Damage numbers, particles, screen effects |
| `resources/tuning/chroma_default.tres` / `chroma_tuning.gd` | Chroma pickup and elemental resource values |

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
is active. During gameplay, the dedicated `open_minimap` action opens the
expanded flame map; its Share/Options, keyboard, and touch bindings all enter
through the same router boundary.

## Extension guide

For content data (enemies, items, elements, rooms, maps), start from
[`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) and the trap register in
[`authoring-system-plan.md`](authoring-system-plan.md); several authored
resources are not yet authoritative at runtime.

### Add a player capability (e.g. a new action)

1. Add the bind in the Input Map and route it through the existing input boundary.
   Until the contextual input slice is complete, follow the established helper path
   and do not add a new direct `Input` polling site.
2. Own the new state in a new component (`player_*_component.gd`) attached by
   `gameplay_bootstrap.gd`; do **not** add fields to `gameplay_state.gd` unless
   two systems genuinely share them.
3. Wire the capability into the frame loop from `gameplay_frame_controller.gd`
   or the component's own `tick`.
4. Add a smoke assertion to `tests/` and verify it through MCP when a Godot
   editor peer is active; reserve `tests/run_all_smoke.ps1` for the supervised
   standalone gate described below.

### Add an enemy variant

Current path (the enemy portion of Slice 1 is now typed and factory-backed):

1. Add a typed `EnemyDefinition` sub-resource to the `definitions` array in
   `resources/definitions/slime_variant_catalog.tres`, including explicit
   visual and encounter metadata.
2. Reuse the `slime_*` components; extend `enemy_tactics_component` only for
   genuinely new tactical state. `EnemyFactory` materializes the actor and the
   runtime pool configures selected slots from the definition.
3. Run the definition validator, catalog report, registry-driven variant
   smoke, factory contract smoke, and normal-room entrance smoke.
4. A genuinely new palette or behavior still belongs to its narrow owner, but
   an existing palette/source is data-only. Do not add a central roster list,
   `RoomController` encounter constant, or scene-authored enemy slot.
5. See `docs/rogue_slime_ambush.md` and `docs/speed_stat_design.md` for earlier
   variant additions as worked examples.

Do not add a new enemy as a special case in `gameplay.gd` or
`gameplay_state.gd`. Read the trap table in `docs/CONTENT_AUTHORING.md` before
editing catalog data.

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
- **Use MCP-first verification when the Godot editor peer is active.** Use MCP
  for scene inspection, diagnostics, playtests, screenshots, and runtime logs;
  do not launch the standalone smoke runner from that session.
- **Run the full smoke suite only as a supervised standalone check** (with no
  MCP Godot runtime active):
  `pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1`
  The default command runs the curated 44-path release gate, including web
  export and main-scene checks. Use `-TestGroup all` to run the complete 132-
  path runnable inventory. Grouping comes from `tests/manifest.csv`, which
  records each script's role, state, owner, target, and load kind. A headless
  renderer crash can multiply into Windows memory-error dialogs. Start with one
  focused test and stop the runner at the first repeating crash.
- **Keep source art out of the import path.** Loose images in `Artwork/`,
  `Mockups/`, and `screenshots/` are `.gdignore`-marked; only `assets/` is
  imported.
