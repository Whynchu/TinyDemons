# Tiny Demons — Timed Floor Spike Hazard Plan

Status: proposed plan (awaiting assignment)

Updated: 2026-09-27

Scope: a randomized, timed spike-floor hazard placed on room-edge tiles
(excluding tiles that connect to doors). It raises on a ~5 s cycle, damages the
player and enemies standing on it during its active frames, retracts, and is
avoided by enemy AI while still being reachable by knockback.

Owner: room/floor systems (`scripts/room_controller.gd`,
`scripts/gameplay_state.gd` room-layout path, plus a new hazard controller and a
new placement helper)

Current code: there is **no hazard/trap system** today (no `Area2D`, no hazard
script or resource). This plan adds one, reusing the isometric `TileMapLayer`
floor grid, the sprite frame-array animation idiom, and the existing
player/enemy damage entries.

Verification: focused fixtures in `tests/manifest.csv`, plus
`tools/dev.ps1 verify`, `tools/dev.ps1 test -Suite content`,
`tools/validate_definitions.ps1`, and an MCP playtest/screenshot at 240×160.
Do **not** run `tests/run_all_smoke.ps1` from an editor session
(`AGENTS.md` MCP-first rule).

Related: `docs/combat-and-dungeon-design-principles.md`,
`docs/ARCHITECTURE.md`, `docs/authoring-system-plan.md`.

## 0. Asset readiness — BLOCKER before any code

Observed: the two spike PNGs live in the **Godot-ignored** `Artwork/` folder
(`Artwork/.gdignore` exists, 0 bytes) and have **no `.import` sidecars**, so
`res://Artwork/environment/rooms/...` cannot load as a `Texture2D`.

- `Artwork/environment/rooms/Tile_spike_hazzard.png` — 16×16 (retracted/inactive). **Inferred**
  state, to confirm.
- `Artwork/environment/rooms/Tile_spike_hazzard_active_frame1-5dmg.png` — 128×16 = **8 slots of
  16×16** by pixel scan, despite the filename's "frame1-5".

Action: move both into `assets/artwork/` (the real runtime art folder; all other
art lives there) and let Godot generate `.import` sidecars. Confirm the intended
active-frame count and order (filename says 1–5; the sheet holds 8 slots).

## 1. Feature contract (acceptance criteria)

- Spike tiles appear on **room-edge floor tiles**, randomized per room, and
  **never on a tile that connects to a door/passage**.
- Each hazard cycles **retracted → active → retracted** on a ~5 s period.
- During the **active frames** it damages **any actor standing on the tile** —
  **player and enemies alike** — **at most once per cycle** (no per-frame
  multi-hit; there is no i-frame system to rely on).
- Enemies **avoid** hazard tiles when steering, but **knockback can still land
  them on** a hazard.
- Placement is **deterministic per room seed** (reload/continue reproduces it).
- Covers both authored (R1–R5) and generated (R6+) rooms; boss room handled
  explicitly.

## 2. Extension points (observed; cite before changing)

| Need | Existing mechanism | Cite |
| --- | --- | --- |
| Room activation / layout build | `GameplayState._ensure_current_room_layout` | `scripts/gameplay_state.gd:1284-1341` |
| Floor grid (isometric) | `TileMapLayer` layers in `main.tscn`, `tile_size = Vector2i(16,8)` | `main.tscn:121-137`; `scripts/isometric_room_layer.gd:50-61` |
| Used floor cells | `floor_layer.get_used_cells()` | `scripts/room_geometry_controller.gd:199` |
| Cell↔pixel | `TileMapLayer.map_to_local/local_to_map` (no custom helper) | `scripts/isometric_room_layer.gd` |
| Active doors / entrances | `RoomController.active_door_sockets` / `active_entrance_sockets` | `scripts/room_controller.gd:457-475` |
| Socket position + block tiles | `socket.spawn_marker()`, `socket.block_tiles()` | `scripts/dungeon_socket.gd:26-48` |
| Door-adjacency distance pattern | `RoomEnemyPlacement.is_enemy_spawn_near_socket` (rejects < 16 px) | `scripts/room_enemy_placement.gd:124-136` |
| Determinism precedent | `room_states[room_id].enemy_spawn_seed` | `scripts/room_controller.gd:166-167` |
| Builder template for placement | `room_enemy_placement.gd` (pure, samples walkable) | `scripts/room_enemy_placement.gd:10-90` |
| Enemy damage | `CombatRuntimeController.damage_slime_with_number` | `scripts/combat_runtime_controller.gd:86-90` |
| Player damage (inline, no shared fn) | blocks at `slime_actor.gd:243-317`; `:549-584` | `scripts/slime_actor.gd:243-317`; `scripts/combat_runtime_controller.gd:549-584` |
| Damage typing | `CombatDamageRequest.physical(base, scale, element, defense, ...)` | `scripts/combat_damage_request.gd:6-112`; resolver `scripts/combat_calculator.gd:98-137` |
| Per-frame sim hook | `_move_slimes(delta)` in the frame controller | `scripts/gameplay_frame_controller.gd:711-717` |
| Enemy steering danger | `SlimeBrain.context_steering_direction` | `scripts/slime_brain.gd:183-291` (integrate after `:233`) |
| Steering weights | `SlimeTuning` `steering_*_weight` | `scripts/slime_tuning.gd:50-52` |
| Regional point test precedent | `WalkableArea.is_in_entrance_block` | `scripts/walkable_area.gd:271-283` |
| Knockback (collision-checked) | `knockback_slime` → `try_knockback_slime` | `scripts/combat_runtime_controller.gd:359-390`; `scripts/slime_runtime_controller.gd:42-74` |
| Frame-array animation | `sprite_frame_library.slice_frames` + manual texture swap | `scripts/sprite_frame_library.gd:16`; `scripts/rest_fire_controller.gd:13-23` |
| Prop art precedent | `firepit.png` (16×16), `Fire.png` (96×16, 6 frames) | `main.tscn:305-316` |

