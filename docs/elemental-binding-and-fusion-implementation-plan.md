# Tiny Demons — Elemental Binding and Flame Fusion Implementation Plan

Status: implemented core plan; final polish and future content remain open

Source of truth:

- [`elemental-binding-and-fusion-design.md`](elemental-binding-and-fusion-design.md)

This plan turns the Binding/Fusion design into ordered implementation slices.
It is intentionally separate from the existing elemental combat-matchup work
and from equipment fusion. The core contract below is now implemented; the
remaining questions in §7 are future tuning/content decisions, not blockers for
the current Swap/Fuse/Bind system.

## 1. Non-negotiable product contract

The implementation must preserve these rules:

1. The current element and bound element are separate values.
2. Flame Swap costs 5 Souls and changes only the current element.
3. Flame Fusion costs 5 Souls and does not require a bound element.
4. Fusion uses the current element plus the contacted flame's element.
5. Fusion results are current and usable immediately, but remain unbound.
6. Every permanent Bind happens at the Cloaked Demon and costs 50 Souls.
7. Binding the already-bound element is a free no-op.
8. A flame never writes the persistent bound element.
9. Elemental doors check current active element, including an unbound fusion
   result; required doors must not require the 50-Soul Bind fee.
10. A solved door remains solved and cannot re-lock because Chroma, current
    element, or Binding state changed later.
11. The existing one-use flame behavior remains explicit and non-passive.
12. Equipment fusion keeps its existing independent Soul-cost ladder.

## 2. Target state model

### 2.1 Profile state

Extend `PlayerProfile` with explicit durable identity:

```text
starter_flame: StringName       # file-creation/default flame
bound_element: StringName       # NONE until a successful Demon Bind
has_bound_element: bool         # explicit, migration-safe state
```

The flat 50-Soul cost does not require a bind-count field. If later design adds
unlock tiers or discounts, that should be a separate progression field rather
than inferred from the current element.

### 2.2 Run-time state

`PlayerChromaComponent` should distinguish:

```text
current_element: Element        # active run-time identity
current_chroma: int             # 0..100
bound_element: Element          # profile-backed persistent identity
```

The runtime may expose a derived state such as:

```text
is_current_bound := current_element == bound_element and has_bound_element
is_current_unbound := current_element != NONE and not is_current_bound
```

Do not encode Binding as only a Boolean. A Boolean cannot represent Water being
bound while an unbound Grass or Ice fusion is currently active.

### 2.3 Ownership boundaries

| Responsibility | Owner |
| --- | --- |
| Stable element IDs, display names, colors | `element_catalog.gd` / aspect data |
| Valid unordered fusion recipes | New `aspect_fusion_catalog.gd` or equivalent data resource |
| Current element, Chroma, zero-Chroma resolution | `PlayerChromaComponent` |
| Souls and bound-element persistence | `PlayerProfile` / profile controller |
| Flame interaction selection and routing | `RestFireController` / gameplay interaction boundary |
| Binding menu and confirmation | `NpcController` plus a dedicated menu/controller if needed |
| Triangle ability mode and execution | Existing magic/aspect ability controllers |
| Door requirements and solved state | Room/puzzle controller |
| Hub flame presentation | Save-flow/hub presentation controller |

Gameplay orchestration may route these actions, but should not become the
authority for recipes, costs, or profile mutation.

## 3. Implementation phases

### Phase 0 — Contract, catalog, and tuning seams

Create the data and constants before changing interaction behavior.

- Add stable aspect IDs for Fire, Water, Electric, Grass, Shadow, Ground, and
  Ice where the existing catalog does not already expose the required player
  identity.
- Add a canonical unordered recipe catalog:
  - Fire + Water → Shadow
  - Fire + Electric → Ground
  - Water + Electric → Grass
  - Grass + Water → Ice
- Add dedicated tuning values:
  - `FLAME_SWAP_SOUL_COST = 5`
  - `FLAME_FUSION_SOUL_COST = 5`
  - `ELEMENT_BIND_SOUL_COST = 50`
- Keep equipment-fusion constants separate from elemental flame constants.
- Define result colors and display names through the existing catalog/palette
  boundary, not through string concatenation or RGB arithmetic.

Exit condition: a pure data test can resolve every approved recipe in either
input order and reject every unlisted pair.

### Phase 1 — Profile schema and durable Binding

