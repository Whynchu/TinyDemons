extends SceneTree

const ITEM_CATALOG_SCRIPT = preload("res://scripts/content/item_catalog.gd")
const ITEM_INSTANCE_SCRIPT = preload("res://scripts/content/item_instance.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog = ITEM_CATALOG_SCRIPT.new()
	var catalog_data := load("res://resources/definitions/item_catalog.tres") as ItemCatalogData
	_expect(catalog_data != null and catalog_data.validate().is_empty(), "typed item catalog passes validation", failures)
	if catalog_data != null:
		var duplicate_set_list := catalog_data.duplicate(true) as ItemCatalogData
		duplicate_set_list.live_set_ids.append(&"swift_weapon")
		_expect(not duplicate_set_list.validate().is_empty(), "duplicate ordered set IDs are rejected", failures)
		var missing_set_link := catalog_data.duplicate(true) as ItemCatalogData
		missing_set_link.live_set_ids.erase(&"swift_weapon")
		_expect(not missing_set_link.validate().is_empty(), "catalog-owned set resources must appear in live_set_ids", failures)
	var invalid_slot_claim := _save_candidate(&"invalid_slot_claim", "slot_claim")
	invalid_slot_claim.locked_slots = [&"head", &"head"]
	_expect(not invalid_slot_claim.validate().is_empty(), "duplicate secondary equipment slots are rejected", failures)
	var primary_slot_claim := _save_candidate(&"primary_slot_claim", "primary_claim")
	primary_slot_claim.locked_slots = [&"weapon"]
	_expect(not primary_slot_claim.validate().is_empty(), "a secondary slot cannot repeat the primary slot", failures)
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
	_expect(authored_count > 0, "typed item definitions are discovered from the generated manifest", failures)
	_expect(catalog.definition_exists(&"cinder_blade"), "cinder_blade is the named authored weapon proof", failures)
	_expect(catalog.save_authored_definition(_save_candidate(&"plain_hood", "baseline")) == ERR_ALREADY_EXISTS, "a saved item cannot collide with a catalog-owned baseline ID", failures)
	_expect(catalog.save_authored_definition(_save_candidate(&"swift_weapon", "set")) == ERR_ALREADY_EXISTS, "a saved item cannot collide with a catalog-owned set ID", failures)
	_expect(catalog.save_authored_definition(_save_candidate(&"cinder_blade", "typed")) == ERR_ALREADY_EXISTS, "a saved item cannot collide with a typed standalone ID", failures)
	var legacy_data := ItemCatalogData.new()
	legacy_data.definitions[&"legacy_collision"] = {"name": "LEGACY ITEM"}
	_expect(legacy_data.save_authored_definition(_save_candidate(&"legacy_collision", "legacy")) == ERR_ALREADY_EXISTS, "a saved item cannot collide with a legacy dictionary ID", failures)
	var cinder := catalog.definition_data(&"cinder_blade")
	_expect(cinder.get("slot", &"") == &"weapon", "cinder_blade owns the weapon slot", failures)
	_expect(float(cinder.get("bonuses", {}).get("strength", 0.0)) == 2.0, "cinder_blade matches the elemental blade strength bonus", failures)
	_expect(catalog.definition_is_runtime_ready(&"cinder_blade"), "cinder_blade is runtime-ready", failures)
	var swift_weapon := catalog.definition_data(&"swift_weapon")
	_expect(swift_weapon.get("name", "") == "SWIFT BLADE" and swift_weapon.get("description", "") == "Movement first.", "typed set item preserves its authored name and description", failures)
	_expect(swift_weapon.get("set_id", &"") == &"swift" and swift_weapon.get("set_name", "") == "SWIFT" and swift_weapon.get("role", &"") == &"swift", "typed set item preserves its set identity and derived role", failures)
	_expect(swift_weapon.get("source_tags", []) == ["shop", "chest", "clear_reward", "boss"] and bool(swift_weapon.get("shop_eligible", false)), "typed set item preserves its acquisition sources", failures)
	_finished = true
	call_deferred("_finish", failures)


func _save_candidate(definition_id: StringName, suffix: String) -> ItemDefinition:
	var candidate := ItemDefinition.new()
	candidate.id = definition_id
	candidate.display_name = "Collision Candidate"
	candidate.slot = &"weapon"
	candidate.source_tags = ["shop"]
	candidate.take_over_path("res://resources/definitions/items/.collision_%s.tres" % suffix)
	return candidate


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
