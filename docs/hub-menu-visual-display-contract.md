# Demon Hub Menu Visual and Display Contract

Status: active menu presentation contract

Updated: 2026-09-11

This document records why the current Equipment, Stats, and Shop menus feel
consistent, and records the shared presentation rules now used by Fusion and
Bind. It is intentionally a presentation contract; transaction rules remain
owned by `HubFlowController`, `PlayerProfile`, and `ItemCatalog`. Runtime
acceptance gaps and the current issue status live in
[`current-issues-and-resolution-plan.md`](current-issues-and-resolution-plan.md).

## 1. Current ownership

| Surface | Scene/presenter | Runtime owner | State owner |
| --- | --- | --- | --- |
| Equipment | `scenes/equipment_menu.tscn` / `equipment_menu_layout.gd` | `screen_state_controller.gd` | `hub_flow_controller.gd` + `PlayerProfile` |
| Shop | `scenes/shop_menu.tscn` / `shop_menu_layout.gd` | `screen_state_controller.gd` | `hub_flow_controller.gd` + `RunState`/`PlayerProfile` |
| Stats | `demon_hub_menu.tscn` shell plus authored runtime nodes | `screen_state_controller.gd` | `hub_flow_controller.gd` + `StatsComponent` |
| Fusion | `scenes/fusion_menu.tscn` / `fusion_menu_layout.gd` (Shop-derived) | `screen_state_controller.gd` | `hub_flow_controller.gd` + `PlayerProfile` |
| Bind | `scenes/bind_menu.tscn` / `bind_menu_layout.gd` | `screen_state_controller.gd` | `hub_flow_controller.gd` + `PlayerChromaComponent`/`PlayerProfile` |

The hub shell owns the common top command row, footer, resource display, and
responsive frame. Equipment, Shop, Fusion, and Bind own their active internal
presentation as scene-authored controls. The older Bind panel remains as a
hidden compatibility presenter while the dedicated view is active.

## 2. What makes Equipment work

Equipment is the strongest reference implementation.

- The scene is authored at a fixed `240x160` logical size. Panels, labels,
  icons, buttons, and cursor anchors can all be inspected and edited in Godot.
- `EquipmentMenuLayout` owns geometry and visual state. The controller sends
  labels, colors, item arrays, descriptions, and selected indices through small
  setter methods.
- Every responsive sprite and button records its native authored position once.
  Later layout passes resolve from that immutable native position, so rotating
  the device cannot compound offsets.
- The view has explicit route depths: command row, slot grid, candidate list,
  and confirmation. Each depth has one cursor and visibility is derived from
  the active mode.
- The selected item keeps its rarity color; selection is communicated by the
  cursor rather than by repainting the item name.
- Cursor targets are derived from the painted text or resolved button geometry,
  not from guessed word widths. Active cursors animate; dimmed breadcrumb
  cursors are locked at their resting endpoint.
- Touch buttons are transparent hit regions owned by the same scene as the
  visible content. Controller navigation and touch navigation share route state,
  but touch can directly target visible controls.
- Resize calls `refresh_layout_preserving_state()`. It reflows geometry and
  reanchors the existing cursor without resetting mode, selection, scroll, or
  animation phase.

## 3. What makes Stats work

Stats uses the common hub shell rather than a separate scene, but follows the
same important rules.

- The shell is laid out in native logical coordinates, then widened by
  `display_controller` through `_hub_left_field_x()` and the shared responsive
  layout policy.
- Labels and values use separate sprites. Values are right-anchored to a fixed
  column, which prevents changing digit counts from moving neighboring text.
- The six base stats and derived values have fixed row pitches. Pending changes
  are represented by color and the authored `+`/`-` markers, not by changing the
  row geometry.
- Only the selected stat receives active adjustment hit regions. Invisible rows
  do not retain touch interaction.
- The top command cursor remains visible as a dimmed breadcrumb when the Stats
  list is open. A second active cursor owns the stat row. This makes route depth
  visible without leaving duplicate active cursors.
- Returning to the hub clears pending state, row selection, and nested cursor
  visibility through the route transition rather than relying on stale sprites.

Stats is visually reliable because its data refresh does not rebuild the shell:
it updates textures and visibility while preserving authored nodes and native
anchors.

## 4. What makes Shop work

Shop is the reference for a data-heavy scrollable transaction menu.

- `scenes/shop_menu.tscn` contains the complete authored mode tabs, list clip,
  item icons, price columns, comparison stats, footer, quantity controls, hit
  regions, and four cursor layers.
- `ShopMenuLayout` owns visual layout. `screen_state_controller.gd` supplies
  normalized rows and comparison data; it does not calculate per-sprite screen
  positions.
