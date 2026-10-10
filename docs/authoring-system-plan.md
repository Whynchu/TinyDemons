# Tiny Demons — Content Authoring System Plan

Status: active plan (approved direction for the authoring and verification workstream)

Scope: make production content creation and feature modification consistently
cheap for designers, artists, engineers, and agents: editor-first typed
definitions, single-source registries, factory-only assembly, asset references,
previews, contract validation, one command surface, and truthful documentation

Owner: repository architecture and gameplay systems

Current code: the definition resources under `resources/definitions/`, the
catalogs and factories (`enemy_factory.gd`, `slime_variant_catalog.gd`,
`item_catalog.gd`, `element_catalog.gd`, the `dungeon_layout_*` and
`puzzle_*` builders), imported art under `assets/`, preview scenes,
`gameplay_bootstrap.gd`, `gameplay_frame_controller.gd`,
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

Updated: 2026-09-27

> **Family geometry decision (2026-09-27):** collision, body-hitbox, and attack
> guide geometry is family-authored. Editing any elemental variant updates the
> canonical family profile consumed by every variant in that family. The
> profile resources are `geometry/slime.tres` and `geometry/skeleton.tres`.

> **Support behavior slice (2026-09-27):** `EnemyDefinition.behavior_id` now
> composes `support_caster` onto `type_id = slime`; the healer is an authored
> support-role variant that resolves through Slime family geometry and factory
> routing. Tuning stays in the consumed global `SlimeTuning` resource.

> **Note (2026-09-27):** a bounded architecture cleanup is running alongside
> this plan as enabling work, recorded under "Added workstream — architecture
> cleanup" in [`ROADMAP.md`](ROADMAP.md). Its goal is to shrink the surface an
> implementer must read to add a definition, so the factory slices below land on
> a cleaner tree. It does not change this plan's acceptance bars.

## 0. Decision principles and research basis

This plan is grounded in the repository's current seams and in the way mature
Godot, Unity, and Unreal projects separate authored data, editor utilities,
runtime assembly, and play-in-editor verification. The external references are
not a reason to copy another engine's asset model; they are a check against
building a bespoke workflow that fights the engine.

| Decision | Direction for Tiny Demons | Evidence and rationale |
|---|---|---|
| Canonical content | Native typed `Resource` files for data, native scenes for spatial composition, stable IDs for persistence | Godot treats resources and scenes as versionable project files; Unity `ScriptableObject` and Unreal Data Assets demonstrate the same data-asset pattern. It keeps Inspector editing, source control, runtime loading, and agent text workflows on one representation. |
| Editor UX | A small `EditorPlugin` dock for discovery and bulk actions, normal Inspector/custom Inspector editing for fields, and scene editing for spatial work | Godot's `EditorPlugin`, `EditorInspectorPlugin`, and `EditorUndoRedoManager` cover the required extension points without making a second editor inside the game. |
| Preview | Three explicit modes: animated design preview, isolated interactive workbench, and full-game playtest | `@tool` is useful but runs inside the editor with limited safety and no automatic undo. Runtime play-in-editor remains the final integration truth. |
| Runtime boundary | The same registry, validator, factory, and compiler are used by the game, preview scenes, exports, and headless tests | This prevents a polished preview from masking a different runtime path. It also gives agents a small, deterministic surface to inspect. |
| Spatial authoring | Rooms and landmarks are scene-authored; identity, behavior, encounters, rewards, and route policy are resource-authored | Godot's scene-organization guidance favors focused, self-contained scenes with explicit dependencies. It matches the existing `basic_room.tscn`, room layers, socket work, and typed definition direction. |
| Asset lifecycle | Source art and imported runtime assets remain distinct; references resolve through resources and `ResourceLoader`; import contracts are validated | Godot's import pipeline owns imported assets. The editor, not raw file manipulation, must own move/rename/delete operations so UIDs and references survive. |
| Performance | Measure cold/warm editor preview, reimport, memory, texture/material count, and gameplay on target devices before adding flexibility | Godot's performance guidance is measurement-first. Authoring convenience must not turn into an unbounded preview world or per-entity asset/material explosion. |

