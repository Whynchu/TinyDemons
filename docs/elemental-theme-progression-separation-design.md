# Elemental Theme Progression Separation — Design

Status: implemented in source; runtime acceptance pending
Owner: `run_flow_controller.gd` (run composition handoff),
`run_state.gd` (theme state), `encounter_definition.gd` (theme policy),
`room_controller.gd` (roster composition)

## Problem

Dying in a run collapses `difficulty_rank`, and `difficulty_rank` is what
selects the run's elemental theme. Because rank 1 is hard-coded to
Normal-only, one death can permanently strip every non-Normal enemy from every
later run.

Observed chain:

1. Every death grades the run `F` — `gameplay_state.gd:858`.
2. Grade `F` ⇒ `difficulty_rank = clampi(difficulty_rank - 1, 1, 20)` —
   `progression_controller.gd:43-44`. The clamp at 1 makes the penalty sticky.
3. The next run's composition rank is that field —
   `run_flow_controller.gd:261-262` `run_rank_for_profile()`.
4. `run_state.begin(..., run_rank)` selects the theme from it —
   `run_state.gd:197-201`.
5. `encounter_definition.gd:78-81`: `if rank <= 1: return []`. An empty theme
   makes every non-Normal variant fail the theme filter in
   `filter_variants_for_theme` (`:144`), `filter_weighted_pool_for_theme`
   (`:161`), and `extend_pool_with_theme_variants` (`:178`), which
   `room_controller.gd:194, 256, 387` apply to every roster.

So a player who clears Run 1, dies, and continues sees a fully themed Run 2
followed by a permanently themeless Run 3 onward. The reported symptom
("run 2 or 3 has no elemental enemies") is this; it is not a stale cache or a
spawner reset defect.

A second, quieter inconsistency drives the same confusion: layout, boss depth,
skeleton introduction, and treasure already key off `progression_run_number`
(`completed_runs + 1`), while theme, matchup policy, and shadow gating key off
`progression_run_rank`. The code already knows rank can fall behind the run
baseline — `run_difficulty_bonus()` floors it at `run_flow_controller.gd:244-251`
— but the theme path has no equivalent floor.

## Design intent

Two progression axes, one owner each.

| Axis | Driver | Owns |
| --- | --- | --- |
| Difficulty / performance | `player_profile.difficulty_rank`, adjusted by the run's grade | Enemy **levels**, popcorn density, shadow eligibility, loot tier |
| Campaign progression | `player_profile.completed_runs + 1` (run number) | Which **elements** are available, theme selection, which variants have unlocked, layout and boss depth |

Difficulty answers "how hard is this." It must never answer "what is in this
room." Losing a run should lower the numbers, not delete content from the game.

The desired consequence, stated for design review: a player who fails Run 2
still meets Run 3's elemental variety, because what they fight in Run 3 is a
function of *how many runs they have completed*, not *how well the last one
went*.

## Target behavior

- Theme selection and per-variant elemental unlock gates derive from run number.
- Enemy level, popcorn, shadow weight, and treasure tier keep
  reading `difficulty_rank` (via `run_difficulty_bonus()` and friends).
- The run's base-advantage/base-counter matchup lesson and its elemental roster
  weights follow campaign run number. A low difficulty rank cannot revert a
  later campaign run to the Normal-only roster policy.
- `difficulty_rank` never gates theme non-emptiness. The invariant
  `run_element_theme != []` holds for every run number ≥ 2, for every seed.
- Run 1 remains deliberately Normal-only as the teaching run, now because it is
  *run 1*, not because the player is performing badly.

## Implementation stages

Each stage is independently shippable and independently verifiable. Ship Stage 1
alone if the change must be small; it is the fix for the reported defect.

### Stage 1 — Theme selection reads run number (fixes the defect)

Add a composition-rank helper next to the existing ones in
`run_flow_controller.gd`, alongside `run_rank()` (`:254`) and
`run_rank_for_profile()` (`:261`):

```
func element_theme_run_number(root) -> int   # completed_runs + 1, floored at 1
```

Then in `begin_new_run` (`:311-317`) and `restore_active_run` (`:368-393`),
pass the run number — not `run_rank(root)` — to:

- `run_state.begin(...)` as `theme_run_number`; `RunState` persists
  `element_theme_run_number` and derives the theme from it. Restore accepts the
  former `element_theme_run_rank` key for compatibility.
- `room_controller.progression_run_number` for element availability, variant
  filtering, roster constraints, support pools, and theme selection.
  `progression_run_rank` remains the pressure input.

`encounter_definition.gd:78-81` keeps its `rank <= 1: return []` guard. It now
reads as a real run-1 teaching gate.

Save compatibility: `run_state.enemy_element_theme` and
`element_theme_initialized` are persisted (`:71`). Restoring an old snapshot
replays the *stored* theme, so interrupted runs keep the theme they started
with — which is the correct behavior and requires no migration. Only the
`legacy_theme_for_rosters` fallback (`:372`) needs the run number substituted
for its rank argument.

The original coupling was that `room_controller.progression_run_rank` fed both
theme filters and pressure tuning. Stage 2 splits those reads.

### Stage 2 — Split composition rank from pressure rank

`room_controller.gd:29-30` currently exposes one `progression_run_rank` used by
both families. Introduce a second field and route each read to the correct axis:

- `progression_run_number` (existing, `:30`) becomes the value passed to every
  `EncounterDefinition` helper that filters, gates, or extends variant pools:
  `:194, 246, 251, 256, 296, 350, 359, 360, 364, 387`.
