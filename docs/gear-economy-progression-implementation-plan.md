# Gear Economy and Progression Implementation Plan

Status: historical balance proposal; current gear contracts are in
`gear-catalogue-spec.md`, `gear-effect-contracts.md`, and `gear-drop-tables.md`

Updated: 2026-09-11

The numerical experiments below remain useful for balance review. They are not
an active implementation checklist until explicitly reopened against the
`0.2.x` baseline.

## Goals

- Keep R1-R10 rarity odds stable, then improve them gently by ten-rank bands.
- Keep the chance of `+`, `++`, and `+++` identical across rarities; each plus independently chooses one of the six random-stat lanes.
- Make repeated rolls on the same lane stronger by rarity, while preserving the very low odds of a fully stacked `+++` package.
- Allow a successful chest to award 1–4 gear items, with 3–4 remaining uncommon at low rank.
- Scale buy and sell value by a stronger rarity ladder.
- Make a second same-row touch on Fusion act as SELECT without changing Shop or other menus.
- Make Fusion enhancement growth monotonic across rarity promotion and apply each enhancement point to the item’s authored primary stat only.

## Working tuning

| Rank band | Rare | Epic | Legendary | Mythic |
| --- | ---: | ---: | ---: | ---: |
| R1–R10 | 12.00% | 0.75% | 0.10% | 0.005% |
| R11–R20 | 12.00% | 1.25% | 0.15% | 0.01% |
| R21–R30 | 12.00% | 1.75% | 0.30% | 0.02% |
| R31–R40 | 12.00% | 2.50% | 0.50% | 0.05% |
| R41–R50 | 12.00% | 3.25% | 0.80% | 0.10% |
| R51–R60 | 12.00% | 4.00% | 1.20% | 0.20% |

Rates interpolate within each post-R10 band and clamp at R60. Performance quality may improve a result within its current band but cannot bypass the band’s progression gates.

The shared plus package is 90% none, 7% `+`, 2.5% `++`, and 0.5% `+++`. Rarity changes the value of duplicate random-stat rolls, not the chance to receive them. The proposed duplicate bonus is `random_value + (random_value - 1) × rarity_rank`.

Rarity price multipliers are Common 1.0, Rare 2.2, Epic 4.84, Legendary 10.65, and Mythic 23.43. Sell remains 25% of buy value; Fusion Soul recovery remains a separate ledger.

## Work sequence and tracking

- [x] Document ownership, tuning, compatibility, and verification boundaries.
- [ ] Implement rarity bands and focused rarity tests.
- [ ] Implement shared plus rolls and rarity-weighted duplicate lanes.
- [x] Implement monotonic primary-stat Fusion enhancement storage/migration.
- [ ] Expand chest quantity to 1–4 and verify four-drop placement.
- [ ] Apply rarity price ladder and update economy tests/tuning docs.
- [x] Add Fusion-only same-row touch double-tap behavior.
- [ ] Add/extend Fusion touch regression tests.
- [ ] Run focused checks, then the appropriate Godot verification path and record results.

## Owners and safety

Rarity, plus packages, and prices belong to `ItemCatalog`; Fusion state belongs to `PlayerProfile`; chest quantity belongs to `RunFlowController` and its drop-spawn caller; touch interpretation belongs at the touch/menu boundary and must remain Fusion-scoped. Existing dirty worktree changes are preserved. No broad refactor or unrelated shop-stock change is included.

## Save and test requirements

Any new Fusion investment field must default safely for old saves and be covered by round-trip serialization tests. Tests must assert the R1–R10 floor, decade progression, identical plus distribution by rarity, stacked-stat math, 1–4 chest counts, rarity prices/sell values, and first/second Fusion touch behavior.
