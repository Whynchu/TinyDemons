extends Node
class_name RoomController

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")

signal room_entered(room_id: StringName, room_type: StringName)
signal room_cleared(room_id: StringName)

var current_room_id: StringName = &""
var arrival_socket_id: StringName = &""
var transition_locked := false
var room_states: Dictionary = {}
var progression_run_rank := 1
var player_level := 1
var boss_slime_authoring_scene: PackedScene = null

const ACTOR_FOOT_OFFSET := Vector2(8, 15)
const BOSS_SLIME_AUTHORING_SCENE := "res://scenes/boss_slime_authoring.tscn"
const ENEMY_MIN_PLAYER_DISTANCE := 20.0
const ENEMY_MIN_SPAWN_DISTANCE := 18.0
const ENEMY_MIN_SOCKET_DISTANCE := 16.0
const SPECIAL_ROOM_RESPAWN_DELAY := 45.0
const POPCORN_RESPAWN_DELAY := 5.0
const POPCORN_RESPAWN_RETRY_DELAY := 0.25
const GREY_ENEMY_WEIGHT: float = 1.0
const YELLOW_ENEMY_WEIGHT: float = 1.0
const YELLOW_MIN_DEPTH := 2
const GROUND_ENEMY_WEIGHT: float = 1.0
const GROUND_MIN_DEPTH := 3
const ICE_ENEMY_WEIGHT: float = 1.0
const ICE_MIN_DEPTH := 4
const SHADOW_ENEMY_WEIGHT: float = 0.12
const SHADOW_BOSS_CHANCE: float = 0.04
const RUN2_POPCORN_CHANCE: float = 0.40
const LATER_POPCORN_CHANCE: float = 0.16
const GUARANTEED_SHADOW_POPCORN_COUNT: int = 1
const BOSS_SUPPORT_POPCORN_BASE_COUNT: int = 2
const BOSS_SUPPORT_POPCORN_MAX_COUNT: int = 6
const BOSS_MIXED_SUPPORT_START_RANK: int = 5


func ensure_layout(graph: DungeonGraph, room_id: StringName, room: DungeonGraph.RoomRecord, room_type: StringName, room_depth: int) -> Dictionary:
	var state := room_states.get(room_id, {}) as Dictionary
	if not state.has("generated_exits"):
		var exits: Array[StringName] = []
		if room.authored:
			for exit_socket in room.outgoing_connections.keys():
				exits.append(StringName(exit_socket))
		elif room.milestone_dead_end:
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
	if room_type == DungeonGraph.ROOM_COMBAT or room_type == DungeonGraph.ROOM_SPECIAL_ENEMY or room_type == DungeonGraph.ROOM_TREASURE:
		if not state.has("enemy_variants"):
			# Special rooms are color-gated route rooms, not elite encounters. Their
			# difficulty comes from the color state and delayed respawns instead of
			# an automatic level, count, or shadow-slime bonus.
			var is_special_room := room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
			var encounter := _generate_enemy_encounter(room.generation_seed, room_depth, false, not is_special_room)
			state["enemy_variants"] = encounter["variants"]
			state["enemy_levels"] = encounter["levels"]
			state["enemy_popcorn"] = encounter["popcorn"]
		if not state.has("enemy_spawn_seed"):
			state["enemy_spawn_seed"] = room.generation_seed + 303
		room_states[room_id] = state
	elif room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		if not state.has("enemy_variants"):
			var boss_encounter := _generate_boss_encounter(room.generation_seed, room_depth)
			state["enemy_variants"] = boss_encounter["variants"]
			state["enemy_levels"] = boss_encounter["levels"]
			state["enemy_scales"] = boss_encounter["scales"]
			state["enemy_popcorn"] = boss_encounter["popcorn"]
		if not state.has("enemy_spawn_seed"):
			state["enemy_spawn_seed"] = room.generation_seed + 909
		room_states[room_id] = state
	elif room_type == DungeonGraph.ROOM_PUZZLE or room_type == DungeonGraph.ROOM_ORB:
		room_states[room_id] = state
	return state


func _generate_enemy_encounter(generation_seed: int, room_depth: int, special_room: bool = false, allow_shadow: bool = true) -> Dictionary:
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
		{"variant": "grey", "weight": GREY_ENEMY_WEIGHT},
	]
	if special_room:
		count = maxi(count + 1, 2)
	if room_depth >= YELLOW_MIN_DEPTH:
		variant_pool.append({"variant": "yellow", "weight": YELLOW_ENEMY_WEIGHT})
	if room_depth >= GROUND_MIN_DEPTH:
		variant_pool.append({"variant": "orange", "weight": GROUND_ENEMY_WEIGHT})
	if room_depth >= ICE_MIN_DEPTH:
		variant_pool.append({"variant": "aquamarine", "weight": ICE_ENEMY_WEIGHT})
	if allow_shadow and room_depth >= 3:
		# Purple is a rare pressure spike, not a normal member of the enemy
		# rotation. A small weight keeps it available without making most later
		# rooms contain one.
		variant_pool.append({"variant": "purple", "weight": SHADOW_ENEMY_WEIGHT})
	# Popcorn is deliberately tied to the player's durable level instead of the
	# dungeon run curve. It is recovery fodder, so it should remain five levels
	# below the player even when a high-level player revisits an early run.
	var base_level := _generated_enemy_base_level(room_depth) + (1 if special_room else 0)
	var level_spread := maxi(1, roundi(float(base_level) * 0.20))
	var popcorn_flags: Array[bool] = []
	for enemy_index in count:
		var total_weight := 0.0
		for entry in variant_pool:
			total_weight += float(entry["weight"])
		var roll := encounter_rng.randf_range(0.0, total_weight)
		var selected: String = "grey"
		for entry in variant_pool:
			roll -= float(entry["weight"])
			if roll <= 0.0:
				selected = entry["variant"] as String
				break
		variants.append(selected)
		# A Shadow Slime is never itself a popcorn roll. That keeps the shadow
		# pressure spike intact while guaranteeing every actual popcorn slot in a
		# shadow encounter is a Normal Slime.
		var is_popcorn := selected != "purple" and encounter_rng.randf() < _popcorn_enemy_chance()
		popcorn_flags.append(is_popcorn)
		var enemy_level := _popcorn_enemy_level() if is_popcorn else encounter_rng.randi_range(base_level - level_spread, base_level + level_spread)
		levels.append(enemy_level if is_popcorn else clampi(enemy_level, 1, _enemy_level_cap()))
	# Shadow encounters keep their low-level mana-recovery opportunity readable:
	# every popcorn slot beside a Shadow Slime becomes a Normal Slime. If the
	# normal popcorn roll produced no slot, add one so Shadow never removes the
	# player's low-mana recovery option entirely.
	if variants.has("purple"):
		var has_shadow_popcorn := false
		for is_popcorn in popcorn_flags:
			if is_popcorn:
				has_shadow_popcorn = true
				break
		if not has_shadow_popcorn:
			for _support_index in GUARANTEED_SHADOW_POPCORN_COUNT:
				variants.append("grey")
				levels.append(_popcorn_enemy_level())
				popcorn_flags.append(true)
		for index in variants.size():
			if popcorn_flags[index]:
				variants[index] = "grey"
	return {"variants": variants, "levels": levels, "popcorn": popcorn_flags}

