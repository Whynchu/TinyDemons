extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)

	var first_slot := catalog.select_slot_for_source(profile, 4242, 1, &"chest", 1)
	var repeat_slot := catalog.select_slot_for_source(profile, 4242, 1, &"chest", 1)
	_expect(first_slot == repeat_slot, "source slot policy is deterministic for a seed", failures)
	_expect(first_slot in ItemCatalog.SLOTS, "source slot policy returns a canonical slot", failures)

	var chest_slots := {}
	for seed in range(1, 300):
		var slot := catalog.select_slot_for_source(profile, seed, 12, &"chest", 12)
		chest_slots[slot] = true
	_expect(chest_slots.size() == ItemCatalog.SLOTS.size(), "representative chest seeds can select every approved slot", failures)

	for slot: StringName in ItemCatalog.SLOTS:
		var item := catalog.generate_item(slot, 9000 + int(slot.hash()), 12, &"common", false, &"chest", 12)
		_expect(not item.definition_id.is_empty() and catalog.definition_slot(item.definition_id) == slot, "chest generation returns a legal %s item" % catalog.slot_label(slot), failures)
		_expect(not bool(catalog.definition_data(item.definition_id).get("starter_only", false)), "chest generation never returns a starter-only %s" % catalog.slot_label(slot), failures)

	var shop := RunState.new()
	shop.begin(777)
	shop.ensure_shop_stock(12)
	var shop_slots := {}
	for entry: Dictionary in shop.shop_stock:
		var item := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
		shop_slots[catalog.definition_slot(item.definition_id)] = true
	_expect(shop.shop_stock.size() == ItemCatalog.SLOTS.size() + 1, "shop keeps one baseline per slot plus one premium", failures)
	_expect(shop_slots.size() == ItemCatalog.SLOTS.size(), "shop stock covers every approved slot", failures)
	_expect(shop.shop_stock.all(func(entry: Dictionary) -> bool: return entry.get("source", "") == "shop" and not str(entry.get("role", "")).is_empty() and entry.has("primary_stat") and entry.has("description")), "shop entries carry source and authored presentation metadata", failures)

	var old_profile := PlayerProfile.new()
	old_profile.ensure_starter_items(catalog)
	var real_head := catalog.generate_item(&"head", 55, 12, &"rare", true, &"chest", 12)
	real_head.instance_id = "real-head"
	old_profile.grant_item(real_head)
	old_profile.equip_item(real_head.instance_id, catalog)
	var real_arm := catalog.generate_item(&"arm", 56, 12, &"rare", true, &"chest", 12)
	real_arm.instance_id = "real-arm"
	old_profile.grant_item(real_arm)
	old_profile.equip_item(real_arm.instance_id, catalog)
	var complete_slot := catalog.select_slot_for_source(old_profile, 4242, 12, &"clear_reward", 12)
	_expect(complete_slot in ItemCatalog.SLOTS, "completed loadout still selects from all canonical slots", failures)
	var clear_history_slot := catalog.select_slot_for_source(old_profile, 4242, 12, &"clear_reward", 12, [String(complete_slot)])
	_expect(clear_history_slot in ItemCatalog.SLOTS and clear_history_slot != complete_slot, "clear reward history avoids an immediate repeat when alternatives exist", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: gear drop policy smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GEAR_DROP_POLICY_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
