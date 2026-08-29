# Tiny Demons — Gear Catalogue and Equipment Specification

## Status and authority

**Approved design — six-slot runtime foundation landed.** Approved 2026-08-29.
Slot migration, authored definitions, source selection, equipment previews, and
save compatibility are implemented; effect rows marked `future` remain
intentionally gated from live generation until their action owner exists.

This is the authoritative content and rules specification for the next
equipment expansion. It supersedes the equipment-slot, rarity, and affix
assumptions in the original meta-progression proposal. The completed
six-stat/composite-combat implementation remains the mechanical foundation;
this document defines how the larger gear catalogue will use it.

Companion documents:

- [`gear-catalogue.md`](gear-catalogue.md) — the authored item list.
- [`gear-effect-contracts.md`](gear-effect-contracts.md) — effect ownership,
  stacking, formulas, and test contracts.
- [`gear-drop-tables.md`](gear-drop-tables.md) — source rules, progression
  gates, slot selection, and duplicate handling.
- [`gear-catalogue-implementation-plan.md`](gear-catalogue-implementation-plan.md)
  — the implementation sequence and exit criteria.
- [`meta_progression_design.md`](meta_progression_design.md) — broader hub and
  persistence design; its equipment sections now defer to these documents.

## Design intent

The equipment loop should make a drop immediately legible while leaving room
for long-term discovery:

```text
find a base identity
    -> understand its stat lane and combat question
    -> compare its projected result on this character
    -> equip, fuse, or save it for a future build
```

