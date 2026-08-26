# Tiny Demons — Project Direction & Feature Set

> **Status notice — elemental direction partially superseded (2026-08-22).**
> The eight-starting-aspect table, matchup wheel, Arcane/Gray rules, independent
> palette selection, and random-rest-fire assumptions in this document are
> legacy direction. The authoritative elemental design is now
> `docs/Tiny Demons — Elemental Chroma System Design.md`, with technical
> sequencing in `docs/elemental-chroma-implementation-plan.md`. Current base
> aspects are Fire, Water, and Electric; Gray is the natural zero-Chroma state;
> every run begins Gray at 0; and the file's permanently selected starter flame
> appears in the hub for optional or curriculum-required attunement to 100.
> Non-elemental sections of this document remain useful unless contradicted by
> a newer feature document.

> Status: **Design proposal — discussion first.** This is the "what makes Tiny
> Demons *Tiny Demons*" document. It projects the mid-big picture direction and
> defines the feature set that gives the game a distinct identity. Nothing here
> authorizes implementation until the open decisions are resolved.
>
> Companion docs: `meta_progression_design.md` (hub/gear), `combat-economy-overhaul.md`
> (current balance), `ARCHITECTURE.md` (technical boundaries).

---

## The problem this solves

The game plays well but "Tiny Demons" barely shows up in the gameplay yet. The
palette you pick at the start is cosmetic. The loop is dive → fight → loot →
return, and it's competent, but nothing in combat *asks* anything of you beyond
survive-and-swing. To make this game *feel* like its name, we need:

1. A combat identity that is **ours** — a reason to pick a color that matters.
2. A moment-to-moment **skill layer** that rewards attention and timing, not
   just stats.
3. **Loop variety** so a run isn't 10 identical combat rooms.

The elemental-aspect system is the anchor. Everything else hangs off it.

---

## Core pillars

These are the load-bearing ideas. Every feature below must reinforce at least
one of them, or it's scope creep.

1. **Your demon is an element.** The color you pick is your aspect. It shapes
   your spell, your matchups, and which rooms are safe for you.
2. **Combat is about attention, not just stats.** FOCUS rewards deliberate
   target-switching; the combo timer rewards aggressive tempo. A skilled player
   with starter gear should *feel* better than a lazy player with good gear.
3. **Every run asks a different question.** Rooms vary: combat, puzzles, traps,
   choice. You should never be on autopilot.
4. **The rest fire changes aspects** Choosing to rest can change your aspect. so now the hub is the players color choice, but walking up to a fire now brings up a circle icon to interact. This flashes the player white and changes them to the new aspect.

---

## 1. Elemental aspects — the identity system

This is the biggest lever. The 8 player palettes become 8 demon aspects with
real combat meaning.

### Legacy aspect table (superseded)

This table is retained as historical design context only. It is not an
implementation target; use the three-base-aspect Chroma documents linked in
the status notice above.

| Palette | Aspect | Role |
| --- | --- | --- |
| Red | **FIRE** | offensive, damage-over-time flavor |
| Blue | **WATER** | flows/utility |
| Light blue (replaces aquamarine/teal) | **ICE** | control, slows/freezes |
| Green | **GRASS** | sustain/nature |
| Yellow | **ELECTRIC** | speed/burst |
| Orange | **ROCK** | defense/weight |
| Purple | **SHADOW** | utility/ambush |
| Grey | **ARCANE** | the one **neutral**, non-elemental aspect |

### Implementation note on the palette swap
- Remove `aquamarine`; add an `ice` (light blue) palette. Per your note: "use
  the palette step up from the blue as the base." The ICE base should sit one
  step up from WATER's blue in the palette table (see `palette_library.gd`).
- The slime palettes (blue/green/red/purple) currently exist as enemies. With
  the aspect system, slime palettes map to **enemy aspects** (WATER slime is
  weak to ELECTRIC, etc.). This is a big content win for later.

### The matchup wheel (rock-paper-scissors)

The 7 elemental aspects form a strength/weakness web. Arcane is neutral (no
strength, no weakness) — it's the "pure" aspect for players who don't want
matchup math. The elemental wheel is directional, Pokemon-style:

```text
FIRE  beats  GRASS, ICE        |  weak to  WATER, ROCK
WATER beats  FIRE, ROCK        |  weak to  ELECTRIC, GRASS
GRASS beats  WATER, ROCK       |  weak to  FIRE, ICE
ICE   beats  GRASS, WATER      |  weak to  FIRE, ELECTRIC
ELECTRIC beats WATER, ICE      |  weak to  GRASS, ROCK
ROCK  beats  FIRE, ELECTRIC    |  weak to  WATER, GRASS
SHADOW beats  ARCANE           |  weak to  (everything elemental)
ARCANE (neutral)               |  strong vs SHADOW, neutral to all elements
```

