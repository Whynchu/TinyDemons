# Tiny Demons — Elemental Status Implementation Plan

Status: bounded five-status implementation is in source; see
[`freeze-status-design.md`](freeze-status-design.md) for the later WATER + ICE
mixture. Focused runtime and rendering acceptance remain open. Balance values
are initial playtest defaults.

Scope: implement Fire Burn, Shadow Poison, Electric Shocked, and Ice Chill for the
player and combat actors. Statuses are selected from elemental effect data on
the existing elemental hit paths. This pass does not add a new ability delivery
system.

Owner: `ElementCatalogData` and `EnemyDefinition` for authored data;
`StatusComponent` for actor-local state; combat/frame owners for hit and tick
lifecycle; `HudController` and `ElementAuraComponent` for presentation. The
player equipment visual component delegates imbue overlays to the aura owner.

Verification target: registered status component/combat coverage, focused MCP
script diagnostics, definition/catalog validators, and a color playtest at
native 240×160 resolution. The new status and death visibility checks are
registered but have not been run. Keep the existing Godot process restriction
in `coord/status-codex.md`.

Supersedes: the status-specific sequence in
[`elemental-ability-and-status-system.md`](elemental-ability-and-status-system.md)
and its [decision addendum](elemental-ability-and-status-system-addendum.md).

## Current extension — 2026-10-03

The affinity/transmission implementation extends the original four-status slice
with Wet and innate enemy affinity. `StatusRecord` distinguishes applied and
innate records; elemental enemies receive their matching harmless record,
which applied ailments suppress for presentation and contact transfer. Wet
conducts Electric damage, accelerates Shocked cadence, removes up to three
applied Burn stacks, and uses the shared bubble texture. Contact transfer uses a
pre-separation contact snapshot, guaranteed status transfer subject to
immunity/special-defense gates, transmission provenance, and one three-second
cooldown per unordered actor pair. Ordinary elemental-hit proc rates are
unchanged.

`RunState` now saves a usually-two, sometimes-three element theme (20% three
chance at rank 3+; rank 1 Normal-only and rank 2 single-element teaching runs).
`RoomController` constrains room and boss rosters, and elemental support
variants all reuse the shared ally-healing behavior. Legacy active-run snapshots
select a deterministic theme from their cached rosters and remap out-of-theme
slots while retaining their runtime state. Focused smoke source has been updated
or added; it is registered but has not been executed. Native visual readability,
seed-sweep evidence, definition/catalog validation, and browser playtesting
remain open.
## Implementation checkpoint — 2026-09-28

The working tree now contains all four status definitions, catalog validation,
actor-local status components, player/enemy proc and tick paths, movement and
attack-speed slow, periodic stun, reset handling, HUD marks, and the shared aura extraction.
Status definitions select one of four particle styles: Burn reuses imbue's
upward ember trail, Poison uses rising motes, Shocked uses short electric sparks,
and Chill uses drifting frost crystals. The aura is a sibling overlay that
copies the actor sprite's global transform; AtlasTexture regions, Sprite2D
regions, and the displayed animation-sheet frame are cropped before outline
generation. Owner checks for status
behavior and delayed player-death visibility are registered in
`tests/manifest.csv`, but they have not been executed. The reported death
visibility path is guarded in the animation component, and death entry restores
the player sprite's white modulate before hiding it. `PlayerAnimationContext`
now carries the configured death-state callback, supplied by
`GameplayFrameController`. Runtime status-effect and death/cloak playtests
remain open.

The transient magenta rectangle remains unresolved. No capture was available,
and the source audit found no explicit magenta color assignment that identifies
its cause. Do not claim the rendering acceptance closed until it can be
reproduced and checked in a color playtest.

The overhead status-marker path had two lifetime defects: registration cast a
stored built-in Array to `Array[Sprite2D]`, and a marker freed with its actor
could remain in the cached array. The shared Array is now used directly and
invalid marker references are pruned before update or cast. The user also
reported status outlines appearing offset or oversized. The outline now mirrors
the actor's global transform as a sibling and crops AtlasTexture regions,
Sprite2D regions, and the active h/v animation-sheet frame before dilation.
Target highlight textures store pixels at double resolution while retaining
the base sprite's logical display size; generated status outlines now keep that
logical size plus their one-pixel border. The edge-particle source uses the same
visible frame. Runtime acceptance remains open.

