# Tiny Demons — Engineering Friction Audit

Status: initial source-backed findings for the `0.2.x` baseline

Updated: 2026-09-11

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

This audit describes where the current project slows safe feature work. It is
an engineering prioritization document, not a deletion list. Measurements are
diagnostic; the goal is clear ownership, faster iteration, and preserved
behavior.

## Findings at a glance

| Finding | Evidence | Impact | Classification |
|---|---|---|---|
| Shared state and compatibility reach-ins | `gameplay_state.gd` is 1,703 lines; exact `root.call/get/set` scan finds 3,112 sites; metadata access appears at 224 sites | Renames and ownership changes can fail at runtime; dependencies are hard to see | Creates regression risk |
| Mixed menu/hub owner | `screen_state_controller.gd` is 5,333 lines with 147 functions | A visual or input change can affect unrelated routes; menu work is slow to localize | Slows content production; creates regression risk |
| Room responsibilities are broad | `room_controller.gd` is 2,060 lines and coordinates transition, layout, actors, state, persistence, and rewards | Adding a room or fixing a transition requires understanding unrelated lifecycle work | Slows content production |
| Dungeon generation has overlapping paths | Authored run layouts, `dungeon_layout_generator.gd` (1,629 lines), and compact puzzle-route generation coexist | Run scope and route contracts can be confused; fixes may land in the wrong generator | Creates regression risk |
| Content definitions are mixed between code and docs | Gear has a typed catalog; tuning is code-instantiated; rooms and encounters use several definition paths | Designers cannot follow one repeatable workflow for every content type | Slows content production |
| Test feedback is process-heavy | 121 test/report scripts exist; 113 are registered; many launch separate Godot processes | Full feedback is slow and renderer failures can obscure individual results | Slows content production |
| Verification is uneven across visual/device contracts | Touch, browser, orientation, cold-start audio, and visual cursor/layout behavior still need live evidence | Source and smoke status can overstate player-facing confidence | Creates regression risk |
| Rendering and startup hot paths need measurement | Per-pixel image loops and synchronous resource paths exist in minimap, effects, HUD, interaction, magic, occlusion, NPC, pickups, and guard areas | Low-resolution development can hide device-specific hitches | Creates regression risk |

## 1. Ownership and state

The project already has named feature controllers and an explicit frame
schedule. The friction is that many owners still reach back through the root for
state and behavior. `gameplay.gd` is relatively small at 245 lines, but it
inherits the much larger `gameplay_state.gd`, which acts as shared state bag,
compatibility API, and composition surface.

The first structural target should therefore be a vertical migration with a
clear command/result or signal boundary. A global conversion of reflective
calls would touch too many features at once and would make failures difficult
to classify.

Recommended evidence for each migration:

1. list the fields and calls owned by the feature;
2. add characterization for the player-visible path;
3. introduce a typed boundary;
4. migrate one consumer group;
5. compare reflective-call counts for that feature; and
6. remove compatibility wrappers only after their last consumer is gone.

## 2. Menus and presentation

The menu system has mature visual conventions but they are not yet represented
by one reusable interaction platform. Pause and Demon Hub are the reference
contracts for panel geometry, right-side command lists, cursor anchoring,
SELECT/BACK footer cells, clipping, responsive layout, and touch hit targets.

The safe order is:

1. characterize Pause and Demon Hub at native 240×160;
2. document the shared geometry and input contract;
3. extract one reusable visual/interaction primitive;
4. migrate one route while preserving controller callbacks;
5. compare keyboard, controller, mouse, and touch behavior; and
6. repeat only after scene parity is demonstrated.

`screen_state_controller.gd` should not be split by line count alone. Split by
route ownership and stable presentation boundary so each extracted piece has a
small, testable contract.

## 3. Room and dungeon content

Room entry currently combines transition locking, layout setup, actor spawning,
player placement, gameplay resets, room-state restoration, persistence, and
presentation. Generated routes also have both broad and compact generation
paths, while authored R1–R5 maps remain important pixel contracts.

The useful boundary is a typed room transition result containing room identity,
arrival socket, layout state, completion state, and transition outcome. A typed
spawn result should contain valid actor placement and any rejected placement
reason. These boundaries make the unreachable-slime bug and doorway geometry
issues observable without moving all room behavior at once.

Content additions should follow [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md):
authored maps and generated routes have separate workflows, stable IDs, and
different validation obligations.

## 4. Content authoring

The gear catalogue is the clearest current data boundary: stable base IDs,
instance serialization, source metadata, rarity, and future-effect gating are
documented. Other domains remain less uniform:

- elements have a stable catalog and matchup table;
- generated routes have typed plans and validators;
- authored room maps are distributed across run-specific scripts;
- enemy variants and tuning remain largely code-backed; and
- tuning classes expose fields but are instantiated directly in
  `gameplay_state.gd` rather than loaded as external resources.

The next useful improvement is a validated example for each common content
type, rather than an abstract universal framework. The example should answer
where the ID lives, how the runtime loads it, how a designer previews it, and
which test proves it.

## 5. Testing and verification

The repository has a substantial test/report surface: 121 GDScript files and
113 registered runner entries. That is useful coverage, but the inventory also
contains standalone reports outside the registry and tests whose target
identity still needs auditing.

Test evidence should state:

- the exact target scene/script/resource;
- whether the check is unit, source, scene, journey, visual, or performance;
- the result category: pass, assertion failure, script error, timeout, crash,
  skipped, unknown, or environment failure; and
- the version/commit and runtime mode used.

Group fast deterministic checks into shared-process suites where safe, while
keeping scene and visual checks isolated. The full runner remains a supervised
standalone operation when no MCP Godot runtime is active.

## 6. Performance

No timing baseline should be inferred from source inspection. The first useful
profile should measure four player-facing scenarios:

1. opening and browsing the Shop SELL list;
2. confirming a sale and rebuilding the list;
3. collecting the first flame and starting room music from a cold launch; and
4. opening/scrolling the minimap and equipment menus on a representative
   device or browser viewport.

Record frame time, allocation or loading spikes where available, inventory or
room size, device/browser, and cold/warm state. Optimize only after the hot
path is reproducible and the relevant exact-identity or visual contract has a
regression check.

## 7. Prioritized action

The current evidence supports this order:

1. finish documentation authority and classify current plans;
2. close the outstanding runtime evidence in [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md);
3. characterize shared menu conventions;
4. establish a typed room transition/spawn boundary;
5. migrate one feature away from root reflection;
6. validate one end-to-end content-authoring workflow; and
7. add repeatable timing scenarios and grouped test feedback.

This order keeps active player-facing contracts visible while reducing the
boundaries that make future content work risky.
