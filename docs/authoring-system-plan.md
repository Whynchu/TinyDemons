# Tiny Demons — Content Authoring System Plan

Status: active plan (approved direction for the authoring and verification workstream)

Scope: make content creation and feature modification consistently cheap for
humans and agents: typed definitions, single-source registries, factory-only
assembly, previews, contract validation, one command surface, and truthful
documentation

Owner: repository architecture and gameplay systems

Current code: the definition resources under `resources/definitions/`, the
catalogs and factories (`enemy_factory.gd`, `slime_variant_catalog.gd`,
`item_catalog.gd`, `element_catalog.gd`, the `dungeon_layout_*` and
`puzzle_*` builders), `gameplay_bootstrap.gd`, `gameplay_frame_controller.gd`,
`screen_state_controller.gd`, and `tests/manifest.csv`

Verification: each slice has a pinned acceptance bar plus
`tools/validate_composition.ps1`, `tools/validate_definitions.ps1` (wired into
the runner and CI), `tools/validate_test_manifest.ps1`, and focused smoke
tests

Supersedes: none. This plan operationalizes the T2 (content authoring) track of
[`long-term-composition-and-performance-plan.md`](long-term-composition-and-performance-plan.md)
and the factory/definition contract in
[`component-composition-design.md`](component-composition-design.md). It does
not change the T1/T3 direction, the product contract, or the explicit frame
schedule.

Updated: 2026-09-21

## 1. Why this plan exists

The runtime architecture is real and working: one deterministic frame
schedule, 20 components, typed room boundaries, stable save IDs, and a deep
test suite. The authoring layer did not finish the same migration. Today the
repository contains:

- authored `.tres` data that the runtime ignores in favor of duplicated code
  constants;
- several competing registries for the same content kind;
- untyped `Dictionary` payloads that the editor can display but not validate;
- count-pinned tests that turn a content addition into a fake regression;
- a 5,508-line menu controller whose code-built routes cannot be opened in the
  editor; and
- documentation that describes the intended state as if it were the current
  state.

The result is a trap for both people and agents: **the file you are told to
edit is often not the file the game reads.** Every slice below removes a class
of that trap and proves the replacement with a second piece of content.

## 2. Measured starting point (2026-09-20, version 0.2.67)

| Surface | Measurement |
|---|---|
| Runtime scripts | 194 files / ~50,300 physical lines, flat under `scripts/` |
| `root.call/get/set` sites | 2,200 (validator metric; regression floor green) |
| `gameplay_state.gd` | 1,715 lines / 285 fields |
| `screen_state_controller.gd` | 5,508 physical lines, 10 routes; root access is included in the global 2,200-site validator metric |
| `room_controller.gd` | 2,246 lines |
| `dungeon_layout_generator.gd` | 2,487 lines, ~100 static functions |
| Definitions | 14 `.tres` under `resources/definitions/`, 6 tuning `.tres`; validator covers 14 |
| Tests | 134 manifest rows / 132 runnable / 44-path default gate, process-per-test |
| Docs | 104 Markdown files under `docs/` and frozen counts in the authority docs |

Reference commands (current behavior):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_test_manifest.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_definitions.ps1   # release and CI preflight
```

## 3. Target operating model

```text
Author edits a typed definition (inspector or text)
        |
Registry auto-discovers and validates it (IDs, refs, schema)
        |
Factory is the only assembly path (scene, generated run, headless fixture)
        |
Preview scene + contract test (iterate the registry, no count pins)
        |
