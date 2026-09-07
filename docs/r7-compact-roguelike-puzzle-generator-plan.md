# R7 Compact Roguelike Puzzle Generator Plan

Status: proposed replacement; do not select for gameplay until validation exit criteria pass

Reference: `Artwork/Rxpuzzle_map_ex.png`

## Outcome

R7 and later generated runs retain roguelike variation while using the same
compact 35x35 lattice, marker language, minimap rendering, room compiler, and
door semantics as the authored R3-R6 maps. Generation must create the route,
its progression states, and its Fire/Orb/fusion dependencies together. A map
that is merely connected is not sufficient.

The first R7 implementation should generate one primary puzzle sequence and at
least one fusion route. A fusion gate may control either an optional reward
branch or mandatory boss progression, but a mandatory placement is accepted
only when the solver proves the complete ordered recipe and return path.

## Reference-map observations

`Rxpuzzle_map_ex.png` demonstrates the target language:

- a 35x35 canvas with room points on the authored diagonal lattice;
- a Hub near the lower edge and a distant Boss;
- combat, Treasure, Orb, Fire, Cloaked, and Boss rooms using existing marker
  colors;
- ordinary, grey-Orb, primary-color, and additional elemental doorways;
- forks, loops, branch rewards, and reconnections that remain legible as a
  compact map.

The reference is an example, not a fixed topology. Seeds may vary room count,
Hub position, route direction, branches, objectives, and gate placement while
preserving the same visual and traversal grammar.

## Existing systems to preserve

- `PuzzleMapGrid.MapPlan` remains the compact map representation.
- `PuzzleMapLayoutCompiler` remains the conversion boundary into
  `DungeonLayoutDefinition`.
- `DungeonGraph` remains the runtime topology.
- `DungeonMapController` remains the authority for discovery, shared Orb state,
  solved entrance-Orb latches, and connection availability.
- `RoomPuzzleController` remains the authority for Fire and Orb interactions.
- `DungeonMinimapController` remains the only player-facing map renderer.
- Existing room engagement and reverse-traversal behavior remains unchanged.
- Existing fusion recipes and elemental IDs remain authoritative; the generator
  must query them instead of duplicating a recipe table.

The current wide-coordinate generated layout and candidate-scoring preview are
legacy paths. Keep them available as a fallback until this plan passes, then
remove the runtime candidate multiplier and retire the misleading preview.

## New generation pipeline

### 1. Compact lattice geography

Owner: new `scripts/puzzle_route_generator.gd`

Generate only ordinary rooms and connections first:

1. Choose a lower-edge Hub point and an upper/side Boss target region.
2. Grow a main route through unused lattice points.
3. Add two meaningful forks.
4. Rejoin at least one fork before the boss approach.
5. Add optional branch pockets for Treasure, utility, or fusion objectives.
6. Reject overlaps, disconnected points, crossed visual edges, and branches
   that cannot receive a valid paired doorway.

Initial R7 targets:

- 24-30 total rooms;
- one Hub and one Boss;
- 6-10 rooms in the opening region;
- two or three major branches;
- at least one reconnection or shortcut;
- no required branch longer than six rooms without a landmark;
- no room with more than four connections;
- the complete plan fits inside 35x35 without scaling.

Output: a topology-only `PuzzleMapGrid.MapPlan` plus explicit logical edges.

### 2. Region and route roles

Owner: new `scripts/puzzle_route_plan.gd`

Partition the topology into ordered regions before assigning gates:

- opening region;
- first state-controlled region;
- alternate-flame region;
- boss approach;
- optional reward/fusion regions and mandatory fusion progression regions.

Every room and edge receives a role such as `main`, `fork`, `rejoin`,
`objective`, `optional_treasure`, `optional_fusion`, `shortcut`, or
`boss_approach`. Gate placement may only divide declared regions. It may not
color arbitrary edges after generation.

### 3. Primary Fire and Orb program

Owner: new `scripts/puzzle_progression_planner.gd`

Place state sources before dependent doors:

1. Place the first Orb in the opening region at or near a useful junction.
2. Select a boundary whose grey-Orb doors expose meaningful new territory.
3. Place the alternate Fire Room inside reachable territory beyond that
   boundary.
4. Place primary-color doors only where the corresponding Fire Room is already
   reachable.
