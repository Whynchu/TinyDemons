extends RefCounted
class_name DungeonLayoutRun2

## The former authored Run 1 map, promoted intact to Run 2.
##
## Keeping this as a separate definition is deliberate: Run 2 is the first
## expansion of the authored language, while Run 3+ can use the procedural
## grammar without changing the player's known second-run route.
##
## The authored room/connection data now lives in
## resources/definitions/dungeon_layout_run2.tres (editor-inspectable). The two
## fire rooms that depend on the selected starter flame keep sentinel flame
## tokens (&"<starter>"/&"<alternate>") so the runtime flame-selection logic
## stays in this builder.

const MAP_SIZE := Vector2i(16, 23)
const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")
const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const DATA := preload("res://resources/definitions/dungeon_layout_run2.tres") as DungeonRunDefinition

const STARTER_FLAME_TOKEN := &"<starter>"
const ALTERNATE_FLAME_TOKEN := &"<alternate>"


static func build(selected_starter_flame: StringName = &"fire"):
	var starter_flame := selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var alternate_flames: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(1, starter_flame)
	var alternate_flame: StringName = alternate_flames[0] if not alternate_flames.is_empty() else starter_flame
	var layout = LAYOUT_DEFINITION_SCRIPT.new(DATA.layout_id, DATA.map_size)
	_add_rooms(layout, starter_flame, alternate_flame)
	_add_connections(layout)
	if DATA.apply_rare_enemy_branch_entry_exceptions:
		LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout


static func _add_rooms(layout, starter_flame: StringName, alternate_flame: StringName) -> void:
	for entry in DATA.rooms:
		var room := entry as Dictionary
		var room_id := room["id"] as StringName
		var room_flame := room.get("fire_flame", &"") as StringName
		if room_flame == STARTER_FLAME_TOKEN:
			room_flame = starter_flame
		elif room_flame == ALTERNATE_FLAME_TOKEN:
			room_flame = alternate_flame
		layout.add_room(layout.make_room_spec(
			room_id,
			room["coordinate"] as Vector2i,
			room["minimap_coordinate"] as Vector2i,
			room["room_type"] as StringName,
			int(room.get("chest_count", 0)),
			room.get("respawn_color", &"") as StringName,
			0,
			room_flame,
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