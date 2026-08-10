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

## Project Layout

- `tiny-demons/` - the Godot project
- `Artwork/` - exported and source art files
- `Mockups/` - reference mockups
- `docs/game-screenshot.png` - first-room gameplay screenshot used in this README

## Running The Project

Open `tiny-demons/project.godot` in Godot 4.7 and run the main scene. The project is configured for a small nearest-neighbor pixel-art presentation, so keep texture filtering and integer-like scaling intact when changing the display settings.

## Controls

- Move: Arrow keys or WASD
- Attack: configured attack input / controller attack button
- Roll: `K` / controller roll button
- Target: configured target input / controller target button
- Interact or restart: `E` / Enter / controller interact button
