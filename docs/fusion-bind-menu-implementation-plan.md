# Fusion and Bind Menu Implementation Plan

Status: Fusion presentation gate accepted; Bind not started.

## Follow-up correction log — 2026-09-05

- Removed the duplicate hub-shell Fusion footer layer; the Shop-derived Fusion
  footer is now the sole visible footer on that route.
- Grouped matching Fusion candidates by definition and rarity, while separating
  displayed unequipped ownership from usable material capacity.
- Expanded the authored Shop row capacity to 11 and reflowed Fusion panels,
  clipping, and stat rows upward into the removed mode-strip space.
- Added duplicate-copy regression coverage and revalidated the changed scripts.
- Follow-up verification: MCP preview confirms the expanded panel geometry and
  single Fusion footer; standalone candidate smoke remains blocked by the
  known local Godot headless renderer crash.
- Input/layout correction: shared direction input now supports initial-plus-hold
  repeat, list snapping waits until the final visible row, and Fusion cursor
  anchors follow its shifted list origin. Amount-state ownership visibility is
  explicit to prevent `OWNED` from persisting under `FUSE?`.
- Scroll symmetry correction: controller list windows now remain fixed while
  moving within the visible rows in either direction, scrolling only after the
  selection crosses the bottom or top edge.

## Progress log

- Added persistent Fusion and Bind scene entry points to the hub shell.
- Added typed model boundaries and dedicated `@tool` layout scripts.
- Migrated Fusion and Bind rendering away from the legacy presenters.
- Added explicit preview/target/amount and preview/action route state handling.
- Preserved existing profile transaction owners and fusion/bind rules.
- Focused MCP script diagnostics pass for the new layouts and both integration owners.
- Fusion correction recorded: adopt Shop's two independent body panels and
  comparison layout; remove the redundant selected-name panel, row greying, and
  duplicate FUSE action presentation. Use Shop's OWNED/FUSE? quantity band and
  Souls icon treatment.
- Remaining gate: run focused hub scene/playtest verification of the populated
  Fusion states.
- Implementation checkpoint: Fusion now instances `shop_menu.tscn` and its
  layout subclasses `ShopMenuLayout`, reusing the persisted two-panel body,
  ten-row Fusion list (Shop remains eight rows), comparison nodes, currency nodes, footer, and responsive
  metadata. The standalone Fusion scene boots cleanly through MCP. Rendering
  data migration remains in progress; the visual acceptance checklist is not
  yet complete.
- Data/rendering checkpoint: Fusion now feeds Shop's row currency nodes,
  `OWNED` count, structured six-stat comparison data, and projected fused
  rarity/enhancement values. Shop's transparent confirm hitbox is reused for
  Fusion action confirmation. Runtime and script diagnostics remain clean;
  focused visual and interaction acceptance is still pending.
- Structural checkpoint: registered `fusion_menu_scene_smoke.gd`; its script
  diagnostics pass. Standalone execution is currently limited by the local
  Godot headless renderer crash, so this gate is retained for supervised runs.
- Populated visual checkpoint: MCP preview of the real Fusion presenter confirms
  independent Shop panels, rarity-colored rows, inline Soul icons, six aligned
  comparisons, `OWNED: x`, and one shared `FUSE / BACK` footer.
- Amount visual checkpoint: MCP preview confirms `FUSE?` beside the existing
  minus / quantity / plus controls and the quantity cursor in the authored
  footer lane.
- Interaction checkpoint: the focused scene smoke now exercises the inherited
  row, quantity, confirm, and back signals; script diagnostics pass. Its
  standalone process remains subject to the known Godot headless crash.
- Hub integration checkpoint: `fusion_tooltip_smoke.gd` now asserts the live
  controller selects the dedicated Fusion presenter, renders its owned/currency
  nodes, suppresses the legacy detail presenter, and remains authoritative
  after visiting Shop. Script diagnostics pass.