> The wheel must be a single source of truth (a data table), readable by both
> combat and the UI. Each matchup: **strong = +50% damage dealt / -25% taken**;
> **weak = -25% dealt / +25% taken**; neutral = 1.0x both ways. Tune from here.

Design intent:
- Every element has two strengths and two weaknesses → no dead picks.
- Arcane is the "safe but unremarkable" pick; Shadow is the "risky glass" pick
  (strong vs Arcane, weak vs everything elemental).
- This is *advisory*, not mandatory. You can beat any room with any aspect;
  the wheel just makes some rooms harder for some aspects.

---

## 2. The triangle-button spell (aspect manifestation)

The triangle button (controller Y / the "spell" input) fires the player's
aspect spell. This is where the element *shows up* in combat.

Each aspect gets **one** spell. Keep them distinct in *behavior*, not just
color:

| Aspect | Spell concept |
| --- | --- |
| FIRE | Ember burst — short-range cone, applies a burn tick |
| WATER | Tide push — knockback wave, pushes enemies away |
| ICE | Frost snap — briefly slows/freezes a target |
| GRASS | Root lash — pulls the locked target toward you |
| ELECTRIC | Arc dash — instant lunge strike, short cooldown |
| ROCK | Bulwark slam — brief guard + ground slam AOE |
| SHADOW | Fade step — brief invulnerable reposition |
| ARCANE | Bolt — a simple, honest projectile |

Spells should consume a resource (the existing **MP** bar that's currently
cosmetic) so they can't be spammed. MP regen on kill or on rest.

> Scope guardrail: build **one** spell first (a projectile) and prove the
> triangle button + MP + aspect-damage pipeline, then build the rest.

---

## 3. FOCUS — the targeting skill layer

Your idea is good and it's exactly the kind of *gameplay juice* the game needs.
Here's the refined version:

**FOCUS mechanic:**
- When you lock a target, you gain **FOCUS** for a short window (~2–3s).
- During FOCUS: your attacks against that target deal **bonus damage** (e.g. +30%).
- After the window: FOCUS decays and your damage against that target drops
  **below baseline** (e.g. -20%) — *less than if you weren't targeting at all*.
- Untargeting and re-locking a different target resets FOCUS.

**Why this is good:**
- It makes target lock a *tactical choice*, not a free always-on buff.
- It rewards active play: pick the right target, burst them, move on.
- It creates the "untarget and retarget" rhythm you described.
- It pairs with the aspect wheel — focus the target you're strong against.

**Tuning values (provisional):**
- FOCUS window: 2.5s
- FOCUS bonus: +30% vs locked target
- Post-FOCUS penalty: -20% vs locked target
- Untargeted damage: 100% (unchanged baseline)

**Juice:** a subtle focus indicator over the locked target (a small shimmer or
color pulse), a "focus lost" vignette tick, and the existing target-lock sound
on lock. When FOCUS expires, a soft negative audio cue.

---

## 4. Combo timer — tempo pressure

A combo timer rewards staying in motion. When you land a hit, a short combo
window opens; each consecutive hit (within the window) builds a combo count and
a small damage bonus; the window resets each time you hit. Letting it lapse
resets the combo.

**Provisional design:**
- Combo window: ~1.5s between hits.
- Each combo step: +5% damage (caps at +25% at 5 hits).
- Getting hit resets the combo to 0.
- Combo count shown as a small counter near the player HUD (not a huge number).

**Why this matters:** it makes aggressive, skillful play *visibly* better and
gives the "harder combat feel" you're chasing without touching enemy HP.

**Synergy with FOCUS:** FOCUS is per-target; combo is global tempo. Together
they reward "lock → burst → move on → keep hitting." The two shouldn't stack
multiplicatively into nonsense — they add as separate percentage categories.

---

## 5. Rest fire aspects — the mid-run pivot

The rest fire flame gets an **aspect color** (RNG when you enter the room).
Touching the flame offers to *re-aspect* your demon: take the flame's aspect in
exchange for your current one. This is the mid-run gamble.

**How it reads:**
- The rest fire's flame is recolored to a random elemental aspect each room.
- Interacting shows a prompt: "TAKE [FIRE] ASPECT?" (with a brief flavor line
  about strengths/weaknesses).
- Accepting swaps your aspect (and your sprite palette) for the run.
- You can decline and keep your aspect.

**Why it's good:** it turns the rest fire from a pure heal stop into a real
*decision point*, and it makes the aspect system something you *interact with
mid-run*, not just a character-creation pick.

**Scope guardrail:** keep it a simple aspect swap + palette recolor. Don't
re-roll your build or change stats.

---

## 6. Room variety — puzzles and traps

Right now every room is a combat room. Variety is the cheapest big win. Keep
these **simple and readable** — they're palate cleansers, not minigames.

### Puzzle rooms (light, fast)
- **Torch order:** light 3-4 torches in a color sequence to open the exit.
  (Great use of the palette colors.)
- **Push-block:** push a single block onto a pressure plate.
- **Timed switches:** hit 2-3 switches before they reset.

