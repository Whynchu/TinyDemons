extends RefCounted
class_name RunSettlementContext

## Narrow input boundary for ending an active run. Profile persistence remains
## owned by RunSettlement; callers only provide the authoritative state.

var player_profile: PlayerProfile = null
var run_state: RunState = null
var result: StringName = &""


func _init(new_player_profile: PlayerProfile, new_run_state: RunState, new_result: StringName) -> void:
	player_profile = new_player_profile
	run_state = new_run_state
	result = new_result


func is_valid() -> bool:
	return player_profile != null and run_state != null and not result.is_empty()
