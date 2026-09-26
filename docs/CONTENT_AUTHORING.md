# Tiny Demons Content Authoring Guide

Status: working guide; enemy definitions and encounter eligibility now use the
typed catalog/factory path, including standalone one-file definitions and the
enemy preview workbench. The authored Hub world now has a standalone animated
design preview; other content surfaces are still only partially wired. Read
the trap table below before editing any `.tres`.

Updated: 2026-09-26

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

Measured 2026-09-22 (version `0.2.72`). Until the listed slice in
[`authoring-system-plan.md`](authoring-system-plan.md) lands, these paths are
traps:

| Authored data | Current runtime behavior | Owner slice |
|---|---|---|
| `dungeon_generation_policy.tres`: `first_orb_depth`, `first_special_depth`, `primary_flames` | Ignored. The generator uses `dungeon_layout_generator.gd:31-32,50`. | 3 |
| Former `resources/definitions/puzzle_map_r3.tres` path | Removed in Slice 0; the runtime and preview use `puzzle_map_r3_new.tres`. | resolved |
| Retired `item_catalog.tres` expansion records | Removed in the schema-14 catalog cleanup; current baseline/set data and standalone `ItemDefinition` resources remain. | resolved |
| Item `visual_id` | Written but never read; item art is slot-level only. | 2 |
| `element_catalog.tres` and `palette_library.tres` | Both are included in recursive validation and read by their runtime catalogs; element identity still spans parallel enums/adapters, and typed consolidation remains Slice 2 work. | 2 |

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

## Viewing the Hub world in the editor

The production Hub world is currently embedded in `scenes/main.tscn` because
the runtime reuses its room shell for dungeon transitions. Opening `main.tscn`
is therefore not the normal authoring view: the root gameplay script is a
runtime bootstrap, the title route hides the world, and the generated Hub stone
accent layer waits for room-entry wiring.

Open `scenes/hub_world_preview.tscn` for the design view instead. It reuses the
same main-world composition without loading a profile or starting a run, shows
the authored map, Hub actors, doors, fire, chest, and stone accents, and hides
the pooled dungeon enemies, HUD, and collision/debug guides by default. The
Inspector controls are:

- `animate_preview` — step the existing fire, cloaked-NPC, and player idle
  frames in the editor;
- `show_collision_guides` — reveal the authored alignment guides when tuning
  geometry; and
- `show_hud` — include the runtime HUD when inspecting its composition.

Under `Player Presentation`, `player_element` controls the player palette,
eye-highlight correction, and preview flame palette; it defaults to Water. The
player is now an authored
placement root with its artwork, attack layer, shadow, collision guides,
runtime components, and editor metadata grouped beneath it. Select
`Main/Actors/Characters/PlayerPlacement` and drag that root in the 2D viewport. Save
`hub_world_preview.tscn` to preserve that local position override without
changing the runtime `main.tscn` source. The root exposes a stable
`placement_id` and authoring category in the Inspector; this is the first
vertical slice of the planned layered prefab workflow.

These preview controls are live editor controls: changing `player_element`,
`show_hud`, or `show_collision_guides` refreshes the rendered scene as soon as
the preview node is ready. No manual method call or scene restart is required;
`refresh_preview` remains available as an explicit reapply button when a
producer has changed source artwork or another authored dependency.

The Hub composition now exposes the same grouping boundary around the rest of
the authored scene: `Main/Map` is the Environment root,
`Main/Actors/Props` groups the fire and chest, and
`Main/Actors/Characters` groups the NPC, player placement, and their shadows.
Move a group root to reposition the complete subtree, or select an individual
placement such as `Main/Actors/Props/Chest` when only one authored object
needs adjustment. The pooled slime slots remain runtime-owned children of
`Actors` and are intentionally hidden from the normal Hub design view.

The agent-friendly equivalent is `pwsh -File tools/dev.ps1 preview hub`; add
`-Editor` to open the same scene directly in Godot.

