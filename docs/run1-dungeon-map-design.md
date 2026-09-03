# Run 1 Dungeon Map and Global Orb-State Design

Status: Approved direction; implementation in progress  
Reference: [`Artwork/minimap- rough draftR1.png`](../Artwork/minimap-%20rough%20draftR1.png)

This document defines the map language introduced by the Run 1 minimap mockup. It is a gameplay and presentation contract, not an implementation checklist. The implementation plan lives in [`run1-dungeon-map-implementation-plan.md`](run1-dungeon-map-implementation-plan.md).

## Design summary

Run 1 should be an authored dungeon route with branching paths, optional treasure, room-clear progression, and two selected puzzle-color keys controlled by Orb Rooms. Those keys are named `PUZZLE_COLOR_A` and `PUZZLE_COLOR_B`; they are not elemental flame palettes. The run begins in Puzzle Color B, whose map presentation is authored grey. Puzzle Color A resolves from the file's selected starter flame, while Puzzle Color B is always grey. The minimap is a compact pixel-art representation of that same graph, not a separate decorative illustration.

The important change is that an orb no longer tints only the room containing it. Changing the orb in any Orb Room changes the active puzzle-color state for the run. Doors with that requirement become available; doors requiring another puzzle color become unavailable. Uncolored doors remain available when their ordinary room-clear or discovery rules allow them. The blue and green pixels in the mockup are semantic design swatches, not hard-coded flame palettes.

The player can therefore change the strategic state of the entire dungeon by reaching an Orb Room and changing its orb. The two Run 1 Orb Rooms are identical room types and share one global orb state: changing either orb changes the other orb, the active puzzle-color state, the eligible color doors, and the environment presentation. The map, door visuals, room environment, and minimap must all read from one shared map-state owner.

## Reference image contract

The mockup is a 16×23 logical-pixel image. Its dark background is not a room type. Colored pixels represent rooms, doors, entrances, and route structure. The runtime minimap should preserve this low-resolution, nearest-neighbor visual language.

The reference palette is:

| Color | RGB | Meaning |
| --- | --- | --- |
| White | `#F4F4F4` | Hub / start room |
| Dark grey | `#333C57` | Ordinary doors and entrances; neutral/open-path structure, not a grey color key |
| Mid grey | `#566C86` | Enemy room |
| Light grey | `#94B0C2` | Special enemy room |
| Yellow | `#FFCD75` | Treasure room |
| Orange | `#EF7D57` | Fire / rest room |
| Purple | `#5D275D` | Cloaked room |
| Red | `#B13E53` | Boss room |
| Light blue | `#73EFF7` | Orb Room marker swatch used at both Orb Room locations |
| Blue | `#3B5DC9` | Puzzle Color A placeholder door swatch in the mockup |
| Green | `#38B764` | Puzzle Color B placeholder door swatch in the mockup |
| Background | `#111318` | Empty minimap canvas |

These are map-display colors. They may reuse palette constants where that improves consistency, but the minimap must not depend on actor sprite recoloring.

## Room vocabulary

| Map symbol | Runtime concept | Required behavior |
| --- | --- | --- |
| White | Hub | Safe start area. The selected starter flame is present here. |
| Mid grey | Enemy Room | Enemies gate the room's ordinary exits. Defeating all enemies clears the room. |
| Light grey | Special Enemy Room | Standard enemy room with special door/path rules and a color-conditional respawn policy. |
| Yellow | Treasure Room | Contains enemies and exactly one chest. Enemy defeat opens its exits; chest collection is optional for room completion. |
| Orange | Fire Room | Rest/attunement room. Some fire rooms can reveal an additional entrance after their prerequisite is satisfied. |
| Purple | Cloaked Room | Exactly one in Run 1. Contains the cloaked-demon interaction and the intended route progression. |
| Red | Boss Room | The Run 1 endpoint encounter. Its exit/settlement behavior is distinct from ordinary rooms. |
| Light blue | Orb Room marker | Both light-blue markers identify the same `ORB` room type. Each location contains exactly one centered shared-state orb; the marker is not a puzzle-color key. |

The existing `START`, `COMBAT`, `REST`, `NPC`, and `DOWNSTAIRS` types are close to this vocabulary. `TREASURE`, `SPECIAL_ENEMY`, and `ORB` are the new authored map concepts. Existing `PUZZLE` should not remain the public name for these single-orb rooms once this design is adopted. `PUZZLE_COLOR_A` and `PUZZLE_COLOR_B` are door/state keys, not room types.

## Topology and route rules

