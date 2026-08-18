# Meta Progression, Equipment, and Hub Design

## Status

**Proposal — discussion first.** This document defines the intended direction and
the smallest version worth building. It does not authorize implementation until
the open decisions are resolved.

## Vision

Tiny Demons should combine skill-first isometric action with a persistent gear
chase. A player clears dungeon rooms, finds useful equipment and resources,
then returns to a hub to compare builds, equip items, enhance duplicates, and
prepare for the next run.

The core promise is simple: a drop should be easy to understand immediately,
but rare enough that players stay curious about the next one.

## Two Connected Loops

```text
HUB / META LOOP
Prepare build -> Start run -> Return after victory, extraction, or death
      ^                                                        |
      +-- Equip, compare, buy, fuse, and optionally transmute-+

IN-RUN LOOP
Choose route -> Fight -> Find gear/gold/temporary power -> Shop or rest -> Boss
```

### Persistence model

Recommended model: **soft roguelite**.

- Persistent: equipped items, collected equipment, duplicate items, fusion
  materials, account-level gold, and player level/experience.
- Run-only: temporary boons, consumables intended for that run, and any
  floor-only currency if it is later added.
- Death ends the run but does not erase the player’s gear progress.

This keeps action skill relevant while respecting the time spent searching for
equipment.

### Death, return, and run completion

When player health reaches zero, end combat input, show a short defeat result,
then transition out of the dungeon. The default destination is the hub. The
title screen remains available as an explicit menu choice from the hub/result
screen, not as the automatic destination after every death.

```text
Player death
  -> defeat presentation
  -> settle persistent rewards and discard run-only state
  -> return to hub
  -> inspect/equip/fuse/shop/start another run
```

The result screen should clearly list what was retained and what was lost.
This prevents the soft-roguelite rule from becoming confusing: found permanent
equipment, gold, materials, and player experience are kept; temporary boons
and run-only consumables are removed.

Boss victory and voluntary extraction use the same reward-settlement boundary,
then return the player to the hub. A title-screen return is always safe after
settlement and must never silently discard unprocessed permanent rewards.

## Player Level: Persistent Character Progression

Player level and experience persist across runs and death. This creates a
second long-term progression layer alongside equipment:

| Layer | Persists? | Main purpose |
| --- | --- | --- |
| Player level / XP | Yes | Predictable character growth and long-term goals |
| Equipment | Yes | Build identity, loot chase, and customization |
| Fusion upgrades | Yes | Productive use for duplicate gear |
| Gold / materials | Yes | Purchase and crafting choices |
| Run boons / consumables | No | Short-term tactical adaptation |

Level growth should remain dependable and modest. It can raise the player’s
core stat budget and health ceiling, while equipment supplies more specific
build decisions. Neither layer should completely replace the other:

- A skilled player with starter equipment and a lower level can still progress.
- A high-level player feels stronger, but cannot ignore enemy patterns.
- A good weapon can change a build even when the player is already high level.

Existing XP granted per defeated slime can feed this persistent progression.
Level-up health should continue to preserve the current health percentage, not
act as a free full heal. The hub/rest recovery rules remain the deliberate
health-management tools.

### Manual stat allocation

Level growth is player-directed. The current automatic Balanced/Favor VIT/
Favor STR/Favor DEF growth profiles may remain as optional auto-allocation
presets, but manual allocation is the default.

Each level grants a bounded number of stat points. The award grows at later
levels so infrequent late-game level-ups still feel meaningful, but it never
exceeds five points for one level.

| New character level | Provisional points awarded |
| --- | ---: |
| 2–5 | 1 |
| 6–10 | 2 |
| 11–20 | 3 |
| 21–35 | 4 |
| 36+ | 5 |

These bands are tuning data, not hard-coded design constants. Final bands must
be chosen after establishing the expected level at each boss and the long-term
level cap. Later levels should require proportionally more XP; progression is
balanced around stat points earned per hour rather than levels per hour.

