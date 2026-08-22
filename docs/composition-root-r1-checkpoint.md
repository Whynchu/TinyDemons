# Composition Root Reduction — R1 Checkpoint 2

Status: complete for typed runtime-owner construction and initial room setup

Historical checkpoint. Superseded by [`composition-root-2000-milestone.md`](composition-root-2000-milestone.md).

Date: 2026-08-22

Commit: `239115e`

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

The initial room seam is now typed as well: current-room synchronization,
socket/layout setup, walkable polygon construction, and post-room state/depth
refresh use `GameplayState` methods and fields directly. This also removes the
bootstrap fallback access around `EDGE_MARGIN`, `SLIME_EDGE_PADDING`, and the
walkable-area geometry.

## What remains intentionally unmigrated

Bootstrap still contains compatibility calls for later slices, including:

- profile application;
- actor and slime assembly;
- scene/UI construction;
- player capability initialization;
- debug/run entry flow.

Those calls remain until their owners and typed APIs are prepared. This checkpoint
does not claim that bootstrap is fully typed or that the root service-locator seam
has been removed globally.

## Verification

- Composition baseline smoke: pass (R0 ceiling remains 2,863 lines / 424 functions).
- Full smoke suite: pass, 19 scripts.
- Main-scene headless boot: pass.
- Frame-time sample: 6.896 ms average / 7.649 ms worst over 180 post-warmup frames.
- Known Godot certificate-store warning remains environment-only.

Current counts are:

- `gameplay.gd`: 2,859 lines / 423 functions (`-4` lines / `-1` function from R0).
- `gameplay_state.gd`: 265 lines (`+1` typed composition field).
- `gameplay_bootstrap.gd`: 232 lines / 9 functions. The line count is unchanged
  by this slice; the remaining dynamic-root access is now concentrated in actor,
  UI, and compatibility assembly rather than initial room geometry.
- Title boot regression check: pass; title overlay is visible and the loading
  cover is hidden on a fresh title route.

## Exit assessment

This R1 slice is safe to keep. It establishes typed bootstrap boundaries for
runtime services and initial room geometry without moving gameplay policy. The
next R1 slice should migrate actor/slime assembly into typed ownership, keeping
health, movement, input, attack, guard, Chroma, animation, and equipment wiring
out of the composition root where possible.
