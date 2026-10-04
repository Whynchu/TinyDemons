extends RefCounted
class_name RunCheckpointContext

## Explicit input boundary for one safe active-run checkpoint. The room and
## snapshot contexts are assembled by GameplayState from its live runtime, but
## the ordering and persistence side effects belong to RunCheckpointService.

var player_profile: PlayerProfile = null
var run_state: RunState = null
var room_context: RoomCheckpointContext = null
var snapshot_context: ActiveRunSnapshotContext = null
var profile_slot := -1


func _init(
	new_player_profile: PlayerProfile,
	new_run_state: RunState,
	new_room_context: RoomCheckpointContext,
	new_snapshot_context: ActiveRunSnapshotContext,
	new_profile_slot: int
) -> void:
	player_profile = new_player_profile
	run_state = new_run_state
	room_context = new_room_context
	snapshot_context = new_snapshot_context
	profile_slot = new_profile_slot


func is_valid() -> bool:
	return player_profile != null and run_state != null and run_state.active and not run_state.settled and room_context != null and room_context.is_valid() and snapshot_context != null and snapshot_context.is_valid() and profile_slot >= 0 and profile_slot < ProfileSaveService.SLOT_COUNT
