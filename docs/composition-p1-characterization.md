# Composition cleanup P1 characterization

Status: P1/P2 implementation is present, but current-source acceptance is incomplete. Formal acceptance remains open for mixed-encounter performance, focused smoke reruns against the current source, the curated release gate, and rebuilt-Web runtime proof. After a fresh editor filesystem scan, focused diagnostics pass for all 14 GDScript files that reference `EnemyBrain`, and a current BossRoomDebug runtime launch succeeds.

Scope: Establish the enemy replacement, room recovery, preview, UID, export, and mixed-encounter performance migration floor for the P2 runtime changes.

Owner: Composition cleanup review

Current code (2026-10-13): `EnemyRoster` owns the ordered run-local enemy array; the legacy `GameplayState.slimes` property returns that same array. Each `EnemyActor` carries typed definition/type/variant and roster-slot IDs, exposes shared health/status capabilities, and joins the `enemies` group. `SlimeActor` and `SkeletonActor` are siblings. `RoomEnemySpawnServices` replaces the actor in place and transfers the stable slot ID while updating runtime lists, HUD bindings, health callbacks, position recovery, occlusion state, and the enemy max-health cache. Save files continue to store the existing ordered variant IDs and slot state. `RunFlowController.restore_active_run()` rebuilds the saved map and room state, mounts the room, and applies the saved roster and runtime state. `GameplayState._restore_active_run_checkpoint()` obtains the file-backed snapshot from `ActiveRunSaveService`.

Verification: Focused enemy, recovery, definition round-trip, preview lifecycle, status, and support-composition smokes passed on Godot 4.7.2 at the prior source checkpoint; the user reports a normal local playtest. The shared source moved `EnemyBrain` into `slime_brain.gd`, preserving the UID referenced by the authored boss scene. A fresh filesystem scan, a current BossRoomDebug launch, and focused MCP diagnostics for all 14 `EnemyBrain` references pass. Current P1/P2 smoke reruns remain necessary. Composition audit/self-test, UID, definition, catalog, manifest, and Web export validators passed at their recorded checkpoints. The latest Run 30 captures predate the current family behavior-component wiring and miss the strict performance bars. The rebuilt Web export passed packaging smoke after the UID correction, but current authored-content loading and MCP autoload inactivity remain unverified. The curated 45-path gate was not run because the MCP Godot editor remains active.

Supersedes: No accepted design contract. This is current-state evidence for `composition-cleanup-review-plan.md`; the approved composition and authoring plans remain authoritative.

## Evidence

