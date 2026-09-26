# Tiny Demons — Version 0.2.81 Codebase Audit

Status: canonical source audit for the `0.2.x` cycle after the composition refactor

Audit date: 2026-09-26

Baseline commit: `8b162a2410ebea45bfea2e846b427838663ad61d` (the `0.2.23` tree that
the measurements below describe; the `0.2.24` documentation/version checkpoint is
the first commit on top of it)

Baseline game version: `0.2.24`

Current release: `0.2.81` (composition refactor structurally and editor-wise
complete: strict scorecard at 100% and editor composition at 100%, typed
room/menu boundaries, and the enemy authoring slice proof landed)

Supersedes: the `0.2.00` audit (`docs/AUDIT.md` at commit
`bfe55782f43ee40fe32b5bebd45de988e34579d8`). That document remains available in
Git history as the historical `0.2.00` baseline; this file is now the current
source-backed reference. Its pre-`0.2.24` numbers are retained in the historical
table in section 3 for comparison.

## Current measured snapshot (2026-09-26, version 0.2.81)

The detailed historical audit below describes the `0.2.32` tree. The current
`0.2.81` working tree measures:

| Metric | 0.2.32 audit | 0.2.81 working tree (2026-09-26) |
| --- | ---: | ---: |
| GDScript files in `scripts/` | 171 | 206 |
| `root.call/get/set` sites | 2,488 | 2,201 |
| `GameplayState` lines / fields | 1,719 / 286 | 1,718 / 286 |
| `RoomController` lines | 2,253 | 2,246 |
| `screen_state_controller.gd` lines | 5,432 | 5,508 |
| GDScript test/report files | 124 | 143 |
| Registered runnable smoke paths | 122 | 141 |
| Curated release-gate paths | 43 | 44 |
| Project Markdown documents under `docs/` | 89 | 104 |

The strict composition audit and the regression floor both pass. The
editor-composition metric reads 100% by its own definition, but that metric
counts component blindness, `@export` presence, and definition scripts loading
`.tres`; it does not prove that the authored data is typed, validated, or read
at runtime. Several catalogs are still untyped dictionaries and several
resource fields are ignored in favor of duplicated code constants — see the
trap register in [`authoring-system-plan.md`](authoring-system-plan.md). Treat
the metric as a regression guard, not an authoring-completeness claim.

The historical sections below retain their original baseline measurements; the
current snapshot above and the focused verification commands are the live
source for present-day counts.

## 1. Purpose

This document records what Tiny Demons is and how its implementation is shaped
after the `0.2.x` composition refactor. It is the authoritative, measured
snapshot for future work: the preserved product contract, the current
architecture, the verification surface, the performance floor, and the
remaining migration sequence.

The composition refactor is now **structurally complete** under the strict
ownership scorecard (see section 5.1). The `GameplayState` state bag, dynamic
`root.call/get/set` seam count, `RoomController` size, transitional adapters,
and paired legacy implementations have all crossed their pinned targets. What
remains is content-authoring composition (T2), device-backed performance work
(T3), the menu platform migration, and the browser/device verification gaps —
not more legacy-coupling cleanup.

## 2. Scope and evidence

The audit inspected:

- all 203 runtime/editor GDScript files under `scripts/`;
- the main scene and 22 supporting project scenes under `scenes/` (the MCP
  addon editor scene is outside this project-scene count);
- project input, renderer, viewport, export, and CI configuration;
- all 141 GDScript test/report files under `tests/` and the manifest registry;
- permanent profile, active-run, local, web, and cloud save boundaries;
- authored and generated dungeon definitions;
- combat, Chroma, progression, equipment, room, enemy, UI, touch, and audio
  ownership paths; and
- the 104 tracked Markdown documents under `docs/` plus `README.md` and
  `AGENTS.md` as the documentation surface.

Historical verification performed for the 0.2.32 baseline:

- `tools/validate_composition.ps1` (regression floor and `-RequireTargets`
  strict audit) both pass: **100%** weighted progress, all strict targets met.
- `tools/validate_test_manifest.ps1` passes: 124 rows, 122 runnable paths, 2
  report rows, 43 curated-gate paths.
- `tools/run_perf_harness.ps1` produced a fresh desktop baseline on the
  `24681357` seed (section 11).
