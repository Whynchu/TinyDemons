# Tiny Demons Feature Map

Status: current baseline map; composition refactor complete, remaining root-access owners listed

Updated: 2026-09-22

This is a human-maintained ownership map. It records the first place to look,
not a claim that every feature is fully isolated. The composition refactor is
complete (strict scorecard at 100%); the remaining dynamic root-access owners
are `screen_state_controller.gd`, `combat_runtime_controller.gd`, and
`slime_runtime_controller.gd`. Content ownership and the current data traps are
in [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md); the active authoring
workstream is [`authoring-system-plan.md`](authoring-system-plan.md).

| Feature | Primary owner / first place to look | State or data authority | Presentation / runtime support | Existing verification | Initial risk |
|---|---|---|---|---|---|
| Boot and run loop | `gameplay_bootstrap.gd`, `gameplay.gd` | `gameplay_state.gd` | `scenes/main.tscn`, frame controller | title and boot smoke tests | High: coordinator remains broad |
| Frame ordering | `gameplay_frame_controller.gd` | frame schedule | runtime controllers | frame-time and composition tests | High: hidden reach-ins |
| Player movement | `player_controller.gd`, `actor_motor.gd` | player runtime state | player scene/components | locomotion, speed, target tests | Medium: input seams overlap |
| Player combat | `player_attack_component.gd`, `combat_runtime_controller.gd` | combat snapshot/calculator | hitbox and effects components | combat path and damage tests | High: coordinator seams remain |
| Actor geometry | `actor_geometry.gd`, `actor_collision_system.gd` | shared geometry source | occlusion/effects/debug guides | geometry and wall tests | High: regression-sensitive |
| Slime enemies | `slime_brain.gd`, `slime_combat_component.gd`, `slime_actor.gd` | enemy runtime state and tuning | slime scenes/components | spawn, engagement, variant tests | Medium |
| Room progression | `room_controller.gd`, `room_transition_result.gd` | run/map state | room scenes and encounter content | room, doorway, and transition-result tests | High: authored/generated overlap |
| Dungeon topology | `dungeon_graph.gd`, `dungeon_map_controller.gd` | `dungeon_map_state.gd` | minimap, doors, room layers | map and door tests | High: multiple layout authorities |
| Generated layouts | `dungeon_layout_generator.gd`, `puzzle_route_generator.gd`, route plan/solver scripts | layout definitions and generated route metadata | generated preview scenes and minimap | generated layout, reachability, and R6+ risk/reward smoke tests | High: focused generation passes; runtime playtest and visual verification pending |
| Stone accents | `hub_stone_accent_layer.gd` | fixed Hub reference, seeded 3–5-piece subtraction, bounded non-Hub jitter, safe same-surface anchor swaps, reserved outer-right wall slot, fixed crack anchors, two-pixel wall solver buffer, connected-layout distinction, room-tint propagation, cached constraint checks, and live geometry validator | `scenes/main.tscn` `Map/HubStoneAccentLayer` and runtime accent assets | `hub_stone_accent_scene_smoke.gd` | Low: weighted variants, mirroring, and actor-distance rules deferred |
| Hub world authoring preview | `hub_world_preview.gd` | the authored Hub composition embedded in `main.tscn` | `scenes/hub_world_preview.tscn`, `tools/dev.ps1 preview hub` | `hub_world_preview_scene_smoke.gd` | Medium: design preview is landed; isolated interactive workbench deferred |
| Chroma and elements | `player_chroma_component.gd`, `element_catalog.gd` | chroma/profile state | pickups, spells, palette-driven fire effects (`gameplay.gd`, `effects_spawner.gd`) | chroma, binding, elemental, and fire-palette tests | Medium |
| Projectiles and magic | `magic_projectile_controller.gd`, `magic_runtime_controller.gd` | combat/runtime state | projectile scenes and effects | imbue and projectile-related tests | High: documented coordinator seams |
| Progression and settlement | `progression_controller.gd`, `run_settlement.gd` when extracted | `player_profile.gd` and run state | hub and reward UI | progression, grade, economy tests | High: state boundary needs tracing |
| Gear and fusion | `item_catalog.gd` (authored data in `resources/definitions/item_catalog.tres`), `item_instance.gd`, `equipment_component.gd` | profile item instances and equipped IDs | equipment/fusion/bind menus | gear, fusion, equipment tests | Medium: legacy compatibility paths |
| Hub and menus | `screen_state_controller.gd` | profile/menu state | menu scenes and layout scripts | menu, hub, touch-menu tests | High: large mixed owner |
| HUD | `player_hud.gd`, `hud_controller.gd` | player/combat display data | `scenes/player_hud.tscn` | player HUD smoke test | Medium: focused scene contract passes; live layout evidence remains |
| Save and profile | `profile_save_service.gd`, `active_run_save_service.gd` | profile and active-run snapshots | cloud panel and recovery UI | save/cloud/recovery tests | Critical: data integrity |
| Settings and display | `settings_service.gd`, `display_controller.gd`, `display_layout.gd` | device-wide settings | title/pause settings panels | settings and responsive tests | Medium |
| Input and touch | `input_router.gd`, `input_device_tracker.gd`, `touch_controls_layer.gd` | per-frame input snapshot | prompts and touch layer | input/device/touch tests | Medium |
| Audio | `sound_manager.gd`, `settings_service.gd` | persisted mix settings | audio assets and buses | sound mix/balance tests | Medium |
| Web export | `export_presets.cfg`, web save/input services | browser save boundary | generated `dist/` output | web export smoke test | High: separate target contract |

## Cross-Cutting Seams To Trace

These are not automatically defects, but they are the first places where the
vertical-slice analysis should look for duplicated ownership:

- `gameplay.gd` and `gameplay_state.gd`;
- `gameplay_frame_controller.gd` string calls and state lookups;
- authored and generated dungeon layout builders;
- `screen_state_controller.gd` combined menu, hub, and persistence behavior;
- profile, active-run, and cloud-save boundaries;
- actor presentation, collision, targeting, and effect geometry;
- direct input polling versus `input_router.gd` snapshots; and
- preview/debug scenes versus production scenes.

## Map Maintenance Rules

- Update the owner before adding a new feature to a coordinator.
- Add a test reference when a feature gains a player-visible contract.
- Mark a feature's risk only after evidence is gathered.
- Record historical or compatibility owners rather than silently deleting them.
- Keep this map focused on ownership and navigation; put detailed findings in
  `vertical-slice-analysis.md` or `engineering-friction-audit.md`.

## Next Analysis Targets

1. Trace room entry, combat, and reward persistence from `main.tscn`.
2. Trace profile and active-run save/load boundaries.
3. Capture live/native-resolution HUD and responsive layout evidence.