Unspent points never expire and have no storage cap. If a player levels during
combat, level and Core HP apply immediately, current health percentage is
preserved, and the points are banked. Allocation is presented after the room is
safe, at a rest point, or in the hub so a level-up never interrupts combat.

Full respec is available in the hub for ordinary gold. Early respecs should be
free or inexpensive so an exciting equipment drop can inspire a new build.

### Stat identity

- **VIT** scales maximum health from the character's level-based Core HP, plus
  healing, regeneration, health-cost effects, and selected shield recovery.
- **STR** scales weapon output, attack knockback, lunging, combo finishers, and
  offensive transmutations.
- **DEF** scales damage mitigation, shield durability, guard recovery,
  knockback resistance, counters, and defensive transmutations.

DEF should support active shield play instead of existing only as passive
damage reduction.

### Stat calculation pipeline

Stats are calculated once through an explicit, non-recursive pipeline:

```text
Innate stats + allocated points + flat equipment stats
  = Effective VIT / STR / DEF

Core HP(level)
  × (1 + Effective VIT × VIT rate + additive Core-HP equipment bonuses)
  + flat equipment HP
  = Maximum HP

Item base output
  + Effective STR × item STR scaling
  + Effective VIT × item VIT scaling
  + Effective DEF × item DEF scaling
  = Item output before conditional effects
```

Bonuses in the same percentage category are added before being applied. No item
may repeatedly multiply a total that already contains its own bonus. This keeps
scaling understandable and prevents recursive power growth.

Level-based Core HP is intentional: every level makes the character sturdier,
while VIT becomes increasingly valuable because it scales that growing base.
Equipment can then favor Core HP, VIT effectiveness, or flat early-game health
without making those bonuses interchangeable.

## Equipment Model

### Slots

The final system supports the existing four equipment slots:

- Weapon
- Armor
- Shield
- Accessory

Each slot must have its own stat vocabulary and gameplay identity. Not every
modifier should be legal on every slot.

| Slot | Primary purpose | Early modifier examples |
| --- | --- | --- |
| Weapon | Offensive identity | strength, attack damage, critical chance, attack effect |
| Armor | Survivability | maximum health, defense, roll recovery |
| Shield | Guard play | defense, guard window, block reward |
| Accessory | Build twist | health, strength, economy, utility |

### Item anatomy

Every item has five readable layers:

1. **Base item** — authored identity, such as Short Sword, Basic Shield, or
   Bangle. The base is reliable and understandable.
2. **Rarity tier** — determines baseline strength and modifier count.
3. **Modifiers (affixes)** — randomized bonuses from the allowed slot pool.
4. **Upgrade level** — a deterministic duplicate-fusion track, shown as `+0`
   through a capped value.
5. **Special effect** — a rare build-defining property reserved for later
   tiers/content.

Every authored item also has a visible scaling profile. Scaling ranges may roll
within narrow authored limits, but random generation cannot erase the base
item's identity. A STR sword may roll from C to A STR scaling; it cannot become
a pure VIT weapon unless that is an authored version of the item.

```text
Guardian Sword
STR: C
VIT: -
DEF: B
```

The comparison UI presents both the readable grade and the exact projected
change for the current character.

The current `Basic Sword`, `Basic Tunic`, `Basic Shield`, and `Bangle` remain
valid starter bases. Their bonuses move into item definitions rather than
being hard-coded as the player’s permanent loadout.

### Tiers

Start with three tiers:

| Tier | Modifier count | Role |
| --- | ---: | --- |
| Common | 0–1 | Reliable baseline, familiar bases |
| Rare | 1–2 | First interesting build decisions |
| Epic | 2–3 | Meaningful chase items |

Legendary and set-like items are deliberately deferred. They should arrive
only after rarity, affix readability, and balance have proven themselves.

### Randomness rules

- Bases are hand-authored; randomness is layered on top.
- Affixes must be slot-restricted and have compatible stat ranges.
- A rare item should never be merely “higher numbers”; at least some affixes
  should change how the player approaches combat.
- Avoid universal all-purpose modifiers. A shield should not compete with a
  weapon by rolling the same best damage effects.
