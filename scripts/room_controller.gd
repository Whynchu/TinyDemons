extends Node
class_name RoomController

signal room_entered(room_id: StringName, room_type: StringName)
signal room_cleared(room_id: StringName)

var current_room_id: StringName = &""
var arrival_socket_id: StringName = &""
var transition_locked := false
var room_states: Dictionary = {}
var progression_run_rank := 1

const ACTOR_FOOT_OFFSET := Vector2(8, 15)
const ENEMY_MIN_PLAYER_DISTANCE := 20.0
const ENEMY_MIN_SPAWN_DISTANCE := 18.0
const ENEMY_MIN_SOCKET_DISTANCE := 16.0


func ensure_layout(graph: DungeonGraph, room_id: StringName, room: DungeonGraph.RoomRecord, room_type: StringName, room_depth: int) -> Dictionary:
	var state := room_states.get(room_id, {}) as Dictionary
	if not state.has("generated_exits"):
		var exits: Array[StringName] = []
		if room.milestone_dead_end:
			pass
		elif room_type == DungeonGraph.ROOM_REST or room_type == DungeonGraph.ROOM_TRADER:
			pass
		elif room_type == DungeonGraph.ROOM_NPC:
			var npc_exit := DungeonGraph.WALL_LEFT if room.generation_seed % 2 == 0 else DungeonGraph.WALL_RIGHT
			exits.append(npc_exit)
			var next_room_type := DungeonGraph.ROOM_DOWNSTAIRS if room_depth >= graph.final_npc_depth() else DungeonGraph.ROOM_COMBAT
			graph.ensure_connection(room_id, npc_exit, next_room_type)
		elif room_depth == 0:
			exits.assign([DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT])
			for exit_socket in exits: graph.ensure_connection(room_id, exit_socket, DungeonGraph.ROOM_COMBAT)
		elif room_type == DungeonGraph.ROOM_DOWNSTAIRS:
			pass
		elif room_type == DungeonGraph.ROOM_PUZZLE:
			var puzzle_exit := DungeonGraph.WALL_RIGHT if room.generation_seed % 2 == 0 else DungeonGraph.WALL_LEFT
			exits.append(puzzle_exit)
			graph.ensure_connection(room_id, puzzle_exit, DungeonGraph.ROOM_COMBAT)
		else:
			var layout_rng := RandomNumberGenerator.new(); layout_rng.seed = room.generation_seed; var primary := DungeonGraph.WALL_LEFT if layout_rng.randi_range(0, 1) == 0 else DungeonGraph.WALL_RIGHT; exits.append(primary); graph.ensure_connection(room_id, primary, DungeonGraph.ROOM_COMBAT)
			if room_depth + 1 != 6 and room_depth + 1 != graph.final_npc_depth() and layout_rng.randf() < graph.side_route_chance():
				var secondary := DungeonGraph.WALL_RIGHT if primary == DungeonGraph.WALL_LEFT else DungeonGraph.WALL_LEFT; var secondary_type := DungeonGraph.ROOM_REST if layout_rng.randf() < graph.side_dead_end_chance() else DungeonGraph.ROOM_COMBAT; exits.append(secondary); graph.ensure_connection(room_id, secondary, secondary_type)
		state["generated_exits"] = exits; state["room_type"] = room_type; state["finished"] = bool(state.get("finished", false)); room_states[room_id] = state
	if room_type == DungeonGraph.ROOM_COMBAT:
		if not state.has("enemy_variants"):
			var encounter := _generate_enemy_encounter(room.generation_seed, room_depth)
			state["enemy_variants"] = encounter["variants"]
			state["enemy_levels"] = encounter["levels"]
		if not state.has("enemy_spawn_seed"):
			state["enemy_spawn_seed"] = room.generation_seed + 303
		room_states[room_id] = state
	elif room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		if not state.has("enemy_variants"):
			var boss_encounter := _generate_boss_encounter(room.generation_seed, room_depth)
			state["enemy_variants"] = boss_encounter["variants"]
			state["enemy_levels"] = boss_encounter["levels"]
			state["enemy_scales"] = boss_encounter["scales"]
		if not state.has("enemy_spawn_seed"):
			state["enemy_spawn_seed"] = room.generation_seed + 909
		room_states[room_id] = state
	elif room_type == DungeonGraph.ROOM_PUZZLE:
		room_states[room_id] = state
	return state


