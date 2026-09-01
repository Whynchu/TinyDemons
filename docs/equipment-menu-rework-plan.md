# Equipment menu rework implementation plan

Status: implemented against the approved visual and interaction contract;
focused smoke coverage passes with the Godot headless runner

Plan date: 2026-08-31

Authoritative renders:

- [`../Mockups/EquipmentMenunotyetselectedequipment.png`](../Mockups/EquipmentMenunotyetselectedequipment.png)
  — slot-focus state: the action cursor is dimmed, the Weapon slot cursor is
  active, and the new 5x5 slot icons are visible.
- [`../Mockups/EquipmentMenuRender.png`](../Mockups/EquipmentMenuRender.png)
  — candidate-focus state: command and slot cursors are dimmed, the candidate
  cursor is active, the same 5x5 equipped-slot icon grid remains visible, and
  the lower panel is the 2x4 item list.

The current `EquipmentMenunotyetselectedequipment.png` supersedes the earlier
command-focus version of that filename. The command-focus state remains a
derived state in the interaction contract; the current renders establish the
slot-focus and candidate-focus pixel targets.

Related boundaries:

- [`menu-ui-migration-plan.md`](menu-ui-migration-plan.md)
- [`ffiii-inspired-stats-and-menu-implementation-plan.md`](ffiii-inspired-stats-and-menu-implementation-plan.md)
- [`gear-catalogue-spec.md`](gear-catalogue-spec.md)
- [`gear-catalogue.md`](gear-catalogue.md)

The two Equipment renders are the visual authority for this slice. Where an
older menu document describes a different Equipment composition, these renders
supersede that presentation detail. The gear catalogue, item effects, save
format, and equipment math remain governed by their existing owners.

## 1. Outcome

Replace the current procedural Demon Hub Equipment page with a scene-authored
240x160 page that matches the approved renders and preserves the existing gear
transactions.

The finished page must:

- use the pause menu's charcoal, eight-piece frame, title-tab, pixel-text, and
  nearest-neighbour visual grammar;
- use Equipment's own stacked-panel composition rather than the pause/hub
  command rail;
- keep the equipped summary visible at every Equipment interaction depth;
- show the highlighted equipped item's description and final item bonuses
  before the candidate list is opened;
- replace the description region with the compatible item list after a gear
  slot is confirmed;
- render the six new 5x5 slot icons at their authored 1:1 positions in the
  persistent equipped summary;
- preserve the command -> slot -> candidate navigation hierarchy;
- show the corrected bottom-right framed navigation cell with the active
  device SELECT/BACK button prompt;
- make the BACK half of that cell a touch-safe route Back target;
- leave a stationary cursor darkened by exactly the approved Aseprite
  brightness -50 treatment at every committed parent selection;
- keep only the current-depth cursor bright and bobbing;
- eliminate stale or duplicated cursor instances when switching Equipment,
  Shop, and other Hub routes or reopening a menu;
- require confirmation for Remove All; and
- remain usable by keyboard, controller, mouse, and touch at every supported
  logical width; and
- finish by exposing the same Equipment presentation from Pause through a
  separate, explicitly scoped Pause route.

## 2. Scope and non-goals

### In scope

- The transactional Equipment route opened from the Demon Hub.
- Exact native 240x160 scene geometry and responsive width behavior.
- Command, slot, candidate, and Remove All confirmation states.
- Equipped-item description and final-bonus presentation.
- The two-column equipped-slot and candidate layouts.
- Cursor locking, dimming, bobbing, and draw order.
- Direct touch targets scoped to the active Equipment depth.
- Focused and existing menu regression coverage.

### Out of scope

- Gear catalogue content, item balance, rarity odds, or enhancement formulas.
- Equipment save schema changes.
- Combat-stat calculation changes.
- Shop, Fusion, Bind, Status, Allocate, or the Demon Hub root layout. Shop's
  existing visual layout remains intact, but its cursor lifecycle is in scope
  for the shared stale-cursor fix.
- A general rewrite of `screen_state_controller.gd` or the full hub flow.

## 3. Visual contract

### 3.1 Native canvas and panels

The renders are authored at the canonical 240x160 logical resolution. Their
pixel positions are copied into one `equipment_menu_layout.gd` authority before
presentation code is connected.

The page contains five framed regions:

1. A split top row with the `EQUIPMENT` title tab on the left and the
   `EQUIP / REMOVE / REMOVE ALL` command row on the right.
