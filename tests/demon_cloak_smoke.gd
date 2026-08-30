extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Demon Cloak coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var profile := gameplay.get("player_profile") as PlayerProfile
	var run_state := gameplay.get("run_state") as RunState
	var anim := gameplay.get("player_animation_component") as PlayerAnimationComponent
	_expect(profile != null and run_state != null and anim != null, "Demon Cloak owners are composed", failures)
	if profile != null and run_state != null and anim != null:
		# Ignore any persistent-save pollution from earlier runs: this test owns
		# the cloak purchase state it asserts on.
		profile.demon_cloak_purchases = 0
		for data: Dictionary in profile.inventory.duplicate():
			if str(data.get("instance_id", "")).begins_with("demon-cloak-"):
				profile.inventory.erase(data)
		if str(profile.get_equipped_instance_id(&"body")).begins_with("demon-cloak-"):
			profile.unequip_slot(&"body")
		gameplay.call("_refresh_player_cloak_visual")
		await process_frame
		_expect(not anim.cloaked, "player starts with the base sheet", failures)
		_expect(profile.demon_cloak_price() == 500, "first cloak costs 500G", failures)
		run_state.ensure_shop_stock(profile)
		var cloak_entry: Dictionary = {}
		for entry: Dictionary in run_state.shop_stock:
			var entry_item: Dictionary = entry.get("item", {}) as Dictionary
			if str(entry_item.get("definition_id", "")) == "demon_cloak":
				cloak_entry = entry
				break
		_expect(not cloak_entry.is_empty(), "shop always offers the Demon Cloak", failures)
		_expect(bool(cloak_entry.get("permanent", false)), "Demon Cloak is a permanent shop offer", failures)
		profile.gold = 1000
		var first_cloak := profile.purchase_demon_cloak()
		_expect(first_cloak != null and first_cloak.definition_id == &"demon_cloak" and first_cloak.rarity == &"common", "Demon Cloak is sold as a Common", failures)
		_expect(profile.demon_cloak_purchases == 1 and profile.gold == 500, "first purchase costs 500G", failures)
		_expect(profile.demon_cloak_price() == 600, "each purchase raises the price by 100G", failures)
		profile.gold = 1000
		var second_cloak := profile.purchase_demon_cloak()
		_expect(second_cloak != null and second_cloak.instance_id != first_cloak.instance_id, "repeated purchases never share an instance", failures)
		_expect(profile.gold == 400 and profile.demon_cloak_price() == 700, "second purchase costs 600G and raises to 700G", failures)
		_expect(profile.demon_cloak_price() == 700, "price escalates per purchase", failures)
		var catalog := ItemCatalog.new()
		var cloak_bonuses := catalog.bonuses(first_cloak)
		_expect(float(cloak_bonuses.get("agi", 0.0)) >= 4.0 and float(cloak_bonuses.get("mnd", 0.0)) >= 2.0, "Demon Cloak carries the buffed Body + Head package", failures)
		var mythic_cloak := ItemInstance.from_dictionary(first_cloak.to_dictionary())
		mythic_cloak.rarity = &"mythic"
		mythic_cloak.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT
		var scaled_bonuses := catalog.bonuses(mythic_cloak)
		_expect(float(scaled_bonuses.get("agi", 0.0)) > float(cloak_bonuses.get("agi", 0.0)) and float(scaled_bonuses.get("defense", 0.0)) > float(cloak_bonuses.get("defense", 0.0)), "both AGI and DEF scale with rarity and enhancement", failures)
		var head_item := ItemInstance.new()
		head_item.instance_id = "test-head"
		head_item.definition_id = &"iron_helm"
		head_item.rarity = &"common"
		profile.grant_item(head_item)
		_expect(profile.equip_item(head_item.instance_id), "a head item equips before the cloak", failures)
		_expect(not profile.get_equipped_instance_id(&"head").is_empty(), "head slot holds the head item", failures)
		if first_cloak != null:
			_expect(profile.equip_item(first_cloak.instance_id), "Demon Cloak equips into the body slot", failures)
		_expect(profile.get_equipped_instance_id(&"head").is_empty(), "equipping the cloak auto-unequips the head slot", failures)
		_expect(profile._head_locked_by_body(catalog), "the cloak locks the head slot", failures)
		_expect(not profile.equip_item(head_item.instance_id), "a head item cannot be equipped while the cloak is worn", failures)
		gameplay.call("_refresh_player_cloak_visual")
		await process_frame
		_expect(anim.cloaked, "equipping the Demon Cloak swaps the player sheet", failures)
		if profile != null:
			_expect(profile.unequip_slot(&"body"), "Demon Cloak unequips", failures)
		_expect(not profile._head_locked_by_body(catalog), "removing the cloak unlocks the head slot", failures)
		_expect(profile.equip_item(head_item.instance_id), "a head item equips again after the cloak is removed", failures)
		gameplay.call("_refresh_player_cloak_visual")
		await process_frame
		_expect(not anim.cloaked, "removing the Demon Cloak reverts the player sheet", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Demon Cloak smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("DEMON_CLOAK_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)