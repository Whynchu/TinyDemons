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
| `tests/r3_authored_layout_smoke.gd` | R3 compiler/runtime layout | R3 authored layout | verified | retain as the R3 authored contract |
| `tests/r4_authored_layout_smoke.gd` | R4 compiler/runtime layout | R4 authored layout | verified | retain as the R4 authored contract |
| `tests/r5_authored_layout_smoke.gd` | R5 compiler/runtime layout | R5 authored layout | verified | retain as the R5 authored contract |
| `tests/puzzle_map_r4_new_grid_smoke.gd` | R4 grid/reference | R4 new grid contract | pending verification | confirm image/source and assertion scope |
| `tests/puzzle_map_r5_grid_smoke.gd` | R5 grid/reference | R5 authored grid contract | pending verification | confirm image/source and assertion scope |

The runner now registers all three authored-layout contracts deliberately.

## Evidence From Focused Run

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

Current post-`0.1.78` grid evidence:

- `puzzle_map_r4_new_grid_smoke`: target is correctly R4, but pixel-for-pixel
  reproduction still fails.
- `puzzle_map_r5_grid_smoke`: target is correctly R5, but pixel-for-pixel
  reproduction and parser round-trip still fail.

These are valid R4/R5 contract failures, unlike the misnamed authored-layout
tests. They should be triaged separately from test-target repair.

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