Final Fantasy III is the organizational reference, not a literal content
target. Its [DS item guide](https://gamefaqs.gamespot.com/ds/924897-final-fantasy-iii/faqs/45997)
is useful because it separates weapon families, uses Head/Body/Arm/Shield
armor categories, and gives each item a repeatable record of name, attack,
effect, bonus, eligibility, and notes. Tiny Demons keeps its own
single-character action identity, so weapon families are catalogue tags and
behavior identities rather than automatic new slots or job restrictions.

## Approved slot taxonomy

The final equipment layout has six slots:

| Canonical key | UI label | State | Primary identity |
| --- | --- | --- | --- |
| `weapon` | WEAPON | Existing | Physical attacks, Imbue resonance, attack profile |
| `head` | HEAD | New | INT/MND, magic defense, elemental wards |
| `body` | BODY | Existing `armor` slot renamed | VIT/DEF, Core HP, general survival |
| `arm` | ARM | New | STR/AGI, attack handling, charge and combo behavior |
| `shield` | SHIELD | Existing | Guard durability, block behavior, DEF/MND |
| `accessory` | ACCESSORY | Existing | One flexible build twist or utility contract |

Compatibility rules:

- `armor` remains a load/save alias for `body` while old profiles and items
  are migrated.
- Old `armor_name` presentation fields may remain as compatibility aliases;
  new UI copy says BODY.
- New profiles visibly contain all six slots.
- `Plain Hood` and `Cloth Wraps` are zero-power, starter-only items. They make
  the new slots visible without adding free early combat power.
- There is one Accessory slot. A second accessory, relic, or Core slot is
  reserved for a later design and is not part of this catalogue.
- A future two-handed rule belongs to weapon metadata (`grip`, `offhand_rule`)
  rather than another equipment slot.

## Slot vocabularies

Each slot has a protected identity. A legal stat is not automatically a good
item: every entry must explain why its package belongs in that slot.

### Weapon

Weapon entries answer “how does this demon attack?” They may emphasize STR,
AGI, or INT, and may carry an explicit attack or Imbue behavior. A weapon’s
elemental identity must never silently replace the player’s current Chroma
aspect, starter flame, or permanent bound element.

Initial families are Blade, Dagger, Maul, and Focus/Rod. Spear, Bow, Tome,
Fist, Thrown, Bell, Harp, and other Final Fantasy-inspired families remain
documented extension points. Each future family requires a real attack,
animation, hitbox, and input contract before it becomes a drop.

### Head

Headgear is the first dedicated magic/defense slot. It is the natural home for
INT, MND, M.DEF, elemental warding, and small resource-management effects.
Headgear should not become a second accessory: its effects remain defensive or
spell-facing.

### Body

Body gear is the current Armor slot under a clearer name. It owns VIT, DEF,
Core HP, broad physical survival, and heavy/light tradeoffs. Body gear may
support MND or elemental wards when the item identity calls for it, but it
should not carry the strongest attack behavior.

### Arm

Arm gear represents gloves, gauntlets, bracers, and sleeves. It is the main
new home for STR/AGI tradeoffs and action handling: attack lunge, Attack 2,
charge, spin, recovery, and guard technique. It changes how an action feels,
not the player’s run grade directly.

### Shield

Shields own guard durability, guard reduction, block recovery, and defensive
tradeoffs. DEF remains the primary shield stat; VIT and MND are valid
secondary lanes. A shield may offer an elemental ward, but its core identity
must still be readable as guard equipment.

### Accessory

The single accessory slot is the broadest build-expression slot. It can carry
one resource, targeting, combo, mobility, or elemental-resonance idea, but it
must not become a universal best-in-slot stat bundle. Direct Souls/gold
multipliers are excluded from this catalogue. Pickup comfort, such as a wider
collection radius, is acceptable.

## Item anatomy

Every authored definition is documented with these layers:

1. **Base identity** — the named item and family behavior.
2. **Primary stat** — exactly one tier-scaled stat lane, except for an
   explicitly marked zero-power starter.
3. **Fixed secondary package** — a small, authored group of bonuses and visible
   tradeoffs.
4. **Derived/action effects** — an explicit effect contract, if present.
5. **Rarity** — the current Common/Rare/Epic/Legendary/Mythic ladder.
6. **Enhancement** — the existing duplicate-fusion `+0` through `+10` track.
7. **Transmutation** — a separate rare behavioral identity, when eligible.

The catalogue does not reintroduce hidden random primary affixes. The current
`quality` field remains an economic value used for price/salvage until a later
decision removes it; it must not silently change combat output.

The canonical authored record is:

```text
id
display_name
slot
family
role
primary_stat
base_bonuses
tradeoffs
derived_effects
passive_id
transmutation_pool
elemental_behavior
rarity_floor / rarity_ceiling
source_tags
minimum_run_rank / minimum_player_level
shop_eligible
fusion_group
price / salvage policy
visual_id
player_description
designer_notes
```

`ItemInstance` continues to persist only instance ID, definition ID, rarity,
quality, transmutation ID, enhancement level, and compatibility fields. A
future catalog revision must not reinterpret an owned item’s saved identity
without an explicit migration.

## Stat and derived-effect contract

The six effective attributes are:

| Attribute | Approved uses |
| --- | --- |
| VIT | Maximum HP, healing/regeneration, health-cost safety, selected shield recovery |
| STR | Physical attack power, physical Imbue portion, knockback, lunge, charge and finisher output |
| DEF | P.DEF, shield durability, guard recovery, knockback resistance, defensive effects |
| AGI | Movement, roll, run, attack/recovery timing, and selected mobility effects |
| INT | M.ATK, Triangle, and the magic portion of Imbue and elemental-slime contracts |
| MND | M.DEF and explicit magic/elemental resistance effects |

The shared calculation remains:

```text
effective attribute
  = (base + allocation + flat gear + explicit temporary flat modifier)
    × (1 + applicable gear rates)
```

Flat gear is applied before rates. The authored `primary_stat` receives the
current rarity and enhancement progression. Secondary bonuses remain limited
and visible. Adding Head and Arm does not authorize a second competing stat
calculation path.

Derived values shown by Status and Equipment are HP, P.ATK, M.ATK, P.DEF,
M.DEF, Move, Recovery, and any explicitly active guard/resource effect. Every
comparison must use the same `CombatStatSnapshot` as combat.

## Elemental gear

Elemental gear is divided into two explicit concepts:

### Imbue Resonance

An `imbue_resonance` effect is keyed by an explicit element, or by an
explicit active-aspect match condition, and applies only while the player has
an active Imbue of that matching element. It may improve the magic portion,
resource efficiency, or presentation intensity within bounded tuning limits. It never
changes the player’s current aspect, permanent binding, starter flame, or
unimbued attack into a hidden element.

### Elemental Ward

An `elemental_ward` effect is defensive mitigation supplied by Head, Body,
Shield, or a carefully chosen Accessory. It is a separate defensive modifier,
not a fake replacement for the defender’s element. The elemental matchup still
resolves once against the full combined composite result. Wards are a future
combat-contract extension and are not implied to be active in the existing
elemental-slime implementation until their tests and tuning are landed.

For an Imbued weapon hit, the established contract remains:

```text
STR physical portion -> P.DEF
INT magic portion    -> M.DEF
combine both portions
one roll / critical result
one elemental matchup against the full combined result
```

The separate elemental-slime contract remains separate from player gear. Gear
may change the player’s M.DEF when defending, but it must not route a slime
attack through the player weapon calculation.

Neutral slimes remain physical-only. Only non-neutral elemental slimes receive
the separate STR-primary plus INT-magic attack package; adding INT gear to the
player does not change that enemy contract.

## Rarity and effect budget

The current five rarity names and colors remain authoritative. Their exact
numeric values stay in the tuning/code surface until the six-slot loadout has
been simulated.

| Rarity | Catalogue promise |
| --- | --- |
| Common | Reliable base package; usually no behavior effect |
| Rare | Noticeable stat identity or one small, readable passive |
| Epic | Strong build direction or transmutation eligibility |
| Legendary | Build-defining behavior with a clear tradeoff |
| Mythic | Signature identity; not merely a larger generic stat bundle |

Package rules:

- One primary tier-scaled stat per item.
- Up to two meaningful positive secondary stats before a tradeoff is required.
- At most one ordinary passive or one transmutation identity per item.
- Effects must declare whether they stack, replace, or are unique.
- Rarity must not turn a penalty into a hidden benefit.
- Style points and direct combo score are never item stats. Gear can alter an
  action’s timing or behavior, while the player still earns Style by playing.

The current rarity implementation applies rates to positive package stats, so
the full six-slot loadout requires a budget simulation before new numerical
values are finalized. Existing items remain compatible during that review.

## Catalogue size and implementation boundary

The approved design catalogue contains 44 authored bases:

| Slot | Target bases |
| --- | ---: |
| Weapon | 10 |
| Head | 6 |
| Body | 8 |
| Arm | 6 |
| Shield | 6 |
| Accessory | 8 |
| **Total** | **44** |

All 44 entries may be designed and reviewed together. Implementation should
land them in tested batches, beginning with the two new slots and migration
support, not with every future weapon family.

## UI and readability requirements

The Equipment screen must reflect the six-slot model without returning to the
overlap problems that motivated the menu rework:

- Slot grid order is `WEAPON`, `HEAD`, `BODY`, `ARM`, `SHIELD`, `ACCESSORY`.
- The selected slot is visually distinct from the selected item.
- The upper region shows what is currently equipped.
- The lower region lists valid items for the selected slot.
- The bottom context strip shows the item’s role, exact stat delta, effect,
  rarity, enhancement, and any tradeoff.
- `EQUIP` enters item selection directly; selecting an item confirms the
  replacement without requiring a second navigation detour.
- Empty/zero-power starter items remain selectable and explain their purpose.
- Status uses derived values from the shared snapshot, including M.DEF from
  MND and any active gear effect.
- Pause exposes read-only Status and Equipment routes; hub-only transactions
  remain unavailable there.

## Save and migration requirements

The catalogue expansion must preserve current progress:

1. Translate old `armor` item definitions to `body` at the catalog boundary.
2. Translate `equipped_instance_ids["armor"]` to `body` without losing the
   equipped item.
3. Add `head` and `arm` keys as empty or starter-only items for existing saves.
4. Preserve all item IDs, rarity, enhancement, transmutation, and Souls/gold.
5. Keep legacy `speed`/`SPD` readers until all authored data and UI are on AGI.
6. Reject an invalid new definition safely rather than deleting an inventory
   item.

## Definition of done for the catalogue design

The two zero-power starter rows are the explicit exception to the one-primary
stat rule: their primary_stat is none, their base_bonuses are empty, and their
purpose is to make Head and Arm visible without granting free power.

The documentation pass is complete when (with the explicit zero-power starter
exception described above):

- all 44 entries have a slot, family, role, primary stat, package, effect
  budget, source tags, and player-facing description;
- every effect has one owner, one stacking rule, and one test contract;
- every new stat or resource hook is identified as existing or future work;
- old four-slot and random-affix instructions are clearly superseded;
- the drop tables explain how every slot can be acquired without flooding the
  inventory; and
- implementation can proceed without inventing missing rules in code.
