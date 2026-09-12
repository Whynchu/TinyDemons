# Test Target Audit

Status: initial findings; expand before using affected tests as release evidence

Date: 2026-09-12

Baseline: version `0.2.00`; expand this audit before using affected tests as
release evidence.

Current release: version `0.2.01`

## Purpose

Confirm that each test actually exercises the feature, layout, scene, or
contract named by its filename. A passing test with the wrong target is not
coverage for the named feature.

## Known Findings

| Test | Target loaded/used | Expected target | Classification | Action |
|---|---|---|---|---|
| `tests/r3_authored_layout_smoke.gd` | R3 compiler/runtime layout | R3 authored layout | verified | retain as the R3 authored contract |
| `tests/r4_authored_layout_smoke.gd` | R4 compiler/runtime layout | R4 authored layout | verified | retain as the R4 authored contract |
| `tests/r5_authored_layout_smoke.gd` | R5 compiler/runtime layout | R5 authored layout | verified | retain as the R5 authored contract |
| `tests/puzzle_map_r4_new_grid_smoke.gd` | R4 grid/reference | R4 new grid contract | pending verification | confirm image/source and assertion scope |
| `tests/puzzle_map_r5_grid_smoke.gd` | R5 grid/reference | R5 authored grid contract | pending verification | confirm image/source and assertion scope |

The runner now registers all three authored-layout contracts deliberately.

## Historical wrapper evidence — 2026-09-07

