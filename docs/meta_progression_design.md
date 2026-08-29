# Meta Progression, Equipment, and Hub Design

## Status

**Foundation implemented; catalogue expansion approved.** This document retains
the broader soft-roguelite and hub direction. Detailed equipment rules now live
in [`gear-catalogue-spec.md`](gear-catalogue-spec.md), its authored list in
[`gear-catalogue.md`](gear-catalogue.md), and the associated drop/effect plans.
The original four-slot prototype is historical; new equipment work follows the
approved six-slot model.

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
combat, the level and newly banked stat points are recorded, current health
percentage is preserved, and no Core HP is added until the player spends points
on VIT or equips HP-specific gear. Allocation is presented after the room is
safe, at a rest point, or in the hub so a level-up never interrupts combat.

Full respec is available in the hub for ordinary gold. Early respecs should be
free or inexpensive so an exciting equipment drop can inspire a new build.

### Stat identity

- **VIT** scales maximum health from the character's flat Core HP, plus
  healing, regeneration, health-cost effects, and selected shield recovery.
- **STR** scales weapon output, attack knockback, lunging, combo finishers, and
  offensive transmutations.
- **DEF** scales damage mitigation, shield durability, guard recovery,
  knockback resistance, counters, and defensive transmutations.
- **AGI** scales movement, roll/run motion, attack/recovery timing, and selected
  mobility effects within bounded tuning limits.
- **INT** scales Triangle magic and the magic portion of Imbue and elemental
  slime contracts. It also controls the approved Imbue visual-intensity path.
- **MND** is the source of derived M.DEF and protects against Triangle, Imbue
  magic portions, and non-neutral elemental-slime magic portions.

DEF should support active shield play instead of existing only as passive
damage reduction.

### Stat calculation pipeline

Stats are calculated once through an explicit, non-recursive pipeline:

```text
Innate stats + allocated points + flat equipment stats
  = Effective VIT / STR / DEF / AGI / INT / MND

Core HP (level-independent)
  × (1 + Effective VIT × VIT rate + additive Core-HP equipment bonuses)
  + flat equipment HP
  = Maximum HP

Physical raw output
  = weapon/ability base + Effective STR × physical scale

Magic raw output
  = spell/ability base + Effective INT × magic scale

Composite output
  = physical portion after P.DEF mitigation
  + magic portion after M.DEF mitigation
  -> one roll/critical result -> one full-packet element matchup
```

Bonuses in the same percentage category are added before being applied. No item
may repeatedly multiply a total that already contains its own bonus. This keeps
scaling understandable and prevents recursive power growth.

Leveling is intentionally not a direct HP source: every level grants agency
through stat points, and VIT becomes the deliberate health investment.
Equipment can then favor Core HP, VIT effectiveness, or flat early-game health
without making those bonuses interchangeable.

## Equipment Model

The approved equipment model is defined in
[`gear-catalogue-spec.md`](gear-catalogue-spec.md). It has six slots:

- Weapon
- Head
- Body (the former Armor slot)
- Arm
- Shield
- Accessory

The new Head and Arm slots are zero-power starter slots initially. They add
room for INT/MND, magic defense, attack handling, charge, combo, and recovery
builds without invalidating the current starter balance. The single Accessory
slot remains the broad build-twist slot; a second Accessory, Relic, or Core slot
is not approved.

The catalogue target is 44 authored bases. Weapon families are data and
behavior tags, not automatic slots. Future Spear, Bow, Tome, Fist, Thrown,
Bell, Harp, and Dark-weapon families are documented extension points and stay
out of the drop pool until their actions, animations, and hitbox contracts
exist.

Every entry has one primary stat, a small authored secondary package, explicit
tradeoffs, source/progression tags, and a player-facing description. The
current deterministic rarity/enhancement model remains in place. Random
primary affixes are not part of the approved expansion; the legacy `quality`
field may affect price/salvage only until a future migration removes it.