| Surface | Result | Evidence and limits |
| --- | --- | --- |
| Family replacement | Pass | `tests/encounter_definition_smoke.gd` covers Slime → Skeleton → Slime in one roster slot. Actor/collision/depth/occlusion arrays, sibling index, transform, HUD children and caches, health callbacks, position recovery, and stale-target cleanup follow the replacement. The ordered roster index remains stable. Godot regenerates the replacement node name, so names are not a durable slot identity. |
| Definition and resource round-trip | Pass | `tests/enemy_definition_slice_smoke.gd` and `tests/enemy_definition_roundtrip_smoke.gd` pass on Godot 4.7.2. The slice test's visual-source expectations match the authored palette IDs, and its preview assertion now uses the shared `EnemyActor` base for sibling families. |
| File-backed room/profile recovery | Pass | `tests/active_run_recovery_contract_smoke.gd` runs in a unique temporary `user://` namespace and an unused profile slot. It saves a profile through `ProfileSaveService`, confirms `GameplayBootstrap` loads that file, writes and reloads a snapshot through `ActiveRunSaveService`, then calls `RunFlowController.restore_active_run()` in a live `GameplayState`. Assertions cover run and room identity, ordered variant ID, enemy health and world position, and player health after the live apply path. Test profile, checkpoint, and generated settings are removed; no existing user profile is read or overwritten. |
| Desktop profile lookup | Corrected | Live recovery initially exposed `_web_has_profile()` parsing an empty browser-storage string on desktop. The method now returns `false` off Web before attempting JSON parsing. The focused recovery rerun passes without the prior JSON parse errors. |
| Preview lifecycle | Pass | `tests/enemy_preview_lifecycle_smoke.gd` passes after selecting regular actor mode explicitly; the scene defaults to Boss mode. The preview round-trip cleanup globalizes its `user://` path. The editor workbench screenshot is [`enemy-preview-workbench-2026-10-13.png`](evidence/enemy-preview-workbench-2026-10-13.png), showing the ready preview and collision guide. The user reports the local playtest looked normal. |
| Script UID status | Pass | The latest `tools/validate_godot_uids.ps1` run reports 467 sidecars with no duplicate or mismatched IDs. `resources/definitions/element_catalog.tres` now points to the actual UID in `status_mixture_definition.gd.uid`; the stale reference was corrected. |
| Definitions and catalogs | Pass | `tools/validate_definitions.ps1` loaded 44/44 authored definitions; `tools/report_catalogs.ps1` loaded the required catalogs and reported item, slime-variant, encounter, room, dungeon-policy, reward, layout, and puzzle surfaces. Environment warnings did not change the successful exit status. |
| Web package | Export smoke pass; title/menu boot verified | `tests/web_export_smoke.ps1 -RequireExport` passed after the UID correction: one WASM, one PCK, and 24 authored-content references. The rebuilt export loaded in the browser and rendered the Tiny Demons title/menu. This confirms Web engine boot and main-scene presentation; the authored-content manifest's runtime loading is not fully exercised yet. The ignored `graphify-godot/` checkout is excluded from the Web pack. The earlier Firefox screenshot is [`web-export-firefox-runtime-2026-10-13.png`](evidence/web-export-firefox-runtime-2026-10-13.png) and predates this export. |
| Exported development tooling | Source review pass; exported runtime confirmation open | `project.godot` declares `MCPRuntimeServer` as an autoload so editor F5/F6 playtests can use the MCP bridge. `addons/godot_mcp_toolkit/runtime/mcp_runtime_server.gd` checks `OS.has_feature("editor")` and disables processing in every export template before opening a socket. The rebuilt browser boot did not visibly report an error, but no runtime/network inspection confirmed the guard. Keep this proof open. |
| Mixed-enemy performance | Strict gate still open | Latest focused unscoped editor Run 30 [`run30-unscoped-after-steering-invariants-2026-10-13.json`](evidence/run30-unscoped-after-steering-invariants-2026-10-13.json): 48.982 s / 2,921 frames, 59.634151 FPS, 16.7689 ms average wall interval, 19.7388 ms average process time, p50/p95/p99 16.342/23.490/28.532 ms, 216 ms worst, and 1,224 intervals >=16.67 ms. Godot 4.7.2 editor/debug, Windows Mobile renderer, 960x640, VSync 60 Hz; focused, with scopes disabled and no runtime errors. First and minimum later one-second throughput windows were 44.970 and 57.464 FPS. The strict 60 FPS and provisional <=16.67 ms p99 targets remain unpassed. A diagnostic scoped follow-up [`run30-scoped-after-steering-invariants-2026-10-13.json`](evidence/run30-scoped-after-steering-invariants-2026-10-13.json) measured enemy runtime at 7.713 ms/frame, actor ticks at 4.551, actor runtime at 3.501, and scoot updates at 1.837; scoped timings are diagnostic. See [mixed-encounter performance correction](mixed-encounter-performance-correction-plan.md). |
| Status and contact behavior | Pass | `status_component_smoke`, `status_combat_smoke`, `status_mixture_smoke`, and `status_transmission_smoke` pass on Godot 4.7.2. The focused tests cover DoT damage/feedback, status cadence and reactions, generic enemy status presentation/defeat, contact cooldown and immunity, same-frame transmission, and authored non-transmissible Shadow Poison. The contact test also confirms pooled pair identity and stale-snapshot clearing. |
| Status contact-pair pooling | Runtime allocation reuse observed; CPU reduction unproven | The post-pool scoped capture measured 0.9921 ms/frame versus 0.974 ms/frame before the change. Live MCP inspection and the passing smoke confirm pair object reuse. This remains an allocation reuse improvement without demonstrated CPU savings. |
| EnemyFactory runtime follow-up | Corrected; focused acceptance pass | The type mismatch was traced to a second preloaded `EnemyFactory` in the boss-phase pool path; `RoomController` now uses the registered class. A restarted MCP boss-room run reached `boot_active=false` with 16 `enemies` group nodes and no fresh editor errors. The focused encounter replacement, definition slice/round-trip, preview, and healer-support smokes pass on Godot 4.7.2. |
| P2 runtime swap probe | Pass | In the MCP boss-room runtime, the first roster slot switched slime → skeleton → slime through `_configure_slime_variant`. `enemy_slot_0000` remained stable. After group registration was narrowed to factory-created actors and roster members, the `enemies` group contained 16 registered actors (13 ordered encounter slots plus three pooled boss-phase enemies); the hidden scene templates were excluded. The scene ran without logged errors after returning the slot to its original family. This is a focused runtime probe, not a substitute for the smoke suite. |
| Current test inventory | Focused pass at prior checkpoint; current-source rerun and release gate pending | `validate_test_manifest.ps1` passes with 159 rows (157 runnable, 2 reports, 45-path gate). The focused P1/P2 `.gd` smoke set passed on Godot 4.7.2 in an isolated profile before the later family brain-behavior wiring; it must be rerun against the current source. The curated gate still waits for an inactive MCP editor/runtime. The registered P3 steering-world and behavior smokes are outside this P1/P2 acceptance scope and remain unverified. |

