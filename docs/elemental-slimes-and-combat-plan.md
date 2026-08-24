# Tiny Demons — Elemental Slimes and Combat Matchups

Status: reviewed and approved with revisions; ready for implementation

Date: 2026-08-24 (reviewed against the codebase and the Generation III source
chart on the same day)

This document is the design and implementation handoff for adding a neutral
Gray slime, assigning an element to every slime color, and carrying elemental
matchups through damage calculation and feedback. The rules in §5 and the
decisions in §12 are now settled; implementation follows the ordered plan in
§10. All code references below were verified against the current tree (see
§13 for the verification log, including the corrections applied during
review).

Related design:

- [`Tiny Demons — Elemental Chroma System Design.md`](Tiny%20Demons%20%E2%80%94%20Elemental%20Chroma%20System%20Design.md)
- [`elemental-chroma-implementation-plan.md`](elemental-chroma-implementation-plan.md)
- [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)

## 1. Player-facing result

Every slime has two related but separate identities:

- A visual variant/palette: `grey`, `red`, `blue`, `yellow`, `green`, or
  `purple`.
- A gameplay element: `neutral`, `fire`, `water`, `electric`, `grass`, or
  `shadow`.

The canonical mapping is:

| Visual variant | Display name | Gameplay element | Intended role |
| --- | --- | --- | --- |
| `grey` | Gray slime | Neutral | Even baseline enemy |
| `red` | Fire slime | Fire | High STR, low VIT |
| `blue` | Water slime | Water | High DEF, low SPD |
| `yellow` | Electric slime | Electric | High SPD, low DEF |
| `green` | Grass slime | Grass | High VIT, low STR |
| `purple` | Shadow slime | Shadow | High SPD and STR, low DEF and VIT |

The code uses `neutral` as the stable element ID and `grey` as the visual
palette key. This matches the existing split verified in code: gameplay
identity strings use the American spelling (`player_chroma_component.gd:107`
returns `&"gray"`), while palette keys use the British spelling
(`palette_library.gd:4` includes `"grey"`). The `gray`/`grey` spelling
difference must never become part of the combat API.

Damage numbers are colored by the element on the damage event, not by the
target's color. A Fire slime hitting the player produces a Fire-colored
number; a neutral player sword hitting a Fire slime produces a neutral/Gray
number. Critical hits keep the original element color inside the glyph and
add a white outline around the number, alongside the existing pop timing (see
§6, "Critical presentation"). This makes crits obvious without replacing the
element identity with the current generic yellow crit color.

## 2. Scope and non-goals

### In scope

- A Gray/Neutral slime variant with even level-one stats.
- Yellow/Electric slime support using the existing recolor pipeline.
- Explicit element identity on slime definitions and damage events.
- Gen-III-inspired Fire/Water/Electric/Grass relationships with the custom
  `0.8` resistance and `1.25` weakness values requested for Tiny Demons.
- Shadow using the relevant Generation III Ghost relationships.
- Element-colored damage numbers for player and enemy damage.
- Focused unit/smoke coverage for the matrix, formulas, variants, and
  presentation.

### Out of scope for this slice

- Burn, poison, paralysis, slow, stun changes, or other elemental status
  effects.
- Dual-type actors, type inheritance, or equipment-based resistances.
- New player Triangle abilities for Grass or Shadow.
- Elemental room puzzles or procedural elemental curriculum changes.
- Replacing the existing Chroma/Aspect state machine with the combat element
  catalog. Player aspects and damage elements interoperate through a mapping,
  not one ownership system.
- Elemental typing of the player as a defender. The player defends as
  Neutral in this slice regardless of active aspect.

## 3. Terminology and ownership rules

### Element

The type used by the damage matchup calculation. The initial catalog is:

```text
NEUTRAL, FIRE, WATER, ELECTRIC, GRASS, SHADOW
```

`NEUTRAL` is the combat equivalent of the Normal-type role needed for the
Shadow/Ghost immunities. It is not the same thing as "no element" in the data
model; an attack must always resolve to an explicit element.

### Aspect