func _generate_enemy_encounter(generation_seed: int, room_depth: int) -> Dictionary:
	var encounter_rng := RandomNumberGenerator.new()
	encounter_rng.seed = generation_seed + 101
	var count := 1
	var depth := maxi(room_depth, 0)
	if encounter_rng.randf() < clampf(0.38 + float(depth) * 0.04, 0.38, 0.68):
		count = 2
		if encounter_rng.randf() < clampf(0.35 + float(depth) * 0.04, 0.35, 0.67):
			count = 3
			if encounter_rng.randf() < clampf(float(depth - 2) * 0.10, 0.0, 0.60):
				count = 4
				if encounter_rng.randf() < clampf(float(depth - 4) * 0.07, 0.0, 0.45):
					count = 5
					if encounter_rng.randf() < clampf(float(depth - 8) * 0.03, 0.0, 0.08):
						count = 6
	var count_cap := _normal_enemy_cap()
	count = mini(count, count_cap)
	# Late ranks may exceed the former six-slime ceiling, but only after the
	# player has had time to learn crowd control and defense.
	while count < count_cap and encounter_rng.randf() < _late_enemy_add_chance():
		count += 1
	var variants: Array[String] = []
	var levels: Array[int] = []
	var variant_pool: Array[Dictionary] = [
		{"variant": "blue", "weight": 1.0},
		{"variant": "green", "weight": 1.0},
		{"variant": "red", "weight": 1.0},
	]
	if room_depth >= 3:
		variant_pool.append({"variant": "purple", "weight": 0.6})
	# Enemy progression advances once for every four dungeon depths:
	# depths 1-4 are level 1, 5-8 are level 2, 9-12 are level 3, and so on.
	var base_level := maxi(1, ceili(float(room_depth) / 4.0))
	var level_spread := maxi(1, roundi(float(base_level) * 0.20))
	for enemy_index in count:
		var total_weight := 0.0
		for entry in variant_pool:
			total_weight += float(entry["weight"])
		var roll := encounter_rng.randf_range(0.0, total_weight)
		var selected: String = "green"
		for entry in variant_pool:
			roll -= float(entry["weight"])
			if roll <= 0.0:
				selected = entry["variant"] as String
				break
		variants.append(selected)
		levels.append(maxi(1, encounter_rng.randi_range(base_level - level_spread, base_level + level_spread)))
	return {"variants": variants, "levels": levels}

func _generate_boss_encounter(generation_seed: int, room_depth: int) -> Dictionary:
	var boss_level := maxi(1, ceili(float(room_depth) / 4.0))
	var minor_count := 2 if progression_run_rank <= 2 else 3 if progression_run_rank <= 4 else 4 if progression_run_rank <= 5 else 6 if progression_run_rank <= 10 else 6
	# Rogue/purple slimes can support the first boss encounter, but the scaled
	# lead boss itself is reserved for R2 and later.
	var boss_palette := ["blue", "green"] if progression_run_rank == 1 else ["blue", "green", "purple"]
	var boss_rng := RandomNumberGenerator.new()
	boss_rng.seed = generation_seed + 991
	var variants: Array[String] = [boss_palette[boss_rng.randi_range(0, boss_palette.size() - 1)]]
	var levels: Array[int] = [boss_level + 1]
	var scales: Array[float] = [3.0]
	var palette := ["blue", "green", "purple"]
	var encounter_rng := RandomNumberGenerator.new()
	encounter_rng.seed = generation_seed + 707
	for index in minor_count:
		if index == 0:
			variants.append("purple")
		else:
			variants.append(palette[encounter_rng.randi_range(0, palette.size() - 1)])
		levels.append(boss_level)
		scales.append(1.0)
	return {"variants": variants, "levels": levels, "scales": scales}

func _normal_enemy_cap() -> int:
	if progression_run_rank <= 2: return 2
	if progression_run_rank <= 4: return 3
	if progression_run_rank <= 6: return 5
	if progression_run_rank <= 10: return 6
	return 7

func _late_enemy_add_chance() -> float:
	if progression_run_rank <= 10:
		return 0.0
	return clampf(0.18 + float(progression_run_rank - 11) * 0.07, 0.18, 0.60)


func enemy_count_for_room(room: DungeonGraph.RoomRecord) -> int:
	if room == null:
		return 0
	if room.room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		return (_generate_boss_encounter(room.generation_seed, room.depth).get("variants", []) as Array).size()
	if room.room_type != DungeonGraph.ROOM_COMBAT:
		return 0
	return ( _generate_enemy_encounter(room.generation_seed, room.depth).get("variants", []) as Array).size()


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

