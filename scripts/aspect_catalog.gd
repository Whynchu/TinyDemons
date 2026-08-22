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
