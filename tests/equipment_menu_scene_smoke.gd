extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(25.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for equipment presentation coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(screens != null and profile != null, "equipment menu owners are composed", failures)
	if screens != null and profile != null:
		profile.ensure_starter_items()
		gameplay.call("_show_hub", true, false)
		await process_frame
		# Equipment is now a Pause-only route; exercise the shared Hub presenter
		# through its compatibility entry so this test remains focused on the
		# authored equipment interaction itself.
		gameplay.call("_set_hub_page", screens.HUB_PAGE_EQUIPMENT)
		await process_frame
		var view := screens.hub_equipment_menu as EquipmentMenuLayout
		_expect(view != null and view.visible, "hub uses the authored equipment scene", failures)
		if view != null:
			_expect(view.command_buttons.size() == 3 and view.slot_buttons.size() == 6 and view.candidate_buttons.size() == 8, "equipment scene owns one fixed button layer per route", failures)
			_expect(view.command_buttons.all(func(button: Button) -> bool: return button.tooltip_text.is_empty()) and view.navigation_back_button != null and view.navigation_back_button.tooltip_text.is_empty(), "equipment command and navigation controls do not show native tooltips", failures)
			var responsive_size := view.size
			view.size = Vector2(240, 160)
			await process_frame
			var top_panel := view.get_node("TopPanel") as NinePatchRect
			_expect(top_panel != null and top_panel.patch_margin_left == 3 and top_panel.patch_margin_top == 3 and top_panel.patch_margin_right == 3 and top_panel.patch_margin_bottom == 3 and top_panel.position == Vector2(0, 0) and top_panel.size == Vector2(89, 21) and view.get_node("CommandPanel").position == Vector2(90, 0) and view.get_node("CommandPanel").size == Vector2(150, 21) and view.get_node("SummaryPanel").position == Vector2(0, 21) and view.get_node("SummaryPanel").size == Vector2(240, 63) and view.get_node("DescriptionPanel").position == Vector2(0, 84) and view.get_node("DescriptionPanel").size == Vector2(240, 49) and view.get_node("StatPanel").position == Vector2(0, 133) and view.get_node("StatPanel").size == Vector2(159, 26) and view.get_node("NavigationPanel").position == Vector2(161, 133) and view.get_node("NavigationPanel").size == Vector2(79, 26), "equipment panels retain the authored 3px-edge/15px-fill 240x160 mockup proportions", failures)
			view.size = responsive_size
			await process_frame
			view.size = Vector2(284, 160)
			await process_frame
			_expect((view.get_node("CommandPanel") as Control).position.x == 107.0 and view.command_buttons[0].position.x == 108.0 and (view.get_node("SlotIcon3") as Sprite2D).position.x == 176.0 and (view.get_node("NavigationPanel") as Control).position.x == 205.0, "equipment distributes authored groups across the 16:9 logical width", failures)
			view.size = responsive_size
			await process_frame
			_expect(view.navigation_back_button != null and view.navigation_text != null and view.navigation_text.texture != null, "equipment renders the select/back navigation prompt with a touch Back target", failures)
			if view.navigation_text.texture != null:
				var nav_image := view.navigation_text.texture.get_image()
				var has_white_text := false
				var has_old_blue_text := false
				for y in nav_image.get_height():
					for x in nav_image.get_width():
						var pixel := nav_image.get_pixel(x, y)
						if pixel == Color.WHITE: has_white_text = true
						if pixel == Color8(148, 220, 255): has_old_blue_text = true
				_expect(has_white_text and not has_old_blue_text, "equipment navigation SELECT/BACK labels use white pixel text", failures)
			for index in 6:
				var icon := view.get_node("SlotIcon%d" % index) as Sprite2D
				_expect(icon != null and icon.texture != null and icon.texture.get_width() == 5 and icon.texture.get_height() == 5, "equipment slot %d renders its 5x5 icon" % index, failures)
		_expect(screens.hub_equipment_mode == 0 and view.command_cursor.visible, "equipment opens on its command row", failures)
		_expect((view.get_node("DescriptionText0") as Sprite2D).texture == null and (view.get_node("BonusText0") as Sprite2D).texture == null and not (view.get_node("CandidateText0") as Sprite2D).visible, "command row clears item description and final bonus strip before slot selection", failures)
		view.navigation_back_button.pressed.emit()
		await process_frame
		_expect(screens.hub_is_root and not view.visible, "the navigation-cell Back prompt unwinds Equipment through the normal touch route", failures)
		gameplay.call("_set_hub_page", screens.HUB_PAGE_EQUIPMENT)
		await process_frame
		view = screens.hub_equipment_menu as EquipmentMenuLayout

		gameplay.call("_hub_item_action")
		await process_frame
		_expect(screens.hub_equipment_mode == 1 and view.slot_cursor.visible and not view.candidate_cursor.visible, "Equip descends into the slot grid", failures)
		_expect((view.get_node("DescriptionText0") as Sprite2D).texture != null and (view.get_node("BonusText0") as Sprite2D).texture != null, "slot selection restores equipped item description and final bonuses", failures)
		gameplay.call("_select_hub_gear_slot", 0)
		await process_frame
		_expect(screens.hub_equipment_mode == 3 and view.candidate_cursor.visible and view.get_node("CandidateText0").texture != null and (view.get_node("CandidateText0") as Sprite2D).visible and not (view.get_node("DescriptionText0") as Sprite2D).visible, "selecting a populated slot opens the two-column candidate grid", failures)
		_expect((view.get_node("SlotIcon0") as Sprite2D).visible and view.slot_cursor.modulate == EquipmentMenuLayout.DIM_CURSOR_MODULATE, "the six equipped icons persist and the previous cursor dims by fifty percent", failures)
		var input_tracker := gameplay.get("input_device_tracker") as InputDeviceTracker
		var equipped_before_touch := profile.get_equipped_instance_id(&"weapon")
		if input_tracker != null: input_tracker.set_device(InputDeviceTracker.Device.TOUCH)
		gameplay.call("_select_hub_gear_candidate", 0)
		await process_frame
		_expect(profile.get_equipped_instance_id(&"weapon") == equipped_before_touch and screens.hub_touch_candidate_index == 0, "first touch on a candidate previews without committing equipment", failures)
		gameplay.call("_select_hub_gear_candidate", 0)
		await process_frame
		_expect(screens.hub_touch_candidate_index == -1, "second touch on the same candidate commits and clears the touch arm", failures)
		gameplay.call("_close_hub_gear_browse")
		await process_frame

		# REMOVE follows the same slot route, then a second confirm performs the
		# transaction on the selected slot.
		screens.hub_equipment_action_focus = true
		screens.hub_equipment_mode = 0
		screens.hub_action_column = 1
		screens.update_hub_ui(gameplay, Callable(gameplay, "_pixel_text_texture"))
		gameplay.call("_remove_hub_gear")
		await process_frame
		_expect(screens.hub_equipment_mode == 2 and view.slot_cursor.visible, "Remove descends into the slot grid", failures)
		gameplay.call("_remove_hub_gear")
		await process_frame
		_expect(screens.hub_equipment_mode == 2 and profile.get_equipped_instance_id(&"weapon").is_empty(), "a second slot confirm removes the selected equipment", failures)

		# Remove All is modal and has a static dim underlay beneath its active
		# cursor; cancelling leaves the command route intact.
		screens.hub_equipment_action_focus = true
		screens.hub_equipment_mode = 0
		screens.hub_action_column = 2
		screens.update_hub_ui(gameplay, Callable(gameplay, "_pixel_text_texture"))
		gameplay.call("_remove_all_hub_gear")
		await process_frame
		_expect(screens.hub_equipment_mode == 4 and view.confirm_locked_cursor.visible and view.confirm_cursor.visible and view.confirm_locked_cursor.modulate == EquipmentMenuLayout.DIM_CURSOR_MODULATE, "Remove All requires the locked-underlay confirmation", failures)
		gameplay.call("_cancel_hub_remove_all")
		await process_frame
		_expect(screens.hub_equipment_mode == 0 and not view.confirm_cursor.visible, "Back cancels Remove All without changing the loadout route", failures)

		# Confirm is direct once the grey locked cursor is active; there is no
		# visible Yes/No prompt or second navigation mode.
		screens.hub_equipment_action_focus = true
		screens.hub_equipment_mode = 0
		screens.hub_action_column = 2
		screens.update_hub_ui(gameplay, Callable(gameplay, "_pixel_text_texture"))
		gameplay.call("_remove_all_hub_gear")
		await process_frame
		gameplay.call("_remove_all_hub_gear")
		await process_frame
		_expect(screens.hub_equipment_mode == 0 and profile.equipped_instance_ids.values().all(func(id: String) -> bool: return str(id).is_empty()), "Confirm on the Remove All cursor clears every equipped slot", failures)

		gameplay.call("_close_hub_to_run")
		gameplay.call("_open_pause_menu")
		await process_frame
		screens.pause_equipment_button.pressed.emit()
		await process_frame
		var pause_view := screens.pause_equipment_menu as EquipmentMenuLayout
		_expect(screens.pause_page == 2 and pause_view != null and pause_view.visible and not pause_view.read_only, "Pause reuses the shared interactive equipment presentation", failures)
		if pause_view != null:
			_expect((pause_view.get_node("SlotIcon0") as Sprite2D).texture != null and pause_view.navigation_text.texture != null and pause_view.navigation_back_button != null and pause_view.command_cursor.visible, "Pause keeps the six icons, select/back prompt, and live command cursor", failures)
			pause_view.navigation_back_button.pressed.emit()
			await process_frame
			_expect(screens.pause_page == 0, "the shared navigation-cell Back prompt returns Pause to its command page", failures)
		gameplay.call("_close_hub_to_run")
		gameplay.call("_show_hub", true, false)
		await process_frame
		screens.hub_page_buttons[1].pressed.emit()
		await process_frame
		_expect(screens.hub_list_cursor.visible and not screens.hub_slot_cursor.visible and not screens.hub_choice_cursor.visible, "Shop receives a clean list cursor after Equipment", failures)
	gameplay.queue_free()
	await process_frame
	_finished = true
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: equipment menu scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("EQUIPMENT_MENU_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
