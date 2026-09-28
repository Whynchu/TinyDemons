@tool
extends Resource
class_name SlimeVariantCatalogData

## Editor-inspectable enemy definitions. The generated content manifest keeps
## standalone definition resources reachable in exported PCKs and supplies the
## same authored set to runtime and editor lookup.

@export var definitions: Array[Resource] = []

const CONTENT_MANIFEST_SERVICE_SCRIPT := preload("res://scripts/content_definition_manifest_service.gd")
const ENEMY_MANIFEST_EXPORT_DEPENDENCY := preload("res://resources/generated/enemy_definition_manifest.tres")
const CATALOG_FILE := "slime_variant_catalog.tres"


func authored_definitions() -> Array[EnemyDefinition]:
	var result: Array[EnemyDefinition] = []
	var registered_ids: Dictionary = {}
	for candidate in _definition_candidates():
		var definition := candidate["definition"] as EnemyDefinition
		if not registered_ids.has(definition.variant_id):
			result.append(definition)
			registered_ids[definition.variant_id] = true
	return result


func validate() -> Array[String]:
	var problems: Array[String] = []
	var candidates := _definition_candidates()
	if candidates.is_empty():
		problems.append("slime variant definitions are empty")
	for entry in definitions:
		if entry as EnemyDefinition == null:
			problems.append("slime variant catalog contains a non-EnemyDefinition entry")
	var seen_sources_by_id: Dictionary = {}
	for candidate in candidates:
		var definition := candidate["definition"] as EnemyDefinition
		var source_path := str(candidate["source"])
		if definition.type_id not in [&"slime", &"skeleton"]:
			problems.append("%s: unsupported enemy type_id '%s'" % [source_path, definition.type_id])
		if seen_sources_by_id.has(definition.variant_id):
			problems.append("%s: duplicate enemy variant id '%s' (first declared at %s)" % [
				source_path,
				definition.variant_id,
				seen_sources_by_id[definition.variant_id],
			])
		else:
			seen_sources_by_id[definition.variant_id] = source_path
		for problem in definition.validate():
			problems.append("%s (%s): %s" % [definition.variant_id, source_path, problem])
	return problems


func _definition_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen_resource_ids: Dictionary = {}
	var registered_external_paths: Dictionary = {}
	for index in definitions.size():
		var definition := definitions[index] as EnemyDefinition
		if definition == null:
			continue
		var instance_id := definition.get_instance_id()
		if seen_resource_ids.has(instance_id):
			continue
		seen_resource_ids[instance_id] = true
		var source_path := definition.resource_path
		if source_path.is_empty():
			source_path = "%s::definitions[%d]" % [CATALOG_FILE, index]
		elif not source_path.contains("::"):
			registered_external_paths[source_path] = true
		candidates.append({"definition": definition, "source": source_path})

	for path in _external_definition_paths():
		if registered_external_paths.has(path):
			continue
		var definition := load(path) as EnemyDefinition
		if definition == null:
			continue
		var instance_id := definition.get_instance_id()
		if seen_resource_ids.has(instance_id):
			continue
		seen_resource_ids[instance_id] = true
		candidates.append({"definition": definition, "source": path})
	return candidates


func _external_definition_paths() -> Array[String]:
	var paths: Array[String] = []
	for resource: Resource in CONTENT_MANIFEST_SERVICE_SCRIPT.load_kind_entries(&"enemy", ENEMY_MANIFEST_EXPORT_DEPENDENCY):
		if resource as EnemyDefinition == null:
			continue
		var path := resource.resource_path
		if not path.is_empty() and path.get_file() != CATALOG_FILE:
			paths.append(path)
	paths.sort()
	return paths
