# Tiny Demons — 0.2.x Roadmap

Status: working roadmap derived from the accepted refactor route

Updated: 2026-09-15

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

Current release: version `0.2.17`

This roadmap sequences infrastructure work around the working game. It does
not authorize a rewrite or change the game's identity. The current product
contract remains dungeon crawling, elemental combat, puzzle solving,
exploration, battling, gear, progression, and the title → Hub → dungeon →
settlement → Hub loop.

## How to use this roadmap

Use [`AUDIT.md`](AUDIT.md) for measured current state, [`ARCHITECTURE.md`](ARCHITECTURE.md)
for ownership rules, and [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for unresolved
behavior and verification findings. Feature-specific plans provide detail only
when they agree with those documents.

Work should move through one narrow slice at a time:

1. characterize the existing behavior;
2. document the owner and boundary;
3. make the smallest structural change;
4. run focused verification and a relevant manual check; and
5. record the result before selecting the next slice.

## Current sequence

| Phase | Purpose | State | Exit evidence |
|---|---|---|---|
| 0.00 | Preserve the `0.2.00` baseline | In progress | clean import, recorded test inventory, focused evidence, and representative manual run |
| 0.10 | Make documentation authoritative | In progress | current map, roadmap, content guide, known-issues register, and lifecycle headers |
| 0.15 | Audit and reduce the verification surface | Active issue | every test/report has a role and state; curated release gate; obsolete checks removed |
| 0.20 | Stabilize active player-facing contracts | In progress | issue tracker findings have focused or manual verification, with failures classified |
| 0.30 | Establish shared menu boundaries | Planned | one migrated menu proves shared frame, cursor, list, footer, clipping, touch, and responsive contracts |
| 0.40 | Separate room and encounter responsibilities | In progress | typed room transition/activation results and deterministic room fixtures |
| 0.50 | Reduce dynamic runtime seams by feature | Planned | one owner migration removes its compatibility calls while preserving frame order |
| 0.60 | Make content authoring repeatable | Planned | validated definitions and an example workflow for rooms, enemies, rewards, and tuning |
| 0.70 | Improve test and performance feedback | Planned | grouped verification, runtime timing baselines, and reproducible performance scenarios |

The numeric labels are sequencing markers, not release versions. The project
version remains governed by [`VERSIONING.md`](VERSIONING.md).

## Next checkpoint after 0.2.17

Version `0.2.17` records the typed reward, checkpoint, and room-state seams alongside
the earlier Web export, touch/cloud, gear, progression, and generated-route
reconciliation. The next checkpoint is a stabilization pass in this order:

1. Keep the manifest preflight and focused room/HUD/reference checks green, then
   run the curated standalone gate and record product, harness, environment, and
   crash outcomes separately.
2. Close the remaining verification-surface decisions: explicitly retain or
   retire duplicate/implementation-detail checks, and link the audit documents
   without duplicating the manifest classification table.
3. Finish the remaining browser/device, native-resolution, cold/warm timing,
   and representative gameplay evidence that cannot be established headlessly.
4. Continue the room boundary one seam at a time: the initial typed enemy-spawn
   and chest-item reward results now travel through their owners; next tighten
   reward persistence/settlement boundaries while preserving authored/generated
   distinctions and the explicit frame schedule.
5. Select the first menu or checkpoint ownership extraction only after the
   active contract evidence is current.

Each item should keep its existing owner, add or correct a focused
characterization check, and record the result in [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).
Do not begin the first broad ownership extraction until the generated-route,
recovery, doorway, and menu contracts are either passing or explicitly
classified as approved design changes. After that gate, take one typed boundary
at a time, with the room transition or checkpoint result as the first candidates.

The approved product direction for generated R6+ maps is documented in
[`r6-plus-risk-reward-generation-plan.md`](r6-plus-risk-reward-generation-plan.md).
It replaces mandatory elemental-door chains with an ungated Boss path, three
guaranteed primary flames, safe/risk route choices, and optional elemental Orb
vaults containing harder encounters and enhanced gear rewards. Implement it in
bounded phases; the current code slice covers the generator contract, runtime
metadata, encounter/reward policy, minimap semantics, and focused smoke
coverage. Godot execution and manual playtesting are still required before
calling the slice verified.

## Phase 0.00 — Preserve the baseline

The baseline is the current game at version `0.2.00`. Preserve its authored
Runs 1–5, generated Run 6+ policy, controls, pixel presentation, save IDs,
active-run recovery, and explicit gameplay frame schedule.

Remaining evidence work:

- keep the distinct R4/R5 `.uid` files committed; a stale local generated cache
  can be rebuilt if the warning reappears;
- keep `tests/manifest.csv` as the single test/report registry (all scripts
  classified by role, state, owner, target, and load kind);
- run the curated standalone release gate and record its result;
- capture a representative cold and warm gameplay run;
- run a focused standalone smoke test, then the full runner only when no MCP
  Godot runtime is active; and
- record browser/device verification separately from local export support.

## Phase 0.10 — Documentation authority

This phase is the current documentation pass. The canonical surface is:

- [`AUDIT.md`](AUDIT.md) for source-backed measurements and preservation rules;
- [`DOCUMENTATION_MAP.md`](DOCUMENTATION_MAP.md) for document authority and
  lifecycle;
- [`project_direction.md`](project_direction.md) for product intent and design
  principles;
- this file for sequence and exit gates;
- [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) for adding content;
- [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for open findings;
- [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`FEATURE_MAP.md`](FEATURE_MAP.md)
  for ownership; and
- [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) for the balance surface.

The remaining work is to classify older plans, add current-state notes as they
are reopened, add run scope to dungeon documents, and archive only after
incoming links and compatibility rationale have been checked.

The verification-surface audit is a separate prerequisite for Phase 0.20. Do
not expand the smoke inventory while it is active; use focused owner checks and
the curated gate only.

## Phase 0.20 — Stabilize active contracts

The active issue register currently contains menu presentation, exact gear
selling, sell performance, first flame music startup, equipment touch clipping,
R5/R6 route identity, flame-room fast travel, zero-Chroma bound identity,
neutral Chroma collection, and pickup color selection. See
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for each acceptance contract.

The rule for this phase is evidence before status changes. “Implemented in
source” means the path exists and has some focused coverage; it does not mean
that cold-start timing, physical-device touch behavior, orientation layout, or
full journey behavior has been verified.

## Phase 0.30 — Shared menu boundaries

Start from the scene-authored Pause and Demon Hub conventions. Extract shared
visual and interaction primitives only after their coordinates and behavior are
characterized:

- panel/frame geometry;
- right-side command lists;
- cursor anchoring and movement;
- SELECT/BACK footer cells;
- list clipping and scrolling;
- responsive layout anchors; and
- equivalent keyboard, controller, mouse, and touch commands.

Move one screen at a time out of `screen_state_controller.gd`. Keep route state
and callbacks explicit, preserve the central frame schedule, and compare the
render at native 240×160 before checking wider modes.

## Phase 0.40 — Room and encounter boundaries

Define typed results around room transition, arrival sockets, room persistence,
encounter spawning, and reward orchestration. The room transition and activation
results, plus the initial typed enemy-spawn and chest-item reward results, are now
in place. Preserve authored and generated layout distinctions. A room is eligible
for activation only after its full enemy body positions and route reachability
have been validated. The next seam is the remaining reward persistence and
settlement boundary.

## Phase 0.50 — Typed runtime ownership

Select one boundary only after the active contracts are stable. The preferred
first candidates are checkpoint command/result, room transition result, or the
shared actor geometry interface. Move behavior vertically, remove obsolete
wrappers only after their final consumer is migrated, and measure the reduction
in reflective calls for the migrated feature.

## Phase 0.60 — Content authoring

Use [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) to make one new room,
enemy, reward, and tuning example repeatable. Add validators at the current
definition boundaries before moving data out of code. Keep stable IDs and save
migrations part of every data change.

## Phase 0.70 — Feedback infrastructure

Group fast tests into shared-process suites where safe, retain focused scene
tests for visual contracts, and record desktop/web timing scenarios. Profile
the known dynamic-call, per-pixel, synchronous-loading, and menu-refresh hot
paths before optimizing them.

## Out of scope for this cycle

- a broad rewrite of `gameplay.gd` or `gameplay_state.gd`;
- changing combat balance during structural work;
- deleting historical design rationale without link and compatibility review;
- moving files by name alone without preserving Godot resource identity; and
- treating static unreferenced results as permission to delete runtime assets.