2. An always-visible equipped-summary panel.
3. A dynamic panel that shows either the highlighted equipped item's
   description or the compatible-item grid.
4. A bottom item-stat strip, split at the native x=`159` boundary; and
5. A bottom-right navigation cell from x=`161` through x=`239`, separated by
   the two-pixel mockup gutter.

Every region uses `assets/artwork/frame 16x16.png` as an unfiltered
nearest-neighbour nine-slice. Stable geometry belongs to the scene and layout
script; dynamic text, item data, and cursor state do not.

At native resolution the authored frame stack is exact: the split top row is
`x=1..88` and `x=90..238`, `y=1..19` (the frame's three-pixel edge treatment
leaves the intended 15-pixel fill), with a two-pixel gutter before the summary
at `y=22..82`; the description is `y=85..131`; and the bottom strip is
`y=134..158`, split at `x=159` with the navigation cell beginning at `x=161`.

The native 240x160 render is the parity target. Wider logical modes stretch
panel widths and distribute the two content columns through layout anchors;
they do not scale the font, cursor, portrait, borders, or row pitch. Logical
height remains 160.

The navigation cell keeps its 78-pixel native width at wider logical widths and
right-anchors to the active canvas. Its prompt composes the current device's
SELECT and BACK face/button glyphs using the same pixel-art prompt builder as
the rest of the menu; it is not a second command rail.

### 3.2 Equipped summary

The summary panel remains visible in every state and contains:

- the existing player portrait at the mockup position;
- player name;
- the effective VIT, STR, DEF, AGI, INT, and MND summary in three two-row
  columns; and
- the six equipped slots arranged as a 2x3 grid:
  - left column: Weapon, Head, Body;
  - right column: Arm, Shield, Accessory.

An occupied slot displays the item's catalogue display name and enhancement
suffix. Rarity is expressed through the approved item color rather than a
rarity-letter prefix. An empty slot displays its slot name in the muted grey
used by `HEAD` in the approved render. It does not display `EMPTY`.

The grid position communicates the slot identity when an item is equipped.
Locked slots retain their current domain behavior and use the same muted visual
family without inventing a second layout.

### 3.2.1 Slot icons

The new slot-focus render adds one authored 5x5 icon before each equipped-slot
label. These are six distinct pixel symbols for Weapon, Head, Body, Arm, Shield,
and Accessory. They are not enlarged versions of the existing 16x16 pickup
sprites.

The icon cells remain exactly 5x5 logical pixels, use the menu palette, and are
drawn at 1:1 nearest-neighbour scale. Their native anchors are transcribed from
the render as the left-column/right-column pair at x=`66`/`149`, with row tops
at y=`50`, `60`, and `70`; the text begins immediately after the icon gutter.
The active 16x16 hand cursor sits to the left of the icon and must never be
replaced by or overlap it.

Icons are part of the persistent equipped summary: they remain visible during
slot focus, Remove slot-grid focus, and candidate browsing. The candidate list
must replace only the dynamic description region; it must never hide, scale, or
reposition the upper icon grid.

### 3.3 Dynamic description/list panel

Before a gear slot is confirmed, the dynamic panel shows the description of
the equipped item associated with the currently highlighted slot. The logical
slot selection is preserved while the command row has focus; Weapon is the
initial default when no previous slot selection exists.

If that slot is empty, the description panel is blank.

After a slot is confirmed while using Equip, the description content is
replaced—not overlaid—by the compatible-item list. The list is a 2x4 grid with
up to eight visible item instances. It uses catalogue display names,
enhancement suffixes, and rarity colors. A moving 2x4 window keeps the approved
geometry when more than eight candidates exist.

Candidate navigation uses up/down within a column and left/right between
columns. This intentionally replaces the current browse-state behavior where
left/right switches equipment slots; changing slots requires Back to the slot
grid.

Confirming a candidate equips it and returns to slot focus. The dynamic panel
then returns to the description of the newly equipped item.

### 3.4 Bottom item-stat strip

The bottom strip always belongs to the highlighted equipment instance. It does
not show the player's total stats and is not a before/after comparison panel.

- At command or slot depth, it shows the final bonuses of the highlighted
  equipped item.
- At candidate depth, it shows the final bonuses of the highlighted candidate.
- If the highlighted slot has no equipment, it is blank.

