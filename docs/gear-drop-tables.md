# Tiny Demons — Gear Sources and Drop Tables

## Status

**Approved acquisition design — six-slot source integration is landed;
numerical weights still require the balance pass.** This document defines
where gear comes from and how the generator behaves with Head and Arm. Rows
whose effect contract is still marked `future` remain out of live source pools
until their owner is implemented.

## Source boundaries

| Source | Gear role | Initial rule |
| --- | --- | --- |
| Starter loadout | Establishes the six visible slots | Weapon, Body, Shield, and Accessory retain current power; Head and Arm use zero-power starters |
| Shop | Reliable choice and bad-luck protection | One readable baseline option per slot plus one rotating premium option |
| Treasure chest | Exciting in-run discovery | One primary gear roll, with the existing occasional second-item burst |
| Run-clear reward | Performance-sensitive long-term chase | One seeded slot/rarity roll using the run grade and score inputs |
| Boss reward | Curated late-game identity | Reserved unique/high-tier pool; not required for ordinary progression |
| Normal enemy death | Moment-to-moment resources | Souls/Chroma remain the normal enemy reward; no inventory flood |
| Fusion | Productive duplicates | Matching definition and rarity remain the material rule |

The existing chest, run-clear, shop, rarity, and fusion services remain the
ownership boundaries. The catalogue expansion adds data and selection rules;
it does not put reward mutation in menu presentation code.

## Slot selection

The current generator chooses a slot from all six canonical slots. It uses an
explicit seeded slot policy instead of silently making every slot equally
likely forever.

### Empty-slot protection

If a profile has an empty Head or Arm slot, the first suitable chest, shop
refresh, or run-clear reward should strongly prioritize that slot. The rule is
seeded and deterministic, but it must not guarantee a specific rare item.

This prevents the two new slots from being invisible simply because the old
four-slot table is still statistically dominant.

### Chest policy

1. Build the eligible slot list from all six slots.
2. If Head or Arm is empty and the source has not recently offered that slot,
   apply the missing-slot priority.
3. Otherwise use source weights that keep the six slots visible over a run.
4. Pick a definition within the slot using family/source tags.
5. Roll rarity from the existing run-rank/performance function.
6. Persist the identified `ItemInstance` in the world drop before collection.

The chest may produce two items under the existing second-drop rule, but each
item must have its own instance ID and landing position. Two items should not
become a hidden merged reward.

### Run-clear policy

Run-clear gear remains one of the most important completion rewards. The slot
roll should use a deterministic rotating bag or equivalent anti-repeat policy:

- avoid repeating the same slot several clears in a row when alternatives are
  available;
- prioritize a missing Head or Arm slot early;
- allow the player’s grade and score to influence rarity, not to erase the
  base identity; and
- keep the existing settlement idempotence boundary.

Full map completion and room completion may improve reward quality through the
existing score path, but gear must not directly award Style or alter the grade
calculation.

### Shop policy

The shop should expose reliable choices for all six slots. The current
per-slot baseline plus one premium model can remain, but the UI must paginate
or group rows if the six-slot stock no longer fits cleanly.

Shop entries should include:

```text
slot, item name, rarity, enhancement, price, role, primary stat,
projected comparison, purchase state
```

The shop is the safety valve for bad drop luck. A player should not need a
specific chest roll to obtain a usable Head or Arm item.

## Rarity policy

The live rarity ladder is Common, Rare, Epic, Legendary, and Mythic. The
existing rarity roll remains the starting point; its probabilities should be
rebalanced only after simulations include six equipped slots.

Content gates are expressed as data:

```text
rarity_floor
rarity_ceiling
minimum_run_rank
minimum_player_level
source_tags
boss_only
shop_eligible
```

Rarity increases the authored package according to the current tuning contract.
It does not create an unrelated random affix pool. Legendary and Mythic items
may unlock a transmutation or signature passive when the definition says so.

## Definition selection

Definitions should carry tags rather than hard-coded source branches:

```text
slot: head
family: circlet
role_tags: [magic, mnd, defense]
source_tags: [chest, shop, clear_reward]
element_tags: [fire]
minimum_run_rank: 3
```

The generator may use those tags to avoid a late-game Fire Ward appearing in a
starter shop, but the definition itself remains independently inspectable.

Basic/starter definitions are safe fallbacks. They may receive a high shop
weight and a low chest weight, but a `prefer_non_basic` source request must
exclude them exactly as the current generator does.

## Duplicate and fusion rules

- A duplicate is still useful when it shares definition ID and rarity with an
  unequipped target.
- Enhancement remains `+0` through `+10`; rarity transition behavior remains
  the current Soul-priced fusion contract.
- Transmutation identity belongs to the target item and is not rerolled by
  ordinary fusion.
- A duplicate from a different family or slot is not a valid material merely
  because its stats look similar.
- Mythic `+10` overflow may use the existing salvage route.

## Quality and economy

The current `quality` roll is allowed to affect price/salvage only. It must not
become an invisible combat roll during this expansion. If quality is eventually
removed, that is a separate save migration decision.

The first catalogue does not add:

- Souls-per-enemy bonuses;
- Gold multipliers;
- global drop-rate multipliers;
- pity currencies;
- gear-identification costs; or
- a second equipment-fusion currency.

Pickup radius and pickup landing comfort are acceptable Accessory utility
because they improve collection feel without multiplying the economy.

## Source telemetry

The implementation should record enough information to balance the catalogue:

```text
source
slot
definition_id
rarity
run_rank
player_level
score / grade
whether slot was empty
whether item was equipped
whether item was fused or salvaged
time from acquisition to equip/sale/fusion
```

This telemetry belongs to reward/progression code, not the menu presenter.

## Acceptance scenarios

The drop system is ready for content implementation when these scenarios are
deterministic and tested:

1. A new profile starts with visible Head and Arm slots and no free power from
   those slots.
2. An old four-slot profile loads with its Armor item in Body and no lost
   equipment.
3. A chest can produce every approved slot over a representative seeded run.
4. Empty Head/Arm slots receive sensible early protection from the missing-slot
   rule.
5. A run-clear reward can produce the new slots without changing settlement
   idempotence.
6. Shop stock remains readable and purchase validation remains atomic.
7. Identical duplicates fuse; different definitions do not.
8. Normal enemy kills still award Souls/Chroma without flooding inventory.
