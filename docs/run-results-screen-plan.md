# Run Results Screen Plan

Status: planned; score presentation is not yet simplified.

## Purpose

The results screen should answer three questions immediately: how well did the
player perform, how fast was the completed route, and what reward was earned.
Detailed telemetry remains available to code, save data, and a later optional
details view rather than competing with the primary result.

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
