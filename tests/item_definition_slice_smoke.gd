extends SceneTree

const ITEM_CATALOG_SCRIPT = preload("res://scripts/item_catalog.gd")
const ITEM_INSTANCE_SCRIPT = preload("res://scripts/item_instance.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog = ITEM_CATALOG_SCRIPT.new()
	var authored_count := 0
	for resource: Resource in catalog.authored_definition_resources:
		authored_count += 1
		var definition_id := StringName(str(resource.get("id")))
		var problems := resource.call("validate") as Array
		_expect(problems.is_empty(), "%s validates" % definition_id, failures)
		_expect(catalog.definition_exists(definition_id), "%s resolves through ItemCatalog" % definition_id, failures)
		_expect(definition_id in catalog.playable_definition_ids(), "%s has a current gameplay acquisition path" % definition_id, failures)
		var instance = ITEM_INSTANCE_SCRIPT.new()
		instance.definition_id = definition_id
		instance.rarity = &"common"
		var restored = ITEM_INSTANCE_SCRIPT.from_dictionary(instance.to_dictionary())
		_expect(restored.definition_id == definition_id, "%s survives item save round-trip" % definition_id, failures)
	_expect(authored_count > 0, "at least one standalone item definition is discovered", failures)
	_expect(catalog.definition_exists(&"cinder_blade"), "cinder_blade is the named authored weapon proof", failures)
	var cinder := catalog.definition_data(&"cinder_blade")
	_expect(cinder.get("slot", &"") == &"weapon", "cinder_blade owns the weapon slot", failures)
	_expect(float(cinder.get("bonuses", {}).get("strength", 0.0)) == 3.0, "cinder_blade carries its authored strength bonus", failures)
	_expect(catalog.definition_is_runtime_ready(&"cinder_blade"), "cinder_blade is runtime-ready", failures)
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: item definition slice smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ITEM_DEFINITION_SLICE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
