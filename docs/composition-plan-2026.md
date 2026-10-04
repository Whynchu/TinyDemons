# Tiny Demons — Full Composition Plan

Status: active plan (approved direction)

Scope: repository-wide script composition — ownership boundaries, script
hierarchy, executable composition rules, and the decomposition sequence that
replaces the saturated legacy-coupling scorecard

Owner: repository architecture and gameplay systems

Current code: 265 scripts distributed across the declared role folders,
`tools/validate_composition.ps1`, `tools/composition-baseline.json`,
`scripts/runtime/controllers/gameplay_bootstrap.gd`,
`scripts/ui/screen_state_controller.gd`,
`scripts/runtime/controllers/room_controller.gd`,
`scripts/runtime/controllers/hub_flow_controller.gd`,
`scripts/runtime/state/gameplay_state.gd`, and the `*Component` classes

Verification: composition validator self-test and strict audit
(`tools/validate_composition.ps1 -SelfTest`, `-RequireTargets`), definition
validator, per-slice focused smokes, then the curated gate

Supersedes: nothing. This plan extends the completed legacy-coupling record in
[`composition-refactor-analysis.md`](composition-refactor-analysis.md) and the
approved component contract in
[`component-composition-design.md`](component-composition-design.md). Where
those documents describe the component contract and the migration record, this
document describes what happens *after* both are considered complete.

Updated: 2026-10-04

Audit date: 2026-10-04, against version `0.3.32` / commit `45db00b`

---

## Purpose

The `0.2.x` composition refactor finished and its validator reports 100%. The
game is now structurally healthier than it has ever been, and the next
generation of work — enemies, gear, rooms, elemental forms — is still expensive
to add because six files carry too many responsibilities and the object graph
is assembled by hand in one imperative script.

This plan does the second half of the job. It exists to make four things true:

1. Every script has **one** clearly declared responsibility, and a reader can
   find that declaration without reading the body.
2. Every script lives in a **role folder** that tells you what kind of thing it
   is before you open it.
3. The composition rules in
   [`component-composition-design.md`](component-composition-design.md) are
   **executed by a check**, not merely written down — so a new contributor or
   agent inherits them without having to know they exist.
4. Adding a runtime system, and adding content, are **cheap and local**, and
   provably so.

This is not a rewrite. It is not an ECS. It is not a licence to create thin
wrappers. The stopping rules in [`ROADMAP.md`](ROADMAP.md) §"Added workstream"
still govern, and this plan inherits them.

---

## Measured baseline (2026-10-04)

All figures are from `scripts/**/*.gd` at commit `45db00b`. Line counts are
physical lines; seam counts are `root.get(` / `root.set(` / `root.call(` /
`root.has_method(` / `root.get_node(` occurrences, attributed to the enclosing
function.

### 1.1 Scale

| Metric | Value |
| --- | ---: |
| Scripts under `scripts/` | 235 |
| Physical lines under `scripts/` | 56,621 |
| Script subdirectories | **0** |
| Test scripts under `tests/` | 155 |
| Documents under `docs/` | 112 |
| Repo-wide dynamic-dispatch sites (`root.get/set/call`) | 2,202 |
| Repo-wide total reach-through sites (any `root.*`) | 4,434 |
| Untyped `root:` function parameters (of 651 total) | **560** |
| Distinct names reached by string through `root` | 459 |

### 1.2 The existing scorecard is saturated

`tools/validate_composition.ps1` passes both modes at 100%:

| Metric | Current | Strict target | Headroom |
| --- | ---: | ---: | ---: |
| `root.call/get/set` sites | 2,202 | ≤ 2,499 | 297 |
| `GameplayState` lines | 1,718 | ≤ 1,719 | **1** |
| `GameplayState` fields | 286 | ≤ 286 | **0** |
| `RoomController` lines | 2,251 | ≤ 2,296 | 45 |
| `.runtime` refs | 0 | ≤ 0 | 0 |
| Legacy duplicate pairs | 0 | ≤ 0 | 0 |
| Transitional contexts | 0 | ≤ 0 | 0 |

Every progress figure reads 100% because every value already sits under a
target that was pinned to the size of the *legacy giants*. This is a regression
floor against the completed `0.2.x` migration, and that migration is done. It
cannot see responsibility overlap, coupling direction, or complexity. Three
specific limits:

- **Aggregate only.** A new `root.call` in one file offset by a deletion in
  another passes. Seams can be traded between files indefinitely.
- **Narrow scope.** `scripts/` only; and the `GameplayState`-in-a-context rule
  matches on the `*context*.gd` **filename**, so a component holding
  `GameplayState` under any other name is invisible to it.
- **`gameplay.gd` is not measured at all**, despite `AGENTS.md` stating "do not
  enlarge `gameplay.gd` by default."

`GameplayState` at 286/286 fields is a live landmine: the next feature that
adds one state field reds CI for an unrelated reason.

### 1.3 Line count is a poor proxy for coupling

There are **three distinct** coupling measures in this tree, and they rank files
completely differently. All three are reproducible:

| Measure | What it counts | Repo total |
| --- | --- | ---: |
| **Dynamic dispatch** | `root.get(` / `root.set(` / `root.call(` — the validator's metric | 2,202 |
| **Total reach-through** | any `root.<identifier>` — adds field reads and direct calls on untyped roots | 4,434 |
| **Untyped root parameters** | functions declaring `root: Object`/`Node`/`Control`/… instead of a concrete type | **560** |

By dynamic-dispatch density — the metric the validator actually tracks:

| File | Lines | Dynamic | /100 lines |
| --- | ---: | ---: | ---: |
| `chest_controller.gd` | 164 | 68 | **41.5** |
| `actor_motor.gd` | 127 | 40 | **31.5** |
| `targeting_runtime_controller.gd` | 225 | 70 | **31.1** |
| `actor_presentation_runtime_controller.gd` | 436 | 123 | **28.2** |
| `shadow_controller.gd` | 69 | 16 | **23.2** |
| `combat_runtime_controller.gd` | 1,097 | 236 | 21.5 |
| `profile_runtime_controller.gd` | 109 | 20 | 18.3 |
| `gameplay_bootstrap.gd` | 616 | 107 | 17.4 |
| `slime_runtime_controller.gd` | 1,323 | 196 | 14.8 |
| `room_controller.gd` | 2,251 | 146 | 6.5 |
| `hub_flow_controller.gd` | 1,425 | 107 | 7.5 |
| `screen_state_controller.gd` | 5,564 | 255 | **4.6** |

The largest file in the tree is among the **cleanest** per line on the metric
the validator tracks.

By total reach-through — which adds field access on untyped roots — the ranking
inverts:

| File | Lines | Reach-through | /100 lines | Dynamic |
| --- | ---: | ---: | ---: | ---: |
| `profile_runtime_controller.gd` | 109 | 86 | **78.9** | 20 |
| `save_flow_controller.gd` | 456 | 314 | **68.9** | 41 |
| `gameplay_frame_controller.gd` | 799 | 455 | 56.9 | 104 |
| `gameplay_bootstrap.gd` | 616 | 340 | 55.2 | 107 |
| `hub_flow_controller.gd` | 1,426 | **658** | 46.1 | 107 |
| `chest_controller.gd` | 164 | 71 | 43.3 | 68 |
| `run_flow_controller.gd` | 703 | 272 | 38.7 | 81 |
| `screen_state_controller.gd` | 5,564 | 437 | 7.9 | 255 |

Absolute reach-through leaders: `hub_flow_controller.gd` 658,
`gameplay_frame_controller.gd` 455, `screen_state_controller.gd` 437,
`gameplay_bootstrap.gd` 340, `save_flow_controller.gd` 314.

**Read the two tables together and note the trap.** A high reach-through count
is only damning when the root is *untyped*.
`gameplay_frame_controller.gd` declares `root: GameplayState` in all 17 of its
root-taking functions, so its 455 sites are **static property reads and are
correct**. `magic_runtime_controller.gd` reaches nothing at all. The validator
cannot tell these cases apart — it counts syntax, not types.

**The single actionable predictor is therefore the third measure:** 560 untyped
`root:` parameters across 28 files, versus only 91 typed. **86% of root-taking
functions declare `root: Object`**, and that is the mechanical reason they need
`root.get()` at all.

