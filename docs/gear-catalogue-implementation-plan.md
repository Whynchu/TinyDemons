# Tiny Demons — Gear Catalogue Expansion Implementation Plan

## Status

**Implementation checkpoint — Phases 0–5 are landed; Phase 6 remains gated.**
This plan follows [`gear-catalogue-spec.md`](gear-catalogue-spec.md) and does
not authorize future weapon families or passive effects that lack an action
contract. Runtime generation excludes authored rows whose effect metadata is
still marked `future`, while the complete 44-row catalogue remains inspectable.

| Phase | Current state | Evidence |
| --- | --- | --- |
| 0 — Documentation/data audit | Complete | Four catalogue companion docs and 44-row schema audit |
| 1 — Slot/save compatibility | Complete | Canonical six slots, Armor alias, starter Head/Arm, schema migration smoke |
| 2 — Shared catalogue schema | Complete | Authored metadata, deterministic generation, fail-closed definitions |
| 3 — Equipment/menu flow | Complete | Six-slot Equipment, direct picker flow, shared snapshot previews, Pause read-only routes |
| 4 — Catalogue content | Complete for authored data | All 44 rows exist; future-effect rows are intentionally runtime-gated |
| 5 — Drops/shop/fusion | Complete for current contracts | Source tags, missing-slot priority, clear anti-repeat history, six-option shop |
| 6 — Effect hooks/balance | Pending by design | Existing effects remain active; future action/elemental contracts need their owner and tuning tests |

## Objective

Expand the current four-slot runtime into the approved six-slot equipment
system, document and author 44 item bases, and connect them to the existing
stat snapshot, menu, drop, shop, fusion, and save boundaries without creating
a second progression formula.

## Phase 0 — Documentation and data audit

1. Treat `gear-catalogue-spec.md`, `gear-catalogue.md`,
   `gear-effect-contracts.md`, and `gear-drop-tables.md` as the design source
   of truth.
2. Reconcile every current definition with a catalogue row.
3. Mark each proposed effect as existing, extension work, or future-only.
4. Simulate a full six-slot loadout using current rarity/enhancement rules.
5. Decide final numerical packages only after the power-budget report.

Exit: no item row lacks an owner, source, effect contract, or migration note.

## Phase 1 — Slot and save compatibility

1. Add canonical `head`, `body`, and `arm` slot keys while reading legacy
   `armor` as Body.
2. Add zero-power `plain_hood` and `cloth_wraps` starter definitions.
3. Migrate `equipped_instance_ids["armor"]` to `body` without changing the
   instance ID.
4. Preserve old `armor_name`, `speed`, and `SPD` readers during the transition.
5. Add profile migration tests for old and new inventory shapes.

Exit: existing saves load with no lost item, allocation, currency, or equipped
state; new profiles show all six slots.

## Phase 2 — Shared catalogue schema

1. Extend the authored definition record with family, role, primary stat,
   source tags, progression gates, effect IDs, and visual IDs.
2. Keep `ItemInstance` compact and persist only stable IDs/values.
3. Replace name-based special cases with explicit effect/transmutation IDs.
4. Make invalid or unavailable definitions fail safely at the catalog boundary.
5. Preserve deterministic generation from a source seed.

Exit: an item can be generated, serialized, loaded, inspected, and compared
without reconstructing hidden behavior from its display name.

## Phase 3 — Six-slot equipment and menu flow

1. Extend `EquipmentComponent` and the shared snapshot to include Head and Arm
   contributions.
2. Rename the player-facing Armor slot to Body while retaining compatibility.
3. Update equipment visuals only where actual Head/Arm art exists; do not
   invent a new layered sprite contract as part of the data migration.
4. Update the FFIII-style Equipment screen to show six slots, current gear in
   the upper region, selectable items in the lower region, and comparison text
   in the bottom strip.
5. Make EQUIP enter item selection directly and keep only the active route’s
   input enabled.
6. Update Status, Shop, Fusion, and read-only Pause Equipment routes.

Exit: controller, keyboard, mouse, and touch can inspect and equip every legal
slot with no overlap, duplicate back prompts, or hidden input route.

## Phase 4 — Catalogue content batches

