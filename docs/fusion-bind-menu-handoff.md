# Fusion / Bind Menu Handoff

Date: 2026-09-05

## Current objective

Finish the Fusion and Bind Demon Hub menu rework so both menus match the
existing Equipment, Stats, and Shop presentation and interaction patterns.
The work must preserve the existing profile, fusion, salvage, bind, soul, and
element rules while supporting controller input, touch input, and aspect-ratio
changes.

## What is implemented

- Added persistent menu scene entry points:
  - `scenes/fusion_menu.tscn`
  - `scenes/bind_menu.tscn`
- Added view-model boundaries:
  - `scripts/fusion_menu_model.gd`
  - `scripts/bind_menu_model.gd`
- Added `@tool` layout scripts:
  - `scripts/fusion_menu_layout.gd`
  - `scripts/bind_menu_layout.gd`
- Added both scenes to `scenes/demon_hub_menu.tscn`.
- Added Fusion and Bind rendering/model assembly to
  `scripts/screen_state_controller.gd`.
- Added explicit route state fields:
  - Fusion: preview, target browse, quantity/action.
  - Bind: preview, action.
- Added controller transitions for entering, browsing, quantity changes,
  confirmation, and backing out.
- Suppressed the old Fusion/Bind legacy presenters when the new views are
  active, preventing duplicate cursors and overlapping content.
- Reused existing item icons, frame artwork, cursor artwork, and minus/plus
  artwork.
- Fixed a Fusion runtime error caused by calling `RefCounted.get()` with a
  default-value argument. Godot only accepts the property name here.
- Updated `docs/fusion-bind-menu-implementation-plan.md` with progress.

## Important architecture notes

- `hub_flow_controller.gd` remains the owner of candidate ordering, cache
  invalidation, transactions, and profile mutation.
- `screen_state_controller.gd` assembles view models and selects the visible
  view; it should not become the owner of transaction rules.
- The layout scripts own visual coordinates, cursor visibility, button hit
  regions, and responsive reflow.
- The native logical layout is `240x160`.
- The current scenes instantiate most visual children from their `@tool`
  scripts. This means the next pass should verify whether the editor preview
  is sufficiently editable/persistent; if not, move the generated children
  into the `.tscn` files or assign scene ownership while in editor mode.

## Known follow-up work

1. Reconnect or restart the Godot MCP editor peer and open the Fusion and Bind
   scenes directly, without navigating from the main menu.
2. Confirm the editor preview visibly contains the generated rows, icons,
   frame, stats, action controls, and cursors.
3. Verify scene ownership/editability. The current saved scene tree is minimal;
   the layout scripts build the child controls at runtime/editor time.
4. Run focused scene/runtime checks for:
   - root preview with no child cursor;
   - Fusion target selection and target cursor movement;
   - Fusion amount selection and minus/plus behavior;
   - Fusion success, insufficient souls, empty state, and overflow salvage;
   - Bind preview, unavailable state, successful bind, and result message;
   - Back behavior at every nested depth;
   - aspect-ratio changes while each menu is open;
   - touch row/button hit regions and touch scrolling.
5. Check for stale legacy labels/cursors behind the new scenes and check the
   debugger for repeated errors while moving between menu states.
6. Re-run focused GDScript diagnostics after the MCP peer is available.
7. Only after verification, update the version and push if requested.

## Verification state at handoff

Focused MCP script checks passed earlier for:

- `fusion_menu_model.gd`
- `bind_menu_model.gd`
- `fusion_menu_layout.gd`
- `bind_menu_layout.gd`
- `screen_state_controller.gd`
- `hub_flow_controller.gd`

`git diff --check` passed. The final MCP runtime/scene probe failed because
the editor connection returned `Invalid URL: ws://127.0.0.1:-1`; do not treat
that as a gameplay failure. Do not run the full smoke runner while an MCP
Godot editor/runtime is active.

## Worktree state

There are uncommitted changes from this and earlier work. Preserve them; do
not reset or discard unrelated modifications. At handoff, the worktree also
contains changes in the sound profile, project settings, gameplay state,
equipment/shop layouts, and hub/screen controllers, plus generated `.import`
and `.uid` files. Inspect the diff before staging anything.

## Suggested first commands

```powershell
Get-Content README.md
Get-Content docs/AUDIT.md
Get-Content docs/fusion-bind-menu-implementation-plan.md
git status --short
git diff --check
```

Then use the Godot MCP peer to open `res://scenes/fusion_menu.tscn` and
`res://scenes/bind_menu.tscn` directly, inspect their trees, and perform a
focused playtest rather than starting from the main menu.
