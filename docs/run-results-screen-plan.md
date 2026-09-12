# Run Results Screen Plan

Status: implemented; score presentation and performance weighting are active.

Updated: 2026-09-11

Current owners: `run_flow_controller.gd`, `progression_controller.gd`, and
`screen_state_controller.gd`.

Verification: run-grade, settlement, results presentation, and reward tests.

## Purpose

The results screen should answer three questions immediately: how well did the
player perform, how fast was the completed route, and what reward was earned.
Detailed telemetry remains available to code, save data, and a later optional
details view rather than competing with the primary result.

## Grade weighting

MAP discovery remains visible as route information but contributes no grade
points. The current score weights are time 30%, combat effectiveness 30%, STYLE
20%, combo 10%, and room completion 10%. Combat effectiveness compares
successful attack swings with incoming damage against enemy pressure; it does
not use enemy kill completion. Room completion is therefore a small
route-discipline bonus rather than a requirement for a high performance grade.
The authored R1 route uses a 150-second par so its introductory pacing leaves
room for learning. Later route pars use the same workload estimator with the
R1 calibration factor of 150/90, so their time windows grow at the same pace.

## Proposed primary information

1. Grade and score — the dominant result.
2. Completion time versus route par — `TIME 04:12 / PAR 04:35`.
3. Route outcome — required route completed, with optional exploration shown only
   as a compact bonus/status when relevant.
4. Reward summary — gold, gear drop, and any new or upgraded item.

## Secondary information

Use one compact performance line for combat quality: kills, damage taken, and
effective defense/ability use. Do not show every raw counter on the first page.
The existing style-action breakdown, combo details, map discovery, and reward
telemetry should move to an optional details page only if playtests show that it
helps players improve.

## Implementation path

- Keep score calculation in `RunGrade` and route-par calculation in
  `RunFlowController`/`RunState`.
- Add a small results view model containing only the primary fields above.
- Render the compact result through the existing results screen owner.
- Preserve the full `clear_summary` dictionary for saves, telemetry, and a future
  details view; presentation reduction must not delete useful data.
- Add a scene smoke test for primary fields, reward visibility, and omission of
  low-value telemetry from the first page.

## Open decisions

- Whether the combat line should show kills/damage taken or a single combat grade.
- Whether optional-room exploration deserves a named bonus.
- Whether details are a second page or an expand/collapse interaction.
