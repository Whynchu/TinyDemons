# TinyDemons

![TinyDemons first gameplay room](docs/game-screenshot.png)

TinyDemons is a compact pixel-art isometric action game built in Godot. Explore dungeon rooms, fight colorful slime enemies, manage your health, and meet the cloaked guide beside the rest fire at the start of each run.

Current gameplay includes:

- Directional attacks with multi-target damage sharing and readable hit feedback.
- Short roll movement with animation timing and collision-safe movement.
- Slime enemies with wandering, targeting, and persistent combat aggro.
- Player, target, and enemy overhead health bars with damage-transition highlights.
- Perspective-aware collision, attack guides, knockback, and brief hitstop.
- Pixel-based attack, slime splat, chest, and title-screen fizzle effects.
- Room progression, chest rewards, gold tracking, and restart flow.
- Elemental Chroma casting, Soul pickups, elemental binding, and flame fusion.
- Six-stat progression, six-slot equipment, rarity effects, and gear drops.
- An authored player HUD with radial ability cooldowns and device-aware prompts.
- Responsive desktop/browser presentation with touch controls and gamepad input.

## Current Focus

The active gameplay work is the **Elemental Chroma system**: starter-flame
attunement, Gray/elemental state, Chroma pickups and casting, and mandatory
elemental puzzle rooms. In parallel, the codebase is entering a staged
feature-oriented refactor so these systems have typed owners instead of
continuing to grow inside the gameplay coordinator.

The next combat design slice is documented in
[`docs/elemental-slimes-and-combat-plan.md`](docs/elemental-slimes-and-combat-plan.md):
elemental slime variants, the custom scaled Gen-III matchup table, and
element-colored damage feedback.

The **web port** (browser build with touch controls, gamepad peripherals, and
last-input-device auto-detection) is implemented and tracked in
[`docs/web-port-implementation-plan.md`](docs/web-port-implementation-plan.md);
desktop remains the primary target and both share this codebase.

The **modular display and settings** slice (adaptive `FULL` landscape mode plus
3:2/16:10/16:9 presets, with the void and decorative bars expanding to fit,
title/pause settings panel with fullscreen and volume sliders, pause
quit-to-title) is implemented and tracked in
[`docs/modular-display-and-settings-plan.md`](docs/modular-display-and-settings-plan.md).

The current combat slice adds the scene-authored Spin Attack and held-button
charge attack; its editor hitbox workflow and tuning contract are tracked in
[`docs/spin-and-charge-attacks-plan.md`](docs/spin-and-charge-attacks-plan.md).

The implemented progression/UI redesign is documented in
[`docs/ffiii-inspired-stats-and-menu-implementation-plan.md`](docs/ffiii-inspired-stats-and-menu-implementation-plan.md):
six manually allocated attributes (STR/AGI/VIT/INT/MND/DEF), typed physical and
magic combat paths, INT-driven Imbue strength, save migration, and
FFIII-inspired menu layouts using Tiny Demons' own visual language.

The staged menu visual migration starts with the scene-authored pause screen;
its 240x160 geometry, fixed command rail, responsive anchors, and migration
order are tracked in
[`docs/menu-ui-migration-plan.md`](docs/menu-ui-migration-plan.md).

The next progression content slice is the approved six-slot equipment
catalogue. Its documentation-first boundary is in
[`docs/gear-catalogue-spec.md`](docs/gear-catalogue-spec.md), with the authored
44-base list, effect contracts, drop rules, and implementation sequence in the
linked companion documents. Head and Arm are approved additions; future weapon
families remain documented extension points until their combat contracts exist.

