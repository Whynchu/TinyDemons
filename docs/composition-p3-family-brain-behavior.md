# P3 follow-on — family brain behavior

Status: implemented and accepted in the [composition plan](composition-cleanup-review-plan.md). Focused family brain and replacement checks pass on current source, 2026-10-15; broader P1/P2 gates remain separate.

Scope: Keep decision state and candidate steering in one shared `EnemyBrain`, while moving the first family-specific preferred-distance rules into typed behavior components.

Owner: Enemy behavior and runtime composition

Parent: [Composition and repository cleanup](composition-cleanup-review-plan.md)

Related first slice: [P3 explicit steering-world injection](composition-p3-steering-injection.md)

## Composition contract

`EnemyBrain` remains the shared decision host. It owns timers, target state, candidate generation, and steering score evaluation. Its typed `EnemyBrainBehaviorComponent` reference supplies the family policy needed by the current scoring and target-position code. It does not own actor identity, movement integration, collision geometry, or a gameplay root reference.

The first two policies are `SlimeBrainBehaviorComponent` and `SkeletonBrainBehaviorComponent`. `EnemyActor.ensure_components()` asks the actor family for its component script so scene-authored actors receive the same policy as factory-created actors. `EnemyFactory` maps authored `type_id` to the sibling actor family; the selected actor owns the one source of truth for its brain policy. Both family actors extend the registered `EnemyActor` class by name, which keeps the runtime type check aligned with the factory signature.

The registered brain class is `EnemyBrain`; no `SlimeBrain` class remains. The
file stays at `scripts/components/slime_brain.gd` to preserve authored-scene UID
references. Some runtime coordinator, tuning, and helper names still contain
`Slime`; this slice changes the shared brain identity and family policy, not
every legacy name in enemy orchestration.

## Preserved behavior

- Slimes prefer `attack_range * 0.72`; support positioning widens that preference to at least the configured support range. A Slime inside its desired range keeps approach interest, preserving its melee chase.
- Skeletons prefer a target position 72 pixels from the player. The Skeleton walk controller follows `EnemyBrain.target` and stops within its existing 1-pixel arrival threshold, so this family target rule preserves ranged spacing.
- The shared brain continues to own attack/notice/repath state, candidate order, geometry samples, RNG use, and steering. This slice does not change attack timing, movement cadence, tuning resources, or combat presentation.
- The steering-world injection from the first P3 slice remains the boundary for player, collision, and walkability queries.

## Boundaries

This builds on the P2 sibling actor and definition/factory boundary: the family
hook installs the matching policy for directly authored and factory-created
actors. It does not change roster slots, serialization, room replacement,
preview ownership, or save formats. P1/P2 release acceptance is tracked
separately.

## Verification

- Fresh Godot filesystem scan followed by a `BossRoomDebug` restart: a serialized boss Slime and factory-created Skeleton both had a `FamilyBehavior` child and a non-null typed strategy reference.
- The focused scene run started without editor-console warnings/errors or game-log errors. This is a startup and composition probe, not a mixed-room behavior or release-gate pass.
- MCP script diagnostics passed for the shared brain, behavior base and family scripts, actor hooks, factory, and new smoke.
- `tests/enemy_brain_behavior_smoke.gd` passes on Godot 4.7.1 and 4.7.2, 2026-10-15. It loads the actual boss Slime authoring scene, checks direct Skeleton setup and factory assembly, preserves family ranges, and verifies the Skeleton target used by its walk path.
- `encounter_definition_smoke.gd` passes on Godot 4.7.2, including Slime-to-Skeleton-to-Slime replacement and matching family components.
- These focused results do not advance P1/P2 release acceptance. See [current characterization](composition-p1-characterization.md) for file-backed recovery, export and curated-gate gaps.

## Future boundary

Preserve the Skeleton bone-throw tell and recovery. A future melee Skeleton may
need a different range policy. Broader attack/ability extraction and a complete
rename of Slime-era coordinators or tuning remain separate changes.
