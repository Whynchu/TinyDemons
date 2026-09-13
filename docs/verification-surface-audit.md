# Tiny Demons — Verification Surface Audit

Status: active issue

Issue: audit the audit; classify, reduce, and govern the test/report surface

Scope: `tests/`, `tests/run_all_smoke.ps1`, `docs/AUDIT.md`, and
`docs/test-target-audit.md`

Owner: verification infrastructure and repository maintainability

Current code: the runner derives grouping from `tests/manifest.csv`. The
manifest classifies all 124 test/report scripts with a role, state, owner,
target, and load kind. Its default release gate selects 43 paths; `owner`,
`reference`, `diagnostic`, and `all` groups keep the remaining evidence
available without making every check a default blocker. The two `report`
scripts (`fusion_menu_preview`, `puzzle_map_reference_diff_report`) are
intentionally not runner tests.

Verification: inventory mode, focused standalone Godot checks, and a supervised
full run when the environment permits it

Supersedes: none; this complements `test-target-audit.md`

## Why this is a separate issue

`test-target-audit.md` checks whether a test exercises the feature named by its
filename. That is necessary, but it does not answer the larger maintenance
questions:

- Is the test a release gate, an owner regression check, or a diagnostic?
- Is its expected behavior current, or is it preserving retired behavior?
- Does it duplicate another test or assert implementation details?
- Can it run reliably in the supported verification environment?
- Is the cost of starting a separate Godot process justified by the evidence it
  produces?

Those questions are about the verification system itself. They must be settled
before using a large green/red test count as evidence about the game.

## Labels

Every registered test will receive one role label and one state label. A test
may also receive a short owner and evidence note.

### Role labels

| Label | Meaning | Release effect |
|---|---|---|
| `role:gate` | Small set of player-facing checks required before a release or broad refactor | Blocks the gate when broken |
| `role:owner` | Focused regression check for one stable feature owner or data policy | Runs with the relevant change; does not automatically block every change |
| `role:reference` | Authored layout, pixel, asset, or visual-reference comparison | Opt-in unless the referenced asset is part of the release gate |
| `role:diagnostic` | Performance sample, report, probe, or exploratory coverage | Never a release blocker by itself |
| `role:migration` | Save/schema/resource-identity compatibility fixture | Blocks changes that can invalidate the migration boundary |
| `role:retire-candidate` | Duplicate, superseded, or implementation-detail coverage awaiting removal | Must not be treated as release evidence |

### State labels

| Label | Meaning | Required action |
|---|---|---|
| `state:verified` | Target, assertions, and environment are current and have named evidence | Retain and record the evidence date/commit |
| `state:open` | The intended contract is current but the behavior or assertion is unresolved | Assign to the feature owner |
| `state:stale` | The test describes behavior that is no longer the accepted contract | Confirm the replacement contract, then update or remove it |
| `state:harness` | Setup, mock, fixture, signal binding, or runner logic prevents a valid result | Repair the test boundary before judging product code |
| `state:environment` | The result depends on permissions, filesystem, renderer, browser, or device state | Re-run in the supported environment; do not weaken product checks |
| `state:unverified` | No reliable current result exists | Do not call it passing or failing by inference |
| `state:superseded` | A newer test or contract replaces it | Keep only if historical provenance matters; otherwise remove |

`state:pass` and `state:fail` are intentionally not labels. They describe one
run, not the quality or authority of a test.

## Runner groups

`tests/run_all_smoke.ps1` reads `tests/manifest.csv` and exposes the
classification at execution time. The `role` column drives grouping; the
`state` column is carried into the result and inventory CSVs so a red result
can be separated into product, harness, and environment causes:

| Command | Current scope | Use |
|---|---:|---|
| default / `-TestGroup gate` | 43 Godot paths plus SFX, web export, and main-scene checks | Release and broad-refactor gate |
| `-TestGroup owner` | 68 Godot paths | Focused feature-owner regressions |
| `-TestGroup reference` | 10 Godot paths | Opt-in authored/visual/reference checks |
| `-TestGroup diagnostic` | 1 Godot path | Opt-in performance/diagnostic evidence |
| `-TestGroup all` | 122 runnable Godot paths plus the post-run checks | Supervised complete inventory |

The web export is intentionally part of the default gate because browser
delivery is a supported target. A restricted local run may still label its
result `state:environment`; that says the evidence is unavailable in that
environment, not that web support is optional.

## Initial triage from the 2026-09-13 sweep

This is a first classification of the current evidence, not a claim that the
full suite is clean.

