extends RefCounted
class_name ChestRewardContext

## Narrow input boundary for deterministic chest item rewards. This intentionally
## contains only reward-authoritative state; presentation and checkpoint writes
## remain owned by the interaction/room boundaries.

var player_profile: PlayerProfile = null
var run_state: RunState = null
var dungeon_seed := 0
var room_id: StringName = &""
var reward_tier: StringName = DungeonGraph.REWARD_STANDARD
var vault_id: StringName = &""
var regular_room_treasure := false


func _init(
	new_player_profile: PlayerProfile,
	new_run_state: RunState,
	new_dungeon_seed: int,
	new_room_id: StringName,
	new_reward_tier: StringName,
	new_vault_id: StringName,
	new_regular_room_treasure: bool
) -> void:
	player_profile = new_player_profile
	run_state = new_run_state
	dungeon_seed = new_dungeon_seed
	room_id = new_room_id
	reward_tier = new_reward_tier
	vault_id = new_vault_id
	regular_room_treasure = new_regular_room_treasure


func is_valid() -> bool:
	return player_profile != null and run_state != null