Implement the 44 rows in small batches:

1. Starter compatibility and existing 20 definitions.
2. Head and Arm foundations.
3. Body and Shield expansions.
4. Weapon and Accessory expansions.
5. Elemental resonance/ward candidates only after their contracts exist.

Every batch must include:

- definition data;
- player-facing description;
- comparison output;
- source tags and rarity gates;
- save/load coverage;
- snapshot/combat preview parity; and
- a focused smoke test.

Exit: every implemented item has an observable, tested identity and no
unsupported future family has entered the drop pool.

## Phase 5 — Drop, shop, and fusion integration

1. Replace four-slot assumptions in chest, run-clear, shop, and starter loops.
2. Add missing-slot protection for Head and Arm.
3. Add deterministic anti-repeat slot selection for run-clear rewards.
4. Keep the current identified world-drop and settlement boundaries.
5. Verify shop pagination/grouping at all supported menu widths.
6. Preserve matching-definition/matching-rarity fusion and overflow salvage.

Exit: every slot can be acquired through an intentional source, duplicates
remain useful, and the inventory is not flooded by normal enemy drops.

## Phase 6 — Effect hooks and balance

1. Add only effects with an approved contract.
2. Route Imbue Resonance through the existing STR/INT composite request.
3. Add Elemental Ward only after its full-packet order and tests are explicit.
4. Keep Style and run grade player-action driven.
5. Run level-one, early, mid, and high-level target-build simulations.
6. Tune resources and item values without changing formulas in menu code.

Exit: six-slot builds are distinct but starter combat remains viable; no
attribute becomes mandatory and no accessory becomes a universal multiplier.

## File ownership map

| Concern | Owner |
| --- | --- |
| Authored definitions and generation | `scripts/item_catalog.gd` or a split catalog data owner |
| Persistent item instances | `scripts/item_instance.gd`, `scripts/player_profile.gd` |
| Equipped flat/rate snapshot | `scripts/equipment_component.gd`, `scripts/combat_stat_snapshot.gd` |
| Derived combat values | `scripts/combat_calculator.gd` |
| Behavioral effects | `scripts/equipment_transmutation_component.gd` or narrow effect owners |
| Drop/source selection | `scripts/run_flow_controller.gd`, `scripts/run_state.gd`, chest/pickup controllers |
| Shop/fusion mutation | `PlayerProfile` and hub/progression domain boundary |
| Equipment presentation | `scripts/screen_state_controller.gd` until a narrower presenter is extracted |
| Save compatibility | `scripts/player_profile.gd`, `scripts/profile_save_service.gd` |
| Balance index | `docs/GAMEPLAY_TUNING.md` and the catalogue documents |

New behavior belongs to the narrowest owner. `gameplay.gd` may orchestrate a
catalogue request but must not become the item database or formula owner.

## Verification matrix

| Area | Required coverage |
| --- | --- |
| Slot migration | Armor-to-Body alias, new Head/Arm keys, invalid IDs |
| Catalogue schema | Every row has a valid slot/family/primary/source contract |
| Snapshot | Six-slot flat-before-rate math and preview parity |
| Derived stats | HP, P.ATK, M.ATK, P.DEF, M.DEF, Move, Recovery |
| Composite damage | Imbue STR/INT portions, DEF/M.DEF, one full-packet matchup |
| Equipment UI | Six slots, direct Equip flow, comparison and descriptions |
| Drop sources | Chest, clear reward, shop, missing-slot priority, deterministic seeds |
| Fusion | Same definition/rarity only, equipped-material protection, overflow |
| Persistence | Save/load retains all item instance fields and equipped state |
| Input/display | Controller/keyboard/touch and 3:2/16:10/16:9/FULL layouts |
| Economy | No direct Souls/gold/drop-rate multiplier from initial gear |

## Explicit non-goals

- Implementing every FFIII weapon family in this slice.
- Adding a second Accessory, Relic, or Core slot.
- Reintroducing random primary affixes.
- Adding a new currency to support gear.
- Making gear award Style or replace player skill.
- Letting an elemental weapon override the starter/bound flame.
- Rewriting the existing Imbue or elemental-slime contracts without a separate
  balance review.
