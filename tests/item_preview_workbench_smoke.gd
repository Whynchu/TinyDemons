extends SceneTree

const ITEM_CATALOG_SCRIPT: Script = preload("res://scripts/content/item_catalog.gd")
const PREVIEW_SCENE: PackedScene = preload("res://scenes/authoring/previews/item_preview_workbench.tscn")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	var definition_ids: Array[StringName] = catalog.playable_definition_ids()
	_expect(not definition_ids.is_empty(), "ItemCatalog exposes current playable definition IDs", failures)
	_expect(&"cinder_blade" in definition_ids, "cinder_blade remains the standalone ItemDefinition proof", failures)
	_expect(&"demon_cloak" in definition_ids, "the special-acquisition Demon Cloak remains previewable", failures)
	_expect(&"ash_mantle" not in definition_ids, "legacy-only Ash Mantle is excluded from the playable picker", failures)

	for definition_id: StringName in definition_ids:
		var preview := PREVIEW_SCENE.instantiate() as Node2D
		_expect(preview != null, "%s preview scene instantiates" % definition_id, failures)
		if preview == null:
			continue
		preview.set("item_id", definition_id)
		root.add_child(preview)
		await process_frame
		var summary := preview.call("get_preview_summary") as Dictionary
		_expect(bool(summary.get("ready", false)), "%s preview is ready" % definition_id, failures)
		_expect(bool(summary.get("actions_ready", false)), "%s preview actions are bound" % definition_id, failures)
		_expect(StringName(str(summary.get("id", ""))) == definition_id, "%s preview preserves its stable ID" % definition_id, failures)
		_expect(not str(summary.get("slot", "")).is_empty(), "%s preview resolves a canonical slot" % definition_id, failures)
		var source_definition := catalog.definition_resource(definition_id)
		var expected_editable := source_definition != null and not source_definition.catalog_owned
		_expect(bool(summary.get("editable", false)) == expected_editable, "%s editability follows explicit catalog ownership" % definition_id, failures)

		var expected_instance: ItemInstance = catalog.create_preview_instance(definition_id, 1, &"common", 0)
		_expect(expected_instance != null, "%s creates a deterministic preview instance" % definition_id, failures)
		if expected_instance != null:
			_expect(summary.get("bonuses", {}) == catalog.bonuses(expected_instance), "%s preview uses ItemCatalog's bonus calculation" % definition_id, failures)
			_expect(summary.get("effect_lines", []) == catalog.effect_display_lines(expected_instance, true), "%s preview uses ItemCatalog's effect presentation" % definition_id, failures)
		preview.queue_free()
		await process_frame

	var catalog_owned_definition := catalog.definition_resource(&"plain_hood")
	_expect(catalog_owned_definition != null and catalog_owned_definition.catalog_owned, "Plain Hood is an explicitly catalog-owned typed resource", failures)
	var catalog_owned_set := catalog.definition_resource(&"swift_weapon")
	_expect(catalog_owned_set != null and catalog_owned_set.catalog_owned and catalog_owned_set.set_id == &"swift", "Swift Blade is an explicitly catalog-owned typed set resource", failures)
	_expect(catalog.save_authored_definition(catalog_owned_set) == ERR_INVALID_PARAMETER, "catalog-owned set item cannot be saved through the catalog API", failures)
	if catalog_owned_definition != null:
		var read_only_preview := PREVIEW_SCENE.instantiate() as Node2D
		read_only_preview.set("item_id", &"plain_hood")
		root.add_child(read_only_preview)
		await process_frame
		var original_name := str(read_only_preview.get("display_name"))
		read_only_preview.set("display_name", "Edited Baseline")
		var read_only_summary := read_only_preview.call("get_preview_summary") as Dictionary
		_expect(str(read_only_preview.get("display_name")) == original_name, "catalog-owned item fields ignore workbench edits", failures)
		_expect(not bool(read_only_summary.get("editable", true)) and not bool(read_only_summary.get("dirty", true)), "catalog-owned item remains preview-only and clean", failures)
		_expect(str(read_only_preview.get("selected_source")).contains("read-only"), "catalog-owned source is labeled read-only", failures)
		_expect(catalog.save_authored_definition(catalog_owned_definition) == ERR_INVALID_PARAMETER, "catalog-owned item cannot be saved through the catalog API", failures)
		read_only_preview.call("save_selected_definition")
		read_only_preview.queue_free()
		await process_frame

	var first_instance: ItemInstance = catalog.create_preview_instance(&"cinder_blade", 4917, &"rare", 3)
	var second_instance: ItemInstance = catalog.create_preview_instance(&"cinder_blade", 4917, &"rare", 3)
	_expect(first_instance != null and second_instance != null, "the selected item can build seeded preview instances", failures)
	if first_instance != null and second_instance != null:
		_expect(first_instance.to_dictionary() == second_instance.to_dictionary(), "preview instance rolls are repeatable for a fixed seed", failures)
	_expect(catalog.create_preview_instance(&"missing_item", 1) == null, "unknown IDs do not build preview instances", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	await create_timer(15.0).timeout
	if _finished:
		return
	push_error("TEST_ABORTED: item preview workbench smoke did not finish")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ITEM_PREVIEW_WORKBENCH_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
