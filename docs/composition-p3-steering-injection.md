# P3 first slice — explicit steering world

Status: implemented. Current P3 acceptance is recorded in the [composition plan](composition-cleanup-review-plan.md); the focused smoke remains unverified.

Scope: Remove `EnemyBrain`'s ancestor search for the world services used by its aggro steering decision.

Owner: Enemy behavior and runtime composition

Parent: [Composition and repository cleanup](composition-cleanup-review-plan.md)

## Source trace

Before this slice, `EnemyBrain.context_steering_direction()` climbed the actor's
parents until it found `_is_slime_collision_rect_walkable_at`, cast that node to
`GameplayState`, then reached through the root for its player, collision system,
combat controller, and slime geometry controller. The runtime coordinator
already has those references when it starts a scoot.

`EnemySteeringWorld` is a narrow, shared service owned by
`SlimeRuntimeController`. The runtime configures it with the player,
`ActorCollisionSystem`, and `WalkableArea`; the service uses `ActorGeometry`, the
existing `SlimeGeometryQueries`, and the generic `EnemyActor.is_defeated()`
capability. It does not hold a `GameplayState` reference. The controller reuses
one service instance instead of allocating a context for each movement choice.

`EnemyBrain.start_scoot()` now receives that service explicitly. Its steering
decision still uses the same direction candidates, geometry samples, neighbor
filters, family range preferences, support positioning, random orbit, and
scoring weights. Movement integration remains on its existing scheduled tick.
The geometry query root-facing methods now delegate to area-based helpers so
steering and existing callers share the same collision and walkability logic.

## Bounded scope

- Included: actor foot and collision polygon queries, neighbor candidates,
  defeated-state checks, and walkability used by aggro steering.
- Preserved: score order, tuning, RNG use, Skeleton/support/boss branches,
  movement distance, collision samples, and start/stop timing.
- Deferred: `EnemyBrain.aggro_target()`'s explicit root parameter, attack
  execution, family strategy extraction, tuning ownership, and optional behavior
  recipes. These need their own source contracts and characterization; the
  family range seam is now tracked separately in
  [P3 family brain behavior](composition-p3-family-brain-behavior.md).

## Evidence and acceptance

- MCP script diagnostics pass for the new service, geometry queries,
  `EnemyBrain`, `SlimeRuntimeController`, and the new smoke script.
- The fixed-seed boss-room scene ran after the change with no editor/runtime
  errors. The screenshot showed the live boss encounter, Skeletons, and effects;
  this is a focused playtest, not the release gate.
- `tests/enemy_steering_world_smoke.gd` characterizes the shared actor foot,
  collision walkability, bounds rejection, and steering toward an injected
  player when the actor has no `GameplayState` ancestor. It is registered as
  unverified. Keep that result truthful; the user accepted the slice based on
  the shared `EnemyBrain` architecture and observed Slime/Skeleton behavior.
  The smoke and P1/P2 performance or release gates are separate from this P3
  acceptance.
