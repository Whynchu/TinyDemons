# Agent skills

This project exposes two skill sources to OpenCode: a curated, trimmed subset of
[GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT) vendored here,
and the Godot MCP Toolkit's companion skills, discovered through the root
`opencode.json`. The GodotPrompter subset is selected to match the feature owners
in `docs/ARCHITECTURE.md` and `AGENTS.md`.

## GodotPrompter subset

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

## Deliberately excluded from the GodotPrompter subset

- `event-bus` — pushes a global EventBus autoload; this project prefers typed
  signals and the narrowest-feature-owner rule.
- `godot-testing` — pushes GUT/gdUnit4; this project uses
  `tests/run_all_smoke.ps1` and its own characterization tests.
- `godot-project-setup`, `scene-organization`, `dependency-injection` — generic
  scaffolding that conflicts with existing `docs/ARCHITECTURE.md` ownership.
- 3D, C#, multiplayer, addon-specific, XR, and mobile skills — out of scope.

## Godot MCP Toolkit companion skills

The project config adds
`addons/godot_mcp_toolkit/CompanionSkills/` as a skill search path, so the
toolkit's own files remain the source of truth rather than being copied into
this directory.

| Skill | Purpose |
| --- | --- |
| `godot-mcp-toolkit` | MCP tool selection, scene/script workflows, playtest verification, and efficient tool use |
| `mcp-extension-creator` | Authoring and validating project-specific MCP extension tools |

## Upgrade notes

`Related skills:` cross-references were trimmed to the GodotPrompter subset and
C# notes were removed from GDScript-only files. When updating from upstream,
re-apply the same trimming and re-run the reference check. The upstream
validator (`scripts/validate-skills.mjs`) validates the whole repo; a subset
reference check can be reproduced with the PowerShell snippet pattern used
during vendoring.

## Authority

The GodotPrompter skills are engine reference; the companion skills describe
the MCP Toolkit workflow and API. Where either conflicts with `AGENTS.md`,
`docs/ARCHITECTURE.md`, or `docs/component-composition-design.md`, the project
documents win.
