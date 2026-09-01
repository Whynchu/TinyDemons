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
		_expect(screens.hub_overlay.get_node_or_null("HubPanel8Piece") != null and screens.hub_overlay.get_node_or_null("FrameOuter") != null and screens.hub_overlay.get_node_or_null("FrameInner") != null, "hub uses the scene-authored eight-piece menu frame", failures)

		screens.hub_page_buttons[0].pressed.emit()
		await process_frame
		_expect(screens.hub_page == screens.HUB_PAGE_STATUS and screens.hub_status_texts.size() == 16 and screens.hub_status_texts[0].visible and screens.hub_status_texts[0].texture != null, "Status is read-only and shows level, XP, and the six-stat/derived block", failures)
		_expect(not screens.hub_stat_buttons[0].visible and not screens.hub_apply_button.visible, "Status does not expose allocation controls", failures)

		screens.hub_page_buttons[1].pressed.emit()
		await process_frame
		_expect(screens.hub_page == screens.HUB_PAGE_ALLOCATE and screens.hub_stat_texts.size() == 6 and screens.hub_stat_buttons.size() == 12 and screens.hub_stat_row_buttons.size() == 6, "Allocate exposes six rows, twelve arrows, and full-row targets", failures)
		_expect(screens.hub_allocate_panel != null and screens.hub_allocate_panel.visible, "Allocate groups its adjustable rows inside a dedicated card", failures)
		_expect(screens.hub_allocate_preview_panel != null and screens.hub_allocate_preview_panel.visible and screens.hub_allocate_preview_texts.size() == 7 and screens.hub_allocate_preview_texts.all(func(text: Sprite2D) -> bool: return text.texture != null), "Allocate shows the seven effective combat previews in a separate right card", failures)
		_expect(screens.hub_stat_left_buttons.all(func(button: Button) -> bool: return is_equal_approx(button.size.y, 12.0)) and screens.hub_stat_row_buttons.all(func(button: Button) -> bool: return is_equal_approx(button.size.y, 12.0)), "Allocate keeps each arrow and row target inside its stat lane", failures)
		_expect(screens.hub_stat_right_buttons.all(func(button: Button) -> bool: return button.position.x < screens.hub_allocate_preview_panel.position.x), "Allocate keeps adjustment arrows inside the left stat card", failures)
		screens.hub_stat_row_buttons[4].pressed.emit()
		screens.hub_stat_right_buttons[4].pressed.emit()
		_expect(screens.hub_stat_row == 4 and screens.hub_pending_int == 1 and screens.hub_pending_vit == 0 and screens.hub_pending_mnd == 0, "Allocate routes an INT row adjustment through the pending transaction", failures)
		screens.hub_stat_row_buttons[5].pressed.emit()
		screens.hub_stat_right_buttons[5].pressed.emit()
		_expect(screens.hub_pending_mnd == 1 and gameplay.call("_hub_points_remaining") == 0, "Allocate routes an MND row adjustment without losing point accounting", failures)
		gameplay.call("_hub_cancel_stats")

		screens.hub_page_buttons[2].pressed.emit()
		await process_frame
		var equipment_view := screens.hub_equipment_menu as EquipmentMenuLayout
		_expect(screens.hub_page == screens.HUB_PAGE_EQUIPMENT and equipment_view != null and equipment_view.visible and equipment_view.command_buttons.size() == 3, "Equipment exposes its authored Equip/Remove/Remove All action row", failures)
		_expect(screens.hub_equipment_action_buttons.size() == 3 and screens.hub_equipment_action_buttons.all(func(button: Button) -> bool: return not button.visible), "Equipment keeps the legacy action row out of the authored presentation", failures)
		_expect(screens.hub_equipment_action_focus and screens.hub_item_name_text != null and not screens.hub_item_name_text.visible, "Equipment enters on its command row without a colliding slot header", failures)
		_expect(screens.hub_gear_slot_buttons.size() == 6 and screens.hub_gear_stat_texts.size() == 6, "Equipment exposes the six approved slots and six-stat comparison capacity", failures)
		_expect(screens.hub_item_action_button != null and not screens.hub_item_action_button.visible, "Equipment does not expose a duplicate lower action button", failures)
		var item_column_end := screens.hub_item_content_clip.position.x + screens.hub_item_content_clip.size.x if screens.hub_item_content_clip != null else -1.0
		var stat_column_start := screens.hub_gear_stat_panel.position.x if screens.hub_gear_stat_panel != null else -1.0
		_expect(screens.hub_item_content_clip != null and screens.hub_item_content_clip.clip_contents and item_column_end <= stat_column_start - 10.0, "equipment item text is clipped before the stat-card gutter", failures)
		var equipment_card_end := screens.hub_item_list_panel.position.x + screens.hub_item_list_panel.size.x if screens.hub_item_list_panel != null else -1.0
		_expect(equipment_card_end <= stat_column_start - 10.0 and screens.hub_gear_stat_panel != null and not screens.hub_gear_stat_panel.visible, "equipment keeps inactive content hidden while the command row is active", failures)
		_expect(screens.hub_equipment_action_buttons[0].position.x + screens.hub_equipment_action_buttons[0].size.x <= screens.hub_equipment_action_buttons[1].position.x and screens.hub_equipment_action_buttons[1].position.x + screens.hub_equipment_action_buttons[1].size.x <= screens.hub_equipment_action_buttons[2].position.x, "equipment action buttons keep non-overlapping hit regions", failures)
		_expect(screens.hub_gear_choice_panel != null and screens.hub_gear_choice_content_clip != null and not screens.hub_gear_choice_panel.visible, "equipment keeps the lower slot-picker closed until a slot is selected", failures)
		_expect(screens.hub_gear_slot_buttons.all(func(button: Button) -> bool: return not button.visible and button.mouse_filter == Control.MOUSE_FILTER_IGNORE), "equipment command row disables slot hit targets", failures)
		profile.ensure_starter_items()
		screens.hub_item_index = 3
		screens.hub_gear_browsing = false
		var input_router := gameplay.get("input_router") as InputRouter
		# Confirm EQUIP enters the six-slot parent menu first.
		input_router.poll(InputRouter.Context.HUB)
		Input.action_press("interact")
		input_router.poll(InputRouter.Context.HUB)
		screens.update_hub_input(gameplay)
		Input.action_release("interact")
		input_router.poll(InputRouter.Context.HUB)
		await process_frame
		_expect(screens.hub_item_index == 3 and not screens.hub_equipment_action_focus and not screens.hub_gear_browsing and equipment_view.slot_cursor.visible and screens.hub_item_list_texts[3] != null and not screens.hub_item_list_texts[3].visible and screens.hub_equipment_action_buttons.all(func(button: Button) -> bool: return not button.visible), "controller confirm on EQUIP enters the slot menu", failures)
		# Directional Down on the command row must not descend; only a second
		# confirm opens the selected slot's candidate menu.
		screens.hub_equipment_action_focus = true
		screens.hub_equipment_mode = EquipmentMenuLayout.MODE_COMMAND
		screens.hub_gear_browsing = false
		screens.update_hub_ui(gameplay, Callable(gameplay, "_pixel_text_texture"))
		_set_menu_direction_edge(input_router, &"ui_down")
		screens.update_hub_input(gameplay)
		_expect(screens.hub_equipment_action_focus and screens.hub_equipment_mode == EquipmentMenuLayout.MODE_COMMAND and not screens.hub_gear_browsing, "controller Down stays on the Equipment command row", failures)
		# Restore the selected ARM slot route, then a confirm enters the item menu.
		screens.hub_equipment_action_focus = false
		screens.hub_equipment_mode = EquipmentMenuLayout.MODE_SLOT_EQUIP
		screens.hub_gear_browsing = false
		screens.update_hub_ui(gameplay, Callable(gameplay, "_pixel_text_texture"))
		_set_menu_edge(input_router, true, false)
		screens.update_hub_input(gameplay)
		_set_menu_edge(input_router, false, false)
		await process_frame
		_expect(screens.hub_item_index == 3 and screens.hub_gear_browsing and equipment_view.candidate_cursor.visible and equipment_view.candidate_buttons[0].visible and screens.hub_gear_choice_panel != null and not screens.hub_gear_choice_panel.visible, "controller confirm on ARM opens the equipment item picker", failures)
		_expect(screens.hub_gear_slot_buttons.all(func(button: Button) -> bool: return not button.visible and button.mouse_filter == Control.MOUSE_FILTER_IGNORE) and screens.hub_equipment_action_buttons.all(func(button: Button) -> bool: return not button.visible), "equipment item picker keeps only its authored candidate rows interactive", failures)
		screens.hub_gear_candidate_indices["arm"] = 0
		screens.update_hub_ui(gameplay, Callable(gameplay, "_pixel_text_texture"))
		gameplay.call("_hub_item_action")
		await process_frame
		_expect(not screens.hub_gear_browsing and not screens.hub_equipment_action_focus and profile.get_equipped_instance_id(&"arm") == "starter-arm", "equipment picker confirm equips the selected Arm candidate and returns to slots", failures)
		gameplay.call("_close_hub_gear_browse")
		await process_frame
		equipment_view.slot_buttons[0].pressed.emit()
		await process_frame
		var top_slot_bottom := screens.hub_item_content_clip.position.y + screens.hub_gear_slot_buttons[0].position.y + screens.hub_gear_slot_buttons[0].size.y
		var choice_window_top := screens.hub_gear_choice_panel.position.y if screens.hub_gear_choice_panel != null else -1.0
		_expect(screens.hub_gear_browsing and equipment_view.candidate_cursor.visible and equipment_view.get_node("CandidateText0").texture != null and screens.hub_gear_choice_panel != null and not screens.hub_gear_choice_panel.visible, "equipment opens a populated authored candidate grid for the selected slot", failures)
		_expect(not screens.hub_item_list_texts[0].visible and choice_window_top >= top_slot_bottom, "equipment keeps the hidden legacy slot presenter out of the authored candidate window", failures)
		_expect(equipment_view.candidate_buttons[0].visible and screens.hub_equipment_action_buttons.all(func(button: Button) -> bool: return button.mouse_filter == Control.MOUSE_FILTER_IGNORE), "equipment limits touch input to the authored picker while browsing", failures)
		equipment_view.navigation_back_button.pressed.emit()
		await process_frame
		_expect(not screens.hub_gear_browsing and not screens.hub_equipment_action_focus, "native BACK from the item picker returns to the slot list", failures)
		# Back follows the same hierarchy in reverse: slots -> command row -> hub.
		_set_menu_edge(input_router, false, true)
		screens.update_hub_input(gameplay)
		_expect(screens.hub_equipment_action_focus and equipment_view.command_cursor.visible and screens.hub_equipment_action_buttons.all(func(button: Button) -> bool: return not button.visible), "equipment BACK from slots returns to the authored command row", failures)
		_set_menu_edge(input_router, false, true)
		screens.update_hub_input(gameplay)
		_expect(screens.hub_is_root and screens.hub_overlay.get_node_or_null("HubRootPage").visible, "equipment BACK from the command row returns to Demon Hub", failures)
		screens.hub_page_buttons[3].pressed.emit()
		_expect(screens.hub_page == screens.HUB_PAGE_SHOP and screens.hub_shop_price_texts.size() == 6 and screens.hub_equipment_menu != null and not screens.hub_equipment_menu.visible, "Shop remains a six-slot transaction page inside the shell", failures)
		_expect(screens.hub_item_row_buttons.all(func(button: Button) -> bool: return button.mouse_filter == Control.MOUSE_FILTER_STOP), "Shop restores its shared item-row touch targets after Equipment", failures)
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


func _set_menu_edge(router: InputRouter, confirm: bool, back: bool) -> void:
	router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
	router.set("_current", {&"menu_confirm": confirm, &"menu_back": back})
	router.set("_previous_menu_directions", {})
	router.set("_menu_directions", {})


func _set_menu_direction_edge(router: InputRouter, direction: StringName) -> void:
	router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
	router.set("_current", {&"menu_confirm": false, &"menu_back": false})
	router.set("_previous_menu_directions", {})
	router.set("_menu_directions", {direction: true})
