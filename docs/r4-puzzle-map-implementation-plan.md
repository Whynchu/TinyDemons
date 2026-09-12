# R4 Puzzle Map Implementation Plan

Status: authored Run 4 implementation reference

Scope: Run 4 authored map only; it does not define the generated R6+ route.

Updated: 2026-09-11

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

R4 must use room-local encounter state rather than a compiler-selected route
direction:

- every doorway supports entry from either side;
- only the doorway used for the current visit remains available for retreat
  while an enemy room is unengaged;
- entering the same uncleared room later through another doorway replaces the
  previous visit's arrival doorway;
- Flame and Grey Orb requirements remain enforced in both directions;
- combat engagement locks every doorway in the occupied enemy room;
- clearing the room reopens its valid doorways; and
- compiler source/destination orientation remains a socket-geometry detail and
  must never define puzzle progression.

The current arrival is visit-local state, not permanent room metadata. This
policy applies to the authored R3/R4 puzzle maps. Generated layouts retain their
existing route-direction policy.

## Verification

Run the focused R4 grid/layout smoke tests first, then the full smoke suite in
a standalone Godot process when no MCP editor/runtime peer is active. Record
the final room/connection counts and any intentional R4 exceptions in
`docs/AUDIT.md`.

## Room Popcorn Requirement

R3 and R4 normal combat rooms should remain active after their first clear by
bringing back small popcorn encounters. This is separate from Shadow/boss
support respawns.

- Start the respawn timer when a normal combat room is completed.
- Wait 45 seconds before spawning the next popcorn group.
- Exclude Hub, Fire/Rest, Orb, and other non-combat utility rooms.
- R3 should use a larger normal-room slime roster than earlier authored runs.
- Roll a new popcorn cap each time the room is cleared. The cap may be lower
  than the previous group, including one slime, and must not exceed the number
  of normal enemies defeated in the latest encounter.
- Once a popcorn group is defeated, another group may spawn up to that room's
  current rolled cap. Do not duplicate groups while a prior group is alive.
- Persist the timer, rolled cap, live/dead popcorn slots, and exclusions through
  room re-entry and active-run recovery.
- Add coverage for repeated clear rolls, the 45-second delay, re-entry, and the
  Fire/Hub/Orb exclusions.
