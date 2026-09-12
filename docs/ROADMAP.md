# Tiny Demons — 0.2.x Roadmap

Status: working roadmap derived from the accepted refactor route

Updated: 2026-09-12

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

Current release: version `0.2.02`

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
| 0.00 | Preserve the `0.2.00` baseline | In progress | clean import, recorded test inventory, duplicate UID decision, and representative manual run |
| 0.10 | Make documentation authoritative | In progress | current map, roadmap, content guide, known-issues register, and lifecycle headers |
| 0.20 | Stabilize active player-facing contracts | In progress | issue tracker findings have focused or manual verification, with failures classified |
| 0.30 | Establish shared menu boundaries | Planned | one migrated menu proves shared frame, cursor, list, footer, clipping, touch, and responsive contracts |
| 0.40 | Separate room and encounter responsibilities | Planned | typed room transition/spawn results and deterministic room fixtures |
| 0.50 | Reduce dynamic runtime seams by feature | Planned | one owner migration removes its compatibility calls while preserving frame order |
| 0.60 | Make content authoring repeatable | Planned | validated definitions and an example workflow for rooms, enemies, rewards, and tuning |
| 0.70 | Improve test and performance feedback | Planned | grouped verification, runtime timing baselines, and reproducible performance scenarios |

The numeric labels are sequencing markers, not release versions. The project
version remains governed by [`VERSIONING.md`](VERSIONING.md).

## Next checkpoint after 0.2.02

Version `0.2.02` records the touch-scroll repair, UID validator, focused
verification results, and the remaining contract failures. The next
implementation checkpoint is a
stabilization pass in this order:

1. Repair closed doorway geometry and trigger fences, then verify that every
   active room has reachable enemy and player space.
2. Fix generated R6+ bounds and fusion-gate validation, then repair active-run
   snapshot validation before adding more generated content.
3. Repair minimap draw order/discovery visibility and the starter-flame music
   gate; add a cold/warm timing measurement.
4. Reconcile Demon Hub, equipment, and touch contracts against the authored
   Pause/Hub conventions, including cursor, footer, clipping, and direct touch
   targets.
5. Recheck gear catalogue/drop expectations and profile exact sell-row rebuilds
   with representative inventory.

Each item should keep its existing owner, add or correct a focused
characterization check, and record the result in [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).
Do not begin the first broad ownership extraction until the generated-route,
recovery, doorway, and menu contracts are either passing or explicitly
classified as approved design changes. After that gate, take one typed boundary
at a time, with the room transition or checkpoint result as the first candidates.

## Phase 0.00 — Preserve the baseline

The baseline is the current game at version `0.2.00`. Preserve its authored
Runs 1–5, generated Run 6+ policy, controls, pixel presentation, save IDs,
active-run recovery, and explicit gameplay frame schedule.

Remaining evidence work:

- resolve the duplicate R4/R5 resource UID warnings found by the editor import
  scan;
- classify the eight test/report scripts outside the registered smoke list;
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
encounter spawning, and reward orchestration. Preserve authored and generated
layout distinctions. A room is eligible for activation only after its full
enemy body positions and route reachability have been validated.

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
