extends Node
class_name HubFlowController

const ProgressionControllerScript = preload("res://scripts/progression_controller.gd")


func build_hub_ui(root: Object) -> void:
	var controls: Dictionary = root.screen_state_controller.build_hub(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_hub_adjust_stat"), Callable(root, "_hub_confirm_stats"), Callable(root, "_hub_cancel_stats"), Callable(root, "_hub_auto_allocate"), Callable(root, "_hub_respec"), Callable(root, "_start_from_hub"), Callable(root, "_return_to_title"), Callable(root, "_set_hub_page"), Callable(root, "_hub_item_action"), Callable(root, "_select_hub_gear_slot"), Callable(root, "_hub_bind_current_element"))
	root.screen_state_controller.hub_overlay = controls["overlay"] as ColorRect
	root.screen_state_controller.hub_summary_text = controls["summary"] as Sprite2D
	root.screen_state_controller.hub_points_text = controls["points"] as Sprite2D
	root.screen_state_controller.hub_stat_texts = controls["stats"] as Array[Sprite2D]
	root.screen_state_controller.hub_stat_buttons = controls["stat_buttons"] as Array[Button]
	root.screen_state_controller.hub_stat_left_buttons = controls["stat_left"] as Array[Button]
	root.screen_state_controller.hub_stat_right_buttons = controls["stat_right"] as Array[Button]
	root.screen_state_controller.hub_respec_button = controls["respec"] as Button
	root.screen_state_controller.hub_start_button = controls["start"] as Button
	root.screen_state_controller.hub_title_button = controls["title"] as Button
	root.screen_state_controller.hub_derived_texts = controls["derived"] as Array[Sprite2D]
	root.screen_state_controller.hub_apply_button = controls["apply"] as Button
	root.screen_state_controller.hub_cancel_button = controls["cancel"] as Button
	root.screen_state_controller.hub_auto_button = controls["auto"] as Button
	root.screen_state_controller.hub_page_buttons = controls["pages"] as Array[Button]
	root.screen_state_controller.hub_item_name_text = controls["item_name"] as Sprite2D
	root.screen_state_controller.hub_item_list_texts = controls["item_list"] as Array[Sprite2D]
	root.screen_state_controller.hub_shop_price_texts = controls["shop_prices"] as Array[Sprite2D]
	root.screen_state_controller.hub_gear_choice_texts = controls["gear_choices"] as Array[Sprite2D]
	root.screen_state_controller.hub_gear_slot_buttons = controls["gear_slot_buttons"] as Array[Button]
	root.screen_state_controller.hub_gear_stat_texts = controls["gear_stats"] as Array[Sprite2D]
	root.screen_state_controller.hub_gear_stat_panel = controls["gear_stat_panel"] as Panel
	root.screen_state_controller.hub_binding_panel = controls["binding_panel"] as Panel
	root.screen_state_controller.hub_binding_texts = controls["binding_texts"] as Array[Sprite2D]
	root.screen_state_controller.hub_binding_action_button = controls["binding_action"] as Button
	root.screen_state_controller.hub_cursor_text = controls["cursor"] as Sprite2D
	root.screen_state_controller.hub_item_detail_texts = controls["item_details"] as Array[Sprite2D]
	root.screen_state_controller.hub_item_action_button = controls["item_action"] as Button


func show_hub(root: Object, from_npc: bool = false, pause_mode: bool = false) -> void:
	if root.screen_state_controller.hub_overlay == null:
		return
	# Inventory and equipped-slot state can change while the hub is closed. The
	# fusion page is intentionally cached for UI reads, so refresh its eligibility
	# whenever the hub is opened instead of showing a stale duplicate list.
	invalidate_hub_fusion_candidates(root)
	root.screen_state_controller.hub_opened_from_npc = from_npc
	root.screen_state_controller.hub_pause_mode = pause_mode
	root.screen_state_controller.hub_interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.hub_cancel_input_was_down = bool(root.call("_is_menu_cancel_input_pressed"))
	root.screen_state_controller.hub_page_previous_input_was_down = bool(root.call("_is_hub_previous_page_input_pressed"))
	root.screen_state_controller.hub_page_next_input_was_down = bool(root.call("_is_hub_next_page_input_pressed"))
	if root.screen_state_controller.title_overlay != null: root.screen_state_controller.title_overlay.visible = false
	if root.screen_state_controller.archetype_overlay != null: root.screen_state_controller.archetype_overlay.visible = false
	if root.loading_screen_overlay != null: root.loading_screen_overlay.visible = false
	if root.game_over_overlay != null: root.game_over_overlay.visible = false
	root.screen_state_controller.hub_overlay.visible = true
	root.screen_state_controller.hub_page = 1 if pause_mode else 0
	root.screen_state_controller.hub_item_index = 0
	root.screen_state_controller.hub_binding_message = ""
	root.call("_hub_cancel_stats")
	root.call("_play_sound", "ui_pause" if pause_mode else "ui_confirm", 0.0, 1.0)
	root.screen_state_controller.set_state(&"hub")
	root.call("_select_hub_menu_row", 0)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func open_pause_menu(root: Object) -> void:
	if root.player_dead or root.player_death_pending or root.screen_state_controller.hub_overlay == null or root.screen_state_controller.hub_overlay.visible:
		return
	root.screen_state_controller.pause_input_was_down = true
	show_hub(root, false, true)


func open_hub_from_cloaked_demon(root: Object) -> void:
	if root.player_dead or root.screen_state_controller.hub_overlay == null:
		return
	if root.npc_controller.dialogue_box != null and root.npc_controller.dialogue_box.visible:
		root.npc_controller.hide_dialogue(root)
	root.player_is_moving = false
	root.player_is_attacking = false
	root.player_is_rolling = false
	root.player_attack_visual.visible = false
	root.interact_prompt.visible = false
	show_hub(root, true)


func close_hub_to_run(root: Object) -> void:
	if root.screen_state_controller.hub_overlay == null:
		return
	var was_pause: bool = bool(root.screen_state_controller.hub_pause_mode)
	root.call("_hub_cancel_stats")
	root.screen_state_controller.hub_gear_browsing = false
	root.screen_state_controller.menu_input_release_lock = bool(root.call("_is_menu_cancel_input_pressed"))
	root.screen_state_controller.hub_overlay.visible = false
	root.screen_state_controller.hub_opened_from_npc = false
	root.screen_state_controller.hub_pause_mode = false
	root.interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.set_state(&"gameplay")
	root.call("_play_sound", "ui_unpause", 0.0, 1.0)
	if was_pause:
		return


func update_hub_input(root: Object) -> void:
	root.screen_state_controller.update_hub_input(root)


func set_hub_page(root: Object, page: int) -> void:
	root.screen_state_controller.hub_page = posmod(page, 5)
	root.screen_state_controller.hub_item_index = 0
	root.screen_state_controller.hub_gear_browsing = false
	root.screen_state_controller.hub_fusion_message = ""
	root.screen_state_controller.hub_binding_message = ""
	root.screen_state_controller.hub_fusion_count = 1
	if root.screen_state_controller.hub_page == 3:
		invalidate_hub_fusion_candidates(root)
	if root.run_state != null and root.screen_state_controller.hub_page == 2:
		root.run_state.ensure_shop_stock(root.player_profile.level)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_hover", -6.0, 1.0)


func hub_bind_current_element(root: Object) -> bool:
	if root.player_profile == null:
		return false
	var chroma := root.get("player_chroma_component") as Node
	var current := String(chroma.call("aspect_name")).to_upper() if chroma != null else "GRAY"
	var success := bool(root.call("_bind_current_element"))
	if success:
		root.screen_state_controller.hub_binding_message = "BOUND %s" % current
	else:
		root.screen_state_controller.hub_binding_message = "NEED 50 SOULS" if current != "GRAY" and root.player_profile.souls < PlayerProfile.ELEMENT_BIND_SOUL_COST else "BIND UNAVAILABLE"
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	return success


func shift_hub_item(root: Object, direction: int) -> void:
	var count: int = 0
	if root.screen_state_controller.hub_page == 1:
		count = ItemCatalog.SLOTS.size()
	elif root.screen_state_controller.hub_page == 2:
		count = root.run_state.shop_stock.size() if root.run_state != null else 0
	elif root.screen_state_controller.hub_page == 3:
		count = hub_fusion_candidates(root).size()
		root.screen_state_controller.hub_fusion_count = 1
	if count > 0: root.screen_state_controller.hub_item_index = posmod(root.screen_state_controller.hub_item_index + direction, count)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_gear_candidates(root: Object, slot: StringName) -> Array[ItemInstance]:
	var candidates: Array[ItemInstance] = []
	if root.player_profile == null:
		return candidates
	var catalog := ItemCatalog.new()
	if slot == &"shield":
		var unequip := ItemInstance.new()
		unequip.instance_id = ItemCatalog.UNEQUIP_SHIELD_ID
		candidates.append(unequip)
	for data: Dictionary in root.player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if catalog.definition_slot(item.definition_id) == slot: candidates.append(item)
	return candidates


func shift_hub_gear_candidate(root: Object, direction: int) -> void:
	if root.screen_state_controller.hub_page != 1 or not root.screen_state_controller.hub_gear_browsing: return
	var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var candidates := hub_gear_candidates(root, slot)
	if candidates.is_empty(): return
	var key := String(slot)
	root.screen_state_controller.hub_gear_candidate_indices[key] = posmod(int(root.screen_state_controller.hub_gear_candidate_indices.get(key, 0)) + direction, candidates.size())
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func select_hub_gear_slot(root: Object, slot_index: int) -> void:
	if root.screen_state_controller.hub_page != 1: return
	root.screen_state_controller.hub_item_index = clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)
	var slot: StringName = ItemCatalog.SLOTS[root.screen_state_controller.hub_item_index]
	var candidates := hub_gear_candidates(root, slot)
	if not candidates.is_empty():
		var equipped_id := str(root.player_profile.equipped_instance_ids.get(String(slot), ""))
		for index in candidates.size():
			if candidates[index].instance_id == equipped_id:
				root.screen_state_controller.hub_gear_candidate_indices[String(slot)] = index
				break
		root.screen_state_controller.hub_gear_browsing = true
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func close_hub_gear_browse(root: Object) -> void:
	root.screen_state_controller.hub_gear_browsing = false
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func refresh_hub_fusion_candidates(root: Object) -> void:
	root.screen_state_controller.hub_fusion_candidates.clear()
	root.screen_state_controller.hub_fusion_candidates_dirty = false
	if root.player_profile == null: return
	var catalog := ItemCatalog.new()
	for data: Dictionary in root.player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if root.player_profile.fusion_material_count(item.instance_id, catalog) > 0 or root.player_profile.can_salvage_overflow(item.instance_id, catalog):
			root.screen_state_controller.hub_fusion_candidates.append(item)


