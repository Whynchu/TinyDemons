# Tiny Demons — Contributor README

Status: engineering and workflow entry point

This is the contributor-facing companion to the public [`README.md`](../README.md).
The public README describes the game; this document describes how to work on it.

## Read first

1. [`README.md`](../README.md) — the product entry point.
2. [`docs/DOCUMENTATION_MAP.md`](DOCUMENTATION_MAP.md) — document authority and lifecycle.
3. [`docs/AUDIT.md`](AUDIT.md) — measured source-backed state and the preservation contract.
4. [`docs/ROADMAP.md`](ROADMAP.md) — the active sequence.
5. [`docs/KNOWN_ISSUES.md`](KNOWN_ISSUES.md) — open behavior, verification, and infrastructure findings.
6. [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — ownership and runtime boundaries.
7. [`docs/CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) — adding content, and the traps in the current data path.
8. [`docs/GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) — the designer-facing balance index.
9. [`docs/SCRIPT_INDEX.md`](SCRIPT_INDEX.md) — generated script/class/function navigation.

`AGENTS.md` at the repository root is the condensed map for agents and new
contributors.

## Build clean contract

The 0.3.x cycle cleans up the existing architecture; from then on, work is
*built* clean rather than cleaned up later. These rules prevent new content from
reintroducing structural debt:

- **Content goes through typed definitions and factories.** A new enemy, item,
  room, or tuning value is a standalone resource plus a registry/factory entry —
  never a central special case or a new `GameplayState` field.
- **No new `root.call/get/set`.** Dynamic root access is a migration seam, not
  architecture. The count must trend down, never up. `tools/validate_composition.ps1`
  enforces the regression floor.
- **No new `_process()` that bypasses the frame schedule.** Behavior is wired
  into `gameplay_frame_controller.gd` or ticked by its owner. Do not add a
  callback just to avoid wiring a controller.
- **New menus use the extracted toolkit**, not `screen_state_controller.gd`.
  Preserve the explicit frame order and characterize each boundary before
  moving ownership.
- **Keep balance changes out of structural changes** unless the balance change
  is required to preserve behavior after an extraction.
- **Prefer composition over copy-paste.** Reuse through shared components,
  definitions, and helpers rather than duplicating a routine in a fourth file.

## Current engineering focus

0.3.x is an **architecture cleanup** cycle, not a feature cycle. The composition
refactor is complete under the strict scorecard, but the remaining targets are:

- the `screen_state_controller.gd` monolith (title, save-select, character
  creation, settings, pause, hub UI, name entry, particles);
- the `save_flow_controller` ↔ `screen_state_controller` title-flow cycle;
- the `hub_flow_controller` facade over `screen_state_controller`;
- 2,200 dynamic `root.call/get/set` sites, concentrated in `screen_state_controller`,
  `combat_runtime_controller`, `room_controller`, and `slime_runtime_controller`;
- dead and duplicated code (orphan editor guides, a no-op per-frame regen call,
  the duplicated pixel-glyph table, the unused `family_mastery` path);
- synchronous file I/O in frame paths and the boss-entry slow path.

The exit intent is that architecture stops being a roadmap topic: later work is
feature, content, and feel, built on clean ground.

## Project layout

- `project.godot` — the Godot project root (this folder is the project).
- `assets/` `scenes/` `scripts/` `shaders/` `tests/` — the Godot project.
- `Artwork/` — exported and source art (source, not imported by Godot).
- `Mockups/` `screenshots/` — reference mockups and captures.
- `docs/` — audit, plans, tuning, feature designs, and this guide.
- `docs/readme/` — README screenshots and gameplay clips.

## Running the project

Open `project.godot` in Godot 4.7 and run the main scene. The project is
configured for a small nearest-neighbor pixel-art presentation; keep texture
filtering and integer-like scaling intact when changing display settings.

### MCP-first safety rule

When a Godot editor peer is connected through the MCP toolkit, use MCP for
scene inspection, script diagnostics, playtests, screenshots, and runtime logs.
Do **not** run `tests/run_all_smoke.ps1` from that editor session. The default
release gate is currently 44 processes; `-TestGroup all` launches all 143
runnable paths in sequence, and a headless renderer crash can produce an
avalanche of Windows memory-error dialogs. MCP cannot run `tests/*.gd`; focused
in-editor verification means diagnostics, a scene probe, or a playtest.

Use the full runner only as an explicitly supervised, standalone step with no
MCP Godot runtime active. Start with one focused smoke test. If a standalone
Godot crash begins repeating, stop the runner and end only the
`Godot_v4.7.1-stable_win64_console` worker processes.

Set `GODOT_BIN` to a Godot 4.7.1 executable when the default development path is
not present. The wrappers also accept `-GodotBin` and resolve the project root
from the script location when `-ProjectRoot` is omitted.

## Verification

```powershell
# Composition guardrail self-test and regression floor.
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1 -SelfTest
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1

# Definition validator: fails on malformed authored resources. Part of
# release preflight and web CI.
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_definitions.ps1

# Catalog report: authored definition surfaces and stable IDs.
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/report_catalogs.ps1

# Curated release gate; includes the web export and main-scene checks.
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1

# Full runnable inventory — standalone/supervised only.
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1 -TestGroup all

# Fast manifest/path preflight — starts no Godot process.
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_test_manifest.ps1
```

The strict composition audit is
`tools/validate_composition.ps1 -RequireTargets`; it currently passes. The strict
audit and editor-composition percentage are proxy metrics, not authoring proof —
the acceptance bars in [`authoring-system-plan.md`](authoring-system-plan.md)
are the real gate.

The local Godot environment may report a root-certificate warning and may be
unable to save editor settings. Treat those as environment warnings unless the
process exits nonzero or a test reports failure.

### Focused authoring commands

```powershell
pwsh -File tools/dev.ps1 new variant example_guard
pwsh -File tools/dev.ps1 preview enemy example_guard
pwsh -File tools/dev.ps1 preview hub -Editor
pwsh -File tools/dev.ps1 new item example_blade
pwsh -File tools/dev.ps1 preview item example_blade
pwsh -File tools/dev.ps1 test -Suite content
pwsh -File tools/dev.ps1 verify
```

`new variant` creates a standalone Slime variant under `resources/definitions/`.
`new item` creates one under `resources/definitions/items/`. The registry,
validator, and content contracts discover these resources without a central
runtime or per-content test edit.

## Web build

Current game version: `0.3.17`. Every push to `main` increments the patch version
by at least `0.0.01`; update the in-game title-menu version and both READMEs in
the same commit.

The browser build publishes to
[GitHub Pages](https://whynchu.github.io/TinyDemons/) from `main`. Pull requests
run the Web export and upload a review artifact without publishing; only a
`main` push (or a manual workflow run on `main`) deploys. The workflow is
[`.github/workflows/web-pages.yml`](../.github/workflows/web-pages.yml). Set
Pages' publishing source to **GitHub Actions** once before the first deployment.

To validate the export locally after installing the matching Godot 4.7.1 Web
template:

```powershell
pwsh -ExecutionPolicy Bypass -File tests/web_export_smoke.ps1 -RequireExport
```

## Documentation

Authority and lifecycle are governed by
[`DOCUMENTATION_MAP.md`](DOCUMENTATION_MAP.md). Regenerate
[`SCRIPT_INDEX.md`](SCRIPT_INDEX.md) with `tools/generate_script_index.ps1` after
structural script changes.

## README assets

The public README references these files under `docs/readme/`. Capture
replacements at the game's native 240×160 logical resolution scaled by an integer
factor (3–4×), and keep clip loops short (6–14 s):

| File | Shows |
| --- | --- |
| `hero.gif` | A short loop: enter a room, fight, cast, collect. |
| `gameplay-beam.gif` | Charged attack releasing the sword beam. |
| `gameplay-spin.gif` | Spin attack clearing several slimes. |
| `gameplay-chroma.gif` | Flame swap / recolor and an elemental cast. |
| `gameplay-boss.gif` | Boss jump-slam and a dodge. |
| `screenshot-title.png` | Title screen. |
| `screenshot-hub.png` | Demon Hub, a command page open. |
| `screenshot-bound.png` | The Bind/element screen. |
| `screenshot-map.png` | Minimap or expanded dungeon map. |