| Slice | Source state | Evidence still open |
|---|---|---|
| S1 definitions/immunity | Typed status resources, catalog registration/validation, and enemy immunity IDs are present | Run catalog and definition validators |
| S2 actor-local state | `StatusComponent`, typed request/result, reset clearing, and owner checks are present | Run the registered component check and fixed-seed coverage |
| S3 combat/ticks/control | Player/enemy proc boundaries, DoT handling, Chill movement/attack slow, and periodic stun are wired | Run combat coverage and inspect lethal/off-screen cases |
| S4 presentation/render | HUD badge lifetime is guarded; status/imbue overlays share the aura owner; data-selected ember/mote/spark/crystal particles are wired; player-death visibility guard is wired | Readability and cloak/death playtest; check aura alignment; diagnose magenta artifact |
| S5 data/docs/hardening | Tuning, authoring, architecture, audit, and known-issue docs are updated | Run data-only proof and validators; complete runtime/web acceptance |

## 1. Completion criteria

1. One typed status definition per ailment, stored in the existing element
   catalog during the open M1 milestone; adding a status does not add a combat
   `if element == ...` branch.
2. Player and enemy elemental damage paths use one status-application contract.
   Status tick damage bypasses that contract, so it cannot trigger another
   status or ordinary hit feedback.
3. Status state belongs to the affected actor. Pooled enemies clear it on reset;
   player statuses clear on room entry and run reset.
4. Damage, death, movement slow, and interruption remain handled by their owning combat/runtime
   boundaries. No new `GameplayState` fields or `_process()` methods.
5. Status marks are distinguishable in the authored game palette at native
   resolution during a representative combat room with a full crowd and HUD.
6. Status outlines match the actor sprite's current frame, transform, and size;
   Burn, Poison, Shocked, and Chill each use their authored particle style.
7. The imbue visual remains aligned to its equipment sprites, and the reported
   transient magenta actor/hitbox rectangle is absent in the same playtest.

## 2. Status rules and initial tuning

Reapplication adds one magnitude stack up to the definition's cap and refreshes
the duration. It preserves the current tick/cadence phase. Status ticks never
call the ordinary damage entry point.

| Status | Initial chance | Active duration | Effect | Cap |
|---|---:|---:|---|---:|
| Fire Burn | 20% per eligible hit | 2.5 s | 1 damage per stack every 1 s | 3 |
| Shadow Poison | 20% per eligible hit | 2.5 s | 1 damage per stack every 1 s | 3 |
| Ice Chill | 20% per eligible hit | 2.0 s | 15% movement and attack-speed slow per stack | 3 |
| Electric Shocked | 10% per eligible hit | 2.5 s | immediate 0.2 s action lock on proc, then repeat locks every 1 s; each extra stack shortens repeat cadence by 0.05 s, floor 0.5 s | 3 |

All values live on typed status definitions and remain tuneable. The numbers are
starting values for playtesting, not a final balance sign-off.

Global rules:

- Only a successful, non-immune elemental hit can roll a status proc. Neutral
  damage and status tick damage do not proc statuses.
- `EnemyDefinition.status_immunities` can reject any status independently of
  element matchup. Matchup immunity also prevents application.
- Burn/Poison ticks may kill an actively engaged enemy while it is on-screen.
  If an enemy is not on-screen or the room has not engaged, lethal ticks hold it
  at 1 HP until it becomes eligible. Player DoT remains lethal.
- Shocked respects the existing boss stun-resistance flag.
- No gear-based status resistance in this pass. The five original element-owned
  statuses may coexist except for the separately authored Wet + Chill mixture,
  which consumes both to create Freeze.

## 3. Data and runtime contracts

- Add a typed `StatusEffectDefinition` with stable ID, element, family, proc
  chance, duration, stack cap, magnitude, tick/cadence settings, and icon mark.
- Register the five definitions through `ElementCatalogData`; keep the stable
  element enum and matchup policy in `element_catalog.gd`. This is the single
  bootstrap registry while M1 remains open. Do not create a parallel status
  lookup table.
- Add and validate `EnemyDefinition.status_immunities` against registered
  status IDs.
- Use a typed status application request containing target component, element,
  resolved effectiveness/immunity, and source kind. The existing `DamageResult`
  already owns effectiveness; preserve it through the damage boundary instead
  of trying to infer an ability payload that current attacks do not pass.
