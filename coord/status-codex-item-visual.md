# codex-item-visual - status

**Focus:** Close the drop-art teardown and catalog-report follow-through for the P4 authoring cleanup on `review/composition-cleanup-plan`.
**Updated:** 2026-10-16

## Completed

The main `ItemDefinition.visual_id` retirement is already on this branch in
`8e4358a`. The shared item-art resolver remains slot based; per-item art is
deferred until real resources and assets exist.

`drop_art_smoke` now frees its temporary `PickupRuntimeController`. The focused
Godot 4.7.2 run passes with exit 0 and no smoke error, warning, or leak in its
log. Its manifest row records the focused verification.

`report_catalogs.gd` now reports live generation-policy fields. The public
PowerShell wrapper fails on GDScript script/parse errors instead of returning a
misleading success. The actual wrapper passes on Godot 4.7.2 and reports all
catalogs. Its headless import phase starts the project MCP plugin and prints
ObjectDB/resource shutdown warnings, but exits 0; the report script itself has
no script errors. `project.godot` remained unchanged.

The extraction ledger now records the retired visual placeholder and policy
fields, while keeping per-item art and room/map authoring work open.

## Handoff

These focused follow-through changes are ready for a scoped commit and push.
Other active worktree changes are outside this claim and must remain unstaged.