docs/CONTENT_INDEX.md regenerated from the registry
```

### 3.1 Rules

1. **One source of truth.** If a value is authored, the runtime reads that
   definition. Mirrored `const` tables are deleted, not documented.
2. **Typed entries, not dictionaries.** Each content kind has a `Resource`
   with `@export` fields, a stable `id: StringName`, `validate() -> Array[String]`,
   and a schema version. Catalogs hold typed entries; the inspector edits
   fields, not nested dictionaries.
3. **Auto-discovery with a checked-in manifest.** The registry scans
   `resources/content/**`; a generated, checked-in manifest resource guarantees
   exported web/mobile builds include every entry. Adding content is adding or
   editing definition files, never editing a code list.
4. **Factory-only assembly.** `EnemyFactory`, `ItemFactory`, `RoomFactory`,
   and their peers are the only materialization path. The normal scene, the
   generated run, and headless fixtures share it.
5. **Contract tests, not count tests.** A `content_contract_smoke` iterates the
   registry and asserts invariants. Golden tests pin specific content; they do
   not pin totals.
6. **Preview first.** Every definition kind has a workbench scene that renders
   or steps it without booting a run.
7. **One command surface.** `tools/dev.ps1` owns verify, test, preview, new,
   report, and doctor. Every command is deterministic, non-interactive, and
   safe for an agent to run.
8. **Docs generated from the runtime.** Counts and content lists live in
   generated blocks; hand-written docs link to them instead of copying them.

### 3.2 The authoring loop (target)

```powershell
pwsh -File tools/dev.ps1 new enemy crimson2     # scaffolds one definition file
# edit resources/definitions/crimson2.tres
pwsh -File tools/dev.ps1 verify                  # schema, duplicate IDs, dangling refs, stale docs
pwsh -File tools/dev.ps1 preview enemy crimson2  # workbench scene or screenshot
pwsh -File tools/dev.ps1 test -Suite content     # contract tests, seconds not minutes
pwsh -File tools/dev.ps1 report                  # prints the authored catalog report
```

A content addition is one or two files. Tests and docs are not edited by hand.

## 4. Workstreams

Sequencing: 0 stops false signals, 1 proves the pattern, 2 maximizes daily
value, 3 unblocks level design, 4 is the largest remaining god object and
depends on trustworthy verification, 5-6 amplify everything. Slices may run in
parallel where files do not overlap.

### Slice 0 — Truth and traps (no architecture)

Goal: an author following the repository docs cannot hit a documented no-op.

Work items:

- [x] Fix the actively wrong authority docs: `AGENTS.md`, `README.md`,
  `docs/ARCHITECTURE.md`, `docs/CONTENT_AUTHORING.md`,
  `docs/DOCUMENTATION_MAP.md`, `docs/ROADMAP.md`, `docs/AUDIT.md`,
  `docs/KNOWN_ISSUES.md`, `docs/verification-surface-audit.md`.
- [x] Add the trap register from section 5 to `docs/CONTENT_AUTHORING.md` as a
  "data paths that currently do nothing" table with owner slices.
- [x] Add `tools/validate_definitions.ps1` to the `tests/run_all_smoke.ps1`
  preflight and to `.github/workflows/web-pages.yml`.
- [x] Make the focused tools and runner class-cache-safe. Reproduced
  2026-09-20: with a stale or missing `.godot/global_script_class_cache.cfg`,
  `encounter_definition_smoke` fails at parse time with
  `Identifier "EncounterDefinition" not declared`, and `report_catalogs.gd`
  fails the same way. A headless import pass (`.godot` cache 25 KB → 35 KB,
  189 classes) fixes both. The runner and `run_headless.ps1` must run an import
  pass or detect staleness before launching `-s` scripts; a clean checkout
  the runner now imports the project before launching focused content tests.
- [x] Make `tools/report_catalogs.gd` robust: preload every definition class it
  references instead of relying on the global class cache, exit nonzero when a
  resource fails to load, and drop the dead R3 plan from its list.
- [x] Make the PowerShell tooling host-agnostic. `validate_composition.ps1`
  self-test and `run_headless.ps1` assume `pwsh` is available; fall back to
  `powershell.exe` when it is not, and give `run_headless.ps1` a resilient
  `$ProjectRoot` default plus `GODOT_BIN` support.
- [x] Fix the content data defects the checks previously missed:
  `resources/definitions/puzzle_map_r5.tres` now declares `plan_id = "r5"`, and
  `slime_variant_catalog.tres` is now covered by the definition-resource UID
  validation; its UID matches the script sidecar after import.
- [x] Make `tools/report_catalogs.gd` exit nonzero on a load failure; it
  previously called `quit(0)` unconditionally.
- [x] Make `tools/run_headless.ps1`, `validate_definitions.ps1`,
  `report_catalogs.ps1`, and `run_perf_harness.ps1` honor `GODOT_BIN` like the
  main runner does; remove the hard-coded `C:\Development\Tiny-Demons` default
  or resolve it from the repository root.
- [x] Correct every stale count in the authority docs, or replace the counts
  with a generated block from `tools/repo_report.ps1` (preferred).
- [ ] Archive genuinely obsolete drafts as a separate, link-checked change to
  `docs/history/` per `docs/documentation-audit.md:328`; update the inbound
  links found by search first.
- [x] Delete or clearly mark the dead `puzzle_map_r3.tres` path
  (`puzzle_map_layout_compiler.gd:14` preloads it but builds R3_NEW).

Acceptance bar: an agent that reads only `README.md`, `AGENTS.md`, and
`CONTENT_AUTHORING.md`, then follows the "add an enemy" workflow, edits data
that the runtime actually reads, and the preflight catches a deliberately
malformed definition.

### Slice 1 — Content spine and the enemy proof

Goal: prove the whole pipeline on the smallest kind, end to end.

Progress: the typed enemy catalog, registry lookup, definition-owned encounter
metadata, factory materialization, registry-driven contract coverage,
normal-room pool bootstrap, enemy-specific one-file discovery, preview
workbench, and fresh second-variant proof landed on 2026-09-20. The remaining
work is the generic base/auto-discovery layer shared by future content kinds.

Work items:

- [ ] Add `ContentDefinition` base (`id`, `display_name`, `validate()`,
  `schema_version`) and `ContentRegistry` with duplicate-ID detection and soft
  failure in game / hard failure in validation.
- [x] Convert the slime catalog to typed `EnemyDefinition` entries. The current
  proof uses one typed sub-resource per variant in
  `resources/definitions/slime_variant_catalog.tres`; the loader owns the
  registry lookup.
- [x] Delete the parallel registries: the old
  `slime_variant_catalog.gd:10-20` (`VARIANTS`) list, the dead `.tres` `order`,
  and the recolor fallback list in `enemy_definition.gd` were removed in favor
  of explicit `visual_source` and registry iteration.
- [x] Move encounter weights and rank gates out of `room_controller.gd` into
  `EnemyDefinition` metadata and consume them at runtime through
  `EncounterDefinition.late_pool_entries()`.
- [x] Make HUD palette resolution definition-aware and convert the enemy
  variant smoke/boss selection checks to registry-driven invariants. The base
  `SlimeVisualComponent.PALETTES` list remains a presentation-library surface
  until a new palette authoring slice exists.
- [x] Add the `EnemyDefinition` contract coverage that iterates the registry,
  plus named Crimson golden assertions and save/load coverage.
- [x] Make `EnemyFactory` the materialization path. The bootstrap now creates
  a capacity pool through the factory, and normal room configuration applies
  selected definitions to those actors; scene-authored enemy slots are no
  longer the content roster.
- [x] Add `scenes/enemy_preview_workbench.tscn` and a headless preview driver;
  it materializes any registry enemy through `EnemyFactory` and shows the
  runtime collision/attack geometry without booting a run.
- [x] Prove a fresh standalone `ember_guard.tres` definition through the
  registry-driven preview, round-trip, encounter, boss, and room-entry checks
  without a per-variant test edit.

Current proof: `crimson` remains the embedded migration proof, while
`ember_guard.tres` is discovered as a standalone authored resource, resolved
from the registry, materialized by `EnemyFactory`, previewed without booting a
run, and exercised by the registry-driven definition, round-trip, encounter,
boss, and normal-room entrance smoke tests.

Remaining acceptance bar: run the focused content checks and the curated gate,
keep the fresh variant at one definition file with zero per-variant runtime or
test edits, and confirm that it spawns through the factory in a normal room
without a scene-authored roster slot.

### Slice 2 — Items and elements

Goal: the two highest-volume content kinds become data-only.

Current proof slice (2026-09-21): standalone `ItemDefinition` resources under
`resources/definitions/items/` are discovered by `ItemCatalogData`, converted at
the compatibility boundary, included in live generation, validated, reported,
and covered by a registry-driven stable-ID round-trip smoke. `cinder_blade.tres`
is the named proof item. The legacy dictionary catalogue and element/flame
tables remain in migration.

Work items:

- [ ] Split `item_catalog.tres` (2,046 lines of nested dictionaries) into typed
  `ItemDefinition` entries in `resources/content/items/`.
- [ ] Collapse the three registries (`live_base_ids`, `live_base_definitions`,
  `definition_metadata`) into one, and move `SET_IDS` and the set synthesis
  rules from `item_catalog.gd` into data.
- [ ] Replace the count-pinned gear tests (`gear_system_rework_smoke.gd:13` = 66,
  `gear_catalogue_expansion_smoke.gd:22` = 45, `drop_art_smoke.gd:37`) with
  registry invariants and specific golden items.
- [ ] Decide the `demon_cloak` model: either a `single_instance`/`unique` flag
  in the definition or a documented special case with one owner, not four
  (`player_profile.gd`, `run_state.gd`, `equipment_component.gd`,
  `hub_flow_controller.gd`).
- [ ] Collapse element identity to one source. At minimum: derive
  `element_for_palette()` (`element_catalog.gd:108-126`) from the data,
  validate `element_count` and matchup-table dimensions, and remove the
  duplicate default in `element_catalog_data.gd:14`.
- [ ] Move `AspectCatalog` flame/palette/recipe tables
  (`aspect_catalog.gd:4-32`) and the `PlayerChromaComponent` aspect mirror into
  typed definitions or generate them from the element registry.
- [ ] Add the item and element previews (card/drop for items, palette/effect
  sample for elements).
- [ ] Include `element_catalog.tres` and `palette_library.tres` in the
  validator with real schema checks.

Acceptance bar: add one weapon and one flame with data only; save round-trip
and `dev.ps1 verify` pass; no test edits.

### Slice 3 — Rooms, maps, and generation policy

Goal: level and route content stops requiring controller knowledge.

Work items:

- [ ] Promote `RoomSpec` / `ConnectionSpec` (`dungeon_layout_definition.gd`)
  to typed resources and make the authoured run/plan loaders consume them;
  remove the `Array[Dictionary]` payloads in `dungeon_run_definition.gd` and
  `puzzle_plan_data.gd`.
- [ ] Replace `push_error`-only layout validation
  (`dungeon_map_controller.gd:65-101`) with fail-fast validation that the
  validator and CI can run without booting the game.
- [ ] Delete or make authoritative the policy fields that are validated but
  ignored: `first_orb_depth`, `first_special_depth`, `primary_flames`
  (`dungeon_generation_policy.gd:21-25` vs
  `dungeon_layout_generator.gd:31-32,50`).
- [ ] Consolidate room-type aliases and gate-color whitelists into one
  registry (`dungeon_graph.gd`, `dungeon_map_state.gd:11-16`,
  `dungeon_map_controller.gd:19-22`, `puzzle_map_layout_compiler.gd:218-228`).
- [ ] Make the compiler able to emit the puzzle room type, or document that
  authored plans cannot express it.
- [ ] Remove the dead R3 plan, the R5-compiled-as-R6 path, and the always-false
  `is_native_r7()` seam (`puzzle_route_generator.gd:216-217`), or move the
  unreachable native R7 builder behind an explicit flag.
- [ ] Extend the room preview (`puzzle_map_preview`,
  `generated_puzzle_map_preview`) to render validation errors for any
  authored or generated layout.

Acceptance bar: add one authored room and one policy value with no controller
edits; a bad socket, gate, or duplicate ID fails `dev.ps1 verify` before
runtime.

### Slice 4 — Menu platform

Goal: a new route or row is a scene and a presenter, not a controller surgery.

Work items:

- [ ] Introduce a route registry (state id -> presenter scene + build/enter/exit
  + input handler) so `set_state()` owns route lifecycle instead of only
  assigning a string (`screen_state_controller.gd:528-532`).
- [ ] Convert the eight code-built overlays to `.tscn` + presenter, one at a
  time, adopting `MenuCommandList`, `MenuCursor`, `MenuResponsiveLayout`, and
  `MenuPlayerContext`: title, archetype, save select, name entry, settings,
  game over, run complete, loading.
- [ ] Delete the legacy-hide duplication
  (`_hide_legacy_equipment_presenter`, `_hide_legacy_shop_presenter`) and dead
  compatibility nodes (`HUB_PAGE_STATUS`, `HubPanel8Piece`, hidden settings
  controls) once their callers are typed.
- [ ] Remove the 33-argument `build_hub` packet
  (`screen_state_controller.gd:1194`, unpacked at
  `hub_flow_controller.gd:49-120`) in favor of typed route wiring.
- [ ] Unify input dispatch so the frame controller's visibility if/else chain
  (`gameplay_frame_controller.gd:426-511`) calls route handlers instead of
  overlay checks.
- [ ] Give each presenter a single shared fixture so editor preview data equals
  runtime data.

Acceptance bar: a new route requires one scene, one presenter, and one registry
row; it opens in the editor; one scene smoke passes.

### Slice 5 — Verification reform

Goal: content verification is fast, deterministic, and safe for an agent.

Work items:

- [ ] Add `tests/suites/fast_suite.gd` that runs pure/domain tests in one Godot
  process; keep process-per-test for scene and main-scene tests.
- [ ] Shrink the default gate to a documented, budgeted path list; record the
  expected runtime in `README.md`.
- [ ] Make `state=environment` and `state=unverified` rows fail loudly instead
  of silently poisoning a green gate; separate "environment unavailable" from
  "product failure" in the runner output.
- [ ] Add a content-contract suite that iterates every registry entry.
- [ ] Add a project MCP extension (or a documented `dev.ps1` command) so an
  agent with the editor open can run one focused test or preview without the
  full runner.
- [ ] Run `tools/validate_definitions.ps1` and the fast suite in CI; keep the
  web export.
- [ ] Clean up temp user-data directories after each run, and support
  `-Resume`/`-TestFilter` for crash-stopped batches.

Acceptance bar: content verification completes in under two minutes, no
machine-specific paths, and no editor-session crash hazard.

### Slice 6 — Repository layout and generated docs

Goal: discovery by feature, truthful documentation by construction.

Work items:

- [ ] Make every repo-scanning tool recursive before moving anything: the
  composition validator globs (`tools/validate_composition.ps1:136,471-472`),
  the script index (`tools/generate_script_index.ps1`), and the definition
  validator.
- [ ] Move scripts by feature boundary after UID preservation checks:
  `content/`, `enemies/`, `rooms/`, `menus/`, `presentation/`, `save/`,
  `input/`, `infrastructure/`.
- [ ] Generate `docs/CONTENT_INDEX.md` from the registry and fail verification
  when it is stale.
- [ ] Generate the metric block used by `README.md` and `AUDIT.md` from
  `tools/repo_report.ps1`.
- [ ] Archive superseded docs to `docs/history/` in a link-checked change, and
  reduce the canonical set in `docs/DOCUMENTATION_MAP.md` to the maintained
  authorities.

Acceptance bar: a new contributor can find the owner of a feature by folder
and file name, and every count in the docs matches the tooling output.

## 5. Trap register (must be removed; do not document around them)

| Trap | Evidence | Owner slice |
|---|---|---|
| Policy fields validated but never read | `dungeon_generation_policy.gd:21-25` vs `dungeon_layout_generator.gd:31-32,50` | 3 |
| Item base needs three `.tres` registries plus code lists | `item_catalog_data.gd:8-13`, `item_catalog.gd:45` | 2 |
| Element identity is four parallel tables | `element_catalog.gd`, `element_catalog_data.gd`, `aspect_catalog.gd:4-32`, `player_chroma_component.gd:14-23` | 2 |
| Count-pinned tests block content additions | `gear_system_rework_smoke.gd:13`, `gear_catalogue_expansion_smoke.gd:22`, `element_catalog_smoke.gd:12-21` | 2/5 |

Slices 0 and 1 resolved the class-cache, validator coverage, catalog exit-code,
portability, R5 identity, UID-validation, dead-R3, enemy-registry, and
enemy-encounter traps. The remaining rows are content-system migration work
owned by later slices.

## 6. Command surface

`tools/dev.ps1` is now the thin wrapper for the enemy and item authoring proof
slices. It will grow as later content kinds land:

| Command | Purpose |
|---|---|
| `verify` | manifest + composition + definitions + UIDs + catalog report |
| `test -Suite fast\|content\|gate\|all` | focused definition/content checks, release gate, or full inventory |
| `preview enemy <id>` | validates the enemy workbench without booting a run; `-Editor` opens the scene |
| `new enemy <id>` | scaffolds one standalone `resources/definitions/<id>.tres` |
| `new item <id>` | scaffolds one standalone `resources/definitions/items/<id>.tres` |
| `report` | prints the authored catalog report |
| `doctor` | checks the project root and configured Godot executable |

All commands accept `-GodotBin` and honor `GODOT_BIN`; none require a running
editor; none launch the full process-per-test inventory unless asked.

## 7. Non-goals

- No rewrite of `GameplayState`, the frame schedule, or the combat model.
- No universal content framework or ECS; one typed definition plus one factory
  per kind is the ceiling.
- No balance, save-identity, or pixel-art changes as part of structure.
- No deletion of authored pixel contracts or design rationale.
- No new architecture document per slice; this plan and the existing
  authorities are the surface.

## 8. Tracking

- Each slice records its result in `docs/AUDIT.md` (measurements) and
  `docs/KNOWN_ISSUES.md` (open evidence) when its acceptance bar passes.
- `docs/CONTENT_AUTHORING.md` is rewritten per slice to describe only the
  workflows that actually work at that point.
- `docs/ROADMAP.md` phase 0.60/0.80 point here.
- The composition validator's editor-composition score is a proxy and must not
  be used as evidence that a slice passed; the acceptance bar in this document
  is the evidence.

### Authoring metrics (the real "easy to work with" score)

Per content kind, record these in `docs/AUDIT.md` after each slice:

| Metric | Source |
|---|---|
| Files changed to add one piece of content | diff of the worked example |
| Central runtime files changed (`gameplay_state`, `room_controller`, `gameplay_frame_controller`) | diff of the worked example |
| Time from blank template to playable content | `dev.ps1 new` + preview + test loop |
| Factory path coverage: kinds whose runtime instances come only from a factory | code search per kind |
| Definition validation coverage: resources covered by `validate_definitions` / total authored resources | validator output |
| Deterministic save/load by stable ID | focused round-trip test |
| Reflection or coordinator access required | diff; must be zero for the worked example |

The target metric set for a passing content add: at most two files changed, zero
central runtime files changed, factory-only materialization, validator coverage
of the kind, and a green save/load round-trip.