func _generate_boss_encounter(generation_seed: int, room_depth: int) -> Dictionary:
	var boss_level := _generated_enemy_base_level(room_depth)
	# Keep early boss rooms focused on the boss and low-level neutral popcorn.
	# Normal/elemental minor slimes join the roster starting with Run 5.
	# Run 5 is the first mixed-support boss encounter; keep its introduction
	# readable instead of spawning the full later-run pressure immediately.
	var minor_count := 0 if progression_run_rank < BOSS_MIXED_SUPPORT_START_RANK else 2 if progression_run_rank == 5 else 6
	# Purple is a rare supporting encounter. It is never the scaled lead boss,
	# and it is not guaranteed as a minor, because its pressure is much higher
	# than the ordinary slime variants.
	var boss_palette := ["blue", "green"]
	var boss_rng := RandomNumberGenerator.new()
	boss_rng.seed = generation_seed + 991
	var variants: Array[String] = [boss_palette[boss_rng.randi_range(0, boss_palette.size() - 1)]]
	var levels: Array[int] = [mini(boss_level + 1, _enemy_level_cap())]
	var scales: Array[float] = [3.0]
	var palette := ["blue", "green", "red"]
	var encounter_rng := RandomNumberGenerator.new()
	encounter_rng.seed = generation_seed + 707
	for index in minor_count:
		var selected_variant: String = palette[encounter_rng.randi_range(0, palette.size() - 1)]
		if encounter_rng.randf() < SHADOW_BOSS_CHANCE:
			selected_variant = "purple"
		variants.append(selected_variant)
		levels.append(mini(boss_level, _enemy_level_cap()))
		scales.append(1.0)
	# Boss rooms always include a run-scaled group of low-level Normal Slime
	# support slots. This is the boss counterpart to Shadow's guaranteed
	# mana-recovery opportunity.
	var popcorn_flags: Array[bool] = []
	for index in variants.size():
		popcorn_flags.append(false)
	for _support_index in _boss_support_popcorn_count():
		variants.append("grey")
		levels.append(_popcorn_enemy_level())
		scales.append(1.0)
		popcorn_flags.append(true)
	return {"variants": variants, "levels": levels, "scales": scales, "popcorn": popcorn_flags}


func _enemy_level_cap() -> int:
	return 3 if progression_run_rank <= 1 else progression_run_rank + 3


func _generated_enemy_base_level(room_depth: int) -> int:
	var depth_level := maxi(1, ceili(float(room_depth) / 4.0))
	return mini(depth_level + maxi(progression_run_rank - 1, 0), _enemy_level_cap())


func _popcorn_enemy_chance() -> float:
	if progression_run_rank == 2:
		return RUN2_POPCORN_CHANCE
	if progression_run_rank > 2:
		return LATER_POPCORN_CHANCE
	return 0.0


func _popcorn_enemy_level() -> int:
	return maxi(1, player_level - 5)


func _popcorn_enemy_level_for_root(root: Object) -> int:
	var profile := root.get("player_profile") as PlayerProfile
	return maxi(1, profile.level - 5) if profile != null else _popcorn_enemy_level()


func _boss_support_popcorn_count() -> int:
	# Run 1 starts at two supports, then adds one more each run until the room
	# reaches a readable six-support ceiling that fits the expanded actor roster.
	if progression_run_rank == 5:
		return 3
	return mini(BOSS_SUPPORT_POPCORN_BASE_COUNT + maxi(progression_run_rank - 1, 0), BOSS_SUPPORT_POPCORN_MAX_COUNT)

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
	if room.room_type != DungeonGraph.ROOM_COMBAT and room.room_type != DungeonGraph.ROOM_SPECIAL_ENEMY and room.room_type != DungeonGraph.ROOM_TREASURE:
		return 0
	var is_special_room := room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
	return (_generate_enemy_encounter(room.generation_seed, room.depth, false, not is_special_room).get("variants", []) as Array).size()


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
	# A combo is local to an encounter. Entering a new room must not carry the
	# previous room's timer or multiplier into the next one.
	if root.has_method("_reset_combo"):
		root.call("_reset_combo")
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
	root.set("last_player_facing_left", player.flip_h)
	root.set("player_is_attacking", false)
	root.set("magic_input_was_down", false)
	root.call("_cancel_magic_animation")
	root.call("_reset_magic_runtime")
	root.set("player_is_rolling", false)
	root.set("player_is_backflipping", false)
	root.set("orb_knockback_animation_lock", false)
	root.set("orb_knockback_animation_grace", false)
	root.set("orb_knockback_attack_cancelled", false)
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
	# Boss arrival sockets are intentionally sealed as soon as the encounter
	# begins. Their trigger polygon belongs to the doorway itself, so deriving a
	# player position from that polygon places the player's foot inside the
	# entrance block and the normal transition fallback snaps them to the room's
	# nearest sampled point (the visual center). Use the authored inset marker
	# instead; it is shared by normal transitions and the boss debug scene.
	if root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS:
		var boss_marker := socket.spawn_marker()
		if boss_marker != null:
			return boss_marker.global_position
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
	var treasure_chest_claimed := _treasure_chest_claimed_from_state(state) if room_type == DungeonGraph.ROOM_TREASURE else false
	if room_type == DungeonGraph.ROOM_TREASURE:
		root.set("chest_unlocked", treasure_chest_claimed)
		root.set("chest_claimed", treasure_chest_claimed)
		root.set("chest_evaporated", bool(state.get("chest_evaporated", treasure_chest_claimed)))
	# The scene's base Chest node is authored visible. Clear its presentation
	# before any room-specific branch; treasure rooms explicitly re-add it later.
	hide_chest_presentation(root)
	_clear_active_world_drop(root)
	root.call("_clear_chroma_pickups")
	root.call("_clear_soul_pickups")
	_apply_special_enemy_color_policy(root, state)
	if is_cleared(room_id): state["finished"] = true
	if room_type == DungeonGraph.ROOM_START or room_type == DungeonGraph.ROOM_REST: root.call("_apply_rest_room_state")
	elif room_type == DungeonGraph.ROOM_NPC: root.call("_apply_npc_room_state")
	elif room_type == DungeonGraph.ROOM_PUZZLE: apply_puzzle_state(root, bool(state.get("finished", false)))
	elif room_type == DungeonGraph.ROOM_ORB: apply_orb_state(root)
	elif bool(state.get("finished", false)): root.call("_apply_finished_room_state")
	else:
		(root.get("cloaked_demon") as Sprite2D).visible = false
		(root.get("collision_sprites") as Array[Sprite2D]).erase(root.get("cloaked_demon"))
		reset_chest_for_room(root, room_type == DungeonGraph.ROOM_TREASURE and not treasure_chest_claimed)
		if room_type == DungeonGraph.ROOM_TREASURE and treasure_chest_claimed:
			root.set("chest_unlocked", true)
			root.set("chest_claimed", true)
			root.set("chest_evaporated", bool(state.get("chest_evaporated", true)))
		reset_slimes_for_room(root)
	_restore_world_drop(root, state)
	_restore_chroma_pickups(root, state)
	root.call("_apply_chest_map_tint")


