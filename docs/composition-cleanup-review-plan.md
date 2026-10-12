# Composition and repository cleanup — review proposal

Status: proposed; awaiting owner review. No implementation or deletion approved.

Scope: whole-repository composition, generic ownership, deprecated code, file
organization, asset and SFX lifecycle; staged implementation after prerequisite proof

Owner: repository architecture and gameplay systems

Current code: tracked-tree snapshot `85c9f071`; graph built at `78320ffb`.
Committed `scripts/`, `resources/`, `scenes/`, `assets/`, and `tests/` paths did
not change between those snapshots. Later documentation/tool/config paths are
listed in the P0 inventory. Pre-existing uncommitted edits to `project.godot`
and `scenes/authoring/previews/enemy_preview_workbench.tscn` are identified but
their contents are outside the captured graph. Counts describe the audit
snapshot, not a release.

Verification: reproducible graph/file census, focused source inspection and
read-only enemy architecture review. No Godot execution or game tests performed.

Supersedes: none. Extends [the approved composition plan](composition-plan-2026.md)
with generic enemy ownership and repository retirement gates; preserves the
[component contract](component-composition-design.md),
[authoring milestones](authoring-system-plan.md), and
[roadmap stopping rules](ROADMAP.md#added-workstream--architecture-cleanup-03x).

Updated: 2026-10-12

## 1. Outcome and boundaries

Adding a new enemy, spell form, room, item or screen should require a definition,
an assembly recipe, and only the capabilities unique to that content. Shared
services must not require editing slime behavior or teaching a global state
holder another species. Human readers should find the owner, consumed data,
dependencies and verification without tracing an entire gameplay root.

Composition means reusable behavior with explicit dependencies. Family-specific
slime movement and skeleton bone attacks remain legitimate specialization.
Generic names alone do not make those behaviors interchangeable. Avoid a new
universal actor with every possible component attached, a second gameplay root,
or an ECS rewrite. Extract a seam only when two real consumers or a demonstrated
extension need justify it. Balance changes require a separate proposal.

This document is a plan for review. It does not declare the engine rewritten,
the graph complete, or any file safe to delete. Implementation starts only
after review, through bounded slices of the existing workstreams.

## 2. Whole-map coverage and evidence limits

The checked-in [census](composition-map-census.json) enumerates **every community
and mapped source path**, plus tracked files missing from the graph. The
[P0 disposition review](composition-p0-review.md) summarizes the completed
whole-map triage; the complete per-community and per-file records are in the
[machine-readable inventory](composition-p0-disposition.json). The census and
inventory contain community names, memberships, top connected nodes,
cross-community edge incidents, relation counts, path dispositions, audio
inventory and byte-identical audio sets.

| Snapshot measure | Count |
| --- | ---: |
| Graph nodes / links | 21,073 / 46,226 |
| Communities / unique mapped source files | 727 / 1,016 |
| Tracked paths in the P0 inventory, excluding the nested Graphify repo | 3,126 |
| Tracked GDScript files, including tests and addons | 605 |
| Files under `assets/` and `Artwork/`, including import sidecars | 1,389 |
| Audio files (`wav`, `ogg`, `mp3`) | 335 |
| Resolved sound catalog keys, including music | 53 |
| Audio outside declared/preferred catalog endpoints | 245 |
| Sets of byte-identical audio files | 5 |

Coverage is **full enumeration plus domain-level triage**, with detailed source
audit of the enemy seam and selected cross-system owners. It is not a manual
review of all 21,073 symbols. P0 completed on 2026-10-12: all 727 communities
and all 2,110 paths absent from the graph now have conservative dispositions,
owners, evidence, confidence, risks and next actions. The path count is 3,124
tracked paths at source commit `85c9f07` plus the two P0 review artifacts. No
deletion is approved. The [extraction ledger](composition-extraction-ledger.md)
reconciles known in-progress work against current source and records the proof
needed to close each handoff; it complements rather than replaces the full P0
inventory.

Graph queries use vocabulary expansion: `enemy`, `slime`, `actor`, `component`,
`runtime`, `catalog`, `resource`, `sound`, `audio`, `asset`, `test`, `profile`.
The census traverses all nodes and edges and ranks connections within each
community. Graph degree indicates navigation pressure, not runtime cost or bad
design. For example, `GameplayState` has 916 edge incidents, while coordination
documents also rank highly because they mention many systems. Documentation
edges, test references, source calls and scene attachments must stay distinct.

The graph includes dynamic-call and Godot-resource blind spots. Missing edges
do not prove unused code, passing tests or an unused asset. Check literal and
computed paths, UIDs, generated manifests, inheritance, signals/Callables,
editor plugins, export presets and save migrations in source. Preserve source
locations and evidence type in each subsequent finding. Graphify itself is an
ignored, separate repository and is not part of the Tiny Demons cleanup.

## 3. Strengths to preserve

- Explicit frame scheduling and narrow runtime owners already provide a good
  foundation. Keep authoritative tick order and debug/pause behavior.
- Typed enemy definitions, factory rejection of unsupported families, family
  geometry resources, manifests, catalogs and the preview workbench are real,
  consumed infrastructure. Extend their contracts rather than inventing a
  competing registry or preview path.
- Shared health/status components, actor geometry and typed room spawn services
  are reusable seams worth keeping.
- Role folders, UID sidecars, test manifest classification, stable content IDs
  and documented compatibility boundaries support safe incremental migration.
- Menu presenters, `HubMenuState` and catalog-driven audio already demonstrate
  shared ownership. Historical claims about duplicated Hub page constants are
  stale: both controllers now alias the same state script.

## 4. Source-backed findings and wider audit queue

Evidence levels: **confirmed** means inspected source; **documented** means an
existing authority records the issue and needs current consumer confirmation;
**candidate** means inventory or graph evidence requiring investigation.

| ID | Finding / evidence | Proposed boundary | Prerequisite |
| --- | --- | --- | --- |
| E1 confirmed | `SkeletonActor extends SlimeActor` (`scripts/actors/skeleton_actor.gd:2`); factory signatures use `SlimeActor` (`scripts/content/enemy_factory.gd:17,32,41`). | Sibling family actors under shared `EnemyActor`; generic factory contract. | Mixed-family characterization and roster contract. |
| E2 confirmed | `SlimeActor.ensure_components` attaches Brain, Combat, Animation, Visual, Spawn, HealthPresenter and BossJumpSlam (`scripts/actors/slime_actor.gd:69–84`). | Shared required capabilities plus optional family/behavior recipes. | Component lifecycle/reset ownership. |
| E3 confirmed | Slime runtime owns targetability, movement, separation, status transmission and skeleton projectiles (`scripts/runtime/controllers/slime_runtime_controller.gd:161,251,355,636,741,869,1089`). | Shared enemy lifecycle coordinator; family locomotion and attack executors. | E1, stable services, performance baseline. |
| E4 confirmed | Targeting reads `root.slimes`; bootstrap mirrors factory actors into several arrays; collision tests `actor is SlimeActor` (`targeting_runtime_controller.gd:24,30,60`, `gameplay_bootstrap.gd:270–275,613–641`, `actor_collision_system.gd:39`). | Ordered enemy roster and common `enemies` membership. | Save slot/order contract and cleanup policy. |
| E5 confirmed | Brain discovers gameplay through parents and consumes world/collision services (`scripts/components/slime_brain.gd:193–208,252,271–278`); combat reads metadata and mixed tuning (`slime_combat_component.gd:100–128`). | Inject narrow movement, perception, neighbor and attack contexts. | Typed interfaces with real callers; no global-root context wrapper. |
| E6 confirmed | `SlimeTuning` spans movement, shared spawn/aggro, boss, support and health presentation (`scripts/content/slime_tuning.gd:4–84`); player HUD reads its drain speed (`gameplay_frame_controller.gd:584`). | Shared enemy defaults, family/behavior tuning and HUD presentation tuning. | Field-to-consumer/default ledger; preserve balance. |
| E7 confirmed | Room persistence uses stable variant IDs and slot-keyed runtime state (`scripts/runtime/controllers/room_controller.gd:1331–1363`). | Preserve serialized IDs, slots, alive/position/health/chroma restore. | Actual file-based restore characterization, not only in-memory roundtrip. |
| E8 confirmed | Mixed-family catalog is `SlimeVariantCatalog` (`scripts/content/slime_variant_catalog.gd:95–100`). | `EnemyCatalog` public ownership with temporary compatibility adapters. | Factory/roster migration; all script/resource/editor consumers enumerated. |
| D1 confirmed | Component guide calls `SlimeBrain` blind while source performs root discovery; architecture recommends slime component reuse for new families. | Correct current-state documentation alongside each migration. | Keep approved target contract distinct from actual implementation. |
| R1 documented | Generator policy fields and item `visual_id` have no authoritative consumer according to `CONTENT_AUTHORING.md` trap table. Item catalog still writes `visual_id` (`scripts/content/item_catalog.gd:246,307–308`). | Complete consumption or deliberately retire schema fields through authoring Slices 2–3. | Refresh source consumer proof; previews and exports agree. |
| R2 confirmed | Item catalog has retained IDs/tombstones and PlayerProfile compatibility aliases (`scripts/content/item_catalog.gd:49–65`, `scripts/runtime/state/player_profile.gd:7,60,72`). | Separate compatibility from current runtime API. | Supported save versions and migration tests; tombstones are not dead code. |
| A1 confirmed | Sound paths are concatenated; `preferred_audio_path` selects an existing `.ogg` sibling (`scripts/content/sound_clip_catalog.gd:7–13,75–83`). | Asset/audio usage resolver that understands derived paths. | Resolve fallback behavior before deduplication. |
| A2 confirmed | Web export uses `all_resources` with an empty exclude filter (`export_presets.cfg:15–17`). | Measure shipped content; decide archive/import/export retention explicitly. | Exported-PCK inventory and live content load proof. |
| A3 candidate | Five byte-identical audio sets and 245 files outside catalog endpoints. | Review source provenance, alternate versions and preview/tool consumers. | No deletion based solely on hashes or catalog absence. |

Paths abbreviated in this table resolve through the matching graph source
paths and role folders. Refresh line locations before implementation.

### Domain-by-domain queue

| Domain / map anchor | Audit questions and bounded target | Existing owner / dependency |
| --- | --- | --- |
| Bootstrap, GameplayState, frame controller | Which state belongs to a feature? Which dynamic seams are still necessary? Inject services once; keep explicit assembly and schedule. Do not relocate all fields into another giant context. | Composition plan and ROADMAP C5; preserve frame ordering. |
| Enemies, collision, targeting, actor presentation | Apply E1–E8. Geometry remains shared across render, collision, targeting, attack guides and flashes. Cache/group updates must not reorder slots. | Enemy authoring milestone and mixed-encounter performance correction. |
| Player, abilities, magic, status, projectiles | Trace cast request → damage/status → projectile lifecycle; distinguish actor-neutral mechanisms from player input and resource rules. Compare spell-form executors before extracting a reusable attack seam. | Element/status/form plans; combat acceptance and focused coverage. |
| Rooms, dungeon graph, generation, encounters, puzzles | Trace definitions → compiler → runtime → map/puzzle preview. Separate route policy, encounter roster, room layout and presentation; remove duplicate authority only after replacement consumption. | Authoring Slice 3 and typed room boundary. |
| Items, elements, rewards, progression | Reconcile parallel enums, records, authored resources, reward rules and profile IDs. Keep stable IDs; identify dictionary adapters that still own live behavior. | Authoring Slice 2; persistence and progression contracts. |
| Hub, menus, HUD, display, input, touch, audio settings | Review complete screen ownership, shared widgets, typed action contexts and transactions. Preserve device prompts, pixel scaling and browser behavior. | Deferred ROADMAP C4 and authoring Slice 4; current Pause acceptance first. |
| Profile, run settlement, cloud, web persistence | Enumerate serializers, aliases, schema migrations, encryption and autosave boundaries. Separate migration code from current API while preserving supported old saves. | Production boundary, profile/save docs and web plan. |
| Effects, lighting, occlusion, art/animation caches | Inspect allocation, cleanup and shared frame/geometry authority. Decide pooling or shared services from measurements, not degree. | Performance cost guide and mixed-encounter correction gates. |
| Editor tooling, previews, manifests, validators | Ensure game, preview and export use the same data and assembly. Audit `@tool` lifecycle, undo, cache invalidation and UID moves. | Authoring M1 export/add/move/delete evidence. |
| Tests, reports, tools, CI | Distinguish runnable tests, reports, helpers and archived fixtures. Trace what assertions prove; avoid duplicate suites or count-pinned content checks. | Verification-surface audit, `tests/manifest.csv`, authoring Slice 5. |
| Addons and third-party sources | Mark vendor ownership, required editor/export integration, licenses and generated files. Exclude vendor internals from first-party refactor targets. | Addon-specific contracts and export requirements. |
| Docs, coordination, config, source art, unmapped files | Classify authority/history/generated output/provenance/runtime source. Repair stale claims; archive only after incoming-link review. | Documentation map, source-art archive, authoring Slice 6. |

## 5. Target enemy composition

`EnemyDefinition` + family geometry + behavior recipe → `EnemyCatalog` →
`EnemyFactory` → `EnemyActor` with explicit required/optional capabilities →
ordered roster → scheduled runtime services.

- `EnemyActor`: identity, shared health/status references, spawn/death lifecycle,
  reset contract and typed capability references. No slime attack, skeleton
  projectile, boss scale heuristics or player/HUD tuning.
- `SlimeActor` and `SkeletonActor`: siblings; family visuals and assembly hooks.
  Prefer injected strategies/components when inheritance would add behavior.
- Required capabilities: health, geometry, presentation and lifecycle as needed
  by existing contracts. Optional capabilities: locomotion, melee/ranged attack,
  support cast, boss phase, ambush. Validators reject incompatible recipes.
  The generic recipe schema and its validator are proposed P3 infrastructure,
  not an existing consumed contract. Prove factory/runtime/preview parity and
  exported loading for each optional capability before retiring actor assembly.
- Perception/steering consumes a typed world/neighbor service. Attack timing
  consumes immutable configuration; execution consumes explicit damage,
  projectile or support services. Components never climb to the gameplay root.
- Ordered roster is authoritative for deterministic iteration and room-save
  slots. Define one owner for insertion, activation, family replacement, death,
  removal and reset.
  Legacy `slimes` adapters must forward to the same data, not keep a second list.
- All factory-created enemies join `enemies`. Proposed meaning: registered
  enemy nodes, including temporarily inactive/pooled ones; explicit roster
  queries select active, alive, hostile and targetable enemies. Group membership
  is discovery/classification, not a replacement for ordered scheduling or save
  identity. Review this lifetime policy before implementation.
- Collision asks for geometry/collision capability and faction; targeting asks
  for targetability. It should not infer either from the slime class name.
- Family collision profiles remain authoritative. Use the existing collision
  guides and authored profiles; do not restore a competing hitbox source.

**Proof:** add a test/preview sibling enemy that does not inherit `SlimeActor`,
then a real approved content family using the same assembly route. It must
work without edits to slime ownership, family branches in shared runtime,
new GameplayState fields, or a bespoke preview implementation.

## 6. Prerequisites and implementation sequence

Each row is a work package; implementation PRs subdivide it into narrow seams.
An open device/performance gate does not block read-only inventory or independent
documentation work, but it blocks claiming risky affected-runtime work accepted.

| Phase | Depends on | Deliverable and acceptance bar |
| --- | --- | --- |
| P0 — complete whole-map disposition | This proposal and the tracked source snapshot | **Complete 2026-10-12.** The [P0 review](composition-p0-review.md) and [full inventory](composition-p0-disposition.json) cover all 727 communities and 2,110 unmatched paths, with owner, evidence, confidence, risk, dependency and next action. No deletion is approved; graph edges and missing text references are not proof of runtime use or non-use. |
| P1 — establish migration floor | Owner review of this proposal and relevant P0 findings | Record current mixed-family behavior, actual room/profile restore, preview lifecycle, exported manifest/PCK load and UID status. Characterize slime → skeleton → slime replacement within one slot: HUD/health bindings, stale targets, caches, position and slot identity. Confirm current test failures and live editor availability. Reproduce mixed-enemy performance baseline under its existing plan. |
| P2 — generic enemy identity and roster | P1 mixed-family/save proof | Introduce EnemyActor sibling contract; coordinate factory, room services, collision/targeting and preview migration through small compatible packages. Add common group lifecycle, including in-slot family replacement; preserve stable IDs/slots/scheduler and balanced stats. Compatibility adapter shares one roster. |
| P3 — reusable enemy behaviors | P2 and relevant performance evidence | Extract one locomotion/attack strategy at a time, remove parent discovery, inject services, attach optional components by recipe. Split tuning by actual consumers. Prove mixed room, support/boss lifecycle and independent sibling. |
| P4 — catalog and content authority | P2; authoring M1 lifecycle evidence | Migrate mixed-family registry API; finish consumed enemy field authority. Coordinate item/element/room work under authoring Slices 2–3. No new parallel registries. Preserve old resource paths until references migrate. |
| P5 — cross-system ownership | Relevant P1/P4 contract evidence | Follow domain queue: one state boundary, complete screen or shared mechanism per slice. Keep C4 deferred until current UI acceptance; retain feature-specific specializations. Demonstrate cheaper second consumer and no performance regression. |
| P6 — retirement and file organization | Replacement accepted for each candidate | Remove obsolete adapters/fields/tests/files in small commits. Asset/SFX dispositions need the evidence below. Godot-aware moves preserve UIDs; regenerate manifests/indexes and repair docs. |
| P7 — closeout | P0–P6 findings resolved or explicitly deferred | Rebuild Tiny Demons-only map and HTML, compare ownership/consumer paths, run applicable gates, record remaining exceptions and update canonical docs. Human can add content through the documented workflow. |

Recommended first correction after review: P1 characterization around the
enemy seam, then P2. Do not start with mass renaming, directory moves or
deleting low-degree nodes.
The known unresolved element catalog UID, open exported-PCK/manifest lifecycle
evidence, mixed-enemy frame-rate incident and current UI/runtime acceptance
remain owned by their existing plans. Resolve only the relevant blocker before
touching its seam; do not require every unrelated product issue to close first.

### Slice contract

Family replacement is already a multi-owner operation:
`scripts/runtime/services/room_enemy_spawn_services.gd:133–182` transfers HUD
children, updates five arrays, rebinds occlusion/HUD, transfers positions,
binds health signals and frees the old actor. Room preparation invokes it while
iterating the roster (`room_controller.gd:1827–1835`). Preserve this path and
prove no duplicate callback, stale target or old group member survives.

Before editing: declare owner/files, current callers and serialized fields,
expected behavior, compatibility adapter, focused characterization, rollback,
and runtime/performance acceptance. A crossing of three owners requires a typed
command/result or signal contract first. Respect the coordination board.

After editing: source/diagnostic check, focused behavior proof, applicable
composition/definition/manifest gates, then curated release gate in a safe
standalone session. Commit one characterized responsibility change. Update
AUDIT/ROADMAP phase status only after the required evidence actually passes.
Keep structural, balance, broad file moves and asset deletion changes separate.

## 7. Deprecated code, stray files, assets and SFX

### Evidence required before retiring code or files

Build an incoming-consumer ledger spanning script calls/inheritance, signals,
Callables/string dispatch, scenes/resources, UIDs, editor entry points, tests,
tools/CI, generated manifests and save compatibility. Record the replacement,
reason, owner and last supported contract. Characterize the replacement before
removing the old path. A test-only helper or historical source is not stray
merely because gameplay does not reference it. Retired item IDs and migration
aliases need compatibility decisions; tombstones may remain permanently.

Initial file-cleanup targets are candidates: compatibility facade methods,
old schema adapters, duplicate generated reports, obsolete fixtures, stale
documentation and unused preview/prototype entry points. P0 determines which
actually exist and which still serve an intentional purpose. No named code file
is presently approved for removal.

### Asset and audio inventory procedure

1. Inventory every tracked asset, source-art file, `.import`/UID sidecar,
   generated sheet and audio clip with size, hash, provenance/license and owner.
   Add ignored authoring outputs only when they matter to reproducibility.
2. Resolve scene/resource dependencies, UID mappings, literal paths, path
   concatenation, fallback siblings, directory scans, manifests and frame-library
   generation. Include game, editor previews, tests and SFX/art production tools.
3. Inventory an actual exported PCK. `all_resources` plus empty exclusions is
   a reason to measure package inclusion; it does not prove every source file
   ships. Compare package bytes, startup/memory and editor-import costs.
4. Classify: required runtime; source/provenance; preview/test-only; generated
   reproducible; alternative approved version; duplicate candidate; unresolved.
   Source art under `Artwork/.gdignore` is an intentional archive, not unused trash.
5. Review alternate audio by listening and checking mix/pitch/loop configuration.
   Compare WAV/OGG equivalence separately from exact hashes. Preserve the selected
   `.ogg` sibling and required fallback until the audio contract changes safely.
6. Propose archive/export-exclusion before deletion when source value remains.
   Record a recoverable Git checkpoint and licenses. Move/delete imported Godot
   assets through the editor, verify dependent paths/UIDs, refresh manifests,
   test affected previews and exported runtime, then record final disposition.

The census resolves 53 catalog keys and their declared/preferred endpoints;
245 of 335 clips lie outside those endpoints. This is a finite investigation
queue, not an unused count. The naive full-literal-path scan finds no audio
references at all because constants compose paths—an explicit demonstration of
why graph isolation or raw text matching cannot authorize deletion.

Five exact-hash duplicate sets include copies of reconstructed footsteps and
level-up audio. They may preserve production provenance. Inspect all sets in
the census, sound mix profile and `tools/sfx_lab` consumers before choosing a
canonical path. No audio licensing conclusion is made by this audit.

## 8. Verification and measurable completion

| Concern | Required evidence |
| --- | --- |
| Composition | Validator/self-test where rules change; no new root discovery in shared components; two actual consumers or a proven extension need. Count reduction alone is insufficient. |
| Enemy behavior | Spawn locks, notice delay, movement/knockback, attack commit/hit/cooldown, support targeting, boss phases, projectile cleanup, death/room clear and renderer registration. Compare old/new mixed families. |
| Persistence | Load supported profile files and restored room states; preserve enemy IDs, slot mapping and alive/position/health/chroma. In-memory definition roundtrip alone is insufficient. |
| Authoring/export | Definition/manifest/UID checks; add/move/delete lifecycle and exported-PCK loading; factory/runtime/preview parity; collision guide fidelity. |
| Presentation/device | Mixed-room playtest, preview lifecycle, UI and input on affected devices; browser save/audio/touch when affected. |
| Performance | Existing Run 30 editor protocol and target gates; measure cache/allocations, tick catch-up, collision and presentation. Headless timings do not close editor/device gates. |
| Retirement | Consumer ledger closed, provenance retained where required, no broken imports/UIDs/exports; manifest classification and doc links corrected. |
| Repository clarity | Every first-party source has a role/owner; every asset has a disposition; authority docs match consumed runtime; generated navigation is refreshed. |

MCP-first rules apply whenever an editor peer is connected. Use script diagnostics,
scene probes and playtests through MCP; do not launch the smoke runner in that
session. Standalone tests require no active MCP editor/runtime and supervision.
Start focused; broaden only for remaining risk or required gates. This plan's
documentation-only commit requires link/census validation and diff review, not
Godot execution or a version bump.

## 9. Model handoff and review decisions

Use **GPT 6.1 Sol** for planning, contract review, source ambiguity and acceptance
review; use **GPT 6 Luna MAX** for bounded implementation packages. Each Luna
handoff names owned paths, current authority documents, exact dependencies,
preservation requirements, focused verification, stopping criteria and expected
evidence. Pause a slice for contract review if new cross-owner coupling, unknown
save semantics, unresolved dynamic consumers or a required failed gate appears.
Do not delegate the entire engine rewrite as one task.

Owner review should settle:

- EnemyActor/ordered-roster direction and proposed `enemies` group lifetime.
- Priority of P2/P3 relative to current enemy authoring and performance work.
- Save support/retention policy for retiring compatibility APIs.
- Archive and shipping policy for source assets, alternative SFX and vendor data.
- The first bounded implementation package after P0/P1 evidence is recorded.

Acceptance of this proposal approves the sequence and boundaries. Individual
removals and gameplay changes still need their concrete evidence and review.
