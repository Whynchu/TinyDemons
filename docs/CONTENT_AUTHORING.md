# Tiny Demons Content Authoring Guide

Status: working guide; enemy definitions and encounter eligibility now use the
typed catalog/factory path, including standalone one-file definitions and the
enemy preview workbench. Other authored surfaces are still only partially
wired. Read the trap table below before editing any `.tres`.

Updated: 2026-09-20

Owner: the feature owner listed in [`FEATURE_MAP.md`](FEATURE_MAP.md). The
content guide describes current boundaries; it does not authorize a new data
framework or a gameplay balance change. The target for definition-driven
content, runtime factories, previews, and verification is
[`authoring-system-plan.md`](authoring-system-plan.md).

This guide answers the practical question: “Where should a new piece of Tiny
Demons content be added?” The safest current workflow is to identify the
stable ID and owning catalog or layout definition first, then add focused
verification before changing runtime orchestration. **Verify that the runtime
consumer reads the field you are editing**; several resources are only
partially wired.

## Data paths that currently do nothing

Measured 2026-09-20 (version `0.2.70`). Until the listed slice in
[`authoring-system-plan.md`](authoring-system-plan.md) lands, these paths are
traps:

| Authored data | Current runtime behavior | Owner slice |
|---|---|---|
| `dungeon_generation_policy.tres`: `first_orb_depth`, `first_special_depth`, `primary_flames` | Ignored. The generator uses `dungeon_layout_generator.gd:31-32,50`. | 3 |
| Former `resources/definitions/puzzle_map_r3.tres` path | Removed in Slice 0; the runtime and preview use `puzzle_map_r3_new.tres`. | resolved |
| `item_catalog.tres`: records added only to `definitions` (not `live_base_definitions`) | Never drop or appear in the shop; the legacy section is loadable but excluded from generation. | 2 |
| Item `visual_id` | Written but never read; item art is slot-level only. | 2 |
| `element_catalog.tres` and `palette_library.tres` | Now included in recursive definition validation; runtime wiring and typed consolidation remain Slice 2 work. | 2 |

The definition validator is part of the release gate and web CI. The catalog
report exits nonzero when a required surface cannot load.

## Shared rules

Every content addition should have:

- a stable machine-readable ID that is never reused for a different meaning;
- a player-facing name or display value owned by the same definition boundary;
- an explicit owner and source of truth;
- a deterministic construction path where randomness is involved;
- a compatibility decision if the content can enter a save or active run; and
- a focused test or manual acceptance step that proves the player-facing
  contract.

Keep authored content distinct from generated content. An authored map is a
pixel/layout contract. A generated map is a seeded output that must pass its
topology, gate, socket, reachability, and milestone validators before runtime
activation.

## Adding a dungeon run or room

### Authored runs

Current owners:

- run layout data in `resources/definitions/dungeon_layout_run1.tres` and
  `dungeon_layout_run2.tres` (`DungeonRunDefinition`), loaded by
  `scripts/dungeon_layout_run1.gd` / `dungeon_layout_run2.gd`;
- map plans in `resources/definitions/puzzle_map_r*.tres` (`PuzzlePlanData`),
  loaded by `scripts/puzzle_map_r*.gd`;
- compilation in `scripts/puzzle_map_layout_compiler.gd`;
- runtime topology in `scripts/dungeon_graph.gd` and
  `scripts/dungeon_map_controller.gd`; and
- room activation and persistence in `scripts/room_controller.gd`.

Workflow (current, before Slice 3):

1. Define the run scope and whether its map is an authored pixel contract.
2. Edit the authored room/connection or puzzle-plan `.tres` resource (or add a
   new one) and assign stable room IDs, room types, sockets, arrival sockets,
   and gate requirements.
3. Keep map art, markers, room geometry, and doorway semantics aligned.
4. Validate socket pairing, room reachability, entrance geometry, and milestone
   ordering.
5. Add or update the run-specific contract test and inspect the rendered map at
   native 240×160.
6. Verify room entry, clear, revisit, chest/pickup claims, and save recovery.

Known traps:
- The former `puzzle_map_r3.tres` path was removed in Slice 0; use
  `puzzle_map_r3_new.tres` for the current R3 plan.
- Layout validation at runtime only calls `push_error`
  (`room_controller.gd` callers of `DungeonLayoutDefinition.validate()` via
  `dungeon_map_controller.gd:65-101`); it does not fail the run.
- The puzzle-map compiler currently cannot emit the puzzle room type, so an
  authored pixel plan cannot express `ROOM_PUZZLE`.
- Room-type aliases (`ROOM_FIRE == ROOM_REST`, `ROOM_CLOAKED == ROOM_NPC`,
  `ROOM_BOSS == ROOM_DOWNSTAIRS`) mean room type alone does not identify
  semantics.