- Live interaction checkpoint: MCP click-through on the authored plus control
  changed the amount from `2` to `3`, recomputed the selected row cost, and
  disabled the control at the maximum. Browse and amount presentation gates
  are now visually accepted; only standalone headless smoke execution remains
  environment-limited.

## Goal

Upgrade Fusion and Bind to the authored, responsive, cursor-driven style already
used by Equipment, Stats, and Shop without changing fusion, salvage, binding,
soul, or profile rules.

The finished menus must be editable in the Godot editor, support controller and
touch input, preserve state across aspect-ratio changes, and contain no legacy
duplicate presenters or cursor layers.

## Non-goals

- No new gear rules, fusion costs, binding costs, or element rules.
- No redesign of the existing Shop, Equipment, or Stats menus during this pass.
- No main-menu navigation for verification.
- No broad rewrite of `gameplay.gd` or the explicit frame schedule.

## Ownership

| Responsibility | Owner |
| --- | --- |
| Route selection and back behavior | `hub_flow_controller.gd` |
| Fusion candidate cache and transactions | `hub_flow_controller.gd`, `PlayerProfile` |
| Bind availability and transaction | `hub_flow_controller.gd`, `PlayerProfile`, `PlayerChromaComponent` |
| View construction and pixel geometry | `fusion_menu_layout.gd`, `bind_menu_layout.gd` |
| Route rendering and view-model assembly | `screen_state_controller.gd` |
| Responsive mapping | Existing display/layout helpers and each layout script |
| Input merge and device detection | Existing `input_router.gd` and `touch_controls_layer.gd` |

`screen_state_controller.gd` selects and renders views. It must not become the
owner of child positions, cursor tweening, or transaction mutation.

## Shared visual contract

Both scenes are authored at `240x160` logical pixels.

- Nine-patch frame panels use the existing 16x16 frame artwork.
- Pixel text remains separate from icons, values, and controls.
- All numeric values are integer-formatted and right-anchored.
- Existing 5x5 equipment icons and 5x5 minus/plus artwork are reused.
- Footer glyphs and native positions match Shop. Fusion labels the shared
  confirm action `FUSE`; Bind retains `SELECT`.
- A command cursor is active only at the top route level.
- A child cursor is active only while that child route owns input.
- Parent cursors become dimmed, frozen breadcrumbs.
- Hidden cursors are stopped, not merely made invisible.
- Touch targets are generous transparent controls aligned to the authored scene.
- Rotation reflows native coordinates without resetting route, selection, count,
  message, scroll, or cursor animation phase.
- Transaction-menu geometry is reused from Shop rather than independently
  approximated. Equivalent nodes use the same native positions, clipping,
  right anchors, row pitches, footer anchors, and responsive metadata.

## Fusion design

Fusion should be a dedicated `scenes/fusion_menu.tscn` with
`scripts/fusion_menu_layout.gd`.

### Authored structure

Fusion is a Shop-derived transaction view with the Buy/Sell route removed. Its
scene must reuse `shop_menu.tscn`'s authored body structure, either by inheriting
the Shop scene or by using a shared authored transaction-menu base extracted
from Shop. A separate runtime-generated reconstruction is not acceptable.

The scene contains:

1. The same independent left list box and right stat-comparison box as Shop.
2. Shop's clipped target list expanded to ten reusable Fusion rows.
3. A slot icon, rarity-colored name, fusion level, equipped marker, and inline
   soul cost per row.
4. Shop's exact six-row stat comparison: label, current value, `>`, projected
   value, fixed right anchors, and increase/decrease colors.
5. A browsing footer that shows `OWNED: x` in Shop's lower-left anchor.
6. An amount footer that replaces `OWNED: x` with `FUSE?` followed by the
   existing minus / quantity / plus controls at Shop's sell-amount anchors.
7. The shared Hub footer action relabeled `FUSE`, plus the existing BACK action.
   There is no second visible FUSE button or independent footer.
8. Dedicated transparent touch buttons for rows, quantity controls, FUSE, and
   BACK.
9. Cursor nodes for target selection, quantity selection, and confirmation/action.

The scene must not contain:

- a Buy/Sell mode panel or mode cursor;
- a redundant selected-item name/header;
- a selected-item detail box nested inside either body panel;
- free-form stat strings in place of Shop's comparison columns;
- separate `MATERIALS` or `COST` summary labels;
- textual `SOULS` suffixes; or
- row-wide grey modulation for unselected or unavailable items.

Selection is communicated by the cursor. Item names always retain their rarity
colors. Disabled transactions affect action availability and status copy, not
the item-row color.

Each visible target row displays its one-material fusion Soul cost in Shop's
currency lane: a right-aligned integer amount followed by
`SoulVisuals.texture()`. In `FUSION_AMOUNT`, the selected row updates to the
current batch total while all other rows retain their one-material costs. The
amount and icon are separate nodes, and no `COST`, `MATERIALS`, or `SOULS` word
is rendered.

### Fusion states

| State | Display | Input |
| --- | --- | --- |
| Preview | Two Shop-derived body panels and browsing footer; no child cursor | Confirm enters target list |
| Target list | Ten-row list, inline costs, selected comparison, `OWNED: x` | Up/down changes target; confirm enters amount or salvage confirmation |
| Quantity | Same panels; lower band becomes `FUSE?  -  x  +` | Left/right changes count; confirm performs the existing transaction |
| Result | Same panels with success/error status; no geometry replacement | Confirm returns to target browsing; Back returns one depth |
| Empty | Empty-state message and disabled action | Back exits |

The route is mandatory and explicit:

```text
COMMAND_PREVIEW -> TARGET_BROWSE -> FUSION_AMOUNT -> RESULT
```

Overflow salvage may replace `FUSION_AMOUNT` with a confirmation/result step
because it has no quantity. A target with neither fusion materials nor overflow
salvage remains visible with its rarity color, but its action is disabled.

### Fusion view model

The controller sends:

```text
state
rows[]
selected_row
scroll_fraction
stat_comparison[]
owned_count
fusion_count
fusion_count_max
can_fuse
can_salvage
message
```

Each row contains the existing `ItemInstance` identity, display name, slot,
rarity color, enhancement level, equipped state, one-material soul cost, and
action availability. The selected row's rendered cost may be replaced by the
current batch total in amount state. `stat_comparison[]` uses Shop's exact dictionary
contract: `label`, `before`, `after`, `before_color`, and `after_color`.
`owned_count` is the number of matching fusion materials available for the
selected target. The layout does not query or mutate the profile.

## Bind design

Bind should be a dedicated `scenes/bind_menu.tscn` with
`scripts/bind_menu_layout.gd`.

### Authored structure

The scene should contain:

1. A full Bind information panel.
2. CURRENT element row.
3. BOUND element row.
4. SOULS and COST rows.
5. A fixed status/message row.
6. A BIND action button.
7. Shared SELECT/BACK footer controls.
8. Transparent touch regions for the action and back route.
9. One command cursor and one action cursor, never two active cursors at once.

### Bind states

| State | Display | Input |
| --- | --- | --- |
| Preview | Current/bound data and status visible | Confirm enters BIND action |
| Action | BIND is highlighted and actionable if valid | Confirm attempts bind |
| Unavailable | Same panel, disabled action, explanatory status | Back exits |
| Result | Same panel with updated bound element/status | Back returns to hub |

The panel remains visible in every state. Only cursor ownership, action
highlighting, and touch activation change.

### Bind view model

The controller sends:

```text
current_element
current_is_bound
bound_element
soul_count
bind_cost
can_bind
status_message
action_label
action_color
```

`PlayerProfile.bind_element()` and `PlayerChromaComponent.set_bound_flame()`
remain outside the layout script.

