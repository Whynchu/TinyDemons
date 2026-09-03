# Tiny Demons — Gear System Rework

## Status

Implemented runtime specification. The live catalogue and generation path use
this model; legacy catalogue records and saved fields remain readable only for
save compatibility.

## Goals

- Make every item readable at a glance.
- Let sets define build identity.
- Keep character starting stats neutral so gear creates specialization.
- Make strong gear powerful through clear, visible tradeoffs.
- Replace hidden and percentage-heavy item behavior with flat stats.

## Character baseline

Every player character starts with the same base profile:

| VIT | STR | DEF | AGI | INT | MND |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 2 | 2 | 2 | 2 | 2 | 2 |

Player archetype profiles such as `FAVOR_VIT`, `FAVOR_STR`, and `FAVOR_DEF`
are not part of the new player path. New-game creation uses the even baseline;
legacy saved base values are preserved rather than rewritten. Enemy profiles
remain independent.

## Slots and weapon scope

The six canonical slots are Weapon, Head, Body, Arm, Shield, and Accessory.
The initial weapon scope is limited to swords and blades. Mauls, rods, claws,
and other weapon families are deferred.

## Gear tiers

| Tier | Drop frequency | Purpose | Random bonus |
| --- | --- | --- | --- |
| Plain | Most common | Empty-slot or low-power fallback | 0–3 random bonus points |
| Basic | Very common | Reliable baseline equipment | 0–3 random bonus points |
| Set | Less common | Themed build equipment | 0–3 random bonus points |

Plain gear has no authored stats, but a plus roll can give it a small random
stat package. Basic gear has small, fixed, dependable stats. Set gear carries
a clear primary identity, optional secondary stats, and explicit flat
tradeoffs. Plain and Basic should make up most drops; Set gear is the exciting
identity-driven find.

## Sets

Every set has one item in each slot. Set names are short and are prefixed to
the slot name: `Swift Boots`, `Guard Shield`, or `Arcane Robe`.

| Set | Primary path | Supporting identity | Main tradeoff |
| --- | --- | --- | --- |
| Swift | AGI | Movement | Low direct damage |
| Soldier | STR | Physical offense | Severe AGI loss |
| Guard | DEF | Protection | Reduced mobility |
| Blood | VIT | Health and risk | Reduced mobility |
| Arcane | INT | Spell output | Lower physical resilience |
| Soul | MND | Chroma and magic defense | Lower physical output |
| Edge | AGI | STR and precision offense | Low DEF |
| Oath | DEF/VIT | Reliable all-rounder | Lower specialization |
| Rune | STR/INT | Brutal battle-mage offense | DEF −3, MND −3 |

The exact per-slot packages are balance data, but each set should follow these
rules:

- The Weapon and Body carry the largest contributions.
- Head, Arm, Shield, and Accessory carry smaller supporting contributions.
- Soldier, Edge, and Rune receive the harshest tradeoffs because they provide
  strong physical or hybrid offense.
- Oath is intentionally less efficient than a specialist in exchange for
  having no severe weakness.

Rune gear uses swords or blades and combines STR with INT. It does not reduce
AGI; its weakness is physical durability and MND-based magical resilience.

## Random `+` bonuses

Any gear drop may receive one to three random bonus points. The marker appears
after the item name using the supplied 3×5 plus artwork:

The source artwork is [`Mockups/gearplus3x5.png`](../Mockups/gearplus3x5.png);
the runtime copy is [`assets/artwork/gearplus3x5.png`](../assets/artwork/gearplus3x5.png).
The pixel text renderer uses that 3×5 glyph for each marker.

| Display | Meaning |
| --- | ---: |
| `SOLDIER SWORD` | No random points |
| `SOLDIER SWORD +` | 1 random point |
| `SOLDIER SWORD ++` | 2 random points |
| `SOLDIER SWORD +++` | 3 random points |

Each point is independently assigned to any of VIT, STR, DEF, AGI, INT, or
MND. It is not restricted to the item's primary or secondary stat. Duplicate
rolls stack, and no random negative stats are generated.

The equipment detail view must show the allocation explicitly, for example:

```text
SOLDIER SWORD ++
STR +1   MND +1
```

The random allocation is locked when the item drops and is never rerolled by
fusion. This applies equally to Plain, Basic, and Set gear.

## Rarity and fusion

Rarity controls the likely plus grade, while the plus grade remains visible:

| Rarity | Expected plus range |
| --- | --- |
| Common | 0–1 |
| Rare | 0–2 |
| Epic | 0–3 |
| Legendary | 1–3 |
| Mythic | 2–3 |

Every assigned random stat grows at the same pace as the item's authored
primary stat through rarity and fusion. The growth is additive, never a
separate multiplier. A `++` item that rolled `STR +1, MND +1` keeps those same
two lanes and advances both on the primary-stat ladder.

Fusion matches items by base definition and rarity. It ignores the random `+`
package, legacy affixes, transmutations, and the target's fusion level. A
`SOLDIER SWORD +` can therefore fuse with a `SOLDIER SWORD` at the same rarity.
The target keeps its own random allocation; the material's allocation is
consumed with the material. The plus marker describes the target drop's random
point count and does not change when the item is fused. The detail panel shows
the current numeric values.

## Removed complexity

The rework does not add or preserve new gear behavior for:

- hidden percentage modifiers;
- random affix pools outside the six core stats;
- random negative affixes;
- conditional future effects;
- direct Souls, gold, drop-rate, or Style multipliers;
- weapon families outside swords and blades.

Existing saves may retain legacy fields for compatibility, but new generated
gear should use only this model.

## Example

```text
RARE SOLDIER SWORD ++
Base: STR +3
Random: STR +1, MND +1
Fusion: both random lanes grow with the authored primary ladder
Tradeoff: Soldier-set gear carries a visible AGI penalty
```
