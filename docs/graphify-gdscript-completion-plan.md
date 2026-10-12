# Graphify GDScript completion and viewer plan

Status: batches 1–7 are landed in the separate Graphify fork at 0.9.87. Local R1 gates are complete; hosted CI has no run on v8 yet. G1–G7 remain partial where the support matrix says so.

Updated: 2026-10-12

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
| V1: source-group filters | Classify exported nodes and add group checkboxes using one shared visibility predicate. | Implemented across graph, tree, and callflow HTML. | Docs/tests/scripts can be independently hidden and restored; community filters, search, edges, and selection remain consistent. |
| G1: declaration and syntax coverage | Signals, enums/members, constants, nested-class ownership, static methods, parameter/return types, annotations, accessors, lambdas and Callable ownership; investigate known recovery spans. | Partial; lambdas and broader grammar coverage remain. | Small fixtures cover each supported construct, duplicate names remain scoped, and valid unsupported syntax is reported honestly. |
| G2: local calls | Same-script calls, explicit `self`, local binding/shadowing, constructors, preload aliases and supported static calls. | Partial; preload aliases and literal dynamic calls are newly covered. | Exact caller-to-method edges, no calls from strings/comments, and negative fixtures prevent name-only matches. |
| G3: typed cross-file calls | Parameters, members, return types, supported inferred assignments, inherited methods, `super`, nested types and typed collections. | Partial; typed collections, inheritance and `super` have bounded support. | Follow calls through known receivers; duplicate classes, overrides, unknown types and reassignment remain safe and diagnosed. |
| G4: property consumption | Record property reads/writes through resolved owners, including supported getters/setters and definition-resource receivers. | Partial; typed cross-script reads/writes, script properties, and serialized assignments are covered. | Distinguish declaration, serialized assignment, runtime read and runtime write; demonstrate a used and an unconsumed authored property without claiming dynamic absence proves dead data. |
| G5: script signal wiring | Declarations/emits, signal `.connect`, supported legacy forms, method Callables and literal callback names. | Partial; declaration, emit/connect and narrow local callbacks are covered. | Wiring and emission remain separate facts; callbacks resolve only with receiver evidence; inherited signals and ambiguous callbacks have fixtures. |
| G6: Godot context | Parse main scene/autoload/plugin settings; resolve supported `$Path`, `%UniqueName`, `get_node` and scene-attached receivers. Add a separate bounded slice for inherited scenes. | Partial; project settings, literal node paths and root inherited scenes are covered. | Project/nested-project isolation; autoload types connect calls; distinguish one script attached to several scenes; unknown runtime nodes stay unresolved. |
| G7: dynamic boundary reporting | `call`, `call_deferred`, computed loads, groups, runtime injection and unresolved callbacks. | Partial; common dynamic boundaries now receive source diagnostics. | Bounded source records identify why a target is unknown; literals resolve only when receiver evidence exists. |
| R1: release proof | Supported-version/platform matrix, clean installs, full/incremental parity, rename/delete invalidation, export/query metadata and documented limitations. | Local Windows full suite, clean wheel/sdist installs, missing-extra diagnostics, parity and rename checks complete; hosted CI is unverified. | Windows/Linux gates pass with Godot extra; missing grammar gives actionable diagnostics; representative end-to-end queries have reviewed answers. |

V1 is implemented across graph, tree, and callflow HTML. G1-G7 remain partial;
use the support matrix to choose bounded follow-up work. The only unverified
R1 gate is the hosted CI result for the pushed fork commit. Refresh the fork's
own graph after code changes as required by its contributor instructions.

## Remaining-gap execution plan

The batches below record the staged implementation and remaining bounded
follow-ups for G1-G7 and V1. Batches 1-7 have landed, but they do not satisfy
every language/viewer contract. Implement follow-ups in `graphify-godot/`;
Tiny Demons remains a read-only integration corpus. Keep the fork support
matrix aligned with fixture evidence and explicit limitations.

### Current evidence (2026-10-12)

- The Tiny Demons integration map was refreshed on 2026-10-12: 21,073 nodes,
  46,226 edges and 727 communities. Its HTML and GRAPH_REPORT.md were rebuilt;
  all nine source-group filters are present. It contains 1,016 source paths and
  zero paths inside `graphify-godot/`, which remains excluded by the root
  `.gitignore` rule.