## Implementation phases

### Phase 1 — Characterization and seams

1. Add focused tests around the existing Fusion and Bind transactions.
2. Record current route behavior: entering, backing out, empty state, disabled
   state, successful mutation, failure message, and selection reset behavior.
3. Define the view-model dictionaries or typed data objects at the
   `screen_state_controller` to layout-script boundary.
4. Add temporary assertions that no new presenter can mutate profile state.

Gate: current gameplay behavior remains unchanged before visual migration.

### Phase 2 — Build editor-authored scenes

1. Derive Fusion from Shop's authored transaction-menu structure. Preserve the
    two body panels, ten-row Fusion clip, stat columns, currency lane, footer anchors,
   quantity controls, touch regions, and native-position metadata; remove only
   the Buy/Sell rail and Shop-specific price/action nodes.
2. Create the Bind scene using the Shop/Equipment native dimensions.
3. Place panels, text anchors, icons, buttons, and cursors in the editor. Fusion
   must be understandable from its persisted `.tscn` nodes without executing a
   runtime node builder.
4. Add exported editor preview states for empty, available, selected, disabled,
   and result views.
5. Add `@tool` layout scripts with native-position metadata and responsive
   `_apply_layout()` behavior.
6. Verify both scenes can be opened and understood without running the game.

Gate: Fusion's two body panels, clip bounds, ten row origins, stat columns,
currency lane, and footer controls match Shop's native geometry exactly; both
editor previews match the established frame and pixel scale.

### Phase 3 — Migrate Fusion rendering

1. Add the Fusion scene to the hub shell as a persistent child.
2. Implement layout setters for rows, inline Soul costs, Shop-structured stat
   comparisons, owned material count, quantity, messages, and action state.
3. Replace rarity-letter rendering with the shared slot icon mapping.
4. Preserve every row's rarity color in all states. Selection and availability
   are shown by cursor/action state, never by greying item rows.
5. Move list clipping and row positioning into `FusionMenuLayout` using Shop's
   ten-row clip and scroll implementation.
6. Render the right panel through Shop's six-stat before/arrow/after contract.
7. Render `OWNED: x` while browsing and swap that same lower-left area to
   `FUSE?  -  x  +` in amount state.
8. Keep `HubFlowController` candidate ordering, cache invalidation, and
   transaction callbacks unchanged.
9. Make the new scene the sole visible and interactive Fusion presenter from
   the first integration pass. Keep any legacy compatibility data non-visual;
   never render old and new presenters together.

Gate: every current Fusion candidate, fusion level, owned material count, inline
Soul cost, projected stat result, overflow salvage case, and error message
renders correctly in the Shop-derived layout with no duplicate or nested panel.

### Phase 4 — Migrate Bind rendering

1. Add the Bind scene to the hub shell as a persistent child.
2. Implement setters for the Bind view model.
3. Move all Bind coordinates, colors, visibility, and action styling into the
   layout script.
4. Connect the layout action signal to the existing bind callback.
5. Remove the dynamic `hub_binding_panel`, `hub_binding_texts`, and legacy action
   presentation after parity is confirmed.

Gate: current element, bound element, soul count, cost, unavailable states,
successful bind, and result text all match existing behavior.

### Phase 5 — Route and input migration

1. Add explicit Fusion and Bind route-state enums.
2. Route controller navigation through the same active-depth rules as Equipment.
3. Make touch row/action buttons call the same callbacks as controller confirm.
4. Ensure tapping a menu background never confirms a transaction.
5. Play the shared cursor movement sound for direct touch selection.
6. Reset child selection/cursors when backing to the command row or closing the
   hub.

Gate: no duplicate cursor, stale cursor, hidden active hitbox, accidental
confirmation, or route-state mismatch remains.

### Phase 6 — Responsive and visual verification

1. Rotate through portrait and landscape while each Fusion/Bind state is open.
2. Assert panel geometry stays on native row baselines.
3. Assert selected row, scroll fraction, quantity, messages, and cursor phase
   survive reflow.
