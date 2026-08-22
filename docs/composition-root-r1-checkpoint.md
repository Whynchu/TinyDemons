# Composition Root Reduction — R1 Checkpoint 1

Status: complete for the typed runtime-owner construction slice

Date: 2026-08-22

Commit: recorded with this checkpoint in git history

## Scope

This checkpoint formalizes the first R1 boundary without changing gameplay
behavior. `GameplayBootstrap.initialize()` now accepts the concrete
`GameplayState` type instead of an untyped `Object` and directly constructs and
assigns the top-level runtime owners it creates.

Migrated construction includes:

- input routing;
- screen state;
- frame scheduling;
- walkability and actor collision;
- geometry debugging;
- depth and occlusion;
- room, shadow, interaction, chest, NPC, rest-fire, and HUD controllers;
- sound and effects services;
- projectile and Chroma-pickup controllers; and
- run state, dungeon seed, and initial room identity.

The runtime owner for the geometry debug drawer was also declared explicitly in
`GameplayState`. It had previously existed only as an implicit dynamic property
created through `root.set(...)`.

## What remains intentionally unmigrated

Bootstrap still contains compatibility calls for later slices, including:

- profile application and room synchronization;
- socket/layout setup;
- actor and slime assembly;
- scene/UI construction;
- player capability initialization;
- walkable-area setup;
- room-state application; and
- debug/run entry flow.

Those calls remain until their owners and typed APIs are prepared. This checkpoint
does not claim that bootstrap is fully typed or that the root service-locator seam
has been removed globally.

## Verification

- Composition baseline smoke: pass (`gameplay.gd` remains 2,863 lines / 424 functions).
- Full smoke suite: pass, 18 scripts.
- Main-scene headless boot: pass.
- Frame-time sample: 6.895 ms average / 11.440 ms worst over 180 post-warmup frames.
- Known Godot certificate-store warning remains environment-only.

## Exit assessment

The first R1 slice is safe to keep. It establishes a typed bootstrap boundary and
removes dynamic construction/state assignment for the top-level runtime services
without moving gameplay policy. The next R1 slice should migrate player actor
assembly into a typed `PlayerAssembler` or player-scene composition API, including
health, movement, input, attack, guard, Chroma, animation, and equipment wiring.
