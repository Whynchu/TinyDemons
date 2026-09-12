# Production Boundary

Status: current baseline for `0.2.x`

Baseline date: 2026-09-11

Canonical baseline: version `0.2.00`, commit
`bfe55782f43ee40fe32b5bebd45de988e34579d8`. See [`AUDIT.md`](AUDIT.md) for
the measured codebase state and preservation contract.

## Project Boundary

The authoritative Godot project is:

```text
TinyDemons/
```

It contains `project.godot`, the runtime project directories, tests, addons,
and project documentation. Material in the parent `Tiny-Demons/` directory is
workspace material until it is proven to be required by the project.

The parent workspace currently includes screenshots, mockups, SFX research and
archives, analysis material, and a local Godot executable. These items are not
assumed to be shipping project dependencies.

## Runtime Entry Points

| Concern | Current source |
|---|---|
| Project configuration | `project.godot` |
| Main scene | `scenes/main.tscn` |
| Autoload | `addons/godot_mcp_toolkit/runtime/mcp_runtime_server.gd` |
| Editor plugin | `addons/godot_mcp_toolkit/plugin.cfg` |
| Web export | `export_presets.cfg`, preset `Web` |
| Smoke test runner | `tests/run_all_smoke.ps1` |
| Web smoke test | `tests/web_export_smoke.ps1` |

## Supported Targets

The project configuration identifies Godot 4.7 and the Mobile feature set.
The repository documents desktop as the primary target and supports a web
build with keyboard, gamepad, and touch input. The configured export preset is
Web and writes to `dist/index.html`; `dist/` is ignored by Git.

The exact release matrix still needs confirmation in a later phase.

## Tracked Project Areas

The main tracked runtime and development areas are:

- `assets/` - runtime and source assets;
- `scenes/` - authored and debug scenes;
- `scripts/` - runtime and tooling scripts;
- `shaders/` - rendering support;
- `tests/` - smoke and contract tests;
- `addons/` - Godot MCP tooling;
- `docs/` - architecture, design, audit, and implementation records.

The project also contains editor, analysis, and authoring material inside these
areas. It must be classified before removal or relocation.

## Ignored And Generated Material

The current `.gitignore` excludes:

- Godot `.godot/` and user directories;
- export artifacts such as `*.pck`, `*.zip`, `web/`, and `dist/`;
- platform junk;
- copyrighted reference audio under `assets/sounds/FFsounds/`;
- browser probe scratch files;
- Python caches and virtual environments;
- `node_modules/`;
- generated analysis and SFX analysis directories;
- generated UI audio; and
- local cloud configuration.

These are cleanup candidates only when they are confirmed to be generated or
local-only. Ignore rules do not by themselves prove that an existing file is
safe to delete.

## Baseline Worktree State

The worktree is not clean. Existing changes were present before this analysis
step and must not be reverted:

- R7 puzzle-generation documentation and scripts are modified;
- `tests/generated_layout_smoke.gd` is modified;
- new puzzle route scripts are untracked; and
- this analysis plan and boundary document are untracked additions.

All later analysis must distinguish pre-existing work from analysis changes.

## Baseline Verification

### Editor/import scan

Result: completed with warnings.

Warnings:

- duplicate UID between `scripts/puzzle_map_r5.gd` and `scripts/puzzle_map_r4.gd`;
- duplicate UID between `tests/r5_authored_layout_smoke.gd` and `tests/r4_authored_layout_smoke.gd`.

These are Phase 0 findings. Do not repair them as part of repository cleanup
until the R4/R5 worktree changes and intended ownership are understood.

### Focused smoke test

Command used:

```powershell
& "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --log-file ".godot_user\analysis-focused-smoke.log" -s res://tests/player_hud_scene_smoke.gd
```

Result: failed.

Reported failures:

- `AbilityIcons/TrianglePromptMagic` is authored in the player HUD scene.
- `AbilityIcons/TrianglePromptImbue` is authored in the player HUD scene.

This is a current verification failure, not yet classified as an analysis or
cleanup issue. The focused test and its scene contract should be investigated
after the production boundary is complete.

## Open Questions

- Is the Godot executable intentionally part of the workspace, or should it be
  installed outside the repository?
- Which screenshots and mockups are active design references?
- Which SFX archives are retained for provenance, and which can be archived?
- Are all debug and preview scenes intentionally shipped or only editor tools?
- What is the authoritative supported release matrix: desktop, web, and mobile?
- Are the R4/R5 duplicate UID warnings introduced by the current uncommitted
  puzzle-generation work?

## Phase 0 Exit Criteria

- [x] Project root identified.
- [x] Runtime entry points identified.
- [x] Export target identified.
- [x] Ignore and generated-material rules recorded.
- [x] Existing worktree changes recorded without modification.
- [x] Editor/import scan performed.
- [x] Focused verification attempted.
- [ ] Release matrix confirmed.
- [ ] Parent workspace material classified.
- [ ] First feature map started.
