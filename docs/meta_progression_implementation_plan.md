# Meta Progression Vertical Slice — Implementation Plan

> **Historical foundation plan — completed and superseded for current equipment
> content.** This document records the original four-slot vertical slice. The
> approved current equipment direction is the six-slot, 44-base expansion in
> [`gear-catalogue-spec.md`](gear-catalogue-spec.md) and
> [`gear-catalogue-implementation-plan.md`](gear-catalogue-implementation-plan.md).
> References below to four slots, random affixes, Common/Rare/Epic-only
> content, or deferred transmutations describe the old delivery slice and are
> not current design requirements.

## Objective

Deliver a fully functional, end-to-end meta-progression vertical slice in four
focused development days:

```text
Title -> Hub -> Allocate / Equip / Shop / Fuse -> Start Run
      -> Fight / Level / Find Gear -> Die or Finish -> Settle -> Hub
```

"Fully functional" means the complete loop saves, loads, changes real combat
outcomes, survives death/title transitions, and is testable with representative
content. It does not mean the final quantity of equipment, final hub artwork,
floor shops, or production balancing is complete.

## Historical Locked Slice Scope (completed)

### Included

- Persistent profile saved to `user://` with a schema version.
- Persistent level, XP, Core HP growth, allocated VIT/STR/DEF, unspent points,
  gold, inventory, equipped item IDs, and equipment-family mastery.
- Manual stat allocation and optional auto-allocation presets.
- Provisional 1–5 point award bands stored as tuning data.
- Health percentage preserved when leveling or changing maximum health.
- Menu-based hub with Build, Allocate, Inventory, Shop, Fusion, Start Run, and
  Title actions.
- Death/result settlement and safe return to hub or title.
- All four equipment slots represented in data and UI.
- Three weapon bases; at least two armor, two shield, and two accessory bases.
- Common, Rare, and Epic item generation.
- Small slot-restricted affix pools.
- One working behavioral transmutation hook per slot.
- Direct identified drops, automatic inventory storage, and a compact pickup
  notification.
- Hub merchant with reliable basics and one seeded rotating premium item.
- Equipment-family fusion from `+0` to `+3` using matching duplicates.
- Save/load, transition, and combat smoke tests.

### Deferred

- Walkable hub artwork and NPC staging.
- Floor merchants.
- Legendary/set items.
- Transmutation rerolling or risky crafting.
- Multiple crafting currencies, gacha chests, pity systems, pets, mounts, or
  hero collection.
- Large item/affix catalogs and final balance.
- Temporary run-boon selection beyond preserving a clean `RunState` boundary.

## Historical Architecture Foundation

Keep the first implementation compact. Data and state should be extensible,
but the slice does not need a framework for every future crafting idea.

### New runtime boundaries

#### `PlayerProfile`

Persistent source of truth:

```text
schema_version
level / xp
unspent_stat_points
allocated_vit / allocated_str / allocated_def
gold
inventory item instances
equipped instance IDs by slot
family mastery by item definition ID
unlocks / completed bosses
```

Responsibilities:

- Award XP and process one or multiple levels.
- Award the configured number of stat points for each reached level.
- Validate allocation/respec operations.
- Grant/remove/equip item instances.
- Validate purchases and fusion exactly once.
- Serialize and deserialize profile data.

#### `RunState`

Temporary source of truth:

```text
dungeon seed and current room state
run-only boons / consumables
pending reward presentation
run result and settlement status
```

The current dungeon graph and room-state implementation can remain in place
for the slice. `RunState` initially wraps its lifecycle so profile data is not
accidentally reset with a run.

#### `ItemCatalog`

Authored definitions for bases, affixes, transmutations, rarity rules, and shop
stock. Runtime item instances store only IDs and rolled values needed to
reconstruct their behavior.

#### `EquipmentComponent`

Consumes the profile's equipped instances and produces one calculated equipment
snapshot. Combat reads this snapshot rather than hard-coded item-name branches.

#### `RunSettlement`

Idempotent boundary used by death, boss victory, extraction, and title return:

1. Commit pending persistent rewards once.
2. Save the profile.
3. Clear run-only state.
4. Route to hub or title.

Calling settlement twice must never duplicate gold, XP, or items.

### Item data

`ItemDefinition`:

```text
id, display name, slot, base output, scaling ranges,
allowed affix pool, allowed transmutation pool, art references
```

`ItemInstance`:

```text
unique instance ID, definition ID, rarity, quality/scaling rolls,
affix IDs and rolled values, transmutation ID
```

Persist rolled values, not only an RNG seed. A future generator change must not
silently alter items a player already owns.

### Stat calculation order