func _treasure_chest_claimed_from_state(state: Dictionary) -> bool:
	if state.has("chest_claimed"):
		return bool(state.get("chest_claimed", false))
	# Older in-memory runs only stored item_rewarded when the chest was opened.
	# Keep those runs from showing the authored chest again on a revisit.
	return state.has("chest_evaporated") or state.has("item_rewarded")


func save_treasure_chest_state(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id")
	var state := room_states.get(room_id, {}) as Dictionary
	state["chest_claimed"] = bool(root.get("chest_claimed"))
	state["chest_evaporated"] = bool(root.get("chest_evaporated"))
	room_states[room_id] = state

func _clear_active_world_drop(root: Object) -> void:
	root.call("_clear_world_item_drops")

func _restore_chroma_pickups(root: Object, state: Dictionary) -> void:
	var saved_pickups: Variant = state.get("chroma_pickups", [])
	if saved_pickups is Array:
		root.call("_restore_chroma_pickups", saved_pickups as Array)

func _restore_world_drop(root: Object, state: Dictionary) -> void:
	var saved_drops: Variant = state.get("world_item_drops", [])
	if saved_drops is Array:
		root.call("_restore_chest_item_drops", saved_drops as Array)
		return
	# Keep the old singular state readable for runs created before chest drops
	# became a collection, without making the runtime model singular again.
	var saved_drop: Variant = state.get("world_item_drop", {})
	if saved_drop is Dictionary:
		root.call("_restore_chest_item_drops", [saved_drop])


func build_entrance_blocks(root: Object) -> void:
	var blocks: Array[PackedVector2Array] = []
	var graph := root.get("dungeon_graph") as DungeonGraph
	for socket_id in dungeon_sockets.keys():
		var socket := dungeon_sockets.get(socket_id) as DungeonSocket
		if socket == null: continue
		var is_entrance := active_entrance_sockets.has(socket_id)
		var is_active := active_door_sockets.has(socket_id) or is_entrance
		if is_active:
			var room_id: StringName = root.get("current_room_id")
			var connection := graph.get_connection_for_entry(room_id, socket_id) if is_entrance else graph.get_connection(room_id, socket_id)
			var connection_available: bool = connection != null and bool(root.call("_map_connection_available", connection, is_entrance))
			var boss_entrance_sealed: bool = is_entrance and root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS and not bool(root.get("entrance_open"))
			if connection_available and not boss_entrance_sealed:
				continue
		for tile in socket.block_tiles(): blocks.append(root.call("_tile_top_polygon", tile))
		if socket.block_trigger_when_closed:
			var trigger_block := _socket_trigger_polygon(socket)
			if trigger_block.size() >= 3:
				blocks.append(trigger_block)
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
	# Authored Run 1 doors are independently gated by the map connection state.
	# The legacy room-wide flag can be false while a color-matched socket is
	# visibly open (notably after a special-room color change), so it must not
	# suppress every authored exit. Keep the tutorial starter gate explicit.
	var map_controller := root.get("dungeon_map_controller") as Node
	var authored_run1 := map_controller != null and bool(map_controller.call("is_authored_run1"))
	var starter_gate_locked: bool = root.get("current_room_type") == DungeonGraph.ROOM_START and not bool(root.get("starter_flame_attuned_this_run"))
	# A generated map can expose one color-matched connection while the legacy
	# room-wide flag is still false. Let the connection-level map check decide
	# whether that socket is traversable instead of blocking every exit first.
	if (door_active or map_controller != null or (authored_run1 and not starter_gate_locked)) and _try_enter_socket_set(root, active_door_sockets, feet, false): return true
	return entrance_open and _try_enter_socket_set(root, active_entrance_sockets, feet, true)


func _try_enter_socket_set(root: Object, sockets: Dictionary, feet: Rect2, is_entrance: bool) -> bool:
	for socket_value in sockets.values():
		var socket := socket_value as DungeonSocket; var polygon := _socket_trigger_polygon(socket)
		if polygon.size() < 3 or not _rect_touches_polygon(feet, polygon): continue
		var socket_id := socket.socket_id(); var graph := root.get("dungeon_graph") as DungeonGraph; var room_id: StringName = root.get("current_room_id")
		var connection := graph.get_connection_for_entry(room_id, socket_id) if is_entrance else graph.get_connection(room_id, socket_id)
		if connection == null: continue
		if not bool(root.call("_map_connection_available", connection, is_entrance)): continue
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
	var was_finished := bool(state.get("finished", false))
	state["finished"] = true
	var graph: DungeonGraph = get_parent().get("dungeon_graph") as DungeonGraph if get_parent() != null else null
	var room := graph.get_room(room_id) if graph != null else null
	if room != null and room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY:
		state["special_clear_earned"] = true
		_ensure_special_enemy_respawn_timers(state)
	room_states[room_id] = state
	if not was_finished:
		room_cleared.emit(room_id)


func is_cleared(room_id: StringName) -> bool:
	var state: Variant = room_states.get(room_id, {})
	return state is Dictionary and state.get("finished", false) == true


func _apply_special_enemy_color_policy(root: Object, state: Dictionary) -> void:
	var graph := root.get("dungeon_graph") as DungeonGraph
	var room := graph.get_room(root.get("current_room_id")) if graph != null else null
	if room == null or room.room_type != DungeonGraph.ROOM_SPECIAL_ENEMY or room.special_respawn_required_color.is_empty():
		return
	if not bool(state.get("special_clear_earned", false)):
		return
	var map_controller := root.get("dungeon_map_controller") as Node
	var active_color: StringName = StringName(map_controller.call("current_color")) if map_controller != null else &"neutral"
	state["finished"] = active_color == room.special_respawn_required_color
	room_states[root.get("current_room_id")] = state


func refresh_special_enemy_color_policy(root: Object) -> void:
	var state: Dictionary = room_states.get(root.get("current_room_id"), {}) as Dictionary
	var previous_finished := bool(state.get("finished", false))
	_apply_special_enemy_color_policy(root, state)
	var now_finished := bool(state.get("finished", false))
	if previous_finished == now_finished:
		return
	if now_finished:
		# Entering the required map color suppresses the room's current enemies,
		# but their respawn clocks remain anchored to when each slot disappeared.
		schedule_special_enemy_respawns(root)
		for slime in root.get("slimes") as Array[Sprite2D]: kill_slime_without_effects(root, slime)
		root.call("_set_door_active", true)
		root.call("_set_entrance_open", true)
	else:
		# Leaving the required color does not instantly repopulate the room. The
		# per-slot timers are allowed to finish and respawn enemies independently.
		schedule_special_enemy_respawns(root)
		root.call("_set_door_active", false)
		root.call("_set_entrance_open", true)


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
	if room_type == DungeonGraph.ROOM_START:
		var profile := root.get("player_profile") as PlayerProfile
		fire_palette = profile.hub_palette() if profile != null else str(root.get("run_start_palette_name"))
		if fire_palette.is_empty(): fire_palette = str(root.get("run_start_palette_name"))
		if fire_palette.is_empty(): fire_palette = String((root.get("screen_state_controller") as Object).get("player_palette_name"))
	elif tutorial_run:
		fire_palette = str(root.get("run_start_palette_name"))
		if fire_palette.is_empty(): fire_palette = String((root.get("screen_state_controller") as Object).get("player_palette_name"))
	else:
		var room := graph.get_room(room_id) if graph != null else null
		if room != null and room.fire_flame != &"":
			fire_palette = ASPECT_CATALOG_SCRIPT.palette_for_flame(room.fire_flame)
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
	if solved:
		mark_cleared(root.get("current_room_id"))


func apply_orb_state(root: Object) -> void:
	reset_chest_for_room(root, false)
	reset_slimes_for_room(root)
	root.call("_set_door_active", true)
	root.call("_set_entrance_open", true)


func apply_finished_state(root: Object) -> void:
	var fire := root.get("rest_fire") as Sprite2D; fire.visible = false; var firepit := fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(firepit); (root.get("cloaked_demon") as Sprite2D).visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(root.get("cloaked_demon")); reset_slimes_for_room(root)
	for slime in root.get("slimes") as Array[Sprite2D]: kill_slime_without_effects(root, slime)
	var room: DungeonGraph.RoomRecord = (root.get("dungeon_graph") as DungeonGraph).get_room(root.get("current_room_id"))
	var is_treasure := room != null and room.room_type == DungeonGraph.ROOM_TREASURE
	var is_boss := room != null and room.room_type == DungeonGraph.ROOM_DOWNSTAIRS
	var chest := root.get("chest") as Sprite2D
	if is_treasure and not bool(root.get("chest_claimed")) and not bool(root.get("chest_evaporated")):
		var normal_texture := root.get("chest_normal_texture") as Texture2D
		if normal_texture != null:
			chest.texture = normal_texture
		chest.visible = true; root.set("chest_unlocked", true); root.set("chest_evaporated", false)
		if not (root.get("collision_sprites") as Array[Sprite2D]).has(chest): (root.get("collision_sprites") as Array[Sprite2D]).append(chest)
		if not (root.get("depth_sprites") as Array[Sprite2D]).has(chest): (root.get("depth_sprites") as Array[Sprite2D]).append(chest)
		if not (root.get("occluder_sprites") as Array[Sprite2D]).has(chest): (root.get("occluder_sprites") as Array[Sprite2D]).append(chest)
	else:
		chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true if not is_treasure else root.get("chest_claimed")); root.set("chest_evaporated", true if not is_treasure else root.get("chest_evaporated")); (root.get("collision_sprites") as Array[Sprite2D]).erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	if is_boss:
		root.call("_open_final_exit")
	else:
		root.call("_set_door_active", true); root.call("_set_entrance_open", true)
	root.set("chest_collect_flash_timer", 0.0)
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


