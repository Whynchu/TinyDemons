extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for six-stat menu coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(screens != null and profile != null, "six-stat menu owners are composed", failures)
	if screens != null and profile != null:
		profile.unspent_stat_points = 2
		gameplay.call("_show_hub", true, false)
		await process_frame
		_expect(screens.hub_overlay.visible and not screens.pause_overlay.visible and screens.state == &"hub", "Cloaked Demon opens the preparation hub", failures)
		_expect(screens.hub_page_buttons.size() == 6 and screens.hub_page_buttons[0].name == "HubCommandStatus" and screens.hub_page_buttons[1].name == "HubCommandAllocate" and screens.hub_page_buttons[2].name == "HubCommandEquipment" and screens.hub_page_buttons[3].name == "HubCommandShop" and screens.hub_page_buttons[4].name == "HubCommandFusion" and screens.hub_page_buttons[5].name == "HubCommandBind", "hub exposes the approved six-command order", failures)
		_expect(screens.hub_start_button == null, "Demon Hub has no Start Run control", failures)
		_expect(screens.hub_overlay.get_node_or_null("FrameOuter") != null and screens.hub_overlay.get_node_or_null("FrameInner") != null, "hub uses the double-border menu frame", failures)

		screens.hub_page_buttons[0].pressed.emit()
		await process_frame
		_expect(screens.hub_page == screens.HUB_PAGE_STATUS and screens.hub_status_texts.size() == 14 and screens.hub_status_texts[0].visible and screens.hub_status_texts[0].texture != null, "Status is read-only and shows the six-stat/derived block", failures)
		_expect(not screens.hub_stat_buttons[0].visible and not screens.hub_apply_button.visible, "Status does not expose allocation controls", failures)

		screens.hub_page_buttons[1].pressed.emit()
		await process_frame
		_expect(screens.hub_page == screens.HUB_PAGE_ALLOCATE and screens.hub_stat_texts.size() == 6 and screens.hub_stat_buttons.size() == 12 and screens.hub_stat_row_buttons.size() == 6, "Allocate exposes six rows, twelve arrows, and full-row targets", failures)
		_expect(screens.hub_stat_left_buttons.all(func(button: Button) -> bool: return is_equal_approx(button.size.y, 12.0)) and screens.hub_stat_row_buttons.all(func(button: Button) -> bool: return is_equal_approx(button.size.y, 12.0)), "Allocate keeps each arrow and row target inside its stat lane", failures)
		screens.hub_stat_row_buttons[4].pressed.emit()
		screens.hub_stat_right_buttons[4].pressed.emit()
		_expect(screens.hub_stat_row == 4 and screens.hub_pending_int == 1 and screens.hub_pending_vit == 0 and screens.hub_pending_mnd == 0, "Allocate routes an INT row adjustment through the pending transaction", failures)
		screens.hub_stat_row_buttons[5].pressed.emit()
		screens.hub_stat_right_buttons[5].pressed.emit()
		_expect(screens.hub_pending_mnd == 1 and gameplay.call("_hub_points_remaining") == 0, "Allocate routes an MND row adjustment without losing point accounting", failures)
		gameplay.call("_hub_cancel_stats")

		screens.hub_page_buttons[2].pressed.emit()
		await process_frame
		_expect(screens.hub_page == screens.HUB_PAGE_EQUIPMENT and screens.hub_equipment_action_buttons.size() == 3 and screens.hub_equipment_action_buttons.all(func(button: Button) -> bool: return button.visible), "Equipment exposes its top Equip/Remove/Remove All action row", failures)
		_expect(screens.hub_gear_slot_buttons.size() == 4 and screens.hub_gear_stat_texts.size() == 6, "Equipment keeps four Tiny Demons slots and six-stat comparison capacity", failures)
		var item_column_end := screens.hub_item_content_clip.position.x + screens.hub_item_content_clip.size.x if screens.hub_item_content_clip != null else -1.0
		var stat_column_start := screens.hub_gear_stat_panel.position.x if screens.hub_gear_stat_panel != null else -1.0
		_expect(screens.hub_item_content_clip != null and screens.hub_item_content_clip.clip_contents and item_column_end <= stat_column_start - 10.0, "equipment item text is clipped before the stat-card gutter", failures)
		var equipment_card_end := screens.hub_item_list_panel.position.x + screens.hub_item_list_panel.size.x if screens.hub_item_list_panel != null else -1.0
		_expect(equipment_card_end >= screens.display_view_size.x - 14.0 and screens.hub_gear_stat_panel != null and not screens.hub_gear_stat_panel.visible, "equipment uses one full-width upper card for slots and stat preview", failures)
		_expect(screens.hub_equipment_action_buttons[0].position.x + screens.hub_equipment_action_buttons[0].size.x <= screens.hub_equipment_action_buttons[1].position.x and screens.hub_equipment_action_buttons[1].position.x + screens.hub_equipment_action_buttons[1].size.x <= screens.hub_equipment_action_buttons[2].position.x, "equipment action buttons keep non-overlapping hit regions", failures)
		_expect(screens.hub_gear_choice_panel != null and screens.hub_gear_choice_content_clip != null and not screens.hub_gear_choice_panel.visible, "equipment keeps the lower slot-picker closed until a slot is selected", failures)
		profile.ensure_starter_items()
		screens.hub_gear_slot_buttons[0].pressed.emit()
		await process_frame
		var top_slot_bottom := screens.hub_item_content_clip.position.y + screens.hub_gear_slot_buttons[0].position.y + screens.hub_gear_slot_buttons[0].size.y
		var choice_window_top := screens.hub_gear_choice_panel.position.y if screens.hub_gear_choice_panel != null else -1.0
		_expect(screens.hub_gear_browsing and screens.hub_gear_choice_panel.visible and screens.hub_gear_choice_content_clip.visible and screens.hub_gear_choice_texts[0].texture != null, "equipment opens a populated lower window for the selected slot", failures)
		_expect(screens.hub_item_list_texts[0].visible and choice_window_top >= top_slot_bottom, "equipment keeps equipped slots visible above the separate candidate window", failures)
		_expect(screens.hub_gear_choice_buttons[0].visible and screens.hub_equipment_action_buttons.all(func(button: Button) -> bool: return button.mouse_filter == Control.MOUSE_FILTER_IGNORE), "equipment limits touch input to the active picker while browsing", failures)
		gameplay.call("_close_hub_gear_browse")
		await process_frame
		screens.hub_page_buttons[3].pressed.emit()
		_expect(screens.hub_page == screens.HUB_PAGE_SHOP and screens.hub_shop_price_texts.size() == 5, "Shop remains a transaction page inside the shell", failures)
		screens.hub_page_buttons[4].pressed.emit()
		_expect(screens.hub_page == screens.HUB_PAGE_FUSION and screens.hub_fusion_decrease_button.visible and screens.hub_fusion_increase_button.visible, "Fusion remains a transaction page inside the shell", failures)
		screens.hub_page_buttons[5].pressed.emit()
		_expect(screens.hub_page == screens.HUB_PAGE_BIND and screens.hub_binding_panel.visible and screens.hub_binding_action_button.visible, "Bind remains the persistent Cloaked Demon action", failures)
		gameplay.call("_close_hub_to_run")
		_expect(not screens.hub_overlay.visible and not screens.pause_overlay.visible and screens.state == &"gameplay", "hub BACK returns to the world", failures)
	gameplay.queue_free()
	await process_frame
	_finished = true
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: six-stat menu scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("SIX_STAT_MENU_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
