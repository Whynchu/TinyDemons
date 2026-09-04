extends Node
class_name DungeonMapController

signal map_state_changed
signal room_discovered(room_id: StringName)
signal room_completed(room_id: StringName)
signal puzzle_color_changed(color: StringName)

const RUN1_LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run1.gd")
const RUN2_LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run2.gd")
const LAYOUT_GENERATOR_SCRIPT = preload("res://scripts/dungeon_layout_generator.gd")
const MAP_STATE_SCRIPT = preload("res://scripts/dungeon_map_state.gd")
const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/element_catalog.gd")
const PUZZLE_COLOR_A: StringName = &"puzzle_a"
const PUZZLE_COLOR_B: StringName = &"puzzle_b"
const PUZZLE_COLOR_C: StringName = &"puzzle_c"
const PUZZLE_COLOR_D: StringName = &"puzzle_d"

var layout = null
var state = MAP_STATE_SCRIPT.new()
var graph: DungeonGraph = null
var authored_run1 := false
var authored_run2 := false
var starter_flame: StringName = &"fire"
var starter_palette_name := "red"
var completed_runs_for_layout := 0
var starter_flame_attuned_this_run := false
var bound_flame: StringName = &""
var current_element := ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL


func begin_run(target_graph: DungeonGraph, dungeon_seed: int, completed_runs: int, selected_starter_flame: StringName = &"fire", selected_bound_flame: StringName = &"") -> StringName:
	graph = target_graph
	completed_runs_for_layout = maxi(completed_runs, 0)
	if graph != null:
		graph.configure_progression(completed_runs_for_layout)
	set_starter_flame(selected_starter_flame)
	set_bound_flame(selected_bound_flame)
	current_element = ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL
	starter_flame_attuned_this_run = false
	authored_run1 = completed_runs == 0
	authored_run2 = completed_runs == 1
	if authored_run1:
		layout = RUN1_LAYOUT_SCRIPT.build()
		var errors: Array[String] = layout.validate()
		for error in errors:
			push_error("Run 1 layout: %s" % error)
	elif authored_run2:
		layout = RUN2_LAYOUT_SCRIPT.build(starter_flame)
		var run2_errors: Array[String] = layout.validate()
		for error in run2_errors:
			push_error("Run 2 layout: %s" % error)
	else:
		layout = LAYOUT_GENERATOR_SCRIPT.build(dungeon_seed, completed_runs, starter_flame, bound_flame)
		# Continue/load paths can hand us an already-created generated layout. Run
		# the same deterministic requirement repair here as build() so recovery is
		# not dependent on whether this map was generated this frame.
		var recovery_repairs: Array[String] = LAYOUT_GENERATOR_SCRIPT.repair_progression(layout, completed_runs, starter_flame, bound_flame)
		for repair in recovery_repairs:
			push_warning("Generated progression recovery (run %d seed %d starter=%s bound=%s): %s" % [completed_runs + 1, dungeon_seed, starter_flame, bound_flame if not bound_flame.is_empty() else "none", repair])
		var generated_errors: Array[String] = LAYOUT_GENERATOR_SCRIPT.validate(layout, completed_runs, starter_flame, bound_flame)
		for error in generated_errors:
			push_error("Generated layout: %s" % error)
	graph.initialize_from_layout(dungeon_seed, layout)
	state.begin(graph.start_room_id)
	var state_changed_callable := Callable(self, "_on_state_changed")
	if not state.changed.is_connected(state_changed_callable):
		state.changed.connect(state_changed_callable)
	return graph.start_room_id


func is_authored_run1() -> bool:
	return authored_run1


func is_authored_run2() -> bool:
	return authored_run2


func is_authored_layout() -> bool:
	return authored_run1 or authored_run2


func has_complete_layout() -> bool:
	return layout != null


func uses_global_orb_state() -> bool:
	return layout != null


func set_starter_flame(selected_flame: StringName) -> void:
	starter_flame = selected_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_flame) else &"fire"
	starter_palette_name = ASPECT_CATALOG_SCRIPT.palette_for_flame(starter_flame)


func set_bound_flame(selected_flame: StringName) -> void:
	bound_flame = selected_flame if ASPECT_CATALOG_SCRIPT.is_elemental_flame(selected_flame) else &""


func set_current_element(element: int) -> void:
	var normalized := ELEMENT_CATALOG_SCRIPT.normalize(element)
	if current_element == normalized:
		return
	current_element = normalized as ELEMENT_CATALOG_SCRIPT.Element
	map_state_changed.emit()


func starter_palette() -> String:
	return starter_palette_name


func set_starter_flame_attuned(attuned: bool) -> void:
	if starter_flame_attuned_this_run == attuned:
		return
	starter_flame_attuned_this_run = attuned
	map_state_changed.emit()


func available_flames() -> Array[StringName]:
	return ASPECT_CATALOG_SCRIPT.flames_available_for_run(completed_runs_for_layout, starter_flame)


func alternate_flames() -> Array[StringName]:
	return ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(completed_runs_for_layout, starter_flame)


func fire_palette_available(palette: String) -> bool:
	if palette == "grey":
		return true
	var flame := ASPECT_CATALOG_SCRIPT.flame_for_palette(palette)
	return not flame.is_empty() and (flame in available_flames() or flame == bound_flame)


func fire_flame_for_room(room_id: StringName) -> StringName:
	if graph == null:
		return &""
	var room := graph.get_room(room_id)
	return room.fire_flame if room != null else &""


func available_puzzle_colors() -> Array[StringName]:
	var colors: Array[StringName] = [PUZZLE_COLOR_B, PUZZLE_COLOR_A]
	var alternates := alternate_flames()
	if alternates.size() >= 1:
		colors.append(PUZZLE_COLOR_C)
	if alternates.size() >= 2:
		colors.append(PUZZLE_COLOR_D)
	return colors


func palette_for_requirement(requirement: StringName) -> String:
	if ELEMENT_CATALOG_SCRIPT.is_valid_id(requirement):
		return str(ELEMENT_CATALOG_SCRIPT.PALETTE_KEYS.get(ELEMENT_CATALOG_SCRIPT.element_for_id(requirement), "grey"))
	match requirement:
		PUZZLE_COLOR_A:
			return starter_palette_name
		PUZZLE_COLOR_B:
			return "grey"
		PUZZLE_COLOR_C:
			var alternates := alternate_flames()
			return ASPECT_CATALOG_SCRIPT.palette_for_flame(alternates[0]) if alternates.size() >= 1 else ""
		PUZZLE_COLOR_D:
			var alternates := alternate_flames()
			return ASPECT_CATALOG_SCRIPT.palette_for_flame(alternates[1]) if alternates.size() >= 2 else ""
	return ""


func door_display_color(requirement: StringName) -> Color:
	var palette := palette_for_requirement(requirement)
	if palette.is_empty():
		return Color8(51, 60, 87)
	return PaletteLibrary.normal(palette)


func active_environment_palette() -> String:
	# The shared Orb Room palette is the room-wide presentation state. Ordinary
	# puzzle colors and mixed elemental charges both flow through this value, so
	# an Orb hit changes the environment even when it is not one of the four
	# strategic puzzle-color keys.
	return state.shared_orb_palette if not state.shared_orb_palette.is_empty() else palette_for_requirement(state.active_puzzle_color)


func element_requirement_for_palette(palette: String) -> StringName:
	var normalized_palette := palette.to_lower()
	if normalized_palette == "gray":
		normalized_palette = "grey"
	var element := ELEMENT_CATALOG_SCRIPT.element_for_palette(normalized_palette)
	if element == ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL:
		return &""
	return ELEMENT_CATALOG_SCRIPT.id(element)


func connection_gate_type(connection) -> StringName:
	if connection == null:
		return DungeonGraph.GATE_NONE
	var explicit_type: StringName = connection.gate_type
	if not explicit_type.is_empty() and explicit_type != DungeonGraph.GATE_NONE:
		return explicit_type
	if not connection.orb_element_requirement.is_empty():
		return DungeonGraph.GATE_ENTRANCE_ORB
	if not connection.element_requirement.is_empty():
		return DungeonGraph.GATE_ELEMENT
	if not connection.color_requirement.is_empty():
		return DungeonGraph.GATE_PUZZLE_COLOR
	return DungeonGraph.GATE_NONE


func connection_display_requirement(connection) -> StringName:
	match connection_gate_type(connection):
		DungeonGraph.GATE_PUZZLE_COLOR:
			return connection.color_requirement
		DungeonGraph.GATE_ELEMENT:
			return connection.element_requirement
		DungeonGraph.GATE_ENTRANCE_ORB:
			return connection.orb_element_requirement
	return &""


func puzzle_color_for_palette(palette: String) -> StringName:
	var normalized_palette := palette.to_lower()
	if normalized_palette == "gray":
		normalized_palette = "grey"
	if normalized_palette == "grey":
		return PUZZLE_COLOR_B
	if normalized_palette == starter_palette_name:
		return PUZZLE_COLOR_A
	var alternates := alternate_flames()
	if alternates.size() >= 1 and normalized_palette == ASPECT_CATALOG_SCRIPT.palette_for_flame(alternates[0]):
		return PUZZLE_COLOR_C
	if alternates.size() >= 2 and normalized_palette == ASPECT_CATALOG_SCRIPT.palette_for_flame(alternates[1]):
		return PUZZLE_COLOR_D
	return &""


