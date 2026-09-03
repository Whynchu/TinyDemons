extends RefCounted
class_name DungeonLayoutRun1

## Authored Run 1 teaching topology from Artwork/minimap- rough draftR1.png.
##
## The minimap coordinates are intentionally copied from the 16x23 authoring
## sketch. Runtime coordinates only provide stable room depth/seed values; the
## authored connections are the source of truth for traversal.

const MAP_SIZE := Vector2i(16, 23)
const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")


static func build():
	var layout = LAYOUT_DEFINITION_SCRIPT.new(&"RUN1", MAP_SIZE)
	_add_rooms(layout)
	_add_connections(layout)
	LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout


static func _add_rooms(layout) -> void:
	_room(layout, &"room_0_0", Vector2i(0, 0), Vector2i(8, 21), DungeonGraph.ROOM_START)
	# This is the first Orb Room: it is adjacent to the Hub and is the only
	# Orb Room that receives the triangle/square teaching prompt.
	_room(layout, &"room_-1_1", Vector2i(-1, 1), Vector2i(6, 19), DungeonGraph.ROOM_ORB)
	_room(layout, &"room_1_1", Vector2i(1, 1), Vector2i(10, 19), DungeonGraph.ROOM_COMBAT)

	# Preserve the original back-right wall placement in the first Treasure Room.
	_room(layout, &"room_-2_2", Vector2i(-2, 2), Vector2i(4, 17), DungeonGraph.ROOM_TREASURE, 1, &"", &"", Vector2(157, 69))
	_room(layout, &"room_0_3", Vector2i(0, 3), Vector2i(8, 17), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_1_4", Vector2i(1, 4), Vector2i(10, 15), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_0_5", Vector2i(0, 5), Vector2i(8, 13), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_2_5", Vector2i(2, 5), Vector2i(12, 13), DungeonGraph.ROOM_FIRE, 0, &"", &"fire")

	_room(layout, &"room_-1_6", Vector2i(-1, 6), Vector2i(6, 11), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_1_6", Vector2i(1, 6), Vector2i(10, 11), DungeonGraph.ROOM_CLOAKED)

	_room(layout, &"room_0_7", Vector2i(0, 7), Vector2i(8, 9), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_2_7", Vector2i(2, 7), Vector2i(12, 9), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_-3_8", Vector2i(-3, 8), Vector2i(4, 9), DungeonGraph.ROOM_TREASURE, 1, &"", &"", Vector2(157, 69))

	_room(layout, &"room_-1_9", Vector2i(-1, 9), Vector2i(6, 7), DungeonGraph.ROOM_COMBAT)
	_room(layout, &"room_1_9", Vector2i(1, 9), Vector2i(10, 7), DungeonGraph.ROOM_COMBAT)

	_room(layout, &"room_-2_11", Vector2i(-2, 11), Vector2i(4, 5), DungeonGraph.ROOM_BOSS)
	# Keep the reward on the rear half of the room. The floor center is around
	# (120, 88); a center anchor can leave the chest in the player's path and
	# makes the authored treasure placement look like a generated fallback.
	_room(layout, &"room_0_11", Vector2i(0, 11), Vector2i(8, 5), DungeonGraph.ROOM_TREASURE, 1, &"", &"", Vector2(128, 62))
	_room(layout, &"room_2_11", Vector2i(2, 11), Vector2i(12, 5), DungeonGraph.ROOM_ORB)


static func _add_connections(layout) -> void:
	# Both Hub exits are ordinary revealed connectors. The first Orb Room then
	# presents the two actual puzzle doors from the sketch: green/grey forward
	# and blue/selected-primary to the optional treasure branch.
	_link(layout, &"room_0_0", DungeonGraph.WALL_LEFT, &"room_-1_1", &"", Vector2i(7, 20))
	_link(layout, &"room_0_0", DungeonGraph.WALL_RIGHT, &"room_1_1", &"", Vector2i(9, 20))
	_link(layout, &"room_-1_1", DungeonGraph.WALL_LEFT, &"room_-2_2", &"puzzle_a", Vector2i(5, 18))
	_link(layout, &"room_-1_1", DungeonGraph.WALL_RIGHT, &"room_0_3", &"puzzle_b", Vector2i(7, 18))

	_link(layout, &"room_0_3", DungeonGraph.WALL_RIGHT, &"room_1_4", &"", Vector2i(9, 16))

	_link(layout, &"room_1_4", DungeonGraph.WALL_LEFT, &"room_0_5", &"", Vector2i(9, 14))
	_link(layout, &"room_1_4", DungeonGraph.WALL_RIGHT, &"room_2_5", &"", Vector2i(11, 14))
	_link(layout, &"room_0_5", DungeonGraph.WALL_LEFT, &"room_-1_6", &"", Vector2i(7, 12))
	_link(layout, &"room_0_5", DungeonGraph.WALL_RIGHT, &"room_1_6", &"", Vector2i(9, 12))
	_link(layout, &"room_2_5", DungeonGraph.WALL_LEFT, &"room_1_6", &"", Vector2i(11, 12))
	_link(layout, &"room_1_6", DungeonGraph.WALL_RIGHT, &"room_2_7", &"", Vector2i(11, 10))

	_link(layout, &"room_2_7", DungeonGraph.WALL_LEFT, &"room_1_9", &"", Vector2i(11, 8))
	# Keep the D9-area fork oriented like the map: room_0_7 is the lower
	# approach, so room_1_9 is reached through its lower-left entrance. The
	# previous version reversed this connector and put an upper-left wall door
	# in the wrong room.
	_link(layout, &"room_0_7", DungeonGraph.WALL_RIGHT, &"room_1_9", &"", Vector2i(9, 8))
	_link(layout, &"room_0_7", DungeonGraph.WALL_LEFT, &"room_-1_9", &"", Vector2i(7, 8))
	_link(layout, &"room_-3_8", DungeonGraph.WALL_RIGHT, &"room_-1_9", &"puzzle_b", Vector2i(5, 8))

	# The upper fork teaches that the selected primary color can choose either
	# of two routes. The upper-right Orb Room remains the same shared Orb type,
	# but it is not a tutorial prompt room.
	_link(layout, &"room_-1_9", DungeonGraph.WALL_LEFT, &"room_-2_11", &"puzzle_a", Vector2i(5, 6))
	_link(layout, &"room_1_9", DungeonGraph.WALL_LEFT, &"room_0_11", &"puzzle_a", Vector2i(9, 6))
	_link(layout, &"room_1_9", DungeonGraph.WALL_RIGHT, &"room_2_11", &"", Vector2i(11, 6))


static func _room(
	layout,
	id: StringName,
	coordinate: Vector2i,
	minimap_coordinate: Vector2i,
	room_type: StringName,
	chest_count: int = 0,
	respawn_color: StringName = &"",
	fire_flame: StringName = &"",
	chest_position: Vector2 = Vector2.ZERO
) -> void:
	layout.add_room(layout.make_room_spec(id, coordinate, minimap_coordinate, room_type, chest_count, respawn_color, 0, fire_flame, chest_position))


static func _link(
	layout,
	source_room_id: StringName,
	exit_socket: StringName,
	destination_room_id: StringName,
	color_requirement: StringName,
	minimap_coordinate: Vector2i
) -> void:
	var source: Variant = layout.room_by_id(source_room_id)
	var destination: Variant = layout.room_by_id(destination_room_id)
	if source == null or destination == null:
		return
	var destination_entry := DungeonGraph.BOTTOM_RIGHT if exit_socket == DungeonGraph.WALL_LEFT else DungeonGraph.BOTTOM_LEFT
	layout.add_connection(layout.make_connection_spec(
		source_room_id,
		exit_socket,
		destination_room_id,
		destination_entry,
		color_requirement,
		false,
		&"",
		minimap_coordinate
	))
