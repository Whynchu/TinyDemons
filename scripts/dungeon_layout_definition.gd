extends RefCounted
class_name DungeonLayoutDefinition

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

## Immutable authored topology input for a run.
##
## The graph owns runtime room/connection records. This definition owns only
## the authored contract: coordinates, room categories, door requirements, and
## minimap placement.

class RoomSpec extends RefCounted:
	var id: StringName
	var coordinate := Vector2i.ZERO
	var minimap_coordinate := Vector2i.ZERO
	var room_type: StringName = DungeonGraph.ROOM_COMBAT
	var chest_count := 0
	## Local room-space placement for the authored chest. A zero vector means
	## that the runtime prefab default should be used (the generated grammar does
	## not need bespoke placement for every optional reward branch).
	var chest_position := Vector2.ZERO
	var special_respawn_required_color: StringName = &""
	var fire_flame: StringName = &""
	var seed_salt := 0

	func _init(
		new_id: StringName,
		new_coordinate: Vector2i,
		new_minimap_coordinate: Vector2i,
		new_room_type: StringName,
		new_chest_count: int = 0,
		new_respawn_color: StringName = &"",
		new_seed_salt: int = 0,
		new_fire_flame: StringName = &"",
		new_chest_position: Vector2 = Vector2.ZERO
	) -> void:
		id = new_id
		coordinate = new_coordinate
		minimap_coordinate = new_minimap_coordinate
		room_type = new_room_type
		chest_count = new_chest_count
		chest_position = new_chest_position
		special_respawn_required_color = new_respawn_color
		seed_salt = new_seed_salt
		fire_flame = new_fire_flame


	func to_dictionary() -> Dictionary:
		return {
			"id": id,
			"coordinate": coordinate,
			"minimap_coordinate": minimap_coordinate,
			"room_type": room_type,
			"chest_count": chest_count,
			"chest_position": chest_position,
			"special_respawn_required_color": special_respawn_required_color,
			"fire_flame": fire_flame,
			"seed_salt": seed_salt,
		}