func on_room_entered(room_id: StringName) -> void:
	if graph == null:
		return
	state.mark_room_discovered(room_id)
	room_discovered.emit(room_id)
	var room := graph.get_room(room_id)
	if room == null:
		return
	# Non-combat utility rooms have no later encounter event to announce their
	# completion. Mark them when the player physically enters them, while keeping
	# puzzle/orb objectives tied to their actual interactions.
	if room_completes_on_entry(room) and not state.is_room_completed(room_id):
		on_room_completed(room_id)
	for connection_value in room.outgoing_connections.values():
		var connection := connection_value as DungeonGraph.ConnectionRecord
		if connection != null and (state.is_room_completed(room_id) or not requires_room_clear(room)) and _event_reveal_satisfied(connection):
			state.reveal_connection(connection)
	for connection_value in room.incoming_connections.values():
		var incoming := connection_value as DungeonGraph.ConnectionRecord
		if incoming != null and state.is_room_discovered(incoming.source_room_id):
			state.reveal_connection(incoming)


func on_room_completed(room_id: StringName) -> void:
	var was_completed := state.is_room_completed(room_id)
	state.mark_room_completed(room_id)
	if not was_completed:
		room_completed.emit(room_id)
	if graph == null:
		return
	var room := graph.get_room(room_id)
	if room == null:
		return
	for connection_value in room.outgoing_connections.values():
		var connection := connection_value as DungeonGraph.ConnectionRecord
		if _event_reveal_satisfied(connection):
			state.reveal_connection(connection)


func reveal_event(event_id: StringName) -> bool:
	if event_id.is_empty():
		return false
	if not state.reveal_event(event_id):
		return false
	if graph != null:
		for room_id in graph.get_room_ids():
			var room := graph.get_room(room_id)
			if room == null:
				continue
			for connection_value in room.outgoing_connections.values():
				var connection := connection_value as DungeonGraph.ConnectionRecord
				if connection != null and connection.hidden_until_event == event_id:
					state.reveal_connection(connection)
	return true


func is_event_revealed(event_id: StringName) -> bool:
	return state.is_event_revealed(event_id)


func _event_reveal_satisfied(connection: DungeonGraph.ConnectionRecord) -> bool:
	return connection != null and (connection.hidden_until_event.is_empty() or state.is_event_revealed(connection.hidden_until_event))


func change_orb_from_room(room_id: StringName, next_puzzle_color: StringName = &"") -> bool:
	if graph == null or not uses_global_orb_state() or room_id != state.current_room_id:
		return false
	var room := graph.get_room(room_id)
	if room == null or room.room_type != DungeonGraph.ROOM_ORB:
		return false
	if next_puzzle_color not in available_puzzle_colors():
		return false
	var next_palette := palette_for_requirement(next_puzzle_color)
	if next_palette.is_empty():
		return false
	var puzzle_color_was_current: bool = state.active_puzzle_color == next_puzzle_color
	var room_was_complete: bool = state.is_room_completed(room_id)
	var orb_element_requirement := element_requirement_for_palette(next_palette)
	var orb_state_changed := state.set_shared_orb_state(next_palette, orb_element_requirement, false)
	if not state.set_puzzle_color(next_puzzle_color):
		return false
	on_room_completed(room_id)
	if room_was_complete and (orb_state_changed or puzzle_color_was_current):
		# A direct fusion charge may have changed the shared presentation while the
		# strategic Puzzle Color key stayed the same. Emit the missing refresh event.
		state.changed.emit()
	puzzle_color_changed.emit(state.active_puzzle_color)
	return true


