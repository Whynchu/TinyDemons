# R8+ Origin-Aware Progression Implementation Plan

Status: historical compatibility reference; mandatory generated fusion tiers
are superseded by the active R6+ risk/reward generation plan

Plan date: 2026-09-06

Companion: [`generated-fusion-gate-inspection.md`](generated-fusion-gate-inspection.md)
records the original topology audit. This plan replaces the incomplete R8+
implementation pass with one explicit traversal contract.

Current direction: [`r6-plus-risk-reward-generation-plan.md`](r6-plus-risk-reward-generation-plan.md)
owns generated Run 6+ topology and intentionally removes mandatory fusion-door
progression. The runtime Orb state, fusion recipes, binding behavior, and save
compatibility described here remain useful supporting context; the mandatory
two-tier route contract below applies only to historical compatibility code and
fixtures.

## Outcome

Every R8+ dungeon must provide a complete, traversable two-tier elemental
curriculum based on the flame bound when the run begins. Each tier must place
its ingredients and matching Orb before its mandatory gate. Normal puzzle state
and ordinary puzzle-color doors remain part of the route system and must be
validated alongside elemental and entrance-Orb gates.

The same implementation pass must also finish the R8 Orb-position correction,
special-enemy persistence, spawn introductions, and backtracking popcorn rules.

## Non-negotiable invariants

1. Every R8+ origin produces two ordered mandatory entrance-Orb gates.
2. The topology is always:
   `ingredients A -> Orb A -> gate A -> ingredients B -> Orb B -> gate B`.
3. Each prerequisite Orb and every ingredient needed to charge it are reachable
   without crossing that Orb's gate.
4. Normal doors, starter-color doors, fused-element doors, and ordinary open
   connections are represented by the same traversal proof.
5. A mixed element does not satisfy a Normal or primary-color puzzle door.
6. Returning to Normal can reopen a Normal route and relock an unsolved colored
   route. A traversed entrance-Orb gate retains its existing solved latch.
7. Binding a flame updates the active Hub/binding state immediately. A new run
   uses the currently bound flame as its origin; an already generated dungeon is
   not silently regenerated.
8. Generated Orb placement uses the loaded room geometry unless an authored
   `OrbCenterGuide` exists.
9. A living special-room enemy retains its health and position across room
   transitions. Only a defeated enemy enters its respawn schedule.
10. Every enemy introduced after room entry uses the spawn animation and remains
    non-collidable/non-combat-active until that animation completes.

## Origin curricula

R8+ uses a deterministic curriculum for each primary origin. Seed variation may
change route shape and optional doors, but must not remove either mandatory tier.

| Run origin | Tier A | Tier B |
| --- | --- | --- |
| Fire | Fire + Water -> Shadow | Water + Electric -> Grass |
| Water | Water + Electric -> Grass | Grass + Water -> Ice |
| Electric | Electric + Water -> Grass | Grass + Water -> Ice |

Normal is a real traversal state, not a fusion recipe. Seeded Normal doors may
block one path while opening another, in the same style as R2 puzzle routing,
but they do not replace either mandatory R8+ fusion tier.

## Implementation sequence

### 1. Replace the fusion-plan fallback

Owner: `scripts/dungeon_layout_generator.gd`

- Replace the Water/Electric special case plus Fire fallback with an explicit
  curriculum table for Fire, Water, and Electric.
- Give every curriculum two ingredient sets, two gate requirements, and two
  prerequisite-Orb branch depths.
- Place Fire's second-tier Water and Electric rooms after gate A and before Orb
  B. Do not reuse Shadow as a fusion input because no such recipe exists.
- Keep optional Normal and primary-color puzzle doors in the generated route,
  but stop treating the old synthetic `normal` fusion option as a substitute
  for a mandatory fusion gate.
- Add a primary Fire Room immediately before the late Special Room on fusion
  runs so a fused result can restore the color required by that door.
- Use the bound flame as the run origin when it is elemental; otherwise use the
  starter flame.

Checkpoint: sampled Fire-, Water-, and Electric-origin R8 layouts each contain
exactly two ordered entrance-Orb gates.

### 2. Make traversal validation state-complete

Owner: `scripts/dungeon_layout_generator.gd`

- Replace the separate permissive color and element proofs for mandatory routes
  with one state containing room, carried flame/element, shared Orb element, and
  ordinary puzzle color.
- Traverse connections bidirectionally, matching runtime room transitions.
- For per-gate prerequisite checks, block only the exact gate connection while
  preserving all other bidirectional routes.
- Apply all gate rules during the search:
  - no gate requirement for ordinary open connections;
  - exact puzzle color for puzzle-color doors, including `puzzle_b`/Normal;
  - exact carried element for element doors;
  - exact shared Orb element for entrance-Orb doors.
- Carry solved entrance-Orb connection keys in the traversal state so charging
  a later shared Orb cannot incorrectly relock a gate the player has already
  crossed.
- Prove both that each gate source is reachable and that its required state can
  be produced on the approach side.
- Keep optional reward-only routes out of boss-progression failures, while still
  checking that their declared requirements are internally valid.

Checkpoint: removing either prerequisite Orb or moving an ingredient behind its
gate makes validation fail with the affected tier and connection identified.

### 3. Correct runtime binding ownership

Owners: `scripts/gameplay_state.gd`, `scripts/dungeon_map_controller.gd`

- Keep `PlayerChromaComponent`, profile persistence, and map state synchronized
  when binding changes.
