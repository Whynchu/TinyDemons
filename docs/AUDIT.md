# Tiny Demons — Version 0.2.99 Codebase Audit

Status: canonical source audit for the `0.2.x` cycle after the composition refactor

Audit date: 2026-09-26

Baseline commit: `8b162a2410ebea45bfea2e846b427838663ad61d` (the `0.2.23` tree that
the measurements below describe; the `0.2.24` documentation/version checkpoint is
the first commit on top of it)

Baseline game version: `0.2.24`

Current release: `0.3.18` (composition refactor structurally and editor-wise
complete: the strict scorecard and regression floor both pass at 100%, with 2,198
root accesses and `GameplayState` at 1,717 lines / 286 fields. The debug-menu
dispatch added in 0.2.96 was extracted into `DebugSessionController` to restore
the floor.)

Supersedes: the `0.2.00` audit (`docs/AUDIT.md` at commit
`bfe55782f43ee40fe32b5bebd45de988e34579d8`). That document remains available in
Git history as the historical `0.2.00` baseline; this file is now the current
source-backed reference. Its pre-`0.2.24` numbers are retained in the historical
table in section 3 for comparison.

## Current measured snapshot (2026-09-26, version 0.2.99)

The detailed historical audit below describes the `0.2.32` tree. The current
`0.2.99` working tree measures:

| Metric | 0.2.32 audit | 0.2.99 working tree (2026-09-26) |
| --- | ---: | ---: |
| GDScript files in `scripts/` | 171 | 208 |
| `root.call/get/set` sites | 2,488 | 2,200 |
| `GameplayState` lines / fields | 1,719 / 286 | 1,718 / 286 |
| `RoomController` lines | 2,253 | 2,251 |
| `screen_state_controller.gd` lines | 5,432 | 5,571 |
| GDScript test/report files | 124 | 145 |
| Registered runnable smoke paths | 122 | 143 |
| Curated release-gate paths | 43 | 44 |
| Project Markdown documents under `docs/` | 89 | 100 |

The strict composition audit and the regression floor both pass at **100%**
(`validate_composition.ps1`: 2,200 root accesses, `GameplayState` 1,718 lines /
286 fields, `RoomController` 2,251 lines). The editor-composition metric reads
100% by its own definition, but
that metric counts component blindness, `@export` presence, and definition
scripts loading `.tres`; it does not prove that the authored data is typed,
validated, or read at runtime. Several catalogs are still untyped dictionaries
and several resource fields are ignored in favor of duplicated code constants -
see the trap register in [`authoring-system-plan.md`](authoring-system-plan.md).
Treat the metric as a regression guard, not an authoring-completeness claim.

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

These are 2026-09-15/16 readings and are **not** re-baselined by the
2026-10-02 polish pass, which changed the profile-write, prefab-reuse,
sprite-slice, and HUD count-up paths those numbers include. The harness now
reports real `layout_ms`/`activate_ms` instead of hardcoded `-1.0`, and gained
an `item_pickup` scenario, so the next run is comparable against these figures
for the first time. Treat the table above as the "before" row, not as current.

Readings:

- Steady-state headless frame time is ~6.9 ms (~145 fps) — the desktop CPU
  floor, not the mobile number.
- The scene holds ~900 sprites across ~1,650 nodes. A device profile decides
  whether node count is the binding cost.
- The regular room transition is ~15.3 ms.
- The 2026-10-02 pass removed the largest identified contributors from both the
  transition and the pickup frame: the synchronous profile write (which
  serialized, wrote, re-read, re-parsed, and rebuilt a profile, then did four
  more filesystem operations, once per transition and again on the pickup
  contact frame), the per-door-crossing room-scene re-instantiation, and the
  per-room-entry sprite re-slice that defeated the occlusion renderer's texture
  caches and forced a fresh per-pixel image pass each time. The `room_transition`
  and `profile_save_*` scopes plus the new `item_pickup` harness scenario exist
  to measure the result; **no post-change timing has been recorded yet.**
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
   unsaved edits. It now has a deterministic `Preview Death Effect` action
   using the runtime palette mapping and default effects tuning. Accept it after
   checking the catalog picker, starter creation, visible frame output,
   save/refresh lifecycle, geometry interaction, death-effect playback, and
   undo/redo. The dock now selects enemies, opens that design view, refreshes on
   saves/reimports, and starts a seeded factory-backed play process with isolated
   user data. Focused dock/session contracts are registered but unverified; use
   the connected editor to prove process cleanup and unchanged profile/settings.
   Enemy and item runtime discovery now uses kind-specific generated manifests,
   with a static dependency for each content kind; exported loading and
   add/move/delete lifecycle evidence remain open. Use the acceptance bars in
   `authoring-system-plan.md` rather than the editor composition percentage as
   proof.
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

