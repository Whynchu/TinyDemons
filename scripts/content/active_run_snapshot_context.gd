extends RefCounted
class_name ActiveRunSnapshotContext

## Explicit input boundary for serializing recoverable run state. The context
## captures the live references and scalar values at the existing checkpoint
## call site; snapshot encoding itself remains a pure data concern.

var player_profile: PlayerProfile = null
var run_state: RunState = null
var dungeon_map_controller: DungeonMapController = null
var room_controller: RoomController = null
var player_health_component: HealthComponent = null
var player_chroma_component: PlayerChromaComponent = null
var dungeon_seed := 0
var current_room_id: StringName = &""
var current_room_type: StringName = &""
var current_room_depth := 0
var puzzle_attempt_rotation_quarter_turns := 0
var player_facing_left := false
var starter_flame_attuned_this_run := false


func _init(
	new_player_profile: PlayerProfile,
	new_run_state: RunState,
	new_dungeon_map_controller: DungeonMapController,
	new_room_controller: RoomController,
	new_player_health_component: HealthComponent,
	new_player_chroma_component: PlayerChromaComponent,
	new_dungeon_seed: int,
	new_current_room_id: StringName,
	new_current_room_type: StringName,
	new_current_room_depth: int,
	new_puzzle_attempt_rotation_quarter_turns: int,
	new_player_facing_left: bool,
	new_starter_flame_attuned_this_run: bool
) -> void:
	player_profile = new_player_profile
	run_state = new_run_state
	dungeon_map_controller = new_dungeon_map_controller
	room_controller = new_room_controller
	player_health_component = new_player_health_component
	player_chroma_component = new_player_chroma_component
	dungeon_seed = new_dungeon_seed
	current_room_id = new_current_room_id
	current_room_type = new_current_room_type
	current_room_depth = new_current_room_depth
	puzzle_attempt_rotation_quarter_turns = new_puzzle_attempt_rotation_quarter_turns
	player_facing_left = new_player_facing_left
	starter_flame_attuned_this_run = new_starter_flame_attuned_this_run


func is_valid() -> bool:
	return player_profile != null and run_state != null and run_state.active and not run_state.settled