- The full 122-path runtime suite was not re-run for this read-only
  documentation baseline. Per the repository safety rule, the curated gate
  remains a supervised standalone step; focused/owner checks are listed in the
  verification section of
  [`composition-refactor-analysis.md`](composition-refactor-analysis.md).

## 3. Measured baseline

### 3.1 Current measurements (2026-09-16)

| Metric | Version 0.2.24 |
| --- | ---: |
| GDScript files in `scripts/` | 171 |
| Runtime/editor GDScript physical lines | 48,329 |
| Non-blank runtime lines | 42,659 |
| Named GDScript classes | 157 |
| Ordinary functions | 2,684 |
| Static functions | 387 |
| Declared signals | 55 |
| Explicit `*Component` classes | 20 |
| `root.call/get/set` sites | 2,488 |
| `GameplayState` lines / fields / functions | 1,719 / 286 / 479 |
| `gameplay.gd` lines | 233 |
| `RoomController` lines | 2,253 |
| Scene files | 19 |
| GDScript test/report files | 124 |
| Registered runnable smoke paths | 122 |
| Curated release-gate paths | 43 |
| Project Markdown documents under `docs/` | 89 |

### 3.2 Historical `0.2.00` measurements (archived)

The `0.2.00` audit at commit `bfe5578` recorded 141 runtime GDScript files,
43,799 lines, 127 named classes, 3,112 `root.call/get/set` sites, 121
test/report files, 113 registered smoke tests, and 19 scenes. The full
`0.2.00` report, including its subsystem tables and preservation contract,
remains available in Git history for anyone who needs the pre-refactor shape.

The migration since then is summarized by the composition scorecard: dynamic
root access fell 3,112 → 2,488, `GameplayState` fell from 1,720+ lines / 287+
fields to 1,719 / 286, `RoomController` fell to 2,253 lines, and the transitional
adapter / parallel-legacy counts are both zero. Through `0.2.32` the
editor-composition half also reached 100%: all 20 components are blind and
`@export`-configured, and all 16 authored definition surfaces are
editor-inspectable resources (see section 5.1).

### 3.3 Largest scripts

| Script | Lines | Primary concern |
| --- | ---: | --- |
| `screen_state_controller.gd` | 5,432 | Menu construction, layout, input, and presentation (326 root accesses remain) |
| `room_controller.gd` | 2,253 | Room lifecycle, encounters, sockets, rewards, and persistence (216 root accesses) |
| `gameplay_state.gd` | 1,719 | Composition root plus remaining shared state/compatibility facade |
| `dungeon_layout_generator.gd` | ~1,630 | Generated topology, curriculum, and layout policy |
| `hub_flow_controller.gd` | ~1,323 | Hub routes, shop, equipment, fusion, stats, and transactions |
| `player_equipment_visual_component.gd` | ~1,150 | Layered gear presentation and attack-state synchronization |
| `item_catalog.gd` | ~990 | Definitions, generation, display, economy, effects, and compatibility |

Line counts are navigation and responsibility indicators. They are not quality
scores or automatic split thresholds.

## 4. Implemented game surface

The implemented game surface from the `0.2.00` baseline is preserved. It
includes:

- the complete title → save selection → Demon Hub → dungeon → settlement → Hub
  loop with persistent profiles and recoverable active runs;
- player action combat: movement, combo attacks, running finishers, charged
  attack-two and sword beam, spin attack, directional contact geometry, roll,
  guard, hit reactions, knockback, target lock, and synchronized equipment
  layers;
- eight stable elements (Neutral, Fire, Water, Electric, Grass, Shadow, Ground,
  Ice) with weakness/resistance/immunity/neutral matchups, Chroma attunement,
  binding, fusion, orb charging, and ability modes;
- Slime variants with shared movement/combat, contextual steering, ambush,
  popcorn respawn, spawn animation, health presentation, and boss jump/slam;
  plus a first Skeleton family actor route reusing that runtime, with authored
  idle/walk/attack/recovery animations and a stub bone projectile;
- authored Runs 1–5 plus deterministic generated Runs 6+ (R6+ risk/reward
  policy is the approved generated direction);
- compact minimap and expanded travel map over the same dungeon graph/state;
- six-stat profiles (VIT/STR/DEF/AGI/INT/MND), XP, gold, Souls, difficulty,
  grades, mastery, and element binding;
