@tool
extends Resource
class_name PaletteLibraryData

## Editor-inspectable palette color tables. PaletteLibrary keeps its static
## lookup API over this resource; the authored colors live here so the editor
## can inspect and retune presentation tones.

@export var palette_names: Array[String] = []
@export var selectable_palettes: Array[String] = []
@export var rest_fire_palettes: Array[String] = []
@export var shadow: Dictionary = {}
@export var normal: Dictionary = {}
@export var accent: Dictionary = {}
@export var archetype_highlights: Array[Color] = []
@export var white: Color = Color.WHITE


func validate() -> Array[String]:
	var problems: Array[String] = []
	var registered_names: Dictionary = {}
	for index in palette_names.size():
		var palette_name := palette_names[index].strip_edges()
		if palette_name.is_empty():
			problems.append("palette name %d must not be empty" % index)
		elif palette_name != palette_names[index]:
			problems.append("palette name %d must not have surrounding whitespace" % index)
		elif registered_names.has(palette_name):
			problems.append("duplicate palette name '%s'" % palette_name)
		registered_names[palette_name] = true
	if registered_names.is_empty():
		problems.append("palette_names must not be empty")
	_validate_palette_subset(selectable_palettes, "selectable_palettes", registered_names, problems)
	_validate_palette_subset(rest_fire_palettes, "rest_fire_palettes", registered_names, problems)
	var selectable_names: Dictionary = {}
	for palette_name in selectable_palettes:
		selectable_names[palette_name] = true
	for palette_name in rest_fire_palettes:
		if not selectable_names.has(palette_name):
			problems.append("rest_fire_palettes contains non-selectable palette '%s'" % palette_name)
	_validate_color_table(shadow, "shadow", problems)
	_validate_color_table(normal, "normal", problems)
	_validate_color_table(accent, "accent", problems)
	if archetype_highlights.is_empty():
		problems.append("archetype_highlights must not be empty")
	return problems


func _validate_palette_subset(values: Array[String], label: String, registered_names: Dictionary, problems: Array[String]) -> void:
	if values.is_empty():
		problems.append("%s must not be empty" % label)
	var seen: Dictionary = {}
	for value in values:
		if not registered_names.has(value):
			problems.append("%s references unknown palette '%s'" % [label, value])
		if seen.has(value):
			problems.append("%s contains duplicate palette '%s'" % [label, value])
		seen[value] = true


func _validate_color_table(table: Dictionary, label: String, problems: Array[String]) -> void:
	for palette_name in palette_names:
		if not table.has(palette_name):
			problems.append("%s is missing palette '%s'" % [label, palette_name])
	for raw_name: Variant in table:
		if not raw_name is String and not raw_name is StringName:
			problems.append("%s contains a non-string palette key" % label)
		elif str(raw_name).strip_edges().is_empty():
			problems.append("%s contains an empty palette key" % label)
		if not table[raw_name] is Color:
			problems.append("%s palette '%s' must contain a Color" % [label, str(raw_name)])
