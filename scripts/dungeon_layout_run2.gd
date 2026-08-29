extends RefCounted
class_name DungeonLayoutRun2

## The former authored Run 1 map, promoted intact to Run 2.
##
## Keeping this as a separate definition is deliberate: Run 2 is the first
## expansion of the authored language, while Run 3+ can use the procedural
## grammar without changing the player's known second-run route.

const MAP_SIZE := Vector2i(16, 23)
const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")
const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")


static func build(selected_starter_flame: StringName = &"fire"):
	var starter_flame := selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var alternate_flames: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(1, starter_flame)
	var alternate_flame: StringName = alternate_flames[0] if not alternate_flames.is_empty() else starter_flame
	var layout = LAYOUT_DEFINITION_SCRIPT.new(&"RUN2", MAP_SIZE)
	_add_rooms(layout, starter_flame, alternate_flame)
	_add_connections(layout)
	LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout


static func _add_rooms(layout, starter_flame: StringName, alternate_flame: StringName) -> void:
	_room(layout, &"room_0_0", Vector2i(0, 0), Vector2i(8, 21), DungeonGraph.ROOM_START)
	_room(layout, &"room_-1_1", Vector2i(-1, 1), Vector2i(6, 19), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_1_1", Vector2i(1, 1), Vector2i(10, 19), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_-2_2", Vector2i(-2, 2), Vector2i(4, 17), DungeonGraph.ROOM_SPECIAL_ENEMY, 0, &"puzzle_a")
	_room(layout, &"room_0_2", Vector2i(0, 2), Vector2i(8, 17), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_2_2", Vector2i(2, 2), Vector2i(12, 17), DungeonGraph.ROOM_ORB)

	_room(layout, &"room_-3_3", Vector2i(-3, 3), Vector2i(2, 15), DungeonGraph.ROOM_TREASURE, 1)
	_room(layout, &"room_-1_3", Vector2i(-1, 3), Vector2i(6, 15), DungeonGraph.ROOM_COMBAT)

	# Run 2 exposes the first unchosen primary flame here, while the second
	# Fire Room remains a source for the selected starter palette.
	_room(layout, &"room_-2_4", Vector2i(-2, 4), Vector2i(4, 13), DungeonGraph.ROOM_FIRE, 0, &"", alternate_flame)
	_room(layout, &"room_0_4", Vector2i(0, 4), Vector2i(8, 13), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_-1_5", Vector2i(-1, 5), Vector2i(6, 11), DungeonGraph.ROOM_CLOAKED)
	_room(layout, &"room_1_5", Vector2i(1, 5), Vector2i(10, 11), DungeonGraph.ROOM_TREASURE, 1)

	_room(layout, &"room_-2_6", Vector2i(-2, 6), Vector2i(4, 9), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_0_6", Vector2i(0, 6), Vector2i(8, 9), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_-3_7", Vector2i(-3, 7), Vector2i(2, 7), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_-1_7", Vector2i(-1, 7), Vector2i(6, 7), DungeonGraph.ROOM_FIRE, 0, &"", starter_flame)
	_room(layout, &"room_1_7", Vector2i(1, 7), Vector2i(10, 7), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_-2_8", Vector2i(-2, 8), Vector2i(4, 5), DungeonGraph.ROOM_ORB)
	_room(layout, &"room_0_8", Vector2i(0, 8), Vector2i(8, 5), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_2_8", Vector2i(2, 8), Vector2i(12, 5), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_-1_9", Vector2i(-1, 9), Vector2i(6, 3), DungeonGraph.ROOM_SPECIAL_ENEMY, 0, &"puzzle_b")
	_room(layout, &"room_3_9", Vector2i(3, 9), Vector2i(14, 3), DungeonGraph.ROOM_TREASURE, 1)
	_room(layout, &"room_-2_10", Vector2i(-2, 10), Vector2i(4, 1), DungeonGraph.ROOM_TREASURE, 1)

	_room(layout, &"room_0_10", Vector2i(0, 10), Vector2i(8, 1), DungeonGraph.ROOM_BOSS)


static func _add_connections(layout) -> void:
	_link(layout, &"room_0_0", DungeonGraph.WALL_LEFT, &"room_-1_1")
	_link(layout, &"room_0_0", DungeonGraph.WALL_RIGHT, &"room_1_1")
	_link(layout, &"room_-1_1", DungeonGraph.WALL_LEFT, &"room_-2_2")
	_link(layout, &"room_-1_1", DungeonGraph.WALL_RIGHT, &"room_0_2")
	_link(layout, &"room_1_1", DungeonGraph.WALL_RIGHT, &"room_2_2")

	# The first Special Room keeps its optional grey-key Treasure branch and its
	# selected-primary forward branch from the former authored Run 1 route.
	_link(layout, &"room_-2_2", DungeonGraph.WALL_LEFT, &"room_-3_3", &"puzzle_b")
	_link(layout, &"room_-2_2", DungeonGraph.WALL_RIGHT, &"room_-1_3", &"puzzle_a")
	_link(layout, &"room_-1_3", DungeonGraph.WALL_LEFT, &"room_-2_4")
	_link(layout, &"room_-1_3", DungeonGraph.WALL_RIGHT, &"room_0_4")
	_link(layout, &"room_0_4", DungeonGraph.WALL_LEFT, &"room_-1_5")
	_link(layout, &"room_0_4", DungeonGraph.WALL_RIGHT, &"room_1_5")
	_link(layout, &"room_-1_5", DungeonGraph.WALL_LEFT, &"room_-2_6")
	_link(layout, &"room_-1_5", DungeonGraph.WALL_RIGHT, &"room_0_6")
	_link(layout, &"room_-2_6", DungeonGraph.WALL_LEFT, &"room_-3_7")
	_link(layout, &"room_0_6", DungeonGraph.WALL_RIGHT, &"room_1_7")
	_link(layout, &"room_-3_7", DungeonGraph.WALL_RIGHT, &"room_-2_8")
	_link(layout, &"room_-1_7", DungeonGraph.WALL_RIGHT, &"room_0_8")
	_link(layout, &"room_1_7", DungeonGraph.WALL_LEFT, &"room_0_8")
	_link(layout, &"room_1_7", DungeonGraph.WALL_RIGHT, &"room_2_8")
	_link(layout, &"room_0_8", DungeonGraph.WALL_LEFT, &"room_-1_9")
	_link(layout, &"room_2_8", DungeonGraph.WALL_RIGHT, &"room_3_9", &"puzzle_b")
	_link(layout, &"room_-1_9", DungeonGraph.WALL_LEFT, &"room_-2_10", &"puzzle_a")
	_link(layout, &"room_-1_9", DungeonGraph.WALL_RIGHT, &"room_0_10", &"puzzle_b")


static func _room(
	layout,
	id: StringName,
	coordinate: Vector2i,
	minimap_coordinate: Vector2i,
	room_type: StringName,
	chest_count: int = 0,
	respawn_color: StringName = &"",
	fire_flame: StringName = &""
) -> void:
	layout.add_room(layout.make_room_spec(id, coordinate, minimap_coordinate, room_type, chest_count, respawn_color, 0, fire_flame))


static func _link(
	layout,
	source_room_id: StringName,
	exit_socket: StringName,
	destination_room_id: StringName,
	color_requirement: StringName = &""
) -> void:
	var source: Variant = layout.room_by_id(source_room_id)
	var destination: Variant = layout.room_by_id(destination_room_id)
	if source == null or destination == null:
		return
	var destination_entry := DungeonGraph.BOTTOM_RIGHT if exit_socket == DungeonGraph.WALL_LEFT else DungeonGraph.BOTTOM_LEFT
	var midpoint_sum: Vector2i = source.minimap_coordinate + destination.minimap_coordinate
	var midpoint: Vector2i = Vector2i(int(float(midpoint_sum.x) / 2.0), int(float(midpoint_sum.y) / 2.0))
	layout.add_connection(layout.make_connection_spec(source_room_id, exit_socket, destination_room_id, destination_entry, color_requirement, false, &"", midpoint))
