# Composition Root Reduction — R0 Inventory

Status: R0 baseline captured; ownership mapping ready for review

Date: 2026-08-22

Parent plan: [`composition-root-reduction-plan.md`](composition-root-reduction-plan.md)

## Baseline

The repository baseline is intentionally recorded before structural movement:

| Measure | Baseline |
| --- | ---: |
| `scripts/gameplay.gd` lines | 2,863 |
| `scripts/gameplay.gd` functions | 424 |
| `scripts/gameplay_state.gd` lines | 264 |
| `gameplay_state.gd` plain variables | 174 |
| Production `root.call(...)` seams | 512 |
| Production `root.get(...)` seams | 539 |
| Production `root.set(...)` seams | 183 |
| Smoke scripts | 18, including this baseline gate |
| Main-scene headless boot | Pass |

The R0 smoke gate is [`composition_root_baseline_smoke.gd`](../tests/composition_root_baseline_smoke.gd).
It prevents `gameplay.gd` from growing beyond 2,863 lines or 424 functions while
the migration is active and verifies that the explicit frame phase order remains
available.

The current full gate is the repository runner:

```powershell
powershell -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1
```

## Ownership inventory

This table describes the intended destination for the major regions currently
living in `gameplay.gd`. “Existing owner” means the destination already exists;
“new owner” means a bounded owner must be introduced before extraction.

| Current region | Intended owner | Destination type | R0 disposition |
| --- | --- | --- | --- |
| Runtime node creation and `_ready()` orchestration | `GameplayComposition` | New composition service | Keep behavior frozen; extract in R1 |
| Player component creation and capability wiring | Player scene / `PlayerAssembler` | Actor composition | Move out of root in R1 |
| Slime capability setup and runtime initialization | `SlimeActor` / `EncounterController` | Actor + domain controller | Move setup and signals in R1/R3 |
| Profile application, equipment, and health preservation | `ProfileRuntimeController` + equipment owner | Domain controller + actor components | Move in R2 |
| Hub equipment, fusion, salvage, and stat allocation | `HubProgressionController` | Domain controller | Move in R2 |
| Save selection and overwrite flow | `SaveSlotController` | Domain controller | Split from screen presentation in R2 |
| Run start, death outcome, completion, settlement, return | `RunFlowController` | Domain controller | Move in R2 |
| Chest item drops and world item collection | `LootDropController` | World controller | Move in R2 |
| Chroma pickup lifecycle | `ChromaPickupController` | Existing world controller | Finish extraction in R4 |
| Magic casting and projectile lifecycle | `PlayerAspectAbilityComponent` + `MagicProjectileController` | Actor component + world controller | Finish extraction in R4 |
| Player attack/combo completion and hit dispatch | `PlayerAttackComponent` + combat API | Actor component + typed service | Move in R3 |
| Slime movement, attack, lunge, knockback, death | `SlimeActor` + `EncounterController` | Actor + domain controller | Move in R3 |
| Damage and combat formula calls | `CombatCalculator` / combat boundary | Stateless service + typed API | Remove root wrappers in R3 |
| Room creation, sockets, doors, puzzle progression | `RoomController` + interaction owners | Existing domain controllers | Finish policy extraction in R4 |
| Chest, rest fire, NPC, and final exit interactions | Existing interaction controllers | Domain controllers | Move remaining policy in R4 |
| Input polling and action edge state | `InputRouter` | Existing service | Remove root polling wrappers in R1/R6 |
| Target selection and target HUD presentation | `TargetingController` + `HudController` | Domain/presentation controllers | Split policy from rendering in R5 |
| Player health, MP, target, and focus UI | `HudController` / presenters | Presentation owner | Remove coordinator update methods in R5 |
| Title, save, creation, hub, run-complete, loading, game-over UI | Split screen flow owners | Presentation/domain controllers | Do not enlarge `ScreenStateController`; split in R2/R5 |
| Occlusion, depth, shadows, palettes, flashes | Existing presentation owners | Presentation services | Remove compatibility wrappers in R5 |
| Effects and sound routing | `EffectsSpawner` + `SoundManager` | Presentation services | Remove root construction helpers in R5 |
| Walkability, collision, actor geometry | `WalkableArea`, `ActorCollisionSystem`, `ActorGeometry` | Existing services | Preserve; remove root delegates in R1/R6 |
| Music and global audio state | `SoundManager` | Presentation service | Move policy in R5 |

