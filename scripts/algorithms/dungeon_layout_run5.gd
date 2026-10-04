extends RefCounted
class_name DungeonLayoutRun5

## R5 promotes the previous authored R4 map. Like R4,
## Flame A follows the selected Hub flame and Flame B follows the first
## alternate primary flame available on this run.

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/content/aspect_catalog.gd")
const COMPILER_SCRIPT = preload("res://scripts/algorithms/puzzle_map_layout_compiler.gd")


static func build(selected_starter_flame: StringName = &"fire", rotation_quarter_turns: int = 0):
	var starter_flame: StringName = selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var alternates: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(4, starter_flame)
	var run_flame: StringName = alternates[0] if not alternates.is_empty() else starter_flame
	return COMPILER_SCRIPT.build_r5(starter_flame, run_flame, rotation_quarter_turns)