- Batch 1 now updates or invalidates reassigned inferred receivers, reports
  missing/ambiguous project methods, and accepts valid project headers/comments.
- Batch 2's sweep parsed all 605 Tiny Demons `.gd` files with zero recovery
  diagnostics after source-preserving normalization of the seven observed files.
- Batch 3 now covers nested class/generic receiver types, bounded static factory
  returns, inline accessors, literal/dynamic property access, literal-loaded
  `.tres` receivers, scoped lambda calls/callbacks, and typed Callable receivers.
  Fork commit: `f3fff95` (`feat(godot): resolve accessors callables and resources`).
- Batch 3 verification: 182 passed, 8 skipped across GDScript, Godot text,
  export and cache suites; `compileall` and `git diff --check` passed. The
  14 cache-root-switch warnings in the GDScript/Godot tests are the existing
  same-process multi-root warning. Graphify's own map refreshed to 20,458 nodes
  and 42,896 edges with `--no-cluster`.
- Batch 4 is complete in fork commit `f9b4e00`: bounded nested scene context,
  inherited attachment overrides, cycle/depth diagnostics, and indexed plugin
  configuration targets. Its focused verification passed 188 tests, 8 skipped.
- Batch 5 is complete in fork commit `86d06c7`: source-group filters and visible
  summaries now work across graph, tree, and callflow exports. Aggregate detail
  remains bounded and is documented in the fork support matrix.
- Batch 6 is complete in fork commit `41ca4b1`: analyzer/target provenance,
  stage timing, Windows worker cap, incremental parity regression, and a
  repeatable Godot corpus benchmark. The fork map refreshed to 20,512 nodes,
  42,205 edges and 1,113 communities. Benchmark measurements and scope are in
  `graphify-godot/BENCHMARKS.md`.
- Batch 6's exporter/cache regression modules passed 677 tests, with 17 skipped.
- Batch 7/R1 is pushed in fork commit `d424821` as package version 0.9.87.
  The final local full-suite run reported 6,790 passed, 409 skipped, and 60
  failures in the existing Windows environment categories; no GDScript, Godot
  resolver, or CLI export tests failed. The recorded categories include missing
  shell tools, optional Terraform/PyYAML dependencies, a non-writable Windows
  `/tmp` mapping, and the build module (installed afterward for artifact checks).
- Built the 0.9.87 wheel and sdist on Windows. Fresh isolated installs passed
  the Godot extraction smoke for both formats; the base wheel passed the
  actionable missing-grammar check. The focused raw and clustered rename/delete
  regression passed both cases. `compileall` and `git diff --check` passed.