class ConnectionSpec extends RefCounted:
	var source_room_id: StringName
	var exit_socket: StringName
	var destination_room_id: StringName
	var destination_entry: StringName
	var color_requirement: StringName = &""
	var hidden_until_clear := false
	var hidden_until_event: StringName = &""
	var minimap_coordinate := Vector2i.ZERO
	var requires_source_room_clear := true
	# Rare branch exception: the destination room may enter the source room
	# before that source enemy room is cleared, while the source's own exit
	# remains clear-gated.
	var allow_entry_before_source_clear := false
	var locks_entry_on_destination_engagement := true
	var route_role: StringName = &"main"
	var element_requirement: StringName = &""
	var gate_type: StringName = &""
	var orb_element_requirement: StringName = &""

	func _init(
		new_source_room_id: StringName,
		new_exit_socket: StringName,
		new_destination_room_id: StringName,
		new_destination_entry: StringName,
		new_color_requirement: StringName = &"",
		new_hidden_until_clear: bool = false,
		new_hidden_until_event: StringName = &"",
		new_minimap_coordinate: Vector2i = Vector2i.ZERO,
		new_requires_source_room_clear: bool = true,
		new_locks_entry_on_destination_engagement: bool = true,
		new_route_role: StringName = &"main",
		new_allow_entry_before_source_clear: bool = false,
		new_element_requirement: StringName = &"",
		new_gate_type: StringName = &"",
		new_orb_element_requirement: StringName = &""
	) -> void:
		source_room_id = new_source_room_id
		exit_socket = new_exit_socket
		destination_room_id = new_destination_room_id
		destination_entry = new_destination_entry
		color_requirement = new_color_requirement
		hidden_until_clear = new_hidden_until_clear
		hidden_until_event = new_hidden_until_event
		minimap_coordinate = new_minimap_coordinate
		requires_source_room_clear = new_requires_source_room_clear
		locks_entry_on_destination_engagement = new_locks_entry_on_destination_engagement
		route_role = new_route_role
		allow_entry_before_source_clear = new_allow_entry_before_source_clear
		element_requirement = new_element_requirement
		gate_type = new_gate_type
		orb_element_requirement = new_orb_element_requirement
		if gate_type.is_empty() or gate_type == DungeonGraph.GATE_NONE:
			if not orb_element_requirement.is_empty():
				gate_type = DungeonGraph.GATE_ENTRANCE_ORB
			elif not element_requirement.is_empty():
				gate_type = DungeonGraph.GATE_ELEMENT
			elif not color_requirement.is_empty():
				gate_type = DungeonGraph.GATE_PUZZLE_COLOR


	func resolved_gate_type() -> StringName:
		if not gate_type.is_empty() and gate_type != DungeonGraph.GATE_NONE:
			return gate_type
		if not orb_element_requirement.is_empty():
			return DungeonGraph.GATE_ENTRANCE_ORB
		if not element_requirement.is_empty():
			return DungeonGraph.GATE_ELEMENT
		if not color_requirement.is_empty():
			return DungeonGraph.GATE_PUZZLE_COLOR
		return DungeonGraph.GATE_NONE


	func to_dictionary() -> Dictionary:
		return {
			"source_room_id": source_room_id,
			"exit_socket": exit_socket,
			"destination_room_id": destination_room_id,
			"destination_entry": destination_entry,
			"color_requirement": color_requirement,
			"hidden_until_clear": hidden_until_clear,
			"hidden_until_event": hidden_until_event,
			"minimap_coordinate": minimap_coordinate,
			"requires_source_room_clear": requires_source_room_clear,
			"allow_entry_before_source_clear": allow_entry_before_source_clear,
			"locks_entry_on_destination_engagement": locks_entry_on_destination_engagement,
			"route_role": route_role,
			"element_requirement": element_requirement,
			"gate_type": resolved_gate_type(),
			"orb_element_requirement": orb_element_requirement,
		}


var layout_id: StringName = &""
var map_size := Vector2i(16, 23)
var rooms: Array[RoomSpec] = []
var connections: Array[ConnectionSpec] = []
var decorative_door_pixels: Array[Dictionary] = []


func _init(new_layout_id: StringName = &"", new_map_size: Vector2i = Vector2i(16, 23)) -> void:
	layout_id = new_layout_id
	map_size = new_map_size


func add_room(spec: RoomSpec) -> RoomSpec:
	rooms.append(spec)
	return spec


func make_room_spec(
	new_id: StringName,
	new_coordinate: Vector2i,
	new_minimap_coordinate: Vector2i,
	new_room_type: StringName,
	new_chest_count: int = 0,
	new_respawn_color: StringName = &"",
	new_seed_salt: int = 0,
	new_fire_flame: StringName = &"",
	new_chest_position: Vector2 = Vector2.ZERO
) -> RoomSpec:
	return RoomSpec.new(new_id, new_coordinate, new_minimap_coordinate, new_room_type, new_chest_count, new_respawn_color, new_seed_salt, new_fire_flame, new_chest_position)


func add_connection(spec: ConnectionSpec) -> ConnectionSpec:
	connections.append(spec)
	return spec