## 3. Design decisions

1. **Hazard tiles are floor cells, computed at room build.** Add
   `scripts/room_hazard_placement.gd` (pure, mirroring `room_enemy_placement.gd`)
   that returns a cell list, invoked from
   `GameplayState._ensure_current_room_layout` (`gameplay_state.gd:1284-1341`)
   after `_collect_walkable_tiles`. Persist the chosen cells + seed in
   `room_controller.room_states[room_id]` for reload determinism
   (`room_controller.gd:166-167`).
2. **Runtime driver.** A small `floor_hazard_controller.gd` owns the hazard
   sprites and the raise/retract timer; tick it from the frame controller beside
   `_move_slimes` (`gameplay_frame_controller.gd:711-717`), delegated through
   `GameplayState` like `_move_slimes` (`gameplay_state.gd:1515-1518`).
3. **Hazards are NOT non-walkable.** Knockback (`try_knockback_slime`,
   `slime_runtime_controller.gd:48-51,70-72`) reverts onto non-walkable cells, so
   encoding hazards as non-walkable would make "knocked onto spikes" impossible.
   Enemies avoid them only via a **steering danger term**, not via walkability.
4. **Avoidance query** is a new `WalkableArea.is_hazard_at(point)` mirroring
   `is_in_entrance_block` (`walkable_area.gd:271-283`), populated during room
   build. Wire the danger term after `slime_brain.gd:233` using a new
   `steering_hazard_danger_weight` in `SlimeTuning` (`slime_tuning.gd:50-52`).
   Also reject hazard cells in `slime_wall_detour_target`
   (`slime_runtime_controller.gd:1020-1029`) and non-aggro target choice.
5. **One hit per cycle per actor.** There is no i-frame system for player or
   enemies, so each hazard keeps a `hit_this_cycle` set and clears it on cycle
   rollover. This is the only correct way to avoid per-frame multi-hit.
6. **Player damage needs a shared entry point.** Player damage today is inlined in
   two places (`slime_actor.gd:243-317`, `combat_runtime_controller.gd:549-584`)
   with no reusable function. Extract
   `CombatRuntimeController.damage_player(root, amount, element, source_pos, allow_guard)`
   first (mirroring `slime_actor.gd:266-317`: guard absorb, `health.apply_damage`,
   hitstun/flash, death pending). The hazard then calls that and
   `damage_slime_with_number` for enemies.
7. **Damage typing.** Use `CombatDamageRequest.physical(base, scale, element,
   defense_element, ...)` with `element = NEUTRAL` for a plain hazard so DEF and
   immunity apply. Seed `damage` (filename suggests 5) and `period` in tuning,
   not code.

## 4. Placement algorithm (room-edge, door-excluded)

1. `cells := floor_layer.get_used_cells()` for the active room's floor layer.
2. Edge cells: keep cells where any 4-neighbour in iso cell space
   `(±1,0)/(0,±1)` is not used.
3. Exclude door-adjacent cells: from
   `room_controller.active_door_sockets` + `active_entrance_sockets`
   (`room_controller.gd:457-475`), take each socket's `spawn_marker().global_position`
   (`dungeon_socket.gd:42-48`) and each `block_tiles()` cell, convert to cell via
   `floor_layer.local_to_map(floor_layer.to_local(p))`, and reject cells within a
   configured radius (reuse the `< 16 px` distance pattern,
   `room_enemy_placement.gd:124-136`).
