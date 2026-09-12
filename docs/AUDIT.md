# Tiny Demons — Version 0.2.00 Codebase Baseline

Status: canonical source audit for the `0.2.x` development cycle

Audit date: 2026-09-11

Baseline commit: `bfe55782f43ee40fe32b5bebd45de988e34579d8`

Baseline game version: `0.2.00`

Current release: `0.2.01` (documentation and verification baseline update)

## 1. Purpose

This document records what Tiny Demons is and how its implementation is shaped
at the start of the `0.2.x` cycle. The current game is the foundation to preserve.
The purpose of the next infrastructure work is to make that foundation easier to
understand, extend, validate, and ship without changing its identity.

Tiny Demons is an action RPG built around deep dungeon crawling, elemental
resistances, puzzle solving, exploration, and battling. Its current systems are
working parts of that identity rather than disposable prototype code.

This audit replaces the August 2026 phase-closeout status previously stored in
this file. That report remains available in Git history. Several of its
architectural decisions remain valid, but its measurements, branch references,
and completion claims no longer describe the current repository.

## 2. Scope and evidence

The audit inspected:

- all 141 runtime/editor GDScript files under `scripts/`;
- the main scene and 18 supporting project scenes under `scenes/` (the MCP
  addon editor scene is outside this project-scene count);
- project input, renderer, viewport, export, and CI configuration;
- all 121 GDScript test/report files and the smoke-test registry;
- permanent profile, active-run, local, web, and cloud save boundaries;
- authored and generated dungeon definitions;
- combat, Chroma, progression, equipment, room, enemy, UI, touch, and audio
  ownership paths; and
- the 77 tracked Markdown documents under `docs/` plus `README.md` as a
  documentation inventory; `AGENTS.md` and addon documentation are tracked
  separately.

Verification performed during the audit:

- The smoke runner's inventory mode found all 113 registered tests.
- A Godot 4.7.1 headless editor import scan completed successfully.
- The import scan reported duplicate-UID warnings between the R4/R5 puzzle-map
  scripts and their corresponding authored-layout smoke tests. These warnings
  require cleanup before file reorganization.
- Expected local environment warnings were emitted for the Windows certificate
  store, MCP registry writes, and editor-settings persistence.
- The full 113-test runtime suite was not run as part of this read-only audit.
  Per the repository safety rule, it remains a supervised standalone gate.
- MCP per-file diagnostics were unavailable because no editor peer was connected.
  The successful editor import scan is the compile/import evidence for this
  baseline; it is not a substitute for runtime behavior tests.

## 3. Measured baseline

| Metric | Version 0.2.00 |
| --- | ---: |
| GDScript files in `scripts/` | 141 |
| Runtime/editor GDScript lines | 43,799 |
| Named GDScript classes | 127 |
| Ordinary functions | 2,514 |
| Static functions | 340 |
| Declared signals | 55 |
| One-line function declarations | 1,963 |
| `root.call/get/set` sites | 3,112 |
| Metadata access sites | 224 |
| Scene files | 19 |
| GDScript test/report files | 121 |
| Test/report lines | 12,664 |
| Registered smoke tests | 113 |
| Tests loading the main scene | 34 |
| Project Markdown documents | 78 |

Largest scripts:

| Script | Lines | Primary concern |
| --- | ---: | --- |
| `screen_state_controller.gd` | 5,333 | All major menu construction, layout, input, and presentation |
| `room_controller.gd` | 2,060 | Room lifecycle, encounters, sockets, rewards, and persistence |
| `gameplay_state.gd` | 1,703 | Shared references/state plus 505 compatibility wrappers |
| `dungeon_layout_generator.gd` | 1,629 | Generated topology, curriculum, and layout policy |
| `hub_flow_controller.gd` | 1,323 | Hub routes, shop, equipment, fusion, stats, and transactions |
| `player_equipment_visual_component.gd` | 1,152 | Layered gear presentation and attack-state synchronization |
| `item_catalog.gd` | 994 | Definitions, generation, display, economy, effects, and compatibility |
| `touch_controls_layer.gd` | 977 | Gameplay controls plus generic menu touch routing |
| `hud_controller.gd` | 921 | HUD construction, updates, prompts, and generated textures |
| `dungeon_minimap_controller.gd` | 882 | Compact map, full map, markers, travel menu, and rendering |