func validate_socket_setup() -> void:
	var pairs := {DungeonGraph.WALL_LEFT: DungeonGraph.BOTTOM_RIGHT, DungeonGraph.WALL_RIGHT: DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_LEFT: DungeonGraph.WALL_RIGHT, DungeonGraph.BOTTOM_RIGHT: DungeonGraph.WALL_LEFT}
	for value in pairs.keys():
		var id := StringName(value); var socket := dungeon_sockets.get(id) as DungeonSocket
		if socket == null: push_error("Missing dungeon socket: %s" % id); continue
		if socket.paired_socket_id != StringName(pairs[id]): push_error("Dungeon socket %s has the wrong paired socket." % id)
		if socket.visual() == null or socket.trigger() == null or socket.spawn_marker() == null: push_error("Dungeon socket %s is missing a visual, trigger, or spawn marker." % id)


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


func enter_connected_room(root: Object, destination_room_id: StringName, destination_socket_id: StringName) -> void:
	root.set("room_transition_locked", true)
	begin_transition()
	root.call("_save_current_room_state")
	root.set("current_room_id", destination_room_id)
	root.call("_sync_current_room_metadata")
	enter_room(destination_room_id, root.get("current_room_type"), destination_socket_id)
	root.call("_ensure_current_room_layout")
	root.call("_update_room_number_indicator")
	var arrival_socket := dungeon_sockets.get(destination_socket_id) as DungeonSocket
	var player := root.get("player") as Sprite2D
	player.global_position = _arrival_player_position(root, arrival_socket)
	if not bool(root.call("_can_actor_stand_at_current_position", player)):
		var requested_foot: Vector2 = root.call("_actor_foot", player)
		var nearest_foot: Vector2 = root.call("_nearest_slime_walkable_point", requested_foot)
		player.global_position = nearest_foot - root.get("ACTOR_FOOT_OFFSET")
	player.flip_h = arrival_socket != null and arrival_socket.inward_facing.x < 0.0
	root.set("player_is_attacking", false)
	root.set("player_is_rolling", false)
	root.call("_clear_roll_dust")
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.reset_for_room(root)
	(root.get("player_attack_visual") as Sprite2D).visible = false
	root.call("_set_current_target", null)
	root.set("target_input_was_down", false)
	(root.get("npc_controller") as NpcController).hide_dialogue(root)
	root.call("_set_target_ui_visible", false)
	root.call("_apply_room_state")
	root.call("_build_depth_lists")
	root.call_deferred("_release_room_transition_lock")


func _arrival_player_position(root: Object, socket: DungeonSocket) -> Vector2:
	if socket == null:
		return root.get("player_start_position")
	var trigger := socket.trigger()
	if trigger != null and trigger.polygon.size() >= 3:
		var center := Vector2.ZERO
		for point in trigger.polygon:
			center += trigger.to_global(point)
		center /= float(trigger.polygon.size())
		return center + socket.arrival_offset
	var marker := socket.spawn_marker()
	return marker.global_position if marker != null else root.get("player_start_position")


