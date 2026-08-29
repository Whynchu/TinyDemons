extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)

	var ember := ItemInstance.new()
	ember.instance_id = "future-emberbrand"
	ember.definition_id = &"emberbrand"
	ember.rarity = &"rare"
	profile.grant_item(ember)
	profile.equip_item(ember.instance_id, catalog)

	var bloodwoven := ItemInstance.new()
	bloodwoven.instance_id = "active-bloodwoven"
	bloodwoven.definition_id = &"bloodwoven_tunic"
	bloodwoven.rarity = &"epic"
	bloodwoven.transmutation_id = &"bloodwoven_core"
	profile.grant_item(bloodwoven)
	profile.equip_item(bloodwoven.instance_id, catalog)

	var equipment := EquipmentComponent.new()
	equipment.configure_from_profile(profile, catalog)
	var stats := StatsComponent.new()
	stats.configure_manual_growth(3, 2, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0)
	var snapshot := CombatStatSnapshot.from_components(stats, equipment)

	_expect(catalog.definition_data(&"emberbrand").get("elemental_behavior", "") == "imbue_resonance:fire", "elemental definitions expose explicit behavior metadata", failures)
	_expect(not catalog.definition_is_runtime_ready(&"emberbrand"), "future effect definitions are not runtime-ready", failures)
	_expect(not (&"emberbrand" in catalog.definitions_for_slot(&"weapon", &"chest", 12, 12)), "future effect definitions stay out of live drops", failures)
	var ember_lines := catalog.effect_display_lines(ember)
	_expect(not ember_lines.is_empty() and ember_lines[0].begins_with("PLANNED:"), "future effect status is visible in item inspection", failures)
	_expect(equipment.effect_entries(&"imbue_resonance").size() == 1 and equipment.active_effect_entries(&"imbue_resonance").is_empty(), "future resonance is declared but not activated", failures)
	_expect(equipment.active_effect_entries(&"core_health_rate").size() == 1 and equipment.active_effect_entries(&"vit_health_multiplier").size() == 1, "active transmutation effects reach the equipment read model", failures)
	_expect(snapshot.active_effects.has("core_health_rate") and snapshot.active_effects.has("vit_health_multiplier"), "active effects reach the shared combat snapshot", failures)
	_expect(snapshot.declared_effects.has("imbue_resonance") and not snapshot.active_effects.has("imbue_resonance"), "snapshot preserves declaration without applying future behavior", failures)
	_expect(is_equal_approx(snapshot.core_health_rate_bonus, 0.12) and is_equal_approx(snapshot.vit_health_multiplier_bonus, 0.20), "existing transmutation health contract remains numeric and shared", failures)

	stats.free()
	equipment.free()
	_finished = true
	call_deferred("_finish", failures)


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