| Area | Initial label | Current interpretation | Next action |
|---|---|---|---|
| Doorway, typed room transition, generated route, boss geometry, slime roster, gear/fusion, cloud typing, and minimap fixes already checked in the focused pass | `role:owner` + `state:verified` | These are useful narrow contracts after the recent reconciliation | Keep the smallest owner-level checks and record named evidence |
| `settings_service_smoke`, `settings_panel_scene_smoke` | `role:owner` + `state:environment` | The restricted run could not write `user://`; this is not product evidence | Re-run elevated, then decide whether the fixture needs an isolated settings path |
| `web_export_smoke` | `role:gate` + `state:environment` | Web is a supported target; the restricted run could not create export output | Verify from a supported standalone environment before changing export code |
| `backtrack_popcorn_smoke` | `role:owner` candidate + `state:stale` candidate | Current source intentionally keeps respawn tied to original popcorn slots and does not inject a new revisit slot | Make the gameplay decision, then update or retire the old expectation |
| `touch_controls_smoke` | `role:owner` + `state:harness`/`state:open` | It contains a signal-argument mismatch and several expectations that may describe different menu policies | Split the test by input boundary before changing gameplay code |
| `puzzle_map_grid_smoke` and related reference checks | `role:reference` + `state:unverified`/`state:harness` | Reference fidelity and duplicate resource IDs are separate from runtime behavior | Resolve canonical assets/UIDs, then keep visual checks opt-in |
| Palette, projectile/imbue, audio, display/pause, soul/spin, stat/menu, locomotion, drop, gear, and HUD checks from the broad failure list | `role:owner` candidates + `state:unverified` | The broad run identified work areas but did not establish which assertions are current contracts | Triage one owner at a time; do not bulk-edit expectations |
| `frame_time_smoke`, reference-diff reports, preview scripts, and similar probes | `role:diagnostic` or `role:reference` | Valuable information, but not ordinary pass/fail release gates | Move them out of the default gate or run them through an explicit diagnostic command |

The focused pass also demonstrated why this classification matters: boss,
generated-layout, slime, and doorway failures were a mixture of real owner
defects and expectations written for an earlier contract. A red result alone
did not identify which kind it was.

## 2026-09-13 focused triage outcome

The six formerly unregistered checks were run one at a time in isolated headless
processes (see `KNOWN_ISSUES.md` for the full note). Result states are recorded
in `tests/manifest.csv`:

- `actor_geometry_smoke` harness defect fixed; now `verified`.
- `cloud_panel_touch_smoke`, `demon_cloak_smoke`, `hub_content_scroll_smoke`,
  `resource_drop_motion_smoke` now `verified` (the earlier stalls were add-on
  teardown noise; the resource test still reports engine resources in use at
  exit).
- `touch_menu_scroll_smoke`, `menu_route_scene_smoke`,
  `gear_system_rework_smoke` were `open` and are now `verified` with documented
  contract decisions (see `KNOWN_ISSUES.md`): the menu-route check was a harness
  injection mismatch; the gear check now reflects the decision that Plain pieces
  drop from chests for every slot; the touch check now exercises the dialogue
  ghost-accept contract and keeps blank non-dialogue menu taps inert.

## Work plan

1. Freeze test growth while this issue is active. A new test must replace or
   consolidate an existing check, or protect a newly agreed public contract.
2. Inventory every registered and unregistered test/report script. Record its
   role, state, owner, target, evidence command, and whether it loads the main
   scene or a lightweight fixture. **Done for the current inventory:** all 124
   scripts are classified in `tests/manifest.csv`; the runner derives grouping
   from that file.
3. Maintain the curated `role:gate` set. It covers headless boot, core room
   transition/doorway behavior, representative combat, progression/profile
   integrity, and the web export because web is a supported target.
4. Keep focused `role:owner` checks beside the feature they protect. Prefer
   table-driven tests for pure policies and one scene smoke per meaningful
   runtime boundary.
5. Move visual comparisons, performance samples, previews, and exploratory
   reports out of the default release run.
6. Delete or consolidate `role:retire-candidate` tests after checking history,
   resource identity, and incoming documentation links.
7. Re-run the curated gate and update `KNOWN_ISSUES.md`; do not report the
   total number of registered scripts as coverage quality.

## Exit criteria

- [x] Every registered test has a role, state, owner, and target note.
- [x] Every unregistered test/report script is intentional, registered, or
  retired (6 previously unregistered scripts are now `role:owner`;
  `fusion_menu_preview` and `puzzle_map_reference_diff_report` are explicit
  `role:report` scripts that are not runner tests).
- [x] The default release gate is curated and substantially smaller than the
  full diagnostic inventory.
- [ ] No test is changed solely to make a red result green without a documented
  contract decision. (2026-09-13: three open findings were resolved with
  recorded decisions; the `six_stat_equipment_smoke` finding uncovered and fixed
  a real stat-ladder regression in `item_catalog.gd`, then its stale aggregate
  expectations were corrected — see `KNOWN_ISSUES.md`.)
- [ ] Duplicate, implementation-detail, and superseded tests are removed or
  explicitly retained for migration history.
- [x] The runner reports product failures separately from harness and
  environment failures (result CSVs now carry the manifest `state` per test).
- [ ] `AUDIT.md`, `test-target-audit.md`, and `KNOWN_ISSUES.md` link to this
  issue without duplicating its classification table.

## Guardrails

This issue does not authorize a gameplay rewrite, balance change, broad scene
move, or new test framework. It is a verification-surface cleanup. The desired
outcome is fewer, clearer, more trustworthy checks—not a larger test directory.
