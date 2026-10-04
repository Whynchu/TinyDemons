# Tiny Demons — Full Composition Plan

Status: active plan (approved direction)

Scope: repository-wide script composition — ownership boundaries, script
hierarchy, executable composition rules, and the decomposition sequence that
replaces the saturated legacy-coupling scorecard

Owner: repository architecture and gameplay systems

Current code: all 235 files under `scripts/`, `tools/validate_composition.ps1`,
`tools/composition-baseline.json`, `gameplay_bootstrap.gd`,
`screen_state_controller.gd`, `room_controller.gd`, `hub_flow_controller.gd`,
`gameplay_state.gd`, and the 22 `*Component` classes

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
  "gameplay_state_fields_max": 286,   // unchanged
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

Proposed layout:

| Folder | Contents |
| --- | --- |
| `scripts/runtime/` | frame controller, bootstrap, state bag, run/hub/save flow, gameplay controllers |
| `scripts/components/` | the 22 `*Component` classes |
| `scripts/content/` | definition, catalog, manifest, tuning resources' scripts |
| `scripts/ui/` | screen state, HUD, minimap, touch controls, layout helpers |
| `scripts/actors/` | player/slime/chest/NPC actors, geometry, collision, motor |
| `scripts/algorithms/` | `dungeon_layout_generator.gd`, pure geometry/polygon math |
| `scripts/editor/` | `enemy_preview_workbench.gd`, `item_preview_workbench.gd`, dock/preview tooling |
| `scripts/autoload/` | singletons and global services |

Rules:

- Folder assignment must correspond to a **declared role**. A folder that only
  relocates a file without clarifying ownership is rejected in review.
- `preload`/`load` paths, `class_name` references, scene resource paths, test
  references, tool references, and generated docs all update in the same commit.
- No behavior change. This stage is verified by the definition validator, the
  UID validator, and the curated gate.

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

Each pair maintains two code paths over one behavior, one reading `root.get(…)`
and one reading pre-built context fields. Collapse to the typed context path;
the `root: Object` signature is the cause and goes with it.

**Bar:** live twin pairs reach 0. No new pair is admitted.

### 2.2 `hub_flow_controller.gd` — split at line 407 (`hub_bind_current_element`)

- **Above (1–406):** hub/pause screen construction and routing.
- **Below (407–1,425):** hub economy and progression — binding, shop,
  inventory, gear, fusion, salvage, stat allocation.

Safe because the dependency is **one-directional**: nothing above calls a
function defined below. This is the cleanest split boundary in the tree, and it
gives the ~440 `screen_state_controller.hub_*` seams a single owning module
instead of scattering them across both halves.

Secondary boundary available later: line 523 (`shop_mode_pressed`) separating
shop query (pure reads) from shop input handling.

### 2.3 `effects_spawner.gd` — split at line 734 (`number_texture`)

The lower 596 lines (procedural pixel-art synthesis, generic emitters, status
particles) contain **zero `root.*` accesses** and zero instance-state mutation —
they are pure functions of their parameters. The upper region orchestrates
world effects. Secondary boundary: line 176 (`spawn_item_acquisition_delivery`).

### 2.4 `slime_runtime_controller.gd` — split at line 1201 (`collect_walkable_tiles`)

The walkable-area construction and geometry-query block reads only
`walkable_area`, `actor_collision_system`, and four size constants; it never
touches `slimes`, `player`, or combat state. Every consumer above reaches it
through host delegates that already exist. The split converts **11
constant-via-`root.get` seams to `const`** and collapses a duplicated
`rest_fire`/`Firepit` lookup present in both halves.

### 2.5 `combat_runtime_controller.gd` — split at 772 and 967

- **At line 772** (`try_apply_status`): the status pipeline below is already the
  most-typed region in the file (5 of 5 signatures take `GameplayState`, zero
  `root.call`, zero `root.set`) and has exactly **one** inbound call site.
- **At line 967** (`configure_equipment_transmutations`): separates
  floating-number presentation from XP/leveling; two inbound call sites, both
  already thin.

---

## Stage 3 — The two giants

### 3.1 `screen_state_controller.gd` (5,564 lines)

Mapped into 22 concern groups. **Frozen external boundary: 45 public methods
and roughly 40 public fields**, called from `hub_flow_controller.gd`,
`save_flow_controller.gd`, `gameplay_state.gd`, `cloud_save_panel.gd`,
`combat_runtime_controller.gd`, `dungeon_minimap_controller.gd`,
`debug_session_controller.gd`, `gameplay_bootstrap.gd`, and eleven test scripts.
Any moved method keeps a recorded forwarding stub until callers are updated.

**Lowest-risk groups first** — these have zero `root.*`, no cross-group state,
and no external callers (≈704 lines, 36 functions): widget factories and retro
styling (245 lines), hub control positioning (269), cursor motion (70), title
particles (93), loading screen (27).

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
   editor tooling and the autoload/singleton layer, or it will fail on
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
- [ ] `screen_state_controller.gd` and `hub_flow_controller.gd` meet their
      forward targets, or an explicit, reviewed exception is recorded.
- [ ] Each owner file carries internal navigation aids sufficient to find a
      screen or workflow without reading linearly.
- [ ] Adding one enemy, one room, and one gear item requires zero edits to
      `gameplay_state.gd`, `gameplay_bootstrap.gd`, and
      `gameplay_frame_controller.gd`.
- [ ] The curated gate is green, including the three rows that were red before
      this plan started.

Until these pass, the repository may be structurally healthy but should not be
described as fully composed.