"Final bonuses" means the item instance's completed package after rarity and
enhancement are applied. The formatter must consume the same ItemCatalog APIs
used by runtime equipment (`bonuses`, item stat rates, and shield bonuses)
rather than reconstructing formulas in UI code.

Values use a compact, deterministic order:

`VIT, STR, DEF, AGI, INT, MND`, followed by approved item-local HP/rate and
shield Block/Armor values when present. Zero-value entries are omitted;
penalties keep their minus sign. The strip shows the item's own package, not a
player-dependent effective-stat delta.

## 4. Interaction state machine

Replace the overlapping Equipment booleans with one authoritative typed mode.
Compatibility accessors may exist during migration, but there must not be two
writable sources of Equipment depth.

```text
COMMAND
  EQUIP confirm ------> SLOT_EQUIP
  REMOVE confirm -----> SLOT_REMOVE
  REMOVE ALL confirm -> REMOVE_ALL_CONFIRM
  Back ----------------> DEMON_HUB_ROOT

SLOT_EQUIP
  Confirm occupied/empty slot with candidates -> CANDIDATE
  Confirm slot without candidates ------------> remain SLOT_EQUIP
  Back ----------------------------------------> COMMAND

CANDIDATE
  Confirm candidate -> equip, then SLOT_EQUIP
  Back -------------> SLOT_EQUIP

SLOT_REMOVE
  Confirm occupied slot -> remove it, remain SLOT_REMOVE
  Confirm empty slot ----> no mutation, remain SLOT_REMOVE
  Back ------------------> COMMAND

REMOVE_ALL_CONFIRM
  Confirm -> remove all equipped items, then COMMAND
  Back ----> cancel without mutation, then COMMAND
```

Entering Equipment starts in `COMMAND` on Equip and preserves/defaults the
logical slot selection to Weapon. Equipping or removing refreshes the equipped
summary, description, bottom bonus strip, runtime equipment snapshot,
transmutations, health-preserving derived values, and saved profile through the
existing transaction path.

`SLOT_EQUIP` is the state shown by
`EquipmentMenunotyetselectedequipment.png`: the command cursor is locked and
dimmed, the selected slot cursor is bright and bobbing, the six 5x5 slot icons
are visible, and the selected equipped item's description and final bonuses
remain in the lower panels. `CANDIDATE` is the state shown by
`EquipmentMenuRender.png`.

Only the active state accepts directional, Confirm, mouse, or touch input.
Hidden and parent-depth Buttons use `MOUSE_FILTER_IGNORE` so a stale target
cannot consume input.

## 5. Cursor contract

Equipment uses separate cursor instances for command, slot, candidate, and the
Remove All confirmation underlay.

- The active cursor uses `assets/artwork/cursor.png`, remains bright, draws
  above every Equipment child, and runs the existing horizontal bob.
- Confirming a parent selection freezes that cursor at its selected target and
  applies the exact Aseprite brightness -50 appearance.
- A locked cursor does not bob or tween.
- Back removes the deepest cursor, restores the parent cursor to full
  brightness, and restarts its bob without changing the selected row.
- Slot focus therefore shows a dim locked command cursor and one bright
  bobbing slot cursor, matching the new
  `EquipmentMenunotyetselectedequipment.png` render.
- Candidate depth therefore shows a dim locked command cursor, a dim locked
  slot cursor, and one bright bobbing candidate cursor, matching
  `EquipmentMenuRender.png`.

If CanvasItem modulation does not reproduce the approved -50 pixels, add one
deterministically derived `cursor_dim.png` runtime asset and record its source.
Do not accept a merely approximate grey cursor.

Remove All uses the Final Fantasy-style armed state:

1. The first Confirm leaves a stationary brightness -50 cursor locked at
   Remove All.
2. A separate bright cursor continues bobbing over that locked position.
3. Back removes the underlay and returns to normal command focus.
4. A second Confirm executes Remove All.

The bright cursor always has the higher draw order so both layers reproduce
the approved effect.

### 5.1 Cursor lifecycle invariant

The existing Hub item page creates separate list, slot, and choice cursor
sprites on one shared page. Its update branches can leave a cursor from the
previous Shop or Equipment depth visible, and repeated route construction can
create another set of cursor nodes. The result is the reported stack of
cursors.

The rework must establish one shared cursor-layer owner for Hub menu routes:

- cursor sprites are constructed once per overlay/scene, never during a render
  or page update;
