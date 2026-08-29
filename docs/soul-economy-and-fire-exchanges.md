# Soul Economy and Fire Exchanges

This document records the implementation of Souls as the persistent currency
for flame services and equipment fusion, plus the elemental Binding/Fusion
system. The canonical rules are in
[`elemental-binding-and-fusion-design.md`](elemental-binding-and-fusion-design.md).

## Enemy drops

- Every defeated enemy drops one Soul.
- Souls use the authored 5x5 `Souls.png` sprite. The grey body is recoloured
  to the existing soul-purple currency base, while the light outline is a
  lighter highlight of that same base; the two dark eye pixels remain intact.
- The pickup launches, lands, bobs, and auto-collects like a Chroma pickup.
- Collected Souls are saved on `PlayerProfile`, so they survive room changes
  and are available when the player returns to the hub.
- Uncollected Soul sprites are room-local and are cleared during a room change.

## Shadow encounters and mana recovery

The purple palette is displayed as **Shadow Slime**. The grey palette is
displayed as **Normal Slime**. Popcorn Normal Slimes are always five levels
below the player, with a minimum level of one, so they remain intentional
gameplay fodder rather than extra challenge. If a generated encounter contains a Shadow
Slime, it guarantees at least one low-level Normal Slime popcorn slot, and
every additional popcorn slot is also forced to Normal Slime. Shadow itself
is never selected as a popcorn roll, so the pressure enemy remains present
while the low-level mana-recovery opportunity stays readable. Boss rooms also
add guaranteed Normal Slime popcorn slots beside the scaled boss: Runs 1–4
use only that neutral popcorn support, while normal/elemental minor slimes
join the boss roster starting on Run 5. The popcorn group starts at two slots
on Run 1 and adds one more support slot per run up to six.

Each popcorn slot returns five seconds after defeat while a Shadow or scaled boss remains alive;
the respawn queue is cleared as soon as that big threat is defeated.

Normal Slimes continue to use the existing neutral Chroma drop chance. This
means a player who is low on mana has a reliable chance to find a neutral
pickup in the encounter without changing the broader Chroma economy.

## Fire services

### Implemented flame services

Interacting with an earned flame is one atomic use costing **5 Souls**. The
single use simultaneously:

1. Heals missing HP to full.
2. Refills the active Chroma bar to full.
3. Attunes the player to the fire's element.

A flame does not heal or refill passively, and the first starter-flame
attunement is not free. On the first run, if the player has fewer than 5
Souls, the Cloaked Demon gives them a conditional 5-Soul starter grant during
their tutorial dialogue. The player then spends those Souls at the starter
fire to begin the run. A same-color flame is unavailable when HP and active
Chroma are already full, so a player cannot spend Souls on a no-op service.

The starter flame selected during character creation is the hub flame even
though it is not yet permanently bound. It remains the hub flame across later
runs until the player explicitly completes a permanent Bind for another
element. Temporary run attunements and Fusion results do not change that hub
identity.

### Approved elemental Binding/Fusion extension

The next elemental flame design changes the action surface as follows:

- Normal **Swap** at a flame costs **5 Souls** and changes the current element
  without changing the persistent bound element.
- **Fuse** at a flame costs **5 Souls** and uses the current element plus the
  contacted flame's element.
- A quick interaction press performs Swap; holding the interaction button
  through the short fusion threshold performs Fuse.
- Fusion does **not** require a bound element. Its result is current and usable
  immediately, but remains unbound.
- Permanent **Bind/Rebind** is available only through the Cloaked Demon and
  costs a flat **50 Souls** for every new element.
- Binding the element that is already bound is a free no-op.
- Binding updates the save-file elemental identity and hub flame, and makes the
  identity available for the approved zero-Chroma recovery behavior.
- Required elemental doors check the current element, including an unbound
  fusion result; they do not require the 50-Soul Binding payment and remain
  unlocked after being solved.
- The approved recipes are Fire + Water → Shadow, Fire + Electric → Ground,
  Water + Electric → Grass, and Grass + Water → Ice. Pairs are unordered.

This extension intentionally separates the 5-Soul route/puzzle actions from
the 50-Soul persistent commitment. See the linked design and implementation
plan for the state model, UI, save behavior, and verification gates.

## Equipment fusion

Fusion uses a stepped Soul ladder:

- Common +0 -> +1 costs 1 Soul.
- Each enhancement step increases the cost by 1 Soul.
- The common +10 -> rare +0 transition costs 10 Souls.
- Rare +0 -> +1 costs 11 Souls, and the same progression continues through
  later rarities.
- Gold remains the currency for shops, chest rewards, respec, and overflow
  salvage.

The hub FUSE and BIND pages show Soul costs and the current Soul balance with
the authored soul icon, and the world HUD shows the same icon beside the Soul
balance and existing gold display.

## Verification

- `tests/rogue_slime_smoke.gd` covers Shadow/Normal popcorn composition.
- `tests/soul_pickup_smoke.gd` covers the authored 5x5 sprite, recolour rules,
  currency headers, and persistent collection.
- `tests/item_economy_smoke.gd` covers profile persistence and Soul-paid fusion.
- `tests/fire_exchange_smoke.gd` covers the conditional starter grant, quick-press
  Swap/hold-to-Fuse gesture, and fixed 5-Soul atomic flame service.
- `tests/starter_flame_hub_scene_smoke.gd` covers starter-flame hub persistence
  across runs and replacement only after an explicit Bind.
- `tests/generated_run_scene_smoke.gd` covers a paid alternate fire attunement.
- `tests/elemental_binding_smoke.gd` covers 5-Soul Swap/Fuse, no-bound Fusion,
  flat 50-Soul Demon Binding, current/bound persistence, and unbound elemental
  door access.