Add persistent storage without changing the player-facing flow yet.

- Add `bound_element` and `has_bound_element` to `PlayerProfile`.
- Serialize and load both fields with a deliberate schema migration default.
- Existing files without Binding load with no bound element; their
  `starter_flame` remains the default hub flame.
- Add atomic profile methods:
  - `can_bind_current_element(current_element)`
  - `bind_element(current_element)`
  - `bound_element_name()` / equivalent read helpers
- Charge exactly 50 Souls only after all validation succeeds.
- Binding the same element returns success/no-op without charging.
- Save and refresh the profile-facing HUD only after the mutation succeeds.

Exit condition: profile-only tests cover new files, old files, first Binding,
re-Binding, same-element no-op, insufficient Souls, cancellation, save/load,
and no partial mutations.

### Phase 2 — Separate current and bound runtime state

Refactor `PlayerChromaComponent` so current and bound identity cannot overwrite
each other accidentally.

- Replace the Boolean-only Binding model with the bound element identity.
- Keep current element changes run-local.
- Preserve existing 0..100 Chroma, 10-point Triangle spending, and 20-point
  neutral restoration.
- Resolve full, Gray, and dormant-bound ability modes from current element,
  Chroma, and bound-element state.
- Define the current/bound mismatch behavior explicitly:
  - a current unbound fusion remains usable while active;
  - a bound identity remains the recovery/default identity at zero according to
    the approved Chroma contract;
  - doors already opened by the unbound current never re-lock.
- Emit state signals that identify both current and bound changes so HUD,
  player visuals, and the hub can update independently.

Exit condition: pure state tests prove that changing current does not mutate
bound, Binding does not silently refill or swap current unless explicitly
specified, and zero-Chroma behavior is deterministic for every combination.

### Phase 3 — Flame Swap transaction

Convert the normal flame use into the new 5-Soul Swap action.

- Add a dedicated validation path for a flame interaction.
- Display the live cost and Soul balance before confirmation.
- On success, atomically:
  1. verify 5 Souls;
  2. verify the flame is usable;
  3. spend 5 Souls;
  4. consume/use the flame;
  5. set current element to the flame element;
  6. apply the existing explicit flame restoration behavior;
  7. leave bound element and profile identity unchanged.
- On rejection or cancellation, change nothing and do not consume the flame.
- Ensure standing near or repeatedly interacting with a flame cannot cause
  passive healing or repeated charges.
- Remove the old hard-coded 10-Soul assumption from the new planned path while
  retaining compatibility only where current implementation tests require it.

Exit condition: a flame-use test proves exact 5-Soul payment, full atomicity,
current-element replacement, restoration, and no profile mutation.

### Phase 4 — Flame Fusion transaction

Add explicit Fusion as a second flame action.

- Do not require `has_bound_element`.
- Require a non-Gray current element and a valid recipe with the contacted
  flame.
- Use current element as input A; never use bound element as an implicit input.
- Show the recipe result and `FUSE — 5 SOULS` before confirmation.
- On success, atomically spend 5 Souls, consume the flame, and set current to
  the recipe result.
- Mark the result unbound unless it already matches the bound element.
- Do not write the profile or hub flame.
- Allow a valid unbound fusion result to participate in a later valid fusion.
- If no recipe exists, disable Fuse while keeping Swap available.
- Do not charge a separate hidden Bind fee during Fusion.

Exit condition: tests cover no-bound fusion, bound/current mismatch, each
recipe in both orders, chained Water → Grass → Ice progression, invalid pairs,
insufficient Souls, cancellation, and no automatic fusion.

### Phase 5 — Cloaked Demon Binding menu

Add the permanent commitment UI at the Cloaked Demon.

- Show current element, bound element, Soul balance, and the flat 50-Soul cost.
- Show `NONE`/`UNBOUND` when there is no permanent identity.
- Enable Bind only when current is a valid non-Gray element and differs from
  the bound element.
- Require a confirmation before charging Souls.
- On success, update profile, save-file color, and hub flame presentation.
- A fused current remains current after Binding; Binding makes it persistent,
  not a second flame transaction.
- If current already matches bound, show an already-bound state and charge
  nothing.

Exit condition: a scene-backed test covers the menu, cost display, disabled
states, confirmation/cancellation, profile update, and hub-flame refresh.

### Phase 6 — Door and authored-curriculum integration

