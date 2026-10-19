# Tiny Demons — Contributor Map

## Read first

1. `README.md` ? project overview; `docs/CONTRIBUTOR_README.md` for commands.
2. `docs/FEATURE_MAP.md` ? find the owner for the task, then inspect its source.
3. `docs/DOCUMENTATION_MAP.md` ? choose only the authority relevant to the task.

Do not read every plan before ordinary work. For composition changes, read
`docs/COMPOSITION_STATUS.md` and the contract in
`docs/component-composition-design.md`. For content changes, read
`docs/CONTENT_AUTHORING.md` and the trap register in
`docs/authoring-system-plan.md`. For verification, follow the rules below and
`docs/verification-surface-audit.md`; select checks from `tests/manifest.csv`.

`docs/ARCHITECTURE.md` describes runtime boundaries; `docs/SCRIPT_INDEX.md`
locates symbols. `docs/KNOWN_ISSUES.md` records open issues. Historical plans
are evidence, not standing instructions to resume a refactor.

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
| Enemy decision and family behavior | `slime_brain.gd` (`EnemyBrain`, historical resource path), `slime_brain_behavior_component.gd`, `skeleton_brain_behavior_component.gd`; [P3 behavior status](docs/composition-p3-family-brain-behavior.md) |
| Slime attack timing and actor hooks | `slime_combat_component.gd`, `slime_actor.gd` |
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

## graphify

Tiny Demons' local knowledge graph is at
`graphify-godot/.tools/tiny-demons-map/graph.json`; its full HTML and report are
in the same directory. The focused verification HTML is at
`graphify-godot/.tools/tiny-demons-map/verification/graph.html`.

Run Graphify through the repository wrapper so it uses the Godot fork's local
Python environment and this project's map:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/graphify.ps1 query "<question>" --budget 1500
powershell -NoProfile -ExecutionPolicy Bypass -File tools/graphify.ps1 path "<A>" "<B>"
powershell -NoProfile -ExecutionPolicy Bypass -File tools/graphify.ps1 explain "<concept>"
```

When the user invokes `/graphify`, read `.codex/skills/graphify/SKILL.md` and
apply its Tiny Demons configuration. The wrapper also works from other working
directories when invoked by its absolute path.

Rules:
- For codebase and ownership questions, first run a scoped graph query when
  the graph exists, then inspect the relevant source spans to verify the answer.
  Use path/explain for focused relationship and symbol questions.
- Consult `GRAPH_REPORT.md` for broad architecture review. If a wiki exists
  under the map directory, use it for broad navigation.
- The graph has partial GDScript/Godot support. Missing edges do not prove a
  method/property is unused. Check parser diagnostics, dynamic boundaries and
  current source before concluding that a dependency is absent.
- For questions about the graph's correctness or freshness, inspect source
  and fixtures directly. Also honor explicit user requests to skip the graph.
- If the local fork/environment/map is unavailable, state that briefly and
  use the ownership docs and source; do not install unrelated upstream tooling.
- Query the existing map during work and check current source for files changed
  since its build. Refresh once after a completed batch of code changes and
  verification, before handoff, using the wrapper with `update .`. Individual
  edits and ordinary questions use the existing map; explicit user requests
  for a fresh graph take precedence. Documentation/instruction-only changes
  do not require a refresh. Regenerate the main HTML/report when needed with
  `cluster-only . --no-label`. Keep maps and caches under the ignored fork.
- When changing Graphify itself, follow `graphify-godot/AGENTS.md` and also
  refresh the fork's own graph; this repository wrapper selects Tiny Demons.
- Codex's installed `hook-check` intentionally emits no guidance; this
  `AGENTS.md` section carries the persistent query-first instructions for
  Codex and other assistants that read this file.
