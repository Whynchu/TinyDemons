extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog: ItemCatalog = ItemCatalog.new()
	var expected_slots: Array[StringName] = [&"weapon", &"head", &"body", &"arm", &"shield", &"accessory"]
	_expect(ItemCatalog.SLOTS == expected_slots, "catalogue exposes the canonical six-slot order", failures)
	_expect(ItemCatalog.canonical_slot(&"armor") == &"body", "legacy armor canonicalizes to body", failures)
	_expect(ItemCatalog.canonical_slot(&"not-a-slot") == &"", "invalid slot names fail closed", failures)
	_expect(catalog.transmutations.is_empty(), "retired item transmutations are absent from the live catalog", failures)
	_expect(not catalog.definition_exists(&"ash_mantle") and not catalog.definition_exists(&"bangle") and not catalog.definition_exists(&"soldier_sword"), "retired expansion items no longer resolve", failures)

	for raw_id: Variant in catalog.definitions.keys():
		var definition_id := StringName(str(raw_id))
		_expect(catalog.definition_resource(definition_id) != null, "%s is an authored ItemDefinition resource" % definition_id, failures)
	_expect(catalog.definition_exists(&"cinder_blade") and catalog.definition_slot(&"cinder_blade") == &"weapon", "cinder_blade remains the standalone weapon proof", failures)
	_expect(catalog.definition_resource(&"demon_cloak") != null and &"demon_cloak" in catalog.playable_definition_ids(), "Demon Cloak remains a typed special-acquisition item", failures)
	var cloak := catalog.definition_data(&"demon_cloak")
	_expect(cloak.get("slot", &"") == &"body" and "defense" in cloak.get("tier_stats", []), "Demon Cloak retains its dual-scaled Body/DEF package", failures)

	var baseline_ids_by_slot: Dictionary = {
		&"weapon": [&"plain_blade", &"basic_sword"],
		&"head": [&"plain_hood", &"basic_hood"],
		&"body": [&"plain_tunic", &"basic_tunic"],
		&"arm": [&"plain_wraps", &"basic_wraps"],
		&"shield": [&"plain_shield", &"basic_shield"],
		&"accessory": [&"plain_ring", &"basic_charm"],
	}
	for slot: StringName in expected_slots:
		var source_ids := catalog.definitions_for_slot(slot, &"chest", 1, 1)
		for baseline_id: StringName in baseline_ids_by_slot[slot]:
			_expect(baseline_id in source_ids, "%s remains available to current chest sourcing" % baseline_id, failures)
		for set_id: StringName in ItemCatalog.SET_IDS:
			var set_item_id := StringName("%s_%s" % [String(set_id), String(slot)])
			_expect(set_item_id in source_ids, "%s remains available to current chest sourcing" % set_item_id, failures)
		for definition_id: StringName in source_ids:
			_expect(catalog.definition_is_runtime_ready(definition_id), "%s is runtime-ready for its current source" % definition_id, failures)

	var hood := catalog.starter_item(&"head")
	var wraps := catalog.starter_item(&"arm")
	_expect(hood.definition_id == &"plain_hood" and wraps.definition_id == &"plain_wraps", "new slots use the Plain starter pieces", failures)
	_expect(catalog.bonuses(hood).is_empty() and catalog.bonuses(wraps).is_empty(), "Head and Arm starters remain zero-power Plain packages", failures)
	_expect(not bool(catalog.definition_data(hood.definition_id).get("starter_only", false)) and not bool(catalog.definition_data(wraps.definition_id).get("starter_only", false)), "Plain Head and Arm starters remain ordinary live drops", failures)

	var generated_head := catalog.generate_item(&"head", 1001, 1, &"common", false, &"shop", 1)
	var generated_arm := catalog.generate_item(&"arm", 1002, 1, &"common", false, &"shop", 1)
	_expect(not generated_head.definition_id.is_empty() and catalog.definition_slot(generated_head.definition_id) == &"head", "shop generation can produce a legal Head", failures)
	_expect(not generated_arm.definition_id.is_empty() and catalog.definition_slot(generated_arm.definition_id) == &"arm", "shop generation can produce a legal Arm", failures)
	_expect(str(catalog.definition_data(generated_head.definition_id).get("gear_tier", "")) in ["basic", "set"] and str(catalog.definition_data(generated_arm.definition_id).get("gear_tier", "")) in ["basic", "set"], "shop generation returns current Basic or Set definitions", failures)

	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)
	var equipment := EquipmentComponent.new()
	equipment.configure_from_profile(profile, catalog)
	_expect(profile.get_equipped_instance_id(&"head") == "starter-head" and profile.get_equipped_instance_id(&"arm") == "starter-arm", "new profiles equip both visible starter slots", failures)
	_expect(equipment.head_name == "PLAIN HOOD" and equipment.arm_name == "PLAIN WRAPS", "runtime presentation resolves current starter item names", failures)

	equipment.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: live gear catalog smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GEAR_CATALOGUE_EXPANSION_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
