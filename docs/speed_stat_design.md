# Speed Stat — Design & Implementation Plan

## Objective

Add **SPD** as a fourth core player stat (alongside VIT / STR / DEF). SPD is an
allocatable stat that scales all time-based player actions — movement speed,
dodge-roll distance, and attack cadence. Gear hooks into SPD:

- High-STR items carry a **speed downside**.
- Low-attack (non-damage-focused) items grant a **speed benefit**.
- **Shields** reduce speed slightly.
- **Heavy armor** (high DEF) reduces speed.
- A new set of speed-focused equipment is added.

Design guardrail: **gameplay feel must not change drastically.** Effects are
intentionally shallow so that only *large* stat deltas produce noticeable
changes — SPD must not become a runaway train.

---

## Part 1 — Understanding the Current System

### 1.1 Stat pipeline (profile → runtime → combat)

```
PlayerProfile  (persisted, save file)
   ├─ base_vit / base_str / base_def          (archetype at creation)
   ├─ allocated_vit / allocated_str / allocated_def  (hub spending)
   └─ unspent_stat_points                     (banked level-up points)
        │  gameplay.gd:_apply_profile_to_runtime (line 11)
        ▼
StatsComponent (configure_manual_growth, stats_component.gd:80)
   ├─ vit / strength / def                    (effective = base + allocated)
   └─ enum Stat { VIT, STR, DEF }             (stats_component.gd:7-11)
        │  CombatStatSnapshot.from_components (combat_stat_snapshot.gd:17)
        ▼
CombatStatSnapshot
   ├─ vit / strength / def                    (base + allocated + gear points)
   ├─ gear_vit / gear_strength / gear_def     (gear points = base * bonus)
   ├─ gear_health_rate / gear_damage_rate     (additive %)
   └─ core_health_rate_bonus / vit_health_multiplier_bonus  (transmutation)
```

**Key facts:**

- Stats are exactly **VIT / STR / DEF**. No SPD, PWR, or DMG stat exists.
- Level-up points are **banked** (`unspent_stat_points`) and spent manually in
  the hub (or via AUTO button). See `player_profile.award_xp` (line 250) and
  `gameplay.gd:_hub_auto_allocate` (line 509).
- Archetype base values + weighted random growth exist in
  `stats_component.gd:_base_profile_values` (119) and `_growth_weights` (153).
  These apply **only before character creation and for enemies**; the player
  uses `configure_manual_growth` once started.
- Save schema version is `CURRENT_SCHEMA_VERSION := 5` (player_profile.gd:4).
  **Any new persisted field requires bumping this to 6.**
- `CombatStatSnapshot` is the single read model for combat + hub UI. Adding a
  stat means threading it through every consumer.

### 1.2 Speed-relevant values today (all in `player_tuning.gd`)

| Tuning field | Value | Line | Consumed at |
|---|---|---|---|
| `speed` (walk) | 36.0 | 4 | `actor_motor.gd:28` |
| `attack_frame_time` | 0.09 | 11 | `player_animation_component.gd:86,89` |
| `between_attack_time` | 0.12 | 15 | attack finish / combo (`player_animation_component.gd:118`, `gameplay_frame_controller.gd:136`) |
| `attack2_cooldown` | 0.16 | 16 | attack2 recovery (`player_animation_component.gd:101`, `gameplay_frame_controller.gd:134`) |
| `roll_distance` | 30.0 | 18 | `player_roll_component.gd:32` |
| `roll_duration` | 0.30 | 19 | `player_roll_component.gd:32,39` |
| `roll_frame_time` | 0.05 | 17 | `player_roll_component.gd:39` |

**Consumption points for the future SPD multiplier:**

- **Movement:** `actor_motor.move_player` (actor_motor.gd:16-28) — the single
  place walk speed is applied: `input.normalized() * tuning.speed * guard_scale * delta`.
  Note the motor reads `root.get("player_tuning")` directly and has **no
  snapshot/stats link today**.
- **Roll:** `player_roll_component.start_from_root` (line 32) sets velocity
  `direction * (roll_distance / roll_duration)`. `update_from_root` (36-49)
  drives `tick_motion` with duration/frame_time. No cooldown on roll.
- **Attack cadence:** `player_animation_component.tick_coordinator_animation`
  (lines 77-130) advances frames every `attack_frame_time`; hit lands on frame
  `attack_hit_frame := 2`; on finish, `between_attack_time` / `attack2_cooldown`
  gate the next swing. `gameplay_frame_controller.gd:131-145` also sets the
  between-timer on attack end.
