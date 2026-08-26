# Run 1 Dungeon Map and Global Orb-State Implementation Plan

Status: Implementation in progress; semantic map contract is locked, room/content integration is ongoing.  
Design authority: [`run1-dungeon-map-design.md`](run1-dungeon-map-design.md)  
Visual authority: [`Artwork/minimap- rough draftR1.png`](../Artwork/minimap-%20rough%20draftR1.png)

## Outcome

Replace the current procedural-first room flow with an authored Run 1 map contract that supports color-gated doors, shared global orb state, optional treasure, event-revealed entrances, and a pixel-faithful minimap. Preserve composition boundaries: topology, mutable map state, room content, environment presentation, and minimap rendering each have their own owner.

## Current implementation checkpoint

Completed in the first integration slice:

- `DungeonLayoutDefinition` and `DungeonLayoutRun1` encode the 24-room Run 1 topology from the mockup.
- Both Orb Room locations use the single runtime type `ORB`; both use the same light-blue map marker, while blue/green swatches are authoring placeholders for the two semantic door keys.
- Door requirements use only `puzzle_a` and `puzzle_b`; no flame palette names are used as topology keys.
- `DungeonMapState` starts in Puzzle Color B, whose authored presentation is grey, and owns the shared puzzle-color state.
- `DungeonMapController` owns effective color gates and exposes a narrow Orb Room activation boundary.
- Authored room sockets consult map availability for both transition checks and entrance-block collision geometry.
- `DungeonMinimapController` renders the 16×23 logical map with progressive room/connection reveal.
- Puzzle Color A doors resolve to the selected starter flame palette; Puzzle Color B doors resolve to grey. The map environment follows the same mapping.
- The hub uses `DoorRightFlameshut.png` until the starter flame is attuned on the tutorial run.
- `scenes/basic_room.tscn` and `scenes/orb_room.tscn` provide editable room and single-orb authoring templates.
- `run1_map_contract_smoke.gd` and `run1_minimap_smoke.gd` cover the semantic contract and pixel placement.

Still pending: authored treasure-room content polish, visual placement review of the new room templates, and the remaining full-run playtest pass. Special-room respawns now use independent 45-second slot timers and need in-game timing confirmation.

## Non-goals for the first pass

- No late-game primordial swapping or bind mechanic.
- No generalized multi-color door system beyond the approved Run 1 colors.
- No save migration. Existing incompatible active runs may be discarded.
- No procedural minimap art that diverges from the mockup.
- No requirement that future runs use the exact Run 1 topology.

## Phase 0 — Confirm the remaining implementation decisions

The following product decisions are confirmed and should be treated as requirements:

- Run 1 uses two semantic door/state keys: `PUZZLE_COLOR_A` and `PUZZLE_COLOR_B`. Both Orb Room locations use the light-blue map swatch; blue and green map swatches identify the two authored door keys as placeholders, not fixed runtime flame colors.
- The run begins with Puzzle Color B, grey shared orb state, and untinted authored grey room/orb artwork.
- The dark-grey minimap structure means ordinary/open paths, not a grey color key.
- Only an Orb Room interaction can change the puzzle-color state.
- Both identical Orb Rooms share one orb state; changing either updates both orbs and the global puzzle-color state.
- The minimap progressively reveals rooms and connections as the player unlocks/discovers them.
- Special Enemy Rooms use the standard encounter roster and can respawn each enemy independently after roughly 45 seconds while their required color is inactive.
- Every Run 1 Treasure Room contains exactly one chest; chest collection is not required to clear the room.
- Puzzle Color A resolves to the file's selected starter flame palette; Puzzle Color B resolves to grey. Orb Rooms begin grey and share one state.

Resolved defaults for this pass:

1. Elemental magic in an Orb Room selects Puzzle Color A; grey regular attack energy selects Puzzle Color B.
2. Puzzle Color A follows the selected starter flame for the file; Puzzle Color B remains grey.
3. The hub's starter gate uses `DoorRightFlameshut.png` until first attunement; later runs do not force that gate.
4. Global map tint affects authored floor, wall, door, and entrance surfaces, never the background layer or editor guides.