4. Test narrow and wide logical widths, not only the default aspect.
5. Check touch regions against global viewport coordinates on phone-sized views.
6. Check all text/value columns for overlap and decimal-format regressions.

Gate: orientation is treated as geometry reflow only; it never re-enters the
route or resets state.

### Phase 7 — Cleanup and closeout

1. Remove dead Fusion/Bind presenter nodes and unused callback arrays.
2. Remove legacy coordinate calculations from `screen_state_controller.gd`.
3. Add scene smoke tests for editor structure and runtime view-model rendering.
4. Run focused menu smoke tests and script diagnostics.
5. Run the full standalone smoke suite only with no active MCP Godot runtime.
6. Record completion and remaining known issues in `docs/AUDIT.md`.

## Verification checklist

- [ ] Fusion scene opens independently in the Godot editor.
- [ ] Bind scene opens independently in the Godot editor.
- [ ] Existing fusion and bind transactions are unchanged.
- [ ] Empty, disabled, available, success, and error states render correctly.
- [ ] Fusion has exactly two independent body panels and no nested detail panel.
- [ ] Fusion has no redundant selected-item name/header or Buy/Sell rail.
- [ ] Fusion uses ten clipped rows at Shop's exact native origins; Shop itself
      remains an eight-row list.
- [ ] Item rows retain rarity color in every state; no row-wide grey modulation.
- [ ] Each visible Fusion row has a right-aligned Soul cost and Soul icon in
      Shop's currency lane, with no textual `COST` or `SOULS` suffix.
- [ ] Fusion stats use Shop's exact label/current/`>`/projected columns, anchors,
      row pitch, and change colors.
- [ ] Browsing shows `OWNED: x` at Shop's lower-left anchor.
- [ ] Amount state replaces `OWNED` with `FUSE?  -  x  +` at Shop's anchors.
- [ ] The shared footer says FUSE/BACK; no second visible FUSE control exists.
- [ ] Lists and values use authored anchors and fixed integer formatting.
- [ ] Fusion rows scroll and retain selection.
- [ ] Quantity controls clamp correctly and use existing +/- art.
- [ ] Touch targets are generous and correctly offset on mobile.
- [ ] Controller and touch use the same callbacks and sounds.
- [ ] Exactly one cursor owns each active depth.
- [ ] Dimmed cursors are frozen at their resting position.
- [ ] Fusion FUSE/BACK and Bind SELECT/BACK match Shop's footer placement.
- [ ] Portrait/landscape changes preserve state and animation phase.
- [ ] No legacy Fusion/Bind presenter remains visible or interactive.
- [ ] Focused smoke tests, script checks, and final suite pass.

## Plan review corrections

The first draft was structurally correct, but the following decisions must be
explicit before implementation begins.

### 1. Preserve the hub preview contract

`select_hub_menu_row()` currently changes the previewed page while leaving
`hub_is_root` true. That is why moving across STATS, SHOP, FUSION, and BIND can
show content without showing a child cursor. A controller confirm then enters
the selected route. A direct touch on a command button currently enters that
route immediately through the same callback used by Shop.

The new menus must preserve both behaviors:

| Input | Behavior |
| --- | --- |
| Controller left/right at hub root | Change previewed command only |
| Controller confirm at hub root | Enter the previewed route |
| Touch on a command cell | Enter that route directly |
| Back inside child route | Return one depth, then hub root |

Do not make `hub_content_focus` the only source of truth for the new scenes.
Give each layout an explicit route state and derive cursor visibility from that
state. The shared hub root flag remains the outer route boundary.

### 2. Make Fusion’s quantity flow explicit

The current implementation has no Fusion quantity mode: Up/Down changes the
candidate and Left/Right changes `hub_fusion_count` while the same legacy list
remains active. That does not provide the same clarity as Shop’s sell amount
route.