- entering Shop, Equipment, or another Hub child route first clears every
  cursor not owned by the new route and stops its bob tween;
- each render declares the complete expected cursor set for that depth instead
  of toggling only the cursor it happens to use;
- hidden page roots never retain visible cursor children;
- closing and reopening Hub is idempotent and does not increase cursor-node
  count;
- Shop has at most one bright list cursor; Equipment has at most one bright
  cursor per active depth plus the intentional Remove All underlay; and
- the shared `menu_cursor.gd` API can freeze, dim, hide, and restart a cursor
  without leaving a live tween behind.

The cursor-layer owner may be a small shared `menu_cursor_layer.gd` helper or a
scene-authored cursor layer with the same typed API. The choice must keep
Equipment's breadcrumb cursors and Shop's single list cursor on one lifecycle
boundary rather than adding route-specific cleanup branches.

## 6. Ownership and file changes

### Scene and layout ownership

Add:

- `scenes/equipment_menu.tscn` — stable five-panel geometry, named text/image
  anchors, Buttons, clips, and cursor layer.
- `scripts/equipment_menu_layout.gd` — canonical 240x160 positions and
  responsive-width calculations.
- `scripts/equipment_menu_preview.gd` — editor-only sample binding that
  reproduces the two approved states without creating runtime preview nodes.
- `assets/artwork/equipment_slot_icons.png` (or six equivalent 5x5 tracked
  textures) — authored Weapon/Head/Body/Arm/Shield/Accessory symbols with
  palette provenance and no runtime scaling.

Instance the Equipment scene as a dedicated Demon Hub child page. Stop sharing
the current generic `HubItemsPage` presentation with Shop and Fusion;
Shop/Fusion keep their existing container and behavior.

### Presentation ownership

Add a narrow `equipment_menu_presenter.gd` if binding the named anchors would
otherwise add another large block to `screen_state_controller.gd`. It may own:

- equipped-slot labels and colors;
- player stat-summary text;
- description wrapping;
- final item-bonus formatting;
- candidate-window population;
- active/locked cursor presentation; and
- depth-specific Button visibility and hit testing.

It must not mutate the profile, equip items, remove items, save, or calculate
new combat formulas.

### Flow and domain ownership

`hub_flow_controller.gd` remains responsible for Equipment transitions and
profile mutations. Reuse the existing equip/unequip, equipment refresh,
transmutation refresh, save, and sound paths. Add the typed Equipment mode and
Remove All armed transition there rather than teaching the scene about domain
transactions.

`screen_state_controller.gd` composes the scene, holds the presenter reference,
and forwards the current view model. Old procedural Equipment anchors and
position writers are deleted only after scene parity and regression coverage
are green.

`menu_cursor.gd` gains a small explicit active/locked API so freezing and
restarting the bob is owned by the cursor rather than by competing tweens in
the screen controller.

Add the shared cursor-layer lifecycle boundary described in §5.1. It owns
construction, route reset, complete-depth visibility, tween cancellation, and
idempotent teardown for both Equipment and Shop.

## 7. Responsive and touch behavior

At 240x160, every authored anchor must match the renders. At 256x160, 284x160,
and live FULL widths:

- the four primary frames fill the active logical width and the bottom-right
  navigation frame remains right-anchored;
- the title tab retains its native width;
- the command row consumes the remaining top width;
- the portrait and left content anchors retain their native margins;
- the right equipped/candidate column follows the layout script's right-side
  anchor;
- text and cursors remain on integer coordinates; and
- clipping prevents long item names from entering the adjacent column.

Each visible command, slot, and candidate receives a full-cell touch Button.
Only Buttons belonging to the active interaction depth are enabled. Touching a
candidate selects and confirms that exact candidate through the same command
path as controller Confirm.

The corrected native mockup contains a permanent bottom-right navigation cell.
Its SELECT/BACK prompt is visible at every Equipment depth, including Pause's
shared view. The BACK half is an invisible, nearest-neighbour touch
Button that invokes the same nested Back callback as keyboard/controller
Cancel; it never exposes inactive Hub controls or mutates the profile.

## 8. Ordered implementation

### Phase 1 — Contract characterization

1. Add a focused Equipment menu smoke test before removing current behavior.
2. Characterize the existing equip, remove, save, and nested Back mutations.
3. Characterize Shop -> Equipment -> Shop and repeated Hub open/close cursor
   lifecycles, including node count and visible-cursor expectations.
