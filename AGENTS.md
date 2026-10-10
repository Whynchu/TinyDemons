# Tiny Demons — Contributor Map

## Read first

1. `README.md` — project entry point and verification commands.
2. `docs/authoring-system-plan.md` — active plan for making content and feature
   work cheap: typed definitions, single-source registries, factories,
   previews, verification, and docs. Read its trap register before touching
   content data.
3. `docs/AUDIT.md` — current findings and phase status.
4. `docs/DOCUMENTATION_MAP.md` — authority and document lifecycle guide.
5. `docs/wiki/README.md` — concise design wiki and topic navigation.
6. `docs/ROADMAP.md` — active product and infrastructure sequence.
7. `docs/KNOWN_ISSUES.md` — open behavior, verification, and infrastructure findings.
8. `docs/verification-surface-audit.md` — test/report roles, release-gate scope, and test-debt cleanup.
9. `docs/CONTENT_AUTHORING.md` — current content workflows and boundaries. It
   documents the runtime as it is, including the data paths that currently do
   nothing; the authoring plan is the target it moves toward.
10. `docs/refactor-route.md` — accepted migration route.
11. `docs/composition-refactor-analysis.md` — component/composition measurements and handoff sequence.
12. `docs/component-composition-design.md` — approved component contract, wiring rules, and interchangeable-entity proof sequence.
13. `docs/long-term-composition-and-performance-plan.md` — long-term content composition, authoring, and performance direction.
14. `docs/ARCHITECTURE.md` — ownership and runtime boundaries.
15. `docs/GAMEPLAY_TUNING.md` — designer-facing balance index.
16. `docs/web-port-implementation-plan.md` — browser export, input, and Pages workflow.
17. `docs/SCRIPT_INDEX.md` — generated script, class, signal, export, and function navigation.
18. `docs/agent-workflow.md` — project-scoped Pip, Thorn, and Hexley advisory roles and usage.
## Coordination with other agents

More than one AI agent may work this repo at the same time (opencode and codex
share the one Godot editor through separate MCP bridges). The Godot toolkit's
mutation lock and scene lease prevent write races but carry no identity or
messages, so use the file-based board in `coord/`:

- **At task start:** read `coord/BOARD.md` and both `coord/status-*.md` files.
- **Before editing:** add your claim row to `coord/BOARD.md` (agent, paths or
  scenes, one-line intent). Remove it when the work lands.
- **While working:** keep your own `coord/status-<you>.md` current (focus, in
  flight, blockers, handoff). Write only your own file.
- **Log events:** append `claim` / `handoff` / `blocker` / `done` lines to
  `coord/journal.md`.
- **Commit the board with the code** at task boundaries.

Protocol and formats: `coord/README.md`. Keep one Godot editor; never open this
project directory in a second editor (`addons/godot_mcp_toolkit/docs/multi-instance.md`).

For scene and content navigation, see `docs/CONTENT_FOLDERS.md`; it describes
the role-based scene folders and distinguishes the source-art archive from
Godot-imported runtime assets and authored resources.

## Verification

### MCP-first safety rule

When a Godot editor peer is connected through the MCP toolkit, use MCP for
scene inspection, script diagnostics, playtests, screenshots, and runtime logs.
Do **not** run `tests/run_all_smoke.ps1` from that editor session. That script
defaults to the curated release gate (currently 45 manifest-selected paths);
the explicit `-TestGroup all` inventory launches all 155 runnable paths
sequentially. A headless renderer crash can therefore produce an avalanche of Windows
memory-error dialogs. MCP cannot run `tests/*.gd`; focused in-editor
verification means script diagnostics, a scene probe, or a playtest, not a
suite run.

Use the full runner only as an explicitly supervised, standalone verification
step when no MCP Godot editor/runtime is active. Prefer one focused smoke test
first. If a standalone Godot crash begins repeating, stop the runner and end
only the `Godot_v4.7.1-stable_win64_console` worker processes; leave the main
editor process running unless it is also failing.