- **Attack lunge:** `player_tuning.gd:25-26` (`attack_lunge_distance=6`,
  `attack_lunge_duration=0.18`) drives forward momentum during a swing via
  `player_attack_component.start_lunge` (line 28).

### 1.3 Equipment → stats pipeline

```
ItemCatalog.DEFINITIONS (item_catalog.gd:26-41)
   ├─ bonuses: {"health_rate", "damage_rate", "strength", "vitality", "defense"}
   └─ shield: {"guard_durability", "guard_reduction", "strength_penalty", "damage_penalty"}
        │  ItemCatalog.bonuses(item, mastery) (line 195) — rarity package + 0.1 tier-stat point/enhancement
        ▼
EquipmentComponent.configure_from_profile (equipment_component.gd:33-85)
   ├─ health_rate_bonus / damage_rate_bonus    (÷100 → %)
   ├─ defense_bonus / strength_bonus / vitality_bonus  (×0.25 → % of base stat)
   └─ shield penalties subtracted here (lines 71-72)
        │  CombatStatSnapshot.from_components (combat_stat_snapshot.gd:17)
        ▼
snapshot.gear_* fields → formulas + hub UI
```

**Key facts:**

- Item stat bonuses for VIT/STR/DEF are **percentage points of the player's
  base stat** (`points × 0.25`, equipment_component.gd:62-67). A +1 STR item
  grants 25% of base STR. Gear points are rounded via
  `_gear_points(base, bonus) = maxi(roundi(base * bonus), 1)`.
- **Shield penalty pattern** (the model to copy for speed penalties):
  definition `shield` sub-dict carries `strength_penalty` / `damage_penalty`,
  subtracted in `equipment_component.gd:71-72`, and mirrored in
  `screen_state_controller.gd:_effective_item_bonuses` (lines 873-874) so the
  gear-comparison UI shows the true net value.
- Item drop/roll economy: `ItemCatalog.generate_item` (line 96) — rarity
  chances scale with level; affixes (`AFFIXES`, line 43) are slot-restricted
  flat bonuses; transmutations (`TRANSMUTATIONS`, line 52) attach special
  effects. New speed items slot into `DEFINITIONS` + optionally `AFFIXES`.
- There is **no heavy/light armor concept** today. Armor differs only by stat
  mix; the only mechanically-special slot is `shield`.
- Gear UI (`screen_state_controller.gd`):
  - Stats page derived panel: currently `HP`, `DEF` (2 sprites, lines 469-470).
  - Gear page: `HubGearStat0..3` panel (4 sprites, lines 510-512) showing
    `HP/VIT/STR/DEF` (fields array line 856).
  - Slot labels: `["WPN","ARM","SHD","ACC"]` (line 747).

### 1.4 Hub stat allocation

- `screen_state_controller.gd:460`: `stat_names := [&"VIT", &"STR", &"DEF"]`,
  3 rows with +/- arrows, y = `43 + index*15`.
- `gameplay.gd`: `_hub_adjust_stat` (481), `_hub_allocate_stat` (490),
  `_hub_points_remaining` (497), `_hub_confirm_stats` (498),
  `_hub_auto_allocate` patterns (511).
- `gameplay_state.gd:187-189`: `hub_pending_vit/str/def`.
- `player_profile.allocate_stat` (269-281) — match arms for VIT/STR/DEF;
  `reset_allocated_stats` (288-299); `to_dictionary`/`load_dictionary`
  (302-371).
- `_hub_auto_allocate` patterns now include SPD and a dedicated
  `FAVOR_STR_DEF` 5th pattern (`gameplay.gd:518`).

---

## Part 2 — Design Decisions

### 2.1 SPD as a core stat

- SPD is a **4th allocatable stat** with its own `base_spd`, `allocated_spd`,
  `hub_pending_spd`, `StatsComponent` enum member, snapshot field, growth
  weights, and archetype base values.
- SPD **does not** feed damage/HP formulas. It feeds the action-speed system
  only.

### 2.2 Action-speed scaling (shallow by design)

Introduce one derived concept: **speed multiplier** `S` (unitless, ~1.0).

```
speed_multiplier = 1.0 + spd_effect
spd_effect       = SPD * SPD_SCALE        (SPD_SCALE tuned small, e.g. 0.015)
```