Primary references: [Godot editor plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/index.html),
[`EditorPlugin`](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html),
[`EditorInspectorPlugin`](https://docs.godotengine.org/en/stable/classes/class_editorinspectorplugin.html),
[`EditorUndoRedoManager`](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html),
[`@tool` editor execution](https://docs.godotengine.org/en/4.5/tutorials/plugins/running_code_in_the_editor.html),
[scene organization](https://docs.godotengine.org/en/4.4/tutorials/best_practices/scene_organization.html),
[project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html),
[the import process](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/import_process.html),
and [Godot performance guidance](https://docs.godotengine.org/en/stable/tutorials/performance/index.html).
The comparable data-asset patterns are documented in [Unity's
`ScriptableObject`](https://docs.unity3d.com/Manual/class-ScriptableObject.html)
and [Unreal Data Assets](https://dev.epicgames.com/documentation/unreal-engine/data-assets-in-unreal-engine).

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

## 2. Measured point (2026-09-22 snapshot, version 0.2.72; test count refreshed 2026-09-26)

| Surface | Measurement |
|---|---|
| Runtime scripts | 199 files / ~50,300 physical lines, flat under `scripts/` |
| `root.call/get/set` sites | 2,200 (validator metric; regression floor green) |
| `gameplay_state.gd` | 1,715 lines / 285 fields |
| `screen_state_controller.gd` | 5,508 physical lines, 10 routes; root access is included in the global 2,200-site validator metric |
| `room_controller.gd` | 2,243 lines |
| `dungeon_layout_generator.gd` | 2,487 lines, ~100 static functions |
| Definitions | 16 authored `.tres` under `resources/definitions/`; validator covers 16/16; composition audit reports 19 editor-able definition surfaces |
| Tests | 149 manifest rows / 147 runnable / 44-path default gate, process-per-test |
| Docs | 105 Markdown files under `docs/` and frozen counts in the authority docs |

Reference commands (current behavior):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_composition.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_test_manifest.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/validate_definitions.ps1   # release and CI preflight
```

### 2.1 Repository-specific implications

Code inspection narrows the implementation route:

- `EnemyDefinition`, `EnemyFactory`, the slime catalog, and the current
  `enemy_preview_workbench.gd` are a usable first vertical slice. The
  workbench is `@tool` and factory-backed, with a catalog-fed Inspector picker,
  starter-definition creation, an inline editable view of the selected typed
  definition, save-to-source support, and a native-size design canvas for shared
  animation states. Definition edits update the preview and unsaved edits block
  selection changes. It disables actor processing and is still a design
  preview, not an isolated interactive workbench or proof of live enemy
  behavior.
- `slime_visual_component.gd` already contains the project's real frame
  vocabulary—idle direction, attack, hurt/shocked, spawn, boss jump/slam, and
  shadow states—while `slime_actor.gd` and `slime_runtime_controller.gd` own
  runtime timing and simulation. The preview adapter must reuse the former and
  keep the latter out of the editor.
- `sprite_frame_library.gd`, `actor_geometry.gd`, and the collision/attack
  guide tools are the correct alignment foundations. Art previews should show
  those guides rather than inventing a second collision model.
- `isometric_room_layer.gd`, `basic_room.tscn`, and the existing puzzle/generated
  map previews are useful spatial-authoring foundations. They should be
  composed into a room/map workbench, not replaced with a code-built level
  editor.
- The repository has several focused `@tool` previews for menus, HUDs, maps,
  and guides, but no Tiny Demons content-authoring `EditorPlugin` or shared
  preview session yet. The existing MCP toolkit is an editor/runtime
  verification aid, not the producer-facing authoring surface.
- `project.godot` uses a small viewport and pixel-scale presentation. Any
  preview camera, animation stepper, imported texture setting, and interactive
  workbench must preserve that native-scale contract.

The Hub preview now contains the first placement-prefab slice: the player is a
`PlacementRoot2D` scene instance whose authored root moves its visual, attack
layer, shadow, guides, stats, and equipment together. The remaining Hub
composition is still embedded in `main.tscn`; extracting the environment,
props, collectables, and actor layers into a canonical `HubRoom` scene remains
the next authoring milestone.

These observations are why M1 is an adapter/dock/session milestone rather than
a rewrite of runtime actors or an attempt to make `main.tscn` continuously
execute in the editor.

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
9. **Separate data, space, presentation, and simulation.** A definition owns
   authorable identity and rules; a scene owns spatial composition; an art
   resource owns visual references and animation metadata; runtime state owns
   transient simulation. No preview or editor convenience may become a hidden
   second owner.
10. **Editor operations are reversible.** Create, duplicate, move, connect,
    and repair actions go through editor undo/redo and resource APIs. Raw file
    writes are reserved for deterministic generated outputs and are never the
    implementation of a normal producer action.
11. **Previews are explicit sessions.** A preview declares its content, seed,
    clock, profile, and isolation level. It never silently uses the producer's
    save data, mutates the active run, or relies on a hidden autoload that is
    absent in a headless check.
12. **Refactors earn an authoring proof.** Moving behavior is not complete when
    the old code is merely split into files. The new owner must be reachable
    through the typed boundary, factory/compiler, preview, and focused
    characterization test described below.

### 3.2 The authoring loop (target)

```powershell
pwsh -File tools/dev.ps1 new variant crimson2   # scaffolds one Slime variant file
# edit resources/definitions/crimson2.tres
pwsh -File tools/dev.ps1 verify                  # schema, duplicate IDs, dangling refs, stale docs
pwsh -File tools/dev.ps1 preview enemy crimson2  # workbench scene or screenshot
pwsh -File tools/dev.ps1 preview hub             # validate the standalone Hub design view
pwsh -File tools/dev.ps1 preview hub -Editor     # open the Hub design view in Godot
pwsh -File tools/dev.ps1 test -Suite content     # contract tests, seconds not minutes
pwsh -File tools/dev.ps1 report                  # prints the authored catalog report
```

A simple variant should need one definition, plus any new assets or scene.
Generated manifests and documentation are refreshed by tooling. Count authored
resources, scenes, assets, generated files, and runtime edits separately.

### 3.3 Production definition of done

The target user is a production teammate working in Godot, not an engineer
editing a coordinator. A content task is complete only when the teammate can
make the change from the editor, preview it without booting a full run, and
validate it before handing it to QA. Text editing of `.tres` files remains a
valid agent and batch workflow, but it must exercise the same typed resources
and validators as the Inspector workflow.

Every authorable content kind must provide all of the following:

1. **An Inspector-facing definition.** The definition has a stable ID, display
   name, schema version, typed exported fields, an owner, and a `validate()`
   method. Nested dictionaries are compatibility data only, never the
   canonical authoring surface.
2. **A discoverable registry.** Adding a definition means adding a resource in
   the documented content directory. No central roster, code constant, scene
   slot, or test edit is required.
3. **A runtime factory or compiler.** The normal game, generated content,
   preview workbench, and headless fixtures use the same materialization path.
4. **A focused preview.** A producer can select one definition and inspect its
   appearance, bounds, authored values, references, and representative runtime
   behavior without navigating through a complete run.
5. **Fail-fast validation.** Missing assets, duplicate IDs, invalid references,
   unsupported combinations, malformed geometry, and incompatible schema
   versions fail `dev.ps1 verify` before the game or export is trusted.
6. **A data-only proof.** A second piece of the same kind can be added with
   data and assets only. The proof must not modify `GameplayState`, a feature
   coordinator, the release gate, or a per-content test.
7. **Stable save and export behavior.** The stable ID is preserved through
   save/load, web export, and content registry discovery. Removing or renaming
   content requires an explicit migration or deprecation record.

The production bar is intentionally stricter than the composition validator.
The validator proves ownership and editor configuration; it does not prove
that a designer can author a complete piece of content successfully.

### 3.4 Authoring contracts by content kind

The following contracts are the direction for the remaining slices.

| Kind | Producer-owned data | Preview and validation proof |
|---|---|---|
| **Enemy** | Identity, behavior archetype, stats, growth, encounter role/weights, drops, art set, sounds, collision and attack profiles | Workbench shows idle/attack/hit/death states, bounds, palette, authored stats, and factory materialization; room-entry proof confirms the registry path |
| **Gear** | Identity, slot, rarity, stat/effect package, uniqueness, transmutation/recipe data, icon, world/drop art, and display metadata | Item card/drop preview, generated-instance preview, save round-trip, effect validation, and registry-driven generation proof |
| **Element / flame** | Identity, palette, matchup relationships, recipes, pickup presentation, audio, and effect references | Palette/effect sample, matchup-table validation, stable-ID round-trip, and a data-only flame proof |
| **Room / level** | Room geometry, tiles/art, sockets, exits, landmarks, encounter groups, rewards, hazards, puzzle rules, and room metadata | Room workbench renders the room and walkable/collision areas, checks sockets and exits, previews encounter/reward composition, and compiles into the live route |
| **Map / route** | Room references, connection policy, depth/milestone rules, route choices, gates, risk/reward metadata, and map presentation | Map workbench validates graph connectivity, reachability, duplicate IDs, gate policy, authored/procedural boundaries, and representative traversal |
| **Artwork / presentation** | Typed references to source textures or frame sets, animation states, frame size, anchors, shadow, palette policy, icon/drop variants, and optional effect/audio companions | Asset validation checks existence, import settings, dimensions, required states, and frame compatibility; an art workbench shows the result at native pixel scale |

Reusable behavior remains code-owned. Designers choose an existing behavior
archetype and tune its exposed data; introducing a genuinely new behavior is an
engineering task that adds a reusable archetype to the authoring contract. This
keeps the Inspector powerful without turning production data into arbitrary
scripts or unsafe runtime reflection.

### 3.5 Artwork and asset rules

Artwork is part of the authoring system, not a final polish pass. A producer
must be able to replace an enemy, gear icon, room tile, landmark, or effect
asset by changing a resource reference or replacing an asset that has the same
declared contract. Runtime scripts must not require a new hardcoded `load()`
path for an ordinary art replacement.

The asset track therefore needs:

- a typed art-set resource or equivalent asset manifest for each visual family;
- explicit state names such as idle, move, attack, hurt, death, spawn, shadow,
  boss, icon, and drop where the content kind needs them;
- declared frame dimensions, anchor/foot position, collision/attack alignment,
  palette policy, native display scale, and optional fallback behavior;
- import validation for missing files, wrong dimensions, missing required states,
  unexpected filtering, and references outside the shipped asset roots;
- preview scenes that show the art with the real material, palette, geometry,
  occlusion, and pixel-scale settings; and
- a documented source-art boundary: production-ready imported assets live under
  `assets/`, while `Artwork/`, `Mockups/`, and `screenshots/` remain source or
  reference material unless deliberately promoted through the import workflow.

Changing art must not silently change collision, save identity, encounter
identity, or gameplay balance. Those contracts stay in typed data and are
validated independently from the asset file.

### 3.6 Production roles and handoff

The authoring system should make ownership obvious:

- **Designers** edit definitions, tuning, encounters, rewards, rooms, maps, and
  route policy in the Inspector or approved text workflow.
- **Artists** add or replace imported assets and update the relevant art-set
  resource; they do not need to edit runtime scripts or central catalogs.
- **Engineers** add reusable behavior archetypes, factories, validators,
  workbenches, import contracts, and migrations.
- **Agents** use `tools/dev.ps1` to scaffold, verify, preview, report, and run
  focused contract tests; they must be able to discover the owner and command
  from `README.md` and `CONTENT_AUTHORING.md`.
- **QA** receives a deterministic preview, validation report, stable-ID change
  summary, and focused smoke result before running the full release gate.

Every content change should be reviewable as three separate questions:

1. Does the definition describe the intended game behavior?
2. Does the asset contract render and align correctly at native pixel scale?
3. Does the runtime consume the definition through the registry/factory path?

Do not hide an unresolved answer by marking the content "implemented". Use the
status language in `KNOWN_ISSUES.md` and record the missing evidence.

### 3.7 Refactor-to-authoring acceptance rule

The refactor and authoring tracks are one sequence, not two independent
projects. For every behavior or data seam that is moved, the change is
accepted only when the following chain is visible in code and evidence:

```text
typed owner/boundary
      -> runtime factory or compiler
      -> design preview and/or interactive workbench
      -> focused contract test
      -> documented producer workflow
```

The implementation checklist for a moved seam is:

- identify the narrowest feature owner and replace untyped coordinator access
  with a typed method, command, result, or signal;
- add or retain a characterization test before changing behavior;
- make the authoritative definition or scene feed the normal runtime path;
- expose the same path to a preview, with a visible error when a dependency is
  missing rather than a silent fallback;
- add editor configuration warnings or validator output at the point where a
  producer can fix the problem;
- prove that the worked example needs no central runtime edit, per-content test
  edit, or release-gate count change; and
- remove, deprecate, or explicitly label the former path after its last
  consumer migrates.

The composition scorecard, `root.call/get/set` count, or a passing static
validator is supporting evidence only. The acceptance artifact is a producer
workflow plus runtime and preview proof for the changed seam.

### 3.8 Preview modes and live-editor architecture

The desired "alive" editor experience is delivered by three cooperating modes,
not by making the whole game `@tool`:

| Mode | Purpose | Allowed behavior | Source of truth |
|---|---|---|---|
| **Design preview** | See an authored enemy, item, art set, room, or effect animate while editing | `@tool` presentation adapter, deterministic preview clock, geometry guides, state/animation controls, no gameplay services, no save mutation | Typed definition/art resource and preview adapter |
| **Interactive workbench** | Walk, fight, inspect, or traverse the selected content | Isolated preview scene or embedded play window, real factory/compiler, explicit seed/loadout, temporary profile, normal input and simulation | Same runtime factory/compiler as the game |
| **Full playtest** | Verify integration, progression, persistence, transitions, and performance | Main scene and normal autoloads only; no preview shortcuts | Production runtime |

The first implementation should introduce these conceptual services, with names
allowed to change during the slice:

- `ContentRegistry` discovers typed resources and exposes stable IDs,
  validation, dependency information, and revision state;
- `ContentPreviewService` resolves a selected ID and builds a preview model
  without making the editor dock responsible for gameplay assembly;
- `PreviewClock` advances animation and presentation at a deterministic rate,
  with pause, step, loop, and state selection controls;
- `PreviewSession` owns seed, temporary profile, player loadout, arrival
  socket, input mode, and cleanup; it is disposable and never the live save;
- `PreviewHost` is a small scene that embeds the selected actor/item/room/map
  and exposes guides, resolved references, and validation state; and
- the authoring `EditorPlugin` supplies browse/create/duplicate/preview/
  validate/refresh actions, delegates field edits to Inspector or scenes, and
  uses editor undo/redo for mutations.

Interactive sessions must isolate storage at the process boundary. The current
`ProfileSaveService` uses static `user://` save paths, and browser profiles use
shared local storage; changing a slot or temporarily swapping a save path inside
the editor process is not isolation. On desktop, the workbench launches a
separate game process with a unique temporary `--user-data-dir`, passes a
versioned preview-session payload (content kind/ID, seed, loadout, arrival
socket, and requested mode), tracks the child process, and removes the temporary
directory after the process exits. Closing the workbench terminates only its
own preview process and then cleans up. Full-game playtest continues to use the
normal project profile. The editor-only interactive session does not run inside
the exported web build; web gameplay is verified through the ordinary browser
playtest and its existing save contract.

Treat this as one game-development workbench with content-kind adapters, not a
separate one-off tool for each feature. The dock owns discovery, selection,
validation results, source navigation, preview launch, and refresh. Enemy, item,
effect, and room adapters provide their typed definitions, factory/compiler,
scene handles, validation rules, and design-preview presentation. A new kind
should add an adapter and focused workflow without copying the dock, registry,
preview-session, or lifecycle logic. Spatial kinds keep using Godot's scene and
2D editors; the workbench coordinates those editors instead of replacing them
with a bespoke level editor.

The delivery order follows the dependency chain: M1 establishes the shared
registry, validation, revision/refresh, dock, and preview-session contracts on
the enemy proof; M2 and M3 add enemy and gear/element adapters; M4 adds room
scene and map adapters on the same services. M1 does not need to implement every
future content kind, but its service boundaries and stable-ID rules must not
assume that every entry is a flat resource or that every preview is a sprite.

The first dock should remain deliberately small: content kind and ID search,
validation summary, Create/Duplicate, Open Source, Preview Design, Play
Interactive, Refresh, and a resolved-reference list. A custom editor for every
field or a bespoke full-screen level editor is not a prerequisite. Inspector
groups, typed resource pickers, scene handles, configuration warnings, and
focused workbenches give producers the majority of the value with much less
editor-only code to maintain.

Animation has a similarly explicit boundary. The current slime presentation
already owns state-specific frame arrays and custom `Sprite2D` frame selection.
The first preview adapter should reuse that frame library and visual component
through a presentation-only interface, so the editor becomes animated without
moving combat timing into editor code. `AnimatedSprite2D` is appropriate for
simple named frame playback; `AnimationPlayer` is appropriate for multi-property
timelines or effects. Neither is a reason to rewrite the existing runtime
animation contract. Any new animation system must preserve shared actor
geometry, attack timing, palette resolution, and pixel-scale rules.

`@tool` scripts must stay narrow and defensive: check
`Engine.is_editor_hint()`, avoid starting timers or gameplay loops, avoid
mutating unrelated nodes, and make rebuilds idempotent. Runtime controllers such
as `gameplay.gd`, `slime_runtime_controller.gd`, room orchestration, save
services, and global audio must not be made editor-live merely to animate a
preview. The interactive workbench is the safe place for real simulation.

## 4. Workstreams

The slice numbers retain their existing references; the delivery order below
governs execution. All new editor features described here are planned.

| Milestone | Scope and responsible feature owners | Required exit evidence |
|---|---|---|
| M0 — Reliable acceptance baseline | Enemy/room owners; Slice 1 | Diagnose the recorded room-entry failure, characterize the intended contract, pass focused checks, and classify the supervised curated gate |
| M1 — Shared authoring and preview foundation | Authoring tooling, presentation, and verification owners; Slices 1 and 5 | The editor dock, typed Inspector workflow, design-time animated preview, isolated interactive workbench, shared validators, and manifest lifecycle proof work for one enemy |
| M2 — Complete enemy authoring | Enemy factory, visual, and actor geometry owners; Slice 1 and enemy artwork | Add a variant and replace its art in the editor; design preview and normal room use the same definition; exported-build and save evidence |
| M3 — Gear and elements | Item/equipment, Chroma, and presentation owners; Slice 2 and gear/element artwork | Add gear and a flame through editor workflows; card/drop/equipment previews, round-trip checks, and art replacement |
| M4 — Visual room and map authoring | Room, graph, layout compiler, and room presentation owners; Slice 3 and room artwork | Place room content visually, connect rooms, play the selected room, and traverse the exported route |
| M5 — Remaining presentation and handoff | Menu/effects, verification, and documentation owners; Slices 4–6 | Menu/effect asset workflows, remaining verification work, generated documentation, and independent production usability exercise |

M1's shared editor and preview foundation precedes bulk content migration.
Artwork ships with its owning milestone. Independent work may proceed in
parallel, but each milestone requires its prerequisites and evidence before
acceptance. Record a responsible engineer and production reviewer when
assigning each milestone. The current enemy design preview is an M0/M1
baseline, not the final live-editor experience.

Execution sequencing decision (2026-09-29): after M1's preview and lifecycle
acceptance, advance the M4 runtime prefab foundation before completing the
broader M2/M3 content migrations. The initial room slice is the scene host,
stable marker/socket contract, and room-state parity proof; it does not claim
that the room/map editor milestone is complete. This pulls forward the runtime
seam needed to replace the shared room shell while keeping M2/M3 and the full
room authoring workflow in the overall production exit gates.

### Editor interaction and content lifecycle (M1 foundation)

- [ ] Provide discoverable Create, Duplicate, Preview, Validate, and Refresh
  actions through native editor workflows and a small authoring dock where
  needed. Share domain operations and validators with the CLI; producers must
  not need a terminal for ordinary authoring.
- [ ] Use typed resource pickers, field descriptions, units/ranges, and grouped
  settings. Errors identify the content ID, file, and field or scene node and
  let the producer navigate to the problem.
- [ ] Support undo/redo for authoring-tool edits, visible unsaved changes, and
  explicit shared-resource versus local-copy choices. Duplicate assigns a new
  stable ID; moving a file preserves identity.
- [x] Wire the current enemy/item registries and previews to a coalesced editor
  refresh after resource saves, reimports, or filesystem changes, and invalidate
  their definition caches without restarting Godot.
- [ ] Show preview revision and stale/error state; label unsaved previews and
  prove that build validation consumes saved content.
- [x] Add the standalone `scenes/authoring/previews/hub_world_preview.tscn` design preview. It
  reuses the authored world from `main.tscn`, exposes the Hub map, actors, and
  stone accents, hides dungeon/HUD clutter by default, and steps existing fire,
  NPC, and player idle frames. The player defaults to the Water element and
  uses the runtime palette material/eye correction; the player is a
  `PlacementRoot2D` prefab instance, so producers drag one actor anchor and move
  its artwork, attack layer, guides, and shadow together through the editable
  `Main` instance.
  `hub_world_preview_scene_smoke.gd` proves this visual setup without booting a
  run; the interactive workbench remains open.
- [x] Promote the Hub's existing spatial boundaries into authoring roots. The
  `Map` root is the Environment layer, `Actors/Props` groups the fire and
  collectable chest, and `Actors/Characters` groups the NPC and player
  placements. Each root carries a stable placement ID and category, so moving
  a layer preserves child-local offsets while runtime node ownership remains
  explicit through `GameplayState`.
- [x] Add the first project-owned authoring dock and placement lifecycle slice.
  It discovers the same `PlacementRoot2D` contract used by focused smoke tests,
  groups roots by category, selects the real scene node, opens the Hub design
  preview, and refreshes on scene changes. The dock now creates an empty
  placement or the PlayerPlacement prefab, duplicates a selected placement
  subtree with undoable fresh stable IDs, and validates placement IDs/layers.
  The dock now also selects registered enemies and opens their pixel-art design
  preview or launches/stops an isolated interactive enemy session. Generic typed
  gear, level, and artwork operations remain open for later slices.
- [x] Validate every distinct embedded and standalone enemy definition source
  before runtime lookup deduplicates stable IDs. Conflicts report the duplicate
  ID and both paths through `SlimeVariantCatalogData.validate()`, which is also
  consumed by the definition preflight. The dock exposes the same contract as
  `Validate Enemies`; placement validation is labelled `Validate Scene`. Runtime
  validation and editor acceptance remain open under the current Godot launch
  restriction.
- [x] Generate deterministic all-resource and kind-specific resource-reference
  manifests from `resources/definitions/**` and the future `resources/content/**` root. The
  authoring dock's save/reimport and Refresh paths and `tools/dev.ps1 manifest
  refresh` share one generator. The definition validator consumes the resource
  references; its freshness check does not rewrite the manifest, so the existing
  definition preflight rejects stale output in CI. Dock refresh invalidates the
  enemy and item definition caches after regenerating the typed manifests.
- [x] Migrate enemy and item runtime catalogs to consume typed resources from
  kind-specific generated manifests. Each catalog preloads only its own
  resource references into exported builds; editor loads replace the cached
  kind manifest after refresh. Both catalogs discover typed entries across
  `resources/definitions/` and `resources/content/` and validate duplicate IDs
  across those roots. The all-resource manifest remains the preflight/freshness
  index.
- [ ] Prove exported web/mobile discovery after adding, moving, or deleting a
  definition; move resources only with reference/UID and stable-ID checks.
- [ ] Show references before deletion or stable-ID changes. Require an explicit
  migration/deprecation mapping for shipped IDs and test old-save fixtures.
  Missing required content blocks validation/export; optional fallbacks must
  be declared and reported, never silently replace saved identities.
- [ ] Prove create, edit, duplicate, move, delete, undo/redo, reimport, and editor
  restart behavior. From a clean checkout, export a newly added entry and
  resolve/play it in the build; local registry discovery alone is insufficient.

### Visual level authoring and source ownership (M4)

Use native scene and 2D editing for spatial work, with a focused map connection
view for route topology. The planned authority split is:

| Authoritative surface | Owns | Derived consumers |
|---|---|---|
| Room prefab scene | Tile/geometry placement, stable socket markers, landmark/hazard transforms, spawn markers referencing definitions | Room compiler, geometry validation, room preview, runtime |
| `RoomPrefabDefinition` | Stable prefab ID, room-scene reference, marker contract, supported capabilities, reusable presentation defaults | Registry and room factory/compiler |
| Typed map definition | Room-instance IDs, prefab references, per-instance encounter/reward/puzzle policy, connections by stable socket ID, route/milestone policy | Graph view, validator, runtime graph |
| Art resource | Textures/frames, visual anchors, palette/material policy | Preview and runtime presentation |
| Shared actor geometry profile | Collision, targeting, and attack bounds consumed through `actor_geometry.gd` | Combat, movement, guides, and alignment checks |

Compiled dictionaries and generated layouts are outputs, not a second editable
copy. Procedural policy remains an explicit input; preview uses a recorded seed
and does not overwrite an authored scene. Art previews overlay authoritative
geometry; art resources must not duplicate collision or attack shapes.

#### Runtime room-prefab seam and staged proof

Runtime status (2026-09-30): the generic room-prefab mount is wired through
ordinary route entry and active-run restore. `RoomPrefabFactory` registers
typed `basic`, `orb`, `treasure`, and `boss` definitions. The route selects
`orb` for Orb rooms, `treasure` for Treasure rooms, and `boss` for boss rooms;
other current roles keep the basic shell. Definitions declare supported
capabilities and required stable marker IDs. Mount validation checks marker
uniqueness, marker type, required sockets, and the capability required by the
gameplay room role. The Treasure Room's `TREASURE_CHEST` marker positions the
persistent chest actor, while the Orb owner resolves `ORB_CENTER` from the
active prefab. Editor-only preview sprites stay visible in the authored scene
and are hidden on runtime mount.

`ORB_CENTER` is the **single source** for the Orb's position: the runtime orb
and the editor preview sprite both sit exactly on it, and the walkable-bounds
centre is only a fallback for room scenes without the marker. There is no
code-side visual offset — a 2026-09-06 change had added
`ORB_ROOM_VISUAL_OFFSET := Vector2(0, -7)`, which floated the Orb ~11 px above
the floor and was hand-mirrored into the preview sprite, silently failing the
"EntryOrb shares the authored center marker" gate assertion. To move the Orb,
move the marker and keep the preview sprite on it.

Room prefab instances are reused by `prefab_id`, not by `room_id`, because most
rooms share the generic shell; keying reuse on the room ID re-instantiated the
same scene on every door crossing. A reuse still rebinds sockets, floor and
socket references, and the accent geometry root — only the instantiate and the
free are skipped.

`RoomPrefabHost` owns the mounted scene; `RoomController` mounts it before room
activation, then rebinds floor, socket, accent, and geometry consumers. The old
shell in `main.tscn` remains a fallback until a mount succeeds and is hidden
after success. `DungeonGraph.RoomRecord` carries optional `prefab_id`, and
snapshots persist the resolved room-ID-to-prefab-ID assignments. Legacy active
run snapshots that assigned `basic` to every role are migrated through the
current explicit room-type compatibility table.

This is source-wired room variation, not full room-prefab parity. Orb and
treasure interactions still use their existing runtime owners, four socket IDs
remain the legacy edge-kind names, and the boss geometry copy adapter remains
for debug/prewarm paths. The factory remains a code-registered definition list.
No Godot runtime, traversal, recovery, or exported-build acceptance has been
run for this slice. The current `RoomDefinition` remains shared encounter/
traffic tuning; do not overload it with prefab identity.

#### Live transition parity contract (source audit, 2026-09-29)

`GameplayBootstrap` creates `RoomPrefabHost` under the persistent `Map` and
configures the geometry service against the shell until the first room mounts.
`_ensure_current_room_layout()` mounts the current room before geometry,
walkability, portals, spawn constraints, puzzle/orb presentation, tint, accents,
or activation are built. A connected transition saves the outgoing state and
mounts its destination before changing current-room metadata; after entry,
`_ensure_current_room_layout()` reuses that mount and applies the saved state.
When the host replaces a scene, `RoomController` refreshes its socket index and
rebinds floor, geometry, and accent consumers before gameplay resumes. This
sequence is source-wired but still needs traversal and recovery acceptance.

Today `main.tscn` owns the player and attack/shadow visuals, the enemy pool,
chest, Rest Fire, NPC, and UI beside its shared `Map`. Keep the player, enemy
pool, HUD, run state, and stateful service actors owned by the gameplay root.
Room scenes supply reusable geometry and stable placement markers; room owners
place or configure the chest, fire, NPC, puzzle props, and enemies from those
markers, then reapply saved state for the current room instance. A prefab scene
must not become the save record for a run.

`DungeonSocket.socket_id()` currently returns the socket-kind enum name, and
graph connections store those four names. The runtime socket also owns edge
placement, paired-edge convention, trigger polygon, closed-door blockers,
arrival offset, and a player arrival marker. Introduce an authored stable
socket ID separately from edge kind and keep a compatibility mapping for the
existing four connection names. Rebind the host's socket index on every mount;
do not retain node references from the scene being released.

`DungeonGraph.RoomRecord` stores a room-instance ID, gameplay `room_type`, and
optional `prefab_id`. `RoomController.room_states` is keyed by room-instance ID
and carries encounter, clear, chest, pickup, and puzzle progress. Active-run
snapshots now persist the resolved room-ID-to-prefab-ID mapping alongside the
layout ID and dungeon seed, current room ID/type, arrival socket, and room
states. Keep three identities separate: room instance ID, gameplay
role/capabilities, and reusable prefab ID. `RoomSpec` can name a prefab
directly; legacy layouts resolve through the explicit room-type mapping to the
`basic`, `orb`, `treasure`, or `boss` definition. Older snapshots that recorded
the former all-basic assignment are migrated by the same role mapping. Existing
type aliases such as FIRE/REST, CLOAKED/NPC, and BOSS/DOWNSTAIRS remain behavior
aliases; visual variation must not create extra gameplay types.

`orb_room.tscn` and `treasure_room.tscn` inherit the generic shell and define
their presentation anchors. The Orb interaction and map palette remain owned
by runtime state. `boss_room.tscn` owns the expanded floor, socket spawn
positions, and return guides; the existing geometry controller still owns the
large camera and keeps the old copy adapter for debug/prewarm compatibility.
Treat these as separate runtime behavior/presentation contracts while parity
acceptance is open.

The room-prefab slice must establish this runtime chain:

```text
map/route entry (stable room instance ID, prefab ID, seed)
        -> RoomPrefabDefinition
        -> RoomPrefabFactory loads the authored PackedScene
        -> active RoomPrefabHost binds scene sockets and definition-backed markers
        -> existing encounter/puzzle/reward owners activate the room
        -> RoomState saves transient progress separately from the scene
```

Keep route topology and room instances distinct. The map owns connections and
stable socket IDs and per-instance policy; a prefab scene owns reusable spatial
composition; the definition owns prefab identity and marker capabilities; a
room-state record owns opened chests, cleared encounters, puzzle progress, and
other run changes. Save IDs and generated seeds, not mutable scene instances.
The normal game and the interactive room workbench must call the same
factory/compiler and marker binding path. New prefab IDs must resolve through a
definition and missing definitions or required markers must fail activation.
Legacy room roles use the explicit compatibility mapping during migration;
never add an implicit catch-all fallback to the basic room.

M4 should stage the code migration before promising a general-purpose room
builder:

1. Characterize and pin the current transition sequence, geometry/walkability
   construction, closed-door and gate behavior, enemy spawn constraints,
   checkpoint/re-entry state, boss camera, and authored pixel output. Define
   stable IDs for sockets, spawn points, landmarks, and hazards; validate
   duplicate/missing references before play.
2. Add `RoomPrefabDefinition` without changing the existing global
   `RoomDefinition` tuning owner. Register and validate one prefab and prove a
   deterministic design preview resolves its scene, markers, and guides.
3. [x] Add the first `RoomPrefabHost`/`RoomPrefabFactory` seam and mount the
   generic room through normal route entry and active-run restore. This proves
   wiring only; behavioral parity is pending focused traversal, revisit,
   recovery, and exported-build checks. Extend the seam to swap the active
   spatial scene while
   preserving the existing `GameplayState`, actor ownership, frame schedule,
   route state, and active-run recovery. Return a typed mount result and rebuild
   socket, walkability, spawn, and presentation bindings before room activation.
   The generic combat room is currently mounted through the ordinary route
   path; acceptance remains open until runtime and export proof pass.
4. [x] Add a treasure-room prefab with an authored `TREASURE_CHEST` marker and
   bind the persistent chest actor to it. [ ] Prove combat clear, reward claim,
   departure, revisit, and run recovery while the existing room services keep
   owning encounter and chest state.
5. [x] Register the Orb scene with an `ORB_CENTER` marker and resolve that
   marker through the prefab host. Register the boss prefab with its expanded
   floor and authored return guides; keep Orb's global palette/map behavior and
   the boss camera contract in their existing runtime owners. [ ] Retire the
   boss-copy adapter after parity proof for runtime entry and prewarm.
6. Extend the workbench to create a room from a template, edit it in the native
   scene editor, run marker/connection validation, preview it with a fixed
   seed, and play it in an isolated session. Undo/redo and save/reopen must
   preserve placement IDs and socket connections.

The first loaded-room acceptance should prove two distinct room prefabs, two
stable room-instance IDs, a traversable connection between named sockets,
return/re-entry with room state restored, and the same prefab resolution in an
exported build. This is the point where authored room prefabs become production
content rather than editor-only templates.

- [ ] Create a room from a template; paint/place geometry; drag definition-backed
  enemy/spawn and landmark markers into the viewport; position and name sockets.
- [ ] Connect room sockets in the map view and edit gates, encounters, rewards,
  and route choices with resource pickers. Invalid connections highlight both
  endpoints and explain the violated contract.
- [ ] Provide Play Selected Room with explicit seed, player loadout, and arrival
  socket. Use isolated temporary run/profile state and the normal runtime
  compiler/factory path; preview must not alter a producer's saved progression.
- [ ] Prove adding and connecting a second room with viewport operations,
  undo/redo, save/reopen, validation, and traversal without code or raw-array edits.

### Asset lifecycle, cache, and performance contract (M1–M5)

The editor workflow must respect Godot's asset lifecycle instead of treating
the project folder as an unmanaged database. The source/import boundary is:

```text
source art / authored scene / typed resource
        -> Godot import and UID tracking
        -> imported runtime resource
        -> art-set or scene reference
        -> preview and runtime materialization
```

Rules for this boundary:

- Keep production source and reference material distinguishable from shipped
  imported assets. `assets/` is the runtime-facing root; source-only
  `Artwork/`, `Mockups/`, and `screenshots/` do not become runtime dependencies
  accidentally.
- Load imported assets through Godot resources and `ResourceLoader`. Do not
  use `FileAccess` to reach imported runtime files, and do not hand-edit
  `.import` metadata. Commit the required `.import`/UID sidecars and keep
  generated `.godot` state out of source control according to the repository's
  ignore policy.
- Create, rename, move, and delete resources through the editor/plugin or a
  deliberately documented migration tool. Before deletion or stable-ID change,
  show inbound references and write a deprecation/migration record for shipped
  IDs.
- Give every art set a stable content-facing ID separate from its file path.
  A file move or replacement therefore does not change a save ID, encounter
  ID, item ID, or room ID.
- Treat a changed source texture, imported setting, definition, or scene as a
  revision event. The registry and preview service invalidate dependent caches
  and expose a stale/reimporting/error state instead of displaying old data as
  if it were current.

Preview performance is an authoring requirement. M1 establishes a baseline on a
developer desktop and the Samsung A17 profile already used by the performance
plan; later changes must report the delta. At minimum record:

| Measurement | Design-preview target | Interactive/full-game evidence |
|---|---|---|
| Select an already-imported definition | Warm rebuild should feel immediate; record a numeric baseline and regression threshold | Not applicable |
| Registry refresh and validation | Bounded, deterministic, and independent of a full game boot | Clean-checkout/export discovery proof |
| Preview startup/reimport | Cold and warm timings, plus error/recovery timing | Exported build resolves the same assets |
| Memory and resource count | Selected-content scope only; no hidden full-run world | Texture, material, frame, and node counts on representative scenes |
| Animation/render loop | Stable stepping and pause; no gameplay process loop in the editor | Frame-time, draw-call, palette, particle, occlusion, and transition measurements on target hardware |

The implementation should make the common case cheap by selecting one content
entry at a time, caching imported resources and frame metadata, rebuilding only
dirty dependents, and disabling audio/particles/full encounter simulation in the
design preview by default. A producer can enable those features in the
interactive workbench. Never solve a preview delay by silently lowering the
runtime quality settings or by creating one unique material/texture copy per
previewed entity.

Every performance claim needs a reproducible scenario, seed, content ID,
device/profile, cold/warm state, and capture date. If a flexible authoring
feature exceeds the agreed budget, it is a documented tradeoff with an owner,
not an invisible regression.

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
workbench, and standalone variant implementation landed on 2026-09-20.
The 2026-09-22 follow-up established the missing run-start palette contract in
the direct room-entry fixture, preserving the assertion while matching the
production run flow. `dev.ps1 test -Suite content` now passes all 7 checks,
including normal-room `guard_slime` materialization. The supervised curated
gate was attempted but remains open on unrelated UI smoke failures and scene
timeouts; that result is classified separately from enemy authoring. The
shared registry/editor foundation also remains to be implemented.

Work items:

- [ ] Add `ContentDefinition` base (`id`, `display_name`, `validate()`,
  `schema_version`) and `ContentRegistry` with duplicate-ID detection and the
  explicit required-content/fallback rules in the M1 lifecycle contract.
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
- [x] Add the data-selected healer slime support behavior: target and rank
  filtering, interruption, cast visuals/VFX, preview state, and a focused
  family/factory/encounter fixture. The healer remains `type_id = slime`.
- [x] Make `EnemyFactory` the materialization path. The bootstrap now creates
  a capacity pool through the factory, and normal room configuration applies
  selected definitions to those actors; scene-authored enemy slots are no
  longer the content roster.
- [x] Add `scenes/authoring/previews/enemy_preview_workbench.tscn` and a headless preview driver;
  it materializes any registry enemy through `EnemyFactory` and shows the
  runtime collision/attack geometry without booting a run.
- [ ] Complete acceptance of the M1 design-preview adapter. The current
  workbench selects authored IDs, creates a starter definition, edits all
  current `EnemyDefinition` fields inline, saves embedded or standalone
  resources, and steps idle, move, attack, shocked, spawn, and boss jump/slam
  states through the shared visual frame contract. Family geometry profiles own
  collision shapes, body hitboxes, collision guides, and left/right attack
  guides; the factory applies the same family geometry to every variant's
  preview and runtime actor.
  The workbench has independent guide toggles, in-preview vertex and rectangle
  editing, reset, and geometry undo/redo. Verify catalog refresh,
  saved-resource lifecycle, geometry interaction, death-effect playback, and
  visible output in the editor before closing acceptance. The workbench now
  includes a deterministic `Preview Death Effect` action that reuses the
  runtime death palette mapping and default effects tuning; editor acceptance
  is still open.
- [ ] Accept the isolated interactive enemy workbench and authoring dock
  actions. The source now launches a separate desktop game process with a
  unique temporary `--user-data-dir` and a schema-versioned `PreviewSession`
  containing the selected enemy ID, deterministic seed, starter loadout, and
  automatic boss-room route. The game rejects unsupported payloads and uses its
  existing factory-backed encounter path. The dock can stop the child process,
  and its session directory is removed after the child exits. The new payload
  contract smoke is registered but unverified; confirm child exit, cleanup, and
  unchanged active profile/settings from the connected editor before closing
  acceptance. `PreviewSession` reserves content kind and arrival socket fields
  so the future room/map workbench can extend the contract instead of inventing
  a separate session format.
- [x] Complete acceptance of the standalone `ember_guard.tres` definition through the
  registry-driven preview, round-trip, encounter, boss, and room-entry checks
  without a per-variant test edit.
- [ ] Separate enemy-family authoring from variant authoring. Skeleton is the
  first non-Slime family proof, with a standalone definition, dedicated actor
  route, authored idle/walk/attack/recovery animations, and a stub bone throw. The
  workbench still needs distinct `Create Enemy` and `Create Variant` flows,
  family-level authoring, and a command path that scaffolds the family without
  an implicit Slime default.

Current proof: `crimson` remains the embedded migration proof, while
`ember_guard.tres` is discovered as a standalone authored resource, resolved
from the registry, materialized by `EnemyFactory`, previewed without booting a
run, and exercised by the registry-driven definition, round-trip, encounter,
boss, and room-entry checks. Normal-room acceptance is now closed; the
curated gate is the remaining M0 release-surface evidence.

Remaining acceptance bar: keep the focused content checks green, resolve or
explicitly accept the unrelated curated-gate failures, keep the fresh variant
at one definition file with zero per-variant runtime or test edits, and confirm
that it spawns through the factory in a normal room without a scene-authored
roster slot.

### Slice 2 — Items and elements

Goal: the two highest-volume content kinds become data-only.

Current proof slice (2026-09-21): standalone `ItemDefinition` resources under
`resources/definitions/items/` are discovered by `ItemCatalogData`, converted at
the compatibility boundary, included in live generation, validated, reported,
and covered by a registry-driven stable-ID round-trip smoke. `cinder_blade.tres`
is the named proof item. The first item design-preview workbench now uses the
same catalog for typed-resource editing, live-item browsing, card/drop/instance/
effect views, and the `preview item` command. Retired expansion item and
transmutation records have been purged; saved profiles migrate by dropping those
retired IDs while preserving Demon Cloak as a typed special-acquisition item.
The live baseline/set dictionaries and element/flame tables remain in migration;
item artwork remains slot-level until `visual_id` becomes authoritative.

Work items:

- [ ] First migrate the 12 live Plain/Basic baseline definitions and their
  metadata from dictionaries to typed `ItemDefinition` resources. Capture the
  effective merged record, including metadata overlays and catalog defaults,
  rather than copying only the raw base dictionary. Keep the existing set
  tables and synthesis in place for this slice. Establish a catalog-owned/
  read-only source boundary before placing them: the current
  `resources/definitions/items/` discovery root feeds the editable standalone
  workflow, and the workbench treats any resolved `ItemDefinition` as editable.
- [ ] Preserve `ItemCatalog`'s dictionary projection and stable IDs while
  changing the baseline source. Include typed and legacy records in validation
  and save collision checks, and preserve the workbench's preview-only behavior
  for catalog-owned items after they become typed resources. The ownership rule
  must be explicit in data or discovery; path placement alone is insufficient
  because the generated item manifest can discover typed resources outside the
  standalone root too.
- [ ] In a later atomic set slice, collapse the remaining registries and move
  `SET_IDS` plus set synthesis rules out of `item_catalog.gd`. Current set IDs
  are synthesized before dictionary fallback, while validation and save collision
  checks omit synthesized IDs; a typed `swift_weapon` would otherwise be
  shadowed without a duplicate-ID error.
- [x] Replace count-pinned legacy-catalogue expectations with live-registry
  invariants, retired-ID checks, and focused current-item fixtures.
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
- [x] Add the first ItemDefinition design-preview workbench. It provides
  `preview item <id>`, typed-resource editing and save/create actions, plus
  Card/Drop/Instance/Effects views backed by `ItemCatalog`; only current playable
  IDs appear, catalog-owned baselines/sets remain read-only, and item art remains
  slot-level.
- [ ] Finish item-specific visual ownership and replacement through `visual_id`,
  then add the element palette/effect preview and complete the item/element
  preview acceptance checks.
- [ ] Include `element_catalog.tres` and `palette_library.tres` in the
  validator with real schema checks.

Acceptance bar: add one weapon and one flame with data only; save round-trip
and `dev.ps1 verify` pass; no test edits.

Baseline-migration checkpoint: all 12 effective records and their live-ID order
remain unchanged; starter and source eligibility, generation, and stable-ID
save/load behavior remain intact; synthesized sets still resolve; malformed or
colliding records fail validation; and migrated catalog-owned entries remain
preview-only in the workbench.

### Slice 3 — Rooms, maps, and generation policy

Goal: level and route content stops requiring controller knowledge.

Work items:

- [ ] Promote `RoomSpec` / `ConnectionSpec` (`dungeon_layout_definition.gd`)
  to typed resources and make the authored run/plan loaders consume them;
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
runtime. Complete the M4 visual workflow and source-ownership proof above;
Inspector arrays and a read-only preview alone do not satisfy this milestone.

### Cross-cutting track — Artwork and presentation assets

Goal: an artist or designer can replace or add ordinary game artwork from the
editor without editing runtime scripts, while the pixel, geometry, and
performance contracts remain explicit.

This track is deliberately cross-cutting rather than a final polish task. An
enemy, item, room, map landmark, menu presenter, and effect all need an asset
reference contract before their content slice can be called production-ready.

Work items:

- [ ] Inventory ordinary runtime art loads and replace magic path families with
  typed art-set resources or a checked-in asset manifest. Hardcoded paths may
  remain only for engine-owned fallback art or an explicitly documented
  presentation-library contract.
- [ ] Define the required visual states for each kind: actor idle/move/attack,
  hurt/death/spawn, shadow/boss variants, item icon/drop, room tile/landmark,
  menu icon, and effect frames where applicable.
- [ ] Store frame dimensions, native display scale, visual anchors,
  shadow, palette policy, and fallback behavior in typed art data. Validate
  alignment against the shared actor geometry profile; do not copy its bounds.
- [ ] Add import validation for missing files, wrong dimensions, missing states,
  invalid filtering, unexpected texture roots, duplicate asset IDs, and
  unsupported palette/material combinations.
- [ ] Add an art workbench that previews each asset set at native pixel scale
  with the real material, palette, occlusion, collision guides, and animation
  states. The workbench must report the content ID and every resolved asset.
- [ ] Add a representative replacement proof: swap an enemy art set, a gear
  icon/drop set, and a room landmark using only editor data and assets; verify
  that save IDs, collision geometry, and gameplay behavior remain unchanged.
- [ ] Profile imported texture count, palette warmup, preview startup, and
  repeated room transitions after the asset contract is in place. Authoring
  freedom must not silently create a per-entity texture or material explosion.

Acceptance bar: a production artist can replace the art for one existing enemy,
one gear item, and one room landmark by changing asset resources or imported
files only; the workbench and `dev.ps1 verify` catch a deliberately missing or
mis-sized asset; the focused visual/geometry checks pass; and no runtime script,
central roster, save ID, or release-gate edit is required.

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

Deliver the shared-process pure/content suite, CI wiring, and editor-safe
validation in M1. Extend coverage with each content milestone; remaining runner
cleanup can finish in M5. Editor/MCP diagnostics and probes remain distinct from
standalone `tests/*.gd` execution under the contributor safety rules.

Work items:

- [ ] Add `tests/suites/fast_suite.gd` that runs pure/domain tests in one Godot
  process; keep process-per-test for scene and main-scene tests.
- [ ] Shrink the default gate to a documented, budgeted path list; record the
  expected runtime in `README.md`.
- [ ] Make `state=environment` and `state=unverified` rows fail loudly instead
  of silently poisoning a green gate; separate "environment unavailable" from
  "product failure" in the runner output.
- [ ] Add a content-contract suite that iterates every registry entry.
- [ ] Add an editor authoring smoke that creates or duplicates a definition,
  refreshes the registry, opens the design preview, launches the interactive
  workbench, and verifies cleanup. Run it through the connected Godot/MCP
  editor when available; keep a standalone focused fallback for CI.
- [ ] Add preview-contract assertions for deterministic seed/clock behavior,
  factory-path identity, resolved asset reporting, stale-resource invalidation,
  and isolation from the active profile/save.
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
| `preview hub` | validates the standalone animated Hub design view; `-Editor` opens it without booting a run |
| `preview enemy <id>` | validates the enemy workbench without booting a run; `-Editor` opens the scene; future `-Mode design\|interactive` selects the preview tier |
| `preview item <id>` | validates the ItemCatalog-driven item design preview without booting a run; `-Editor` opens the workbench |
| `new variant <id>` | scaffolds one standalone Slime variant in `resources/definitions/<id>.tres` |
| `new enemy <id>` | reserved for a distinct family; Skeleton is the first manually authored family proof, while generic family scaffolding remains future work |
| `new item <id>` | scaffolds one standalone `resources/definitions/items/<id>.tres` |
| `manifest refresh\|check` | regenerate the checked-in resource references or fail on stale output |
| `report` | prints the authored catalog report |
| `doctor` | checks the project root and configured Godot executable |

Planned extensions use the same surface rather than adding ad hoc scripts:

| Command | Purpose |
|---|---|
| `preview room <id>` | inspect geometry, sockets, walkability, encounters, and rewards |
| `preview map <id>` | inspect graph connectivity, route policy, gates, and landmarks |
| `preview art <kind> <id>` | inspect resolved frames, palettes, anchors, and native-scale output |
| `new room <id>` / `new map <id>` | scaffold validated typed level definitions |
| `test -Suite content` | run shared registry/content contracts in one bounded suite |
| `editor authoring` | open the authoring dock or run its focused lifecycle smoke in a connected editor |

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
| Definitions, scenes, assets, generated files, and runtime edits | separate counts from the worked example diff |
| Central runtime files changed (`gameplay_state`, `room_controller`, `gameplay_frame_controller`) | diff of the worked example |
| Time from blank template to playable content | `dev.ps1 new` + preview + test loop |
| Factory path coverage: kinds whose runtime instances come only from a factory | code search per kind |
| Definition validation coverage: resources covered by `validate_definitions` / total authored resources | validator output |
| Deterministic save/load by stable ID | focused round-trip test |
| Reflection or coordinator access required | diff; must be zero for the worked example |
| Preview lifecycle: cold/warm select, rebuild, reimport, and cleanup time | editor authoring smoke with content ID and revision |
| Preview resource footprint: nodes, textures, materials, frames, and memory | design/interactive workbench capture |
| Preview/runtime parity: factory/compiler path and resolved references | preview contract plus normal scene/export proof |

The target is zero runtime-code, per-content test, or gate edits for content
using supported behaviors, plus shared factory/compiler materialization,
validation, and a green save/load round-trip. A simple variant should need one
definition; new scenes and art sets may legitimately require multiple assets.
Generated records are reported separately and never hand-maintained.

### Independent production usability acceptance

At each content milestone, a teammate unfamiliar with its implementation uses
only Godot and `CONTENT_AUTHORING.md` to create the worked example. Record the
commit, participant role, task, elapsed time, mistakes, confusing fields,
documentation lookups, and engineering interventions. Agree a task-time target
with the production reviewer before the exercise; do not infer usability from
test counts or an engineer's own demonstration.

Final handoff repeats enemy, gear, room/map, and artwork tasks from a clean
checkout. Passing requires no code/raw-resource editing, terminal dependency,
or engineer intervention, plus successful undo/redo, save/reopen, preview,
validation, and exported-content proof. Fix blockers and repeat affected tasks.

## 9. Production exit gates

This plan is complete only when all of these statements are true:

- [ ] The M1 editor controls and lifecycle checks pass, including stale-cache
  refresh, manifest freshness, duplication/rename/deletion, and exported discovery.
- [ ] The three preview modes are distinct and verified: an animated design
  preview that is safe inside the editor, an interactive workbench that uses
  isolated runtime state, and a full-game playtest that remains the integration
  authority.
- [ ] A preview can pause, step, choose a representative state, show geometry
  and resolved assets, recover from a reimport, and cleanly close without
  leaving timers, nodes, audio, profile data, or modified resources behind.
- [ ] The independent production usability exercise passes for every supported
  content workflow, with results and agreed time targets recorded.
- [ ] A designer can add an enemy using the Inspector, select an existing
  behavior archetype, assign stats and encounter data, preview it, and spawn it
  in a normal room without editing GDScript.
- [ ] A designer can add a weapon, armor piece, or accessory with typed stats,
  effects, slot, rarity, icon, drop art, and stable ID; generation, equipment,
  save/load, and preview all use the same definition.
- [ ] A designer can add an authored room and route/map entry with typed
  geometry, sockets, connections, encounters, rewards, landmarks, and policy;
  invalid content fails before runtime.
- [ ] An artist can replace actor, gear, room, menu, and effect artwork through
  imported assets and art-set resources without runtime code changes.
- [ ] Every authorable kind has a preview workbench that uses the same factory
  or compiler path as the game and reports resolved references.
- [ ] Editor preview performance has a recorded cold/warm baseline, resource
  footprint, and target-device comparison; no preview feature creates an
  unbounded world or silently changes runtime quality settings.
- [ ] `dev.ps1 verify` validates all authored definitions, asset contracts,
  stable IDs, UIDs, registry discovery, and generated documentation.
- [ ] A content addition is proven with one data-only worked example per kind;
  no central runtime file, test file, or release-gate edit is needed.
- [ ] Fast pure/content checks run in a shared process, while scene and visual
  checks remain focused and explicitly classified in the manifest.
- [ ] QA receives a deterministic validation report, preview result, focused
  contract result, and stable-ID/save compatibility summary.
- [ ] The README, content guide, generated content index, metric blocks, and
  agent command surface describe the workflow that actually exists.

Until these gates pass, the repository may be structurally healthy but should
not be described as production-authorable.
