@tool
extends Resource
class_name ItemCatalogData

## Editor-inspectable item definition data. ItemCatalog loads this resource so
## the authored gear definitions live in .tres data instead of code dictionaries,
## while the instance API stays unchanged.

@export var live_base_ids: Array[StringName] = []
@export var live_base_definitions: Dictionary = {}
@export var set_definitions: Dictionary = {}
@export var definitions: Dictionary = {}
@export var definition_metadata: Dictionary = {}
@export var transmutations: Dictionary = {}
## Explicit resource references keep special-acquisition definitions reachable
## in exported builds; directory discovery remains useful for editor authoring.
@export var authored_definitions: Array[Resource] = []

const AUTHORED_ITEM_ROOT := "res://resources/definitions/items"
var _authored_definition_resources_cache: Array[Resource] = []
var _authored_definition_resources_loaded := false


func authored_definition_resources() -> Array[Resource]:
	if _authored_definition_resources_loaded:
		return _authored_definition_resources_cache
	var resources: Array[Resource] = authored_definitions.duplicate()
	var referenced_paths: Dictionary = {}
	for resource: Resource in resources:
		if resource != null and not resource.resource_path.is_empty():
			referenced_paths[resource.resource_path] = true
	var paths := _discover_authored_paths(AUTHORED_ITEM_ROOT)
	for path: String in paths:
		if referenced_paths.has(path):
			continue
		var resource := load(path) as Resource
		if resource != null:
			resources.append(resource)
	_authored_definition_resources_cache = resources
	_authored_definition_resources_loaded = true
	return _authored_definition_resources_cache


func invalidate_authored_definition_cache() -> void:
	_authored_definition_resources_cache.clear()
	_authored_definition_resources_loaded = false


func authored_definition_resource(definition_id: StringName) -> ItemDefinition:
	for resource: Resource in authored_definition_resources():
		var definition := resource as ItemDefinition
		if definition != null and definition.id == definition_id:
			return definition
	return null


func save_authored_definition(definition: ItemDefinition) -> int:
	if definition == null:
		return ERR_INVALID_PARAMETER
	var source_path := definition.resource_path
	if not source_path.begins_with(AUTHORED_ITEM_ROOT + "/") or source_path.get_extension().to_lower() != "tres":
		return ERR_INVALID_PARAMETER
	if not definition.validate().is_empty():
		return ERR_INVALID_DATA
	for raw_id: Variant in live_base_definitions.keys():
		if StringName(str(raw_id)) == definition.id:
			return ERR_ALREADY_EXISTS
	for raw_id: Variant in definitions.keys():
		if StringName(str(raw_id)) == definition.id:
			return ERR_ALREADY_EXISTS
	var existing := authored_definition_resource(definition.id)
	if existing != null and existing != definition and existing.resource_path != source_path:
		return ERR_ALREADY_EXISTS
	var save_error := ResourceSaver.save(definition, source_path)
	if save_error == OK:
		invalidate_authored_definition_cache()
	return save_error


func authored_definition_data() -> Dictionary:
	var result: Dictionary = {}
	for resource: Resource in authored_definition_resources():
		if not resource.has_method("to_record") or not resource.has_method("validate"):
			continue
		var definition_id := StringName(str(resource.get("id")))
		if definition_id.is_empty():
			continue
		result[definition_id] = resource.call("to_record")
	return result


func authored_live_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for resource: Resource in authored_definition_resources():
		if not bool(resource.get("live")):
			continue
		var definition_id := StringName(str(resource.get("id")))
		if not definition_id.is_empty():
			result.append(definition_id)
	return result


func validate() -> Array[String]:
	var problems: Array[String] = []
	if live_base_ids.is_empty():
		problems.append("live_base_ids must not be empty")
	if live_base_definitions.is_empty():
		problems.append("live_base_definitions must not be empty")
	var seen: Dictionary = {}
	for definition_id: Variant in live_base_definitions:
		seen[StringName(str(definition_id))] = "item_catalog.tres"
	for definition_id: Variant in definitions:
		seen[StringName(str(definition_id))] = "item_catalog.tres"
	for resource: Resource in authored_definition_resources():
		if not resource.has_method("to_record") or not resource.has_method("validate"):
			problems.append("%s: resource must use the ItemDefinition contract" % resource.resource_path)
			continue
		var definition_id := StringName(str(resource.get("id")))
		if definition_id in seen:
			problems.append("duplicate item definition id '%s' (already owned by %s)" % [definition_id, seen[definition_id]])
		else:
			seen[definition_id] = resource.resource_path
		var resource_problems := resource.call("validate") as Array
		for problem: Variant in resource_problems:
			problems.append("%s: %s" % [resource.resource_path, str(problem)])
	return problems


func _discover_authored_paths(directory_path: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := directory_path.path_join(entry)
			if directory.current_is_dir():
				paths.append_array(_discover_authored_paths(entry_path))
			elif entry.get_extension().to_lower() == "tres":
				paths.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths
