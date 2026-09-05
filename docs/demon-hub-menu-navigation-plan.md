# Demon Hub Menu Navigation Plan

## Goal

Make the Demon Hub root previews and nested SHOP, FUSION, and BIND menus behave like the authored Equipment menu: only the currently active menu owns a cursor, input, and detail presentation.

## Root hover previews

- Keep the shared Demon Hub shell visible while hovering a command.
- SHOP displays the BUY/SELL preview underneath it using the last BUY/SELL selection from the current hub session.
- The SHOP preview shows no shop cursors.
- BUY and SELL remain visually distinct: the selected label uses the normal text color and the inactive label is greyed out.
- FUSION and BIND show their preview content without nested route cursors or stale detail cursors.

## Cursor ownership

- A cursor is visible only when its corresponding menu depth has input focus.
- Root command focus owns only the shared command cursor.
- SHOP mode focus owns only the BUY/SELL cursor.
- SHOP item browsing owns only the item cursor.
- SHOP sell amount confirmation owns only the amount cursor.
- FUSION owns its item/action cursor only after entering FUSION.
- BIND owns its selection/action cursor only after entering BIND.
- Equipment remains the reference behavior: inactive depth cursors are hidden or locked as intentional breadcrumbs, never left active over another menu.
- Every route transition must stop motion and hide cursors belonging to the previous route before rendering the new route.
- Hidden cursors must use mouse-ignore behavior through their associated controls so they cannot intercept touch input.

## Command cursor alignment

- SHOP, FUSION, and BIND command cursors should derive their position from the rendered command text, using the same text-relative offset as STATS.
- Do not use independent hard-coded left offsets for these commands.
- Re-anchor the cursor after responsive layout changes without restarting its bob animation.

## Nested route behavior

- Confirming SHOP enters the BUY/SELL mode menu.
- Confirming BUY or SELL enters item browsing and transfers cursor ownership to the item list.
- Confirming SELL on an item enters quantity selection and transfers ownership to the amount cursor.
- BACK reverses one depth at a time, matching Equipment:
  - sell amount → item browse;
  - item browse → BUY/SELL mode;
  - BUY/SELL mode → hub root.
- FUSION and BIND follow the same enter, own, and back-out pattern.

## State and cleanup

- Preserve the last BUY/SELL selection while navigating within the open hub.
- Reset the selection to BUY when the entire hub closes.
- Returning to the root clears the selected stat row and selected item.
- Returning to the root hides stat comparisons, item details, transaction prompts, and all nested cursors.
- Root previews must not retain stale list selection, stat-change text, amount controls, or touch candidates.

## Implementation owners

- `screen_state_controller.gd`: visibility, preview rendering, cursor ownership, and responsive re-anchoring.
- `hub_flow_controller.gd`: route transitions, selection persistence, and back-depth behavior.
- `shop_menu_layout.gd`: authored SHOP presentation and local cursor visibility.
- `equipment_menu_layout.gd`: behavioral reference for nested cursor ownership.
- `tests/demon_hub_menu_scene_smoke.gd`: focused route, cleanup, cursor, and responsive assertions.

## Acceptance checks

- Hovering SHOP shows the correct BUY/SELL preview with no shop cursor.
- The inactive BUY/SELL label is greyed out.
- SHOP, FUSION, and BIND cursors sit beside their rendered command labels.
- No cursor remains visible after backing to the root.
- Root state has no stat-change or item-detail text.
- Nested SHOP navigation owns exactly one active cursor at each depth.
- BUY/SELL selection persists until hub close, then starts on BUY.
- Portrait/landscape changes preserve route state, cursor ownership, and cursor motion.

## Progress update — sell presentation and settlement

- Completed: sell rows now include the item's fusion level as a compact `F#`
  suffix, so fused gear remains identifiable in the sell list.
- Completed: selling fused gear refunds 50% of its fusion souls, rounded down
  to whole souls.
