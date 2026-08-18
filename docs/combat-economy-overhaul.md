# Combat & Economy Overhaul

> Status: **Implemented - playtest pending**
> Branch: `agent/script-consolidation`
> Scope: player gear value, base stats, enemy/boss difficulty, and the
> automated safety net around all of it.

This is the current flagship overhaul of Tiny Demons. The game is fun and
playable in its present state; the goal here is to make **gear feel
impactful**, make **difficulty scale honestly** so progress is earned, and
make every change **verifiable headless** so nothing silently regresses.

---

## Why now

Three problems were confirmed during the repo audit (see
`docs/script-consolidation-plan.md`, milestones M0-M9):

1. **Gear primary stats do nothing.** `equipment_component.gd` converts item
   bonus points to `% * 0.01`, then `combat_stat_snapshot.gd` does
   `roundi(base_stat * bonus)`. At any realistic stat value this rounds to
   **zero**, so VIT/STR/DEF bonuses are cosmetic. Only `health_rate` and
   `damage_rate` have any effect.
2. **Player outpaces enemies.** With the player near level 10, level 16-20
   slimes are trivial and the boss dies too quickly.
3. **No safety net.** Two of three smoke tests referenced renamed fields
   (`damage_bonus`, `gear_health`) and were red at HEAD; nothing caught it
   because no headless runner existed.

## Locked decisions

- Player base stats start **lower**: 3/2/2 (VIT/STR/DEF) instead of 4/3/3.
- Gear bonus per primary-stat point is at least **25%**, with a **1-point
  floor** so even a 3-base-stat player feels a +1 item.
- Gear bonuses may exceed **100%**; the game is rebalanced so that is
  intended and fair, not accidental inflation.
- Enhancement/leveling gear raises its % further, so upgrading feels
  impactful.
- Enemies and the boss are **buff**ed to scale with the player's new power.
- The three smoke tests are fixed and run headless (already done); a runner
  script is wired into `tests/`.

---

## Pre-overhaul numbers (baseline)

### Player
- Base stats: `base_vit 4 / base_str 3 / base_def 3`
  (`player_profile.gd:20-22`, `stats_component.gd:44-46`).
- Archetype presets (`stats_component.gd:118-143`):
  - BALANCED 4/3/3, FAVOR_VIT 6/3/1, FAVOR_STR 3/6/1, FAVOR_DEF 4/1/5.
- Archetype selection copies the chosen preset into profile base stats
  (`screen_state_controller.gd:start_selected_archetype`).

### Gear scaling (the broken part)
- `item_catalog.gd:bonuses()` returns raw points (e.g. sword `strength: 1.0`).
- `equipment_component.gd:60-66` multiplies primary stats by `0.01`
  (`strength_bonus += points * 0.01`).
- `combat_stat_snapshot.gd:22-24` computes `gear_X = roundi(base_X * bonus)`.
- Result: `roundi(36 * 0.02) = 0` at endgame; **always zero**.

### Combat math
- `combat_tuning.gd`: `health_base 8`, `health_per_vit 4`,
  `health_per_level 5`, `health_vit_core_rate 0.03`, `damage_base 2`,
  `defense_scale 12`, roll `0.85-1.15`, crit `10% / 1.5x`.
- Health = `(base + (lvl-1)*5) + vit*4 + (vit-based)`, scaled by
  `(1 + gear_health_rate)`.
- Damage = `(2 + attacker STR) * (1 + gear_damage_rate) * def_factor * roll`.

### Enemy scaling
- `_enemy_level_for_room()` = `max(1, ceil(room_depth / 2))`
  (`gameplay.gd:960`).
- `_enemy_level_cap_for_run()` = `7` until run rank 10, then unlimited
  (`gameplay.gd:961-964`).
- `_run_enemy_level_bonus()` = `0` (`gameplay.gd:965`).
- Boss depth: `target_boss_depth = 12 + min(completed_runs, 8)`
  (`dungeon_graph.gd:132`).
- Slime archetypes: blue = FAVOR_DEF, red = FAVOR_STR, green = FAVOR_VIT
  (`gameplay.gd:972-976`).

### Item economy
- Rarity power multipliers: common 1.0, rare 2.2, epic 4.84, legendary
  10.648, mythic 23.4256 (`item_catalog.gd:16-22`). Each tier is 2.2x the
  previous so a +10 item (2.0x) always stays below the next tier's +0.