## Shared-state inventory

The remaining `gameplay_state.gd` fields must be classified by ownership before
they are moved. The categories below are the R0 map; no field is allowed to remain
in shared state merely because moving it is inconvenient.

| State category | Intended owner | Examples |
| --- | --- | --- |
| Actor references and capabilities | Actor scene/components | player, motor, attack, guard, Chroma, animation |
| Enemy roster and encounter state | `EncounterController` / `SlimeActor` | slimes, targetable actors, encounter progress |
| Room and dungeon state | `RoomController` / `DungeonGraph` | room id, sockets, doors, depth, milestones |
| Profile and durable progression | `PlayerProfile` / `ProfileSaveService` | gold, XP, level, inventory, starter flame |
| Run-local progression | `RunFlowController` / `RunState` | timer, grade, damage, completion, settlement |
| Hub draft edits | `HubProgressionController` / `HubProgressionDraft` | pending stats, fusion selection, respec state |
| Screen mode and cursors | Split screen flow owners | title, save slot, hub, run complete, dialogue modes |
| Presentation caches | HUD, effects, occlusion, sound owners | texture maps, damage numbers, particles, flashes |
| Input edges and context | `InputRouter` / mode owner | held/pressed/released state, context locks |
| World pickups and drops | `LootDropController` / `ChromaPickupController` | launch state, positions, collection state |
| Cross-domain session state | Minimal runtime session object | only values genuinely read by multiple owners |

## High-risk function groups

These groups are the first review targets because they combine multiple lifecycles
or contain policy that should not be delegated through the root:

1. `_ready()`, `_physics_process()`, and runtime construction. These define the
   composition boundary and must move only after R1 APIs exist.
2. Hub, save, equipment, fusion, salvage, and settlement functions. This is the
   largest mixed workflow and needs focused interactive characterization.
3. `GameplayFrameController.tick()`. It currently contains mode routing and nearly
   every simulation/presentation phase. It must be split after its typed owners are
   available, not merely moved wholesale.
4. Player and slime combat wrappers. These are behavior-sensitive and must preserve
   attack timing, hitstop, knockback, target selection, and boss geometry.
5. Remaining Chroma/projectile/pickup compatibility functions. These already have
   partial owners and should be among the safest early extractions after composition.
6. Screen construction and update helpers. `ScreenStateController` is already large;
   its next move must split lifecycles rather than absorb more root behavior.

## Extraction order

The proposed order is:

```text
R0 baseline and ownership map
  → R1 typed composition and actor assembly
  → R2 run/profile/hub/loot flow
  → R3 combat and encounter ownership
  → R4 Chroma/projectiles/interactions
  → R5 presentation and screen ownership
  → R6 typed frame scheduler and shared-state removal
  → R7 architecture hardening
```

This order is deliberate. Composition and typed dependencies must exist before
feature owners can stop reaching through the root. Run and hub flow is separated
before screen work so `ScreenStateController` does not become the new god object.
Combat moves after the actor component APIs are stable. Frame scheduling moves last
because it currently exposes every unresolved seam at once.

## R0 exit conditions

R0 is complete when:

- this inventory has been reviewed and any disputed owner is recorded;
- every `gameplay.gd` feature function has a destination or an explicit exception;
- every `gameplay_state.gd` variable has an owner category;
- the baseline smoke gate is registered and passing;
- the complete 18-script suite and main-scene boot pass;
- no behavior or balance changes have been mixed into the inventory checkpoint; and
- the next slice is limited to R1 typed composition.

R0 does not move runtime code. Its purpose is to make the next move reversible,
measurable, and ownership-led.