- Verified in code path: quantity selection hides SELECT/BACK and exposes only
  the SELL? quantity controls with YES/NO confirmation.
- Completed verification: focused diagnostics pass for ItemCatalog, hub
  presentation, ShopMenuLayout, and HubFlowController; `git diff --check` is
  clean.

## Full-menu audit — September 2026

### Current findings

- Pause Equipment is the correct navigation reference. It derives each cursor
  target from the rendered command text or active button geometry, keeps only
  the current depth animated, locks intentional ancestor breadcrumbs, and
  recomputes anchors without restarting motion after an aspect-ratio change.
- The Demon Hub command cursor now uses one shared offset, but SHOP still uses
  hard-coded targets for its top, BUY/SELL, item, and amount cursors. Those
  targets can drift away from the authored text and responsive touch rectangles.
- SHOP mode and item buttons are currently interactive only at the controller's
  active depth. That is correct for controller navigation but prevents the
  requested touch behavior: tapping BUY, SELL, or a visible item should jump
  directly to that route from anywhere inside SHOP.
- Shop finger scrolling currently relies on the hub-wide touch-scroll value.
  The authored Shop scene does not own drag recognition, does not distinguish a
  tap from a drag, and its row buttons can consume the gesture before the list
  receives it.
- Shop stock currently generates one random common item per equipment slot.
  Common rarity does not guarantee the `plain_*` definition, and
  `ensure_shop_stock()` returns immediately for existing stock, so neither new
  nor already-started runs guarantee a complete plain set.
- Tapping an item updates selection through `select_hub_item_row()`, but that
  path does not play `ui_hover`; controller movement does. Touch therefore lacks
  the normal cursor-movement feedback.

## Implementation plan

### 1. Normalize cursor geometry and ownership

- Add shared helpers for resolving a cursor from the actual rendered label or
  button rectangle, following `equipment_menu_layout.gd`.
- Replace SHOP's hard-coded mode and item cursor coordinates with anchors from
  `ModeBuyButton`, `ModeSellButton`, and the selected `ItemButton#`.
- Resolve the amount cursor from the active subtract/add/confirmation geometry
  instead of a standalone coordinate.
- Apply the same label-relative root command rule to STATS, SHOP, FUSION, and
  BIND. Preserve the current half-pixel hub-shell correction.
- Keep content previews visible for STATS, FUSION, and BIND while root focus owns
  the only active cursor. Entering a panel transfers cursor ownership; backing
  out stops and hides that panel's child cursor.
- On portrait/landscape changes, re-resolve every visible cursor from current
  geometry and preserve the active cursor's animation phase.

### 2. Separate controller depth from touch reachability

- Keep controller flow unchanged: command → BUY/SELL → item → sell amount.
- Keep visible SHOP touch targets enabled whenever SHOP is open, independent of
  controller depth. Their callbacks will explicitly change route state before
  acting.
- Tapping BUY or SELL at any SHOP depth immediately selects that mode and opens
  its item browser. A mode switch cancels an active sell-amount prompt, resets
  quantity to one, clears stale item confirmation, and preserves the selected
  mode for the current hub session.
- Tapping a visible item at any SHOP depth switches to item-browse state and
  selects that row. It must not immediately buy or sell; a second explicit tap
  or the action affordance performs the transaction, matching Equipment's safe
  touch-selection pattern.
- Tapping STATS, SHOP, FUSION, or BIND on the root command rail opens that menu
  directly and places its active cursor at the correct initial control.
- Route all touch transitions through `hub_flow_controller.gd`; the scene emits
  intent and does not mutate shared navigation state itself.

### 3. Add native finger scrolling to SHOP

- Give `ShopMenuLayout` a drag surface covering only `ListClip` and emit a
  signed scroll delta to the hub flow owner.
- Track press origin and accumulated movement so a drag never also activates a
  row. Use the same small drag threshold as the existing menu input layer.
- Clamp scrolling to `item_count - VISIBLE_ROWS`, update rows continuously, and
  retain the selected item even when it scrolls offscreen. A later tap moves the
  selection to the tapped visible row.
- Keep mouse-wheel/controller scrolling on the existing shared path and disable
  quantity changes from vertical list drags while SELL amount confirmation is
  active.
- Recompute responsive drag and row hit rectangles from the authored TSCN
  geometry so portrait and landscape use the same logical list bounds.

### 4. Guarantee basic shop stock

- Define a canonical basic item for each of the six equipment slots and add one
  deterministic shop entry for each slot on every run. Plain gear remains the
  player's starter equipment and is not sold in the shop.
- Keep the random common set, premium item, and Demon Cloak as additional stock;
  guaranteed basic gear does not replace the shop's variable offerings.
- Repair already-created run stock idempotently: convert legacy guaranteed plain
  entries to their basic equivalents, then append only missing basic slot
  entries. Preserve sold state, IDs, and existing stock order.
- Give guaranteed entries stable run-scoped IDs and normal catalog-derived
  prices so save/load and sold-state behavior remain deterministic.
- Because the expanded stock exceeds eight rows, verify controller, wheel, and
  finger scrolling all reach the final entry.

### 5. Unify interaction audio

- Play `ui_hover` once whenever a touch changes the selected command, mode, item,
  stat, fusion target, or bind target.
- Do not replay hover audio when tapping the already-selected control unless the
  tap advances/activates it; activation keeps `ui_confirm` or transaction audio.
- Keep `ui_no_input` for disabled amount changes and `ui_decline` for backing
  out. Ensure one gesture cannot trigger both hover and confirm sounds.

### 6. Focused verification

- Extend `demon_hub_menu_scene_smoke.gd` with cursor-anchor assertions against
  rendered labels/buttons at every depth and after two aspect-ratio changes.
- Add stock tests proving all six `basic_*` definitions exist exactly once in a
  fresh and a repaired nonempty shop stock, while starter inventory uses
  `plain_*` definitions.
- Add touch-route tests for direct command taps, BUY↔SELL switching from item and
  amount states, item selection sound, drag-without-tap, scroll bounds, and the
  last stock row.
- Verify STATS/FUSION/BIND previews remain populated at root with no child cursor,
  then gain exactly one active child cursor after entry. SHOP additionally keeps
  its mode/item touch hitboxes live at root for direct touch entry.
- Run MCP script diagnostics and the focused hub smoke only. Do not invoke the
  full smoke runner while the Godot editor peer is active.

## Completion order

1. Cursor anchors and ownership across the entire hub.
2. Direct touch route switching and interaction audio.
3. Shop-owned finger scrolling with tap/drag separation.
4. Guaranteed and repaired plain stock.
5. Focused automated checks plus direct editor scene inspection.

## Implementation progress

- Completed: SHOP cursor anchors now resolve from authored mode, item, and
  amount controls; hidden legacy SHOP coordinates are no longer used for those
  active cursors.
- Completed: visible SHOP mode tabs and item rows remain touch-reachable across
  route depths, and item taps play `ui_hover` through the hub flow owner.
- Completed: fresh shop stocks receive one stable basic item per equipment slot;
  legacy guaranteed plain entries are migrated idempotently, while variable
  common entries avoid duplicating guaranteed basic gear.
- Completed: the shared hub breadcrumb cursor remains visible on nested SHOP,
  FUSION, and BIND routes and resolves from the active command page instead of
  defaulting to STATS.
- Completed: root-hover previews for STATS, FUSION, and BIND keep their live
  content visible while suppressing nested cursors and controller ownership.
  SHOP follows the same rule while leaving its BUY/SELL and visible-item touch
  targets live for direct touch entry. Their responsive page geometry remains
  owned by the shared layout.
