# Generated Route Audit

Status: historical finding; addressed by the active R6+ risk/reward generator
plan, with runtime verification still pending

Audit date: 2026-09-07

The active implementation is documented in
[`r6-plus-risk-reward-generation-plan.md`](r6-plus-risk-reward-generation-plan.md).
The compact-bound and mandatory-fusion findings below describe the superseded
route contract and remain useful as regression history.

## Current Evidence

Focused batch:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1 -TestFilter '*generated*' -TestTimeoutSeconds 90 -StopAfterEngineCrashes 2 -ResultsPath '.godot_user/generated-current.csv'
```

Observed:

- `generated_layout_smoke` timed out after 90 seconds.
- `generated_flame_progression_smoke` passed.
- `generated_fusion_gate_scene_smoke` exited successfully but logged repeated
  invalid R7 route diagnostics.
- `generated_minimap_smoke` failed an entrance-Orb gate color assertion.
- `generated_run_scene_smoke` passed.
- `generated_bound_reachability_smoke` exited successfully after logging invalid
  route diagnostics and a test-side `RoomSpec.depth` access error in an earlier
  run; the latest batch completed without a process crash but still emitted
  invalid-layout errors.

## Generated Route Findings

`scripts/puzzle_route_generator.gd` owns the native R7 path when
`completed_runs == 6`. `dungeon_layout_generator.gd` continues to own legacy
generated ranks, including later R8/R12 compatibility cases. The smoke output
must keep those paths separate.

### Compact coordinate violations

The generator reports rooms and connections outside the 35×35 bounds, including:

```text
room_-2_-2 at (13, 36)
room_-1_-3 at (15, 38)
room_0_-4 at (17, 40)
room_-1_17 at (15, -2)
room_-3_17 at (11, -2)
```

The violations occur in multiple seed/origin cases, including ordinary and
bound-reachability tests. They are deterministic, not random noise. The
observed examples are currently mixed across generated R8/R12 compatibility
tests and native R7 validation, so the next diagnostic must label the run rank
and generator owner for each failure before code changes.

### Likely source boundaries

Native R7 stores logical room coordinates in `add_room()`, then maps them to
minimap coordinates with:

```gdscript
Vector2i(17, 32) + Vector2i(coordinate.x * 2, -coordinate.y * 2)
```

The native generator maps logical coordinates into minimap coordinates using a
fixed origin and two-pixel spacing. The legacy generator has its own coordinate
construction and repair path. Side pockets and route branches can exceed the
assumed vertical range in either path, producing negative or greater-than-34
minimap coordinates.

This is an investigation lead, not yet a confirmed correction. Changing an
origin, clamping coordinates, repairing legacy layouts, or rotating routes would
have different gameplay and presentation consequences.

### Progression validation

The generator also reports:

```text
R7 progression requires exactly one mandatory fusion gate, got 2
```

The route currently creates a gate at depth 7 and may classify another route
edge as mandatory through planner/route metadata. The correct fix must preserve
the intended curriculum, not merely suppress the validation message.

## Related Contract Failures

`generated_minimap_smoke` fails because the rendered entrance-Orb gate color does
not match the mixed element expected by the test. This may be downstream of the
invalid route or a separate presentation-owner defect. It should be rerun after
the route is valid before changing minimap color logic.

`generated_bound_reachability_smoke` also contains a test-side helper that reads
`RoomSpec.depth`, even though the layout-definition room spec exposes logical
coordinates rather than the runtime graph's `depth` property. That harness
error must be classified separately from route validity.

## Next Investigation

1. Print the generator owner, run rank, seed, logical route, and mapped
   coordinates for each failing seed.
2. Identify the maximum logical X/Y range required by each generator path.
3. Decide whether the compact map origin, route shape, legacy repair, or
   side-pocket policy is
   authoritative.
4. Count mandatory fusion gates from the final compiled route and planner roles.
5. Re-run `generated_layout_smoke` and `generated_bound_reachability_smoke` after
   each isolated change.
6. Only then triage the minimap color assertion.

Do not fix this by clamping out-of-bounds coordinates or suppressing validation
errors. Either change the route construction so it fits, or revise the compact
map contract with explicit design approval.
