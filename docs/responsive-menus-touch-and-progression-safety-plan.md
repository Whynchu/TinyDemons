# Responsive menus, touch preview, and progression safety

Status: Phases A–D (Demon Hub pass) implemented and verified; the remaining
menu migration continues in the next pass.

Plan date: 2026-09-01

Related contracts:

- [`equipment-menu-rework-plan.md`](equipment-menu-rework-plan.md)
- [`menu-ui-migration-plan.md`](menu-ui-migration-plan.md)
- [`modular-display-and-settings-plan.md`](modular-display-and-settings-plan.md)
- [`elemental-binding-and-fusion-design.md`](elemental-binding-and-fusion-design.md)
- [`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md)

This document records three decisions discovered while bringing the Equipment
menu to the same standard as Pause: wide-screen menu composition must distribute
its extra width, touch equipment selection needs a preview step, and generated
doors must be proven reachable from the player's actual elemental state. These
are shared product rules, not isolated Equipment fixes.

Where an older menu document says that a wide layout expands only its left
field while leaving authored content at its original x positions, the
responsive policy in this document supersedes that behavior. Native 240x160
geometry and the approved mockups remain authoritative.

## 1. Confirmed findings

### 1.1 Wide menus grow around left-clustered content

`EquipmentMenuLayout._apply_layout()` currently expands panel widths and moves
the bottom-right navigation panel, but most labels, icons, buttons, portrait,
slot columns, and cursors retain their native x coordinates. Pause likewise
anchors its command rail to the right while much of the authored content stays
fixed on the left. The frame is technically responsive, but the composition is
not: added width becomes empty space instead of useful spacing between groups.

### 1.2 Touch commits a candidate before its comparison can be read

The candidate grid already calculates and renders the correct preview snapshot
and green/red stat comparison. Keyboard and controller navigation expose that
preview before Confirm. A touch candidate press currently selects the candidate
and immediately invokes the equipment transaction, leaving no rendered frame in
which the player can inspect the comparison.

### 1.3 Generated-door validation assumes the wrong initial flame after Bind

Generated layout construction and validation receive `starter_flame`, while the
runtime map separately receives `bound_flame`. The reachability solvers seed
their state with the starter flame even when runtime begins the player as a
permanently bound fusion element.

This can approve an early starter-color requirement as reachable when a player
actually begins with ICE, GRASS, SHADOW, or GROUND and cannot reach the matching
starter Fire Room. The reported R12 ICE/WATER softlock is one manifestation of
that mismatch. Catalog availability is not proof of route reachability.

## 2. Non-negotiable behavior

### 2.1 Responsive menu contract

- The 240x160 mockup is the canonical composition and must remain pixel exact.
- Wider aspect ratios add horizontal space; they do not scale fonts, icons,
  cursors, borders, portraits, or other pixel artwork.
- Added width is distributed across the composition according to each authored
  element's relative horizontal position.
- Left-edge content moves little or not at all, centered content receives about
  half the extra width, and right-edge content follows the right edge.
- Panel rectangles map their left and right edges independently so their fill
  expands while their three-pixel borders remain intact.
- Repeated columns and grouped controls spread apart as a group; they must not
  remain piled against the native left edge.
- Final layout coordinates and hit rectangles are rounded to whole logical
  pixels.
- Visual nodes, cursors, and touch targets must all use the same resolved
  geometry.

The preferred shared mapping is an integer-pixel horizontal spread function:

```text
extra_width = max(view_width - 240, 0)
weight = clamp(native_x / 240, 0, 1)
resolved_x = round(native_x + extra_width * weight)
```

Named left, center, and right anchors remain appropriate for elements that are
semantically edge-bound. The proportional mapping is for preserving the visual
relationships inside a full-width composition. Layout owners may expose group
weights where an exact mockup relationship requires them, but must not introduce
one-off fullscreen offsets in controllers.

### 2.2 Touch equipment contract

- The first touch on a candidate moves the active selection to that item.
- That first touch renders its description, final bonuses, effective stat
  values, and green/red differences without changing the equipped item.
- A second touch on the same candidate commits the equipment transaction.
- Touching a different candidate moves the preview and arms that new candidate.
- Leaving the candidate grid, changing slots, pressing Back, committing an
  item, or reopening Equipment clears the armed touch candidate.
- Keyboard and controller retain their current navigation-then-Confirm behavior.
- Mouse behavior remains independent unless it is deliberately classified as
  touch by the input-device layer.
- The behavior is identical in Demon Hub Equipment and Pause Equipment.

The touch arm must use the absolute candidate index or stable item instance ID,
not merely the visible 2x4 cell, so scrolling cannot commit the wrong item.

### 2.3 Elemental progression safety contract

- Door safety is evaluated from the profile's actual run-start state.
- The initial current flame is the bound flame when a valid Bind exists;
  otherwise it is the starter flame.
- A globally unlocked or curriculum-available flame is not considered possessed
  until it is actually reachable on the current side of the gate.
- Reachability adds accessible Fire Rooms, current-element changes, valid fusion
  results, and Orb charges in the same order runtime permits them.
- Every mandatory color, current-element, and entrance-orb gate must have a
  satisfiable state on its source side before that gate is traversed.
- Optional routes may be restrictive, but may not contain a required resource
  needed to unlock the only critical route leading to them.
- A layout that cannot prove boss-route reachability is rejected or repaired
  before play begins.
- Existing generated-run saves receive the same validation during continue/load;
  safety is not limited to newly created runs.

## 3. Implementation plan

### Phase A — progression softlock prevention and recovery

1. Thread `bound_flame` through generated layout construction, validation, and
   their call sites in bootstrap/save flow.
2. Introduce one explicit run-start elemental-state builder shared by generation
   validation and recovery checks.
3. Update color and element reachability solvers to seed from the actual initial
   flame and discover only reachable Fire Rooms and fusion results.
4. Validate every required gate against its reachable source-side states.
5. Repair unsafe early gates deterministically. Prefer placing or exposing a
   prerequisite Fire Room; otherwise normalize the requirement to a reachable
   state without changing the seed's broader topology.
6. Run the validator on continued generated runs and apply the same deterministic
   repair before restoring the player to the map.
7. Add diagnostic output containing run, seed, starter, bound flame, gate, and
   missing prerequisite whenever a repair occurs.

This phase is first because it addresses a live progression-blocking defect.

### Phase B — touch candidate preview

1. Add a touch-only armed-candidate state to the Equipment interaction owner.
2. Route candidate button presses through a device-aware selection method.
3. On first touch, update the candidate index and redraw without committing.
4. On a second touch of the same armed candidate, use the existing transaction
   path so save, equipment recalculation, sounds, and cursor depth remain shared.
5. Reset the arm at every route boundary described in section 2.2.
6. Exercise the behavior in both Hub and Pause instances of the authored scene.

### Phase C — shared responsive menu geometry

1. Add a small shared menu-layout helper for proportional x spreading, semantic
   anchors, edge mapping, and integer rounding.
2. Keep native positions in scenes and mockup-facing layout constants. Resolve
   responsive positions only from those native values and the live logical size.
3. Migrate Equipment first: panels, title/command row, portrait/summary, slot
   columns, candidate columns, description/stat content, navigation prompt,
   cursors, and every Button rectangle.
4. Migrate Pause second: player information groups, command rail relationship,
   footer prompts, resources, child pages, and Equipment instance.
5. Recalculate on aspect changes, FULL window resize, and orientation changes.
6. Remove obsolete per-menu fullscreen offsets after their replacement is
   covered by tests.

### Phase D — menu-system migration

Use Pause and Equipment as the quality bar, then migrate:

1. Demon Hub root and its merged STATS/SHOP/FUSION/BIND command shell. The old
   Hub Status route is not exposed; Status remains a first-class Pause-menu
   destination alongside Equipment.
2. Shop, Fusion, and Bind.
3. Settings, save selection, title, game-over, and results screens.

Each migration includes authored native geometry, responsive group ownership,
finite cursor ownership, depth-aware Back, device prompts, touch semantics,
and focused smoke coverage. A menu is not considered migrated when only its
background fills the viewport.

## 4. Verification matrix

### Display and menu checks

- 240x160 native reference remains pixel exact.
- 256x160 and 284x160 distribute added width without fractional coordinates.
- FULL is checked at 4:3, 16:10, 16:9, ultrawide, and portrait-clamped windows.
- Live orientation changes recompute every panel, group, cursor, and hit target.
- Touch rectangles remain aligned with visible controls at every tested width.
- Reopening, changing pages, and switching aspect ratios leaves exactly the
  finite authored cursor set—no accumulated cursors.

### Touch equipment checks

- First candidate tap changes preview but not equipped instance ID.
- Preview renders effective values and the correct green/red/white comparison.
- Second tap on the same item commits it.
- Tapping A then B previews B and does not commit A.
- Back, slot change, scroll-window change, and reopen clear the armed item.
- Keyboard/controller Confirm remains single-confirm and unchanged.
- Hub and Pause produce the same transaction result.

### Progression checks

- Test every starter flame against no Bind and every valid bound flame.
- Cover early runs, the first fusion curriculum, R12, and later generated runs.
- Run a deterministic multi-seed matrix for every profile combination.
- Assert each mandatory gate has a reachable satisfying state on its source side.
- Assert the boss remains reachable without relying on a resource behind its own
  gate.
- Add a regression fixture for an ICE-bound R12 profile facing a WATER starter
  requirement.
- Test continue/load recovery for an already-created unsafe run.

## 5. Completion criteria

This plan is complete only when:

- the reported R12 profile can continue without abandoning the run;
- generated layouts cannot validate against a flame the actual player does not
  possess or cannot reach;
- touch players can inspect candidate comparisons before equipping;
- native Pause and Equipment remain faithful to their approved renders;
- wider formats use their available width as a balanced composition; and
- the responsive and interaction rules are reusable by subsequent menu work.

## 6. Implementation record

The current implementation covers the active Equipment/Pause and progression
scope described above:

- Phase A is landed in `dungeon_layout_generator.gd` and
  `dungeon_map_controller.gd`. Generated validation and recovery now receive
  the bound flame, seed their reachability state from the real run-start flame,
  repair unsafe mandatory color/Orb requirements deterministically, and leave
  optional Treasure color choices seed-owned. The R12 fixture covers all three
  starter flames, every valid elemental Bind (plus no Bind), and continued-run
  recovery.
- Phase B is landed in `hub_flow_controller.gd`, `screen_state_controller.gd`,
  and the shared Equipment scene path. Touch candidate presses preview first
  and commit on a second tap of the same absolute candidate in both Hub and
  Pause; route changes clear the arm.
- Phase C is landed in `menu_responsive_layout.gd`,
  `equipment_menu_layout.gd`, and `pause_menu_layout.gd` with controller-level
  wide-layout assertions. Native 240x160 coordinates remain authoritative,
  while wider logical views spread groups and hit rectangles on integer pixels.
- Focused verification currently passes:
  `GENERATED_LAYOUT_SMOKE_OK`, `GENERATED_FLAME_PROGRESSION_SMOKE_OK`,
  `ELEMENTAL_BINDING_SMOKE_OK`, `GENERATED_BOUND_REACHABILITY_SMOKE_OK`,
  `EQUIPMENT_MENU_SCENE_SMOKE_OK`, `PAUSE_MENU_SCENE_SMOKE_OK`,
  `DISPLAY_RESPONSIVE_SCENE_SMOKE_OK`, `GENERATED_RUN_SCENE_SMOKE_OK`, and
  `GENERATED_FUSION_GATE_SCENE_SMOKE_OK`.

The local Godot process may still print root-certificate and MCP registry lock
warnings; those are environment diagnostics and did not cause a test failure.
The next planned work is Phase D: migrate the remaining Hub, Shop, Fusion,
Bind, Settings, save, title, game-over, and results menus onto the same shared
responsive/cursor/touch contracts.