- `MASTERY_BONUS_PER_LEVEL = 0.05`; enhancement raises implicit by 5% per
  level up to `MAX_ITEM_ENHANCEMENT = 10` (`item_catalog.gd:14`,
  `player_profile.gd:7`).

---

## Design targets

### 1. Player base stats 3/2/2 (done)
- `player_profile.gd`: `base_vit := 3`, `base_str := 2`, `base_def := 2`
  (incl. save fallbacks `player_profile.gd:298-300`).
- `stats_component.gd`: `manual_base_vit := 3`, `manual_base_str := 2`,
  `manual_base_def := 2`.
- `stats_component.gd:base_points` lowered `10 -> 7` so the archetype base is
  not padded back up to 10 by random growth allocation at start.
- Archetype presets (`stats_component.gd:_base_profile_values`), all sum to 7:
  - BALANCED **3/2/2**, FAVOR_VIT **4/2/1**, FAVOR_STR **2/4/1**,
    FAVOR_DEF **3/1/3**.

### 2. Gear primary-stat scaling: 25% per point, 1-point floor (done)
- `equipment_component.gd`: primary stats `* 0.25` (each item point = 25% of
  base stat). Shield `strength_penalty` also `* 0.25` to keep the trade-off;
  `health_rate`/`damage_rate` keep their existing `* 0.01` rate scaling
  (incl. shield `damage_penalty`).
- `combat_stat_snapshot.gd:_gear_points` applies the **1-point floor**:
  `0 if bonus <= 0 else maxi(roundi(base * bonus), 1)`.
- No upper clamp on bonuses: 100%+ is allowed by design.
- Example (base STR 3, +1 STR sword): `3 * 0.25 = 0.75` -> floor to **1**
  point. Base STR 36, +3 sword: `36 * 0.75 = 27` -> **27** points.
- Starter loadout now yields real stats at a 3/2/2 base: +1 VIT / +2 STR /
  +2 DEF, plus HP/DMG rates unchanged (0.15 / 0.03).

### 3. Enhancement feels impactful (done)
- `MASTERY_BONUS_PER_LEVEL` raised `0.05 -> 0.10`: each fusion level adds 10%
  of the item's implicit package (matches the pre-existing `bonuses()`
  comment). Both `item_catalog.bonuses()` and `shield_bonuses()` scale.

### 4. Enemy & boss difficulty (done)
- `_enemy_level_for_room()`: `ceil(depth / 2)` -> **`max(1, ceil(depth / 4))`**
  (`gameplay.gd:993`). Depth 12 -> 3, depth 20 -> 5.
- Pre-rank-10 cap raised from flat `7` to **`999 if rank > 10 else 2 + rank`**
  (`gameplay.gd:994`): R1 cap 3, R5 cap 7, R10 cap 12.
- `_run_enemy_level_bonus()`: `0` -> **`max(0, run_rank - 8)`** so late runs
  (R9+) add real pressure on top of the depth curve.
- Boss: `_generate_boss_encounter` boss level uses the same
  `max(1, ceil(depth / 4))` curve (`room_controller.gd`); first-run boss room
  (depth 12) now spawns the boss slime at level 4 (boss_level 3 + 1, was 7).
  Boss room slimes still receive `difficulty_bonus` via
  `_apply_enemy_room_level`, so later runs scale further.

### 5. Automation (safety net) (done)
- Fixed the two stale smoke tests (`progression_smoke.gd`,
  `item_economy_smoke.gd` now assert the current stat model and pass).
- Added `tests/run_all_smoke.ps1`: runs all three SceneTree tests headless
  plus the main-scene `--quit-after 30` check and reports per-test exit
  codes.
- Every balance change re-runs: main-scene headless run, and all three smoke
  tests (`pwsh -File tests/run_all_smoke.ps1`).

---

## Verification (always)

Godot console build (available):
```
& "C:\Development\Tiny-Demons\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Development\Tiny-Demons\TinyDemons"
```
- Main scene 120-frame run: zero errors/warnings.
- Smoke tests (exit 0):
  - `-s res://tests/run_grade_smoke.gd` -> `RUN_GRADE_SMOKE_OK`
  - `-s res://tests/progression_smoke.gd` -> `PROGRESSION_SMOKE_OK`
  - `-s res://tests/item_economy_smoke.gd` -> `ITEM_ECONOMY_SMOKE_OK`

