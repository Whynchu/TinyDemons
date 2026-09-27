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
	LAYOUT_DEFINITION_SCRIPT.add_rooms_from_data(layout, DATA)
	LAYOUT_DEFINITION_SCRIPT.add_connections_from_data(layout, DATA)
	if DATA.apply_rare_enemy_branch_entry_exceptions:
		LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout