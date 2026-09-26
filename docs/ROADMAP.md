# Tiny Demons — 0.2.x Roadmap

Status: working roadmap derived from the accepted refactor route

Updated: 2026-09-26

Baseline: version `0.2.00`, commit `bfe55782f43ee40fe32b5bebd45de988e34579d8`

Current release: version `0.2.86`; the authoring and verification sequence is
now owned by [`authoring-system-plan.md`](authoring-system-plan.md).

This roadmap sequences infrastructure work around the working game. It does
not authorize a rewrite or change the game's identity. The current product
contract remains dungeon crawling, elemental combat, puzzle solving,
exploration, battling, gear, progression, and the title → Hub → dungeon →
settlement → Hub loop. The measured current state is in [`AUDIT.md`](AUDIT.md);
the composition refactor is complete (100% on the strict scorecard).

## How to use this roadmap

Use [`AUDIT.md`](AUDIT.md) for measured current state, [`ARCHITECTURE.md`](ARCHITECTURE.md)
for ownership rules, [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for unresolved
behavior and verification findings, and
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md)
for the post-cleanup content-composition and device-performance direction.
Feature-specific plans provide detail only when they agree with those documents.

Work should move through one narrow slice at a time:

1. characterize the existing behavior;
2. document the owner and boundary;
3. make the smallest structural change;
4. run focused verification and a relevant manual check; and
5. record the result before selecting the next slice.

## Current sequence

| Phase | Purpose | State | Exit evidence |
|---|---|---|---|
| 0.00 | Preserve the `0.2.00` baseline | Complete | clean import, recorded test inventory, focused evidence, and representative manual run |
| 0.10 | Make documentation authoritative | In progress | current map, roadmap, content guide, known-issues register, and lifecycle headers |
| 0.15 | Audit and reduce the verification surface | Active issue | every test/report has a role and state; curated release gate; obsolete checks removed |
| 0.20 | Stabilize active player-facing contracts | In progress | issue tracker findings have focused or manual verification, with failures classified |
| 0.30 | Establish shared menu boundaries | Planned | one migrated menu proves shared frame, cursor, list, footer, clipping, touch, and responsive contracts |
| 0.40 | Separate room and encounter responsibilities | Complete | typed room transition/activation/entry/spawn/clear results and deterministic room fixtures |
| 0.50 | Reduce dynamic runtime seams by feature | Complete | composition scorecard and editor composition at 100%; state bag and room owner at strict targets; legacy adapters retired; all authored definitions inspectable |
| 0.60 | Make content authoring repeatable | In progress — owned by [`authoring-system-plan.md`](authoring-system-plan.md) | typed definitions, single-source registries, factories, previews, and a data-only workflow for enemies, items, rooms, maps, and tuning |
| 0.70 | Improve test and performance feedback | In progress | device-backed timing, memory, render-cost, and reproducible performance scenarios; shared-process fast suites are owned by Slice 5 of the authoring plan |
| 0.80 | Establish long-term content composition | In progress — owned by [`authoring-system-plan.md`](authoring-system-plan.md) | an enemy/room/map can be added through definitions and composition without central-state special cases |

The numeric labels are sequencing markers, not release versions. The project
version remains governed by [`VERSIONING.md`](VERSIONING.md).

## Current checkpoint after 0.2.78

The 0.2.78 composition check passes at 2,201 root accesses, 1,718
`GameplayState` lines / 286 fields, and 2,250 `RoomController` lines. The strict
scorecard and editor-composition measure both read 100%, but that is a proxy:
several authored resources are still untyped dictionaries that the runtime
partly ignores. The authoring system in
[`authoring-system-plan.md`](authoring-system-plan.md) remains the active
sequence for closing the gap between the score and a real workflow:

1. Slice 0 — completed the authority-doc correction, recursive definition
   preflight, `GODOT_BIN` portability, class-cache bootstrap, catalog failure
   signaling, R5 identity check, UID coverage, and dead R3 plan cleanup.
2. Slice 1 — typed enemy definitions, registry, factory assembly, and preview
   implementations are landed. The normal-room `guard_slime` acceptance gap was
   closed on 2026-09-22 by making the room-entry fixture initialize the same
   run-start palette contract as production. The focused content suite is now
   8/8 green. A standalone animated Hub world design preview and project-owned
   authoring dock now reuse the `main.tscn` composition without booting a run.
   The standalone curated gate
   was attempted but remains open on unrelated UI smoke failures and scene
   timeouts; it is not a clean release result yet.
3. Slices 2–3 — items, elements, rooms, maps, and generation policy.
4. Slice 4 — menu route registry and conversion of the code-built overlays.
5. Slice 5 — shared-process fast suites and content-contract tests in CI.
6. Slice 6 — feature folders, generated content/metric docs, and the
   link-checked archive.

Execution order is governed by the authoring plan's M0–M5 milestones: classify
the acceptance baseline, build the shared editor/preview and fast-validation
foundation, finish enemy/art authoring, then gear/elements, visual room/map
authoring, and remaining presentation and handoff work. The editor experience
has three deliberate tiers—animated design preview, isolated interactive
workbench, and full-game playtest—and the refactor is considered complete at a
seam only when the typed owner, runtime factory/compiler, preview, focused test,
and producer workflow all agree. Slice numbers above are workstream
identifiers, not a requirement to defer verification until the end. Each
content milestone includes artwork, performance measurements, and independent
production usability evidence.