Line counts are navigation and responsibility indicators. They are not quality
scores or automatic split thresholds.

## 4. Implemented game surface

### 4.1 Core loop

The project currently supports a complete loop from title and save selection to
the Demon Hub, dungeon entry, room traversal, combat, puzzles, treasure, rest
flames, boss completion, settlement, progression, and return to the Hub.

The loop is backed by persistent profiles and recoverable active runs. Dungeon
state tracks discovery, completion, gate state, visited flames, current room,
and teleport destinations. Room runtime state preserves enemies and drops across
transitions.

### 4.2 Player action combat

Implemented player actions include:

- isometric movement and running;
- attack-one/attack-two combo flow;
- running finishers;
- held charge into a charged attack-two and sword beam;
- circular-input spin attack;
- directional attack geometry and multi-target contact;
- roll, backflip-related movement state, guard, hit reactions, and knockback;
- target lock and target-facing behavior; and
- equipment layers synchronized to locomotion, guard, attacks, charge, spin,
  recovery, occlusion, and palette changes.

`PlayerAttackComponent`, `PlayerAnimationComponent`, `PlayerGuardComponent`,
`PlayerRollComponent`, `ActorMotor`, `ActorGeometry`, and
`CombatRuntimeController` contain useful ownership boundaries. Combat requests
and stat snapshots are typed, and `CombatCalculator` is largely independent of
scene presentation.

### 4.3 Elements and Chroma

The combat catalog contains eight stable elements: Neutral, Fire, Water,
Electric, Grass, Shadow, Ground, and Ice. The matchup table expresses weakness,
resistance, immunity, and neutral relationships.

The player can attune to primary and fused aspects, spend and restore Chroma,
remain bound while visually desaturating at zero Chroma, cast aspect abilities,
imbue attacks, collect aspect-colored Chroma, charge Orbs, bind an element, and
fuse flames. `PlayerChromaComponent` is a strong state owner with signals for
aspect, bound aspect, Chroma, and ability-mode changes.

### 4.4 Enemies

The active enemy family is slime-based. It includes Neutral and elemental
variants, shared movement and combat components, contextual steering, attack
commitment, hitstun, knockback, ambush behavior, respawning popcorn enemies,
spawn animation, health presentation, and boss jump/slam behavior.

The architecture separates reusable slime state (`SlimeBrain`,
`SlimeCombatComponent`, `SlimeAnimationComponent`, and related components) from
the large `SlimeRuntimeController` integration layer. Variant definitions are
centralized in `SlimeVariantCatalog`, although runtime configuration still
crosses the shared root heavily.

### 4.5 Dungeons, rooms, puzzles, and exploration

`DungeonGraph` provides typed room, connection, socket, and gate concepts.
Current room categories include Start, Combat, Puzzle, Rest/Fire, Trader, NPC,
Downstairs/Boss, Special Enemy, Treasure, and Orb.

The dungeon supports authored layouts for Runs 1–5 and deterministic generated
layouts from Run 6 onward. Layout definitions include world coordinates,
minimap coordinates, room types, chest placement, flames, socket pairings,
route roles, clear gates, elemental gates, puzzle-color gates, and entrance-Orb
gates. Generator and route-solver code contains explicit reachability and
curriculum logic.

The compact minimap and expanded travel map use the same graph/state. Visited
flames and the Hub are travel destinations, with travel restricted to flame
rooms and the Hub.

Room scenes contain authored floor, wall, socket, spawn, collision, and return
guides. Runtime code composes these with active graph connections. This supports
the current visual flexibility but also makes room geometry one of the most
coupled and regression-prone areas.

### 4.6 Progression, equipment, and economy

Profiles contain six player stats: VIT, STR, DEF, AGI, INT, and MND. They track
level, XP, unspent points, gold, Souls, run completion, difficulty, grades,
element binding, inventory, equipment, mastery, and stable item instance IDs.

