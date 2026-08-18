extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)
	_expect(profile.inventory.size() == 4, "four starter items", failures)
	_expect(profile.equipped_instance_ids.values().all(func(id: String) -> bool: return not id.is_empty()), "all slots equipped", failures)
	var first := catalog.generate_item(&"weapon", 12345, 10, &"epic")
	var second := catalog.generate_item(&"weapon", 12345, 10, &"epic")
	_expect(first.to_dictionary() == second.to_dictionary(), "seeded item generation is stable", failures)
	_expect(first.affixes.size() == 2, "epic has two affixes", failures)
	var legendary := catalog.generate_item(&"weapon", 90210, 20, &"legendary")
	var mythic := catalog.generate_item(&"weapon", 90211, 20, &"mythic")
	_expect(legendary.affixes.size() == 3 and mythic.affixes.size() == 3, "legendary and mythic have three affixes", failures)
	var common_price_item := ItemInstance.new(); common_price_item.definition_id = &"basic_sword"; common_price_item.rarity = &"common"
	legendary.definition_id = &"basic_sword"; legendary.quality = 1.0; mythic.definition_id = &"basic_sword"; mythic.quality = 1.0
	_expect(catalog.price(mythic) > catalog.price(legendary) and catalog.price(legendary) > catalog.price(common_price_item), "higher rarity has higher shop value", failures)
	var rarity_order := [&"common", &"rare", &"epic", &"legendary", &"mythic"]
	var prev_plus_ten := -INF
	for rarity_index in rarity_order.size():
		var rarity: StringName = rarity_order[rarity_index]
		var base_item := ItemInstance.new(); base_item.definition_id = &"basic_sword"; base_item.rarity = rarity; base_item.quality = 1.0
		var tier_zero := float(catalog.bonuses(base_item, 0)["damage_rate"])
		if rarity_index > 0:
			_expect(tier_zero > prev_plus_ten, "%s +0 (%f) beats %s +10 (%f)" % [String(rarity), tier_zero, String(rarity_order[rarity_index - 1]), prev_plus_ten], failures)
		base_item.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT
		prev_plus_ten = float(catalog.bonuses(base_item, 0)["damage_rate"])
	_expect(catalog.rarity_color(&"common") == Color.WHITE and catalog.rarity_color(&"rare") != catalog.rarity_color(&"epic") and catalog.rarity_color(&"legendary") != catalog.rarity_color(&"mythic"), "rarity colors are distinct", failures)
	first.instance_id = profile.create_item_id("test")
	_expect(profile.grant_item(first), "new item granted", failures)
	_expect(not profile.grant_item(first), "duplicate item rejected", failures)
	_expect(profile.equip_item(first.instance_id, catalog), "weapon equips", failures)
	var equipment := EquipmentComponent.new()
	equipment.configure_from_profile(profile, catalog)
	_expect(equipment.damage_rate_bonus > 0.0, "equipped bonuses reach combat component", failures)
	var restored := PlayerProfile.new()
	restored.load_dictionary(profile.to_dictionary())
	_expect(restored.find_item(first.instance_id) != null, "inventory persists", failures)
	_expect(restored.equipped_instance_ids["weapon"] == first.instance_id, "equipped slot persists", failures)
	var run := RunState.new(); run.begin(424242); run.ensure_shop_stock(restored.level)
	var stock_copy := run.shop_stock.duplicate(true); run.ensure_shop_stock(restored.level)
	_expect(run.shop_stock == stock_copy and run.shop_stock.size() == 5, "shop stock stable within run", failures)
	var entry: Dictionary = run.shop_stock[0]; var shop_item := ItemInstance.from_dictionary(entry["item"])
	restored.gold = int(entry["price"])
	_expect(restored.purchase_item(shop_item, int(entry["price"])), "purchase succeeds atomically", failures)
	_expect(restored.gold == 0 and restored.find_item(shop_item.instance_id) != null, "purchase spends and grants", failures)
	var fusion_base := ItemInstance.new(); fusion_base.instance_id = "fusion-equipped"; fusion_base.definition_id = &"soldier_sword"; fusion_base.rarity = &"rare"
	var fusion_duplicate := ItemInstance.new(); fusion_duplicate.instance_id = "fusion-consume"; fusion_duplicate.definition_id = &"soldier_sword"; fusion_duplicate.rarity = &"rare"; fusion_duplicate.affixes = {"keen": 2}
	_expect(restored.grant_item(fusion_base), "fusion base granted", failures)
	_expect(restored.grant_item(fusion_duplicate), "fusion duplicate granted", failures)
	_expect(restored.equip_item(fusion_base.instance_id, catalog), "fusion base equips", failures)
	var inventory_before_fusion := restored.inventory.size()
	_expect(restored.fusion_material_count(fusion_base.instance_id, catalog) == 1, "one duplicate is available as material", failures)
	_expect(restored.fusion_material_count(fusion_duplicate.instance_id, catalog) <= 1, "equipped base is not a material", failures)
	_expect(restored.fusion_batch_cost(fusion_base, 1) == PlayerProfile.FUSION_BASE_COST, "single-step fusion costs the base rate", failures)
	restored.gold = 50
	_expect(restored.fuse_duplicates(fusion_base.instance_id, 1, catalog), "target fuses its available duplicate", failures)
	_expect(restored.inventory.size() == inventory_before_fusion - 1, "fusion consumes exactly one material", failures)
	_expect(restored.find_item(fusion_base.instance_id).enhancement_level == 1, "fusion enhances the target", failures)
	_expect(restored.gold == 50 - PlayerProfile.FUSION_BASE_COST, "fusion charges the target-scaled cost", failures)
	_expect(restored.fusion_material_count(fusion_base.instance_id, catalog) == 0, "no materials remain after fusion", failures)
	_expect(not restored.fuse_duplicates(fusion_base.instance_id, 1, catalog), "fusion fails without materials", failures)
	_expect(restored.fusion_batch_cost(restored.find_item(fusion_base.instance_id), 1) == PlayerProfile.FUSION_BASE_COST + PlayerProfile.FUSION_COST_PER_ENHANCEMENT, "fusion cost scales with target enhancement", failures)
	var overflow_item := ItemInstance.new(); overflow_item.instance_id = "overflow-salvage"; overflow_item.definition_id = &"soldier_sword"; overflow_item.rarity = &"mythic"; overflow_item.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT
	_expect(restored.grant_item(overflow_item), "overflow item granted", failures)
	var gold_before_salvage := restored.gold
	_expect(not restored.can_salvage_overflow(fusion_base.instance_id, catalog), "equipped overflow item cannot salvage", failures)
	_expect(restored.can_salvage_overflow(overflow_item.instance_id, catalog), "maxed mythic duplicate can salvage", failures)
	var salvage_value := restored.salvage_overflow(overflow_item.instance_id, catalog)
	_expect(salvage_value == catalog.overflow_salvage_value(overflow_item) and restored.gold == gold_before_salvage + salvage_value, "overflow salvage grants deterministic gold", failures)
	_expect(restored.find_item(overflow_item.instance_id) == null, "salvage consumes overflow once", failures)
	var plain_source := ItemInstance.new(); plain_source.definition_id = &"soldier_sword"
	var plain_bonuses := catalog.bonuses(plain_source, 0)
	var enhanced_item := restored.find_item(fusion_base.instance_id)
	var enhanced_bonuses := catalog.bonuses(enhanced_item, 0)
	_expect(float(enhanced_bonuses["damage_rate"]) > float(plain_bonuses["damage_rate"]), "enhancement improves base implicit", failures)
	equipment.configure_from_profile(restored, catalog)
	var equipped_shield := restored.find_item(restored.equipped_instance_ids["shield"])
	var shield_damage_penalty := float(catalog.shield_bonuses(equipped_shield).get("damage_penalty", 0.0)) * 0.01
	_expect(is_equal_approx(equipment.damage_rate_bonus, float(enhanced_bonuses["damage_rate"]) * 0.01 - shield_damage_penalty), "enhanced weapon bonus reaches combat equipment", failures)
	var affixed := ItemInstance.new(); affixed.definition_id = &"soldier_sword"; affixed.affixes = {"keen": 2}
	var affixed_plain := catalog.bonuses(affixed, 0)
	affixed.enhancement_level = 1
	var affixed_enhanced := catalog.bonuses(affixed, 0)
	_expect(is_equal_approx(float(affixed_enhanced["damage_rate"]) - float(affixed_plain["damage_rate"]), (float(plain_bonuses["damage_rate"]) + 2.0) * ItemCatalog.MASTERY_BONUS_PER_LEVEL), "enhancement scales implicit and affixes together", failures)
	var fusion_round_trip := PlayerProfile.new(); fusion_round_trip.load_dictionary(restored.to_dictionary())
	_expect(fusion_round_trip.find_item(fusion_base.instance_id).enhancement_level == 1, "fusion enhancement persists", failures)
	var bastion_shield := ItemInstance.new(); bastion_shield.instance_id = "bastion-test"; bastion_shield.definition_id = &"living_bulwark"; bastion_shield.rarity = &"epic"; bastion_shield.transmutation_id = &"bastion_core"
	var bastion_round_trip := ItemInstance.from_dictionary(bastion_shield.to_dictionary())
	_expect(bastion_round_trip.transmutation_id == &"bastion_core", "transmutation persists on item", failures)
	_expect(restored.grant_item(bastion_shield) and restored.equip_item(bastion_shield.instance_id, catalog), "bastion shield equips", failures)
	equipment.configure_from_profile(restored, catalog)
	var transmutations := EquipmentTransmutationComponent.new(); transmutations.configure(equipment)
	_expect(transmutations.guard_maximum_durability(8.0, 6) > 8.0, "bastion DEF raises guard durability", failures)
	transmutations.record_successful_block(); transmutations.record_successful_block()
	_expect(transmutations.bastion_charges == 2, "successful blocks store bastion charges", failures)
	transmutations.begin_attack(1)
	_expect(is_equal_approx(transmutations.attack_knockback_multiplier(), 1.0) and transmutations.bastion_charges == 2, "attack 1 preserves bastion charges", failures)
	transmutations.begin_attack(2)
	_expect(transmutations.bastion_charges == 0 and transmutations.attack_knockback_multiplier() > 1.0, "attack 2 consumes bastion charges", failures)
	transmutations.finish_attack()
	_expect(is_equal_approx(transmutations.attack_knockback_multiplier(), 1.0), "bastion boost ends with attack", failures)
	var duelist_seal := ItemInstance.new(); duelist_seal.instance_id = "duelist-test"; duelist_seal.definition_id = &"duelist_seal"; duelist_seal.rarity = &"epic"; duelist_seal.transmutation_id = &"duelist_focus"
	_expect(restored.grant_item(duelist_seal) and restored.equip_item(duelist_seal.instance_id, catalog), "duelist seal equips", failures)
	equipment.configure_from_profile(restored, catalog); transmutations.configure(equipment)
	var locked_target := Sprite2D.new(); var other_target := Sprite2D.new()
	_expect(transmutations.duelist_damage_multiplier(locked_target, locked_target, 8) > 1.0, "duelist boosts locked target with STR", failures)
	_expect(is_equal_approx(transmutations.duelist_damage_multiplier(other_target, locked_target, 8), 0.80), "duelist penalizes other targets", failures)
	locked_target.free(); other_target.free()
	var gathering_sword := ItemInstance.new(); gathering_sword.instance_id = "gathering-test"; gathering_sword.definition_id = &"soldier_sword"; gathering_sword.rarity = &"epic"; gathering_sword.transmutation_id = &"gathering_edge"
	_expect(restored.grant_item(gathering_sword) and restored.equip_item(gathering_sword.instance_id, catalog), "gathering sword equips", failures)
	equipment.configure_from_profile(restored, catalog); transmutations.configure(equipment)
	var gathered_a := Sprite2D.new(); var gathered_b := Sprite2D.new(); var outside_target := Sprite2D.new()
	transmutations.begin_attack(1); transmutations.record_attack_hits(1, [gathered_a, gathered_b]); transmutations.finish_attack(); transmutations.begin_attack(2)
	_expect(is_equal_approx(transmutations.damage_share_divisor(gathered_a, 3), 2.0), "gathering reduces split for original target", failures)
	_expect(is_equal_approx(transmutations.damage_share_divisor(outside_target, 3), 3.0), "gathering does not boost unrelated target", failures)
	transmutations.finish_attack(); _expect(is_equal_approx(transmutations.damage_share_divisor(gathered_a, 3), 3.0), "gathering boost ends with attack", failures)
	gathered_a.free(); gathered_b.free(); outside_target.free()
	transmutations.free()
	equipment.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: item economy smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ITEM_ECONOMY_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)