extends Node
class_name RoomController

signal room_entered(room_id: StringName, room_type: StringName)
signal room_cleared(room_id: StringName)

var current_room_id: StringName = &""
var arrival_socket_id: StringName = &""
var transition_locked := false
var room_states: Dictionary = {}


func ensure_layout(graph: DungeonGraph, room_id: StringName, room: DungeonGraph.RoomRecord, room_type: StringName, room_depth: int) -> Dictionary:
	var state := room_states.get(room_id, {}) as Dictionary
	if not state.has("generated_exits"):
		var exits: Array[StringName] = []
		if room_type == DungeonGraph.ROOM_REST or room_type == DungeonGraph.ROOM_TRADER:
			pass
		elif room_type == DungeonGraph.ROOM_NPC:
			var npc_exit := DungeonGraph.WALL_LEFT if room.generation_seed % 2 == 0 else DungeonGraph.WALL_RIGHT; exits.append(npc_exit); graph.ensure_connection(room_id, npc_exit, DungeonGraph.ROOM_COMBAT)
		elif room_depth == 0:
			exits.assign([DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT])
			for exit_socket in exits: graph.ensure_connection(room_id, exit_socket, DungeonGraph.ROOM_COMBAT)
		else:
			var layout_rng := RandomNumberGenerator.new(); layout_rng.seed = room.generation_seed; var primary := DungeonGraph.WALL_LEFT if layout_rng.randi_range(0, 1) == 0 else DungeonGraph.WALL_RIGHT; exits.append(primary); graph.ensure_connection(room_id, primary, DungeonGraph.ROOM_COMBAT)
			if room_depth + 1 != 6 and room_depth + 1 != 11 and layout_rng.randf() < 0.45:
				var secondary := DungeonGraph.WALL_RIGHT if primary == DungeonGraph.WALL_LEFT else DungeonGraph.WALL_LEFT; var secondary_type := DungeonGraph.ROOM_REST if layout_rng.randf() < 0.40 else DungeonGraph.ROOM_COMBAT; exits.append(secondary); graph.ensure_connection(room_id, secondary, secondary_type)
		state["generated_exits"] = exits; state["room_type"] = room_type; state["finished"] = bool(state.get("finished", false)); room_states[room_id] = state
	return state


func configure_sockets(graph: DungeonGraph, room_id: StringName, _unlocked: bool, set_blocks: Callable) -> void:
	active_door_sockets.clear(); active_entrance_sockets.clear()
	for socket_value in dungeon_sockets.values():
		var visual := (socket_value as DungeonSocket).visual()
		if visual != null: visual.visible = false
	var room := graph.get_room(room_id)
	if room == null: return
	var state := room_states.get(room_id, {}) as Dictionary
	for exit_value in state.get("generated_exits", []) as Array:
		var exit_socket := StringName(exit_value); var socket := dungeon_sockets.get(exit_socket) as DungeonSocket
		if socket != null: active_door_sockets[exit_socket] = socket
	for entry_value in room.incoming_connections.keys():
		var entry_socket := StringName(entry_value); var socket := dungeon_sockets.get(entry_socket) as DungeonSocket
		if socket != null:
			active_entrance_sockets[entry_socket] = socket; var visual := socket.visual(); if visual != null: visual.visible = true
	set_blocks.call()
var dungeon_sockets: Dictionary = {}
var active_door_sockets: Dictionary = {}
var active_entrance_sockets: Dictionary = {}


func hide_editor_only_guides(floor_tiles: Node2D) -> void:
	var floor_collision_guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as CanvasItem
	if floor_collision_guide != null:
		floor_collision_guide.visible = false
	for socket_value in dungeon_sockets.values():
		var socket := socket_value as DungeonSocket
		var trigger := socket.trigger()
		if trigger != null:
			trigger.visible = false


func set_current_room(room_id: StringName, room_type: StringName) -> void:
	current_room_id = room_id
	room_entered.emit(room_id, room_type)


func enter_room(room_id: StringName, room_type: StringName, arrival_socket: StringName = &"") -> void:
	arrival_socket_id = arrival_socket
	set_current_room(room_id, room_type)