func invalidate_hub_fusion_candidates(root: Object) -> void:
	root.screen_state_controller.hub_fusion_candidates_dirty = true


func hub_fusion_candidates(root: Object) -> Array[ItemInstance]:
	if root.screen_state_controller.hub_fusion_candidates_dirty:
		refresh_hub_fusion_candidates(root)
	return root.screen_state_controller.hub_fusion_candidates


func fuse_profile_target(root: Object, instance_id: String, count: int) -> bool:
	if root.player_profile == null or count <= 0 or not root.player_profile.fuse_duplicates(instance_id, count, ItemCatalog.new()):
		return false
	root.player_equipment.configure_from_profile(root.player_profile)
	root.call("_configure_equipment_transmutations")
	root.call("_apply_player_level")
	root.call("_save_player_profile")
	root.call("_update_soul_indicator")
	invalidate_hub_fusion_candidates(root)
	return true


func shift_hub_fusion_count(root: Object, direction: int) -> void:
	if root.screen_state_controller.hub_page != 3: return
	var candidates := hub_fusion_candidates(root)
	if candidates.is_empty(): return
	var index: int = clampi(root.screen_state_controller.hub_item_index, 0, candidates.size() - 1)
	var target: ItemInstance = candidates[index]
	if root.player_profile.can_salvage_overflow(target.instance_id): return
	var material_count: int = root.player_profile.fusion_material_count(target.instance_id)
	if material_count <= 0: return
	root.screen_state_controller.hub_fusion_count = clampi(int(root.screen_state_controller.hub_fusion_count) + direction, 1, material_count)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func salvage_profile_overflow(root: Object, instance_id: String) -> int:
	if root.player_profile == null: return 0
	var value: int = root.player_profile.salvage_overflow(instance_id)
	if value <= 0: return 0
	invalidate_hub_fusion_candidates(root)
	root.call("_save_player_profile")
	root.call("_update_gold_indicator")
	return value


