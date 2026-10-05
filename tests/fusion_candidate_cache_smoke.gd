extends SceneTree

const HubEconomyControllerScript = preload("res://scripts/runtime/controllers/hub_economy_controller.gd")
const HubTransactionMenuContextScript = preload("res://scripts/ui/hub_transaction_menu_context.gd")
const HubTransactionMenuPresenterScript = preload("res://scripts/ui/hub_transaction_menu_presenter.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var controller := HubEconomyControllerScript.new()
	var root := _MockRoot.new()
	root.screen_state_controller = _MockScreenState.new()
	root.player_profile = PlayerProfile.new()
	root.player_profile.souls = 999
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
	var refreshed_candidates := controller.hub_fusion_candidates(root)
	_expect(refreshed_candidates.size() == 1 and controller.fusion_candidate_details(root, target).get("material_count", 0) == 2, "inventory revision refreshes Fusion eligibility and quantities immediately", failures)
	var high_target := ItemInstance.new()
	high_target.instance_id = "cache-high-target"
	high_target.definition_id = &"arcane_body"
	high_target.rarity = &"common"
	var high_material := ItemInstance.new()
	high_material.instance_id = "cache-high-material"
	high_material.definition_id = &"arcane_body"
	high_material.rarity = &"common"
	root.player_profile.grant_item(high_target)
	root.player_profile.grant_item(high_material)
	var low_target := ItemInstance.new()
	low_target.instance_id = "cache-low-target"
	low_target.definition_id = &"plain_hood"
	low_target.rarity = &"common"
	var low_material := ItemInstance.new()
	low_material.instance_id = "cache-low-material"
	low_material.definition_id = &"plain_hood"
	low_material.rarity = &"common"
	root.player_profile.grant_item(low_target)
	root.player_profile.grant_item(low_material)

	root.screen_state_controller.hub_page = 3
	var candidates := controller.hub_fusion_candidates(root)
	_expect(candidates.size() == 3 and candidates[0].instance_id == target.instance_id and candidates[1].instance_id == high_target.instance_id and candidates[2].instance_id == low_target.instance_id, "Fusion sorts equipped targets first, then descending total primary stats", failures)
	_expect(catalog.stat_allocation_total(high_target) > catalog.stat_allocation_total(low_target), "Fusion sort fixture has distinct total primary stat allocations", failures)
	_expect(root.screen_state_controller.hub_fusion_candidates_dirty == false, "refreshed fusion cache is clean", failures)
	_expect(root.player_profile.fusion_owned_count(target.instance_id, catalog) == 2, "collapsed FUSE row reports both unequipped copies as owned", failures)
	_expect(root.player_profile.fusion_material_count(target.instance_id, catalog) == 2, "matching basic swords remain usable as materials", failures)
	var inventory_size_before_selection := root.player_profile.inventory.size()
	var inventory_revision_before_selection := root.player_profile.inventory_revision
	controller.select_hub_item_row(root, 0)
	_expect(root.screen_state_controller.hub_fusion_target_instance_id == candidates[0].instance_id and root.screen_state_controller.hub_fusion_state == 1, "touch row selects a stable Fusion target without entering the action state", failures)
	_expect(root._hub_item_action_count == 0 and root.player_profile.inventory.size() == inventory_size_before_selection and root.player_profile.inventory_revision == inventory_revision_before_selection, "selecting a Fusion row never calls the transaction or changes inventory", failures)
	controller.hub_item_action(root)
	_expect(root.screen_state_controller.hub_fusion_state == 2 and root.player_profile.inventory.size() == inventory_size_before_selection and root.player_profile.inventory_revision == inventory_revision_before_selection, "first Fusion confirmation only enters amount selection", failures)
	controller.shift_hub_fusion_count(root, 1)
	_expect(root.screen_state_controller.hub_fusion_count == 2, "Fusion quantity control advances the selected target above one", failures)
	var fusion_context := HubTransactionMenuContextScript.new()
	fusion_context.profile = root.player_profile
	fusion_context.catalog = catalog
	fusion_context.fusion_candidates = controller.hub_fusion_candidates(root)
	fusion_context.fusion_state = root.screen_state_controller.hub_fusion_state
	fusion_context.selected_index = 1 # stale cursor must not redirect a confirmed target's data
	fusion_context.fusion_target_instance_id = target.instance_id
	fusion_context.fusion_count = root.screen_state_controller.hub_fusion_count
	fusion_context.fusion_details = controller.fusion_candidate_details(root, candidates[0])
	var fusion_model := HubTransactionMenuPresenterScript.new().build_fusion_model(fusion_context)
	_expect(fusion_model.selected_row == 0 and fusion_model.owned_count == 2 and fusion_model.material_count == 2 and fusion_model.fusion_count_max == 2, "Fusion amount view resolves selected target by instance ID despite stale cursor and preserves its counts", failures)
	controller.hub_item_action(root)
	_expect(root.player_profile.inventory.size() == inventory_size_before_selection - 2 and root.player_profile.inventory_revision == inventory_revision_before_selection + 1, "second Fusion confirmation consumes the requested materials as one transaction", failures)
	_expect(root.player_profile.find_item(target.instance_id).fusion_count == 2, "completed Fusion applies both enhancement steps to the selected target", failures)
	# A profile change while the amount prompt is open must never redirect the
	# final confirmation to the item now occupying the old row.
	root.screen_state_controller.hub_item_index = 1
	root.screen_state_controller.hub_fusion_state = 1
	root.screen_state_controller.hub_fusion_target_instance_id = ""
	controller.hub_item_action(root)
	var vanished_id := root.screen_state_controller.hub_fusion_target_instance_id
	var remaining_inventory_before := root.player_profile.inventory.size()
	var remaining_revision_before := root.player_profile.inventory_revision
	root.player_profile.inventory = root.player_profile.inventory.filter(func(data: Dictionary) -> bool: return str(data.get("instance_id", "")) != vanished_id)
	root.player_profile.inventory_revision += 1
	remaining_inventory_before -= 1
	remaining_revision_before += 1
	controller.hub_item_action(root)
	_expect(root.player_profile.inventory.size() == remaining_inventory_before and root.player_profile.inventory_revision == remaining_revision_before, "vanished Fusion target cannot consume another row's materials", failures)
	_expect(root.screen_state_controller.hub_fusion_state == 1, "vanished Fusion target returns to browsing", failures)

	var mismatch_profile := PlayerProfile.new()
	mismatch_profile.souls = 999
	var rare_target := ItemInstance.new()
	rare_target.instance_id = "cache-rare-target"
	rare_target.definition_id = &"basic_sword"
	rare_target.rarity = &"rare"
	var common_material := ItemInstance.new()
	common_material.instance_id = "cache-common-material"
	common_material.definition_id = &"basic_sword"
	common_material.rarity = &"common"
	_expect(mismatch_profile.grant_item(rare_target), "rare target can be staged for rarity-boundary coverage", failures)
	_expect(mismatch_profile.grant_item(common_material), "common material can be staged for rarity-boundary coverage", failures)
	mismatch_profile.equipped_instance_ids["weapon"] = rare_target.instance_id
	var mismatch_root := _MockRoot.new()
	mismatch_root.screen_state_controller = _MockScreenState.new()
	mismatch_root.player_profile = mismatch_profile
	controller.refresh_hub_fusion_candidates(mismatch_root)
	_expect(mismatch_profile.fusion_material_count(rare_target.instance_id, catalog) == 0, "different-rarity material is not eligible for a rare target", failures)
	_expect(controller.hub_fusion_candidates(mismatch_root).is_empty(), "different-rarity material does not expose a fusion candidate", failures)
	_expect(not mismatch_profile.fuse_duplicates(rare_target.instance_id, 1, catalog), "different-rarity material cannot fuse into a rare target", failures)
	_expect(mismatch_profile.find_item(rare_target.instance_id).rarity == &"rare" and mismatch_profile.find_item(common_material.instance_id) != null, "rejected cross-rarity fusion leaves both items unchanged", failures)

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
	var hub_list_scroll := 0.0
	var hub_is_root := true
	var hub_content_focus := false
	var hub_equipment_action_focus := false
	var hub_gear_browsing := false
	var hub_fusion_message := ""
	var hub_binding_message := ""
	var hub_fusion_count := 1
	var hub_fusion_target_instance_id := ""
	var hub_fusion_state := 1
	var hub_fusion_item_selected := false
	var hub_fusion_menu: Control = null
	var hub_fusion_candidates: Array[ItemInstance] = []
	var hub_fusion_candidates_dirty := true

	func update_hub_ui(_root: Object, _pixel_text: Callable) -> void:
		pass

	func snap_hub_list_scroll_to_selection(_root: Object) -> void:
		pass

	func refresh_equipment_menu(_root: Object) -> void:
		pass


class _MockRoot:
	var screen_state_controller: _MockScreenState
	var player_profile: PlayerProfile
	var run_state: RunState = null
	var _hub_item_action_count := 0
	var player_equipment := _MockEquipment.new()

	func _play_sound(_sound_name: String, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
		pass

	func _hub_item_action() -> void:
		_hub_item_action_count += 1

	func _pixel_text_texture(_text: String, _color: Color = Color.WHITE) -> Texture2D:
		return null

	func _configure_equipment_transmutations() -> void:
		pass

	func _apply_player_level() -> void:
		pass

	func _save_player_profile() -> void:
		pass

	func _update_soul_indicator() -> void:
		pass


class _MockEquipment:
	func configure_from_profile(_profile: PlayerProfile) -> void:
		pass