func change_orb_from_palette(room_id: StringName, palette: String) -> bool:
	if graph == null or not uses_global_orb_state() or room_id != state.current_room_id:
		return false
	var room := graph.get_room(room_id)
	if room == null or room.room_type != DungeonGraph.ROOM_ORB:
		return false
	var normalized_palette := palette.to_lower()
	if normalized_palette == "gray":
		normalized_palette = "grey"
	if normalized_palette not in PaletteLibrary.PALETTE_NAMES:
		return false
	# Earned starter flames retain their strategic Puzzle Color behavior. Any
	# other valid elemental palette is an exclusive fusion result: it charges the
	# shared Orb Room presentation and clears the ordinary Puzzle Color key. A
	# mixed result therefore cannot continue to satisfy either input color door.
	var requested_color := puzzle_color_for_palette(normalized_palette)
	if not requested_color.is_empty():
		return change_orb_from_room(room_id, requested_color)
	var palette_changed: bool = state.shared_orb_palette != normalized_palette
	var orb_element_requirement := element_requirement_for_palette(normalized_palette)
	var orb_element_changed: bool = state.shared_orb_element != orb_element_requirement
	var puzzle_key_changed: bool = state.active_puzzle_color != MAP_STATE_SCRIPT.MAP_COLOR_NEUTRAL or state.shared_orb_puzzle_color != MAP_STATE_SCRIPT.MAP_COLOR_NEUTRAL
	var orb_state_changed := state.set_shared_orb_state(normalized_palette, orb_element_requirement, false)
	if puzzle_key_changed:
		# Keep the ordinary key separate from the mixed Orb presentation. The
		# optional count flag makes this one Orb charge even though two state
		# fields are being updated.
		state.set_puzzle_color(MAP_STATE_SCRIPT.MAP_COLOR_NEUTRAL, false)
	if orb_state_changed or puzzle_key_changed:
		state.orb_change_count += 1
	var room_was_complete: bool = state.is_room_completed(room_id)
	on_room_completed(room_id)
	if room_was_complete and (orb_state_changed or palette_changed or orb_element_changed or puzzle_key_changed):
		state.changed.emit()
	return true


func current_color() -> StringName:
	return state.active_puzzle_color


func shared_orb_puzzle_color() -> StringName:
	return state.shared_orb_puzzle_color


func shared_orb_element() -> StringName:
	return state.shared_orb_element


func orb_display_palette() -> StringName:
	# Orb Rooms are light blue only on the minimap. Their in-world orb starts
	# grey, then mirrors the shared elemental charge after activation. The
	# strategic puzzle key is cleared for an exclusive fusion palette, so a
	# fusion result cannot make either input color door valid by accident.
	return StringName(state.shared_orb_palette if not state.shared_orb_palette.is_empty() else palette_for_requirement(state.shared_orb_puzzle_color))


func requires_room_clear(room: DungeonGraph.RoomRecord) -> bool:
	if room == null:
		return false
	return room.room_type == DungeonGraph.ROOM_COMBAT or room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY or room.room_type == DungeonGraph.ROOM_TREASURE


func room_completes_on_entry(room: DungeonGraph.RoomRecord) -> bool:
	if room == null or room.depth < 1:
		return false
	return room.room_type == DungeonGraph.ROOM_REST or room.room_type == DungeonGraph.ROOM_TRADER or room.room_type == DungeonGraph.ROOM_NPC


func run_room_ids() -> Array[StringName]:
	var room_ids: Array[StringName] = []
	if graph == null:
		return room_ids
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room != null and room.depth >= 1:
			room_ids.append(room.id)
	return room_ids


func run_room_count() -> int:
	return run_room_ids().size()


func discovered_run_room_count() -> int:
	var count := 0
	for room_id in run_room_ids():
		if state.is_room_discovered(room_id):
			count += 1
	return count


func completed_run_room_count() -> int:
	var count := 0
	for room_id in run_room_ids():
		if state.is_room_completed(room_id):
			count += 1
	return count


func is_connection_color_locked(connection: DungeonGraph.ConnectionRecord) -> bool:
	if connection == null or connection_gate_type(connection) != DungeonGraph.GATE_PUZZLE_COLOR:
		return false
	return connection.color_requirement != state.active_puzzle_color or connection.color_requirement not in available_puzzle_colors()


func is_connection_orb_locked(connection: DungeonGraph.ConnectionRecord) -> bool:
	if connection == null or connection_gate_type(connection) != DungeonGraph.GATE_ENTRANCE_ORB or connection.orb_element_requirement.is_empty():
		return false
	# Crossing a correctly charged entrance-Orb door permanently solves that
	# connection. Without this latch, charging a later Orb can relock the route
	# behind the player and strand them on the wrong side of an earlier gate.
	if state.is_orb_connection_solved(connection):
		return false
	return state.shared_orb_element != connection.orb_element_requirement


func is_connection_element_locked(connection: DungeonGraph.ConnectionRecord) -> bool:
	if connection == null or connection_gate_type(connection) != DungeonGraph.GATE_ELEMENT or connection.element_requirement.is_empty() or state.is_element_connection_solved(connection):
		return false
	return current_element != ELEMENT_CATALOG_SCRIPT.element_for_id(connection.element_requirement)


