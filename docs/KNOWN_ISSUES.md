# Tiny Demons — Known Issues and Verification Gaps

Status: live register for the `0.2.x` cycle

Updated: 2026-09-12

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

Current release: version `0.2.04`

This page is the short navigation view of current problems. The detailed
reports, reproduction notes, and acceptance criteria remain in
[`current-issues-and-resolution-plan.md`](current-issues-and-resolution-plan.md),
[`AUDIT.md`](AUDIT.md), and [`test-target-audit.md`](test-target-audit.md).

“Implemented in source” means that a code path and focused assertions exist. It
does not mean that cold-start timing, every display orientation, physical
touch input, browser behavior, or a complete player journey has been verified.

## Focused baseline verification — 2026-09-11

The smoke inventory found `113` registered test paths with `0` missing files.
Because no Godot editor peer or runtime was active, focused tests were run as
individual standalone Godot processes. The full process-per-test suite was not
run.

Passing contracts included dungeon map events, authored R3/R4/R5 layouts, the
Run 2 authored layout, room prefab construction, slime spawning, enemy-room
engagement, gear effects, gear-slot migration, Chroma state and pickup rules,
aspect abilities, starter-flame setup, and generated flame progression.

The following contracts failed and need triage before they can serve as
release evidence:

- `active_run_recovery_contract_smoke`: a valid snapshot failed schema/slot
  validation;
- `cloud_save_contract_smoke`: the source contract still lacks the expected
  explicit runtime-safe types in the cloud panel;
- `wall_socket_geometry_smoke`: closed doorway seams remain physically
  enterable or lack the expected trigger fence;
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

The native R7 generator smoke did not complete. It repeatedly reported rooms
and connections outside the declared compact 35×35 map, including
`room_9_11` at `(35, 10)`, before its standalone worker stalled. Several other
standalone checks also stalled during the add-on MCP runtime startup/teardown
path without producing a reliable assertion result; those checks remain
unverified rather than passing or failing by inference. The certificate-store
and MCP registry messages are environment warnings seen across the direct
runs, not product assertions.

Detailed command output and target interpretation are tracked in
[`test-target-audit.md`](test-target-audit.md). This snapshot is evidence for
triage, not a release gate.

## Player-facing findings still needing runtime evidence

| Area | Current state | Evidence still required |
|---|---|---|
| Demon Hub SELECT/BACK presentation | Source implementation exists; visual orientation check remains | Compare all hub routes at native and supported responsive layouts |
| Shop exact sell variants | Exact instance grouping and selection logic exists | Sell same-name gear at different levels/rolls through the live transaction |
| Shop sell performance | Cache/rebuild pass exists; no timing baseline | Measure open, row movement, sale, and post-sale refresh with representative inventory |
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
run room-state snapshots. The focused generator and scene tests are registered,
but Godot execution and manual save/load/touch playtesting remain outstanding.

## Infrastructure findings

| Finding | Impact | Next evidence or decision |
|---|---|---|
| Duplicate Godot resource UIDs reported for R4/R5 puzzle scripts and tests | Import and future file moves may resolve the wrong resource | Inspect the `.uid`/import state, choose canonical resources, then rerun the editor scan |
| Full smoke runner has 113 registered paths and launches one Godot process per test | Slow feedback and possible Windows renderer/memory failure avalanche | Use focused groups first; record a supervised full-run result only without an MCP runtime |
| Eight test/report scripts are outside the registered runner | Coverage claims can be incomplete or misleading | Classify each as registered, intentional standalone, obsolete, or missing from the registry |
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
