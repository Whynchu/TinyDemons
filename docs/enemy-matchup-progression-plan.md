# Enemy Matchup Progression Plan

Status: future encounter-content design; current matchup implementation is
documented in `elemental-slimes-and-combat-plan.md`

Updated: 2026-09-11

Scope: encounter composition for authored R3–R5 and later content; it does not
replace the stable element catalog or current generated-route validation.

## Purpose

Define how enemy elemental composition should progress from the current early
runs into the authored R3, R4, and R5 puzzle maps. The goal is to teach
elemental advantage gradually, then make the two-flame R4 dungeon use its
matchups intentionally rather than relying on one global random pool.

## Terminology and exact mappings

The encounter contract uses the flame chosen for the run, not the player's
temporary current Chroma color. Changing Chroma during a run must not change
the composition of an unvisited authored room.

The run flame is resolved once at run start: use the permanent bound flame when
one exists; otherwise use the original game-start flame. Binding during an
active run never changes that run's encounter composition. The new identity
takes effect only after the current run is completed or the player dies and a
new run begins.

The base elemental variants are:

| Element | Enemy variant key | Palette |
| --- | --- | --- |
| Normal | `grey` | Grey |
| Fire | `red` | Red |
| Water | `blue` | Blue |
| Electric | `yellow` | Yellow |
| Grass | `green` | Green |

“Player advantage” means the enemy is intentionally vulnerable to the named
player flame. Use this exact mapping:

| Player/flame element | Vulnerable enemy element | Enemy variant |
| --- | --- | --- |
| Fire | Grass | `green` |
| Water | Fire | `red` |
| Electric | Water | `blue` |

“Enemy advantage” means the enemy is the intended counter to the named player
flame. Use this exact authored progression mapping:

| Player/base element | Counter enemy element | Enemy variant |
| --- | --- | --- |
| Fire | Water | `blue` |
| Water | Electric | `yellow` |
| Electric | Grass | `green` |

These tables are the design contract. Encounter generation should not derive a
different answer from generic palette order or from a mutable runtime color.

## Current implementation

The encounter generator currently builds a weighted variant pool in
`scripts/room_controller.gd`:

- R1 uses Normal Slimes only.
- R2 adds a preferred elemental variant based on the player's current palette.
- R3 and later add the remaining base elemental variants to the pool instead
  of applying the intended R3 counter mapping.
- Later progression adds Yellow, Orange, Aquamarine, and Shadow variants by
  rank.
- Popcorn flags are assigned per encounter slot and respawn independently.

The current R2 preferred-variant mapping is now:

| Player element | R2 enemy element | Teaching intent |
| --- | --- | --- |
| Water | Fire | Player has an advantage |
| Electric | Water | Player has an advantage |
| Fire | Grass | Player has an advantage |

This is currently supplied as one room-controller preference. It does not yet
distinguish authored rooms or route branches, and it incorrectly uses a
mutable current palette instead of the run-locked base flame.

## Target progression

### R1 — Normal fundamentals

Use Normal Slimes only, with popcorn support. R1 should teach movement,
attacks, blocking, and room completion without asking the player to interpret
elemental matchups.

### R2 — Player advantage

Keep Normal Slimes as the majority and introduce the element that is weak to
the player's current element. The existing mapping is the intended teaching
contract:

- Water player receives Fire enemies.
- Electric player receives Water enemies.
- Fire player receives Grass enemies.

The elemental group should be readable and predictable, not a broad random
elemental lottery.

### R3 — Enemy advantage

R3 should reverse the lesson. Its elemental group should counter the
run-locked base flame, while Normal Slimes remain present as a baseline:

- Water player receives Electric enemies.
- Electric player receives Grass enemies.
- Fire player receives Water enemies.

R3 should be the first authored dungeon where the player is encouraged to
change Chroma defensively rather than simply exploiting the current flame.

Shadow binding is the deliberate exception to the ordinary R3 teaching pool.
Across all runs, a player whose run-start identity is permanently bound to
Shadow should see most Normal/grey encounter slots converted to Shadow Slimes.
Normal Slimes remain as an occasional relief encounter at approximately 20%
of those otherwise-normal slots. Existing elemental variants may remain in
the pool. This Shadow-specific composition is based on the run-start bind, not
temporary Shadow fusion, and does not change if the player binds midway through
the active run.

### R4 — Two-flame matchup dungeon

R4 contains two meaningful flame types:

- Flame A: the Hub/base flame.
- Flame B: the second flame introduced by the dungeon.

