# Tiny Demons — Composition Refactor Analysis and Handoff

Status: active handoff
Scope: runtime composition, component ownership, dependency direction, and the next refactor sequence
Owner: repository refactor / architecture
Current code: `gameplay.gd`, `gameplay_state.gd`, `gameplay_bootstrap.gd`, `chest_reward_context.gd`, `run_settlement_context.gd`, `run_settlement_result.gd`, `room_checkpoint_context.gd`, `room_checkpoint_result.gd`, `run_checkpoint_context.gd`, `run_checkpoint_result.gd`, `run_checkpoint_service.gd`, `room_clear_context.gd`, `room_clear_result.gd`, `room_entry_context.gd`, `room_entry_result.gd`, `room_activation_context.gd`, `room_spawn_context.gd`, `room_respawn_context.gd`, `room_runtime_context.gd`, `room_enemy_runtime_context.gd`, `room_enemy_runtime_result.gd`, `menu_player_context.gd`, external tuning resources under `resources/tuning/`, feature components/controllers, and `gameplay_frame_controller.gd`
Baseline commit: `d6a965d` (2026-09-15)
Verification: see the named evidence and commands in the Verification section below
Supersedes: none; this document extends the completed `refactor-route.md` Phase C and becomes the authoritative sequence for the next composition phase

This document explains where Tiny Demons is relative to its long-term
composition goal. It is intended for a future human or agent taking over the
refactor. It describes the current shape and migration order; it does not
authorize a rewrite or a gameplay-balance change.

## Relationship to `refactor-route.md`

`refactor-route.md` is the accepted execution plan for the `0.2.x` cycle. Its
slices B1–B6 and Phase C are marked complete on 2026-08-22. This document does
not supersede that route; it **follows it**. The route remains the record of
what was executed; this document is the handoff for the next sequence after the
route's completed slices. If the two disagree about ordering, this document's
migration sequence is the current intent for post-Phase-C work.

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

### Progress estimate — 25% strict ownership score

The previous **98% complete / 2% remaining** estimate was too generous. It
counted typed method names and passing behavior checks as if they proved that
ownership had moved. They do not. The current strict score is **25% complete /
75% remaining** because only one of four hard ownership gates is satisfied.
The accepted `0.2.x` migration route remains complete; this is the separate
post-Phase-C composition score.

The scorecard is intentionally difficult to satisfy:

| Hard gate | Baseline (`d6a965d`) | Current | Status |
|---|---:|---:|---|
| Meaningful reduction in dynamic `root.call/get/set` sites | 3,140 | 3,135 | `[ ]` only 5 fewer sites, or about 0.16% |
| `GameplayState` smaller than the pre-slice baseline | 1,720 lines / 287 fields | 1,777 lines / 299 fields | `[ ]` larger by 57 lines and 12 fields |
| `RoomController` below its pre-refactor baseline | 2,297 lines | 3,265 lines | `[ ]` larger by 968 lines |
| At least one direct typed context used end-to-end | none counted | `ChestRewardContext`, `RoomClearContext`, `RoomCheckpointContext`, `RoomEnemyRuntimeContext`, `RunSettlementContext`, `ActiveRunSnapshotContext`, `RunCheckpointContext`, `MenuPlayerContext` | `[x]` |

This score is a measure of architectural ownership, not a claim that the
recent work was useless. Typed result contracts, deterministic snapshots,
external tuning resources, and focused behavior checks are valuable foundation
work. They become composition progress only when a slice also removes the
state-bag dependency and retires its duplicate compatibility implementation.

The next work is therefore not browser evidence or more wrapper creation. It
is to rework the room lifecycle through direct typed slices, reduce the root
access surface, and make `RoomController` smaller than its pre-refactor
baseline before assigning a higher percentage.

The 25% score advances only when a slice earns measurable credit against these
pinned thresholds, not when it merely adds a typed class:

- **Root access threshold:** total `root.call/get/set` sites must fall below
  **2,500** before the first slice earns credit; each completed slice must also
  reduce its own owner's count.
- **State-bag threshold:** `GameplayState` must be below its pre-slice baseline
  (1,720 lines / 287 fields) before assigning 50%.
- **Owner-size threshold:** `RoomController` must be below its pre-refactor
  baseline (2,297 lines) or have a clear extracted owner that removes at least
  500 lines from the coordinator.
- **Slice integrity:** a slice earns no credit while it has a parallel
  `*_legacy` or root-shaped implementation of the same behavior, or a context
  that stores `GameplayState`.

Until all four thresholds move together on the same slice, the score stays
25%. Do not raise it based on a single gate.

## Current measured shape

These measurements are from the working tree on 2026-09-15; `d6a965d` remains
the pinned comparison baseline. They are useful for choosing leverage points,
not as quality scores. To regenerate them, run the PowerShell one-liner in the
Measurement command section below.