- `progression_run_rank` stays as the performance axis and keeps driving the
  pressure knobs: `level_spread` (`:268`), `popcorn` (`:405, 422, 426, 432`),
  boss level offset (`:392, 401`), and shadow eligibility. Matchup policy changes
  which themed elemental family is emphasized, so its campaign lesson follows
  `progression_run_number`.

Consequence: `encounter_min_run_number` on an `EnemyDefinition`
(`enemy_definition.gd:35`) is reinterpreted as "unlocks by run number." That is
the reading the name already implies and the one the authoring preview
(`enemy_preview_workbench.gd:254`) now matches. The field is named
`encounter_min_run_number` throughout the definition, factory, preview, and
authored resources.

Shadow is the deliberate exception: `shadow_min_rank` and
`boss_mixed_support_start_rank` (`encounter_definition.gd:29`,
`room_controller.gd:360`) are pressure multipliers, not elemental availability.
They keep reading the performance rank.

### Stage 3 — Remove the confusion at the naming layer (optional)

With the split in place, rename `run_rank()` → `performance_rank()` and
`run_difficulty_bonus()` stays as-is. This is cleanup for readability, not a
behavior change, and can ship independently.

## Docs that currently misstate the design

These describe `difficulty_rank` as if it were the run number, which is the
root of the confusion that produced the bug:

- `docs/GAMEPLAY_TUNING.md:148-151` — "rank 1 remains Normal-only" must read
  "run 1 is Normal-only"; difficulty rank no longer removes elements.
- `docs/AUDIT.md:736-737` — same correction.
- `docs/procedural-dungeon-design.md:197` — already records
  `progression_run_rank = difficulty_rank`; annotate that this now applies to
  levels and pressure only.
- `docs/elemental-slimes-and-combat-plan.md` — the owning feature plan; its
  current composition section does not define run themes.

`docs/KNOWN_ISSUES.md:938-956` records the theme feature as "implemented in
source, runtime acceptance open." This defect should be logged there and closed
by the acceptance evidence below.

## Acceptance criteria

1. `select_run_element_theme` returns a non-empty theme for **every** run number
   ≥ 2 across a seed sweep of at least 1000 seeds. No dependence on
   `difficulty_rank`.
2. Run 1 is Normal-only regardless of `difficulty_rank`, including a rank of 20.
3. Death → `_show_game_over` → `begin_new_run` with `difficulty_rank` decremented
   to 1 yields a non-empty `run_state.enemy_element_theme`, and
   `room_controller.run_element_theme` matches it.
4. Enemy level for the same room in the same run is unchanged by this work:
   assert `run.difficulty_bonus` and the resolved enemy level are identical
   before and after for a fixed profile.
5. Difficulty rank still measurably affects pressure: a rank-8 profile produces
   a higher level and/or popcorn count than a rank-2 profile in the same run
   number.
6. An interrupted-run snapshot taken at run number 3 restores with its original
   theme, and a pre-change snapshot restores without error.

## Verification

- `tests/run_element_theme_smoke.gd` — currently asserts only literal ranks 1
  and 2 (`:24-25`) and is marked `unverified` in `tests/manifest.csv:147`.
  Rewrite it around the seed sweep in criterion 1 and the death chain in
  criterion 3, then flip the manifest entry to verified.
- New focused test for criteria 4 and 5 pinning the difficulty-vs-level
  contract so a later tuning pass cannot silently repoint levels at run number.
- `tools/validate_definitions.ps1` covers the `encounter_min_run_number` field
  through the element and enemy catalogs.
- `pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1`
  for the ownership/dependency guardrail.
- `pwsh -ExecutionPolicy Bypass -File tests/run_all_smoke.ps1` for the curated
  release gate. Do not run the full `-TestGroup all` inventory while a Godot
  editor is attached over MCP.

## Scope and non-goals

- Not changing the `F` grade penalty itself. `difficulty_rank` still drops on a
  loss; it just no longer decides content.
- Not rebalancing enemy levels, popcorn, or matchup policy. Only their *input*
  is clarified, and in Stage 1 not even that.
- Not adding new elements or variants.
- Not touching shadow gating beyond keeping it on the performance axis.

## Risks

- **Players now see elements earlier after a loss.** A rank-1 player on run 4
  fights themed rooms they would previously have seen as Normal-only. This is
  the intended change; it is also a difficulty increase for exactly the players
  who are struggling, which is worth watching in playtest data.
- **Stage 2 touches a lot of call sites.** It is a mechanical routing change with
  no intended behavior difference beyond the axis swap, but it should land as
  its own commit with the seed-sweep test as its safety net.
- The content workbench and enemy factory now label variant eligibility as a
  minimum run number, matching the runtime gate.

## Implementation record (2026-10-04)

Stages 1 and 2 are implemented. One correction from source review: matchup
policy controls elemental roster composition, so its teaching/default branch
now follows `progression_run_number`, not performance rank. Difficulty still
controls levels, density, and shadow pressure. `RunFlowController.element_theme_run_number()`
uses `completed_runs + 1`; `RunState` persists the theme run number while
reading legacy snapshots; every themed variant pool, roster migration,
elemental unlock, and support pool uses that run number. `RoomController` keeps
`progression_run_rank` for levels and pressure and `progression_run_number` for
elemental content. `EnemyDefinition.encounter_min_run_number` replaces the
ambiguous old field name. The focused seed-sweep test source covers Run 1, Run
2, later-run availability, and saved theme compatibility. Runtime acceptance is
still pending; the smoke source remains `unverified` until it is run.
