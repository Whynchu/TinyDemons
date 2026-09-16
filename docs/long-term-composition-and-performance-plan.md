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

## Purpose

The current composition percentage measures a specific cleanup: reducing legacy
coupling around `GameplayState`, reflective root access, oversized owners, and
transitional adapters. It is useful, but it is not the full product goal.

The long-term goal is a game that can grow for years without every new enemy,
room, map rule, reward, effect, or balance change requiring edits to a central
state bag or a large coordinator. A new piece of content should be assembled
from an explicit definition, a runtime scene/component composition, and a
validated registration or content pool.

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
tests:

1. Add a new enemy by creating or composing a scene, definition, and behavior
   registration without editing `GameplayState` or adding a room special case.
2. Add a room by supplying geometry, sockets, encounter, reward, and milestone
   definitions without changing the central frame coordinator.
3. Add a map or route by selecting a dungeon definition and generator policy,
   with deterministic seed output and validation.
4. Change tuning, palettes, drops, or spawn weights through resources/catalogs
   while preserving stable IDs and save migration rules.
5. Instantiate the same content in a headless fixture, a normal scene, and a
   generated run with the same ownership rules.
6. Validate definitions before runtime: duplicate IDs, missing assets,
   invalid references, impossible geometry, unreachable sockets, and unsafe
   encounter placement should fail early.
7. Keep persistence based on IDs, seeds, and plain data rather than live Node
   references.

The current `tools/validate_composition.ps1` percentage remains useful for the
legacy-coupling subproject. It should not be renamed into a claim that these
content-authoring workflows are complete.

## Incremental migration sequence

### A. Finish the current ownership cleanup without blocking feature work

Complete the remaining room-entry/activation adapters, state-bag reductions,
and root-access reductions tracked in
[`composition-refactor-analysis.md`](composition-refactor-analysis.md). Keep
this as a hygiene track. A feature may proceed when it uses the new boundary it
needs; it should not add new `GameplayState`-backed contexts or reflective seams.

### B. Build one enemy definition vertical slice

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

### C. Separate encounters and rooms

Move room-specific enemy/reward choices into `EncounterDefinition` and
`RoomDefinition` while leaving authored geometry and generated topology
distinct. Room runtime state should own claims, active actors, entrance locks,
and clear state; definitions should remain reusable and immutable.

### D. Make dungeon and map authoring compositional

Keep the seeded generator responsible for producing a validated layout, but
make its inputs explicit: room pool, route policy, milestone rules, socket
rules, reward policy, and seed. The map controller should present the result,
not become the source of every generation rule.

### E. Extend the same pattern to items, elements, rewards, and effects

Use stable definitions and catalogs for content. Runtime components should
consume typed definitions and emit typed results/signals. Do not create a new
global registry as a replacement service locator; catalogs should be narrow,
validated dependencies.

### F. Add authoring and validation feedback

The editor/designer workflow should answer “what can I add and what will break?”
without reading several coordinators. Add definition validation, catalog
reports, deterministic preview commands, and one documented example each for
an enemy, room, encounter, reward, and map.

## Performance investigation track

Tiny Demons’ low logical resolution does not automatically make it cheap. A
small pixel game can still spend significant time on transparent blended
sprites, many CanvasItem nodes, material/texture changes that reduce batching,
per-frame script loops, image allocations, duplicate GPU textures, particles,
occlusion, and synchronous resource preparation. These are hypotheses until a
device profile confirms them.

The project already selects Godot’s mobile renderer and nearest-neighbor canvas
texture filtering in `project.godot`. That is a sensible baseline, but it is
not a performance diagnosis or a mobile budget.

### Current hypotheses to measure

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

### Measurement before optimization

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

### Palette rendering decision

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

### Performance exit criteria

Before calling the performance track complete, record device-backed budgets for
frame time, transition hitch duration, memory stability, and startup/room-entry
latency. The budgets should be based on the actual target devices and agreed
player experience; do not invent a desktop-only number and call mobile done.
Every optimization must include a before/after measurement and a visual
regression check at native pixel scale.

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

1. Keep the current 82.5% composition score labeled as the legacy-coupling
   checkpoint.
2. Build the enemy-definition/factory proof around one existing slime variant.
3. Add a fixed-seed performance scenario harness that reports frame time,
   active visual objects, palette/resource preparation, and room-transition
   timing on the desktop and Samsung A17 targets.
4. Use the measured result to choose between cache/atlas work, node/effect
   reduction, loading changes, and the palette-shader experiment.
5. Require every new content feature to use the emerging definition boundary.