Run 1 is an authored topology. Its room coordinates, room categories, connector positions, door requirements, and optional branches must be deterministic and reviewable as data. The minimap image is a visual reference for that topology; it is not the source of truth for graph connectivity.

The topology must guarantee:

- one Hub;
- one Cloaked Room;
- one Boss Room;
- two identical Orb Room instances, each with one centered orb;
- treasure rooms that contain enemies as well as chests;
- at least one optional or newly revealed path, including the fire-room branch shown in the mockup;
- a valid route from the Hub to the Boss without requiring an impossible color state;
- no room or connector that is permanently unreachable because of its own color requirement;
- deterministic room coordinates that can be rendered onto the 16×23 minimap canvas.

Room records should distinguish the complete authored graph from currently available paths. A connection can exist in the graph while its entrance is hidden, undiscovered, room-clear gated, or color locked.

## Door and entrance state

Every connection needs an explicit requirement rather than inheriting a single `door_active` boolean. Recommended connection fields are:

```text
source room
destination room
source socket
destination socket
display coordinate(s)
base availability: open | hidden_until_clear | hidden_until_event
room-clear requirement: none | source_room_clear
color requirement: none | puzzle_a | puzzle_b
```

The effective state is evaluated centrally:

```text
available = base availability is satisfied
         && room-clear requirement is satisfied
         && color requirement is none or equals active_puzzle_color
```

### Enemy engagement lock

Combat, Treasure, and Special Enemy Rooms use a deliberate two-stage lock:

1. Entering an uncleared room leaves its arrival entrance open, while its
   forward and side exits remain room-clear gated.
2. The first player attack that actually lands on a slime marks the room as
   engaged. Empty swings and passive slime aggro do not engage it.
3. An engaged room locks its arrival entrance as well as its ordinary exits.
4. Clearing the required enemies releases the engagement lock; each connector
   then follows its normal visibility and puzzle-color requirements.

This lets the player inspect or retreat from a room before they consciously
commit to a fight, while preventing an engaged encounter from being abandoned.
Engagement is map state, not a sprite or collision-only effect, so door art,
collision, transition checks, and minimap presentation must all query the same
effective connection state.

An entrance always retains its source-side clear gate. At a merge, an incoming
entrance tied to an uncleared sibling branch remains closed: entrance
availability is the source gate *and* the destination-not-engaged rule. This
prevents a merge from becoming a backdoor into a locked enemy room.