Make elemental puzzles use current identity rather than persistent Binding.

- Add a door requirement resolver for current active element.
- Accept unbound current fusion results.
- Latch a solved door's state so it cannot re-lock after Chroma depletion,
  swapping, death recovery, or profile changes.
- Keep required doors free of the 50-Soul Binding requirement.
- Validate authored/procedural routes before accepting them:
  - each required input flame is reachable;
  - each fusion's second flame is reachable;
  - the door is reachable immediately after the intended action;
  - no route requires returning to the Demon just to pass a mandatory door;
  - room transitions do not discard the current fusion before the door;
  - an interrupted interaction leaves a recoverable route.
- Reserve permanently-bound-element checks for explicitly optional secret or
  mastery content.

Exit condition: a headless route test solves a mandatory Ice door by reaching
Ice without Binding it, and the door remains open after current/Chroma changes.

### Phase 7 — Chroma pickup, Triangle, and presentation integration

Connect the new state model to the existing player systems.

- Neutral Chroma pickups restore according to current/bound zero-Chroma rules.
- A bound element is available for elemental recovery at zero Chroma.
- An unbound fusion does not silently become a saved bound identity when a
  pickup is collected.
- Triangle resolves from current element and effective Chroma/Binding mode.
- Player sprite, Chroma bar, damage element mapping, and ability visuals read
  current element consistently.
- Add `BOUND`/`UNBOUND` feedback where the HUD has room.
- Keep elemental combat matchups separate from flame recipes.

Exit condition: an integration test can swap, fuse, open a door, deplete
Chroma, bind at the Demon, collect Chroma, and verify the expected ability and
visual state at every step.

### Phase 8 — Economy, tutorial, and polish pass

- Update the flame cost prompt from the current implementation value to 5.
- Add Demon Binding prompt and 50-Soul confirmation.
- Add tutorial dialogue explaining that fusion is temporary until Binding.
- Make the first Binding opportunity readable without implying it is required
  for the first elemental door.
- Revisit the one-time starter Soul grant: it should cover the first necessary
  flame action, not silently subsidize the 50-Soul permanent commitment.
- Add recipe/result color and sound feedback.
- Playtest the time and Soul cost of finding flames versus returning to the
  Demon.

Exit condition: a new player can understand Swap, Fuse, current/unbound state,
and Bind without opening a debug screen, and the mandatory route never feels
like it requires a 50-Soul tax.

## 4. Integration map

The first implementation pass should inspect these existing seams:

| Concern | Existing seam | Planned responsibility |
| --- | --- | --- |
| Chroma state | `scripts/player_chroma_component.gd` | Current/bound state, depletion, recovery |
| Profile persistence | `scripts/player_profile.gd` | Bound element and Soul payment |
| Flame interaction | `scripts/gameplay.gd`, `scripts/gameplay_state.gd`, `scripts/rest_fire_controller.gd` | Route Swap/Fuse requests and flame presentation |
| Demon interaction | `scripts/npc_controller.gd` and UI controllers | Binding menu and confirmation |
| Aspect recipes | `scripts/element_catalog.gd` or new fusion catalog | Stable element IDs and recipes |
| Hub identity | Save-flow/hub flame setup | Bound-first, starter-fallback flame presentation |
| Triangle behavior | `scripts/magic_runtime_controller.gd` and aspect ability boundary | Current/effective aspect resolution |
| Door requirements | Room/puzzle controllers and `scripts/dungeon_graph.gd` | Current-element checks and latched unlocks |
| HUD | `scripts/hud_controller.gd` / player HUD | Costs, current/bound labels, feedback |

The exact controller split may change during the composition-root work, but
the ownership boundaries must remain stable.

## 5. Verification matrix

### Pure catalog and economy tests

- Recipe pairs are unordered and deterministic.
- Only the four approved recipes resolve.
- Swap cost is exactly 5 Souls.
- Fusion cost is exactly 5 Souls.
- Every new permanent Binding costs exactly 50 Souls.
- Same-element Binding is a free no-op.
- Insufficient Souls reject without consuming a flame or changing state.
- Equipment-fusion costs remain unchanged.

### Runtime state tests

- New run starts Gray/current None at 0 Chroma with the profile's bound state
  unchanged.
