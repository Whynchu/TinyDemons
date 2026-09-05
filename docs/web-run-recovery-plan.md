# Web Restart Diagnosis and Run Recovery

## Goal

Mobile browser restarts may show the Godot loader during an active run. Tiny
Demons must preserve progress through the last safely completed room, explain
the restart through durable diagnostics, and offer an explicit resume or
discard choice when the game starts again.

This plan uses the current runtime boundaries. It does not put save rules in
`gameplay.gd`, duplicate room-state formats, or mix active-run data into the
permanent `PlayerProfile` schema.

## Current architecture and required changes

| Concern | Current owner | Required change |
| --- | --- | --- |
| Permanent profile | `profile_save_service.gd` | Reuse its atomic file and web mirror pattern, but keep run data separate |
| Web lifecycle | `gameplay.gd` | Forward lifecycle events to narrow diagnostics/checkpoint owners |
| Run identity and metrics | `run_state.gd` | Add complete versioned dictionary round trips |
| Dungeon topology | `dungeon_graph.gd`, `dungeon_map_controller.gd` | Rebuild from seed, then restore progression through public methods |
| Room contents | `room_controller.gd` | Serialize the existing `room_states`; do not create another format |
| Active runtime | `gameplay_state.gd` | Assemble checkpoints and restore runtime state |
| Run lifecycle | `run_flow_controller.gd` | Clear checkpoints on new run, settlement, and abandonment |
| Continue flow | `save_flow_controller.gd`, `screen_state_controller.gd` | Add resume/discard after profile selection |

The current lifecycle callback saves only `PlayerProfile`. `RunState`, dungeon
progression, room states, and the current room are memory-only and disappear
when the web runtime restarts.

## Recovery contract

### Safe checkpoint boundary

A checkpoint represents the start of the next room after the previous room and
its rewards are fully committed. The fixed transaction order is:

1. Finish the objective and commit rewards/profile mutations.
2. Run the existing `_save_current_room_state()` for the departing room.
3. Complete the connected-room transition and choose a safe arrival point.
4. Apply the destination room's saved/default state.
5. Save `PlayerProfile`.
6. Assemble and atomically write the active-run checkpoint.

If the browser dies before step 6, the previous checkpoint remains valid. If it
dies after step 6, recovery starts in the new room. Mid-combat snapshots are
never created.

### Snapshot schema

Create a schema-versioned `ActiveRunSnapshot` containing:

```text
schema_version, profile_slot, profile_identity, created_at,
run_state, dungeon_seed, run_rank,
current_room_id, current_room_type, current_room_depth, arrival_socket_id,
room_states, map_state,
player_health, player_chroma_state, player_facing_left,
starter_flame_attuned_this_run
```

Do not store transient animation/input timers, attack frames, cursors, live
projectiles, or raw player world position. Recovery places the player at the
room's safe arrival socket. Normalize `StringName`, `Vector2`, and typed values
to JSON-safe primitives at this boundary.

## Implementation sequence

### Phase 1 — Complete durable diagnostics

Owner: `web_run_diagnostics.gd`; bootstrap wiring only in `gameplay.gd`.

1. Retain the implemented bounded `localStorage` lifecycle ring.
2. Add checkpoint time/room, game version, viewport, orientation, and user-agent
   summary to records.
3. Attach context-loss listeners to the actual Godot canvas.
4. Deduplicate browser listeners across scene reloads.
5. Add read/copy/clear helpers through a debug-only surface.

Gate: each simulated lifecycle event creates exactly one durable record;
desktop startup creates none.

### Phase 2 — Add pure serialization contracts

Owners: `run_state.gd` and new `active_run_snapshot.gd`.

1. Add `RunState.to_dictionary()` and `RunState.from_dictionary()` for every
   owned field, including shop sold state, metrics, completion sets, and reward
   telemetry.
2. Add snapshot creation, JSON normalization, parsing, and validation.
3. Reject future schemas, mismatched profile/run identity, settled runs, unknown
   rooms, and malformed room-state collections.
4. Keep these value objects free of filesystem and scene mutations.

Gate: representative run and room data survive JSON round trips exactly.

### Phase 3 — Add the active-run save service

Owner: new `active_run_save_service.gd`, parallel to
`profile_save_service.gd`.

1. Store one checkpoint per profile slot at
   `user://tiny_demons_active_run_<slot>.json`.
2. Use temp file, validation, backup, and atomic rename ordering.
3. Mirror valid JSON synchronously to slot-specific web `localStorage`.
4. Load the newest valid local/web copy.
5. Expose only `save`, `load`, `has_valid`, `clear`, and
   `quarantine_invalid`.
6. Preserve invalid data for diagnostics instead of silently deleting it.

Gate: interrupted writes recover, slots cannot cross, and future schemas are
retained but never applied.

### Phase 4 — Commit safe checkpoints

Owners: `gameplay_state.gd` and `run_flow_controller.gd`.

1. Add `_save_active_run_checkpoint()` to `gameplay_state.gd`.
2. Call it after destination-room state application, in the transaction order
   above.
3. Update diagnostics only after a successful checkpoint write.
4. On page hide, flush the last assembled safe snapshot; never assemble a new
   mid-combat snapshot.
5. Clear the checkpoint on explicit new run, successful settlement, defeat
   finalization, abandonment, and profile deletion.
6. Keep `gameplay.gd` limited to forwarding lifecycle requests.

Gate: forced termination before/after writes restores only a fully committed
room and never duplicates rewards.

### Phase 5 — Restore deterministically

Owners: `save_flow_controller.gd`, `run_flow_controller.gd`,
`gameplay_state.gd`, and existing dungeon owners.