func apply_state(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id"); var room_type: StringName = root.get("current_room_type")
	var state := room_states.get(room_id, {}) as Dictionary
	_clear_active_world_drop(root)
	root.call("_clear_chroma_pickups")
	if is_cleared(room_id): state["finished"] = true
	if room_type == DungeonGraph.ROOM_START or room_type == DungeonGraph.ROOM_REST: root.call("_apply_rest_room_state")
	elif room_type == DungeonGraph.ROOM_NPC: root.call("_apply_npc_room_state")
	elif room_type == DungeonGraph.ROOM_PUZZLE: apply_puzzle_state(root, bool(state.get("finished", false)))
	elif bool(state.get("finished", false)): root.call("_apply_finished_room_state")
	else:
		(root.get("cloaked_demon") as Sprite2D).visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(root.get("cloaked_demon")); reset_chest_for_room(root); reset_slimes_for_room(root)
	_restore_world_drop(root, state)
	_restore_chroma_pickups(root, state)

func _clear_active_world_drop(root: Object) -> void:
	var item_drop := root.get("world_item_drop") as Sprite2D
	if item_drop != null: item_drop.queue_free()
	var item_label := root.get("world_item_drop_label") as Sprite2D
	if item_label != null: item_label.queue_free()
	root.set("world_item_drop", null); root.set("world_item_drop_label", null); root.set("world_item_drop_instance", null); root.set("world_item_drop_air_time", 0.0)

func _restore_chroma_pickups(root: Object, state: Dictionary) -> void:
	var saved_pickups: Variant = state.get("chroma_pickups", [])
	if saved_pickups is Array:
		root.call("_restore_chroma_pickups", saved_pickups as Array)

func _restore_world_drop(root: Object, state: Dictionary) -> void:
	var saved_drop: Variant = state.get("world_item_drop", {})
	if not (saved_drop is Dictionary):
		return
	var item := ItemInstance.from_dictionary(saved_drop.get("item", {}) as Dictionary)
	if item.instance_id.is_empty():
		return
	root.call("_restore_chest_item_drop", item, saved_drop.get("position", root.get("chest_start_position")) as Vector2)


func build_entrance_blocks(root: Object) -> void:
	var blocks: Array[PackedVector2Array] = []
	for socket_id in dungeon_sockets.keys():
		if active_door_sockets.has(socket_id) or active_entrance_sockets.has(socket_id): continue
		var socket := dungeon_sockets.get(socket_id) as DungeonSocket
		if socket == null: continue
		for tile in socket.block_tiles(): blocks.append(root.call("_tile_top_polygon", tile))
	root.set("entrance_block_polygons", blocks)


func try_enter_active_socket(root: Object, door_active: bool, entrance_open: bool, transition_lock: bool) -> bool:
	if transition_lock: return false
	var feet: Rect2 = root.call("_collision_guide_rect_by_name", root.get("player"), "DoorFeetGuide")
	if not feet.has_area():
		var foot: Vector2 = root.call("_actor_foot", root.get("player")); var size: Vector2 = root.get("PLAYER_DOOR_FOOT_COLLIDER_SIZE") if root.get("PLAYER_DOOR_FOOT_COLLIDER_SIZE") != null else Vector2(4, 2); feet = Rect2(foot - size * 0.5, size)
	if bool(root.get("final_exit_open")) and root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS:
		var final_socket := dungeon_sockets.get(DungeonGraph.WALL_RIGHT) as DungeonSocket
		if final_socket != null and _rect_touches_polygon(feet, _socket_trigger_polygon(final_socket)):
			root.call("_enter_final_settlement_room")
			return true
	if door_active and _try_enter_socket_set(root, active_door_sockets, feet, false): return true
	return entrance_open and _try_enter_socket_set(root, active_entrance_sockets, feet, true)


func _try_enter_socket_set(root: Object, sockets: Dictionary, feet: Rect2, is_entrance: bool) -> bool:
	for socket_value in sockets.values():
		var socket := socket_value as DungeonSocket; var polygon := _socket_trigger_polygon(socket)
		if polygon.size() < 3 or not _rect_touches_polygon(feet, polygon): continue
		var socket_id := socket.socket_id(); var graph := root.get("dungeon_graph") as DungeonGraph; var room_id: StringName = root.get("current_room_id")
		var connection := graph.get_connection_for_entry(room_id, socket_id) if is_entrance else graph.get_connection(room_id, socket_id)
		if connection == null: continue
		var destination: StringName = connection.source_room_id if is_entrance else connection.destination_room_id; var arrival: StringName = connection.exit_socket if is_entrance else connection.destination_entry
		root.call("_enter_connected_room", destination, arrival); return true
	return false


func _socket_trigger_polygon(socket: DungeonSocket) -> PackedVector2Array:
	if socket == null or socket.trigger() == null or socket.trigger().polygon.size() < 3: return PackedVector2Array()
	var polygon := PackedVector2Array(); var guide := socket.trigger()
	for point in guide.polygon: polygon.append(guide.to_global(point))
	return polygon


func _rect_touches_polygon(rect: Rect2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3: return false
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()): bounds = bounds.expand(polygon[index])
	if not bounds.intersects(rect, false): return false
	if Geometry2D.is_point_in_polygon(rect.get_center(), polygon): return true
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y)]
	for point in corners: if Geometry2D.is_point_in_polygon(point, polygon): return true
	for point in polygon: if rect.has_point(point): return true
	return false