4. Randomize a subset from the remaining edge cells using the room seed
   (deterministic); cap per room to keep readability.
5. Convert cells to pixels with `floor_layer.map_to_local(cell)` / `to_global`;
   align to the same transform as the floor tile art and verify overlap visually.
6. Skip or explicitly handle `ROOM_DOWNSTAIRS` (boss geometry is swapped in and
   larger).

## 5. State machine and timing

- States: `RETRACTED` → `EXTENDING` (play active frame strip) → `ACTIVE`
  (damage window; filename implies frames 1–5 deal damage) → `RETRACTED`.
- Period ~5 s (tuning); active window is the frame strip's duration
  (`frame_count * frame_time`), rest is the remainder.
- On entering `ACTIVE`: for each actor whose foot point is inside the hazard
  cell polygon (`tile_top_polygon` diamond, `slime_runtime_controller.gd:1177`)
  and not already in `hit_this_cycle`, apply once.
- Optional telegraph: if a "rising/warning" frame exists, play it before the
  damaging frames so the hazard is readable.

## 6. Implementation phases

**Phase 0 — asset prep (external)**
- Move both PNGs to `assets/artwork/`; import; confirm active-frame count/order.

**Phase 1 — placement + rendering (no damage)**
- `room_hazard_placement.gd` (pure, unit-testable) + call site in
  `_ensure_current_room_layout`.
- `floor_hazard_controller.gd` spawning aligned `Sprite2D` hazard tiles under a
  dedicated layer; retracted texture by default.
- Fixture: edge cells chosen, door-adjacent cells excluded, deterministic per seed.

**Phase 2 — timing + animation**
- Raise/retract state machine with `slice_frames` active strip and manual
  texture swap (idiom: `rest_fire_controller.gd:13-23`).
- Fixture: one full cycle; correct frame order; retracts on schedule.

**Phase 3 — damage (both sides)**
- Pre-req: extract `CombatRuntimeController.damage_player(...)`.
- Hazard applies one hit per actor per cycle during active frames; player and
  enemies. Fixture: standing enemy and standing player each take exactly one hit
  per cycle; a second cycle re-hits.

**Phase 4 — AI avoidance**
- `WalkableArea.is_hazard_at` + `steering_hazard_danger_weight`; danger term in
  `context_steering_direction`; detour/non-aggro rejection.
- Fixture: an aggroed slime prefers a path off hazard cells; knockback can still
  push a slime onto a hazard cell.

**Phase 5 — verification + docs**
- Register fixtures in `tests/manifest.csv`; run `dev.ps1 verify` +
  `dev.ps1 test -Suite content`; MCP playtest/screenshot at 240×160.

## 7. Tuning / data contract

Add to a hazard tuning resource (mirroring `SlimeTuning`'s data-authorable
pattern, `resources/tuning/`), not code constants:

- `period_seconds` (~5.0), `active_frame_time`, `active_frame_count`,
- `damage` (seed 5), `damage_element` (NEUTRAL), `door_exclusion_radius`,
  `max_hazards_per_room`, `steering_hazard_danger_weight`.

## 8. Risks and open decisions

- **Asset blocker:** art is in a `.gdignore` folder with no `.import`; must be
  relocated before any rendering work.
- **Frame-count discrepancy:** filename says frames 1–5; the sheet is 8 slots.
  Confirm the intended active strip and whether frame 1 is a telegraph.
- **"5dmg":** confirm it means 5 damage (not "frames 1–5 damage").
- **No i-frames:** the per-cycle fired-set is mandatory, not optional.
- **Player damage refactor** (extraction) is a prerequisite; keep it behavior-
  preserving and covered before wiring the hazard.
- **Fixed footprint:** all non-boss rooms share the same floor cells, so "edge"
  tiles are identical each room — variety comes from the randomized subset, not
  from different geometry. Confirm that is acceptable.
- **Boss room:** geometry is swapped and larger; decide skip vs support.
- **Coordination:** codex holds `scripts/enemy_preview_workbench.gd`,
  `docs/authoring-system-plan.md`, `docs/KNOWN_ISSUES.md`; room/enemy methods may
  also be touched by in-flight slime work — re-check `coord/BOARD.md` before
  editing `slime_brain.gd` / `slime_runtime_controller.gd`.

## 9. Independent verification expectations

- Focused fixtures in `tests/manifest.csv` (role `owner`).
- `tools/dev.ps1 verify`, `tools/dev.ps1 test -Suite content`,
  `tools/validate_definitions.ps1`.
- MCP playtest + native 240×160 screenshot for readability (telegraph clarity).
- No edits to `GameplayState` coordinators beyond the documented hook, the
  release gate, or count-pinned tests.