Tiny Demons 0.2.99 remains past the legacy-coupling and editor-composition
cleanup. The latest composition validation reports 2,200 root accesses
(baseline 2,202), `GameplayState` at 1,718 lines / 286 fields (baseline 1,718),
and `RoomController` at 2,251 lines; the strict scorecard and editor-composition
measure both pass at 100%. The 0.2.96 debug-menu dispatch was moved out of the
composition root into `DebugSessionController`. The two stale player-combat and
recovery contract smoke scripts that no longer compiled were repaired and now
pass standalone (`spin_damage_smoke`, `active_run_recovery_contract_smoke`). The
test
manifest validates at 149 rows, 147 runnable paths, two reports, and a 44-path
default gate. These are focused validation results, not a fresh run of the full
curated gate.

Content authoring is the active refactor work. The placement dock and Hub design
preview are landed. The enemy design-preview adapter now edits and saves its
typed definitions inline. The dock also selects registered enemies, opens
their design preview, and launches a seeded factory-backed session in a child
process with separate user data. Dock/session contract checks are registered
but unverified; editor refresh, process cleanup, profile isolation, and visual
acceptance remain open. The next sequence is to close those M1 checks, then
continue the item and element migration in Slice 2. The curated gate and
device-backed performance evidence remain separate open verification work.
Keep future structural work vertical and owner-led; do not reopen a broad
composition rewrite.

## 17. Architecture cleanup (added 2026-09-27)

Recorded in [`ROADMAP.md`](ROADMAP.md) as an added 0.3.x workstream that is
explicitly sequenced as enabling work for the content-authoring and
verification track, rather than a competing rewrite.

Landed so far:

- **C0** (`f089c30`) removed a per-frame no-op regeneration call
  (`combat_runtime_controller.gd`, `gameplay_state.gd`,
  `gameplay_frame_controller.gd`) and glyph entries that were immediately
  overridden in `effects_spawner.gd`; the script index was regenerated and the
  one stale tuning reference corrected.
- **C1** (`357f62b`) cached the per-frame `DebugSessionController` lookup,
  skipped the per-frame `performance_capture_service` property lookup in release
  builds, and replaced the 200 ms sound-mix-profile file read-and-hash with a
  metadata stat. Verified by `sound_mix_live_reload_smoke`,
  `sound_mix_profile_smoke`, `sound_balance_smoke`, and
  `composition_root_baseline_smoke`.

Current composition check after C0/C1: **2,199** root accesses, `GameplayState`
**1,717** lines / 286 fields, `RoomController` 2,251 lines; the strict scorecard
and regression floor still pass.

Two wordings from the initial cleanup scan are corrected here: the title/save
overlap between `save_flow_controller.gd` and `screen_state_controller.gd` is
**circular delegation and split ownership**, not mutual recursion; and
`hub_flow_controller.gd` is a **split owner**, not an empty facade. The
"synchronous disk I/O in frame paths" finding was **understated** rather than
too broad. Pickup saves were coalesced into a pending flag, but the flag was
flushed on the same physics frame that queued it, so a single contact still
performed a full serialize + write + re-read + re-parse + profile rebuild, and
a room transition wrote unconditionally *and* again through gold settle — up to
three writes in one tick. The 2026-10-02 pass moved the write itself off the
requesting frame and removed the re-parse; see section 19.

## 18. Elemental status implementation follow-up (2026-09-28)

The working tree now contains the first four catalog-backed elemental statuses,
actor-local status components, player/enemy application and tick integration,
Chill movement/attack slow, Shocked periodic interruption, status HUD marks,
and the shared aura owner.
Death visibility also has a source fix: animation refresh/tick callbacks check
the player-dead state before exposing sprites, and death entry restores opaque
modulation before hiding the player. The reported transient magenta actor/hitbox
rectangle remains unexplained because no capture or reproducible source-backed
cause was available.

The newly registered status component, status combat, and player-death
visibility checks are still unrun. Focused offline script diagnostics passed
for the corrected HUD registration, animation context, frame-context builder,
animation component, and death visibility contract. Native-resolution visual
acceptance, cloak/death reproduction, catalog validators, and browser playtest
remain open. The user-reported HUD startup failure from casting a stored Array
to `Array[Sprite2D]` was corrected and its script diagnostic now passes.

## 19. Player polish pass (2026-10-02)

Three player reports, all fixed in source. Full detail and the pre-existing gate
failures found while verifying are in
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

**Fire Cinder Cone.** The lateral-only aim rule lived in
`begin_magic_animation`, which the ordinary tap-and-release cast never reaches
holding a form: a magic press starts a candidate animation with
`pending_magic_form = null` and the closest-enemy direction already resolved,
and the form is only captured on release. The rule is now
`apply_horizontal_cone_aim` and is called from both entry points, so the cone
resolves to left or right and the cast sprite re-faces to match. Other forms
keep their aimed vector. `tests/cone_aim_contract_smoke.gd` drives the real entry
point across both paths and fails on the pre-fix source.

