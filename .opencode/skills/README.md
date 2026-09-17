# Vendored skills (GodotPrompter subset)

A curated, trimmed subset of [GodotPrompter](https://github.com/jame581/GodotPrompter)
(MIT) vendored for this project. Selected to match the feature owners in
`docs/ARCHITECTURE.md` and `AGENTS.md`.

## Installed skills

| Skill | Owner / first place to look |
| --- | --- |
| `gdscript-patterns` | Any GDScript — static typing, await, lambdas, match, exports |
| `physics-system` | `actor_geometry.gd`, `actor_collision_system.gd` |
| `input-handling` | `input_device_tracker.gd`, `input_router.gd`, `touch_controls_layer.gd` |
| `save-load` | `player_profile.gd`, `profile_save_service.gd`, `cloud_save_service.gd` |
| `godot-code-review` | Code review checklist |
| `component-system` | `slime_combat_component.gd`, `player_chroma_component.gd` |
| `state-machine` | `slime_brain.gd`, `screen_state_controller.gd` |
| `procedural-generation` | `room_controller.gd`, `dungeon_graph.gd` |
| `math-essentials` | Game math recipes |
| `resource-pattern` | `settings_service.gd`, data-driven config |
| `godot-ui` | Hub/menu presentation (`screen_state_controller.gd`) |
| `responsive-ui` | `display_controller.gd`, `display_layout.gd` |
| `audio-system` | `sound_manager.gd` |

## Deliberately excluded

- `event-bus` — pushes a global EventBus autoload; this project prefers typed
  signals and the narrowest-feature-owner rule.
- `godot-testing` — pushes GUT/gdUnit4; this project uses
  `tests/run_all_smoke.ps1` and its own characterization tests.
- `godot-project-setup`, `scene-organization`, `dependency-injection` — generic
  scaffolding that conflicts with existing `docs/ARCHITECTURE.md` ownership.
- 3D, C#, multiplayer, addon-specific, XR, and mobile skills — out of scope.

## Upgrade notes

`Related skills:` cross-references were trimmed to this subset and C# notes were
removed from GDScript-only files. When updating from upstream, re-apply the same
trimming and re-run the reference check. The upstream validator
(`scripts/validate-skills.mjs`) validates the whole repo; a subset reference
check can be reproduced with the PowerShell snippet pattern used during vendoring.

## Authority

These skills are engine reference only. Where they conflict with
`AGENTS.md`, `docs/ARCHITECTURE.md`, or `docs/component-composition-design.md`,
the project documents win.