| File | Untyped `root:` params | Typed | Lines |
| --- | ---: | ---: | ---: |
| `slime_runtime_controller.gd` | 77 | 0 | 1,323 |
| `combat_runtime_controller.gd` | 74 | 9 | 1,097 |
| `room_controller.gd` | 54 | 0 | 2,252 |
| `hub_flow_controller.gd` | 50 | 0 | 1,426 |
| `screen_state_controller.gd` | 40 | 23 | 5,564 |
| `pickup_runtime_controller.gd` | 38 | 10 | 1,105 |
| `actor_presentation_runtime_controller.gd` | 35 | 0 | 436 |
| `room_puzzle_controller.gd` | 34 | 0 | 715 |
| `run_flow_controller.gd` | 27 | 2 | 703 |
| `save_flow_controller.gd` | 27 | 1 | 456 |
| `effects_spawner.gd` | 18 | 0 | 1,522 |

Two consequences for sequencing:

1. **A line-sorted review finds the wrong files first.** `screen_state_controller.gd`
   and `room_controller.gd` are the right *decomposition* targets but not the
   *densest coupling* targets. `chest_controller.gd` (41.5/100),
   `actor_motor.gd` (31.5), `targeting_runtime_controller.gd` (31.1) and
   `shadow_controller.gd` (23.2 in 69 lines) never appear on a size-sorted list.
2. **Most of the seam debt is mechanically typeable.** The untyped signatures
   are the cause; the dynamic accesses are the symptom.

### 1.4 One file is not a complexity problem

`gameplay_state.gd` — 1,718 lines, 286 fields, 480 functions, **3** seams:

| Function category | Count | Share |
| --- | ---: | ---: |
| One-line `.call(...)` bridge | 296 | 61.7% |
| One-line direct-method bridge | 77 | 16.0% |
| Short helpers (1–2 statements) | 39 | 8.1% |
| Genuine multi-line logic | **68** | 14.2% |
| Trivial field getters/setters | **0** | 0% |

77.7% of the file is mechanical pass-through, and there are zero trivial
accessors. The 250 fields are mostly references (80 are scene bindings or
service handles); roughly 110 are genuine gameplay scalars. This file is a
**surface-area** problem — 459 externally reachable names reached by string —
not a complexity problem. Splitting it by line range would make it worse.

### 1.5 The wiring is not configurable

`gameplay_bootstrap.gd`, `initialize()` at lines 68–414:

| Fact | Count |
| --- | ---: |
| Individual `_add_runtime_node(...)` calls, each with its own preload, node-name string, parent argument, and `as` cast | **44** |
| `root.call("...")` string dispatches into the host | **31** |
| Hand-written `_phase()` labels that exist only because the boot order is not introspectable | **34** |
| Physical lines of linear wiring | 347 |

There is no table, no registry, no declarative descriptor, and no second
assembly path. Load-bearing ordering — display controller before
`room_controller.configure_geometry`, HUD before
`effects_spawner.configure_item_acquisition_delivery` — is expressed purely as
statement order. The UI-build sub-sequence is **duplicated** between the
title-only boot branch (192–218) and the full path (306–370). The single
aggregation object, `RoomEnemySpawnServices`, is a 46-member field bag with no
enumeration and no per-member validation.

Consequence: adding a runtime system means editing a 616-line imperative
script, and no tool can verify the resulting graph.

### 1.6 There is already a working template

`magic_runtime_controller.gd` — **1,704 lines, 87 functions, zero dynamic
seams.** Every function takes a typed `MagicRuntimeContext`
(`scripts/magic_runtime_context.gd`, 80 lines). This is the approved component
contract working, at scale, in the game's most complex feature. It is the
reference implementation this plan points at, not a rule in prose.

### 1.7 The documentation surface

Of the composition rules recorded in
[`component-composition-design.md`](component-composition-design.md),
[`ARCHITECTURE.md`](ARCHITECTURE.md), and
[`refactor-route.md`](refactor-route.md), **18 have no automated check**,
including: component blindness from `get_parent()`/`get_node()`; no
`initialize(root)`; no self-wiring between components; no identity branches;
no `_process()` outside the frame controller; dependency direction between
controllers; and the requirement that every new substantial script declares its
owner and responsibility.

`tools/check_definition_manifest.gd` is not in the smoke-runner preflight and
not in CI. CI runs four validators and a web export — **no smoke tests at all**.

---

## Principles

1. **Split by responsibility, never by line range.** A file may stay long if
   one coherent responsibility makes it long. `dungeon_layout_generator.gd`
   (2,488 lines) is real route-generation and reachability validation; splitting
   it would obscure the algorithms. Line count is a *review prompt*, not a gate.
2. **No wrapper proliferation.** A move must delete a path, not add a
   forwarding layer. The only permitted forwarding stubs are those required by
   a frozen public boundary, and they must be recorded and retired.
3. **Move authority, not just code.** When behavior moves, the state it owns
   and the events it emits move with it. A relocated method that still reads a
   foreign bag has not been decomposed.
4. **Characterize before moving.** Add or confirm focused coverage of the exact
   behavior before it changes hands.
5. **No balance changes in structural work.**
6. **Enforcement is part of the work, not a follow-up.** A slice that cannot be
   checked is not finished.

---

## Stage 0 — Re-base the guardrail (prerequisite)

Nothing else can be verified until the validator can detect forward progress.
Today it is saturated, so every later slice would need a manual baseline bump.

### 0.1 Split the metric into floor and ceiling

Rename the current targets to explicit `*_max` regression floors (unchanged
values), and add forward targets:

```jsonc
"targets": {
  "root_accesses_max": 2499,          // unchanged regression floor
  "gameplay_state_lines_max": 1719,   // unchanged
  "gameplay_state_fields_max": 287,   // one deliberate slot above the 286-field baseline
  "room_controller_lines_max": 2296,  // unchanged
  "forward": {
    "screen_state_controller_lines": 800,
    "hub_flow_controller_seams": 120,
    "screen_state_controller_seams": 120,
    "live_context_twin_pairs": 0,
    "bootstrap_registration_rows": 44,   // must become data-driven, then drop
    "scripts_flat_directory": false
  }
}
```

After Stage 2.2, `hub_flow_controller_seams` measures the combined
`hub_flow_controller.gd` and `hub_economy_controller.gd` modules. Moving a
method into its composition submodule must not make the hub seam target appear
to improve by relocation alone.

Forward targets start at current values and tighten as stages land. A forward
target that is currently *met* is recorded as `met`; one that is currently
*missed* is recorded as `open` with the stage that will close it. This is
deliberately different from a hard gate: an open forward target must not block
unrelated work, but it must never be silently deleted or loosened.

### 0.2 Make seams per-file, not aggregate

Report a per-file seam table and fail when **any single file** exceeds its own
recorded baseline, instead of only checking the repo-wide sum. Seams traded
between files are how aggregate floors get gamed.

### 0.3 Add the missing metrics

The existing metric set cannot distinguish a *typed* root reach-through (fine)
from an *untyped* one (a migration seam), and it tracks neither ownership
reach-through nor the signature that causes both. Add:

- **Untyped `root:` parameter count, repo-wide and per file.** This is the
  single strongest predictor in the tree (§1.3): 560 today across 28 files.
  Baseline it, floor it, and drive it to zero. This is the metric that makes the
  rest of the plan measurable.
- **Total reach-through** (`any root.<identifier>`) as a second reported number,
  reported per file alongside the dynamic-dispatch count, so the two can be
  compared and typed access is not mistaken for a seam.
- `gameplay.gd` line count (currently unmeasured despite the extension rule).
- `*_context` twin pair count **per file**, not just newly-added pairs.
  `room_controller.gd` has **24 `*_context` functions, of which 14 are twin
  pairs** over the same behavior (the remainder are context builders and
  adapters, which are legitimate). `screen_state_controller.gd` has **4 pairs**.
  The validator only prevents new ones.
- Count `Callable(root, "...")` and `.connect("...")` string forms, which the
  current regex misses entirely.
- `scripts/` subdirectory presence, and a count of unclassified scripts.

### 0.4 Add the missing checks

All greppable, all in the existing preflight. Each needs a fixture in
`-SelfTest` proving it **rejects** a violation, matching the existing
self-test discipline.

