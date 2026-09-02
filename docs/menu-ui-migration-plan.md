# Menu UI migration

Responsive-layout amendment:

- [`responsive-menus-touch-and-progression-safety-plan.md`](responsive-menus-touch-and-progression-safety-plan.md)
  supersedes the older wide-screen rule that only expanded the left field while
  leaving its internal content at native x coordinates. The 240x160 geometry
  below remains authoritative; wider compositions now distribute added width.

The menu migration uses the authored `Mockups/PAUSE MENU.png` render as the
first visual contract. The pause screen is authored in the game's canonical
240x160 logical coordinate space and then resized by the display layout code.

## Pause screen contract

- The authored placement references are `Artwork/PAUSE MENU LEFT.png`,
  `Artwork/PAUSE MENU RIGHT.png`, and
  `Artwork/PAUSE MENU gold_soulspanel.png`; their imported runtime copies are
  under `assets/artwork/`. They are full 240x160 transparent canvases with
  exact alpha bounds: left `x=0..175`, right `x=176..239,y=0..135`, and
  resource shelf `x=176..239,y=136..159`.
- `scenes/menu_panel_8_piece.tscn` is the reusable panel source. The three
  pause exports establish the exact 240x160 placement contract, while
  `assets/artwork/frame 16x16.png` supplies the complete frame/background tile.
  Each panel region uses that tile as a nearest-neighbour eight-piece
  nine-slice, so the frame is composed without redrawing or scaling the
  authored pixels. At 240x160 the regions are 1:1 pixel exact; in FULL mode
  the left region may expand while the right and gold/souls regions stay
  anchored to the fixed 64-pixel rail.
  `scripts/menu_panel_8_piece.gd` owns that sizing rule so another menu can
  instance the scene and resize its root without duplicating the panel math.
- The outer frame occupies the complete logical viewport.
- The command rail is 64 pixels wide and stays attached to the right edge.
- The command divider is one pixel wide and sits immediately before the rail.
- The resource shelf is the bottom 24 pixels of the rail.
- The player information block stays in the upper-left field: portrait at
-  `(19, 26)`, name at `(43, 29)`, element at `(88, 29)`, and HP/CHROMA rows
  at y=`37` and y=`45`; the level completes the mockup's top row at `(138, 29)`.
- Command labels are centered in the rail at x=`208`, with button x=`181` and
  button y=`7` (their visible glyphs begin at y=`10`). The cursor is positioned
  ten pixels before the command hit target and is rendered above every menu
  child.
- Select begins at `(104, 149)`. The back button begins at `(128, 145)`, which
  places its face glyph at `(141, 149)`. Neither prompt consumes the resource
  shelf.
- The resource shelf has a three-pixel inner margin: gold and soul icons begin
  at x=`182`, with gold at y=`142` and souls at y=`149`. Their counts are
  right-aligned six pixels before the outer frame.
- `scripts/pause_menu_layout.gd` is the single source of truth for these
  anchors. `scripts/pause_menu_preview.gd` renders the same pixel content in
  the editor, including the sample level and both resource icons; it is
  editor-only and never adds preview nodes to a running game.
- All menu textures use nearest-neighbour filtering so the authored pixels stay
  crisp at integer scale.
- The root command rail contains Status, Equipment, Settings, and Quit Title;
  cancel/back closes the pause menu, so there is no duplicate Resume command.
- Status and Equipment replace the root shell with a full-viewport eight-piece
  background and an upper-left title card. The root command rail and resource
  shelf are hidden on those child pages.

In KEEP/native mode the contract is exactly 240x160. In FULL mode the left
field expands with the viewport while the 64-pixel command rail remains fixed.
The frame and dividers are resized from these anchors rather than from a
second aspect-specific set of coordinates.

## Current implementation versus target

Before this slice, `screen_state_controller.gd` created the pause frame, title
tab, player card, buttons, and page roots procedurally in one function. That
made the pause screen inherit unrelated menu geometry and left the cursor with
several competing position writers. The pause data and callbacks themselves
are still valid and remain owned by the controller.

The target boundary is now partially established: `scenes/menu_panel_8_piece.tscn`
owns the reusable frame geometry and `scenes/pause_menu.tscn` instances it for
the pause screen, alongside the portrait, rail, resource shelf, and page
containers;
`screen_state_controller.gd` owns dynamic text, palette binding, input routing,
and callbacks. `scripts/menu_cursor.gd` owns one cursor's transition/bob tween.
The remaining menus will move to the same boundary one screen at a time, with
their existing route contracts preserved until scene parity is verified.

## Migration order

1. Pause scene and frame geometry (current vertical slice).
2. Shared frame, cursor, command-list, prompt, and resource-panel components.
3. Pause data binding and isolated preview harness.
4. Title, save, settings, element selection, hub, and result screens.
5. Remove procedural presentation that has reached scene parity.

## Demon Hub visual-identity handoff

The Demon Hub should share the pause menu's visual grammar without becoming a
copy of the pause layout:

1. The stable hub shell now lives in `scenes/demon_hub_menu.tscn` so its frame,
   title card, four-command header, stat content frame, cursor layer, and
   footer/resource cells can be inspected independently in the editor.
2. Use the same 16x16 eight-piece frame, upper-left title-card proportions,
   muted prompt color, nearest-neighbour filtering, and top-draw cursor contract
   as the pause menu.
3. The Demon Hub root exposes exactly four commands in the authored order:
   `STATS`, `SHOP`, `FUSION`, and `BIND`. `STATS` is the merged allocation page;
   the old hub Status page is not a visible route, and Equipment remains a
   Pause-only route while its transaction presenter stays reusable internally.
   Pause keeps its separate `STATUS` page and its `EQUIPMENT` entry.
4. The hub keeps its title/header shell visible while the selected command
   previews content underneath it. Confirm enters that content; Back returns
   to the header without losing the selected preview.
5. Keep hub-only presentation modular: soul balance and shop costs, allocation
   panels, equipment inventory/detail panes, fusion controls, and binding state
   stay scene-authored anchors populated by `screen_state_controller.gd`.
6. Continue moving stable content panels into the scene one route at a time,
   with route and touch-hit regression coverage before removing each remaining
   procedural content anchor.

The controller remains responsible for route state, input, and callbacks. A
menu scene owns stable visual geometry and named presentation anchors. This
keeps layout changes local and lets each menu be previewed without changing
gameplay ownership.