static func apply_rare_enemy_branch_entry_exceptions(layout) -> void:
	if layout == null:
		return
	for connection in layout.connections:
		if connection.allow_entry_before_source_clear:
			continue
		var source = layout.room_by_id(connection.source_room_id)
		var destination = layout.room_by_id(connection.destination_room_id)
		if source == null or destination == null:
			continue
		var source_delta: Vector2i = source.minimap_coordinate - destination.minimap_coordinate
		var is_lower_left_branch: bool = connection.destination_entry == DungeonGraph.BOTTOM_LEFT and source_delta == Vector2i(-2, 2)
		var is_lower_right_branch: bool = connection.destination_entry == DungeonGraph.BOTTOM_RIGHT and source_delta == Vector2i(2, 2)
		if not is_lower_left_branch and not is_lower_right_branch:
			continue
		# These rare branch entries point down-left or down-right into a room
		# whose red/puzzle-A exit is the actual progression gate. Open only the
		# destination-side entrance before the branch room is cleared; the branch
		# room's own upper exit remains governed by its normal clear gate.
		if not _room_has_enemy_clear_gate(source.room_type):
			continue
		if not _room_has_enemy_clear_gate(destination.room_type):
			continue
		if not _room_has_puzzle_a_exit(layout, destination.id):
			continue
		connection.allow_entry_before_source_clear = true


static func _room_has_enemy_clear_gate(room_type: StringName) -> bool:
	return room_type == DungeonGraph.ROOM_COMBAT or room_type == DungeonGraph.ROOM_SPECIAL_ENEMY or room_type == DungeonGraph.ROOM_TREASURE


static func _room_has_puzzle_a_exit(layout, room_id: StringName) -> bool:
	for connection in layout.connections:
		if connection.source_room_id == room_id and connection.color_requirement == &"puzzle_a":
			return true
	return false


func make_connection_spec(
	new_source_room_id: StringName,
	new_exit_socket: StringName,
	new_destination_room_id: StringName,
	new_destination_entry: StringName,
	new_color_requirement: StringName = &"",
	new_hidden_until_clear: bool = false,
	new_hidden_until_event: StringName = &"",
	new_minimap_coordinate: Vector2i = Vector2i.ZERO,
	new_requires_source_room_clear: bool = true,
	new_locks_entry_on_destination_engagement: bool = true,
	new_route_role: StringName = &"main",
	new_allow_entry_before_source_clear: bool = false,
	new_element_requirement: StringName = &"",
	new_gate_type: StringName = &"",
	new_orb_element_requirement: StringName = &""
) -> ConnectionSpec:
	return ConnectionSpec.new(new_source_room_id, new_exit_socket, new_destination_room_id, new_destination_entry, new_color_requirement, new_hidden_until_clear, new_hidden_until_event, new_minimap_coordinate, new_requires_source_room_clear, new_locks_entry_on_destination_engagement, new_route_role, new_allow_entry_before_source_clear, new_element_requirement, new_gate_type, new_orb_element_requirement)


func add_decorative_door(pixel: Vector2i, color_requirement: StringName = &"", source_room_id: StringName = &"") -> void:
	decorative_door_pixels.append({
		"coordinate": pixel,
		"color_requirement": color_requirement,
		"source_room_id": source_room_id,
	})


func room_by_id(room_id: StringName) -> RoomSpec:
	for spec in rooms:
		if spec.id == room_id:
			return spec
	return null


func room_by_coordinate(room_coordinate: Vector2i) -> RoomSpec:
	for spec in rooms:
		if spec.coordinate == room_coordinate:
			return spec
	return null


func room_by_minimap_coordinate(map_coordinate: Vector2i) -> RoomSpec:
	for spec in rooms:
		if spec.minimap_coordinate == map_coordinate:
			return spec
	return null


func to_dictionary() -> Dictionary:
	var room_data: Array[Dictionary] = []
	for spec in rooms:
		room_data.append(spec.to_dictionary())
	var connection_data: Array[Dictionary] = []
	for spec in connections:
		connection_data.append(spec.to_dictionary())
	return {
		"layout_id": layout_id,
		"map_size": map_size,
		"rooms": room_data,
		"connections": connection_data,
		"decorative_door_pixels": decorative_door_pixels.duplicate(true),
	}


