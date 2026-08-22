# Tiny Demons — Composition Root Reduction Plan

Status: implementation active; 2,000-line milestone achieved

Plan date: 2026-08-22

Branch: `refactor/2026-08-18`

Related documents:

- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`AUDIT.md`](AUDIT.md)
- [`script-consolidation-plan.md`](script-consolidation-plan.md)
- [`refactor-route.md`](refactor-route.md)

---

## 1. Decision summary

The direction is correct and should be adopted with one important refinement:
the objective is not simply to shorten `gameplay.gd`. The objective is to make
Tiny Demons composition-driven, with one explicit owner for every feature and
`gameplay.gd` serving only as the runtime composition root.

The proposed architecture is accepted in principle. Implementation should not
begin until the ownership map and characterization gates in this document are
approved.

The previous B/C refactor route improved geometry, input, Chroma, progression,
frame naming, and verification boundaries. It did not complete the older M9/M10
coordinator-reduction objective. The engineering closeout recorded in `AUDIT.md`
therefore closes that bounded route, not the deeper composition-root migration.

## 2. Current evidence

Repository measurements on 2026-08-22:

| Surface | Current measurement | Desired end state |
| --- | ---: | ---: |
| `gameplay.gd` | 1,999 lines / 422 functions | 150–300 lines |
| `gameplay_state.gd` | 264 lines / 174 plain variables | Removed or limited to documented global session state |
| `screen_state_controller.gd` | 1,235 lines | Split by screen/domain ownership |
| `player_equipment_visual_component.gd` | 801 lines | Reviewed and split if it contains multiple lifecycles |
| `room_controller.gd` | 595 lines | Retained only if cohesive |
| Repository `root.call(...)` seams | 512 | Zero in production feature code |
| Repository `root.get(...)` seams | 539 | Zero in production feature code |
| Repository `root.set(...)` seams | 183 | Zero in production feature code |

The existing controllers demonstrate useful extraction work, but two files still
act as extensions of the old root object:

- `GameplayBootstrap` constructs systems by mutating an untyped `root` and calling
  coordinator compatibility methods.
- `GameplayFrameController` reads and writes root state dynamically and performs
  input policy, screen routing, combat sequencing, death flow, presentation, and
  transitions inside one update method.

This means the architecture is distributed physically but remains centrally
coupled behaviorally. Reducing only `gameplay.gd` while preserving those dynamic
root dependencies would move the god object rather than remove it.

The first composition milestone is now complete: profile, pickup, run, hub,
save/character-creation, and puzzle-room workflows have dedicated runtime
owners. The remaining work is the deeper coupling cleanup described below,
especially replacing compatibility delegates with typed owner commands and
signals.

## 3. The one purpose of `gameplay.gd`

`gameplay.gd` is the composition root for a gameplay scene.

It may:

1. Hold typed references to top-level runtime owners.
2. Assemble or request assembly of those owners during `_ready()`.
3. Connect cross-domain signals whose relationship is genuinely scene-wide.
4. Pass the frame delta to an explicit frame scheduler.
5. Start and stop the composed runtime as the scene enters or exits.

It may not:

- implement combat, Chroma, inventory, room, puzzle, enemy, UI, audio, geometry,
  collision, profile, save, loot, or presentation rules;
- own feature timers, actor-keyed registries, caches, or mutable feature state;
- construct feature-specific UI or effects;
- query input directly;
- use dynamic `call`, `get`, or `set` to treat the root as a service locator;
- expose compatibility wrappers that merely forward to a feature owner; or
- decide feature policy inside `_physics_process()`.

The intended shape is approximately:

```gdscript
extends Node2D

@onready var runtime := GameplayComposition.compose(self)


func _ready() -> void:
    runtime.connect_cross_domain_events()
    runtime.start()


func _physics_process(delta: float) -> void:
    runtime.tick(delta)
```

The exact API may differ, but any additional responsibility requires an explicit
architecture review.