- six canonical equipment slots with stable instance IDs, enhancement, random
  stats, effects, fusion, salvage, and full Hub transaction flows;
- 240×160 pixel-art presentation with nearest filtering, integer scaling,
  adaptive landscape widths, and fixed aspect presets;
- keyboard, controller, mouse, and touch input through the centralized
  `InputRouter` / `InputDeviceTracker` boundary; and
- the Web export, GitHub Pages workflow, localStorage save mirror, active-run
  recovery, browser lifecycle diagnostics, and optional encrypted cloud backup.

Nothing in the composition refactor changed this surface. Behavior, balance,
timing, save identities, and pixel presentation were preserved as migration
contracts.

## 5. Runtime architecture

### 5.1 Composition — structurally complete

The composition refactor is complete under the strict scorecard enforced by
`tools/validate_composition.ps1`:

| Hard gate | `0.2.24` | Target | Status |
|---|---:|---:|---|
| Dynamic `root.call/get/set` sites | 2,488 | ≤ 2,499 | `[x]` |
| `GameplayState` lines / fields | 1,719 / 286 | ≤ 1,719 / 286 | `[x]` |
| `RoomController` lines | 2,253 | ≤ 2,296 | `[x]` |
| `.runtime` references in contexts | 0 | 0 | `[x]` |
| Paired legacy/context duplicates | 0 | 0 | `[x]` |
| Transitional `GameplayState`-backed contexts | 0 | 0 | `[x]` |

The validator reports **100%** weighted progress from the recorded
`completion_start`. The strict audit (`-RequireTargets`) passes; it is no longer
expected to fail. The accepted floor in `tools/composition-baseline.json` is now
the achieved state, so the guardrail protects against regression rather than
tracking an open migration.

The editor-composition half is also **100%** at `0.2.32`. Every one of the 20
reusable components is both blind (no `root.call/get/set`) and editor-configured
(`@export`), so components are 20/20 blind, 20/20 configured, 20/20 both. All 16
authored definition surfaces (10 builders/catalogs loading
`resources/definitions/*.tres` + 6 tuning resources) are editor-inspectable, so
definitions are 16/16. The weighted composite is **100.0%**. The migration that
reached this state is recorded in `docs/component-composition-design.md`:
player equipment visual (A1), player animation (A2), item catalog (B1),
dungeon layout run2 (B2), the four authored puzzle plans (C1), the final two
`@export`-configured components (C2), and the final scope correction that
restricted the definition surface list to authored-content-only files (the
procedural `dungeon_layout_run3/4/5/6` wrappers and the shared
`dungeon_layout_definition` contract hold no authored data, so they are not
definition surfaces). Root sites fell 2,414 → 2,308 across the component
adapters alone.

Completed typed boundaries now include: `RoomEnemyContext` / `RoomSpawnContext`
/ `RoomRespawnContext` (direct `RoomEnemyContext` slices backed by
`RoomEnemySpawnServices` and pure `RoomEnemyPlacement`), `RoomEntryContext` /
`RoomActivationContext` (retired as adapters; room entry/activation now runs
through `room_entry_services.gd` and `room_activation_services.gd`),
`RoomClearContext`/`RoomClearResult`, `RoomCheckpointContext`/
`RoomCheckpointResult`, `RunCheckpointContext`/`RunCheckpointResult`/
`RunCheckpointService`, `RunSettlementContext`/`RunSettlementResult`,
`ChestRewardContext`/`ChestRewardResult`, `ActiveRunSnapshotContext`,
`MenuPlayerContext`, `RoomTransitionResult`, `RoomActivationResult`,
`RoomSpawnResult`, `RoomEntryResult`, `RoomEnemyRuntimeResult`, and
`RoomGeometryController`. Six tuning classes now load external defaults from
`resources/tuning/*.tres`, deep-duplicated per runtime. Authored definition data
loads from `resources/definitions/*.tres` through typed resources:
`ItemCatalogData`, `DungeonRunDefinition` (run1/run2), and `PuzzlePlanData`
(r3_new/r4/r5).

`GameplayState` remains the composition root and a compatibility facade, but it
is now at its smallest measured size (1,719 lines / 286 fields / 479 functions)
and no longer carries room geometry, room runtime, or the frame-schedule seam.
`gameplay.gd` remains a slim 233-line coordinator.

