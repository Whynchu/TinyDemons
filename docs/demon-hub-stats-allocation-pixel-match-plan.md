# Demon Hub Stats Allocation Pixel-Match Implementation Plan

## Objective

Rebuild the Demon Hub stats allocation page so its rendered `240x160` output is visually identical to:

`Mockups/DEMON HUB REWORK_STATSALLOCATE.png`

The mockup is the source of truth. The existing implementation is not a visual specification and must not constrain the final arrangement.

## Source and Current State

### Reference assets

- Reference layout: `Mockups/DEMON HUB REWORK_STATSALLOCATE.png`
- Add glyph: `assets/artwork/DEMON HUB REWORK_STATSALLOCATEaddition.png`
- Subtract glyph: `assets/artwork/DEMON HUB REWORK_STATSALLOCATEsubtract.png`
- Comparison screenshot: `../Screenshots/currentdemonhubstats.png`

### Main implementation files

- `scripts/screen_state_controller.gd`
  - Builds the allocation controls in `build_hub()`.
  - Positions them in `_position_hub_controls()`.
  - Renders allocation and derived values.
- `scripts/hub_flow_controller.gd`
  - Stores references to allocation controls and routes selection changes.
- `scripts/hub_flow_controller.gd`
  - Owns pending allocation changes and apply/clear behavior.
- `scripts/equipment_menu_layout.gd`
  - Reference implementation for cursor states, dimmed cursors, and interaction-layer behavior.
- `scenes/demon_hub_menu.tscn`
  - Provides the authored hub shell and footer frame.

### Current implementation problems

- Allocation content is built as separate left and right cards. The reference composition must be reproduced instead of preserving this split-card arrangement.
- Stat labels and values are not independently laid out, preventing exact left/right alignment.
- The derived-stat area is created but is not rendered and positioned as the complete right-side reference block.
- Left and right arrow buttons remain visible when add/subtract glyphs are shown. The glyphs must replace the arrows, not overlay them.
- Add/subtract markers use independent positions and do not share the arrow control lanes.
- Allocation positions use responsive/proportional calculations. Pixel matching requires fixed reference coordinates at the native menu resolution.
- The allocation cursor does not yet reproduce the equipment menu's active/dim cursor behavior.

## Final Visual Specification

### Coordinate system

- Treat the reference as a native `240x160` canvas.
- Establish a named coordinate table for every visible element.
- Use integer pixel positions and sizes.
- Do not use proportional positioning, centering, automatic layout containers, font scaling, or per-device coordinate changes for this page.
- If the game is displayed at another resolution, scale the finished `240x160` result as a whole using the existing nearest-neighbor display path.

### Required visible groups

Recreate the reference in this order, from back to front:

1. Existing hub shell, top navigation, content frame, and footer.
2. Allocation page background/content area.
3. Demon icon and points information at the reference coordinates.
4. Six editable stat rows: `VIT`, `STR`, `DEF`, `AGI`, `INT`, and `MND`.
5. Right-side derived-stat block, including every label and value shown in the reference.
6. Bottom commands: `APPLY`, `CLEAR`, `AUTO`, and `RESPEC`.
7. Cursor and row adjustment controls.

### Text alignment

Use separate sprites/textures for each label and each value.

- Stat labels are left-aligned to one fixed x-coordinate.
- Stat values are right-aligned to one fixed x-coordinate.
- Derived-stat labels are left-aligned to their own fixed x-coordinate.
- Derived-stat values are right-aligned to their own fixed x-coordinate.
- Alignment must remain correct for one-, two-, and three-digit values.
- Do not approximate right alignment by assigning one position to a combined string.

### Cursor and adjustment states

Each stat row has two visual states.

Normal row:

- Left arrow is visible in the reference left control lane.
- Right arrow is visible in the reference right control lane.
- Add and subtract glyphs are hidden.

Selected/hovered row:

- The row cursor is positioned exactly as in the equipment menu.
- The inactive/top cursor treatment uses the equipment menu's dark/dim modulation behavior.
- The left and right arrows are hidden.
- The subtract glyph appears in the left arrow lane.
- The add glyph appears in the right arrow lane.
- The glyphs occupy the arrow positions; they are not additional decorations layered over arrow buttons.

Only one row may be selected at a time. Changing rows must hide the previous row's replacement glyphs immediately and show the new row's state without leaving stale markers behind.