func mark_cleared(room_id: StringName) -> void:
	var state: Dictionary = room_states.get(room_id, {}) as Dictionary
	state["finished"] = true
	room_states[room_id] = state
	room_cleared.emit(room_id)


func is_cleared(room_id: StringName) -> bool:
	var state: Variant = room_states.get(room_id, {})
	return state is Dictionary and state.get("finished", false) == true


func apply_rest_state(root: Object) -> void:
	reset_slimes_for_room(root)
	for slime in root.get("slimes") as Array[Sprite2D]: kill_slime_without_effects(root, slime)
	var chest := root.get("chest") as Sprite2D
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); collision.erase(chest)
	(root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); root.call("_set_door_active", true); root.call("_set_entrance_open", true)
	var fire := root.get("rest_fire") as Sprite2D; fire.visible = true; var firepit := fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = true; if firepit != null and not collision.has(firepit): collision.append(firepit)
	_assign_rest_fire_palette(root)
	var demon := root.get("cloaked_demon") as Sprite2D
	demon.visible = root.get("current_room_type") == DungeonGraph.ROOM_START
	if demon.visible:
		demon.position = root.get("cloaked_demon_start_position"); var npc := root.get("npc_controller") as NpcController; npc.demon_wander_origin = root.get("cloaked_demon_start_position"); npc.demon_wander_timer = 0.0; npc.demon_patrol_direction = -1.0; npc.demon_patrol_paused = false; npc.demon_patrol_pause_timer = 0.0; npc.demon_patrol_position_x = demon.position.x; root.call("_configure_cloaked_demon_patrol_route")
		if not collision.has(demon): collision.append(demon)
	else: collision.erase(demon)
	root.call("_set_rest_fire_frame", 0); (root.get("rest_fire_controller") as RestFireController).reset_animation(); _mark_finished(root)


func _assign_rest_fire_palette(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id"); var room_type: StringName = root.get("current_room_type")
	var fire_palette: String
	var graph := root.get("dungeon_graph") as DungeonGraph
	var tutorial_run := graph != null and graph.completed_run_count == 0
	if room_type == DungeonGraph.ROOM_START or tutorial_run:
		fire_palette = str(root.get("run_start_palette_name"))
		if fire_palette.is_empty(): fire_palette = String((root.get("screen_state_controller") as Object).get("player_palette_name"))
	else:
		var state: Dictionary = room_states.get(room_id, {}) as Dictionary
		if not state.has("fire_palette"):
			var rng := root.get("rng") as RandomNumberGenerator
			state["fire_palette"] = PaletteLibrary.REST_FIRE_PALETTES[rng.randi_range(0, PaletteLibrary.REST_FIRE_PALETTES.size() - 1)]
			room_states[room_id] = state
		fire_palette = str(state.get("fire_palette"))
	root.call("_apply_rest_fire_palette", fire_palette)


func apply_npc_state(root: Object) -> void:
	reset_slimes_for_room(root)
	for slime in root.get("slimes") as Array[Sprite2D]: kill_slime_without_effects(root, slime)
	var chest := root.get("chest") as Sprite2D; var collision := root.get("collision_sprites") as Array[Sprite2D]; chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); collision.erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); var fire := root.get("rest_fire") as Sprite2D; fire.visible = false; var firepit := fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; collision.erase(firepit)
	var demon := root.get("cloaked_demon") as Sprite2D; demon.visible = true; demon.position = root.get("cloaked_demon_start_position"); var npc := root.get("npc_controller") as NpcController; npc.demon_wander_origin = demon.position; npc.demon_wander_timer = 0.0; npc.demon_patrol_direction = -1.0; npc.demon_patrol_paused = false; npc.demon_patrol_pause_timer = 0.0; npc.demon_patrol_position_x = demon.position.x; root.call("_configure_cloaked_demon_patrol_route"); if not collision.has(demon): collision.append(demon)
	root.call("_set_door_active", true); root.call("_set_entrance_open", true); _mark_finished(root)