**Orb-room Orb height.** `room_puzzle_controller.gd` carried a hard-coded
`ORB_ROOM_VISUAL_OFFSET := Vector2(0, -7)` on top of the authored `ORB_CENTER`
marker, floating the 9x9 art ~11 px above the floor surface, and the editor
preview sprite in `scenes/gameplay/rooms/orb_room.tscn` had been hand-mirrored to the same
offset. The constant is removed; the authored marker is the single source for
both the preview and the runtime orb. This also restores the release-gate
assertion that the `-7` had been silently failing.

**Transition and pickup hitches.** Both moments wrote the profile
synchronously inside one physics tick, and that write serialized, wrote,
re-read, re-parsed, and rebuilt a full profile before doing four more filesystem
operations. Nine changes: byte-length write verification instead of a re-parse;
a queued, rate-limited write that never lands on the requesting frame with
forced drains at every safe boundary; room prefabs reused by prefab rather than
by room ID; sprite sheets sliced once so the occlusion renderer's texture caches
actually hit; the floor tile polygon read once instead of per room entry; a
bounded HUD count-up with a cached reaction tint; pickup audio prewarmed at
boot; and cached `ItemCatalogData` projections. `room_transition`,
`profile_save_queue_delay`, and `profile_save_write` are now recorded scopes,
and the perf harness reports real layout/activate timings plus a new
`item_pickup` scenario.

**First post-change desktop run** (2026-10-02, seed `24681357`): single gold
contact **1.50 ms**; steady state ~6.9 ms avg / ~7.3 ms worst, unchanged;
boss entry 52.7 ms; regular room transition 41.0 ms. These are single samples
with no pre-fix comparison, and both transition figures sit inside the
already-documented 300–385 ms noise band, so they are **not** evidence that
the pass improved transitions. The 1.50 ms contact frame is consistent with the
profile write no longer being on it, but a pre-fix run is needed to call it an
improvement.

Composition after the pass: **2,200** root accesses, `GameplayState` **1,718**
lines / 286 fields, `RoomController` 2,251 lines. The regression floor and the
strict target audit both pass.

**Verification state.** `cone_aim_contract_smoke` (new) and
`run1_room_prefab_smoke` pass; so do `cloud_save_contract_smoke`,
`active_run_recovery_contract_smoke`, `demon_cloak_smoke`, `drop_art_smoke`,
`entry_orb_visual_smoke`, `gear_catalogue_expansion_smoke`,
`gear_drop_policy_smoke`, `item_drop_scene_smoke`, `combat_momentum_smoke`,
`fusion_candidate_cache_smoke`, and `frame_time_smoke`. The pre-existing
`hub_binding_smoke`, `equipment_menu_scene_smoke`, and `imbue_spell_scene_smoke`
gate failures are unrelated to this pass and are recorded in
`KNOWN_ISSUES.md`. **No rendered playtest, device profile, or A/B comparison
has been captured**; the 2026-09-15/16 table in section 11 is a "before" row and
this pass does not claim to have moved section 11.2.

## 20. Element affinity, Wet, contact transmission, and run themes (2026-10-03)

The full elemental-affinity implementation is now present in the working tree.
`StatusRecord` separates permanent innate affinity from temporary applied
ailments; the catalog now registers Wet. Innate enemy statuses are harmless,
blocked by authored immunity, suppressed by applied statuses, and excluded from
mechanical modifiers while innate. Wet amplifies Electric damage, shortens
Shocked cadence, removes applied Burn stacks, and shares the Water bubble
texture. Contact transfer is bidirectional, captures source payloads before any
pair applies, guarantees eligible contact transfer subject to immunity and
special-defense gates, and uses one unordered
three-second pair cooldown with room and spawn-generation isolation.

`RunState` serializes a deterministic enemy-element theme. Rank 1 remains
Normal-only, rank 2 teaches one element, and rank 3+ usually uses two with a
configured 20% chance for three. `EncounterDefinition` favors the authored
Water/Electric synergy and migrates cached legacy rosters deterministically;
`RoomController` constrains generated and cached room/boss rosters. Elemental
healer variants use the shared ally-healing behavior. Active-run migration keeps
health, Chroma, death flags, levels, and pickup state in the existing slot
records while changing only off-theme variants and dependent ambush flags.

Focused smoke source now covers Wet/innate state, transfer cooldown/suppression,
same-frame propagation prevention, run-theme serialization, healer filtering,
and legacy roster migration. The smoke checks are registered but not executed.
This is **implemented in source**, not verified. Godot parsing, definition and
catalog validation, native 240x160 readability, run-seed frequencies and
migration, combat balance, and browser playtesting remain acceptance work.
