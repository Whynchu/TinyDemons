# Tiny Demons — Composition Refactor Analysis and Handoff

Status: historical / implemented (legacy-coupling cleanup complete)
Scope: runtime composition, component ownership, dependency direction, and the next refactor sequence
Owner: repository refactor / architecture
Current code: `gameplay.gd`, `gameplay_state.gd`, `gameplay_bootstrap.gd`, `chest_reward_context.gd`, `run_settlement_context.gd`, `run_settlement_result.gd`, `room_checkpoint_context.gd`, `room_checkpoint_result.gd`, `run_checkpoint_context.gd`, `run_checkpoint_result.gd`, `run_checkpoint_service.gd`, `room_clear_context.gd`, `room_clear_result.gd`, `room_entry_context.gd`, `room_entry_result.gd`, `room_entry_services.gd`, `room_activation_context.gd`, `room_activation_services.gd`, `room_enemy_context.gd`, `room_spawn_context.gd`, `room_respawn_context.gd`, `room_enemy_placement.gd`, `room_enemy_spawn_services.gd`, `room_enemy_runtime_context.gd`, `room_enemy_runtime_result.gd`, `room_geometry_controller.gd`, `menu_player_context.gd`, external tuning resources under `resources/tuning/`, feature components/controllers, and `gameplay_frame_controller.gd`
Baseline commit: `d6a965d` (2026-09-15); final measured state: `8b162a2` (2026-09-16, version `0.2.23`)
Verification: see the named evidence and commands in the Verification section below
Supersedes: none; this document extends the completed `refactor-route.md` Phase C. **The legacy-coupling cleanup it tracked is now complete (100% on the strict scorecard at `0.2.23`/`0.2.24`).** This file is retained as the historical completion record and handoff. The active authority for the broader post-cleanup direction is [`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md), and the current measured baseline is [`AUDIT.md`](AUDIT.md).

This document records where Tiny Demons was during the legacy-coupling
cleanup. It is now a historical completion record: the migration sequence it
describes has finished, and the scorecard it tracked is fully green. It
describes the migration shape and order for anyone who needs to understand why
the current boundaries exist; it does not authorize further rewrites or
gameplay-balance changes. The broader goal—content definitions, runtime
factories, authoring workflows, and performance budgets—is defined in
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md).

## Relationship to `refactor-route.md`

`refactor-route.md` is the accepted execution plan for the `0.2.x` cycle. Its
slices B1–B6 and Phase C are marked complete on 2026-08-22. This document does
not supersede that route; it **follows it**. The route remains the record of
what was executed; this document is the handoff for the next sequence after the
route's completed slices. If the two disagree about ordering, this document's
migration sequence is the current intent for the narrow post-Phase-C cleanup.
The long-term plan is the authority for what the finished
content/composition project must make possible.

## Executive summary

Tiny Demons already uses Godot-style composition in several important areas:
scene-authored objects are assembled with child nodes, runtime components are
attached during bootstrap, and the player/slime systems have focused behavior
owners. The project is not starting from a monolithic script anymore.

The remaining problem is that many of those components and controllers still
communicate through `GameplayState` using dynamic `root.call/get/set` access.
The pieces are separated physically, but their dependencies are often implicit.
`GameplayState` is simultaneously the composition root, mutable state bag,
compatibility API, and service locator.

The current architectural task is therefore:

> Make the existing composition honest by giving each vertical slice explicit
> owners, typed dependencies, typed commands/results, and intentional signals.

This is a staged consolidation, not a universal conversion of every script into
a Node or every method into a component.

### Progress estimate — 100% measured ownership progress (complete)

The legacy-coupling cleanup tracked by this document is **complete**. The
authoritative number is the completion percentage printed by
`tools/validate_composition.ps1`, which measures weighted progress from the
recorded `completion_start` toward the strict targets and now reads **100%**.
The strict audit (`-RequireTargets`) passes; it is no longer expected to fail.
The accepted floor in `tools/composition-baseline.json` is the achieved state,
so the guardrail now protects against regression rather than tracking an open
migration.

The scorecard at final measurement (`0.2.23`, commit `8b162a2`):

| Hard gate | Baseline (`d6a965d`) | Final (`8b162a2`) | Status |
|---|---:|---:|---|
| Meaningful reduction in dynamic `root.call/get/set` sites | 3,140 | 2,488 | `[x]` below the ≤2,499 strict target |
| `GameplayState` smaller than the pre-slice baseline | 1,720 lines / 287 fields | 1,719 lines / 286 fields | `[x]` at the strict target |
| `RoomController` below its pre-refactor baseline | 2,297 lines | 2,253 lines | `[x]` below the ≤2,296 strict target |
| `.runtime` references in contexts | 20 | 0 | `[x]` |
| Paired legacy/context duplicates | 11 | 0 | `[x]` |
| Transitional `GameplayState`-backed contexts | 5 | 0 | `[x]` |
| At least one direct typed context used end-to-end | none counted | `RoomEnemyContext`, `RoomSpawnContext`, `RoomRespawnContext`, `RoomEnemyRuntimeContext`, `ChestRewardContext`, `RoomClearContext`, `RoomCheckpointContext`, `RunSettlementContext`, `ActiveRunSnapshotContext`, `RunCheckpointContext`, `MenuPlayerContext`, plus the `room_entry_services.gd` / `room_activation_services.gd` owners | `[x]` |

The final room entry/activation work retired the last two transitional
adapters (`RoomEntryContext` and `RoomActivationContext` no longer carry
`GameplayState`); entry and activation now run through direct typed owners in
`room_entry_services.gd` and `room_activation_services.gd`. The
`composition-baseline.json` target values (≤2,499 root sites, ≤1,719/286
`GameplayState`, ≤2,296 `RoomController`, 0 `.runtime`, 0 legacy pairs, 0
transitional contexts) are all met, so the strict audit is green.

The strict scorecard measures architectural ownership, not gameplay value.
This 100% figure means the state-bag dependency is removed, the compatibility
duplicates are retired, and the seam count is below target. It does not mean
content authoring is compositional or that device performance is proven; those
are the T2/T3 tracks in
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md).

The measured score advances only when a slice earns measurable credit against
these pinned thresholds, not when it merely adds a typed class:

- **Root access threshold:** total `root.call/get/set` sites must fall below
  **2,500** before the root-dependency milestone is considered crossed; each
  completed slice must also reduce its own owner's count.
- **State-bag threshold:** `GameplayState` must be below its pre-slice baseline
  (1,720 lines / 287 fields) before the state-bag migration is considered
  complete. The weighted aggregate may advance before this individual gate is
  closed because the other metrics are measured independently.
- **Owner-size threshold:** `RoomController` must be below its pre-refactor
  baseline (2,297 lines) or have a clear extracted owner that removes at least
  500 lines from the coordinator.
- **Slice integrity:** a slice earns no credit while it has a parallel
  `*_legacy` or root-shaped implementation of the same behavior, or a context
  that stores `GameplayState`.

The thresholds are guardrails for interpreting the weighted score, not a reason
to claim completion from one favorable metric. A slice should move the access
surface, its owner, and its compatibility debt together wherever the behavior
allows it.

## Current measured shape

These are the **final** measurements from the working tree on 2026-09-16
(commit `8b162a2`, version `0.2.23`); `d6a965d` remains the pinned comparison
baseline from which the cleanup started. To regenerate them, run the PowerShell
one-liner in the Measurement command section below.

| Surface | Measurement | Interpretation |
|---|---:|---|
| Runtime GDScript files | 171 | There are enough existing boundaries to refactor vertically |
| Runtime physical lines | 48,329 | Large enough that broad mechanical migration is unsafe |
| Runtime non-blank lines | 42,659 | Blank lines are excluded; comments remain counted |
| Explicit `*Component` classes | 20 | Entity-level composition is established |
| Named functions | 2,684 | Function count is not a reason to create more wrappers |
| `GameplayState` lines | 1,719 | At the strict target; remains the shared-state surface |
| `GameplayState` functions | 479 | Remaining forwarding/compatibility methods |
| `GameplayState` declared fields | 286 | At the strict target; state is distributed to owners |
| `gameplay.gd` lines | 233 | The coordinator is slim; seams moved into typed owners |
| Dynamic `root.call/get/set` sites | 2,488 | Below the ≤2,499 strict target; remaining sites are the next migration seams |

The largest dynamic-access concentrations (the next vertical migration targets):

| Script | Lines | Dynamic root accesses | Architectural concern |
|---|---:|---:|---|
| `screen_state_controller.gd` | 5,432 | 326 | Menu construction, input, layout, and presentation remain mixed |
| `combat_runtime_controller.gd` | 795 | 222 | Combat integration still reaches through the root |
| `room_controller.gd` | 2,243 | 216 | Room lifecycle, encounters, persistence, and rewards overlap |
| `slime_runtime_controller.gd` | 805 | 195 | Reusable slime components still rely on a broad runtime context |
| `magic_runtime_controller.gd` | 686 | 141 | Magic state and presentation have remaining coordinator seams |
| `room_geometry_controller.gd` | 291 | 0 | Direct typed owner for boss geometry snapshots and camera setup |
| `gameplay_frame_controller.gd` | 266 | 0 | Explicit phase ordering crosses a typed `GameplayState` boundary |

## Measurement command

The following was used to produce the table above. It counts `scripts/*.gd`
only; test scripts, tools, and add-ons are not runtime code.

```powershell
$files = Get-ChildItem scripts -Filter *.gd
"files=$($files.Count)"
$phys = 0; $nonblank = 0
foreach ($f in $files) { $lines = Get-Content $f.FullName; $phys += $lines.Count; $nonblank += ($lines | Where-Object { $_.Trim() -ne '' }).Count }
"physical_lines=$phys"
"non_blank_lines=$nonblank"
"components=$((Get-ChildItem scripts -Filter '*Component*.gd').Count)"
$gs = Get-Content scripts/gameplay_state.gd
"gameplay_state_lines=$($gs.Count)"
"gameplay_state_functions=$(($gs | Where-Object { $_ -match '^func\s' }).Count)"
"gameplay_state_fields=$(($gs | Where-Object { $_ -match '^(var|const)\s' }).Count)"
"gameplay_lines=$((Get-Content scripts/gameplay.gd).Count)"
$total = 0
foreach ($f in $files) { $c = Get-Content $f.FullName -Raw; $total += ([regex]::Matches($c, 'root\.(call|get|set)\(')).Count }
"root_dynamic_accesses=$total"
```

## What is already compositional

### Scene and bootstrap composition

`main.tscn` authors the durable world and actor nodes. `GameplayBootstrap` adds
runtime services/controllers and attaches player/enemy components. This is the
correct Godot shape for objects whose lifetime, signals, or scene participation
matter.

The bootstrap already wires meaningful events, including health changes, motor
motion, room entry/clear, input-device changes, and Chroma/equipment reactions.
That wiring should be extended deliberately rather than replaced with a new
global event bus.

### Entity components

The strongest examples are:

- player movement, attack, guard, roll, animation, equipment, health, Chroma,
  and ability components;
- slime brain, combat, animation, visual, health-presenter, ambush, and tactics
  components; and
- focused pickup, interaction, rest-fire, shadow, and presentation nodes.

These are useful components because they have a recognizable owner and a
meaningful lifecycle or state boundary. They should not be flattened back into
the coordinator.

### Feature controllers

Controllers are appropriate when behavior crosses multiple entities or owns a
feature workflow. `RoomController`, `RunFlowController`, `PickupRuntimeController`,
`ProfileRuntimeController`, `DisplayController`, and `SaveFlowController` are
examples. A controller is not a failed component merely because it is larger;
the important question is whether its inputs and outputs are explicit.

### Typed boundaries: direct versus transitional

> Historical note: this section records the mid-migration distinction used to
> judge slices as they landed. The final state at `0.2.23` has **no** remaining
> transitional adapters: `RoomEntryContext` and `RoomActivationContext` no longer
> store `GameplayState`, entry/activation run through direct typed owners in
> `room_entry_services.gd` / `room_activation_services.gd`, and the transitional
> allowlist is empty. It is retained here to explain the judgement rule.

The refactor has established useful typed results and contexts, but their names
do not all mean the same architectural thing. The distinction below is part of
the handoff and must remain explicit.

Genuinely direct contexts currently include:

- `ChestRewardContext`, which passes profile/run data directly to the reward
  decision without a `GameplayState` field;
- `RoomClearContext`, which passes the room identity and authored record to the
  room-clear owner;
- `RoomCheckpointContext`, `RoomEnemyRuntimeContext`, and
  `ActiveRunSnapshotContext`, which pass direct room, component, controller,
  and scalar inputs to snapshot/serialization boundaries;
- `RoomEnemyContext`, `RoomSpawnContext`, and `RoomRespawnContext`, which pass
  direct room, actor, tuning, RNG, placement, and spawn-service inputs through
  the enemy lifecycle;
- `RunCheckpointContext` and `RunSettlementContext`, which compose direct
  persistence inputs; and
- `MenuPlayerContext`, which supplies direct profile, snapshot, tuning,
  component, palette, and portrait inputs to the migrated pause/Hub presenters.

The typed result contracts paired with these contexts remain useful:
`RoomTransitionResult`, `RoomActivationResult`, `RoomSpawnResult`,
`RoomClearResult`, `RoomEntryResult`, `RoomEnemyRuntimeResult`,
`ChestRewardResult`, `RunSettlementResult`, `RoomCheckpointResult`, and
`RunCheckpointResult` are all real boundary improvements. The six default
tuning resources under `resources/tuning/` are also real composition-root
improvements because each runtime receives an isolated duplicate.

The following room contexts are **transitional adapters, not completed narrow
contexts**:

- `RoomEntryContext` stores `GameplayState` and a transition result. Its entry
  owner still discovers most of its actual dependencies through that runtime;
- `RoomActivationContext` stores `GameplayState` and `RoomController`, then
  copies a few fields from the runtime. It does not own the activation inputs;
- `RoomSpawnContext` and `RoomRespawnContext` are now direct subclasses of
  `RoomEnemyContext`; they no longer store or inherit `GameplayState` and are
  not transitional; and
- `RoomRuntimeContext` has been removed. The direct enemy slice uses
  `RoomEnemySpawnServices` and the pure `RoomEnemyPlacement` helper instead;
- the corresponding `*_context` methods in `RoomController` still have
  parallel root-shaped implementations and call back into the remaining
  transitional contexts.

The remaining adapters make some call sites look typed, but they do not yet
reduce the state-bag coupling. A context containing `GameplayState`, or whose
completed operation still relies on `context.runtime`, cannot receive `[x]`
credit in the strict scorecard. Do not copy this shape into another feature. The
enemy spawn/respawn slice is now the reference for replacing an adapter with
direct typed dependencies without throwing away useful result contracts.

Before relying on any boundary as release or architecture evidence, confirm the
file is tracked, the owning test passes, and the slice demonstrates reduced
dynamic access or retired compatibility code.

## What is still only partially compositional

### `GameplayState` is doing four jobs

It currently acts as:

1. the composition root;
2. the shared mutable runtime state container;
3. the compatibility facade for older callers; and
4. the dynamic dependency hub used by controllers.

The first role is necessary. The other three should shrink gradually. Do not
remove the state root all at once; migrate ownership slice by slice and retain a
wrapper until its last consumer is gone.

### Dynamic root access hides dependency direction

Calls such as these are migration seams, not the desired endpoint:

```gdscript
root.call("_update_player_health_ui")
root.get("player_profile")
root.set("room_transition_locked", true)
```

They make it difficult to know what a controller requires, make renames
runtime-fragile, and allow a feature owner to reach unrelated state. The goal is
not zero calls immediately. The goal is to reduce them in a completed vertical
slice and replace them with direct typed references, narrow context objects, or
signals.

### Some "components" are still root-dependent

The existence of a file named `*_component.gd` does not prove architectural
independence. A component is genuinely compositional when its required state is
owned by it or passed through a narrow interface. If it requires most of
`GameplayState`, it is currently a component-shaped adapter and should be
refined later through its owning slice.

### Large feature owners remain mixed

`ScreenStateController`, `RoomController`, `HubFlowController`,
`PlayerEquipmentVisualComponent`, `ItemCatalog`, and `TouchControlsLayer` each
contain multiple related concerns. Their size alone does not justify a split.
First characterize a boundary, then move one complete responsibility with its
state and tests.

## Target composition model

The intended runtime relationship is:

```text
main.tscn
└── GameplayState / composition root
    ├── GameplayBootstrap wires typed owners
    ├── GameplayFrameController orders phases
    ├── entity components own local state and behavior
    ├── feature controllers coordinate cross-entity workflows
    ├── typed commands/results describe boundaries
    ├── signals describe meaningful domain events
    └── tuning Resources provide designer-facing data
```

For a feature such as chest rewards:

```text
ChestController
    → requests reward resolution
RunFlowController
    → generates deterministic items and returns ChestRewardResult
RoomController
    → persists the room claim marker
PickupRuntimeController
    → presents world drops
ProfileRuntimeController
    → owns permanent profile mutations when required
```

The feature should not need to discover every service through the root. A narrow
typed context or direct reference should make its dependencies visible.

## Current migration sequence

Status legend: `[x]` complete, `[~]` in progress, `[ ]` not started. These
statuses reflect the current working tree; update them as slices land.

### 1. Finish the reward boundary — [x]

The item-reward decision now lives in `RunFlowController` and returns
`ChestRewardResult`. The reward path now receives a narrow typed
`ChestRewardContext`; persistence and settlement ordering now have explicit
typed boundaries:

- keep `ChestController` responsible for interaction and presentation timing;
- keep `RoomController` responsible for room claim persistence;
- keep `RunState` responsible for telemetry;
- keep profile mutations in profile/progression owners; and
- keep browser durability characterization as a separate verification task.

Do not change reward probabilities or item balance during this structural pass.

### 2. Prove one direct typed dependency migration — [x]

The chest/reward path is the first committed example. `ChestController` receives
typed `RunFlowController`, `RoomController`, and `PickupRuntimeController`
references; `RunFlowController` receives only the narrow reward context; and the
result returns generated item data without owning presentation side effects.
The context is intentionally smaller than `GameplayState`. The extracted reward
method has no `root.call/get/set` accesses; the remaining dynamic accesses in
`ChestController` belong to the other interaction and presentation paths and
are separate migration work. The context and dependency code is now committed;
those remaining accesses are separate migration work.

Completion evidence should include:

- the migrated owner has fewer dynamic root accesses;
- its public inputs/outputs are typed;
- its frame ordering is unchanged;
- the focused characterization tests still pass; and
- the obsolete wrappers are removed only after their final consumer migrates.

### 3. Migrate checkpoint and settlement — [x]

Checkpoint ordering crosses room, map, profile, active-run, and settlement
boundaries. The settlement domain has committed `RunSettlementContext` and
`RunSettlementResult`; `RunFlowController` preserves the existing
save-before-`RunState.mark_settled` ordering while using that typed boundary.
Room-state assembly has committed `RoomCheckpointContext` and
`RoomCheckpointResult`; `GameplayState` captures enemy runtime through the
direct `RoomEnemyRuntimeContext` and `RoomEnemyRuntimeResult`, then delegates
dictionary assembly to `RoomController`. The active-run file write still needs
browser durability evidence, which is a verification task rather than an
ownership gap. `RunCheckpointService` owns the ordered room → profile →
active-run writes, and the room-clear event crosses the composition boundary as
`RoomClearResult` rather than a loose room ID. `GameplayState` retains only the
web-checkpoint eligibility guard and the compatibility checkpoint wrapper;
those are the remaining compatibility facade, tracked with the state-bag
wrapper until their final consumers migrate.

### 4. Rework room lifecycle ownership — [x]

The clear event is explicit: `RoomController.mark_cleared_context()` owns the
mutation and returns `RoomClearResult`; the map controller and checkpoint
consumer receive that typed event. Room entry and activation now run through
direct typed owners: `room_entry_services.gd` and `room_activation_services.gd`
consume `RoomEntryContext` / `RoomActivationContext` without a `GameplayState`
dependency, returning `RoomEntryResult` / `RoomActivationResult`. The final
slice retired the last two transitional adapters and reduced the guardrail's
transitional allowlist to zero. The ID-based `mark_cleared()` and
`enter_connected_room()` methods remain compatibility facades for direct
callers.

Room-level initial spawn orchestration now consumes `RoomSpawnContext`, and the
normal frame schedule sends respawn ticks through `RoomRespawnContext`. Both are
direct `RoomEnemyContext` slices backed by `RoomEnemySpawnServices`, which is
composed from typed references and callbacks in `GameplayBootstrap`. Pure
placement rules live in `RoomEnemyPlacement`; neither the contexts nor the
placement helper reaches through `GameplayState`.

The normal Combat path also sends the room-owned death consequences through
`record_enemy_death_context()`. The enemy spawn/respawn root-shaped bodies and
their duplicate legacy helpers have been retired. This is the first room slice
that demonstrates the intended pattern end to end; the remaining lifecycle
debt at that point was entry/activation, where two transitional contexts
remained.

**Final state:** the entry/activation debt was subsequently closed at `0.2.23`.
`RoomEntryContext` and `RoomActivationContext` no longer carry `GameplayState`;
`room_entry_services.gd` and `room_activation_services.gd` own entry/activation
with direct typed dependencies, and the transitional allowlist is empty.

#### Room geometry ownership — [x]

`RoomGeometryController` now owns the authored boss-room template, normal-room
geometry snapshot/restore, boss underlay and return-guide setup, and the
large-room camera. `GameplayBootstrap` composes it with direct references to
the map, floor, player, display controller, and scene path. `RoomController`
retains thin compatibility delegates for older callers, but no longer reaches
through `GameplayState` to perform geometry work.

This slice removed the `normal_room_geometry` field from `GameplayState`,
retired the room geometry implementation from `RoomController`, and reduced
that controller from 2,447 to 2,243 lines and from 245 to 216 dynamic root
accesses. `boss_geometry_scene_smoke` and `generated_run_scene_smoke` cover the
authored and generated boot/transition paths.

Room entry must come later: it crosses the most systems and is the most likely
target to produce another oversized context if attempted first. Preserve the
authored/generated room distinction and the central frame schedule while
migrating it.

Focused evidence for this slice:

- `room_transition_result_smoke`: typed clear result, idempotency, and single
  event emission.
- `enemy_room_engagement_smoke`: map clear behavior remains intact.
- `enemy_room_entrance_scene_smoke`: composed room wiring, typed initial spawn,
  and normal-frame respawn dispatch remain intact.
- `special_respawn_policy_smoke`: special-room timer policy remains intact
  through the direct context fixture path.
- `boss_geometry_scene_smoke`: boss room composition remains intact.
- `generated_run_scene_smoke`: typed room-entry and activation path remains
  intact during generated traversal.

These checks prove that the behavior survived the seam extraction; they do not
prove that the room contexts are narrow or that ownership moved out of
`GameplayState`. `popcorn_respawn_smoke` is now manifest `verified`; its fixture checks the
waiting-before-clear contract, seeded 30–45 second schedule, support respawn,
and sealed boss entrance.

#### Frame-schedule dependency boundary — [x]

`GameplayFrameController` now accepts a typed `GameplayState` reference and
reads/writes the scheduled state through direct properties and methods. The
explicit input → simulation → contact → damage → presentation → transition
ordering is unchanged. The scheduler no longer uses `root.call/get/set`; the
remaining dynamic calls in this file target generic collaborator nodes such as
the minimap and aspect-ability components and are outside the root seam metric.

This slice removed 205 dynamic root accesses (`2,931` → `2,726`) without adding
a universal context or moving frame behavior into another coordinator. The
validator moved from 70.6% to 82.5%. Focused evidence includes
`generated_run_scene_smoke`, `boss_geometry_scene_smoke`,
`enemy_room_entrance_scene_smoke`, `room_transition_result_smoke`, and
`typed_combat_path_smoke`; the headless editor import scan also passed.

### 5. Tackle menus after the runtime pattern is proven — [~]

`ScreenStateController` is the largest remaining owner, but it should not be the
next broad extraction by default. `MenuPlayerContext` now supplies the pause
root card, pause Status page, and Hub player summary with profile, combat and
progression snapshots/tuning, health, Chroma, palette, and portrait
dependencies. Continue one screen at a time while preserving native 240×160
geometry and touch/controller behavior; the remaining settings, save,
equipment, and transaction workflows still use the mixed controller.

### 6. Move tuning data deliberately — [x]

The six existing tuning classes now have external defaults in
`resources/tuning/*.tres`. `GameplayState` deep-duplicates each resource per
runtime, preserving test/debug overrides without allowing one runtime to mutate
the cached inspector default. Future hardcoded knobs can be added incrementally
without reopening this ownership migration.

## Verification

The manifest validator and focused standalone Godot checks for this slice pass:

- `tools/run_headless.ps1 -Editor`: import scan completed successfully,
  including the typed room and menu contexts.
- `room_transition_result_smoke`.
- `enemy_room_engagement_smoke`.
- `enemy_room_entrance_scene_smoke` (typed initial spawn path).
- `special_respawn_policy_smoke` (respawn timer policy through the legacy
  fixture boundary).
- `boss_geometry_scene_smoke`.
- `generated_run_scene_smoke`.
- `popcorn_respawn_smoke` (waiting, seeded schedule, support respawn, entrance
  seal).
- `typed_combat_path_smoke` (typed combat damage and room-owned death boundary).
- `pause_menu_scene_smoke` (typed player-card/status context plus existing
  layout and route contract).
- `composition_root_baseline_smoke` (six external tuning resources and isolated
  per-runtime copies).
- Fresh-output `tests/web_export_smoke.ps1 -RequireExport` (single-threaded
  Compatibility payload; `.wasm` and `.pck` present).
- `tools/validate_test_manifest.ps1`: 124 rows, 122 runnable paths, 2 report
  rows, and 43 curated-gate paths.
- `tools/validate_composition.ps1`: **100%** measured ownership progress; the
  strict audit (`-RequireTargets`) passes. All strict targets are met, the
  transitional allowlist is empty, and the geometry, frame-schedule, and
  entry/activation slices are below their accepted owner floors with zero
  paired legacy implementations.
- Curated `tests/run_all_smoke.ps1 -TestGroup gate`: no engine crash; SFX
  pytest 25/25, Web export (`wasm=1`, `pck=1`), and main-scene boot pass. The
  runner remains nonzero only for the documented legacy `run1_door_path_smoke`
  mismatch and the two restricted-host settings persistence findings.

Use the manifest-driven runner for repeatable checks. For example:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1 `
  -TestGroup all -TestFilter '*enemy_room_entrance_scene_smoke'
```

The Windows root-certificate warning and headless editor-settings persistence
warning are environment warnings. The local web export can fail if an old
ignored `dist/` payload is locked; the fresh temporary-output export is the
reliable local evidence. Browser/device/hosted-Pages behavior remains open,
and `run1_door_path_smoke` remains the known verified legacy room-lock
regression; neither is evidence against the typed room slice.

## Refactor rules for the next agent

- Preserve the explicit frame schedule.
- Add characterization coverage before moving behavior. Characterization must
  replace or consolidate an existing test when the verification-surface audit
  freeze is active; do not grow the test inventory for each slice.
- Prefer a direct typed reference over a new reflective call.
- Prefer a narrow context over a universal runtime context.
- Never add `GameplayState` as a field or constructor dependency to a context
  intended to represent a completed slice. Existing room contexts with that
  shape are transitional adapters and must remain labeled as such.
- A typed method name is not enough for completion credit: inspect the body for
  `context.runtime`, root reflection, and a parallel `_legacy` implementation.
- Every completed slice must report before/after dynamic-access counts, the
  relevant owner size/state change, and the compatibility code that was
  retired. If those numbers do not improve, record the work as a seam or
  characterization step rather than an ownership migration.
- Use signals for events, not as a replacement for every function call.
- Keep state with the owner that has the authority to change it.
- Do not split a file solely because its line count is large.
- Do not mix gameplay balance changes into ownership migrations.
- Do not remove compatibility wrappers until their final consumer is migrated.
- Run a focused test first, then the relevant owner group, then the supervised
  curated gate when no Godot editor peer is active. Use the manifest-driven
  runner: `tests/run_all_smoke.ps1` with `-TestGroup gate`, `-TestGroup owner`,
  or `-TestGroup all`. Test roles and states are tracked in
  `tests/manifest.csv` and `docs/verification-surface-audit.md`.

## Architecture guardrail

The manifest validator (`tools/validate_test_manifest.ps1`) enforces the test
inventory. The composition refactor has an equivalent structural guard,
`tools/validate_composition.ps1`, wired into the same CI and runner preflight.
Its default mode is a **regression floor**: it passes the current open debt but
fails when a future change makes that debt worse. It checks for:

- a context that declares or accepts `GameplayState`, outside the transitional
  allowlist stored in the baseline JSON;
- `.runtime` access in a context that is not transitional;
- a new parallel `*_legacy`/`*_context` pair, including changes that keep the
  total duplicate count unchanged; and
- root-access, `GameplayState`, `RoomController`, `.runtime`, or duplicate-count
  regressions against the accepted baseline.

Run `-SelfTest` to exercise the guard against temporary valid, coupling,
duplicate, regression, and strict-target fixtures. Run `-RequireTargets` as the
strict completion audit; it now **passes** (the final target values were met at
`0.2.23`, commit `8b162a2`). The normal CI gate uses the regression floor,
which now protects the achieved state from future regressions.
`-UpdateBaseline` preserves `completion_start`, so the percentage measures
progress since the original reference and cannot be re-zeroed by a routine
baseline refresh.

The default output now also prints a **completion percentage**: weighted
progress from the recorded `completion_start` toward the strict targets, where
each metric is weighted by the size of its remaining gap. It starts at 0% and
climbs only when a slice measurably reduces a metric; a metric that grows
beyond its start contributes zero progress (clamped, never negative credit).
`-UpdateBaseline` preserves `completion_start`, so the percentage measures
progress since the original reference and cannot be re-zeroed by a routine
baseline refresh.

The validator reads `tools/composition-baseline.json`, which records the
accepted floor, the `completion_start` reference, and the strict target
thresholds. Use `-UpdateBaseline` only when a reviewed slice deliberately
retires coupling or extracts an owner; it refuses to write when the current
tree has audit errors. Run it with `-BaselinePath`/`-ScriptsDirectory` to test
against a different tree.

Current recorded baseline, completion start, and strict targets (from
`tools/composition-baseline.json`):

| Metric | Accepted floor | Completion start | Strict target |
|---|---:|---:|---:|
| `root.call/get/set` sites | 2,726 | 3,135 | ≤ 2,499 |
| `GameplayState` lines / fields | 1,772 / 298 | 1,777 / 299 | ≤ 1,719 / 286 |
| `RoomController` lines | 2,243 | 3,265 | ≤ 2,296 |
| `.runtime` references | 5 | 20 | 0 |
| Paired legacy/context duplicates | 0 | 11 | 0 |
| Transitional contexts | 2 | 5 | 0 |

The accepted floor is the regression baseline. The strict target column is now
met, so both the regression floor and `-RequireTargets` are green.

The transitional allowlist is now empty; the final slice retired the last two
adapters:

- `RoomEntryContext` and `RoomActivationContext` no longer declare or accept a
  `GameplayState` dependency; entry and activation run through direct typed
  owners in `room_entry_services.gd` and `room_activation_services.gd`;
- `RoomSpawnContext` and `RoomRespawnContext` are direct typed contexts (not
  transitional); `RoomRuntimeContext` has been removed; and
- `MenuPlayerContext` and `RunCheckpointContext` mention `GameplayState` only in
  comments and do not store it — they are not transitional and were never added
  to the allowlist.

The current regression-floor output lists zero paired duplicates and zero
transitional contexts. The strict target audit is also green. The self-test and
regression-floor run are wired into CI and the smoke runner so the guard itself
is exercised before gameplay tests begin.

## Handoff checklist

Before declaring a slice complete, record:

- the owner and state authority;
- the typed command/context/result boundary;
- the signals and direct dependencies involved;
- the dynamic root-access reduction;
- characterization and integration test results (named tests, not "the suite");
- any manual/native/browser evidence still outstanding; and
- the next smallest slice.

The success condition is not that every script is tiny. It is that a human or
agent can locate a feature, understand its dependencies, change it safely, and
verify it without reading the entire coordinator.