| Rule | Check | Today |
| --- | --- | --- |
| Components are blind | no `get_parent(` / `get_node(` / `root.*` in `*component*.gd` | partial (`root.*` only) |
| No `initialize(root)` | grep repo-wide for the pattern | none |
| No self-wiring | a `*component*.gd` must not `.connect()` a sibling component | none |
| Dependency direction | controller-to-controller import graph must be acyclic | none |
| No identity branches | no `if <content_id> == "..."` branches in runtime scripts | none |
| Frame schedule preserved | no `_process(` outside `gameplay_frame_controller.gd` | none |
| No god-file growth | a new or substantially expanded file over a threshold must carry an owner/responsibility declaration | none |
| Script hygiene | every `scripts/*.gd` sits in a declared role folder | none |

The last two are prompts with teeth: they require a declaration to exist, not
that the file be short.

### 0.5 Close the preflight and CI gaps

- Add `tools/check_definition_manifest.gd` to the smoke-runner preflight.
- Record the CI smoke-coverage decision on the `tests/run_all_smoke.ps1` claim
  in [`../coord/BOARD.md`](../coord/BOARD.md).

### Acceptance bar

`-SelfTest` proves every new check rejects its fixture. Both validator modes
still pass at no regression. `GameplayState` fields gain declared headroom or
their floor is raised with a recorded reason.

---

## Stage 1 — Role folders for `scripts/`

`scripts/` is 235 files in **one flat directory**. Scenes were organized by role
in commit `82091e2`; scripts were not. This is the cheapest legibility win
available and it makes every later stage cheaper to navigate.

The approved map is [`script-role-map-2026.md`](script-role-map-2026.md), which
assigns every tracked script exactly once and records the ownership rule for each.
The migration remains one coordinated writer slice because path references cross
the full repository.

Top-level roles:

| Folder | Ownership |
| --- | --- |
| `scripts/runtime/` | Feature controllers, composition, runtime contexts/results, mutable runtime state, runtime services, and world rendering. Subfolders are `controllers/`, `contexts/`, `state/`, `services/`, and `world/`. |
| `scripts/components/` | Entity-local behaviour and state governed by the component contract. |
| `scripts/content/` | Authored definitions, catalogs, tuning resources, and generated content data. |
| `scripts/ui/` | Screen-anchored and `CanvasLayer` presentation, menus, HUD, and input surfaces. |
| `scripts/actors/` | Actor entities and actor-attached world-space presentation. |
| `scripts/algorithms/` | Pure computation and deterministic transformations without node lifetime or side effects. |
| `scripts/editor/` | Authoring, previews, editor diagnostics, and debug tooling. |
| `scripts/services/` | Process-wide shared services instantiated by `GameplayBootstrap`; these are not Godot autoloads. |

Assignment rules:

- Coordinate ownership sets the presentation boundary: screen-anchored content is
  `ui/`; actor-attached world content is `actors/`; room substrate and
  cross-cutting world rendering are `runtime/world/`.
- Mutable profile and active-run state belongs in `runtime/state/`, not `content/`.
- Typed runtime contexts and results belong in `runtime/contexts/`.
  `room_enemy_spawn_services.gd` moves to `runtime/services/` to satisfy the
  classification rule and is removed by Stage 3.2 when the transfer bag is
  collapsed; it is not retained as a new architectural boundary.
- `autoload/` is not a game role in this project: the only project autoload is
  provided by the MCP toolkit. Use `services/` for the game's boot-instantiated
  shared services.
- The validator classifies scripts by their top-level role, so all `runtime/*`
  subdivisions remain covered. Its role list includes `services/`.

Migration requirements:

- Every tracked `.gd` file and its `.gd.uid` sidecar moves exactly once to its
  mapped destination. No scripts remain directly under `scripts/`.
- Update `preload`/`load` paths, `class_name` references, scene resource paths,
  test references, tool references, and generated docs in the same change.
- Make no behavior changes. Verify the mapping and path rewrites, then run the
  definition validator, UID validator, and curated gate.
- Acceptance: the composition validator reports `unclassified_scripts = 0` and
  `scripts_flat_directory = false`; every tracked script and UID sidecar is
  accounted for exactly once.

**Implementation record (2026-10-04):** All 235 mapped scripts and their UID
sidecars were moved; 566 live literal script-path references across 256 files
were updated; the generated script index and recursive tooling were refreshed.
The composition validator's regression mode passes, as do its self-test and
the test-manifest and UID validators. The target-completion mode remains open
for the later composition stages. The UID check exposed a
pre-existing stale script UID in four room-prefab resources; those references
now match the preserved UID sidecar for `room_prefab_definition.gd`.

The definition validator and curated gameplay gate remain pending: the
repository's active-editor restriction prevents launching a second Godot
process in this session. Run those Godot-backed checks before treating Stage 1
as fully verified.

---
## Stage 2 — Zero-cost decompositions (Tier A)

Each item below is a bounded slice with a named boundary, a stated reason the
boundary is safe, and near-zero behavior risk. These are ordered by safety, not
by size.

### 2.1 Collapse the live `_context` twin pairs

**`room_controller.gd` — 14 twin pairs (28 of 129 functions, 21.7%):**
`enter_connected_room`/`_context`, `activate_room`/`_context`,
`apply_state`/`_context`, `mark_cleared`/`_context`,
`record_special_enemy_death`/`_context`, `record_popcorn_enemy_death`/`_context`,
`prepare_boss_jump_phase_pool`/`_context`,
`schedule_special_enemy_respawns`/`_context`, `update_respawns`/`_context`,
`update_special_enemy_respawns`/`_context`, `update_popcorn_respawns`/`_context`,
`_prepare_enemy_slot_visuals`/`_context`, `_spawn_enemy_slot`/`_context`,
`reset_slimes_for_room`/`_context`.

**`screen_state_controller.gd` — 4 pairs:** `_update_player_card`/`_context`,
`_update_pause_player_info`/`_context`, `_update_pause_resources`/`_context`,
`_update_pause_status`/`_context`. The last two are byte-identical 15-row stat
tables; `_update_pause_status` also contains a dead `max_health` recompute.

These pairs expose parallel entry paths: some duplicate root reads and typed
context reads, while others are legacy adapters that forward to an existing
typed implementation. Keep one typed-context behavior path; build the context
at a typed boundary and remove unused compatibility adapters.

The validator found two additional twins missing from the original inventory:

- **`active_run_snapshot.gd` — `create(root: Object)` / `create_context(context)`:**
  remove the root-field extractor and use `create(context)` at existing typed
  callers.
- **`run_settlement.gd` — `settle(profile, run_state, result)` / `settle_context(context)`:**
  remove the unreferenced compatibility implementation and use `settle(context)`.

The measured baseline contained 20 live twins, not 18. These two pairs are part
of this slice because the acceptance bar is zero across the repository.

**Bar:** live twin pairs reach 0. No new pair is admitted.

**Implementation record (2026-10-04):** All 20 measured pairs were collapsed:
four in `screen_state_controller.gd`, 14 in `room_controller.gd`, and the two
additional snapshot/settlement pairs found during implementation. Callers now
use typed contexts; the root adapters and duplicated settlement path are gone.
The composition validator reports zero live twins in strict mode. The Godot
smoke and editor checks remain pending while the shared editor session is
active.

### 2.2 `hub_flow_controller.gd` — split at `hub_bind_current_element`

- Hub and pause construction/routing stays in `hub_flow_controller.gd`.
- Binding, shop, inventory, gear, fusion, salvage, stat allocation, and hub
  start progression move to `hub_economy_controller.gd`.
- The two controllers share page/mode constants, optional-property handling,
  and equipment-mode transitions through `ui/hub_menu_state.gd`; don't duplicate
  that compatibility logic.
- `HubFlowController` owns the economy module as a `RefCounted` subcontroller.
  It has no frame or scene lifecycle, so this split does not add another
  GameplayState field or bootstrap registration.

Boundary correction found during implementation: `back_from_hub_route` was
above the proposed split, but directly called the equipment-browse and
remove-confirm operations below it. Move that route handler with the economy
module. The economy module requests a return to the hub root through the
GameplayState callback, so its code does not take a direct controller reference
back to the route owner.

Direct controller calls do not cross the split. Existing menu callbacks still
pass through GameplayState, which dispatches each public entry to its owning
subcontroller; keep those callback signatures stable while moving methods.

Secondary boundary available later: the shop query/cache block before
`shop_mode_pressed` is separable from stateful shop input and transactions.
Revisit it after measuring the new economy module's actual complexity; the
initial split leaves that module above 1,000 lines and does not claim the hub
domain is fully decomposed.