## Latest run follow-up - 2026-10-13

The callback/component-cache follow-up capture
[`run30-unscoped-p1p2-followup-2026-10-13.json`](evidence/run30-unscoped-p1p2-followup-2026-10-13.json)
ran 41.970 seconds / 2,381 frames at 56.730998 FPS. At about 34 seconds, it
logged an `EnemyFactory.configure_actor()` type error and is diagnostic only.
Source review found `RoomController` preloaded a second `EnemyFactory` resource
for boss-phase pool creation while other runtime paths use the registered
`EnemyFactory` class. The pool now uses the shared class. After that change, a
focused unscoped capture
[`run30-unscoped-post-factory-fix-2026-10-13.json`](evidence/run30-unscoped-post-factory-fix-2026-10-13.json)
ran 45.128 seconds / 2,700 frames without runtime errors. It recorded 59.829817
FPS, 16.7141 ms average wall interval, 17.6077 ms average process time,
p95/p99 22.737/27.775 ms, and a 91.085 ms worst interval. The window reported
focused; the strict 60 FPS average and provisional <=16.67 ms p99 target still
fail. Its scoped companion
[`run30-scoped-post-factory-fix-2026-10-13.json`](evidence/run30-scoped-post-factory-fix-2026-10-13.json)
measured `slime_actor_runtime` at 3.278 ms/frame, `slime_scoot_updates` at 1.772,
`enemy_overhead_hud` at 0.918, and `frame_presentation` at 2.991. These are close
to the prior 3.312/1.783/3.088 measurements; the callback/component caches have
not demonstrated a material reduction. The no-error editor run is encouraging;
clean standalone family/factory smokes have since passed, as summarized below.

## Remaining P1 gates

1. **Mixed-encounter performance remains formally open.** The latest focused
   unscoped capture
   [`run30-unscoped-post-map-lighting-scope-2026-10-13.json`](evidence/run30-unscoped-post-map-lighting-scope-2026-10-13.json)
   ran 36.176 seconds / 2,132 frames at 58.934100 FPS, with 16.9681 ms average
   wall interval, p95/p99 25.843/33.462 ms, 145.460 ms worst, and 884
   intervals at or above 16.67 ms. The window stayed focused in `BossRoomDebug`;
   no runtime errors or warnings were logged. The strict average and provisional
   p99 criteria still fail. The user-reported normal playtest supports
   functional acceptance; it does not change those measured thresholds. The
   latest scoped follow-up measured actor occlusion at 0.149 ms/frame and map
   lighting at 0.023 ms/frame, versus 7.820 ms for enemy runtime. Neither
   presentation subsystem is a useful optimization target at those costs.
2. **Browser runtime proof remains open.** The rebuilt Web package passed its
   packaging smoke and reached the title/menu, but authored-content manifest
   loading and the MCP autoload's exported inactive state were not inspected in
   the running browser export.
3. **The curated 45-path release gate remains open.** The affected factory and
   encounter, family replacement, file-backed recovery, definition round-trip,
   preview lifecycle, status component/combat/mixture/transmission, healer
   support, and enemy stat-growth smokes pass on Godot 4.7.2 in an isolated
   profile. The full gate waits for a supervised session with no active MCP
   Godot editor/runtime.

