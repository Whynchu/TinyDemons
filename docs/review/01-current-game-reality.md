# Current Game Reality

This is an implementation inventory, not a wish list.

## Implemented game surface

Tiny Demons currently includes:

- Title, save selection, Demon Hub, dungeon, settlement, and restart flow.
- Directional attacks, combo attacks, charged attacks, spin attack, roll, guard, target lock, knockback, hit reactions, hitstop, and combat feedback.
- Slime combat with wandering, targeting, aggro, variants, respawn, health presentation, and boss jump/slam behavior.
- Elemental Chroma casting, Soul pickups, binding, fusion, matchup behavior, and starter-flame flow.
- Room progression, authored dungeon runs, generated continuation, chests, rewards, gold, XP, Souls, grades, mastery, and equipment.
- Six-stat progression and six equipment slots with enhancement, rarity, effects, fusion, salvage, and Hub transactions.
- Authored HUD, cooldown presentation, device-aware prompts, keyboard/controller/mouse/touch input, responsive landscape presentation, and web export.
- Local, browser, active-run, and optional cloud-save boundaries.

## Not yet equivalent to the full vision

The following are design directions or incomplete content systems rather than fully realized player-facing features:

- Full elemental class/loadout trees with regular magic, held magic, held attack, passives, and cross-element mastery.
- Broad roster coverage for melee, ranged, healer, and airborne enemies beyond the current slime-focused foundation.
- A complete library of distinct biomes with strong enemy, puzzle, and visual identities.
- A mature room grammar combining combat, keys, switches, carried orbs, optional elemental routes, traps, choices, and rewards.
- A complete production-grade enemy-definition/factory pipeline for adding new enemies without central special cases.
- Proven Samsung A17 performance and real-device budgets.

## Current engineering checkpoint

- Composition audit: 100% strict scorecard.
- Dynamic `root.call/get/set`: 2,202 sites, below the 2,499 threshold.
- `GameplayState`: 1,718 lines / 286 fields.
- `RoomController`: 2,248 lines.
- Editor composition: 100% for measured components and definitions.
- Test manifest: 134 rows, 132 runnable paths, 43 curated release-gate paths.

These numbers indicate structural readiness, not finished content or guaranteed performance.

