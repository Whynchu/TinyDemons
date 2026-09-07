# Generated R7 Route Validation

`scripts/puzzle_route_generator.gd` is now the runtime and preview ownership
boundary for generated R7 routes. `scenes/generated_puzzle_map_preview.tscn` is
a designer-facing gallery for
the first generated run after authored R3–R6. The runtime generator now builds
one deterministic compact candidate per requested seed and validates its
progression. The gallery builds six outer seed iterations and renders their room
connections, gate colors, and special room types side by side.

Open the scene directly in Godot and adjust the exported values on
`GeneratedPuzzleMapPreview`:

- `preview_seed` changes the seed family.
- `iteration_count` changes how many routes are shown.
- `completed_runs` is `6` for R7.
- `starter_flame` tests a different starting flame.

Each panel reports its seed, room/gate counts, and whether the generator's
structural and progression validation passed. A valid panel proves the route
is reachable and its authored progression checks pass; it still needs a human
readability review for excessive branching, awkward crossings, or an unclear
sequence of Orb and elemental gates.

The boundary now owns the runtime generation/validation call and composes
`PuzzleRoutePlan`, `PuzzleProgressionPlanner`, and `PuzzleRouteSolver` for typed
gate/prerequisite metadata and ordered state checks. R7 uses the native compact
route builder; later generated ranks still use the historical assembler's
lower-level route-construction primitive while their topology is migrated.

`PuzzleRouteGenerator.build_compact_plan()` projects the same selected runtime
candidate into the 35x35 presentation lattice, preserving room and gate marker
semantics while the typed compact topology metadata is migrated out of the
legacy assembler.

Each compact plan also carries `logical_edges` with paired sockets, route role,
gate type, exact requirements, and fusion-prerequisite identity. Consumers can
therefore compile generated routes from metadata without inferring gameplay
semantics from rendered colors.

Edges additionally record `source_region` and `destination_region`; mandatory
progression is checked against the ordered opening, first-state,
alternate-flame, and boss-approach regions.

Native structural validation also checks edge endpoint ownership, paired room
sockets, doorway bounds, duplicate room positions, and the four-edge degree
limit before runtime graph initialization.

Focused automated coverage is `tests/r7_native_generator_smoke.gd`; it samples
100 seeds each for Fire, Water, and Electric starts and checks route validity,
room density, fusion-gate count, logical-edge preservation, and determinism.
The progression planner additionally enforces the native R7 landmark program:
two ingredient Fire Rooms, two Orbs, two Special Rooms, one mandatory fusion
gate, and a Boss continuation.