Smoke tests include a watchdog so a mid-script assertion aborts with exit 1
instead of hanging.

---

## Fusion redesign (target-centric)

> Status: **Implemented - verified headless**

The old fuse flow consumed a *selected duplicate* and upgraded whichever
surviving item shared its definition. Cost was a flat 20G per fuse regardless
of the target's state, so a full +10 upgrade cost the same as a single step.
The redesign makes the hub FUSE tab explicit and honest:

- The player browses **targets**: any item with upgrade capacity and at least
  one eligible material, plus overflow items at mythic +10.
- A target may be **equipped** (upgrading equipped gear is the primary case);
  only *materials* must be unequipped.
- Materials are non-equipped items sharing the target's `definition_id` and
  rarity. `fusion_material_count(target)` caps eligible duplicates at the
  target's remaining upgrade capacity (`max_fusion_steps`).
- The player chooses a **batch count** (left/right in the FUSE tab) up to the
  available material count. `fusion_batch_cost(item, count)` sums per-step
  costs, so the price scales with the target's enhancement: +0 -> +1 costs
  `FUSION_BASE_COST` (20G), +1 -> +2 costs `+FUSION_COST_PER_ENHANCEMENT`
  (15G more), and the step cost resets to the base rate after a rarity bump.
- `fuse_duplicates(target_id, count)` validates gold and materials, applies
  each step to a working copy (enhancement up to +10, then rarity bump to
  +0), consumes exactly the requested materials, charges the summed cost, and
  emits `changed`.
- Overflow mythic +10 items that no longer upgrade remain listable for
  **SALVAGE** (`can_salvage_overflow` / `overflow_salvage_value`).

New API in `player_profile.gd` (replaces the removed
`can_fuse_duplicate`/`fuse_duplicate`):

- `max_fusion_steps(item)` - steps to reach mythic +10 from the item's state.
- `fusion_material_count(target_instance_id, catalog)` - eligible material
  count (0 when full or no materials).
- `fusion_batch_cost(item, count)` - summed per-step gold cost.
- `fuse_duplicates(target_instance_id, count, catalog)` - validates + applies
  a batch upgrade.

### Hub UI (screen_state_controller.gd)

- FUSE tab (page 3) lists targets; row label shows the target's enhancement.
- Detail area shows `FUSE xN  costG  HAVE n  +x -> +y` with the live batch
  cost and final-enhancement projection; overflow rows show
  `MYTHIC +10  SALVAGE nG`.
- Action button reads `FUSE xN` / `SALVAGE` and is disabled when there is no
  valid action or gold is insufficient (message `NEED nG`).
- Left/right adjusts the batch count (`_shift_hub_fusion_count`); page and
  item changes reset it to 1.

### Smoke coverage (`tests/item_economy_smoke.gd`)

Asserts material counting (equipped target vs. unequipped materials), batch
cost at base rate, fusion consuming exactly the requested materials and
charging the target-scaled cost, enhancement applied to the target, no
materials remaining afterward, a failed fuse with zero materials, and that
cost scales with target enhancement.

---

## Task list

- [x] Base stats 3/2/2 (`player_profile.gd`, `stats_component.gd` + archetypes
      + `base_points` 7)
- [x] Gear primary-stat `* 0.25` + 1-point floor (`equipment_component.gd`,
      `combat_stat_snapshot.gd`)
- [x] Enhancement scaling bump `0.05 -> 0.10` (`item_catalog.gd`)
- [x] Enemy level/difficulty buffs (`gameplay.gd`)
- [x] Boss level buff (`room_controller.gd` boss encounter)
- [x] Update smoke-test expected values to new balance; verify headless
- [x] Wire `tests/run_all_smoke.ps1` runner (all three + main scene)
- [x] Update `docs/gameplay-smoke-checklist.md` expectations
- [x] Fusion redesign: target-centric API (`player_profile.gd`)
- [x] Fusion redesign: hub FUSE tab UI (gameplay.gd, screen_state_controller.gd)
- [x] Fusion redesign: smoke-test assertions for target/batch/cost scaling
- [ ] Playtest pass (manual) - tune enemy HP / boss health / shield penalties
      against the new power curve

## Related docs

- `docs/script-consolidation-plan.md` - architecture consolidation (M0-M9).
- `docs/gameplay-smoke-checklist.md` - manual behavior baseline.
- `docs/meta_progression_design.md` - hub/progression design.