func record_special_enemy_death(root: Object, slime: Sprite2D) -> void:
	if root.get("current_room_type") != DungeonGraph.ROOM_SPECIAL_ENEMY:
		return
	var slimes := root.get("slimes") as Array[Sprite2D]
	var slot := slimes.find(slime)
	if slot < 0:
		return
	var state: Dictionary = room_states.get(root.get("current_room_id"), {}) as Dictionary
	var timers := state.get("special_respawn_timers", {}) as Dictionary
	var timer_key := str(slot)
	if not timers.has(timer_key) or float(timers[timer_key]) <= 0.0:
		timers[timer_key] = SPECIAL_ROOM_RESPAWN_DELAY
	state["special_respawn_timers"] = timers
	room_states[root.get("current_room_id")] = state


func _is_popcorn_respawn_room(root: Object) -> bool:
	var room_type: StringName = StringName(root.get("current_room_type"))
	return room_type == DungeonGraph.ROOM_COMBAT or room_type == DungeonGraph.ROOM_TREASURE or room_type == DungeonGraph.ROOM_DOWNSTAIRS


func _is_popcorn_slot(state: Dictionary, slot: int) -> bool:
	var popcorn_flags := state.get("enemy_popcorn", []) as Array
	return slot >= 0 and slot < popcorn_flags.size() and bool(popcorn_flags[slot])


func _big_threat_is_alive(root: Object, state: Dictionary) -> bool:
	var slimes := root.get("slimes") as Array[Sprite2D]
	var active_variants := state.get("enemy_variants", []) as Array
	var active_scales := state.get("enemy_scales", []) as Array
	for slot in active_variants.size():
		if slot >= slimes.size():
			continue
		var slime := slimes[slot]
		if slime == null or not is_instance_valid(slime) or not slime.visible:
			continue
		var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
		if combat == null or combat.dead:
			continue
		if String(active_variants[slot]) == "purple":
			return true
		if slot < active_scales.size() and float(active_scales[slot]) > 1.0:
			return true
	return false


func record_popcorn_enemy_death(root: Object, slime: Sprite2D) -> void:
	if not _is_popcorn_respawn_room(root):
		return
	var room_id: StringName = StringName(root.get("current_room_id"))
	var state: Dictionary = room_states.get(room_id, {}) as Dictionary
	var slimes := root.get("slimes") as Array[Sprite2D]
	var slot := slimes.find(slime)
	if not _is_popcorn_slot(state, slot):
		return
	if not _big_threat_is_alive(root, state):
		return
	var pending := state.get("popcorn_respawn_slots", {}) as Dictionary
	pending[str(slot)] = POPCORN_RESPAWN_DELAY
	state["popcorn_respawn_slots"] = pending
	room_states[room_id] = state


func _ensure_special_enemy_respawn_timers(state: Dictionary) -> void:
	var timers := state.get("special_respawn_timers", {}) as Dictionary
	var active_variants := state.get("enemy_variants", []) as Array
	for slot in active_variants.size():
		var timer_key := str(slot)
		if not timers.has(timer_key):
			timers[timer_key] = SPECIAL_ROOM_RESPAWN_DELAY
	state["special_respawn_timers"] = timers


func schedule_special_enemy_respawns(root: Object) -> void:
	if root.get("current_room_type") != DungeonGraph.ROOM_SPECIAL_ENEMY:
		return
	var state: Dictionary = room_states.get(root.get("current_room_id"), {}) as Dictionary
	_ensure_special_enemy_respawn_timers(state)
	room_states[root.get("current_room_id")] = state


func _is_special_room_state(root: Object, room_id: StringName, state: Dictionary) -> bool:
	var graph := root.get("dungeon_graph") as DungeonGraph
	var room := graph.get_room(room_id) if graph != null else null
	if room != null:
		return room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
	return StringName(state.get("room_type", &"")) == DungeonGraph.ROOM_SPECIAL_ENEMY