## 4. Ownership model

Not every object should be called a component. Tiny Demons should use three clear
ownership forms.

### Actor components

Actor components own local capabilities and state attached to one actor.

Examples: health, movement, attacks, guard, Chroma, animation, equipment, slime
brain, slime combat, and slime presentation.

An actor component owns its state transitions and exposes typed commands and
signals. It does not locate unrelated systems through the scene root.

### Domain controllers

Domain controllers own workflows spanning several objects inside one bounded
feature.

Examples: run flow, room lifecycle, projectiles, pickups, targeting, HUD, effects,
screen flow, save-slot flow, hub progression, and encounter coordination.

A controller owns its feature state, lifecycle, construction where appropriate,
and update entry points. It does not become a generic destination for unrelated
code extracted from `gameplay.gd`.

### Stateless services and resources

Stateless calculations and authored configuration belong in calculators, catalogs,
typed resources, and tuning resources.

Examples: combat formulas, aspect definitions, item catalogs, palette definitions,
geometry helpers, and progression calculations.

## 5. Feature-creation contract

Every new feature must answer these questions before implementation:

1. Who owns its mutable state?
2. Who constructs and destroys it?
3. What typed commands can other owners issue?
4. What signals or typed results does it publish?
5. Which frame phase updates it, if any?
6. Which automated test characterizes its contract?

The required flow is:

```text
Define owner
  → define state and lifecycle
  → define typed API/signals
  → add characterization
  → compose the owner
```

Adding variables to `gameplay_state.gd`, methods to `gameplay.gd`, or new
`root.call/get/set` dependencies is prohibited unless the architecture plan is
first amended with a documented exception.

## 6. Migration rules

These rules prevent another apparent extraction that leaves the same hidden root
coupling behind.

1. Move ownership, not just functions. State, behavior, lifecycle, and tests move
   together.
2. Use typed dependencies. A feature receives only the owners it actually needs.
3. Do not introduce a universal mutable `GameplayContext` or service locator.
   Small immutable dependency bundles are allowed only when every field is relevant
   to the receiving owner.
4. Delete the old seam in the same slice. A forwarding wrapper may exist only
   during one in-progress slice and may not survive its exit gate.
5. Preserve frame ordering explicitly. Extraction may move phase work but may not
   create independent `_process()` loops that obscure order.
6. Do not mix balance or feature changes into structural slices.
7. Do not create replacement god objects. Any controller approaching 600 lines or
   combining multiple lifecycles requires an ownership review before more code is
   added.
8. Keep one structural slice in progress at a time. Each slice must return the full
   suite to green before the next begins.

## 7. Target runtime composition

The final composition should resemble the following ownership tree. Names are
provisional; boundaries are the important part.

```text
Gameplay (composition root)
├── GameplayRuntime / phase scheduler
├── InputRouter
├── RunFlowController
├── RoomController
├── EncounterController
├── PlayerActor
│   ├── PlayerController + ActorMotor
│   ├── Health + Guard
│   ├── Attack + CombatMomentum
│   ├── Chroma + AspectAbility
│   └── Equipment + Animation + Visuals
├── SlimeActor instances
│   ├── Health + Stats
│   ├── Brain + Tactics
│   ├── Combat + Animation
│   └── HealthPresenter + Visuals
├── Interaction owners
│   ├── ChestController
│   ├── RestFireController
│   └── NpcController
├── World capability owners
│   ├── MagicProjectileController
│   ├── ChromaPickupController
│   ├── LootDropController
│   └── ActorCollisionSystem
└── Presentation owners
    ├── HudController
    ├── ScreenFlow owners
    ├── EffectsSpawner
    ├── OcclusionRenderer + DepthSorter
    ├── ShadowController
    └── SoundManager
```

## 8. Execution phases

### Phase R0 — Reopen and characterize

Purpose: establish an honest baseline and protect behavior before ownership moves.

Work:

- Mark M9 coordinator reduction active again and clarify the narrower B/C closeout.
- Generate a complete function/state inventory for `gameplay.gd` and
  `gameplay_state.gd`, grouped by intended owner.
- Record baseline line counts, dynamic root seams, frame timing, and smoke results.
- Add missing characterization for run flow, screen mode routing, combat order,
  room transitions, and save/hub transitions.
- Freeze feature and balance changes during structural slices.

Exit gate:

- Every coordinator function and state field has a proposed owner.
- The complete smoke suite and supported manual checklist pass before movement.

### Phase R1 — Typed composition boundary

Purpose: replace dynamic root mutation with explicit construction and dependencies.

Work:

- Define the typed runtime owners assembled by the composition root.
- Replace `GameplayBootstrap.initialize(root)` with typed construction/configuration
  APIs.
- Move actor capability creation into actor scenes or typed actor assemblers.
- Connect signals at construction time instead of discovering owners through root
  properties.
- Keep startup ordering explicit and characterized.

Exit gate:

- Bootstrap code performs no `root.call/get/set` operations.
- Player and slime capabilities can be assembled without feature logic in
  `gameplay.gd`.
- `gameplay.gd` checkpoint: at or below 2,400 lines.

### Phase R2 — Run, profile, loot, and hub ownership

Purpose: remove the largest non-combat workflow from the coordinator without
enlarging `ScreenStateController`.

Work:

- Add a `RunFlowController` for run start, completion, death outcome, return, and
  settlement commands.
- Add or complete a hub progression owner for pending stats, respec, equipment,
  fusion, salvage, and confirmation.
- Separate save-slot/character-creation flow from generic screen presentation.
- Add a world loot-drop owner for chest item launch, recovery, interaction, and
  collection.
- Keep profile persistence in `ProfileSaveService` and durable data in
  `PlayerProfile`.

Exit gate:

- `gameplay.gd` contains no hub, save-slot, settlement, item-fusion, salvage, or
  world-loot behavior.
- `ScreenStateController` is split by lifecycle rather than growing further.
- `gameplay.gd` checkpoint: at or below 1,800 lines.

### Phase R3 — Combat and encounter ownership

Purpose: make actor components and encounter controllers own combat behavior.

Work:

- Move player attack completion policy, combo transitions, damage dispatch, and
  combat telemetry behind typed combat APIs.
- Move slime movement coordination, attack reach/lunge, knockback, death, health
  presentation events, and boss/add priority to enemy/encounter owners.
- Keep formulas in stateless combat calculators and tuning in resources.
- Replace coordinator accessors such as `_slime_health`, `_slime_brain`, and
  `_damage_slime` with direct typed component APIs.

Exit gate:

- `gameplay.gd` contains no actor-specific combat calculations or state machines.
- Encounter updates are one typed phase call.
- `gameplay.gd` checkpoint: at or below 1,200 lines.

### Phase R4 — Elemental, projectile, pickup, and interaction ownership

Purpose: finish domains that already have partial owners.

Work:

- Move casting policy and presentation synchronization behind
  `PlayerAspectAbilityComponent` and `PlayerChromaComponent`.
- Give `MagicProjectileController` complete projectile spawn, movement, impact,
  targeting, trail, and cleanup ownership.
- Give `ChromaPickupController` complete spawn, launch, collection, restoration,
  and cleanup ownership.
- Move chest, rest fire, NPC, puzzle orb, door, and final-exit policy to their
  interaction/room owners.

Exit gate:

- No magic, projectile, Chroma pickup, puzzle, chest, fire, NPC, or door feature
  behavior remains in `gameplay.gd`.
- `gameplay.gd` checkpoint: at or below 750 lines.

### Phase R5 — Presentation and screen ownership

Purpose: remove remaining rendering and UI implementation from the composition
root.

Work:

- Move HUD update policy, target presentation, health/MP presentation, and focus
  indicators fully into HUD presenters.
