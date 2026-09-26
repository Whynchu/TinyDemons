extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := PlayerTuning.new()
	_expect(is_equal_approx(tuning.speed_multiplier(0), 1.0), "zero SPD is neutral move speed", failures)
	_expect(is_equal_approx(tuning.roll_multiplier(0), 1.0), "zero SPD is neutral roll", failures)
	_expect(is_equal_approx(tuning.attack_multiplier(0), 1.0), "zero SPD is neutral attack", failures)
	_expect(tuning.speed_multiplier(10) > 1.0, "positive SPD raises move speed", failures)
	_expect(tuning.roll_multiplier(10) > 1.0, "positive SPD raises roll", failures)
	_expect(tuning.attack_multiplier(10) > 1.0, "positive SPD raises attack", failures)
	_expect(tuning.attack_multiplier(-10) < 1.0, "negative SPD lowers attack", failures)
	_expect(is_equal_approx(tuning.attack_multiplier(200), 1.0 + tuning.attack_scale * 100.0), "attack multiplier clamps at max", failures)
	_expect(is_equal_approx(tuning.speed_multiplier(-200), 0.5), "move multiplier clamps at min", failures)
	_expect(tuning.agi_multiplier(0.0) < tuning.agi_multiplier(1.0) and tuning.agi_multiplier(1.0) < tuning.agi_multiplier(2.0), "AGI movement is a strict reward curve from zero", failures)
	_expect(tuning.agi_multiplier(2.0) < 1.0 and is_equal_approx(tuning.agi_multiplier(tuning.movement_agi_reference), 1.0), "AGI movement specs off the reference and starts below neutral", failures)

	var profile := PlayerProfile.new()
	profile.ensure_starter_items()
	var catalog := ItemCatalog.new()
	var gear := EquipmentComponent.new()
	gear.configure_from_profile(profile, catalog)
	_expect(is_equal_approx(gear.speed_bonus, 0.0), "Plain starter gear has no flat speed trade-off", failures)

	var swift_blade := ItemInstance.new(); swift_blade.instance_id = "swift-blade-test"; swift_blade.definition_id = &"swift_weapon"; swift_blade.rarity = &"common"
	var swift_cloak := ItemInstance.new(); swift_cloak.instance_id = "swift-cloak-test"; swift_cloak.definition_id = &"swift_body"; swift_cloak.rarity = &"common"
	var swift_boots := ItemInstance.new(); swift_boots.instance_id = "swift-boots-test"; swift_boots.definition_id = &"swift_accessory"; swift_boots.rarity = &"common"
	var speed_profile := PlayerProfile.new(); speed_profile.ensure_starter_items()
	speed_profile.grant_item(swift_blade); speed_profile.equip_item(swift_blade.instance_id)
	speed_profile.grant_item(swift_cloak); speed_profile.equip_item(swift_cloak.instance_id)
	speed_profile.grant_item(swift_boots); speed_profile.equip_item(swift_boots.instance_id)
	var speed_gear := EquipmentComponent.new(); speed_gear.configure_from_profile(speed_profile, catalog)
	_expect(is_equal_approx(speed_gear.speed_bonus, 3.0 + 3.0 + 3.0), "current Swift set pieces stack flat bonuses", failures)

	var base_stats := StatsComponent.new()
	base_stats.configure_manual_growth(4, 3, 3, 2, 1, 0, 0, 0)
	var base_snapshot := CombatStatSnapshot.from_components(base_stats, gear)
	_expect(base_snapshot.speed == 2, "Plain starter loadout leaves the authored speed baseline intact", failures)
	var tall_stats := StatsComponent.new()
	tall_stats.configure_manual_growth(4, 3, 3, 40, 1, 0, 0, 0)
	var tall_snapshot := CombatStatSnapshot.from_components(tall_stats, gear)
	var tall_speed_snapshot := CombatStatSnapshot.from_components(tall_stats, speed_gear)
	_expect(tall_speed_snapshot.speed > tall_snapshot.speed, "speed gear raises effective SPD at scale", failures)
	_expect(tall_speed_snapshot.speed - tall_snapshot.speed == 9, "speed gear adds its nine-point package over the Plain starter loadout", failures)

	var heavy_sword := ItemInstance.new(); heavy_sword.instance_id = "heavy-test"; heavy_sword.definition_id = &"soldier_weapon"; heavy_sword.rarity = &"common"
	var soldier_mail := ItemInstance.new(); soldier_mail.instance_id = "soldier-mail-test"; soldier_mail.definition_id = &"soldier_body"; soldier_mail.rarity = &"common"
	var soldier_shield := ItemInstance.new(); soldier_shield.instance_id = "soldier-shield-test"; soldier_shield.definition_id = &"soldier_shield"; soldier_shield.rarity = &"common"
	var heavy_profile := PlayerProfile.new(); heavy_profile.ensure_starter_items()
	heavy_profile.grant_item(heavy_sword); heavy_profile.equip_item(heavy_sword.instance_id)
	heavy_profile.grant_item(soldier_mail); heavy_profile.equip_item(soldier_mail.instance_id)
	heavy_profile.grant_item(soldier_shield); heavy_profile.equip_item(soldier_shield.instance_id)
	var heavy_gear := EquipmentComponent.new(); heavy_gear.configure_from_profile(heavy_profile, catalog)
	_expect(heavy_gear.speed_bonus < 0.0, "high STR gear and heavy armor penalize speed", failures)
	var heavy_snapshot := CombatStatSnapshot.from_components(base_stats, heavy_gear)
	_expect(heavy_snapshot.speed < base_snapshot.speed, "STR gear penalty lowers effective SPD below base", failures)

	var live_set_found := false
	for seed in 512:
		var generated_weapon := catalog.generate_item(&"weapon", seed, 20, &"epic")
		live_set_found = live_set_found or str(catalog.definition_data(generated_weapon.definition_id).get("gear_tier", "")) == "set"
	_expect(live_set_found, "seed sample reaches a live set piece", failures)
	for retired_id: StringName in ItemCatalog.RETIRED_DEFINITION_IDS:
		_expect(not catalog.definition_exists(retired_id), "%s is not available to the speed gear catalog" % retired_id, failures)

	base_stats.free()
	tall_stats.free()
	gear.free()
	speed_gear.free()
	heavy_gear.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: speed scale smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SPEED_SCALE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
