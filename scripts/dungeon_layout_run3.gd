extends RefCounted
class_name DungeonLayoutRun3

## R3 is the first authored map compiled directly from a designer grid plan.
## Flame A follows the selected Hub flame; Flame B follows the first alternate
## primary flame available on this run.

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const COMPILER_SCRIPT = preload("res://scripts/puzzle_map_layout_compiler.gd")


static func build(selected_starter_flame: StringName = &"fire", rotation_quarter_turns: int = 0, selected_bound_flame: StringName = &""):
	var starter_flame: StringName = selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var alternates: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(2, starter_flame)
	# A permanent Hub bind is the flame the player actually starts this run with.
	# It must drive the run's puzzle Fire Room even when the profile's original
	# starter flame remains unchanged for save/profile identity.
	# Every R3 Fire Room uses the flame selected for this run in the Hub: a
	# run-start binding wins, otherwise the chosen starter flame remains the
	# fallback until a future run begins with a different binding.
	var run_flame: StringName = selected_bound_flame if ASPECT_CATALOG_SCRIPT.is_elemental_flame(selected_bound_flame) else starter_flame
	return COMPILER_SCRIPT.build_r3(starter_flame, run_flame, rotation_quarter_turns)