- The inspect screen always displays the base, tier, upgrade level, exact
  modifier values, and a comparison to the currently equipped item.

## Acquisition and Economy

### In-run rewards

- Combat rooms can directly drop identified equipment. This is recommended for
  the first version because it makes drops exciting and understandable.
- Chests provide gold and can later have a small chance to provide equipment.
- Bosses should have a better chance for high-tier or unique rewards, but must
  not be the only viable source of progress.
- Temporary boons remain distinct from permanent equipment.

### Shops

The hub merchant is the first shop. Certain dungeon floors can later host a
smaller run shop using the same catalog and purchase boundary.

Recommended initial stock:

- Reliable starter/basic items, so bad luck never blocks a build.
- One rotating randomized premium equipment item.
- A small number of healing or run-only utility goods when consumables exist.

Use existing gold as the initial currency. Add a fusion material only if it is
needed to pace upgrades; do not add currencies simply to make the system look
deeper.

### Fusion and transmutation

These are intentionally separate mechanics:

- **Fusion:** consume matching duplicates to improve the mastery of that
  equipment family, initially `+0 -> +3`. Family mastery applies to every
  current and future instance of that authored base, so finding a better random
  roll never invalidates previous fusion investment. Mastery improves base
  item output, not every multiplicative modifier.
- **Transmutation:** a build-defining behavioral effect found on eligible high
  tier items or applied through a later controlled process. Transmutations
  react to real combat events and are distinct from ordinary numeric affixes.
  Rerolling a transmutation may be added later, but risky rerolling must never
  replace fusion as the dependable path.

### Transmutation design language

Tiny Demons transmutations should use the combat rules that already define the
game: attack variants, combo timing, lunging, directional hit shapes,
multi-target damage sharing, directional guard, shield durability/breaking,
rolling, target lock, knockback, health thresholds, and room performance.

Initial examples:

- **Gathering Edge (weapon):** after Attack 1 hits multiple enemies, Attack 2
  divides its damage less severely among those same targets. Its output scales
  with STR.
- **Defiant Edge (weapon):** a successful frontal block arms the next Attack 2,
  which consumes the charge for additional DEF-scaled damage.
- **Blood Rhythm (weapon):** Attack 2 may spend current health for additional
  VIT-scaled damage but can never reduce the player below one health.
- **Bastion Core (shield):** DEF scales shield durability; successful frontal
  blocks store charges consumed by Attack 2 for knockback.
- **Living Bulwark (shield):** VIT improves shield regeneration delay and rate,
  trading away some maximum durability.
- **Shatterguard (shield):** breaking the shield knocks back enemies in front,
  but increases the break-recovery time.
- **Bloodwoven Tunic (armor):** grants a percentage of Core HP and improves
  VIT's contribution while providing little DEF.
- **Anchorplate (armor):** improves DEF and knockback resistance but shortens
  attack lunges.
- **Duelist Seal (accessory):** attacks gain STR scaling against the locked
  target and lose some effectiveness against other enemies.
- **Crowd Idol (accessory):** attacks divide multi-target damage less severely
  but deal less damage against a lone target.
- **Pilgrim's Knot (accessory):** clearing a room without health damage grants
  a temporary next-room bonus; shield durability damage is allowed.

Ordinary affixes provide readable numerical texture. Transmutations should
change a decision, create a trigger chain, or introduce a tradeoff.

## Hub Responsibilities

The hub is a calm preparation space, not another combat room. Its first
features should be:

1. Build screen: show equipped Weapon/Armor/Shield/Accessory and final stats.
2. Inventory: inspect, compare, equip, and retain collected items.
3. Merchant: buy basic equipment and one rotating premium item.
4. Fusion station: added only after duplicate inventory is working.
5. Run start: enter the dungeon with the chosen persistent build.

The current dialogue/shop concept remains useful for merchant interaction:
`dialogue -> browse -> inspect -> confirm purchase -> result -> browse/leave`.

## Technical Foundation

Before content expands, create data-driven boundaries:

```text
RunState
  - current run boons, run-only items, floor state, active run state

ProfileState
  - player level and XP, account gold, persistent inventory, equipped item IDs,
    fusion resources, unlocks

ItemDefinition (authored data)
  - base identity, slot, base stats, art, permitted affix pool

ItemInstance (generated/persistent data)
  - instance ID, definition ID, rarity, rolled affixes, upgrade level

AffixDefinition (authored data)
  - permitted slots, stat/effect, value range, rarity weighting

Economy / Inventory boundary
  - validates grants, purchases, equips, fusion, and persistence exactly once

Run settlement boundary
  - commits persistent rewards, clears run-only state, and returns to hub/title
```

Combat reads the equipped item instances and derives player bonuses through a
single stat-calculation path. UI and shops must request mutations through the
inventory/economy boundary; they must not change player stats or gold directly.

## First Vertical Slice

Do not build the whole system first. Validate the loop with:

- Persistent profile, inventory, and a menu-based hub equipment screen.
- Infrastructure for all four slots, with weapon-first content depth.
- Three authored weapon bases with clearly distinct stat focus or behavior.
- Common, Rare, and Epic tiers.
- Four to six weapon-only affixes.
- Direct weapon drops from combat rooms.
- One hub merchant with basic stock and one rotating premium item.
- Equip/compare flow that changes real combat stats in the next run.
- Equipment-family duplicate fusion from `+0` to `+3`.
- One proven transmutation hook in each equipment slot, using placeholder item
  content where final artwork is unavailable.
- Manual VIT/STR/DEF allocation with the capped point-award schedule.
- Death settlement and return to hub/title with level, XP, gold, equipment, and
  allocations retained.

Explicitly out of scope for this slice:

- Transmutation.
- Floor shops.
- Legendary tiers, sets, item identification, or multiple crafting currencies.
- A walkable hub scene; the first hub is a complete menu flow.
- Broad content production beyond the minimum items needed to test every slot.

### Slice success criteria

After one short run, a player can level, bank and allocate points, find an item,
understand whether it is better or differently useful, equip it in the hub, and
feel both the allocation and item scaling in the next run. A duplicate has an
obvious family-fusion use rather than feeling like junk. Death safely returns
the player to the hub without losing persistent progression.

## Balancing Principles

- Combat skill must remain sufficient to progress with starter gear.
- Gear expands viable approaches; it must not become a mandatory stat check.
- Permanent gains should be noticeable but incremental.
- Player level provides reliable baseline growth; items provide the more
  expressive build-changing growth.
- Gold, drops, duplicates, and fusion materials must each have distinct value.
- Use telemetry/debug displays during development: rarity acquired, affix
  frequencies, time to first upgrade, shop purchase rate, and boss win rate.

## Open Decisions Before Implementation

1. Confirm soft-roguelite persistence on death.
2. Confirm that death, boss victory, and voluntary extraction return to the
   hub by default, with title return as an explicit safe option.
3. Confirm the provisional point-award bands after deciding target boss levels
   and the long-term level cap.
4. Confirm direct, identified drops for the first version.
5. Define the three first weapon bases and what makes each play differently.
6. Define the initial weapon-only affix pool and forbidden combinations.
7. Decide whether family fusion costs only matching duplicates or also a small
   gold amount.
8. Decide whether the hub shop’s rotating premium item refreshes per run,
   per boss clear, or by real-world time. Recommendation: per run.
9. Confirm the menu-based hub for the first implementation; treat a walkable
   hub as a later presentation upgrade.

## Independent Review Notes

An independent systems review supported the direction and highlighted three
risks:

1. Too many progression layers at once can make strength changes unreadable.
2. Gold, drops, duplicates, stock, and materials can create an inflated,
   interchangeable economy.
3. Permanent gear can either dominate run balance or feel irrelevant.

The resulting guardrails are: build content deeply for the weapon slot first,
keep the other three slots to the minimum needed to prove the shared pipeline,
retain gold plus duplicates as the only initial progression inputs, make base
combat viable with starter gear, and expand transmutation content only after
the vertical slice is fun.