Rarity is Common, Rare, Epic, Legendary, or Mythic. Rarity may strengthen the
authored package and unlock a documented passive/transmutation, but it cannot
turn a generic item into an unrelated stat bundle. Transmutations remain
separate behavioral identities and currently include Gathering Edge, Blood
Feed, Bloodwoven Core, Bastion Core, and Duelist Focus.

## Acquisition and Economy

The detailed source rules are in [`gear-drop-tables.md`](gear-drop-tables.md).
The current boundaries remain:

- Normal enemy deaths primarily provide Souls/Chroma rather than inventory
  flooding.
- Treasure chests provide identified world gear under seeded source rules.
- Run-clear rewards provide one performance-sensitive persistent gear roll.
- The hub shop provides reliable choices and a seeded premium option.
- Bosses may later use a curated unique/high-tier pool.
- Matching definition/rarity duplicates remain the dependable fusion material.
- No initial gear effect multiplies Souls, gold, or global drop rate.

The six-slot expansion adds missing-slot protection and explicit source tags so
Head and Arm items appear early enough to matter. It does not add another
currency or move reward mutation into menu presentation code.

## Hub Responsibilities

The hub is a calm preparation space, not another combat room. Its first
features should be:

1. Build screen: show equipped Weapon/Head/Body/Arm/Shield/Accessory and final
   stats.
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
  - base identity, slot, family, base stats, art, source/effect tags

ItemInstance (generated/persistent data)
  - instance ID, definition ID, rarity, quality, transmutation ID, enhancement
    level, and compatibility fields

Effect/Transmutation definitions (authored data)
  - explicit owner, trigger, stat/effect values, stacking rule, source gates,
    and player-facing text

Economy / Inventory boundary
  - validates grants, purchases, equips, fusion, and persistence exactly once

Run settlement boundary
  - commits persistent rewards, clears run-only state, and returns to hub/title
```

Combat reads the equipped item instances and derives player bonuses through a
single stat-calculation path. UI and shops must request mutations through the
inventory/economy boundary; they must not change player stats or gold directly.

## Foundation Slice and Current Expansion

The original vertical slice is complete in the current runtime: persistent
profiles, manual six-stat allocation, five rarities, identified gear, shops,
enhancement fusion, transmutations, composite combat, and the menu flow are
implemented. Its four-slot scope was appropriate for proving the pipeline but
is not the final catalogue target.

The current catalogue implementation is the approved six-slot expansion described in
[`gear-catalogue-implementation-plan.md`](gear-catalogue-implementation-plan.md):
Head and Arm are visible with zero-power starters, Armor is renamed to Body
with compatibility, all 44 rows are authored, and source/effect coverage is
integrated in tested batches. Future weapon families and future effect rows
remain gated until their combat contracts are approved.

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
- Use telemetry/debug displays during development: source and slot acquired,
  definition/rarity frequencies, time to first upgrade, shop purchase rate,
  empty-slot coverage, and boss win rate.

## Resolved Direction and Remaining Review

The following decisions are approved: soft-roguelite persistence, identified
drops, the menu-based hub, the existing fusion/economy boundary, the six-stat
model, and the six equipment slots with one Accessory. The new Head and Arm
slots use zero-power starter items, and elemental gear uses explicit Imbue
Resonance/Elemental Ward contracts without overriding the starter or bound
flame.

Remaining review belongs to the catalogue documents rather than this broad
vision page: final names, numerical packages, source weights, elemental ward
ordering, effect stacking, art coverage, and the balance simulation for a full
six-slot loadout.

## Independent Review Notes

An independent systems review supported the direction and highlighted three
risks:

1. Too many progression layers at once can make strength changes unreadable.
2. Gold, drops, duplicates, stock, and materials can create an inflated,
   interchangeable economy.
3. Permanent gear can either dominate run balance or feel irrelevant.

The resulting guardrails are: design all six approved slots with distinct
identities, implement them in tested batches, retain gold plus duplicates as
the only initial progression inputs, make base combat viable with starter gear,
and expand transmutation content only after each underlying effect is readable.