### Trap rooms (danger without combat)
- **Spike tiles:** telegraphed floor tiles that deal damage on step.
- **Arrow walls:** wall projectiles on a rhythm you have to dodge through.
- **Collapsing floor:** a path that crumbles, forcing a fast crossing.

These use the existing walkable-area + collision systems. No new engine
features needed — just room generators that emit hazards instead of slimes.

**Pacing:** aim for roughly 1 puzzle or trap room per 4-5 combat rooms so the
dungeon never feels monotonous. The dungeon graph already has room types
(`ROOM_START`, `ROOM_COMBAT`, `ROOM_REST`, `ROOM_DOWNSTAIRS`) — add
`ROOM_PUZZLE` and `ROOM_TRAP` as new types with their own spawn logic.

---

## 7. What makes this "Tiny Demons" and not a generic crawler

The name says small, elemental, and a little mischievous. The systems above
lean into that:
- **Elemental demon aspects** = the title. Your demon IS an element.
- **Rest fire aspect swaps** = the "demon at the flame" fantasy.
- **FOCUS + combo** = the attention-based combat that makes it feel alive.
- **Puzzle/trap rooms** = the dungeon is a place with rules, not just enemies.

If we do these well, "Tiny Demons" stops being a title and becomes the game.

---

## 8. Phased roadmap (the projection)

Build in this order. Each phase is independently shippable and verifiable.

**Phase 1 — Combat juice (do first, biggest immediate fun win)**
- FOCUS targeting mechanic (data table + timer + damage multipliers + indicator)
- Combo timer (window, count, small damage bonus, reset on hit)
- Playtest: FOCUS and combo alone should make combat feel meaningfully better.

> **Status: implemented 2026-08-18.** FOCUS (+30% bonus / 2.5s window / −20%
> penalty) and the hit-streak combo (+5%/hit, +25% cap, 1.5s window, reset on
> hit) shipped as `CombatMomentumComponent` and slot into
> `_player_attack_damage_against`. The "FOCUS" HUD label next to the target
> name is a backfill gauge: it renders in the player's main color and drains
> from the right as the window expires; on draining out it flashes white once,
> then settles grey. The locked enemy's highlight outline also turns grey when
> focus is lost. A soft `ui_decline` cue plays on expiry. Verified by
> `combat_momentum_smoke.gd` (which guards the FOCUS glyph set and the
> grey-outline path).

**Phase 2 — Elemental aspects (the identity)**
- Replace `aquamarine` with `ice` palette; lock the 8 aspects.
- The matchup wheel as a single data table; apply to damage.
- Triangle-button spell: build ONE (ARCANE bolt or a projectile) end-to-end
  with MP. Prove the pipeline.
- Playtest: aspects affect matchups; the spell lands.

**Phase 3 — Aspect variety**
- The rest of the spells (FIRE, WATER, ICE, etc.) one by one.
- Rest-fire aspect swap + flame recolor RNG.
- Slime aspects + which aspect each slime is.

**Phase 4 — Room variety**
- Puzzle rooms (torch order first — palette tie-in).
- Trap rooms (spike tiles first).
- New room types in the dungeon graph + spawn logic.

**Phase 5 — Polish the identity**
- Slime aspects affect their behavior (e.g. ICE slimes slower, ELECTRIC faster).
- Aspect-specific transmutations that hook into the element.
- Boss aspect identity.

**Explicitly NOT yet (scope guardrails):**
- Legendary items, item sets, multiple crafting currencies.
- A walkable hub scene.
- More than one spell until the pipeline is proven.
- Enemy variety beyond slimes until aspects prove themselves.

---

## 9. Open decisions to resolve before building

1. **Aspect matchups** — confirm the wheel and the +50%/-25% damage swing.
2. **Spell resource** — confirm MP as the spell cost + regen source.
3. **FOCUS numbers** — confirm 2.5s window / +30% bonus / -20% penalty.
4. **Combo numbers** — confirm 1.5s window / +5% per hit / cap 25%.
5. **Rest-fire swap** — confirm it's opt-in and run-only (not permanent).
6. **Puzzle/trap pacing** — confirm ~1 special room per 4-5 combat rooms.
7. **The palette swap** — confirm removing `aquamarine` for `ice` (uses the
   "step up from blue" base).

---

## 10. Verification approach

Like the combat-economy overhaul, every system gets a headless smoke test:
- `aspect_wheel_smoke.gd` — every matchup returns the right multiplier.
- `combat_momentum_smoke.gd` — FOCUS timer starts, decays, applies the
  multipliers; combo builds within window, resets on lapse/hit. *(Phase 1,
  implemented.)*
- Existing suite stays green; every balance change re-runs the full runner.

The design doc's job is to give us a **shared projection** so that every feature
builds toward the same identity. When we pick these up, we'll start with Phase 1
(FOCUS + combo) because it's the fastest path to "this feels better."