When the project plugin is enabled, the `Tiny Demons Authoring` dock appears in
the editor's right dock. It lists every `PlacementRoot2D` in the open scene by
category, stable ID, and scene path. Selecting an entry selects the real node in
the editor; `Open Hub Preview` and `Refresh` keep the common workflow visible
without replacing Godot's native Inspector or undo/redo behavior. The current
placement actions are deliberately narrow: `Create` can add an empty placement
or a `PlayerPlacement` prefab under the selected authoring layer, `Duplicate`
creates fresh IDs for a placement subtree through the editor undo/redo stack,
and `Validate` reports missing, malformed, duplicate, or unsupported placement
metadata. The dock is not yet a generic enemy/gear/level factory; those typed
content operations remain planned domain work rather than guessed scene
mutations.
After creating or duplicating content, save the edited scene with Godot's normal
save command; the dock intentionally leaves save timing and version-control
review in the producer's hands.

This is the safe design-preview tier. It is not yet the interactive Hub
workbench: use the normal game for progression, save, input, and room-entry
behavior until that isolated workbench lands in the authoring plan.

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

1. Decide whether this is a variant of an existing enemy family or a new
   family. The authored Slime entries use `type_id = slime`; Skeleton is the
   first separate family and uses `type_id = skeleton`. New families still
   need an actor route in `EnemyFactory`; changing a variant's `type_id` alone
   does not create a new enemy.
2. Create one standalone variant definition with
   `pwsh -File tools/dev.ps1 new variant <id>`; this writes
   `resources/definitions/<id>.tres`. Existing embedded catalog entries in
   `slime_variant_catalog.tres` remain valid, but new content should use the
   one-file path. Set `id` to the stable variant ID and `type_id` to the owning
   family (`slime` for Slime variants; `skeleton` for Skeleton entries),
   then author the element, display name, `base_stats`, `growth_weights`,
   `damage_contract`, and explicit `visual_source`. The resource keeps the
   serialized property name `id`; code and the workbench also expose it as
   `variant_id`. `visual_source` is a palette ID (for example `grey`), and the
   workbench selector and runtime renderer resolve that same field.
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
   `visual_source` is data-only; invalid palette IDs fail enemy-definition
   validation.
6. Run `pwsh -File tools/dev.ps1 verify`, then preview the definition with
   `pwsh -File tools/dev.ps1 preview enemy <id>` and run
   `pwsh -File tools/dev.ps1 test -Suite content`. Verify normal, scaled/boss,
   wall-adjacent, and attack-contact behavior when the content is intended for
   those paths.

The enemy-specific one-file discovery and preview workbench are now landed.
The generic `ContentDefinition`/`ContentRegistry` layer remains future work;
the current enemy path already removes the old parallel registries and central
encounter branches.

Open `scenes/enemy_preview_workbench.tscn` for the enemy design preview, or run
`pwsh -File tools/dev.ps1 preview enemy <id> -Editor` to open a selected enemy.
In the workbench Inspector, `Enemy` selects the actor family (`Slime` or
`Skeleton`) and `Variant` selects an authored entry from that family.
Variant picker labels omit the redundant family name and stable ID, so the
choices read `Normal`, `Fire`, `Guard`, and so on. `Selected Variant ID` shows
the stable ID. The picker adds an ID only if two variants in one family share
a display name. `Ember Guard` keeps its authored name. `Selected Type ID` shows
its actor family (`slime`), and `Selected Enemy Name` shows its friendly name.
Slime entries use the `slime` type and share the Slime actor implementation.
Skeleton has its own factory actor route and authored idle, walk, attack, and
between-attack sheets. Its attack throws the authored four-frame bone projectile.
Skeleton variants are `skeleton` (Neutral), `skeleton_fire`, `skeleton_water`,
`skeleton_electric`, `skeleton_grass`, `skeleton_shadow`, `skeleton_ground`,
and `skeleton_ice`. Elemental variants share the Skeleton art and use the
elemental damage contract. Normal Slime encounter rolls filter by `type_id`,
so these definitions cannot enter the Slime pool accidentally.

