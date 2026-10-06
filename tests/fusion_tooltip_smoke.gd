extends SceneTree

const HubEconomyControllerScript = preload("res://scripts/runtime/controllers/hub_economy_controller.gd")
const EquipmentMenuLayoutScript = preload("res://scripts/ui/equipment_menu_layout.gd")
const ShopMenuLayoutScript = preload("res://scripts/ui/shop_menu_layout.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var root := _MockRoot.new() as _MockRoot
	var controller_instance := ScreenStateController.new() as ScreenStateController
	var hub_flow_controller := HubFlowController.new() as HubFlowController
	var host := Node.new()
	host.add_child(controller_instance)
	root.screen_state_controller = controller_instance
	root.hub_flow_controller = hub_flow_controller
	var pixel: Callable = Callable(root, "_pixel_text_texture")
	var actions := HubScreenActions.new() as HubScreenActions
	actions.adjust_stat = Callable(root, "_adj")
	actions.apply_stats = Callable(root, "_apply")
	actions.cancel_stats = Callable(root, "_cancel")
	actions.auto_allocate = Callable(root, "_auto")
	actions.respec = Callable(root, "_respec")
	actions.set_page = Callable(root, "_set_page")
	actions.item_action = Callable(root, "_item_action")
	actions.select_gear_slot = Callable(root, "_select_gear_slot")
	actions.bind_element = Callable(root, "_bind_element")
	actions.select_gear_candidate = Callable(root, "_select_gear_candidate")
	actions.select_stat_row = Callable(root, "_select_stat_row")
	actions.select_item_row = Callable(root, "_select_item_row")
	actions.adjust_fusion_count = Callable(root, "_shift_fusion_count")
	actions.equipment_remove = Callable(root, "_item_action")
	actions.equipment_remove_all = Callable(root, "_item_action")
	actions.equipment_remove_all_cancel = Callable(root, "_back")
	actions.hub_back = Callable(root, "_back")
	actions.shop_mode = Callable(root, "_shop_mode")
	actions.shop_amount = Callable(root, "_shop_amount")
	actions.shop_amount_cancel = Callable(root, "_back")
	actions.shop_back = Callable(root, "_back")
	controller_instance.build_hub(host, pixel, actions)
	var stat_buttons := controller_instance.hub_stat_buttons
	var stat_texts := controller_instance.hub_stat_texts
	var equipment_view := controller_instance.hub_equipment_menu as EquipmentMenuLayout
	var shop_view := controller_instance.hub_shop_menu as ShopMenuLayout
	var fusion_view := controller_instance.hub_fusion_menu as FusionMenuLayout
	_expect(stat_buttons.size() == 12 and stat_buttons.all(func(button: Button) -> bool: return button.size.x >= 18.0 and button.size.y >= 12.0), "hub stat arrows expose touch-sized hit targets for six stats", failures)
	_expect(controller_instance.hub_stat_row_buttons.size() == 6 and controller_instance.hub_item_row_buttons.size() == 6, "hub stats, shop, and fusion expose row touch targets", failures)
	_expect(controller_instance.hub_fusion_decrease_button.size.x >= 20.0 and controller_instance.hub_fusion_increase_button.size.x >= 20.0, "fusion exposes direct count controls", failures)
	_expect(stat_texts.size() == 6 and controller_instance.hub_stat_value_texts.size() == 6 and stat_texts.all(func(text: Sprite2D) -> bool: return not text.centered) and controller_instance.hub_stat_value_texts.all(func(text: Sprite2D) -> bool: return not text.centered), "hub stats keep separate left labels and right-anchored value sprites", failures)
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
	duplicate.definition_id = &"soldier_weapon"
	duplicate.rarity = &"rare"
	profile.grant_item(duplicate)
	var duplicate2 := ItemInstance.new()
	duplicate2.instance_id = "dupe-weapon-2"
	duplicate2.definition_id = &"soldier_weapon"
	duplicate2.rarity = &"rare"
	profile.grant_item(duplicate2)
	root.player_profile = profile
	root.progression_tuning = ProgressionTuning.new()
	root.run_state = RunState.new()
	controller_instance.hub_page = 0
	controller_instance.update_hub_ui(root, pixel)
	_expect(controller_instance.hub_derived_texts.size() == 7 and controller_instance.hub_derived_texts.all(func(text: Sprite2D) -> bool: return text.visible), "stats preview exposes the seven authored derived-stat labels", failures)
	var details := controller_instance.hub_item_detail_texts as Array[Sprite2D]
	controller_instance.hub_page = 1
	controller_instance.hub_is_root = false
	controller_instance.hub_content_focus = true
	controller_instance.hub_equipment_mode = EquipmentMenuLayoutScript.MODE_CANDIDATE
	controller_instance.hub_gear_browsing = true
	controller_instance.hub_item_index = 0
	controller_instance.update_hub_ui(root, pixel)
	_expect(equipment_view != null and equipment_view.visible and (equipment_view.get_node("VitText") as Sprite2D).texture != null and (equipment_view.get_node("MndText") as Sprite2D).texture != null, "gear browse keeps one authored six-stat summary without a duplicate SPD row", failures)
	_expect(equipment_view.candidate_buttons.size() == 8 and equipment_view.candidate_buttons.all(func(b: Button) -> bool: return b.mouse_filter != Control.MOUSE_FILTER_IGNORE), "gear browse exposes authored touch candidate rows", failures)
	_expect(equipment_view.candidate_buttons[0].visible and equipment_view.candidate_buttons[1].visible, "gear browse shows touch targets for visible candidates", failures)
	_expect(equipment_view.candidate_buttons[0].size.y >= 14.0 and equipment_view.candidate_buttons[2].position.y - equipment_view.candidate_buttons[0].position.y == 9.0, "equipment candidate touch targets expand across row spacing while visuals keep their compact pitch", failures)
	equipment_view.candidate_buttons[0].pressed.emit()
	_expect(root.selected_gear_candidate_row == 0, "gear choice row forwards its selected candidate", failures)
	var gear_flow := HubEconomyControllerScript.new()
	var gear_candidates := gear_flow.hub_gear_candidates(root, &"weapon")
	root.selected_equipped_instance_id = ""
	controller_instance.hub_gear_candidate_indices = {"weapon": 0}
	gear_flow.select_hub_gear_candidate(root, 1)
	_expect(gear_candidates.size() > 1 and root.selected_equipped_instance_id.is_empty() and controller_instance.hub_gear_browsing and controller_instance.hub_gear_candidate_indices["weapon"] == 1, "first touch previews the visible candidate without equipping", failures)
	gear_flow.select_hub_gear_candidate(root, 1)
	_expect(root.selected_equipped_instance_id == gear_candidates[1].instance_id, "second touch on the selected gear row equips that candidate", failures)
	_expect(not controller_instance.hub_gear_browsing, "touch gear selection closes the browse state", failures)
	controller_instance.update_hub_ui(root, pixel)
	_expect(equipment_view.get_node("SummaryPanel").visible and equipment_view.get_node("DescriptionPanel").visible, "equipment keeps its authored summary and description panels after selection", failures)
	_expect((equipment_view.get_node("DescriptionText0") as Sprite2D).texture != null or (equipment_view.get_node("BonusText0") as Sprite2D).texture != null, "equipment exposes the selected item through authored detail rows", failures)
	root._set_page(3)
	controller_instance.hub_page = 3
	controller_instance.hub_is_root = false
	controller_instance.hub_content_focus = true
	controller_instance.hub_item_index = 0
	controller_instance.hub_gear_browsing = false
	profile.equipped_instance_ids["weapon"] = duplicate.instance_id
	controller_instance.update_hub_ui(root, pixel)
	_expect(fusion_view != null and fusion_view.visible, "Fusion route uses its dedicated visible presenter", failures)
	_expect(fusion_view.get_node("ShopListPanel").visible and fusion_view.get_node("ShopStatsPanel").visible, "Fusion keeps Shop's independent body panels", failures)
	_expect((fusion_view.get_node("OwnedText") as Sprite2D).texture != null, "Fusion renders the owned footer", failures)
	_expect((fusion_view.get_node("ListClip/SellRowSoulAmount0") as Sprite2D).texture != null and (fusion_view.get_node("ListClip/SellRowSoulIcon0") as Sprite2D).texture != null, "Fusion renders inline Soul amount and icon", failures)
	var fusion_model := fusion_view.get("_last_fusion_model") as FusionMenuModel
	_expect(fusion_model != null and not fusion_model.rows.is_empty() and str(fusion_model.rows[0].get("label", "")).ends_with(" E"), "Fusion marks the equipped row with an E suffix", failures)
	_expect(not details[0].visible and not controller_instance.hub_item_detail_panel.visible, "legacy item detail presenter stays hidden on FUSE", failures)
	root._set_page(2)
	controller_instance.hub_page = 2
	controller_instance.hub_is_root = false
	controller_instance.hub_shop_state = ShopMenuLayoutScript.ITEM_BROWSE
	controller_instance.hub_shop_command_focus = false
	controller_instance.hub_item_index = 0
	controller_instance.update_hub_ui(root, pixel)
	_expect(shop_view != null and shop_view.visible and (shop_view.get_node("ListClip/ItemText0") as Sprite2D).texture != null and (shop_view.get_node("StatLabel0") as Sprite2D).texture != null, "shop page renders its selected row and six-stat comparison in the authored presenter", failures)
	_expect((shop_view.get_node("ShopListPanel") as Control).visible and (shop_view.get_node("ShopStatsPanel") as Control).visible and (shop_view.get_node("ItemActionButton") as Button).visible, "shop keeps independent body panels and an active item action", failures)
	controller_instance.hub_item_index = 6
	controller_instance.update_hub_ui(root, pixel)
	_expect((shop_view.get_node("ListClip/ItemText6") as Sprite2D).texture != null, "shop keeps a visible selected row at the end of the authored window", failures)
	root._set_page(3)
	controller_instance.hub_page = 3
	controller_instance.hub_item_index = 0
	controller_instance.update_hub_ui(root, pixel)
	_expect(fusion_view.visible and (fusion_view.get_node("StatLabel0") as Sprite2D).texture != null, "Fusion presenter remains authoritative after returning from Shop", failures)
	controller_instance.hub_overlay.free()
	hub_flow_controller.free()
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


class _MockRoot extends GameplayState:
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

	func _bind_element() -> void:
		pass

	func _select_stat_row(row: int) -> void:
		screen_state_controller.hub_stat_row = row

	func _select_item_row(row: int) -> void:
		screen_state_controller.hub_item_index = row

	func _shift_fusion_count(direction: int) -> void:
		hub_fusion_count = maxi(hub_fusion_count + direction, 1)

	func _back() -> void:
		pass

	func _shop_mode(_mode: int) -> void:
		pass

	func _shop_amount(_amount: int) -> void:
		pass

	func _equip_profile_item(instance_id: String) -> bool:
		selected_equipped_instance_id = instance_id
		player_profile.equipped_instance_ids["weapon"] = instance_id
		return true

	func _play_sound(_sound_name: String, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
		pass

	func _health_feedback_color(_palette_name: String) -> Color:
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

	func _player_stat_snapshot() -> CombatStatSnapshot:
		return null

	func _hub_points_remaining() -> int:
		return 0
