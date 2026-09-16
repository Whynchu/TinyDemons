extends RefCounted
class_name RoomActivationServices

## Direct dependencies and room-presentation operations used while restoring a
## persisted room. The gameplay root may compose these callbacks, but it is
## never stored in the activation context.

var player: Sprite2D = null
var slimes: Array[Sprite2D] = []
var dungeon_graph: DungeonGraph = null
var hide_chest_presentation: Callable = Callable()
var clear_active_world_drop: Callable = Callable()
var clear_chroma_pickups: Callable = Callable()
var clear_soul_pickups: Callable = Callable()
var apply_special_enemy_color_policy: Callable = Callable()
var apply_rest_room_state: Callable = Callable()
var apply_npc_room_state: Callable = Callable()
var apply_puzzle_state: Callable = Callable()
var apply_orb_state: Callable = Callable()
var apply_finished_room_state: Callable = Callable()
var reset_chest_for_room: Callable = Callable()
var reset_slimes_for_room: Callable = Callable()
var restore_world_drop: Callable = Callable()
var restore_chroma_pickups: Callable = Callable()
var apply_chest_map_tint: Callable = Callable()
var set_runtime_property: Callable = Callable()
var activation_state: Dictionary = {}
var puzzle_solved := false
var chest_visible := true


static func from_runtime(runtime: GameplayState, controller: RoomController, state: Dictionary, room_type: StringName) -> RoomActivationServices:
	var services := RoomActivationServices.new()
	services.player = runtime.player; services.slimes = runtime.slimes; services.dungeon_graph = runtime.dungeon_graph
	services.hide_chest_presentation = Callable(controller, "hide_chest_presentation").bind(runtime)
	services.clear_active_world_drop = Callable(controller, "_clear_active_world_drop").bind(runtime)
	services.clear_chroma_pickups = Callable(runtime, "_clear_chroma_pickups")
	services.clear_soul_pickups = Callable(runtime, "_clear_soul_pickups")
	services.apply_special_enemy_color_policy = Callable(controller, "_apply_special_enemy_color_policy").bind(runtime, state)
	services.apply_rest_room_state = Callable(runtime, "_apply_rest_room_state")
	services.apply_npc_room_state = Callable(runtime, "_apply_npc_room_state")
	services.apply_puzzle_state = Callable(controller, "apply_puzzle_state").bind(runtime, bool(state.get("finished", false)))
	services.apply_orb_state = Callable(controller, "apply_orb_state").bind(runtime)
	services.apply_finished_room_state = Callable(runtime, "_apply_finished_room_state")
	var treasure_claimed := controller._treasure_chest_claimed_from_state(state)
	var regular_treasure := bool(state.get("regular_room_treasure", false)) and room_type == DungeonGraph.ROOM_COMBAT
	services.reset_chest_for_room = Callable(controller, "reset_chest_for_room").bind(runtime, (room_type == DungeonGraph.ROOM_TREASURE and not treasure_claimed) or (regular_treasure and not treasure_claimed))
	services.reset_slimes_for_room = Callable(controller, "reset_slimes_for_room").bind(runtime)
	services.restore_world_drop = Callable(controller, "_restore_world_drop").bind(runtime, state)
	services.restore_chroma_pickups = Callable(controller, "_restore_chroma_pickups").bind(runtime, state)
	services.apply_chest_map_tint = Callable(runtime, "_apply_chest_map_tint")
	services.set_runtime_property = Callable(runtime, "set")
	return services


func is_valid() -> bool:
	return player != null and dungeon_graph != null