func hub_item_action(root: Object) -> void:
	if root.player_profile == null: return
	if root.screen_state_controller.hub_page == 1:
		var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var candidates := hub_gear_candidates(root, slot)
		if not candidates.is_empty():
			var candidate_index: int = posmod(int(root.screen_state_controller.hub_gear_candidate_indices.get(String(slot), 0)), candidates.size())
			if not root.screen_state_controller.hub_gear_browsing:
				var equipped_id := str(root.player_profile.equipped_instance_ids.get(String(slot), ""))
				for index in candidates.size():
					if candidates[index].instance_id == equipped_id:
						root.screen_state_controller.hub_gear_candidate_indices[String(slot)] = index
						break
				root.screen_state_controller.hub_gear_browsing = true
			else:
				var selected: ItemInstance = candidates[candidate_index]
				var equipped_id := str(root.player_profile.equipped_instance_ids.get(String(slot), ""))
				if selected.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID or (slot == &"shield" and selected.instance_id == equipped_id):
					root.call("_unequip_profile_slot", slot)
				else:
					root.call("_equip_profile_item", selected.instance_id)
				# Equipping or unequipping changes which copies may be used as
				# materials, so the cached target list must be rebuilt.
				invalidate_hub_fusion_candidates(root)
				root.screen_state_controller.hub_gear_browsing = false
			root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		return
	elif root.screen_state_controller.hub_page == 2 and root.run_state != null and not root.run_state.shop_stock.is_empty():
		var index: int = clampi(root.screen_state_controller.hub_item_index, 0, root.run_state.shop_stock.size() - 1)
		var entry: Dictionary = root.run_state.shop_stock[index]
		if not bool(entry.get("sold", false)):
			var item := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
			if root.player_profile.purchase_item(item, int(entry.get("price", 0))):
				entry["sold"] = true; root.run_state.shop_stock[index] = entry; invalidate_hub_fusion_candidates(root); root.call("_save_player_profile"); root.call("_update_gold_indicator"); root.call("_play_sound", "ui_confirm", 0.0, 1.0); root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			else:
				root.call("_play_sound", "ui_denied", 0.0, 1.0)
	elif root.screen_state_controller.hub_page == 3:
		var fusion_candidates := hub_fusion_candidates(root)
		if not fusion_candidates.is_empty():
			var index: int = clampi(root.screen_state_controller.hub_item_index, 0, fusion_candidates.size() - 1)
			var target: ItemInstance = fusion_candidates[index]
			if root.player_profile.fusion_material_count(target.instance_id) > 0:
				var material_count: int = root.player_profile.fusion_material_count(target.instance_id)
				var count: int = clampi(int(root.screen_state_controller.hub_fusion_count), 1, material_count)
				var batch_cost: int = root.player_profile.fusion_batch_cost(target, count)
				if root.player_profile.souls < batch_cost:
					root.screen_state_controller.hub_fusion_message = "NEED %dS" % batch_cost
					root.call("_play_sound", "ui_denied", 0.0, 1.0)
				else:
					var family_name := str(ItemCatalog.DEFINITIONS.get(target.definition_id, {}).get("name", "ITEM"))
					if fuse_profile_target(root, target.instance_id, count):
						root.screen_state_controller.hub_fusion_message = "%s ENHANCED" % family_name
						root.call("_play_sound", "ui_confirm", 0.0, 1.0)
						root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			elif root.player_profile.can_salvage_overflow(target.instance_id):
				var salvage_value: int = salvage_profile_overflow(root, target.instance_id)
				if salvage_value > 0:
					root.screen_state_controller.hub_fusion_message = "SALVAGED %dG" % salvage_value
					root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			if not root.screen_state_controller.hub_fusion_message.is_empty():
				invalidate_hub_fusion_candidates(root)
				root.screen_state_controller.hub_item_index = clampi(root.screen_state_controller.hub_item_index, 0, maxi(hub_fusion_candidates(root).size() - 1, 0))
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func select_hub_menu_row(root: Object, row: int) -> void:
	root.screen_state_controller.hub_menu_row = posmod(row, 5)
	if root.screen_state_controller.hub_menu_row < 4: root.screen_state_controller.hub_action_column = 0
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func shift_hub_action_column(root: Object, direction: int) -> void:
	var count: int = 4 if root.screen_state_controller.hub_menu_row == 4 else 2
	root.screen_state_controller.hub_action_column = posmod(root.screen_state_controller.hub_action_column + direction, count)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_adjust_stat(root: Object, stat_name: StringName, direction: int) -> void:
	if direction > 0:
		hub_allocate_stat(root, stat_name)
		return
	match stat_name:
		&"VIT": root.screen_state_controller.hub_pending_vit = maxi(root.screen_state_controller.hub_pending_vit - 1, 0)
		&"STR": root.screen_state_controller.hub_pending_str = maxi(root.screen_state_controller.hub_pending_str - 1, 0)
		&"DEF": root.screen_state_controller.hub_pending_def = maxi(root.screen_state_controller.hub_pending_def - 1, 0)
		&"SPD": root.screen_state_controller.hub_pending_spd = maxi(root.screen_state_controller.hub_pending_spd - 1, 0)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_allocate_stat(root: Object, stat_name: StringName) -> void:
	if root.player_profile == null or hub_points_remaining(root) <= 0: return
	match stat_name:
		&"VIT": root.screen_state_controller.hub_pending_vit += 1
		&"STR": root.screen_state_controller.hub_pending_str += 1
		&"DEF": root.screen_state_controller.hub_pending_def += 1
		&"SPD": root.screen_state_controller.hub_pending_spd += 1
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_points_remaining(root: Object) -> int:
	return ProgressionControllerScript.points_remaining(root.player_profile, {"VIT": root.screen_state_controller.hub_pending_vit, "STR": root.screen_state_controller.hub_pending_str, "DEF": root.screen_state_controller.hub_pending_def, "SPD": root.screen_state_controller.hub_pending_spd})


