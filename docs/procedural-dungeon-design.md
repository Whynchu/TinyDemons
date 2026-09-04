# Procedural Dungeon Design — Generated Run 3+

Status: Implemented — flat difficulty, RNG Hub degree, wandering critical path,
interlocking lower routes, ungated cross-links, and free boss lateral position
are live; event-revealed shortcuts remain an optional future extension.
Design authority: this document
Related: [`run1-dungeon-map-design.md`](run1-dungeon-map-design.md), [`run1-dungeon-map-implementation-plan.md`](run1-dungeon-map-implementation-plan.md), [`elemental-binding-and-fusion-design.md`](elemental-binding-and-fusion-design.md), [`gear-system-rework.md`](gear-system-rework.md)

This document defines the grammar for procedurally generated runs (Run 3 and
later). It is a gameplay and presentation contract, not an implementation
checklist. Run 1 and Run 2 remain authored and are the reference corpus the
grammar must be able to reproduce.

## Design summary

Generated runs should feel like an authored dungeon that has been rearranged,
not a corridor climbed top-to-bottom. The current generated model is a
monotonic spine: every step moves "up" (increasing `y`), and both enemy
difficulty and enemy density scale with `y`. This document replaces that with a
flat, exploratory lattice:

- Difficulty is **flat within a run**: enemy level, count, and variant pool are
  driven by run rank (`difficulty_rank`), not by room depth.
- The **boss** is reached through a "northern" wall door (stairs-up art), but
  its position on the map is free.
- Rooms support **all four socket directions**, and generated routes use loops,
  diamonds, and dig branches — with some intentional dead ends.
- Required backtracking is paired with **shortcuts** that unlock on progress, so
  the return trip is always faster than the outward trip.
- Gates (puzzle color, element, entrance orb) and the milestone room types are
  the only structure that constrains the map; difficulty is never a constraint.

## Design principles

The following decisions are treated as requirements.

### 1. Flat per-run difficulty

Enemy strength is a property of the run, not the room.

| Attribute | Current source | Target source |
| --- | --- | --- |
| Enemy level | `ceil(depth/4) + (run_rank - 1)` | `difficulty_rank` only |
| Enemy count | `0.38 + depth * 0.04` … capped | `difficulty_rank` only |
| Variant pool | unlocked by `YELLOW_MIN_DEPTH`, `GROUND_MIN_DEPTH`, `ICE_MIN_DEPTH`, shadow at depth ≥ 3 | unlocked by `difficulty_rank` |

The only intra-run difficulty spikes are the authored room types:

- **Special Enemy** rooms (already `+1` level and their own respawn policy);
- **Boss** (scales with `difficulty_rank`);
- **Shadow** (purple) slimes (their own low-weight pressure spike).

`depth`/`y` therefore stops meaning "harder" and becomes purely a layout and
landmark-ordering coordinate. The player-facing "D-number" room label is removed
entirely; the room indicator shows only landmark names (START, REST, CLOAKED,
BOSS) and nothing for ordinary combat/treasure rooms.

### 2. Boss is a "northern door", not a northern position

The boss arrival socket must be a **wall socket** (`WALL_LEFT` or `WALL_RIGHT`)
so it renders the stairs-up door art. Its lattice coordinate is otherwise
free — the boss can sit left, right, or centered, as long as the edge into it
reads as a doorway heading up. The boss remains the single "up" landmark; no
other room carries that obligation.

### 3. Hub degree is RNG-chosen

The Hub may be 2-way, 3-way, or 4-way. Four-way support is a capability, not a
mandate. The assembler chooses a Hub's degree based on the routes it wants to
emit:

- **2-way** — a clean linear opening;
- **3-way** — one progression exit plus one optional dig;
- **4-way** — two progression forks (upper) plus two scoutable dig branches
  (lower).

Lower (`BOTTOM_LEFT`/`BOTTOM_RIGHT`) exits are scoutable dig branches: entering
does not engage the room; the first landed hit does. A dig branch may rejoin
the spine later instead of dead-ending.

Implemented lower-route variation is seed-owned: a branch varies between two
and four rooms, can bend toward or away from the Hub, and ends at Treasure or a
utility Fire room. A three-way Hub also seed-chooses which lower side opens, so
different seeds do not merely hide one of two fixed diagonal corridors.

Each available lower route attempts a seeded climb back into the first pre-gate
boss approach. This forms a real Hub-to-spine loop without bypassing the first
Special gate. The assembler also adds seed-selected `rejoin` edges wherever two
rooms naturally touch across an ungated lattice layer; any layer containing a
puzzle-color, element, or entrance-Orb gate is excluded from cross-linking.

### 4. The Hub as a return center is optional

A loop that returns to the Hub is generated only when it makes a good route or
a good puzzle — for example, a Fire or Orb reachable through the Hub that gives
a meaningful state change. The Hub is not a default return point.

## Room vocabulary

Reuse the authored vocabulary from Run 1/Run 2. Generated runs must place, at
minimum, the milestone skeleton:

- one **Hub**;
- two **Orb** rooms (shared global state — the strategic pivot);
- two **Special Enemy** rooms (forward `puzzle_a`/`puzzle_b` gate plus a grey
  `puzzle_b` treasure detour);
- at least one **Fire** room per flame the run teaches (flame acquisition
  source);
- one **Cloaked** room;
- one **Boss**;
- optional **Treasure** rooms (one chest each, chest optional for clear).