```text
innate stats
  + manually allocated stats
  + flat stats from all equipped items
  = effective stats

Core HP (level-independent)
  -> VIT and additive equipment scaling
  -> flat equipment health
  = maximum health

item base output
  -> effective-stat scaling
  -> family mastery bonus to the base implicit
  -> affixes
  -> conditional transmutation behavior
```

The character sheet must be able to display this breakdown. Scaling never reads
its own final output as an input.

## Historical Representative Slice Content

Use existing visuals where possible. Mechanical validation is the priority.

### Weapon bases

1. **Soldier's Sword** — STR-forward, reliable two-hit combo.
2. **Guardian Sword** — DEF scaling and block-to-counter synergy.
3. **Blood Sword** — VIT scaling and health-risk effects.

### Other slot bases

- Armor: Basic Tunic, Bloodwoven Tunic.
- Shield: Basic Shield, Living Bulwark.
- Accessory: Bangle, Duelist Seal.

### Initial transmutations

- Weapon: Gathering Edge or Defiant Edge.
- Armor: Bloodwoven Core-HP scaling.
- Shield: Bastion Core durability/counter charge.
- Accessory: Duelist Seal target-lock scaling.

Prefer hooks that can be expressed through existing attack, guard, roll, health,
and targeting signals. Every transmutation gets an explicit trigger, effect,
tradeoff, cooldown/stack rule if needed, and UI description.

## Historical Four-Day Delivery Plan

### Day 1 — Persistent profile and stat foundation

1. Checkpoint the current intended worktree before implementation.
2. Add profile data, schema versioning, default-profile creation, and save/load.
3. Move level, XP, gold, and persistent stat ownership into the profile.
4. Replace automatic level growth with banked manual allocations; retain the
   existing profiles as optional allocation helpers.
5. Add data-driven point-award bands capped at five.
6. Refactor Core HP/VIT/equipment calculation into one stat snapshot.
7. Preserve health percentage on level and equipment changes.

Day 1 exit test:

- A fresh profile starts with the intended default stats/loadout.
- A multi-level XP grant awards the correct points for every crossed level.
- Allocation changes health/damage/defense and survives application restart.
- Leveling does not fully heal the player.

### Day 2 — Hub, death flow, and allocation UI

1. Add a menu-based hub screen under the existing screen-state controller.
2. Add Build and Allocate pages with current/effective stat breakdowns.
3. Support point spending, confirmation, optional presets, and hub respec.
4. Add defeat/result presentation with Hub and Title choices.
5. Add idempotent run settlement and route death through it.
6. Start runs from the hub and keep profile state separate from dungeon reset.

Day 2 exit test:

- Title can open/create a profile and enter the hub.
- Hub starts a clean run.
- Death returns to hub by default; title is a safe explicit choice.
- Level, XP, allocations, gold, and current equipment survive both routes.
- Run-only room state is reset.

### Day 3 — Items, drops, inventory, equipment, and shop

1. Add item definitions/instances and the representative base catalog.
2. Generate Common/Rare/Epic instances with slot-restricted rolls.
3. Replace hard-coded equipment-name bonuses with equipped item instances.
4. Add inventory inspect/compare/equip interactions for all four slots.
5. Add a compact direct-drop reward and automatic inventory grant.
6. Add a hub merchant with deterministic basics and one seeded premium item.
7. Validate purchase affordability and mutation through the profile boundary.

Day 3 exit test:

- Combat/chests can produce an identified item exactly once.
- The item remains in inventory after death and application restart.
- Equipping it changes the character sheet and real combat calculation.
- Shop success subtracts gold and grants once; failure changes nothing.
- Shop rotation is stable for its configured run seed.

### Day 4 — Fusion, transmutations, and hardening

1. Add family mastery and duplicate-consumption UI from `+0` to `+3`.
2. Apply mastery only to the authored base implicit.
3. Implement one transmutation hook per slot.
4. Add trigger feedback using appropriate existing visual/audio treatments.
5. Add save corruption fallback and validate schema/default migration behavior.
6. Run the complete smoke matrix and tune obvious power spikes.
7. Document remaining content/balance work separately from foundation bugs.

Day 4 exit test:

- Fusion consumes the selected unequipped duplicate once.
- Family mastery affects existing and future instances of that base.
- Every initial transmutation triggers only under its documented condition.
- Saving during hub/run transitions cannot duplicate rewards.
- A complete run/death/restart loop works without state leakage.

## Historical File-Level Change Map

Exact names may follow current conventions, but responsibilities should remain
separate.

### Likely new files

- `scripts/player_profile.gd`
- `scripts/run_state.gd`
- `scripts/run_settlement.gd`
- `scripts/item_definition.gd`
- `scripts/item_instance.gd`
- `scripts/item_catalog.gd`
- `scripts/hub_controller.gd`
- `scripts/profile_save_service.gd`