### 5.2 Frame ordering

The runtime retains one explicit physics schedule. `gameplay.gd` polls the
input router and delegates the frame to `GameplayFrameController`, which orders
input, player actions, movement, animation, enemies, pickups, interactions, UI,
effects, depth, targeting, and stabilization. `GameplayFrameController` now
crosses a typed `GameplayState` boundary with zero root reflection. This
deterministic schedule is preserved and must remain the ordering authority.

### 5.3 Coupling profile

| Script | Dynamic root sites | Architectural concern |
| --- | ---: | --- |
| `screen_state_controller.gd` | 326 | Menu construction, input, layout, and presentation remain mixed |
| `combat_runtime_controller.gd` | 222 | Combat integration still reaches through the root |
| `room_controller.gd` | 216 | Room lifecycle, encounters, persistence, and rewards overlap |
| `slime_runtime_controller.gd` | 195 | Reusable slime components rely on a broad runtime context |
| `magic_runtime_controller.gd` | 141 | Magic state and presentation have remaining coordinator seams |
| `actor_presentation_runtime_controller.gd` | 122 | Presentation integration reaches through the root |
| `hub_flow_controller.gd` | 108 | Hub transactions still mix navigation and presentation |

These are the migration seams for the next ownership cycle. The aggregate
threshold is crossed, but these owners remain the vertical slices that would
benefit most from typed dependencies and direct references. Metadata usage is
tracked separately and remains appropriate for open-ended presentation tags;
gameplay-significant metadata should become typed state where practical.

### 5.4 Architectural strengths to retain

- Central deterministic frame scheduling.
- Typed combat requests, stat snapshots, and room death consequences.
- Stable element IDs and one matchup authority.
- Dedicated Chroma state ownership and signals.
- Dungeon graph, map state, and layout-definition boundaries.
- Shared actor geometry for rendering and combat bounds.
- One input snapshot boundary across desktop, gamepad, and touch.
- Permanent profile state separated from disposable active-run recovery.
- Stable item instance IDs and explicit profile migrations.
- One desktop/web codebase with platform behavior isolated at seams.
- Room-owned typed spawn/respawn/clear/entry/activation boundaries.
- External tuning resources as the composition-root default surface.

## 6. Subsystem assessment

| Domain | Current owners | Assessment | Main scaling need |
| --- | --- | --- | --- |
| Frame orchestration | `gameplay.gd`, `gameplay_frame_controller.gd` | Completed typed boundary | Preserve the schedule; do not add independent `_process()` |
| Shared runtime state | `gameplay_state.gd` | At the measured target | Continue migrating remaining wrappers as feature owners mature |
| Player combat | player components, combat calculator/runtime | Strong mechanics and useful components | Reduce `combat_runtime_controller.gd` root glue (222 sites) |
| Slime combat | slime components and runtime controller | Rich reusable behavior | Typed enemy runtime context / archetype boundary (T2 slice B) |
| Actor geometry | actor geometry/collision/motor/occlusion | Shared geometry is a good foundation | Clarify collision versus rendering ownership and test room edges |
| Chroma/magic | Chroma, aspect ability, magic/projectile controllers | Chroma state is well owned | Remove `magic_runtime_controller.gd` coordinator seams (141 sites) |
| Dungeon topology | graph, layouts, generator, route solver | Capable authored/generated foundation | Split generation policy, compilation, and validation |
| Room runtime | room and puzzle controllers | Typed room lifecycle boundaries in place | Next seam: reward persistence/settlement and puzzle ownership |
| Progression | profile, progression, run state/settlement | Durable data model with migrations | Separate profile data from economy and content policies |
| Equipment/content | item catalog, instances, equipment | Stable instance model is valuable | Move authored definitions into validated catalogs (T2) |
| Hub flow | hub flow plus screen state | All required flows exist | Separate transactions, navigation state, and presentation |
| Menus/UI | screen state plus layout scripts/scenes | `MenuPlayerContext` proves the pattern | One reusable menu toolkit, one presenter per route (Phase 0.30) |
| Input/touch | input router, tracker, touch layer | Strong centralized input boundary | Split gameplay touch rendering from generic menu hit testing later |
| HUD/effects | HUD, effects, sprite library | Functional and cache-aware | Consolidate generated-texture services and profile hot paths |
| Audio | sound manager, clip catalog, mix profile | Centralized playback and web-aware assets | Add focused lifecycle/performance verification |
| Saves/cloud | profile/active-run services and cloud boundary | More mature than most systems | Formal migration fixtures and browser durability evidence |
| Display/web | display owner, layout helpers, export workflow | Sound cross-platform direction | Maintain a device/browser acceptance matrix |