**Implementation record (2026-10-04):** Split the 1,425-line hub controller
into a 340-line routing owner and a 1,091-line economy/progression module.
Moved the missed nested back-route handler with the economy methods, extracted
the shared menu-state helpers, retained the GameplayState facade, and updated
the fusion presenter and focused fixture references. The seam guardrail counts
both hub modules together and remains at 109 against its target of 120, so the
structural split does not report a false seam reduction. Its GameplayState facade adds eight lines: the measured regression floor is now 1,726 while the forward target stays at 1,719 for a later shrink pass. Static gameplay
verification remains pending under the shared-editor restriction.

### 2.3 effects_spawner.gd - extract pixel text texture creation

Code inspection corrected the original boundary. The methods beginning at
number_texture form a cohesive glyph and text texture builder with four local
caches and the gear-plus source asset. They build deterministic ImageTextures,
but the caches are mutable instance state, so the new factory is not stateless.
The later particle emitters and status visuals mutate EffectsSpawner-owned
particle arrays and image caches; they stay in EffectsSpawner.

Move the five public texture methods, their multiline and glyph helpers, color
cache key, four texture caches, and gear-plus asset into
PixelTextTextureFactory (RefCounted). Keep the existing EffectsSpawner methods
as forwarding facades so runtime and editor callers retain their API.

**Implementation record (2026-10-04):** Extracted the glyph and pixel text
texture builder to a 250-line PixelTextTextureFactory; EffectsSpawner retains
the existing five texture entry points as forwarding methods and is now 1,294
lines. The factory owns its four caches and the gear-plus source asset. Particle
emission, status visuals, and their lifecycle state remain in EffectsSpawner.
Source references were checked to confirm no caller accesses the moved caches
or private helpers. Godot runtime verification remains pending under the
shared-editor restriction.

### 2.4 slime_runtime_controller.gd - isolate typed collision and walkability queries

Code inspection corrected the proposed boundary. The query block reads slime
lists, chest and RestFire collision shapes, collision sprites, room RNG, and
cloaked-demon foot state; its proximity filter also checks whether slimes are
dead. It is coupled to GameplayState, not a standalone walkability algorithm.
The stable GameplayState delegate methods already expose this surface.

Extract from collides_with_static through the end of the controller into
SlimeGeometryQueries. Give the helper typed GameplayState inputs and direct
field/method access, while keeping its existing controller facade methods for
GameplayState and callback consumers. Leave movement attempts and displacement
in SlimeRuntimeController. Share the RestFire/Firepit lookup between static
collision and collision-rectangle calculation.

**Implementation record (2026-10-04):** Moved the collision and walkability
query surface into a 206-line SlimeGeometryQueries helper. SlimeRuntimeController
now has a typed 1,220-line facade; GameplayState delegate names and callback
routing remain stable. The helper uses typed GameplayState fields, the four
actor/chest geometry constants, and direct calls for existing host queries.
A shared Firepit helper removes the repeated RestFire child lookup. Measured helper metrics: the controller now has 158 dynamic root calls/gets/sets
and 159 root-member references; the helper adds zero dynamic accesses and 30
typed root-member references. Across both files, dynamic dispatch fell from
196 to 158 and total root references from 197 to 189. Untyped root parameters
fell from 77 to 55. All 57 Callable(root, ...) sites remain visible across the
pair; the callback seam count did not fall. Godot runtime verification remains
pending while the shared editor session is active.

### 2.5 `combat_runtime_controller.gd` — status and combat feedback

The original line boundaries and call-site notes did not match the current
source. `try_apply_status` has three call sites: two damage-resolution paths
inside CombatRuntimeController and one enemy-contact path in SlimeActor.
`tick_actor_statuses` is called by the scheduled player and slime updates. The
five-method status pipeline is cohesive and already uses typed GameplayState
parameters, so move it as one unit while preserving the controller's public
delegates.

The second seam starts at `spawn_damage_number` (around line 893), not at
`configure_equipment_transmutations` (around 967). Move the damage/healing
number factory, player-number origin calculation, generic number spawning, and
health feedback color into a `CombatFeedbackPresenter`. Keep lifesteal in
CombatRuntimeController because it applies a health effect and merely requests
presentation. XP batching, reward calculation, level application, and
progression UI also remain in CombatRuntimeController for this slice; they are
not part of the feedback factory.

Both helpers take a typed GameplayState. CombatRuntimeController retains the
existing public method names as a forwarding facade, so GameplayState, actor,
and scheduled-update call sites keep their current entry points. Equipment
transmutation setup remains in CombatRuntimeController.

**Implementation record (2026-10-04):** Extracted the five status methods to
the 116-line `ActorStatusRuntimeController` and nine combat number/color methods
to the 64-line `CombatFeedbackPresenter`. CombatRuntimeController is now 986
lines. The public delegates remain; status application still reaches the same
three call sites, and the status tick remains on the explicit frame schedule.
The two helpers use typed GameplayState references. XP/reward batching and
transmutation logic were left in the combat owner. The regression audit now
measures 221 dynamic accesses and 247 root-member references in the combat
owner (down from 236 and 284); the helpers add 37 typed root-member references
and zero dynamic accesses. The total callable-string count stays at nine across
the three modules, and the compatibility facade retains 74 untyped root
parameters. The updated source was statically audited and the composition
baseline/index were refreshed; Godot runtime verification remains pending
while the shared editor session is active.

---

## Stage 3 — The two giants

### 3.1 `screen_state_controller.gd` (5,446 lines at the start of Stage 3.1)

Mapped into 22 concern groups. **Frozen external boundary: 45 public methods
and roughly 40 public fields**, called from `hub_flow_controller.gd`,
`save_flow_controller.gd`, `gameplay_state.gd`, `cloud_save_panel.gd`,
`combat_runtime_controller.gd`, `dungeon_minimap_controller.gd`,
`debug_session_controller.gd`, `gameplay_bootstrap.gd`, and eleven test scripts.
Any moved method keeps a recorded forwarding stub until callers are updated.

**Lowest-risk groups first** — these have zero `root.*` and no cross-group
state (≈408 lines across the three verified groups): widget factories and retro
styling (245 lines), cursor motion (70), and title particles (93). The
title-particle methods do have GameplayState callers for spawning and cleanup;
keep the ScreenStateController facade while moving the unshared particle
collection and lifecycle into a UI helper.

**Audit correction:** hub/pause control positioning is not a stateless 269-line
block. `_position_hub_controls` spans 210 lines and reads 67 hub-owned UI
fields; `_position_pause_controls` spans 54 lines and reads 14 pause fields.
They call adjacent layout/cursor helpers, so defer extraction until those
mutable screen fields have a typed layout owner rather than passing a large bag
back to ScreenStateController.

The loading screen is another coupled seam. Its 27-line update hides the title,
archetype, and hub overlays and changes screen state when fading completes.
Move visual construction/fade animation into a presenter, but keep completion
and overlay visibility coordination in ScreenStateController.

**Audit correction:** The settings screen is not an isolated widget group yet.
GameplayState assigns ten settings-control fields from its build result, while
frame/input routing and display reflow read the settings overlay directly.
Prompt texture composition and face-icon layout are shared by title, game-over,
hub, pause, equipment, settings, and name-entry screens. Extract that stateless
shared factory before moving a screen group; keep input-device prompt selection
and screen transitions with ScreenStateController until they have a typed owner.

Name Entry has a separate wiring seam: SaveFlowController currently copies 11
node references into ScreenStateController, then reads/writes its pending-slot,
owner, and overlay lifecycle fields during completion. GameplayFrameController
and input routing only need the overlay as an observation point. Move the full
name-entry widget/state bundle behind a typed screen interface and expose the
pending-slot/completion operations explicitly instead of returning a dictionary
for callers to copy into public fields.

**Then the self-contained screens:** loading/save-select/name-entry (381
lines), title + archetype (321), settings (303), death/game-over (183).

**Highest risk, last:** `update_hub_ui` (423 lines, 26 outgoing internal
edges), `update_hub_input` (239 lines, 155 `root.call`), pause menu (18
functions, crosses hub + pause + debug + scroll), and the scene-build group
(563 lines, owning the legacy-widget cluster that is hidden but still read).

Three specific hazards recorded during the audit:

- **A dead-but-load-bearing widget cluster.** Legacy hub item/gear fields are
  built by `build_hub`, hidden by `_hide_legacy_equipment_presenter` /
  `_hide_legacy_shop_presenter`, and still read by `_update_hub_item_page`,
  `_update_hub_gear_slots`, and `update_hub_input`. Rendered by nobody, loaded
  by three groups.
- **Pause renders the hub's presenter.** `update_pause_ui` calls the
  equipment presenter built by `build_hub`, and mutates nodes from that build.
  Pause and hub are structurally coupled through the node tree, not just
  through variables.
- **One input latch across three handlers.** `menu_input_release_lock` is shared
  by hub, pause, and settings input, and is written from outside by
  `cloud_save_panel.gd`.
- **Zero internal navigation aids.** No section banners, no regions, no docstring
  headers across 5,564 lines; function order is arbitrary. Whatever split
  sequence is chosen must add banners, because a reader currently has none.

**Implementation record (2026-10-04):** Moved the title particle array,
spawning, cleanup, and ticking into the 97-line `TitleParticleController`.
ScreenStateController is now 5,374 lines and retains its existing particle
method names as delegates. GameplayState still owns the particle layer and
supplies its texture/snap callbacks. Source search confirmed the particle array
has no external readers. The first Stage 3.1 seam is isolated without adding a
GameplayState field or runtime bootstrap registration. Godot runtime
verification remains pending while the shared editor session is active.

**Implementation record (2026-10-04):** Moved shared retro button styling,
button and overlay/sprite construction, menu frame/card helpers, and title
decoration into the 250-line `MenuWidgetFactory`. ScreenStateController is now
5,208 lines and keeps each existing method as a forwarding facade; this
preserves its broad internal use plus direct callers in GameplayState and
CloudSavePanel. The factory has no GameplayState/root dependency. Its title
rule receives the view size explicitly, so it owns no screen-layout state.
Godot runtime verification remains pending while the shared editor session is
active.

**Implementation record (2026-10-04):** Moved cursor positioning, target
motion, bobbing, and tween cleanup into the 61-line `MenuCursorAnimator`.
ScreenStateController remains the tween owner and passes itself to the helper,
preserving tween processing and lifetime. Existing `move_menu_cursor` and
positioning delegates remain for SaveFlowController and the screen groups; the
public cursor constants still resolve through ScreenStateController. It is now
5,174 lines. Godot runtime verification remains pending while the shared
editor session is active.

**Implementation record (2026-10-04):** Moved loading overlay construction,
label animation, and fade visuals into the `LoadingScreenPresenter`. The
presenter uses the existing `MenuWidgetFactory` and receives the view size
explicitly. ScreenStateController retains the existing build/update facade and
owns the cross-screen completion transaction: hiding title/archetype/hub
overlays and changing state to gameplay. SaveFlowController call sites and the
returned result keys remain unchanged. ScreenStateController now measures
5,168 lines. Godot runtime verification remains pending while the shared editor
session is active.

**Implementation record (2026-10-04):** Moved shared face-button glyph lookup,
button icon layout, prompt/sequence texture composition, and its cache into the
140-line `MenuPromptTextureFactory`. ScreenStateController keeps each previous
method as a forwarding facade, including the icon API used by hub, pause, and
equipment UI. The factory has no screen-state or GameplayState dependency; the
controller's device-specific prompt selection remains in place. It now measures
5,061 lines. Godot runtime verification remains pending while the shared editor
session is active.

**Implementation record (2026-10-04):** Added 25 one-line semantic section
banners at existing method-group boundaries throughout ScreenStateController.
The banners improve source navigation without reordering methods or changing
behavior. The controller now measures 5,086 lines; the largest coupled screen
areas remain hub rendering/input and the settings/name-entry state owner.

**Implementation record (2026-10-04):** Moved Name Entry widget construction
and responsive positioning into the 94-line `NameEntryWidgetPresenter`. The
presenter owns the 13 visual-node references and builds the controls directly;
`SaveFlowController` no longer unpacks the returned dictionary into eleven
ScreenStateController fields. Those existing properties remain as forwarding
compatibility accessors for probes and frame/input observers. Name-entry text,
selection, callbacks, and lifecycle transitions remained in ScreenStateController
for the following typed-state slice. At that checkpoint it measured 5,052 lines.

**Implementation record (2026-10-04):** Completed the Name Entry owner with
the 251-line `NameEntryScreenController`. It now owns name text, page/case/error
state, selection, cell activation, visual refresh, callbacks, and pending-slot
lifecycle. `NameEntryWidgetPresenter` retains only the visual nodes and their
construction/layout. ScreenStateController preserves its overlay/state
compatibility properties and owns shared release-lock handling and transitions;
SaveFlowController uses explicit pending-slot and completion operations rather
than mutating internal lifecycle fields. Both helpers have unique Godot UID
sidecars. ScreenStateController now measures 4,956 lines. The strict target
audit remains open: GameplayState is 1,726 lines against its 1,719-line target.
Godot runtime verification remains pending while the shared editor session is
active.

**Implementation record (2026-10-04):** Moved Save Select overlay construction
and footer reflow into the 75-line `SaveSelectScreenPresenter`, using the shared
`MenuWidgetFactory`. ScreenStateController keeps the overlay and footer accessors
used by frame routing and SaveFlowController; slot selection and overwrite
transactions stay in SaveFlowController. The controller now measures 4,914
lines. The script index and composition baseline include 249 scripts, with zero
unclassified files. Godot runtime verification remains pending while the shared
editor session is active.

**Implementation record (2026-10-04):** Moved title overlay construction,
profile-dependent menu-row layout, and responsive title/cursor positioning into
the 103-line `TitleScreenPresenter`. It owns the title widgets and command list;
ScreenStateController retains its compatibility accessors and title transition
input/flow. SaveFlowController no longer copies the returned title-node
dictionary into nine controller fields. ScreenStateController now measures
4,877 lines. The script index and composition baseline include 250 scripts,
with zero unclassified files. Godot runtime verification remains pending while
the shared editor session is active.

**Implementation record (2026-10-04):** Moved Archetype overlay construction,
arrow creation, and responsive control/footer positioning into the 86-line
`ArchetypeScreenPresenter`. ScreenStateController exposes compatibility
accessors and keeps selection, preview animation, and transitions; SaveFlowController
no longer copies the returned node dictionary into eight fields. The controller
now measures 4,865 lines. The script index and composition baseline include 251
scripts, with zero unclassified files. Godot runtime verification remains
pending while the shared editor session is active.

**Implementation record (2026-10-04):** Moved Settings widget construction,
responsive layout, option value presentation, selected-row state, cursor
placement, and typed setting changes into the 244-line `SettingsScreenPresenter`.
ScreenStateController keeps input routing, prompt-device lookup, and open/close
transitions. GameplayState no longer copies ten settings-node references out
of the builder result; it now measures 1,716 lines, under the 1,719-line
forward target. ScreenStateController now measures 4,713 lines. The script
index and composition baseline include 252 scripts, with zero unclassified
files. Godot runtime verification remains pending while the shared editor
session is active.

**Implementation record (2026-10-04):** Moved Game Over widget construction,
responsive positioning, selected-row state, and fade visuals into the 72-line
`GameOverScreenPresenter`. ScreenStateController retains the death timeline,
shared input-release latch, and menu input routing; GameplayState retains defeat
grading, puzzle rotation, and run settlement while observing the overlay through
a compatibility getter. The strict composition audit passes at 253 scripts,
zero unclassified files, and unique UID sidecars. GameplayState is 1,714 lines /
282 fields; ScreenStateController is 4,677 lines; root reach-through fell from
4,350 to 4,337. Godot runtime verification remains pending while the shared
editor session is active.

**Implementation record (2026-10-04):** Moved Run Complete widget construction
and responsive layout into the 73-line `RunCompleteScreenPresenter`. Its typed
fields own the nodes while ScreenStateController preserves the accessors used
by frame routing and RunFlowController's result rendering. GameplayState no
longer copies five node references from the build result. The strict audit
passes at 254 scripts, zero unclassified files, and unique UID sidecars.
GameplayState is 1,709 lines / 282 fields; ScreenStateController is 4,628
lines. Godot runtime verification remains pending while the shared editor
session is active.