- GitHub Actions currently reports zero runs for both commit `d424821` and
  branch `v8` ([fork Actions](https://github.com/Whynchu/graphify-godot/actions?query=branch%3Av8)).
  Windows package checks are verified locally; Linux CI remains unverified.
- The Tiny Demons map took approximately 495 seconds to refresh in one earlier
  run. This is a single observation, not a benchmark budget.

### Batch 1: prevent misleading relationships (G2-G4, G7)

**Owners:** `graphify/extractors/gdscript.py`, `graphify/godot_resolution.py`,
`graphify/extractors/godot_text.py`, and their focused fork tests.

1. Add failing fixtures for inferred receiver reassignment, missing methods on
   typed receivers, and standard Godot project headers.
2. Invalidate inferred bindings when reassignment makes their type uncertain.
   Resolve sequential reassignment only with sufficient evidence. Cover member
   access as well as calls, shadowing, branches and assignments inside loops.
3. Emit distinct missing, ambiguous, excluded-dependency and dynamic diagnostics.
   Distinguish known engine methods and unknown engine inheritance from missing
   project methods. Keep diagnostic truncation visible when per-file caps apply.
4. Handle comments and pre-section assignments according to the input format.
   Preserve quoted semicolons, multiline values and real malformed-input errors;
   do not relax scene/resource validation indiscriminately.

**Acceptance:** `First.new(); receiver = Second.new(); receiver.ping()` must
never retain an edge to First based on its initial binding. A missing project
method has a source diagnostic without a fabricated target. A valid
`project.godot` header has no bogus parse errors and settings still resolve.
Expected and forbidden edges survive final graph assembly and export.

**First implementation slice:** the receiver reassignment regression and
conservative binding invalidation. Land the diagnostic and config fixes as
separate reviewable changes within this batch.

### Batch 2: close parser recovery gaps (G1)

**Owners:** GDScript extractor, grammar dependency/configuration, syntax fixtures.

Minimize each recovery into a standalone fixture before choosing a grammar fix
or narrowly validated source normalization. Preserve original line/column
locations; do not rewrite game scripts to accommodate the analyzer.

| Current corpus recovery | Observed line |
| --- | --- |
| `scripts/runtime/state/gameplay_state.gd` | 1453 |
| `scripts/ui/screen_route_controller.gd` | 215 |
| `scripts/ui/cloud_save_panel.gd` | 75 |
| `scripts/ui/hub_input_controller.gd` | 210 |
| `scripts/runtime/controllers/room_controller.gd` | 1116 |
| `scripts/runtime/controllers/gameplay.gd` | 181 |
| `scripts/components/slime_visual_component.gd` | 399 |

These are observed locations, not permanent identifiers. Include compact
compound control flow, semicolon statements, lambdas, accessors, annotations and
nested classes in the syntax inventory. Record exactly which declarations,
calls and properties should remain extractable around any unsupported span.

**Acceptance:** zero recoveries for supported valid syntax in the 605-file
corpus, plus positive and negative extraction assertions for minimized fixtures.
Any remaining unsupported construct must have an exact diagnostic span and
documented limitation; it keeps the corresponding completion gate open.

### Batch 3: extend script semantics safely (G3-G5, G7)

**Owners:** GDScript extractor/resolver and support matrix. Depends on Batch 1;
lambda/accessor extraction depends on the relevant Batch 2 syntax fixtures.

Deliver separate slices for:

1. Return-value inference, nested generic types and nested-class type spellings.
2. Accessor bodies, dynamic property get/set with literal names, and resource
   receivers inferred from supported literal `.tres` loads and attached scripts.
3. Lambda/Callable ownership, callbacks on typed receivers, inherited signals
   and supported connect/emit forms.
4. Boundary diagnostics for computed loads/callbacks, groups, reflection and
   runtime script/node injection. Keep unsupported runtime relationships explicit.

**Acceptance:** each slice has expected and forbidden edges for duplicate names,
unknown types and ambiguous ownership. Declaration, serialized assignment,
runtime read/write, signal wiring and emission remain distinct facts. Never
infer a target through name-only matching. A lack of statically observed reads
does not label an authored field unused at runtime.

**Status (2026-10-11): complete in Graphify commit `f3fff95`.** The fork now
extracts nested class-qualified and nested collection receiver types, resolves
the supported static factory return subset, connects inline accessor bodies,
reports computed `get`/`set`, follows literal `.tres` loads to attached scripts,
and gives lambdas and typed Callable receivers scoped ownership. The focused
GDScript/Godot, export, and cache suites passed (182 passed, 8 skipped).

### Batch 4: complete bounded scene/resource context (G6)

**Owners:** Godot text extractor, project/resource identity and scene resolver.
Depends on Batch 1; typed script edges use Batch 3 where required.

Resolve ordinary nested instanced scenes, inherited overrides and supported
NodePath cases within a documented static scene model. Keep context specific
when the same script attaches to several scenes. Cover root/parent paths,
unique names, duplicate node names, cyclic instances and unresolved runtime
nodes. Model literal plugin configuration resource targets where supported.

**Acceptance:** nested attached-script calls and resource references follow the
correct scene context. Overrides replace the appropriate inherited binding;
ambiguous contexts produce evidence rather than arbitrary targets. Project
boundaries and excluded dependencies remain respected. Rename/delete and
scene-override updates invalidate dependent edges in unchanged scripts.

**Status (2026-10-12): complete in Graphify commit `f9b4e00`.** Fixtures cover
ordinary nested scene instances, inherited attachment replacement, cycles,
depth limits and plugin configuration references. Absolute NodePaths and other
engine-specific runtime override behavior remain outside the documented model.

### Batch 5: make source filters accurate in every view (V1)

**Owners:** main HTML exporter and tree/callflow exporters, with viewer fixtures.
Can proceed after Batch 1 independently of script semantics.

First choose and document an aggregation design: retain member/edge source
provenance and recompute visible summaries, or provide a bounded detailed
drill-down with explicit aggregate limitations. Measure payload size and browser
cost before selecting the design; do not embed the entire graph without a cap.
An aggregate edge must not imply hidden-source contributions remain visible.
Then add equivalent source-group controls to tree/callflow views.

**Acceptance:** a mixed Docs/Tests/Scripts community accurately changes its
visible membership, counts and link contributions when groups are disabled.
Source and community filters compose with AND; search, neighbors, selection,
URL restoration and pan/zoom obey the same visibility contract. Restore groups
without losing data. Verify both aggregated and individual-node exports, along
with explicit total/included counts for capped exports.

**Status (2026-10-12): complete in Graphify commit `86d06c7`.** Graph, tree and
callflow filters share source-group classification and preserve truthful
filtered summaries. Aggregate graph communities remain summary nodes; their
bounded per-group counts are documented in `docs/godot-support.md`.

### Batch 6: measure maintenance and preserve provenance

**Owners:** fork update/extraction/resolution/export pipeline and metadata;
`tools/graphify.ps1` only if integration changes are necessary.

Capture a baseline during Batch 1, then optimize after the relevant semantics
stabilize. Time discovery, extraction, resolution, graph assembly, clustering,
reporting and HTML export separately. Benchmark cold, unchanged, one-GDScript,
one-resource and one-scene updates with consistent inputs; record wall time,
peak memory, cache state and corpus configuration. Set budgets from measurements
and optimize the demonstrated bottleneck while preserving normalized parity.

Record analyzer package version/revision separately from target project
revision/dirty state. Verify installed distribution metadata agrees with the
package being used; output-directory placement must not select the fork commit
as the Tiny Demons source revision.

**Acceptance:** repeatable measurements explain update cost, incremental edits
match a full build, and metadata identifies both analyzer and analyzed checkout.
Keep query speed and update speed as separate measurements.

**Status (2026-10-12): complete in Graphify commit `41ca4b1`.** The benchmark
records separate update/query/export costs, sampled process-tree memory, cache
state, stage timing and normalized full/incremental topology. Its Windows sample
and limits are recorded in `BENCHMARKS.md`; it is not a full-map performance
budget.

### Batch 7: prove and release supported Godot coverage (R1)

**Owners:** fork CI, packaging/lockfile, integration fixtures and support matrix.
Depends on the preceding completion gates; CI fixtures can be added earlier.

- Declare supported Godot syntax/version, Python and operating-system lanes.
  Test clean wheel/sdist installs with the Godot extra on Windows and Linux;
  require grammar availability so skipped extraction tests cannot create a false
  green result. Include a missing-grammar lane with actionable diagnostics.
- Compare baseline and final full-suite failures. Fix regressions and document
  genuine platform/optional-dependency exclusions with explicit gate scope.
- Verify final CLI graph equivalence for full/incremental builds, UID and path
  renames/deletes, autoload/attachment/override changes, and cache-schema changes.
  Confirm distinct evidence and metadata survive assembly, export and queries.
- Review all seven useful queries below against current source. Static test
  references describe dependencies, not execution coverage.
- Package version 0.9.87 and the lockfile are in the pushed candidate commit;
  the support matrix and limitations are published in the fork. Wait to tag or
  publish a package release until the hosted Linux CI result is available.
  Documentation and tooling work require no Tiny Demons game version bump.

**Acceptance:** clean supported-platform gates, reviewed useful-query evidence,
reproducible install/update/export steps, and no unexplained regressions. Keep
partial status for any unfulfilled language or viewer contract.

**R1 status (2026-10-12):** The fork candidate is pushed as `d424821` on `v8`.
Windows wheel/sdist clean installs, the base-wheel missing-grammar diagnostic,
the two raw/clustered incremental invalidation cases, and the reviewed Tiny
Demons source queries pass. The Actions API reports zero workflow runs for the
commit and branch, so the hosted Linux lane is still unverified; do not mark R1
fully closed until a run is available. Tiny Demons remains at game version
0.3.89.

### Working cadence and handoff

For each code slice: claim paths, add focused regression evidence, implement,
run focused fork checks and the required regressions, then update support status.
Refresh the affected graph once after a completed code batch and verification,
before handoff. Use the existing map during individual edits and ordinary
questions; check changed source directly. Documentation-only work needs no
refresh. An explicit fresh-map request overrides that cadence.

Use parser/resolver/viewer tests for this work; do not run Godot gameplay smoke
suites to validate the analyzer. Keep the entire `graphify-godot/` directory
excluded from the Tiny Demons corpus. Fork code commits and Tiny Demons
documentation commits remain separate.

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
