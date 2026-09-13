# Tiny Demons — Known Issues and Verification Gaps

Status: live register for the `0.2.x` cycle

Updated: 2026-09-13

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

Current release: version `0.2.06`

This page is the short navigation view of current problems. The detailed
reports, reproduction notes, and acceptance criteria remain in
[`current-issues-and-resolution-plan.md`](current-issues-and-resolution-plan.md),
[`AUDIT.md`](AUDIT.md), and [`test-target-audit.md`](test-target-audit.md).

“Implemented in source” means that a code path and focused assertions exist. It
does not mean that cold-start timing, every display orientation, physical
touch input, browser behavior, or a complete player journey has been verified.

## Focused baseline verification — 2026-09-11

The smoke inventory found `114` registered test paths with `0` missing files.
Because no Godot editor peer or runtime was active, focused tests were run as
individual standalone Godot processes. The full process-per-test suite was not
run.

Passing contracts included dungeon map events, authored R3/R4/R5 layouts, the
Run 2 authored layout, room prefab construction, slime spawning, enemy-room
engagement, gear effects, gear-slot migration, Chroma state and pickup rules,
aspect abilities, starter-flame setup, and generated flame progression.

The following contracts failed in that baseline run and need triage before they
can serve as release evidence; the follow-up below records resolved items.

- `active_run_recovery_contract_smoke`: a valid snapshot failed schema/slot
  validation;
- `cloud_save_contract_smoke`: the source contract still lacks the expected
  explicit runtime-safe types in the cloud panel;
- `demon_hub_menu_scene_smoke`, `equipment_menu_scene_smoke`, and
  `touch_controls_smoke`: current menu geometry, cursor/selection state, and
  touch-target contracts disagree with the tests;
- `gear_catalogue_expansion_smoke` and `gear_drop_policy_smoke`: current
  starter/package expectations disagree with the catalogue and shop policy;
- `elemental_binding_smoke`: generated R7 validation and fusion-state
  assertions fail;
- `generated_minimap_smoke`, `run1_minimap_smoke`, and
  `run_music_flame_gate_smoke`: minimap draw order, undiscovered-room
  visibility, and starter-flame music-gate assertions fail.

The active-run snapshot fixture and the R6+ generator were corrected during the
2026-09-13 follow-up. Isolated focused checks now pass for
`active_run_recovery_contract_smoke`, `r6_plus_risk_reward_generation_smoke`,
`elemental_binding_smoke`, `generated_run_scene_smoke`, `run1_door_path_smoke`,
`wall_socket_geometry_smoke`, and the new `room_transition_result_smoke`.
Those results do not replace the unresolved contracts listed above.

The compatibility-named `r7_native_generator_smoke` and neighboring
`generated_layout_smoke` checks were also rerun in isolated headless processes.
Both pass: the active R6+ route stays inside the declared compact 35x35 map,
preserves its logical-edge projection, and remains deterministic across the
sampled starter-flame and seed cases. No new test path was added.

### 2026-09-13 focused triage of the newly registered and previously stalled checks

The six checks that were outside the runner are now registered and were run one
at a time in isolated headless processes:

- `actor_geometry_smoke` had a harness defect (its success path called
  `quit(0)` without `return`, then fell through to `quit(1)`); fixed, and the
  test now passes.
- `cloud_panel_touch_smoke`, `demon_cloak_smoke`, `hub_content_scroll_smoke`,
  and `resource_drop_motion_smoke` pass in the isolated runner (the earlier
  stalls were environment/add-on teardown noise). `resource_drop_motion_smoke`
  reports four engine resources still in use at exit.
- `touch_menu_scroll_smoke` fails its ghost-accept and stale-hold assertions;
  this is an `input & touch` product-area finding, not a harness stall.
- `menu_route_scene_smoke` and `gear_system_rework_smoke` run to completion but
  fail real assertions (game-over directional navigation; head/arm source drop
  counts). These are `hub & menus` and `gear & fusion` findings respectively.

Result states are recorded in `tests/manifest.csv` (state `open` for the three
assertion failures, `verified` for the five passing checks).

### 2026-09-13 contract decisions and resolutions

All three open findings from the triage are now resolved with documented
contract decisions:

- `menu_route_scene_smoke` was a harness defect: the test injected
  `_menu_directions` directly, but `update_game_over_input` reads
  `_menu_direction_events` (populated only inside `poll()`). The test now
  injects the field the code actually reads; product code was unchanged and the
  test passes.