- The item list has a clip region and eight reusable rows. Controller scrolling
  moves through a bounded logical window; touch scrolling uses the same list
  state but can respond to any drag within the list area.
- Icons, names, prices, gold, souls, and comparison values are separate layers.
  This prevents a long name or a changed price from shifting unrelated columns.
- Buy/Sell is a route depth, not a modal replacement of the whole scene. The
  visible contents remain present while the active cursor changes.
- On sell quantity selection, the footer swaps only its action copy to YES/NO;
  after either choice it returns to SELECT/BACK. The item cursor is hidden until
  the item list owns focus, while the dimmed selected-item cursor remains when
  appropriate.
- Duplicate functional sellable gear is grouped through the shared inventory
  signature, while items with different stats or enhancement state remain
  separate. `OWNED` is calculated from the same signature instead of from the
  number of rendered rows. Economic quality stays on each concrete instance,
  so the amount state totals the IDs that the sale will consume.
- All responsive sprites and hit buttons retain native metadata. Reflow maps
  those coordinates to the current logical width without changing pixel-art
  scale or vertical row pitch.

## 5. Shared display and input contract

These rules are the active contract for Fusion and Bind as well as the existing
Equipment and Stats views:

1. Native geometry is authored at `240x160`; all horizontal expansion goes
   through the existing display/layout helpers.
2. Scene geometry owns positions. Controller code supplies data and state, not
   scattered screen coordinates.
3. Every route depth has exactly one active cursor. Parent cursors become
   dimmed, frozen breadcrumbs; inactive child cursors are hidden and stopped.
4. Cursor anchors come from painted text or button rectangles. They must not be
   based on label length, an old cursor position, or a mutated position from the
   previous frame.
5. Controller and touch input may enter the same visible route, but neither
   input method may accidentally confirm a transaction merely by tapping the
   surrounding menu background.
6. Touch hit regions should be generous, clipped to the visible panel, and
   reflowed with their associated content. A touch should also produce the same
   hover/movement sound as controller navigation.
7. Resize is geometry-only. Preserve route, selection, scroll, quantity, draft
   fusion count, and cursor animation phase across portrait/landscape changes.
8. Refreshing data must update existing scene nodes in place. Do not append a
   second cursor, duplicate footer, or replacement panel on every render.
9. Values are integer-formatted unless a specific decimal is part of the
   approved design. Right-anchor numeric columns to fixed edges.
10. SELECT/BACK glyphs and their text use one shared authored footer contract;
    no menu should invent a different X/Y pair.

## 6. Fusion gap analysis

Fusion now has a dedicated Shop-derived scene/layout boundary while retaining
the existing transaction owner in `HubFlowController`. The remaining review
gate is populated runtime verification of the presentation and interaction
states:

- populated rows, inline Souls icons, six-stat comparisons, and quantity-state
  footer labels still need an in-game screenshot/interaction acceptance pass;
- legacy compatibility nodes remain in the hub controller until that acceptance
  pass confirms they can be removed safely;
- standalone headless smoke execution is currently limited by the local Godot
  renderer crash, although MCP scene boot and script diagnostics are clean.

### Recommended Fusion shape

The implemented Fusion scene/layout is derived directly from Shop's authored
structure and contains:

- a clipped, scrollable target list with ten visible rows, slot icons, and `F`
  level suffixes;
- a fixed right comparison/stat panel;
- inline per-row Soul costs using Shop's amount-plus-icon currency lane;
- `OWNED: x` in the browsing footer, replaced by `FUSE?  -  xN/M  +` in amount
  state using Shop's existing footer anchors and 5x5 minus/plus artwork, where
  `M` is the maximum material count for the next gear rank;
- a fixed action/footer region for FUSE and BACK;
- a distinct overflow/salvage state without changing the surrounding frame;
- one cursor per depth: target list, quantity, and action/confirmation.

### Fusion row and touch amendment — 2026-09-06

Fusion shows ten target rows at once. The ten-row capacity is shared by the
presenter, controller selection window, cursor snapping, and touch scroll clamp;
Shop retains its separate eight-row capacity. Any extra inherited row nodes are
hidden and removed from the touch hit-test path.

The active Hub overlay owns Fusion touch routing through the shared menu layer:
visible rows, the SELECT/FUSE footer, quantity controls, and BACK all use native
buttons wired to the same route callbacks as controller input. A drag inside the
Hub list reports scroll distance to the same bounded Fusion window, while a
background tap remains inert.

The presenter should receive normalized target rows, selected index, scroll
fraction, fusion count, maximum count, cost, and message text. `HubFlowController`
continues to perform the actual fusion and invalidates candidates after a
successful change.

### Fusion presentation correction — 2026-09-05

Fusion must follow the Shop body presentation directly. The Shop menu is the
visual reference and its authored layout is the contract:

