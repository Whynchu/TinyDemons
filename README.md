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
The longer-term goal—data-driven content composition, easier enemy/room/map
authoring, and device-backed performance work—is documented in
[`docs/long-term-composition-and-performance-plan.md`](docs/long-term-composition-and-performance-plan.md).

### Current refactor focus

The composition refactor is complete: components own focused state and
behavior, controllers coordinate feature boundaries, and `GameplayState`
remains the composition root instead of a shared service locator. The
completion record is in
[`docs/composition-refactor-analysis.md`](docs/composition-refactor-analysis.md)
and the current measured baseline is in [`docs/AUDIT.md`](docs/AUDIT.md). The
active forward direction — content definitions, factories, and device-backed
performance — is in
[`docs/long-term-composition-and-performance-plan.md`](docs/long-term-composition-and-performance-plan.md).

The latest source scan (working tree on 2026-09-17; version `0.2.32`) gives us
this shape:

| Surface | Current measurement | What it tells us |
|---|---:|---|
| Runtime scripts | 183 | The project already has a substantial feature vocabulary |
| Explicit `*Component` classes | 20 | Player, slime, Chroma, equipment, health, and interaction composition is established |
| `gameplay.gd` | 233 lines | The old giant coordinator has already been reduced |
| `gameplay_state.gd` | 1,719 lines / 479 functions / 286 fields | At the strict target; the composition root and compatibility surface remain, but the state bag no longer owns room/geometry/frame-schedule seams |
| `root.call/get/set` | 2,308 sites | Below the strict target; the remaining sites are the next vertical migration seams |

Completed refactor foundations include the explicit frame scheduler, runtime
bootstrap wiring, player and slime components, typed reward and settlement
boundaries, typed room transition/entry/activation/clear results, typed
enemy-runtime capture, typed room-level initial spawn orchestration, typed
per-frame respawn coordination, typed room spawn/death helpers, typed
room-owned combat death consequences, room-owned geometry, external default
tuning resources, typed pause/Hub player presentation contexts, and
editor-inspectable definition resources for slime variants, elements, palettes,
the item catalogue, the Run 1/Run 2 layouts, and the authored puzzle plans.
Under the strict ownership scorecard in
[`docs/composition-refactor-analysis.md`](docs/composition-refactor-analysis.md),
the legacy-coupling cleanup is **complete (100%)**: the strict audit passes and
the regression floor now protects the achieved state. The **editor-composition
score is 100%**: all 20 components are blind + editor-configured, and all 16
authored definition surfaces are editor-inspectable resources — see
[`docs/component-composition-design.md`](docs/component-composition-design.md).
That is a real milestone, but not the end of the authoring goal: the remaining
work is to make content additions definition-driven so an enemy, room, or map
can be added through a factory and definition instead of central-state special
cases, while also establishing real desktop/web/mobile performance budgets.

The practical sequence is:

1. Make the boss-entry measurement a stable gate (the harness currently reports
   one noisy sample) and keep the curated standalone gate and focused room/HUD
   checks green; optimize the boss entry after the A17 device profile exists.
2. Finish the `EnemyDefinition` + `EnemyFactory` proof: the slime variant data is
   now an editor-inspectable resource, so the next step is a factory that
   assembles a runtime slime from the definition and mounts a second entity
   sharing its components with zero `GameplayState` edits.
3. Convert `item_catalog.gd`, `dungeon_layout_definition.gd`, and the Run 1–6
   builders to editor-inspectable resources, then make dungeon/map generation
   consume validated content rather than accumulating special cases.
4. Profile title, hub, rooms, boss combat, transitions, effects, and menus on
   desktop, web, and the Samsung A17 before choosing rendering optimizations.
5. Characterize browser/device file-write ordering and the hosted Pages
   artifact alongside the runtime work.

Line counts and dynamic-call counts are navigation evidence, not quality scores.
Do not split files or remove `GameplayState` wholesale; preserve the explicit
frame order and characterize each vertical slice before changing its ownership.
The long-term composition plan defines the workflow tests that matter: adding
an enemy, room, or map without editing the central state bag, and meeting
measured performance budgets on the actual target device.

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

# Composition ownership guardrail — blocks composition regressions
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1

# Guardrail implementation self-test
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1 -SelfTest

# Opt-in completion audit — expected to fail until the remaining targets land
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1 -RequireTargets
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

Current game version: **0.2.35**. Every push to `main` must increment the
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