Equipment uses six canonical slots: Weapon, Head, Body, Arm, Shield, and
Accessory. Items have stable definition and instance identities, rarity,
enhancement, random stat points, effects, source restrictions, prices,
salvage values, and fusion behavior. The Hub provides buying, selling,
equipping, removal, duplicate fusion, binding, allocation, respec, and run
entry flows.

The item model already distinguishes individual instances, which is important
for independently handling gear with different enhancement and random-stat
values. `ItemCatalog` currently combines content data, compatibility data,
generation policy, display formatting, pricing, and effect interpretation in
one code file.

### 4.7 Presentation and platform support

The game uses a 240×160 logical pixel-art presentation with nearest filtering
and integer scaling. It supports adaptive landscape widths plus fixed aspect
presets. Desktop and web share one codebase; the web renderer is overridden to
Compatibility mode.

Input supports keyboard, gamepad, mouse/menu interaction, virtual touch
controls, touch menu scrolling, and last-input-device prompts. Direct engine
input access is limited to `InputRouter` and `InputDeviceTracker`, which is a
good boundary.

The Web export, GitHub Pages workflow, localStorage save mirror, active-run
recovery, browser lifecycle diagnostics, and optional encrypted cloud backup
are substantial production-facing systems already present in the foundation.

## 5. Runtime architecture

### 5.1 Composition

`scenes/main.tscn` is the primary composition scene. Its root uses
`gameplay.gd`, which inherits `GameplayState`. The scene authors the persistent
world and actor nodes, while `GameplayBootstrap` creates and wires many runtime
components and controllers.

`gameplay.gd` is now a relatively small 245-line coordinator containing startup,
the physics entry point, music coordination, a few remaining interactions, and
compatibility accessors. This is a meaningful improvement over the older giant
coordinator design.

The architectural center has moved into `gameplay_state.gd`. It owns node
references, controller references, transient fields, constants, collections,
and 505 short forwarding methods. It acts simultaneously as:

- composition root;
- mutable shared-state container;
- compatibility API;
- adapter between controllers;
- repository of gameplay constants; and
- inherited base class for the main runtime.

This arrangement preserves behavior and made incremental extraction possible,
but it is now the main obstacle to compile-time dependency checking.

### 5.2 Frame ordering

The runtime correctly retains one explicit physics schedule. `gameplay.gd`
polls the input router and delegates the frame to `GameplayFrameController`.
That controller orders input, player actions, movement, animation, enemies,
pickups, interactions, UI, effects, depth, targeting, and stabilization.

This deterministic schedule should be preserved. Future ownership work should
replace string calls inside scheduled phases with typed collaborators rather
than distributing gameplay across independent `_process()` methods.

### 5.3 Coupling profile

There are 3,112 `root.call/get/set` sites. The largest concentrations are in:

| Script | Dynamic root sites |
| --- | ---: |
| `screen_state_controller.gd` | 422 |
| `room_controller.gd` | 409 |
| `combat_runtime_controller.gd` | 221 |
| `gameplay_frame_controller.gd` | 205 |
| `slime_runtime_controller.gd` | 194 |
| `magic_runtime_controller.gd` | 141 |
| `player_animation_component.gd` | 124 |
| `actor_presentation_runtime_controller.gd` | 122 |
| `hub_flow_controller.gd` | 108 |

These calls hide required inputs, allow misspelled properties to survive until
runtime, make ownership difficult to infer, and broaden the effect of changes.
They are migration seams, not evidence that the underlying feature components
should be discarded.

Metadata is used at 226 sites for encounter scale, temporary effects, visual
state, menu state, and runtime annotations. Metadata is appropriate for some
open-ended presentation tags, but gameplay-significant metadata should become
typed state where practical.

### 5.4 Architectural strengths to retain

