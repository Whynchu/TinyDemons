# Tiny Demons — Contributor Map

## Read first

1. `README.md` — project entry point and verification commands.
2. `docs/AUDIT.md` — current findings and phase status.
3. `docs/refactor-route.md` — accepted migration route.
4. `docs/ARCHITECTURE.md` — ownership and runtime boundaries.
5. `docs/GAMEPLAY_TUNING.md` — designer-facing balance index.
6. `docs/web-port-implementation-plan.md` — browser export, input, and Pages workflow.

## Verification

```powershell
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1
& "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --log-file ".godot_user/editor-scan.log" --editor --quit
```

The local Godot environment may report a root-certificate warning and may be
unable to save editor settings. Treat those as environment warnings unless the
process exits nonzero or a test reports failure.

## Ownership rules

| Feature | Owner / first place to look |
| --- | --- |
| Frame ordering | `gameplay_frame_controller.gd` |
| Player input and movement | `player_controller.gd`, `actor_motor.gd` |
| Actor geometry and combat bounds | `actor_geometry.gd`, then `actor_collision_system.gd` |
| Slime behavior and attack timing | `slime_brain.gd`, `slime_combat_component.gd`, `slime_actor.gd` |
| Chroma and elemental casting | `player_chroma_component.gd`, then the Chroma plan/docs |
| Projectile lifecycle | `magic_projectile_controller.gd` when extracted; currently coordinator seams |
| Room generation and milestones | `room_controller.gd`, `dungeon_graph.gd` |
| Progression and settlement | `progression_controller.gd` / `run_settlement.gd` when extracted |
| Hub and menu presentation | `screen_state_controller.gd` |
| Input device prompts | `input_device_tracker.gd`, `input_router.gd` |
| Touch controls | `touch_controls_layer.gd`, `input_router.gd` |
| Actor occlusion and visual effects | `occlusion_renderer.gd`, `effects_spawner.gd` |
| Persistent profile data | `player_profile.gd`, `profile_save_service.gd` |

## Extension rules

- Add behavior to the narrowest feature owner; do not enlarge `gameplay.gd` by
  default.
- Preserve the explicit frame schedule. Do not add `_process()` just to avoid
  wiring a controller into the scheduler.
- Prefer typed references, direct methods, and signals. Treat `root.call/get/set`
  as migration seams, not new architecture.
- Keep render transforms, collision geometry, targeting, attacks, and flashes on
  the shared actor geometry source.
- Add characterization coverage before moving behavior, then run the full smoke
  suite before recording a phase change in `docs/AUDIT.md`.
- Do not mix intentional gameplay balance changes into structural refactors.

## Where does a new feature go?

Start with the feature owner above. If behavior crosses three or more owners,
define a typed command/result or signal at the boundary before adding coordinator
logic. If no owner is obvious, update `docs/ARCHITECTURE.md` and `docs/AUDIT.md`
before implementing the feature.
