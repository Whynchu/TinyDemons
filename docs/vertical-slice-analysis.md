# Vertical Slice Analysis

Status: first slice traced through source; runtime characterization remains
incomplete

Slice: start run -> enter room -> fight enemy -> clear room -> claim reward

## Slice Summary

The current flow is functional but crosses a large number of coordinator seams.
`GameplayBootstrap` composes the runtime graph, `GameplayFrameController`
enforces update order, and `GameplayState`/`gameplay.gd` expose compatibility
methods used by feature controllers.

The most important finding is that the feature owners are present, but the
authoritative state still frequently lives on `GameplayState` and is accessed
through `root.get`, `root.set`, and `root.call`.

## 1. Boot And Run Initialization

### Observed path

1. `project.godot` launches `scenes/main.tscn`.
2. The root `Main` node uses `scripts/gameplay.gd`.
3. `gameplay.gd::_ready()` creates `GameplayBootstrap` and calls `initialize`.
4. `GameplayBootstrap` creates runtime controllers and services, including:
   - profile and save controllers;
   - input and touch services;
   - dungeon and room controllers;
   - combat, magic, slime, and presentation controllers;
   - HUD, audio, effects, and pickup controllers.
5. A `RunState` is created and attached to the root.
6. `DungeonMapController.begin_run()` creates or restores the initial dungeon
   layout and returns an initial room ID.
7. The root records `current_room_id`, synchronizes room metadata, and calls
   `RoomController.set_current_room()`.
8. Room layout, sockets, actors, UI, and loading presentation are initialized.
9. The title screen is shown unless a direct hub/run route is pending.

### Ownership assessment

- Composition owner: `GameplayBootstrap`.
- Run/dungeon initialization: split between `GameplayBootstrap`,
  `DungeonMapController`, `DungeonGraph`, and `RunFlowController`.
- Root state: `GameplayState`.
- Persistent profile: `PlayerProfile` and `ProfileSaveService`.

### Friction

- Bootstrap directly writes many root fields and calls many root helpers.
- Initial room setup is partly in bootstrap and partly in `RoomController`.
- The boot path performs substantial synchronous construction before yielding.
- The title/hub/run route decision is mixed into bootstrap initialization.

These are not deletion targets. They are candidates for a future vertical
migration only after characterization tests describe the boot contract.

## 2. Room Entry

### Observed path

1. `RoomController.enter_connected_room()` locks the transition.
2. The current room state is saved through the root.
3. The root current-room fields are updated.
4. `RoomController.enter_room()` emits `room_entered`.
5. The destination layout is ensured and the player is positioned at the arrival
   socket.
6. Player attack, magic, roll, target, dialogue, and equipment presentation
   state are reset.
7. `RoomController.apply_state()` restores room completion, chest, puzzle,
   pickup, and enemy state.
8. The profile and active-run checkpoint are saved.
9. The transition lock is released deferred.

### Ownership assessment

- Room transition owner: `RoomController`.
- Topology and gates: `DungeonMapController` and `DungeonGraph`.
- Per-room persistent state: `RoomController.room_states`.
- Player placement and root room metadata: still coordinated through
  `GameplayState` methods.

### Friction

- Room transition owns gameplay reset, persistence, presentation reset, and
  player positioning in one large path.
- `RoomController` needs the root for many unrelated concerns.
- Persistence occurs both before and after state application, making ordering a
  critical implicit contract.

## 3. Combat

### Observed path

1. `GameplayFrameController` runs the explicit phases in this order:

   ```text
   input -> simulation -> contact_resolution -> damage_and_progression
   -> presentation -> transitions
   ```

2. Input starts attacks through `PlayerAttackComponent`.
3. Attack components and magic controllers calculate contacts and damage.
4. `CombatRuntimeController` builds a damage request from player/enemy stats,
   equipment, elements, and tuning.
5. `CombatCalculator` returns the damage result.
6. `SlimeActor.damage_actor()` applies the result.
7. Combo/momentum and run telemetry are updated for valid damage.
8. Health signals route back through root callbacks and runtime controllers.
9. Room completion is detected by `RoomController` after active enemies are no
   longer present and eventually calls `mark_cleared()`.

### Ownership assessment

- Attack initiation: `PlayerAttackComponent`.
- Damage calculation: `CombatRuntimeController` and `CombatCalculator`.
- Damage application: `SlimeActor`/health components.
- Enemy behavior: slime runtime/brain/combat components.
- Room completion: `RoomController`.
- Frame order: `GameplayFrameController`.

### Friction