- Central deterministic frame scheduling.
- Typed combat requests and stat snapshots.
- Stable element IDs and one matchup authority.
- Dedicated Chroma state ownership and signals.
- Dungeon graph, map state, and layout-definition boundaries.
- Shared actor geometry for rendering and combat bounds.
- One input snapshot boundary across desktop, gamepad, and touch.
- Permanent profile state separated from disposable active-run recovery.
- Stable item instance IDs and explicit profile migrations.
- One desktop/web codebase with platform behavior isolated at seams.

## 6. Subsystem assessment

| Domain | Current owners | Assessment | Main scaling need |
| --- | --- | --- | --- |
| Frame orchestration | `gameplay.gd`, `gameplay_frame_controller.gd` | Direction is sound | Replace dynamic calls with typed phase dependencies |
| Shared runtime state | `gameplay_state.gd` | Preserves compatibility but owns too much | Move state to feature owners and shrink wrapper API |
| Player combat | player components, combat calculator/runtime | Strong mechanics and useful components | Separate pure resolution from root-based scene integration |
| Slime combat | slime components and runtime controller | Rich reusable behavior | Add typed enemy runtime context and archetype boundary |
| Actor geometry | actor geometry/collision/motor/occlusion | Shared geometry is a good foundation | Clarify collision versus rendering ownership and test room edges |
| Chroma/magic | Chroma, aspect ability, magic/projectile controllers | Chroma state is well owned | Remove root glue and define typed ability execution requests |
| Dungeon topology | graph, layouts, generator, route solver | Capable authored/generated foundation | Split generation policy, compilation, and validation |
| Room runtime | room and puzzle controllers | Feature-complete but highly coupled | Extract transition, encounter, geometry, and persistence services |
| Progression | profile, progression, run state/settlement | Durable data model with migrations | Separate profile data from economy and content policies |
| Equipment/content | item catalog, instances, equipment | Stable instance model is valuable | Move authored definitions and generation policy out of one catalog |
| Hub flow | hub flow plus screen state | All required flows exist | Separate transactions, navigation state, and presentation |
| Menus/UI | screen state plus layout scripts/scenes | Visual language exists but implementation is fragmented | One reusable menu contract and one presenter per route |
| Input/touch | input router, tracker, touch layer | Strong centralized input boundary | Split gameplay touch rendering from generic menu hit testing later |
| HUD/effects | HUD, effects, sprite library | Functional and cache-aware | Consolidate generated-texture services and profile hot paths |
| Audio | sound manager, clip catalog, mix profile | Centralized playback and web-aware assets | Add focused lifecycle/performance verification |
| Saves/cloud | profile/active-run services and cloud boundary | More mature than most systems | Formal migration fixtures and failure-path integration tests |
| Display/web | display owner, layout helpers, export workflow | Sound cross-platform direction | Maintain a device/browser acceptance matrix |

## 7. Content authoring assessment

The game can already express substantial content, but authoring is primarily
code-driven:

- item and enemy definitions are large dictionaries in GDScript;
- authored runs are separate GDScript builders;
- generated-run policy is concentrated in a large static generator;
- tuning classes are instantiated directly with defaults in
  `gameplay_state.gd` rather than loaded as named project resources; and
- room variants depend on a combination of scene guides and runtime policy.

This is workable for the current content volume. It will become expensive as
the number of items, enemy families, rooms, abilities, and run rules grows.

The target content path for `0.2.x` should be:

```text
authored definition -> validator -> catalog -> runtime instance -> stable save ID
```

Likely definition types are Item, Enemy Archetype, Encounter, Room Template,
Run, Ability, Reward Table, and Gate/Puzzle Rule. These definitions may be
Godot resources or another typed, validated format. Behavior remains in code;
definitions select and tune existing behavior.

Content migration must be incremental. Stable IDs and save migrations take
priority over changing the storage format. Existing dictionaries should first
receive validators and typed accessors, then move only when equivalence is
characterized.

## 8. UI and menu assessment

UI is the clearest current scaling bottleneck. `ScreenStateController` grew
from the old audit's 1,225-line baseline to 5,333 lines and now combines:

- title, save, character creation, game-over, and results flows;
- Hub, pause, status, allocation, shop, fusion, bind, and equipment views;
- menu construction and layout;
- navigation and input handling;
- cursor motion and touch targets;
- generated pixel text and detail formatting;
- responsive positioning; and
- transition particles and button effects.

Dedicated layout scripts and authored menu scenes already exist, but ownership
is split between those files, `HubFlowController`, and the screen controller.
This explains repeated regressions where one menu uses slightly different
cursor, footer, orientation, touch, clipping, or scrolling behavior.

The desired boundary is not a large menu inheritance hierarchy. It is a small
shared menu toolkit plus focused route presenters:

- shared frame, footer, prompt, cursor, list, clipping, and responsive-layout
  primitives;
- one navigation model that exposes selection, enabled state, and commands;
- one presenter per major route; and
- the same command path for keyboard, controller, mouse, and touch.

Pause and Demon Hub are the best visual references for this toolkit. New menu
work should stop expanding `ScreenStateController` while existing screens are
migrated one at a time with screenshot and input characterization.

## 9. Testing and verification assessment

The test investment is a major strength: 121 scripts and 12,664 lines cover
domain rules, generated layouts, scenes, geometry, menus, progression, saves,
touch, display, combat, and web-facing contracts. Thirty-four tests load the
main scene, providing meaningful integration coverage.

The current harness limits that value:

- each registered test launches a separate Godot process;
- the full run is slow and can amplify renderer crashes;
- all tests are called “smoke” tests despite having different cost and scope;
- the registry is a manually maintained PowerShell array;
- eight GDScript test/report files are outside the registry; and
- visual acceptance remains mostly manual.

Unregistered files at this baseline:

- `actor_geometry_smoke.gd`
- `cloud_panel_touch_smoke.gd`
- `demon_cloak_smoke.gd`
- `fusion_menu_preview.gd`
- `hub_content_scroll_smoke.gd`
- `puzzle_map_reference_diff_report.gd`
- `resource_drop_motion_smoke.gd`
- `touch_menu_scroll_smoke.gd`

Some may intentionally be reports or environment-sensitive checks. Their status
should be explicit rather than inferred from absence.

The 2026-09-11 standalone baseline found all `113` registered paths with no
missing files. Direct focused execution confirmed the authored R3/R4/R5 and
Run 2 layout contracts, room/slime/enemy setup, selected gear contracts, and
selected Chroma/progression contracts. It also exposed current failures in
active-run recovery, doorway geometry, Hub/equipment/touch menu contracts,
gear catalogue/drop policy, generated minimap visibility/order, the starter
flame music gate, elemental binding, and generated R7 bounds. The native R7
smoke did not complete after reporting out-of-bounds rooms. See
[`test-target-audit.md`](test-target-audit.md) for the test-by-test result and
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for the triage register.

The target test structure should contain:

1. fast pure/domain checks in a shared process;
2. content and resource validation in a shared process;
3. focused scene integration suites;
4. a small number of full runtime journeys;
5. web export/boot checks; and
6. manual visual and device acceptance checklists.

The current process-per-test runner should remain available until an equivalent
suite runner proves the same failures are detected.

## 10. Persistence and compatibility

`PlayerProfile` currently writes schema 13 and accepts legacy schemas 8–13.
Compatibility includes the SPD-to-AGI transition, six-stat migration, equipment
slot migration, Demon Cloak behavior, gear-system revisions, and current stat
baselines.

Permanent profiles use three slots, temporary writes, validation, backups, and
web localStorage mirroring. Active runs use a separate schema-1 snapshot with
normalized vectors, run identity, room state, map state, player health, Chroma,
facing, and run layout identity. Cloud saves export a versioned profile envelope
and store encrypted payloads remotely.

This is a professional-quality foundation worth protecting. Every content or
state refactor must answer:

- Is the stable ID unchanged?
- Can the current version load every supported legacy schema?
- Does a failed write preserve the previous valid save?
- Does desktop behavior match the web localStorage path?
- Can an active run fail validation without damaging permanent progression?

Migration fixtures should eventually replace ad hoc assumptions about old save
shapes.

## 11. Performance profile