- Puzzle gate colors and room-type whitelists are duplicated across
  `dungeon_graph.gd`, `dungeon_map_state.gd:11-16`,
  `dungeon_map_controller.gd:19-22`, and
  `puzzle_map_layout_compiler.gd:218-228`.
- Run 1 has bespoke validation branches that other runs do not share.

Slice 3 turns room/connection payloads into typed resources and makes
validation fail fast in the validator and CI.

Do not make a new room by adding a special case to `gameplay.gd` or by silently
reusing an existing room ID. If a new room type is needed, document its
milestone and persistence semantics before implementation.

### Generated runs

Current owners:

- `scripts/puzzle_route_generator.gd` for the active R6+ risk/reward route
  boundary and its compact presentation plan;
- `scripts/puzzle_route_plan.gd` for route roles and planning data;
- `scripts/puzzle_route_solver.gd` and
  `scripts/puzzle_progression_planner.gd` for validation/support; and
- `scripts/dungeon_layout_generator.gd` for the broader generated layout path
  and compatibility seams.

Workflow:

1. Start with a seeded route requirement, not a visual arrangement.
2. Generate topology and explicit edge metadata.
3. Assign room roles, milestones, gates, flames, Orbs, and optional branches.
4. Validate bounds, duplicate coordinates, socket uniqueness, connectedness,
   ungated critical reachability, safe/risk route lengths, optional vault
   requirements, no-stranding, and room-size/encounter placement requirements.
5. Confirm the same seed and run context produce the same layout.
6. Check representative starter-flame and bound-flame combinations.
7. Add a deterministic generator test and a runtime route test before changing
   the active threshold.

For the current baseline, authored R1–R5 remain preserved and generated maps
are used from R6 onward. Existing R6 assets and compiler paths remain historical
or compatibility material unless a separate content decision changes that
policy.

## Adding an enemy or enemy variant

Current owners:

- actor behavior and lifecycle: `slime_actor.gd`;
- decision-making: `slime_brain.gd`;
- combat and attack timing: `slime_combat_component.gd`;
- spawn placement: `slime_spawn_component.gd` and room encounter ownership;
- visual variant mapping: `slime_variant_catalog.gd` and
  `slime_visual_component.gd`; and
- balance values: `slime_tuning.gd` and combat tuning.

Workflow (current, typed enemy-definition path):

1. Decide whether the addition is a visual variant, gameplay element, behavior
   variant, or a new actor class.
2. Create one standalone definition with
   `pwsh -File tools/dev.ps1 new enemy <id>`; this writes
   `resources/definitions/<id>.tres`. Existing embedded catalog entries in
   `slime_variant_catalog.tres` remain valid, but new content should use the
   one-file path. Set the stable `id`, element, display name, `base_stats`,
   `growth_weights`, `damage_contract`, and explicit `visual_source`.
3. Set encounter metadata on that same definition when it should enter normal
   generation: `encounter_role` (`baseline`, `matchup`, `late`, or `shadow`),
   `encounter_weight`, `encounter_min_rank`, and any preferred/matchup weight.
   `EncounterDefinition` and `RoomController` consume these fields at runtime.
4. Do not add a `VARIANTS` entry, a `RoomController` constant, a scene-authored
   roster slot, or a count-table expectation. The registry discovers the typed
   entry, `EnemyFactory` materializes it, and the runtime pool configures the
   selected slot from the definition.
5. If the variant introduces a genuinely new palette or behavior, extend that
   narrow owner and add a focused golden assertion. Reusing an existing
   `visual_source` is data-only.
6. Run `pwsh -File tools/dev.ps1 verify`, then preview the definition with
   `pwsh -File tools/dev.ps1 preview enemy <id>` and run
   `pwsh -File tools/dev.ps1 test -Suite content`. Verify normal, scaled/boss,
   wall-adjacent, and attack-contact behavior when the content is intended for
   those paths.

The enemy-specific one-file discovery and preview workbench are now landed.
The generic `ContentDefinition`/`ContentRegistry` layer remains future work;
the current enemy path already removes the old parallel registries and central
encounter branches.

Do not implement a new enemy only as a recolor if its combat identity differs.
Do not alter global tuning to solve a room-specific placement problem.

## Adding gear

Current owners:

- definitions and stable IDs: `resources/definitions/item_catalog.tres`
  (`ItemCatalogData`), loaded by `scripts/item_catalog.gd`;
- serialized instance identity: `scripts/item_instance.gd`;
- equip/unequip state: `scripts/equipment_component.gd`;
- equipment presentation: `scripts/player_equipment_visual_component.gd`;
- acquisition rules: the shop, chest, drop, fusion, and settlement owners; and
- player-facing contracts: `gear-catalogue-spec.md`,
  `gear-effect-contracts.md`, and `gear-catalogue.md`.