- Split title, save selection, character creation, hub, run results, loading,
  transition, and game-over flows into cohesive owners.
- Move actor visual transforms, flashes, palette effects, depth, occlusion,
  shadows, sound, and effect construction to their existing presentation owners.
- Remove texture-generation and UI-construction compatibility wrappers.

Exit gate:

- `gameplay.gd` performs no drawing, texture generation, UI construction, visual
  animation, or audio decisions.
- No presentation controller relies on dynamic root access.
- `gameplay.gd` checkpoint: at or below 450 lines.

### Phase R6 — Frame scheduler and state elimination

Purpose: leave only composition and explicit phase sequencing.

Work:

- Replace the current monolithic `GameplayFrameController.tick(root, delta)` with
  typed mode routing and small ordered phase runners.
- Preserve the named order: input, simulation, contact resolution,
  damage/progression, presentation, transitions.
- Move mode-specific update policy to its owner; the scheduler selects owners, not
  individual feature methods.
- Remove compatibility delegates, duplicate mirrors, actor registries, and dead
  shared state.
- Remove `gameplay_state.gd` if no truly global session values remain. Otherwise,
  rename and document the minimal state object.

Exit gate:

- `gameplay.gd` is 150–300 lines and has one purpose: composition.
- `GameplayFrameController` performs typed phase scheduling only.
- Production feature code contains no `root.call/get/set` seams.
- No coordinator-owned feature state remains.

### Phase R7 — Architecture hardening

Purpose: prove the architecture supports continued game development.

Work:

- Add one small representative capability through composition without adding
  feature logic to `gameplay.gd`.
- Run keyboard/controller, combat, rooms, puzzles, interactions, hub, save/load,
  death, run completion, depth/occlusion, and performance playtests.
- Re-run fresh-clone import and the complete automated suite.
- Record final metrics and update `ARCHITECTURE.md`, `AGENTS.md`, and audit status.
- Archive superseded migration notes after their evidence has been preserved.

Exit gate:

- The full game loop passes without meaningful behavior or frame-time regression.
- A documented new-feature example demonstrates owner-first composition.
- The composition-root rule is the default extension path for future work.

## 9. Slice quality gate

Every implementation slice must record:

- exact responsibility moved;
- previous and new owner;
- state moved;
- typed API and signals introduced;
- old dynamic seams removed;
- focused characterization result;
- complete smoke-suite result;
- manual playtest required and result;
- `gameplay.gd` line/function delta;
- repository `root.call/get/set` delta; and
- frame-time observation for runtime-sensitive slices.

A slice is incomplete if behavior has moved but the old forwarding surface remains.

## 10. Success definition

This migration is complete only when all of the following are true:

- `gameplay.gd` is 150–300 lines and serves only as composition root.
- `gameplay_state.gd` is absent or contains only explicitly justified global
  session state.
- Every mutable feature state has one owner.
- New actors are assembled from actor components.
- New world and UI features are introduced through cohesive domain owners.
- Cross-domain communication uses typed methods, commands/results, and signals.
- Production feature code contains no dynamic root service-locator seams.
- The frame schedule remains explicit and deterministic.
- No replacement god controller was created.
- Automated, manual, fresh-clone, and frame-time gates pass.

## 11. Evaluation

This is the correct long-term direction for Tiny Demons. The repository already
contains many of the necessary components and controllers, so the migration is not
a rewrite. The principal work is completing ownership, replacing dynamic root
coupling, splitting oversized mixed-lifecycle controllers, and deleting the
compatibility surface after each move.

The highest-risk areas are run/hub/save flow and frame scheduling. They should be
characterized before extraction and moved in bounded slices. Combat geometry and
Elemental Chroma work should remain behaviorally frozen while their ownership is
moved; feature expansion resumes after the receiving APIs are stable.

The plan should be approved before Phase R0 begins. Once approved, R0 produces the
function/state owner matrix that controls all later implementation work.