**Implementation record (2026-10-04):** Replaced Hub construction's positional
callback list with the typed 29-action `HubScreenActions` record. The hub
builder now owns its constructed node references and returns `void`, removing
the string-keyed dictionary copied back through `HubFlowController`. Moved
Pause widget construction, debug menu setup, and node references into the
149-line `PauseScreenPresenter`; ScreenStateController keeps typed forwarding
accessors for existing callers while retaining navigation, input, rendering,
and cross-screen state. The strict audit passes at 256 scripts, 13
subdirectories, zero unclassified files, and 2,092 root accesses. Reach-through
fell from 4,337 to 4,258; GameplayState is 1,709 lines / 282 fields, and
ScreenStateController is 4,641 lines with 292 seams still open against the
120-seam target. `HubFlowController` remains within its 120-seam target at
109. The touch-control fixture now reads typed controller fields. No Godot
runtime or gameplay tests were run.
**Implementation record (2026-10-04):** Converted `update_pause_input`,
`_update_pause_equipment_input`, and `update_hub_input` to accept typed
`GameplayState` references and replaced 222 string-based `root.call` dispatches
with direct methods. All called root methods exist on GameplayState, and the
three modified handlers have no remaining dynamic root calls. The strict audit
passes at 1,870 root call/get/set sites (down from 2,092), 513 untyped root
arguments (down from 516), and 70 ScreenStateController seams (down from 292,
meeting the 120-seam target). Reach-through remains 4,258, showing that typed
calls improve dispatch safety while the screen still has substantial ownership
coupling. No Godot runtime or gameplay tests were run.

**Implementation record (2026-10-04):** Split the stat-allocation branch out of
the high-risk `update_hub_ui` renderer into the typed
`_update_hub_allocation_page` boundary. The helper uses direct typed
`GameplayState` reads for stats, remaining points, and the preview snapshot;
dynamic root access fell from 1,870 to 1,867, and reach-through from 4,258 to
4,257. This is a boundary inside ScreenStateController, not a completed
presenter extraction: the controller remains 4,642 lines with 67 measured
seams. Mapping confirmed that hub stat node fields are also read by responsive,
equipment, six-stat, fusion, and touch-control callers, so the next owner must
preserve those names through typed forwarding properties while it takes over
the stat nodes and rendering. The strict audit passes at 256 scripts, 13
directories, and zero unclassified files. The script index was regenerated.
No Godot runtime or gameplay tests were run.

**Implementation record (2026-10-04):** Completed the stats presenter boundary
with `HubStatsScreenPresenter`. It now owns allocation/status node construction,
status and allocation rendering, marker/target placement, and allocation preview
calculation. ScreenStateController retains the existing typed property names as
forwarders for responsive layout and menu callers. The fusion smoke fixture now
uses the typed `build_hub` and `update_hub_ui` APIs and a `GameplayState`-based
mock with the hub flow dependency supplied. The refreshed strict composition
audit passes at 257 scripts, zero unclassified files, 1,856 root call/get/set
sites, 510 untyped root arguments, and 56 ScreenStateController seams. The
controller is 4,437 lines; total reach-through is 4,258, effectively flat from
4,257. The script index and regression baseline were refreshed. No Godot
runtime or gameplay tests were run. Next: map and extract hub shell/page
visibility coordination without moving routing transactions out of their
owners.

**Implementation record (2026-10-04):** Moved Hub page-root lookup, legacy
page-title setup/chrome hiding, and root/active-page visibility into the typed
`HubPageVisibilityPresenter`. ScreenStateController retains typed forwarding
properties for `hub_root_page` and `hub_page_roots`, and still normalizes the
legacy STATUS route before delegating page visibility. The strict composition
audit passes at 258 scripts with zero unclassified files. No gameplay or Godot
runtime tests were run. ScreenStateController measures 4,405 lines, down from
4,437 before this slice; its dynamic seam count remains 56. The script index
and regression baseline now include the presenter. Next: map the remaining
command-shell render and cursor ownership before extracting it.

**Implementation record (2026-10-04):** Moved Hub command-button and Back-button
construction, command-cursor target calculation, responsive reanchoring, and
active/dimmed cursor presentation into the typed `HubCommandShellPresenter`.
ScreenStateController keeps forwarding properties for the command buttons,
Back button, and cursor. `MenuCursorAnimator` remains the tween owner and is
passed explicitly to the presenter. The strict composition audit passes at 259
scripts with zero unclassified files; ScreenStateController is 4,332 lines,
with 56 dynamic seams. The 800-line controller target remains open. The script
index, role map, and regression baseline include the new presenter. No Godot
runtime or gameplay tests were run.

**Implementation record (2026-10-04):** Moved responsive Hub geometry for the
command/resource rails, page roots, player card, allocation/status controls,
item/gear/binding panels, and legacy cursors into
`HubResponsiveLayoutPresenter`. Its `HubResponsiveLayoutContext` carries typed
viewport and menu state plus `HubPageVisibilityPresenter`,
`HubStatsScreenPresenter`, `HubCommandShellPresenter`, `MenuCursorAnimator`,
and the tween-owning node. ScreenStateController keeps its existing typed
accessors while its layout method now assembles the context and delegates. The
presenter divides positioning into frame/navigation, player/footer, stats,
inventory, child-menu, and cursor operations so each layout concern is easy to
find and change independently.
`HubStatsScreenPresenter` now places its own stat cursor. The strict composition
audit passes at 261 scripts with zero unclassified files; ScreenStateController
is 4,218 lines with 56 measured seams. The 800-line target remains open. The
script index and baseline were refreshed. No Godot runtime or gameplay tests
were run.

**Implementation record (2026-10-04):** Moved allocation/status node visibility,
focus targets, and stat-cursor display into `HubStatsInteractionPresenter`,
which coordinates the widgets built and rendered by `HubStatsScreenPresenter`.
This keeps rendering and interaction visibility in separate small owners. The
strict `god_file_declaration` guard rejected growing the stats presenter past
400 lines, so the interaction responsibilities now live in an 82-line module.
The strict composition audit passes at 262 scripts with zero unclassified
files; ScreenStateController is 4,182 lines with 56 measured seams. The
800-line target remains open. The script index and baseline were refreshed. No
Godot runtime or gameplay tests were run. Next: map `build_hub`'s widget
construction against its typed presenters and keep orchestration separate
from owned construction.

**Implementation record (2026-10-04):** Moved Hub player-card, context/back
prompt, footer, and gold/soul node construction into
`HubResponsiveLayoutPresenter`, which already owns those references and their
responsive positions. `build_hub` delegates shell chrome construction and
retains the compatibility currency aliases; the method fell from 303 to 262
lines. The presenter is 360 lines, below the 400-line declaration guard. The
strict audit passes at 262 scripts with zero unclassified files;
ScreenStateController is 4,141 lines with 56 measured seams. The script index
and baseline were refreshed. No Godot runtime or gameplay tests were run. Next:
map the remaining 269-line `update_hub_ui` by page and owner.

**Implementation record (2026-10-04):** Moved Hub confirmation/back prompt
textures and footer glyph/text visibility and labels into
`HubResponsiveLayoutPresenter.update_footer_content`. ScreenStateController
still chooses prompt text and creates the prompt textures, keeping device-aware
prompt rules at the screen boundary. `update_hub_ui` fell from 269 to 253
lines. The presenter is 392 lines, still under the 400-line guard. The strict
audit passes at 262 scripts with zero unclassified files; ScreenStateController
is 4,125 lines with 56 measured seams. The index and baseline were refreshed.
No Godot runtime or gameplay tests were run. Next: map the remaining
`update_hub_ui` routing and item-page visibility by owner.

**Implementation record (2026-10-04):** Moved nested Fusion, Equipment, and
Shop visibility, authored Equipment page chrome, and transparent Back hit
routing into `HubPageVisibilityPresenter`. Fusion is reset before the cursor
layer reset as before; legacy STATUS normalization, player-card refresh, and
item-page rendering remain at the screen boundary. The presenter takes typed
page state, authored controls, and the texture callback directly. The strict
audit passes at 262 scripts with zero unclassified files;
ScreenStateController is 4,095 lines with 56 measured seams, and
`update_hub_ui` is 223 lines. The script index and baseline were refreshed. No
Godot runtime or gameplay tests were run.