The remaining review questions are visual placement of the prefabs, whether the exact 45-second delay feels right, and whether color changes need a one-use grace period at a socket.

## Phase 1 — Add the topology data contract

Create dedicated data ownership rather than adding fields to `gameplay.gd`.

Likely new files:

- `scripts/dungeon_layout_definition.gd`: authored room and connection definitions.
- `scripts/dungeon_layout_run1.gd`: the exact Run 1 room list, coordinates, categories, and edges.
- `scripts/dungeon_map_state.gd`: neutral/`PUZZLE_COLOR_A`/`PUZZLE_COLOR_B` active puzzle-color state, shared orb state, discovered rooms, completed rooms, and revealed connections.
- `scripts/dungeon_connection_state.gd` or an equivalent value type: base availability, room-clear rule, color requirement, and effective state.
- `scripts/dungeon_map_controller.gd`: initializes the layout, answers gate queries, and emits state-change signals.

Extend `DungeonGraph` only as needed to represent authored records and connections. Keep graph structure separate from mutable run state. `RoomController` should consume graph/map-controller answers instead of inventing gate rules.

Deliverables:

- typed room-category and door-requirement vocabulary;
- an explicit shared-orb-state contract in which both identical Orb Rooms mirror one puzzle-color state;
- deterministic coordinate-to-room lookup;
- deterministic connection lookup by source socket;
- serialization shape for the active run state, with no migration requirement;
- unit-level tests for graph construction and coordinate uniqueness.

## Phase 2 — Encode the Run 1 topology

Translate the mockup into an explicit layout definition. Do not infer edges from image pixels at runtime.

For every authored room, define:

- stable ID and minimap coordinate;
- room category;
- incoming/outgoing sockets;
- door requirement for each connector;
- initial visibility/discovery rule;
- room-clear rule;
- exactly one chest and its authored placement if it is a Treasure Room;
- Orb Room marker and central orb placement; both Orb Rooms use the same runtime room type and the orb's displayed state comes from shared map state;
- event-revealed entrances;
- boss/cloaked special flags.

Validation must reject layouts with missing Hub, anything other than two Orb Room instances, multiple Cloaked Rooms, missing Boss, unreachable required nodes, or a color-gated route with no valid activation path. It must not interpret ordinary dark-grey connectors as a grey color gate.

At this phase, use a graph snapshot test to prove the authored map matches the mockup's room count, color categories, and connector positions.

## Phase 3 — Implement effective door state

Move door decisions behind `DungeonMapController`:

```text
is_connection_available(connection, current_room_state, map_state)
```

The controller should own:

- ordinary open/closed state;
- room-clear gates;
- Puzzle Color A/B gates;
- event-revealed entrances;
- state-change signals for room controllers and minimap presentation.

Import the authored `Artwork/DoorRightOrbshut.png` as the color-locked door visual during this phase. Keep its runtime asset path alongside the existing door textures, and keep collision/transition blocking derived from `is_connection_available` rather than from the sprite itself.

`RoomController` remains responsible for applying the answer to active socket visuals, entrance blocking polygons, and transition triggers. It should no longer use one room-global boolean to represent every exit.

Add explicit tests for:

- ordinary doors remaining available;
- grey Puzzle Color B state leaving ordinary dark-grey connectors available;
- Puzzle Color A doors opening only in Puzzle Color A state;
- Puzzle Color B doors opening only in Puzzle Color B state;
- changing the shared orb from Puzzle Color A to Puzzle Color B relocking A and unlocking B for both identical Orb Rooms;
- room-clear gates opening after enemies die;
- chest collection not being required;
- event-revealed entrances appearing only after their event.

## Phase 4 — Replace the current puzzle-room content

Replace the current two-entry-orb `ROOM_PUZZLE` implementation for Run 1 with the two authored Orb Room categories:

- one central orb per room;
- Puzzle Color A and Puzzle Color B are authored door/state options, while the displayed orb state is shared;
- activation event routed to `DungeonMapController`;
- changing either orb synchronizes the other orb and `active_puzzle_color`;
- no local two-orb door puzzle;
- no room-only environment tint.

