# Tiny Demons Content Authoring Guide

Status: working guide; current workflows are partly data-driven and partly
embedded in typed GDScript

Updated: 2026-09-11

Owner: the feature owner listed in [`FEATURE_MAP.md`](FEATURE_MAP.md). The
content guide describes current boundaries; it does not authorize a new data
framework or a gameplay balance change.

This guide answers the practical question: “Where should a new piece of Tiny
Demons content be added?” The safest current workflow is to identify the
stable ID and owning catalog or layout definition first, then add focused
verification before changing runtime orchestration.

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

- run layout definitions in `scripts/dungeon_layout_run*.gd`;
- map plans in `scripts/puzzle_map_r*.gd` and related layout scripts;
- compilation in `scripts/puzzle_map_layout_compiler.gd`;
- runtime topology in `scripts/dungeon_graph.gd` and
  `scripts/dungeon_map_controller.gd`; and
- room activation and persistence in `scripts/room_controller.gd`.

Workflow:

1. Define the run scope and whether its map is an authored pixel contract.
2. Assign stable room IDs, room types, sockets, arrival sockets, and gate
   requirements in the layout definition.
3. Keep map art, markers, room geometry, and doorway semantics aligned.
4. Validate socket pairing, room reachability, entrance geometry, and milestone
   ordering.
5. Add or update the run-specific contract test and inspect the rendered map at
   native 240×160.
6. Verify room entry, clear, revisit, chest/pickup claims, and save recovery.

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

Workflow:

1. Decide whether the addition is a visual variant, gameplay element, behavior
   variant, or a new actor class.
2. Give it a stable variant/element ID and record its visual-to-gameplay
   mapping.
3. Define stats, attack timing, body geometry, collision bounds, and any
   special room rules together.
4. Ensure spawn validation keeps the complete actor body inside usable
   walkable space and away from unreachable geometry.
5. Add variant, damage, placement, and engagement coverage as applicable.
6. Verify normal, scaled/boss, wall-adjacent, and attack-contact behavior.

Do not implement a new enemy only as a recolor if its combat identity differs.
Do not alter global tuning to solve a room-specific placement problem.

## Adding gear

Current owners:

- definitions and stable IDs: `scripts/item_catalog.gd`;
- serialized instance identity: `scripts/item_instance.gd`;
- equip/unequip state: `scripts/equipment_component.gd`;
- equipment presentation: `scripts/player_equipment_visual_component.gd`;
- acquisition rules: the shop, chest, drop, fusion, and settlement owners; and
- player-facing contracts: `gear-catalogue-spec.md`,
  `gear-effect-contracts.md`, and `gear-catalogue.md`.

Workflow:

1. Choose one of the six canonical slots: weapon, head, body, arm, shield, or
   accessory. Preserve the legacy `armor` compatibility key where required.
2. Add a stable base ID, display name, family, rarity behavior, source tags,
   stat lane, and effect status to the catalogue.
3. Decide whether the effect is active or `future`. A future effect may remain
   inspectable but must not enter live generation until its owner and action
   contract exist.
4. Confirm serialization, shop identity, exact sell identity, fusion identity,
   equip behavior, and visual fallback.
5. Add catalogue/schema coverage and an acquisition test if the item can enter
   a source pool.
6. Check the item at each supported rarity/enhancement path without changing
   unrelated balance.

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

Verify Gray/Normal collection, bound depletion, temporary fusion depletion,
pickup coloring, save/load at zero, and any relevant gate route. Do not fold a
new element into the player aspect state without an explicit mapping decision.

## Adding tuning

The intended tuning classes are `PlayerTuning`, `CombatTuning`, `SlimeTuning`,
`EffectsTuning`, `ChromaTuning`, and `ProgressionTuning`. In version `0.2.00`
they are instantiated in `gameplay_state.gd`; their exported fields are not yet
external `.tres` resources. Update [`GAMEPLAY_TUNING.md`](GAMEPLAY_TUNING.md)
and the relevant class together when adding a tuning value.

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

Menu work is currently a planned extraction boundary. Keep dynamic route state
and callbacks in the controller until a focused presenter has scene parity and
characterization coverage.

## Adding audio

Current owners are `sound_manager.gd` for loading, playback, channels, and mix
policy, and the feature owner for the event that gives a sound its meaning.
Add an asset to the sound catalog, specify its bus/volume/loop policy, and
verify cold startup, repeated playback, unavailable-resource fallback, and
volume settings when the sound is first used.

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
