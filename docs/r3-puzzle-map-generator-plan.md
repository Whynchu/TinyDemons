# R3 Puzzle-Map Generator

## Scope

R3 starts as an authored 35 x 35 map-plan image, rendered over
`Artwork/puzzle_map.png`. The image is the visual design contract; the plan
must reproduce `Artwork/R3_Grey,ColorA_ColorB_puzzle_map.png` exactly before
it is permitted to drive live dungeon generation.

The plan now also drives the authored Run 3 topology. The compiler keeps the
image's minimap coordinates, turns each gate pixel into a paired room
connection, and maps the three visual gate families to Puzzle A, Puzzle B
(Grey Orb), and Puzzle C (the first alternate primary flame).

## Current contract

`PuzzleMapGrid.MapPlan` is an ordered set of named markers at template-pixel
coordinates. The exact renderer copies the blank puzzle-map template and
applies the markers for reference round-tripping. The design-preview renderer
dims the construction-grid connector lattice and unused room placeholders.
Regular room/path tiles retain their original combat-grey color only when they
are endpoints of an authored connection; authored room and door markers remain
bright. Validation rejects unknown marker types, off-grid coordinates,
duplicate points, and points placed in the empty canvas rather than on the
template grid.

R3 uses three door swatches and seven room roles:

- Dark grey: normal grey entrance; it is passable without an Orb.
- Light grey: Grey Orb door / transition piece; it carries the Orb requirement.
- Blue: Flame A / hub-flame door.
- Green: Flame B / run-flame door.
- White: hub flame; orange: Flame B room.
- Cyan: Orb room; purple: cloaked room; red: boss.
- Light grey: transition piece; yellow: treasure room.

The R3 manifest is code rather than a copied image. The smoke test renders it
onto the template, checks a pixel-perfect match against the original reference,
then parses that reference and confirms the parser also round-trips exactly.
It also renders swatch variants to ensure the renderer is reusable for later
maps.

## Viewing it

Open `scenes/puzzle_map_preview.tscn` in Godot and run the current scene. It
shows original R3 beside three generated gate-swatch variants at pixel-perfect
nearest-neighbor scale. It is a design scene only and does not enter the game
or change dungeon generation.

## Runtime integration

`scripts/puzzle_map_layout_compiler.gd` emits a `DungeonLayoutDefinition` for
the 39 active R3 room points and all 42 gate pixels. `dungeon_layout_run3.gd`
selects the Hub flame as Flame A and the first alternate primary flame as
Flame B. Completed Run 3 now selects this authored layout; later runs return
to the procedural generator.

The light-grey transition pieces remain logically Puzzle B but carry the
distinct `grey_orb` display key, so the in-game door texture and minimap stay
light grey instead of becoming the ordinary grey entrance.

Compiler source/destination orientation only selects paired runtime sockets; it
does not define progression direction. R3 can be traversed through either side
of every doorway. On each visit to an uncleared enemy room, only the doorway
used to enter remains available for retreat; entering later from another side
replaces that visit-local arrival. Puzzle-color requirements apply in both
directions, combat engagement locks every doorway, and clearing the room opens
all valid routes.