- `StatusComponent` owns active records `{id, remaining, stacks, source_element,
  tick_timer}` and exposes apply, clear, tick, active-state, movement-slow, and
  attack-speed queries. It does not apply health damage or call `GameplayState`.
- Combat/runtime owners consume typed tick results. Enemy ticks reuse the
  existing slime kill lifecycle; player ticks set the existing pending-death
  state. Tick damage shows the existing small damage number without hitstop,
  hit flash, knockback, or proc recursion.

## 4. Slices

### S1 — Definitions and immunity data

- Add status definitions to the existing element catalog and add
  `EnemyDefinition.status_immunities` validation.
- Resolve each element through catalog data, including the status mark and
  element color used by presentation.
- Verify the catalog and authored definitions with their existing validators.

### S2 — Actor-local status mechanism

- Add `StatusComponent` to the player and `SlimeActor` family, including
  skeleton-derived actors.
- Add the typed `StatusApplication` boundary and deterministic RNG input.
- Define refresh, cap, expiry, tick phase, status clear, and immunity behavior
  in the owner test before wiring live attacks.

### S3 — Combat, ticks, and controls

- Route player melee/magic hits and enemy melee/projectile/boss hits through the
  same status-application request after hit validation and guard resolution.
- Tick statuses from the existing frame schedule after the hitstop return, so
  player and enemy status clocks freeze consistently during hitstop.
- DoT uses a dedicated status tick result. The combat owner applies damage,
  regen delay, number feedback, screen/engagement lethality policy, and normal
  enemy/player death transitions.
- Ice Chill feeds player/enemy movement multipliers and slows player/enemy
  attack cadence and attack animation timing using the same stacked multiplier.
- Electric Shocked immediately cancels the active attack and briefly blocks
  movement/attacks on proc, then repeats on its stack-adjusted cadence. Enemy
  lock windows add a short sprite-only jolt; collision geometry does not move.
  It observes the boss resistance flag.

### S4 — Presentation and render fix

- Show a distinct small pixel mark for each active status in the element color;
  fit all five element-owned statuses plus the auxiliary Freeze condition
  without silently dropping one. The enemy mark
  is attached to the existing overhead-bar presentation; the player mark sits
  beside the existing player HUD.
- Use one `ElementAuraComponent` for status aura and imbue outline rendering.
  Preserve the existing sprite source, offset, horizontal flip, scale, z-order,
  nearest filtering, cache behavior, and imbue frame timing.
- Trace and fix the transient magenta actor/hitbox rectangle in the generated
  overlay/render path. Do not replace it with an unrelated debug visualization.
- Verify in color at 240×160 with the actual HUD and representative actors.

### S5 — Data proof, docs, and hardening

- Demonstrate that status data is resolved by catalog lookup and no runtime
  element branch is needed to add another status.
- Register focused component and combat cases in `tests/manifest.csv`.
- Update `GAMEPLAY_TUNING.md`, `SCRIPT_INDEX.md`, `ARCHITECTURE.md`, and the
  audit/known-issues record with actual consumers and evidence.
- Keep M1 authoring acceptance and rendered web/mobile acceptance separate from
  status code correctness; do not claim either closed without its evidence.

## 5. Required coverage

- Apply, reapply, stack cap, duration refresh, preserved tick phase, expiry,
  immunity, clear/reset, and fixed-seed proc determinism.
- DoT applies to enemy and player, cannot re-proc, does not trigger hitstop,
  uses normal death handling, and follows the on-screen/engaged lethal rule.
- Chill affects player and enemy movement and attack tempo, then expires cleanly.
- Stun's immediate proc lock, repeat cadence, stack reduction/floor, action
  interruption, sprite-only jolt, boss resistance, and expiry.
- Status marks add and remove for pooled actors and the player HUD.
- Imbue overlay alignment plus the magenta artifact report case.

## 6. Risks and verification limits

- Element-owned statuses and the auxiliary Freeze condition touch multiple
  combat boundaries. Keep status tick damage behind the typed result contract
  and keep initial tuning data-only.
- Passive stun can chain-interrupt fast enemies; playtest the conservative
  initial proc rate and cadence before raising either value.
- The current session must not launch another Godot process after the recorded
  startup stall/crash. Use connected-editor MCP diagnostics; leave runtime
  rendering and web playtest claims open until safe visual evidence is captured.