## 7. Content authoring assessment

Content authoring is moving from code-driven to editor-inspectable data. The
item catalogue loads live baseline/set data and their metadata from
`resources/definitions/item_catalog.tres` (`ItemCatalogData`); retired expansion
item/transmutation records were removed, Demon Cloak now has a standalone typed
definition, and the old item IDs are pruned from saved profiles. The authored
Run 1 and Run 2 layouts load from
`resources/definitions/dungeon_layout_run1.tres` / `dungeon_layout_run2.tres`
(`DungeonRunDefinition`); and the four authored puzzle plans load from
`resources/definitions/puzzle_map_r{3_new,4,5}.tres` (`PuzzlePlanData`). The
six tuning classes load external defaults. Procedural run builders
(`dungeon_layout_run3/4/5/6`) and the shared layout contract remain code, since
their authored content lives in the puzzle-plan resources above. This is the
first piece of the intended path:

```text
authored definition -> validator -> catalog -> runtime instance -> stable save ID
```

The long-term target is validated `Resource` definitions plus factories for
enemies, encounters, rooms, dungeon/map rules, items, rewards, and effects.
The first proof is the `EnemyDefinition` vertical slice (T2 slice B): move one
existing slime variant behind an inspector-editable `Resource` and an
`EnemyFactory`, then prove a second variant can be added with one standalone
definition file and **zero** `GameplayState` edits. See
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md)
for the pinned acceptance bars.

Content migration must remain incremental. Stable IDs and save migrations take
priority over changing the storage format.

## 8. UI and menu assessment

UI remains the clearest scaling bottleneck. `ScreenStateController` (5,432
lines, 326 root accesses) still combines title/save/creation/game-over flows,
Hub/pause/status/shop/fusion/bind/equipment views, menu construction, layout,
navigation, input, cursor, touch targets, generated pixel text, responsive
positioning, and transition effects.

The composition refactor added `MenuPlayerContext`, which supplies the pause
root card, pause Status page, and Hub player summary with typed profile,
combat/progression snapshots, tuning, health, Chroma, palette, and portrait
dependencies. That is the reference pattern for the remaining extraction. The
desired boundary remains a small shared menu toolkit (frame, footer, prompt,
cursor, list, clipping, responsive layout) plus one presenter per major route,
with a single command path for keyboard, controller, mouse, and touch.

Pause and Demon Hub remain the best visual references. New menu work should not
expand `ScreenStateController`; migrate one screen at a time with screenshot and
input characterization.

## 9. Testing and verification assessment

The test investment is a major strength: 137 manifest rows, 135 registered
runnable paths, a 44-path curated release gate, and a manifest registry
(`tests/manifest.csv`) that drives the runner groups. The current harness
limitations remain: each test launches a separate Godot process, the full run
is slow, and visual acceptance is mostly manual.

The target structure remains: fast pure/domain checks, content/resource
validation, focused scene integration suites, a small number of full runtime
journeys, web export/boot checks, and manual visual/device checklists. The
process-per-test runner should remain available until an equivalent suite
runner proves the same failures are detected. Live triage and the detailed
test-by-test record are in [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) and
[`test-target-audit.md`](test-target-audit.md).

The browser/device and hosted-Pages verification gaps remain separate release
work, as do native-resolution orientation checks, cold/warm timing, and the
full supervised standalone gate.

## 10. Persistence and compatibility

`PlayerProfile` writes schema 14 and accepts legacy schemas 8–13. Compatibility
includes the SPD-to-AGI transition, six-stat migration, equipment slot
migration, retired-item pruning, typed Demon Cloak data, and current stat
baselines. Permanent profiles use three slots, temporary writes, validation,
backups, and web localStorage mirroring. Active runs use a separate schema-1
snapshot with normalized vectors, run identity, room state, map state, player
health, Chroma, facing, and run layout identity. Cloud saves export a versioned
profile envelope and store encrypted payloads remotely.