func update_special_enemy_respawns(root: Object, delta: float) -> void:
	var active_room_id: StringName = StringName(root.get("current_room_id"))
	var current_state: Dictionary = {}
	var ready_slots: Array[int] = []
	for room_key in room_states.keys():
		var room_id: StringName = StringName(room_key)
		var state := room_states.get(room_key, {}) as Dictionary
		if not _is_special_room_state(root, room_id, state) or not bool(state.get("special_clear_earned", false)):
			continue
		var timers := state.get("special_respawn_timers", {}) as Dictionary
		if timers.is_empty() and bool(state.get("finished", false)):
			_ensure_special_enemy_respawn_timers(state)
			timers = state.get("special_respawn_timers", {}) as Dictionary
		if timers.is_empty():
			room_states[room_key] = state
			continue
		var room_is_current: bool = room_id == active_room_id and root.get("current_room_type") == DungeonGraph.ROOM_SPECIAL_ENEMY
		for timer_key in timers.keys():
			var remaining := maxf(0.0, float(timers[timer_key]) - maxf(delta, 0.0))
			timers[timer_key] = remaining
			if room_is_current and remaining <= 0.0 and not _special_room_hides_enemies(root, state, room_id):
				ready_slots.append(int(timer_key))
		state["special_respawn_timers"] = timers
		room_states[room_key] = state
		if room_is_current:
			current_state = state
	if ready_slots.is_empty():
		return
	var current_room_state: Dictionary = current_state
	var current_room_timers: Dictionary = current_room_state.get("special_respawn_timers", {}) as Dictionary
	_prepare_enemy_slot_visuals(root, current_room_state)
	var player := root.get("player") as Sprite2D
	var player_foot: Vector2 = root.call("_actor_foot", player)
	var chest := root.get("chest") as Sprite2D
	var chest_rect: Rect2 = root.call("_collision_rect", chest)
	var occupied: Array[Vector2] = []
	for slime in root.get("slimes") as Array[Sprite2D]:
		if slime.visible and not bool(root.call("_is_slime_dead", slime)):
			occupied.append(root.call("_actor_foot", slime))
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = int(current_room_state.get("enemy_spawn_seed", String(root.get("current_room_id")).hash() + 303)) + 1771
	var did_respawn := false
	for slot in ready_slots:
		var timer_key := str(slot)
		if _spawn_enemy_slot(root, current_room_state, slot, occupied, layout_rng, player_foot, chest_rect):
			current_room_timers.erase(timer_key)
			did_respawn = true
		else:
			# Keep retrying if a temporary actor/wall arrangement prevents a valid
			# spawn. This does not reset the original staggered schedule.
			current_room_timers[timer_key] = 0.25
	current_room_state["special_respawn_timers"] = current_room_timers
	if did_respawn:
		current_room_state["finished"] = false
		root.call("_set_door_active", false)
		root.call("_set_entrance_open", true)
		root.call("_build_depth_lists")
	room_states[root.get("current_room_id")] = current_room_state


func update_popcorn_respawns(root: Object, delta: float) -> void:
	if not _is_popcorn_respawn_room(root):
		return
	var room_id: StringName = StringName(root.get("current_room_id"))
	var state: Dictionary = room_states.get(room_id, {}) as Dictionary
	var pending := state.get("popcorn_respawn_slots", {}) as Dictionary
	if pending.is_empty():
		if state.has("popcorn_respawn_slots"):
			state.erase("popcorn_respawn_slots")
			room_states[room_id] = state
		return
	if not _big_threat_is_alive(root, state):
		state.erase("popcorn_respawn_slots")
		room_states[room_id] = state
		return

	var ready_slots: Array[int] = []
	var active_variants := state.get("enemy_variants", []) as Array
	for pending_key in pending.keys():
		var slot := int(pending_key)
		if slot < 0 or slot >= active_variants.size():
			pending.erase(pending_key)
			continue
		var remaining := maxf(0.0, float(pending[pending_key]) - maxf(delta, 0.0))
		pending[pending_key] = remaining
		if remaining <= 0.0:
			ready_slots.append(slot)
	if ready_slots.is_empty():
		if pending.is_empty():
			state.erase("popcorn_respawn_slots")
		else:
			state["popcorn_respawn_slots"] = pending
		room_states[room_id] = state
		return

	_prepare_enemy_slot_visuals(root, state)
	var player := root.get("player") as Sprite2D
	var player_foot: Vector2 = root.call("_actor_foot", player)
	var chest := root.get("chest") as Sprite2D
	var chest_rect: Rect2 = root.call("_collision_rect", chest)
	var occupied: Array[Vector2] = []
	for slime in root.get("slimes") as Array[Sprite2D]:
		if slime.visible and not bool(root.call("_is_slime_dead", slime)):
			occupied.append(root.call("_actor_foot", slime))
	var respawn_serial := int(state.get("popcorn_respawn_serial", 0)) + 1
	state["popcorn_respawn_serial"] = respawn_serial
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = int(state.get("enemy_spawn_seed", String(room_id).hash() + 303)) + 1771 + respawn_serial * 7919
	var spawn_positions := state.get("enemy_spawn_positions", {}) as Dictionary
	var did_respawn := false
	for slot in ready_slots:
		if not _big_threat_is_alive(root, state):
			break
		var timer_key := str(slot)
		var slimes := root.get("slimes") as Array[Sprite2D]
		if slot < 0 or slot >= slimes.size():
			pending.erase(timer_key)
			continue
		var slime := slimes[slot]
		if slime.visible and not bool(root.call("_is_slime_dead", slime)):
			pending.erase(timer_key)
			continue
		# A defeated support slot gets a fresh position when it returns. The
		# spawn helper still validates it against walls, the player, and all
		# currently active actors.
		spawn_positions.erase(slot)
		spawn_positions.erase(timer_key)
		if _spawn_enemy_slot(root, state, slot, occupied, layout_rng, player_foot, chest_rect):
			pending.erase(timer_key)
			did_respawn = true
		else:
			pending[timer_key] = POPCORN_RESPAWN_RETRY_DELAY
	state["enemy_spawn_positions"] = spawn_positions
	if pending.is_empty():
		state.erase("popcorn_respawn_slots")
	else:
		state["popcorn_respawn_slots"] = pending
	if did_respawn:
		state["finished"] = false
		root.call("_set_door_active", false)
		root.call("_set_entrance_open", false if root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS else true)
		root.call("_build_depth_lists")
	room_states[room_id] = state