func validate() -> Array[String]:
	var errors: Array[String] = []
	var room_ids: Dictionary = {}
	var minimap_coordinates: Dictionary = {}
	var start_count := 0
	var boss_count := 0
	var cloaked_count := 0
	var orb_room_count := 0
	var connection_sockets: Dictionary = {}
	var coordinates: Dictionary = {}
	for spec in rooms:
		if room_ids.has(spec.id):
			errors.append("duplicate room id: %s" % spec.id)
		room_ids[spec.id] = true
		if coordinates.has(spec.coordinate):
			errors.append("duplicate room coordinate: %s" % spec.coordinate)
		coordinates[spec.coordinate] = true
		if minimap_coordinates.has(spec.minimap_coordinate):
			errors.append("duplicate minimap coordinate: %s" % spec.minimap_coordinate)
		minimap_coordinates[spec.minimap_coordinate] = true
		if spec.room_type == DungeonGraph.ROOM_START:
			start_count += 1
		elif spec.room_type == DungeonGraph.ROOM_BOSS:
			boss_count += 1
		elif spec.room_type == DungeonGraph.ROOM_CLOAKED:
			cloaked_count += 1
		if spec.room_type == DungeonGraph.ROOM_ORB:
			orb_room_count += 1
		if spec.chest_count < 0:
			errors.append("room has a negative chest count: %s" % spec.id)
		if spec.room_type == DungeonGraph.ROOM_TREASURE and spec.chest_count != 1:
			errors.append("Treasure Room must contain exactly one chest: %s" % spec.id)
		if layout_id == &"RUN1" and spec.room_type == DungeonGraph.ROOM_TREASURE and spec.chest_position == Vector2.ZERO:
			errors.append("Run 1 Treasure Room is missing an authored chest placement: %s" % spec.id)
		if spec.room_type == DungeonGraph.ROOM_FIRE and layout_id == &"RUN_GENERATED" and spec.fire_flame.is_empty():
			errors.append("generated Fire Room is missing a flame: %s" % spec.id)
		if spec.room_type == DungeonGraph.ROOM_FIRE and not spec.fire_flame.is_empty() and not AspectCatalogScript.is_elemental_flame(spec.fire_flame):
			errors.append("unknown Fire Room flame: %s" % spec.fire_flame)
	if start_count != 1:
		errors.append("expected exactly one Hub room")
	if boss_count != 1:
		errors.append("expected exactly one Boss room")
	if cloaked_count != 1:
		errors.append("expected exactly one Cloaked room")
	if layout_id == &"RUN1" and orb_room_count != 2:
		errors.append("Run 1 expects exactly two identical Orb Rooms")
	if not rooms.is_empty() and start_count == 1:
		var reachable: Dictionary = {}
		var pending: Array[StringName] = []
		for spec in rooms:
			if spec.room_type == DungeonGraph.ROOM_START:
				reachable[spec.id] = true
				pending.append(spec.id)
		while not pending.is_empty():
			var room_id: StringName = pending.pop_back() as StringName
			for connection in connections:
				var adjacent_id: StringName = &""
				if connection.source_room_id == room_id:
					adjacent_id = connection.destination_room_id
				elif connection.destination_room_id == room_id:
					adjacent_id = connection.source_room_id
				if adjacent_id.is_empty() or reachable.has(adjacent_id):
					continue
				reachable[adjacent_id] = true
				pending.append(adjacent_id)
		if reachable.size() != room_ids.size():
			for room_id in room_ids:
				if not reachable.has(room_id):
					errors.append("room is unreachable from the Hub: %s" % room_id)
	for spec in connections:
		if not room_ids.has(spec.source_room_id):
			errors.append("connection source is missing: %s" % spec.source_room_id)
		if not spec.destination_room_id.is_empty() and not room_ids.has(spec.destination_room_id):
			errors.append("connection destination is missing: %s" % spec.destination_room_id)
		var socket_key := "%s:%s" % [spec.source_room_id, spec.exit_socket]
		if connection_sockets.has(socket_key):
			errors.append("duplicate authored exit socket: %s" % socket_key)
		connection_sockets[socket_key] = true
		if layout_id == &"RUN1" and room_ids.has(spec.source_room_id) and room_ids.has(spec.destination_room_id):
			var source_spec := room_by_id(spec.source_room_id)
			var destination_spec := room_by_id(spec.destination_room_id)
			var map_delta: Vector2i = destination_spec.minimap_coordinate - source_spec.minimap_coordinate
			var expected_delta := Vector2i(-2, -2) if spec.exit_socket == DungeonGraph.WALL_LEFT else Vector2i(2, -2)
			if map_delta != expected_delta:
				errors.append("Run 1 connector is not oriented from the lower map room to its upper destination: %s:%s -> %s" % [spec.source_room_id, spec.exit_socket, spec.destination_room_id])
			var expected_entry := DungeonGraph.BOTTOM_RIGHT if spec.exit_socket == DungeonGraph.WALL_LEFT else DungeonGraph.BOTTOM_LEFT
			if spec.destination_entry != expected_entry:
				errors.append("Run 1 connector has the wrong paired lower entrance: %s:%s" % [spec.source_room_id, spec.exit_socket])
		if not spec.color_requirement.is_empty() and spec.color_requirement not in [&"puzzle_a", &"puzzle_b", &"puzzle_c", &"puzzle_d"]:
			errors.append("unknown puzzle-color door key: %s" % spec.color_requirement)
		if not spec.element_requirement.is_empty() and not ElementCatalogScript.is_valid_id(spec.element_requirement):
			errors.append("unknown elemental door key: %s" % spec.element_requirement)
		if not spec.orb_element_requirement.is_empty() and not ElementCatalogScript.is_valid_id(spec.orb_element_requirement):
			errors.append("unknown entrance-orb door key: %s" % spec.orb_element_requirement)
		var resolved_gate_type := spec.resolved_gate_type()
		if resolved_gate_type not in DungeonGraph.VALID_GATE_TYPES:
			errors.append("unknown connection gate type: %s" % resolved_gate_type)
		if resolved_gate_type == DungeonGraph.GATE_ENTRANCE_ORB and spec.orb_element_requirement.is_empty():
			errors.append("entrance-orb gate is missing its elemental requirement: %s:%s" % [spec.source_room_id, spec.exit_socket])
		if resolved_gate_type == DungeonGraph.GATE_PUZZLE_COLOR and spec.color_requirement.is_empty():
			errors.append("puzzle-color gate is missing its color requirement: %s:%s" % [spec.source_room_id, spec.exit_socket])
		if resolved_gate_type != DungeonGraph.GATE_PUZZLE_COLOR and not spec.color_requirement.is_empty():
			errors.append("non-puzzle-color gate carries a puzzle-color requirement: %s:%s" % [spec.source_room_id, spec.exit_socket])
		if resolved_gate_type != DungeonGraph.GATE_ENTRANCE_ORB and not spec.orb_element_requirement.is_empty():
			errors.append("non-entrance-orb gate carries an orb requirement: %s:%s" % [spec.source_room_id, spec.exit_socket])
		if resolved_gate_type == DungeonGraph.GATE_ELEMENT and spec.element_requirement.is_empty():
			errors.append("element gate is missing its elemental requirement: %s:%s" % [spec.source_room_id, spec.exit_socket])
		if resolved_gate_type != DungeonGraph.GATE_ELEMENT and not spec.element_requirement.is_empty():
			errors.append("non-element gate carries an elemental requirement: %s:%s" % [spec.source_room_id, spec.exit_socket])
		if spec.route_role.is_empty():
			errors.append("connection route role is empty: %s:%s" % [spec.source_room_id, spec.exit_socket])
	for decorative_door in decorative_door_pixels:
		var decorative_requirement: StringName = decorative_door.get("color_requirement", &"")
		if not decorative_requirement.is_empty() and decorative_requirement not in [&"puzzle_a", &"puzzle_b", &"puzzle_c", &"puzzle_d"]:
			errors.append("unknown decorative puzzle-color door key: %s" % decorative_requirement)
	return errors
