# In-progress extraction ledger

Status: initial source-reconciled inventory for the cleanup review; not an
implementation approval

Scope: explicit decomposition already in progress, documented follow-ups, and
authoring migrations that still change runtime ownership

Owner: repository architecture and gameplay systems

Current code: local Tiny Demons review snapshot, inspected 2026-10-12; see the
source references in each row. Some authority plans retain dated measurements.

Verification: read-only source/path inspection and Graphify navigation. No
Godot tests or playtests were run for this ledger.

Supersedes: nothing. This ledger supplements
[composition-cleanup-review-plan.md](composition-cleanup-review-plan.md) and
does not replace the workstream owners cited below.

Updated: 2026-10-12

## How to read status

- **Implemented in source:** the extraction or boundary exists in code. It may
  still need the owning plan's runtime, export, device or acceptance evidence.
- **Open:** source and plan both show the extraction or authoring migration is
  still required.
- **Partially extracted:** code has moved, but a facade, service bag, dynamic
  lookup or owning-state coupling remains part of the intended follow-up.
- **Closed/stale plan detail:** source has already resolved the specific item;
  do not schedule it again. Update its older authority text at the next doc pass.
- **Needs refresh:** the plan contains useful ownership detail, but its count or
  exact call sites are historical and must be remeasured before implementation.

The active plans are useful design records, but several were last reconciled
with source on 2026-10-04 or earlier. An unchecked box is a claimed work item,
not proof the current source still needs exactly that edit. Recheck every row
before assigning implementation.

## A. Runtime and UI decomposition