Start with [`docs/DOCUMENTATION_MAP.md`](docs/DOCUMENTATION_MAP.md) for the
documentation authority, then [`docs/AUDIT.md`](docs/AUDIT.md) for current
findings and [`docs/ROADMAP.md`](docs/ROADMAP.md) for the active sequence.
Use [`docs/SCRIPT_INDEX.md`](docs/SCRIPT_INDEX.md) to jump directly to a
runtime script or function declaration; refresh it with
`tools/generate_script_index.ps1` after structural script changes.
Use [`docs/CONTENT_AUTHORING.md`](docs/CONTENT_AUTHORING.md) when adding game
content and [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md) for open verification
gaps. The accepted refactor route is in
[`docs/refactor-route.md`](docs/refactor-route.md). The completed Combat & Economy work remains documented in
[`docs/combat-economy-overhaul.md`](docs/combat-economy-overhaul.md).

### Current refactor focus

The current engineering goal is to make the runtime genuinely compositional:
components should own focused state and behavior, controllers should coordinate
feature boundaries, and `GameplayState` should remain the composition root
instead of becoming a shared service locator. The detailed handoff is in
[`docs/composition-refactor-analysis.md`](docs/composition-refactor-analysis.md).

The latest source scan (working tree on 2026-09-15; `d6a965d` remains the
pinned comparison baseline) gives us this shape:

| Surface | Current measurement | What it tells us |
|---|---:|---|
| Runtime scripts | 166 | The project already has a substantial feature vocabulary |
| Explicit `*Component` classes | 20 | Player, slime, Chroma, equipment, health, and interaction composition is established |
| Runtime physical lines | 48,534 | Refactor by ownership, not by indiscriminate file splitting |
| Runtime non-blank lines | 42,900 | Blank lines are excluded; comments remain counted |
| `gameplay.gd` | 233 lines | The old giant coordinator has already been reduced |
| `gameplay_state.gd` | 1,777 lines / 510 functions / 299 fields | The remaining composition-root and compatibility surface is the main debt |
| `root.call/get/set` | 3,135 sites | Dependencies are still hidden across controllers and components |

Completed refactor foundations include the explicit frame scheduler, runtime
bootstrap wiring, player and slime components, typed reward and settlement
boundaries, typed room transition/activation/clear results, typed enemy-runtime
capture, typed room-level initial spawn orchestration, typed per-frame
respawn coordination, typed room spawn/death helpers, typed room-owned combat
death consequences, external default tuning resources, and typed pause/Hub
player presentation contexts. Those result contracts and data snapshots are a
useful foundation, but they do not prove that ownership has moved out of the
state bag. Under the strict ownership scorecard in
[`docs/composition-refactor-analysis.md`](docs/composition-refactor-analysis.md),
the composition refactor is approximately **25% complete / 75% remaining**.
The one completed hard gate is a genuine direct typed context; root-access
reduction, state-bag shrinkage, and room-owner shrinkage are not complete.

The practical sequence is:

1. Stop adding `GameplayState`-backed contexts; classify the existing room
   adapters as transitional seams.
2. Rework room entry, activation, spawn, and respawn through direct typed
   slices that lower root access and keep `RoomController` below its baseline.
3. Move state out of `GameplayState` only when its owner and direct consumers
   are established, then retire the parallel compatibility implementation.
4. Characterize browser/device file-write ordering and the hosted Pages
   artifact after the runtime ownership work is genuinely complete.

Line counts and dynamic-call counts are navigation evidence, not quality scores.
Do not split files or remove `GameplayState` wholesale; preserve the explicit
frame order and characterize each vertical slice before changing its ownership.

Current playtest issues and their resolution order are tracked in
[`docs/current-issues-and-resolution-plan.md`](docs/current-issues-and-resolution-plan.md).

## Project Layout

- `project.godot` - the Godot project root (this folder is the project)
- `assets/` `scenes/` `scripts/` `shaders/` `tests/` - the Godot project
- `Artwork/` - exported and source art files (source, not imported by Godot)
- `Mockups/` - reference mockups
- `screenshots/` - game screenshots
- `docs/` - audit, plans, tuning index, feature designs, and smoke checklist
- `docs/SCRIPT_INDEX.md` - generated script/class/function navigation index
- `docs/game-screenshot.png` - first-room gameplay screenshot used in this README

