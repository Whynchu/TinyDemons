extends RefCounted
class_name AspectCatalog

const STARTER_FLAMES: Array[StringName] = [&"fire", &"water", &"electric"]
const ELEMENTAL_FLAMES: Array[StringName] = [&"fire", &"water", &"electric", &"grass", &"shadow", &"ground", &"ice"]
const STARTER_PALETTES: Dictionary = {
	&"fire": "red",
	&"water": "blue",
	&"electric": "yellow",
	&"grass": "green",
	&"shadow": "purple",
	&"ground": "orange",
	&"ice": "aquamarine",
}
const DISPLAY_NAMES: Dictionary = {
	&"fire": "FIRE",
	&"water": "WATER",
	&"electric": "ELECTRIC",
	&"grass": "GRASS",
	&"shadow": "SHADOW",
	&"ground": "GROUND",
	&"ice": "ICE",
}

## Fusion is a deliberately small data table. Keys are canonicalized by
## fusion_result(), so the order of the two contacted flames never matters.
const FUSION_RECIPES: Dictionary = {
	"fire|water": &"shadow",
	"electric|fire": &"ground",
	"electric|water": &"grass",
	"grass|water": &"ice",
}


static func is_starter_flame(flame: StringName) -> bool:
	return flame in STARTER_FLAMES


static func is_elemental_flame(flame: StringName) -> bool:
	return flame in ELEMENTAL_FLAMES


static func palette_for_flame(flame: StringName) -> String:
	return str(STARTER_PALETTES.get(flame, "grey"))


static func display_name(flame: StringName) -> String:
	return str(DISPLAY_NAMES.get(flame, "NORMAL"))


static func flame_for_palette(palette: String) -> StringName:
	var normalized_palette := palette.to_lower()
	if normalized_palette == "gray":
		normalized_palette = "grey"
	for flame: StringName in ELEMENTAL_FLAMES:
		if palette_for_flame(flame) == normalized_palette:
			return flame
	return &""


static func fusion_result(first_flame: StringName, second_flame: StringName) -> StringName:
	if not is_elemental_flame(first_flame) or not is_elemental_flame(second_flame) or first_flame == second_flame:
		return &""
	var pair: Array[String] = [String(first_flame), String(second_flame)]
	pair.sort()
	return FUSION_RECIPES.get("%s|%s" % [pair[0], pair[1]], &"") as StringName


static func fusion_recipes() -> Dictionary:
	return FUSION_RECIPES.duplicate()


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