func reset_chest_for_room(root: Object, show_chest: bool = true) -> void:
	var rest_fire := root.get("rest_fire") as Sprite2D; var demon := root.get("cloaked_demon") as Sprite2D; var chest := root.get("chest") as Sprite2D
	rest_fire.visible = false; var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(firepit); demon.visible = false; chest.position = root.get("chest_start_position"); chest.flip_h = false; chest.texture = root.get("chest_gray_texture"); chest.visible = show_chest; chest.self_modulate = Color.WHITE; root.set("chest_unlocked", false); root.set("chest_claimed", false); root.set("chest_evaporated", false); root.set("chest_collect_flash_timer", 0.0); root.call("_set_door_active", false)
	var unlock_overlay := root.get("chest_unlock_overlay") as Sprite2D; if unlock_overlay != null: unlock_overlay.queue_free(); root.set("chest_unlock_overlay", null)
	var flash_overlay := root.get("chest_flash_overlay") as Sprite2D; if flash_overlay != null: flash_overlay.queue_free(); root.set("chest_flash_overlay", null)
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	if show_chest:
		if not collision.has(chest): collision.append(chest)
		if not (root.get("depth_sprites") as Array[Sprite2D]).has(chest): (root.get("depth_sprites") as Array[Sprite2D]).append(chest)
		if not (root.get("occluder_sprites") as Array[Sprite2D]).has(chest): (root.get("occluder_sprites") as Array[Sprite2D]).append(chest)
	else:
		collision.erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("occlusion_renderer") as OcclusionRenderer).sprite_images[chest] = (root.get("occlusion_renderer") as OcclusionRenderer).cached_texture_image(chest.texture)