Keyboard, controller, mouse, and touch input must all update the same selected-row state.

## Implementation Steps

### 1. Capture the reference coordinate map

Measure the reference image at native resolution and record, in code constants or a dedicated layout section:

- Top navigation bounds and selected command state.
- Demon icon and points positions.
- Every stat label/value position.
- Left/right arrow lanes.
- Add/subtract glyph positions.
- Every derived-stat label/value position.
- Bottom command positions.
- Footer prompt and resource positions.

Do not infer positions from the current screenshot. Use the rework image only.

### 2. Replace allocation layout construction

Update `build_hub()` so allocation controls are created according to the coordinate map.

- Remove the allocation page's dependence on the two generic cards as visual layout boundaries.
- Keep compatibility references only where tests or controllers require them.
- Create separate label and value sprites for editable and derived stats.
- Create one row hit target per stat.
- Create arrow controls in the exact normal-state lanes.
- Create add/subtract glyph sprites in the exact selected-state lanes.

### 3. Remove responsive allocation positioning

Update the allocation branch of `_position_hub_controls()`:

- Stop deriving allocation x positions from `display_view_size` or `proportional_x()`.
- Apply the native coordinate table directly.
- Keep only the outer overlay scaling/resizing behavior outside the allocation layout.

### 4. Implement one allocation visual-state renderer

Add a single update path that receives the selected row and applies all row visuals:

- Show/hide each row's arrows.
- Show/hide add/subtract glyphs.
- Position and modulate the cursor using the equipment-menu behavior.
- Clear all other rows before applying the selected row.

The renderer must be called after page changes, row changes, reopening the hub, and allocation value changes.

### 5. Render all data in the reference arrangement

Populate the complete right-side derived-stat group every time the allocation page is rendered.

- Use the existing profile and pending allocation values as the data source.
- Preserve current allocation semantics and point accounting.
- Change only presentation and visual grouping unless a value is demonstrably missing from the underlying data model.

### 6. Match navigation cursor behavior

Reuse or extract the equipment menu's cursor modulation and movement behavior rather than creating a separate visual convention.

- The active cursor should retain the equipment menu's active appearance.
- The non-active/top cursor should use the same dark/dim appearance.
- Cursor position must be based on the authored target position, not button text width.

### 7. Preserve behavior

The following behavior must remain unchanged:

- Moving between all six stat rows.
- Adding and subtracting pending points.
- Preventing negative pending values.
- Respecting available stat points.
- `APPLY`, `CLEAR`, `AUTO`, and `RESPEC` actions.
- Returning to the hub and reopening the allocation page.
- Touch hit targets and controller navigation.

## Verification Procedure

### Required screenshots

Capture at native `240x160` resolution in at least these states:

- Allocation page with the first row selected.
- Allocation page with a middle row selected.
- Allocation page with the last row selected.
- Allocation page after at least one point is pending.
- Allocation page with no row hover/selection, if supported by the reference.

### Pixel comparison

For each state:

1. Crop both images to the same `240x160` canvas.
2. Confirm nearest-neighbor scaling and identical image format.
3. Create a 50% alpha overlay of the implementation and reference.
4. Generate an absolute pixel-difference image.
5. Inspect every non-zero difference, including one-pixel borders, glyph placement, and text baselines.

No visual mismatch is acceptable for authored UI elements. Differences caused by dynamic values must be isolated to the expected value pixels and documented.

### Automated checks

Extend the relevant menu smoke test to verify:

- Native allocation coordinates are fixed.
- All derived-stat nodes are visible on the allocation page.
- Stat labels and values are separate nodes.
- Exactly one stat row can expose add/subtract glyphs.
- Selected-row arrows are hidden.
- Unselected-row arrows remain visible.
- Re-selecting rows clears the previous visual state.
- Existing allocation and point-accounting tests continue to pass.

## Definition of Done

- The allocation page matches `DEMON HUB REWORK_STATSALLOCATE.png` at `240x160`.
- The complete right-side derived-stat arrangement is visible and aligned.
- Labels are left-aligned and numbers are right-aligned exactly as authored.
- Add/subtract glyphs replace, rather than overlay, the arrows.
- The equipment-style cursor and dark inactive cursor behavior are reproduced.
- No stale cursor, glyph, or arrow state remains after navigation.
- Native-resolution screenshot overlays show no unexplained authored-UI differences.
- Existing allocation, touch, controller, and navigation tests pass.
