# Composition Root Reduction — 2,000-Line Milestone

Status: achieved

Date: 2026-08-22

Branch: `refactor/2026-08-18`

## Result

The composition-root reduction crossed the requested ceiling. `gameplay.gd`
now measures 1,999 lines / 422 functions, down from the R0 baseline of 2,863
lines / 424 functions.

The source file ends with a newline; the smoke scanner reports the same
non-terminal source-line count used by the milestone assertion.

## Ownership moved out of `gameplay.gd`

The root now delegates these bounded domains to dedicated runtime owners:

- `ProfileRuntimeController`: profile application, equipment refresh, stat
  synchronization, gold, and respec flow.
- `PickupRuntimeController`: item drops, Chroma pickups, collection, restore,
  launch, and pickup motion.
- `RunFlowController`: run setup/settlement, telemetry, rewards, completion
  presentation, run metrics, and room/run bookkeeping.
- `HubFlowController`: hub construction, navigation, gear/shop/fusion actions,
  stat allocation, and hub entry/exit.
- `SaveFlowController`: title, save-slot, overwrite, character creation,
  starter-flame selection, loading, and starting-room handoff.
- `RoomPuzzleController`: puzzle room tinting, entry-orb lifecycle, puzzle
  solving, door visuals, and room socket visuals.

The composition root retains compatibility delegates for existing cross-domain
callbacks. Those delegates are intentionally the next cleanup target: the
2,000-line milestone reduces root size, while the longer-term architecture plan
still calls for typed commands/signals to replace root callback routing.

## Verification

- Composition-root milestone smoke: pass; 1,999 lines / 422 functions.
- Full smoke suite: pass; 19 smoke scripts.
- Main-scene headless boot: pass.
- Frame sample: 6.894 ms average / 7.737 ms worst over 180 post-warmup frames.
- Known Godot certificate-store and existing resource-leak warnings remain
  environment/runtime cleanup warnings; no test failed.

## Current supporting-file counts

- `gameplay_state.gd`: 271 lines.
- `gameplay_bootstrap.gd`: 244 lines / 9 functions.
- `profile_runtime_controller.gd`: 88 lines / 7 functions.
- `pickup_runtime_controller.gd`: 177 lines / 13 functions.
- `run_flow_controller.gd`: 222 lines / 22 functions.
- `hub_flow_controller.gd`: 368 lines / 29 functions.
- `save_flow_controller.gd`: 324 lines / 31 functions.
- `room_puzzle_controller.gd`: 174 lines / 14 functions.
