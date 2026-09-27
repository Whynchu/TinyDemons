@tool
extends Resource
class_name SlimeVariantCatalogData

## Editor-inspectable enemy definitions. Standalone resources can be registered
## here to declare explicit dependencies; ResourceLoader directory discovery
## also finds authored resources in exported PCKs.

@export var definitions: Array[Resource] = []

const DEFINITION_ROOT := "res://resources/definitions"
const CATALOG_FILE := "slime_variant_catalog.tres"


func authored_definitions() -> Array[EnemyDefinition]:
	var result: Array[EnemyDefinition] = []
	var registered_ids: Dictionary = {}
	for entry in definitions:
		var definition := entry as EnemyDefinition
		if definition != null and not registered_ids.has(definition.variant_id):
			result.append(definition)
			registered_ids[definition.variant_id] = true

	var external_paths: Array[String] = []
	for entry in ResourceLoader.list_directory(DEFINITION_ROOT):
		if entry.get_extension().to_lower() == "tres" and entry != CATALOG_FILE:
			external_paths.append(DEFINITION_ROOT.path_join(entry))

	external_paths.sort()
	for path in external_paths:
		var definition := load(path) as EnemyDefinition
		if definition != null and not registered_ids.has(definition.variant_id):
			result.append(definition)
			registered_ids[definition.variant_id] = true
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
