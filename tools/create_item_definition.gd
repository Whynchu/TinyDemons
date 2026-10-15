extends SceneTree

## Owner: item authoring tooling. Build the CLI starter definition, then use
## the same catalog transaction as the editor to publish it and its manifests.

const ITEM_CATALOG_SCRIPT := preload("res://scripts/content/item_catalog.gd")
const ITEM_DEFINITION_SCRIPT := preload("res://scripts/content/item_definition.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var item_id := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--item-id="):
			item_id = argument.trim_prefix("--item-id=")
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	if pattern.search(item_id) == null:
		push_error("ITEM_CREATE_FAILED: item ID must match ^[a-z][a-z0-9_]*$")
		quit(1)
		return

	var definition: ItemDefinition = ITEM_DEFINITION_SCRIPT.new()
	definition.id = StringName(item_id)
	definition.display_name = item_id.replace("_", " ").to_upper()
	definition.resource_name = definition.display_name
	definition.slot = &"weapon"
	definition.gear_tier = &"basic"
	definition.tier_stat = &"strength"
	definition.bonuses = {"strength": 1.0}
	definition.description = "An authored equipment definition."
	definition.price = 25
	definition.source_tags = ["shop", "chest", "clear_reward"]
	definition.shop_eligible = true
	definition.family = definition.id
	definition.role = &"strength"
	definition.role_tags = ["strength"]
	definition.fusion_group = definition.id
	var catalog: ItemCatalog = ITEM_CATALOG_SCRIPT.new()
	var path := "res://resources/definitions/items/%s.tres" % item_id
	var result: Error = catalog.create_authored_definition(definition, path)
	if result != OK:
		push_error("ITEM_CREATE_FAILED id=%s error=%d" % [item_id, result])
		quit(1)
		return
	print("ITEM_CREATE_OK id=%s path=%s" % [item_id, path])
	quit(0)