4. Record the new 5x5 icon cells, their slot mapping, and native anchors in
   `equipment_menu_layout.gd`.
5. Record the mockup's native panel and content coordinates in
   `equipment_menu_layout.gd`.
6. Record the corrected x=`159` stat split, x=`161` navigation panel, prompt
   anchor, and touch Back target from the newest render.
7. Add test fixtures for an occupied Weapon, empty Head, enhanced item,
   penalized item, shield, and more than eight candidates.

Exit: old behavior is covered and the new visual/state requirements fail for
the expected reasons.

### Phase 2 — Scene-authored visual shell

1. Build `equipment_menu.tscn` with the framed regions and named anchors.
2. Instance it as the dedicated Hub Equipment page.
3. Add the editor preview with both approved sample states.
4. Add the six 5x5 slot icons and map them to the six fixed slot positions.
5. Implement native and responsive layout constants.
6. Add the split bottom navigation cell, device prompt, and touch Back target.
7. Remove Equipment's dependency on the generic Shop/Fusion page geometry.

Exit: the editor preview matches both 240x160 renders with no runtime data.

### Phase 3 — Dynamic item presentation

1. Bind portrait, name, and effective six-stat summary.
2. Bind the 2x3 equipped grid, including muted empty slots and the six 5x5
   slot icons, and keep that grid visible while candidates are browsed.
3. Bind equipped-item descriptions and blank empty-slot behavior.
4. Add the final item-bonus formatter using ItemCatalog results.
5. Populate the 2x4 moving candidate window and active touch targets.

Exit: occupied, empty, enhanced, penalized, shield, and overflow fixtures all
render the correct description/list and item-local final bonuses.

### Phase 4 — Flow and cursor hierarchy

1. Introduce the authoritative typed Equipment mode.
2. Route Equip through command -> slot -> candidate.
3. Route Remove through command -> slot -> second-confirm removal.
4. Add the armed Remove All confirm/cancel state.
5. Implement active versus locked cursor behavior and exact -50 brightness.
6. Update Back to unwind one Equipment depth at a time.
7. Make mouse/touch Buttons invoke the same transitions.
8. Keep the navigation-cell Back target active in Pause's shared Equipment
   view.

Exit: every state and reverse transition matches the contract, only the active
depth accepts input, and cancelled actions never mutate the profile.

### Phase 5 — Responsive parity, cursor cleanup, and cleanup

1. Verify 240x160 pixel placement against both renders.
2. Verify 256x160, 284x160, and live FULL layout behavior.
3. Remove superseded procedural Equipment nodes, arrays, and position writers.
4. Exercise Shop -> Equipment -> Shop and repeated Hub open/close transitions;
   verify cursor-node counts, visibility, brightness, and tween ownership stay
   stable.
5. Update the menu migration and FFIII-inspired implementation documents.
6. Run focused tests, then the project verification gate appropriate to the
   active Godot environment.

Exit: the new scene is the only Demon Hub Equipment presentation owner and no
old hidden control can receive input.

## 9. Verification

### Focused automated coverage

Add or update coverage for:

- exact native panel bounds and named scene anchors;
- corrected x=`159` stat split, x=`161` navigation panel, and device prompt;
- 2x3 slot order and muted `HEAD` presentation for an empty Head slot;
- six slot icons are exactly 5x5, mapped to the correct slot, filtered nearest,
  and positioned at the supplied native anchors;
- command-depth occupied-item description and final bonuses;
- slot-focus state matches the new render: dim command cursor, bright slot
  cursor, icons, description, and final bonuses;
- candidate-focus state preserves the same icon grid while replacing only the
  description region with the 2x4 candidate list;
- blank description and stat panels for an empty highlighted slot;
- description panel replacement by the 2x4 candidate list;
- candidate final bonuses using rarity and enhancement;
- more-than-eight-candidate windowing and cursor visibility;
- command -> slot -> candidate -> slot transitions;
- Remove second-confirm semantics and empty-slot no-op;
- Remove All first-confirm arm, Back cancel, and second-confirm mutation;
- locked cursors frozen at brightness -50 and only one bobbing active cursor;
- Back unwinding candidate -> slot -> command -> Demon Hub;
- active-depth-only mouse/touch targets;
- navigation-cell Back invokes nested Equipment Back and Pause-page Back;
- no profile mutation on browsing or cancellation;
- profile/runtime refresh after equip/remove; and
- responsive integer placement at every supported logical width.