| Surface | Measurement | Interpretation |
|---|---:|---|
| Runtime GDScript files | 166 | There are enough existing boundaries to refactor vertically |
| Runtime physical lines | 48,534 | Large enough that broad mechanical migration is unsafe |
| Runtime non-blank lines | 42,900 | Blank lines are excluded; comments remain counted |
| Explicit `*Component` classes | 20 | Entity-level composition is established |
| Named functions | 2,709 | Function count is not a reason to create more wrappers |
| `GameplayState` lines | 1,777 | It remains the main shared-state surface |
| `GameplayState` functions | 510 | Many are forwarding/compatibility methods |
| `GameplayState` declared fields | 299 | State and ownership are still concentrated |
| `gameplay.gd` lines | 233 | The coordinator itself has been slimmed; the seams moved to state/components |
| Dynamic `root.call/get/set` sites | 3,135 | Dependency direction remains the largest structural risk |

The largest dynamic-access concentrations are:

| Script | Lines | Dynamic root accesses | Architectural concern |
|---|---:|---:|---|
| `screen_state_controller.gd` | 5,432 | 423 | Menu construction, input, layout, and presentation remain mixed |
| `room_controller.gd` | 3,265 | 420 | Room lifecycle, encounters, persistence, and rewards overlap |
| `combat_runtime_controller.gd` | 795 | 222 | Combat integration still reaches through the root |
| `gameplay_frame_controller.gd` | 266 | 205 | Ordering is explicit, but phase dependencies are hidden |
| `slime_runtime_controller.gd` | 805 | 195 | Reusable slime components still rely on a broad runtime context |
| `magic_runtime_controller.gd` | 686 | 141 | Magic state and presentation have remaining coordinator seams |

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
- `RoomRuntimeContext` stores `GameplayState` and copies room/slime/player/chest
  references. `RoomSpawnContext` and `RoomRespawnContext` inherit the same
  dependency shape; and
- the corresponding `*_context` methods in `RoomController` still have
  parallel root-shaped implementations and call back into `context.runtime`.

These adapters make call sites look typed, but they do not yet reduce the
state-bag coupling. A context containing `GameplayState`, or whose completed
operation still relies on `context.runtime`, cannot receive `[x]` credit in the
strict scorecard. Do not copy this shape into another feature. The room layer
needs a direct typed-slice redesign; a wholesale revert would throw away the
useful result contracts and the genuinely direct contexts without solving the
underlying ownership problem.

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

### 3. Migrate checkpoint and settlement — [~]

Checkpoint ordering currently crosses room, map, profile, active-run, and
settlement boundaries. The settlement domain now has committed
`RunSettlementContext` and `RunSettlementResult`; `RunFlowController` preserves
the existing save-before-`RunState.mark_settled` ordering while using that typed
boundary. Room-state assembly now has committed
`RoomCheckpointContext` and `RoomCheckpointResult`; `GameplayState` captures
enemy runtime through the direct `RoomEnemyRuntimeContext` and
`RoomEnemyRuntimeResult`, then delegates dictionary assembly to
`RoomController`. Room activation now consumes `RoomActivationContext` and
returns the existing `RoomActivationResult` through a typed runtime path, but
that context is still a `GameplayState`-backed adapter and does not yet count
as direct ownership migration.
The active-run file write still needs browser durability evidence. `RunCheckpointService`
owns the ordered room → profile → active-run writes, and the room-clear event now
crosses the composition boundary as `RoomClearResult` rather than a loose room
ID. `GameplayState` retains only the web-checkpoint eligibility guard and the
compatibility checkpoint wrapper. Do not mark this slice fully shipped until
browser durability evidence is recorded.

### 4. Rework room lifecycle ownership — [~]

The clear event is explicit: `RoomController.mark_cleared_context()` owns the
mutation and returns `RoomClearResult`; the map controller and checkpoint
consumer receive that typed event. Room entry now follows the same pattern via
`RoomEntryContext` and `RoomEntryResult`; the normal `GameplayState` path no
longer runs the old entry body directly. That is a useful seam, but the entry
context still carries the entire `GameplayState`, so it has not moved the
entry dependencies into a room-owned boundary. The ID-based
`mark_cleared()` and `enter_connected_room()` methods remain compatibility
facades for direct callers. Room activation follows the same typed-context
path and preserves the existing `RoomActivationResult`/`RoomSpawnResult`
reporting, while `RoomActivationContext` still wraps the root.

Room-level initial spawn orchestration consumes `RoomSpawnContext`, and the
normal frame schedule sends respawn ticks through `RoomRespawnContext`. Those
contexts inherit `RoomRuntimeContext`, which still stores `GameplayState` and
lets `RoomController` call back into it. The Combat normal path now sends the
three room-owned death consequences through `record_enemy_death_context()`;
that result boundary and `RoomEnemyRuntimeContext` are useful direct pieces,
but the room lifecycle migration remains incomplete while the parallel
`*_context` and root-shaped implementations coexist.

