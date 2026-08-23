extends RefCounted
class_name AspectCatalog

const STARTER_FLAMES: Array[StringName] = [&"fire", &"water", &"electric"]
const STARTER_PALETTES: Dictionary = {
	&"fire": "red",
	&"water": "blue",
	&"electric": "yellow",
}
const DISPLAY_NAMES: Dictionary = {
	&"fire": "FIRE",
	&"water": "WATER",
	&"electric": "ELECTRIC",
}


static func is_starter_flame(flame: StringName) -> bool:
	return flame in STARTER_FLAMES


static func palette_for_flame(flame: StringName) -> String:
	return str(STARTER_PALETTES.get(flame, "grey"))


static func display_name(flame: StringName) -> String:
	return str(DISPLAY_NAMES.get(flame, "GRAY"))


static func flame_for_palette(palette: String) -> StringName:
	for flame: StringName in STARTER_FLAMES:
		if palette_for_flame(flame) == palette:
			return flame
	return &""


static func flames_available_for_run(completed_runs: int, starter_flame: StringName) -> Array[StringName]:
	var selected_starter := starter_flame if is_starter_flame(starter_flame) else STARTER_FLAMES[0]
	var available: Array[StringName] = [selected_starter]
	var target_count := clampi(completed_runs + 1, 1, STARTER_FLAMES.size())
	for flame: StringName in STARTER_FLAMES:
		if flame == selected_starter:
			continue
		if available.size() >= target_count:
			break
		available.append(flame)
	return available


static func alternate_flames_for_run(completed_runs: int, starter_flame: StringName) -> Array[StringName]:
	var available := flames_available_for_run(completed_runs, starter_flame)
	if available.size() <= 1:
		return []
	var alternates: Array[StringName] = []
	for index in range(1, available.size()):
		alternates.append(available[index])
	return alternates