Workflow (current, before Slice 2):

1. Choose one of the six canonical slots: weapon, head, body, arm, shield, or
   accessory. Preserve the legacy `armor` compatibility key where required.
2. Add the base ID to `live_base_ids` **and** a record to
   `live_base_definitions` in `resources/definitions/item_catalog.tres`.
   Records added only to the legacy `definitions` section do not drop or shop.
3. Add source tags, rarity gates, metadata, and effect status to
   `definition_metadata`; the loader merges it over the base record.
4. For a set piece, add the set data and the set ID to
   `scripts/item_catalog.gd:45` (`SET_IDS`). Set acquisition tags and rarity
   gates are hardcoded in `item_catalog.gd`'s set synthesis today.
5. Decide whether the effect is active or `future`. A future effect may remain
   inspectable but must not enter live generation until its owner and action
   contract exist.
6. Update the count-pinned tests or the gate fails on a correct addition:
   `tests/gear_system_rework_smoke.gd:13` (66 live definitions),
   `tests/gear_catalogue_expansion_smoke.gd:22` (45 bases by slot),
   `tests/drop_art_smoke.gd:37`, and any shop/tooltip coverage.
7. Add catalogue/schema coverage and an acquisition test if the item can enter
   a source pool; add any new test file to `tests/manifest.csv`.
8. Check the item at each supported rarity/enhancement path without changing
   unrelated balance.

Known traps: `visual_id` is never read (item art is slot-level), `demon_cloak`
is special-cased across `player_profile.gd`, `run_state.gd`,
`equipment_component.gd`, and `hub_flow_controller.gd`, and there is no
`validate()` on `ItemCatalogData`, so malformed keys fail at runtime. Slice 2
replaces this with typed `ItemDefinition` entries, one registry, and
registry-driven tests.

Gear identity includes more than the display name. Enhancement, rarity,
affixes, random stats, transmutation, and fusion investment determine the
functional Equipment/Shop row; `quality` remains available on the exact
instance for economic pricing without splitting an otherwise identical row.
The sell cache still retains each concrete instance ID so grouped sales remove
the requested stock and calculate the correct payout.

## Adding an element, flame, or Chroma rule

Current owners:

- stable combat element IDs and matchups: `element_catalog.gd`;
- player Chroma state: `player_chroma_component.gd`;
- flame and pickup behavior: the Chroma/flame and pickup controllers;
- elemental ability behavior: `player_aspect_ability_component.gd` and magic
  runtime owners; and
- player-facing Binding/Fusion rules:
  `elemental-binding-and-fusion-design.md`.

Use the existing element catalog rather than adding a second spelling or
numeric table. Keep `gray`/`grey` presentation differences at the palette
boundary. A new elemental rule must specify current element, bound element,
Chroma amount, pickup behavior, zero-resource behavior, combat element, gate
requirements, visual palette, and save compatibility.

Known traps: element identity currently lives in four parallel tables — the
`ElementCatalog.Element` enum (`element_catalog.gd:11-20`), the numeric keys and
`element_count` in `element_catalog.tres`, the `PlayerChromaComponent.Aspect`
enum (`player_chroma_component.gd:14-23`), and the flame/palette/recipe strings
in `aspect_catalog.gd:4-32`. `element_for_palette()` is a hand-written switch
that can drift from the resource, `element_count` has two defaults, and
`element_catalog.tres` is now loaded by the recursive definition validator. Adding
a ninth element also breaks the hardcoded 8×8 table in
`tests/element_catalog_smoke.gd:12-21`, the `<= Aspect.ICE` validity bound, and
the `element_for_aspect` numeric adapter at the same time. Slice 2 collapses
this to one source with schema validation.

Verify Gray/Normal collection, bound depletion, temporary fusion depletion,
pickup coloring, save/load at zero, and any relevant gate route. Do not fold a
new element into the player aspect state without an explicit mapping decision.

## Adding tuning