- Swap changes current but not bound or profile identity.
- Fusion works with no bound element.
- Fusion uses current rather than bound as its first ingredient.
- Fusion results are current and unbound.
- Chained unbound fusion works for Water → Grass → Ice.
- Binding a fused result updates bound and leaves current correct.
- Current/bound mismatch has deterministic zero-Chroma behavior.
- Room transitions do not accidentally bind or discard a valid current fusion.
- Save/load restores bound identity but not an uncommitted temporary fusion as
  permanent profile state.

### Door and curriculum tests

- A current unbound element opens the matching door.
- The matching door does not require Binding or an additional Soul payment.
- Solved doors remain open after Chroma depletion and swapping.
- A generated Ice route does not put the Water/Electric/Grass prerequisite
  behind the Ice door itself.
- A player can cancel Swap, Fuse, or Bind and recover normally.

### Scene and presentation tests

- Flame UI shows the correct action, recipe, cost, and disabled reason.
- Demon UI shows current/bound state and 50-Soul cost.
- Hub flame uses bound element first and starter flame as fallback.
- Current element, Chroma bar, sprite saturation, Triangle mode, and damage
  element remain synchronized.
- The full `tests/run_all_smoke.ps1` suite remains green.

## 6. Recommended development checkpoints

Commit each checkpoint as a reviewable slice:

1. `elemental binding contract and recipe catalog`
2. `persist bound elemental identity`
3. `separate current and bound chroma state`
4. `add five-soul flame swap`
5. `add unbound flame fusion`
6. `add cloaked demon binding menu`
7. `allow unbound elements to solve doors`
8. `integrate zero-chroma recovery and presentation`
9. `add binding and fusion smoke coverage`

Do not combine equipment-fusion changes, new elemental status effects, or a
general procedural-generation rewrite with these checkpoints.

## 7. Questions to resolve before code

The core economy and access rules are settled. These smaller behavior details
should be answered during the first implementation review:

1. Does a successful Fuse receive the same full HP/full Chroma restoration as
   a successful Swap, or does it only change the element and consume Chroma?
   The default recommendation is to retain the existing explicit one-use flame
   restoration, with no passive healing.
2. When an unbound current reaches zero while a different bound element exists,
   does the player immediately resolve to the bound identity or to Gray? The
   recommended recovery behavior is bound identity as the fallback, while
   already-solved doors remain latched.
3. Does an unbound current fusion survive death, or does death restore the last
   bound/default state? The recommended behavior is to restore the last durable
   state on death and keep temporary fusion state run-local only.
4. At what story/run milestone does the Demon Binding menu become available?
   The menu should not appear as a required solution to the first elemental
   door.
5. Are current class stat/passive effects always derived from current element,
   or does Binding preserve any portion of the old package during a temporary
   swap? The recommended first implementation uses current element only and
   avoids stat stacking.

## 8. Definition of done

This plan is implemented when:

- all four recipes work from current element state;
- no bound element is required for Fusion or mandatory doors;
- every permanent Binding is a Cloaked Demon action costing 50 Souls;
- current unbound results are clearly visible and usable;
- Binding changes save-file and hub identity only after confirmation;
- bound identity supports the agreed zero-Chroma recovery behavior;
- required doors latch after being solved;
- save, room-transition, death, and run-reset behavior are tested;
- documentation, tuning index, and smoke coverage match the shipped rules.

## 9. Implementation record

The current feature branch implements the core slices through the existing
composition root:

- `AspectCatalog` owns the four commutative recipes and all seven elemental
  flame identities.
- `PlayerProfile` persists a bound element with schema-8 compatibility for
  the previous profile schema; Binding is a flat 50-Soul Demon transaction.
- `PlayerChromaComponent` keeps current and bound identities separate, supports
  unbound fusion, and restores a bound identity when zero-Chroma recovery is
  collected.
- Flames expose an explicit Swap/Fuse menu at 5 Souls per action. Fusion never
  mutates the profile by itself.
- Elemental doors accept the current element, including unbound results, and
  latch their solved state in the run map.
- Generated Run 6+ layouts contain validated mandatory fusion gates. Run 8+
  adds the chained Grass and Ice gates.
- `tests/elemental_binding_smoke.gd` covers recipes, economy, state separation,
  unbound door access, and generated Run 6–9 curriculum validation.
- `tests/generated_fusion_gate_scene_smoke.gd` verifies the R6 gate in the
  composed scene, including its locked/open/latching presentation states.

The full smoke runner remains the release gate after any further changes.
