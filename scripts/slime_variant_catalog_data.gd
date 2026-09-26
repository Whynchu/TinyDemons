@tool
extends Resource
class_name SlimeVariantCatalogData

## Editor-inspectable slime variant definitions. Existing entries may remain
## embedded sub-resources for compatibility, while standalone EnemyDefinition
## resources in this directory are discovered as authored content. That gives
## content authors a one-file path without introducing a second runtime list.

@export var definitions: Array[Resource] = []

const DEFINITION_ROOT := "res://resources/definitions"
const CATALOG_FILE := "slime_variant_catalog.tres"


func authored_definitions() -> Array[EnemyDefinition]:
	var result: Array[EnemyDefinition] = []
	for entry in definitions:
		var definition := entry as EnemyDefinition
		if definition != null:
			result.append(definition)

	var external_paths: Array[String] = []
	var directory := DirAccess.open(DEFINITION_ROOT)
	if directory != null:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if entry != "." and entry != ".." and not directory.current_is_dir() and entry.get_extension().to_lower() == "tres" and entry != CATALOG_FILE:
				external_paths.append(DEFINITION_ROOT.path_join(entry))
			entry = directory.get_next()
		directory.list_dir_end()

	external_paths.sort()
	for path in external_paths:
		var definition := load(path) as EnemyDefinition
		if definition != null:
			result.append(definition)
	return result


func validate() -> Array[String]:
	var problems: Array[String] = []
	var authored := authored_definitions()
	if authored.is_empty():
		problems.append("slime variant definitions are empty")
	var seen: Dictionary = {}
	for entry in definitions:
		if entry as EnemyDefinition == null:
			problems.append("slime variant catalog contains a non-EnemyDefinition entry")
	for definition in authored:
		if definition.type_id not in [&"slime", &"skeleton"]:
			problems.append("%s: unsupported enemy type_id '%s'" % [definition.variant_id, definition.type_id])
		if seen.has(definition.variant_id):
			problems.append("duplicate enemy variant id '%s'" % definition.variant_id)
		seen[definition.variant_id] = true
		for problem in definition.validate():
			problems.append("%s: %s" % [definition.variant_id, problem])
	return problems
