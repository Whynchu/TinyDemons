extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog: ItemCatalog = ItemCatalog.new()
	var data := load("res://resources/definitions/item_catalog.tres") as ItemCatalogData
	_expect(data != null and data.definitions.is_empty(), "retired expansion item records are removed from ItemCatalogData", failures)
	_expect(data != null and data.transmutations.is_empty(), "retired item transmutation bindings are removed from ItemCatalogData", failures)
	if data != null:
		for raw_id: Variant in data.definition_metadata.keys():
			_expect(StringName(str(raw_id)) in data.live_base_ids, "%s metadata belongs to a retained live base" % str(raw_id), failures)
		_expect(data.validate().is_empty(), "purged ItemCatalogData and remaining typed resources validate", failures)
	_expect(catalog.transmutations.is_empty(), "retired-item transmutation records are removed from the runtime catalog", failures)
	for definition_id: StringName in ItemCatalog.RETIRED_DEFINITION_IDS:
		_expect(not catalog.definition_exists(definition_id), "%s no longer resolves from the runtime catalog" % definition_id, failures)
	for raw_id: Variant in catalog.definitions.keys():
		var definition_id := StringName(str(raw_id))
		_expect(catalog.definition_resource(definition_id) != null, "%s is backed by a standalone ItemDefinition, not the retired dictionary catalog" % definition_id, failures)

	var playable_ids := catalog.playable_definition_ids()
	_expect(&"cinder_blade" in playable_ids, "the standalone weapon remains playable", failures)
	_expect(&"demon_cloak" in playable_ids, "the special-acquisition Demon Cloak remains playable", failures)
	_expect(&"ash_mantle" not in playable_ids and &"bangle" not in playable_ids, "retired catalog entries are absent from the workbench/game list", failures)
	var cloak := catalog.definition_data(&"demon_cloak")
	_expect(catalog.definition_resource(&"demon_cloak") != null, "Demon Cloak is migrated to a typed resource", failures)
	_expect(cloak.get("slot", &"") == &"body" and "cloaked_demon" in cloak.get("source_tags", []), "Demon Cloak retains its special source and Body slot", failures)
	_expect("defense" in cloak.get("tier_stats", []), "Demon Cloak keeps its dual-scaled DEF lane", failures)
	_expect(not bool(cloak.get("drop_eligible", true)), "special-source Demon Cloak is playable but never enters random drops", failures)
	var basic_sword := catalog.definition_data(&"basic_sword")
	_expect(bool(basic_sword.get("shop_eligible", false)), "live base-item metadata still resolves after the legacy catalog purge", failures)

	var profile := PlayerProfile.new()
	profile.load_dictionary({
		"schema_version": 13,
		"gold": 123,
		"inventory": [
			{"instance_id": "retired-ash", "definition_id": "ash_mantle", "rarity": "rare"},
			{"instance_id": "retired-soldier", "definition_id": "soldier_sword", "rarity": "epic"},
			{"instance_id": "retired-effect", "definition_id": "basic_sword", "transmutation_id": "gathering_edge", "rarity": "rare"},
			{"instance_id": "live-cloak", "definition_id": "demon_cloak", "rarity": "common"},
			{"instance_id": "future-item", "definition_id": "future_item", "rarity": "common"},
		],
		"equipped_instance_ids": {
			"weapon": "retired-soldier",
			"body": "live-cloak",
		},
	})
	_expect(profile.schema_version == PlayerProfile.CURRENT_SCHEMA_VERSION, "retired-item save migration writes the current schema", failures)
	_expect(profile.find_item("retired-ash") == null and profile.find_item("retired-soldier") == null, "retired inventory instances are discarded on load", failures)
	_expect(profile.find_item("live-cloak") != null and profile.find_item("future-item") != null, "current special gear and unknown forward-compatible IDs are preserved", failures)
	var retired_transmutation_item := profile.find_item("retired-effect")
	_expect(retired_transmutation_item != null and retired_transmutation_item.transmutation_id.is_empty(), "retired transmutation data is cleared from retained current items", failures)
	_expect(profile.get_equipped_instance_id(&"body") == "live-cloak", "Demon Cloak remains equipped through profile migration", failures)
	_expect(profile.get_equipped_instance_id(&"head").is_empty(), "Demon Cloak keeps the Head slot locked after profile migration", failures)
	_expect(profile.get_equipped_instance_id(&"weapon") == "starter-weapon", "an equipped retired item is replaced by the current slot starter", failures)
	_expect(profile.gold == 123, "retired-item migration preserves unrelated profile progress", failures)

	var run_state := RunState.new()
	var restored := run_state.restore_from_dictionary({
		"run_id": "retired-item-run",
		"active": true,
		"shop_stock": [
			{"item": {"instance_id": "retired-stock", "definition_id": "ash_mantle"}, "price": 100},
			{"item": {"instance_id": "live-stock", "definition_id": "basic_sword", "transmutation_id": "gathering_edge"}, "price": 25},
			{"item": {"instance_id": "future-stock", "definition_id": "future_item"}, "price": 25},
		],
	})
	_expect(restored, "active-run snapshot with retired stock restores", failures)
	var stock_ids: Array[StringName] = []
	var live_stock_transmutation := ""
	for entry: Dictionary in run_state.shop_stock:
		var item_data: Dictionary = entry.get("item", {})
		var definition_id := StringName(str(item_data.get("definition_id", "")))
		stock_ids.append(definition_id)
		if definition_id == &"basic_sword":
			live_stock_transmutation = str(item_data.get("transmutation_id", ""))
	_expect(&"ash_mantle" not in stock_ids and &"basic_sword" in stock_ids and &"future_item" in stock_ids, "shop stock drops retired IDs but retains current and forward-compatible IDs", failures)
	_expect(live_stock_transmutation.is_empty(), "retired transmutation data is cleared from retained shop items", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	await create_timer(15.0).timeout
	if _finished:
		return
	push_error("TEST_ABORTED: retired item purge smoke did not complete")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RETIRED_ITEM_PURGE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