Command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1 -TestFilter '*authored_layout*' -TestTimeoutSeconds 60 -ResultsPath '.godot_user/authored-layout-target-audit.csv'
```

Observed:

- `r3_authored_layout_smoke`: passed its explicit R3 identity, validation, and
  runtime-selection assertions.
- `r4_authored_layout_smoke`: passed its explicit R4 identity, validation, and
  runtime-selection assertions.
- `r5_authored_layout_smoke`: passed its explicit R5 identity, validation, and
  runtime-selection assertions.
- `run2_authored_layout_smoke`: executed Run 2 assertions and failed on its
  clear-gating expectations.

The R3/R4/R5 target mismatch is corrected. Their pixel-perfect grid tests remain
separate contracts and still fail independently where the authored image does
not match the manifest.

Historical post-`0.1.78` grid evidence:

The results below document an earlier target-repair pass. They remain useful
for provenance, but do not constitute a complete `0.2.00` release matrix.

- `puzzle_map_r4_new_grid_smoke`: target is correctly R4. The reference diff
  identified two missing Treasure markers at `(19,15)` and `(15,19)`; adding
  them and updating the manifest count from 49 to 51 made the test pass.
- `puzzle_map_r5_grid_smoke`: target is correctly R5. The old reference image
  represented a pre-renumbering R4/R5 state; it was rebuilt from the desired
  current R5 manifest and the pixel/parser contract now passes.

These are valid R4/R5 contract failures, unlike the misnamed authored-layout
tests. They should be triaged separately from test-target repair.

The R5 reference can be regenerated with `tools/rebuild_r5_reference.gd` when
the authored manifest is intentionally changed. The old image remains available
through Git history rather than being preserved as a competing runtime source.

## Revised Runner Evidence

The runner now supports:

- `-InventoryOnly` for preflight path inventory;
- `.inventory.csv` output alongside result CSVs;
- explicit `missing` results for absent scripts;
- `engine_start_failure` classification; and
- `engine_crash` classification with a configurable repeated-crash stop gate.

The authored-layout batch was rerun after the target repair. This is retained as
historical evidence because the current direct baseline below is the authoritative
result for `0.2.00`.

| Test | Result |
|---|---|
| `r3_authored_layout_smoke` | pass |
| `r4_authored_layout_smoke` | pass |
| `r5_authored_layout_smoke` | pass |
| `run2_authored_layout_smoke` | fail: existing clear-gating assertions |

The R3/R4/R5 target repair is therefore evidenced. Run 2 remains a separate
gameplay-contract failure.

## Run 2 Gate Diagnosis

The original Run 2 assertions queried `is_connection_available()` from the
run-start context. Authored runs intentionally use current-room and arrival
state in that method, so those calls did not model traversal through the source
combat room. The code also treats the rare lower-side branch entrance and the
source room's forward clear gate as separate contracts.

The test now asserts the authored contract directly:

- the rare branch allows destination entry before source clear;
- the source exit remains `requires_source_room_clear`;
- the Special Room route carries its Puzzle A requirement and source-clear gate;
- the Special Room completion is recorded.

The later focused rerun result for `run2_authored_layout_smoke` passed. This was
a test setup defect, not evidence that gameplay allowed early entry.

## Current standalone baseline — 2026-09-11

Inventory preflight:

```text
registered=113
missing=0
```

Focused tests were invoked directly with the Godot console executable because
the process-per-test wrapper reported false timeouts for tests that completed
successfully. No Godot editor peer or runtime was active during this pass.

Confirmed passing tests:

- `dungeon_map_event_smoke`
- `r3_authored_layout_smoke`
- `r4_authored_layout_smoke`
- `r5_authored_layout_smoke`
- `run2_authored_layout_smoke`
- `run1_room_prefab_smoke`
- `slime_spawn_smoke`
- `enemy_room_engagement_smoke`
- `gear_effect_contract_smoke`
- `gear_slot_migration_smoke`
- `chroma_state_smoke`
- `chroma_pickup_smoke`
- `aspect_ability_smoke`
- `starter_flame_smoke`
- `generated_flame_progression_smoke`

Confirmed failing tests:

| Test | Current assertion evidence |
|---|---|
| `active_run_recovery_contract_smoke` | A valid snapshot failed schema/slot validation. |
| `cloud_save_contract_smoke` | Cloud panel lacks the expected explicit runtime-safe types. |
| `wall_socket_geometry_smoke` | Closed seams remain enterable or lack expected trigger fences. |
| `demon_hub_menu_scene_smoke` | Hub root, shop cursor, shop geometry, and sell amount assertions fail. |
| `equipment_menu_scene_smoke` | Equipment cursor animation/selection and post-equipment shop cursor assertions fail. |
| `touch_controls_smoke` | Hub stat-row and outside-button touch assertions fail; one signal call has an argument mismatch. |
| `gear_catalogue_expansion_smoke` | Starter package and runtime presentation expectations fail. |
| `gear_drop_policy_smoke` | Shop baseline/premium/cloak inventory expectation fails. |
| `elemental_binding_smoke` | R7 bounds/gate validation and two binding assertions fail. |
| `generated_minimap_smoke` | Destination cursor is ordered behind the opaque full-map texture. |
| `run1_minimap_smoke` | An undiscovered room remains visible. |
| `run_music_flame_gate_smoke` | Dungeon-Crawl music does not start after starter-flame pickup under the test contract. |

`r7_native_generator_smoke` did not complete. It repeatedly reported an R7 room
outside the compact map (`room_9_11` at `(35, 10)`) before its worker stalled.
`menu_route_scene_smoke`, `gear_system_rework_smoke`,
`cloud_panel_touch_smoke`, and `touch_menu_scroll_smoke` did not produce a
reliable result in this pass because their standalone workers stalled around
the add-on MCP runtime startup/teardown path. They remain unverified.

The repeated root-certificate and MCP registry messages are environment
warnings. They appeared in direct runs and were not counted as test failures.

This is an initial list, not a complete audit.

## Audit Procedure

For each registered test:

1. Confirm the file exists and is included by the runner.
2. Identify every scene, script, resource, image, and fixture it loads.
3. Identify the primary owner under test.
4. Compare the filename and description with the actual target.
5. Check whether assertions test behavior, structure, visual data, or only
   construction.
6. Record target mismatches, stale expectations, and missing coverage.

## Result Labels

- **Verified** - target and assertions match the test name.
- **Target mismatch** - test loads or asserts a different feature/version.
- **Stale contract** - target is correct but expected behavior is obsolete.
- **Harness defect** - setup/mock/fixture prevents the intended test.
- **Partial coverage** - test touches the target but does not establish the
  claimed contract.
- **Unknown** - requires runtime or asset inspection.

## Exit Criteria

- [ ] Every runner-registered test has a target classification.
- [x] R3/R4/R5 authored-layout tests have explicit layout/version scope.
- [ ] Tests changed alongside gameplay code are reviewed for assertion changes.
- [ ] Test count changes are accompanied by a reason and verification result.
- [ ] The current matrix distinguishes test-target defects from product bugs.
