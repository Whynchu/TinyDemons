# Generated R7 Route Validation

`scenes/generated_puzzle_map_preview.tscn` is a designer-facing gallery for
the first generated run after authored R3–R6. The runtime generator now builds
four deterministic candidates per requested seed, validates their progression,
and selects the clearest candidate by route score. The gallery builds six
outer seed iterations and renders their room
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