### Likely existing-file changes

- `stats_component.gd` — explicit allocations and effective-stat input.
- `combat_calculator.gd` — Core HP and item scaling order.
- `combat_tuning.gd` — level curve, VIT rate, and allocation bands as data.
- `equipment_component.gd` — calculated snapshot from item instances.
- `gameplay_state.gd` — references profile/run state instead of owning permanent
  progression fields.
- `gameplay.gd` — rewards, level feedback, equipment hooks, and transition
  adapters.
- `gameplay_bootstrap.gd` — load profile and initialize run separately.
- `screen_state_controller.gd` — hub/result states.
- `chest_controller.gd` and `room_controller.gd` — grant rewards through the
  profile/run boundaries.
- `player_attack_component.gd`, `player_guard_component.gd`, and
  `player_roll_component.gd` — expose narrow transmutation events without
  containing item-database logic.

## Historical Save and Migration Rules

- Start schema at version 1.
- Write to a temporary save, then replace the profile save after success.
- Keep one recoverable backup of the previous valid profile.
- Missing fields receive defaults; unknown fields are ignored.
- Invalid equipped instance IDs are unequipped, not fatal.
- If no profile exists, convert the current starter level, XP, gold, and default
  equipment into a new profile.
- Developer reset must require an explicit debug action and never run as part
  of ordinary death/restart flow.

## Historical Verification Matrix

### Progression

- Exact XP threshold and multi-level overflow.
- Point awards at every band boundary and five-point cap.
- Manual allocation, cancel, confirm, preset, and respec.
- Level/equipment maximum-health changes preserve health percentage.

### Inventory and economy

- Item IDs remain unique across save/load.
- Equip restrictions by slot.
- Purchase success/failure is atomic.
- Duplicate fusion cannot consume equipped or missing items.

### Runs and transitions

- Hub -> run -> death -> hub.
- Hub -> run -> death -> title -> hub.
- Boss/result settlement follows the same path.
- Repeated settlement calls do not duplicate rewards.
- Temporary room/boon state does not leak into the next run.

### Combat

- STR-scaling weapon changes expected damage.
- VIT scales growing Core HP.
- DEF still uses diminishing mitigation and affects shield mechanics.
- Multi-target, guard, roll, and target-lock transmutations trigger correctly.
- Starter gear remains capable of clearing early content.

## Historical Scope Controls

If the schedule slips, cut in this order:

1. Reduce shop stock variety; keep purchasing functional.
2. Use one base per armor/shield/accessory slot; keep the slot pipeline.
3. Keep one weapon transmutation production-ready and leave the other slot
   hooks behind debug items.
4. Use text-only hub presentation.

Do not cut save/load, death settlement, stat allocation, item-instance
ownership, or atomic economy operations. Those are the foundation.

## Historical Definition of Done

The slice is complete when a new player can:

1. Enter the hub from the title screen.
2. Start a run and earn XP, gold, and an equipment drop.
3. Level up, return safely, allocate points, and inspect the derived stats.
4. Equip the drop and observe a real combat difference.
5. Buy an item and fuse a matching duplicate.
6. Trigger at least one documented transmutation in combat.
7. Die, return to hub or title, relaunch the game, and retain all permanent
   progression without duplicated or lost rewards.

Only after this loop is stable should content expansion, floor shops, a
walkable hub, and transmutation rerolling begin.

## Current handoff: approved gear catalogue expansion

The foundation described above is now stable enough for the six-slot catalogue
content pass. The implementation checkpoint has landed the slot schema,
authored read model, source policy, menus, and current effect contracts:

- Weapon, Head, Body, Arm, Shield, and one Accessory slot;
- zero-power starter items for Head and Arm;
- 44 authored bases in the shared runtime schema, with values still subject to
  balance review;
- deterministic authored packages instead of hidden random primary affixes;
- current Common/Rare/Epic/Legendary/Mythic rarity support;
- explicit current transmutation contracts and future Imbue Resonance/Elemental
  Ward contracts;
- current fusion, transmutation, shop, chest, run-clear, and save boundaries;
- no direct Souls, gold, global drop-rate, or Style multipliers; and
- future Spear, Bow, Tome, Fist, Thrown, Bell, Harp, and Dark-weapon families
  retained as documentation extension points only.

Use [`gear-catalogue-implementation-plan.md`](gear-catalogue-implementation-plan.md)
for the remaining effect-owner and balance phases. Do not expand the runtime
catalogue from this historical plan’s old affix or four-slot examples.

## Follow-up Plan: Simplified Run Results and Attainable Grades

### Problem statement