Primary regression files:

- add `tests/equipment_menu_scene_smoke.gd` for focused visual/state coverage;
- update `tests/six_stat_menu_scene_smoke.gd` to remove the superseded
  vertical-list/stat-comparison assumptions;
- update `tests/demon_hub_menu_scene_smoke.gd` for the dedicated Equipment
  child scene;
- update `tests/menu_route_scene_smoke.gd` for Equipment's nested depth;
- update `tests/fusion_tooltip_smoke.gd` where it currently assumes Equipment
  shares the Shop/Fusion controls; and
- add Shop -> Equipment -> Shop and repeated Hub open/close cursor-count checks;
- extend responsive and touch smoke coverage only where the focused scene test
  cannot exercise the real route.

### Manual parity checklist

- Compare the command-focus state with
  `EquipmentMenunotyetselectedequipment.png` at native resolution.
- Compare candidate focus with `EquipmentMenuRender.png` at native resolution.
- Confirm only the active cursor bobs; locked cursors remain pixel-still.
- Confirm locked-cursor brightness matches the Aseprite -50 reference.
- Switch repeatedly between Shop and Equipment and reopen the Hub; confirm no
  cursor sprites accumulate and no hidden route cursor remains visible.
- Confirm all six 5x5 slot icons retain their exact palette, 1:1 scale, and
  spacing from the updated slot-focus render.
- Confirm the bottom-right navigation cell remains at the corrected split and
  its BACK touch target unwinds one route depth without mutation.
- Highlight occupied, empty, enhanced, penalized, and shield slots.
- Exercise Equip, Remove, Remove All confirm, Remove All cancel, and every Back
  transition using keyboard, controller, mouse, and touch.
- Check long catalogue names, `+10` suffixes, rarity colors, and candidate
  overflow.
- Check fixed 3:2, 16:10, 16:9, and live FULL widths without fractional text or
  cursor placement.

When a Godot editor peer is active, use MCP scene inspection, diagnostics,
playtests, screenshots, and runtime logs. Run the standalone full smoke runner
only as the supervised gate described in `AGENTS.md`.

## 10. Final phase — Pause Equipment integration

After Demon Hub parity and cursor cleanup are complete, expose the Equipment
presentation from the Pause menu through its own route. This is deliberately the
last phase so Pause does not become a second source of Equipment state while the
Hub contract is still moving.

1. Keep Pause and Hub as separate overlay instances and separate route state.
2. Reuse the Equipment scene/presenter in an explicit Pause mode rather than
   toggling Hub controls or sharing mutable Button collections.
3. Carry over the equipped summary, 2x3 slot grid, highlighted-item
   description, final item-bonus strip, six 5x5 slot icons, empty-slot
   treatment, and cursor rendering.
4. Pause Equipment reuses the shared Equipment presentation with the same
   live transaction flow as the Demon Hub: Equip, Remove, and the armed
   Remove All confirm operate identically while paused. This replaces the
   earlier read-only Pause rule; the migration deliberately shares the Hub
   mutation callbacks rather than building a second read-only equipment path.
5. Make Pause Back return to the Pause command page, with no Hub overlay left
   visible and no cursor or tween carried across the overlay boundary.
6. Add Pause-specific scene and route assertions, including cursor cleanup and
   the presence of the shared transaction callbacks.

Pause exit evidence:

- Pause Equipment reproduces the shared Equipment presentation with its own
  full-screen page root;
- Hub and Pause never show simultaneously;
- Pause input can equip, remove, and arm Remove All through the same route as
  the Demon Hub;
- Back restores Pause only; and
- opening and closing Pause repeatedly does not add cursor nodes.

## 11. Completion criteria

The slice is complete when:

- both approved renders can be reproduced by the scene at 240x160;
- the description/list and final-bonus panels follow the highlighted item at
  every depth;
- empty slots and empty lower panels match the approved treatment;
- Equip, Remove, and confirmed Remove All preserve profile/runtime behavior;
- the cursor hierarchy and -50 locked state are exact;
- touch and controller routes agree;
- responsive modes preserve the native pixel composition; and
- focused regressions plus the appropriate full verification gate pass with no
  hidden stale Equipment controls or accumulated Shop/Equipment cursors;
- Pause exposes the same Equipment presentation through its isolated final
  route; and
- Pause/Hub overlay and cursor ownership remain mutually exclusive.