5. Keep a reachable route back to an appropriate Fire or Orb whenever a state
   change can close another route.

Every generated gate records:

- gate type and exact requirement;
- source and destination regions;
- whether it is mandatory or optional;
- the Fire/Orb/fusion interaction that enables it;
- whether it latches after solving;
- its route purpose.

## Fusion route contract

R7 guarantees one fusion puzzle when a valid route can be embedded. The seeded
route program may assign it to an optional branch or to the boss path. It may
generate a second only when both remain visually separate and their ingredient,
Orb, gate, and restoration routes do not compete for required sockets.

A fusion route consists of:

1. two reachable input Fire sources, or one run-origin flame plus one reachable
   Fire source;
2. a reachable Orb/fusion interaction;
3. a doorway requiring the exact fusion-result element;
4. either a reward region containing Treasure, an elite encounter, or a
   shortcut, or the next mandatory region on the boss route;
5. a reachable way to restore a useful primary/Normal state afterward.

The generator queries `AspectCatalog` for the fusion result and `ElementCatalog`
for the doorway requirement. It must not infer fusion from display colors.

Initial R7 policy:

- fusion doors may be optional or required to reach the boss;
- a mandatory fusion route exposes both ingredient opportunities and its Orb
  before the fused door becomes the only useful frontier;
- each mandatory fusion gate has a dedicated ordered proof:
  `ingredients -> matching Orb -> exact fused result -> gate`;
- a fused element does not satisfy either ingredient's primary-color door;
- solved entrance-Orb fusion doors use the existing persistent latch;
- optional reward value scales with the cost and backtracking required by the
  branch;
- after crossing a mandatory fusion gate, the player can reach the next needed
  primary, Normal, or fused state without becoming trapped behind the solved
  gate.

Later generated ranks may chain multiple mandatory fusion tiers using proofs
equivalent to:

`ingredients A -> Orb A -> gate A -> ingredients B -> Orb B -> gate B`.

## Stateful solvability proof

Owner: new `scripts/puzzle_route_solver.gd`

Validate using the same state changes available to the player. A solver state
contains:

- current room;
- current carried flame/element;
- active ordinary puzzle color;
- active shared-Orb element;
- available Fire Rooms;
- solved entrance-Orb connection IDs;
- completed rooms and revealed shortcuts.

The solver may:

- traverse an available doorway in either direction;
- interact with a reachable Fire Room;
- change a reachable Orb to every recipe/state that its discovered inputs
  support;
- latch an entrance-Orb gate only after producing its exact required element;
- reveal a shortcut only after its authored event.

Required proofs:

1. The boss is reachable through every mandatory fusion tier, while optional
   fusion regions remain unnecessary for completion.
2. Every mandatory gate has a reachable prerequisite on its approach side.
3. Every fusion gate, mandatory or optional, is reachable through its declared
   recipe.
4. No state transition can strand the player away from every usable exit.
5. No shortcut or loop bypasses a mandatory gate.
6. Every reachable room has a valid retreat before combat engagement.
7. Every required Fire/Orb interaction remains reachable at the point it is
   needed, not merely somewhere in the final connected graph.

Failure output identifies the stage, gate coordinate, expected state, and
missing prerequisite.

## Candidate generation and scoring

Generate candidates offline inside the route generator, not by repeatedly
building the entire runtime dungeon during a scene transition.

- Generate lightweight topology/plan candidates.
- Reject invalid plans before compiling runtime rooms.
- Run the full state solver only on structurally valid finalists.
- Compile only the selected plan into `DungeonLayoutDefinition`.
- Keep the same requested dungeon seed deterministic.

Score only after hard validation. Suggested soft preferences:

- readable separation between landmarks;
- useful forks and reconnections;
- limited mandatory backtracking;
- shortcuts that reduce return distance;
- gate boundaries that visibly control regions;
- optional fusion rewards proportional to effort;
- no long sequence of indistinguishable combat rooms;
- no dense cluster of differently colored doors at one junction unless that
  junction is intentionally the puzzle's central control point.

Runtime generation budget target: under 50 ms on the development machine and
without launching multiple Godot processes.

## Marker and compiler extensions

Owner: `scripts/puzzle_map_grid.gd`, then
`scripts/puzzle_map_layout_compiler.gd`

Extend `MapMarker` or add edge metadata so generated doors can represent:

- ordinary entrance;
- grey Orb door;
- primary Flame A/B doors;
- exact elemental doors;
- exact entrance-Orb fusion doors;
- hidden shortcuts.

The 35x35 image remains presentation data. Exact element, gate type, latch
behavior, route role, and prerequisite identity live in typed metadata rather
than being reconstructed from pixel color.

## Validation viewer

Owner: replacement for `generated_puzzle_map_preview.gd`

The validation tool uses the same compact-plan renderer as R3-R6. It does not
instantiate gameplay or the runtime minimap controller.

Required views:

- a grid of complete 35x35 candidate maps that fits in one editor window;
- one selected candidate at a larger integer scale;
- stage overlays showing opening, Orb, alternate flame, fusion, and boss
  reachability;
- seed, score, validation result, landmark counts, and recipe labels;
- next/previous seed and regenerate controls;
- optional display of gate prerequisite arrows and route roles.

The plain map view must look like an authored `PuzzleMapGrid` preview. Debug
information appears only when its overlay is enabled.

## Migration sequence

### Phase A - characterize and isolate

- Preserve representative legacy R7 seeds as fixtures.
- Add tests for current Fire, Orb, entrance-Orb latch, reverse traversal, and
  fusion runtime behavior.
- Put the compact generator behind an explicit R7 feature selector.
- Remove the four-candidate runtime multiplier from the legacy build path once
  equivalent validation is available in the compact planner.

Exit: legacy gameplay remains unchanged and the new planner can run in tests.

### Phase B - topology-only generator

- Implement lattice expansion, route roles, bounds checks, forks, rejoins, and
  structural validation.
- Render batches through `PuzzleMapGrid` without compiling gameplay rooms.

Exit: generated maps fit 35x35 and consistently resemble the visual density and
clarity of `Rxpuzzle_map_ex.png`.

### Phase C - primary puzzle program

- Add region partitioning, Orb placement, alternate Fire placement, and
  primary/grey gate boundaries.
- Add stateful boss-route proofs.

Exit: every sampled R7 map has a readable, solvable primary puzzle.

### Phase D - fusion routes

- Add recipe selection, ingredient placement, fusion Orb placement, elemental
  gate metadata, optional rewards, mandatory boss-route gates, and restoration
  routes.
- Add exact mandatory and optional route solver proofs.

Exit: every generated fusion route is attainable and escapable; mandatory
fusion routes reach the boss, while optional routes remain skippable.

### Phase E - runtime compilation

- Compile the selected `MapPlan` through the authored layout boundary.
- Confirm every doorway uses the correct room socket and display tint.
- Confirm combat locks, reverse traversal, discovery, and minimap cropping.

Exit: the compact route behaves identically in preview and gameplay.

### Phase F - R7 cutover

- Run representative seeds for Fire, Water, and Electric starts.
- Record generation time and reject any seed requiring fallback repair.
- Switch `DungeonMapController` R7 selection to the compact generator.
- Retain the legacy generator for later comparison until one release passes.

## Verification matrix

| Case | Required result |
| --- | --- |
| 100+ topology seeds | Fits 35x35; connected; valid sockets; no crossings or duplicate points |
| Fire/Water/Electric origin | Primary puzzle and boss route solve for each origin |
| Mandatory fusion boss route | Inputs, Orb, exact result gate, restoration state, and boss all solve |
| Optional fusion branch | Inputs, Orb, exact result gate, reward, and return route all solve without being required |
| Wrong fusion result | Door remains locked and no unrelated primary door opens |
| Orb state change | Unsolved doors update; solved entrance-Orb doors remain latched |
| Reverse traversal | Arrival remains available until engagement and follows existing combat-lock rules |
| Minimap | Preview plan and in-game full map use the same marker positions and door colors |
| Death rotation | Entire generated plan rotates by one quarter-turn without changing logical dependencies |
| Performance | Runtime plan selection completes under the generation budget |

## Exit criteria

R7 may switch to the compact generator only when:

1. at least 100 deterministic seeds pass structural and stateful validation for
   every starter flame;
2. every sampled fusion branch has a mechanically verified recipe and return;
3. the preview and in-game minimap match marker-for-marker;
4. no generated map requires a post-build progression repair;
5. generation meets the runtime budget;
6. a human review accepts route readability across a representative gallery.