func mark_room_engaged(room_id: StringName) -> bool:
	if graph == null or state.is_room_completed(room_id):
		return false
	var room := graph.get_room(room_id)
	if not requires_room_clear(room):
		return false
	return state.mark_room_engaged(room_id)


func is_room_engaged(room_id: StringName) -> bool:
	return state.is_room_engaged(room_id)


func is_connection_available(connection: DungeonGraph.ConnectionRecord, is_entrance: bool = false) -> bool:
	if connection == null:
		return false
	var gate_type: StringName = connection_gate_type(connection)
	var source_room := graph.get_room(connection.source_room_id) if graph != null else null
	var destination_room := graph.get_room(connection.destination_room_id) if graph != null else null
	# Once the boss is defeated, its arrival route is a guaranteed way back out.
	# Do not let a stale source-room gate or a changed map color trap the player in
	# the completed boss room; forward entry into the boss still uses the normal
	# connection rules because this exception applies only to the reverse entrance.
	if is_entrance and state.current_room_id == connection.destination_room_id and destination_room != null and destination_room.room_type == DungeonGraph.ROOM_DOWNSTAIRS and state.is_room_completed(destination_room.id):
		return true
	if source_room != null and source_room.room_type == DungeonGraph.ROOM_START and not starter_flame_attuned_this_run:
		return false
	if is_connection_color_locked(connection):
		return false
	if is_connection_orb_locked(connection):
		return false
	if gate_type == DungeonGraph.GATE_ELEMENT:
		if is_connection_element_locked(connection):
			return false
	if source_room == null:
		return false
	if connection.hidden_until_clear and not state.is_room_completed(source_room.id):
		return false
	if not connection.hidden_until_event.is_empty() and not state.is_event_revealed(connection.hidden_until_event):
		return false
	var source_clear_satisfied := not connection.requires_source_room_clear or not requires_room_clear(source_room) or state.is_room_completed(source_room.id)
	if is_entrance and connection.allow_entry_before_source_clear:
		# A rare lower-side enemy branch may be entered before its enemies are
		# cleared. The source room's own upper exit still uses the normal clear gate.
		source_clear_satisfied = true
	if not source_clear_satisfied:
		return false
	if is_entrance:
		# A reverse entrance must still honor the source room's forward gate; this
		# prevents a merge from becoming a backdoor into an uncleared enemy branch.
		# Once the source side is valid, the destination remains escapable until
		# the player lands the first hit there.
		var entrance_available := destination_room == null or not (connection.locks_entry_on_destination_engagement and requires_room_clear(destination_room) and state.is_room_engaged(destination_room.id) and not state.is_room_completed(destination_room.id))
		if entrance_available and gate_type == DungeonGraph.GATE_ELEMENT:
			state.mark_element_connection_solved(connection)
		if entrance_available and gate_type == DungeonGraph.GATE_ENTRANCE_ORB:
			state.mark_orb_connection_solved(connection)
		return entrance_available
	if gate_type == DungeonGraph.GATE_ELEMENT:
		state.mark_element_connection_solved(connection)
	elif gate_type == DungeonGraph.GATE_ENTRANCE_ORB:
		state.mark_orb_connection_solved(connection)
	return true


func is_connection_revealed(connection: DungeonGraph.ConnectionRecord) -> bool:
	return state.is_connection_revealed(connection)


func is_room_discovered(room_id: StringName) -> bool:
	return state.is_room_discovered(room_id)


func is_room_completed(room_id: StringName) -> bool:
	return state.is_room_completed(room_id)


func connection_visual_state(connection: DungeonGraph.ConnectionRecord, is_entrance: bool = false) -> StringName:
	if connection == null:
		return &"hidden"
	if is_connection_color_locked(connection):
		return &"orb_locked"
	if is_connection_orb_locked(connection):
		return &"orb_locked"
	if is_connection_element_locked(connection):
		return &"element_locked"
	if not is_connection_available(connection, is_entrance):
		return &"room_locked"
	return &"open"


func room_requires_open_entry(room: DungeonGraph.RoomRecord) -> bool:
	if room == null:
		return false
	return room.room_type == DungeonGraph.ROOM_START or room.room_type == DungeonGraph.ROOM_REST or room.room_type == DungeonGraph.ROOM_FIRE or room.room_type == DungeonGraph.ROOM_CLOAKED or room.room_type == DungeonGraph.ROOM_ORB


func decorative_door_pixels() -> Array[Dictionary]:
	return layout.decorative_door_pixels if layout != null else []


func _on_state_changed() -> void:
	map_state_changed.emit()
