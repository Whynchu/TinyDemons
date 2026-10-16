# Composition team execution

Status: active execution plan, 2026-10-16

Owner: parent Codex agent; implementation delegated by bounded file ownership.

Authority: [composition cleanup](composition-cleanup-review-plan.md),
[full composition exit criteria](composition-plan-2026.md#exit-criteria),
[extraction ledger](composition-extraction-ledger.md), and
[content authoring](authoring-system-plan.md). This document sequences their
work and records evidence; it does not replace their acceptance contracts.

## Goal and working branch

Complete the composition plan and demonstrate that an unfamiliar agent can
find the right owner, change supported content, and verify the result without
editing central gameplay coordination. Human visual/input acceptance is the
last product check. A passing composition percentage is a regression floor.

Work in `review/composition-cleanup-plan` at
`C:/Users/Samue/AppData/Local/Temp/TinyDemons-composition-review`.
`G:/dev/Games/TinyDemons` is a separate dirty `main` worktree. Preserve it.
The user authorized publishing composition changes to the existing review
branch, not merging or publishing a game release on `main`.

The recovered `visual_id` retirement is published as `8e4358a` (its tree is
identical to local recovery commit `4801d0c`). Gear, item-definition, and item
workbench smokes pass on Godot 4.7.2; recursive definitions pass at 110/110.
Strict composition, manifest (160 rows / 158 runnable / 45 gate), and UID
(469 script sidecars) checks pass. The pending Web renderer override edit is
outside the recovered change. Direct Git transport is unavailable; the GitHub
connector published the same tree after its public-journal disclosure check.

## Team and ownership

Use the team skill and agent workflow. The project config permits four concurrent child agents (five total including the parent); this live chat currently caps at four total.
Parallelize independent reviews and disjoint worker packets with explicit board claims. Serialize overlapping edits.
The parent owns Godot/editor access, status coordination, integration, and acceptance. Never claim capacity beyond the active session.

| Responsibility | Assignment | Evidence expected |
| --- | --- | --- |
| Source/ownership audit | Thorn, read-only | Named callers, definitions, runtime consumers, stale claims, risks |
| Player and author workflow review | Hexley, read-only | Preserved behavior and end-user acceptance checklist |
| Sequencing and bounded tasks | Pip, read-only | Dependencies, files, done evidence, stop conditions |
| Mechanical instructions and independent navigation | Luna LOW worker | Localized diff or unassisted task report |
| Contract and lifecycle implementation | Luna MAX worker | Characterization, typed ownership, rollback, focused evidence |
| Integration and publication | Parent | Review every diff; own coordination, editor, checks, commits and branch publication |

Every packet names the absolute worktree, branch, allowed files, authority
sections, callers/data consumers, preserved semantics, required evidence and
stopping conditions. Workers report surprises instead of broadening ownership.
They do not revert concurrent work. Parent alone touches the shared Godot
bridge and `coord/status-codex.md`; preserve opencode's runner/Pages claim.

## Execution queue

| Package | Phase / dependency | Deliverable | Acceptance and status |
| --- | --- | --- | --- |
| E0 Recovery | P4; existing overnight diff | Retire unused item visual metadata; retain shared slot art | Published; three focused checks, 110 definitions and static guards pass |
| E1 Team workflow | All phases | Small reusable skill and evidence-backed execution packets | Implemented; independent LOW navigation completed; official YAML validator unavailable without PyYAML |
| E2 Item lifecycle | P4 / X12 / X17 | Catalog-owned create/remove, generated manifest and cache parity, editor undo/redo | Technical smoke passes on 4.7.1 including both replacement guards and post-save rollback; real editor history/reopen acceptance open |
| E3 Entry points | E2 | CLI item scaffolding reaches the same fresh registry; guide describes actual editor/CLI paths | CLI creation, fresh-process preview and fixture-inclusive validation pass; original manifests and fixture absence restored |
| E4 Source reconciliation | P4 / X14, X18 | Correct stale room-spec/policy/folder claims using field-to-consumer evidence | Typed RoomSpec/ConnectionSpec and policy consumption already exist; assign only remaining real parity/validation defects |
| E5 Agent usability | E1-E4 | Independent LOW agent follows docs for supported enemy/item/room tasks | Item exercise passes; isolated enemy create/preview plus fixture-inclusive 111/111 validation and manifest check pass on Godot 4.7.2. Room authoring is not data-only; human editor acceptance remains open (details below) |
| E6 Migration evidence | P1/P2/P3 | Current-source family swap, file-backed restore, brain/steering and preview evidence | Focused checks pass; earlier P3 user acceptance remains valid; do not misreport previously unrun checks |
| E7 Export lifecycle | P4/M1 | Authored fixture and manifest references survive export/reload; runtime MCP autoload inert | Exported-content inventory and actual browser/runtime proof; no conclusion from packaging alone |
| E8 Content authority | Remaining P4 | Reconcile item/element/room field ownership, remove remaining unsupported schemas only with evidence | Consumer ledger closed; stable saves preserved. New-flame proof uses disposable data; shipping new gameplay/art requires a product decision |
| E9 Runtime ownership | P5 / X04-X09 | One complete state/service boundary at a time; validated runtime registration and narrow spawn contracts | Preserve explicit schedule, roster slots, callback/render caches; prove a second consumer or cheaper extension; characterize before moving behavior |
| E10 Menu ownership | P5 / X01-X02-X16 | Finish Pause acceptance before the next complete menu route | Parent/user visual and input evidence at native and wide sizes; forward target met or reviewed exception; no line-count-only split |
| E11 Retirement | P6 / accepted replacement | Close incoming-consumer ledger and retire specific obsolete adapters/schema/files | Script/dynamic/scene/UID/save/editor/export/provenance references proved; no asset/SFX deletion from missing graph edges or hashes |
| E12 Final gates | P7 / E0-E11 | Current graph/report/indexes, authority docs and end-user review packet | Required gate passes; unresolved failures and deferrals named; human enemy/room/gear authoring and product acceptance remain explicit |

P0 disposition is complete; P3 shared-brain architecture is accepted. P1/P2
acceptance is partial. P4 is in progress, and P5-P7 remain open. Performance
acceptance stays owner-deferred; it cannot be silently relabeled as passed.
The broad plan is not complete merely because E0-E3 land.

### E9 checkpoint (2026-10-16)

The X04 registrar covers 42 production services in seven ordered cohorts. The
new typed `GameplayBootstrap.BuildStep` contract carries a name, enum phase,
action, and optional frame yield. Ordered queues now cover shared loading,
title-only assembly, and full gameplay animation/visual/UI construction while
preserving all diagnostic keys and ten gameplay UI frame boundaries. The title
boot and enemy-room entrance smokes pass on Godot 4.7.2. Bootstrap `root.call`
invocations fell from 37 to one concrete-Gameplay save hook; the strict
composition self-test and audit pass. The remaining X04 work is production
append-one-row acceptance and typed `RoomEnemySpawnServices` contexts. The
direct `PerformanceCaptureService` attachment remains outside this slice.

The current 45-path gate remains 30 pass / 12 fail / 3 timeout; the 12 failures
are the recorded red list, and generated bound reachability passed. Timeouts
were generated layout, generated run scene, and touch controls. Main-scene
headless verification passed; Web export remains blocked by missing Godot
4.7.2 Web templates. See `docs/composition-plan-2026.md` for the full current
record.

### E5 checkpoint (2026-10-16)

A LOW worker found no data-only room workflow: the prefab factory still uses an
explicit code registry, while authored run resources carry dictionary room
entries without `prefab_id`. A follow-up isolated E5 trial used Godot 4.7.2 via
a temporary CLI shim: `new variant codex_e5_probe`, same-ID enemy preview,
definition validation (111/111), and manifest check (111 entries) passed. The
fixture was removed and the three changed catalog/manifest resources restored
to their captured SHA-256 values; the disposable checkout is clean. The first
content-suite run passed seven paths before finding stale Slime, boss-selection,
and enemy-room assertions; each corrected smoke passed individually on the
review branch. A fresh one-command 10-path rerun and human Godot-editor checks
remain open. The attempted one-command rerun was not started after its safety
preflight observed a Godot GUI process. Adding a data-driven room definition
path is still needed before a producer can author a new room.

## Checks and integration

Confirm the editor's actual project before using `res://` diagnostics. At this
checkpoint the connected editor uses the separate main worktree, whose old
ItemDefinition still contains `visual_id`. Its results do not validate review
source. Keep one shared editor. Never launch the full runner while an MCP
editor/runtime is active. Focused standalone checks in the isolated review
worktree use a bounded process, their own log, and byte-for-byte restoration
of any temporary MCP-autoload configuration; stop on a crash or timeout.

For each package, record actual engine version, test/probe, result, environment
limits, changed runtime/data/generated paths, and remaining human checks.
Use composition self-test/strict audit, manifest, UID and definitions checks
as relevant. Do not weaken baselines or tests to manufacture a green gate.
The parent reviews changes, commits only the package's paths plus coordination,
and publishes to the authorized review branch. Refresh Graphify once after a
completed verified code batch, not after every individual edit.

Initial gate debt included Chroma default expectations, binding-smoke teardown,
R6+ elite support scaling, and a removed run-theme API call. Chroma and run-theme
fixtures now pass; the elite support runtime defect is fixed in `221d387` with
R6+ and support-component checks passing on 4.7.1. Binding teardown remains
open. Classify each
failure using the current source and accepted gameplay contract. Repair
relevant regressions before runtime extraction; keep independent packages moving.

## Completion evidence

Before declaring completion, reconcile every full-plan exit criterion: enforced
composition rules have rejecting fixtures or explicit unenforced reasons;
floor/forward targets are distinct; scripts have declared roles; live context
twins are zero; Stage 4 non-splits have current reviews; one-row runtime-system
registration validates dependencies; giant targets are met or reviewed;
owner navigation works; enemy, room and gear examples require no central
runtime edits; and the curated gate is green.

Keep a task record for each independent authoring exercise: participant/model,
starting commit, task, elapsed time, allowed docs, paths changed, mistakes,
questions, engineering interventions, save/reopen/preview/export outcome, and
cleanup result. An agent code/terminal exercise does not satisfy the separate
production requirement for Godot-only authoring by an unfamiliar human.

## Review decisions received

Thorn traced the missing item manifest refresh and confirmed the room ledger
has stale dictionary-spec claims. Hexley endorsed item lifecycle consistency,
with stable IDs, source tags, acquisition order and slot art preserved. Pip
selected that lifecycle as the next bounded slice and retained all broader
composition exit criteria. None claimed editor or runtime checks they did not
perform. LOW implemented the reusable team skill; MAX implemented the item
transaction after its regression was characterized.

Current evidence: the expanded item-workbench smoke fails on old source at
immediate registry/picker discovery, stale manifests, selected ID/path, and
missing transaction/undo APIs. Its fixture and project configuration were
restored. The expanded smoke subsequently passed on the implementation, as did
item-definition and gear smokes. Thorn requested an additional same-ID external
replacement guard before final integration. The composition self-test passes.
The team skill's official validator is environment-blocked by missing PyYAML;
its scalar frontmatter and instruction paths were inspected. The review branch
now has a worktree-aware Graphify wrapper:
a query launched from the primary checkout resolved the shared ignored fork
and existing map successfully without changing that checkout's source.

Final E2 focused checks on Godot 4.7.1: expanded item-workbench smoke,
item-definition slice, steering world, family brain behavior, and definition
validator all exit 0 (110/110 definitions after cleanup). Godot 4.7.2 also passed
gear rework, Chroma state, encounter family swaps and run-element themes. The
last three repair earlier stale fixtures/current-source verification gaps.
Steering verification exposed real typed-empty-array failures in the optional
collision-service path of EnemySteeringWorld and EnemyBrain; narrow typed
branches fix both. The steering fixture now explicitly uses non-centered actor
geometry, also checks centered targets, and frees its unattached WalkableArea.
No production tuning changed. The curated gate has not been run with the main
editor active; R6+ elite generation and binding teardown remain open.

Independent navigation exercise: Luna LOW started from the team skill, AGENTS
and authoring guide on the working tree based on `ca18e279`. In approximately
35 seconds it ran Graphify, verified source, and located item CLI/workbench,
enemy family behavior owners, and the typed-runtime/dictionary-authored room
boundary. It needed no runtime edits or engineering intervention. It did not
create content, save/reopen, export, or visually inspect anything. Its cleanup
ambiguity was repaired in CONTENT_AUTHORING: CLI creation has no editor undo;
manual experiment deletion requires manifest refresh. E5's actual authoring
exercise and the human Godot-only acceptance therefore remain open.

The parent separately ran the real CLI create command successfully, then the
creation driver and item preview in fresh processes; the temporary item was
immediately found. Definitions passed at 111/111 with the fixture present.
Cleanup restored the original manifests, fixture absence and project config.
The first preview attempt used a nonexistent driver name; the corrected
`res://tools/preview_item.gd -- --item-id=...` passed. Headless CLI import also
enabled the editor MCP plugin briefly; subsequent isolated import probes must
temporarily disable both editor plugins and the runtime autoload, restoring the
exact original configuration. No GUI editor was opened.

## Independent item authoring exercise

Participant: a separate Luna LOW worker starting at published `094cdef5`.
Elapsed: approximately nine minutes. Parent supplied the worktree, engine path,
allowed fixture paths and verification limits, and isolated the review project's
plugins/autoload with an exact configuration backup. The worker used the team
skill, AGENTS, coordination, authoring guide/traps, Graphify, CLI scripts and
ItemDefinition source. It made no production code changes.

1. `tools/dev.ps1 new item agent_probe_20261015`: exit 0, `ITEM_CREATE_OK`.
2. Edited only the new resource's description and price (37).
3. Fresh `tools/dev.ps1 preview item agent_probe_20261015`: exit 0,
   requested ID, weapon slot, editable card preview.
4. `tools/validate_definitions.ps1`: exit 0, 111/111.
5. Removed its reserved resource (no UID existed), then
   `tools/dev.ps1 manifest refresh`: exit 0, 110 entries.

Parent independently confirmed fixture absence and byte-identical restoration
of all three manifests, then restored the exact project configuration. No
unrelated source, profile, catalog-owned item or main-worktree file was edited.
This proves a terminal authoring path; it does not prove visual quality,
editor save/reopen or export acceptance.

Friction: the worker initially used invalid PowerShell condition syntax, hit a
broken `pwsh` app alias, mistyped the provided Mono engine filename, and paused
on normal headless import's `loading_editor_layout` text. These failed before
content mutation or were corrected before proceeding. Parent confirmed that
only the original main editor remained after the headless worker exited.
The guide now documents Windows PowerShell fallback, exact engine selection
and import-result interpretation. Expected certificate/editor-cache warnings
remained; a Mono Timer teardown warning appeared in the cleanup import, while
the refresh exited 0. No crash occurred.

## Additional findings before the next batch

The initial enemy CLI wrote a raw resource with the removed
`encounter_min_rank` property and leaves manifests stale. Parent reproduced
creation exit 0 followed by an unknown-ID warning and a false preview success:
the requested fixture was reported as `healer_slime`. The preview command
checked readiness without checking selected identity. MAX implemented guarded
catalog creation after old-source failures. The real CLI now creates and
previews the requested fixture in a fresh process, rejects unknown IDs and
rejects `-Force` without changing resource bytes. The starter uses the actual
`encounter_min_run_number = 3` consumer.

The P1 report linked from the plan was missing in this branch, and the branch's
recovery smoke covered in-memory JSON rather than the file-backed/live
path documented in the separate dirty primary checkout. A branch-specific
[P1 report](composition-p1-characterization.md) now records the stronger proof:
the guarded file-backed save/load and live restore check passes on 4.7.1.
P1/P2 remain partial pending export and the supervised standalone gate.

Long generated enemy names exposed a first-draw freeze: label clipping removed
one character and appended three dots to the same string on every iteration.
The parent replaced it with a shrinking raw prefix and bounded width result.
A diagnostic reaches the first frame and the real CLI preview exits 0 for the
long fixture ID. The existing preview lifecycle smoke passes on 4.7.1 with
width-boundary and long-name draw checks. Fixture-inclusive validation passes
111/111; after API cleanup the three manifests match their original bytes.
Godot reserializes the catalog with different bytes; the parent harness restores
its exact original bytes along with the configuration and fixture absence.

Thorn also found that comparing disk state with the mutable draft breaks
Undo Create after an unsaved edit. Parent reproduced dirty-undo and UID-sidecar
directory failures in both existing catalog smokes. MAX implemented persisted
semantic snapshots and pre-mutation directory guards; both smokes now pass on
4.7.1. Both tests also cover an explicit save updating the persisted baseline,
followed by a different dirty draft, and a post-delete manifest failure followed
by successful dirty removal. The latter exposed another bug: Godot can report
a parse error yet return an old cached manifest. Cache adoption now requires a
fresh disk load and complete typed entries matching declared paths. Both smokes
pass after the fix, with exact original catalog/manifest bytes before harness
restoration. Expected loader errors come from the reserved invalid resource;
there are no script failures. Real editor history acceptance remains open.

The standard 4.7.1 build produced a fresh Web artifact; the installed Mono build
refused Web export. Parent verified the standard archive against its official
published SHA256 before use. An isolated native process launched the Web PCK
outside the source worktree and loaded 110 authored resources, 74 item IDs and
Slime/Skeleton factory output. Packaging used temporary plugin/autoload isolation
and the committed Compatibility renderer setting; original config was restored.
This does not prove the export plugin, shipped MCP guard or browser runtime.
The browser bridge reports no IAB/Chrome provider. Those checks remain open.