For a live gameplay check, select the `Main` root in `scenes/main.tscn`, set
`debug_enemy_test_id` to `skeleton` (or an elemental Skeleton ID) in the
Inspector, save the scene, then start or continue a run and enter an encounter.
The Output panel confirms the resolved ID; the override forces encounter slots
to use that definition and its actor family. Setting the ID alone does not skip
the title. To start directly in a boss room, enable `debug_start_in_boss_room`
as well; the debug encounter keeps the Skeleton at normal size. Clear
`debug_enemy_test_id` when finished to restore normal room generation. This
local debug override does not change encounter weights.

The workbench preview displays the Skeleton's authored frames with geometry
guides enabled by default. `Geometry Guides` and its visible-overlay options
toggle collision, body, and attack guides; the selected guide can be dragged in
the preview and saved to the enemy definition. For live positioning checks,
`debug_actor_geometry` draws the actor foot anchor, collision bounds, and body
hitbox in gameplay.

To add a Slime
variant, select
the closest existing variant, enter a
lowercase variant ID under `Add Variant`, and click `Create Variant from
Selected`. The workbench copies that variant's stats, geometry, palette, and
encounter settings into a new standalone definition, derives its initial name
from the ID, and selects it for editing. The Inspector presents the selected
definition as editable sections instead of exposing its raw dictionaries and
polygon arrays:

- `Identity & Appearance`: display name, element, damage type, and appearance
  palette.
- `Combat & Growth`: starting values for all six stats, followed by each stat's
  growth weight per level.
- `Encounter`: spawn role, weight, minimum rank, matchup and preference weights,
  and whether preferred selection is allowed.
- `Preview`: animation state, facing, actor scale, playback, and frame timing.
- `Geometry Guides`: independent guide visibility and a viewport edit target.
- `Save & Validation`: current edit/validation status and the save action.

The separate `Add Enemy Family` section marks the family boundary. The
workbench can create variants for a registered family; a new runtime family
still needs a family definition and a supported actor route in `EnemyFactory`
before it can be previewed or spawned. Skeleton is the current second family
proof. The family workflow remains: create the family (stable ID, display name,
actor route), create its first variant from that family, and add sibling
variants as needed.

Edits appear in the preview as you make them. The workbench marks unsaved edits
and blocks enemy switching or creation until you save. Click `Save Enemy
Changes` to write the owning resource: standalone definitions save to their own
`.tres`, while embedded catalog definitions save through
`slime_variant_catalog.tres`. The variant ID is the stable identity used by
the current catalog and runtime compatibility paths. Keep it stable after
content is referenced; create a new variant ID for a distinct entry. The type ID
selects the actor family and must match a supported family (`slime` or
`skeleton` at present).

In `Geometry Guides`, enable the overlay you want, then choose the target under
`Edit in Preview`. Drag polygon vertices or drag inside a rectangle to move it;
drag a rectangle corner to resize. Edits snap to half-pixels. Undo, redo, and
reset operate on canvas edits to the selected guide; other Inspector edits use
Godot's regular undo history. These fields live on the selected
`EnemyDefinition`; `EnemyFactory` applies the same authored geometry to this
preview and to runtime actors.
Definition validation rejects polygons with infinite or NaN coordinates,
zero area, or self-intersections, and rectangles with zero or negative sizes.

The other buttons pause/resume, step one frame, restart the selected state, and
refresh the preview and catalog. Idle breathing and move squish are
presentation-only; the preview uses the enemy factory and shared slime frame
builders but does not run AI or combat. The sprite is positioned inside the
project's 240-by-160 preview canvas. Boss jump/slam sheets require `Boss actor`
preview size. Death currently has no authored slime frame sequence and remains
an effect-preview gap. Automatic asset reimport refresh and the isolated
interactive workbench remain open M1 work.

Do not implement a new enemy only as a recolor if its combat identity differs.
Do not alter global tuning to solve a room-specific placement problem.

## Adding gear

Current owners:

- live baseline/set definitions and retained metadata:
  `resources/definitions/item_catalog.tres` (`ItemCatalogData`), loaded by
  `scripts/item_catalog.gd`;
- new standalone definitions: `resources/definitions/items/*.tres`
  (`ItemDefinition`), discovered by the same catalog registry;