func hide_chest_presentation(root: Object) -> void:
	var chest := root.get("chest") as Sprite2D
	if chest == null:
		return
	chest.visible = false
	(root.get("collision_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("depth_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)


func _special_room_hides_enemies(root: Object, state: Dictionary, room_id: StringName = &"") -> bool:
	if not bool(state.get("special_clear_earned", false)):
		return false
	var graph := root.get("dungeon_graph") as DungeonGraph
	var target_room_id: StringName = room_id if not room_id.is_empty() else StringName(root.get("current_room_id"))
	var room := graph.get_room(target_room_id) if graph != null else null
	if room == null or room.special_respawn_required_color.is_empty():
		return false
	var map_controller := root.get("dungeon_map_controller") as Node
	var active_color: StringName = StringName(map_controller.call("current_color")) if map_controller != null else &"neutral"
	return active_color == room.special_respawn_required_color


func _prepare_enemy_slot_visuals(root: Object, state: Dictionary) -> void:
	var slimes := root.get("slimes") as Array[Sprite2D]
	var active_variants := state.get("enemy_variants", []) as Array
	for slot in active_variants.size():
		if slot >= slimes.size():
			break
		root.call("_configure_slime_variant", slimes[slot], String(active_variants[slot]))
	root.call("_build_slime_direction_textures")
	root.call("_assign_slime_attack_frames")
	root.call("_assign_slime_shocked_frames")
	root.call("_refresh_enemy_palette_textures")


func _spawn_enemy_slot(root: Object, state: Dictionary, slime_index: int, occupied: Array[Vector2], layout_rng: RandomNumberGenerator, player_foot: Vector2, chest_rect: Rect2) -> bool:
	var slimes := root.get("slimes") as Array[Sprite2D]
	if slime_index < 0 or slime_index >= slimes.size():
		return false
	var active_variants := state.get("enemy_variants", []) as Array
	var active_levels := state.get("enemy_levels", []) as Array
	if slime_index >= active_variants.size() or slime_index >= active_levels.size():
		return false
	var active_scales := state.get("enemy_scales", []) as Array
	var spawn_positions: Dictionary
	if state.has("enemy_spawn_positions"):
		spawn_positions = state["enemy_spawn_positions"] as Dictionary
	else:
		spawn_positions = {}
		state["enemy_spawn_positions"] = spawn_positions
	var slime := slimes[slime_index]
	var popcorn_flags := state.get("enemy_popcorn", []) as Array
	var is_popcorn := slime_index < popcorn_flags.size() and bool(popcorn_flags[slime_index])
	var spawn_level := int(active_levels[slime_index])
	if is_popcorn:
		# Recalculate on every spawn so a level-up during a run also keeps a
		# respawning fodder slime five levels under the player.
		spawn_level = _popcorn_enemy_level_for_root(root)
		active_levels[slime_index] = spawn_level
	slime.set_meta("is_popcorn", is_popcorn)
	var tuning := root.get("slime_tuning") as SlimeTuning
	var rng := root.get("rng") as RandomNumberGenerator
	var actor_sprites := root.get("actor_sprites") as Array[Sprite2D]
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	var depth_sprites := root.get("depth_sprites") as Array[Sprite2D]
	var occluder_sprites := root.get("occluder_sprites") as Array[Sprite2D]
	var occlusion := root.get("occlusion_renderer") as OcclusionRenderer
	var encounter_scale := float(active_scales[slime_index]) if slime_index < active_scales.size() else 1.0
	if encounter_scale > 1.0:
		_apply_authored_boss_geometry(slime)
	slime.set_meta("encounter_scale", encounter_scale)
	root.call("_set_actor_visual_scale", slime, Vector2.ONE)
	root.call("_apply_actor_scale", slime, false)
	var has_saved_position := spawn_positions.has(slime_index) or spawn_positions.has(str(slime_index))
	var spawn_position: Vector2 = spawn_positions.get(slime_index, spawn_positions.get(str(slime_index), Vector2.ZERO))
	if not has_saved_position or not _valid_enemy_spawn_foot(root, slime, spawn_position + ACTOR_FOOT_OFFSET, player_foot, chest_rect, occupied):
		spawn_position = _choose_enemy_spawn_position(root, slime, layout_rng, occupied)
		spawn_positions[slime_index] = spawn_position
	var spawn_foot := spawn_position + ACTOR_FOOT_OFFSET
	if not _valid_enemy_spawn_foot(root, slime, spawn_foot, player_foot, chest_rect, occupied):
		spawn_positions.erase(slime_index)
		spawn_positions.erase(str(slime_index))
		slime.visible = false
		actor_sprites.erase(slime)
		collision.erase(slime)
		depth_sprites.erase(slime)
		occluder_sprites.erase(slime)
		return false
	occupied.append(spawn_foot)
	var actor := slime as SlimeActor
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	# The spawn solver returns a world-space position because it validates against
	# the world-space floor outline. Actors are children of the offset Actors
	# node, so assign through global_position instead of treating that point as a
	# local coordinate (the old path double-applied the 16:9 horizontal offset).
	slime.global_position = spawn_position
	if brain != null:
		brain.start_position = slime.position
	slime.visible = true
	slime.flip_h = false
	root.call("_apply_enemy_room_level", slime, spawn_level)
	var max_health := float(root.call("_enemy_max_health", slime))
	if actor != null:
		actor.configure_health(max_health, tuning.regen_delay, tuning.regen_interval, tuning.regen_amount)
		actor.reset_runtime_state(slime.position, slime.position, rng.randf_range(tuning.repath_min, tuning.repath_max), rng.randf_range(tuning.hold_min, tuning.hold_max), 0.0, rng.randf_range(0.2, 0.6))
	var presenter := root.call("_slime_health_presenter", slime) as SlimeHealthPresenter
	presenter.display_health = max_health
	presenter.damage_fill_hold_timer = 0.0
	var visual := root.call("_slime_visual", slime) as SlimeVisualComponent
	root.call("_set_actor_base_texture", slime, visual.right_texture if visual != null else occlusion.actor_default_textures[slime])
	var is_boss := encounter_scale > 1.0
	slime.set_meta("movement_speed_multiplier", rng.randf_range(0.75, 1.20) * (0.72 if is_boss else 1.0))
	slime.set_meta("attack_speed_multiplier", rng.randf_range(0.85, 1.20) * (1.12 if is_boss else 1.0))
	root.call("_set_actor_visual_scale", slime, Vector2.ONE)
	root.call("_apply_actor_scale", slime, false)
	if not actor_sprites.has(slime):
		actor_sprites.append(slime)
	if not collision.has(slime):
		collision.append(slime)
	if not depth_sprites.has(slime):
		depth_sprites.append(slime)
	if not occluder_sprites.has(slime):
		occluder_sprites.append(slime)
	return true


func reset_slimes_for_room(root: Object) -> void:
	var slimes := root.get("slimes") as Array[Sprite2D]
	(root.get("effects_spawner") as EffectsSpawner).clear_slime_notices()
	for slime in slimes: kill_slime_without_effects(root, slime)
	var room_id: StringName = root.get("current_room_id")
	var state: Dictionary = room_states.get(room_id, {}) as Dictionary
	state.erase("popcorn_respawn_slots")
	var active_variants := state.get("enemy_variants", []) as Array
	var spawn_positions: Dictionary
	if state.has("enemy_spawn_positions"):
		spawn_positions = state["enemy_spawn_positions"] as Dictionary
	else:
		spawn_positions = {}
		state["enemy_spawn_positions"] = spawn_positions
	var spawn_seed := int(state.get("enemy_spawn_seed", String(room_id).hash() + 303))
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = spawn_seed
	_prepare_enemy_slot_visuals(root, state)
	var player := root.get("player") as Sprite2D; var player_foot: Vector2 = root.call("_actor_foot", player); var chest := root.get("chest") as Sprite2D; var chest_rect: Rect2 = root.call("_collision_rect", chest)
	var occupied: Array[Vector2] = []
	var special_timers := state.get("special_respawn_timers", {}) as Dictionary
	var hide_special_enemies := _special_room_hides_enemies(root, state)
	for slime_index in active_variants.size():
		if slime_index >= slimes.size(): continue
		var timer_key := str(slime_index)
		if hide_special_enemies or (root.get("current_room_type") == DungeonGraph.ROOM_SPECIAL_ENEMY and special_timers.has(timer_key) and float(special_timers[timer_key]) > 0.0):
			continue
		_spawn_enemy_slot(root, state, slime_index, occupied, layout_rng, player_foot, chest_rect)
	state["enemy_spawn_positions"] = spawn_positions; state["enemy_spawn_seed"] = spawn_seed; room_states[room_id] = state
	var run_state := root.get("run_state") as RunState
	if run_state != null and run_state.active:
		run_state.register_room_enemies(room_id, active_variants.size())
	if root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS:
		for slime in slimes:
			if slime.visible:
				root.call("_trigger_slime_notice", slime)


func rebase_enemy_spawn_positions(delta: Vector2) -> void:
	# Spawn positions are stored in world space because walkability, sockets, and
	# collision geometry are all queried in world space. When the wide display
	# mode moves Map and Actors together, keep saved room positions in that same
	# space so revisiting a room does not resurrect enemies at the old 3:2 edge.
	if delta == Vector2.ZERO:
		return
	for room_id in room_states.keys():
		var state := room_states[room_id] as Dictionary
		if state == null:
			continue
		var positions := state.get("enemy_spawn_positions", {}) as Dictionary
		for slot in positions.keys():
			var saved_position: Variant = positions[slot]
			if saved_position is Vector2:
				positions[slot] = (saved_position as Vector2) + delta
		if not positions.is_empty():
			state["enemy_spawn_positions"] = positions
			room_states[room_id] = state


func _apply_authored_boss_geometry(slime: Sprite2D) -> void:
	if boss_slime_authoring_scene == null:
		boss_slime_authoring_scene = load(BOSS_SLIME_AUTHORING_SCENE) as PackedScene
	if boss_slime_authoring_scene == null:
		push_error("Boss slime authoring scene could not be loaded: %s" % BOSS_SLIME_AUTHORING_SCENE)
		return
	var authored := boss_slime_authoring_scene.instantiate()
	var geometry_names := [&"CollisionGuide", &"CollisionPolygon", &"BodyHitbox", &"AttackGuideL", &"AttackGuideR"]
	for geometry_name in geometry_names:
		var source := authored.get_node_or_null(NodePath(geometry_name)) as Node
		if source == null:
			continue
		var existing := slime.get_node_or_null(NodePath(geometry_name)) as Node
		if existing != null:
			existing.free()
		var clone := source.duplicate() as Node
		if clone == null:
			continue
		slime.add_child(clone)
		# The authoring scene intentionally keeps these geometry overlays visible
		# for level-design work. They are collision data at runtime, not gameplay
		# UI, so cloned boss guides must start hidden as well.
		if clone is CanvasItem:
			(clone as CanvasItem).visible = false
		if clone is Node2D:
			clone.set_meta("authored_position", (clone as Node2D).position)
	authored.free()


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


func apply_room_geometry(root: Object) -> void:
	var floor_tiles := root.get("floor_tiles") as Node2D
	if floor_tiles == null:
		return
	root.call("_capture_normal_room_geometry")
	if root.get("current_room_type") != DungeonGraph.ROOM_DOWNSTAIRS:
		root.call("_restore_normal_room_geometry")
		var underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
		if underlay != null:
			underlay.visible = false
		root.call("_configure_large_room_camera", false)
		return
	apply_authored_boss_room_geometry(root)
	root.call("_configure_large_room_camera", true)


func apply_authored_boss_room_geometry(root: Object) -> void:
	var floor_tiles := root.get("floor_tiles") as Node2D
	if String(root.get("scene_file_path")) == "res://scenes/boss_room_debug.tscn":
		var existing_underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
		if existing_underlay != null:
			existing_underlay.visible = true
		_configure_boss_return_guides(root)
		return
	var packed_scene := load("res://scenes/boss_room_debug.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load the authored boss room scene.")
		return
	var template := packed_scene.instantiate()
	for path in ["Map/FloorTiles/FloorLayer", "Map/FloorTiles/FloorLFaceLayer", "Map/FloorTiles/FloorRFaceLayer", "Map/Walls/WallLeftLayer", "Map/Walls/WallRightLayer"]:
		copy_authored_tile_layer(template.get_node_or_null(path) as TileMapLayer, root.call("get_node_or_null", path) as TileMapLayer)
	copy_authored_polygon(root, template, "Map/FloorTiles/FloorCollisionGuide")
	copy_boss_floor_underlay(root, template)
	for path in ["Map/FloorTiles/Entrance", "Map/FloorTiles/EntranceRight", "Map/Walls/DoorLeft", "Map/Walls/DoorRight"]:
		copy_authored_room_sprite(root, template, path)
	for path in ["Map/Sockets/WALL_LEFT/SpawnMarker", "Map/Sockets/WALL_RIGHT/SpawnMarker", "Map/Sockets/BOTTOM_LEFT/SpawnMarker", "Map/Sockets/BOTTOM_RIGHT/SpawnMarker"]:
		copy_authored_marker(root, template, path)
	_configure_boss_return_guides(root)
	template.free()


func _configure_boss_return_guides(root: Object) -> void:
	var floor_tiles := root.get("floor_tiles") as Node2D
	if floor_tiles == null:
		return
	var left_guide := floor_tiles.get_node_or_null("Entrance/EntranceReturnGuide") as Polygon2D
	var right_guide := floor_tiles.get_node_or_null("EntranceRight/EntranceReturnGuide") as Polygon2D
	# The normal room guides are authored against the compact floor diamond. The
	# boss floor is larger and its lower edges sit farther out, so those guides
	# land beyond the walkable polygon. Keep the entrance art where it is, but
	# move only the return triggers inward to the reachable floor edge.
	if left_guide != null:
		left_guide.position = Vector2(11.0, -7.0)
	if right_guide != null:
		right_guide.position = Vector2(5.0, -7.0)


func copy_authored_room_sprite(root: Object, template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(path) as Sprite2D
	var destination := root.call("get_node_or_null", path) as Sprite2D
	if source == null or destination == null:
		return
	destination.position = source.position
	destination.texture = source.texture
	destination.flip_h = source.flip_h
	destination.flip_v = source.flip_v
	destination.offset = source.offset
	destination.scale = source.scale


func copy_authored_marker(root: Object, template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(path) as Marker2D
	var destination := root.call("get_node_or_null", path) as Marker2D
	if source == null or destination == null:
		return
	destination.position = source.position


func copy_boss_floor_underlay(root: Object, template: Node) -> void:
	var source := template.get_node_or_null("Map/FloorTiles/BossFloorUnderlay") as Polygon2D
	if source == null:
		return
	var floor_tiles := root.get("floor_tiles") as Node2D
	var underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
	if underlay == null:
		underlay = Polygon2D.new()
		underlay.name = "BossFloorUnderlay"
		floor_tiles.add_child(underlay)
	underlay.position = source.position
	underlay.polygon = source.polygon.duplicate()
	underlay.color = source.color
	underlay.z_index = -1
	underlay.visible = true


func copy_authored_tile_layer(source: TileMapLayer, destination: TileMapLayer) -> void:
	if source == null or destination == null:
		return
	destination.clear()
	for cell in source.get_used_cells():
		destination.set_cell(cell, source.get_cell_source_id(cell), source.get_cell_atlas_coords(cell), source.get_cell_alternative_tile(cell))
	destination.update_internals()


func copy_authored_polygon(root: Object, template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(path) as Polygon2D
	var destination := root.call("get_node_or_null", path) as Polygon2D
	if source == null or destination == null:
		return
	destination.position = source.position
	destination.polygon = source.polygon.duplicate()


func capture_normal_room_geometry(root: Object) -> void:
	var saved := root.get("normal_room_geometry") as Dictionary
	if not saved.is_empty():
		return
	var map_root := root.get("map_root") as Node2D
	for path in ["FloorTiles/FloorLayer", "FloorTiles/FloorLFaceLayer", "FloorTiles/FloorRFaceLayer", "Walls/WallLeftLayer", "Walls/WallRightLayer"]:
		var layer := map_root.get_node_or_null(path) as TileMapLayer
		if layer != null:
			saved[path] = layer.get_used_cells()
	var floor_tiles := root.get("floor_tiles") as Node2D
	var guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as Polygon2D
	if guide != null:
		saved["guide_position"] = guide.position
		saved["guide_polygon"] = guide.polygon.duplicate()
	for path in ["FloorTiles/Entrance/EntranceReturnGuide", "FloorTiles/EntranceRight/EntranceReturnGuide"]:
		var return_guide := map_root.get_node_or_null(path) as Polygon2D
		if return_guide != null:
			saved["position:%s" % path] = return_guide.position
	for path in ["FloorTiles/Entrance", "FloorTiles/EntranceRight", "Walls/DoorLeft", "Walls/DoorRight"]:
		var node := map_root.get_node_or_null(path) as Sprite2D
		if node != null:
			saved["position:%s" % path] = node.position
			saved["texture:%s" % path] = node.texture
			saved["flip_h:%s" % path] = node.flip_h
			saved["flip_v:%s" % path] = node.flip_v
			saved["offset:%s" % path] = node.offset
			saved["scale:%s" % path] = node.scale


func restore_normal_room_geometry(root: Object) -> void:
	var saved := root.get("normal_room_geometry") as Dictionary
	if saved.is_empty():
		return
	var map_root := root.get("map_root") as Node2D
	for path in ["FloorTiles/FloorLayer", "FloorTiles/FloorLFaceLayer", "FloorTiles/FloorRFaceLayer", "Walls/WallLeftLayer", "Walls/WallRightLayer"]:
		var layer := map_root.get_node_or_null(path) as TileMapLayer
		if layer == null:
			continue
		layer.clear()
		var saved_cells: Array = saved.get(path, []) as Array
		for cell_value in saved_cells:
			var cell: Vector2i = cell_value
			layer.set_cell(cell, 0, Vector2i.ZERO)
		layer.update_internals()
	var floor_tiles := root.get("floor_tiles") as Node2D
	var guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as Polygon2D
	if guide != null:
		guide.position = saved.get("guide_position", guide.position)
		guide.polygon = saved.get("guide_polygon", guide.polygon)
	for path in ["FloorTiles/Entrance", "FloorTiles/EntranceRight", "Walls/DoorLeft", "Walls/DoorRight"]:
		var node := map_root.get_node_or_null(path) as Sprite2D
		if node != null:
			node.position = saved.get("position:%s" % path, node.position)
			node.texture = saved.get("texture:%s" % path, node.texture)
			node.flip_h = bool(saved.get("flip_h:%s" % path, node.flip_h))
			node.flip_v = bool(saved.get("flip_v:%s" % path, node.flip_v))
			node.offset = saved.get("offset:%s" % path, node.offset)
			node.scale = saved.get("scale:%s" % path, node.scale)
	for path in ["FloorTiles/Entrance/EntranceReturnGuide", "FloorTiles/EntranceRight/EntranceReturnGuide"]:
		var return_guide := map_root.get_node_or_null(path) as Polygon2D
		if return_guide != null:
			return_guide.position = saved.get("position:%s" % path, return_guide.position)


func configure_large_room_camera(root: Object, enabled: bool) -> void:
	var display_controller := root.get("display_controller") as DisplayController
	if display_controller != null:
		display_controller.set_large_room_camera_active(enabled)
	var player := root.get("player") as Sprite2D
	var camera := player.get_node_or_null("LargeRoomCamera") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "LargeRoomCamera"
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.5
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		player.add_child(camera)
		camera.top_level = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.5
	camera.enabled = enabled
	if enabled:
		update_large_room_camera(root)


func update_large_room_camera(root: Object) -> void:
	var player := root.get("player") as Sprite2D
	var camera := player.get_node_or_null("LargeRoomCamera") as Camera2D
	if camera == null or not camera.enabled:
		return
	camera.global_position = (root.call("_actor_foot", player) as Vector2) + Vector2(0.0, -7.0)


func _mark_finished(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id")
	mark_cleared(room_id)