Every content or state refactor must continue to answer: is the stable ID
unchanged; can the current version load every supported legacy schema; does a
failed write preserve the previous valid save; does desktop behavior match the
web localStorage path; and can an active run fail validation without damaging
permanent progression.

Open persistence gaps: formal migration fixtures (to replace ad hoc assumptions
about legacy save shapes) and browser durability evidence for the active-run
file write path.

## 11. Performance profile

### 11.1 Fresh desktop baseline (2026-09-16, seed `24681357`)

Fixed-seed harness via `tests/performance_scenario_harness.gd` /
`tools/run_perf_harness.ps1`. 90-frame warmup, 180 samples per scenario.

| Scenario | avg ms | worst ms | nodes | sprites |
|---|---:|---:|---:|---:|
| title idle | 6.89 | 10.64 | 1,646 | 891 |
| hub idle | 6.90 | 11.09 | 1,657 | 902 |
| hub shop page | 6.90 | 15.86 | 1,657 | 902 |
| combat room | 6.92 | 23.84 | 1,659 | 904 |
| boss room transition | 164.73 | 164.73 | — | — |
| boss room | 7.04 | 39.70 | 1,666 | 909 |
| room transition | 15.26 | 15.26 | — | — |
| pause menu | 6.89 | 9.32 | 1,671 | 914 |

Readings:

- Steady-state headless frame time is ~6.9 ms (~145 fps) — the desktop CPU
  floor, not the mobile number.
- The scene holds ~900 sprites across ~1,650 nodes. A device profile decides
  whether node count is the binding cost.
- The regular room transition is ~15.3 ms.
- **The boss room transition is the worst single case but is highly
  noisy.** The 2026-09-16 run recorded ~164.7 ms; an earlier favorable sample
  on 2026-09-15 recorded ~89 ms. Interleaved A/B runs against the `d3408b6`
  tree (the commit the 89 ms figure was attributed to) show both trees mostly
  landing in the 300–385 ms band with occasional ~100–165 ms low samples. The
  harness reports one un-averaged sample per run, so it cannot distinguish a
  small regression from machine/load noise. The conclusion is that the boss
  entry is a genuine slow path (see 11.2) but the composition refactor did not
  measurably regress it.

### 11.2 Boss entry is a genuine slow path, not a measured regression

The plan's ~89 ms figure was a single favorable sample and is not reproducible,
even at the exact commit that supposedly measured it. Interleaved runs of the
`d3408b6` (pre-refactor) tree and the current tree under identical conditions
produce the same distribution. The real finding is that the boss door entry is
one of the slowest synchronous paths in the game and deserves optimization work,
with the phase costs dominated by:

- the stone-accent layout/placer work in `_ensure_current_room_layout()` during
  the entry (roughly a third of the transition);
- boss activation and enemy spawn inside `_apply_room_state()` /
  `reset_slimes_for_room()` (roughly half of the transition); and
- the synchronous `ProfileSaveService.save_profile()` write on entry.

The immediate next step is not to hunt a refactor regression but to (a) make the
harness average the boss-transition measurement across several door entries so
it becomes a stable gate, and (b) optimize the three dominant phases above once
the Samsung A17 profile exists. Any fix must preserve the stone-accent layout
contract and the typed entry/activation boundaries.

### 11.3 Performance rules

The rule for `0.2.x` remains profile before optimizing. Each performance task
needs a reproducible scenario, baseline time, target device, and before/after
evidence. Caches require explicit invalidation ownership. Samsung A17 remains
the explicit low-end mobile target; the desktop numbers above are a CPU floor,
not a mobile budget.

## 12. Naming and repository organization

The source consistently uses `snake_case` filenames and generally `PascalCase`
named classes. The terminology contract is now established in the audit
vocabulary: Component (entity state/behavior), Controller (bounded feature
workflow), Service (durable capability), Definition (authored immutable data),
State (serializable mutable data), Presenter (state → view updates), Layout
(geometry without transactions), Catalog (lookup/index over validated
definitions).

All 171 scripts still occupy one flat `scripts/` directory. A feature-based
directory structure will improve discovery, but files should move with their
feature migration after import checks are green, preserving UIDs and resource
references.

## 13. Documentation assessment

