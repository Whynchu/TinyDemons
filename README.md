# TinyDemons

![TinyDemons gameplay screenshot](docs/game-screenshot.png)

TinyDemons is a small pixel-art isometric action prototype built in Godot. Fight colorful slime enemies, lock onto targets, dodge with a roll, collect chest rewards, and clear rooms while managing health and enemy aggro.

Current gameplay includes:

- Directional player attacks with multi-target damage sharing.
- Short roll movement with animation timing and collision-safe movement.
- Slime enemies with wandering and persistent combat aggro behavior.
- Direction-aware slime attack guides and perspective-aware hit detection.
- Player and enemy overhead health bars, target HP display, and top HUD HP/gold counters.
- Diminishing-returns DEF calculations, hit feedback, knockback, and brief hitstop.
- Pixel-based slime splat and player/chest fizzle effects.
- Room progression, chest unlocking, gold rewards, and restart flow.

## Project Layout

- `tiny-demons/` - the Godot project
- `Artwork/` - exported and source art files
- `Mockups/` - reference mockups
- `docs/game-screenshot.png` - gameplay screenshot used in this README

## Running The Project

Open `tiny-demons/project.godot` in Godot 4.7 and run the main scene. The project is configured for a small nearest-neighbor pixel-art presentation, so keep texture filtering and integer-like scaling intact when changing the display settings.

## Controls

- Move: Arrow keys or WASD
- Attack: configured attack input / controller attack button
- Roll: `K` / controller roll button
- Target: configured target input / controller target button
- Interact or restart: `E` / Enter / controller interact button