Keep the existing orb art, palette preservation, bob, twinkle, and target highlight as reusable presentation pieces. The new room controller should own only placement and activation behavior.

The old tutorial two-orb room path should be removed or isolated behind the obsolete run path once the new Run 1 topology is active. Do not leave two competing meanings for `ROOM_PUZZLE`.

## Phase 5 — Add authored Treasure and Special Enemy rooms

Add room content policies without coupling them to the minimap:

- Treasure Rooms spawn their authored enemy encounter and exactly one authored chest.
- All required enemies must die before ordinary exits open.
- Chests remain collectible after room clear and do not control door state.
- Special Enemy Rooms use the standard encounter roster and their authored connection rules.
- Room completion emits a single event consumed by map state.

This phase should reuse the existing chest and enemy components where possible. New room categories should select behavior through `RoomController`/content policies rather than branches in `gameplay.gd`. Special Enemy content uses independent 45-second respawn timers anchored to each enemy's death; the required color suppresses the room without resetting those timers.

## Phase 6 — Apply global map environment color

Add a single presentation owner for the active puzzle-color state. On orb activation and room entry:

1. Read `active_puzzle_color` from `DungeonMapState`.
2. Resolve it to the approved environment tint.
3. Apply it to intended floor, wall, door, and entrance surfaces.
4. Reset surfaces before applying a new tint.
5. Exclude background, UI, collision guides, and hidden unused surfaces unless explicitly approved.

This replaces the current room-local puzzle tint path. The rendering code should be reusable by ordinary rooms, Orb Rooms, and revisits.

## Phase 7 — Build the pixel-faithful minimap

Create a dedicated minimap scene/controller. Recommended ownership:

- `MinimapController`: subscribes to map/room signals and controls visibility/layout.
- `MinimapRenderer`: draws a 16×23 logical canvas from layout and state.
- `MinimapPalette`: stores the exact reference colors.

Rendering order:

1. Fill the dark background.
2. Draw ordinary room/entrance structure.
3. Draw room-category pixels.
4. Draw Puzzle Color A/B required door pixels using resolved runtime palettes while retaining the mockup's blue/green swatches as the reference contract.
5. Apply locked/available state treatment.
6. Apply current-room and completion overlays only after the base map matches.

Use an `Image`/`ImageTexture` or equivalent nearest-filter pixel surface. Do not use anti-aliased vector primitives for the base map. The renderer should have a snapshot test that compares logical pixel colors and positions against a checked-in expected map representation.

The exact distinction between unlocked, entered, and adjacent-discovered can be resolved during the UI contract pass, but the progressive-reveal invariant is not optional.

## Phase 8 — Integrate, verify, and remove obsolete paths

Integration order:

1. Initialize authored Run 1 layout through `RunFlowController`.
2. Initialize `DungeonMapState` for the run.
3. Route room entry/clear/orb events through the map controller.
4. Route socket visuals and movement blocking through effective connection state.
5. Route environment tint through the global puzzle-color state.
6. Mount the minimap under the HUD/UI layer.
7. Remove old Run 1 two-orb puzzle assumptions and room-local tint calls.
8. Keep compatibility wrappers narrow and document ownership in `ARCHITECTURE.md` if the new owners become canonical.

Required verification:

- Run 1 authored topology smoke test;
- connection gate state-machine test;
- orb activation/global-color test;
- Treasure Room chest-optional completion test;
- event-revealed entrance test;
- global environment tint/revisit test;
- starter-flame hub-gate and delayed special-respawn tests;
- minimap logical-pixel snapshot test;
- title boot, main scene, boss geometry, and full smoke suite.

## Handoff checklist

Implementation is ready to begin when:

- the remaining visual/timing review questions have answers or approved defaults;
- the mockup room/connector reading is converted to a labeled topology sheet;
- the exact Run 1 room count and authored one-chest Treasure Room placements are agreed;
- the neutral-grey active-color start state and door grace rule are agreed;
- progressive minimap reveal behavior is implemented and reviewed;
- the new ownership files are accepted as the composition boundary.
