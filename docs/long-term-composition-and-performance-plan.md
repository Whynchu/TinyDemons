# Tiny Demons — Long-Term Composition and Performance Plan

Status: active plan

Scope: long-term content composition, runtime modularity, authoring workflows,
and mobile/desktop/web performance

Owner: repository architecture and gameplay systems

Current code: `GameplayBootstrap`, `GameplayState`, the player and slime
components, room/dungeon layout code, catalogs, tuning resources, effects,
occlusion, palette, and texture preparation systems

Verification: the current composition guardrail and focused smoke tests provide
the foundation; performance evidence must be added through the measurement
plan in this document

Supersedes: none; this plan extends
[`composition-refactor-analysis.md`](composition-refactor-analysis.md) from a
post-Phase-C cleanup tracker into the long-term architecture direction

Updated: 2026-09-15

## How this plan is tracked

This document bundles three long-running tracks that are sequenced separately
and each have their own completion gate. They are deliberately not one
monolithic effort:

| Track | Scope | Sequence gate | Tracked in |
|---|---|---|---|
| **T1 — Ownership cleanup** | Reduce `GameplayState` coupling, root reflection, oversized owners, transitional adapters | **Complete** — `tools/validate_composition.ps1` reports 100% and the strict audit passes; the regression floor now protects the achieved state | `composition-refactor-analysis.md` (historical record) |
| **T2 — Content authoring** | Definitions, factories, catalogs for enemy/room/encounter/dungeon/item/effect; workflow tests | Enemy-definition proof slice (B); then one slice per content kind | this document + [`component-composition-design.md`](component-composition-design.md) |
| **T3 — Performance** | Device-backed frame-time, transition, memory, and startup budgets on desktop + Samsung A17 | First fixed-seed scenario harness; then A/B palette test | this document |

Each track may be at a different progress point and can be picked up
independently. Do not treat T2 or T3 as blocked by T1, and do not treat T1 as
blocked by the content or performance work.

## Purpose

The current composition percentage measures a specific cleanup: reducing legacy
coupling around `GameplayState`, reflective root access, oversized owners, and
transitional adapters. It is useful, but it is not the full product goal. That
percentage is **not hardcoded in this document** — it is produced by
`tools/validate_composition.ps1` (run it with no arguments for the regression
floor, or `-RequireTargets` for the strict completion audit). Refer to that
validator as the live source of truth instead of reading a stale number here.

The long-term goal is a game that can grow for years without every new enemy,
room, map rule, reward, effect, or balance change requiring edits to a central
state bag or a large coordinator. A new piece of content should be assembled
from an explicit definition, a runtime scene/component composition, and a
validated registration or content pool.

The **editor-composition percentage** produced by `tools/validate_composition.ps1`
is the real representation of this direction: it measures the pieces that have
been given direct access *and* are changeable in the editor (blind components,
`@export`/`.tres`/Resource-driven definitions). It is a separate number from the
legacy-coupling score. As of `0.2.32` it is **100%**: all 20 components are
blind and `@export`-configured, and all 16 authored definition surfaces are
editor-inspectable resources (`item_catalog` `ItemCatalogData`, Run 1/Run 2
`DungeonRunDefinition`, the four `PuzzlePlanData` puzzle plans, plus the six
tuning `.tres`). The component contract and the weighted sub-metrics are
defined in [`component-composition-design.md`](component-composition-design.md).

This is an incremental architecture plan, not permission to rewrite the game.
Existing authored rooms, pixel geometry, save identities, frame ordering, and
player-facing behavior remain contracts while ownership moves one vertical
slice at a time.

## Reference: what Spire Codex can and cannot teach us

The linked [Spire Codex project](https://github.com/ptrlrd/spire-codex) is not
the original Slay the Spire 2 gameplay source. Its README describes the game
logic as living in a C#/.NET 8 DLL and describes Codex as a reverse-engineered
pipeline that extracts assets, decompiles models, parses structured data, and
serves it through a typed backend/frontend system.

That makes it a useful reference for:

- stable IDs and domain data categories;
- separating source data from presentation;
- typed schemas at boundaries;
- repeatable parsing/build pipelines;
- versioned data and field-level change reports; and
- treating content as something tools can inspect and validate.

It is not evidence that Tiny Demons should copy its runtime architecture, and
it does not give us the original game’s internal Godot composition. Tiny Demons
should borrow the data-contract discipline while keeping its own scene,
component, pixel-art, and gameplay design.

## North-star composition model

Use the following distinction consistently:

| Boundary | Responsibility | Example direction |
|---|---|---|
| Definition `Resource` | Editable, serializable content data | `EnemyDefinition`, `RoomDefinition` |
| Runtime instance | Live state for one spawned object or room | `EnemyActor`, `RoomRuntime` |
| Component | Focused local behavior and state | health, combat, movement, palette |
| Controller | A feature workflow spanning several objects | room activation, settlement |
| Factory | Builds a runtime composition from definitions | enemy or room factory |
| Catalog/registry | Stable IDs, lookup, validation, pools | enemy and item catalogs |
| Composition root | Wires typed dependencies and services | `GameplayBootstrap` |
| Signal/result | Explicit cross-owner communication | room clear or damage result |
| Snapshot | Saveable data, never live node references | active run and room claims |

Not every meaningful piece should become a component. Data belongs in
Resources, pure calculations can remain `RefCounted`, workflows belong in
controllers, and only local behavior/state should become a component. This
keeps composition understandable instead of replacing one large coordinator
with dozens of tiny wrappers.

The target runtime shape is approximately:

```text
GameplayBootstrap / composition root
├── ContentCatalogs and validated definitions
├── Run and persistence services
├── DungeonRun / graph / seeded layout output
├── RoomFactory → RoomRuntime + room-owned components
├── EnemyFactory → actor scene + behavior/combat/health/visual components
├── Player scene + focused player components
├── Combat, effects, audio, display, and input services
└── Explicit frame scheduler
```

## Content contracts we should grow toward

These are target boundaries, not a demand to create every file immediately.

| Definition | Should describe | Should not own |
|---|---|---|
| `EnemyDefinition` | stable ID, scene/archetype, tuning, geometry profile, behavior, palette, drops, tags | room persistence or global run state |
| `EncounterDefinition` | enemy entries, counts/weights, tier, spawn policy, room tags | actor movement or save writes |
| `RoomDefinition` | room ID/type, geometry/scene, sockets, encounter, rewards, doors, modifiers | global player progression |
| `DungeonDefinition` | room set, topology rules, route roles, seed policy, milestones | live room nodes or UI state |
| `ItemDefinition` | stable ID, slot, stats, effect contract, rarity/pool tags | a concrete equipped instance |
| `EffectDefinition` | effect identity, visual/audio recipe, lifetime, palette policy | combat authority or persistent state |

The existing `DungeonLayoutDefinition` and `DungeonLayoutGenerator` are useful
foundations. A generated layout result can remain a typed runtime object; the
long-term improvement is to move reusable authored rules and content choices
into inspectable definitions rather than growing more code-created special
cases. Likewise, the current slime variant catalog and tuning resources are
seeds of the enemy-definition system, but a dictionary lookup alone is not yet
an editor-friendly enemy composition boundary.

## What completion of the larger goal means

The long-term architecture should pass workflow tests, not only line-count
tests. Each workflow has a pinned acceptance bar so "done" is measurable, not a
vibe. These bars may tighten as the architecture improves, but they are the
minimum to claim a workflow passes:

1. **Add a new enemy** by creating or composing a scene, definition, and behavior
   registration without editing `GameplayState` or adding a room special case.
   Bar: the new enemy requires **zero edits to `GameplayState`** and at most one
   new catalog/definition row plus one factory registration.
2. **Add a room** by supplying geometry, sockets, encounter, reward, and milestone
   definitions without changing the central frame coordinator.
   Bar: **no `gameplay_frame_controller.gd` edit** and no new
   `root.call/get/set` site in the definition or factory path.
3. **Add a map or route** by selecting a dungeon definition and generator policy,
   with deterministic seed output and validation.
   Bar: a fixed seed reproduces the layout, and validation fails early on
   duplicate IDs, unreachable sockets, or unsafe encounter placement.
4. **Change tuning, palettes, drops, or spawn weights** through resources/catalogs
   while preserving stable IDs and save migration rules.
   Bar: the change is a resource/catalog edit only; no runtime script body is
   touched, and save compatibility round-trips.
5. **Instantiate the same content** in a headless fixture, a normal scene, and a
   generated run with the same ownership rules.
   Bar: one shared factory path produces the same definition-derived composition
   in all three hosts.
6. **Validate definitions before runtime**: duplicate IDs, missing assets,
   invalid references, impossible geometry, unreachable sockets, and unsafe
   encounter placement should fail early.
   Bar: a validator runs in the same CI preflight as the manifest and
   composition checks, and fails on a malformed definition.
7. **Keep persistence based on IDs, seeds, and plain data** rather than live Node
   references.
   Bar: a save snapshot contains no `Object`/node handles and round-trips
   through a schema-versioned serializer.

A workflow is not complete until its bar is met and demonstrated with a focused
test. The current `tools/validate_composition.ps1` percentage remains useful for
the legacy-coupling subproject (T1). It should not be renamed into a claim that
these content-authoring workflows (T2) are complete.

## Incremental migration sequence

### A. Finish the current ownership cleanup without blocking feature work — T1

Complete the remaining room-entry/activation adapters, state-bag reductions,
and root-access reductions tracked in
[`composition-refactor-analysis.md`](composition-refactor-analysis.md). Keep
this as a hygiene track. A feature may proceed when it uses the new boundary it
needs; it should not add new `GameplayState`-backed contexts or reflective seams.

### B. Build one enemy definition vertical slice — T2 (first proof)

Start with an existing slime variant so behavior is preserved:

1. define a typed enemy content contract and stable ID;
2. move one existing variant’s scene, tuning, geometry, visual, and behavior
   choices behind that contract;
3. let an `EnemyFactory` assemble the existing actor/components;
4. migrate one encounter path to request the definition by ID; and
5. prove that a second variant can be added through content/configuration and
   focused tests rather than central-state edits.

This is the first meaningful proof that the architecture makes adding enemies
easier. A recolor-only variant is not enough if the gameplay identity differs.

**Slice B acceptance bar (T2 gate):**

- the enemy definition is a `Resource` subclass (or an equivalent validated,
  serializable contract) that the editor can inspect, not a `const` dictionary;
- the migrated variant's scene, tuning, geometry, visual, and behavior are all
  driven by the definition, not by hand-written `GameplayState` branches;
- `EnemyFactory` assembles the actor/components from the definition;
- adding a **second** variant requires: one new definition resource, one
  catalog row, and no `GameplayState` edit — nothing else;
- focused tests cover the new variant and a save/load round-trip of any
  definition-derived runtime state.

If the second variant cannot be added with ≤1 definition/catalog change and zero
`GameplayState` edits, the slice is not complete. Do not declare B done on
"a test passes" alone.

### B1. Cost of the Resource migration — T2

The dictionary catalogs are moving to inspector-editable `Resource` subclasses.
**Completed at `0.2.32`:** the item catalogue (`ItemCatalogData`), the Run 1/Run
2 layouts (`DungeonRunDefinition`), and the four authored puzzle plans
(`PuzzlePlanData`) now load from `resources/definitions/*.tres`; the six tuning
classes load from `resources/tuning/*.tres`. **At `0.2.33`** the enemy vertical
slice (Slice B) landed: `EnemyDefinition` (`scripts/enemy_definition.gd`) is a
typed `@export` contract over each `SlimeVariantCatalogData` record, and
`EnemyFactory` (`scripts/enemy_factory.gd`) assembles/configures `SlimeActor`
from a definition (variant, combat element, damage contract, stats profile).
The runtime spawn path (`room_enemy_spawn_services.gd` and
`combat_runtime_controller.gd` `configure_slime_variant`) and the visual
texture source resolution (`actor_presentation_runtime_controller.gd`
`build_slime_direction_textures`) now read through the factory/definition
instead of raw dictionaries and a hardcoded palette→art mapping. A second
variant ("crimson", a tanky Fire slime) was added via one catalog row + one
`EnemyDefinition` view with **zero `GameplayState` edits**, proven by
`enemy_definition_slice_smoke`. **Remaining:** the definition/run contracts
for encounters, rooms, rewards, and effects do not yet have typed `Resource`
definitions. The honest cost items that still apply to the unmigrated kinds:

- a `Resource` subclass per definition kind with `@export` fields and stable
  IDs;
- a load path that migrates the existing `const DEFINITIONS := {...}` data
  into `.tres` files (or an equivalent authored source) without losing the
  current default tuning;
- a validation pass that catches missing fields, duplicate IDs, and dangling
  references before runtime (ties into workflow test 6);
- a save/load compatibility decision: old saves reference stable IDs, so the
  definition move must not invalidate them;
- editor workflow: the resource must be readable in the inspector and
  exportable in the web/mobile builds.

Sequence B before B1: prove the enemy slice works with one hand-authored
definition resource first, then migrate the remaining catalogs behind the same
pattern. Do not migrate every catalog in one commit; each kind (enemy, item,
element, room, encounter, effect) is a separate slice with its own tests.

### C. Separate encounters and rooms — T2

Move room-specific enemy/reward choices into `EncounterDefinition` and
`RoomDefinition` while leaving authored geometry and generated topology
distinct. Room runtime state should own claims, active actors, entrance locks,
and clear state; definitions should remain reusable and immutable.

### D. Make dungeon and map authoring compositional — T2

Keep the seeded generator responsible for producing a validated layout, but
make its inputs explicit: room pool, route policy, milestone rules, socket
rules, reward policy, and seed. The map controller should present the result,
not become the source of every generation rule.

### E. Extend the same pattern to items, elements, rewards, and effects — T2

Use stable definitions and catalogs for content. Runtime components should
consume typed definitions and emit typed results/signals. Do not create a new
global registry as a replacement service locator; catalogs should be narrow,
validated dependencies.

### F. Add authoring and validation feedback — T2

The editor/designer workflow should answer “what can I add and what will break?”
without reading several coordinators. Add definition validation, catalog
reports, deterministic preview commands, and one documented example each for
an enemy, room, encounter, reward, and map.

## Performance investigation track — T3

Tiny Demons’ low logical resolution does not automatically make it cheap. A
small pixel game can still spend significant time on transparent blended
sprites, many CanvasItem nodes, material/texture changes that reduce batching,
per-frame script loops, image allocations, duplicate GPU textures, particles,
occlusion, and synchronous resource preparation. These are hypotheses until a
device profile confirms them.

The project already selects Godot’s mobile renderer and nearest-neighbor canvas
texture filtering in `project.godot`. That is a sensible baseline, but it is
not a performance diagnosis or a mobile budget.

### Current hypotheses to measure — T3

- `SpriteFrameLibrary`, `SlimeVisualComponent`, and player animation paths
  perform per-pixel image recoloring and create `ImageTexture` resources. Caches
  exist, but palette/animation combinations can still create a large texture
  set during startup, room entry, or respawn.
- `EffectsSpawner` creates and updates pixel particles, damage numbers, sparks,
  and charge visuals as individual sprites. The pixel-particle cap is a safety
  limit, not proof that the effect path is inexpensive.
- The explicit frame scheduler visits many gameplay, presentation, targeting,
  depth, occlusion, UI, and effect systems every physics frame. Direct typed
  calls improve safety, but they do not automatically reduce the amount of work.
- Actor occlusion, shadows, palette variants, and texture preparation may add
  extra image work or break batching.
- Synchronous loading and transition prewarming may trade room-entry hitches
  for startup memory/CPU spikes.

### Measurement before optimization — T3

Capture the same scenarios on desktop, web, and the Samsung A17 before changing
rendering architecture:

1. title screen idle;
2. hub idle with fire, particles, and UI;
3. normal room with no enemies;
4. full enemy room during movement and combat;
5. boss room with effects active;
6. room transition and return to a previously visited room; and
7. minimap, pause, and equipment screens.

For each scenario record average and worst frame time, CPU/GPU frame time when
available, draw calls/CanvasItems, active nodes, texture/resource memory,
particle counts, load/prewarm time, and whether memory grows after repeated
room transitions. Use fixed seeds and a repeatable input script where possible.
The first performance task is an evidence report, not an optimization claim.

### Palette rendering decision — T3

Shaders may reduce duplicated palette textures, but they are not automatically
cheaper. A palette shader can save CPU-side image copies and texture memory
while adding per-pixel GPU work, material changes, or batching costs. The right
answer may be hybrid:

- keep baked atlases for content where they are faster or simpler;
- test a palette lookup shader on one actor and a small animation set;
- preserve nearest-neighbor sampling, alpha, outlines, and pixel identity;
- compare startup time, steady-state frame time, texture memory, and visual
  parity against the current baked/recolored path; and
- only expand the shader path if the Samsung A17 profile improves without
  increasing transition or effect costs.

Do not replace all sprite sets with shaders before this A/B test. A shader will
not fix excessive node counts, per-frame allocations, synchronous loading, or
an overactive update loop.

### Performance exit criteria — T3

Before calling the performance track complete, record device-backed budgets for
frame time, transition hitch duration, memory stability, and startup/room-entry
latency. The budgets should be based on the actual target devices and agreed
player experience; do not invent a desktop-only number and call mobile done.
Every optimization must include a before/after measurement and a visual
regression check at native pixel scale.

## Measured baseline — 2026-09-15

The fixed-seed scenario harness (`tests/performance_scenario_harness.gd`,
invoked via `tools/run_perf_harness.ps1`) now produces a repeatable desktop
baseline. Run it with no arguments for the regression floor, or on the device
build for the mobile profile. The harness does **not** assert budgets; budgets
are decided here after both targets are measured.

Desktop (this dev machine, headless console, seed `24681357`, 180 samples per
scenario after 90-frame warmup):

| Scenario | avg ms | worst ms | nodes | sprites |
|---|---:|---:|---:|---:|
| title idle | 6.90 | 8.08 | 1,646 | 891 |
| hub idle | 6.90 | 8.27 | 1,657 | 902 |
| hub shop page | 6.90 | 8.17 | 1,657 | 902 |
| combat room | 6.91 | 13.81 | 1,659 | 904 |
| boss room | 6.90 | 11.80 | 1,659 | 904 |
| room transition | 16.56 | 16.56 | — | — |
| pause menu | 6.89 | 8.28 | 1,664 | 909 |

Readings:

- Steady-state headless frame time is ~6.9 ms everywhere (~145 fps). That is the
  desktop CPU floor for the current scene, not the mobile number.
- The scene holds **~900 sprites across ~1,650 nodes**. That is a real count to
  watch; a device profile will decide whether node count is the binding cost.
- The **room transition is the one clear hitch** at ~16.6 ms single-sample,
  roughly 2.4× the steady state. This matches the plan's hypothesis that
  synchronous transition/prewarm work is a hot spot and is the first
  optimization target.
- Combat and boss worst-frames (13.8 / 11.8 ms) show the frame scheduler
  visiting more systems; still sub-16 ms headless.

Samsung A17 (real low-end target, already experienced as poor): baseline not yet
recorded. The harness must be run on a device build of this seed before any
optimization claim. Until the A17 numbers exist, the desktop numbers above are a
CPU floor, not a mobile budget.

### Measured improvement — 2026-09-15 (room-transition hitches)

The harness's `boss_room_transition` scenario was corrected to enter the real
`ROOM_DOWNSTAIRS` room for the seed through the actual door path
(`enter_connected_room`) instead of forcing a room id that did not exist in the
graph. That exposed a real defect the desktop baseline had hidden:

| Scenario | before | after | factor |
|---|---:|---:|---:|
| boss room transition (real door entry) | ~1,786 ms | ~89 ms | 20× |
| regular room transition | ~17 ms | ~16 ms | — |

The hitch was not the geometry copy (`tile_map_data` was already one native
operation, ~0.5 ms) or the walkable-tile rebuild (~0.2 ms). It was the stone
accent placer in `hub_stone_accent_layer.gd`:

1. **Full permutation enumeration** of every swappable group's anchors, then a
   cross-product over all groups, each candidate re-validating every placement's
   per-pixel footprint. Bounded to a seeded partial-shuffle candidate set.
2. **Double search** — the anchor-map validation re-ran `_find_valid_position`
   for every placement, then `_apply_room_placements` re-ran it again to commit
   the same positions. The validation now returns the resolved positions and the
   commit path consumes them directly.
3. **Unbounded retry loop** — rooms whose geometry (boss underlay/sealed doors)
   invalidate several authored anchors can never reach the full density target,
   so `refresh_current_room` retried up to 32 layout variants, each a full
   search (~50 ms). A plateau check now stops retrying once the visible count
   stops improving, and keeps the best variant.
4. **Authored anchor buried in the shuffled jitter order** — the designed slot
   could sit 20+ entries deep in a 25-offset shuffle, so every placement burned
   ~20 failed footprint scans before trying it. The authored anchor is now tried
   first, then a bounded seeded fallback.
5. **Unbounded anchor-map search budget** — the first-safe-map DFS could evaluate
   hundreds of candidate maps on anchor-hostile rooms before giving up. A
   per-leaf evaluation budget (`SAFE_MAP_EVALUATION_BUDGET`, tuned to 9) bounds
   the fallback without breaking the connected-room distinct-layout contract the
   accent smoke test enforces.

The accent layout contract (density 3-5 removals, per-group anchor swaps,
connected-room movement ≥ 60%, fixed cracks, room-tinted overlays) is unchanged
and verified by `hub_stone_accent_scene_smoke` across all 64 seeds.

The remaining ~40 ms of the boss entry is the boss activation (enemy spawn +
chest/room state) and the synchronous profile save; those are separate targets
from the accent hitch.

## Guardrails

- Prefer a new definition or direct typed dependency over a new global lookup.
- Keep definitions immutable at runtime and keep save data plain and stable.
- Do not make procedural generation erase authored pixel contracts.
- Do not optimize from line counts or intuition alone.
- Do not mix balance changes into composition or performance changes.
- Preserve the explicit frame schedule unless a measured scheduling change is
  deliberately designed and tested.
- A feature is a successful architecture proof only when a second piece of the
  same kind can be added with less central code, not merely when the first piece
  was moved into a new file.

## Immediate next moves

Ordered by dependency: the performance harness runs first because every
composition change touches the same hot paths (per-frame controller visits,
sprite preparation, palette recolor), and without a baseline the T2/T1 work
cannot be shown not to regress.

1. **[x] Add the fixed-seed performance scenario harness** (`tests/performance_scenario_harness.gd` + `tools/run_perf_harness.ps1`). It reports frame time, active nodes/sprites, and room-transition timing on fixed seeds. The desktop baseline is recorded above; the **Samsung A17 run is the outstanding next measurement** and gates any optimization claim.
1b. **[x] Fix the room-transition hitch** the harness exposed: the boss-room door entry measured ~1,786 ms (real `enter_connected_room` path) and is now ~89 ms via the stone-accent placer fixes above. Steady-state frame time and the accent layout contract are unchanged (verified by the accent smoke + door smoke tests). **Measurement note:** the ~89 ms figure is a single favorable sample; later runs (2026-09-16) ranged ~100–385 ms across both the pre- and post-refactor trees, so the boss entry is a genuine slow path but not a measured refactor regression. See [`AUDIT.md`](AUDIT.md) section 11.2 for the corrected reading and the harness-averaging next step.
2. **[x] Complete the legacy-coupling cleanup (T1)** — the composition score is
   100% and the strict audit passes; the regression floor is re-baselined to the
   achieved state. Do not hardcode the percentage in this document; the
   validator is the live source of truth.
3. Build the enemy-definition/factory proof around one existing slime variant
   (T2 slice B, with its pinned acceptance bar).
4. Use the measured A17 + desktop result to choose between cache/atlas work,
   node/effect reduction, loading changes, and the palette-shader experiment.
5. Require every new content feature to use the emerging definition boundary.

Each of these is an independent track: the harness (1/4) is T3, the enemy
proof (3) is T2, and the score (2) is T1. Pick them up in parallel where the
environment permits.
