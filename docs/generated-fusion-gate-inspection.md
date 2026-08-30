# Generated Fusion-Gate Inspection

Status: inspection complete; implementation not started  
Inspected: 2026-08-30  
Scope: generated R6+ room topology, entrance-Orb gates, shared Orb state, and validation

## Purpose

This document separates what the current code produces from the topology the game
needs to produce. It is intended to be the design record for the follow-up
generator and regression-test changes.

## Current production path

For generated runs (`completed_runs >= 2`), `DungeonMapController.begin_run()` calls
`DungeonLayoutGenerator.build()`, then validates the returned
`DungeonLayoutDefinition`, and finally copies that layout into `DungeonGraph`.

The generator currently combines two different placement systems:

1. `_fusion_plan_for_run()` assigns required Fire-room flames and entrance-Orb
   gate requirements by source depth.
2. `_off_route_orb_depths()` decides whether the two generic Orb depths are on
   the main spine or side detours based on the seed. `_room_type_for_depth()`
   then creates an Orb on the spine only when that depth is not marked as a
   detour; `_add_side_route()` creates the detour Orb otherwise.

The result is that fusion gates have explicit requirements, but their prerequisite
Orb locations are not explicitly coupled to those gates.

The runtime map state does correctly model the intended state transition once an
Orb is reached:

- `change_orb_from_palette()` stores the shared Orb palette and elemental result.
- A mixed result clears the ordinary puzzle-color key, so it cannot accidentally
  satisfy either input-color door.
- `_activate_orb_connections()` solves every matching entrance-Orb connection.
- Solved entrance-Orb connections remain latched in `solved_orb_connections`.
- `connection_visual_state()` and the minimap can therefore display the locked or
  solved state from the same graph/state data.

The primary defect is upstream: the generated route can require the player to
reach a prerequisite Fire room or Orb through the gate whose state that room or
Orb is supposed to provide.

## Reproduction evidence

### R6, seed 607001

`completed_runs = 5`, starter flame `fire` produces the Fire + Water curriculum,
whose result is Shadow. The inspected graph contained:

- a Water Fire room at depth 6 (`room_0_6` in the inspected layout),
- a mandatory entrance-Orb connection from the depth-6 route to depth 7,
  requiring `shadow`,
- a second Orb at depth 11 (`room_-1_11`) reached through the depth-10 route.

The depth-11 Orb is not a valid prerequisite for the depth-6 gate. Depending on
the seed’s generic Orb split, the early Orb can instead be placed away from the
usable progression or otherwise fail to provide the intended pre-gate charge.
The important failure is ordered reachability, not merely whether the graph is
connected when all gates are treated as eventually solvable.

### R8, seed 607001

`completed_runs = 7` produces the two-step Grass -> Ice curriculum:

- Water and Electric Fire rooms are assigned before the first gate at source
  depth 6, requiring `grass`.
- A Water Fire room is assigned at source depth 10 before the second gate,
  requiring `ice`.
- The explicit second Orb is placed as a depth-11 detour from the depth-10
  room, which is the correct shape for the later Ice gate.

This confirms that the special depth-11 placement is solving the second gate’s
local prerequisite, but the first gate still relies on the generic first Orb
placement rule. The two gates therefore do not yet share one explicit, symmetric
ordered-reachability contract.

## Why current validation misses the failure

`_fusion_gate_reachability_errors()` calls `_element_reachable_states()` and asks
whether some state at each gate source contains the required Orb element.

That state search is useful as a broad curriculum sanity check, but it is too
permissive for this guarantee:

- it traverses connections in both directions;
- it accumulates discovered flames and derived elements globally;
- it records Orb elements whenever a state reaches an Orb room;
- it does not retain an explicit “this Orb was reached without crossing this
  gate” proof for each mandatory gate;
- it does not validate the intended order of ingredient rooms -> matching Orb ->
  gate.

The scene smoke test has the same gap: it finds the first Orb by scanning room
IDs and charges it directly, rather than traversing from the start to a specific
pre-gate Orb while respecting room-clear and gate rules.

## Unified gate-prerequisite rule