Milestones are placed for the teaching curve, not pinned to a `y` column. The
only ordering constraint is logical: a Fire room that teaches a flame must be
reachable **before** the first gate that requires that flame; an Orb is the only
way to change the shared puzzle-color state.

## Topology model

The generator is an assembler, not a walker.

1. **Place the milestone skeleton** on the lattice in an order that matches the
   teaching curve (Orb early, Specials mid, Cloaked once, Boss last), but with
   free coordinates.
2. **Wire the critical path** through the milestones with explicit gates:
   - Specials carry `puzzle_a`/`puzzle_b` forward and a grey `puzzle_b` treasure
     detour;
   - Fires sit on an already-traversable route before the gate they unlock;
   - Orbs are the state pivots.
3. **Fill** with combat/treasure rooms, diamonds (fork → rejoin), dig branches
   that rejoin, and optional loops.
4. **Attach shortcuts** to every required backtrack (see below).
5. **Validate** before handing the layout to `DungeonGraph.initialize_from_layout`.

### The shortcut principle

A "good" build is one where progress improves the route. Concretely:

> Every required backtrack (a trip to an Orb or Fire that gates progress) is
> paired with a **latent shortcut** — a `return`/`rejoin` connection marked
> `hidden_until_clear` (or `hidden_until_event`) that opens on the way back, so
> the second traversal is strictly shorter than the first.

This reuses the existing `hidden_until_clear` / `hidden_until_event` fields and
the Fire-room "revealed entrance" language already in the authored design. A
noisy loop that simply re-enters a cleared combat room with nothing to do is
never generated — loops exist either to explore or to shorten a backtrack.

### Gate and loop invariants

Loops and shortcuts are safe only when they cannot bypass a gate. Two invariants
hold for every connection:

1. **No gate bypass** — an edge may never let the player walk around a
   `puzzle_color`, `element`, or `entrance_orb` gate on the critical path. A
   cross-link or shortcut may only connect rooms under the same effective gate
   state, or lead *into* (not around) a gated area.
2. **No stranding** — changing the shared state (orb/fire) may relock doors, but
   it must never strand the player without a valid exit. The existing color
   solvers already model this; the shortcut/link generator must preserve it.

Entrance-Orb gates latch after a legitimate matching traversal. This keeps the
shared Orb state meaningful for unopened gates while guaranteeing that changing
a later Orb cannot relock an already-crossed gate behind the player.

## Validation contract

The layout is rejected unless all of the following pass before
`initialize_from_layout`:

- existing reachability solvers (`_color_reachable_states`,
  `_element_reachable_states`, boss color/element reachability, fusion gate
  checks);
- a **no-gate-bypass** check over every generated edge;
- a **shortcut coverage** check — every required backtrack has at least one
  `hidden_until_*` shortcut;
- milestone counts (two Orbs, two Specials, one Cloaked, one Boss, required
  Fires);
- socket uniqueness and paired arrival sockets.

Run 1 and Run 2 remain authored fixtures that the grammar's validation and
helpers must accept unchanged, so the authored language stays the regression
baseline for the generator.

## Difficulty model detail

Enemy level, count, and variant pool all derive from `difficulty_rank`
(clamped 1–20, advanced/retreated by the previous run's grade via
`ProgressionController.apply_run_grade`). The boss uses its own
`_generate_boss_encounter`, scaling with `difficulty_rank` rather than depth.
Popcorn (recovery fodder) stays keyed to player level, unchanged.

Concrete mapping (implemented):

- `RoomController.progression_run_rank` is now fed `player_profile.difficulty_rank`
  (see `gameplay_state.gd::_ensure_current_room_layout`) instead of
  `completed_run_count + 1`, so the existing rank milestones keep their 1:1
  meaning while the difficulty source is rank-only.
- Enemy level: `_generated_enemy_base_level` = `maxi(rank - 1, 0)` (capped);
  the `ceil(depth/4)` term is removed, so a rank N encounter peaks at level N.
- Enemy count: base 1→2 roll with no depth multiplier; `_normal_enemy_cap()` and
  `_late_enemy_add_chance()` (both rank-based) still bound the roster.
- Variant pool: unlocked by rank — yellow at rank 2
  (`YELLOW_MIN_RANK`), ground at rank 3 (`GROUND_MIN_RANK`), ice at rank 4
  (`ICE_MIN_RANK`), shadow at rank 3.
- Runtime fallback `enemy_level_for_room` mirrors rank base
  (`maxi(1, rank - 1)`) instead of `ceil(depth/4)`.

Consequence: a shortcut no longer reads as "skipping danger", because no zone is
intrinsically more dangerous than another. Exploration and traversal are pure.

## Non-goals

- No per-room difficulty curve or hidden depth stat in generated runs.
- No generalized multi-color door system beyond the existing puzzle colors and
  element gates.
- No change to authored Run 1/Run 2 topology or content.
- No change to the engagement-lock contract (enter freely, first hit commits,
  clear releases).
- No procedural minimap art that diverges from the established pixel language.

## Open defaults to confirm during review

1. Shortcut frequency — one per required backtrack is the floor; the exact
   density (how aggressively to shorten long branches) is a tuning knob.
2. Whether "up" retains any soft meaning beyond the boss door — currently none;
   wall sockets remain the visual "up" doors, but carry no difficulty meaning.
3. The D-number room label is removed; `depth` remains an internal layout and
   milestone-ordering coordinate only, and is no longer shown to the player.