- Combat ownership is comparatively well separated.
- Root callbacks still hide dependencies between health, combat, room, and UI.
- Combat completion and room completion are separate concepts but are connected
  through root state and polling.
- The frame schedule is a strength and should be preserved during refactoring.

## 4. Room Clear And Reward

### Observed path

1. `RoomController.mark_cleared()` sets the room state `finished`.
2. It schedules respawns and special-room state.
3. It emits `room_cleared` only on the first clear.
4. Bootstrap connects that signal to:
   - `DungeonMapController.on_room_completed()`;
   - `GameplayState._on_room_cleared_for_checkpoint()`.
5. The checkpoint path assembles room state, saves the profile, and saves a web
   active-run snapshot when applicable.
6. In treasure rooms, `ChestController.update_interaction()` handles the player
   interaction.
7. Chest claim state is written into `RoomController.room_states`.
8. `_grant_chest_item_reward()` in `gameplay.gd` creates deterministic item
   drops and records telemetry on `RunState`.
9. `_chest_gold_reward()` is delegated from `GameplayState` to
   `RunFlowController`.
10. Gold is applied through `ProfileRuntimeController`.
11. The checkpoint is written before the visual chest flash and evaporation.
12. The chest opens the exit path after presentation completes.

### Ownership assessment

- Chest interaction and visual state: `ChestController`.
- Room chest persistence: `RoomController`.
- Item generation: `ItemCatalog` called by `gameplay.gd`.
- Run reward telemetry: `RunState`.
- Gold mutation: `ProfileRuntimeController`.
- Reward scaling: `RunFlowController` through root delegation.
- Web durability: `ActiveRunSnapshot` and `ActiveRunSaveService`.

### Friction

- Reward ownership is split across chest, gameplay, room, profile, run, and
  flow controllers.
- Idempotence is intentionally implemented, but the contract is distributed.
- The item reward method remains in `gameplay.gd`, despite item authority being
  documented elsewhere.
- The checkpoint ordering is important but not represented by a typed command or
  result object.

## Findings

### Strengths

- The explicit frame schedule is clear and tested.
- Room completion emits a signal and avoids duplicate clear events.
- Chest reward IDs are deterministic and provide replay protection.
- Checkpointing occurs before reward presentation completes, protecting browser
  reload behavior.
- Combat calculation has a recognizable owner and typed result object.
- Tuning is already moving into dedicated resources.

### Highest-value risks

1. `GameplayState` remains the implicit dependency container for room, combat,
   reward, and presentation systems.
2. Reward granting crosses too many owners and still has implementation in
   `gameplay.gd`.
3. Room transition combines state restoration, movement, presentation reset,
   and persistence ordering.
4. Root callbacks make renames and ownership changes runtime-fragile.
5. The current HUD smoke failure and duplicate UID warnings need resolution
   before using the full suite as a clean baseline.

## Recommended Follow-Up

- Add or confirm characterization coverage for the room-clear checkpoint and
  idempotent chest claim contract.
- Trace the save/load slice before moving reward code; reward durability is the
  boundary that must not regress.
- Do not split `GameplayFrameController` into independent update loops.
- Do not move reward code solely to reduce `gameplay.gd` line count.
- Consider a typed room-clear result or command only after the existing signal
  and checkpoint behavior are covered.

---

## Second Slice: Profile, Settings, Save, And Recovery

Slice: change profile/settings -> save -> reload -> restore active run or cloud
profile

### 1. Permanent Profile Data

`PlayerProfile` is the authority for durable progression, including player
identity, level, gold, inventory, equipment, run history, settings-adjacent
progression, and compatibility fields. `ProfileSaveService` owns persistence.

The service currently provides:

- three profile slots;
- slot selection persisted locally and in browser storage;
- schema validation through `PlayerProfile.supports_schema_version()`;
- temporary-file writes;
- read-back validation before replacement;
- backup rotation;
- browser `localStorage` mirroring; and
- cloud envelope import/export.

The file replacement sequence is intentionally defensive:

```text
serialize -> write temp -> parse temp -> backup current -> replace current
```

If replacement fails, the backup is copied back where possible.

### 2. Settings Data

`SettingsService` owns device-wide preferences independently of profile slots.
It stores display and audio preferences in `user://settings.cfg`, normalizes
values, saves on change, and emits `setting_changed`.

`GameplayBootstrap` loads settings before creating and initializing the display
controller. This is the correct ownership boundary: settings should not be
serialized into each profile unless the product intentionally changes to
per-slot preferences.

### 3. Active Run Recovery

`ActiveRunSnapshot` is explicitly separate from `PlayerProfile`:

- profile data represents durable progression;
- active-run data represents disposable recovery state.

The snapshot records:

- profile slot and identity information;
- run state;
- dungeon seed and layout-bound flame;
- current room and arrival socket;
- room states;
- map state;
- player health and Chroma state; and
- limited presentation/input state.

`ActiveRunSnapshot.validate()` checks format, schema, slot, active-run status,
seed consistency, current room identity, and required map fields before data is
accepted.

`ActiveRunSaveService` stores the snapshot using the same broad durability
pattern as profile saves:

```text
validate -> write browser mirror -> write temp -> validate temp
-> rotate backup -> replace current
```

On load it considers the browser mirror, current file, and backup, then selects
the newest valid snapshot by `created_at`.

### 4. Checkpoint Triggers

The current checkpoint boundary is assembled by `GameplayState`:

- chest claims call `_checkpoint_safe_run_state()`;
- room clears emit `room_cleared`, which invokes the checkpoint callback;
- room transitions save profile data and defer an active-run checkpoint;
- browser focus/page lifecycle events save the permanent profile; and
- run settlement clears the active-run snapshot.

`_checkpoint_safe_run_state()` first saves current room state, then the profile,
then the active-run snapshot. It does nothing outside web builds or while a
transition is locked.

### 5. Reload And Continue

During bootstrap:

1. The selected profile is loaded.
2. A valid active-run snapshot is detected for the selected slot.
3. A pending route determines whether the title, hub, or run is entered.
4. A normal browser reload returns to the title so the player can explicitly
   choose Continue or discard the recovery run.
5. Confirmed Continue routes through `RunFlowController.restore_active_run()`.

This is a good product decision: reload does not silently resume an active run.

### 6. Cloud Recovery

`CloudSaveService` owns encrypted cloud transport and `CloudSavePanel` owns the
title-screen recovery workflow. The cloud envelope contains profile slots, not
the active-run recovery snapshot. This separation should remain explicit when
cloud behavior changes.

## Save Slice Ownership Assessment

| Concern | Current authority | Assessment |
|---|---|---|
| Permanent progression | `PlayerProfile` | Clear |
| Permanent profile serialization | `ProfileSaveService` | Clear and defensive |
| Device preferences | `SettingsService` | Clear and correctly separate |
| Active run contents | `ActiveRunSnapshot` | Clear schema boundary |
| Active run storage | `ActiveRunSaveService` | Clear and defensive |
| Checkpoint timing | `GameplayState` callbacks | Distributed, high risk |
| Reload route decision | `GameplayBootstrap` and `SaveFlowController` | Split but understandable |
| Recovery confirmation UI | `SaveFlowController`, `ScreenStateController` | Mixed presentation/flow |
| Cloud transport | `CloudSaveService` | Clear |
| Cloud recovery UI | `CloudSavePanel` | Clear |

## Save Slice Findings

### Strengths

- Permanent profile and disposable active-run state are separate.
- Both local save paths validate serialized data before replacement.
- Backups exist for profile and active-run saves.
- Profile slots are validated and active-run snapshots cannot cross slots.
- Settings are device-wide rather than duplicated across profiles.
- Checkpoints occur at meaningful safe boundaries rather than every frame.
- Browser reload offers explicit recovery choice.

### Risks And Open Questions

1. Checkpoint policy is spread across `GameplayState`, `RoomController`,
   `ChestController`, and browser lifecycle handling.
2. The profile is saved before the active-run snapshot, so a failure between
   those operations can produce a newer permanent profile paired with an older
   recoverable run. This may be intentional, but it should be documented and
   tested.
3. `ActiveRunSnapshot` reads many values from the root, making the serialized
   contract dependent on the coordinator's field names.
4. Snapshot validation checks structural consistency but does not appear to
   validate that profile identity matches the currently loaded profile beyond
   the selected slot.
5. Cloud profile restore and active-run discard/resume behavior should be tested
   together, especially after restoring a different slot set.
6. Settings save failure is not surfaced by `set_setting()`; the in-memory
   setting still changes and the signal still emits.

## Verification Targets

The existing tests provide good contract coverage for several boundaries:

- `active_run_recovery_contract_smoke.gd`;
- `cloud_save_contract_smoke.gd`;
- `display_responsive_scene_smoke.gd`;
- `settings_service_smoke.gd`; and
- cloud panel touch coverage.

The next useful characterization tests would cover:

- profile save failure and backup restoration;
- active-run current/backup timestamp selection;
- profile-versus-active-run partial checkpoint failure;
- identity mismatch during recovery;
- cloud restore followed by active-run slot selection; and
- settings write failure behavior.
