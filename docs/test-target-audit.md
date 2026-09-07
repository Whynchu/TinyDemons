# Test Target Audit

Status: initial findings; expand before using affected tests as release evidence

Date: 2026-09-07

## Purpose

Confirm that each test actually exercises the feature, layout, scene, or
contract named by its filename. A passing test with the wrong target is not
coverage for the named feature.

## Known Findings

| Test | Target loaded/used | Expected target | Classification | Action |
|---|---|---|---|---|
| `tests/r4_authored_layout_smoke.gd` | R3 layout/reference path | R4 authored layout | target mismatch | inspect and correct before treating as R4 evidence |
| `tests/r5_authored_layout_smoke.gd` | requires current R5 target verification | R5 authored layout | unverified | inspect scene/script/resource path and assertions |
| `tests/puzzle_map_r4_new_grid_smoke.gd` | R4 grid/reference | R4 new grid contract | pending verification | confirm image/source and assertion scope |
| `tests/puzzle_map_r5_grid_smoke.gd` | R5 grid/reference | R5 authored grid contract | pending verification | confirm image/source and assertion scope |

Additional runner defect:

- `tests/run_all_smoke.ps1` registers `r3_authored_layout_smoke`, but no
  `tests/r3_authored_layout_smoke.gd` currently exists. This must be repaired or
  removed from the registered inventory with an explicit decision; it must not
  be counted as a passing or covered test.

## Evidence From Focused Run

Command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1 -TestFilter '*authored_layout*' -TestTimeoutSeconds 60 -ResultsPath '.godot_user/authored-layout-target-audit.csv'
```

Observed:

- `r3_authored_layout_smoke`: failed to load because the script is missing.
- `r4_authored_layout_smoke`: executed R3 assertions and failed on current R3
  reachability/count expectations; it provided no valid R4 evidence.
- `run2_authored_layout_smoke`: executed Run 2 assertions and failed on its
  clear-gating expectations.
- `r5_authored_layout_smoke` was not selected by the `*authored_layout*` filter
  because the runner's current name/filter inventory needs separate review.

The R4/R5 test files must not be mechanically relabeled. The correct repair is
to create explicit R3, R4, and R5 test contracts, then register each verified
path deliberately.

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
- [ ] R3/R4/R5/R7 tests have explicit layout/version scope.
- [ ] Tests changed alongside gameplay code are reviewed for assertion changes.
- [ ] Test count changes are accompanied by a reason and verification result.
- [ ] The current matrix distinguishes test-target defects from product bugs.