- Use the same two independent body boxes as Shop: the left clipped item list
  and the right stat-comparison panel. Do not add a nested detail box inside
  either panel, and do not create a second frame around the selected item.
- Remove the redundant selected-item name/header row. The selected item is
  already identified by its row, icon, and cursor.
- Item names retain their rarity color. Fusion selection is communicated by the
  cursor, not by greying the entire list or muting unselected items.
- The right panel uses Shop's exact comparison structure: stat label, current
  value, `>`, and projected value, with the same row pitch, colors, and fixed
  right anchors. Fusion must not substitute a free-form list of stat strings.
- The lower band follows Shop's sell interaction geometry. While browsing it
  shows `OWNED: x` at the left. When an action is selected it shows `FUSE?`
  beside the existing minus / quantity / plus controls. The existing shared
  SELECT footer action is relabeled `FUSE`; no second visible FUSE button or
  independent footer is introduced.
- Soul costs use Shop's currency treatment: a numeric value followed by the
  existing Souls icon. The word `SOULS` is not rendered as part of the cost
  label.
- Fusion keeps its own target and quantity route state, but its nodes,
  coordinates, clipping, cursor anchors, footer spacing, and responsive
  reflow should be copied from `ShopMenuLayout`/`shop_menu.tscn` wherever the
  interaction is equivalent.

The intended browsing composition is therefore:

```text
┌──────────────── left item list ───────────────┬──── right stat comparison ────┐
│ icon  item row                                 │ STAT   old  >  new             │
│ ...                                            │ ...                            │
│ OWNED: x                                      │                                │
└───────────────────────────────────────────────┴────────────────────────────────┘
                 FUSE?       −   x   +       (shared FUSE / BACK footer)
```

This correction supersedes the earlier Fusion approximation with a separate
name/detail panel, free-form stat strings, greyed rows, and an additional action
label. The next implementation pass should be judged against Shop's actual
`render_shop()` and scene node positions before adding any new visual elements.

## 7. Bind gap analysis and migration record

Bind now has a dedicated `scenes/bind_menu.tscn` and `BindMenuLayout` view. The
older dynamically created `hub_binding_panel`, text sprites, and action button
remain as a compatibility fallback, but the active Hub path uses the authored
view. The remaining review work is visual orientation and touch acceptance:

- `BindMenuLayout` owns the current/bound element rows, souls, cost, status,
  action target, command cursor, and action cursor;
- its Back hit target now shares the canonical Hub footer lane;
- the shell still owns the visible shared SELECT/BACK glyphs while Bind's
  internal Back target remains transparent;
- portrait/landscape and touch interaction still need the same runtime pass as
  the other Hub routes.

### Recommended Bind shape

The following list is the original migration target and is retained as a design
reference for future polish:

Create `scenes/bind_menu.tscn` and `scripts/bind_menu_layout.gd` with an authored
panel matching the Shop and Stats frame language. It should contain:

- CURRENT element row, including the current/bound state;
- BOUND element row, including NONE when no element is bound;
- souls and cost rows with right-anchored integer values;
- a fixed status/message row;
- a BIND action region and shared SELECT/BACK footer;
- a transparent, generous touch map covering each visible action;
- a command breadcrumb cursor and one active action cursor, with no duplicate
  cursor layer.

The controller should pass a small view model: current element, bound element,
can-bind flag, soul count, cost, status, and action label/color. Binding remains
in `HubFlowController`/`PlayerProfile`; the view must not spend souls or mutate
the profile.

## 8. Implementation sequence

1. Add focused scene smoke coverage for current Equipment, Stats, and Shop
   invariants: native positions, cursor visibility by depth, row scrolling,
   touch hit routing, and portrait/landscape preservation.
2. Extract the shared footer and cursor-state conventions into reusable helpers
   without changing the three working menus.
3. Build Fusion's authored scene and layout script. Migrate rendering first,
   then route input and touch callbacks, then remove the legacy Fusion presenter.
4. Build Bind's authored scene and layout script. Migrate rendering first,
   then action cursor/touch behavior, then remove the dynamic binding panel path.
5. Add orientation tests for both new views. Rotate while each depth is active
   and assert route state, selected row, quantity, and cursor ownership remain
   unchanged.
6. Run focused menu smoke tests and the editor script diagnostics. Only after
   those pass should the full standalone smoke suite be run without an active
   MCP Godot runtime.

## 9. Completion criteria

Fusion and Bind are complete when they can be opened directly in the Godot
editor, show the same authored frame quality as Shop and Equipment, expose no
legacy duplicate presenters, preserve all state through aspect-ratio changes,
provide generous touch targets and matching sounds, and pass the same cursor,
scroll, numeric-alignment, and route-reset checks already expected of the other
hub menus.

## 10. Detailed implementation understanding

