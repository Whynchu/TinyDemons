# Dynamic Dependency Audit

Status: current measured audit for the `0.2.x` baseline

Audit date: 2026-09-11

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

## Scope

This audit measures calls that cross feature boundaries through the root object
or dynamic reflection. It is intended to identify ownership and refactor
priorities, not to prescribe a mass conversion to typed APIs.

## Measured Baseline

Across tracked GDScript files:

| Expression family | Matches |
|---|---:|
| `root.get(...)` | 1,402 |
| `root.set(...)` | 289 |
| `root.call(...)` | 1,421 |
| Total measured root seam uses | 3,112 |

These are regex matches in the 141 GDScript files under `scripts/`, not unique
runtime executions. They include editor/runtime support code where applicable;
the highest-volume files are runtime controllers. Re-run the measurement after
each vertical migration rather than treating the total as a quality score.

## Highest-Volume Runtime Files

| File | Seam matches | Primary responsibility |
|---|---:|---|
| `screen_state_controller.gd` | 422 | menus, hub presentation, settings, save UI |
| `room_controller.gd` | 409 | room entry, state restoration, encounters, doors |
| `combat_runtime_controller.gd` | 221 | damage, stats, enemy scaling, combat feedback |
| `gameplay_frame_controller.gd` | 205 | explicit frame schedule and input routing |
| `slime_runtime_controller.gd` | 194 | slime movement, attacks, targeting, spawning |
| `magic_runtime_controller.gd` | 141 | magic/imbue state and projectile interactions |
| `player_animation_component.gd` | 124 | player animation and visual state |
| `actor_presentation_runtime_controller.gd` | 122 | depth, occlusion, presentation transforms |
| `hub_flow_controller.gd` | 108 | hub routes, gear, shop, fusion, stats |
| `player_attack_component.gd` | 103 | attack lifecycle and hit timing |
| `gameplay_bootstrap.gd` | 96 | runtime construction and dependency wiring |
| `room_puzzle_controller.gd` | 86 | puzzle state and room interaction |
| `chest_controller.gd` | 72 | chest state, interaction, reward callbacks |
| `run_flow_controller.gd` | 72 | run lifecycle, settlement, telemetry |

## Most Shared Dynamic Methods

The most frequently requested root methods are:

| Method | Calls | Likely owner | Interpretation |
|---|---:|---|---|
| `_play_sound` | 214 | `SoundManager` / audio boundary | Broad presentation dependency; good signal/command candidate |
| `_is_menu_direction_just_pressed` | 85 | `InputRouter` / menu input | Menu systems depend on root input wrappers |
| `_actor_foot` | 78 | `ActorGeometry` | Geometry is a shared contract; centralize rather than duplicate |
| `_is_menu_confirm_just_pressed` | 31 | `InputRouter` | Same menu-input seam |
| `_save_player_profile` | 21 | `ProfileSaveService` | Save ownership crosses gameplay/UI/room flows |
| `_pixel_text_texture` | 22 | text/presentation service | UI creation depends on root utility |
| `_is_slime_dead` | 20 | combat/slime runtime | Enemy lifecycle queried by many systems |
| `_slime_combat` | 27 | slime component owner | Component lookup is still root-mediated |
| `_is_slime_targetable` | 14 | targeting/slime runtime | Targeting contract is hidden behind root |
| `_shift_hub_item` | 14 | `HubFlowController` | Hub routing uses compatibility delegates |
| `_collision_rect` | 14 | `ActorGeometry` | Geometry consumers use a shared but reflective boundary |
| `_set_door_active` | 12 | room/map presentation | Door state crosses room, chest, and map behavior |
| `_load_texture_or_null` | 12 | resource/presentation loading | Dynamic asset loading is root-mediated |

## Classification By Risk

### High-value seams to migrate carefully

#### Persistence

Examples:

- `_save_player_profile`
- `_save_active_run_checkpoint`
- `_checkpoint_safe_run_state`
- `_save_current_room_state`
- `_restore_active_run_checkpoint`

Risk: partial state writes, duplicate rewards, or slot/recovery mismatch.

Recommendation: define a typed checkpoint command/result boundary before moving
implementation. Preserve ordering and idempotence tests first.

#### Geometry

Examples:

- `_actor_foot`
- `_collision_rect`
- `_collision_polygon_intersects_actor`
- `_can_actor_stand_at_current_position`
- `_depth_key`

Risk: collision, targeting, occlusion, and presentation disagree.

Recommendation: keep one geometry owner. Replace reflective calls with a typed
geometry interface only after characterization coverage is complete.

#### Room and puzzle state

Examples:

- `_apply_room_state`
- `_ensure_current_room_layout`
- `_sync_current_room_metadata`
- `_configure_room_sockets`
- `_set_door_active`
- `_set_entrance_open`

Risk: authored/generated layouts and room presentation diverge.

Recommendation: define a room transition result containing room identity,
layout, socket state, and completion state. Do not split puzzle logic during
active generator work.

#### Input/menu routing

Examples:

- `_is_menu_direction_just_pressed`
- `_is_menu_confirm_just_pressed`
- `_is_menu_back_just_pressed`
- `_is_touch_input_device`
- `_update_hub_input`

Risk: device-specific behavior and menu route regressions.

Recommendation: make `InputRouter` the only input snapshot boundary and let
menu owners consume typed intents rather than querying root wrappers.

### Broad but lower-priority presentation seams

Examples:

- `_play_sound`
- `_pixel_text_texture`
- `_update_player_health_ui`
- `_update_overworld_ui`
- `_update_depth_sorting`
- `_update_actor_occlusion`

These are numerous because presentation needs to react to many systems. They
should not all be converted into signals automatically. Prefer narrow commands
or owner methods where a concrete rename or lifecycle problem exists.

## Ownership Findings

1. `screen_state_controller.gd` is not merely a large UI file; it is a major
   dependency hub for input, profile state, hub routes, settings, and menus.
2. `room_controller.gd` is the second major hub and currently combines room
   content, transitions, encounter generation, respawns, sockets, and state
   restoration.
3. Combat and slime systems are more componentized than their seam counts imply,
   but they still use the root as an implicit service locator.
4. Audio is the most repeated single presentation dependency. It is a good
   candidate for a narrow typed command boundary, but not necessarily a signal
   bus.
5. Geometry has many consumers but should remain a shared source of truth,
   rather than being split by consumer.
6. Root seam volume is a navigation and coupling indicator, not a refactor
   target by itself.

## Recommended Refactor Candidates

Prioritized by safety and player impact:

1. Add a typed checkpoint command/result around profile and active-run saves.
2. Add a typed room-transition result after puzzle-generation work stabilizes.
3. Expose a typed actor-geometry interface while preserving one geometry owner.
4. Make menu intent consumption explicit through `InputRouter`.
5. Move reward calculation/granting behind a typed reward service boundary.
6. Reduce compatibility delegates only as each owner migration is verified.

## Do Not Do Yet

- Do not mechanically replace every `root.call`.
- Do not introduce an event bus or service locator to hide the same problem.
- Do not split `screen_state_controller.gd` by line count alone.
- Do not move room/puzzle methods while generator behavior is still being
  validated.
- Do not treat high seam counts as evidence of dead code.