The code already uses caches, bounded effect collections, spatial slime
broad-phase logic, and startup warming. Known areas that deserve measurement
before more content is added are:

- per-pixel actor occlusion and highlight texture generation;
- generated pixel-text and recolor caches;
- large menu refreshes and inventory comparison rendering;
- room transition setup and enemy-state restoration;
- dungeon generation and reachability checks;
- startup palette/frame preparation; and
- mobile/web behavior under single-threaded rendering.

The rule for `0.2.x` should be profile before optimizing. Each performance task
needs a reproducible scenario, baseline time or allocation count, target device,
and before/after evidence. Caches require explicit invalidation ownership so
speed fixes cannot display stale inventory, palette, or room state.

## 12. Naming and repository organization

The source consistently uses `snake_case` filenames and generally uses
`PascalCase` named classes. The larger naming problem is semantic: terms such as
controller, component, runtime controller, system, layout, model, and service
do not yet carry a strict responsibility contract.

Recommended meanings:

- **Component** — state and behavior belonging to one actor/entity.
- **Controller** — coordinates a bounded feature or lifecycle.
- **Service** — stateless or durable capability used by multiple features.
- **System** — evaluates a collection of entities or shared rules.
- **Definition** — authored immutable content data.
- **State** — serializable or explicitly owned mutable data.
- **Presenter** — converts state into view updates and visual commands.
- **Layout** — geometry and responsive positioning without transactions.
- **Catalog** — lookup/index over validated definitions.

All 141 scripts currently occupy one flat `scripts/` directory. A feature-based
directory structure will improve discovery, but moving files before ownership
is clarified would create noisy Godot reference changes. Files should move with
their feature migration after duplicate UIDs are resolved and import checks are
green.

## 13. Documentation assessment

The baseline repository contains 78 project Markdown documents (77 under
`docs/` plus `README.md`; `AGENTS.md` and addon documentation are excluded from
this count). The current documentation-only worktree adds the new canonical
guides listed below:

- 35 files named as implementation plans;
- approximately 15 audits, analyses, inventories, checkpoints, inspections, or
  validation reports; and
- multiple overlapping design, handoff, contract, and catalogue documents.

The primary problem is authority and lifecycle, not the amount of writing.
Documents mix intended design, implementation history, current behavior,
branch-specific status, and unresolved ideas. Several active-looking files
refer to old feature or refactor branches. Older plans may remain valuable, but
they must not silently override current source or current design direction.

The documentation audit should establish these maintained authorities:

- `README.md` — entry point and verification;
- `docs/AUDIT.md` — measured current implementation baseline;
- `docs/project_direction.md` — approved game identity and design principles;
- `docs/ARCHITECTURE.md` — current ownership and extension rules;
- `docs/ROADMAP.md` — active product and infrastructure sequence;
- `docs/CONTENT_AUTHORING.md` — repeatable content workflows;
- `docs/GAMEPLAY_TUNING.md` — designer-facing balance surface;
- `docs/KNOWN_ISSUES.md` — current reproducible issues; and
- `docs/VERSIONING.md` — release numbering and update rules.

Every other document should be classified as active proposal, feature
reference, historical, superseded, or disposable. Historical material should
be archived before deletion. Maintained documents should state status, owner,
last verified version/commit, source of truth, and supersession relationships.

## 14. Baseline preservation contract

Infrastructure work during `0.2.x` must preserve:

1. The current action-RPG identity: dungeon crawling, elemental combat,
   puzzles, exploration, and battling.
2. The complete title → Hub → dungeon → settlement → Hub loop.
3. Existing authored Runs 1–5 and generated Run 6+ policy unless an intentional
   content decision changes them.
4. Existing movement, attack, combo, spin, charge, guard, roll, magic, Chroma,
   target, and enemy timing unless a balance change is separately approved.
5. The 240×160 pixel-art composition and responsive landscape behavior.
6. Keyboard, controller, touch, desktop, and web operation.
7. One deterministic gameplay frame schedule.
8. Stable profile, item, element, room, and run identities.
9. Supported save migrations and active-run recovery.
10. Current menu visual conventions while their implementation is unified.