The current post-run panel exposes too many raw counters and combines time,
damage, exploration, combat variety, accuracy, and input discipline into a
single score. In practice, the S threshold is not a believable target during a
normal strong clear. The result screen should answer three useful questions
quickly: how much of the current level was completed, how cleanly was combat
handled, and how efficiently was the level cleared?

This is a follow-up implementation slice. It should not be folded into the
existing score silently; the displayed metrics, grade thresholds, reward
inputs, and smoke fixtures must change together.

### Target scoring model

Use three player-readable categories:

| Category | Weight | Measurement direction |
| --- | ---: | --- |
| Room completion | 60% | Completed local room objectives; a full clear reaches 100% |
| Time | 30% | Clear time compared with a route-scaled target window |
| Style | 10% | A capped 0–10 measure of varied, successful combat actions |

Map discovery and room completion are intentionally distinct. Map discovery is
the percentage of non-hub rooms the player physically entered. Room completion
is the percentage of those authored/generated rooms whose local objective was
completed. Discovery is shown as a progress metric, but room completion drives
the completion pillar so walking through a room cannot substitute for clearing
it. Utility rooms such as rest, trader, and NPC rooms complete on entry; combat
and puzzle rooms retain their objective-specific completion behavior.

Style is flexible rather than a checklist: successful basic/follow-up attacks,
spin and charged attacks, dodge rolls, backflips, blocks, magic, imbued hits,
and sustained combo flow contribute to a capped 0–10 score. Repeating one
action does not farm unlimited points, and the visible combo increments once
per enemy hit, including multi-target attacks.

The weighted total remains a 0–100 score. A run that leaves a room objective
incomplete is capped at grade B even if its time and style would otherwise
produce A or S. Damage, survival, accuracy, and mis-input counts remain useful
backend telemetry but do not lower the player-facing grade.

The first tuning pass uses S 90+, A 78+, B 64+, C 48+, and D below 48. Target
times and thresholds are clearly owned constants for now so they can move into
tuning data after representative playtests establish normal clear times.

### Result-panel rewrite

Replace the current long diagnostic list with a compact hierarchy:

```text
GRADE S          091
TIME             00:42
MAP              8/8
ROOMS            8/8
STYLE            8/10
MAX COMBO        x12

REWARDS
+GOLD / GEAR / XP
RETURN TO HUB
```

The exact reward line depends on the existing settlement result, but the panel
should not display implementation-only counters such as damage, wasted inputs,
accuracy, or every attack/block count. Those values remain available in the
backend summary for debugging and future detail views. Map discovery is shown
alongside room completion so the two kinds of progress are understandable at a
glance. Each metric gets one clear value and a consistent color treatment; the
grade and reward remain visually dominant.

### Implementation sequence

1. Audit every `RunGrade` field and every consumer in `RunState`,
   `RunFlowController`, loot rarity/reward calculation, profile persistence,
   the result UI, and tests.
2. Add separate physical map-entry discovery and local room-objective
   completion to the run state. Finalize both at the same settlement boundary
   used by completion, extraction, and defeat. Keep partial-run values valid
   and deterministic.
3. Replace the grade evaluator with the 60/30/10 room/time/style model. Keep
   raw combat telemetry in the summary for backend consumers without letting it
   change the displayed grade.
4. Move target times, category weights, and grade thresholds into a tuning
   resource or clearly owned constants. Avoid deriving speed from the player's
   personal best during the same run.
5. Simplify `build_run_complete` and `show_run_complete` to render only the
   compact result hierarchy, preserving touch/controller return behavior.
6. Add the visible combo timer to the HUD, freeze it in menus, reset it on
   damage/death/room transition, and record its max/hit telemetry once per
   successful enemy hit.
7. Rebalance loot/reward use of the score so an attainable S is valuable but
   cannot create an outsized difficulty or drop-rate jump.
8. Replace the synthetic S fixture with representative full-clear,
   slow-clear, and partial-run fixtures and add boundary tests for grade clamps,
   style caps, completion ratios, and orientation-driven UI reflow.
9. Run a manual matrix across full/partial, fast/slow, and varied-style runs;
   verify the panel communicates the outcome without requiring a second pass
   through diagnostic counters.

### Exit criteria

- A normal excellent current-level clear can reach S without requiring every
  optional behavior or a near-zero damage run.
- A partial session reports truthful map-entry and room-completion percentages
  and cannot receive a high grade solely from speed or style.
- Room completion, time, and style are bounded, explainable, and independent of
  unrelated damage/UI/input noise.
- Rewards, profile `last_run_grade`, and future-run loot modifiers use the new
  score/grade consistently.
- The result panel is materially shorter, readable at 3:2/16:9 and mobile
  landscape orientations, and usable by keyboard, gamepad, and touch.
- `run_grade_smoke`, result-panel smoke coverage, and the full smoke suite pass.