func begin_transition() -> void:
	transition_locked = true


func end_transition() -> void:
	transition_locked = false


func mark_cleared(room_id: StringName) -> void:
	var state: Dictionary = room_states.get(room_id, {}) as Dictionary
	state["finished"] = true
	room_states[room_id] = state
	room_cleared.emit(room_id)


func is_cleared(room_id: StringName) -> bool:
	var state: Variant = room_states.get(room_id, {})
	return state is Dictionary and state.get("finished", false) == true


func apply_rest_state(root: Object) -> void:
	root.call("_reset_slimes_for_room")
	for slime in root.get("slimes") as Array[Sprite2D]: root.call("_kill_slime_without_effects", slime)
	var chest := root.get("chest") as Sprite2D
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); collision.erase(chest)
	(root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); root.call("_set_door_active", true); root.call("_set_entrance_open", true)
	var fire := root.get("rest_fire") as Sprite2D; fire.visible = true
	var demon := root.get("cloaked_demon") as Sprite2D
	demon.visible = root.get("current_room_type") == DungeonGraph.ROOM_START
	if demon.visible:
		demon.position = root.get("cloaked_demon_start_position"); root.set("cloaked_demon_wander_origin", root.get("cloaked_demon_start_position")); root.set("cloaked_demon_wander_timer", 0.0); root.set("cloaked_demon_patrol_direction", -1.0); root.set("cloaked_demon_patrol_paused", false); root.set("cloaked_demon_patrol_pause_timer", 0.0); root.set("cloaked_demon_patrol_position_x", demon.position.x); root.call("_configure_cloaked_demon_patrol_route")
		if not collision.has(demon): collision.append(demon)
	else: collision.erase(demon)
	root.call("_set_rest_fire_frame", 0); (root.get("rest_fire_controller") as RestFireController).reset_animation(); _mark_finished(root)


func apply_npc_state(root: Object) -> void:
	root.call("_reset_slimes_for_room")
	for slime in root.get("slimes") as Array[Sprite2D]: root.call("_kill_slime_without_effects", slime)
	var chest := root.get("chest") as Sprite2D; var collision := root.get("collision_sprites") as Array[Sprite2D]; chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); collision.erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); (root.get("rest_fire") as Sprite2D).visible = false
	var demon := root.get("cloaked_demon") as Sprite2D; demon.visible = true; demon.position = root.get("cloaked_demon_start_position"); root.set("cloaked_demon_wander_origin", demon.position); root.set("cloaked_demon_wander_timer", 0.0); root.set("cloaked_demon_patrol_direction", -1.0); root.set("cloaked_demon_patrol_paused", false); root.set("cloaked_demon_patrol_pause_timer", 0.0); root.set("cloaked_demon_patrol_position_x", demon.position.x); root.call("_configure_cloaked_demon_patrol_route"); if not collision.has(demon): collision.append(demon)
	root.call("_set_door_active", true); root.call("_set_entrance_open", true); _mark_finished(root)


func apply_finished_state(root: Object) -> void:
	(root.get("rest_fire") as Sprite2D).visible = false; (root.get("cloaked_demon") as Sprite2D).visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(root.get("cloaked_demon")); root.call("_reset_slimes_for_room")
	for slime in root.get("slimes") as Array[Sprite2D]: root.call("_kill_slime_without_effects", slime)
	var chest := root.get("chest") as Sprite2D; chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); root.set("chest_collect_flash_timer", 0.0); root.call("_set_door_active", true); root.call("_set_entrance_open", true); (root.get("collision_sprites") as Array[Sprite2D]).erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	for key in [&"chest_unlock_overlay", &"chest_flash_overlay"]:
		var overlay := root.get(key) as Sprite2D
		if overlay != null: overlay.queue_free(); root.set(key, null)
	var prompt := root.get("interact_prompt") as Sprite2D
	if prompt != null: prompt.visible = false


func _mark_finished(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id")
	var state := room_states.get(room_id, {}) as Dictionary
	state["finished"] = true
	room_states[room_id] = state