Restore in this exact order:

1. Load and validate the selected profile.
2. Load the matching run snapshot.
3. Rebuild through `dungeon_map_controller.begin_run()` using saved seed/rank
   and flame identities.
4. Confirm the rebuilt graph contains the checkpoint room.
5. Restore `RunState`, then `RoomController.room_states`.
6. Restore map discovery/completion through public map-controller methods.
7. Set room metadata, ensure/apply its layout, and place the player at the safe
   arrival socket (canonical room entrance as fallback).
8. Restore health, Chroma, facing, and starter-flame state.
9. Reset combat, projectiles, animations, input edges, and transition locks.
10. Write a fresh checkpoint after successful restoration.

On failure, preserve the snapshot, return to title, and show an error. Never
silently start a fresh run.

Gate: repeated restore is idempotent and creates no duplicate entities,
rewards, or progression.

### Phase 6 — Add resume/discard UI

Owners: `save_flow_controller.gd` and `screen_state_controller.gd`.

1. After profile selection, check for that slot's valid active run.
2. Present `RESUME RUN` and `DISCARD RUN` using existing keyboard/controller/
   touch conventions; default to Resume.
3. Discard requires confirmation and clears only the selected slot's snapshot.
4. Back never deletes a snapshot.
5. Aspect changes preserve the selection and do not replay transitions.

Gate: all input methods complete both paths and ordinary tab hiding does not
create a false prompt.

### Phase 7 — Profile and optimize web runtime

1. Ship the completed OGG companions; existing
   `SoundClipCatalog.preferred_audio_path()` selects them automatically.
2. Compare export size, startup time, decoded audio memory, and stability.
3. Test iPhone Safari and Android Chrome in browser/Home Screen modes with
   orientation, backgrounding, lock/unlock, menus, and long runs.
4. Correlate restarts with lifecycle records, WebGL loss, and checkpoints.
5. Profile room generation, occlusion buffers, textures, and responsive-layout
   rebuilds. Add web-only quality reductions only for measured hotspots.

Gate: observed restarts are categorized as lifecycle, WebGL, memory pressure,
application error, or unknown with retained evidence.

## Verification

Focused automated coverage:

- `active_run_recovery_contract_smoke.gd` covers RunState, map-state, snapshot,
  JSON round-trip, slot/schema validation, and malformed-data rejection.
- existing profile, room, dungeon-map, save-flow, and web-export smokes

Manual matrix:

| Platform | Mode | Scenarios |
| --- | --- | --- |
| iPhone Safari | Browser and Home Screen | Hide/show, reload, orientation, lock, eviction, long run |
| Android Chrome | Browser and installed mode | Hide/show, reload, orientation, low memory, long run |
| Desktop browsers | Available browsers | Forced reload and WebGL loss |

Use MCP for focused verification while an editor peer is active. Run the full
suite only as a supervised standalone gate with no MCP runtime active.

## Delivery order

1. Diagnostics completion.
2. Pure serialization.
3. Durable save service.
4. Checkpoint writes and cleanup.
5. Deterministic restore.
6. Resume/discard UI.
7. Device profiling and measured optimizations.
8. Version bump, web export verification, and deployment when requested.

## Completion criteria

- Restart loss is limited to the last completed-room boundary.
- Profile and run snapshots are slot-safe and transactionally consistent.
- Recovery cannot duplicate rewards, enemies, chests, or settlement.
- Resume/discard works with touch, controller, and keyboard.
- Invalid recovery data is retained and reported.
- Diagnostics survive restarts and classify the likely cause.
- Focused automated tests and the mobile browser matrix pass.

## Current progress

- Implemented: 42 runtime WAV assets have OGG companions and retain the same
  mix-profile keys; the catalog selects the compact companion automatically.
- Implemented: `WebRunDiagnostics` records bounded startup/session, room/run,
  viewport/orientation, user-agent summary, checkpoint, page lifecycle,
  visibility, and canvas WebGL events in `localStorage`. Browser listeners are
  deduplicated across scene reloads; debug read/clear helpers are available on
  the diagnostics node.
- Implemented: `RunState`, `DungeonMapState`, and `ActiveRunSnapshot` have
  versioned JSON-safe round trips with validation for future schemas, slot
  mismatches, malformed room collections, settled runs, and seed/room identity.
- Implemented: `ActiveRunSaveService` writes one slot-specific checkpoint to a
  synchronous web mirror plus an atomic `user://` file with backup recovery and
  newest-valid-copy selection.
- Implemented: safe checkpoints occur after destination-room application and
  after completed-room, puzzle/orb, flame-attunement, and chest-claim changes.
  The profile is saved before the checkpoint, and the checkpoint is cleared on
  new runs, settlement, defeat/title return, and new-profile creation.
- Implemented: Continue detects a matching active checkpoint and presents the
  existing save prompt as an explicit Resume/Discard choice. Restore rebuilds
  the deterministic map, room state, map progress, health, Chroma, facing, and
  safe arrival point, then resets transient combat/input state. Failed restore
  preserves the checkpoint and returns to title instead of starting over.
- Verified: focused script checks pass for all recovery owners and the new
  `active_run_recovery_contract_smoke.gd` contract test. A standalone headless
  execution was attempted once but hit the known Windows Godot renderer crash
  before test execution; the full smoke runner remains intentionally deferred
  while an MCP editor peer is active.
- Remaining release gate: run the focused contract smoke in a healthy Godot
  runtime, then perform the iPhone Safari/Android Chrome restart and long-run
  profiling matrix, compare export/runtime metrics, and deploy only when
  requested.
