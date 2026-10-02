# opencode — status

_Only opencode writes this file._

**Focus:** Player polish pass — Fire cone aim, Orb height, transition/pickup hitches
**Updated:** 2026-10-02

## Completed (2026-10-02)

Three player reports, fixed in source and verified by focused Godot 4.7.1
headless runs. Full write-up in `docs/KNOWN_ISSUES.md` §2026-10-02 and
`docs/AUDIT.md` §19.

**Fire Cinder Cone aimed at the closest enemy.** Root cause: the lateral-only
aim rule lived in `begin_magic_animation`, which the ordinary tap-and-release
cast never reaches holding a form. A magic press starts a *candidate*
animation with `pending_magic_form = null` and the closest-enemy direction
already resolved; the form is only chosen on release in
`execute_current_aspect_ability`. The rule is now
`MagicRuntimeController.apply_horizontal_cone_aim`, called from both entry
points, and it re-faces the cast sprite. Other forms keep their aimed vector.
New `tests/cone_aim_contract_smoke.gd` drives the real entry point through both
paths across eight target geometries and both facings with a non-cone control
case; **it fails on the pre-fix source and passes after** (verified by
temporarily reverting the one call site).

**Orb-room Orb floated ~11 px above the floor.** `room_puzzle_controller.gd`
carried `ORB_ROOM_VISUAL_OFFSET := Vector2(0, -7)` on top of the authored
`ORB_CENTER` marker, and `scenes/orb_room.tscn` had the preview sprite
hand-mirrored to the same offset. The constant is gone; the authored marker is
now the single source for both the preview and the runtime orb, and the scene
was resynced. This also **restores the release-gate assertion** that the `-7`
had been silently failing since `b454529`.

**Transition and pickup hitches.** Both moments wrote the profile
synchronously inside one physics tick, and `save_profile` serialized, wrote,
re-read, re-parsed, and rebuilt a full profile before four more filesystem
operations. Nine changes: byte-length write verification instead of a re-parse;
a queued, rate-limited write that never lands on the requesting frame with
forced drains at `RunCheckpointService` / `RunSettlement` /
`_save_active_run_checkpoint`; room prefabs reused by `prefab_id` rather than
`room_id`; sprite sheets sliced once so the occlusion renderer's texture-keyed
caches actually hit; the floor tile polygon read once instead of per room
entry; a bounded HUD count-up with a cached chroma reaction tint; pickup audio
prewarmed at boot; and cached `ItemCatalogData` projections.

**Instrumentation.** `room_transition`, `profile_save_queue_delay`, and
`profile_save_write` are now recorded scopes. The perf harness no longer
hardcodes `layout_ms`/`activate_ms` to `-1.0`, gained an `item_pickup`
scenario, and its `PERF_` trailing number is now labelled.

## Verification

- Composition regression floor, strict `-RequireTargets` audit, and
  `-SelfTest`: **pass**. `2,200` root accesses, `GameplayState` `1,718` lines /
  286 fields, `RoomController` `2,251` lines.
- `validate_definitions.ps1`: **pass** (32/32). `report_catalogs.ps1`: **pass**.
  `git diff --check`: clean.
- Focused headless: `cone_aim_contract_smoke`, `run1_room_prefab_smoke`,
  `cloud_save_contract_smoke`, `active_run_recovery_contract_smoke`,
  `demon_cloak_smoke`, `drop_art_smoke`, `entry_orb_visual_smoke`,
  `gear_catalogue_expansion_smoke`, `gear_drop_policy_smoke`,
  `item_drop_scene_smoke`, `combat_momentum_smoke`, `fusion_candidate_cache_smoke`,
  `frame_time_smoke` — **all pass**. `frame_time_smoke`: avg 6.897 ms, worst
  7.288 ms.
- Perf harness (seed `24681357`): `item_pickup` **1.50 ms** single contact;
  steady state unchanged at ~6.9 ms avg / ~7.3 ms worst.

**Three pre-existing gate failures found and recorded, not fixed** (each fails
identically with `scripts/` stashed to `HEAD`): `hub_binding_smoke`,
`equipment_menu_scene_smoke`, and `imbue_spell_scene_smoke` (its line 191
asserts `imbue_outline_overlays`, which `d6e1f8b`/0.3.19 removed; the abort
skips `quit()` so the process hangs rather than exiting).

## Open

- **No rendered playtest or device profile.** The Samsung A17 measurement still
  gates any claim that the transition fix helped; the two transition figures
  from the post-change run (boss 52.7 ms, regular 41.0 ms) are single samples
  inside the already-documented 300–385 ms noise band and are **not** evidence
  of improvement. An F9 capture and a pre-fix A/B run are the next evidence.
- Boss entry is still the worst transition case; `_ensure_current_room_layout`
  accounts for ~31–39 ms of it in the two post-change runs.
- The MCP Godot editor peer dropped mid-session (no Godot process remained),
  so the whole-project `lsp_project_diagnostics` scan could not be re-run at
  the very end. The composition/definition validators and every focused headless
  run above stand in for it.

## Handoff / next

1. Open the editor and run the curated gate
   (`pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1`) once the
   editor peer is free; the three pre-existing failures above need triage
   independent of this pass.
2. Capture an F9 performance capture over a room-transition sweep and a pickup
   burst, then A/B the same sweep against `63e998f` to get the comparison the
   post-change numbers currently lack.
3. Rendered acceptance for all three fixes: cone exits only left/right, orb sits
   on the floor, transitions and pickups feel seamless.