R4 encounters should use two deliberate enemy families:

- Mob Type 1 is weak to Flame A.
- Mob Type 2 is weak to Flame B.

Resolve each family independently through the player-advantage table above:

| Room role | Relevant flame | Enemy family |
| --- | --- | --- |
| Flame A target | Flame A is Fire | Grass / `green` |
| Flame A target | Flame A is Water | Fire / `red` |
| Flame A target | Flame A is Electric | Water / `blue` |
| Flame B target | Flame B is Fire | Grass / `green` |
| Flame B target | Flame B is Water | Fire / `red` |
| Flame B target | Flame B is Electric | Water / `blue` |

A mixed R4 room contains both resolved families. For example, if Flame A is
Water and Flame B is Electric, the room contains Fire (`red`) enemies and
Water (`blue`) enemies. Normal Slimes may fill remaining slots, but unrelated
elemental variants must not enter that room's pool.

The first R4 rooms should establish the families separately. Later rooms may
mix both families, but the encounter should still communicate which flame is
the intended answer. Normal Slimes can fill neutral rooms and soften mixed
encounters.

### R5 — Broader authored mixing

R5 can combine the R4 families more freely with neutral, counter, and later
elemental variants. It should be the first authored map where the player is
expected to read room context and switch between several established matchup
patterns.

## Required implementation changes

### 1. Replace the single preferred variant with matchup policy

Keep the current global preference for R1/R2, but add a typed encounter policy
for authored rooms. The policy should be able to express:

- neutral-only;
- player-advantage element;
- player-counter element;
- Flame A target family;
- Flame B target family;
- mixed Flame A/Flame B families.

The policy should carry resolved enemy variant keys rather than recalculating
them during every spawn. Suggested policy IDs are `neutral_only`,
`base_advantage`, `base_counter`, `flame_a_target`, `flame_b_target`, and
`flame_a_b_mixed`.

### 2. Add authored room matchup metadata

R4 and R5 room manifests should assign a matchup role to each combat room or
route branch. This metadata belongs in the authored layout contract rather
than being inferred from runtime room depth. The first rooms on each R4 branch
should use a single family; mixed roles should appear only after both flames
have been introduced.

### 3. Preserve encounter determinism

The same room seed, run-locked Flame A, and run-locked Flame B must produce the
same matchup family and slot composition. R2/R3 use Flame A as their immutable
base-element input. R4 uses the authored room role plus Flame A/Flame B. The
player's temporary current Chroma color is not an encounter-generation input.

### 4. Delay unrelated variants until the teaching sequence is complete

R1 must not generate elemental variants. R2 and R3 must not receive unrelated
Yellow, Orange, Aquamarine, or Shadow variants from the global rank pool. R4
uses only its authored Flame A/Flame B families plus Normal Slimes. The broad
rank-driven pool begins in R5 unless a room explicitly declares a narrower
authored role.

### 5. Keep popcorn independent

Popcorn remains a slot property. It should not change the room's matchup role,
and its 45-second respawn timer should continue to work while the player is in
another room.

### 6. Shadow-bound encounter identity

Shadow Slimes remain rank-gated for unbound runs and retain their later pressure
role. A permanently Shadow-bound run may opt into the Shadow replacement policy
at any run rank where Shadow is available. The policy should replace roughly
80% of Normal/grey slots with Shadow and leave roughly 20% Normal relief slots;
it must not rewrite explicitly authored elemental slots. Shadow's vulnerability
windows remain combat tuning, separate from matchup selection.

## Validation requirements

Add focused coverage for:

- R1 never generating elemental variants;
- R2 mapping each supported player element to its intended weak enemy;
- R3 mapping each supported player element to its intended counter enemy;
- R2/R3 using the run-locked base flame even after current Chroma changes;
- binding Shadow before a run replaces most Normal slots with Shadow while
  retaining approximately 20% Normal relief slots;
- binding during a run leaving all already-generated and future encounter pools
  unchanged until death or run completion;
- R4 separating Flame A and Flame B room families;
- R4 mixed rooms containing both intended families without random unrelated
  elements;
- R1–R4 excluding unrelated rank-pool variants;
- encounter seeds producing stable family assignments;
- popcorn flags and respawn timers remaining unchanged by matchup policy;
- Shadow vulnerability and shield-block windows remaining rank-gated and
  independently testable.

## Design boundary

Do not fold the R4 matchup policy into the global random variant pool. The
global pool is appropriate for generated late-run content; authored R4/R5
rooms need explicit intent so the puzzle and combat progression reinforce each
other.
