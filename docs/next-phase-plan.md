# Next Phase Plan

Status: historical working sequence; current sequence is [`ROADMAP.md`](ROADMAP.md)

Date: 2026-09-07

This document retains the detailed stabilization checklist and runner safety
notes. Use [`ROADMAP.md`](ROADMAP.md) for the current phase order and
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for the live issue register.

## Current Position

The repository has completed its initial inspection and mapping pass. The
current maps, vertical-slice analysis, dynamic dependency audit, asset audit,
and documentation audit are available from `docs/runtime-map.md`.

The project is not yet at a clean refactor baseline. Active gameplay and puzzle
changes have recently landed, and the smoke suite contains failures that may be
intentional contract changes, stale expectations, or real regressions.

## Objective

Move from broad discovery to controlled stabilization and one safe architectural
improvement at a time.

The next phase must improve confidence without blocking content work or mixing
large unrelated refactors into active gameplay changes.

## Phase 1: Freeze And Record The Baseline

- [ ] Record the current branch and commit in `docs/AUDIT.md`.
- [ ] Confirm the current version in `README.md`, `docs/VERSIONING.md`, and the
  title/runtime version display.
- [ ] Record all known uncommitted work before any cleanup or refactor.
- [ ] Keep the Web export renderer override in `project.godot`.
- [ ] Confirm the GitHub Pages workflow is green after the current push.
- [ ] Record known warnings, crashes, and incomplete fixes separately from
  confirmed regressions.

Exit gate:

- Clean checkout boots.
- Web export and Pages deployment pass.
- The current worktree state is explicitly recorded.
- Every claimed fix has a reproducing test or documented manual evidence.

## Phase 2: Produce A Reliable Test Matrix

Use the improved `tests/run_all_smoke.ps1` runner with bounded focused batches.
Do not rely on a single 90-process run as the only source of truth.

### Verification mode must be explicit

- When an MCP Godot editor/runtime is active, use MCP for scene inspection,
  diagnostics, playtests, screenshots, and logs. Do not run the standalone full
  runner in that session.
- When using the standalone runner, record the Godot executable, project path,
  batch/filter, timeout, and whether the run was supervised.
- A focused test may run standalone when no MCP runtime is active.
- A full suite is a supervised standalone operation only.

Run groups separately:

1. Boot, save, settings, and web.
2. Combat, slime, and actor geometry.
3. Authored dungeon and room contracts.
4. Puzzle and generated-route contracts.
5. Menus, gear, and progression.

### Test inventory comes before test results

Before trusting names or counts:

- [ ] Confirm every registered test path exists.
- [ ] Confirm each test's loaded scene/script/resource target.
- [ ] Confirm the test's assertions exercise the feature named by the file.
- [ ] Identify copied, stale, or misnamed tests.
- [ ] Record target mismatches in `docs/test-target-audit.md`.

Test names, pass counts, and runner registration do not establish coverage by
themselves. For example, an R4-named test that loads an R3 layout must be
classified as a test-target defect before its result is used as R4 evidence.

### Runner safety requirements

- [ ] Write an initial inventory of the selected tests before execution.
- [ ] Record every test as pass, assertion failure, script error, timeout,
  engine crash, skipped, or unknown.
- [ ] Distinguish a nonzero test exit from a Godot process crash.
- [ ] Stop the batch after repeated engine crashes or repeated process startup
  failures rather than continuing to consume time and memory.
- [ ] Preserve completed results when a batch stops early.

For every failure, classify it as:

- current regression;
- stale characterization expectation;
- intentional design change;
- test harness defect;
- timeout/crash; or
- environment failure.

Exit gate:

- Every registered test is pass, fail, skipped, timeout, or unknown.
- No result is described as green merely because a batch stopped early.
- Test target identity has been audited for the affected feature group.

## Phase 3: Stabilize Active Gameplay Contracts

Do not refactor ownership until active Shadow Slime and puzzle-generation work
has a stable contract.

Priority order:

1. Generated layout timeout and crash behavior.
2. R3/R4/R5 authored pixel/reference contracts.
3. Generated minimap gate color contract.
4. Shadow Slime variant and scaling expectations.
5. Room entrance and door gating behavior.
6. Elemental binding nil/setup failures.

Also include these recent behavior-sensitive contracts:

- lambda capture and seed serial behavior in `puzzle_route_generator.gd`;
- chest claims across revisits and browser reload/recovery;
- run-start binding and starter-flame state;
- boss entrance sealing, arrival placement, and final exit routing; and
- route par/results behavior, including metrics, grade, reward, and completion
  presentation.

### Evidence requirement

Do not call a fix complete because a code path looks correct or because a test
count changed. A fix requires one of:

- a focused test that reproduces the original defect and now passes;
- a verified existing contract test whose target has been audited; or
- documented manual/runtime evidence with exact steps and expected behavior.

If a fix is incomplete, record it as an open finding rather than updating the
baseline as though it were resolved.

Each fix must identify whether code or test is authoritative. Do not weaken a
test solely to make the suite pass.

Exit gate:

- Active puzzle and slime tests pass or have documented approved exceptions.
- Generator output is deterministic and bounded.
- Authored map tests remain pixel/reference-safe where that is the contract.
- Recent behavior contracts have targeted evidence, not only broad smoke output.

## Phase 4: Select One Refactor Boundary

Only after the baseline is stable, select one boundary from the dynamic audit.

Recommended order:

### Candidate A: Checkpoint command/result

Unify profile and active-run checkpoint ordering without changing save format.
Preserve idempotent chest claims, room-clear checkpoints, slot validation, and
browser recovery behavior.

This is the preferred first ownership change, but only after chest claims across
revisits/reloads and active-run recovery have verified characterization tests.

### Candidate B: Room transition result

Represent room identity, arrival socket, layout state, completion state, and
transition lock changes explicitly. Preserve the existing frame schedule and
authored/generated distinction.

### Candidate C: Actor geometry interface

Replace reflective geometry calls with a typed interface while retaining one
shared source for collision, targeting, occlusion, and presentation transforms.

Do not pursue all three candidates simultaneously.

## Phase 5: Documentation Consolidation

After the active contracts settle:

- Add status, scope, owner, current code, verification, and supersession headers
  to active plans.
- Mark completed implementation plans as implemented handoffs.
- Mark superseded plans as historical and link them to the canonical route.
- Keep design rationale for shipped compatibility and balance decisions.
- Do not delete historical documents until all incoming links are checked.

Canonical current documents remain:

- `README.md`
- `AGENTS.md`
- `docs/production-boundary.md`
- `docs/runtime-map.md`
- `docs/FEATURE_MAP.md`
- `docs/ARCHITECTURE.md`
- `docs/AUDIT.md`
- `docs/refactor-route.md`
- `docs/GAMEPLAY_TUNING.md`

## Phase 6: Cleanup

Cleanup begins only after the test matrix and asset-reference scanner provide
evidence.

Start with:

- caches;
- logs;
- local editor metadata;
- temporary generated reports; and
- clearly superseded documentation.

Do not remove runtime art, baked frames, audio catalog entries, scenes, or
preview/authoring assets solely because literal search found no reference.

Every deletion must be recorded in `docs/cleanup-ledger.md` with evidence,
verification, and confidence.

## Working Rules

- Preserve the explicit frame schedule.
- Do not add an event bus or service locator.
- Do not mix gameplay balance changes with structural refactors.
- Prefer the narrowest owner and typed boundary.
- Add characterization coverage before moving behavior.
- Run focused tests before broad tests.
- Never revert concurrent work without explicit approval.
- Record evidence, failures, warnings, and partial progress continuously.
- Mark a phase complete in `AUDIT.md` only after its exit gate is actually
  satisfied.

## Immediate Next Actions

1. Finish recording the current worktree and commit baseline.
2. Run the focused test groups after the latest gameplay/puzzle commits.
3. Triage failures without deleting or restructuring runtime files.
4. Select one refactor boundary only after the active contracts stabilize.