| ID | Status and source evidence | Explicit remaining work | Prerequisite / acceptance |
| --- | --- | --- | --- |
| X01 — screen state ownership | **Partially extracted; open.** screen_state_controller.gd is 906 lines in this snapshot. set_state() only stores a state and emits state_changed (line 706); it does not own a route registry. Many screen-specific builders and presenters now exist under scripts/ui/. | Finish only cohesive residual screen responsibilities toward the 800-line forward target in composition-plan-2026.md; establish state-id → presenter scene plus build/enter/exit/input route ownership. Preserve the frozen public boundary until all callers migrate. Do not split coherent leftovers by line count. | Pause page/runtime acceptance first. Inventory facade callers in GameplayState, SaveFlowController, HubFlowController, GameplayFrameController, cloud-save and tests. Prove route transitions, input device prompts, back behavior, native 240×160 and wide layout. ROADMAP C4 and authoring Slice 4 are the same work; track it once. |
| X02 — Hub / Pause presentation | **Partially extracted.** Screen setup, render, responsive layout, visibility, input, transaction contexts and presenters are separate files. screen_state_controller.gd still delegates legacy widget hiding; HubScreenRenderController still calls these compatibility methods (lines 165–179). hub_flow_controller.gd retains transaction and route interactions. | Trace each remaining compatibility call to a real rendered/input consumer. Retire hidden legacy widget nodes only after presenter and input ownership no longer reads them. Keep Hub state in HubMenuState; do not move a handler that still reads that state into an unrelated owner. | Shared Hub/Pause tree and equipment presenter lifecycle; typed transaction/action contexts; source and playtest proof that fallback input, row counts and visibility do not depend on hidden nodes. |
| X03 — Hub build packet | **Closed in current source; old plan stale.** ScreenStateController.build_hub(parent, pixel_texture, actions: HubScreenActions) has three typed arguments (screen_state_controller.gd:746). The older authoring Slice 4 claim of a 33-argument packet is no longer current. | Do not schedule packet replacement again. Refresh authoring-system-plan.md when that slice is next edited. | A narrow source reference check was done; no runtime verification was run for this ledger. |
| X04 — declarative runtime bootstrap | **Open; registration migration substantially advanced.** Seven ordered typed cohorts cover 42 production services. `GameplayBootstrap.BuildStep` now carries a name, typed phase, action, and optional frame yield; ordered queues cover shared loading, title-only assembly, and the full gameplay animation/visual/UI sequence. Every existing diagnostic key is retained through the phase map. Title-step order/mapping/yields and full enemy-room boot pass focused Godot 4.7.2 checks. `root.call(` fell from 37 to zero; active-profile persistence calls `ProfileSaveService` directly; the strict audit still reports two `_add_runtime_node(` matches (the direct PerformanceCaptureService attachment and helper declaration). | The title boot smoke now uses a newly added test-only service script in an appended row: the generic registrar instantiates it without production script edits, while the live Gameplay cohort probe verifies script, parent, and sibling order and rejects a missing prerequisite. Remaining work: production append-one-row acceptance and typed RoomEnemySpawnServices context extraction. Keep saved-profile route selection, checkpoint selection, and the awaited room handoff outside BuildStep queues; these branches and awaits preserve runtime workflow boundaries after service assembly. Keep the PerformanceCaptureService attachment outside this slice. | Preserve settings/display before geometry setup, HUD before item-acquisition delivery, room/occlusion ordering, save/profile bootstrap and title-vs-gameplay paths. Verify each service's required references and every original frame boundary. Do not make registration-row count the only acceptance measure. |
| X05 — runtime wiring transfer bag | **Partially extracted; open, dependent on X04 and enemy design.** RoomEnemySpawnServices is down from 40 to 24 stored fields after player/chest references moved to typed RoomController context construction and the room `WalkableArea` moved into each spawn/respawn context snapshot. `EnemyActorRuntimeServices` now owns the EnemyRoster reference, four actor query lists, enemy component access, encounter clearing/restored health, variant and ambush configuration, max-health cache invalidation, list registration/removal, last-valid-position transfer, HUD/occlusion rebinding, and enemy health callback binding (12 fields). The duplicate mutable slimes pool is gone: room contexts and boss pools use canonical EnemyRoster members; RoomEnemyContext and RoomEnemyRuntimeContext name these roster-backed lists `enemy_actors` so SlimeActor and SkeletonActor slots share the same typed contract. RoomController now changes actor-list membership and variant/ambush state through the lifecycle API, calls its own boss-pool preparation method directly, and plays spawn cues through the spawn service's typed `SoundManager` dependency. Room spawning and camera geometry use the canonical `GameplayState.ACTOR_FOOT_OFFSET`. Godot 4.7.2 encounter_definition_smoke, special_respawn_policy_smoke, enemy_room_entrance_scene_smoke, slime_variant_smoke, and boss_variant_selection_smoke pass. `boss_jump_slam_smoke` still reports its four assertions on both this change and untouched commit `634337d`; the known popcorn smoke remains a baseline issue. | Map remaining fields to their consumers and owners. Split room placement inputs from enemy capability/lifecycle operations only along focused typed responsibilities; keep the single roster and avoid another universal context. Family swap, clear, restore, variant/ambush setup, actor-list mutation, and direct boss-pool orchestration now use focused owners; the broader service surface remains open. | `encounter_definition_smoke` exercises both Slime↔Skeleton swaps and verifies roster slot/sibling order, all four lists, HUD children/caches, health callbacks, last valid position, cache invalidation, and occlusion rebinding. Room entry, respawn, variant setup, and boss-pool preparation pass focused smokes; enemy_room_entrance_scene_smoke asserts the spawn/respawn snapshots preserve player/chest identity, walkability identity, roster order, and derived geometry. Preserve these behaviors while mapping the remaining fields; keep the recorded boss debug smoke failures classified as baseline until their fixtures/assertions are repaired. |
| X06 — gameplay bootstrap facade/state surface | **Needs refresh.** GameplayState remains 1,714 lines with 481 methods in this source snapshot; the measured large share of methods is bridge/wiring surface in the existing composition plan. | Delete bridge methods only after all callers become typed and direct; assign mutable fields to their feature owner only when state and events move with behavior. Do not split by line range or add another global container. | Refresh current public/dynamic consumer inventory; preserve frame order, save fields and scene bindings. validate_composition.ps1 is a regression guard, not proof of this extraction. |
| X07 — room orchestration | **Partially extracted; specific twin cleanup recorded complete.** room_controller.gd is 2,170 lines / 115 methods. Typed RoomEntryContext, RoomActivationContext, RoomClearContext, RoomRespawnContext, and RoomSpawnContext exist. Historical 2.1 reports all 20 root/context twins removed; current source has context paths and typed results. | Treat remaining size as an audit prompt. Trace room reward persistence/settlement ownership noted by ROADMAP 0.40; prove whether current RunSettlement/RunFlowController already owns it before proposing movement. Do not recreate deleted _context twins. | Verify room activation, authored/generated route distinction, ordered enemy slots, clear/reward commit and restored room state. In-memory definition round-trip is not persistence proof. |
| X08 — combat/status/feedback | **Partially extracted; implementations exist.** ActorStatusRuntimeController and CombatFeedbackPresenter exist; CombatRuntimeController still exposes delegates such as try_apply_status, tick_actor_statuses and spawn_damage_number (combat_runtime_controller.gd:795–810). | For each facade, enumerate dynamic and typed consumers; remove only wrappers with no frozen scene/tool/test/save caller. Keep XP/reward application, lifesteal effects and equipment transmutation with their gameplay owners unless a separate event/result contract is proved. | Preserve actor contact and scheduled status ticks, damage feedback appearance, player/enemy differences and equipment behavior. Historical seam counts in the composition plan require a fresh measurement. |
| X09 — enemy runtime shared vs family behavior | **P3 current acceptance: see the composition plan.** `SlimeActor` and `SkeletonActor` are sibling `EnemyActor` types. `EnemyBrain` is the shared decision host; typed family behavior components supply preferred range, and steering uses an injected world context. `SlimeRuntimeController` still owns skeleton-specific movement/projectile/render paths. See [P3 family brain behavior](composition-p3-family-brain-behavior.md). | Treat broader family attack/locomotion/presentation extraction and narrowing the runtime controller as separate future slices. Split `SlimeTuning` only after consumer/default mapping. | Preserve explicit schedule, cooldown/hit frames, spawn/respawn, contact/status, geometry, and targeting. `slimes` compatibility views share one roster; `enemies` group is discovery only. |