A single SPD point changes actions by ~1.5%. **~7 SPD points ≈ +10% speed** —
perceptible but gradual. The walk/roll/attack values each get a shallow,
separately-tunable coefficient so one stat doesn't dominate every action:

| Action | Formula | Tuning knob |
|---|---|---|
| Walk speed | `tuning.speed * (1.0 + SPD * WALK_SCALE)` | `WALK_SCALE` ≈ 0.012 |
| Roll distance | `tuning.roll_distance * (1.0 + SPD * ROLL_SCALE)` | `ROLL_SCALE` ≈ 0.015 |
| Roll duration | `tuning.roll_duration / (1.0 + SPD * ROLL_SCALE)` | same knob (farther + faster) |
| Attack frame time | `tuning.attack_frame_time / (1.0 + SPD * ATK_SCALE)` | `ATK_SCALE` ≈ 0.010 |
| Between/cooldown | `tuning.between_attack_time / (1.0 + SPD * ATK_SCALE)` | same knob |
| Attack lunge | scale lunge velocity by `(1.0 + SPD * ATK_SCALE)` | same knob |

Rationale for shallow coefficients: with point grants of 1–5 per level (banded,
`progression_tuning.gd:7-8`) and items granting SPD as % of base, a normal
build lands in the **SPD 3–15** range — yielding at most ~20% action-speed
spread. Big stat swings (tanky vs. speedy loadouts) produce the visible
difference the user wants without a runaway.

Clamp: `spd_effect` clamped to `[-0.5, 1.0]` (never more than ~2× faster, never
slower than half speed) to protect game feel and animation integrity.

### 2.3 Gear rules (penalty/benefit design)

Follow the existing shield-penalty pattern and the HP/DMG gear convention
(percentage points of the target, ÷100):

- **SPD gear bonus** (new `speed` key in `bonuses`): a **percentage-of-base-SPD
  grant**, expressed on the same scale as the other stats (1 point ≈ 1% of base
  SPD, e.g. `speed: 1.0` = +1% of base SPD; `quick_dagger` = +2%, `swift_boots`
  = +3%). Converted in equipment via `× 0.01`. Positive values benefit speed.
  To keep single points meaningful at low SPD, the snapshot rounds a nonzero
  bonus up to at least ±1 SPD point (`_gear_points_signed`), so gear never
  grants nothing.
- **SPD gear penalty** (new `speed_penalty` key in the `shield` sub-dict for
  shields, and negative `speed` values or a dedicated penalty for armor):
  subtracted from the SPD bonus like `strength_penalty` is today.
- **High-STR items carry a speed downside.** Weapons/accessories whose bonuses
  are dominated by `strength` (soldier_sword, iron_maul, duelist_seal,
  warrior_charm, guardian-ish) get a `speed` penalty or reduced SPD.
- **Low-attack items grant a speed benefit.** Items with no/weak `damage_rate`
  or `strength` (basic_tunic, bangle, new light gear) get a positive `speed`.
- **Shields** reduce speed slightly: add `speed_penalty` to every shield's
  `shield` sub-dict (scaled with rarity, but fixed while the item is enhanced).
- **Heavy armor with high DEF** reduces speed: `iron_cuirass` becomes heavy
  (speed penalty); `basic_tunic` stays light (speed neutral/benefit).

This is implemented entirely in `equipment_component.configure_from_profile`
(new `speed_bonus` accumulator, shield `speed_penalty` subtraction) and
mirrored in `_effective_item_bonuses` for the UI, exactly like
`strength_penalty` today.

### 2.4 New speed equipment set

New items (added to `ItemCatalog.DEFINITIONS`) that "utilize" SPD — light gear
that trades damage for speed:

| definition_id | slot | flavor | bonuses (incl. new `speed`) |
|---|---|---|---|
| `quick_dagger` | weapon | fast dagger, low dmg | `damage_rate` low, `speed` +5 |
| `feather_cloak` | armor | light armor, fast | `health_rate` low, `speed` +5 |
| `swift_boots` | accessory | pure speed | `speed` +8 |
| `parry_buckler` | shield | light shield | low guard, `speed_penalty` 0 (or -1), lower durability |

The speed set is the **only gear line granted enhanced speed values** (5/5/8);
incidental speed on other gear stays on the ±1-2 point scale, so the quick set
delivers a meaningfully stronger speed benefit while keeping the 1%-per-point
conversion.