The intended tuning classes are `PlayerTuning`, `CombatTuning`, `SlimeTuning`,
`EffectsTuning`, `ChromaTuning`, and `ProgressionTuning`. They load external
defaults from `resources/tuning/*.tres`, deep-duplicated per runtime, so a
balance change is an inspector/resource edit. Update
[`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md) and the relevant `.tres` resource
together when adding a tuning value.

Every tuning value should state its unit, owner, safe range or invariant, and
the behavior it changes. Keep animation frame identity and authored hit-frame
contracts separate from numerical balance. Add a focused test or manual
measurement for values that affect timing, geometry, persistence, or economy.

## Adding menu content

Current owner: `screen_state_controller.gd`, with stable geometry in the
corresponding menu scene/layout script.

Start from the Pause and Demon Hub visual contracts. At native 240×160, use the
existing panel/frame, right-side list, cursor anchor/movement, SELECT/BACK
footer, clipping, prompt, and responsive-anchor conventions. A menu route must
define its input context, selection ownership, confirm/back behavior, touch hit
targets, and cursor visibility. Do not add a separate navigation convention
for one screen.

Menu work is a planned extraction boundary (Slice 4 of the authoring plan).
Current reality: pause, Demon Hub, equipment, shop, and fusion are
scene-authored with presenters; title, archetype, save select, name entry,
settings, game over, run complete, and loading are still built imperatively in
`screen_state_controller.gd` and cannot be opened in the editor. Adding a route
or row currently touches several of: the controller build function
(`build_hub` alone takes 33 callables), the route's layout script, the
navigation state in `hub_flow_controller.gd` or the controller, the touch
active-root list in `touch_controls_layer.gd`, a scene smoke, and
`tests/manifest.csv`. Start from the Pause and Demon Hub visual contracts and
follow the presenter pattern rather than adding a new navigation convention.

## Adding audio

Current owners are `sound_manager.gd` for loading, playback, channels, and mix
policy, and the feature owner for the event that gives a sound its meaning.
Add an asset to the sound catalog, specify its bus/volume/loop policy, and
verify cold startup, repeated playback, unavailable-resource fallback, and
volume settings when the sound is first used.

## Worked authoring examples

One concrete "add one piece" workflow per content kind. These are the current
truthful paths; slices in [`authoring-system-plan.md`](authoring-system-plan.md)
replace them with data-only workflows.

### Example: add an enemy variant

Current steps:

1. Run `tools/dev.ps1 new enemy <id>` and edit the generated definition with
   its stable ID, stats, element, damage contract, `visual_source`, and
   encounter fields.
2. Run `tools/dev.ps1 verify`; the report should list the new ID and the
   validator should load every authored definition.
3. Run `tools/dev.ps1 preview enemy <id>` and
   `tools/dev.ps1 test -Suite content`. No registry list, central controller,
   scene roster, or test count should need editing.

Real example: `crimson` — a tanky Fire slime added as one catalog row with
`visual_source: "red"`, proven by `enemy_definition_slice_smoke`, the
save/load round-trip `enemy_definition_roundtrip_smoke`, and the normal-room
entrance smoke. Its original proof required parallel registry and controller
edits; the current migrated path no longer does.

The standalone one-file proof is `ember_guard`. It is discovered by the
registry, previewed through the factory, and covered by the registry-driven
slice, round-trip, encounter, boss, and room-entry checks without a central
runtime or per-variant test edit.

### Example: add a room difficulty/traffic policy

1. Edit `resources/definitions/room_definition.tres` (enemy cap, popcorn rates,
   boss support counts, treasure chance).
2. `RoomController` reads it through `_room_definition()` — no code change.
3. Add a curve assertion to `tests/room_definition_smoke.gd`.
4. Run `tools/validate_definitions.ps1`.

### Example: add an encounter policy

The encounter resource owns baseline/shadow policy and the enemy definitions
own variant-specific late/matchup eligibility. To add a late variant, edit its
typed catalog entry; do not add a rank gate or weight to `RoomController`.

1. Edit `resources/definitions/encounter_definition.tres` only for shared
   baseline/shadow policy, or edit the enemy definition for variant-specific
   eligibility.
2. `RoomController` reads the shared policy through `_encounter_definition()`
   and resolves variant entries through the typed catalog.
3. Run `tools/validate_definitions.ps1`, `tools/report_catalogs.ps1`, and the
   encounter/variant smoke tests.

### Example: add a reward/tuning change

1. Edit the relevant `resources/tuning/*.tres` value and the matching row in
   `docs/GAMEPLAY_TUNING.md`.
2. Add a focused test for the value's timing, geometry, persistence, or economy
   impact.
3. Run the focused check, then the curated gate.

### Example: add a generated-map policy

Current caveat: `first_orb_depth`, `first_special_depth`, and `primary_flames`
in `dungeon_generation_policy.tres` are validated but ignored; the generator
uses `dungeon_layout_generator.gd:31-32,50`. The candidate counts, risk-choice
band, vault cap, and route-advantage fields are read.

1. Edit `resources/definitions/dungeon_generation_policy.tres` for the fields
   the generator actually reads (see caveat).
2. `DungeonLayoutGenerator.policy()` reads it — no code change.
3. Add an assertion to `tests/dungeon_generation_policy_smoke.gd`.
4. Run `tools/validate_definitions.ps1` and the generated-run smoke.

## Authoring checklist

Before calling a content addition ready, record:

- stable ID and owning definition;
- authored/generated scope;
- player-facing contract;
- save and compatibility impact;
- runtime owner and presentation owner;
- validation and focused tests;
- native-resolution visual check where relevant; and
- any remaining manual, browser, touch, or performance verification.