func apply_puzzle_state(root: Object, solved: bool) -> void:
	reset_chest_for_room(root)
	var chest := root.get("chest") as Sprite2D
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	chest.visible = false
	root.set("chest_unlocked", solved)
	root.set("chest_claimed", true)
	root.set("chest_evaporated", true)
	collision.erase(chest)
	(root.get("depth_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	root.call("_set_door_active", solved)
	root.call("_set_entrance_open", true)


func apply_finished_state(root: Object) -> void:
	var fire := root.get("rest_fire") as Sprite2D; fire.visible = false; var firepit := fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(firepit); (root.get("cloaked_demon") as Sprite2D).visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(root.get("cloaked_demon")); reset_slimes_for_room(root)
	for slime in root.get("slimes") as Array[Sprite2D]: kill_slime_without_effects(root, slime)
	var chest := root.get("chest") as Sprite2D; chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); root.set("chest_collect_flash_timer", 0.0); root.call("_set_door_active", true); root.call("_set_entrance_open", true); (root.get("collision_sprites") as Array[Sprite2D]).erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	for key in [&"chest_unlock_overlay", &"chest_flash_overlay"]:
		var overlay := root.get(key) as Sprite2D
		if overlay != null: overlay.queue_free(); root.set(key, null)
	var prompt := root.get("interact_prompt") as Sprite2D
	if prompt != null: prompt.visible = false


func kill_slime_without_effects(root: Object, slime: Sprite2D) -> void:
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent; combat.dead = true; combat.active = false; slime.visible = false; combat.timer = 0.0; combat.frame = 0; combat.hit_done = false
	var brain := root.call("_slime_brain", slime) as SlimeBrain; if brain != null: brain.attack_cooldown = 0.0; brain.aggroed = false
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent; if tactics != null: tactics.reset()
	(root.get("collision_sprites") as Array[Sprite2D]).erase(slime); (root.get("depth_sprites") as Array[Sprite2D]).erase(slime); (root.get("occluder_sprites") as Array[Sprite2D]).erase(slime); (root.get("actor_sprites") as Array[Sprite2D]).erase(slime)
	var health := root.call("_slime_health", slime) as HealthComponent; if health != null: health.reset(0.0)
	(root.call("_slime_health_presenter", slime) as SlimeHealthPresenter).display_health = 0.0
	var hud := root.get("hud_controller") as HudController
	for item in [hud.target_overhead_frames.get(slime), hud.target_overhead_damage_fills.get(slime), hud.target_overhead_fills.get(slime)]: if item != null: (item as Sprite2D).visible = false


func reset_chest_for_room(root: Object) -> void:
	var rest_fire := root.get("rest_fire") as Sprite2D; var demon := root.get("cloaked_demon") as Sprite2D; var chest := root.get("chest") as Sprite2D
	rest_fire.visible = false; var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(firepit); demon.visible = false; chest.position = root.get("chest_start_position"); chest.flip_h = false; chest.texture = root.get("chest_gray_texture"); chest.visible = true; chest.self_modulate = Color.WHITE; root.set("chest_unlocked", false); root.set("chest_claimed", false); root.set("chest_evaporated", false); root.set("chest_collect_flash_timer", 0.0); root.call("_set_door_active", false); root.call("_set_entrance_open", false)
	var unlock_overlay := root.get("chest_unlock_overlay") as Sprite2D; if unlock_overlay != null: unlock_overlay.queue_free(); root.set("chest_unlock_overlay", null)
	var flash_overlay := root.get("chest_flash_overlay") as Sprite2D; if flash_overlay != null: flash_overlay.queue_free(); root.set("chest_flash_overlay", null)
	var collision := root.get("collision_sprites") as Array[Sprite2D]; if not collision.has(chest): collision.append(chest)
	(root.get("occlusion_renderer") as OcclusionRenderer).sprite_images[chest] = (root.get("occlusion_renderer") as OcclusionRenderer).cached_texture_image(chest.texture)


func reset_slimes_for_room(root: Object) -> void:
	var slimes := root.get("slimes") as Array[Sprite2D]; var tuning := root.get("slime_tuning") as SlimeTuning; var rng := root.get("rng") as RandomNumberGenerator; var actor_sprites := root.get("actor_sprites") as Array[Sprite2D]; var collision := root.get("collision_sprites") as Array[Sprite2D]; var occlusion := root.get("occlusion_renderer") as OcclusionRenderer
	(root.get("effects_spawner") as EffectsSpawner).clear_slime_notices()
	for slime in slimes: kill_slime_without_effects(root, slime)
	var room_id: StringName = root.get("current_room_id"); var state: Dictionary = room_states.get(room_id, {}) as Dictionary; var active_variants := state.get("enemy_variants", []) as Array; var active_levels := state.get("enemy_levels", []) as Array; var active_scales := state.get("enemy_scales", []) as Array; var spawn_positions := state.get("enemy_spawn_positions", {}) as Dictionary; var spawn_seed := int(state.get("enemy_spawn_seed", String(room_id).hash() + 303)); var layout_rng := RandomNumberGenerator.new(); layout_rng.seed = spawn_seed
	for slot in active_variants.size():
		if slot >= slimes.size(): break
		root.call("_configure_slime_variant", slimes[slot], String(active_variants[slot]))
	root.call("_build_slime_direction_textures")
	root.call("_assign_slime_attack_frames")
	root.call("_assign_slime_shocked_frames")
	root.call("_refresh_enemy_palette_textures")
	var player := root.get("player") as Sprite2D; var player_foot: Vector2 = root.call("_actor_foot", player); var chest := root.get("chest") as Sprite2D; var chest_rect: Rect2 = root.call("_collision_rect", chest)
	var occupied: Array[Vector2] = []
	for slime_index in active_variants.size():
		if slime_index >= slimes.size(): continue
		var slime := slimes[slime_index]; var spawn_position: Vector2 = spawn_positions.get(slime_index, Vector2.ZERO)
		if not spawn_positions.has(slime_index) or not _valid_enemy_spawn_foot(root, slime, spawn_position + ACTOR_FOOT_OFFSET, player_foot, chest_rect, occupied):
			spawn_position = _choose_enemy_spawn_position(root, slime, layout_rng, occupied); spawn_positions[slime_index] = spawn_position
		var spawn_foot := spawn_position + ACTOR_FOOT_OFFSET
		if not _valid_enemy_spawn_foot(root, slime, spawn_foot, player_foot, chest_rect, occupied):
			spawn_positions.erase(slime_index)
			(slime as Sprite2D).visible = false
			(actor_sprites as Array[Sprite2D]).erase(slime)
			(collision as Array[Sprite2D]).erase(slime)
			continue
		occupied.append(spawn_foot)
		var actor := slime as SlimeActor; var brain := root.call("_slime_brain", slime) as SlimeBrain; brain.start_position = spawn_position; slime.position = spawn_position; slime.visible = true; slime.flip_h = false; root.call("_apply_enemy_room_level", slime, int(active_levels[slime_index]))
		var encounter_scale := float(active_scales[slime_index]) if slime_index < active_scales.size() else 1.0; slime.set_meta("encounter_scale", encounter_scale)
		var max_health := float(root.call("_enemy_max_health", slime)); if actor != null: actor.configure_health(max_health, tuning.regen_delay, tuning.regen_interval, tuning.regen_amount); actor.reset_runtime_state(spawn_position, slime.position, rng.randf_range(tuning.repath_min, tuning.repath_max), rng.randf_range(tuning.hold_min, tuning.hold_max), 0.0, rng.randf_range(0.2, 0.6))
		var presenter := root.call("_slime_health_presenter", slime) as SlimeHealthPresenter; presenter.display_health = max_health; presenter.damage_fill_hold_timer = 0.0; var visual := root.call("_slime_visual", slime) as SlimeVisualComponent; root.call("_set_actor_base_texture", slime, visual.right_texture if visual != null else occlusion.actor_default_textures[slime]); var is_boss := encounter_scale > 1.0; slime.set_meta("movement_speed_multiplier", rng.randf_range(0.75, 1.20) * (0.72 if is_boss else 1.0)); slime.set_meta("attack_speed_multiplier", rng.randf_range(0.85, 1.20) * (1.12 if is_boss else 1.0)); root.call("_set_actor_visual_scale", slime, Vector2.ONE); root.call("_apply_actor_scale", slime, false)
		if not actor_sprites.has(slime): actor_sprites.append(slime)
		if not collision.has(slime): collision.append(slime)
	state["enemy_spawn_positions"] = spawn_positions; state["enemy_spawn_seed"] = spawn_seed; room_states[room_id] = state
	var run_state := root.get("run_state") as RunState
	if run_state != null and run_state.active:
		run_state.register_room_enemies(room_id, active_variants.size())
	if root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS:
		for slime in slimes:
			if slime.visible:
				root.call("_trigger_slime_notice", slime)


func _choose_enemy_spawn_position(root: Object, slime: Sprite2D, layout_rng: RandomNumberGenerator, occupied: Array[Vector2]) -> Vector2:
	var area := root.get("walkable_area") as WalkableArea
	var bounds := Rect2()
	if area != null:
		for point in area.outline: bounds = bounds.expand(point)
	var player := root.get("player") as Sprite2D; var player_foot: Vector2 = root.call("_actor_foot", player); var chest := root.get("chest") as Sprite2D; var chest_rect: Rect2 = root.call("_collision_rect", chest)
	for attempt in 96:
		if bounds.size == Vector2.ZERO: break
		var candidate_foot := Vector2(layout_rng.randf_range(bounds.position.x, bounds.end.x), layout_rng.randf_range(bounds.position.y, bounds.end.y))
		if _valid_enemy_spawn_foot(root, slime, candidate_foot, player_foot, chest_rect, occupied): return candidate_foot - ACTOR_FOOT_OFFSET
	if area != null:
		for candidate_foot in area.points:
			if _valid_enemy_spawn_foot(root, slime, candidate_foot, player_foot, chest_rect, occupied): return candidate_foot - ACTOR_FOOT_OFFSET
	var nearest_foot: Vector2 = root.call("_nearest_slime_walkable_point", player_foot)
	for radius_value in [0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0]:
		var radius: float = radius_value
		for direction_index in 16:
			var candidate_foot: Vector2 = nearest_foot + Vector2.RIGHT.rotated(TAU * float(direction_index) / 16.0) * radius
			if _valid_enemy_spawn_foot(root, slime, candidate_foot, player_foot, chest_rect, occupied): return candidate_foot - ACTOR_FOOT_OFFSET
	return Vector2(INF, INF)


func _valid_enemy_spawn_foot(root: Object, slime: Sprite2D, candidate_foot: Vector2, player_foot: Vector2, chest_rect: Rect2, occupied: Array[Vector2]) -> bool:
	if not bool(root.call("_is_slime_collision_rect_walkable_at", slime, candidate_foot)): return false
	var collision_rect := _enemy_collision_rect_at(slime, candidate_foot)
	if not _is_collision_rect_walkable(root, collision_rect): return false
	if candidate_foot.distance_to(player_foot) < ENEMY_MIN_PLAYER_DISTANCE: return false
	if chest_rect.grow(4.0).intersects(collision_rect, false): return false
	if _is_enemy_spawn_near_socket(candidate_foot): return false
	for occupied_foot in occupied:
		if candidate_foot.distance_to(occupied_foot) < ENEMY_MIN_SPAWN_DISTANCE: return false
	return true


func _is_enemy_spawn_near_socket(candidate_foot: Vector2) -> bool:
	for socket_group in [active_door_sockets, active_entrance_sockets]:
		for socket_value in socket_group.values():
			var socket := socket_value as DungeonSocket
			var marker := socket.spawn_marker() if socket != null else null
			if marker != null and candidate_foot.distance_to(marker.global_position) < ENEMY_MIN_SOCKET_DISTANCE: return true
	return false


func _enemy_collision_rect_at(slime: Sprite2D, foot: Vector2) -> Rect2:
	var guide := slime.get_node_or_null("CollisionGuide") as Node2D
	if guide == null: return Rect2(foot - Vector2(4.5, 2.2), Vector2(9, 4))
	var guide_position: Vector2 = guide.get("rect_position"); var guide_size: Vector2 = guide.get("rect_size"); var actor_position := foot - ACTOR_FOOT_OFFSET; var origin := actor_position + guide.position + guide_position + Vector2(minf(guide_size.x, 0.0), minf(guide_size.y, 0.0))
	return Rect2(origin, guide_size.abs())


func _is_collision_rect_walkable(root: Object, collision_rect: Rect2) -> bool:
	var samples := [collision_rect.position, collision_rect.position + Vector2(collision_rect.size.x, 0), collision_rect.position + collision_rect.size, collision_rect.position + Vector2(0, collision_rect.size.y), collision_rect.get_center(), collision_rect.position + Vector2(collision_rect.size.x * 0.5, 0), collision_rect.position + Vector2(collision_rect.size.x, collision_rect.size.y * 0.5), collision_rect.position + Vector2(collision_rect.size.x * 0.5, collision_rect.size.y), collision_rect.position + Vector2(0, collision_rect.size.y * 0.5)]
	for sample in samples:
		if not bool(root.call("_is_slime_walkable_point", sample)): return false
	return true


func _mark_finished(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id")
	var state := room_states.get(room_id, {}) as Dictionary
	state["finished"] = true
	room_states[room_id] = state
