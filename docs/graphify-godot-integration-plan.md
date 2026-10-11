# Graphify Godot integration plan

Status: partial Godot support is implemented in the fork; completion and release proof remain in progress

Updated: 2026-10-11

Owner: developer tooling in `Whynchu/graphify-godot`; Tiny Demons is the
integration corpus and adoption owner.

Follow-on execution: [GDScript completion and viewer plan](graphify-gdscript-completion-plan.md)
defines the remaining language semantics, release proof, and source-group filters.
This integration plan retains ownership of the Godot file-format contract.

## Current implementation snapshot

The fork now discovers `.gd`, `.tres`, `.tscn`, and `.godot` project settings;
extracts scoped GDScript declarations and supported call/property/signal facts;
resolves project-local resources, UIDs, autoloads, literal NodePaths, and root
inherited-scene trees; and exports intersecting source-group/community filters
in the main HTML view. These are static facts with explicit dynamic boundaries,
not complete Godot runtime or language support. Tested details and current
limits live in the fork's
[Godot support matrix](https://github.com/Whynchu/graphify-godot/blob/v8/docs/godot-support.md).

Goal: answer dependency and ownership questions across GDScript, authored
resources, scenes, and project configuration with links to the source evidence.
The first useful release must connect these file types, not just list symbols.

## 1. Scope and evidence

Implement Godot 4 support first, including Tiny Demons' current 4.7-era text
files. Godot 3 compatibility and binary resource decoding are later work.
Use deterministic local parsing for the structural graph. Optional semantic
document analysis can follow once the structural graph is trustworthy.

The original integration inspected Graphify `b4e6307`, package version
`0.9.85`, on `v8`. Godot support is now developed on the fork's default `v8`
branch. Upstream synchronization and branch state are recorded in the matching
`coord/status-codex.md` entry; check it before the next integration release.

| Existing surface | Integration consequence |
| --- | --- |
| `graphify/detect.py`, `CODE_EXTENSIONS` | `.gd`, `.tres`, `.tscn`, and `.godot` are currently absent. Discovery must route them to deterministic extraction, including in `--code-only` mode. |
| `graphify/extract.py`, `_DISPATCH` | This is the active per-extension dispatcher. Add thin facade imports and dispatch entries here. |
| `graphify/extractors/__init__.py`, `LANGUAGE_EXTRACTORS` | Descriptive registry; its own docstring says dispatch has not migrated here. Register new modules consistently without assuming this alone activates them. |
| `graphify/resolver_registry.py` | Register a Godot pass after per-file extraction; this is the existing extension seam for cross-file resolution. |
| `graphify/extractors/base.py`, `ids.py`, `validate.py` | Reuse source reading and ID helpers; satisfy existing node/edge fields and confidence values. |
| `graphify/build.py` | Assembly applies deduplication and relation precedence. Test final built graphs, because a correct raw edge may disappear or collapse with another edge. |
| `graphify/cache.py` | AST caches include package/schema/grammar versions. Godot project context and cross-file changes also need explicit invalidation acceptance. |
| Tiny Demons `docs/CONTENT_AUTHORING.md` | Authored values can be ignored by runtime code. Resource presence and property reads are separate facts. |

Representative local evidence:

- `scripts/content/enemy_definition.gd`: global class, exported data,
  script preloads, and a runtime load boundary.
- `resources/definitions/healer_slime.tres`: script-backed resource,
  StringName IDs, dictionaries, and packed geometry arrays.
- `scenes/authoring/previews/boss_slime_authoring.tscn`: attached component
  scripts, external texture, spatial child nodes, and `unique_id` values.
- `scripts/content/content_definition_manifest_data.gd`: generated dependency
  references that remain real export dependencies.
- `project.godot`: main scene, autoload, enabled editor plugins, input data.

## 2. Architecture

Keep the implementation in the Graphify fork as ordinary extractor/resolver
modules. Tiny Demons receives only invocation/configuration and adoption docs.
The ignored nested checkout remains an independent Git repository.

Proposed modules; final names can follow nearby upstream conventions:

| Module | Responsibility |
| --- | --- |
| `extractors/gdscript.py` | Tree-sitter syntax walking, symbols, local calls, types, literal resource dependencies, unresolved records. |
| `extractors/godot_text.py` | Shared lexer/parser for scene/resource sections and Variant-shaped values. Emits authored structure and references. |
| `extractors/godot_project.py` | Relevant project settings and plugin configuration; uses the shared text parser where compatible. |
| `godot_resolution.py` | Project roots, `res://` and UID lookup, class index, typed receiver resolution, scene attachments and connections. |
| `tests/fixtures/godot/` | Small licensed/synthetic Godot projects and selected Tiny Demons patterns. |

Pipeline: discover files -> parse each file into source facts -> construct
project/class/UID indexes -> resolve references -> build/validate the graph ->
report coverage and unresolved evidence.

Per-file cache entries contain syntax facts, not resolved answers that depend
on another file. Re-run project resolution over the current corpus on update.
Keep its inputs serializable for Graphify's parallel extraction workers.
Do not introduce a Godot installation or live editor dependency for indexing.

### Identity and project roots

- Reuse Graphify's canonical file IDs and source-path normalization. Add scoped
  symbol/scene-node/subresource IDs using the existing helpers and collision
  handling. Test identical names and identical stems with different extensions.
- Locate the owning `project.godot` even when scanning a subdirectory. A scan
  root and a Godot resource root are different concepts. Partition nested
  projects so `res://` resolves inside the correct project.
- Normalize `res://` against that project root; relative external-resource
  paths against their containing file. Never lowercase identities globally;
  verify Windows behavior and case-sensitive Linux behavior.
- Build UID aliases from scene/resource headers and `.gd.uid` sidecars; expand
  to other source-side UID files when needed. Treat contradictory UID/path
  pairs, duplicate UIDs, and unknown UIDs as diagnostics. Do not silently
  choose a target or depend on the editor's `.godot` cache.
- Local `ExtResource` and `SubResource` IDs are separate namespaces scoped
  to a file. Scene-node IDs include their scene and full node path; retain
  `unique_id` as metadata when present. UID aliases support finding moved files;
  graph IDs may change on rename until a separately tested identity policy lands.
- Do not pull excluded dependencies back into the corpus. Represent them as
  external references using a tested Graphify convention or report them unresolved.

### Graph contract and evidence

Keep valid existing `file_type` values; use a namespaced kind attribute for
Godot classes, signals, resources, scene nodes, and configuration. Verify that
extra metadata survives graph assembly, JSON export, queries, and MCP responses.

| Source fact | Relation / context direction |
| --- | --- |
| Script declares class, function, signal, or export | `contains` / `method` with scoped ownership. |
| Script extends a project script/class | `inherits` to the resolved base; engine bases recorded as built-in metadata. |
| Literal `preload`, `load`, `ResourceLoader.load` | Existing dependency relation with `godot_preload` / `godot_load` context. Preserve the literal, location, and owner. |
| Resolved function invocation | `calls`, with receiver/type evidence. |
| `.tres` root/subresource has an attached script | `references` with `godot_script_attachment` context to the script/class. |
| Authored property uses external/subresource | `references` with property name and owner context. |
| Scene parent owns a child | `contains` in the authored tree. |
| Scene node instances another scene | `uses` with `godot_scene_instance` context. |
| Serialized signal connects to a method | `references` with `godot_signal_connection` context; distinguish connection wiring from an executed call. |
| Project selects main scene/autoload/plugin | `uses` with the corresponding project-setting context. |

These are proposed mappings to validate against Graphify consumers. Avoid new
relation vocabulary until an existing relation demonstrably loses meaning.
Where assembly collapses facts sharing endpoints, preserve all relevant source
locations/contexts through a tested aggregation strategy; do not silently lose
the distinction between loading a file and attaching its script.

Use `EXTRACTED` for explicit source facts. Resolved associations must include
their evidence; label assumptions `INFERRED`, and unresolved ambiguity
`AMBIGUOUS` where Graphify can retain it. Never resolve an unknown receiver by
choosing the only method in the repository with a matching name.

Keep scalar values as bounded property metadata. Do not make every number,
vector coordinate, dictionary key, or animation sample into a graph node.
Preserve large values as type/size/source-span summaries. Property-level nodes
can be added selectively when needed for usage queries and demonstrated to
survive Graphify assembly without overwhelming the graph.

## 3. Implementation sequence

Each phase is a reviewable change in the fork. Include its fixture coverage and
update language support docs. Separate upstream-compatible extraction work
from Tiny Demons invocation changes.

### Phase 0: prove parser packaging and freeze the contract

Use the existing `PrestonKnopp/tree-sitter-gdscript` grammar. As of 2026-10-11,
PyPI lists release `6.1.0`, MIT licensed. Its project page says repowise-dev
publishes the upstream release unchanged; the PyPI provenance attests to that
publisher's GitHub Actions build. Wheels are listed for Windows x86-64, Linux
x86-64, and macOS ARM64. Graphify's supported platform matrix still needs CI
coverage where no wheel is published. The upstream Graphify issue's statement
that the package is not on PyPI is now stale.

Add it as pinned optional extra `graphifyy[godot]`. Do not request the grammar's
own optional `[core]` extra: its metadata pins `tree-sitter~=0.22`, which
conflicts with Graphify's `tree-sitter>=0.25,<0.26`. The base grammar binding
works with the installed Tree-sitter 0.25 runtime according to the upstream
Graphify proof of concept. Verify that exact combo in required-platform CI.

Acceptance: clean installs on Windows and Linux; parse representative Godot 4
syntax including annotations, typed arrays, lambdas, inner classes, and newer
supported syntax. Document rejected syntax and parse-error spans. Missing grammar
must produce an actionable installation warning, never a successful empty graph.
Capture a small baseline fixture graph and validate the proposed graph metadata
and relation mappings through assembly/export. No Godot execution is required.

Initial local setup (2026-10-11): pinned `tree-sitter-gdscript==6.1.0` under
the `godot` optional extra and resolved/installed with Graphify's locked
`tree-sitter==0.25.2` on Windows x86-64. This verifies package resolution and
installation in this local workspace, not clean-environment CI coverage. A
parse inspection found the grammar emits `ERROR` nodes for a valid
semicolon-separated line in Tiny Demons' `scripts/components/slime_brain.gd`.
Treat partial tree parses as partial evidence and preserve an error diagnostic;
evaluate a span-preserving preprocessing fix or upstream grammar correction
before claiming zero syntax errors on the whole project.

### Phase 1: GDScript declarations and dependencies

Add discovery/dispatch and a dedicated AST extractor. Cover file-level classes
with and without `class_name`, `extends` by class or quoted path, inner classes,
static and instance functions, signals, enums, constants, variables, exports,
parameter/return types, annotations, and `@onready` declarations. Keep local
variables out of the default top-level symbol inventory.

Record literal `preload/load/ResourceLoader.load` targets and bindings such as
`const SCRIPT = preload(...)`. Implement same-script and typed class/static
calls first; retain unresolved receiver records for later project resolution.
Avoid engine built-ins becoming highly connected fake project symbols.

Acceptance: discovery and `--code-only` include `.gd`; named/unnamed scripts
produce valid symbols; comments and strings do not create calls; overload-like
names in unrelated classes stay distinct; parse errors are visible; repeat and
parallel runs produce the same normalized facts.

Initial implementation (2026-10-11, now on the fork's default `v8` branch):
`.gd` is in code discovery and dispatch, with a helpful `[godot]`
missing-grammar hint. The extractor records one script-class node per file,
global `class_name` and `extends` facts, top-level property
types/annotations/export flags, and class-scoped method ownership. Tree-sitter
recovery errors are retained on the file metadata and in Graphify's
`parse_errors` field. A read-only corpus sweep found 605 scripts, 4,068
top-level properties, and 6,222 methods; seven files have grammar recovery
errors, including known valid semicolon-separated statements. These counts are
coverage evidence, not complete GDScript support. Literal resource dependencies
and unique global-class references are covered by the later Phase 4 slice;
signals, enums, constants, broader type resolution, and cross-file calls remain
open. `.tres` and `.tscn` parsing are covered by Phases 2 and 3.

### Phase 2: shared text parser and `.tres` resources

Implement a lexer with quoted/escaped strings, comments, balanced delimiters,
multiline values, section attributes, property paths, and source spans. Parse
`[gd_resource]`, `[ext_resource]`, `[sub_resource]`, and `[resource]` plus
reference values nested in typed/untyped arrays and dictionaries. Understand
StringName, NodePath, and typed constructors as data. Preserve unsupported
constructors as opaque values with diagnostics; never evaluate constructors.

Create root/subresource records, script attachments, and resource references.
Expose declared script class/type and bounded authored fields such as `id`,
`behavior_id`, and geometry. A field named `id` remains data, not a globally
unique graph identity. Cross-reference typed exports when proven, without
claiming a property is read at runtime just because it was serialized.

Acceptance: healer definition -> EnemyDefinition script; nested references
resolve; local external/subresource IDs do not collide; cyclic resources
terminate; strings containing reference-looking text stay strings; absent
default properties remain unknown; malformed files report useful locations.

### Phase 3: `.tscn` structure and scene composition

Reuse the text parser for scene headers, resource sections, node hierarchy,
script attachments, groups, scene instances/inheritance, editable instances,
NodePaths, and serialized signal connections. Retain overrides as authored
facts. Do not flatten inherited scenes or instantiate PackedScenes to guess
effective property values in this phase.

Acceptance: the boss authoring fixture links Brain/Combat/Health components to
their scripts and locates CollisionGuide under the root. A synthetic fixture
proves a nested scene instance, override, relative NodePath, and serialized
connection resolves to the correct method when attachment/type evidence exists.
Inherited or dynamically created nodes remain explicitly unresolved where
effective composition is required.

Initial implementation (2026-10-11, pushed to the fork's default `v8` branch
at `ea4fdc4`): the shared section/value reader handles Godot 4 `.tres` and `.tscn` text,
including multiline balanced values, comments, quoted strings, StringName and
NodePath constructors, typed arrays, bounded property summaries, and explicit
ExtResource/SubResource/Resource references. It resolves project-local
`res://` paths, resource UIDs, and adjacent `.uid` sidecars after extraction.
The graph includes resource roots/subresources, scene roots/nodes, authored
parent-child edges, script attachments, scene instances, and serialized signal
connections. A callback resolves to a GDScript method only when the receiving
scene node has an explicit script attachment; otherwise the graph preserves the
connection to the destination node and records an unresolved diagnostic.
Incremental extraction reuses reference facts persisted on unchanged file
nodes. Relative NodePaths resolve from the owning scene node; unsupported
absolute, escaping, or missing paths produce diagnostics without invented
nodes. Typed-array summaries count collection entries and do not label vector
constructor arguments as collection sizes. Focused resource/scene tests cover
nested references, strings that look like resource constructors, cyclic
`.tres` files, UID resolution, nested scene instances, relative and unresolved
NodePaths, callback methods, graph assembly, and incremental resolution.

Current limits: project settings/autoload/plugin parsing remains Phase 4;
inherited scenes are not flattened; external assets excluded from the indexed
code corpus remain diagnostics; and dynamically created nodes or untyped signal
callbacks are not guessed.

Tiny Demons code-only map (2026-10-11): generated locally at the ignored path
`graphify-godot/.tools/tiny-demons-map/` with no clustering or LLM pass. It
contains 16,995 nodes and 19,443 edges from 605 `.gd`, 65 `.tres`, and 29
`.tscn` files. Godot links include 165 script attachments, 468 resource
property references, 19 scene instances, and 28 resolved NodePaths. The corpus
has no serialized scene signal connections; their method resolution is covered
by the synthetic fixture. All 194 corpus diagnostics are references to
dependencies excluded from the code-only index (190 PNG textures and four
`.gdshader` files); there are no Godot text parse errors.

Verification: focused Godot text, GDScript, registry, and cache tests pass
(87 passed, 8 skipped); hook coverage passes with Git for Windows' shell on
`PATH` (218 passed, 8 skipped). The entire upstream suite collected 7,042
cases: 6,628 passed, 388 skipped, and 34 failed. Those failures are outside the
Godot changes: 29 Terraform cases need the missing `tree_sitter_hcl` extra; the
wheel-content case needs the `build` dev dependency; the Swift fixture assumes
POSIX `/tmp`; Markdown nested frontmatter needs PyYAML; and two path-memoization
tests fail in unchanged resolver code on this Windows environment.

### Phase 4: project context and cross-file resolution

Parse `project.godot` for main scene, autoloads (including `*` singleton prefix),
enabled editor plugins, and selected input-action metadata. Recognize referenced
`plugin.cfg` files by path/header, without classifying arbitrary `.cfg` files as
Godot code. Build project-local global-class, preload alias, UID, and scene
attachment indexes. Resolve explicit types, `.new()` constructors, inherited
members, `self/super`, and known autoload receivers.

Initial cross-file slice implemented on the fork (2026-10-11): literal
`preload`, `load`, and `ResourceLoader.load` references to indexed `.gd`,
`.tres`, and `.tscn` files resolve through the project resource index. Explicit
type, constructor, inheritance, and class-receiver references resolve only to a
unique project `class_name`; missing resources and duplicate global classes
remain diagnostics. Recognized test-inventory CSVs expose bounded row nodes and
link each row to its sibling GDScript test; the PowerShell extractor follows
`Import-Csv` when its path is a literal or a `Join-Path $PSScriptRoot` binding.
The runner → manifest → test → explicit game dependency chain is now available
in the local Tiny Demons graph. `project.godot` autoload parsing, typed member
calls, scene attachments, and dynamic boundaries remain open.

Add bounded handling for `$Node`, `%UniqueName`, `get_node`, literal
`call/call_deferred`, and signal `connect/emit` patterns. Resolve only when a
scene/type binding is proven. A script may attach to several scenes with
different node trees; preserve candidates/context rather than picking one.
Computed loads, runtime injection, reflection, and group lookups remain visible
unresolved evidence. Do not introduce name-only global call matching.

Acceptance: a complete mini-project connects main scene -> component script ->
resource preload -> typed definition class and a typed method call. Duplicate
class names and dynamic calls produce diagnostics without invented edges.
Changes to a class name, UID, resource reference, project root, or attachment
update edges in unchanged dependent files. Deletions and renames remove stale
nodes/edges. A full build and incremental update agree on normalized results.

### Phase 5: Tiny Demons adoption and useful queries

Use an isolated editable Python environment inside the ignored fork, with its
tested dependency extra. Invoke the fork explicitly so a globally installed
upstream Graphify cannot shadow it. Provide a repository wrapper only after
confirming current CLI/config options; support build, update, and query using
those existing commands. Keep outputs/caches ignored and outside runtime assets.

Honor `.gitignore` and a reviewed `.graphifyignore`: exclude `.godot`, Git data,
the nested Graphify checkout, environments, exports, generated graph outputs,
source-art archives, and irrelevant binary media. Index first-party authoring
addons; separate third-party tooling if it dominates the graph. Keep generated
resource manifests as dependency evidence and mark their generated origin.
Treat `.gd.uid` as supporting metadata, not independent code symbols.

Start with deterministic code-only indexing. Add existing document extraction
later with clear authored-doc provenance and cost controls. Benchmark cold build,
unchanged update, and one-script/one-resource update on this machine; record
durations, peak memory, parsed/failed/skipped counts, and unresolved counts.
Choose performance budgets from those measurements before enabling automation.

Minimum adoption questions, each checked against source spans:

1. Which script defines EnemyDefinition, which resources attach it, and which
   catalogs/manifests reference those resources?
2. Which nodes/components compose the boss authoring scene, and where is its
   CollisionGuide authored?
3. Which functions directly read the CollisionGuide geometry, and which
   owners call those functions? Distinguish direct reads from transitive usage.
4. Which code references healer_slime, and which dependencies lead to the
   support component? If behavior selection is dynamic, show that boundary.
5. Can a fixture with a removed statically resolvable method produce a missing
   target diagnostic? A dynamic root call must remain unresolved unless its
   receiver is established; the graph is not a replacement for Godot diagnostics.
6. Which gameplay scripts/resources do smoke tests exercise? Follow the runner's
   manifest edge to a test entry, then follow only explicit resource and
   global-class references; dynamically selected targets remain unresolved.

Acceptance: reviewed answers for those questions, valid final graph, no silent
Godot-file skips, reproducible full/incremental output, and repeat indexing does
not mutate source assets or start a Godot editor. Existing Graphify discovery,
cache, assembly, and language regression tests pass. Only then add a lightweight
Graphify fixture gate; keep game release verification independent initially.

## 4. Support boundary and follow-ups

First usable milestone: Phases 0-4 complete with end-to-end fixture proof.
Tiny Demons adoption is Phase 5. Symbols alone are an intermediate milestone.

Follow-ups: `.gdshader`/shader includes and material shader references,
`.escn`, selected `.import` metadata for asset UIDs, effective inherited-scene
composition, animation method tracks, and optional C# scene attachments using
Graphify's existing C# extractor. Each needs its own tests and explicit support
statement. Binary `.res/.scn` and exported PCKs are opaque dependencies initially.
`user://` denotes runtime data and is not resolved into the source repository.

The graph shows static source relationships. It cannot prove gameplay execution,
identify every dynamic callback, establish that authored balance is authoritative,
or determine which scene is actually instantiated on a particular run without
additional evidence. Existing ownership docs, validators, and Godot diagnostics
remain necessary inputs to those questions.

## 5. Delivery and references

Implement on a dedicated branch in the Graphify fork. Keep modules and tests
small enough to contribute upstream as GDScript, text resources/scenes, and
resolution slices. Preserve upstream notices/licenses and avoid renaming the
Python distribution before packaging and release policy are decided.
For extractor code changes, follow the fork's `AGENTS.md` requirement to refresh
its own graph after verification, reporting any unavailable tool explicitly.
The present document changes no extractor code and requires no game version bump.

Primary references checked when preparing this plan:

- [Godot 4.6 text scene/resource format](https://docs.godotengine.org/en/4.6/engine_details/file_formats/tscn.html):
  section structure, typed values, UIDs, resource references, and scene paths.
- [GDScript Tree-sitter grammar](https://github.com/PrestonKnopp/tree-sitter-gdscript):
  existing grammar candidate; installation and syntax coverage are Phase 0 gates.
- [PyPI tree-sitter-gdscript 6.1.0](https://pypi.org/project/tree-sitter-gdscript/):
  current distribution metadata, platform wheels, MIT license, and build provenance.
- [Graphify Godot fork](https://github.com/Whynchu/graphify-godot): implementation home.
- [Content authoring guide](CONTENT_AUTHORING.md) and
  [authoring system plan](authoring-system-plan.md): Tiny Demons source-of-truth
  and resource-consumer boundaries.

Verification on 2026-10-11: the pinned grammar resolved and installed against
Tree-sitter 0.25.2 in the fork's ignored Windows x64 environment;
`tests/test_gdscript.py` and `tests/test_extractors_registry.py` pass (5 tests).
The 605-file Tiny Demons GDScript sweep completed without extractor errors and
reported seven parse-recovery files. The fork's required `graphify update .`
also passed, rebuilding its own code graph (20,060 nodes and 40,883 edges).
This is not clean-platform CI or Tiny Demons full-project indexing; `.tres`,
`.tscn`, and Godot runtime verification remain open.