- `gear_system_rework_smoke` was a stale expectation. Decision: Plain pieces
  drop from chests for every slot under the same rules; the Demon Cloak remains
  the only shop-purchased non-set item. `plain_hood` and `plain_wraps` are no
  longer `starter_only`, and the head/arm "needs introduction" check now keys on
  the Plain tier (zero-power) instead of a starter-only flag. The gear, drop,
  and catalogue tests pass.
- `touch_menu_scroll_smoke` was a stale expectation. Decision: blank non-dialogue
  menu taps stay inert; the ghost-accept/stale-hold mechanism belongs to the
  dialogue context. The test now exercises scroll delta in the hub/menu context
  and the ghost-accept hold in the dialogue context; it passes.

A separate pre-existing finding surfaced during verification:
`six_stat_equipment_smoke` fails its INT/MND flat bonus assertions (a
`gear & fusion` product-area finding tracked in `tests/manifest.csv`).

### 2026-09-13 gear stat-ladder regression fix

Investigating `six_stat_equipment_smoke` exposed a real product regression in
the gear stat ladder, not just a stale test:

- The original design (`item_catalog.gd`) adds `rarity_flat_points` (rank × 2,
  which already carries the "+1 from the rarity jump" and the "+1 earned from
  the previous track's ten levels") plus a per-track enhancement term of +0.1
  per level (`MASTERY_BONUS_PER_LEVEL`), resetting to 0 on promotion.
- A later refactor computed the enhancement term as
  `max(fusion_stat_points, enhancement_level)`. `fusion_stat_points` is the
  monotonic total that never resets on promotion, so any promoted item received
  its prior-track fusion points a second time on top of the rarity rank.
- `combat-economy-overhaul.md` documents the intended per-track model ("reaching
  the same +1.0 at +10"). `gear-economy-progression-implementation-plan.md`
  documents monotonic `fusion_stat_points` as storage/migration, not as a second
  stat-ladder term.
- Fix: the enhancement term now uses `enhancement_flat_points(enhancement_level)`
  (the per-track +0..+10 counter). Fused gear now follows the intended ladder
  (common+0 STR 3 → common+10 STR 4 → rare+0 STR 5 → rare+10 STR 6 → mythic+10
  STR 12 for the tier-stat sword) and a fused-up rare equals a fresh rare at the
  same track position.
- `six_stat_equipment_smoke` aggregate expectations were also stale (equipment
  INT is 5.0, not 4.0); corrected and the test passes.

### 2026-09-13 menu/equipment test fixes

Two further pre-existing failures were stale test expectations, not product bugs
(the product matches the documented contracts; the tests described older layouts
or raced the cursor motion):

- `six_stat_calculator_smoke` asserted the level-one starter deals 3–5 physical
  damage, which assumed the old Basic starter gear. Plain starters are
  intentionally zero-power (per the starter contract), so the benchmark is now
  the base-stat 2.0 and the test asserts the 1–3 band.
- `equipment_menu_scene_smoke` had four stale assertions: the cursor bob checks
  sampled a single frame while the cursor was still in its short glide, the
  slot-description check expected a bonus strip for zero-power plain gear, and
  the Shop check expected the legacy list cursor instead of the modern
  `ShopMenuLayout` cursor layer. All corrected; the test passes.
- `demon_hub_menu_scene_smoke` and `pause_menu_scene_smoke` were verified
  pre-existing on the baseline and remain open; the menu/hub/shop presentation
  work is tracked separately.

### 2026-09-13 touch/cloud contract reconciliation

- `cloud_save_contract_smoke` passes in an isolated headless run. Its existing
  source assertions now have current evidence for the cloud panel's runtime-safe
  pixel UI types, web crypto path, migration, and recovery-vault edge function.
- `touch_controls_smoke` passes after its fixture supplies the optional pause
  callbacks expected by `ScreenStateController.build_hub()`. The remaining
  expectation changes are contract alignment: the current hub stat-row target is
  69.5x12 logical pixels, a non-dialogue blank menu tap is inert, and dialogue
  retains the explicit tap-anywhere accept path. No new test file was added.

### 2026-09-13 web export gate output fix

`web_export_smoke.ps1 -RequireExport` now stages local verification in a fresh
temporary directory, avoiding stale ignored `dist` artifacts held open by an
editor. The GitHub Pages workflow passes `-OutputDirectory dist` explicitly, so
the publishable artifact contract is unchanged. The local single-threaded Web
export passes; browser/device and hosted Pages verification remain open.

A supervised full-run attempt on 2026-09-13 reached ordinary assertion
failures without a native headless renderer crash. It was stopped at the
broader R6+ seed failure, which the focused elemental-binding and R6+ checks
now cover. The full suite remains a release gate rather than a claim of zero
behavioral failures.

The earlier native R7 generator smoke report is retained as historical
evidence: it repeatedly reported rooms and connections outside the declared
compact 35x35 map, including `room_9_11` at `(35, 10)`, under the superseded
route contract. The current compatibility-named check exercises the active R6+
route and is verified in `tests/manifest.csv`. Several other standalone checks
still stalled during the add-on MCP runtime startup/teardown path without
producing a reliable assertion result; those checks remain unverified rather
than passing or failing by inference. The certificate-store and MCP registry
messages are environment warnings seen across the direct runs, not product
assertions.

Detailed command output and target interpretation are tracked in
[`test-target-audit.md`](test-target-audit.md). This snapshot is evidence for
triage, not a release gate.

## Player-facing findings still needing runtime evidence

### Doorway geometry — verified

Doorways were checked in gameplay on 2026-09-13 and are functioning as intended:
the player can traverse active openings and closed doorway behavior is correct
for the current authored rooms. On 2026-09-13,
`wall_socket_geometry_smoke` was reconciled with the current portal-based
walkability model and passed in the isolated headless runner. The test covers
closed-socket portal exclusion, closed transition rejection, open portal
participation, and normal open-entrance movement.

| Area | Current state | Evidence still required |
|---|---|---|
| Demon Hub SELECT/BACK presentation | Source implementation exists; visual orientation check remains | Compare all hub routes at native and supported responsive layouts |
| Shop functional sell variants | Functional grouping and exact instance selection logic exists | Sell same-name gear at different levels/rolls through the live transaction |
| Shop sell performance | Cache/rebuild pass exists; no timing baseline | Measure open, row movement, sale, and post-sale refresh with representative inventory |
| Fusion batch capacity | Next-rank cap and `xN/M` amount display exist | Confirm +0/+9/+10/Mythic +10 limits through the live Fusion transaction |
| First flame-room music start | Music warmup/cache exists | Cold versus warm room pickup frame profile and audio-start check |
| Pause equipment clipping | Candidate clip and local scroll bounds exist | Fast swipe/release checks in Pause and Hub at supported aspect presets |
| R5/R6 route identity | New runs preserve authored R5 and use generated R6+ | Fresh-run identity, fixed-seed layout, and active-run recovery checks |
| Flame-room fast travel | Eligibility and transition path exist | Hub/flame-room origin rules, travel lifecycle, save/load, and repeated travel |
| Bound identity at zero Chroma | Domain path preserves bound identity and desaturates | Live body/equipment presentation, depletion, pickup restore, and save/load |
| Gray/Normal Chroma collection | Collection path exists | Live collection while Gray, storage amount, and unchanged Normal state |
| Needed-color Chroma pickups | Selection path exists | Visual color checks for each current need and neutral/Normal state |

The source-level status for each item is maintained in the detailed issue
tracker. Update both documents when a focused check changes the status.

### Newly reported R6+ playtest blocker

Late generated rooms could retain an active slime outside the visible playable
area. The slime remained able to attack and counted against encounter
completion. Runtime sanitation now validates active slime positions before each
combat update and uses the existing recovery/deactivation path. This requires
focused R6+ playtest verification before being marked verified.

### R6+ risk/reward generation implementation status

The active generated-run slice now uses an ungated critical route with one
safe/risk fork, guaranteed Fire/Water/Electric flame rooms, and one or two
optional elemental Orb vaults. Dangerous shortcut rooms receive a stronger
encounter profile and risk reward tier; vault rooms receive an elite profile and
guaranteed enhanced gear through the existing chest item generator. New route
metadata is carried through layout, graph, room state, minimap plans, and active
run room-state snapshots. The focused generator, elemental-binding, and scene
tests pass in isolated Godot processes; the 2026-09-13 R7 playthrough accepted
the minimap landmark visibility behavior. Manual enemy-placement, reward,
save/load, touch, and flame-travel checks remain outstanding.

### 2026-09-13 minimap landmark visibility reconciliation

The intended minimap contract is now explicit: the Hub, boss/downstairs rooms,
Orb rooms, and Fire/Rest or flame-bearing landmarks are visible at run start;
unvisited flame landmarks are grey; ordinary rooms remain hidden until entered.
The user-confirmed R7 playthrough matched that behavior. Both
`generated_minimap_smoke` and `run1_minimap_smoke` pass the focused contract,
including landmark colors, ordinary-room discovery, and destination cursor draw
order. Their older `open` entries were stale and are now `verified` in
`tests/manifest.csv`. Flame-to-flame travel and browser/device verification
remain separate evidence gaps.

## Verification surface audit — open

The repository has a large test/report inventory. `tests/manifest.csv` now
classifies all 121 scripts with a role (gate/owner/reference/diagnostic/report),
state, owner, target, and load kind. The runner derives its grouping from that
manifest: the default release gate selects 43 paths; `-TestGroup all` covers the
119 runnable paths. The 2026-09-13 pruning slice removed the stale
`backtrack_popcorn_smoke` expectation and consolidated the three identical
R3/R4/R5 layout wrappers into `authored_layouts_smoke`; no gate coverage or web
export coverage was removed. The separate classification and pruning issue is
[`verification-surface-audit.md`](verification-surface-audit.md). Until its
remaining exit criteria are met, the total smoke count is an inventory metric,
not a quality score or release gate.

## Infrastructure findings

| Finding | Impact | Next evidence or decision |
|---|---|---|
| Duplicate Godot resource UIDs reported for R4/R5 puzzle scripts; the former duplicate test wrappers were consolidated | Import and future file moves may resolve the wrong resource | Inspect the remaining `.uid`/import state for the puzzle scripts, choose canonical resources, then rerun the editor scan |
| Full smoke runner has 119 runnable manifest paths; the default gate selects 43 and launches one Godot process per selected path | Slow feedback and possible Windows renderer/memory failure avalanche | Use the default gate for release checks and `-TestGroup all` only as a supervised inventory; runner isolates each worker with temporary user data and Dummy audio |
| Six formerly unregistered `role:owner` checks are now triaged and resolved | All six have reliable states recorded in `tests/manifest.csv` | `actor_geometry_smoke` harness fixed; `cloud_panel_touch_smoke`, `demon_cloak_smoke`, `hub_content_scroll_smoke`, `resource_drop_motion_smoke` verified; `touch_menu_scroll_smoke` rewritten for the dialogue-context contract and verified |
| Browser/device verification remains incomplete | Local export support does not prove shipped web behavior | Verify touch, controller prompts, save/reload, audio, responsive layout, and Pages artifact |
| `screen_state_controller.gd` remains a large mixed menu/hub/persistence owner | Menu changes carry broad regression risk | Characterize shared menu conventions, then extract one presenter boundary |
| `gameplay_state.gd` remains a shared state bag and compatibility surface | Ownership and rename safety are obscured | Select one typed vertical migration after active contracts stabilize |
| `root.call/get/set` remains widespread across runtime controllers | Hidden dependencies and runtime-only failures | Reduce calls by feature, measuring before/after rather than performing a global rewrite |
| Tuning classes are instantiated in code rather than external `.tres` resources | Designers cannot yet use the intended inspector workflow | Define resource equivalence and migration tests before moving tuning data |
| Per-pixel image work and synchronous startup paths exist in rendering/audio/UI | Device-specific frame hitches remain possible | Capture repeatable frame-time scenarios before optimization |

## Documentation findings

- Some plans still contain historical dates, branch names, or completion claims;
  use [`DOCUMENTATION_MAP.md`](DOCUMENTATION_MAP.md) to decide authority.
- Dungeon documents cover authored and generated routes with overlapping names;
  each plan needs explicit run scope before it is reopened.
- Several implemented handoffs do not yet identify a current code owner or
  verification path.
- Historical documents should be archived only after incoming links and save or
  gameplay compatibility rationale have been checked.

## Status language

Use these labels consistently:

- `open`: behavior or evidence is still missing;
- `implemented in source`: focused source/test work exists, runtime proof is
  incomplete;
- `verified`: the stated test or manual matrix passed at a named version/commit;
- `blocked`: external state prevents the specified verification, with the
  blocking condition recorded; and
- `superseded`: the old behavior or plan is retained only for history.

Do not promote an item to `verified` because a test file exists or because a
runner completed only part of its batch.