The next room slice must replace one of these adapters with direct typed
dependencies, demonstrate a measurable root-access reduction, and delete the
duplicate implementation for that slice. Preserve the authored/generated room
distinction and the central frame schedule while doing so.

**First target: enemy spawn and respawn.** This is the narrowest room workflow
with the strongest existing coverage (`enemy_room_entrance_scene_smoke`,
`popcorn_respawn_smoke`, `generated_run_scene_smoke`, `typed_combat_path_smoke`)
and the smallest cross-system surface. The acceptance criteria for this slice
are:

- build `RoomSpawnContext`/`RoomRespawnContext` from direct typed inputs
  (slime component arrays, room state, tuning, RNG, placement services) with no
  `GameplayState` field and no inheritance from `RoomRuntimeContext`;
- route the normal runtime path through the direct implementation and reduce
  the owner's `root.*` count by at least the accesses that slice removed;
- delete or collapse the parallel `_spawn`/`_respawn` root-shaped body to a
  one-line compatibility forward, or remove it once the final consumer migrates;
- keep `RoomController` authoritative for room state; and
- report before/after line and access counts in the handoff.

Room entry must come later: it crosses the most systems and is the most likely
target to produce another oversized context if attempted first.

Focused evidence for this slice:

- `room_transition_result_smoke`: typed clear result, idempotency, and single
  event emission.
- `enemy_room_engagement_smoke`: map clear behavior remains intact.
- `enemy_room_entrance_scene_smoke`: composed room wiring, typed initial spawn,
  and normal-frame respawn dispatch remain intact.
- `special_respawn_policy_smoke`: special-room timer policy remains intact
  through the compatibility fixture path.
- `boss_geometry_scene_smoke`: boss room composition remains intact.
- `generated_run_scene_smoke`: typed room-entry and activation path remains
  intact during generated traversal.

These checks prove that the behavior survived the seam extraction; they do not
prove that the room contexts are narrow or that ownership moved out of
`GameplayState`. `popcorn_respawn_smoke` is now manifest `verified`; its fixture checks the
waiting-before-clear contract, seeded 30–45 second schedule, support respawn,
and sealed boss entrance.

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
- `tools/validate_test_manifest.ps1`: 123 rows, 121 runnable paths, 2 report
  rows, and 43 curated-gate paths.
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
opt-in completion audit; it is expected to fail while the room migration is
still open. The normal CI gate does not use `-RequireTargets`, because the
strict ownership targets are the work remaining, not the current release
floor.

The validator reads `tools/composition-baseline.json`, which records both the
accepted values and the target thresholds. Use `-UpdateBaseline` only when a
reviewed slice deliberately retires coupling or extracts an owner; it refuses
to write when the current tree has audit errors. Run it with
`-BaselinePath`/`-ScriptsDirectory` to test against a different tree.

Current recorded baseline and strict targets (from
`tools/composition-baseline.json`):

| Metric | Accepted floor | Strict target |
|---|---:|---:|
| `root.call/get/set` sites | 3,135 | ≤ 2,499 |
| `GameplayState` lines / fields | 1,777 / 299 | ≤ 1,719 / 286 |
| `RoomController` lines | 3,265 | ≤ 2,296 |
| `.runtime` references | 20 | 0 |
| Paired legacy/context duplicates | 11 | 0 |
| Transitional contexts | 5 | 0 |

The accepted floor is the regression baseline. The strict target column is only
enforced when `-RequireTargets` is supplied; it is intentionally red while the
room ownership migration remains open.

The transitional allowlist must name exactly the current adapters and shrink as
slices land:

- `RoomEntryContext`, `RoomActivationContext`, and `RoomRuntimeContext` declare a
  `GameplayState` field directly;
- `RoomSpawnContext` and `RoomRespawnContext` inherit that field through
  `RoomRuntimeContext`; and
- `MenuPlayerContext` and `RunCheckpointContext` mention `GameplayState` only in
  comments and do not store it — they are **not** transitional and must not be
  added to the allowlist.

The allowlist therefore contains five entries today
(`RoomEntryContext`, `RoomActivationContext`, `RoomRuntimeContext`,
`RoomSpawnContext`, `RoomRespawnContext`). The moment a slice migrates one to
direct typed dependencies, remove it from the allowlist and record the metric
delta.

The current regression-floor output is expected to list the 11 existing paired
duplicates and five transitional contexts. The strict target audit remains
red until those are retired and the three size/access thresholds move. The
self-test and regression-floor run are wired into CI and the smoke runner so
the guard itself is exercised before gameplay tests begin.

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
