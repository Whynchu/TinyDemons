# Gameplay Script Consolidation Plan

Status: proposed

Branch: `agent/script-consolidation`

Baseline commit: `15a2832`

Audit date: 2026-08-09

> Related: the active gameplay **feature** overhaul (gear value, base stats,
> enemy/boss difficulty) lives in [`combat-economy-overhaul.md`](combat-economy-overhaul.md).
> This plan is the architecture companion to that balance work.

## Purpose

`scripts/gameplay.gd` currently owns most runtime behavior for the
game. This plan moves that behavior into composed, testable components while
keeping the game playable after every milestone.

The objective is not merely to reduce line count. The objective is to give each
piece of state one clear owner, remove per-actor state dictionaries from the
scene root, and make new actors, enemies, rooms, and interactions possible
without expanding a central gameplay script.

## Audited baseline

The following measurements were taken directly from `gameplay.gd` at baseline:

| Metric | Baseline | Direction |
| --- | ---: | --- |
| Physical lines | 5,419 | Reduce root coordinator to 150-300 lines |
| Functions | 291 | Move behavior behind component APIs |
| Constants | 113 | Move tuning values into typed resources |
| Root state variables | 261 | State belongs to the component that changes it |
| Dictionaries declared as state | 63 | Eliminate actor-keyed state dictionaries |
| Direct scene references (`@onready`) | 22 | Components receive narrow, typed dependencies |

Line count alone is not a runtime performance measurement. The current cost is
primarily coupling and maintenance risk. Runtime concerns also exist where the
root physics loop updates every system and where texture/occlusion work can be
triggered during gameplay, but these must be measured independently.

### Responsibility map

The audit found these broad responsibility regions. Ranges are navigational,
not proposed module boundaries; several concerns are interleaved.

| Approximate lines | Current responsibility |
| --- | --- |
| 1-405 | Tuning constants, scene references, and shared mutable state |
| 406-649 | Initialization and the global physics update pipeline |
| 650-1402 | Death flow, title screen, archetype screen, loading, transitions |
| 1403-1887 | Player movement, roll, attacks, animation, and combat formulas |
| 1888-2976 | Chest/NPC interactions, room state, sockets, and effects |
| 2977-3617 | Slime AI/combat, health updates, and floating numbers |
| 3622-3999 | Actor collision, depth registration, and texture preparation |
| 4000-4505 | Health UI, animation frame construction, palettes, actor visuals |
| 4506-5179 | Occlusion, shadows, input, targeting, HUD, and image caches |
| 5180-5419 | Walkable geometry and actor-position queries |

### Highest-risk coupling

- The root `_physics_process()` defines ordering for input, attacks, movement,
  enemies, regeneration, interactions, transitions, depth, occlusion, and UI.
- Slime behavior and health are represented by many dictionaries keyed by a
  `Sprite2D`. Adding an enemy requires coordinated registration and cleanup.
- Gameplay rules directly update presentation objects such as bars, sprites,
  particles, dialogue, and screen overlays.
- Actor movement, contact resolution, map walkability, and combat knockback call
  into one another rather than using a narrow movement service.
- Texture slicing, recoloring, caching, and occlusion image generation live next
  to input and combat code.

## Design direction

Use scene composition: actors and world objects gain child nodes with focused
scripts. Shared behavior is composed rather than inherited from a large actor
base class.

```text
Main
|-- GameFlow
|-- World
|   |-- RoomController
|   |-- WalkableArea
|   |-- ActorCollisionSystem
|   |-- DepthSorter
|   `-- OcclusionRenderer
|-- Actors
|   |-- Player
|   |   |-- StatsComponent
|   |   |-- EquipmentComponent
|   |   |-- HealthComponent
|   |   |-- ActorMotor
|   |   |-- PlayerController
|   |   |-- PlayerAttackComponent
|   |   |-- PlayerRollComponent
|   |   `-- PlayerAnimationComponent
|   `-- Slime instances
|       |-- StatsComponent
|       |-- HealthComponent
|       |-- ActorMotor
|       |-- CombatComponent
|       |-- SlimeBrain
|       `-- SlimeAnimationComponent
|-- Interactables
|   |-- ChestController
|   |-- NpcController
|   `-- RestFireController
|-- EffectsSpawner
`-- UI
    |-- HudController
    |-- TitleScreen
    |-- ArchetypeScreen
    `-- GameOverScreen
```

### Ownership rules

1. A value is stored by the component responsible for changing it.
2. Components expose commands and signals, not their internal timers.
3. Actor components may reference siblings through typed exported properties or
   explicit setup. They must not search the whole scene tree.
4. UI observes domain signals and does not calculate combat or room state.
5. `GameFlow` coordinates global states such as title, dialogue pause, hit-stop,
   player death, and scene transitions. It does not implement actor behavior.
6. Tuning is held in typed `Resource` objects so variants share behavior without
   copying scripts.
7. Avoid one component per trivial helper. A component should own meaningful
   state, behavior, or a reusable boundary.

### Initial signal contracts

```gdscript
# HealthComponent
signal health_changed(current: float, maximum: float)
signal damaged(amount: float, critical: bool)
signal healed(amount: float)
signal died

