extends SceneTree

const HubFlowControllerScript = preload("res://scripts/hub_flow_controller.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var controller := HubFlowControllerScript.new()
	get_root().add_child(controller)
	var root := _MockRoot.new()
	root.screen_state_controller = _MockScreenState.new()
	root.player_profile = PlayerProfile.new()
	var catalog := ItemCatalog.new()
	var target := ItemInstance.new()
	target.instance_id = "cache-target"
	target.definition_id = &"basic_sword"
	target.rarity = &"common"
	root.player_profile.grant_item(target)
	root.player_profile.equipped_instance_ids["weapon"] = target.instance_id

	controller.refresh_hub_fusion_candidates(root)
	_expect(controller.hub_fusion_candidates(root).is_empty(), "fusion cache starts empty without a duplicate", failures)

	var material := ItemInstance.new()
	material.instance_id = "cache-material"
	material.definition_id = &"basic_sword"
	material.rarity = &"common"
	root.player_profile.grant_item(material)
	var material2 := ItemInstance.new()
	material2.instance_id = "cache-material-2"
	material2.definition_id = &"basic_sword"
	material2.rarity = &"common"
	root.player_profile.grant_item(material2)
	_expect(controller.hub_fusion_candidates(root).is_empty(), "cached result stays stable until invalidated", failures)

	controller.set_hub_page(root, 3)
	var candidates := controller.hub_fusion_candidates(root)
	_expect(candidates.size() == 1 and candidates[0].instance_id == target.instance_id, "matching unequipped copies collapse into one FUSE row", failures)
	_expect(root.screen_state_controller.hub_fusion_candidates_dirty == false, "refreshed fusion cache is clean", failures)
	_expect(root.player_profile.fusion_owned_count(target.instance_id, catalog) == 2, "collapsed FUSE row reports both unequipped copies as owned", failures)
	_expect(root.player_profile.fusion_material_count(target.instance_id, catalog) == 2, "matching basic swords remain usable as materials", failures)

	# Equipment and Shop use the same functional identity. Quality is an
	# economic value, so copies with different quality still collapse; random
	# stat lanes and enhancement levels remain separate rows.
	var quality_copy := ItemInstance.new()
	quality_copy.instance_id = "cache-quality-copy"
	quality_copy.definition_id = &"basic_sword"
	quality_copy.rarity = &"common"
	quality_copy.quality = 0.91
	root.player_profile.grant_item(quality_copy)
	var stat_variant := ItemInstance.new()
	stat_variant.instance_id = "cache-stat-variant"
	stat_variant.definition_id = &"basic_sword"
	stat_variant.rarity = &"common"
	stat_variant.random_stat_points = {"mnd": 1}
	root.player_profile.grant_item(stat_variant)
	var enhanced_variant := ItemInstance.new()
	enhanced_variant.instance_id = "cache-enhanced-variant"
	enhanced_variant.definition_id = &"basic_sword"
	enhanced_variant.rarity = &"common"
	enhanced_variant.enhancement_level = 1
	enhanced_variant.fusion_stat_points = 1
	root.player_profile.grant_item(enhanced_variant)
	var equipment_candidates := controller.hub_gear_candidates(root, &"weapon")
	_expect(equipment_candidates.size() == 3, "Equipment collapses exact functional copies but keeps stat and enhancement variants", failures)
	var sellable := controller.shop_sellable_items(root)
	_expect(controller.shop_owned_matching_count(root, material) == 3, "Shop OWNED count includes quality-only copies in one functional stack", failures)
	var matching_rows := 0
	var stat_rows := 0
	var enhancement_rows := 0
	for item: ItemInstance in sellable:
		if item.inventory_stack_key() == material.inventory_stack_key(): matching_rows += 1
		if item.inventory_stack_key() == stat_variant.inventory_stack_key(): stat_rows += 1
		if item.inventory_stack_key() == enhanced_variant.inventory_stack_key(): enhancement_rows += 1
	_expect(matching_rows == 1 and stat_rows == 1 and enhancement_rows == 1, "Shop keeps each distinct stat/enhancement variant in its own row", failures)
	var batch_value := controller.shop_batch_value(root, material, 3)
	var expected_gold := catalog.sell_value(material) + catalog.sell_value(material2) + catalog.sell_value(quality_copy)
	var expected_souls := catalog.sell_soul_value(material) + catalog.sell_soul_value(material2) + catalog.sell_soul_value(quality_copy)
	_expect(int(batch_value.get("gold", 0)) == expected_gold and int(batch_value.get("souls", 0)) == expected_souls, "Grouped sell totals use the concrete quality/history values being consumed", failures)

	var cap_item := ItemInstance.new()
	cap_item.definition_id = &"basic_sword"
	cap_item.rarity = &"common"
	_expect(profile_steps_to_next_rank(cap_item) == PlayerProfile.MAX_ITEM_ENHANCEMENT, "Fusion cap starts at the current rarity boundary", failures)
	cap_item.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT - 1
	_expect(profile_steps_to_next_rank(cap_item) == 1, "Fusion cap is one step at the top enhancement", failures)
	cap_item.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT
	_expect(profile_steps_to_next_rank(cap_item) == 1, "Fusion cap allows one rarity promotion step", failures)
	cap_item.rarity = &"mythic"
	_expect(profile_steps_to_next_rank(cap_item) == 0, "Fusion cap closes at mythic maximum", failures)

	var capped_profile := PlayerProfile.new()
	capped_profile.souls = 999
	var capped_target := ItemInstance.new()
	capped_target.instance_id = "cache-cap-target"
	capped_target.definition_id = &"basic_sword"
	capped_target.rarity = &"common"
	capped_target.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT - 1
	capped_target.fusion_stat_points = PlayerProfile.MAX_ITEM_ENHANCEMENT - 1
	capped_profile.grant_item(capped_target)
	capped_profile.equipped_instance_ids["weapon"] = capped_target.instance_id
	for index in 3:
		var capped_material := ItemInstance.new()
		capped_material.instance_id = "cache-cap-material-%d" % index
		capped_material.definition_id = &"basic_sword"
		capped_material.rarity = &"common"
		capped_profile.grant_item(capped_material)
	_expect(capped_profile.fusion_material_count(capped_target.instance_id, catalog) == 1, "Fusion material count stops at the next rank boundary", failures)
	var capped_fuse_succeeded := capped_profile.fuse_duplicates(capped_target.instance_id, 3, catalog)
	var capped_result := capped_profile.find_item(capped_target.instance_id)
	_expect(capped_fuse_succeeded and capped_result != null and capped_result.enhancement_level == PlayerProfile.MAX_ITEM_ENHANCEMENT and capped_profile.inventory.size() == 3, "Fusion transaction clamps an oversized request to one boundary step", failures)

	controller.queue_free()
	_finished = true
	if failures.is_empty():
		print("FUSION_CANDIDATE_CACHE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: fusion candidate cache smoke failed before completion")
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)


func profile_steps_to_next_rank(item: ItemInstance) -> int:
	var profile := PlayerProfile.new()
	return profile.fusion_steps_to_next_rank(item)


class _MockScreenState:
	var hub_page := 0
	var hub_item_index := 0
	var hub_gear_browsing := false
	var hub_fusion_message := ""
	var hub_binding_message := ""
	var hub_fusion_count := 1
	var hub_fusion_candidates: Array[ItemInstance] = []
	var hub_fusion_candidates_dirty := true

	func update_hub_ui(_root: Object, _pixel_text: Callable) -> void:
		pass


class _MockRoot:
	var screen_state_controller: _MockScreenState
	var player_profile: PlayerProfile
	var run_state: RunState = null

	func _play_sound(_sound_name: String, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
		pass
