# FFIII-Inspired Six-Stat & Menu Redesign — Implementation Plan

Status: implemented and verified on `feature/ffiii-stats-menu-rework`; reviewed
against the reference screenshots and the current codebase on 2026-08-27;
composite elemental combat clarification added on 2026-08-28

Date: 2026-08-27

## Objective

Replace the current four-stat player model with a six-stat, manually allocated
model and rebuild the player-facing hub, status, equipment, and pause layouts
around the information hierarchy of the supplied Final Fantasy III references.

The reference is for **layout, density, selection flow, and panel hierarchy**.
Tiny Demons keeps its own art, glyphs, void/charcoal palette, elemental color
language, single-character structure, and touch-first interaction rules.

The completed slice must provide a readable, testable pipeline from saved
allocation through gear and combat, while retaining all current elemental
rules, run flow, and persistent progression.

Related documents:

- [`meta_progression_design.md`](meta_progression_design.md) — persistent
  progression and equipment intent; this plan supersedes its player-stat
  details once implemented.
- [`elemental-chroma-implementation-plan.md`](elemental-chroma-implementation-plan.md)
  — current/bound element, Chroma, flame, and Triangle rules.
- [`elemental-binding-and-fusion-implementation-plan.md`](elemental-binding-and-fusion-implementation-plan.md)
  — flame interaction and Cloaked Demon Binding rules.
- [`elemental-slimes-and-combat-plan.md`](elemental-slimes-and-combat-plan.md)
  — implemented element identities and matchup rules. Its current
  four-stat physical slime-bite formula is the pre-rework baseline; Phase 2 of
  this plan supersedes it for non-neutral slime composite damage.
- [`speed_stat_design.md`](speed_stat_design.md) — historical SPD rollout;
  AGI replaces the player-facing SPD attribute under this plan.
- [`modular-display-and-settings-plan.md`](modular-display-and-settings-plan.md)
  — supported 3:2, 16:10, and 16:9 logical display widths.

## 1. Locked product decisions

### 1.1 Core attributes

All six attributes are durable, manually allocatable player stats:

| Attribute | Initial gameplay responsibility | It must not do |
| --- | --- | --- |
| **STR** | Physical weapon damage and physical knockback. | Change animation speed or spell power. |
| **AGI** | Walk speed, roll behavior, and safe action-recovery scaling. | Skip authored animation frames, alter hit-frame indices, or grant random evasion. |
| **VIT** | Maximum HP and explicitly authored health-centric effects. | Contribute to Physical Defense, Magic Defense, or passive mitigation. |
| **INT** | Triangle damage, the magic portion of Imbue, and the magic portion of non-neutral slime attacks. | Change elemental matchup values, Imbue duration, Chroma cost, or cooldown. |
| **MND** | M.DEF for magic portions of attacks, including composite elemental attacks, and later explicit status resistance. | Change Chroma maximum, pickup value, flame cost, or spell cooldown. |
| **DEF** | Physical mitigation, the physical portion of composite elemental attacks, guard strength, shield durability/stability, and physical knockback resistance where a current hook exists. | Grant HP or replace MND against magic damage. |

`P.DEF` and `M.DEF` are derived combat values. They must be labeled distinctly
from the allocated `DEF` and `MND` attributes in every UI so a player never
has to guess which number they are changing.

### 1.2 Manual allocation and progression

- Manual allocation remains the player’s primary build choice; no job system
  is introduced in this slice.
- Level-up points remain banked and are spent only from the Cloaked Demon hub
  allocation screen. A level-up never forces a modal choice during combat.
- The existing automatic allocation profiles may remain as optional **AUTO**
  presets. They are convenience patterns, not jobs, classes, or hidden growth.
- Player growth must be fully deterministic: no weighted/random player stat
  gains occur after a file begins.
- Existing point-award bands are subject to tuning because six destinations
  make the current four-stat economy less concentrated. Values are not changed
  until Phase 0 benchmark simulations approve them.

### 1.3 Elements, Triangle, and Imbue

- The existing element table stays exactly as implemented: resistance `0.8`,
  neutral `1.0`, weakness `1.25`, immunity `0.0`.
- Elemental matchup stays independent of attributes. INT increases a spell’s,
  Imbue’s, or non-neutral slime’s magic raw power; it never makes a weakness
  multiplier larger than `1.25`.
- Normal, spin, charge, and charged-attack hits remain physical, STR-led
  weapon actions. Their existing special multipliers remain valid.
- Triangle becomes a magic source: it scales from INT and is mitigated by
  M.DEF derived from MND.
- An imbued weapon strike remains **one readable damage packet**:

  ```text
  physical weapon portion (STR-led, mitigated by P.DEF)
  + elemental/magic Imbue portion (INT-led, mitigated by M.DEF)
  = one combined weapon hit
  → current element matchup applies once to the full result
  ```

- The physical and magic portions are resolved against their respective
  defenses, then combined before the existing roll/critical/matchup pipeline.
  This is one damage result, not two floating numbers or two separate
  elemental matchups.
- Neutral slime contact remains physical-only. Every non-neutral slime attack
  is an elemental composite attack: STR is the primary physical portion and
  INT supplies its separate magic portion. Non-neutral slimes receive the INT
  bonus; neutral slimes do not.
- Elemental slime attacks use their own damage contract and tuning values,
  separate from the player Imbue contract, while sharing the common composite
  resolver. Their element comes from the slime variant.
- INT also controls **visual intensity only** for the active Imbue: outline
  brightness/opacity, flash strength, and upward pixel-bleed density. It does
  not affect Imbue timing, duration, resource cost, or cooldown.
- Imbue visuals remain behind/front-layer aware and must never show through
  the player when the sword art is occluded.

### 1.4 Hub and run flow

- The Cloaked Demon hub does **not** contain a `START RUN` command.
- The world flame/entrance remains the action that begins a dungeon run and
  handles flame Swap/Fuse behavior.
- The Cloaked Demon owns preparation only: Status, Allocate, Equipment, Shop,
  Fusion, and Bind.
- Pause is a separate menu state and overlay, even if it shares the same visual
  shell. It must not reuse hidden hub controls or overlap the Demon Hub.

### 1.5 Visual direction

The four reference screenshots live in the repo at
[`../Mockups/ffiii-reference/`](../Mockups/ffiii-reference/)
(`status-menu.png`, `equipment-menu.png`, `pause-menu.png`, `config-menu.png`;
source copies in the repo-adjacent `examples/` folder). Reviewed against the
images, the transferable **construction grammar** is:

- A **title tab** at the upper left, overlapping the frame's top edge.
- A **framed content panel** with a thin double border (light outer line,
  darker inner line) enclosing everything else on the screen.
- **Dotted leaders** connecting row labels to their values (Status).
- A **hand cursor** marking the active command/option — Tiny Demons uses its
  existing cursor sprite instead of the glove.
- Per-screen organization (this is where accuracy matters — the screens do
  NOT share one layout):
  - **Pause/main menu** (`pause-menu.png`): player card column on the left,
    vertical **right-side command column** (Item/Magic/Equipment/Status/…),
    currency box at the bottom right, disabled entries shown greyed.
  - **Status** (`status-menu.png`): two-column stat block with dotted leaders
    (attributes left, derived values right), identity/EXP block above.
  - **Equipment** (`equipment-menu.png`): a **top action row inside the
    frame** (Equip / Remove / Remove All), a slot grid with tiny icons, a
    large item-list region, and a **bottom context strip** (`Attack: 8`).
  - **Config** (`config-menu.png`): rows whose **options are laid out
    horizontally** (Slow / Normal / Fast) with the cursor on the current
    choice, plus a **bottom description strip** explaining the active row.
- A **footer strip** with device-appropriate button hints (the references
  show `L`/`R` page hints bottom corners and `B Back` bottom right).

Tiny Demons substitutions and non-goals:

- Do not copy FFIII's blue panel palette, noise texture, art, font, portraits,
  party slots, hand cursor, formation screen, job system, or unused commands.
- Use Tiny Demons' void/charcoal base, warm white border/text treatment, and
  current-element accents for the active row or relevant values.
- The party-card column becomes **one compact player card** (palette-colored
  demon marker, name, current element, LV, HP, Chroma) — never a party list
  or portrait. HP/MP rows map to HP/**Chroma**.
- The `Gil` box stays out of the menu: Gold and Souls remain in the top HUD
  black bar with their existing icons.
- Every selectable row is a full touch target. Controller/keyboard cursor,
  touch selection, and cancel/back behavior must agree.

## 2. Target stat model

### 2.1 One authoritative calculation pipeline

```text
PlayerProfile (saved base + allocated attributes)
        +
Elemental affinity modifier (only when explicitly authored)
        +
Equipment flat bonuses, then equipment rates
        ↓
CombatStatSnapshot (effective STR/AGI/VIT/INT/MND/DEF)
        ↓
Derived values (HP, P.ATK, P.DEF, M.ATK, M.DEF, movement/action multipliers)
        ↓
Combat damage request (physical, magic, imbued weapon, or elemental slime)
        ↓
Component mitigation (P.DEF/M.DEF for composite attacks)
        ↓
One random roll and critical result
        ↓
One full-packet element matchup, presentation
```

No caller may calculate a competing final stat from a profile field, equipment
field, or palette string. Combat, UI, preview/comparison, and runtime movement
all consume the same effective snapshot or a pure derived-value helper.

### 2.2 Formula contracts

Exact coefficients belong in tuning resources and are approved through Phase 0
benchmarks. The formulas below define ownership and order, not final numbers.

```text
effective attribute
  = (base + manual allocation + flat gear + explicit temporary flat modifier)
    × (1 + summed applicable gear rates)

maximum HP
  = health baseline + VIT contribution + approved health-specific gear effects

physical raw power
  = weapon/ability base + STR × physical scale

physical mitigation
  = physical-defense scale / (physical-defense scale + effective DEF)

magic raw power
  = spell/ability base + INT × magic scale

magic mitigation
  = magic-defense scale / (magic-defense scale + effective MND)

imbued weapon physical raw power
  = weapon/ability base + STR × physical scale

imbued weapon magic raw power
  = Imbue base + INT × Imbue scale

elemental slime physical raw power
  = slime attack base + STR × slime physical scale

elemental slime magic raw power
  = slime elemental base + INT × slime magic scale

composite pre-matchup result
  = (physical raw power × physical mitigation)
    + (magic raw power × magic mitigation)

final composite result
  = max(1, floor(rolled-or-critical composite result × one element multiplier))
  except immunity, which remains an exact zero
```

`VIT` is deliberately absent from both mitigation formulas. `DEF` and `MND`
must use diminishing-return curves so they remain useful without erasing damage.
For composite elemental damage, the physical portion uses P.DEF derived from
effective DEF, while the magic portion uses M.DEF derived from effective MND.
The existing random roll and critical result are applied once to the combined
post-mitigation value, and the existing element multiplier is applied once to
that full value.

For AGI, the multiplier is based on a configurable reference value so the
starting build preserves the current game feel:

```text
agility delta = effective AGI - AGI reference
action multiplier = 1 + clamp(agility delta × per-action scale, min, max)
```

AGI may alter timer duration and motion magnitude only within configured
bounds. It never changes an animation sheet’s frame count, event frame, or
attack-hitbox frame index.

### 2.4 Implementation worksheet (Phase 0 lock)

The first implementation pass uses the following named tuning values. They
are deliberately conservative so the current physical game remains familiar
while the new INT/MND choices become measurable immediately:

| Area | Locked first-pass value |
| --- | --- |
| Level-1 balanced base (VIT/STR/DEF/AGI/INT/MND) | `3 / 2 / 2 / 1 / 1 / 1` |
| Level-up point bands | levels `2–5: 1`, `6–10: 2`, `11–20: 3`, `21–35: 4`, `36+: 5` |
| Physical packet | base `2.0` + `STR × 0.50`; P.DEF curve scale `12.0` |
| Triangle magic packet | base `2.0` + `INT × 0.75`; elemental mode adds `0.75`; M.DEF curve scale `12.0` |
| Imbue magic portion | base `1.0` + `INT × 0.50`; physical portion uses the normal weapon contract |
| Elemental slime physical portion | base `1.5` + `STR × 0.85` |
| Elemental slime magic portion | base `0.75` + `INT × 0.50` |
| Existing roll/critical | roll `0.85–1.15`, critical chance `10%`, critical multiplier `1.5` |
| AGI reference and scales | reference `1.0`; movement `0.012`, roll `0.015`, recovery `0.010`; existing `-0.5/+1.0` bounds |
| Physical knockback STR helper | reference `5.0`, `+4%` per STR, bounded `0.75–1.50` |
| Starter flat gear | weapon `STR +2`; armor `VIT +1/DEF +1`; shield `VIT +1/DEF +2/AGI -1`; accessory `STR +1/VIT +1/AGI +1` |

The starter package therefore keeps the established effective gear totals
(`VIT +3`, `STR +3`, `DEF +3`, `AGI +0`) while the balanced player baseline
adds one point each of INT and MND. Flat gear is applied before additive rates.
The first benchmark target is a readable level-one physical hit of roughly
`3–5` damage into a level-one neutral slime and a Triangle result that rises
only with INT; exact integer outcomes remain governed by the shared roll and
element table.

The authored enemy table is the catalog source of truth. Normal Slime has
`INT 0` and the physical contract. Every colored variant has a positive INT
and the separate elemental-slime contract; MND is defensive and never changes
the element multiplier. The composite resolver exposes both post-mitigation
components for tests and debugging, but presentation emits one damage number.

### 2.3 Damage classification

Every damaging action must explicitly choose a source category:

| Source | Offense stat | Defense stat | Current examples |
| --- | --- | --- | --- |
| Physical | STR | DEF | Attack 1, Attack 2, spin, charge, contact weapon hit |
| Magic | INT | MND | Triangle projectile/ability |
| Imbued weapon | STR physical portion + INT magic portion | P.DEF + M.DEF | Active elemental weapon hit; separate player Imbue contract |
| Elemental slime | STR physical portion + INT magic portion | P.DEF + M.DEF | Non-neutral slime contact/special attack; separate slime contract |

Element remains separate from the source contract. Neutral slime body contact
uses the physical category. A non-neutral slime’s elemental body contact is a
composite physical/magic attack even when its physical STR portion is
dominant. Authored projectiles or special attacks may opt in to the pure magic
category or receive their own explicit contract.

## 3. Current-state migration

The project already has useful boundaries that must be extended instead of
duplicated:

| Current owner | Current responsibility | Required change |
| --- | --- | --- |
| `PlayerProfile` | Persistent bases, allocations, point bank, save data. | Add INT/MND bases and allocations; migrate schema 8 saves. |
| `StatsComponent` | Runtime base/manual/enemy stat values. | Promote the four-stat enum to STR/AGI/VIT/INT/MND/DEF. |
| `HubProgressionDraft` | Pending hub allocation transaction. | Carry all six pending attributes atomically. |
| `EquipmentComponent` | Flat and rate-based equipped bonuses. | Add INT/MND/AGI bonus and rate channels. |
| `CombatStatSnapshot` | Shared effective combat read model. | Expose all six effective stats and gear contributions. |
| `CombatCalculator` | Physical health/damage formulas. | Accept explicit physical, pure-magic, Imbue-composite, and elemental-slime damage specifications with DEF/M.DEF mitigation. |
| `PlayerTuning` | Current SPD action multipliers. | Rename player-facing SPD terms to AGI and retain bounded timing rules. |
| `ScreenStateController` | Current hub/pause views. | Consume the new menu shell and separate hub/pause navigation state. |

### 3.1 Save schema and compatibility

The current profile schema is 8. The implementation bumps it to **9** and
adds an explicit schema-8-to-9 conversion rather than relying only on missing
field defaults.

| Schema 8 field | Schema 9 destination |
| --- | --- |
| `base_str`, `allocated_str` | `base_str`, `allocated_str` |
| `base_spd`, `allocated_spd` | `base_agi`, `allocated_agi` |
| `base_vit`, `allocated_vit` | `base_vit`, `allocated_vit` |
| `base_def`, `allocated_def` | `base_def`, `allocated_def` |
| no INT/MND fields | approved baseline INT/MND, zero allocations |
| `unspent_stat_points` | retained exactly |

The migration must preserve a player’s existing STR/VIT/DEF/AGI investment and
must never silently discard allocated points. Existing autoset/profile fields
may be retained only as preset metadata; they may not produce random player
growth after migration.

The current loader accepts only the current or immediately previous schema.
Phase 1 must make the supported schema-8 migration explicit and keep the
existing safe behavior for unknown/unsupported old schemas. Loading a migrated
file writes schema 9 on its next normal save.

### 3.2 Equipment and content compatibility

- Current `speed` equipment data becomes `agility` in authored definitions and
  item presentation.
- Read `speed` as a temporary compatibility alias while all catalog and affix
  entries are converted, then remove it in a follow-up cleanup commit.
- Existing VIT/STR/DEF gear values retain their current interpretation.
- INT/MND gear begins with a small authored pool. No item may gain a new
  magical bonus just to fill a table; every initial bonus must support a real
  Triangle, Imbue, or MND-defense decision.
- Flat gear still lands before rate bonuses. Rates remain additive within their
  category, preventing recursive self-multiplication.

### 3.3 Enemy profile migration

Enemy `StatsComponent` profiles also gain all six attributes. Their values are
authored/deterministic, not derived from player allocation.

Existing elemental slime identity stays intact:

| Variant | Required early emphasis |
| --- | --- |
| Normal Slime | Balanced six-stat baseline. |
| Fire Slime | High STR, low VIT. |
| Water Slime | High DEF, low AGI. |
| Electric Slime | High AGI, low DEF. |
| Grass Slime | High VIT, low STR. |
| Shadow Slime | High STR and AGI, low DEF and VIT. |

Ground (orange) and Ice (aquamarine) already have full four-stat profiles and
growth weights in `slime_variant_catalog.gd:60-73`; they gain the six-stat
extension on the same footing as the six older variants. Their enemy
behaviors remain as currently authored. Neutral slimes use the physical
contract and receive no offensive INT bonus. Every non-neutral slime uses the
separate elemental-slime contract, with STR as its primary physical portion
and INT supplying its magic portion. Enemy MND contributes to M.DEF whenever
the enemy defends against a magic or composite elemental portion.

## 4. Combat, ability, and visual implementation

### 4.1 Calculator boundary

Introduce a small typed request/value object (for example
`CombatDamageRequest`) rather than continuing to extend positional calculator
arguments. It carries:

```text
damage category (physical / magic / imbued weapon / elemental slime)
base power and independent physical/magic stat scales
attack element and defense element
critical eligibility
contract-specific tuning identifier and optional Imbue or slime bonus
```

CombatCalculator resolves raw power, applies DEF to the physical component and
M.DEF to the magic component for composite requests, combines those results,
preserves the existing single roll and critical behavior, then applies the
existing element effectiveness result once to the full result. Player Imbue
and elemental slime attacks have separate typed contracts and tuning values;
they share this low-level composite resolution without sharing balance
constants. Existing generic attack callers convert to a physical request
first, so the refactor can preserve present balance while each new path is
migrated.

### 4.2 Player attacks

- `PlayerAttackComponent` supplies physical requests for Attack 1/2, spin,
  charge, and charged Attack 2.
- Existing spin behavior remains: 90% single-target baseline and no normal
  multi-target damage sharing.
- Existing charge/finisher multipliers apply after its physical base result as
  they do today; their relation to a regular Attack 2 must remain intact.
- Physical knockback scales from STR through one tuning helper, then preserves
  existing spin/charged special multipliers.
- The player weapon element continues to drive puzzle-orb interaction and
  damage-number color. An active Imbue explicitly selects the Imbued Weapon
  contract; an arbitrary element value does not infer a category by itself.
- Attack modifiers and criticals apply to the complete resolved packet, not
  separately to its physical and magic portions.

### 4.3 Triangle and MND

Triangle currently reuses the normal player attack damage result. Replace that
path with a pure magic request so it uses INT against defender M.DEF, derived
from MND. Existing Gray and elemental ability base multipliers remain ability
tuning, applied after the magic base is determined.

MND’s initial gameplay uses are M.DEF mitigation for Triangle, Imbue magic
portions, and non-neutral slime magic portions. Future status resistance can be
added only with a concrete status system and an explicit formula; it is not
simulated with hidden reductions in this slice.

### 4.4 INT-driven Imbue

When Imbue is active:

1. Build the normal STR-led weapon hit.
2. Build the separate INT-led elemental/magic portion from Imbue tuning data.
3. Mitigate the physical portion with P.DEF and the magic portion with M.DEF,
   then combine them into one result.
4. Resolve the combined hit through the weapon’s current element once.
5. Produce the same single, element-colored damage number used today.

`MagicRuntimeController` continues to own activation, hold branching, resource
spend, duration, and cooldown. It exposes a read-only normalized Imbue
intensity derived from effective INT. `PlayerEquipmentVisualComponent` receives
that intensity in `begin_imbue` and uses it only for bounded presentation:

- outline/flash opacity and brightness;
- noise/bleed particle density or interval;
- optional small outline-pixel reach within the existing sword silhouette.

It may not alter equipment depth ordering, duration, cooldown, Chroma cost,
animation timing, or hitbox data. The existing room-transition preservation of
an active Imbue remains required.

### 4.5 Elemental slime attacks

- Neutral slime contact uses the existing physical damage contract and does not
  receive an INT contribution.
- Every non-neutral slime attack uses a separate elemental-slime damage
  contract. Its physical component is STR-led; its magic component is
  elemental-base plus INT scaling from the slime’s authored six-stat profile.
- Resolve the two components with P.DEF and M.DEF respectively, combine them
  into one result, then apply the existing roll, critical, and element
  matchup flow once. The element matchup affects the full combined result.
- Slime contracts use separate base values and scales from player Imbue, even
  though both use the common composite resolver. Existing slime contact
  timing, hit ownership, reactions, and knockback behavior remain unchanged.

### 4.6 Health, guard, and AGI runtime consumers

- Maximum HP remains calculated from VIT plus existing health-specific gear;
  health percentage is preserved after allocation/equip changes.
- DEF feeds physical defense and current guard/shield hooks. If a hook is not
  currently owned by DEF, do not invent a second implementation path merely to
  make a tooltip sound broader.
- AGI replaces player-facing `SPD` in the profile, snapshot, HUD, menu, and
  tuning labels. Internally derived speed multipliers can remain named
  `speed_multiplier` where that is clearer.
- Movement, roll, lunge, attack, charge, spin, and magic timers all read the
  same bounded AGI-derived helper. Magic animation still has enough authored
  frames for the Imbue activation frame; AGI only changes safe durations.

## 5. Menu information architecture

### 5.1 Reference map

Each screen borrows the organization of exactly one reference screenshot
(copied into `Mockups/ffiii-reference/` so the links below survive version
control):

| Reference | Tiny Demons screen | What transfers | What is not borrowed |
| --- | --- | --- | --- |
| `pause-menu.png` | Demon Hub main page; Pause | Right-side vertical command column; player-card column at left; greyed disabled entries; footer button hints | Party list (one card instead), Gil box, Quicksave/Save/Formation/Job entries |
| `status-menu.png` | Status page | Identity + LV/EXP block at top; HP/Chroma rows; two-column stat block with dotted leaders (attributes left, derived values right) | Portrait art, job level, the 8-slot magic-charge grid |
| `equipment-menu.png` | Equipment page | Top action row inside the frame; slot grid with icons; large item-list region; bottom context/comparison strip | R Hand/L Hand/Head/Body/Arms slot labels (Tiny Demons keeps Weapon/Armor/Shield/Accessory) |
| `config-menu.png` | Settings page (title and pause) | Rows of horizontal option selectors with the cursor on the active value; bottom description strip for the highlighted row | All FFIII option content |

### 5.2 Shared shell

Create a small menu-shell builder/presenter rather than adding more layout
branches to `ScreenStateController`. The shell owns only visual composition:

```text
title tab (overlapping the frame's top-left edge)
framed content region (thin double border)
footer hint bar (device-aware prompts)
bottom description/context strip (on pages that need one)
```

The right-side command column is NOT a shell element — it belongs to the hub
and pause main pages only. Equipment declares a top action row inside the
frame; Settings declares horizontal option rows; Status declares two-column
data. Each page picks exactly one organization pattern.

Screen state/navigation remains the responsibility of screen-flow code. Hub
and pause each own a separate instance/state; they may reuse shell styling but
never toggle visibility across the same mutable control collection.

The shell uses the active logical view width from the display controller. It
must be centered at 240×160 and naturally widen at 256×160/284×160 without
making the panel shorter or moving the footer outside the top/bottom bars.

### 5.3 Cloaked Demon menu

The Cloaked Demon opens a preparation menu only, organized after
`pause-menu.png`: player card at left, vertical command column at right.

```text
┌─ DEMON HUB ───────────────────────────────────────────┐
│ ┌───────────┐                                STATUS   │
│ │ (demon    │                            ▶ ALLOCATE   │
│ │  card)    │   [selected page content]  EQUIPMENT    │
│ │ LV · HP · │                                SHOP     │
│ │ Chroma    │                              FUSION     │
│ └───────────┘                                BIND     │
│                                                       │
│              [contextual helper]          [BACK]      │
└───────────────────────────────────────────────────────┘
```

The player card holds a palette-colored demon marker, the current element
name, LV, HP, and Chroma — the single-character answer to the reference's
party cards; there is no portrait art and no party list.

The six commands map from today's hub tabs (`screen_state_controller.gd:641`,
`["STATS", "GEAR", "SHOP", "FUSE", "BIND"]`) as: STATS splits into read-only
STATUS plus ALLOCATE, GEAR becomes EQUIPMENT, and SHOP/FUSE/BIND carry over
as SHOP/FUSION/BIND.

There is deliberately no `START RUN` entry — already true in code
(`build_hub` returns `"start": null`, `screen_state_controller.gd:823`); this
plan keeps it that way. Cancelling returns to the hub world; the
flame/entrance begins the run.

Gold and Souls stay in the top black HUD bar using their existing icons. They
do not become tiny FFIII-style `Gil` text, and no currency box is added to
the menu's bottom-right corner. Disabled commands render greyed, matching the
reference's disabled `Save` and the existing sold-out shop treatment
(`screen_state_controller.gd:1126`).

### 5.4 Status and Allocate

`STATUS` is read-only and follows `status-menu.png`: identity and LV/EXP
block at top, HP/Chroma rows beneath (the reference's HP/MP rows map to
HP/**Chroma**), then a two-column stat block with dotted leaders — allocated
attributes on the left, derived combat values on the right:

```text
┌─ STATUS ──────────────────────────────────────────┐
│  (card)  Tiny Demon — Fire             LV .... 4  │
│                                     EXP .... 210  │
│                                 NEXT LV .... 46   │
│                                                   │
│  HP ...... 26/32       CHROMA ....... 75/100      │
│                                                   │
│  STR ...... 6          P.ATK ....... 8            │
│  AGI ...... 5          P.DEF ....... 1            │
│  VIT ...... 5          M.ATK ....... 3            │
│  INT ...... 5          M.DEF ....... 1            │
│  MND ...... 5          MOV ......... 1.00x        │
│  DEF ...... 4          RECOVERY .... 1.00x        │
└───────────────────────────────────────────────────┘
```

It must fit this hierarchy without exposing six adjustment arrows, and the
derived `P.DEF`/`M.DEF` labels must stay visibly distinct from the allocated
`DEF`/`MND` rows beside them (§1.1).

`ALLOCATE` owns the six pending rows, point total, AUTO, APPLY, CLEAR, and
RESPEC actions. It shows the base/allocated change clearly and gives each row
one full-width touch target plus explicit left/right controls. Gear effects
belong on Status/Equipment rather than making allocation rows unreadable.

### 5.5 Equipment, shop, fusion, and bind

- **Equipment** follows `equipment-menu.png`: a **top action row inside the
  frame** (EQUIP / REMOVE / REMOVE ALL with the cursor on the active
  command), a slot grid with tiny icons, a large item-list region, and a
  bottom context strip carrying the comparison (`P.ATK: 8 → 10`) or the
  highlighted item's description. Retain Tiny Demons'
  Weapon/Armor/Shield/Accessory slots; never relabel them as body parts that
  do not match their mechanics.
- **Shop/Fusion:** keep their current transactions and validation rules, but
  display them inside the same shell so selected row, cost, outcome, and BACK
  are consistent. Sold-out or unaffordable entries use the greyed-disabled
  convention (as the current `SOLD` row already does).
- **Bind:** remains the Cloaked Demon's 50-Soul persistent binding action. It
  shows current element, bound element, Souls, cost, and outcome; Swap/Fuse
  remain flame actions and are not duplicated here.

### 5.6 Pause and settings

Pause uses the same visual grammar but a distinct state and a smaller command
set, organized after `pause-menu.png` like the hub (player card left,
commands right):

```text
RESUME
STATUS
EQUIPMENT
SETTINGS
QUIT TO TITLE
```

Reconciliation with the landed modular-display slice: RESUME, SETTINGS, and
QUIT TO TITLE already exist as buttons inside the hub overlay
(`screen_state_controller.gd:806`). This plan supersedes that arrangement and
the "settings over hub chrome" note in
[`modular-display-and-settings-plan.md`](modular-display-and-settings-plan.md):
pause becomes its own shell instance, ports those three actions, and adds
read-only STATUS/EQUIPMENT pages. It must not toggle hub page controls or
reuse hidden hub widgets.

The Settings page (from both title and pause) follows `config-menu.png`:
each row is a label plus a **horizontal option selector** with the cursor on
the active value (e.g. `ASPECT   3:2   16:10   16:9`; MUSIC/SFX step 0–100),
and the bottom strip describes the highlighted row. It hosts the five landed
settings rows (fullscreen, aspect, pixel perfect, music, SFX) without
changing their approved behavior.

Status/Equipment opened from pause are read-only for progression transactions:
no shop, fuse, bind, allocation, or run-start actions. Returning from Settings
must restore pause only; it must never leak confirmation into title-screen New
Game or leave two overlays visible.

### 5.7 Input contract

- Keyboard/controller: one visible cursor, directional row navigation,
  accept, and cancel/back work on every page.
- Touch: every displayed action has a direct tap target; no touch path relies
  on hidden focus, a held control, or controller-only glyphs.
- The footer back/cancel control lives in the lower-right safe area when touch
  controls are active and mirrors the Cancel action.
- Prompts use the active input device but must retain sufficient contrast. In
  particular, TAP text uses black glyph interiors with a white highlight, as
  established by the touch UI direction.

## 6. Implementation phases and exit criteria

### Phase 0 — Formula and balance contract

1. Add a stat-matrix worksheet/document section containing level-1, early,
   mid, and high-level target builds.
2. Choose approved base values, point-award bands, per-stat scales, reference
   AGI, caps, starter equipment contributions, and enemy baselines.
3. Define explicit attack-category assignments for every current player and
   slime attack, including the separate Imbue and elemental-slime composite
   contracts.
4. Use the locked composite physical/magic resolution order: DEF mitigates
   the physical portion, M.DEF mitigates the magic portion, both are combined
   before one roll/critical/matchup flow, and the element multiplier affects
   the full combined result. Choose only the curves, bases, and scales.
5. Add pure calculator tests before changing live combat values, including
   neutral physical slimes, non-neutral elemental slimes, Imbue, and the
   separate DEF/M.DEF contributions.

Exit condition: each point’s expected player-facing effect is quantified;
there is no unresolved overlap between VIT/DEF or INT/MND.

### Phase 1 — Six-stat data model and safe save migration

1. Add `AGI`, `INT`, and `MND` to `StatsComponent`; rename player-facing SPD
   fields to AGI while maintaining a temporary compatibility reader where
   migration needs it.
2. Add base/allocated INT and MND to `PlayerProfile`, `HubProgressionDraft`,
   `ProgressionController`, profile-runtime application/sync, and all
   allocation/respec paths.
3. Bump the profile schema to 9 and implement schema-8 conversion.
4. Extend `EquipmentComponent` and `CombatStatSnapshot` to carry all six
   flat/rate values.
5. Keep current physical outcome equivalent before magic/Imbue formulas are
   switched.

Exit condition: new and migrated profiles load/save without point loss;
the full six-stat snapshot is deterministic and UI-independent.

### Phase 2 — Derived values and combat categories

1. Introduce the typed combat damage request and physical, pure-magic,
   Imbue-composite, and elemental-slime-composite resolution paths.
2. Keep existing physical attacks on the physical path and verify their
   current spin/charge/critical behavior.
3. Move Triangle to INT-vs-MND magic resolution.
4. Add the INT magic portion to an imbued weapon hit, resolve its physical and
   magic portions through DEF and M.DEF respectively, and keep one element
   match and one damage number.
5. Add the separate elemental-slime contract: neutral slimes stay physical;
   non-neutral slimes use STR plus INT with DEF/M.DEF composite mitigation.
6. Route HP through VIT only; route physical portions through DEF and magic
   portions through MND/M.DEF, including composite elemental contracts.
7. Replace the current player SPD runtime source with the bounded AGI helper.

Exit condition: raising exactly one attribute changes only its approved
derived/combat outcomes; all existing element effectiveness tests remain green.

### Phase 3 — Equipment, enemies, and presentation

1. Convert catalog/affix keys from speed to agility and add authored INT/MND
   opportunities only where meaningful.
2. Update equipment previews and comparisons to use the shared six-stat
   snapshot rather than locally reconstructed numbers.
3. Give every existing slime variant an explicit six-stat profile, preserving
   its documented color identity and assigning the neutral physical versus
   non-neutral elemental-slime contract explicitly.
4. Add INT-normalized Imbue visual intensity, respecting front/back sword
   layering, room transitions, and expiration fade.
5. Add a compact stat breakdown to debugging/dev output for balance review.

Exit condition: gear can visibly alter every approved stat, enemy variants
remain legible, and high INT makes Imbue stronger both mechanically and
visually without changing its timing contract.

### Phase 4 — Shared menu shell and Cloaked Demon redesign

1. Build the reusable shell with own hub and pause instances.
2. Implement read-only Status and separate Allocate pages.
3. Rebuild Equipment with its action row, comparison panel, and description
   bar; port Shop/Fusion/Bind into the shell.
4. Replace horizontal hub tabs with the right-side command column.
5. Remove all obsolete Start Run controls from the Demon Hub while keeping the
   hub flame’s run-entry path intact.
6. Restyle Pause and Settings with the shell without changing their already
   approved settings behavior.

Exit condition: no hub/pause overlap exists; every page works by controller,
keyboard, mouse, and touch at all supported widths.

### Phase 5 — Tuning, migration rehearsal, and release verification

1. Run target-build simulations and adjust tuning resources only.
2. Load representative schema-8 saves, allocate/respec/equip/bind, enter a
   run through the flame, fight, die/settle, reload, and confirm persistence.
3. Test physical, pure magic, Imbue composite, and elemental-slime composite
   hits against neutral, resistant, weak, and immune targets.
4. Perform manual visual review for 3:2, 16:10, and 16:9 on desktop and web,
   including touch controls.
5. Update affected design docs and mark the historical SPD plan superseded.

Exit condition: the full profile → hub → flame → combat → settlement loop is
playable with no save loss, no hidden input trap, no menu overlap, and no
unexplained stat effect.

## 7. Automated verification matrix

| Area | Required coverage |
| --- | --- |
| Profile migration | Schema-8-to-9 mapping, retained allocations/points, default INT/MND, round-trip save. |
| Allocation | Six valid rows, invalid names, negative/over-budget requests, AUTO, APPLY, CLEAR, RESPEC. |
| Snapshot math | Flat-before-rate ordering, no recursive rates, one-stat-at-a-time deltas, equipment preview parity. |
| Health/defense | VIT changes HP only; DEF mitigates physical portions; MND-derived M.DEF mitigates magic portions, including composite attacks. |
| Physical combat | STR affects regular/spin/charge; existing damage-share and critical rules remain correct. |
| Magic combat | INT affects pure Triangle magic; MND-derived M.DEF protects the defender; element table remains unchanged. |
| Imbue | STR physical portion + INT magic portion, DEF/M.DEF composite mitigation, one damage number/full-packet element multiplier, fixed cost/duration/cooldown, visual-intensity cap, front/back occlusion, room persistence. |
| Elemental slime combat | Neutral slimes remain physical-only; non-neutral slimes use their separate STR-primary/INT-magic contract with DEF/M.DEF composite mitigation and one full-packet element matchup. |
| Enemy profiles | Normal/Fire/Water/Electric/Grass/Shadow/Ground/Ice six-stat identities, neutral-versus-elemental contracts, and deterministic generation. |
| Menus | Status/Allocate/Equipment/Shop/Fusion/Bind/Pause transitions, no simultaneous overlays, direct touch taps, cancel routing. |
| Responsive display | Centering and safe footer at 240×160, 256×160, 284×160; web touch and desktop controller smoke paths. |

Likely new focused smoke tests:

- `composite_elemental_damage_smoke.gd`
- `six_stat_profile_migration_smoke.gd`
- `six_stat_calculator_smoke.gd`
- `magic_mind_damage_smoke.gd`
- `imbue_intelligence_smoke.gd`
- `six_stat_equipment_smoke.gd`
- `six_stat_menu_scene_smoke.gd`
- `demon_hub_menu_scene_smoke.gd`

The existing progression, item-economy, elemental-damage, Imbue, pause-menu,
touch-controls, display-responsive, spin-charge, and full-suite smoke tests
must be updated rather than bypassed.

## 8. Risks and guardrails

| Risk | Guardrail |
| --- | --- |
| Six choices dilute level-up impact. | Establish target-build simulations before changing awards; keep all starters viable. |
| AGI breaks authored combat timing. | Scale timers only within caps; never alter frame count/hit-frame data; retain animation smoke tests. |
| VIT and DEF become interchangeable. | VIT gives HP only in the initial release; all passive physical mitigation comes from DEF. |
| INT makes a weapon build mandatory to split points. | STR owns normal weapon power; INT adds the deliberate Imbue/elemental-slime magic portions and Triangle power, with separate contracts and tunable scales. |
| MND has no immediate value. | MND-derived M.DEF mitigates Triangle, Imbue magic portions, and every non-neutral slime’s magic portion from the first combat phase. |
| Composite attacks become difficult to read or overcomplicated. | Resolve physical and magic portions against DEF/M.DEF internally, then use one roll, one critical result, one full-packet element matchup, and one damage number. |
| Imbue and elemental slime balance become coupled. | Keep separate typed contracts and base/scaling values while sharing only the low-level composite resolver. |
| Save migration weakens existing files. | Map all four old attributes exactly, retain points, run before/after snapshot fixtures. |
| Menu redesign reintroduces touch traps/overlap. | Separate hub/pause state, direct tap targets, routing tests, and supported-aspect visual checks. |
| Reference imitation obscures Tiny Demons identity. | Reuse only layout grammar; use original colors, glyphs, panel treatment, and game terminology. |

## 9. Values approved in Phase 0

The implementation worksheet in §2.4 is the approved first-pass balance
contract. These values are now represented by named tuning fields and covered
by focused smoke tests:

1. Level-1 base values for STR/AGI/VIT/INT/MND/DEF.
2. Stat-point award bands for a six-choice economy.
3. HP, physical, pure magic, Imbue composite, elemental-slime composite, AGI,
   DEF, and MND coefficients/caps.
4. Initial INT/MND gear and affix distribution.
5. Exact enemy six-stat tables, elemental-slime base/scales, and which future
   enemy actions are pure magic.
6. Whether VIT receives a later explicit health-only secondary effect after
   the initial max-HP implementation proves readable.

None of these values are inferred from palette color, old allocation profiles,
or a UI label. They are balance data represented by named tuning values and
the six-stat calculator, profile, equipment, composite-combat, slime, and
Imbue smoke coverage.

## 10. Definition of done

Implementation status: complete on the feature branch. The baseline was pushed
to `main` before implementation began; the feature branch contains the full
six-stat, combat-contract, menu, migration, and verification slice.

The slice is complete only when:

- players can manually allocate STR, AGI, VIT, INT, MND, and DEF from the
  Cloaked Demon menu;
- every stat has a visible, tested gameplay outcome with no forbidden overlap;
- existing saves migrate without losing investments;
- Triangle uses INT/MND; Imbue uses a STR-primary plus INT-magic composite
  contract; and non-neutral slimes use their separate STR-primary plus
  INT-magic composite contract;
- element weaknesses, binding, flame Swap/Fuse, and flame-driven run entry
  retain their approved behavior;
- the Cloaked Demon has no Start Run command;
- Status, Allocate, Equipment, Shop, Fusion, Bind, Pause, and Settings use a
  coherent Tiny Demons menu shell inspired by the references, not copied
  assets;
- menu input works on controller, keyboard/mouse, and touch at all supported
  display widths; and
- the full smoke suite plus targeted migration/combat/menu tests pass.
