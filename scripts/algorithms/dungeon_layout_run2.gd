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
const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/algorithms/dungeon_layout_definition.gd")
const ASPECT_CATALOG_SCRIPT = preload("res://scripts/content/aspect_catalog.gd")
const DATA := preload("res://resources/definitions/dungeon_layout_run2.tres") as DungeonRunDefinition

const STARTER_FLAME_TOKEN := &"<starter>"
const ALTERNATE_FLAME_TOKEN := &"<alternate>"


static func build(selected_starter_flame: StringName = &"fire"):
	var starter_flame := selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var alternate_flames: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(1, starter_flame)
	var alternate_flame: StringName = alternate_flames[0] if not alternate_flames.is_empty() else starter_flame
	var layout = LAYOUT_DEFINITION_SCRIPT.new(DATA.layout_id, DATA.map_size)
	LAYOUT_DEFINITION_SCRIPT.add_rooms_from_data(layout, DATA, _resolve_flame.bind(starter_flame, alternate_flame))
	LAYOUT_DEFINITION_SCRIPT.add_connections_from_data(layout, DATA)
	if DATA.apply_rare_enemy_branch_entry_exceptions:
		LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout


static func _resolve_flame(flame: StringName, starter_flame: StringName, alternate_flame: StringName) -> StringName:
	if flame == STARTER_FLAME_TOKEN:
		return starter_flame
	if flame == ALTERNATE_FLAME_TOKEN:
		return alternate_flame
	return flame