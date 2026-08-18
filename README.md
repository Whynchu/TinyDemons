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

## Current Focus

The active feature overhaul is the **Combat & Economy pass**: gear primary
stats now give 25% of base per point with a 1-point floor, player base stats
moved to 3/2/2 (archetypes sum to 7), enhancement adds 10%/level, and
enemies/boss are rebalanced to scale honestly. The hub FUSE tab is now
**target-centric**: pick the item you want to upgrade, choose how many
duplicates to fuse into it, and the gold cost scales with the target's
enhancement level. See
[`docs/combat-economy-overhaul.md`](docs/combat-economy-overhaul.md).

## Project Layout

- `project.godot` - the Godot project root (this folder is the project)
- `assets/` `scenes/` `scripts/` `shaders/` `tests/` - the Godot project
- `Artwork/` - exported and source art files (source, not imported by Godot)
- `Mockups/` - reference mockups
- `screenshots/` - game screenshots
- `docs/` - audit, plans, tuning index, feature designs, and smoke checklist
- `docs/game-screenshot.png` - first-room gameplay screenshot used in this README

## Running The Project

Open `project.godot` in Godot 4.7 and run the main scene. The project is configured for a small nearest-neighbor pixel-art presentation, so keep texture filtering and integer-like scaling intact when changing the display settings.

Run the headless smoke suite before committing:
```powershell
pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1
```

## Controls

Bindings are defined in the **Input Map** (Project Settings > Input Map) and
remappable in-editor. Defaults:

- Move: Arrow keys / WASD / left stick / D-pad
- Attack: `J` / Space / controller X
- Roll: `K` / controller A
- Target lock: `Q` / Tab / controller right shoulder or right trigger
- Guard: `L` / Shift / controller left shoulder or left trigger
- Interact / confirm: `E` / Enter / controller B
- Cancel: `X` / controller A
- Pause: Escape / controller Start