The scoped diagnostic
[`run30-scoped-frame-phases-post-status-allocation-skip-2026-10-13.json`](evidence/run30-scoped-frame-phases-post-status-allocation-skip-2026-10-13.json)
measured enemy runtime at 7.788 ms/rendered frame (slime runtime 7.523), actor
ticks at 4.556, scoot updates at 1.922, contact snapshot at 1.063, separation
at 0.727, player contacts at 0.542, and presentation at 3.002. Capture-only
phase scopes attributed 7.788 ms to enemy runtime, 0.855 to feedback, 0.741 to
world interaction, 0.220 to player core, 0.064 to player finish, and 0.016 to
projectiles. These scopes overlap; the capture is for source ranking, not
acceptance.

The follow-up scoped capture
[`run30-scoped-map-lighting-refresh-2026-10-13.json`](evidence/run30-scoped-map-lighting-refresh-2026-10-13.json)
ran 45.813 seconds / 2,729 frames in the focused 4.7.2 editor/debug
`BossRoomDebug` scene with no logged errors. It measured map-light refresh at
0.0232 ms/rendered frame, enemy runtime at 7.581, and inclusive presentation
at 2.911. The capture added timing around map-light refresh only; its frame
percentiles are instrumentation-affected and are not acceptance data. This
rules out map lighting as a meaningful next source change, while leaving the
strict unscoped performance gate open.

The latest scoped follow-up
[`run30-scoped-actor-occlusion-followup-2026-10-13.json`](evidence/run30-scoped-actor-occlusion-followup-2026-10-13.json)
ran 38.418 seconds / 2,249 frames in `BossRoomDebug` with the window focused.
It measured actor occlusion at 0.1492 ms/rendered frame, map lighting at
0.0233 ms, enemy runtime at 7.820 ms, and inclusive presentation at 2.924 ms.
The capture reported no runtime errors or warnings. Timing instrumentation
affected the frame percentiles, so only the per-scope attribution is useful;
the unscoped performance gate remains open.

After the capture-only scope was added, an unscoped follow-up
[`run30-unscoped-post-map-lighting-scope-2026-10-13.json`](evidence/run30-unscoped-post-map-lighting-scope-2026-10-13.json)
ran 36.176 seconds / 2,132 frames with scopes disabled and the window focused.
It measured 58.934100 FPS, 16.9681 ms average wall interval, p95/p99
25.843/33.462 ms, and 145.460 ms worst, with no runtime log entries. This
confirms the diagnostic scope is inactive in an unscoped run, but the measured
performance gate still fails and remains open.

## P2 runtime state

`EnemyActor` siblings, `EnemyRoster`, stable slot identity, enemy group
registration, family replacement, save/restore, preview, and the shared-array
`slimes` compatibility view remain in place. The duplicate `EnemyFactory`
script path is corrected. A restarted MCP boss-room run reached
`boot_active=false` with 16 registered `enemies` nodes and ran without new
editor errors; a live Slime/Skeleton/Slime round-trip previously retained
`enemy_slot_0000`. The focused Godot 4.7.2 family, definition, file-backed
recovery, preview, status, support-composition, and stat-growth smoke batch
passes in an isolated temporary profile. The curated release gate and P1
performance/Web proofs remain open. Keep `docs/AUDIT.md` unchanged until those
formal acceptance gates pass.

## Latest P1/P2 runtime and performance follow-up - 2026-10-13

At the time of these captures, a prior version of `slime_brain.gd` hoisted
steering values that are invariant across candidate directions and passed MCP
script diagnostics. The focused unscoped Run 30 report is
[`run30-unscoped-after-steering-invariants-2026-10-13.json`](evidence/run30-unscoped-after-steering-invariants-2026-10-13.json):
48.982 seconds / 2,921 frames, 59.634151 FPS, 16.7689 ms average wall
interval, 19.7388 ms average process time, p50/p95/p99 16.342/23.490/28.532
ms, 216 ms worst, and 1,224 intervals >=16.67 ms. Godot 4.7.2 editor/debug,
Windows Mobile renderer, 960x640, VSync 60 Hz, focused, scopes disabled, and
no runtime errors. It misses the 60 FPS average and provisional p99 targets;
the first and minimum subsequent one-second throughput windows were 44.970 and
57.464 FPS.