Not every door is color locked. An ordinary dark-grey door remains available when its other requirements are satisfied. A Puzzle Color A or Puzzle Color B connector is visually represented by its resolved runtime palette (the mockup's blue/green swatches are authoring references) and is locked whenever the global active puzzle-color state does not match.

Color-locked doors should use the authored closed-door artwork supplied at `Artwork/DoorRightOrbshut.png` (16×32 RGBA, matching the existing right-door scale). The runtime asset/import path must be established before the first map-door integration pass. This visual is presentation only; effective availability and collision remain owned by the map connection state.

The runtime display mapping is explicit:

| Semantic requirement | Runtime display palette |
| --- | --- |
| `puzzle_a` | The selected starter flame palette (`red`, `blue`, or `yellow`) |
| `puzzle_b` | `grey` |
| no requirement | Ordinary dark-grey door art |

This keeps the mockup's blue/green key legible during authoring while allowing a new file's selected starter flame to be the actual Puzzle Color A door color.

When an orb changes the active puzzle-color state, all connection states are reevaluated. Puzzle Color B is the grey starting key; the legacy `neutral` value remains valid only for compatibility and resolves to the same grey presentation. The currently loaded room, its socket visuals, entrance blocking polygons, and minimap must update from the same result.

Recommended safety rule: changing color never ejects the player from the room or strands them inside a room with no valid exit. If a color change would lock the socket the player is currently occupying, the visual may update immediately but the player must be allowed to leave that socket once. This is an explicit design choice to confirm before implementation.

## Orb behavior

Each Orb Room has one orb at the center and no two-orb puzzle arrangement. Run 1 defines two door/state keys, `PUZZLE_COLOR_A` and `PUZZLE_COLOR_B`, but neither Orb Room owns a permanent color. Both orbs always display the current shared orb state, including authored grey Puzzle Color B at the start of the run. The two light-blue pixels in the mockup identify the two authored locations only; they do not define separate room behavior or flame aspects.

The interaction should be treated as a map-state event that is only available in an Orb Room:

1. Player enters the Orb Room.
2. Player strikes the central orb with an elemental magic projectile or regular attack.
3. The map-state owner resolves starter/earned energy to its Puzzle Color key,
   while any other valid elemental energy (including Grass, Ice, Ground, and
   Shadow fusion results) is accepted as a shared elemental orb charge.
4. A Puzzle Color key and its shared orb palette change together. An unkeyed
   elemental charge changes the shared orb palette and clears the current
   Puzzle Color key; it cannot satisfy an ordinary color-gated door. A color
   gate already opened before that charge remains latched.
5. Every Orb Room orb synchronizes to the new elemental color.
6. Every color-gated connection reevaluates when the Puzzle Color key changed.
7. The environment palette and minimap update from the same strategic state.

No ordinary room, flame, or global shortcut can change the puzzle-color state; only an Orb Room interaction can do so. All valid elemental palettes can
charge the shared orb presentation, while the selected/earned starter flames
remain the source of Puzzle Color keys for route logic. Fusion palettes do not
silently become a new ordinary color-door key.

## Room completion and treasure

Room completion is not synonymous with reward collection.

- Enemy, Special Enemy, and Treasure Rooms become clear when all required enemies are defeated.
- Treasure chests may remain unopened after the room clears. Their contents are optional rewards, not exit requirements.
- Each Run 1 Treasure Room contains exactly one authored chest and placement.
- Special Enemy Rooms use the standard encounter roster and level curve. Their enemies respawn one slot at a time after roughly 45 seconds while the required puzzle color is not active; each slot's timer begins when that enemy dies, so respawns are naturally staggered. The required color suppresses the room, and switching away can make the remaining timers eligible again.
- Fire Rooms and the Cloaked Room use their own event completion rules.
- Orb Rooms become complete when their orb activation event succeeds.
- The Boss Room completes through the boss/settlement flow.

When a room becomes complete, the map-state owner may reveal any connections whose `hidden_until_clear` requirement is now satisfied. The fire-room branch in the mockup is the canonical example of a newly available entrance/path.

## Global environment color

`active_puzzle_color` is run state, not room-local puzzle state. It starts as Puzzle Color B, changes only when an Orb Room changes its shared orb, and persists while the run continues. A mixed elemental Orb charge sets the ordinary key to `neutral` while retaining its own shared presentation palette. The two identical Orb Rooms always reflect this same state. Puzzle Color B and the legacy neutral value resolve to grey environment presentation; Puzzle Color A resolves to the selected starter flame palette.

On room load, the room presentation applies the active puzzle-color state to the intended environmental surfaces. This should include the room's floor, wall, and door/entrance art that is meant to react to the map state. It should exclude the background layer, UI, actor sprites, collision guides, and hidden/unrendered surfaces unless explicitly included by the art direction.

The current room may update immediately after an orb change, but all future room loads must also apply the same state. Leaving and revisiting a room must not revert the environment to a room-local tint.

## Minimap presentation

The minimap should be a dedicated presentation component with no topology or progression ownership. It consumes:

- the authored dungeon layout;
- room visited/discovered/completed state;
- current room;
- effective connection state;
- `active_puzzle_color` (`neutral`, `puzzle_a`, or `puzzle_b`).

The first renderer should generate a 16×23 logical canvas using nearest-neighbor pixel cells. A `MinimapController` or `MinimapRenderer` should own the generated texture and update it when map state changes, room discovery changes, or the player changes rooms.

The initial visual pass should reproduce the mockup's room/connector placement and palette exactly. The base topology is progressively unveiled as the player unlocks/discovers rooms and connections; undiscovered portions remain hidden rather than showing the complete authored route immediately. Status overlays such as current-room cursor, visited state, and locked-door marks should be added only after the base map matches the reference.

The mockup remains the complete authoring reference, while the player-facing minimap is a progressive reveal of that topology. The exact distinction between “room unlocked,” “room entered,” and “adjacent connection discovered” is an implementation detail to lock during the UI pass.

## Current repository gap

The current project has:

- a deterministic branching `DungeonGraph` with coordinate-based rooms;
- `RoomController`-owned per-room dictionaries and socket configuration;
- a single current-room `door_active` / `entrance_open` flow;
- local two-orb `ROOM_PUZZLE` rooms and room-local tinting;
- combat-room chest support, but no authored Treasure Room category;
- no dedicated minimap renderer;
- an exact Run 1 authored topology and editable `basic_room.tscn` / `orb_room.tscn` room templates.

The new design should therefore add ownership around the graph and run-map state instead of expanding `gameplay.gd`. `GameplayState` should expose narrow compatibility calls while dedicated controllers own topology, gates, puzzle-color state, and minimap presentation.

## Authored Run 2 and generated Run 3+ layouts

Run 1 is the simplified authored teaching instance of a reusable dungeon
grammar. The former complex authored map is preserved intact as Run 2. Run 3
and later generate a complete `DungeonLayoutDefinition` from the run seed
before the player enters the dungeon; room entry must never create new topology.
The generated layout retains the same core beats while varying placement,
branches, and room variants:

- an early fork that rejoins;
- combat-gated main progression;
- two shared-state Orb Rooms before the corresponding color-gated choices;
- two Special Enemy Rooms whose forward routes carry the current progression
  requirement while their side Treasure routes remain deliberate grey
  (`puzzle_b`) detours;
- at least one Orb Room is placed off the main spine as an exploratory
  backtracking branch, with Treasure branches following the same side-route
  language;
- optional Treasure branches, Fire/utility rooms, one Cloaked Room, and a Boss;
- deterministic coordinates, socket pairs, route roles, clear requirements,
  engagement-entry locks, and color requirements for every connection.

### Four-way Hubs and reversible dig branches

The reusable grammar is not a one-way staircase. A Hub may expose all four
socket directions: upper-left, upper-right, down-left, and down-right. The
upper exits normally carry progression or a fork that later rejoins; lower
exits are well-suited to optional Combat, Treasure, Fire, or Orb dig branches.

Entering a Combat branch is deliberately scoutable. Arrival alone does not
engage the room, so the player can inspect it and retreat without starting the
fight. The first player hit engages the room and applies its entrance lock;
clearing the encounter restores the return entrance. This preserves combat
dead ends as intentional risk/reward choices while keeping backtracking safe.

Connections should carry explicit route roles such as `progression`, `fork`,
`dig`, `return`, `rejoin`, or `state_change`. A required backtrack should be
caused by a meaningful state change—usually an Orb or Fire room—not by an
unmarked missing forward edge. Every such route must retain a reachable neutral
return path so changing the global state cannot strand the player.

### Generated flame progression

Run 1 begins grey and has only the selected starter flame as its elemental
source. Authored Run 2 adds the first remaining primary flame in the canonical
`fire`, `water`, `electric` order; Generated Run 3 adds the final remaining
flame. The selected starter is skipped when choosing that order, so every file
eventually exposes all three primary flames without duplicating the starter.

Every generated Fire Room declares the exact flame it provides. A later map may
use `puzzle_c` for the first alternate flame and `puzzle_d` for the second, but
the generator must place a matching Fire Room on an already traversable route
before the first connection that requires that key. The player can return to a
reachable flame, swap the player palette there, and then use the matching
palette at an Orb Room to change the shared map state. Layout validation walks
room, active puzzle color, and acquired-flame states together; a layout is
rejected if any colored connection lacks a reachable matching Fire Room or if
the boss cannot be reached under those transitions.

The generator must validate reachability, socket uniqueness, boss accessibility
under valid orb-color changes, and the absence of impossible key cycles before
the layout is passed to `DungeonGraph.initialize_from_layout()`.

## Acceptance invariants

The design is considered correctly implemented when:

1. Run 1 reproduces the authored room categories, route branches, two selected Orb Rooms, and single Cloaked Room.
2. One centered orb exists in each Orb Room, and both orbs display the same current color.
3. Run 1 begins grey; changing either identical Orb Room orb changes one shared
   `active_puzzle_color` state to Puzzle Color A or Puzzle Color B, with A
   resolving to the selected starter flame and B resolving to grey. Grass, Ice,
   Ground, Shadow, and other valid elemental charges recolor the shared orb
   presentation and clear the ordinary Puzzle Color key.
4. Color-gated doors open only when their requirement matches that state, or
   when that individual door was already solved and latched.
5. Ordinary doors are not accidentally color locked.
6. Enemy defeat opens Treasure Room exits even if its single chest remains unopened.
7. Completed rooms can reveal their authored additional entrances.
8. The environment uses the global puzzle-color state rather than a local Orb Room tint.
9. The revealed portions of the minimap are pixel-identical in layout and palette to the mockup before status overlays are added.
10. The graph, runtime map state, room controller, and minimap can be tested independently of `gameplay.gd`.
11. Generated and future authored Hubs can expose all four socket directions with correctly paired arrival sockets.
12. Entering an uncleared Combat dig branch leaves its return entrance open until the first player hit engages the room; clearing it restores that entrance.

## Authoring prefabs

`scenes/basic_room.tscn` is the editable room shell. It includes the isometric floor faces, wall faces, both wall doors, both lower entrances, socket markers, and editor-only guide polygons. `scenes/orb_room.tscn` instances that shell and adds one centered six-frame `EntryOrb` with a grey initial-palette metadata contract. These scenes are authoring templates; runtime room assembly remains owned by the gameplay room controllers so art-position edits can be copied into the authored room flow deliberately.
