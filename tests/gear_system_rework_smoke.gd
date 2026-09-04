extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)

	_expect(catalog.live_definition_ids().size() == 66, "live catalogue contains 12 plain/basic pieces and 54 set pieces", failures)
	_expect(profile.base_vit == 2 and profile.base_str == 2 and profile.base_def == 2 and profile.base_agi == 2 and profile.base_int == 2 and profile.base_mnd == 2, "new profiles use the even two-point baseline", failures)
	var forbidden_names := ["maul", "rod", "claw", "mask", "veil", "circlet", "mantle", "ear", "talisman"]
	for definition_id: StringName in catalog.live_definition_ids():
		var definition := catalog.definition_data(definition_id)
		var lower_name := str(definition.get("name", "")).to_lower()
		for forbidden: String in forbidden_names:
			_expect(not lower_name.contains(forbidden), "live gear name does not use deferred family '%s': %s" % [forbidden, definition_id], failures)
		_expect((definition.get("effects", {}) as Dictionary).is_empty(), "live gear has no hidden effect package: %s" % definition_id, failures)
		_expect(catalog.player_stat_rates(ItemInstance.from_dictionary({"definition_id": String(definition_id)})).is_empty(), "live gear has no player-stat percentage package: %s" % definition_id, failures)
		if catalog.definition_slot(definition_id) == &"weapon":
			_expect(lower_name.contains("sword") or lower_name.contains("blade"), "live weapon is a sword or blade: %s" % definition_id, failures)
	for set_id: StringName in ItemCatalog.SET_IDS:
		for slot: StringName in ItemCatalog.SLOTS:
			var definition_id := StringName("%s_%s" % [String(set_id), String(slot)])
			var definition := catalog.definition_data(definition_id)
			_expect(not definition.is_empty() and str(definition.get("gear_tier", "")) == "set", "set has a live definition: %s" % definition_id, failures)
			_expect(str(definition.get("set_id", "")) == String(set_id) and catalog.definition_slot(definition_id) == slot, "set keeps its slot identity: %s" % definition_id, failures)

	for slot: StringName in ItemCatalog.SLOTS:
		var source_definitions := catalog.definitions_for_slot(slot, &"chest", 1, 1)
		_expect(source_definitions.size() == 11, "each slot exposes two baseline and nine set drops: %s" % slot, failures)
	var observed_tiers: Dictionary = {}
	for seed in range(1, 512):
		var generated := catalog.generate_item(&"weapon", seed, 12, &"common", false, &"chest", 12)
		observed_tiers[str(catalog.definition_data(generated.definition_id).get("gear_tier", ""))] = true
	_expect(observed_tiers.has("plain") and observed_tiers.has("basic") and observed_tiers.has("set"), "chest generation reaches every live gear tier", failures)

	# A set accessory must beat the flexible basic bangle, not copy or trail it.
	var oath_charm := ItemInstance.new(); oath_charm.definition_id = &"oath_accessory"; oath_charm.rarity = &"common"
	var bangle := ItemInstance.new(); bangle.definition_id = &"bangle"; bangle.rarity = &"common"
	var oath_bonuses := catalog.bonuses(oath_charm)
	var bangle_bonuses := catalog.bonuses(bangle)
	var oath_sum := 0.0
	for value in oath_bonuses.values(): oath_sum += float(value)
	var bangle_sum := 0.0
	for value in bangle_bonuses.values(): bangle_sum += float(value)
	_expect(oath_bonuses.has("defense") and oath_sum > bangle_sum, "Oath Charm is a stronger defense-tier set accessory than the bangle", failures)
	_expect(catalog.price(oath_charm) > catalog.price(bangle), "Oath Charm prices above the basic bangle", failures)

	var plus_item := ItemInstance.new()
	plus_item.instance_id = "plus-display"
	plus_item.definition_id = &"basic_sword"
	plus_item.random_stat_points = {"defense": 1, "mnd": 2}
	_expect(catalog.random_plus_count(plus_item) == 3 and catalog.gear_name(plus_item) == "BASIC SWORD +++", "three random points display as a suffix after the gear name", failures)
	_expect(catalog.random_stat_text(plus_item) == "RANDOM DEF +1 MND +2", "the detail view names each random plus allocation", failures)
	_expect(catalog.display_name(plus_item) == "COMMON BASIC SWORD +++", "rarity and plus suffix remain readable together", failures)
	var clamped_plus := ItemInstance.from_dictionary({"instance_id": "clamped", "definition_id": "basic_sword", "random_stat_points": {"str": 3, "mnd": 3}})
	_expect(catalog.random_plus_count(clamped_plus) == 3, "saved random plus data is capped at three total points", failures)

	var common_growth := ItemInstance.new()
	common_growth.definition_id = &"soldier_weapon"
	common_growth.rarity = &"common"
	common_growth.random_stat_points = {"mnd": 1}
	var rare_growth := ItemInstance.from_dictionary(common_growth.to_dictionary())
	rare_growth.rarity = &"rare"
	var common_growth_values := catalog.bonuses(common_growth)
	var rare_growth_values := catalog.bonuses(rare_growth)
	_expect(is_equal_approx(float(rare_growth_values["strength"]) - float(common_growth_values["strength"]), 2.0) and is_equal_approx(float(rare_growth_values["mnd"]) - float(common_growth_values["mnd"]), 2.0), "a random secondary lane grows at the same rarity pace as the primary lane", failures)
	var enhanced_growth := ItemInstance.from_dictionary(common_growth.to_dictionary())
	enhanced_growth.enhancement_level = 1
	var enhanced_growth_values := catalog.bonuses(enhanced_growth)
	_expect(is_equal_approx(float(enhanced_growth_values["strength"]) - float(common_growth_values["strength"]), 0.1) and is_equal_approx(float(enhanced_growth_values["mnd"]) - float(common_growth_values["mnd"]), 0.1), "a random secondary lane grows at the same fusion pace as the primary lane", failures)

	var fusion_target := ItemInstance.new()
	fusion_target.instance_id = "fusion-no-plus"
	fusion_target.definition_id = &"basic_sword"
	fusion_target.rarity = &"common"
	var fusion_material := ItemInstance.new()
	fusion_material.instance_id = "fusion-plus"
	fusion_material.definition_id = &"basic_sword"
	fusion_material.rarity = &"common"
	fusion_material.random_stat_points = {"mnd": 1}
	_expect(profile.grant_item(fusion_target) and profile.grant_item(fusion_material), "fusion test items enter the profile", failures)
	_expect(profile.fusion_material_count(fusion_target.instance_id, catalog) == 1, "+ gear can fuse into an otherwise plain target", failures)
	profile.souls = 1
	_expect(profile.fuse_duplicates(fusion_target.instance_id, 1, catalog), "fusion accepts a material with an independent plus package", failures)
	var fused_target := profile.find_item(fusion_target.instance_id)
	_expect(fused_target != null and fused_target.enhancement_level == 1 and fused_target.random_stat_points.is_empty(), "fusion keeps the target's random package and raises its fusion level", failures)
	_expect(profile.find_item(fusion_material.instance_id) == null, "the independent-plus material is consumed", failures)

	var legacy_profile := PlayerProfile.new()
	legacy_profile.load_dictionary({"schema_version": 11, "base_vit": 4, "base_str": 3, "base_def": 1, "base_agi": 1, "base_int": 1, "base_mnd": 1})
	_expect(legacy_profile.base_vit == 2 and legacy_profile.base_str == 2 and legacy_profile.base_def == 2 and legacy_profile.base_agi == 2 and legacy_profile.base_int == 2 and legacy_profile.base_mnd == 2, "pre-baseline saves migrate to the even 2/2/2/2/2/2 base during the schema bump", failures)

	plus_item = null
	clamped_plus = null
	common_growth = null
	rare_growth = null
	enhanced_growth = null
	fusion_target = null
	fusion_material = null
	fused_target = null
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: gear system rework smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GEAR_SYSTEM_REWORK_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
