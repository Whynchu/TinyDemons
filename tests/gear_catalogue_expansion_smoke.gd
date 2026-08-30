extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var expected_slots := [&"weapon", &"head", &"body", &"arm", &"shield", &"accessory"]
	_expect(ItemCatalog.SLOTS == expected_slots, "catalogue exposes the canonical six-slot order", failures)
	_expect(ItemCatalog.canonical_slot(&"armor") == &"body", "legacy armor canonicalizes to body", failures)
	_expect(ItemCatalog.canonical_slot(&"not-a-slot") == &"", "invalid slot names fail closed", failures)

	var counts := {}
	for definition_id: StringName in ItemCatalog.DEFINITIONS:
		var definition := catalog.definition_data(definition_id)
		var slot := catalog.definition_slot(definition_id)
		counts[slot] = int(counts.get(slot, 0)) + 1
		for required_key in ["family", "role", "primary_stat", "base_bonuses", "tradeoffs", "derived_effects", "source_tags", "rarity_floor", "rarity_ceiling", "minimum_run_rank", "minimum_player_level", "shop_eligible", "fusion_group", "visual_id", "player_description"]:
			_expect(definition.has(required_key), "%s has authored field %s" % [String(definition_id), required_key], failures)
	_expect(counts.get(&"weapon", 0) == 10 and counts.get(&"head", 0) == 6 and counts.get(&"body", 0) == 9 and counts.get(&"arm", 0) == 6 and counts.get(&"shield", 0) == 6 and counts.get(&"accessory", 0) == 8, "catalogue contains the approved 45 bases by slot", failures)

	var hood := catalog.starter_item(&"head")
	var wraps := catalog.starter_item(&"arm")
	_expect(hood.definition_id == &"plain_hood" and wraps.definition_id == &"cloth_wraps", "new slots use the approved zero-power starters", failures)
	_expect(catalog.bonuses(hood).is_empty() and catalog.bonuses(wraps).is_empty(), "Head and Arm starters add no combat stats", failures)
	_expect(bool(catalog.definition_data(hood.definition_id).get("starter_only", false)) and bool(catalog.definition_data(wraps.definition_id).get("starter_only", false)), "zero-power starters are protected from random drops", failures)

	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)
	var equipment := EquipmentComponent.new()
	equipment.configure_from_profile(profile, catalog)
	_expect(profile.get_equipped_instance_id(&"head") == "starter-head" and profile.get_equipped_instance_id(&"arm") == "starter-arm", "new profiles equip both visible starter slots", failures)
	_expect(equipment.head_name == "PLAIN HOOD" and equipment.arm_name == "CLOTH WRAPS" and equipment.armor_name == "BASIC TUNIC", "runtime presentation names use Head/Arm/Body with armor compatibility", failures)

	var generated_head := catalog.generate_item(&"head", 1001, 1, &"common", false, &"shop", 1)
	var generated_arm := catalog.generate_item(&"arm", 1002, 1, &"common", false, &"shop", 1)
	_expect(not generated_head.definition_id.is_empty() and catalog.definition_slot(generated_head.definition_id) == &"head", "shop generation can produce a legal Head", failures)
	_expect(not generated_arm.definition_id.is_empty() and catalog.definition_slot(generated_arm.definition_id) == &"arm", "shop generation can produce a legal Arm", failures)
	_expect(not bool(catalog.definition_data(generated_head.definition_id).get("starter_only", false)) and not bool(catalog.definition_data(generated_arm.definition_id).get("starter_only", false)), "shop generation excludes starter-only definitions", failures)

	var ember := ItemInstance.new()
	ember.definition_id = &"emberbrand"
	ember.rarity = &"rare"
	var ember_effects := catalog.definition_effects(ember.definition_id)
	_expect(ember_effects.has("imbue_resonance") and str(ember_effects["imbue_resonance"].get("element", "")) == "fire", "elemental gear declares explicit resonance metadata", failures)
	_expect(not ember_effects.has("souls_multiplier") and not ember_effects.has("gold_multiplier") and not ember_effects.has("drop_rate"), "initial catalogue has no direct economy multipliers", failures)

	equipment.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: gear catalogue expansion smoke failed before completion")
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