func hub_confirm_stats(root: Object) -> void:
	if root.player_profile == null: return
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	ProgressionControllerScript.allocate_stats(root.player_profile, {"VIT": root.screen_state_controller.hub_pending_vit, "STR": root.screen_state_controller.hub_pending_str, "DEF": root.screen_state_controller.hub_pending_def, "SPD": root.screen_state_controller.hub_pending_spd})
	root.screen_state_controller.hub_pending_vit = 0; root.screen_state_controller.hub_pending_str = 0; root.screen_state_controller.hub_pending_def = 0; root.screen_state_controller.hub_pending_spd = 0
	root.call("_apply_profile_to_runtime"); root.call("_apply_player_level"); root.call("_sync_runtime_progression_to_profile")
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_cancel_stats(root: Object) -> void:
	root.screen_state_controller.hub_pending_vit = 0; root.screen_state_controller.hub_pending_str = 0; root.screen_state_controller.hub_pending_def = 0; root.screen_state_controller.hub_pending_spd = 0
	if root.screen_state_controller != null and root.screen_state_controller.hub_overlay != null: root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_auto_allocate(root: Object) -> void:
	if root.player_profile == null: return
	var patterns: Array = [[&"VIT", &"STR", &"DEF", &"SPD"], [&"VIT", &"VIT", &"STR", &"VIT", &"DEF", &"SPD"], [&"STR", &"STR", &"VIT", &"STR", &"DEF", &"SPD"], [&"DEF", &"DEF", &"VIT", &"DEF", &"STR", &"SPD"], [&"STR", &"DEF", &"STR", &"DEF", &"SPD"]]
	var pattern: Array = patterns[clampi(root.player_profile.allocation_profile, 0, patterns.size() - 1)]
	var index: int = 0
	while hub_points_remaining(root) > 0:
		match pattern[index % pattern.size()]:
			&"VIT": root.screen_state_controller.hub_pending_vit += 1
			&"STR": root.screen_state_controller.hub_pending_str += 1
			&"DEF": root.screen_state_controller.hub_pending_def += 1
			&"SPD": root.screen_state_controller.hub_pending_spd += 1
		index += 1
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_respec(root: Object) -> void:
	hub_cancel_stats(root)
	if int(root.call("_respec_player_stats")) > 0: root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func start_from_hub(root: Object) -> void:
	if root.screen_state_controller.hub_opened_from_npc:
		root.call("_close_hub_to_run")
		return
	if root.screen_state_controller.hub_overlay != null: root.screen_state_controller.hub_overlay.visible = false
	if root.player_profile != null:
		root.player_profile.open_hub_on_load = false
		root.player_profile.pending_route = "run"
		root.call("_save_player_profile")
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	root.call("_begin_scene_transition")
