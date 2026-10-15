# Composition team execution

Status: active execution plan, 2026-10-15

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

Use the [team skill](../.agents/skills/tiny-demons-team/SKILL.md) and
[agent workflow](agent-workflow.md). The live cap is parent plus one child.
Run advisors and workers serially; the parent can review unrelated material
while the child works. Never claim parallel implementation capacity that the
session does not provide.

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
| E5 Agent usability | E1-E4 | Independent LOW agent follows docs for supported enemy/item/room tasks | Record time, files/docs consulted, errors, interventions, central runtime edits, fixture cleanup and save/preview proof; repair and repeat failures |
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

Existing gate debt includes Chroma default expectations, binding-smoke teardown,
R6+ elite-vault expectations, and a removed run-theme API call. Classify each
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
