# UI Consistency and Touch Polish Plan

Status: implemented
Scope: target health HUD, full-map touch affordances, and Demon Hub shop hitboxes
Owner: `HudController`, `DungeonMinimapController`, `TouchControlsLayer`, and `ShopMenuLayout`
Current code: target bars are assembled from runtime dictionaries; the full-map footer and shop rows are responsive overlays; browser touch dispatches through `TouchControlsLayer` into authored `Button` nodes.
Verification: focused UI smoke, HUD smoke, composition/manifest checks, headless boot, and web-export smoke passed on 2026-09-19.
Supersedes: none

## Intent

Keep the minimal pixel UI visually stable and directly touchable as the logical
viewport changes width. The player should never need to compensate for a stale
texture, a drifting label, an invisible legacy button, or a browser-specific
coordinate offset.

## Problems being closed

1. Target health can fall back to the authored green base texture when a target
   was spawned after the initial health UI build. The target number is also only
   centered during construction, so a later layout or target swap can leave it
   visually off the bar.
2. The full map has a legacy circular MAP touch visual in addition to its own
   SELECT/BACK footer. The map footer used fixed x positions while the actual
   BACK button was already responsive, so the prompts drift on wider browser
   viewports.
3. Shop item rows have authored visuals and touch buttons with independently
   maintained offsets. BUY and SELL therefore become easy to hit above or below
   the visible row after responsive layout or fractional list scrolling.

## Implementation contract

### Target health HUD

- Target and overhead bars use canonical red texture fallbacks.
- A target that is not present in the initial roster lazily receives the same
  canonical texture and damage texture when selected or registered.
- The health number is always centered on the laid-out target bar's visual
  center, including after target changes and display-layout refreshes.
- The bar's fill ratio continues to use the existing authored track metadata;
  this slice does not change health math, colors for player bars, or combat
  balance.

### Full map and touch controls

- The legacy `open_minimap` visual is never shown over the full map. Its input
  route remains available for compatibility with existing minimap gestures.
- SELECT and BACK glyph/text positions are derived from
  `PauseMenuLayout.back_button_position(view_size)` and move as one footer group.
- The map overlay owns its visual prompts; the general gameplay touch cluster
  does not duplicate them.

### Shop BUY/SELL rows

- Each visible item button gets its native rectangle from the same row origin as
  the item text/icon, with a full row-pitch touch lane.
- The rectangle is then passed through the existing responsive mapping and the
  existing fractional scroll offset. No browser-only y correction is allowed.
- BUY/SELL mode tabs and sell-confirm controls keep their current authored
  footer behavior.

## Acceptance criteria

- A newly spawned or dynamically registered target cannot display a green target
  health fill when the target HUD expects red.
- The target number remains centered on the bar at native and wider logical
  widths.
- Opening the map on touch shows no large circular MAP control.
- Map SELECT/BACK prompts stay aligned with the responsive BACK hitbox at the
  native width and at wider browser widths.
- The first and last visible shop rows are touchable at their visual centers in
  both BUY and SELL views; fractional scroll moves artwork and hitboxes
  together.
- Existing desktop/controller routes are unchanged.
- Focused smokes and a headless boot pass before this plan is marked
  implemented.

## Verification matrix

Use the native 240px logical view, a wider browser view, and portrait/landscape
window shapes. The deterministic checks should cover:

- HUD texture fallback and target-number geometry;
- map footer anchor positions and hidden duplicate MAP presentation;
- shop row hit testing through the same `TouchControlsLayer` path used by the
  browser;
- existing touch-controls, menu scene, player HUD, web export, and headless
  boot checks.

## Follow-up, if hardware testing still disagrees

Capture the logical viewport size, the active `DisplayLayout` transform, the
button global rect, and the touch event position in one diagnostic record. Fix
the owning transform or scene hierarchy from that evidence; do not add a
device-specific browser offset.

## Verification notes

The new `ui_consistency_touch_polish_smoke` covers native, 284px, and 320px
logical widths, both BUY and SELL row states, the real touch menu hit-test, and
the map footer anchor contract. The existing player HUD smoke and web export
smoke also pass.

The broader legacy `touch_controls_smoke` still reports its pre-existing
equal-arc assertion for the separately authored gameplay button arrangement.
The existing full hub scene smokes currently abort during their older hub-open
fixture before reaching the shop page. Neither failure is part of this UI slice;
they remain follow-up verification debt rather than being masked here.
