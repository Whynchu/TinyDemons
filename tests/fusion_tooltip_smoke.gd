extends SceneTree

const HubFlowControllerScript = preload("res://scripts/hub_flow_controller.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var root := _MockRoot.new()
	var controller_instance: Node = ScreenStateController.new()
	var host := Node.new()
	host.add_child(controller_instance)
	root.screen_state_controller = controller_instance
	var pixel: Callable = Callable(root, "_pixel_text_texture")
	var built: Dictionary = controller_instance.call("build_hub", host, pixel, Callable(root, "_adj"), Callable(root, "_apply"), Callable(root, "_cancel"), Callable(root, "_auto"), Callable(root, "_respec"), Callable(root, "_start"), Callable(root, "_title"), Callable(root, "_set_page"), Callable(root, "_item_action"), Callable(root, "_select_gear_slot"), Callable(), Callable(root, "_select_gear_candidate"))
	var key_map := {
		"overlay": "hub_overlay", "summary": "hub_summary_text", "points": "hub_points_text",
		"stats": "hub_stat_texts", "stat_buttons": "hub_stat_buttons", "derived": "hub_derived_texts",
		"apply": "hub_apply_button", "cancel": "hub_cancel_button", "auto": "hub_auto_button", "respec": "hub_respec_button",
		"pages": "hub_page_buttons", "item_name": "hub_item_name_text", "item_list": "hub_item_list_texts",
		"shop_prices": "hub_shop_price_texts", "gear_choices": "hub_gear_choice_texts", "gear_choice_buttons": "hub_gear_choice_buttons",
		"gear_slot_buttons": "hub_gear_slot_buttons", "gear_stats": "hub_gear_stat_texts",
		"gear_stat_panel": "hub_gear_stat_panel", "item_details": "hub_item_detail_texts",
		"item_action": "hub_item_action_button", "binding_panel": "hub_binding_panel",
		"binding_texts": "hub_binding_texts", "binding_action": "hub_binding_action_button", "cursor": "hub_cursor_text",
	}
	for key: String in built:
		controller_instance.set(str(key_map.get(key, key)), built[key])
	var stat_buttons := built["stat_buttons"] as Array[Button]
	var stat_texts := built["stats"] as Array[Sprite2D]
	_expect(stat_buttons.size() == 8 and stat_buttons.all(func(button: Button) -> bool: return button.size.x >= 18.0 and button.size.y >= 12.0), "hub stat arrows expose touch-sized hit targets", failures)
	_expect(stat_texts.all(func(text: Sprite2D) -> bool: return text.centered), "hub stat values are centered between their touch targets", failures)
	controller_instance.hub_overlay = ColorRect.new()
	controller_instance.hub_page = 1
	controller_instance.hub_pause_mode = false
	controller_instance.hub_menu_row = 0
	controller_instance.hub_item_index = 0
	controller_instance.hub_gear_browsing = false
	controller_instance.hub_gear_candidate_indices = {}
	controller_instance.hub_fusion_message = ""
	controller_instance.hub_fusion_count = 1
	controller_instance.player_palette_name = "blue"
	var profile := PlayerProfile.new()
	profile.ensure_starter_items(ItemCatalog.new())
	var duplicate := ItemInstance.new()
	duplicate.instance_id = "dupe-weapon-1"
	duplicate.definition_id = &"soldier_sword"
	duplicate.rarity = &"rare"
	profile.grant_item(duplicate)
	var duplicate2 := ItemInstance.new()
	duplicate2.instance_id = "dupe-weapon-2"
	duplicate2.definition_id = &"soldier_sword"
	duplicate2.rarity = &"rare"
	profile.grant_item(duplicate2)
	root.player_profile = profile
	root.progression_tuning = ProgressionTuning.new()
	root.run_state = RunState.new()
	controller_instance.hub_page = 0
	controller_instance.call("update_hub_ui", root, pixel)
	_expect(controller_instance.hub_derived_texts.all(func(text: Sprite2D) -> bool: return not text.visible), "stats page hides duplicate derived values", failures)
	var gear_stats := controller_instance.hub_gear_stat_texts as Array[Sprite2D]
	var details := controller_instance.hub_item_detail_texts as Array[Sprite2D]
	controller_instance.hub_page = 1
	controller_instance.hub_gear_browsing = true
	controller_instance.hub_item_index = 0
	controller_instance.call("update_hub_ui", root, pixel)
	_expect(gear_stats.slice(0, 4).all(func(s: Sprite2D) -> bool: return s.texture != null) and gear_stats[4].texture == null, "gear browse shows four flat-stat rows without stale duplicate SPD", failures)
	var gear_choice_buttons: Array[Button] = controller_instance.hub_gear_choice_buttons
	_expect(gear_choice_buttons.size() == 4 and gear_choice_buttons.all(func(b: Button) -> bool: return b.mouse_filter != Control.MOUSE_FILTER_IGNORE), "gear browse exposes touchable choice rows", failures)
	_expect(gear_choice_buttons[0].visible and gear_choice_buttons[1].visible, "gear browse shows touch targets for visible candidates", failures)
	gear_choice_buttons[0].pressed.emit()
	_expect(root.selected_gear_candidate_row == 0, "gear choice row forwards its selected candidate", failures)
	var gear_flow := HubFlowControllerScript.new()
	var gear_candidates := gear_flow.hub_gear_candidates(root, &"weapon")
	root.selected_equipped_instance_id = ""
	controller_instance.hub_gear_candidate_indices = {"weapon": 0}
	gear_flow.select_hub_gear_candidate(root, 1)
	_expect(gear_candidates.size() > 1 and root.selected_equipped_instance_id == gear_candidates[1].instance_id, "touching a gear row equips that visible candidate", failures)
	_expect(not controller_instance.hub_gear_browsing, "touch gear selection closes the browse state", failures)
	gear_flow.free()
	root._set_page(3)
	controller_instance.hub_page = 3
	controller_instance.hub_item_index = 0
	controller_instance.hub_gear_browsing = false
	controller_instance.call("update_hub_ui", root, pixel)
	_expect(gear_stats[0].texture != null, "fusion preview populates gear stat panel on FUSE page", failures)
	_expect(details[0].texture == null, "gear tooltip not retained in details[0] when FUSE item has no transmutation", failures)
	root._set_page(2)
	controller_instance.hub_page = 2
	controller_instance.hub_item_index = 0
	controller_instance.call("update_hub_ui", root, pixel)
	_expect(details[0].texture != null, "shop page shows item bonus text in details[0]", failures)
	root._set_page(3)
	controller_instance.hub_page = 3
	controller_instance.hub_item_index = 0
	controller_instance.call("update_hub_ui", root, pixel)
	_expect(details[0].texture == null, "shop bonus text cleared from details[0] on FUSE page", failures)
	_expect(gear_stats[0].texture != null, "fusion preview repopulates gear stat panel after shop visit", failures)
	controller_instance.hub_overlay.free()
	host.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: hub fusion tooltip smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("HUB_FUSION_TOOLTIP_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)


class _MockRoot:
	var screen_state_controller: ScreenStateController = null
	var hub_page := 0
	var hub_pause_mode := false
	var hub_menu_row := 0
	var hub_item_index := 0
	var hub_gear_browsing := false
	var hub_gear_candidate_indices := {}
	var hub_fusion_message := ""
	var hub_fusion_count := 1
	var hub_interact_input_was_down := false
	var hub_page_previous_input_was_down := false
	var hub_page_next_input_was_down := false
	var hub_cancel_input_was_down := false
	var hub_action_column := 0
	var player_profile: PlayerProfile = null
	var progression_tuning: ProgressionTuning = null
	var run_state: RunState = null
	var combat_tuning: CombatTuning = null
	var player_palette_name := &""
	var hub_summary_text: Sprite2D = null
	var hub_points_text: Sprite2D = null
	var hub_cursor_text: Sprite2D = null
	var hub_overlay: ColorRect = null
	var hub_item_name_text: Sprite2D = null
	var hub_item_list_texts: Array[Sprite2D] = []
	var hub_shop_price_texts: Array[Sprite2D] = []
	var hub_gear_choice_texts: Array[Sprite2D] = []
	var hub_gear_stat_texts: Array[Sprite2D] = []
	var hub_item_detail_texts: Array[Sprite2D] = []
	var hub_stat_texts: Array[Sprite2D] = []
	var hub_stat_buttons: Array[Button] = []
	var hub_derived_texts: Array[Sprite2D] = []
	var hub_page_buttons: Array[Button] = []
	var hub_gear_slot_buttons: Array[Button] = []
	var hub_gear_choice_buttons: Array[Button] = []
	var hub_gear_stat_panel: Panel = null
	var hub_item_action_button: Button = null
	var hub_binding_panel: Panel = null
	var hub_binding_texts: Array[Sprite2D] = []
	var hub_binding_action_button: Button = null
	var hub_apply_button: Button = null
	var hub_cancel_button: Button = null
	var hub_auto_button: Button = null
	var hub_respec_button: Button = null
	var selected_gear_candidate_row := -1
	var selected_equipped_instance_id := ""

	func _pixel_text_texture(text: String, color: Color) -> Texture2D:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(color)
		return ImageTexture.create_from_image(image)

	func _adj(_s: StringName, _d: int) -> void:
		pass

	func _apply() -> void:
		pass

	func _cancel() -> void:
		pass

	func _auto() -> void:
		pass

	func _respec() -> void:
		pass

	func _start() -> void:
		pass

	func _title() -> void:
		pass

	func _set_page(page: int) -> void:
		hub_page = page
		hub_item_index = 0
		hub_gear_browsing = false
		hub_fusion_message = ""
		hub_fusion_count = 1

	func _item_action() -> void:
		pass

	func _select_gear_slot(_slot_index: int) -> void:
		pass

	func _select_gear_candidate(choice_row: int) -> void:
		selected_gear_candidate_row = choice_row

	func _equip_profile_item(instance_id: String) -> void:
		selected_equipped_instance_id = instance_id
		player_profile.equipped_instance_ids["weapon"] = instance_id

	func _health_feedback_color(_palette: StringName) -> Color:
		return Color.WHITE

	func _hub_gear_candidates(slot: StringName) -> Array[ItemInstance]:
		var candidates: Array[ItemInstance] = []
		if player_profile == null:
			return candidates
		var catalog := ItemCatalog.new()
		if slot == &"shield":
			var unequip := ItemInstance.new()
			unequip.instance_id = ItemCatalog.UNEQUIP_SHIELD_ID
			candidates.append(unequip)
		for data: Dictionary in player_profile.inventory:
			var item := ItemInstance.from_dictionary(data)
			if catalog.definition_slot(item.definition_id) == slot:
				candidates.append(item)
		return candidates

	func _hub_fusion_candidates() -> Array[ItemInstance]:
		if player_profile == null:
			return []
		var catalog := ItemCatalog.new()
		var candidates: Array[ItemInstance] = []
		for data: Dictionary in player_profile.inventory:
			var item := ItemInstance.from_dictionary(data)
			if player_profile.fusion_material_count(item.instance_id, catalog) > 0 or player_profile.can_salvage_overflow(item.instance_id, catalog):
				candidates.append(item)
		return candidates

	func _player_stat_snapshot() -> Object:
		return null

	func _hub_points_remaining() -> int:
		return 0
