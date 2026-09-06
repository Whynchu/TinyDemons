# R4 Puzzle Map Implementation Plan

## Goal

Turn `Artwork/R4puzzle_map.png` into the next authored dungeon layout while
keeping the existing puzzle-map generator reusable for later runs.

R4 should be validated as a map plan before it is selected by gameplay. The
image coordinates remain the source of truth for room placement, doorway
placement, and minimap presentation.

## Implementation order

### 1. Transcribe the authored map

Create `scripts/puzzle_map_r4.gd` with a `MapPlan` containing:

- normal grey completion doorways;
- Grey Orb doorways;
- Flame A and Flame B doorways;
- Hub, combat, treasure, Orb, flame, cloaked, and boss room markers;
- any R4-specific active grid tiles.

Keep normal grey doors distinct from Grey Orb doors. A normal doorway must not
receive Orb or puzzle-color metadata.

### 2. Compile R4 into the dungeon layout contract

Extend `scripts/puzzle_map_layout_compiler.gd` with `build_r4()` and reuse the
existing grid endpoint validation. Invalid gate endpoints must be skipped
rather than creating runtime rooms at placeholder grid points.

The compiler should:

- preserve authored minimap coordinates;
- generate stable room IDs and runtime coordinates;
- pair each doorway with the correct dungeon socket;
- assign puzzle requirements only to authored color/Orb gates;
- assign `grey_orb` display metadata only to Grey Orb doors.

### 3. Add the authored Run 4 selector

Create `scripts/dungeon_layout_run4.gd`. Select it from
`dungeon_map_controller.gd` when `completed_runs == 3`.

Flame A should resolve from the selected Hub flame. Flame B should resolve
from the first alternate primary flame for the run, matching the R3 contract.

### 4. Validate in the preview scene

Add R4 to `scenes/puzzle_map_preview.tscn` and render it beside the authored
source image. Confirm:

- inactive grid placeholders are darker than active rooms;
- active rooms use the intended room grey;
- normal door pixels and Grey Orb door pixels are visibly distinct;
- no unconnected room appears in the generated preview.

### 5. Add smoke coverage before runtime integration

Add an R4 layout smoke test covering:

- expected room and connection counts;
- exact authored marker coordinates;
- valid endpoint pairs only;
- no phantom rooms from invalid gate fallback;
- normal doors have empty color and Orb display metadata;
- Grey Orb doors alone use `grey_orb`;
- all four doorway directions are revealed when a room is entered;
- room exits lock according to the current room’s encounter state;
- the used arrival doorway remains distinct from unrelated exits.

### 6. Enable gameplay after validation

Only after the preview and smoke test match the source image should R4 become
the authored layout for the fourth completed run. Later runs remain on the
procedural generator until another authored map is ready.

## Door-state requirement

R4 must use room-local encounter state rather than a global route lock:

- exits from the current enemy room remain unavailable until that room is
  cleared;
- the doorway used to enter remains available while scouting;
- that arrival doorway may lock once combat begins;
- clearing the room reopens its exits;
- the behavior must work regardless of which doorway was used to enter.

Tracking the actual arrival doorway is required before finalizing this part of
the runtime integration.

## Verification

Run the focused R4 grid/layout smoke tests first, then the full smoke suite in
a standalone Godot process when no MCP editor/runtime peer is active. Record
the final room/connection counts and any intentional R4 exceptions in
`docs/AUDIT.md`.