- serialized instance identity: `scripts/item_instance.gd`;
- equip/unequip state: `scripts/equipment_component.gd`;
- equipment presentation: `scripts/player_equipment_visual_component.gd`;
- acquisition rules: the shop, chest, drop, fusion, and settlement owners; and
- player-facing contracts: `gear-catalogue-spec.md`,
  `gear-effect-contracts.md`, and `gear-catalogue.md`.

Workflow (current, during Slice 2 migration):

1. Choose one of the six canonical slots: weapon, head, body, arm, shield, or
   accessory. Preserve the legacy `armor` compatibility key where required.
2. For a new live item, run `pwsh -File tools/dev.ps1 new item <id>` and edit
   the generated `resources/definitions/items/<id>.tres`, or select a typed seed
   in the workbench and use `Create Item from Selected`. Set the stable ID,
   display name, slot, tier/stat, bonuses, source tags, rarity gates, and any
   effect status on that one typed resource.
3. Do not edit `item_catalog.tres`, `live_base_ids`, `definition_metadata`,
   `SET_IDS`, or a count-pinned test for a standalone item. The registry
   discovers the resource, converts it through the compatibility boundary, and
   exposes it to live generation.
4. Run `pwsh -File tools/dev.ps1 test -Suite content` and
   `pwsh -File tools/dev.ps1 verify`. The validator checks every standalone
   `ItemDefinition`, the report lists its ID, and the registry smoke covers
   validation plus stable-ID save round-trip.
5. Run `pwsh -File tools/dev.ps1 preview item <id>` and inspect each supported
   rarity/enhancement path in the workbench without changing unrelated balance.
   Remaining live baseline/set data consolidation is still Slice 2 work.

Known traps: `visual_id` is never read (item art is slot-level), `demon_cloak`
has a special acquisition/equip rule in `player_profile.gd`, `run_state.gd`,
`equipment_component.gd`, and `hub_flow_controller.gd`. Live baseline/set data
still uses dictionaries and set synthesis still lives in `item_catalog.gd`, but
the retired expansion definitions and their transmutation bindings are purged.
Schema-14 profile loading removes saved instances of those retired IDs and
restores starter equipment for slots they left empty. Standalone
`ItemDefinition` resources use the same catalog path and validator. The design
workbench covers typed editing and card/drop/instance/effect previews;
per-item visual ownership and full catalog conversion remain unfinished.

Open `scenes/item_preview_workbench.tscn` to browse the item design preview, or
run `pwsh -File tools/dev.ps1 preview item <id> -Editor` to open a selected item.
The `Item` picker uses `ItemCatalog.playable_definition_ids()`: current
baseline/set items, standalone live `ItemDefinition` resources, and special-
source items such as Demon Cloak. Retired expansion records are deleted and
cannot be selected. Catalog-owned baseline/set entries are preview-only;
standalone `ItemDefinition` resources can be edited, duplicated with `Create
Item from Selected`, or saved with `Save Item Changes`.
`Preview` selects Card, Drop, Instance, or Effects;
rarity, enhancement, seed, and transmutation controls configure a temporary
preview instance. The preview uses `ItemCatalog` calculations and does not change
profile or gameplay state. Item drop art still resolves by slot; `visual_id` is
shown for authoring but is not yet an item-specific art reference. The headless
check is `pwsh -File tools/dev.ps1 preview item <id>`.

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
truthful paths; later slices extend the same contracts to the remaining legacy
surfaces.

### Example: add an enemy variant

Current steps:

1. Run `tools/dev.ps1 new variant <id>` and edit the generated definition with
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

### Example: add a weapon

1. Run `tools/dev.ps1 new item <id>` and edit the generated
   `resources/definitions/items/<id>.tres` with its slot, stat package, source
   tags, rarity gates, and description.
2. Run `tools/dev.ps1 test -Suite content`; the item registry smoke validates
   every standalone item and checks stable-ID save round-trips.
3. Run `tools/dev.ps1 verify`; the catalog report should list the item and no
   legacy catalog, central runtime, or per-item test edit should be needed.

The concrete proof is `cinder_blade.tres`: it is a live weapon with no edit to
`item_catalog.tres`, and the existing gear contracts continue to pass after its
addition. Item card/drop preview and full legacy catalogue migration remain
open Slice 2 work.

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