Structural and gameplay-balance changes should not share a patch unless the
balance change is required to preserve behavior after extraction.

## 15. Recommended `0.2.x` infrastructure sequence

### Phase 0 — Preserve and document 0.2.00

- Keep this audit tied to the baseline commit.
- Capture a short manual acceptance run and representative screenshots.
- Resolve the duplicate R4/R5 UID warnings.
- Classify the eight unregistered test/report scripts.
- Record a full supervised smoke result when the environment is stable.

Exit: the baseline can be rebuilt, tested, and visually compared.

### Phase 1 — Documentation authority

- Write the project-direction document from the creator's current intent.
- Create one documentation index and lifecycle convention.
- Reconcile `ARCHITECTURE.md`, `refactor-route.md`, and `FEATURE_MAP.md` with
  this baseline.
- Classify all remaining documents and archive superseded material.
- Create the live roadmap, known-issues list, and content-authoring skeleton.

Exit: a contributor can identify current truth without reading historical plans.

### Phase 2 — Menu platform

- Characterize Pause and Demon Hub visual/input conventions.
- Extract shared menu frame, footer, prompt, cursor, list, clipping, and
  responsive-layout primitives.
- Move one screen at a time from `ScreenStateController` into focused presenters.
- Route touch, mouse, controller, and keyboard through the same commands.
- Preserve screenshots and behavior at every extraction.

Exit: adding a menu does not enlarge `ScreenStateController`, and migrated menus
share one interaction contract.

### Phase 3 — Room and encounter boundaries

- Separate transition, socket/geometry, encounter spawning, room persistence,
  and reward orchestration.
- Define typed spawn and transition results.
- Validate full-body enemy placement and route reachability before activation.
- Add deterministic room scenario fixtures.

Exit: adding a room or encounter uses a documented definition and does not
require editing a general 2,000-line controller.

### Phase 4 — Typed runtime ownership

- Create narrow typed contexts for scheduled domains.
- Move single-owner fields out of `GameplayState` with characterization first.
- Replace `root.call/get/set` vertically by feature.
- Remove compatibility wrappers after their final consumer migrates.
- Convert gameplay-significant metadata to typed fields.

Exit: migrated features are rename-safe and declare their dependencies.

### Phase 5 — Content authoring pipeline

- Add validators and typed accessors around current item, enemy, room, run,
  ability, reward, and tuning data.
- Define stable authoring templates and extension examples.
- Move data from code only when save and runtime equivalence are covered.
- Add one content-validation suite to CI.

Exit: ordinary content additions primarily create validated definitions rather
than modify central runtime code.

### Phase 6 — Test and performance infrastructure

- Group fast tests into shared-process suites.
- Keep focused scene and journey tests separate.
- Add screenshot/geometry checks for fragile visual contracts.
- Establish desktop and web frame-time scenarios.
- Profile known hot paths and optimize only with evidence.

Exit: routine feedback is fast, the release gate remains comprehensive, and
performance regressions have reproducible evidence.

### Phase 7 — Feature-based repository layout

- Move scripts, scenes, tests, and content by completed feature boundary.
- Preserve UIDs and validate all resource references after each move.
- Update the architecture and authoring guides with each domain migration.

Exit: repository structure mirrors runtime ownership without a disruptive
all-at-once path rewrite.

## 16. Immediate conclusions

Tiny Demons 0.2.00 already contains a broad, distinctive game and several
strong engineering foundations. Its largest risk is not missing architecture;
it is that successful incremental extraction stopped halfway, leaving mature
feature components connected through a shared dynamic compatibility layer.

The next cycle should therefore focus on consolidation: preserve behavior,
make documentation authoritative, establish shared menu conventions, separate
room responsibilities, then migrate runtime seams and content authoring one
vertical slice at a time. A broad rewrite would put working combat, dungeon,
save, input, and web behavior at unnecessary risk.

This baseline is the starting point for that work. Product direction determines
what Tiny Demons should become; source characterization and staged extraction
determine how it can grow safely.