The legacy item visibility block is now owned by `HubItemVisibilityPresenter`.
It receives page, focus, selection, and profile values through the typed
`HubItemVisibilityContext`, and uses the responsive presenter's typed widget
references. The screen facade keeps its compatibility properties for item
rendering and input. `update_hub_ui` fell from 223 to 158 lines; the full
ScreenStateController fell from 4,095 to 4,057 lines. The new presenter is 111
lines and its context is 13 lines. The strict composition audit passes at 264
scripts, zero unclassified files, 56 ScreenStateController seams, and 510
untyped root arguments. The script index and regression baseline were
refreshed. No Godot runtime or gameplay tests were run.

## Completed: Stage 3.1 Hub input ownership

Moved the 240-line `update_hub_input` route into a 306-line
`HubInputController`, then arranged it as a short ordered dispatcher with named
Back, command-rail, status, binding, fusion, allocation, equipment, shop, and
inventory handlers. The controller receives typed `GameplayState` and
`HubMenuState` references, typed stats/layout presenters, and explicit render
and scroll callbacks; it does not receive the whole ScreenStateController.
Moved mutable Hub page, focus, equipment, shop, fusion, binding, and input-edge
state into `HubMenuState`; ScreenStateController retains typed forwarding
properties for existing callers. GameplayState now calls the typed screen
method directly after casting its existing Node reference.

ScreenStateController fell from 4,057 to 3,898 lines, while its Hub input
facade is 7 lines. `HubMenuState` is 93 lines; the input controller is 306.
The composition audit passes at 265 scripts with zero unclassified files,
56 ScreenStateController seams, 4,256 total reach-throughs, and 510 untyped
root arguments. The script index and regression baseline were refreshed. No
Godot runtime or gameplay tests were run.

Boundary audit: the authored Hub Equipment route and the Pause Equipment route
both use `_render_equipment_menu`; `_update_hub_item_page` and
`_update_hub_gear_slots` are compatibility fallbacks reached only when their
authored views are unavailable. Keep those fallback paths separate from the
active presenter extraction.

**Implementation record (2026-10-04):** Extracted the active shared Hub/Pause
Equipment renderer into the 240-line `HubEquipmentMenuPresenter`, with a
16-line `HubEquipmentMenuContext` carrying the authored view, `HubMenuState`,
profile, stat snapshot, selected-slot candidates, and legacy probe arrays. The
presenter receives no `GameplayState` or `ScreenStateController`; the screen
facade supplies typed render inputs and retains compatibility wrappers for
equipment text/mode helpers used by existing callers. `HubMenuState` now owns
the Equipment render-mode resolution. The controller is 3,675 lines, down from
3,898; the new presenter remains below the 400-line per-file ceiling. The
authored Equipment smoke sources cover the existing Hub/Pause route, slot,
candidate, stat, and touch behaviors. No game or test run was performed while
the shared editor session is active.

Static verification after the extraction: strict composition audit passes at
267 scripts, zero unclassified files, 52 ScreenStateController seams, 4,253
total root reach-throughs, and 509 untyped root parameters. The generated
script index contains 267 scripts, and the UID validator confirms 422 unique
and matching sidecars. These checks do not substitute for gameplay
verification; none was run while the shared editor session was active.

**Implementation record (2026-10-04):** Extracted Shop and Fusion presentation
model construction into `HubTransactionMenuPresenter`, with typed
`HubTransactionMenuContext` input and a new `ShopMenuModel` matching the
existing authored `ShopMenuLayout` renderer contract. Fusion continues through
its existing typed `FusionMenuModel`. `ScreenStateController` now gathers stock
and inventory state and resolves economy-owned sell/fusion details; stock
initialization, transactions, and mutable menu state remain with their current
owners. The presenter owns row-window formatting, Fusion row/stat comparison,
and the shared equipment-stat comparison; ShopMenuLayout retains a backward
compatible argument-based render method for its editor preview and focused
callers. ScreenStateController fell from 3,675 to 3,596 lines. Strict
composition audit passes at 270 scripts, zero unclassified files, 52 screen
controller seams, 4,253 root reach-throughs, and 509 untyped root parameters.
The script index has 270 entries; UID validation passes for 425 sidecars.
Offline MCP script validation passes for all five changed scripts. No game or
gameplay tests were run while the shared editor session is active.

Next: map the legacy Hub Equipment/Shop widget cluster built by `build_hub` to
its remaining render and input readers before moving or deleting it. Preserve
the fallback route and its data arrays until the typed authored views replace
all three consumer groups.

**Implementation record (2026-10-04):** Moved Equipment, Shop, Fusion, and Bind
authored-view signal connections from `build_hub` into the typed
`HubMenuSignalBinder`. It accepts the four authored layout types, the existing
`HubScreenActions` callback record, and one callback for Equipment command
selection. `ScreenStateController` still constructs the views and owns menu
state; it only selects typed views and delegates binding. The old
`has_signal`/string `connect` branch was replaced by signals declared on those
view types. Strict composition audit passes at 271 scripts, zero unclassified
files, 52 screen controller seams, 4,253 root reach-throughs, and 509 untyped
root parameters; string `.connect` calls fell from seven to zero. The index
contains 271 scripts, UID validation passes for 426 sidecars, and offline MCP
script checks pass for the binder and screen controller. No game or gameplay
tests were run while the shared editor session is active.

**Implementation record (2026-10-04):** Moved the legacy-widget suppression
for authored Equipment and Shop routes into
`HubLegacyWidgetVisibilityPresenter`, which receives the existing typed
`HubResponsiveLayoutPresenter` widget owner. The suppression rules remain
distinct: Equipment hides legacy visuals and permanently disables only its
exclusive hit targets; Shop also ignores all legacy Control input and stops
the legacy Shop cursor. All widget aliases, fallback rendering, and readers in
input, economy, responsive layout, and smoke sources remain intact. Removed a
duplicate stat-text append from the old Equipment suppression list. Strict
composition audit passes at 272 scripts, zero unclassified files, 52 screen
controller seams, 4,253 root reach-throughs, and 509 untyped root parameters.
The index contains 272 scripts, UID validation passes for 427 sidecars, and
offline MCP script checks pass for the presenter and ScreenStateController.
No game or gameplay tests were run while the shared editor session is active.

Audit result: runtime always instantiates the preloaded
`demon_hub_menu.tscn`, and that scene contains authored Equipment, Shop, and
Fusion children. Legacy item/gear rendering therefore runs only when a child
view is absent. Its widget handles still serve fallback input, row counts,
responsive positioning, smoke assertions, and debug callers; retain that
compatibility surface until those consumers move to the authored views. Next,
map each remaining reader and identify which can use an authored-view contract
directly.

**Implementation record (2026-10-04):** Moved the fractional y-position updates
for legacy item rows, Shop prices, touch-row buttons, and gear-choice rows into
`HubLegacyWidgetScrollPresenter`. It reads the widget references from the
existing `HubResponsiveLayoutPresenter`; ScreenStateController still chooses
scroll deltas, clamps state, and selects rows. Strict composition audit passes
at 273 scripts, zero unclassified files, 52 screen controller seams, 4,253
root reach-throughs, and 509 untyped root parameters. The index contains 273
scripts, UID validation passes for 428 sidecars, and MCP offline script checks
pass for the presenter and ScreenStateController. No game or gameplay tests
were run while the shared editor session is active.

**Implementation record (2026-10-04):** Removed the unused
`_shop_item_signature`, `_shop_matching_count`, and `_shop_item_details`
helpers after a repository-wide scripts/tests search found no callers. The
active Shop model uses `HubTransactionMenuPresenter`; fallback row rendering
has its own inline detail path. The runtime scene reference is the preloaded
`demon_hub_menu.tscn`, whose authored Equipment, Shop, and Fusion children are
present in the scene source. The legacy rendering branch remains for missing
child-view compatibility; widget fields still have consumers and were not
removed. Offline MCP script validation and strict composition audit pass.

**Implementation record (2026-10-04):** Replaced HubEconomyController's two
fallback-visible-row calculations that read legacy button-array lengths with
`HubResponsiveLayoutPresenter` capacity constants. `build_hub` uses the same
six item-row and four gear-choice-row constants when creating those widgets;
the authored layouts continue using their own row counts. Economy/input still
use actual button references when they need to emit an action. Root
reach-throughs fell from 4,253 to 4,251, and the regression baseline was
refreshed; strict targets pass at 273 scripts and zero unclassified files.
UID validation passes for 428 sidecars, the script index has 273 entries, and
offline MCP checks pass for all three changed scripts. No game or gameplay
tests were run while the shared editor session is active.