- Emit `map_state_changed` only when the bound flame actually changes.
- Ensure Hub flame availability reads the current bound flame immediately.
- Confirm `begin_run()` passes both starter and current bound flame into build,
  repair, and validation.
- Keep the generated layout origin separate from the current persistent bind so
  an active run is not regenerated after rebinding or after recovery. The
  changed bind becomes the origin for the next generated run.

Checkpoint: Fire starter + Water bind generates the Water curriculum; rebinding
to Electric before the next run generates the Electric curriculum.

### 4. Finish the R8 Orb-position fix

Owner: `scripts/room_puzzle_controller.gd`

- Compute the fallback from `walkable_outline` bounds.
- Use `OrbCenterGuide.global_position` when that authored marker exists.
- Remove the unconditional assignment of `map_root.to_global(ORB_AUTHORING_CENTER)`
  that currently overwrites the bounds-derived result.
- Preserve the existing Orb node during palette-only updates.

Checkpoint: generated shifted R8 rooms place the Orb at the loaded puzzle
footprint center; authored rooms still follow their guide marker.

### 5. Finalize special-enemy persistence and spawn introductions

Owner: `scripts/room_controller.gd`

- Save alive state, health, and world position before leaving a room.
- On re-entry, restore living slots directly and do not create respawn timers
  for them.
- Keep defeated slots hidden until their existing timer completes.
- Use animated spawning for first entry, special-enemy respawns, popcorn
  respawns, and newly injected backtracking popcorn.
- Clear a pending introduction flag only after the spawn animation actually
  starts; retain it when placement temporarily fails.

Checkpoint: damage a special slime, leave, and return. It must appear at the
saved position and health without replaying a spawn or entering a reset timer.

### 6. Normalize backtracking popcorn behavior

Owner: `scripts/room_controller.gd`

- Eligible rooms are Hub, Combat, Treasure, Downstairs, and Special Enemy.
  Fire/Rest, Cloaked/NPC, Orb, and Trader remain excluded.
- Define the roll as once per room per run. Record the attempt consistently
  whether it succeeds, fails, or the room has no free actor slot.
- Use a deterministic room/run seed so saves and reloads cannot reroll.
- A successful injection appends one grey popcorn slot, marks the room active,
  and introduces that slot with the standard spawn animation.
- Do not overwrite living runtime entries or resurrect defeated special slots.

Checkpoint: revisiting the same room cannot duplicate popcorn or repeatedly
reroll; different room/run seeds still produce varied appearances.

## Verification coverage

### Generator smoke coverage

Update `tests/generated_layout_smoke.gd` to sample all three origins separately.
For each origin and sampled seed, assert:

- exactly two mandatory entrance-Orb gates;
- gate A and gate B occur at their declared curriculum tiers;
- each gate has one dedicated prerequisite-Orb branch;
- required ingredients are reachable before that Orb and gate;
- boss progression remains reachable through Normal, ordinary, and elemental
  route-state changes;
- starter Fire + bound Water matches Water-origin topology;
- starter Fire + bound Electric matches Electric-origin topology.

Remove the current aggregate `>= 5` assertion. It combines incompatible origin
samples and is guaranteed to disagree with the filtered Fire curriculum.

### Scene/runtime smoke coverage

Update `tests/generated_fusion_gate_scene_smoke.gd` to traverse both tiers in
order rather than charging only the first Orb directly:

1. reach ingredients A;
2. produce result A;
3. reach and charge Orb A;
4. cross and latch gate A;
5. reach ingredients B;
6. produce result B;
7. reach and charge Orb B;
8. cross and latch gate B;
9. change the shared Orb state and verify both traversed gates remain available
   for return travel.

Add focused characterization for:

- Normal versus colored puzzle doors;
- shifted generated Orb placement versus authored guide placement;
- living special-enemy re-entry;
- defeated special-enemy respawn animation;
- one-shot deterministic backtracking popcorn in every eligible room family.

The late-run regression fixtures also include seeds `2196629887`, `3217254121`,
and `2448781665` with starter `water` and bound `shadow`.

## Verification order

Because an MCP Godot editor peer may be connected, verification follows the
project safety rule:

1. Run script diagnostics for every edited owner and focused smoke test.
2. Launch the main scene through MCP and inspect new runtime errors.
3. Exercise the two-tier route and room re-entry scenarios through focused MCP
   playtests where practical.
4. Run one focused standalone smoke only when no competing runtime is active.
5. Run `tests/run_all_smoke.ps1` only as a supervised standalone step after the
   local headless `user://logs` crash is resolved and no MCP runtime is active.

## Completion checklist

- [x] Fire, Water, and Electric origins each generate two valid R8+ tiers.
- [x] Normal and ordinary doors participate in the unified traversal proof.
- [x] Every prerequisite is reachable without crossing its own gate.
- [x] Rebinding changes the next run's origin and current Hub presentation.
- [x] Generated R8 Orb position follows loaded geometry.
- [x] Living special enemies persist without reset or spawn replay.
- [x] All new and respawned enemies use spawn introductions.
- [x] Backtracking popcorn is deterministic, one-shot, and correctly scoped.
- [x] Both R8+ gates are exercised by scene-level regression coverage.
- [x] Focused diagnostics and runtime checks pass.
- [ ] Full smoke suite passes in a stable standalone Godot environment.

The full standalone suite remains intentionally unchecked: this environment's
Godot 4.7.1 headless renderer crashes before smoke assertions run. The connected
editor pass is clean, and the focused scripts are registered for the next stable
standalone run.