### Existing Fusion behavior to preserve

The current Fusion route already has the correct gameplay boundary:
`HubFlowController` obtains cached fusion candidates, selects a target, clamps
the fusion count to available materials, checks the soul cost, performs fusion,
invalidates the candidate cache, and preserves the selected position when the
list changes. Overflow items can instead enter the salvage path.

The migration must preserve these facts while changing only presentation and
input ownership:

| State | Current meaning | New view state |
| --- | --- | --- |
| `hub_is_root` | command row is active | `COMMAND_PREVIEW` |
| `hub_content_focus = true` | Fusion target is active | `TARGET_LIST` |
| `hub_item_index` | selected fusion target | `selected_target` |
| `hub_choice_scroll` / `hub_list_scroll` | legacy list offsets | `target_scroll` |
| `hub_fusion_count` | material quantity | `fusion_quantity` |
| `hub_fusion_message` | result/error/status copy | `message` |

Fusion should not invent a second candidate/material model. The new presenter
should consume the existing candidate array and expose a normalized row model:
target instance, display name, slot icon, rarity color, enhancement level,
equipped marker, material count, and whether the row is salvageable.

### Existing Bind behavior to preserve

Bind is a single-action route rather than a list. The current controller already
derives the current aspect, whether it is already bound, the saved bound aspect,
soul count, cost, availability, and status text. `PlayerProfile.bind_element()`
and `PlayerChromaComponent.set_bound_flame()` remain the only mutation points.

The new view model should therefore be small:

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

Bind does not need a scrolling model. It needs deterministic panel geometry and
explicit action focus. A user can preview the full panel while the top BIND
command is selected, then enter the action with confirm or a direct touch on
the action region.

### Route state matrix

Both views should make visibility and cursor ownership a direct function of
state. This prevents the current legacy problem where content is visible but a
stale cursor or hidden hitbox remains active.

| Route state | Visible content | Active cursor | Dimmed cursor | Confirm result |
| --- | --- | --- | --- | --- |
| Command preview | Full authored panel preview | Hub command cursor | None | Enters route content |
| Fusion target list | Target list, stats, material summary | Target cursor | Hub command breadcrumb | Selects/opens target action |
| Fusion quantity | Selected target, quantity row, cost | Quantity cursor | Hub command breadcrumb | Performs fusion/salvage |
| Bind preview | Full Bind panel | Hub command cursor | None | Enters Bind action |
| Bind action | Full panel plus active action | Action cursor | Hub command breadcrumb | Performs bind or shows error |

The panel contents should remain visible in command preview, matching the
current Shop requirement. Only ownership of the active cursor and touch actions
changes when the user descends into a route.

### Exact migration boundary

`screen_state_controller.gd` should continue to decide which hub route is
visible, but it should stop directly creating or positioning Fusion/Bind
content. The intended call shape is:

```text
screen_state_controller
  -> fusion_view.render(fusion_view_model)
  -> bind_view.render(bind_view_model)

hub_flow_controller
  -> owns selection and transaction callbacks
  -> invalidates candidates after Fusion changes
  -> updates profile/chroma after Bind changes
```

The new layout scripts may call shared display helpers and emit typed signals,
but must not call `PlayerProfile` mutation methods directly. The controller must
not reach into layout children to move cursors or rebuild text.

### Reuse versus new work

Reuse directly:

- `ShopMenuLayout` native-coordinate and responsive mapping pattern;
- `EquipmentMenuLayout` cursor depth, breadcrumb, and animation preservation;
- existing 5x5 slot icon assets and minus/plus assets;
- shared footer glyphs and prompt placement;
- `ItemCatalog` naming, rarity, slot, bonus, and fusion data methods;
- existing `HubFlowController` transaction callbacks.

Build new:

- dedicated Fusion scene and layout script;
- dedicated Bind scene and layout script;
- Fusion target/material/quantity view model;
- Bind current/bound/status view model;
- route-specific transparent touch hit regions;
- editor preview fixtures for empty, available, unavailable, and completed
  states;
- focused smoke tests for cursor ownership, resize preservation, and callbacks.

Do not reuse directly:

- `hub_item_list_texts` and `hub_list_cursor` as Fusion's final presenter;
- dynamically appended `hub_binding_texts` as Bind's final layout;
- rarity-letter rendering from `_update_hub_item_page()`;
- button-relative cursor guesses based on the current mutated position;
- page-wide visibility resets that affect unrelated menu presenters.

### Risk order

The highest-risk Fusion issues are stale candidate rows after fusion, list
scroll/selection preservation, and accidental confirmation while changing
quantity. The highest-risk Bind issues are action availability, stale status
messages after binding, and duplicate cursor ownership with the hub command
cursor. These should be covered before visual polish or additional animation.
