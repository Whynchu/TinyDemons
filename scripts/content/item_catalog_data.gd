@tool
extends Resource
class_name ItemCatalogData

## Editor-inspectable item definition data. ItemCatalog loads this resource so
## the authored gear definitions live in .tres data instead of code dictionaries,
## while the instance API stays unchanged. The generated manifest supplies the
## standalone resources in both editor and exported runtime builds.

@export var live_base_ids: Array[StringName] = []
@export var live_base_definitions: Dictionary = {}
@export var set_definitions: Dictionary = {}
@export var definitions: Dictionary = {}
@export var definition_metadata: Dictionary = {}
@export var transmutations: Dictionary = {}
## Explicit references keep special-acquisition definitions reachable even when
## they are not part of the generated authored-definition set.
@export var authored_definitions: Array[Resource] = []

const AUTHORED_ITEM_ROOT := "res://resources/definitions/items"
const DEFAULT_DATA_PATH := "res://resources/definitions/item_catalog.tres"
const CONTENT_MANIFEST_SERVICE_SCRIPT := preload("res://scripts/content/content_definition_manifest_service.gd")
const ITEM_MANIFEST_EXPORT_DEPENDENCY := preload("res://resources/generated/item_definition_manifest.tres")
var _authored_definition_resources_cache: Array[Resource] = []
var _authored_definition_resources_loaded := false
var _authored_definition_data_cache: Dictionary = {}
var _authored_definition_data_loaded := false
var _authored_live_ids_cache: Array[StringName] = []
var _authored_live_ids_loaded := false


func authored_definition_resources() -> Array[Resource]:
	if _authored_definition_resources_loaded:
		return _authored_definition_resources_cache
	var resources: Array[Resource] = authored_definitions.duplicate()
	var seen_resource_ids: Dictionary = {}
	var seen_resource_paths: Dictionary = {}
	for resource: Resource in resources:
		if resource != null:
			seen_resource_ids[resource.get_instance_id()] = true
			if not resource.resource_path.is_empty():
				seen_resource_paths[resource.resource_path] = true
	for resource: Resource in CONTENT_MANIFEST_SERVICE_SCRIPT.load_kind_entries(&"item", ITEM_MANIFEST_EXPORT_DEPENDENCY):
		if resource == null:
			continue
		var is_legacy_item_root_resource := resource.resource_path.begins_with(AUTHORED_ITEM_ROOT + "/")
		if resource as ItemDefinition == null and not is_legacy_item_root_resource:
			continue
		var instance_id := resource.get_instance_id()
		var source_path := resource.resource_path
		if seen_resource_ids.has(instance_id) or (not source_path.is_empty() and seen_resource_paths.has(source_path)):
			continue
		seen_resource_ids[instance_id] = true
		if not source_path.is_empty():
			seen_resource_paths[source_path] = true
		resources.append(resource)
	_authored_definition_resources_cache = resources
	_authored_definition_resources_loaded = true
	return _authored_definition_resources_cache


func invalidate_authored_definition_cache() -> void:
	_authored_definition_resources_cache.clear()
	_authored_definition_resources_loaded = false
	_authored_definition_data_cache.clear()
	_authored_definition_data_loaded = false
	_authored_live_ids_cache.clear()
	_authored_live_ids_loaded = false


static func invalidate_default_cache() -> void:
	var default_data := load(DEFAULT_DATA_PATH) as ItemCatalogData
	if default_data != null:
		default_data.invalidate_authored_definition_cache()


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


## Derived projections of the authored resource set. Each one is cached beside
## authored_definition_resources() because every ItemCatalog construction needs
## them, and pickups and chest opens construct a catalog per call.
func authored_definition_data() -> Dictionary:
	if _authored_definition_data_loaded:
		return _authored_definition_data_cache
	var result: Dictionary = {}
	for resource: Resource in authored_definition_resources():
		if not resource.has_method("to_record") or not resource.has_method("validate"):
			continue
		var definition_id := StringName(str(resource.get("id")))
		if definition_id.is_empty():
			continue
		result[definition_id] = resource.call("to_record")
	_authored_definition_data_cache = result
	_authored_definition_data_loaded = true
	return _authored_definition_data_cache


func authored_live_ids() -> Array[StringName]:
	if _authored_live_ids_loaded:
		return _authored_live_ids_cache
	var result: Array[StringName] = []
	for resource: Resource in authored_definition_resources():
		if not bool(resource.get("live")):
			continue
		var definition_id := StringName(str(resource.get("id")))
		if not definition_id.is_empty():
			result.append(definition_id)
	_authored_live_ids_cache = result
	_authored_live_ids_loaded = true
	return _authored_live_ids_cache


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