Plus a **new `speed` affix** (e.g. `swift`) usable on weapon/armor/accessory.

Also retune existing items per §2.3 (e.g. soldier_sword `speed` -1,
iron_cuirass `speed` -2, bangle `speed` +1).

### 2.5 Where the speed multiplier is computed

Add a single resolver so all three action systems share one value:

- Add `player_speed_multiplier` to `gameplay_state.gd` (runtime).
- Recompute it wherever the snapshot changes: `_apply_profile_to_runtime`
  (gameplay.gd:11), `_hub_confirm_stats` (498), `_apply_player_level` (1703),
  and on equip/unequip (`_equip_profile_item`, line 30).
- Resolver: `player_speed_multiplier = 1.0 + clampf((base_spd + allocated_spd +
  gear_spd_points) * SPD_SCALE, -0.5, 1.0)` where `gear_spd_points` comes from
  the snapshot's new `gear_speed` field.

Then the three consumers read `root.get("player_speed_multiplier")`:
- `actor_motor.gd:28` — multiply `tuning.speed`.
- `player_roll_component.gd:32,39` — scale distance/duration.
- `player_animation_component.gd:86,99,101,118` +
  `gameplay_frame_controller.gd:134,136` — scale frame time / between /
  cooldown (divide time values by the multiplier).

All runtime sources are **code-created resources** (gameplay_state.gd:363-367);
no `.tres` overrides exist, so adding fields is safe.

---

## Part 3 — Implementation Plan

### Step 1 — Core stat plumbing (no behavior change yet)

1. `stats_component.gd`
   - Add `SPD` to `enum Stat` (line 7).
   - Add `manual_base_spd`, `manual_spd` fields; extend
     `configure_manual_growth` signature (line 80), `_recalculate` (95),
     `get_stat` (61), `get_stats` (72), `manual_allocation` (91),
     `_base_profile_values` (119), `_growth_weights` (153),
     `_roll_growth_stat` (187), `_stat_priority` (223).
   - Archetype bases (suggest): BALANCED SPD 2, FAVOR_VIT SPD 3,
     FAVOR_STR SPD 1, FAVOR_DEF SPD 1, FAVOR_STR_DEF SPD 1.
   - Growth weights: shift a small weight to SPD (e.g. BALANCED
     VIT .32 STR .30 DEF .30 SPD .08).
2. `combat_stat_snapshot.gd`
   - Add `speed` and `gear_speed` fields; populate in `from_components` (17-32)
     with `_gear_points(stats.speed, equipment.speed_bonus)`.
3. `player_profile.gd`
   - Add `base_spd := 1`, `allocated_spd := 0`.
   - Extend `allocate_stat` (269), `reset_allocated_stats` (288).
   - Extend `to_dictionary` / `load_dictionary` (302-371).
   - **Bump `CURRENT_SCHEMA_VERSION` 5 → 6** (line 4). Default-migrate missing
     fields (`data.get("base_spd", 1)`, `data.get("allocated_spd", 0)`).
4. `gameplay.gd`
   - `_apply_profile_to_runtime` (25): pass SPD into `configure_manual_growth`.
   - `_hub_adjust_stat` / `_hub_allocate_stat` / `_hub_confirm_stats` /
     `_hub_cancel_stats` / `_hub_points_remaining` / `_hub_auto_allocate`
     (481-520): add SPD arms + pending field.
   - Add SPD to all 4-5 AUTO patterns (511).
5. `gameplay_state.gd`
   - Add `hub_pending_spd := 0` (next to 187-189).
   - Add `player_speed_multiplier := 1.0`.
6. `screen_state_controller.gd`
   - `stat_names := [&"VIT", &"STR", &"DEF", &"SPD"]` (460); rows auto-grow
     via `stat_names.size()`.
   - `update_hub_ui` (573-581): add SPD to `pending` / `values` / `allocations`
     / label arrays.
   - Derived panel (469-470, 592-595): append `SPD` derived value (e.g.
     `"SPD %d"` from snapshot.speed) → `for index in 3`, position y=45+i*18.
   - Gear panel: `fields` array (856) + pause-mode values (848-850) + build
     loop (511) grow to include `SPD`. Gear stat panel height (507) may need
     +10px.
   - `_item_comparison_text` (883-885) label map: add `"speed": "SPD"`.
7. Tests
   - `tests/progression_smoke.gd`: extend snapshot assertions for SPD gear
     rounding, allocation, serialization round-trip. Bump any version checks.

