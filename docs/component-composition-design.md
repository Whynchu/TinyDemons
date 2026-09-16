# Tiny Demons — Component Composition Design

Status: active plan (approved direction)

Scope: reusable, interchangeable entity components; the component contract, wiring
rules, factory/definition boundary, and the interchangeability proof

Owner: repository architecture and gameplay systems

Current code: `gameplay_bootstrap.gd`, the 20 `*Component` classes under
`scripts/`, `slime_actor.gd`, `slime_runtime_controller.gd`,
`actor_motor.gd`, `actor_geometry.gd`, `health_component.gd`, tuning resources
under `resources/tuning/`, and the typed room/menu contexts established by the
composition refactor

Verification: focused characterization tests first, then the manifest-driven
runner; the interchangeability proof must pass its pinned acceptance bar below
without any `GameplayState` edit

Supersedes: none; this plan extends the T2 track of
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md)
and the completed legacy-coupling record in
[`composition-refactor-analysis.md`](composition-refactor-analysis.md)

Updated: 2026-09-16

## Purpose

Tiny Demons wants entity behavior to work in a highly modular way: add a
component, and have that component usable across several entities
interchangeably. The goal is not a rewrite and not an ECS engine. The goal is a
disciplined component contract plus a definition/factory boundary so that
adding a feature (a new enemy, a shared behavior, a new pickup) no longer
requires editing a central state bag or a large coordinator.

The repository already has physical composition: 20 `*Component` classes are
attached as child nodes of the player and slimes by `GameplayBootstrap`. What it
lacks is contract composition. Measured on 2026-09-16, several components still
reach through the shared root at runtime, and there is no data layer or factory,
so nothing is genuinely interchangeable yet.

## Component contract

A component is compositional when all of these hold:

1. **It is blind.** It does not know its parent entity, its siblings, or the
   composition root. It never calls `get_parent()`, `get_node()`, or
   `root.call/get/set` to discover dependencies. Its required inputs arrive as
   `@export` configuration, direct typed references, or a narrow context passed
   by the entity/factory.
2. **One responsibility.** A component named `HealthAndShieldAndRegenComponent`
   is a failure. Split it.
3. **State lives inside.** The component owns the mutable state for its
   responsibility. Authority to change its state does not live in the
   coordinator.
4. **It signals up and lets the owner call down.** The component emits typed
   signals (`damaged`, `died`, `state_changed`) for anything that happened. It
   exposes commands (`apply_damage`, `begin_attack`) for things someone asks it
   to do. It does not call sibling methods directly.
5. **It works without knowing what it is attached to.** `HealthComponent` on a
   player, a slime, a chest, or an NPC must behave identically. The entity
   configures it and reacts to its signals.
6. **Config is data, not code.** Tuning arrives as `@export` values or a typed
   tuning resource, never as hardcoded branches on entity identity.

A component that fails rules 1 or 5 is a **component-shaped adapter**: it is
physically a child node but architecturally still service-locator code. It must
be refined through its owning slice, not treated as proof of composition.

### The clean reference: `HealthComponent`

`health_component.gd` is the current reference for the contract:

- `extends Node`, attached as a child; `@export` for `maximum_health`,
  `regen_delay`, `regen_interval`, `regen_amount`;
- owns `current_health`, timers, and `_dead` internally;
- emits `health_changed`, `damaged`, `healed`, `died`;
- exposes `reset`, `set_maximum_health`, `apply_damage`, `apply_healing`,
  `tick_regeneration`, `is_dead`;
- zero `root.call/get/set` sites.

`SlimeCombatComponent`, `SlimeAnimationComponent`, `SlimeBrain`,
`CombatMomentumComponent`, `EnemyTacticsComponent`, `StatsComponent`, and
`EquipmentComponent` also meet the contract.

### Adapters to refine (measured 2026-09-16)

These are component-named but still reach through the root:

| Script | root sites | Refinement note |
|---|---:|---|
| `player_animation_component.gd` | 86 | `root._play_sound`, palette/HUD coordination |
| `player_equipment_visual_component.gd` | 65 | presentation side effects on `root` |
| `player_roll_component.gd` | 52 | movement/dust coordination |
| `interaction_component.gd` | 37 | prompt targeting |
| `player_guard_component.gd` | 23 | flash/block feedback |
| `boss_jump_slam_component.gd` | 22 | boss presentation |

`slime_runtime_controller.gd` (805 lines, 195 root sites) is not a component; it
is the enemy runtime controller that drives the clean slime components through
the root. It is the largest single enforcement problem for this design: the
reusable slime behavior exists, but every consumer discovers it through the
state bag.

## Wiring rules

The composition root (`GameplayBootstrap`) and the entity/factory own wiring.
Components never wire themselves to each other.

- **Call down:** the entity or factory asks a component to do something through
  its typed command API.
- **Signal up:** the component reports what happened through typed signals.
- **Narrow contexts, not the root:** when a component needs more than its own
  state, it receives a narrow typed context (the pattern already proven by
  `RoomSpawnContext`, `MenuPlayerContext`, `ChestRewardContext`) or direct typed
  references to the few collaborators it actually uses.
- **No `initialize(root)`.** An `initialize(root)` method that receives
  `GameplayState` is a code smell under this design; replace it with `configure`
  calls that take typed values and direct references.
- **Signals are for events, not for every call.** Do not turn every method into
  a signal. Commands stay as methods; results of commands can be returned or
  surfaced as signals.

## Definition and factory boundary (T2)

The interchangeability goal depends on a data layer. A component becomes
reusable in practice when an entity can be assembled from a definition rather
than hand-written bootstrap steps.

Target relationship:

```text
EnemyDefinition (Resource)                ItemDefinition (Resource)
      │                                        │
      ▼                                        ▼
EnemyFactory / RoomFactory ──► entity scene + child components
      │                                         │
      └── wires components: typed refs, signals, narrow contexts (NO root)
components stay blind:  health, combat, movement, palette, drop
      │  signal up
      ▼
typed owners / controllers consume signals (room, profile, hud)
```

Terminology is pinned in `docs/ARCHITECTURE.md` and the long-term plan:
Definition (authored immutable data), Factory (builds a runtime composition from
definitions), Component (local behavior/state), Controller (bounded feature
workflow), Catalog (validated lookup).

## Interchangeability proof — Slice B (first gate)

Start with the clean slime components and one existing variant so behavior is
preserved. The proof:

1. Define a typed `EnemyDefinition` content contract and stable ID.
2. Move one existing slime variant's scene, tuning, geometry, visual, and
   behavior choices behind that contract.
3. Let an `EnemyFactory` assemble the existing actor/components.
4. Migrate one encounter path to request the definition by ID.
5. Mount the reusable components (`HealthComponent`, `SlimeCombatComponent`,
   `SlimeAnimationComponent`, `SlimeVisualComponent`) on a **second distinct
   entity** through the same factory.

## Completion measurement

The editor-composition percentage is produced by
`tools/validate_composition.ps1` (printed as `editor compos.`), alongside the
legacy-coupling score. It is the real representation of "pieces given direct
access and changeable in the editor." A piece counts toward completion only when
it passes **both** gates:

- **Gate A — Direct access:** the component is blind (zero `root.call/get/set`
  reach-ins) or the definition surface is reached by a typed reference, narrow
  context, or signal.
- **Gate B — Editor-changeable:** its config/data lives in `@export` fields, a
  tuning `.tres`, or a typed `Resource` — not a hardcoded `const` dictionary or
  an identity branch in code.

The weighted composite is a blend of four measured sub-metrics:

| Sub-metric | Formula | Weight | 2026-09-16 start | after slice 1 | after slice 2 |
|---|---|---:|---:|---:|---:|
| Component direct access | blind components / total components | 20% | 13/20 = 65% | 13/20 = 65% | 13/20 = 65% |
| Component editor-config | `@export`-configured / total components | 30% | 3/20 = 15% | 5/20 = 25% | 11/20 = 55% |
| Both-gate components | blind AND editor-configured / total | 25% | 3/20 = 15% | 5/20 = 25% | 11/20 = 55% |
| Definition editor-ability | editor-able surfaces / total definition surfaces | 25% | 6/17 ≈ 35% | 6/17 ≈ 35% | 6/17 ≈ 35% |
| **Composite** | weighted blend | | **≈ 30.1%** | **≈ 35.6%** | **≈ 52.1%** |

Slice 1 (2026-09-16) promoted two already-blind components to editor-configured:
`SlimeCombatComponent` gained `@export var regular_attack_lunge_duration` (replacing a
hardcoded `0.12`), and `PlayerAspectAbilityComponent` gained
`@export var default_elemental_cooldown` / `@export var default_grey_cooldown`
(used when the caller passes no explicit value). Defaults match prior behavior;
`typed_combat_path_smoke` and `enemy_room_engagement_smoke` pass unchanged, and
the headless import scan is clean.

Slice 2 (2026-09-16) cleared the 50% milestone (composite **≈ 52.1%**). Six more
already-blind components became editor-configured, each with behavior-identical
defaults and external class-const consumers migrated to instance reads:

- `SlimeSpawnComponent`: `@export var default_frame_time`, used by `begin()` when
  the caller passes no explicit duration.
- `SlimeAmbushComponent`: `@export` defaults for reveal window, block stun, hit
  extension, and hidden modulate, used when `configure()` omits them.
- `EquipmentTransmutationComponent`: six transmutation tuning consts converted to
  `@export` vars (bastion charges/knockback/durability, duelist multipliers,
  blood-feed life steal). StringName core IDs stay consts.
- `EquipmentComponent`: default loadout names (`BASIC SWORD` etc.) converted to
  `@export` and consumed by `_reset_runtime_state()`.
- `PlayerAttackComponent`: sword-beam cost/cooldown and spin hitstun converted to
  `@export` vars; `hud_controller.gd` and `effects_spawner.gd` now read the
  instance values.
- `PlayerChromaComponent`: max chroma, pickup value, and elemental ability cost
  converted to `@export` vars; HUD/status card denominators migrated to
  `MenuPlayerContext.max_chroma()` (new typed accessor) and instance reads in
  `screen_state_controller.gd` and `gameplay_state.gd`.

Verification for slice 2: headless import scan clean (exit 0);
`typed_combat_path_smoke`, `pause_menu_scene_smoke`, `chroma_pickup_smoke`,
`chroma_projectile_scene_smoke`, `chroma_state_smoke`, `item_economy_smoke`,
and `rogue_slime_smoke` all pass; `chroma_state_smoke.gd` was updated to read the
instance `elemental_ability_cost` instead of the retired class const. Baseline
re-locked at 52.1% via `-UpdateBaseline`.

Definition surfaces are counted by file: `item_catalog.gd`, `element_catalog.gd`,
`slime_variant_catalog.gd`, `palette_library.gd`, `dungeon_layout_definition.gd`,
the Run 1–6 builders, and the six tuning `.tres` resources under
`resources/tuning/` (the six `.tres` files are the only editor-able surfaces
today). The metric is low because the editor-changeable half has barely started;
it climbs only when a piece actually becomes both direct and editable.

The validator regression-guards the four sub-metrics against
`tools/composition-baseline.json` (`editor_composition` record). Run
`-UpdateBaseline` after a reviewed slice improves a sub-metric so the floor moves
up with it; the guarded floor is the current accepted state, so a future change
cannot silently undo an editor-composition gain.

### Slice B acceptance bar