## B. Authoring work with runtime ownership consequences

These are not separate refactor plans. They are explicit migration packages in
the active [authoring plan](authoring-system-plan.md); the cleanup sequence must
use them as prerequisites and avoid conflicting registries or definitions.

| ID | Current status / specific unfinished extraction | Dependencies and done proof |
| --- | --- | --- |
| X10 — shared content definition contract | **Open/partial.** Enemy and item definitions, kind catalogs, generated manifests and ContentDefinitionManifestService exist. A search of current source found no ContentDefinition base or generic ContentRegistry; the manifest service is not that registry. | Decide the shared ID/schema/validation contract only for fields genuinely common across kinds. Keep kind-specific typed catalogs. Prove duplicate IDs, unsupported fields and manifest freshness fail preflight; editor preview and exported loading use the same definitions. |
| X11 — enemy family vs variant authoring | **Open.** EnemyFactory, EnemyDefinition, skeleton actor route and workbench exist; authoring Slice 1 still calls for distinct family and variant creation, family-level art/behavior ownership, and removing the implicit Slime default. | Make Skeleton the independent-family proof, but do not use this authoring task to disguise its inheritance. Prove authoring preview, export, normal room and restore through one factory path. |
| X12 - item data/catalog authority | **Open/partial.** The 12 Plain/Basic baselines and 54 set pieces are typed catalog-owned resources; ordered IDs replace set synthesis. Demon Cloak is intentionally repeatable for fusion, not unique: its definition declares seller source and locked slots, while `PlayerProfile` owns the persistent purchase counter, price, and transaction. Dictionary projections and slot-level art remain; the unconsumed `visual_id` placeholder was retired on 2026-10-15. | Focused item, workbench, and Demon Cloak smokes plus definition validation cover typed and compatibility records; catalog-owned items stay read-only. Per-item artwork remains deferred until visual resources/assets exist. Live editor history/export lifecycle proof and remaining Slice 2 authoring acceptance remain open. |
| X13 — element/flame identity | **Partial.** `element_catalog.tres` now owns IDs, names, combat and player palettes, starter order, and fusion recipes; `AspectCatalog` and `PlayerChromaComponent` derive their string mappings from it. Stable numeric enums remain save-facing, and the player roster is bounded to the current enum range. | Element, starter, binding, and generated-progression smokes pass; malformed palette/starter/recipe data is rejected. Still prove a data-only new flame through save/load and combat/gates, plus palette/effect preview, without balance drift. |
| X14 - rooms, maps and generation policy | **Open.** Slice 3 still lists dictionary RoomSpec/ConnectionSpec, push_error-only layout validation, duplicated room/gate registries, puzzle room compilation, and old R3/R5/R7 compatibility branches. Duplicate/ignored generation-policy route anchors and primary-flame fields are retired; the remaining policy fields are validated and consumed by generation. | Keep generated and authored room compiler paths, route reachability and save-state parity; add fail-fast validation and preview error display for the remaining route/puzzle structures. No ignored generation-policy fields remain. |
| X15 — art-set and asset path authority | **Open cross-cutting track.** Runtime art uses ordinary hardcoded load families; no full art-set contract, import validator or replacement workbench is accepted yet. | Build on ActorGeometry, frame library and existing workbenches. Verify references in runtime, editor, preview, tests, generated manifests and exported PCK. This precedes asset deletion/export filtering. |
| X16 — menu route/platform extraction | **Open; shared with X01, not an extra pass.** Authoring Slice 4 and ROADMAP C4 both define route registry and .tscn/presenter conversion for title, archetype, save select, name entry, settings, game over, run complete and loading. Existing shared menu primitives and presenters are partial foundations. | Complete one screen per characterized package; unify frame input dispatch and presenter fixtures. Delete legacy hide paths only after typed callers and live preview/runtime parity. First finish current Pause acceptance. |
| X17 — verification and editor lifecycle | **Open.** Slice 5 still lists shared-process pure/content tests, environment/unverified manifest failures, registry contract iteration, editor create/move/delete lifecycle, deterministic preview contracts, CI validation and temp-user-data cleanup. | Respect MCP-first rules. Prove one mutation lifecycle through editor, generated manifests, cache invalidation and export; keep standalone gameplay suites supervised with no editor active. |
| X18 — role-specific source folders and generated docs | **Needs reconciliation; broad feature-folder move remains open in Slice 6.** The earlier role-folder migration is recorded complete, but Slice 6 still proposes recursive scanners, new feature folders, generated content/metric index, link-checked history archive. | Do not do two folder migrations. Decide whether current role folders already satisfy navigation; move only if one owner-map demonstrates better discovery. Update UID/path references atomically and regenerate indexes. Archive docs after authority links are repaired. |