The recommended new flow is:

```text
FUSION preview
  -> TARGET_BROWSE
  -> FUSION_AMOUNT
  -> transaction result/message
```

- `TARGET_BROWSE`: Up/Down changes the target; Confirm enters amount selection.
- `FUSION_AMOUNT`: Left/Right changes the count, defaulting to 1; Confirm
  performs the existing fusion transaction.
- Back from amount returns to target browse; Back from target returns to the
  command row.
- A target with no fusion material but valid overflow salvage skips amount and
  confirms the existing salvage action directly.
- A target with neither option remains selectable but has a disabled action and
  the existing explanatory message.

This changes navigation clarity, not fusion rules. It must be characterized in
tests before the old path is removed.

### 3. Make Bind’s action depth explicit

Bind currently enters the page with `hub_content_focus = true` and immediately
uses Confirm against the dynamic action button. The new route should model that
as:

```text
BIND preview -> BIND_ACTION -> result/message
```

The full panel stays visible in both states. Preview owns the dimmed/selected
command breadcrumb; `BIND_ACTION` owns the active action cursor. Touching the
BIND action enters or confirms that action directly, while touching the panel
background does nothing.

### 4. Use typed view models at the presenter boundary

The plan currently allows dictionaries or typed objects. The implementation
should choose typed objects because the boundary crosses route, presentation,
and profile data. Add small `RefCounted` model scripts (or equivalent typed
classes) for Fusion and Bind. They should contain display data only and no
profile or transaction methods.

Recommended APIs:

```text
FusionMenuLayout.render(model: FusionMenuModel)
FusionMenuLayout.refresh_layout_preserving_state()
FusionMenuLayout.stop_cursor_motion()
signals: target_pressed, amount_changed, action_pressed, back_pressed

BindMenuLayout.render(model: BindMenuModel)
BindMenuLayout.refresh_layout_preserving_state()
BindMenuLayout.stop_cursor_motion()
signals: action_pressed, back_pressed
```

`screen_state_controller.gd` assembles models and selects the visible scene.
`HubFlowController` remains the only transaction callback owner.

### 5. Do not run old and new presenters visibly together

The draft’s temporary side-by-side migration is unsafe because the current hub
already has overlapping legacy panels, rows, and cursors. Use one of these
safe approaches instead:

1. Render the new scene as the only visible presenter and compare its model
   output to a non-visual characterization test; or
2. Keep the legacy presenter hidden behind a temporary migration flag while the
   new scene is active, then delete the flag in cleanup.

At no point should both presenters have visible or interactive children.

### 6. Clarify the scene integration point

The hub is currently instantiated from `demon_hub_menu.tscn`, while
`screen_state_controller.build_hub()` injects runtime controls into its page
roots. Fusion should be a persistent child of the existing Items page, and Bind
should be a persistent child of the existing Bind page, matching the way Shop
and Equipment are currently hosted. The controller changes visibility; it must
not construct their child panels at runtime.

Each new scene must be independently openable for editor review and must expose
the same native-size and preview properties as Shop.

### 7. Add missing acceptance cases

Before implementation is marked complete, tests must cover:

- Fusion candidate with materials, candidate without materials, and overflow
  salvage candidate;
- Fusion quantity default 1, lower/upper clamps, and Back transitions;
- Fusion candidate invalidation and selected-index preservation after fusion;
- Bind with no current element, insufficient souls, already-bound element,
  successful bind, and result message refresh;
- touch on command, row, action, quantity, and background regions;
- no hidden legacy button intercepting a touch;
- one active cursor and zero stale child cursors in every state;
- portrait/landscape changes in every state without route or selection reset;
- editor preview states for every empty/available/disabled/result case.

With these corrections, the plan is implementation-ready. The existing
transaction code remains the behavioral oracle; the new scenes become the sole
owners of visual geometry, cursor state, touch hitboxes, and responsive reflow.
