extends SceneTree

const PauseMenuLayoutScript = preload("res://scripts/pause_menu_layout.gd")

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for pause menu coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(screens != null and profile != null, "pause menu owners are composed", failures)
	if screens != null and profile != null:
		var starting_gold := profile.gold
		var starting_runs := profile.completed_runs
		gameplay.call("_open_pause_menu")
		await process_frame
		_expect(screens.pause_overlay != null and screens.pause_overlay.visible and not screens.hub_overlay.visible and screens.hub_pause_mode, "pause opens its own overlay", failures)
		_expect(screens.state == &"pause", "pause owns a distinct screen state", failures)
		var pause_frame := screens.pause_overlay.get_node_or_null("FrameOuter") as Panel
		var pause_inner_frame := screens.pause_overlay.get_node_or_null("FrameInner") as Panel
		var pause_divider := screens.pause_overlay.get_node_or_null("CommandDivider") as ColorRect
		var pause_resource_divider := screens.pause_overlay.get_node_or_null("ResourceDivider") as ColorRect
		var pause_panel := screens.pause_overlay.get_node_or_null("PausePanel8Piece") as Control
		var pause_left_panel := screens.pause_overlay.get_node_or_null("PausePanel8Piece/LeftPanel") as NinePatchRect
		var pause_right_panel := screens.pause_overlay.get_node_or_null("PausePanel8Piece/RightPanel") as NinePatchRect
		var pause_gold_souls_panel := screens.pause_overlay.get_node_or_null("PausePanel8Piece/GoldSoulsPanel") as NinePatchRect
		var pause_gold_icon := screens.pause_overlay.get_node_or_null("PauseGoldIcon") as Sprite2D
		var pause_soul_icon := screens.pause_overlay.get_node_or_null("PauseResourceIcon") as Sprite2D
		var pause_gold_text := screens.pause_overlay.get_node_or_null("PauseGoldText") as Sprite2D
		var pause_soul_text := screens.pause_overlay.get_node_or_null("PauseSoulText") as Sprite2D
		_expect(pause_frame != null and pause_inner_frame != null and pause_divider != null and pause_resource_divider != null and pause_panel != null, "pause scene owns its frame and rail geometry", failures)
		_expect(pause_left_panel != null and pause_right_panel != null and pause_gold_souls_panel != null and pause_left_panel.texture != null and pause_right_panel.texture != null and pause_gold_souls_panel.texture != null, "pause uses the three authored panel layers", failures)
		_expect(pause_gold_icon != null and pause_gold_icon.texture != null and pause_gold_icon.region_enabled and pause_soul_icon != null and pause_soul_icon.texture != null, "pause shows separate gold and soul icons", failures)
		_expect(pause_gold_text != null and pause_soul_text != null and pause_gold_text.texture != null and pause_soul_text.texture != null, "pause shows both resource counts", failures)
		_expect(pause_frame != null and pause_frame.size == screens.display_view_size and pause_divider != null and pause_divider.position.x == screens.display_view_size.x - 65.0, "pause frame follows the logical viewport with a fixed command rail", failures)
		if pause_left_panel != null and pause_right_panel != null and pause_gold_souls_panel != null and pause_gold_icon != null and pause_soul_icon != null:
			var expected_divider_x := maxf(screens.display_view_size.x - 64.0, 176.0)
			_expect(pause_left_panel.position == Vector2.ZERO and pause_left_panel.size == Vector2(expected_divider_x, screens.display_view_size.y), "pause left panel keeps authored origin and expands from the divider", failures)
			_expect(pause_right_panel.position == Vector2(expected_divider_x, 0.0) and pause_right_panel.size == Vector2(maxf(screens.display_view_size.x - expected_divider_x, 1.0), maxf(screens.display_view_size.y - 24.0, 1.0)), "pause right panel stays anchored to the fixed rail", failures)
			_expect(pause_gold_souls_panel.position == Vector2(expected_divider_x, maxf(screens.display_view_size.y - 24.0, 0.0)) and pause_gold_souls_panel.size == Vector2(maxf(screens.display_view_size.x - expected_divider_x, 1.0), 24.0), "pause resource panel stays in the rail footer", failures)
			_expect(pause_gold_icon.position == Vector2(expected_divider_x + 6.0, screens.display_view_size.y - 18.0) and pause_soul_icon.position == Vector2(expected_divider_x + 6.0, screens.display_view_size.y - 11.0), "pause resource icons use the authored three-pixel inner margin", failures)
			if pause_gold_text != null and pause_soul_text != null and pause_gold_text.texture != null and pause_soul_text.texture != null:
				_expect(pause_gold_text.position == Vector2(screens.display_view_size.x - pause_gold_text.texture.get_width() - 6.0, screens.display_view_size.y - 18.0) and pause_soul_text.position == Vector2(screens.display_view_size.x - pause_soul_text.texture.get_width() - 6.0, screens.display_view_size.y - 11.0), "pause resource counts use the authored right margin", failures)
		_expect(screens.pause_menu_buttons.size() == 4, "pause exposes Status, Equipment, Settings, and Quit to Title", failures)
		if screens.pause_menu_buttons.size() >= 4:
			_expect(screens.pause_menu_buttons[0].position == Vector2(maxf(screens.display_view_size.x - 59.0, 181.0), 7.0) and screens.pause_menu_buttons[3].position.y == 49.0, "pause command rail uses the authored x and y positions", failures)
		_expect(screens.pause_back_button != null and screens.pause_back_button.position == PauseMenuLayoutScript.back_button_position(screens.display_view_size), "pause back prompt uses the authored rail-anchored footer row", failures)
		# The native card remains the visual reference, while a wider logical
		# surface spreads authored left-field groups toward (but never through) the
		# fixed command rail. Restore the native size immediately so the remaining
		# route assertions continue against the approved mockup geometry.
		var native_pause_size := screens.display_view_size
		var wide_pause_size := Vector2(284.0, native_pause_size.y)
		screens.display_view_size = wide_pause_size
		screens.call("_position_pause_controls")
		var expected_wide_portrait_x := PauseMenuLayoutScript.left_field_x(PauseMenuLayoutScript.PLAYER_PORTRAIT_POSITION.x, wide_pause_size.x)
		var expected_wide_card_x := PauseMenuLayoutScript.left_field_x(PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[6].x, wide_pause_size.x)
		_expect(screens.pause_player_portrait.position.x == expected_wide_portrait_x and screens.pause_player_card_texts[6].position.x == expected_wide_card_x and screens.pause_menu_buttons[0].position == PauseMenuLayoutScript.command_button_position(wide_pause_size, 0), "pause spreads player groups while keeping the command rail edge-anchored on wide layouts", failures)
		screens.display_view_size = native_pause_size
		screens.call("_position_pause_controls")
		for button in screens.pause_menu_buttons:
			_expect(button.visible, "pause menu action is visible", failures)
		_expect(screens.pause_player_card_texts.size() >= 7 and screens.pause_player_card_texts[0].texture != null and screens.pause_player_card_texts[6].texture != null and screens.pause_player_card_texts[6].visible, "pause shows the player info block and level", failures)
		if screens.pause_player_card_texts.size() >= 7:
			_expect(screens.pause_player_card_texts[0].position == Vector2(43.0, 29.0) and screens.pause_player_card_texts[1].position == Vector2(88.0, 29.0) and screens.pause_player_card_texts[2].position == Vector2(88.0, 37.0) and screens.pause_player_card_texts[6].position == Vector2(138.0, 29.0), "pause player card uses the authored three-column top row", failures)
		var pause_portrait := screens.pause_overlay.get_node_or_null("PauseRootPage/PausePlayerPortrait") as Sprite2D
		_expect(pause_portrait != null and pause_portrait.texture != null, "pause shows the palette-aware player portrait", failures)
		_expect(screens.pause_cursor_text != null and screens.pause_cursor_text.z_index >= 4095 and screens.pause_cursor_text.has_method("move_to"), "pause cursor owns top draw order and unified motion", failures)
		_expect(screens.pause_status_texts.size() >= 16 and screens.pause_equipment_texts.size() >= 4, "pause owns read-only status and equipment pages", failures)
		if screens.pause_status_button != null:
			screens.pause_status_button.pressed.emit()
		var status_background := screens.pause_page_roots[1].get_node_or_null("Background") as NinePatchRect
		var status_title := screens.pause_page_roots[1].get_node_or_null("Title") as Sprite2D
		_expect(screens.pause_page == 1 and screens.pause_status_texts[0].visible and not screens.hub_overlay.visible, "pause Status opens a read-only page without hub controls", failures)
		_expect(status_background != null and status_background.size == screens.display_view_size and status_title != null and status_title.texture != null, "pause Status owns a full-screen background and upper-left title card", failures)
		if screens.pause_equipment_button != null:
			screens.pause_equipment_button.pressed.emit()
		var equipment_background := screens.pause_page_roots[2].get_node_or_null("Background") as NinePatchRect
		var equipment_title := screens.pause_page_roots[2].get_node_or_null("Title") as Sprite2D
		var authored_equipment := screens.pause_equipment_menu as EquipmentMenuLayout
		_expect(screens.pause_page == 2 and authored_equipment != null and authored_equipment.visible and not authored_equipment.read_only, "pause Equipment opens the shared interactive authored page", failures)
		_expect(equipment_background != null and equipment_background.size == screens.display_view_size and equipment_title != null and equipment_title.texture != null, "pause Equipment owns a full-screen background and upper-left title card", failures)
		if authored_equipment != null and not authored_equipment.command_buttons.is_empty():
			authored_equipment.command_buttons[0].pressed.emit()
			await process_frame
			_expect(screens.hub_equipment_mode == EquipmentMenuLayout.MODE_SLOT_EQUIP and authored_equipment.slot_cursor.visible, "pause Equipment command buttons enter the live slot flow", failures)
			if not authored_equipment.slot_buttons.is_empty():
				authored_equipment.slot_buttons[0].pressed.emit()
				await process_frame
				var pause_input_tracker := gameplay.get("input_device_tracker") as InputDeviceTracker
				var pause_equipped_before_touch := profile.get_equipped_instance_id(&"weapon")
				if pause_input_tracker != null: pause_input_tracker.set_device(InputDeviceTracker.Device.TOUCH)
				gameplay.call("_select_hub_gear_candidate", 0)
				await process_frame
				_expect(profile.get_equipped_instance_id(&"weapon") == pause_equipped_before_touch and screens.hub_touch_candidate_index == 0, "pause Equipment first touch previews a candidate without committing", failures)
				gameplay.call("_select_hub_gear_candidate", 0)
				await process_frame
				_expect(screens.hub_touch_candidate_index == -1, "pause Equipment second touch commits and clears the preview arm", failures)
				if pause_input_tracker != null: pause_input_tracker.set_device(InputDeviceTracker.Device.KEYBOARD_MOUSE)
		if screens.pause_back_button != null:
			screens.pause_back_button.pressed.emit()
			screens.pause_back_button.pressed.emit()
		await process_frame
		_expect(not screens.pause_overlay.visible and not screens.hub_overlay.visible and not screens.hub_pause_mode, "BACK from the pause root returns to gameplay", failures)
		_expect(screens.state == &"gameplay", "pause cancellation restores gameplay state", failures)
		gameplay.call("_open_pause_menu")
		await process_frame
		var pause_quit := screens.pause_quit_button
		_expect(pause_quit != null and not pause_quit.disabled, "Quit to Title is available from pause", failures)
		if pause_quit != null:
			pause_quit.pressed.emit()
		_expect(not screens.pause_overlay.visible and not screens.hub_overlay.visible, "Quit to Title closes the pause overlay", failures)
		_expect(bool(gameplay.get("scene_transition_active")), "Quit to Title reuses the scene teardown transition", failures)
		_expect(profile.gold == starting_gold and profile.completed_runs == starting_runs, "Quit to Title leaves settled profile progress intact", failures)
		_expect(profile.pending_route == "title", "Quit to Title records the title route", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: pause menu scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("PAUSE_MENU_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