## C. Completed or superseded items; do not count as unfinished extraction

| Item | Current evidence and treatment |
| --- | --- |
| Composition plan Stage 1 role-folder move | Recorded complete: scripts and UID sidecars were moved into role folders. This does not prove later feature folders or generated docs are done. |
| Stage 2.1 _context twins | Recorded complete (20 pairs, including snapshot and settlement). Current room methods use typed contexts; don't re-add root/context duplicates. Refresh the repo-wide check as part of the normal guardrail. |
| Stage 2.2 HubFlow/Economy split | Both owners are present. This is an existing split boundary, not a request to re-split them. Audit current coupling before further movement. |
| Stage 2.3–2.5 helper extractions | PixelTextTextureFactory, SlimeGeometryQueries, ActorStatusRuntimeController, and CombatFeedbackPresenter exist. Retire their facades only when incoming consumers and tests are migrated; don't repeat their code moves. |
| 33-argument build_hub packet | Resolved in current source by typed three-argument build_hub(..., actions: HubScreenActions). Older Slice 4 text needs correction. |
| Duplicate Hub page constants claim in ROADMAP C3b | Resolved in current source: screen_state_controller.gd and hub_flow_controller.gd both alias HubMenuState. |

“Implemented in source” is not the same as verified for shipping. Existing
plans record several 2026-10-04 runtime checks as pending under a shared-editor
restriction. Before closeout, check current verification records; do not assume
those historical pending states still apply or that source presence alone
closes them.

## D. Dependency order for the remaining extraction work

1. **Refresh the migration baseline.** Update stale measurements and false
   open items (X03); inspect completion evidence for recorded code moves.
   Reconcile Graphify paths against current HEAD before using the map as an
   extraction ledger.
2. **Close the active authoring/runtime proof needed by each seam.** For enemy
   work: preview/session/export lifecycle and a real same-slot family swap. For
   screens: current Pause acceptance and typed action/context owners. For room
   data: generated/authored parity and save restore. Unrelated open proof does
   not block independent seams.
3. **Migrate generic enemy ownership.** Introduce sibling identity and one
   ordered roster, then migrate room replacement, collision, targeting and
   rendering through compatibility adapters. Extract family behavior only
   after contracts and performance are stable.
4. **Finish bootstrap wiring after feature owners stabilize.** A registration
   table should reference typed owners with validated dependencies, not freeze
   the current transfer bag or make imperative work harder to inspect.
5. **Advance item/element/room data by their authoring slices.** Preserve old
   schemas until the replacement feeds runtime, editor, preview, save and web.
6. **Continue menu extraction one route at a time.** Current Pause behavior is
   the gate; do not combine menu platform work with enemy/runtime restructuring.
7. **Retire facades and assets last.** Close incoming consumers, saves, editor
   lifecycle, UID and export references before deletion or archive.

This ledger is the starting inventory for P0, not evidence that every one of
the 727 Graphify communities has already been source-reviewed. As each item is
confirmed, split it into bounded implementation records and update its owning
plan; corrections belong here first so the cleanup plan does not maintain a
competing status table.