Items that stay in this roadmap rather than the authoring plan:

- Make the boss-entry measurement a stable gate: the perf harness reports one
  noisy sample per run, so average it across several door entries before
  treating it as a trend, and optimize only after the A17 device profile exists
  (see `AUDIT.md` section 11.2).
- Finish the browser/device, native-resolution, cold/warm timing, and
  representative gameplay evidence that cannot be established headlessly.
- Close the remaining verification-surface role/state decisions.

Each item should keep its existing owner, add or correct a focused
characterization check, and record the result in
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md). Do not begin a broad ownership extraction
while the authoring slices are in flight.

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
- [`authoring-system-plan.md`](authoring-system-plan.md) for the content,
  verification, and documentation workstream;
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

**Status (0.2.38; extended 2026-09-20):** the shared `MenuCommandList` primitive
is extracted and both the title and pause screens delegate their command-rail
navigation to it (characterized by `menu_command_list_smoke`). Remaining: the
route registry and conversion of the eight code-built overlays, owned by
Slice 4 of [`authoring-system-plan.md`](authoring-system-plan.md).

## Phase 0.40 — Room and encounter boundaries

Typed results now wrap room transition, entry, activation, spawn, clear, and
reward orchestration, with room geometry owned by `RoomGeometryController` and
entry/activation by `room_entry_services.gd` / `room_activation_services.gd`.
Authored and generated layout distinctions are preserved. A room is eligible
for activation only after its full enemy body positions and route reachability
have been validated. The next seam is the remaining reward persistence and
settlement boundary.

## Phase 0.50 — Typed runtime ownership

Complete. The latest 0.2.78 composition check is at 100%: `GameplayState` is
at 1,717 lines / 286 fields, dynamic root access is at 2,202, `RoomController`
is at 2,250 lines, and the transitional/legacy counts are zero. The strict
audit (`tools/validate_composition.ps1 -RequireTargets`) passes, and the
regression floor protects the achieved state. The editor-composition measure
also remains 100% by its definition (all 20 components are blind and
`@export`-configured; 19 editor-able definition surfaces), though that metric
does not prove the content workflows work. See
`docs/component-composition-design.md` for the A1/A2/B1/B2/C1/C2/scope
sequence and `docs/authoring-system-plan.md` for the remaining authoring
reality. Remaining dynamic-access owners (`screen_state_controller.gd`,
`combat_runtime_controller.gd`, `slime_runtime_controller.gd`,
`magic_runtime_controller.gd`) remain possible targeted migration candidates.
The current execution priority is the shared authoring foundation in M1; any
later controller extraction should stay feature-scoped, preserve frame order,
and remove wrappers only after their final consumer migrates.

## Phase 0.60 — Content authoring

Owned by [`authoring-system-plan.md`](authoring-system-plan.md) slices 0–3.
Use [`CONTENT_AUTHORING.md`](CONTENT_AUTHORING.md) for the current workflow and
its trap table; do not follow it blind, because several authored resource
fields are currently ignored. The exit bar is a typed
definition/catalog/factory path for enemies, items, elements, rooms, and
dungeon layouts, an editor dock plus native Inspector/scene workflows, animated
design previews, isolated interactive workbenches, and validators at each
boundary. A second piece of each kind must be added with data only. Keep stable
IDs, asset import/move behavior, cache invalidation, and save migrations part
of every data change.

## Phase 0.70 — Feedback infrastructure

Owned by Slice 5 of [`authoring-system-plan.md`](authoring-system-plan.md):
shared-process fast suites, a content-contract suite, CI coverage, editor
authoring smoke, and preview-contract checks. Keep focused scene tests for
visual contracts and record desktop/web/mobile timing scenarios. Profile the
known dynamic-call, per-pixel palette/image, synchronous-loading, particle,
occlusion, menu-refresh, and editor-preview paths before optimizing them.
Include the Samsung A17 as an explicit target rather than inferring mobile
performance from desktop.

## Phase 0.80 — Long-term content composition

Owned by [`authoring-system-plan.md`](authoring-system-plan.md) slices 1–6, with
the broader direction in
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md)
and the component contract in
[`component-composition-design.md`](component-composition-design.md). The
composition refactor is complete on its scorecard, but that is not a claim that
content authoring is complete. The enemy vertical proof now has a typed catalog,
standalone definitions, definition-owned encounter metadata, a preview
workbench, a factory-created runtime pool, and a passing focused room-entry
acceptance. The current authoring slice adds the editor-neutral placement
catalog, an authoring dock, and live animated Hub preview bindings. The
isolated interactive workbench remains the next M1 work. The curated release
gate remains open on unrelated existing paths. Slices 2–3 extend the same
contract to items, elements, rooms, and dungeon/map definitions.

## Out of scope for this cycle

- a broad rewrite of `gameplay.gd` or `gameplay_state.gd`;
- changing combat balance during structural work;
- deleting historical design rationale without link and compatibility review;
- moving files by name alone without preserving Godot resource identity; and
- treating static unreferenced results as permission to delete runtime assets.
