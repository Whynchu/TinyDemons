# Gameplay Script Consolidation Plan

Status: proposed

Branch: `agent/script-consolidation`

Baseline commit: `15a2832`

Audit date: 2026-08-09

## Purpose

`tiny-demons/scripts/gameplay.gd` currently owns most runtime behavior for the
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
guidance](https://developers.openai.com/api/docs/models), which positions GPT-5.6
Luna for cost-sensitive high-volume work, GPT-5.6 Terra for balancing capability
and cost, and GPT-5.6 Sol for complex reasoning and coding. Recheck that page if
the plan is executed after the audit date because model availability can change.

The model is selected by risk, not by milestone size. Use the lowest tier that
can safely own the decision being made.

| Tier | Model and effort | Appropriate work | Do not assign |
| --- | --- | --- | --- |
| Mechanical | `gpt-5.6-luna`, low | Metrics, documentation, formatting, repetitive resource population, known renames, checklist execution | Architecture, state ownership, timing-sensitive behavior |
| Implementation | `gpt-5.6-terra`, medium by default; high for coupled state | Focused component extraction, typed APIs, signal wiring, tests, scene edits with established boundaries | Unresolved cross-system architecture or subtle global update-order changes |
| Architecture | `gpt-5.6-sol`, high | Boundary design, interleaved state machines, collision/room transitions, difficult regressions, final architecture review | Bulk mechanical edits that Luna or Terra can perform |

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
4. Escalate Luna to Terra when the task requires choosing ownership, changing a
   signal/API contract, or diagnosing a failed behavior check.
5. Escalate Terra to Sol when work crosses three or more systems, changes global
   update order, exposes circular dependencies, or fails the same acceptance
   check twice for a non-mechanical reason.
6. After Sol resolves the design decision, return implementation and repetitive
   follow-up work to Terra or Luna with the decision recorded in this document.

### Milestone model assignments

| Milestone | Default | Use the cheaper tier for | Escalate when |
| --- | --- | --- | --- |
| M0 Baseline/safeguards | Luna, low | Metrics, smoke-check transcription, documentation | Terra, medium, if building a test harness or diagnosing inconsistent baseline behavior |
| M1 Utilities/tuning | Terra, medium | Luna, low, for approved constant/resource moves and formatting | Sol, high, only if extraction reveals an unresolved shared cache or ownership boundary |
| M2 Health | Terra, high | Luna, low, for adding established component nodes/resources after the first actor works | Sol, high, if death, regeneration, room reset, and UI ownership cannot be separated cleanly |
| M3 Player | Sol, high | Terra, medium, for implementing isolated components after contracts and update phases are decided | Sol, xhigh, only for an unresolved combo/roll/hit-stop ordering regression |
| M4 Enemies | Terra, high | Luna, low, for creating slime variants from an approved scene/resource template | Sol, high, if removing dictionaries changes multi-enemy ordering, targeting, or collision behavior |
| M5 World/rooms | Sol, high | Terra, medium, for implementing a settled world-service API | Sol, xhigh, only for an unresolved collision, socket traversal, or persistence defect |
| M6 Interactions/presentation | Terra, medium | Luna, low, for repetitive UI hookups and resource moves | Sol, high, for occlusion performance/design or event-order regressions spanning gameplay and UI |
| M7 Cleanup | Terra, medium | Luna, low, for metrics, dead-code inventory, and documentation updates | Sol, high, for the final dependency/update-order review or a cross-system regression |

## Migration roadmap

Each milestone must leave the game runnable. During migration, `gameplay.gd` may
temporarily delegate to new components before old fields and methods are removed.

### M0 - Baseline and safeguards

Model route: Luna at low effort by default; Terra at medium effort for harness
design or baseline diagnosis.

- [x] Record source metrics and responsibility map.
- [x] Preserve baseline commit on `main`.
- [x] Create a dedicated consolidation branch.
- [ ] Write a manual smoke-test checklist for the current playable loop.
- [ ] Capture expected room, combat, interaction, and death behavior.
- [ ] Add a headless scene-load/parser check if the Godot executable is
  available in development and CI environments.

Exit criteria: behavior checks are documented and can be repeated after every
milestone.

### M1 - Pure utilities and tuning data

Model route: Terra at medium effort for extraction; Luna at low effort after
resource schemas and move lists are approved.

- [ ] Extract `CombatCalculator` without changing damage results.
- [ ] Extract sprite slicing/flipping/recoloring into `SpriteFrameLibrary`.
- [ ] Introduce typed player, slime, combat, and effects tuning resources.
- [ ] Replace constants only after parity is verified.

Exit criteria: pure calculations and static asset preparation no longer depend
on the gameplay scene root.

### M2 - Health composition

Model route: Terra at high effort because lifecycle state crosses combat, UI,
death, regeneration, and room reset. Escalate boundary conflicts to Sol.

- [ ] Add `HealthComponent` to the player and each slime.
- [ ] Move health, maximum health, regen, and death state into the component.
- [ ] Connect health UI and effects using signals.
- [ ] Remove actor health, display-health, regen, and death dictionaries from
  `gameplay.gd`.
- [ ] Verify damage rolls, critical hits, regen delays, death, and room reset.

Exit criteria: each actor owns its health lifecycle; the root does not index
health state by actor.

### M3 - Player composition

Model route: Sol at high effort for the initial state/update-order design; route
isolated implementation slices back to Terra after contracts are fixed.

- [ ] Add `ActorMotor` and move normal movement/knockback behind its API.
- [ ] Extract player input/action coordination into `PlayerController`.
- [ ] Extract roll state and roll-dust event.
- [ ] Extract attack, combo buffering, lunge, hitbox, and hit tracking.
- [ ] Extract animation state and palette/frame application.
- [ ] Verify dialogue locks, hit-stop, combo timing, collision, and death.

Exit criteria: the root starts/stops player control but owns no player action
timers or animation frames.

### M4 - Enemy composition

Model route: Terra at high effort for the first reusable slime; Luna can create
later variants from the approved template. Escalate behavioral coupling to Sol.

- [ ] Create a reusable `slime.tscn` with exported visual/tuning resources.
- [ ] Move aggro, repath, scoot, hold, attack, hit reaction, and death state to
  slime components.
- [ ] Replace blue/green/red setup with configured scene instances.
- [ ] Remove all remaining slime-keyed behavior dictionaries.
- [ ] Verify multi-slime collision, targeting, room reset, and difficulty level.

Exit criteria: adding a slime variant requires a resource/scene configuration,
not new root-script state.

### M5 - World and room systems

Model route: Sol at high effort for collision, walkability, transition, and
persistence boundaries; Terra implements APIs after the design is settled.

- [ ] Extract walkable geometry and queries into `WalkableArea`.
- [ ] Extract actor contact/static collision into `ActorCollisionSystem`.
- [ ] Extract depth ordering and shadows.
- [ ] Extract dungeon graph, room state, sockets, and transitions into
  `RoomController`.
- [ ] Verify every socket direction, return traversal, room persistence, and
  actor placement.

Exit criteria: actors request movement and room transitions through narrow world
APIs; they do not inspect map implementation details.

### M6 - Interactions and presentation

Model route: Terra at medium effort by default; use Luna for repetitive UI
wiring and Sol only for cross-system occlusion or event-order problems.

- [ ] Give chest, NPC, and rest fire dedicated controllers.
- [ ] Centralize nearby interaction selection in an interaction component.
- [ ] Extract HUD, targeting display, damage numbers, and particles.
- [ ] Extract title, archetype, loading, game-over, and transition screens.
- [ ] Isolate occlusion/image-cache updates and measure their update frequency.

Exit criteria: game rules emit events; UI and effects render those events without
owning gameplay outcomes.

### M7 - Coordinator cleanup

Model route: Terra at medium effort for cleanup, Luna for metrics/docs, and Sol
at high effort for the final dependency and update-order review.

- [ ] Reduce `gameplay.gd` to startup, global modes, and signal wiring.
- [ ] Remove compatibility delegates and unused state.
- [ ] Ensure no component reaches into another component's internal fields.
- [ ] Repeat the complete smoke-test checklist.
- [ ] Record final metrics and compare them with the baseline.
- [ ] Update project documentation for adding actors and interactables.

Exit criteria: the coordinator is 150-300 lines, has no actor-keyed state
dictionaries, and new gameplay objects are assembled through composition.

## Progress dashboard

Update this table in every consolidation pull request.

| Milestone | Status | Default model | Owner | PR/commit | Notes |
| --- | --- | --- | --- | --- | --- |
| M0 Baseline | In progress | Luna, low | - | - | Audit complete; behavior safeguards remain |
| M1 Utilities/tuning | Not started | Terra, medium | - | - | |
| M2 Health | Not started | Terra, high | - | - | |
| M3 Player | Not started | Sol, high | - | - | |
| M4 Enemies | Not started | Terra, high | - | - | |
| M5 World/rooms | Not started | Sol, high | - | - | |
| M6 Interactions/presentation | Not started | Terra, medium | - | - | |
| M7 Cleanup | Not started | Terra, medium | - | - | Sol performs final architecture review |

Allowed statuses: `Not started`, `In progress`, `Blocked`, `Complete`.

## Validation checklist

Run the relevant subset for every milestone and the full list for M7.

- [ ] Project parses and the main scene loads without errors or new warnings.
- [ ] Keyboard and controller movement preserve deadzones and isometric scaling.
- [ ] Attack 1, buffered attack 2, cooldowns, lunge, and hit-stop match baseline.
- [ ] Roll timing, distance, collision, direction, and dust match baseline.
- [ ] Slimes wander, aggro, attack, receive knockback, regenerate, and die.
- [ ] Health bars, delayed damage fills, targeting, and floating numbers update.
- [ ] Chest unlocking/reward, NPC dialogue, and rest-room behavior work.
- [ ] All dungeon sockets transition correctly and revisited rooms retain state.
- [ ] Title, archetype selection, loading, death, restart, and return-to-title work.
- [ ] Depth sorting, shadows, actor occlusion, palettes, and pixel effects match.
- [ ] No frame-time regression is introduced in representative combat rooms.

## Metric collection

Use the same patterns when recording progress so comparisons remain meaningful:

```powershell
$path = 'tiny-demons/scripts/gameplay.gd'
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
