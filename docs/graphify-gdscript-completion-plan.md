# Graphify GDScript completion and viewer plan

Status: implementation in progress; GDScript, project/scene resolution, and main-HTML source-group filtering have landed as partial support in the ignored Graphify fork

Updated: 2026-10-11

Owner: `Whynchu/graphify-godot`, default branch `v8`.

Companion: [Godot integration plan](graphify-godot-integration-plan.md).
That document owns resource/scene formats and project identity. This plan owns
the remaining GDScript semantics, their completion gates, and source-group
navigation in the exported viewer. Tiny Demons is the integration corpus.

Implementation evidence and limits are tracked in the fork's
[Godot support matrix](https://github.com/Whynchu/graphify-godot/blob/v8/docs/godot-support.md).
This plan remains the staged acceptance contract; a supported feature is not
considered complete just because one Tiny Demons query links successfully.

## Goal and baseline evidence

Make dependency chains explain which methods call which owners, which authored
properties are consumed, and which tests reference those systems. Allow users
to hide entire source groups without changing the indexed graph.

Before implementation, source evidence lived in the fork's
`graphify/extractors/gdscript.py`, `graphify/godot_resolution.py`, and
`graphify/exporters/html.py`:

- Script classes, scoped methods, top-level variables/types/exports, literal
  source-resource loads, and unique project global-class references exist.
- Resource/scene parsing, attachments, resource properties, scene instances,
  NodePaths, and serialized signal connections exist.
- The initial viewer had community checkboxes and label search but no
  source-group controls. V1 now routes both filters through one visibility
  predicate; see the support matrix for implemented behavior and deferred
  viewer surfaces.
- The local map contains 17,165 nodes and 21,766 edges. Seven of the 605 scanned
  GDScript files reported grammar recovery. These are baseline observations,
  not a declaration of language completeness or successful runtime execution.

## Completion contract

Target explicitly documented Godot 4 syntax. Inventory supported syntax in
fixtures; preserve locations and diagnostics for unsupported/recovered spans.
Resolve a relationship only when scope, binding, type, or scene evidence supports
it. Distinguish engine built-ins, excluded files, missing targets, ambiguous
targets, and dynamic receivers. Never pick a method globally by matching name.

Every stage must survive final graph assembly/export, preserve distinct evidence
when endpoints coincide, and produce equivalent normalized full/incremental
results. Indexing must require neither Godot nor a live editor and must never
mutate the game project. Dynamic behavior may remain unresolved with useful
evidence; silently missing behavior does not satisfy completion.

## Delivery sequence

| Stage | Work | Status | Acceptance |
| --- | --- | --- | --- |
| V1: source-group filters | Classify exported nodes and add group checkboxes using one shared visibility predicate. | Implemented for main HTML; tree/callflow views deferred. | Docs/tests/scripts can be independently hidden and restored; community filters, search, edges, and selection remain consistent. |
| G1: declaration and syntax coverage | Signals, enums/members, constants, nested-class ownership, static methods, parameter/return types, annotations, accessors, lambdas and Callable ownership; investigate known recovery spans. | Partial; lambdas and broader grammar coverage remain. | Small fixtures cover each supported construct, duplicate names remain scoped, and valid unsupported syntax is reported honestly. |
| G2: local calls | Same-script calls, explicit `self`, local binding/shadowing, constructors, preload aliases and supported static calls. | Partial; preload aliases and literal dynamic calls are newly covered. | Exact caller-to-method edges, no calls from strings/comments, and negative fixtures prevent name-only matches. |
| G3: typed cross-file calls | Parameters, members, return types, supported inferred assignments, inherited methods, `super`, nested types and typed collections. | Partial; typed collections, inheritance and `super` have bounded support. | Follow calls through known receivers; duplicate classes, overrides, unknown types and reassignment remain safe and diagnosed. |
| G4: property consumption | Record property reads/writes through resolved owners, including supported getters/setters and definition-resource receivers. | Partial; typed cross-script reads/writes, script properties, and serialized assignments are covered. | Distinguish declaration, serialized assignment, runtime read and runtime write; demonstrate a used and an unconsumed authored property without claiming dynamic absence proves dead data. |
| G5: script signal wiring | Declarations/emits, signal `.connect`, supported legacy forms, method Callables and literal callback names. | Partial; declaration, emit/connect and narrow local callbacks are covered. | Wiring and emission remain separate facts; callbacks resolve only with receiver evidence; inherited signals and ambiguous callbacks have fixtures. |
| G6: Godot context | Parse main scene/autoload/plugin settings; resolve supported `$Path`, `%UniqueName`, `get_node` and scene-attached receivers. Add a separate bounded slice for inherited scenes. | Partial; project settings, literal node paths and root inherited scenes are covered. | Project/nested-project isolation; autoload types connect calls; distinguish one script attached to several scenes; unknown runtime nodes stay unresolved. |
| G7: dynamic boundary reporting | `call`, `call_deferred`, computed loads, groups, runtime injection and unresolved callbacks. | Partial; common dynamic boundaries now receive source diagnostics. | Bounded source records identify why a target is unknown; literals resolve only when receiver evidence exists. |
| R1: release proof | Supported-version/platform matrix, clean installs, full/incremental parity, rename/delete invalidation, export/query metadata and documented limitations. | In progress; focused Windows fixtures cover parity and rename behavior. | Windows/Linux gates pass with Godot extra; missing grammar gives actionable diagnostics; representative end-to-end queries have reviewed answers. |

V1 is implemented on the main HTML export and remains partial until auxiliary
tree/callflow views can expose equivalent controls. G1-G7 are intentionally
partial; use the support matrix to pick bounded follow-up work. Refresh the
fork's own graph after code changes as required by its contributor instructions.

## V1: source-group filtering contract

Use a new namespaced role field such as `source_group`; preserve existing
`file_type` values and language metadata. Assign every node exactly one group,
including methods, properties, document sections, resources, and manifest rows.
Derive the group from normalized source paths and extensions, with configurable
path overrides. Nodes inherit the role of their owning source file.

| Checkbox | Default membership |
| --- | --- |
| Docs | Markdown and other indexed documentation sources |
| Tests | Test directories/files and verification inventory rows/manifests |
| Scripts | GDScript and other application source code outside tests/tools/addons |
| Scenes | `.tscn` scene sources |
| Resources | `.tres` resource sources |
| Tools | Repository tooling and automation sources |
| Addons | Addon/plugin sources |
| Config | Project/build configuration and workflow sources |
| Other | Remaining sources and nodes without an attributable source |

Classification precedence: explicit user override, addon/tool ownership, test
ownership, then ordinary extension/path rules. Thus addon tests stay under
Addons by default; `tests/foo.gd` and its methods belong to Tests rather than
Scripts. A Markdown file under tools/addons follows that ownership unless
overridden. Show these rules in help and provide path overrides so this remains
useful beyond Tiny Demons. Normalize Windows separators without lowercasing
canonical file identities. Ignored `graphify-godot/` remains outside the corpus.

Viewer behavior:

- All groups checked initially; group labels show exported node counts. Include
  Select all, Clear all, and presets for Game (Scripts/Scenes/Resources),
  Verification (Tests plus Game), and Everything. Presets change group choices
  only; provide a separate Reset filters action to restore community choices.
- A node is visible only when its group AND its community are enabled. Route
  both controls through one visibility function. Hide edges when either endpoint
  is hidden; toggling a community must never resurrect an excluded group.
- Search operates on visible nodes. Inspection lists visible neighbors and a
  hidden-neighbor count. If selection becomes hidden, clear its inspection and
  highlight state. Community counts distinguish visible and total nodes.
- Changing filters preserves pan/zoom and does not restart physics by default.
  Keep labels, details and checkbox text accessible and usable by keyboard.
- Classification precedes any exporter sampling/cap. Filtering is limited to
  exported nodes: show the export's total-versus-included count and ensure
  presets do not imply omitted nodes can be restored. Review sampling separately
  if a source group disappears because of the export cap.
- Keep graph JSON intact; store filter choices in the URL fragment so they can
  be shared and restored in a standalone HTML file. Unknown group values are
  ignored safely. The main HTML viewer is the first delivery surface; inventory
  tree/callflow viewers and add equivalent controls where their data permits,
  documenting any deferred surface explicitly.

Verification: classification fixtures for overlapping paths, path overrides,
unknown sources and child nodes; behavior checks for intersecting filters,
hidden edges/selection/search, preset/reset and URL restoration. Regenerate both
Tiny Demons HTML exports and inspect Scripts-only, Docs-off, Tests-off and
Verification views. Check an addon/tool cluster is independently removable.

## Evidence and useful-query gates

Maintain a support matrix with implemented/partial/unsupported status, fixture
names and known limits. Report extracted/resolved/ambiguous/dynamic counts
separately. Zero extractor crashes is insufficient: validate the missing facts.

Review these queries against source evidence after the relevant stages:

1. Which method calls a slime's damage handler, including inherited dispatch?
2. Which consumers read the authored collision geometry, and which only load it?
3. Which authored enemy property is assigned but has no statically observed read?
4. Which signal/Callable connects a UI action to its handler?
5. Which autoload or attached component owns a call from the main scene?
6. Which tests reference a changed owner, and what portion is still dynamic?
7. Does deleting or renaming a target remove old edges and report new gaps?

Run focused extractor/resolver/exporter tests first, then required fork regression
checks. Use synthetic fixtures with expected and forbidden edges, plus read-only
Tiny Demons corpus checks. Capture unresolved examples, not just totals. No game
smoke suite is needed for documentation or parser/viewer-only changes.

## Boundaries

Godot 3, binary `.res/.scn` decoding, shaders, C# interop and runtime execution
tracing are separately scoped extensions. Static graph support cannot prove test
coverage, actual execution, performance, or authority of every authored value.
Record packaging/version policy at R1; documentation alone needs no game bump.