## Running The Project

Open `project.godot` in Godot 4.7 and run the main scene. The project is configured for a small nearest-neighbor pixel-art presentation, so keep texture filtering and integer-like scaling intact when changing the display settings.

When the Godot MCP editor peer is active, perform verification through MCP:
scene inspection, script diagnostics, playtests, screenshots, and runtime
logs. Do not run the full standalone smoke runner from that session. It starts
one separate Godot process per selected test. The default release gate is
currently 43 paths; the explicit `-TestGroup all` inventory runs all 121
runnable paths. A single headless renderer failure can create repeated Windows
memory-error dialogs.

Run the headless smoke suite only as a supervised standalone check, with no MCP
Godot runtime active. Start with one focused test before using the full runner.
The runner derives its groups from `tests/manifest.csv`, which classifies every
test/report script with a role, state, owner, target, and load kind:

Set `GODOT_BIN` to use a Godot executable outside the repository’s default
Windows development path. The runner derives the project root from its own
location, so it can be launched from a clean checkout.

```powershell
# Focused check
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/run_headless.ps1 -Script res://tests/player_hud_scene_smoke.gd

# Curated release gate — standalone/supervised only; includes web export
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1

# Complete runnable inventory — standalone/supervised only
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1 -TestGroup all

# Fast manifest/path preflight — no Godot process starts
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_test_manifest.ps1

# Composition ownership guardrail — enforces the strict refactor scorecard
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1
```

If Windows memory-error dialogs start repeating, stop the smoke runner and
terminate only the `Godot_v4.7.1-stable_win64_console` worker processes. Keep
the main editor/MCP process alive if it remains healthy.

For one-off headless checks, use `tools/run_headless.ps1`; it creates a temporary
user-data directory, selects the Dummy audio driver, and writes an isolated log
so the editor profile is never reused by a worker. Display settings are
device-wide and can be changed from SETTINGS on the title
screen or from the pause menu. Available options are aspect (`FULL`, 3:2,
16:10, or 16:9), fullscreen, pixel-perfect scaling, music volume, and SFX
volume. `FULL` is the default and follows the live landscape browser/window
viewport while keeping the 160 px logical height.

## Controls

Bindings are defined in the **Input Map** (Project Settings > Input Map) and
remappable in-editor. Defaults:

- Move: Arrow keys / WASD / left stick / D-pad
- Attack: `J` / Space / controller X
- Roll: `K` / controller A
- Target lock: `Q` / Tab / controller right shoulder or right trigger
- Guard: `L` / Shift / controller left shoulder or left trigger
- Interact / confirm: `E` / Enter / controller B (PlayStation Circle)
- Cancel/back: `X` / Escape / controller A (PlayStation Cross)
- Pause: Escape / controller Start
- Open minimap: `M` / controller Share or Options (DS4) / touch MAP

## Web build

Current game version: **0.2.15**. Every push to `main` must increment the
patch version by at least `0.0.01`; update the in-game title-menu version and
this README in the same commit.

The browser build is published to
[GitHub Pages](https://whynchu.github.io/TinyDemons/) from `main`. Pull
requests run the Web export and upload a review artifact without publishing;
only a `main` push (or a manual workflow run on `main`) deploys the public
site. The workflow is [`.github/workflows/web-pages.yml`](.github/workflows/web-pages.yml).
In repository settings, set Pages' publishing source to **GitHub Actions** once
before the first deployment.

On a touch device, the virtual stick and action controls appear after touch
input. Keyboard, mouse, and gamepad input remain available, and prompts follow
the last device used. To validate the export locally after installing the
matching Godot 4.7.1 Web template:

```powershell
pwsh -ExecutionPolicy Bypass -File tests/web_export_smoke.ps1 -RequireExport
```

Local smoke runs stage the export in a fresh temporary directory so an ignored
artifact held by an editor cannot make the check fail. The Pages workflow passes
`-OutputDirectory dist` explicitly for the publishable artifact.
