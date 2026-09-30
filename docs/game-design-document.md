# TINY DEMONS — Game Design Document

Version: 0.3.0 (active development)

Status: current
Scope: whole-game design authority — concept, pillars, systems, content inventory, and 1.0 direction
Owner: design/product
Current code: describes shipped `0.3.0` behavior and marks aspirational work `T`; verify against [`AUDIT.md`](AUDIT.md) and [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md)
Verification: `S` reflects shipped state per `AUDIT.md`; `T` items are targets and `O` items are open questions
Supersedes: none — first whole-game GDD; subsystem design docs remain in force and are the detail authority

Engine: Godot 4.7.1 / GDScript · main.tscn
Presentation: 240×160 pixel-art base, nearest-neighbor, integer scaling
Platforms: Windows desktop · Web (GitHub Pages) · mobile/touch
Genre: Isometric action dungeon crawler · soft roguelite
Session length: 2–5 minute runs; occasional 10–20 minute challenge dives
Monetization: none shipped; pay-to-win rejected at the contract level
Status tags used below: S shipped · T 1.0 target · O open question

## 1. High Concept

A bite-sized isometric action dungeon crawler where you play a small elemental
demon. Clear tight, readable rooms of slimes and skeletons, attune to flames to
change your element mid-run, fuse elements into new classes, and carry your gear
and mastery back to the Demon Hub for the next dive.

The name is the thesis: your demon IS an element. The palette you choose is a
class, not a skin. It changes your spell, your damage matchups, and how you solve
optional problems in the dungeon. Everything else in the game is designed to make
that elemental identity matter.

Core fantasy: be a small, mischievous, elemental thing that gets stronger by
committing to what it is.

## 2. Design Pillars

1. **Your demon is an element.** Color is class identity — it shapes your
   ability, your matchups, and your route options.
2. **Combat is about attention, not stats.** FOCUS and the combo timer reward
   timing and target choice. A skilled player in starter gear should outplay a
   lazy player in good gear.
3. **Every run asks a different question.** Combat, elements, routing, and
   risk/reward vary; you are never on autopilot.
4. **Small rules, deep combinations ("massively tiny").** Few interacting rules
   should generate a large space of encounters, routes, and solutions.
5. **Elements are classes, not dungeon keys.** The critical path is solvable by
   any starter; matching elements open shortcuts, secrets, and rewards.
6. **Readability before complexity.** At 240×160, silhouette, animation, timing,
   and color must explain intent without text.
7. **Cause is immediate; reward is legible.** Every meaningful event gets a
   one-frame visual/audio response. Nothing resolves silently.
