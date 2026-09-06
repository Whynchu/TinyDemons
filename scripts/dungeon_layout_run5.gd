extends RefCounted
class_name DungeonLayoutRun5

## R5 is the third authored map compiled from a designer grid plan. Like R4,
## Flame A follows the selected Hub flame and Flame B follows the first
## alternate primary flame available on this run.

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const COMPILER_SCRIPT = preload("res://scripts/puzzle_map_layout_compiler.gd")


static func build(selected_starter_flame: StringName = &"fire"):
	var starter_flame: StringName = selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var alternates: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(4, starter_flame)
	var run_flame: StringName = alternates[0] if not alternates.is_empty() else starter_flame
	return COMPILER_SCRIPT.build_r5(starter_flame, run_flame)