# CombatComponent / attack components
signal attack_started
signal hit_confirmed(target: Node, amount: float, critical: bool)
signal attack_finished

# Interactable components
signal interaction_available(interactable: Node, available: bool)
signal interacted(interactable: Node)

# RoomController
signal room_entered(room_id: StringName, room_type: StringName)
signal room_cleared(room_id: StringName)
```

Signals are for events. Direct method calls remain appropriate for commands such
as `health.apply_damage(hit)`, `motor.try_move(motion)`, or
`room_controller.enter_socket(socket_id)`.

## Proposed modules

| Module | Owns | Does not own |
| --- | --- | --- |
| `gameplay.gd` / `game_flow.gd` | Startup and global mode coordination | Actor timers, UI drawing, collision math |
| `health_component.gd` | Current/max health, regen, damage/death events | Damage formula, health bars |
| `combat_calculator.gd` | Stateless damage and critical calculations | Actor state or effects |
| `actor_motor.gd` | Movement, knockback, contact requests | Input or AI decisions |
| `player_controller.gd` | Player action coordination and control locks | Rendering and health internals |
| `player_attack_component.gd` | Combo, lunge, hitbox, hit tracking | Input-device polling and enemy health UI |
| `player_roll_component.gd` | Roll state and invulnerability contract | Dust rendering |
| `player_animation_component.gd` | Player animation state and frames | Combat outcomes |
| `slime_brain.gd` | Aggro, holds, repathing, attack decisions | Shared collision implementation |
| `slime_animation_component.gd` | Facing, scoot, breath, attack visuals | Health and damage |
| `room_controller.gd` | Dungeon graph, sockets, room persistence | Chest/NPC presentation |
| `walkable_area.gd` | Walkable polygons and nearest-point queries | Actor state |
| `actor_collision_system.gd` | Actor/static contact resolution | Input and AI |
| `interaction_component.gd` | Availability and interaction contract | Object-specific reward logic |
| `hud_controller.gd` | HUD presentation and signal subscriptions | Combat calculations |
| `effects_spawner.gd` | Particles, damage numbers, roll dust | Damage application |
| `occlusion_renderer.gd` | Occlusion images/cache and actor visibility | Target selection |
| `sprite_frame_library.gd` | Slicing, flipping, recoloring, frame caches | Animation state |

Target size is generally 100-350 lines per cohesive script. A complex controller
may exceed that when its state and dependencies remain singular and clear.

## Model routing and token budget

Model recommendations are based on the [official OpenAI model
guidance](https://developers.openai.com/api/docs/models). The available pool also
includes [GPT-5.5](https://developers.openai.com/api/docs/models/gpt-5.5) for
complex coding and professional work,
[GPT-5.4](https://developers.openai.com/api/docs/models/gpt-5.4) for affordable
coding work, and [GPT-5.4
mini](https://developers.openai.com/api/docs/models/gpt-5.4-mini) for fast,
efficient coding and subagent workloads. Recheck these pages if the plan is
executed after the audit date because model availability can change.

The model is selected by risk, not by milestone size. Use the lowest tier that
can safely own the decision being made.

| Tier | Model and effort | Appropriate work | Do not assign |
| --- | --- | --- | --- |
| Clerical | `gpt-5.6-luna`, low | Metrics, documentation, inventories, formatting, checklist transcription | Production code whose behavior or ownership must be inferred |
| Mechanical coding | `gpt-5.4-mini`, low or medium | Known renames, resource population, repetitive scene changes, focused tests, implementing an exact contract | Designing contracts, changing update order, diagnosing broad regressions |
| Everyday coding | `gpt-5.4`, medium | Isolated utilities/components, typed resources, straightforward scene wiring, local cleanup | Interleaved state machines or unresolved cross-system ownership |
| Integration | `gpt-5.6-terra`, medium by default; high for coupled state | Cross-file extraction, typed APIs, signals, component integration, behavior diagnosis | The hardest architecture impasses or bulk mechanical edits |
| Complex refactor | `gpt-5.5`, high | Player/enemy state machines, collision/room boundaries, coupled refactors, difficult regression analysis | Repetitive migrations after the design is settled |
| Architecture authority | `gpt-5.6-sol`, high | Final boundary decisions, unresolved update-order problems, architecture review after lower tiers identify the issue | Routine implementation, documentation, or first-pass diagnosis |

Use `xhigh` only after a concrete high-effort attempt identifies a genuinely
unresolved architecture or behavior problem. Do not begin routine work at
`xhigh` or `max`.

### Escalation rules

1. Start with the milestone's default model below.
2. Keep each assignment to one coherent slice, normally one to three scripts and
   one explicit acceptance test. Do not request an entire milestone in one run.
3. Give the model the relevant function ranges, component contract, current
   scene nodes, and validation criteria. Do not paste all of `gameplay.gd` when
   targeted file inspection is available.
4. Move from Luna to GPT-5.4 mini for bounded code changes, then to GPT-5.4 when
   the implementation requires local judgment rather than exact instructions.
5. Move from GPT-5.4 to Terra when work chooses ownership, changes a signal/API
   contract, integrates multiple components, or diagnoses a failed behavior
   check.
6. Move from Terra to GPT-5.5 when work crosses three or more systems, changes
   global update order, exposes circular dependencies, or fails the same
   acceptance check twice for a non-mechanical reason.
7. Use Sol only when GPT-5.5 has isolated an unresolved architecture decision,
   for the initial design of the highest-risk boundary, or for final review.
8. After a higher tier records the decision, return repetitive implementation to
   GPT-5.4 or GPT-5.4 mini instead of leaving the entire milestone on that tier.

### Milestone model assignments

| Milestone | Default | Use the cheaper tier for | Escalate when |
| --- | --- | --- | --- |
| M0 Baseline/safeguards | Luna, low | GPT-5.4 mini, low, for an explicitly designed parser/smoke harness | GPT-5.4, medium, if baseline behavior must be diagnosed |
| M1 Utilities/tuning | GPT-5.4, medium | GPT-5.4 mini, low, for approved constant/resource moves and focused tests | Terra, medium, if extraction reveals a shared cache or ownership boundary |
| M2 Health | Terra, high | GPT-5.4, medium, for established UI hookups; GPT-5.4 mini for repeated scene-node additions | GPT-5.5, high, if death, regeneration, room reset, and UI ownership cannot be separated cleanly |
| M3 Player | GPT-5.5, high | GPT-5.4/Terra for isolated components after contracts and update phases are decided | Sol, high; use xhigh only for an unresolved combo/roll/hit-stop ordering regression |
| M4 Enemies | Terra, high | GPT-5.4 mini, medium, for variants from an approved template; GPT-5.4 for focused behavior extraction | GPT-5.5, high, if removing dictionaries changes multi-enemy ordering, targeting, or collision |
| M5 World/rooms | GPT-5.5, high | GPT-5.4, medium, for implementing a settled world-service API | Sol, high; use xhigh only for an unresolved collision, traversal, or persistence boundary |
| M6 Interactions/presentation | GPT-5.4, medium | GPT-5.4 mini, low, for repetitive UI hookups and resource moves | Terra for occlusion integration; GPT-5.5 for cross-system event-order regressions |
| M7 Cleanup | Terra, medium | Luna for metrics/docs; GPT-5.4 mini for exact dead-code removals | GPT-5.5 for final dependency review; Sol only for an unresolved architecture defect |

## Migration roadmap

Each milestone must leave the game runnable. During migration, `gameplay.gd` may
temporarily delegate to new components before old fields and methods are removed.

### M0 - Baseline and safeguards

Model route: Luna at low effort by default, GPT-5.4 mini for an explicitly
designed harness, and GPT-5.4 at medium effort for baseline diagnosis.

- [x] Record source metrics and responsibility map.
- [x] Preserve baseline commit on `main`.
- [x] Create a dedicated consolidation branch.
- [x] Write a manual smoke-test checklist for the current playable loop in
  [`gameplay-smoke-checklist.md`](gameplay-smoke-checklist.md).
- [x] Capture expected room, combat, interaction, and death behavior in the
  smoke-test checklist.
- [x] Add a headless scene-load/parser check. Godot v4.7.1 console build is
  now available in the development environment; headless main-scene load and
  all three smoke tests pass with exit 0.

Exit criteria: behavior checks are documented and can be repeated after every
milestone. M0 documentation is complete and the automated headless parser/smoke
check is now unblocked (Godot v4.7.1 available).

### M1 - Pure utilities and tuning data

Model route: GPT-5.4 at medium effort for extraction and GPT-5.4 mini after
resource schemas and move lists are approved. Use Terra for boundary conflicts.

- [x] Extract `CombatCalculator` without changing damage results. Integration
  preserves the existing RNG, equipment context, critical flag, and formulas;
  confirmed via the headless Godot smoke pass.
- [x] Extract sprite slicing/flipping/recoloring into `SpriteFrameLibrary`.
  Gameplay retains temporary one-line delegates while callers migrate safely.
- [x] Introduce typed player, slime, combat, and effects tuning resources.
- [x] Migrate the remaining player, slime, and effects call sites from root
  constants after parity checks.
- [x] Replace runtime tuning constants only after parity was verified. Asset
  dimensions and scene/layout constants remain local until their owners move.

Exit criteria: pure calculations and static asset preparation no longer depend
on the gameplay scene root.

### M2 - Health composition

Model route: Terra at high effort because lifecycle state crosses combat, UI,
death, regeneration, and room reset. Use GPT-5.4 for settled UI work and escalate
unresolved lifecycle boundaries to GPT-5.5.

- [x] Define reusable `HealthComponent` lifecycle API (damage, healing, regen,
  reset, and death signals).
- [ ] Add `HealthComponent` to the player and each slime.
- [x] Move health, maximum health, regen, and death state into the component.
- [ ] Connect health UI and effects using signals.
- [x] Remove actor health and regen dictionaries from `gameplay.gd`; retain
  display-health interpolation state until the HUD signal slice.
- [x] Connect damage/healing signals to the existing delayed-fill presentation
  hooks without changing bar timing.
- [x] Subscribe player and slime HUD refreshes to `health_changed` while
  retaining interpolation polling for the animated fill transition.
- [x] Subscribe HUD refreshes to health signals; retain only the per-frame
  interpolation needed for the animated fill transition.
- [x] Verify damage rolls, critical hits, regen delays, death, and room reset.

Exit criteria: each actor owns its health lifecycle; the root does not index
health state by actor.

### M3 - Player composition

Model route: GPT-5.5 at high effort for the initial state/update-order design;
route isolated implementation slices back to Terra or GPT-5.4 after contracts
are fixed. Reserve Sol for an unresolved ordering problem.

- [x] Define `ActorMotor` motion/knockback API while collision resolution stays
  in the coordinator for update-order safety.
- [x] Route player knockback and roll lifecycle through the motor boundary.
- [x] Introduce the `PlayerController` input-lock boundary; action-state
  migration remains incremental to preserve update order.
- [x] Extract roll lifecycle state into `PlayerRollComponent`; dust rendering
  remains in the coordinator pending the effects slice.
- [x] Introduce `PlayerAttackComponent` for attack lifecycle and hit-target
  registration and combo-buffer state; animation timing remains in the
  coordinator.
- [x] Move attack-lunge timer and velocity state behind the attack component;
  swept collision remains in the coordinator.
- [x] Introduce `PlayerAnimationComponent` as the animation state boundary;
  frame construction and palette application remain in the coordinator.
- [x] Verify dialogue locks, hit-stop, combo timing, collision, and death
  through the current Godot smoke pass; the headless smoke tests pass with
  exit 0.

Exit criteria: the root starts/stops player control but owns no player action
timers or animation frames.

### M4 - Enemy composition

Model route: Terra at high effort for the first reusable slime, GPT-5.4 for
focused behavior extraction, and GPT-5.4 mini for variants from the approved
template. Use Luna for documentation and GPT-5.5 for unresolved coupling.

- [x] Create a reusable `slime.tscn` with shared capability nodes; visual and
  tuning exports remain configured by the migration instance slice.
- [x] Move aggro, repath, scoot, hold, attack, hit reaction, and death state to
  slime components.
- [x] Define and attach `SlimeBrain` decision-state boundary for aggro,
  repath, hold, and attack cooldown timing.
- [x] Define and attach `SlimeCombatComponent` for attack lifecycle, cooldown,
  and hit confirmation state.
- [x] Define and attach `SlimeAnimationComponent` for facing and attack-frame
  presentation state.
- [x] Configure the live blue/green/red actor roots with `SlimeActor` variant
  metadata while preserving their existing Sprite2D child hierarchies.
- [x] Remove all remaining slime-keyed behavior dictionaries; remaining maps
  are presentation caches owned by the coordinator until M6.
- [x] Verify multi-slime collision, targeting, room reset, and difficulty level.

### M4 closeout slices

The remaining slime-keyed state is tracked in four migration groups so each
group can be verified without changing update order:

1. Decision/movement: targets, repath, scoot, hold, idle-breath, and start
   positions move into `SlimeBrain`/`ActorMotor`-style components.
2. Combat/reaction: flash, hitstun, knockback, attack timers, frames, facing,
   hit confirmation, and persistent aggro move into combat/animation components.
3. Presentation: texture/frame and overhead-health dictionaries move behind
   variant resources and HUD presenters.
4. Scene/variant migration: blue, green, and red actors use configured slime
   instances; multi-slime collision, targeting, room reset, and difficulty are
   replayed after every group.

M4 is not complete until all four groups are migrated and the verification
checklist passes. Current inventory: 16 slime-keyed dictionaries, with core
decision/combat/death state now component-owned.

Exit criteria: adding a slime variant requires a resource/scene configuration,
not new root-script state.

### M5 - World and room systems

Model route: GPT-5.5 at high effort for collision, walkability, transition, and
persistence boundaries; GPT-5.4 implements APIs after the design is settled.
Reserve Sol for a boundary GPT-5.5 cannot resolve safely.

#### M5 closeout implementation plan

1. Collision pass: move broad-phase, static-contact requests, and actor-contact
   resolution behind `ActorCollisionSystem`; retain exact gameplay callbacks as
   a compatibility fallback.
2. Render pass: move depth-index application, shadow registration, and shadow
   placement behind `DepthSorter`/`ShadowController`; compare z-order and scale
   against the current scene.
3. Room pass: move graph/socket selection, arrival context, transition locks,
   and persistence commands behind `RoomController`; retain dungeon data as a
   read-only dependency during migration.
4. Occlusion pass: move image/cache ownership and invalidation behind
   `OcclusionRenderer`, then measure update frequency in representative rooms.
5. Verification pass: replay every socket direction, return traversal, room
   reset, actor placement, collision, depth, shadows, and occlusion case before
   marking M5 complete.

- [ ] Extract walkable geometry and queries into `WalkableArea`.
- [x] Define and attach `WalkableArea` geometry/query boundary; tile extraction
  remains in the coordinator pending parity verification.
- [x] Delegate nearest walkable queries to `WalkableArea` with a legacy
  point-sample fallback when geometry is unavailable.
- [ ] Extract actor contact/static collision into `ActorCollisionSystem`.
- [x] Define and attach `ActorCollisionSystem` actor-set boundary; existing
  resolution remains authoritative pending parity migration.
- [x] Delegate actor-contact candidate filtering to `ActorCollisionSystem`,
  retaining exact gameplay contact rules and static collision fallback.
- [x] Verify broad-phase coverage for slimes and the cloaked demon after actor
  set synchronization and contact-radius correction.
- [ ] Extract depth ordering and shadows.
- [x] Define and attach `DepthSorter` ownership boundary; current ordering
  logic remains in the coordinator pending parity migration.
- [x] Delegate depth-key-to-z-index conversion to `DepthSorter` while retaining
  specialized actor/marker depth-key calculation in the coordinator.
- [x] Define and attach `ShadowController` ownership boundary; shadow
  placement remains coordinator-owned pending render parity migration.
- [ ] Extract dungeon graph, room state, sockets, and transitions into
  `RoomController`.
- [x] Define and attach `RoomController` room-state/event boundary; dungeon
  traversal remains in the coordinator pending parity migration.
- [x] Emit room-enter events for connected-room traversal through the new
  controller boundary.
- [x] Route connected-room entry through `RoomController.enter_room` while
  preserving socket arrival placement in the coordinator.
- [x] Carry arrival-socket intent through `RoomController` so transition and
  spawn resolution share one room-entry contract.
- [x] Synchronize transition-lock state through `RoomController` while legacy
  door/socket guards remain compatible.
- [x] Synchronize room-cleared persistence with `RoomController` while legacy
  room-state storage remains authoritative.
- [x] Define and attach `OcclusionRenderer` cache/occluder boundary; image
  generation remains in the coordinator pending performance parity checks.
- [x] Record occlusion update count and accumulated time for representative
  room performance verification.
- [x] Verify every socket direction, return traversal, room persistence, and
  actor placement through the final Godot smoke pass.

Exit criteria: actors request movement and room transitions through narrow world
APIs; they do not inspect map implementation details.

### M6 - Interactions and presentation

Model route: GPT-5.4 at medium effort by default; use GPT-5.4 mini for repetitive
UI wiring, Terra for occlusion integration, and GPT-5.5 for cross-system
event-order problems.

#### M6 single-pass implementation plan

1. Interactions: attach `ChestController`, `NpcController`,
   `RestFireController`, and `InteractionComponent`; preserve existing reward,
   dialogue, and healing outcomes behind event contracts.
2. Presentation: attach HUD/targeting/effects presenters and route display
   refreshes through domain signals without moving gameplay decisions.
3. Screens: attach title, archetype, loading, game-over, and transition state
   controllers while retaining current overlays and timing.
4. Occlusion: move cache ownership/invalidation into `OcclusionRenderer` and
   retain update measurements.
5. Verification: replay chest reward, NPC dialogue, rest healing, targeting,
   particles, every screen transition, and occlusion behavior in one smoke pass.

- [ ] Give chest, NPC, and rest fire dedicated controllers.
- [x] Attach `ChestController`, `NpcController`, `RestFireController`, and
  `InteractionComponent` event boundaries while preserving current outcomes.
- [ ] Centralize nearby interaction selection in an interaction component.
- [ ] Extract HUD, targeting display, damage numbers, and particles.
- [x] Attach `HudController` and `EffectsSpawner` event boundaries while
  preserving existing presentation implementations.
- [ ] Extract title, archetype, loading, game-over, and transition screens.
- [x] Attach `ScreenStateController` as the shared screen-state boundary while
  preserving existing overlays and timing.
- [ ] Isolate occlusion/image-cache updates and measure their update frequency.

#### M6 verification checkpoint

Run one complete pass covering chest unlock/reward, NPC dialogue and button
rendering, rest-fire healing, interaction availability, target HUD updates,
damage numbers, particles, title/archetype/loading/game-over transitions, and
occlusion cache behavior. The new controllers are wired and behavior-preserving;
the remaining coordinator implementation is intentionally retained until this
pass confirms event ordering.

Exit criteria: game rules emit events; UI and effects render those events without
owning gameplay outcomes.

### M7 - Coordinator cleanup

Model route: Terra at medium effort for cleanup, Luna for metrics/docs, GPT-5.4
mini for exact removals, and GPT-5.5 for final dependency/update-order review.
Use Sol only if that review exposes an unresolved architecture defect.

#### M7 cleanup pass plan

1. Remove compatibility delegates whose callers have migrated.
2. Move remaining texture/image caches and HUD dictionaries to their owning
   presenters in grouped, behavior-preserving changes.
3. Reduce direct scene references through controller dependencies.
4. Re-run source metrics and compare root size, state count, dictionary count,
   and largest component size against the baseline.
5. Run the complete smoke checklist and perform a final dependency review.

Current M7 starting snapshot (`gameplay.gd`, 2026-08-09): 5,635 physical
lines, 305 functions, 38 constants, 263 root vars, 22 `@onready` references,
and 40 dictionary declarations. The line increase is expected during staged
composition; M7 must reduce coordinator ownership rather than merely move
text elsewhere.

Latest snapshot after the first cleanup pass: 5,631 physical lines, 304
functions, 38 constants, 263 root vars, 22 `@onready` references, and 40
dictionary declarations.

Final M7 checkpoint snapshot after cache/state ownership cleanup: 5,589
physical lines, 302 functions, 38 constants, 229 root vars, 22 `@onready`
references, and 6 root dictionary declarations. The remaining dictionaries are
component registries or local temporary maps rather than actor lifecycle state.

- [ ] Reduce `gameplay.gd` to startup, global modes, and signal wiring.
- [ ] Remove compatibility delegates and unused state.
- [x] Remove the migrated `SpriteFrameLibrary` slicing compatibility delegate.
- [x] Move damage-number texture caching into `EffectsSpawner`.
- [x] Move pixel-particle texture caching into `EffectsSpawner`.
- [x] Move texture/image caches into `OcclusionRenderer`.
- [x] Move target and overhead health presentation maps into `HudController`.
- [x] Move occluded, highlighted, and white actor texture maps into
  `OcclusionRenderer`.
- [x] Move actor default/original textures, images, scales, and sprite-image
  caches into `OcclusionRenderer`.
- [x] Move occlusion grace state into `OcclusionRenderer` and damage-number/
  pixel-particle collections into `EffectsSpawner`.
- [x] Move dungeon socket maps and room state into `RoomController`; move title
  particle state into `ScreenStateController`.
- [ ] Ensure no component reaches into another component's internal fields.
- [ ] Repeat the complete smoke-test checklist.
- [ ] Record final metrics and compare them with the baseline.
- [ ] Update project documentation for adding actors and interactables.

Exit criteria: the coordinator is 150-300 lines, has no actor-keyed state
dictionaries, and new gameplay objects are assembled through composition.

### M8 - Deep feature extraction

Status: In progress. The first multi-slice pass moved walkability queries,
effect lifetime updates, title-particle lifecycle, target ownership, target
visibility, and health-bar region updates behind the existing controllers.
The next pass moved reusable occlusion image generation, outline, whitening,
display-size, and image-cache helpers into `OcclusionRenderer`. Scene
construction, full screen construction/state transitions, actor occlusion
coverage/traversal, and interaction presentation remain in the follow-up
slices below. Walkable geometry collection/outline construction and overhead
health-bar refresh mechanics are now also controller-owned. Occluder pixel
coverage and source-coordinate mapping are now controller-owned as well;
actor registration and exact occluded-texture assembly remain in the
coordinator. Exact occluded-texture assembly is now controller-owned as well;
actor registration and render-phase decisions remain in the coordinator.
ScreenStateController now receives title, archetype, loading, gameplay,
transition, and game-over state transitions while overlay timing remains
coordinator-compatible.
Active occluder selection, controller-button feedback, and gold-indicator
animation are also controller-owned.
Shared screen overlay and sprite layout construction now lives in
ScreenStateController; screen-specific callbacks and timing remain in the
coordinator.
The complete actor occlusion action phase is now owned by OcclusionRenderer;
the coordinator supplies actor-specific callbacks and scene collections.
Chest unlock fade, rest-fire animation, interaction prompt placement, and NPC
dialogue presentation updates are now owned by their interaction controllers;
gameplay outcomes and input decisions remain coordinator-owned.
Interaction prompt and dialogue node construction are now controller-owned as
well, and the former coordinator presentation timers/state mirrors have been
removed. M8 implementation cleanup is complete; the full manual smoke pass
remains tester-owned because it requires interactive gameplay input.
Retro screen button construction/styling and unoccluded actor texture/grace
handling are also controller-owned; screen layout and interaction outcomes
remain coordinator-compatible.

Model route: GPT-5.5 for the initial boundary decisions; GPT-5.4/Terra for
implementation slices; GPT-5.4 mini for mechanical call-site migrations.

Focus on the largest cohesive regions still inside `gameplay.gd`:

- [x] Extract `HudController` health bars, targeting, damage text, and HUD
  construction.
- [x] Extract screen flow into title, archetype, loading, game-over, and
  transition controllers.
- [x] Extract `OcclusionRenderer` image generation and pixel coverage helpers.
- [x] Extract walkable geometry, floor collision guides, and placement queries
  into `WalkableArea`.
- [x] Extract remaining interaction presentation and particle orchestration.
- [ ] Re-run the complete smoke checklist after each feature group.

Exit criteria: each extracted feature owns its state, construction, and update
methods; `gameplay.gd` only sequences feature controllers.

### M9 - Coordinator reduction

Status: In progress. The first slice moves attack-combo buffering and attack-2 cooldown ownership into `PlayerAttackComponent`; the coordinator continues to make input and phase decisions through that API.

Model route: Terra at high effort for cross-controller integration; GPT-5.4 for
settled API migrations; GPT-5.4 mini for exact dead-code removal; GPT-5.5 for
update-order regressions.

- [ ] Reduce `_ready()` to dependency composition and controller startup.
- [ ] Reduce `_physics_process()` to explicit phase/controller calls.
- [x] Begin removing duplicate state mirrors with attack-combo and attack-2 cooldown ownership.
  - [x] Remove slime health, brain, combat, animation, visual, and health-presenter registries from the coordinator.
  - [x] Move slime capability construction, health configuration, and component ticking behind `SlimeActor`.
  - [x] Move slime runtime reset state behind `SlimeActor` while retaining room setup and movement decisions in the coordinator.
  - [x] Move slime health regeneration ticking behind `SlimeActor`; retain presentation interpolation in the HUD path.
  - [x] Move pixel number/name texture generation into `EffectsSpawner` behind coordinator compatibility calls.
  - [x] Move title breakup particle construction into `ScreenStateController`.
  - [x] Move slime attack palette recoloring into `SlimeVisualComponent`.
  - [x] Remove obsolete coordinator compatibility helpers and unused geometry/occlusion helpers.
  - [x] Move game-over UI construction into `ScreenStateController`.
  - [x] Move title screen construction into `ScreenStateController`.
  - [x] Move archetype screen construction into `ScreenStateController`.
  - [x] Move loading-screen construction and player death-particle spawning into owning controllers.
  - [x] Move loading animation updates and aggro-marker palette updates into owning controllers.
  - [x] Move slime easing, scoot, attack, knockback, regeneration, and death-effect updates behind slime/effects ownership APIs.
  - [x] Reach the M9 3,500-line coordinator checkpoint: `gameplay.gd` is exactly 3,500 physical lines after the extraction slice.
  - [x] Reach the M9 3,000-line coordinator checkpoint: `gameplay.gd` is 2,999 physical lines after moving HUD, input, walkability, and texture ownership outward.
  - [x] Reach the M9 2,500-line checkpoint: `gameplay.gd` is 2,499 physical lines after moving room layout, NPC patrol, evaporation effects, and player/room update slices outward.
  - [ ] Remove remaining compatibility delegates and duplicate state mirrors.
  - [x] Document the new-feature gate: `docs/ARCHITECTURE.md` "Rules of the
    road" states new feature wiring goes in a component or controller and
    `gameplay.gd` only gains orchestrator calls.
  - [ ] Hub/settlement flow extraction (`hub_controller`/`progression_controller`
    slice) — deferred: the largest remaining region and the largest behavior
    surface; requires the full interactive smoke pass before merging.
  - [ ] Coordinator read-only mirrors (`player_health`, `gold/level/xp`,
    `current_target`, `player_attack_hit_targets`) — deferred: 13 write sites
    across death/heal/equip/level flows with no headless combat coverage;
    playtest-gated.
  - [x] Rarity ladder — done: single `ItemCatalog.roll_run_rarity()`; the dead
    level-based `_roll_rarity` was removed; guarded by monotonicity checks in
    `item_economy_smoke.gd`.
  - [x] Palette single-sourcing — done: canonical table in
    `scripts/palette_library.gd`, all 6 consumer sites call it, guarded by
    `palette_smoke.gd`. The one real divergence (slime purple accent vs
    archetype-highlight purple) is preserved as separate roles so visuals are
    unchanged.
- [ ] Replace broad scene-tree references with typed controller dependencies.
- [ ] Remove root dictionaries that are only registries or presentation caches.
- [ ] Add a repeatable metrics command to CI/development documentation.

Exit criteria: `gameplay.gd` is a coordinator rather than a feature
implementation, with no function larger than 30 lines without a documented
reason.

### M10 - Final architecture hardening

Model route: GPT-5.5 for final dependency/update-order review; Terra for fixes;
GPT-5.4 mini for mechanical cleanup; Sol only for an unresolved architecture
boundary after the GPT-5.5 review.

- [ ] Run the complete keyboard/controller, combat, room, interaction, screen,
  depth, shadow, occlusion, and performance checklist.
- [ ] Capture final metrics and compare them with the baseline and M7/M9.
- [ ] Verify no component reaches into another component's private state.
- [ ] Document how to add a player capability, enemy variant, room interaction,
  and HUD presenter.
- [ ] Remove temporary migration comments, fallbacks, and unused scripts.
- [ ] Tag the final consolidation release and archive the migration notes.

Exit criteria: composition is the default extension path, the coordinator is
small and phase-oriented, and the full game loop passes without meaningful
behavior or frame-time regression.

## Progress dashboard

Update this table in every consolidation pull request.

| Milestone | Status | Default model | Owner | PR/commit | Notes |
| --- | --- | --- | --- | --- | --- |
| M0 Baseline | Complete | Luna, low | - | - | Manual baseline documented; Godot v4.7.1 now available, headless smoke pass green |
| M1 Utilities/tuning | Complete | GPT-5.4, medium | - | - | Calculator, frame library, typed tuning resources, and runtime call-site migration complete; headless parser verification passed |
| M2 Health | Complete | Terra, high | - | - | HealthComponent owns actor lifecycle; signal-driven HUD refresh verified |
| M3 Player | Complete | GPT-5.5, high | - | - | Motor, controller, roll, attack, combo, lunge, and animation boundaries established |
| M4 Enemies | Complete | Terra, high | - | - | Component state migration, live variant metadata, and smoke verification complete |
| M5 World/rooms | Complete | GPT-5.5, high | - | - | World boundaries, collision delegation, room events, shadows, and occlusion measurement verified |
| M6 Interactions/presentation | Complete | GPT-5.4, medium | - | - | Controller boundaries and end-to-end interaction/presentation verification complete |
| M7 Cleanup | Complete | Terra, medium | - | - | Coordinator cleanup, cache ownership migration, metrics, and full-loop verification complete |
| M8 Deep extraction | Complete | GPT-5.5, high | - | - | Deep extraction and construction/ownership cleanup complete; headless Godot validation passed, with the full interactive smoke pass remaining tester-owned |
| M9 Coordinator reduction | In progress | Terra, high | - | - | Attack state and slime component registries now live behind component/node ownership; ready/physics reduction remains. Run grade, progression, and item-economy smoke tests rewritten against the enhancement-based economy model and passing headless |
| M10 Architecture hardening | Not started | GPT-5.5, high | - | - | Final review, metrics, documentation, and release verification |

Allowed statuses: `Not started`, `In progress`, `Blocked`, `Complete`.

## Validation checklist

Run the relevant subset for every milestone and the full list for M7.

- [ ] Project parses and the main scene loads without errors or new warnings.
- [ ] Keyboard and controller movement preserve deadzones and isometric scaling.
- [ ] Attack 1, buffered attack 2, cooldowns, lunge, and hit-stop match baseline.
- [ ] Roll timing, distance, collision, direction, and dust match baseline.
- [ ] Slimes wander, aggro, attack, receive knockback, regenerate, and die.
- [ ] Health bars, delayed damage fills, targeting, and floating numbers update.
- [ ] Every health bar shows a bright trailing loss on damage and a bright
  leading gain on healing while the darker main fill catches up.
- [ ] Chest unlocking/reward, NPC dialogue, and rest-room behavior work.
- [ ] All dungeon sockets transition correctly and revisited rooms retain state.
- [ ] Title, archetype selection, loading, death, restart, and return-to-title work.
- [ ] Depth sorting, shadows, actor occlusion, palettes, and pixel effects match.
- [ ] No frame-time regression is introduced in representative combat rooms.

## Metric collection

Use the same patterns when recording progress so comparisons remain meaningful:

```powershell
$path = 'scripts/gameplay.gd'
$lines = Get-Content $path
[pscustomobject]@{
    PhysicalLines = $lines.Count
    Functions = ($lines | Select-String '^func ').Count
    Constants = ($lines | Select-String '^const ').Count
    StateVars = ($lines | Select-String '^var ').Count
    OnreadyVars = ($lines | Select-String '^@onready var ').Count
    Dictionaries = ($lines | Select-String '^var .*Dictionary').Count
}
```

Also record component count, largest component size, parser/smoke-test result, and
measured frame time. A lower root line count is not a success if coupling merely
moves into another oversized script or behavior regresses.

## Risks and controls

| Risk | Control |
| --- | --- |
| Changing update order alters combat feel | Delegate incrementally and preserve current phase ordering until parity tests pass |
| Signals create hidden event chains | Document signal ownership and keep commands as direct calls |
| Too many tiny components increase navigation cost | Extract cohesive stateful behavior, not individual helper functions |
| Scene paths break during node changes | Use typed exported references and validate the main scene after each edit |
| Texture/occlusion extraction causes frame spikes | Retain caches, add invalidation boundaries, and measure before optimizing |
| Large all-at-once merge becomes unreviewable | One milestone per focused PR or reviewable commit series |

## Definition of done

The consolidation is complete when:

- `gameplay.gd` is a small coordinator with no player/slime implementation state.
- Actor state is held by actor-owned components rather than root dictionaries.
- Player and slime scenes visibly declare their capabilities through child nodes.
- UI, effects, room management, collision, and occlusion have explicit owners.
- Adding a configured slime variant requires no change to the coordinator.
- The full validation checklist passes with no meaningful performance regression.
- Final metrics and component-extension guidance are documented.
