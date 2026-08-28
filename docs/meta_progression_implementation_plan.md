# Meta Progression Vertical Slice — Implementation Plan

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

## Locked Slice Scope

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

## Architecture

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

## Representative Slice Content

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

## Four-Day Delivery Plan

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

## File-Level Change Map

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

## Save and Migration Rules

- Start schema at version 1.
- Write to a temporary save, then replace the profile save after success.
- Keep one recoverable backup of the previous valid profile.
- Missing fields receive defaults; unknown fields are ignored.
- Invalid equipped instance IDs are unequipped, not fatal.
- If no profile exists, convert the current starter level, XP, gold, and default
  equipment into a new profile.
- Developer reset must require an explicit debug action and never run as part
  of ordinary death/restart flow.

## Verification Matrix

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

## Scope Controls

If the schedule slips, cut in this order:

1. Reduce shop stock variety; keep purchasing functional.
2. Use one base per armor/shield/accessory slot; keep the slot pipeline.
3. Keep one weapon transmutation production-ready and leave the other slot
   hooks behind debug items.
4. Use text-only hub presentation.

Do not cut save/load, death settlement, stat allocation, item-instance
ownership, or atomic economy operations. Those are the foundation.

## Definition of Done

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

Use three player-readable categories, each normalized to 0–100:

| Category | Starting weight | Measurement direction |
| --- | ---: | --- |
| Level completion | 50% | Current-level objective progress, with a complete level reaching 100% |
| Combat | 25% | A compact combination of successful clears/kills and damage avoided; no style or input-count requirement |
| Speed | 25% | Clear time compared with a level-specific target window, with a forgiving floor and cap |

The weighted total remains a 0–100 score so existing reward code can migrate
without introducing a second scale. Completion must be based on the current
level's authored/generated objective count rather than a global lifetime or
run-rank value. If the player can extract or die before the level is complete,
the result must show the partial percentage that was actually achieved.

The first tuning pass should make S achievable by a strong, repeatable clear,
not by perfect damage, perfect accuracy, every optional room, and an extreme
time simultaneously. Begin with provisional thresholds of S 90+, A 75+, B 60+,
C 40+, and D below 40, then calibrate them against representative real runs.
Thresholds and speed target windows belong in tuning data once the first
playtest establishes the normal clear-time distribution.

### Result-panel rewrite

Replace the current long diagnostic list with a compact hierarchy:

```text
LEVEL COMPLETE   100%
COMBAT           84%
SPEED            72%
GRADE S          91

REWARDS
+GOLD / GEAR / XP
RETURN TO HUB
```

The exact reward line depends on the existing settlement result, but the panel
should not display implementation-only counters such as wasted inputs, style
ratios, or every attack/block count. Those values may remain in debug logging
or a later optional detail view. Each category gets one clear value and a
consistent color treatment; the grade and reward remain visually dominant.

### Implementation sequence

1. Audit every `RunGrade` field and every consumer in `RunState`,
   `RunFlowController`, loot rarity/reward calculation, profile persistence,
   the result UI, and tests.
2. Add explicit current-level objective progress to the run state and finalize
   it at the same settlement boundary used by completion, extraction, and
   defeat. Keep partial-run values valid and deterministic.
3. Replace the grade evaluator with the three weighted categories. Keep the
   output keys temporarily compatible where reward code still needs them, then
   remove obsolete presentation-only fields after the migration is covered.
4. Move target times, category weights, and grade thresholds into a tuning
   resource or clearly owned constants. Avoid deriving speed from the player's
   personal best during the same run.
5. Simplify `build_run_complete` and `show_run_complete` to render only the
   compact result hierarchy, preserving touch/controller return behavior.
6. Rebalance loot/reward use of the score so an attainable S is valuable but
   cannot create an outsized difficulty or drop-rate jump.
7. Replace the synthetic S fixture with representative clean/ordinary/partial
   run fixtures and add boundary tests for each grade and each category clamp.
8. Run a manual matrix across a full clear, a slow clear, a damaged clear, and
   an early defeat/extraction; verify that the panel communicates the outcome
   without requiring a second pass through the old diagnostic counters.

### Exit criteria

- A normal excellent current-level clear can reach S without requiring every
  optional behavior or a near-zero damage run.
- A partial session reports a truthful completion percentage and cannot receive
  a high grade solely from speed or combat.
- Combat and speed categories are bounded, explainable, and independent of
  unrelated UI/input noise.
- Rewards, profile `last_run_grade`, and future-run loot modifiers use the new
  score/grade consistently.
- The result panel is materially shorter, readable at 3:2/16:9, and usable by
  keyboard, gamepad, and touch.
- `run_grade_smoke`, result-panel smoke coverage, and the full smoke suite pass.
