extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var legacy_body := ItemInstance.new()
	legacy_body.instance_id = "legacy-armor-instance"
	legacy_body.definition_id = &"basic_tunic"
	legacy_body.rarity = &"rare"
	legacy_body.enhancement_level = 4
	var legacy_data := {
		"schema_version": PlayerProfile.LEGACY_SIX_STAT_SCHEMA_VERSION,
		"has_started": true,
		"player_name": "OLD FILE",
		"base_agi": 4,
		"base_int": 3,
		"base_mnd": 2,
		"gold": 321,
		"souls": 77,
		"inventory": [legacy_body.to_dictionary()],
		"equipped_instance_ids": {"weapon": "", "armor": legacy_body.instance_id, "shield": "", "accessory": ""},
	}
	var profile := PlayerProfile.new()
	profile.load_dictionary(legacy_data)
	_expect(profile.schema_version == PlayerProfile.CURRENT_SCHEMA_VERSION, "legacy six-stat profile upgrades to the current schema", failures)
	_expect(profile.get_equipped_instance_id(&"body") == legacy_body.instance_id and profile.equipped_instance_ids.get("armor", "") == legacy_body.instance_id, "legacy Armor remains equipped as Body with an alias", failures)
	var restored_body := profile.find_item(profile.get_equipped_instance_id(&"body"))
	_expect(restored_body != null and restored_body.rarity == &"rare" and restored_body.enhancement_level == 4, "legacy Body item identity and enhancement survive migration", failures)
	_expect(profile.get_equipped_instance_id(&"head") == "starter-head" and profile.get_equipped_instance_id(&"arm") == "starter-arm", "legacy files receive the two visible zero-power slots", failures)
	_expect(profile.gold == 321 and profile.souls == 77, "legacy currency survives slot migration", failures)

	var saved := profile.to_dictionary()
	_expect(saved.get("schema_version") == PlayerProfile.CURRENT_SCHEMA_VERSION and saved.get("equipped_instance_ids", {}).get("body", "") == legacy_body.instance_id, "new saves emit canonical Body state", failures)
	var round_trip := PlayerProfile.new()
	round_trip.load_dictionary(saved)
	_expect(round_trip.get_equipped_instance_id(&"body") == legacy_body.instance_id and round_trip.get_equipped_instance_id(&"head") == "starter-head" and round_trip.get_equipped_instance_id(&"arm") == "starter-arm", "canonical save round trip preserves all six slots", failures)
	_expect(round_trip.unequip_slot(&"body") and round_trip.get_equipped_instance_id(&"body").is_empty() and str(round_trip.equipped_instance_ids.get("armor", "")).is_empty(), "Body unequip clears the legacy Armor alias", failures)

	var invalid := ItemInstance.new()
	invalid.instance_id = "invalid-definition"
	invalid.definition_id = &"removed_future_item"
	_expect(profile.grant_item(invalid), "unknown inventory definitions remain recoverable", failures)
	_expect(not profile.equip_item(invalid.instance_id), "unknown definitions cannot enter an equipment slot", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: gear slot migration smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GEAR_SLOT_MIGRATION_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