**Implementation record (2026-10-04):** Removed HubInputController's direct
reads of the legacy Equipment-action array and Shop item-action button. The
new `HubLegacyWidgetActionPresenter` exposes narrow trigger methods and returns
whether an enabled action was emitted, preserving no-input feedback and leaving
navigation with HubInputController. Its typed input is the existing
`HubResponsiveLayoutPresenter`, keeping action activation out of that already
large layout script. A runtime/scripts search now finds no external reads of
the listed legacy item/gear widget fields; remaining references are inside
ScreenStateController's fallback/build path, the widget owner, and tests.
Strict composition audit passes at 274 scripts with zero unclassified files;
root reach-throughs fell to 4,250 and the regression baseline was refreshed.
UID validation passes for 429 sidecars, index generation contains 274 scripts,
and offline MCP checks pass for the action presenter, input controller, and
layout owner. No game or gameplay tests were run while the shared editor
session is active.

Next: trace the remaining ScreenStateController fallback/build field bridges
and test probes, then define the migration order for retiring those bridges.

### 3.2 `gameplay_bootstrap.gd` — declarative assembly

Replace the 44 hand-written `_add_runtime_node` calls with a registration table
of `[node_name, script, parent, configure_callable]` rows, and the 31
`root.call(...)` build dispatches with named build steps in an ordered list.

Then collapse `RoomEnemySpawnServices` — a 46-member field bag — into typed
context objects of the `MagicRuntimeContext` shape, and give each boot phase a
real interface instead of a `_phase()` string label.

**Acceptance bar, per the "second piece of the same kind" rule already in
[`component-composition-design.md`](component-composition-design.md):** a new
runtime system is added by appending **one table row and zero edits to any
existing script**, and a validator asserts every registered system's
dependencies resolve.

---

## Stage 4 — Explicitly not splitting

| File | Reason |
| --- | --- |
| `dungeon_layout_generator.gd` (2,488) | Substantial route generation and reachability validation. Line-slicing would obscure coherent algorithms. Judge by whether its stages are separable responsibilities, not by length. |
| `enemy_preview_workbench.gd` (1,999) | Broad editor tool. Judge by whether its preview modes share state and workflow; apply editor-tool rules, not runtime-controller rules. |
| `gameplay_state.gd` (1,718) | 77.7% mechanical bridges, zero trivial accessors. The cost is the 459-name string-reachable surface. Reduce that by deleting bridges or typing consumers — not by cutting the file in half. |

---

## Stage 5 — Make composition executable

Applies to everything added after this plan lands.

1. **Every new `scripts/**/*.gd` sits in a declared role folder** and carries a
   one-line owner/responsibility declaration. Checked in preflight.
2. **No `initialize(root)`**, anywhere. Checked.
3. **Components are blind** — no `get_parent()`, no `get_node()`, no `root.*`.
   Checked.
4. **No self-wiring between components**; composition roots and factories wire.
   Checked.
5. **No identity branches on content IDs** in runtime code. Config is data.
   Checked.
6. **No `_process()`** outside the explicit frame schedule. Checked.
7. **No growth in a measured giant** without a recorded slice that reduces it.
   Checked per-file.
8. **A new substantial script declares its owner before it is written**, in the
   pull request or board claim — process rule, reinforced by check 1.

`AGENTS.md` §"Extension rules" and this document are the two places a new
contributor or agent looks. Both must state these rules, and the checks must be
what actually fails when a rule is broken.

---

## Sequencing

```
Stage 0  guardrail re-base+new checks     [single claim, blocks everything]
Stage 1  role folders                     [single claim, merge-conflict heavy]
Stage 2  Tier A decompositions            [one claim per file, parallelizable]
Stage 3  giants + declarative assembly    [one claim per boundary]
Stage 4  reviewed, no work queued
Stage 5  continuous
```

**Ordering dependencies that must be respected:**

- Stage 0 before Stage 3. Forward targets must exist before a decomposition can
  be measured as progress.
- Stage 1 before Stage 2. Reorganizing after decomposition means re-resolving
  every moved path twice.
- Stage 2 before Stage 3. Tier A removes duplicate logic that the giants'
  splits would otherwise have to carry across the boundary.

**Concurrency note.** Stage 0 and Stage 1 should each be a single claimed block:
Stage 0 touches one validator and one baseline, and Stage 1 rewrites paths
repo-wide. Running them concurrently with other agents creates merge conflicts
in every file. Stage 2 onward parallelizes cleanly per file — but not per
function within `screen_state_controller.gd` or `room_controller.gd`, where
boundaries share state.

---

## Prerequisites and blockers

1. **Three red gate rows must be triaged first.** `hub_binding_smoke`,
   `equipment_menu_scene_smoke`, and `imbue_spell_scene_smoke` fail on
   unmodified `main` (recorded in
   [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) §"Pre-existing failures"). Stage 2.2,
   2.3 and 3.1 all touch the same files. Without a trustworthy floor, every
   slice in this plan is unverifiable.
2. **`GameplayState` at 286/286 fields** has zero headroom and will red CI on an
   unrelated feature. Resolve in Stage 0.
3. **`_process()` rule scope.** The new frame-schedule check must exempt
   editor tooling and the shared-services layer, or it will fail on
   legitimate code. Define the exemption list before writing the check.
4. **Runtime acceptance debt.** Releases `0.3.29`–`0.3.32` shipped with no Godot
   runtime, test, or diagnostic run. The elemental affinity, transmission, and
   run-theme work is source-verified only. That debt should be cleared with a
   live editor before structural work begins, because Stage 2 moves the code
   that implements it.

---

## Verification per slice

1. Focused smoke covering the exact behavior moved, run before and after.
2. `tools/validate_composition.ps1 -SelfTest` and `-RequireTargets`.
3. `tools/validate_definitions.ps1` and `tools/report_catalogs.ps1` when authored
   data is touched.
4. The relevant owner test group from `tests/manifest.csv`.
5. The curated gate, as a supervised standalone step, when no MCP Godot editor
   is attached. Per `AGENTS.md`, never run the runner from an MCP-attached
   editor session.
6. Determinism checks for any slice touching generation or persistence
   round-trips.

Per-slice reporting requirement: record per-file seam counts and owner size
deltas before and after. The aggregate scorecard does not substitute for this.

---

## Metrics

Recorded in [`AUDIT.md`](AUDIT.md) after each stage:

| Metric | Source |
| --- | --- |
| Scripts per role folder; unclassified scripts | Stage 1 check |
| Live `_context` twin pairs, total and per file | validator |
| Per-file seam counts, top 20 | validator |
| Scripts over the review-prompt line threshold | report (a prompt, not a gate) |
| Untyped `root:` parameters, total and per file | validator |
| Dynamic-dispatch vs reach-through, per file | validator |
| Longest functions per owner | report |
| Forward target status: `met` / `open` with owning stage | validator |
| Central files edited to add one enemy / room / gear item | worked-example diff |
| Content addition requiring zero runtime-code edits | worked example |

The last two are the real acceptance bars. The rest are progress indicators.

---

## Exit criteria

- [ ] Every documented composition rule in
      [`component-composition-design.md`](component-composition-design.md) and
      [`ARCHITECTURE.md`](ARCHITECTURE.md) has an automated check with a
      rejecting fixture in `-SelfTest`, or is explicitly recorded as
      unenforced with a reason.
- [ ] The validator distinguishes regression floors from forward targets, and
      forward progress is measurable.
- [ ] `scripts/` is organized by declared role; unclassified scripts: 0.
- [ ] Live `_context` twin pairs: 0.
- [ ] Every file listed in Stage 4 is reviewed and its non-split recorded.
- [ ] A new runtime system is added by appending one registration row, with a
      validator proving its dependencies resolve.
- [ ] `screen_state_controller.gd` and the combined hub flow/economy controller
      modules meet their forward targets, or an explicit, reviewed exception
      is recorded.
- [ ] Each owner file carries internal navigation aids sufficient to find a
      screen or workflow without reading linearly.
- [ ] Adding one enemy, one room, and one gear item requires zero edits to
      `gameplay_state.gd`, `gameplay_bootstrap.gd`, and
      `gameplay_frame_controller.gd`.
- [ ] The curated gate is green, including the three rows that were red before
      this plan started.

Until these pass, the repository may be structurally healthy but should not be
described as fully composed.