8. **Cozy and mysterious, lightly cruel.** Death stings a little ("there was a
   way"); victories delight.

## 3. Core Loop

```text
              Choose a flame
                   |
                   v
   Demon Hub  ->  dive the dungeon  ->  fight, route, discover
      ^                                        |
      |                                        v
      +------  settle rewards, keep gear  <----+
```

In-run loop: choose route → fight → find flames, gear, gold, Chroma → beat the
boss or extract.

Between runs: level up, allocate six stats, buy/fuse gear, and commit a permanent
element at the Cloaked Demon.

Persistence (the "soft" part): death ends the run, never your progress.

Persists:

- Equipped + stored gear
- Duplicates / fusion levels
- Souls, gold
- Player level / XP
- Bound element, gear mastery
- Difficulty rank, last run grade

On death: end input → short defeat presentation → settle persistent rewards,
discard run-only state → return to Hub. The results screen explicitly lists what
was kept and what was lost.

## 4. Combat

Combat is the core product; every other system feeds it. The player uses weapon
foundations that are always available, then layers elemental identity on top.

### 4.1 Player kit — universal foundations S

| Action | Behavior |
| --- | --- |
| Move | 8-way; vertical movement compressed (scale 0.5) for the isometric feel |
| Combo attack | Attack 1 → Attack 2 (Attack 2 deals 1.25× dmg; 1.10× when hitting multiple targets) |
| Running attack | Fires directly from a run, starts at Attack 2; 1.10× dmg with extra lunge, knockback, and hitstop |
| Charged attack + sword beam | Hold 0.25–0.65s to release a 1.60× damage projectile beam |
| Spin attack | Circular-joystick gesture; 0.90× dmg but 2× knockback and a lunge — crowd control and repositioning |
| Roll / backflip | Invulnerability frames, ~24px travel |
| Guard | Block with a perfect-block window (0.14s); perfect blocks roughly double stun and add a 1.5× counter-shove |
| Target lock | Locks an enemy; enables FOCUS |
| Triangle magic | The current elemental ability (see §5) |

### 4.2 The skill layer — what makes combat ours S

**FOCUS.** Locking a target grants bonus damage against it for a short window;
when the window lapses, damage against that target drops below baseline. The
result: target lock is a tactical decision, not a free buff.

- Locked-target bonus: +30%
- Window: 2.5s
- Post-window penalty vs that target: −20%
- Un-target and re-lock a different enemy to reset.

**Combo timer.** Landing a hit opens a tempo window; each consecutive hit adds
damage and a visible streak.

- Window between hits: ~1.5s
- Per hit: +5%, capped at +25%
- Getting hit resets the combo to zero
- The visible streak counter is uncapped; five is a damage milestone, not a ceiling

FOCUS (per-target) and combo (global tempo) add as separate percentage
categories, so they never multiply into nonsense.

### 4.3 Enemy combat contract S

Every enemy must have exactly: one primary behavior, one strong telegraph, one
reliable counter, one punish window, one memorable reaction, and one reason to
combine it with another role. Variants add one meaningful change, not five
overlapping systems.

### 4.4 Impact and feedback S

A landed hit layers: hit flash + element-colored particle burst + damage number
(criticals get color, outline, and a denser burst) + knockback + frame-scheduled
hitstop (1.8× on criticals) + bounded screen shake + sound. Future controller
haptics join the same resolution points.

Feedback is split into two roles:

- **Information layer** (flash, numbers, health bars, knockback, hitstop) —
  deterministic and readable at 240×160.
- **Texture layer** (sparks, trails, auras, signatures, dust, debris) — may use
  GPU particles, but density must never obscure telegraphs or hitboxes.

Removing any layer of impact should be a deliberate choice, never an omission.

## 5. The Element System

This is the identity anchor. Element is expressed through Chroma, flames, fusion,
and permanent Binding.

### 5.1 Elements and matchups S

Eight combat elements: Neutral (Gray), Fire, Water, Electric, Grass, Shadow,
Ground, Ice.

- Starters: Fire, Water, Electric.
- Fusion-born: Shadow, Ground, Grass, Ice.

Matchups (`element_catalog.gd`): weakness 1.25×, resistance 0.8×, with some
strong resists at 0.25× (Shadow vs Neutral, Ground vs Electric). There is no full
immunity currently.

Design intent: matchups are advisory, not mandatory. Any aspect can clear any
room; the wheel makes some rooms harder or easier. Resistances are learned by
attempting — enemy reactions are the tutorial, not a tooltip.

Fusion recipes (commutative, data-driven):

```text
Fire + Water      -> Shadow
Fire + Electric   -> Ground
Water + Electric  -> Grass
Grass + Water     -> Ice
```

### 5.2 Elemental identity targets

| Element | Combat identity |
| --- | --- |
| Fire | Burst, aggression, expensive commitment |
| Water | Efficiency, control, knockback, area shaping |
| Electric | Stun, chaining, targeting, tempo |
| Grass | Sustain, drain, regeneration, restraint |
| Shadow | Deception, curse, phase, lifesteal |
| Ground | Defense, armor, stagger, force |
| Ice | Slow, freeze, preservation, momentum |

### 5.3 Chroma — the run-local resource S

- Maximum 100; elemental Triangle ability costs 10; a Chroma pickup grants 20.
- Magic always requires Chroma. At zero, even the Gray baseline bolt is blocked.
- Unbound elements fall back to Gray at zero Chroma.
- Bound elements survive at zero, weakened/desaturated, and recover through
  neutral Chroma.
- Pickup tint follows the player's current effective element.

### 5.4 Current vs. Bound vs. Mastered

Three separate concepts:

- **Current element** — the active run identity: your spell, your color while
  charged, current-element door checks, and the first input to a fusion.
- **Bound element** — the persistent identity written only at the Cloaked Demon.
  It sets the hub flame, survives zero Chroma, and enables neutral-Chroma
  recovery.
- **Mastered ability T** — a learned technique that can eventually be equipped
  outside its native element.

Changing the current element never erases bound progress.

### 5.5 The flame interaction — the mid-run pivot S

An interacted flame offers two deliberate gestures:

- **Quick press/release → SWAP (5 Souls):** become the flame's element, restore
  full HP and Chroma.
- **Hold 0.35s → FUSE (5 Souls):** combine the current element with the flame via
  a recipe, producing a new unbound element.

Fusion uses the current element, so a player with no binding can still solve a
hybrid gate. Fusion results are immediately usable in combat and at doors, but
remain unbound until confirmed at the Demon. Invalid/unaffordable interactions
spend nothing and change no state.

### 5.6 Binding economy S

| Action | Location |
| --- | --- |
| Swap / use flame | Elemental flame |
| Fuse | Elemental flame |
| Bind current element | Cloaked Demon |
| Bind already-bound | Cloaked Demon |

Intent: cheap flame actions let players experiment and solve required routes
freely; the expensive Bind is reserved for the "this is who I am" commitment.

Hard rule: required critical-path progression must never force the 50-Soul Bind.
Hybrid gates are always solvable in-run. Only optional secret/mastery content may
require a bind. A 5-Soul bailout is granted whenever the player is out of Souls,
so flame interaction can never soft-lock.

### 5.7 Ability-kit target T

Each element eventually carries a small signature package, not an oversized tree:

1. Regular magic — quick, reliable, lower-commitment.
2. Held magic — charged/high-impact with positional commitment.
3. Held attack — charged physical/hybrid attack that changes combat rhythm.
4. One passive per element.

Mastery lets a native ability travel across elements; once mastered there is no
cross-element blocker — mastery is the loadout economy. (Note: the "mastery" that
ships today is gear family mastery, §8.2 — a different system.)

## 6. Enemies and Bosses

### 6.1 Role taxonomy

Combat roles are distinct from movement. Aerial is a movement layer, not a role.

- **Melee** — closes distance; readable attack, clear counter, punish window.
- **Ranged** — controls space; visible wind-up, readable path, vulnerable while
  firing/repositioning.
- **Support** — changes other enemies; must have multiple counters (kill,
  interrupt, separate, exploit).

### 6.2 Shipped enemy families S

| Family | Variants | Role | Movement |
| --- | --- | --- | --- |
| Slime | 10 | Melee | Ground |
| Skeleton | 8 | Ranged | Ground, holds a preferred range |

The two families share the actor runtime, but are distinct in behavior and
presentation. Skeletons use authored
idle/walk/attack/wind-up/recovery/shocked/spawn sheets and a bone projectile with
an outline, swept-hit collision, and impact burst. They steer to a preferred
firing range and appear, weight-balanced against slimes, once the run pool opens.
Slimes are elemental variants by default (Normal, Fire, Water, Electric, Grass,
Shadow, Ground, Ice) plus Crimson (Fire reskin) and Guard.

Element drives typed damage and matchup; some variants are rank-gated (Yellow,
Ground, Ice are "late"; Shadow is a rare pressure spike).

### 6.3 Design-target roles T

The vertical-slice bar calls for a deliberately small roster with distinct
questions:

| Enemy | Role | Movement |
| --- | --- | --- |
| Biter | Melee | Ground |
| Spitter | Ranged | Ground |
| Healer | Support | Ground |
| Cave Bat | Melee/hazard | Aerial |

Support and aerial roles do not exist yet; they are targets, not shipped content.
The roster should not expand until the shipped roles produce satisfying
encounters alone and in combination.

### 6.4 Bosses and elites S

- **Bosses:** any slime variant can lead as a boss. All bosses share one
  large-slime kit — heavier scoot/hold/squish/bite language, a committed
  multi-frame bite lunge, strong contact authority that slows and redirects the
  player, one authored jump-away + targeted slam, and support waves of minor
  slimes and skeletons that respawn until the boss dies. Variant controls name,
  element, stats, palette, and matchup.
- **Elites T:** optional hyper-stat enemies with feints. Bosses are
  scripted-phase, main-line encounters.
- Element-specific boss mechanics are a later extension, not part of the base
  pass.

## 7. Dungeon

### 7.1 Room types S

START, COMBAT, PUZZLE, REST/FIRE, TRADER, NPC/CLOAKED, DOWNSTAIRS/BOSS,
SPECIAL_ENEMY, TREASURE, ORB.

### 7.2 Pacing S

- Normal room ≈ 6 enemies; congested rooms cap at 8–9; boss rooms breathe.
- Every room should ask a timing or positioning question, not just a damage check.

### 7.3 Authored + procedural S

- Runs 1–5 are authored. Run 1 is the teaching run ("Slimey Depths"); R3–R5 use
  authored puzzle maps with color-gate puzzles.
- Runs 6+ are deterministic generated risk/reward layouts, bounded to a 35×35
  presentation; strength scales with encounter rank/depth.
- R6+ policy: an ungated boss path, three guaranteed primary flames, safe vs.
  risk route choices, and optional elemental Orb vaults with elite encounters and
  enhanced guaranteed gear. Mandatory fusion-gate chains were removed from the
  generated critical path.

### 7.4 Gate classes S

1. **Mandatory & universal** — solvable by any valid loadout.
2. **Optional & elemental** — a matching element opens a secret/shortcut/reward.
3. **Multi-solution** — different elements or objects solve the same problem
   differently.

Avoid mandatory elemental locks that are merely menu administration. If a
mandatory element is ever justified, provide temporary access, an alternate
solution, or a clearly telegraphed return path.

### 7.5 Puzzle vocabulary S

Keys, switches, levers, pressure plates, breakable obstacles, carryable objects
(including a physical Orb with a visible origin and destination, recoverable,
that never strands the player), and timed mechanisms.

Teaching curve: introduce in a safe room → use with normal movement → combine
with one known enemy → offer a mastery shortcut. The critical path is always
recoverable — no permanent key loss on death, no sealing the player away from the
solution, no puzzle requiring an ability the player could have lost.

### 7.6 Biomes T

One dungeon ships today: Slimey Depths, element-agnostic and playable by all
three starters. Each location should eventually define a visual rule, a spatial
rule, a danger behavior, a small role-based roster, and an optional discovery
language — independent of the player's element. Multiple biomes are a 1.0 target;
no biome system exists yet.

## 8. Progression and Economy

### 8.1 Six stats S

| Stat | Identity |
| --- | --- |
| VIT | Max HP, healing, regen, health-cost effects, shield recovery |
| STR | Weapon output, knockback, lunging, combo finishers |
| DEF | Mitigation, shield durability, guard recovery, counters (active shield play, not passive DR) |
| AGI | Movement, roll/run, attack/recovery timing (bounded) |
| INT | Triangle magic and the magic portion of Imbue |
| MND | Derived magic defense vs. Triangle and enemy elemental magic |

New characters begin at 2 in every stat. Level-ups grant 1 point (Lv 2–5) up to 5
points (Lv 36+); points never expire and have no storage cap. Level grants no
direct Core HP — health comes from VIT and HP gear, keeping VIT a deliberate
investment. Level-up preserves current health percentage (never a free full
heal). Respec is cheap or free early, gold-cost later, in the Hub.

### 8.2 Gear S

- Six slots: Weapon, Head, Body, Arm, Shield, Accessory.
- Five rarities: Common, Rare, Epic, Legendary, Mythic.
- Enhancement: up to +10; each level adds a small flat tier-stat point.
- Nine sets: Swift, Soldier, Guard, Blood, Arcane, Soul, Edge, Oath, Rune, plus
  12 Plain/Basic baseline pieces.
- Stat ladder: definition base + (rarity rank × 2) + (fusion enhancement × 0.1),
  plus up to three random + points.
- Gear family mastery: up to level 3; feeds shield guard/enhancement scaling.
- Duplicates are the dependable fusion material.
- No gear multiplies Souls, gold, or global drop rate.
- Balance guardrail: combat skill must remain sufficient with starter gear; gear
  expands approaches, it is not a stat check.

### 8.3 Run grading and difficulty S

Each run is graded S/A/B/C/D/F by performance. The grade adjusts a persistent
difficulty rank (1–20) and applies loot-grade drop bonuses — a performance-over-
baseline layer above the fixed run curve.

### 8.4 Currencies S

| Currency | Scope | Primary use |
| --- | --- | --- |
| Chroma | Run-local | Elemental casting |
| Souls | Persistent | Flame actions (5), fusion (5), Binding (50), skill tree |
| Gold | Persistent | Hub shop, respec |

### 8.5 Drop sources S

Enemy deaths give Souls/Chroma (never inventory floods). Treasure chests give
identified gear under seeded source rules; regular combat rooms roll roughly a
50% treasure chance. Run-clear gives one performance-sensitive persistent roll.
The Hub shop offers reliable stock plus a seeded premium slot. Bosses may later
use a curated high-tier pool.

## 9. The Demon Hub S

The Hub is a calm preparation space, not another combat room. Its surfaces:

- **STATS** — manual six-stat allocation and respec.
- **SHOP** — nested BUY / SELL. SELL lists unequipped gear only, requires a
  second confirm, and pays 25% of price plus 75% of recorded fusion steps as
  Souls.
- **FUSION** — combine matching definition + rarity duplicates to enhance.
- **BIND** — 50 Souls to permanently commit the current element. Shows
  current/bound element, cost, Soul balance, and a confirmation step.

Runs launch from the Hub with the persistent build. The hub flame displays the
bound element, falling back to the starter flame when no bind exists.

The fantasy beat: a flame creates the new element; the Cloaked Demon preserves it
permanently. Create, then commit.

## 10. Presentation, Audio, and Feel

- **Art:** 240×160 pixel art, nearest-neighbor, integer scaling; adaptive
  landscape widths with fixed 3:2/16:10/16:9 presets.
- **Tone:** intentional minimalism that "communicates confidence." A missing
  response is treated as a bug even when the pixels are correct.
- **Audio hierarchy:** gameplay-critical > reward > ambience. Broad event
  coverage with random enemy-hit variants and pitch variation on criticals. T
  dedicated SFX/Music buses and music ducking.
- **Haptics:** mobile handheld vibration exists; T controller rumble and a single
  unified haptics seam where "enemy hits the player" is the highest-priority
  pulse.
- **Camera:** centered gameplay camera with large-room follow and frame-driven
  screen shake. T room-to-room transition is currently an instant swap; a
  wipe/fade is a known gap.
- Currency and rewards are delivered, not incremented — pickups visibly travel to
  the HUD before the number changes, and the affected readout acknowledges the
  change.

## 11. Controls, Platform, and Tech

Keyboard/mouse, controller, and touch all route through one centralized input
boundary with device-aware prompts.

| Action | Keyboard / Mouse |
| --- | --- |
| Move | WASD / arrows |
| Attack | LMB / J / Space |
| Magic | MMB / U |
| Roll / Run | RMB / K |
| Target lock | Q / Tab |
| Guard | L / Shift |
| Interact | E / Enter |
| Cancel | X / Esc |
| Pause | Esc |
| Map | M |

Mouse aims facing while movement controls travel; a click selects an enemy,
holding attacks, holding an attack charges it.

Tech: one desktop/web codebase; native mobile renderer, web `gl_compatibility`.
Explicit performance target is the Samsung A17 and the browser build within
measured frame budgets.

## 12. Shipped Content Inventory (0.3.0)

- Full title → save select → Demon Hub → dungeon → settlement loop, with
  persistent profiles and recoverable active runs.
- Action combat: movement, combo, running attack, charged attack + sword beam,
  spin attack, roll, guard with perfect block, hit reactions, knockback, target
  lock, FOCUS, combo.
- Eight elements with weakness/resistance matchups, Chroma, flames, fusion,
  Binding, orb charging.
- Two enemy families — 10 slime variants (melee, one ambushing) and 8 skeleton
  variants (ranged bone-throwers) — plus bosses with jump-slam and mixed support
  waves.
- Authored Runs 1–5 and deterministic generated Runs 6+ risk/reward layouts.
- Compact minimap and expanded travel map over the same dungeon graph.
- Six-stat profiles, XP, gold, Souls, difficulty rank, run grades, gear family
  mastery, bound element.
- Six equipment slots, five rarities, enhancement, random stat points, nine sets,
  fusion, transmutations, salvage, and full Hub transaction flows.
- 240×160 pixel presentation with nearest filtering and integer scaling.
- Keyboard, controller, mouse, and touch input.
- Web export, GitHub Pages workflow, localStorage save mirror, active-run
  recovery, and privacy-preserving per-file encryption with optional cloud
  backup.

## 13. Road to 1.0

- **T Class depth** — the three starters play as genuinely distinct classes, each
  with its own ability kit learned and equipped at the Demon Hub.
- **T Mastery** — abilities travel between elements; mastery becomes the loadout
  economy.
- **T Enemy roster** — a small, readable roster covering melee, ranged, support,
  and airborne, with each room asking a different question.
- **T Biomes** — multiple locations with distinct spatial and emotional
  identities, each playable by all starters.
- **T Interface and feel gaps** — XP-bar tween, cost-affordability visuals,
  controller rumble, audio buses and ducking, room-transition wipe, boss-entry
  performance measurement.
- **T Performance** — the browser build and low-end mobile hit real, measured
  frame budgets.

## 14. Open Questions

- **O** Gold vs. Souls market split — needs play data.
- **O** Stub-gear pricing against the Gold curve.
- **O** Time-to-master for elemental mastery.
- **O** Readability ceiling: do 8–9 actors, telegraphs, and effects read clearly
  at 240×160?
- **O** Are elemental reactions distinct enough for players to learn them by
  feel?
- **O** Where does the vertical-slice acceptance bar stand (support/aerial, one
  optional elemental interaction, one non-elemental solution, reward choice,
  elite/boss)?

Tiny Demons is a soft roguelite: death ends the run, never your progress. It
should feel small, readable, and fast to learn, while allowing many different
decisions to emerge from a few interacting rules. The target is not low content —
it is high content density per rule.
