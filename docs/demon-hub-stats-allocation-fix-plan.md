# Demon Hub Stats Allocation - Full Fix Plan

Reference: `Mockups/DEMON HUB REWORK_STATSALLOCATE.png`
Current: `../Screenshots/currentdemonhubstats.png`

This plan itemizes every confirmed mismatch between the current implementation and the
mockup, then specifies the exact fix for each. The mockup is the source of truth.

## 1. Top Command Navigation Direction

**Problem:** On the Demon Hub root (the top section showing `STATS SHOP FUSION BIND`),
the current code navigates with Up/Down. The commands are laid out horizontally, so
navigation must be Left/Right.

**Current code:** `screen_state_controller.gd` `update_hub_input()` lines ~3258-3268:
```gdscript
if hub_is_root:
    if ... "ui_up": _select_hub_menu_row(row - 1)
    elif ... "ui_down": _select_hub_menu_row(row + 1)
    elif ... confirm: _set_hub_page(...)
```

**Fix:**
- Change Up/Down handlers to Left/Right.
- Left decreases `hub_menu_row` (wrapping), Right increases it (wrapping between the
  4 commands).
- Confirm stays the same (enter the selected command).

**Flow requirement:** Choosing a menu with Left/Right, then pressing Confirm should
enter that menu and land its cursor on the FIRST item (VIT for STATS).

## 2. Entering a Menu Lands Cursor on First Item

**Problem:** When you confirm on a command (e.g. STATS), focus should move into the
content and the cursor should appear on the first item (VIT row), not remain in the
top section or land elsewhere.

**Fix:**
- On confirm from the hub root for STATS: set `hub_content_focus = true` and
  `hub_stat_row = 0` so the hand cursor appears to the left of VIT.
- Other menus (SHOP/FUSION/BIND) already have their own entry-focus behavior; keep
  those consistent but ensure the cursor lands on their first item too.

## 3. "DEMON HUB" Title Position

**Problem:** The "DEMON HUB" text is not in the position shown in the mockup.

**Fix:** Position the title sprite at the mockup coordinates. In the mockup the title
is in the upper-left title cell. Verify the `Title` sprite position in
`_position_hub_controls()` and the authored scene (`demon_hub_menu.tscn`), and match
the mockup's placement exactly.

## 4. Command Tab Highlight Box

**Problem:** The `STATS SHOP FUSION BIND` commands show a box/highlight when hovered
or selected. The mockup shows no box — the hand cursor is the only selection
indicator.

**Cause:** My change to `update_hub_ui()` called
`set_archetype_button_state(page_buttons[i], is_current_page, ...)`, which draws a
selection box on the current page.

**Fix:**
- Do NOT draw a box on the command tabs.
- Keep the command buttons text-only with no highlight, exactly like the equipment
  command rail.
- The cursor alone marks the selected command.
- Revert the `is_current_page` box highlight logic.

## 5. POINTS Display

**Problem:** 
- Current shows `POINTS >2` as two separate sprites/lines.
- It should be `POINTS X` all on ONE line.
- The `>` is only used to indicate a pending change, like the other stats.
- So it should render like: `POINTS 2` normally, and `POINTS 2 > 3` when there is a
  pending allocation that would change the remaining points.

**Fix:**
- Render `POINTS X` as a single line/text at the mockup position.
- When `remaining` would change due to pending allocations, show
  `POINTS X > Y` where `X` is current remaining and `Y` is remaining after pending.
- Remove the separate `POINTS` / `> X` split I introduced.

## 6. Plus/Minus Centering Around Stat Text

**Problem:** The `+` and `-` glyphs are not centered vertically/horizontally around
the stat text as shown in the mockup.

**Fix:**
- Position the subtract glyph centered to the left of the label and the add glyph
  centered to the right, at the same vertical center as the stat row text.
- Match the mockup's exact horizontal offsets.

## 7. Stat Numbers Right-Anchored

**Problem:** The stat values are not right-aligned in their column.

**Fix:**
- Right-anchor each stat value at a fixed x-coordinate (matching the mockup).
- Because the pixel-texture width varies with the number of digits, position each
  value by `anchor_x - texture_width` so the right edge is flush.

## 8. Missing Circle Back Indicator

**Problem:** There is no `(Circle) Back` indicator at the bottom of the menu.

**Fix:**
- Add the Circle icon + "BACK" prompt at the bottom-left, matching the mockup and the
  equipment menu convention.
- Use the `MENU_CIRCLE_TEXTURE` and a "BACK" label.

## 9. SELECT Prompt Color

**Problem:** The SELECT prompt is blue when it should be white.

**Fix:**
- Render the footer prompt text in `Color.WHITE` instead of the blue
  (`Color8(148, 220, 255)`) used for the SELECT label.

## 10. Command Cursor Too Far Right

**Problem:** The hand cursor on the `STATS SHOP FUSION BIND` commands sits too far
right.

**Fix:**
- Adjust the cursor's left gap for the command rail so the hand points at the left
  edge of the label.
- Match the equipment command rail's cursor spacing.

## 11. Derived Stats Layout

**Problem:** Derived stats labels/values need exact left/right alignment and row
positions.

**Fix:**
- Keep labels left-aligned and values right-aligned in the right column.
- Verify row pitch and x-coordinates against the mockup.

## 12. Definition of Done

- Top commands navigate with Left/Right.
- Confirm on STATS enters content with cursor on VIT.
- "DEMON HUB" title at mockup position.
- No box highlight on command tabs.
- `POINTS X` on one line; `>` only for pending change.
- `+`/`-` centered around the stat text.
- Stat numbers right-anchored.
- Circle Back indicator present at bottom.
- SELECT prompt is white.
- Command cursor is correctly positioned.
- Derived stats layout matches mockup.
- All existing allocation/touch/controller tests still pass.
