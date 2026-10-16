extends SceneTree

## Owner: enemy authoring tooling. Build a typed Slime variant and publish it
## through EnemyCatalog so the catalog and generated manifests stay in sync.

const ENEMY_CATALOG_SCRIPT := preload("res://scripts/content/enemy_catalog.gd")
const ENEMY_DEFINITION_SCRIPT := preload("res://scripts/content/enemy_definition.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy_id := _enemy_id_from_args()
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	if pattern.search(enemy_id) == null:
		push_error("ENEMY_CREATE_FAILED: enemy ID must match ^[a-z][a-z0-9_]*$")
		quit(1)
		return

	var definition: EnemyDefinition = ENEMY_DEFINITION_SCRIPT.new()
	definition.id = StringName(enemy_id)
	var display_parts := PackedStringArray()
	for part: String in enemy_id.split("_"):
		if not part.is_empty():
			display_parts.append(part.capitalize())
	definition.display_name = " ".join(display_parts)
	definition.resource_name = definition.display_name
	definition.type_id = &"slime"
	definition.element = 0
	definition.damage_contract = &"physical"
	definition.base_stats = {"AGI": 2, "DEF": 2, "INT": 0, "MND": 1, "STR": 2, "VIT": 2}
	definition.growth_weights = {"AGI": 0.2, "DEF": 0.24, "INT": 0.0, "MND": 0.08, "STR": 0.24, "VIT": 0.24}
	definition.visual_source = "green"
	definition.encounter_role = &"late"
	definition.encounter_weight = 0.5
	definition.encounter_min_run_number = 3
	var resource_path := "res://resources/definitions/%s.tres" % enemy_id
	var create_error: Error = ENEMY_CATALOG_SCRIPT.create_authored_definition(definition, resource_path)
	if create_error != OK:
		push_error("ENEMY_CREATE_FAILED id=%s error=%d" % [enemy_id, create_error])
		quit(1)
		return

	var discovered := ENEMY_CATALOG_SCRIPT.definition_resource(StringName(enemy_id))
	if discovered == null or discovered.variant_id != StringName(enemy_id):
		var rollback_error: Error = ENEMY_CATALOG_SCRIPT.remove_authored_definition(definition, resource_path)
		push_error("ENEMY_CREATE_FAILED id=%s error=catalog did not discover the saved definition rollback=%d" % [enemy_id, rollback_error])
		quit(1)
		return
	print("ENEMY_CREATE_OK id=%s path=%s" % [enemy_id, resource_path])
	quit(0)


func _enemy_id_from_args() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--enemy-id="):
			return argument.trim_prefix("--enemy-id=")
	return ""