The player's current Chroma identity (`NONE`, `FIRE`, `WATER`, or `ELECTRIC`
today — `player_chroma_component.gd:11-16`). `PlayerChromaComponent` remains
the owner of aspect/Chroma state. A small adapter in the element catalog maps
Gray/`NONE` to `NEUTRAL` and active player aspects to their combat element.

### Damage event

The existing `CombatCalculator.DamageResult`
(`combat_calculator.gd:9-11`) extended from:

```text
amount: float
critical: bool
```

to also carry:

```text
element: int        # ElementCatalog.Element of the attack
effectiveness: float
immune: bool
```

The result is the boundary between calculation, health application, sound,
hit effects, and damage-number presentation. `HealthComponent.apply_damage`
(`health_component.gd:46`) stays amount-only; the typed result must remain
available until all presentation consumers have read it.

## 4. Elemental matchup contract

The relationship layout follows the Generation III subset for Normal, Fire,
Water, Electric, Grass, and Ghost. Tiny Demons intentionally uses different
strengths than Pokémon: a weakness is `1.25x`, a resistance is `0.8x`, and an
immunity is `0.0x`. Neutral is `1.0x`.

The original Generation III chart uses `2x`, `0.5x`, and `0x`; the source
reference is the [Generation III type chart](https://bulbapedia.bulbagarden.net/wiki/Type_chart_%28Generation_III%29)
(Generation II–V chart on Bulbapedia's type-chart page). The table below is
the authoritative Tiny Demons rule set. Every cell of the six-type subset was
re-checked against the source during review; see §13.

Rows are attacking elements. Columns are defending elements.

| Attacker ↓ / Defender → | Neutral | Fire | Water | Electric | Grass | Shadow |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Neutral | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | **0.00** |
| Fire | 1.00 | 0.80 | 0.80 | 1.00 | **1.25** | 1.00 |
| Water | 1.00 | **1.25** | 0.80 | 1.00 | 0.80 | 1.00 |
| Electric | 1.00 | 1.00 | **1.25** | 0.80 | 0.80 | 1.00 |
| Grass | 1.00 | 0.80 | **1.25** | 1.00 | 0.80 | 1.00 |
| Shadow | **0.00** | 1.00 | 1.00 | 1.00 | 1.00 | **1.25** |

The bold cells are the intentional weakness/immunity moments. This means:

- Fire is strong against Grass and resisted by Fire/Water.
- Water is strong against Fire and resisted by Water/Grass.
- Electric is strong against Water and resisted by Electric/Grass.
- Grass is strong against Water and resisted by Fire/Grass. (Review
  correction: the earlier draft also listed Electric as resisting Grass. In
  the Generation III chart Grass attacking Electric is neutral — it is
  Electric attacking Grass that is resisted — so Grass → Electric is `1.00`.)
- Neutral attacks cannot damage Shadow.
- Shadow attacks cannot damage Neutral.
- Shadow is weak to Shadow, matching Ghost attacking Ghost.
- The four elemental types have no special interaction with Shadow in this
  first slice.

The Neutral ↔ Shadow immunities are approved. Rationale: Shadow slimes are
already a rare, high-pressure ambush variant (`room_controller.gd:22-23`,
`PURPLE_ENEMY_WEIGHT 0.12`, `PURPLE_BOSS_CHANCE 0.04`), so making them immune
to the neutral sword creates a deliberate "use an elemental Triangle" moment
without affecting the common room curve. Shadow's own bite being unable to
hurt a Neutral-aspect player would be a player-side immunity — but since the
player defends as Neutral in this slice (§2), a Shadow slime's bite deals
`0.0x` to the player. That is intentional: Shadow pressure comes from its
speed/attack profile and ambush, and its low damage-into-player output is
offset by its rarity. If playtesting shows Purple feels toothless, the first
balance lever is its STR/SPD stats, not removing the immunity.

## 5. Damage formula integration

The verified current formula (`combat_calculator.gd:65-80`, tuning defaults
from `combat_tuning.gd`) is:

```text
raw = damage_base + attacker_strength * strength_scale
defense = defense_scale / (defense_scale + max(defender_defense, 0))
rolled = raw * defense * random_roll              # roll in [0.85, 1.15]
critical = rolled * critical_multiplier           # 10% chance, x1.5
final = max(1, floor(rolled_or_critical))
```

The elemental extension keeps this numerically identical when the matchup
multiplier is `1.0`:

```text
typed = rolled_or_critical * effectiveness
final = 0 when effectiveness == 0
        otherwise max(1, floor(typed))
```

Rules:

- The effectiveness multiplier applies after the critical multiplier and
  before the final floor. Critical and weakness compose exactly once.
- The minimum-one rule must not defeat immunity: `effectiveness == 0` yields
  exactly `0` and `immune = true` on the result.
- A resisted hit may still resolve to one damage, preserving the current
  readable low-damage behavior.

The calculator returns the extended `DamageResult` (final amount, critical,
attacking element, effectiveness, immune). It must not look at Sprite2D
colors, variant strings, Chroma UI state, or damage-number nodes; callers
supply both elements explicitly. `calculate_snapshot_damage` gains optional
`attack_element`/`defense_element` parameters defaulting to `NEUTRAL`, so
every existing call site keeps its current numeric behavior until migrated.

### Attack element defaults

Each attack supplies its own element. The actor's palette is only a way to
author or present that data.

| Attack source | Element in this slice |
| --- | --- |
| Player basic attack 1/2 | Neutral |
| Player Triangle while Gray | Neutral |
| Player Triangle while Fire/Water/Electric | Current Chroma element |
| Slime contact bite | The slime definition's element |
| Shield-absorbed portion of an incoming hit | Not re-typed; keeps the light-blue shield channel (§12, decision 9) |
| Healing, XP, level-up, gold, and other non-damage numbers | Existing special presentation rules, unchanged |

Verified boundary notes:

- The basic sword path is confirmed untyped today
  (`player_attack_component.gd:42-86` → `combat_runtime_controller.gd:47-59`
  reads stats only), so "basic attacks are always Neutral" is a guarantee,
  not a behavior change.
- The Triangle hit path already carries the projectile palette string down to
  `magic_hit_slime` (`magic_runtime_controller.gd:322`, bridged at
  `gameplay_state.gd:1077`), so the element adapter keys off that palette:
  `grey → neutral`, `red → fire`, `blue → water`, `yellow → electric`. Do not
  invent a second aspect lookup.

### Critical presentation

Today `was_critical` only swaps the number color to yellow
(`effects_spawner.gd:327`). Element colors occupy that channel, so critical
hits should keep the original element color inside the glyph and add a white
outline around the glyph. The outline is the critical channel; do not lerp the
interior toward white and do not replace it with yellow. Keep the existing pop
timing. `EffectsSpawner` can use the existing `was_critical` flag to build a
white outline behind the element-colored main sprite; no new combat-state field
is required. The existing `healing_color` override channel
(`effects_spawner.gd:325-327`) continues to provide the interior color.

### Immunity presentation

An immune hit deals zero damage and shows a brief `immune` floater in the
attack's element color, using the existing `display_text` parameter of
`spawn_health_number` (`effects_spawner.gd:323-324`); arbitrary glyph strings
through the 5px number font are already proven (`"FOCUS"`, `"lv up!"`).
Immune hits skip hit-flash, hitstun, hitstop, and knockback so the "no
effect" read is unambiguous.

## 6. Slime stat definitions

All six slime variants use an eight-point level-one base budget in the
project's existing stat order: `VIT`, `STR`, `DEF`, `SPD`. These are the
approved first-pass definitions:

| Variant | Element | VIT | STR | DEF | SPD | Read |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Gray | Neutral | 2 | 2 | 2 | 2 | Even baseline |
| Red | Fire | 1 | 4 | 2 | 1 | STR pressure, fragile health |
| Blue | Water | 2 | 1 | 4 | 1 | Durable, slow |
| Yellow | Electric | 2 | 2 | 1 | 3 | Fast, low DEF |
| Green | Grass | 4 | 1 | 2 | 1 | High health, low damage |
| Purple | Shadow | 1 | 3 | 1 | 3 | Fast ambush pressure, fragile |

Approved level-growth weights, in the same stat order:

| Variant | VIT | STR | DEF | SPD |
| --- | ---: | ---: | ---: | ---: |
| Gray | 0.25 | 0.25 | 0.25 | 0.25 |
| Red | 0.10 | 0.55 | 0.20 | 0.15 |
| Blue | 0.20 | 0.10 | 0.55 | 0.15 |
| Yellow | 0.20 | 0.15 | 0.10 | 0.55 |
| Green | 0.55 | 0.10 | 0.20 | 0.15 |
| Purple | 0.08 | 0.42 | 0.08 | 0.42 |

Review corrections and constraints:

- The draft claimed `AllocationProfile` is player-oriented. Verified wrong:
  enemies already use it (`combat_runtime_controller.gd:173` maps blue →
  `FAVOR_DEF`, red → `FAVOR_STR`, purple → `FAVOR_STR_DEF`, else →
  `FAVOR_VIT`). The real problem is that the five existing profiles cannot
  express these six definitions (Yellow and Purple especially), not that the
  mechanism is player-only.
- Adopting this table rebalances existing variants. Today's bases are
  green `4/2/1/3` (FAVOR_VIT), blue `3/1/3/1` (FAVOR_DEF), red `2/4/1/1`
  (FAVOR_STR), purple `1/3/3/1` (FAVOR_STR_DEF). This is an intentional
  gameplay change, so per the extension rules it must land in its own commit,
  not mixed into structural work, and Phase 5's baseline comparison covers
  the difficulty impact.
- The deterministic growth path (`stats_component.gd:208-241`: variance ±0.06,
  anti-runaway bias, point curve) is reused unchanged. Note its seed is
  `points_per_level*313 + base_points*733 + allocation_profile*197 +
  path_hash` — path-hash based, not run-seed based. The variant override must
  fold a variant token into that seed (replacing the `allocation_profile`
  term) so two variants on the same node path roll different, stable
  sequences. Already-earned level points are never rerolled because
  `_recalculate` replays the same seeded sequence.

## 7. Gray and Yellow presentation plan

No new imported sprite sheets are required. The verified pipeline already
recolors the authored Green sheets for Purple
(`actor_presentation_runtime_controller.gd:64-77`,
`slime_visual_component.gd:149-155`). Reuse it:

1. Source `SlimeGreenLeft.png` / `SlimeGreenRight.png` for variants without
   dedicated art, exactly as Purple does today.
2. Recolor the Green shadow/normal/accent source tones (`257179`, `38B764`,
   `A7F070`) through `PaletteLibrary`. Verified: `grey` and `yellow` both have
   `SHADOW`, `NORMAL`, and `ACCENT` entries (`palette_library.gd:14-32`), and
   `_palette_color` recolors any palette that has an `ACCENT` key, so both
   work through the existing path with no mapping changes.
3. Add `grey` and `yellow` entries to the attack frame library
   (`slime_visual_component.gd:59-64`) and shocked frame library
   (`slime_visual_component.gd:88-93`).
4. Generalize the Purple-only direction-texture fallback in
   `build_slime_direction_textures` into a recolored-fallback list
   (`grey`, `yellow`, `purple`), each recolored exactly once.
5. Keep the visual variant key separate from the element ID.

Damage-number colors reuse `PaletteLibrary` — no second RGB table. Per
element, use `PaletteLibrary.accent(palette_key)` with `normal(palette_key)`
as fallback. Two verified color collisions make ACCENT the right default:
`NORMAL["yellow"]` is exactly the gold number color `Color8(255, 205, 117)`
(`effects_spawner.gd:22-23`), and `NORMAL["red"]` is exactly the player
healing color `Color8(177, 62, 83)` (`combat_runtime_controller.gd:276,436`).
Acceptable near-neighbor: grey ACCENT `Color8(148, 176, 194)` sits close to
the shield light blue `Color8(148, 220, 255)` but is visibly duller; keep an
eye on it in playtesting.

Remaining presentation call sites the draft missed (verified):

- Target display names: `targeting_runtime_controller.gd:178-179` currently
  returns "Blue Slime" / "Red Slime" / "Rogue Slime" / "Green Slime". Add
  "Gray Slime" and "Yellow Slime"; Purple keeps "Rogue Slime" (its ambush
  identity) while its combat element is Shadow.
- Target health-bar textures: `hud_controller.gd:358,383` select per palette
  with a green fallback; extend for `grey` and `yellow`.

## 8. Code ownership and migration seams

All rows verified against the current tree:

| Concern | Current seam | Planned change |
| --- | --- | --- |
| Element IDs, display names, palette mapping, matchup table, aspect/palette adapters | No owner (no element concept exists anywhere in `scripts/`) | Add `scripts/element_catalog.gd` as a stateless source of truth |
| Slime variant → element/stats/palette/display name | `CombatRuntimeController.configure_slime_variant` (`combat_runtime_controller.gd:168-174`) + borrowed `AllocationProfile` presets | Add `scripts/slime_variant_catalog.gd` (stateless, `item_catalog.gd` precedent; GAMEPLAY_TUNING's catalog-style preset rule) holding variant definitions; `StatsComponent` gains a variant override API that feeds the existing deterministic growth path |
| Formula | `CombatCalculator.calculate_snapshot_damage` (`combat_calculator.gd:65-80`) | Optional element params; extended `DamageResult` |
| Player damage request | `player_attack_damage_against` (`combat_runtime_controller.gd:47-59`) and `PlayerAttackComponent.apply_hitbox` (`player_attack_component.gd:42-86`) | Return/propagate the typed result through combo/share logic instead of a bare float |
| Enemy damage request | `slime_attack_damage` (`combat_runtime_controller.gd:244-245`) and `SlimeActor.apply_attack_hit` (`slime_actor.gd:152-201`) | Resolve the slime's configured element; preserve it through guard split and health application |
| Triangle damage | `magic_hit_slime` (`magic_runtime_controller.gd:322-329`) | Map the projectile's existing palette argument to an explicit element |
| Slime element storage | None | `SlimeActor` field set by `configure_slime_variant`; also extend the `@export_enum` at `slime_actor.gd:4` with `grey`/`yellow` |
| Health application | `SlimeActor.damage_actor` (`slime_actor.gd:113`), `HealthComponent.apply_damage` | Unchanged amount-only API; typed event flows to feedback in parallel |
| Damage number color | `CombatRuntimeController.spawn_damage_number` (`combat_runtime_controller.gd:395`), `spawn_player_damage_number` (`:406`), `EffectsSpawner.spawn_health_number` (`effects_spawner.gd:323`) | Optional color parameter forwarded through the existing `healing_color` override channel; no `EffectsSpawner` signature change |
| Spawn pool | `RoomController._generate_enemy_encounter` (`room_controller.gd:85-138`), boss tables (`:140-162`) | Add Gray to the base pool; Yellow gated by depth; Purple rarity constants unchanged this slice |
| Visual source selection | `build_slime_direction_textures` (`actor_presentation_runtime_controller.gd:64-77`), `SlimeVisualComponent` frame libraries | Generalized fallback recoloring plus `grey`/`yellow` frame entries |

The `ElementCatalog` must not become an alias for `PaletteLibrary`, and
`PaletteLibrary` must not become the authority for damage. The catalog may ask
the palette library for presentation colors.

Migration note: `last_damage_was_critical` (`gameplay_state.gd:286`, written
at `combat_runtime_controller.gd:101`, read at
`player_attack_component.gd:86`) is removed in Phase 3 once the typed result
reaches all player attack consumers. The magic path currently overwrites that
flag as a side effect of reusing `_player_attack_damage_against` for its base
damage (`magic_runtime_controller.gd:323`); typing the magic path removes
that wart too.

## 9. Ordered implementation plan

One testable milestone per commit. Run
`pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1` before every
commit, and register every new test file in the hard-coded list at
`tests/run_all_smoke.ps1:5` (verified: the runner does not auto-discover).

### Phase 1 — Pure element and result data

- Add `scripts/element_catalog.gd`: `Element` enum, display names, palette
  keys, the six-by-six table from §4, `effectiveness(attacker, defender)`,
  `damage_number_color(element)` (ACCENT with NORMAL fallback), and the
  `aspect → element` / `magic palette → element` adapters.
- New `tests/element_catalog_smoke.gd`: every table cell, both immunity
  directions, Shadow-vs-Shadow weakness, adapter mappings, color fallback.
- Extend `CombatCalculator.DamageResult` and `calculate_snapshot_damage` with
  optional element parameters defaulting to Neutral.
- New `tests/elemental_damage_smoke.gd`: neutral-vs-non-Shadow damage is
  byte-identical to the pre-element formula; weakness/resistance scale in the
  documented order; crit × weakness composes once; immunity returns 0 despite
  the minimum-one rule. (Verified gap: no test currently exercises the damage
  formula directly.)

Exit condition: the type system and formulas work without a main scene.

### Phase 2 — Variant catalog and Gray/Yellow visuals

- Add `scripts/slime_variant_catalog.gd` with the six definitions from §6
  (variant key, element, display name, base stats, growth weights).
- Add `StatsComponent.apply_enemy_variant_profile(base_values,
  growth_weights, seed_token)`: stores overrides, folds `seed_token.hash()`
  into `_growth_seed()` in place of the `allocation_profile` term when active,
  and leaves the roll math untouched.
- Rewrite `configure_slime_variant` to read the catalog: set variant, element
  (stored on the actor), and stats override. Extend the `slime_actor.gd:4`
  `@export_enum` with `grey` and `yellow`.
- Generalize the direction-texture fallback and add `grey`/`yellow` attack
  and shocked frame entries (§7).
- Extend `targeting_runtime_controller.gd:178-179` display names and
  `hud_controller.gd:358,383` bar textures.
- Tests: exact level-one stats per variant (Gray `2/2/2/2`), each variant's
  element, Yellow/Purple growth-direction assertions at level 25 (mirroring
  `rogue_slime_smoke.gd:16-22`), and a grey/yellow recolor assertion on
  `SlimeGreenLeft.png` output mirroring the existing purple test
  (`rogue_slime_smoke.gd:77-96`).

Exit condition: a configured Gray slime renders, has even stats, and spawns
without missing-texture special cases.

### Phase 3 — Typed player and slime damage

- `combat_damage` (`combat_runtime_controller.gd:93-102`) accepts attacker and
  defender elements and returns the full `DamageResult` instead of a float.
- Player basic attacks pass Neutral; `apply_hitbox` reads crit/element from
  the returned result, preserving attack-2 scaling and multi-target sharing.
- Slime bites pass the slime's configured element through
  `slime_attack_damage` and `apply_attack_hit`; the guard split
  (`player_guard_component.gd:121-156`) keeps its current float API, with the
  element flowing around it to presentation.
- `magic_hit_slime` maps its palette argument to an element (§5).
- Delete `last_damage_was_critical` from `gameplay_state.gd` and both call
  sites.
- Tests: sword into Shadow = 0/`immune`; Fire Triangle into Grass gets
  `1.25x`; slime bites carry their own element; guard reduction math is
  unchanged for Neutral.

Exit condition: every damage path has an explicit element, Neutral-versus-
non-Shadow numbers match the pre-element baseline, and the global crit flag
is gone.

### Phase 4 — Element-colored feedback

- Thread the element color through `CombatRuntimeController.spawn_damage_number`
  and `spawn_player_damage_number` via the existing color-override channel;
  critical hits add a white outline while preserving the original element color
  inside the glyph (§5).
- Add the `immune` floater for zero-effectiveness hits (§5); skip hit-flash,
  hitstun, hitstop, and knockback on immune hits.
- Healing, XP, level-up, gold, and shield numbers stay exactly as they are.
- Tests: generated pixel-texture color per element (the
  `palette_smoke.gd:61-74` glyph-rendering assertions are the pattern);
  critical numbers retain element identity; `immune` text renders; healing
  and XP colors unchanged.

Exit condition: players can identify the attacking element from damage
feedback without reading a debug label.

### Phase 5 — Encounter and balance integration

- Add `grey` at weight `1.0` to the base variant pool
  (`room_controller.gd:108-112`); add `yellow` at weight `1.0` once
  `room_depth >= 2` so the first rooms of run 1 stay on the established
  colors plus Gray. Purple's constants are untouched.
- Boss tables stay unchanged (lead never Purple; minors blue/green/red with
  the 4% Purple conversion). Revisit only if Phase 5 metrics say otherwise.
- Update `GAMEPLAY_TUNING.md`: final stat/matchup weights, the two new
  catalog scripts, and fix the verified stale claim that there are five
  tuning resources — `chroma_tuning.gd` exists and is unindexed.
- Encounter tests: Gray appears in generated pools; Yellow never appears
  below depth 2; Purple rarity bounds from `rogue_slime_smoke.gd:24-40,63-74`
  still hold.
- Run the full smoke suite and compare early-room time-to-kill and
  incoming-damage distributions against the pre-element baseline.

Exit condition: all intended variants appear, remain readable, and do not
create an accidental early-game difficulty spike.

### Phase 6 — Later expansion (not scheduled)

- Grass/Shadow player aspects only when their Triangle abilities are
  designed.
- Status effects as separate typed effect requests, not hidden branches in
  the multiplier table.
- Dual types or equipment resistances only after single-element results are
  easy to inspect and test.
- Player-side defending elements (aspects granting weaknesses/resistances).

## 10. Verification checklist

### Pure data and formula tests

- Every element ID maps to exactly one display name and palette key.
- The six-by-six table is deterministic and directionally correct, including
  Grass → Electric = `1.00` (the review correction).
- Neutral damage is unchanged at `1.0x`.
- Fire/Water/Electric/Grass use `0.8x` and `1.25x`, not `0.5x` and `2.0x`.
- Shadow ↔ Neutral is immune in both directions.
- Shadow → Shadow is `1.25x`.
- Immunity produces zero even when the old minimum-damage rule would produce
  one.
- Critical damage and type effectiveness compose once, with no double
  scaling.

### Slime and encounter tests

- Gray has `2/2/2/2` at level one; all six variants match §6.
- Each slime bite resolves to its own element.
- Generated encounters can produce Gray immediately and Yellow at depth ≥ 2.
- Purple's rarity/role remains within the existing tested bounds.
- Gray and Yellow direction, attack, shocked, death, and health UI paths have
  valid textures.
- Target display names and target health bars cover Grey/Yellow.

### Integration and presentation tests

- Basic player attacks are Neutral.
- Gray Triangle is Neutral; active starter aspects use Fire/Water/Electric.
- Damage numbers use the attack element's ACCENT color, not the target
  variant and not `NORMAL["yellow"]`/`NORMAL["red"]` (gold/healing clashes).
- Enemy damage numbers are element-colored for all six variants.
- Critical numbers keep the exact element color inside the glyph and add a
  white outline.
- Immune hits show the `immune` floater and deal zero.
- Shield numbers stay light blue; healing and XP numbers are unchanged.
- Multi-target sharing applies after the typed result and does not lose the
  element or critical flag.
- `last_damage_was_critical` no longer exists.
- The full `tests/run_all_smoke.ps1` suite remains green, with all new test
  files registered in its list.

## 11. Resolved decisions

These settle the nine review questions from the draft, with code evidence:

1. **Stable spelling**: `neutral` element ID, `grey` palette key, `Gray`
   display name. Approved — matches the verified gray/grey split already in
   the codebase.
2. **Neutral into Shadow**: full immunity (`0.0x`), not limited to a future
   "physical" tag. Approved — matches Normal → Ghost in Gen III, and Purple's
   existing rare-pressure role keeps it fair. See §4 for the player-side
   consequence and its mitigation levers.
3. **Basic attack typing**: always Neutral; active Chroma aspects do not
   retype the sword. Approved — verified the sword path is untyped today, so
   this costs nothing and keeps the sword reliable.
4. **Stat profiles and growth weights**: approved as written in §6, with the
   explicit acknowledgment that they rebalance the four existing variants
   (separate balance commit, Phase 5 baseline comparison).
5. **Gray availability**: common in the base pool immediately. It is the
   baseline enemy; gating it would add progression plumbing for no teaching
   value.
6. **Yellow availability**: joins the pool at `room_depth >= 2`. Yellow is
   the fastest variant (SPD 3); keeping it out of the very first rooms
   preserves the established run-1 learning curve.
7. **Immune feedback**: a brief `immune` floater in the attack's element
   color through the existing `display_text` path, plus suppressed hit
   reactions. No new glyph pipeline needed.
8. **Damage-number color source**: `PaletteLibrary.ACCENT` with `NORMAL`
   fallback. Verified collisions rule out NORMAL-first: `NORMAL["yellow"]`
   equals the gold number color and `NORMAL["red"]` equals the player healing
   color.
9. **Shield numbers**: keep the existing light-blue `Color8(148, 220, 255)`
   convention as a separate UI channel. The absorbed portion is guard
   bookkeeping, not elemental damage to the player, and the convention is
   already established.

## 12. Research verification log

Everything below was double-checked on 2026-08-24 before this plan was
accepted.

### Matchup research (external)

- Source: Bulbapedia type chart, Generation II–V table (which is the
  Generation III chart). All 36 cells of the six-type subset were compared.
- Result: the draft table matched Gen III in 35 of 36 cells. Corrected:
  **Grass attacking Electric is `1.00`, not `0.80`** — in Gen III, Electric
  resists Electric and Grass resists Electric, but Electric does not resist
  Grass. Both immunities (Neutral↔Shadow), Shadow → Shadow weakness, and all
  Fire/Water/Electric/Grass relationships were confirmed accurate.
- The `0.8`/`1.25` strengths are an intentional, documented deviation from
  the source's `0.5`/`2.0`.

### Codebase research (internal)

| Draft claim | Verdict |
| --- | --- |
| `CombatCalculator.calculate_snapshot_damage` exists; extend `DamageResult` | Verified — `combat_calculator.gd:65`; result today is only `{amount, critical}` |
| Mutable global `last_damage_was_critical` | Verified — `gameplay_state.gd:286`; one writer, one reader |
| `AllocationProfile` is player-oriented | **Corrected** — enemies already use it (`combat_runtime_controller.gd:173`); the gap is that five presets cannot express six variant definitions |
| `CombatRuntimeController` damage/variant/number seams | Verified — all four methods exist (`:47,168,244,395`); damage getters return bare floats |
| `PlayerAttackComponent.apply_hitbox`, `SlimeActor.apply_attack_hit`/`damage_actor`, `HealthComponent` | Verified — damage crosses as float + crit bool only |
| `MagicRuntimeController` Triangle path | Verified — grey ×1.10 / elemental ×1.15; palette is visual-only today and already reaches `magic_hit_slime` |
| `EffectsSpawner.spawn_health_number` color rules | Verified — white default, crit yellow, non-white override channel; XP/gold/level-up/shield specials catalogued |
| Purple-only Green-sheet recolor; `PaletteLibrary` has grey/yellow | Verified — `actor_presentation_runtime_controller.gd:64-77`; grey and yellow have full SHADOW/NORMAL/ACCENT entries |
| Encounter pools and Purple rarity | Verified — `room_controller.gd:22-23,108-119,140-162` |
| `SlimeActor` variant validation | Clarified — the enum lives at `slime_actor.gd:4`; the runtime fallback lives in `configure_slime_variant`, not in the actor |
| `slime_tuning.gd` per-variant data | **Corrected** — none exists; variant stats come from the AllocationProfile mapping, so the variant catalog adds a new home rather than extending slime_tuning |
| Test coverage | Verified with gaps — no existing test for the damage formula or damage-number colors; new tests must be registered manually in `tests/run_all_smoke.ps1:5` |

Additional call sites found during review that the draft missed:
`targeting_runtime_controller.gd:178-179` (display names),
`hud_controller.gd:358,383` (target bar textures), and the
`chroma_tuning.gd` omission in `GAMEPLAY_TUNING.md` (fixed in Phase 5).