The same ordering rule applies to every mandatory gate, not only entrance-Orb
fusion gates. A regular puzzle-color gate must have its required Fire/flame state
available on the approach side of the gate. A fusion gate must have both input
Fire rooms and its matching Orb available on that side. If a new color or mixed
result is needed, the player must not be forced to cross a gate of that color and
then backtrack through it to obtain the prerequisite.

Fusion gate type and Orb behavior do not need to change for this rule. The
generator’s placement of Fire rooms, color-gate requirements, and curriculum
Orbs must become tier-aware.

## Intended topology

### One-gate fusion runs: R6 and R7

The generator should produce a deliberate sequence:

`start -> ingredient Fire rooms -> matching Orb -> entrance-Orb gate -> rest of run`

The matching Orb may be a short side room, but its entrance must branch from a
room that is reachable before the mandatory gate. It must never be placed only
behind that gate. The second Orb remains available for the run’s normal Orb
economy, but its location must not become the sole way to solve the first gate.

### Two-gate fusion runs: R8+

Each mandatory gate needs its own pre-gate charge opportunity:

`ingredients A -> Orb A -> gate A -> ingredients B -> Orb B -> gate B`

The Orb for gate B can be the depth-11 detour beside the depth-10 Water Fire
room, as the current plan intends. Gate A needs the same explicit treatment near
the depth-6 ingredient pair. A later Orb must not be the only Orb that can charge
an earlier gate.

## Required invariants

Every generated fusion layout should satisfy all of the following:

1. Every mandatory gate’s required Fire/flame state is reachable before its gate.
2. Every ingredient Fire room for a mandatory fusion is reachable before its gate.
3. A matching Orb is reachable from the start without crossing the gate it
   unlocks and without requiring the result element first.
4. The Orb’s route is physically connected and respects source-room-clear rules.
5. The mixed result is exclusive: it charges only matching entrance-Orb gates and
   does not reopen either input element’s ordinary route.
6. Solving a gate latches it open and remains reflected in world and minimap
   presentation.
7. The number of Orb Rooms is allowed to grow when curriculum tiers require it;
   optional Orbs and mandatory prerequisite Orbs remain distinguishable.
8. The proof works across representative seeds, starter flames, and the R6/R7
   pair rotation—not only one hand-picked graph.
9. The boss remains reachable after applying the same ordered traversal rules.

## Recommended implementation shape

The next implementation should make fusion Orb placement explicit rather than
derive it from the generic Orb detour split.

1. Extend the run curriculum plan with ordered gate tiers. Each tier should
   identify required Fire/flame inputs, any required Orb, and the gate that those
   prerequisites unlock.
2. Add narrow generator helpers that place required Fire rooms and curriculum
   Orbs on the pre-gate side of their tier. Keep generic optional branches
   separate from these curriculum-critical placements. Permit additional Orb
   Rooms when a tier needs one.
3. Preserve the existing shared Orb state and gate-latching behavior unless a
   test demonstrates a separate state bug.
4. Replace or supplement `_fusion_gate_reachability_errors()` with an ordered
   reachability proof. The proof must track which mandatory gates have been
   crossed and must reject any solution whose matching Orb is only reachable
   after that gate.
5. Update the scene smoke test to traverse or simulate the actual route to the
   specific required Orb, then charge it and verify the gate opens. Do not select
   an Orb by arbitrary room-ID order.
6. Add generated-layout coverage for R6, R7, R8, and at least one later two-gate
   run across multiple seeds and starter flames. Include minimap/visual-state
   assertions for locked, charged, and latched doors.

## Verification matrix

| Case | Required proof |
| --- | --- |
| R6, each pair-rotation seed | Shadow ingredient pair, pre-gate Orb, Shadow gate, boss route |
| R7, each pair-rotation seed | Ground ingredient pair, pre-gate Orb, Ground gate, boss route |
| R8 | Grass Orb before gate A; Ice Orb before gate B |
| R9+ representative seeds | Same two ordered gate proofs under alternate topology and branches |
| Orb state | Matching mixed charge opens only matching entrance-Orb gate and latches |
| Minimap | Door color/locked state changes with the shared Orb/gate state |

## Out of scope for this inspection

This record does not change generator code, map-state code, room counts, enemy
balance, or version numbers. Those changes belong to the implementation pass after
the topology and test contract are agreed.