The repository contains 89 Markdown documents under `docs/` plus `README.md`
and `AGENTS.md`. Authority and lifecycle are governed by
[`DOCUMENTATION_MAP.md`](DOCUMENTATION_MAP.md). The maintained authorities are
`README.md`, this audit, `project_direction.md`, `ARCHITECTURE.md`,
`ROADMAP.md`, `CONTENT_AUTHORING.md`, `GAMEPLAY_TUNING.md`,
`KNOWN_ISSUES.md`, and `VERSIONING.md`.

The `0.2.00` audit is archived in Git history. `composition-refactor-analysis.md`
is now marked `historical`/`implemented` as the completion record of the
legacy-coupling cleanup; the long-term direction is the active authority in
`long-term-composition-and-performance-plan.md`.

## 14. Baseline preservation contract

Infrastructure work must continue to preserve:

1. The action-RPG identity: dungeon crawling, elemental combat, puzzles,
   exploration, and battling.
2. The complete title → Hub → dungeon → settlement → Hub loop.
3. Authored Runs 1–5 and generated Run 6+ policy (R6+ risk/reward is approved).
4. Movement, attack, combo, spin, charge, guard, roll, magic, Chroma, target,
   and enemy timing unless a balance change is separately approved.
5. The 240×160 pixel-art composition and responsive landscape behavior.
6. Keyboard, controller, touch, desktop, and web operation.
7. One deterministic gameplay frame schedule.
8. Stable profile, item, element, room, and run identities.
9. Supported save migrations and active-run recovery.
10. Current menu visual conventions while their implementation is unified.
11. The typed room and menu boundaries established by the composition refactor.

Structural and gameplay-balance changes should not share a patch unless the
balance change is required to preserve behavior after extraction.

## 15. Recommended next sequence from 0.2.78

1. **Keep the composition scorecard green.** The strict ownership cleanup is
   complete. Continue moving state to its feature owner when new work calls for
   it, but do not start another broad `GameplayState` or root-access cleanup.
2. **Close the M0 verification gap.** The manifest validator passes, but that is
   not a curated-gate result. The last recorded gate attempt timed out in
   `chroma_projectile_scene_smoke`; no fresh 0.2.78 curated-gate result is
   recorded. Run the gate as a supervised standalone check and classify any
   remaining product versus environment failures.
3. **Finish M1's shared authoring foundation.** The enemy design preview now
   edits all current `EnemyDefinition` fields inline, updates its preview as
   they change, saves to the owning catalog or standalone resource, and guards
   unsaved edits. Accept it after checking the catalog picker, starter creation,
   visible frame output, save/refresh lifecycle, and undo/redo; then add the
   isolated interactive workbench and close the remaining cache, manifest, and
   cleanup checks. Use the acceptance bars in `authoring-system-plan.md` rather
   than the editor composition percentage as proof.
4. **Continue Slice 2 after the M1 workflow is dependable.** Finish the full
   item catalog migration and consolidate element identity, then prove gear
   and flame authoring through data-only additions, previews, and save/load.
5. **Keep performance work evidence-led.** Capture repeatable cold/warm room-
   transition and enemy-death measurements, including the Samsung A17 profile,
   before optimizing the known synchronous and rendering paths.
6. **Return to menu and controller extractions as targeted slices.** Preserve
   the explicit frame schedule, add focused coverage for each boundary, and
   remove wrappers only after their final consumer moves.

## 16. Immediate conclusions

Tiny Demons 0.2.81 remains past the legacy-coupling and editor-composition
cleanup. The latest composition validation reports 2,202 root accesses,
`GameplayState` at 1,717 lines / 286 fields, and `RoomController` at 2,250
lines; both the strict scorecard and editor-composition measure pass. The test
manifest validates at 143 rows, 141 runnable paths, two reports, and a 44-path
default gate. These are focused validation results, not a fresh run of the full
curated gate.

Content authoring is the active refactor work. The placement dock and Hub design
preview are landed. The enemy design-preview adapter now edits and saves its
typed definitions inline, while editor acceptance, the isolated interactive
workbench, and the remaining authoring lifecycle checks are still open. The
next sequence is to complete that shared M1 foundation, then continue the item
and element migration in Slice 2. The curated gate and device-backed
performance evidence remain separate open verification work. Keep future
structural work vertical and owner-led; do not reopen a broad composition
rewrite.