- the enemy definition is a `Resource` subclass (or equivalent validated,
  serializable contract) the editor can inspect, not a `const` dictionary;
- the migrated variant's scene, tuning, geometry, visual, and behavior are all
  driven by the definition, not by hand-written `GameplayState` branches;
- `EnemyFactory` assembles the actor/components from the definition;
- adding a **second** variant requires: one new definition resource, one
  catalog row, and **no `GameplayState` edit** — nothing else;
- the reusable components used by the second entity contain **zero new
  `root.call/get/set` sites** and no parent/identity branches;
- focused tests cover the new variant and a save/load round-trip of any
  definition-derived runtime state.

If the second variant cannot be added with ≤1 definition/catalog change and
zero `GameplayState` edits, the slice is not complete. A passing test alone does
not complete the slice.

## Component adoption sequence

1. **[x] `HealthComponent`/clean-component editor promotion.** Slice 1 exposed
   editor-facing `@export` defaults on two blind components; slice 2 promoted six
   more and migrated their external class-const consumers to instance reads.
   Composite is at **52.1%**; the component-editor and both-gate sub-metrics are
   now 55%, so the next component lever is the four remaining blind components
   (`combat_momentum` is RefCounted, `slime_animation` has no knobs, and the
   non-blind adapters need root-refinement first).
2. **`EnemyDefinition` + `EnemyFactory` slice (Slice B above)** for one slime
   variant and a second entity sharing its components. This is the slice that
   moves the **definition editor-ability** sub-metric (currently the biggest
   remaining gap at 35%), by converting one authored definition surface from a
   code dictionary into an editor-inspectable `Resource`.
3. **Refine the adapters vertically** one at a time, replacing `initialize(root)`
   and root reach-ins with typed config/direct references:
   `interaction_component`, `player_roll_component`, `player_guard_component`,
   then `player_animation_component` and `player_equipment_visual_component`
   (these two are the largest and should be last).
4. **Replace `SlimeRuntimeController` root mediation** with typed slime runtime
   contexts, so enemy behavior is discovered through narrow dependencies rather
   than the state bag.
5. **Extend the same contract** to items, elements, rewards, and effects via the
   definition/catalog pattern.

Each step keeps the explicit frame schedule and moves one complete
responsibility with its state and tests. Do not split a file solely because its
line count is large; characterize the boundary first.

## Rules and guardrails

- Preserve the explicit frame schedule; do not add independent `_process()`
  loops just to avoid wiring a component into the scheduler.
- Prefer a direct typed reference over a new reflective call.
- Prefer a narrow context over a universal runtime context.
- Never add `GameplayState` as a field or constructor dependency to a component
  intended to be reusable.
- Keep state with the owner that has the authority to change it.
- Use signals for events, not as a replacement for every function call.
- Do not mix gameplay balance changes into ownership migrations.
- Add characterization coverage before moving behavior; replace or consolidate
  an existing test when the verification-surface audit freeze is active.
- A feature is a successful architecture proof only when a second piece of the
  same kind can be added with less central code, not merely when the first piece
  was moved into a new file.
- Stable IDs and save migrations take priority over changing the storage format.

## Verification

- Composition guardrail: `tools/validate_composition.ps1` (regression floor and
  `-RequireTargets` both pass at `0.2.24`).
- Manifest validator: `tools/validate_test_manifest.ps1`.
- Focused characterization for each component slice before moving behavior.
- The Slice B acceptance bar above is the gate for the content-composition
  track; record each step in `KNOWN_ISSUES.md` and this document.
- No new test file is added while the verification-surface freeze is active;
  existing owner checks are consolidated instead.

## Handoff checklist

Before declaring a component slice complete, record:

- the owner and state authority;
- the typed signals and direct dependencies involved;
- the root-access reduction (before/after counts);
- characterization and integration test results (named tests, not "the suite");
- any manual/native/browser evidence still outstanding; and
- the next smallest slice.