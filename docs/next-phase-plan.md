# Next Phase Plan

Status: approved working sequence

Date: 2026-09-07

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

Exit gate:

- Clean checkout boots.
- Web export and Pages deployment pass.
- The current worktree state is explicitly recorded.

## Phase 2: Produce A Reliable Test Matrix

Use the improved `tests/run_all_smoke.ps1` runner with bounded focused batches.
Do not rely on a single 90-process run as the only source of truth.

Run groups separately:

1. Boot, save, settings, and web.
2. Combat, slime, and actor geometry.
3. Authored dungeon and room contracts.
4. Puzzle and generated-route contracts.
5. Menus, gear, and progression.

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

Each fix must identify whether code or test is authoritative. Do not weaken a
test solely to make the suite pass.

Exit gate:

- Active puzzle and slime tests pass or have documented approved exceptions.
- Generator output is deterministic and bounded.
- Authored map tests remain pixel/reference-safe where that is the contract.

## Phase 4: Select One Refactor Boundary

Only after the baseline is stable, select one boundary from the dynamic audit.

Recommended order:

### Candidate A: Checkpoint command/result

Unify profile and active-run checkpoint ordering without changing save format.
Preserve idempotent chest claims, room-clear checkpoints, slot validation, and
browser recovery behavior.

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
- Update `AUDIT.md` only after an exit gate is actually satisfied.

## Immediate Next Actions

1. Finish recording the current worktree and commit baseline.
2. Run the focused test groups after the latest gameplay/puzzle commits.
3. Triage failures without deleting or restructuring runtime files.
4. Select one refactor boundary only after the active contracts stabilize.
