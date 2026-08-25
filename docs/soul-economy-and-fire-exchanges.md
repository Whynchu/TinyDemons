# Soul Economy and Fire Exchanges

This document records the first implementation of Souls as the persistent
currency for fire services and equipment fusion.

## Enemy drops

- Every defeated enemy drops one Soul.
- Souls use a generated 9x9 nearest-filtered diamond sprite for now.
- The pickup launches, lands, bobs, and auto-collects like a Chroma pickup.
- Collected Souls are saved on `PlayerProfile`, so they survive room changes
  and are available when the player returns to the hub.
- Uncollected Soul sprites are room-local and are cleared during a room change.

## Shadow encounters and mana recovery

The purple palette is displayed as **Shadow Slime**. The grey palette is
displayed as **Normal Slime**. If a generated encounter contains a Shadow
Slime, every popcorn slot in that encounter is forced to Normal Slime. Shadow
itself is never selected as a popcorn roll, so the pressure enemy remains
present while the low-level mana-recovery opportunity stays readable.

Normal Slimes continue to use the existing neutral Chroma drop chance. This
means a player who is low on mana has a reliable chance to find a neutral
pickup in the encounter without changing the broader Chroma economy.

## Fire services

Interacting with an earned fire is one atomic use costing **10 Souls**. The
single use simultaneously:

1. Heals missing HP to full.
2. Refills the active Chroma bar to full.
3. Attunes the player to the fire's element.

A fire does not heal or refill passively, and the first starter-flame
attunement is not free. On the first run, if the player has fewer than 10
Souls, the Cloaked Demon gives them a one-time 10-Soul starter grant during
their tutorial dialogue. The player then spends those Souls at the starter
fire to begin the run.

## Equipment fusion

Fusion uses a stepped Soul ladder:

- Common +0 -> +1 costs 1 Soul.
- Each enhancement step increases the cost by 1 Soul.
- The common +10 -> rare +0 transition costs 10 Souls.
- Rare +0 -> +1 costs 11 Souls, and the same progression continues through
  later rarities.
- Gold remains the currency for shops, chest rewards, respec, and overflow
  salvage.

The hub FUSE page shows Soul costs and the current Soul balance, and the world
HUD shows a purple coin icon with the Soul balance beside the existing gold
display.

## Verification

- `tests/rogue_slime_smoke.gd` covers Shadow/Normal popcorn composition.
- `tests/soul_pickup_smoke.gd` covers the 9x9 sprite and persistent collection.
- `tests/item_economy_smoke.gd` covers profile persistence and Soul-paid fusion.
- `tests/fire_exchange_smoke.gd` covers the one-time starter grant and the
  fixed 10-Soul atomic fire service.
- `tests/generated_run_scene_smoke.gd` covers a paid alternate fire attunement.
