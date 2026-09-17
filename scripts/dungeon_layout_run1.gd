extends RefCounted
class_name DungeonLayoutRun1

## Authored Run 1 teaching topology from Artwork/minimap- rough draftR1.png.
##
## The authored room/connection data now lives in
## resources/definitions/dungeon_layout_run1.tres (editor-inspectable); this
## builder loads it and assembles the runtime layout with the same flame and
## exception policy as before.

const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")
const DATA := preload("res://resources/definitions/dungeon_layout_run1.tres") as DungeonRunDefinition


static func build():
	var layout = LAYOUT_DEFINITION_SCRIPT.new(DATA.layout_id, DATA.map_size)
	_add_rooms(layout)
	_add_connections(layout)
	if DATA.apply_rare_enemy_branch_entry_exceptions:
		LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout


static func _add_rooms(layout) -> void:
	for entry in DATA.rooms:
		var room := entry as Dictionary
		layout.add_room(layout.make_room_spec(
			room["id"] as StringName,
			room["coordinate"] as Vector2i,
			room["minimap_coordinate"] as Vector2i,
			room["room_type"] as StringName,
			int(room.get("chest_count", 0)),
			room.get("respawn_color", &"") as StringName,
			0,
			room.get("fire_flame", &"") as StringName,
			room.get("chest_position", Vector2.ZERO) as Vector2
		))


static func _add_connections(layout) -> void:
	for entry in DATA.connections:
		var link := entry as Dictionary
		var source: Variant = layout.room_by_id(link["source_room_id"] as StringName)
		var destination: Variant = layout.room_by_id(link["destination_room_id"] as StringName)
		if source == null or destination == null:
			continue
		var exit_socket := link["exit_socket"] as StringName
		var destination_entry := DungeonGraph.paired_socket(exit_socket)
		layout.add_connection(layout.make_connection_spec(
			link["source_room_id"] as StringName,
			exit_socket,
			link["destination_room_id"] as StringName,
			destination_entry,
			link.get("color_requirement", &"") as StringName,
			false,
			&"",
			link.get("minimap_coordinate", Vector2i.ZERO) as Vector2i
		))