These captures predate a later shared-worktree rewrite of `slime_brain.gd` as
the `EnemyBrain` host. In the current source, the orbit vector, orbit factor,
and cone cosine are calculated inside the candidate loop again. The captures
are historical and do not measure or validate the current source. Current
runtime and performance evidence is recorded below.

The paired diagnostic capture
[`run30-scoped-after-steering-invariants-2026-10-13.json`](evidence/run30-scoped-after-steering-invariants-2026-10-13.json)
ran 41.972 seconds / 2,497 frames. It measured enemy runtime at 7.713
ms/rendered frame, actor ticks at 4.551, actor runtime at 3.501, scoot updates
at 1.837, contact snapshots at 1.056, and separation at 0.591. The scoot scope
was 1.837 versus 1.912 in the prior scoped report; this small difference is
not controlled before/after proof. The source version at capture time only
hoisted invariant calculations and retained steering decisions and tick
cadence. A later shared-worktree rewrite changed this path; the current source
computes those values inside the candidate loop, so these reports are
historical and do not validate current source or establish a causal performance
change.

The current MCP `BossRoomDebug` run reached `boot_active=false` at debug Run 30
with 16 `enemies` group members and 13 ordered roster members. The first roster
slot started as the yellow Slime, changed to `skeleton_grass`, and returned to
yellow. The same `enemy_slot_0000` stayed at roster index zero and in the
`enemies` group throughout. Its `Brain/FamilyBehavior` changed to the Skeleton
policy and back to the Slime policy. No warnings or errors appeared in the game
log. This confirms the current-source family swap and restoration; it does not
replace the focused smoke suite.

The latest `validate_composition.ps1 -RequireTargets` and `-SelfTest` both pass;
the strict audit reports 308 scripts with no unclassified files. After a fresh
Godot filesystem scan, `script_check` passes for all 14 current `.gd` files
that reference `EnemyBrain`. A restarted `BossRoomDebug` run loaded the
serialized boss Slime and a factory-created Skeleton with their family behavior
components attached and no warnings or errors. Treat this as current-source scene/runtime
evidence, not a substitute for focused smoke reruns. P3 family brain behavior
is now a separate bounded follow-on; see
[`composition-p3-family-brain-behavior.md`](composition-p3-family-brain-behavior.md).
The shared editor remains active, so the P1/P2 and P3 focused smokes,
rebuilt-Web authored-content/autoload proof, and curated 45-path release gate
remain pending. Keep `docs/AUDIT.md` unchanged until all formal gates pass.

## Current-source Run 30 capture - 2026-10-13

After the `EnemyBrain` rewrite, a current `BossRoomDebug` launch reported
`boot_active=false`, debug run 30, and 16 members in `enemies`. The first
unscoped capture
[`run30-unscoped-current-source-after-brain-rewrite-2026-10-13.json`](evidence/run30-unscoped-current-source-after-brain-rewrite-2026-10-13.json)
ran 54.526 seconds / 3,208 frames at 58.834317 FPS, 16.9969 ms average wall
interval, 16.256/25.851/35.903 ms wall p50/p95/p99, and 158.361 ms worst.
Boot completion was not explicitly sampled before that capture, so retain it as
diagnostic only.

The second unscoped capture
[`run30-unscoped-current-source-after-boot-confirmed-2026-10-13.json`](evidence/run30-unscoped-current-source-after-boot-confirmed-2026-10-13.json)
started after confirming `boot_active=false`, run 30, and 16 enemy-group
members. It ran 50.221 seconds / 2,552 frames at 50.815396 FPS, with 19.6791
ms average wall interval, 16.745/34.198/77.267 ms wall p50/p95/p99, 184.238
ms worst, and 1,308 intervals at or above 16.67 ms. Its first two one-second
windows were 59.117 and 30.828 FPS; the minimum later window was 5.886 FPS.
The capture service recorded the window focused at stop, not continuously.
No runtime warning/error entries appeared in the MCP game log. The strict 60
FPS average and provisional p99 target remain unpassed; the very low throughput
window needs a repeat under a fully observed foreground window before choosing
another source optimization.