Set `GODOT_BIN` to a Godot 4.7.1 executable when the default development path
is not present; the smoke runner, web export, and focused tools honor it. The
PowerShell wrappers also accept an explicit `-GodotBin` and resolve the project
root from the script location when `-ProjectRoot` is omitted.

```powershell
# Composition guardrail implementation self-test and regression floor.
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1 -SelfTest
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1
# Definition validator: discovers every authored definition resource and fails
# on malformed content. It is part of the release preflight and web CI.
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_definitions.ps1
# Catalog report: prints authored definition surfaces and stable IDs; exits
# nonzero when a required surface cannot load.
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/report_catalogs.ps1
# Curated release gate; includes the web export and main-scene checks.
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1
# Full runnable inventory — standalone/supervised only.
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1 -TestGroup all
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/run_headless.ps1 -Editor
```

The strict composition audit is
`pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1 -RequireTargets`.
It currently **passes**: the recorded baseline meets every strict target. The
strict audit and the editor-composition percentage are proxy metrics, not
authoring proof; the acceptance bars in the authoring plan are the real gate.

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
| Chroma and elemental casting | `player_chroma_component.gd`, then `player_aspect_ability_component.gd` and `magic_runtime_controller.gd` |
| Projectile lifecycle | `magic_projectile_controller.gd`, driven by `magic_runtime_controller.gd` |
| Room generation and milestones | `room_controller.gd`, `dungeon_graph.gd`, `dungeon_map_controller.gd`, `room_transition_result.gd` |
| Progression and settlement | `progression_controller.gd`, `run_settlement.gd`, `run_flow_controller.gd` |
| Hub and menu presentation | `screen_state_controller.gd` |
| Stone accent presentation | `hub_stone_accent_layer.gd`, `docs/stone-accent-procedural-placement-plan.md` |
| Display settings and responsive layout | `display_controller.gd`, `display_layout.gd`, `settings_service.gd`, `screen_state_controller.gd` |
| Audio mix settings | `sound_manager.gd`, `settings_service.gd` |
| Input device prompts | `input_device_tracker.gd`, `input_router.gd` |
| Touch controls | `touch_controls_layer.gd`, `input_router.gd` |
| Actor occlusion and visual effects | `occlusion_renderer.gd`, `effects_spawner.gd` |
| Persistent profile data | `player_profile.gd`, `profile_save_service.gd` |
| Encrypted cloud saves | `cloud_save_service.gd`, `web_save_crypto.gd`, `cloud_save_panel.gd` |
| Content definitions and authoring pipeline | `docs/authoring-system-plan.md`, then the owning catalog/definition script named in `docs/CONTENT_AUTHORING.md` |

## Extension rules

- Add behavior to the narrowest feature owner; do not enlarge `gameplay.gd` by
  default.
- Preserve the explicit frame schedule. Do not add `_process()` just to avoid
  wiring a controller into the scheduler.
- Prefer typed references, direct methods, and signals. Treat `root.call/get/set`
  as migration seams, not new architecture.
- Keep render transforms, collision geometry, targeting, attacks, and flashes on
  the shared actor geometry source.
- Add characterization coverage before moving behavior, then run the focused
  check and the curated gate before recording a phase change in `docs/AUDIT.md`.
- Do not mix intentional gameplay balance changes into structural refactors.
- For content work, start from `docs/CONTENT_AUTHORING.md` and the trap register
  in `docs/authoring-system-plan.md`. Until a slice lands, assume the authored
  resource is not authoritative unless the runtime consumer is named: several
  `.tres` fields are currently ignored in favor of duplicated code constants.

## Where does a new feature go?

Start with the feature owner above. If behavior crosses three or more owners,
define a typed command/result or signal at the boundary before adding coordinator
logic. If no owner is obvious, update `docs/ARCHITECTURE.md` and `docs/AUDIT.md`
before implementing the feature.
