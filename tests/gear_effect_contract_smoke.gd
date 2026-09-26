extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog: ItemCatalog = ItemCatalog.new()
	var future_resonance := {
		"imbue_resonance": {
			"element": "fire",
			"magic_multiplier": 0.06,
			"mode": "matching_imbue",
			"status": "future",
		}
	}
	_register_definition_fixture(catalog, &"test_future_blade", &"weapon", &"strength",
		{"strength": 2.0}, future_resonance)
	_register_definition_fixture(catalog, &"test_blood_body", &"body", &"vitality",
		{"vitality": 2.0}, {})
	catalog.transmutations[&"bloodwoven_core"] = {
		"definitions": [&"test_blood_body"],
		"min_rarity": "epic",
		"name": "TEST BLOODWOVEN CORE",
		"slot": &"body",
		"effects": {"core_health_rate": 0.12, "vit_health_multiplier": 0.20},
	}

	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)
	var future_blade := ItemInstance.new()
	future_blade.instance_id = "future-blade-fixture"
	future_blade.definition_id = &"test_future_blade"
	future_blade.rarity = &"rare"
	profile.grant_item(future_blade)
	profile.equip_item(future_blade.instance_id, catalog)

	var blood_body := ItemInstance.new()
	blood_body.instance_id = "blood-body-fixture"
	blood_body.definition_id = &"test_blood_body"
	blood_body.rarity = &"epic"
	blood_body.transmutation_id = &"bloodwoven_core"
	profile.grant_item(blood_body)
	profile.equip_item(blood_body.instance_id, catalog)

	var equipment := EquipmentComponent.new()
	equipment.configure_from_profile(profile, catalog)
	var stats := StatsComponent.new()
	stats.configure_manual_growth(3, 2, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0)
	var snapshot := CombatStatSnapshot.from_components(stats, equipment)

	_expect(catalog.definition_data(&"test_future_blade").get("elemental_behavior", "") == "imbue_resonance:fire", "fixture definition exposes explicit resonance metadata", failures)
	_expect(not catalog.definition_is_runtime_ready(&"test_future_blade"), "future effect definitions are not runtime-ready", failures)
	_expect(not (&"test_future_blade" in catalog.definitions_for_slot(&"weapon", &"chest", 12, 12)), "future effect definitions stay out of live drops", failures)
	var future_lines := catalog.effect_display_lines(future_blade)
	_expect(not future_lines.is_empty() and future_lines[0].begins_with("PLANNED:"), "future effect status is visible in item inspection", failures)
	_expect(equipment.effect_entries(&"imbue_resonance").size() == 1 and equipment.active_effect_entries(&"imbue_resonance").is_empty(), "future resonance is declared but not activated", failures)
	_expect(equipment.active_effect_entries(&"core_health_rate").size() == 1 and equipment.active_effect_entries(&"vit_health_multiplier").size() == 1, "active fixture transmutation effects reach the equipment read model", failures)
	_expect(snapshot.active_effects.has("core_health_rate") and snapshot.active_effects.has("vit_health_multiplier"), "active effects reach the shared combat snapshot", failures)
	_expect(snapshot.declared_effects.has("imbue_resonance") and not snapshot.active_effects.has("imbue_resonance"), "snapshot preserves declaration without applying future behavior", failures)
	_expect(is_equal_approx(snapshot.core_health_rate_bonus, 0.12) and is_equal_approx(snapshot.vit_health_multiplier_bonus, 0.20), "fixture transmutation health contract remains numeric and shared", failures)

	stats.free()
	equipment.free()
	_finished = true
	call_deferred("_finish", failures)


func _register_definition_fixture(catalog: ItemCatalog, definition_id: StringName,
		slot: StringName, tier_stat: StringName, bonuses: Dictionary,
		effects: Dictionary) -> void:
	catalog.definitions[definition_id] = {
		"id": String(definition_id),
		"name": "TEST %s" % String(definition_id).to_upper(),
		"description": "Test-only effect fixture.",
		"slot": slot,
		"gear_tier": "basic",
		"tier_stat": tier_stat,
		"bonuses": bonuses.duplicate(true),
		"effects": effects.duplicate(true),
		"source_tags": ["test_fixture"],
		"minimum_run_rank": 1,
		"minimum_player_level": 1,
		"rarity_floor": "common",
		"rarity_ceiling": "mythic",
		"shop_eligible": false,
	}


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: gear effect contract smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GEAR_EFFECT_CONTRACT_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
