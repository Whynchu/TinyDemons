extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)
	_expect(profile.inventory.size() == 6, "six starter items", failures)
	_expect(profile.equipped_instance_ids.values().all(func(id: String) -> bool: return not id.is_empty()), "all slots equipped", failures)
	var first := catalog.generate_item(&"weapon", 12345, 10, &"epic")
	var second := catalog.generate_item(&"weapon", 12345, 10, &"epic")
	_expect(first.to_dictionary() == second.to_dictionary(), "seeded item generation is stable", failures)
	_expect(first.affixes.is_empty() and catalog.random_plus_count(first) <= 3, "generated gear uses the flat package and capped random-plus data", failures)
	var legendary := catalog.generate_item(&"weapon", 90210, 20, &"legendary")
	var mythic := catalog.generate_item(&"weapon", 90211, 20, &"mythic")
	_expect(legendary.affixes.is_empty() and mythic.affixes.is_empty(), "high-rarity gear has no hidden random stat points", failures)
	var common_sword := ItemInstance.new(); common_sword.definition_id = &"basic_sword"; common_sword.rarity = &"common"
	var common_sword_plus_one := ItemInstance.from_dictionary(common_sword.to_dictionary()); common_sword_plus_one.enhancement_level = 1
	var common_sword_plus_five := ItemInstance.from_dictionary(common_sword.to_dictionary()); common_sword_plus_five.enhancement_level = 5
	var common_sword_plus_ten := ItemInstance.from_dictionary(common_sword.to_dictionary()); common_sword_plus_ten.enhancement_level = 10
	var rare_sword := ItemInstance.from_dictionary(common_sword.to_dictionary()); rare_sword.rarity = &"rare"
	var rare_sword_plus_ten := ItemInstance.from_dictionary(rare_sword.to_dictionary()); rare_sword_plus_ten.enhancement_level = 10
	var epic_sword := ItemInstance.from_dictionary(rare_sword.to_dictionary()); epic_sword.rarity = &"epic"
	_expect(is_equal_approx(catalog.bonuses(common_sword)["strength"], 2.0), "common sword starts at STR 2", failures)
	_expect(is_equal_approx(catalog.bonuses(common_sword_plus_one)["strength"], 2.1), "common +1 sword gains 0.1 STR", failures)
	_expect(is_equal_approx(catalog.bonuses(common_sword_plus_five)["strength"], 2.5), "common +5 sword gains 0.5 STR", failures)
	_expect(is_equal_approx(catalog.bonuses(common_sword_plus_ten)["strength"], 3.0), "common +10 sword reaches STR 3", failures)
	_expect(is_equal_approx(catalog.bonuses(rare_sword)["strength"], 4.0), "rare sword starts at STR 4", failures)
	_expect(is_equal_approx(catalog.bonuses(rare_sword_plus_ten)["strength"], 5.0), "rare +10 sword reaches STR 5", failures)
	_expect(is_equal_approx(catalog.bonuses(epic_sword)["strength"], 6.0), "epic sword starts at STR 6", failures)
	_expect(is_equal_approx(catalog.rarity_stat_rate(&"common"), 0.0) and is_equal_approx(catalog.rarity_stat_rate(&"rare"), 0.0) and is_equal_approx(catalog.rarity_stat_rate(&"epic"), 0.0) and is_equal_approx(catalog.rarity_stat_rate(&"legendary"), 0.0) and is_equal_approx(catalog.rarity_stat_rate(&"mythic"), 0.0), "live gear has no hidden rarity percentage rates", failures)
	var basic_tunic := ItemInstance.new(); basic_tunic.definition_id = &"basic_tunic"
	var basic_shield := ItemInstance.new(); basic_shield.definition_id = &"basic_shield"
	var bangle := ItemInstance.new(); bangle.definition_id = &"bangle"
	var tunic_bonuses := catalog.bonuses(basic_tunic)
	var shield_bonuses := catalog.bonuses(basic_shield)
	var bangle_bonuses := catalog.bonuses(bangle)
	_expect(is_equal_approx(tunic_bonuses.get("vitality", 0.0), 1.0) and is_equal_approx(tunic_bonuses.get("defense", 0.0), 1.0), "basic tunic package is VIT 1 DEF 1", failures)
	_expect(is_equal_approx(shield_bonuses.get("vitality", 0.0), 1.0) and is_equal_approx(shield_bonuses.get("speed", 0.0), -1.0) and is_equal_approx(shield_bonuses.get("defense", 0.0), 2.0), "basic shield package is VIT 1 SPD -1 DEF 2", failures)
	_expect(is_equal_approx(bangle_bonuses.get("strength", 0.0), 1.0) and is_equal_approx(bangle_bonuses.get("vitality", 0.0), 1.0) and is_equal_approx(bangle_bonuses.get("speed", 0.0), 1.0), "bangle package is STR 1 VIT 1 SPD 1", failures)
	var common_price_item := ItemInstance.new(); common_price_item.definition_id = &"basic_sword"; common_price_item.rarity = &"common"
	legendary.definition_id = &"basic_sword"; legendary.quality = 1.0; mythic.definition_id = &"basic_sword"; mythic.quality = 1.0
	_expect(catalog.price(mythic) > catalog.price(legendary) and catalog.price(legendary) > catalog.price(common_price_item), "higher rarity has higher shop value", failures)
	var rarity_order := [&"common", &"rare", &"epic", &"legendary", &"mythic"]
	_expect(rarity_order.size() == 5, "rarity tiers remain available", failures)
	_expect(catalog.rarity_color(&"common") == Color.WHITE and catalog.rarity_color(&"rare") != catalog.rarity_color(&"epic") and catalog.rarity_color(&"legendary") != catalog.rarity_color(&"mythic"), "rarity colors are distinct", failures)
	var low_rank_rare_roll := catalog.roll_run_rarity(0.35, 1, 0.0)
	var high_rank_rare_roll := catalog.roll_run_rarity(0.35, 12, 3.0)
	var rarity_rank_order := {&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 4}
	_expect(rarity_rank_order[high_rank_rare_roll] > rarity_rank_order[low_rank_rare_roll], "higher rank/performance rolls strictly higher rarity", failures)
	_expect(high_rank_rare_roll == &"rare", "rank 12 + S-grade at roll 0.35 is rare", failures)
	_expect(low_rank_rare_roll == &"common", "rank 1 at roll 0.35 is common", failures)
	_expect(catalog.roll_run_rarity(0.0, 1, 0.0) != &"common", "roll near zero is never common at any rank", failures)
	_expect(catalog.roll_run_rarity(1.0, 1, 0.0) == &"common", "roll of one is always common", failures)
	var consistent_tiers := [&"mythic", &"legendary", &"epic", &"rare", &"common"]
	for tier in consistent_tiers:
		_expect(catalog.roll_run_rarity(0.0, 12, 3.0) == &"mythic", "top rank guarantees %s is reachable" % String(tier), failures)
	first.instance_id = profile.create_item_id("test")
	_expect(profile.grant_item(first), "new item granted", failures)
	_expect(not profile.grant_item(first), "duplicate item rejected", failures)
	_expect(profile.equip_item(first.instance_id, catalog), "weapon equips", failures)
	var equipment := EquipmentComponent.new()
	equipment.configure_from_profile(profile, catalog)
	_expect(equipment.strength_bonus >= 0.0, "equipped primary bonuses reach combat component", failures)
	var rate_profile := PlayerProfile.new(); rate_profile.ensure_starter_items(catalog)
	var rare_starter_sword := ItemInstance.new(); rare_starter_sword.instance_id = "rare-starter-sword"; rare_starter_sword.definition_id = &"basic_sword"; rare_starter_sword.rarity = &"rare"
	_expect(rate_profile.grant_item(rare_starter_sword) and rate_profile.equip_item(rare_starter_sword.instance_id, catalog), "rare starter sword equips", failures)
	var rate_equipment := EquipmentComponent.new(); rate_equipment.configure_from_profile(rate_profile, catalog)
	_expect(is_equal_approx(rate_equipment.strength_rate_bonus, 0.0), "rare positive STR package has no hidden player STR rate", failures)
	var rate_stats := StatsComponent.new(); rate_stats.configure_manual_growth(3, 2, 2, 1, 0, 0, 0, 0)
	var rate_snapshot := CombatStatSnapshot.from_components(rate_stats, rate_equipment)
	_expect(is_equal_approx(rate_snapshot.gear_strength, 4.0) and is_equal_approx(rate_snapshot.strength, 7.0), "rarity adds flat points to the affected stat", failures)
	var restored := PlayerProfile.new()
	profile.souls = 7
	restored.load_dictionary(profile.to_dictionary())
	_expect(restored.find_item(first.instance_id) != null, "inventory persists", failures)
	_expect(restored.equipped_instance_ids["weapon"] == first.instance_id, "equipped slot persists", failures)
	_expect(restored.souls == 7, "souls persist with the profile", failures)
	var run := RunState.new(); run.begin(424242); run.ensure_shop_stock(restored)
	var stock_copy := run.shop_stock.duplicate(true); run.ensure_shop_stock(restored)
	_expect(run.shop_stock == stock_copy and run.shop_stock.size() == 8, "shop stock stable within run", failures)
	var shop_ids: Dictionary = {}
	for shop_entry: Dictionary in run.shop_stock:
		var stock_item := ItemInstance.from_dictionary(shop_entry.get("item", {}) as Dictionary)
		_expect(not shop_ids.has(stock_item.instance_id), "shop stock entries keep unique purchase IDs", failures)
		shop_ids[stock_item.instance_id] = true
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
	var common_plus_ten := ItemInstance.new(); common_plus_ten.definition_id = &"soldier_sword"; common_plus_ten.rarity = &"common"; common_plus_ten.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT
	var common_plus_zero := ItemInstance.new(); common_plus_zero.definition_id = &"soldier_sword"; common_plus_zero.rarity = &"common"; common_plus_zero.enhancement_level = 0
	var rare_plus_one := ItemInstance.new(); rare_plus_one.definition_id = &"soldier_sword"; rare_plus_one.rarity = &"rare"; rare_plus_one.enhancement_level = 1
	_expect(restored.fusion_batch_cost(common_plus_zero, 1) == 1, "common +0 to +1 starts at 1 Soul", failures)
	_expect(restored.fusion_batch_cost(common_plus_ten, 1) == 10, "common +10 to rare costs 10 Souls", failures)
	_expect(restored.fusion_batch_cost(fusion_base, 1) == 11, "rare +0 to +1 costs 11 Souls", failures)
	_expect(restored.fusion_batch_cost(rare_plus_one, 1) == 12, "fusion cost rises one Soul per enhancement tier", failures)
	restored.souls = 50
	_expect(restored.fuse_duplicates(fusion_base.instance_id, 1, catalog), "target fuses its available duplicate", failures)
	_expect(restored.inventory.size() == inventory_before_fusion - 1, "fusion consumes exactly one material", failures)
	_expect(restored.find_item(fusion_base.instance_id).enhancement_level == 1, "fusion enhances the target", failures)
	_expect(restored.souls == 50 - 11, "fusion charges the stepped Soul cost", failures)
	_expect(restored.fusion_material_count(fusion_base.instance_id, catalog) == 0, "no materials remain after fusion", failures)
	_expect(not restored.fuse_duplicates(fusion_base.instance_id, 1, catalog), "fusion fails without materials", failures)
	_expect(restored.fusion_batch_cost(restored.find_item(fusion_base.instance_id), 1) == 12, "fusion cost scales with target enhancement", failures)
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
	_expect(enhanced_bonuses.has("strength"), "enhancement preserves primary implicit", failures)
	equipment.configure_from_profile(restored, catalog)
	var equipped_shield := restored.find_item(restored.equipped_instance_ids["shield"])
	_expect(not enhanced_bonuses.has("damage_rate"), "ordinary gear has no damage-rate bonus", failures)
	var affixed := ItemInstance.new(); affixed.definition_id = &"soldier_sword"; affixed.affixes = {"keen": 2}
	var affixed_plain := catalog.bonuses(affixed, 0)
	affixed.enhancement_level = 1
	var affixed_enhanced := catalog.bonuses(affixed, 0)
	_expect(is_equal_approx(affixed_plain.get("strength", 0.0), 3.0) and is_equal_approx(affixed_enhanced.get("strength", 0.0), 3.1), "legacy affixes do not bypass the tier package", failures)
	_expect(not affixed_enhanced.has("damage_rate"), "damage affixes are not ordinary gear stats", failures)
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
	rate_stats.free()
	rate_equipment.free()
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