### Step 2 — Action-speed scaling

1. `player_tuning.gd` — add `@export` knobs:
   - `speed_scale := 0.012`, `roll_scale := 0.015`, `attack_scale := 0.010`,
     `speed_effect_clamp := 1.0`.
   - Helper on `PlayerTuning` (or a static) `speed_multiplier(spd, effect)`.
2. `gameplay.gd` — resolver `_recompute_player_speed_multiplier()`:
   `1.0 + clampf(snapshot.speed * SPD_SCALE, -0.5, speed_effect_clamp)`,
   called from `_apply_profile_to_runtime`, `_hub_confirm_stats`,
   `_apply_player_level`, equip paths.
3. `actor_motor.gd:28` — multiply by `root.get("player_speed_multiplier")`.
4. `player_roll_component.gd:32,39` — scale `roll_distance` and `roll_duration`
   by the multiplier (via `root.get`).
5. `player_animation_component.gd` (86, 99, 101, 118) + `gameplay_frame_controller.gd`
   (134, 136) — divide time values by the multiplier.
6. Sanity smoke: add `tests/speed_scale_smoke.gd` verifying that a SPD-15 build
   moves/finishes attacks faster than SPD-1 without violating animation frame
   counts.

### Step 3 — Gear integration + new equipment

1. `item_catalog.gd`
   - Add `speed` (bonus) and `speed_penalty` (shield/armor) keys as
     percentage points of base SPD (1 point ≈ 1%, like the stat scale, ÷100):
     - `EquipmentComponent` line 65-67 pattern: `speed_bonus += speed * 0.01`.
     - Shield: `speed_bonus -= speed_penalty * 0.01` (mirror line 71-72).
     - `CombatStatSnapshot._gear_points_signed` floors nonzero results to ±1.
   - Add `swift` affix to `AFFIXES` (weapon/armor/accessory, `speed`, 1-2%).
   - Add new definitions from §2.4 (`quick_dagger`, `feather_cloak`,
     `swift_boots`, `parry_buckler`) with a new `speed` bonus.
   - Retune existing items per §2.3: soldier_sword/iron_maul/duelist_seal/
     warrior_charm `speed` negative; iron_cuirass heavy `speed` negative;
     basic_tunic/bangle `speed` positive; shields get `speed_penalty`.
   - `shield_bonuses` (217-227) already returns the shield sub-dict — add
     `speed_penalty` passthrough.
2. `equipment_component.gd` — add `speed_bonus` var, reset (35-44), accumulate
   (65-67), shield subtraction (71-72).
3. `combat_stat_snapshot.gd` — `gear_speed` via `_gear_points` (Step 1).
4. `screen_state_controller.gd:_effective_item_bonuses` (867-875) — subtract
   shield `speed_penalty` like lines 873-874 so comparisons show net speed.
5. Gear UI: add SPD row to the gear stat panel (Step 1 already extends it).

### Step 4 — Balance pass + verification

- Verify default starter loadout (basic_sword/tunic/shield/bangle) nets near
  zero SPD change so first-run feel is unchanged.
- Confirm FAVOR_STR (SPD 1 base + heavy STR gear) is meaningfully slower than
  a speed build, but only by ~10-15% — visible, not punishing.
- Run `tests/run_all_smoke.ps1` (run_grade, progression, item_economy,
  rogue_slime, speed_scale, main scene) + `--headless --check-only`.
- Remind user to reload the editor (stale class cache).

---

## Risks / Watch-items

- **Schema bump breaks old saves** unless `load_dictionary` defaults new fields
  (it does via `data.get`). Version 5 saves remain loadable.
- **Animation integrity:** attack frames are fixed 4-frame sheets. Only *time
  between* frames scales — never the frame count. Keep `attack_scale` ≤ ~0.02
  so the hit frame doesn't feel off.
- **AUTO pattern clamp:** ~~`FAVOR_STR_DEF` falls through to FAVOR_DEF
  pattern~~ — resolved: `gameplay.gd:_hub_auto_allocate` now has a dedicated
  5th STR/DEF-weighted pattern.
- **Enemy usage:** `StatsComponent` SPD growth affects enemy slimes (they use
  the non-manual path). This is harmless (SPD doesn't touch combat), but enemy
  SPD growth uses the new weights — verify slime stat totals are unaffected.
- **`_stat_priority`** is used for ordering; SPD must be appended last.