- Completed: removed SHOP's duplicate top cursor; the shared hub cursor is now
  the sole command breadcrumb. Nested breadcrumbs lock at the exact active
  anchor and all SHOP inner cursors map native geometry exactly once on resize.
- Completed: measured the authoritative `Mockups/DEMON HUB REWORK_SHOP_Buy.png`
  and Sell references directly. The native anchors are SHOP `(122, 5)`, BUY
  `(75, 26)`, SELL `(115, 26)`, and the first Buy item cursor `(9, 48)` (row 1
  in the exported mockup is `(9, 58)`). The shared command and BUY/SELL offsets
  now resolve to those pixels; item-list anchoring is unchanged because it
  already matched.
- Completed: `Mockups/.gdignore` was removed so the two authoritative Buy/Sell
  exports can actually be imported by Godot. The preview scene now references
  `Mockups/DEMON HUB REWORK_SHOP_Buy.png` and
  `Mockups/DEMON HUB REWORK_SHOP_Sell.png`, not the superseded artwork copies.
- Completed: SHOP's standalone editor preview can also be launched directly,
  and its cursor nodes start hidden in the production scene to prevent a
  one-frame duplicate before the live presenter assigns ownership.
- Completed: fixed the root SHOP render order. Preview mode is applied before
  rendering, so BUY/SELL mode text keeps the last selection, nested cursors are
  hidden at root, and a direct touch on BUY/SELL or a visible item enters the
  route cleanly.
- Completed: fusion now persists both its step count and exact soul investment.
  Enhanced legacy gear migrates to a visible `F#` sell entry, and selling uses
  50% of the recorded investment (with conservative reconstruction for old
  saves that predate the ledger).
- Completed: the editor console was cleared, the direct preview was reopened,
  and it started with zero warnings/errors after the reference-folder import
  fix. Per-file MCP script checks pass for the Shop presenter, preview,
  ScreenStateController, HubFlowController, and focused hub smoke.
- Completed: the editor scene tree was synchronized with the corrected command
  glyph anchors: STATS `(106, 8)`, SHOP `(139, 8)`, FUSION `(168, 8)`, and
  BIND `(206, 8)`. The direct SHOP preview then confirmed the authored cursor
  state: SHOP `(122, 5)` dim, BUY `(75, 26)` dim, selected item `(9, 58)`
  active, and amount cursor hidden.
- Completed: SHOP controller navigation now keeps the first eight rows fixed;
  selecting row nine is the first downward scroll step, and moving back above
  that boundary returns the window toward the top. Touch drags remain
  independent and scroll immediately with a fractional pixel offset, moving
  row visuals, hitboxes, and the active cursor together.
- Completed: after a sell, the list is rebuilt in place. The selected logical
  row and fractional window position are retained when possible, the cursor is
  re-anchored, and quantity/confirmation state returns to item browse.
- Completed: the shared top command cursor uses the Equipment-relative command
  gutter and keeps the normal three-pixel idle animation. The editor preview's
  static STATS breadcrumb uses the same resting anchor.
- Completed: menu touch hit regions now include a forgiving four-pixel gutter,
  choose the nearest overlapping row, and measure drag deltas in logical menu
  coordinates so portrait and landscape scroll at the same rate. A drag still
  cancels the pending tap before it can activate a row.
- Completed: fixed the hub stat visibility pass so its mixed `CanvasItem` list
  no longer calls typed `Array[Sprite2D].has()` with `Button` values. The
  visibility lookup now uses node instance IDs, eliminating the repeated
  validation error emitted during hub navigation.
- Verification note: the focused standalone SceneTree smoke was attempted, but
  Godot 4.7.1's headless renderer crashed before executing assertions. The
  console worker was stopped and the editor was left running. The full smoke
  runner remains intentionally out of scope while an MCP editor session is
  active; rerun the focused smoke under a supervised standalone process after
  disconnecting the MCP editor peer.
