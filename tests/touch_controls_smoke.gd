extends SceneTree

var stat_touch_count := 0
var stat_touch_names: Array[StringName] = []
var stat_row_touch_count := 0
var item_row_touch_count := 0
var fusion_count_touch_count := 0
var pause_touch_count := 0


func _initialize() -> void:
	var failures: Array[String] = []
	var layer := TouchControlsLayer.new()
	get_root().add_child(layer)
	layer.build()
	layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	layer.set_input_context(InputRouter.Context.GAMEPLAY)
	_expect(layer.is_active(), "touch controls activate for touch gameplay input", failures)
	var touch_root := layer.get_node("TouchControlsRoot") as Control
	_expect(touch_root != null and touch_root.mouse_filter == Control.MOUSE_FILTER_PASS, "active touch controls remain in the GUI hit-test path", failures)

	layer.set_virtual_stick(Vector2(2.0, 0.25))
	var stick := layer.movement_vector()
	_expect(stick.x > 0.99 and stick.y > 0.12 and stick.y < 0.13, "virtual stick clamps and normalizes its vector", failures)
	layer.set_virtual_stick(Vector2.ZERO)
	_expect(layer.movement_vector() == Vector2.ZERO, "virtual stick release resets movement", failures)

	var router := InputRouter.new()
	get_root().add_child(router)
	for action in [&"attack", &"interact", &"roll", &"magic", &"cancel", &"pause", &"open_minimap", &"target", &"guard", &"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	router.set_touch_provider(layer)
	var minimap_rect: Rect2 = layer._layout["minimap"]
	var minimap_down := InputEventScreenTouch.new()
	minimap_down.device = 0; minimap_down.index = 8; minimap_down.pressed = true; minimap_down.position = minimap_rect.get_center()
	layer._input(minimap_down)
	var minimap_up := InputEventScreenTouch.new()
	minimap_up.device = 0; minimap_up.index = 8; minimap_up.pressed = false; minimap_up.position = minimap_down.position
	layer._input(minimap_up)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.just_pressed(&"open_minimap"), "touch map control reaches the dedicated minimap action", failures)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.just_released(&"open_minimap"), "touch map control releases cleanly", failures)
	layer.set_button_state(&"attack", true)
	layer.set_virtual_stick(Vector2(1.0, 0.0))
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"attack") and router.just_pressed(&"attack"), "touch button reaches router held and edge state", failures)
	_expect(router.movement(0.25).x > 0.9, "touch stick reaches router movement snapshot", failures)
	layer.set_button_state(&"attack", false)
	layer.set_virtual_stick(Vector2.ZERO)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.just_released(&"attack"), "touch release reaches router release edge", failures)
	layer.set_button_state(&"attack", true)
	router.poll(InputRouter.Context.GAMEPLAY)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"attack") and not router.just_pressed(&"attack"), "held touch action does not repeat its edge", failures)
	layer.set_button_state(&"attack", false)

	# Discrete gameplay presses pulse a short haptic; releases, the virtual
	# stick, and UI-only controls must not pulse.
	var haptic_actions: Array[StringName] = []
	layer.haptic_pulse.connect(func(action: StringName) -> void: haptic_actions.append(action))
	layer.vibration_enabled_override = true
	layer.set_button_state(&"magic", true)
	layer.set_button_state(&"magic", false)
	layer.set_virtual_stick(Vector2(1.0, 0.0))
	layer.set_button_state(&"pause", true)
	layer.set_button_state(&"pause", false)
	_expect(haptic_actions.size() == 1 and haptic_actions[0] == &"magic", "a discrete gameplay press pulses haptics once; release, stick, and UI buttons do not", failures)
	layer.vibration_enabled_override = false
	layer.set_button_state(&"magic", true)
	_expect(haptic_actions.size() == 1, "the vibration setting toggle suppresses the press pulse", failures)
	layer.vibration_enabled_override = null
	layer.set_button_state(&"magic", false)
	var world_tap := InputEventScreenTouch.new()
	world_tap.device = 0; world_tap.index = 13; world_tap.pressed = true; world_tap.position = Vector2(120.0, 60.0)
	layer._input(world_tap)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"interact") and router.just_pressed(&"interact"), "world tap reaches the displayed TAP interaction", failures)
	var world_tap_release := InputEventScreenTouch.new()
	world_tap_release.device = 0; world_tap_release.index = 13; world_tap_release.pressed = false; world_tap_release.position = world_tap.position
	layer._input(world_tap_release)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"interact") and router.just_released(&"interact"), "world TAP interaction releases cleanly", failures)
	var target_rect: Rect2 = layer._layout["buttons"][&"target"]
	var target_down := InputEventScreenTouch.new()
	target_down.device = 0; target_down.index = 11; target_down.pressed = true; target_down.position = target_rect.get_center()
	layer._input(target_down)
	var target_up := InputEventScreenTouch.new()
	target_up.device = 0; target_up.index = 11; target_up.pressed = false; target_up.position = target_rect.get_center()
	layer._input(target_up)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"target") and router.just_pressed(&"target"), "touch target toggles on with a tap", failures)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"target") and not router.just_pressed(&"target"), "toggled target remains active after release", failures)
	var target_down_again := InputEventScreenTouch.new()
	target_down_again.device = 0; target_down_again.index = 12; target_down_again.pressed = true; target_down_again.position = target_rect.get_center()
	layer._input(target_down_again)
	var target_up_again := InputEventScreenTouch.new()
	target_up_again.device = 0; target_up_again.index = 12; target_up_again.pressed = false; target_up_again.position = target_rect.get_center()
	layer._input(target_up_again)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"target") and router.just_released(&"target"), "second target tap toggles targeting off", failures)

	# Exercise the real pointer path: a long drag keeps the same stick owner
	# even when the browser reports a mouse-motion echo with another device id.
	var stick_home := layer._layout["stick_home"] as Vector2
	var stick_down := InputEventScreenTouch.new()
	stick_down.device = 0; stick_down.index = 9; stick_down.pressed = true; stick_down.position = stick_home
	layer._input(stick_down)
	var stick_drag := InputEventScreenDrag.new()
	stick_drag.device = 0; stick_drag.index = 9; stick_drag.position = stick_home + Vector2(12.0, 0.0)
	layer._input(stick_drag)
	var movement_before_echo := layer.movement_vector()
	var echoed_motion := InputEventMouseMotion.new()
	echoed_motion.device = 0; echoed_motion.relative = Vector2(8.0, 0.0); echoed_motion.position = stick_drag.position
	layer._input(echoed_motion)
	_expect(movement_before_echo.x > 0.5 and layer.movement_vector().is_equal_approx(movement_before_echo), "virtual stick keeps moving through a browser mouse echo", failures)
	var stick_up := InputEventScreenTouch.new()
	stick_up.device = 0; stick_up.index = 9; stick_up.pressed = false; stick_up.position = stick_drag.position
	layer._input(stick_up)
	_expect(layer.movement_vector() == Vector2.ZERO, "virtual stick release clears its pointer", failures)

	# The floating joystick relocates to any left-half touch and nests back in
	# the lower-left corner on release, mirroring the button cluster's home.
	var relocate_position := Vector2(stick_home.x + 40.0, stick_home.y - 20.0)
	var relocate_down := InputEventScreenTouch.new()
	relocate_down.device = 0; relocate_down.index = 22; relocate_down.pressed = true; relocate_down.position = relocate_position
	layer._input(relocate_down)
	_expect(layer._stick_origin.distance_to(relocate_position) < 1.0, "left-half touch relocates the floating stick to that point", failures)
	var relocate_up := InputEventScreenTouch.new()
	relocate_up.device = 0; relocate_up.index = 22; relocate_up.pressed = false; relocate_up.position = relocate_position
	layer._input(relocate_up)
	_expect(layer._stick_origin.distance_to(stick_home) < 1.0, "released stick nests back in its lower-left home", failures)

	layer.set_last_input_device(InputDeviceTracker.Device.KEYBOARD_MOUSE)
	layer.set_button_state(&"magic", true)
	layer.set_virtual_stick(Vector2.RIGHT)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"magic") and router.movement(0.25) == Vector2.ZERO, "hidden touch provider is inert", failures)
	layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	var hub_host := Node.new()
	get_root().add_child(hub_host)
	var hub_builder := ScreenStateController.new()
	var noop := Callable(self, "_noop")
	var noop_int := Callable(self, "_noop_int")
	# Keep every optional callback valid so the fixture exercises native button
	# activation without falling back to an unbound page setter.
	var hub_controls := hub_builder.build_hub(
		hub_host,
		Callable(self, "_pixel_texture"),
		Callable(self, "_record_stat_touch"), # adjust_stat
		noop, # apply_stats
		noop, # cancel_stats
		noop, # auto_allocate
		noop, # respec
		noop, # start_run
		noop, # return_title
		noop_int, # set_page
		noop, # item_action
		noop_int, # select_gear_slot
		noop, # bind_element
		noop_int, # select_gear_candidate
		Callable(self, "_record_hub_row"), # select_stat_row
		Callable(self, "_record_item_row"), # select_item_row
		Callable(self, "_record_fusion_count"), # adjust_fusion_count
		noop, # pause_resume
		noop, # pause_settings
		noop, # pause_quit
		noop, # pause_status
		noop, # pause_equipment
		noop) # pause_back_callback
	var hub_overlay := hub_controls["overlay"] as ColorRect
	hub_overlay.visible = true
	(hub_overlay.get_node("HubAllocatePage") as Control).visible = true
	for child in hub_overlay.get_children():
		if child is BaseButton:
			(child as BaseButton).visible = false
	for stat_button in hub_controls["stat_buttons"] as Array[Button]:
		stat_button.visible = false
	for stat_row in hub_controls["stat_rows"] as Array[Button]:
		stat_row.visible = true
	hub_builder.hub_stat_buttons = hub_controls["stat_buttons"] as Array[Button]
	hub_builder.hub_stat_row = 0
	hub_builder.hub_content_focus = true
	hub_builder._set_hub_stat_adjustment_targets(0, true)
	await process_frame
	layer.set_input_context(InputRouter.Context.HUB)
	_expect(layer.is_active(), "touch input remains available behind hub/menu overlays", failures)
	_expect(touch_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "inactive touch overlay does not intercept menu taps", failures)
	_expect(not (layer.get_node("TouchControlsRoot/Touch_Cancel") as Panel).visible, "hub uses its native BACK button instead of a floating cancel control", failures)
	var hub_blank_down := InputEventScreenTouch.new()
	hub_blank_down.device = 0; hub_blank_down.index = 13; hub_blank_down.pressed = true; hub_blank_down.position = hub_overlay.global_position + Vector2(78.0, 110.0)
	layer._input(hub_blank_down)
	router.poll(InputRouter.Context.HUB)
	_expect(not router.ui_accept_just_pressed(), "blank hub touch does not move the hidden menu cursor", failures)
	var hub_blank_up := InputEventScreenTouch.new()
	hub_blank_up.device = 0; hub_blank_up.index = 13; hub_blank_up.pressed = false; hub_blank_up.position = hub_blank_down.position
	layer._input(hub_blank_up)
	var stat_right := (hub_controls["stat_right"] as Array[Button])[0]
	var stat_add_marker := hub_controls["stat_add_marker"] as Sprite2D
	_expect(stat_add_marker != null and is_equal_approx(stat_right.get_global_rect().get_center().x, stat_add_marker.position.x), "hub stat plus hitbox is centered on its visible glyph", failures)
	var stat_down := InputEventScreenTouch.new()
	stat_down.device = 0; stat_down.index = 14; stat_down.pressed = true; stat_down.position = stat_right.get_global_rect().get_center()
	layer._input(stat_down)
	var stat_up := InputEventScreenTouch.new()
	stat_up.device = 0; stat_up.index = 14; stat_up.pressed = false; stat_up.position = stat_down.position
	layer._input(stat_up)
	_expect(stat_touch_count == 1 and stat_touch_names[0] == &"VIT", "touching the selected hub stat plus activates its hit target", failures)
	var nonselected_stat_right := (hub_controls["stat_right"] as Array[Button])[2]
	var nonselected_down := InputEventScreenTouch.new()
	nonselected_down.device = 0; nonselected_down.index = 20; nonselected_down.pressed = true; nonselected_down.position = nonselected_stat_right.get_global_rect().get_center()
	layer._input(nonselected_down)
	var nonselected_up := InputEventScreenTouch.new()
	nonselected_up.device = 0; nonselected_up.index = 20; nonselected_up.pressed = false; nonselected_up.position = nonselected_down.position
	layer._input(nonselected_up)
	_expect(stat_touch_count == 1, "a non-selected hub stat cannot be adjusted by touch", failures)
	var stat_rows := hub_controls["stat_rows"] as Array[Button]
	_expect(stat_rows.size() == 6 and stat_rows[0].size.x >= 60.0 and stat_rows[0].size.y >= 12.0, "hub stat rows expose direct touch targets for six stats", failures)
	var stat_row_touch_count_before := stat_row_touch_count
	var stat_row_down := InputEventScreenTouch.new()
	stat_row_down.device = 0; stat_row_down.index = 15; stat_row_down.pressed = true; stat_row_down.position = stat_rows[2].get_global_rect().get_center()
	layer._input(stat_row_down)
	var stat_row_up := InputEventScreenTouch.new()
	stat_row_up.device = 0; stat_row_up.index = 15; stat_row_up.pressed = false; stat_row_up.position = stat_row_down.position
	layer._input(stat_row_up)
	_expect(stat_row_touch_count == stat_row_touch_count_before + 1, "touching a hub stat row selects it directly", failures)
	hub_builder.hub_stat_row = 2
	hub_builder._set_hub_stat_adjustment_targets(2, true)
	# The first touch regression was caused by a one-shot cursor advance. A
	# second arrow touch must still reach its own button after the row touch.
	var stat_down_again := InputEventScreenTouch.new()
	stat_down_again.device = 0; stat_down_again.index = 16; stat_down_again.pressed = true; stat_down_again.position = stat_right.get_global_rect().get_center()
	layer._input(stat_down_again)
	var stat_up_again := InputEventScreenTouch.new()
	stat_up_again.device = 0; stat_up_again.index = 16; stat_up_again.pressed = false; stat_up_again.position = stat_down_again.position
	layer._input(stat_up_again)
	_expect(stat_touch_count == 1, "the old selected hub stat does not remain touch-active after row selection", failures)
	var selected_stat_right := (hub_controls["stat_right"] as Array[Button])[2]
	var selected_stat_down := InputEventScreenTouch.new()
	selected_stat_down.device = 0; selected_stat_down.index = 21; selected_stat_down.pressed = true; selected_stat_down.position = selected_stat_right.get_global_rect().get_center()
	layer._input(selected_stat_down)
	var selected_stat_up := InputEventScreenTouch.new()
	selected_stat_up.device = 0; selected_stat_up.index = 21; selected_stat_up.pressed = false; selected_stat_up.position = selected_stat_down.position
	layer._input(selected_stat_up)
	_expect(stat_touch_count == 2 and stat_touch_names[1] == &"DEF", "the newly selected hub stat owns the plus touch target", failures)
	for child in hub_overlay.get_children():
		if child is BaseButton:
			(child as BaseButton).visible = false
	(hub_overlay.get_node("HubAllocatePage") as Control).visible = false
	(hub_overlay.get_node("HubItemsPage") as Control).visible = true
	for item_row in hub_controls["item_rows"] as Array[Button]:
		item_row.visible = true
	for competing_button in (hub_controls["gear_slot_buttons"] as Array[Button]):
		competing_button.visible = false
	for competing_button in (hub_controls["gear_choice_buttons"] as Array[Button]):
		competing_button.visible = false
	for competing_button in (hub_controls["equipment_actions"] as Array[Button]):
		competing_button.visible = false
	(hub_controls["item_action"] as Button).visible = false
	(hub_controls["fusion_decrease"] as Button).visible = true
	(hub_controls["fusion_increase"] as Button).visible = true
	var item_rows := hub_controls["item_rows"] as Array[Button]
	_expect(item_rows.size() == 6 and item_rows[0].size.x >= 80.0, "shop and fusion rows expose direct touch targets for all six slots", failures)
	var item_row_down := InputEventScreenTouch.new()
	item_row_down.device = 0; item_row_down.index = 17; item_row_down.pressed = true; item_row_down.position = item_rows[0].get_global_rect().get_center()
	layer._input(item_row_down)
	var item_row_up := InputEventScreenTouch.new()
	item_row_up.device = 0; item_row_up.index = 17; item_row_up.pressed = false; item_row_up.position = item_row_down.position
	layer._input(item_row_up)
	_expect(item_row_touch_count == 1, "touching a shop or fusion row selects it directly", failures)
	var fusion_count_down := InputEventScreenTouch.new()
	fusion_count_down.device = 0; fusion_count_down.index = 18; fusion_count_down.pressed = true; fusion_count_down.position = (hub_controls["fusion_increase"] as Button).get_global_rect().get_center()
	layer._input(fusion_count_down)
	var fusion_count_up := InputEventScreenTouch.new()
	fusion_count_up.device = 0; fusion_count_up.index = 18; fusion_count_up.pressed = false; fusion_count_up.position = fusion_count_down.position
	layer._input(fusion_count_up)
	_expect(fusion_count_touch_count == 1, "touching fusion count controls reaches their callbacks", failures)
	# The pause shell is a separate full-screen overlay and uses its native
	# button/footer path without a second floating cancel affordance.
	var pause_overlay := hub_controls["pause_overlay"] as ColorRect
	var pause_buttons := hub_controls["pause_buttons"] as Array[Button]
	hub_overlay.visible = false
	pause_overlay.visible = true
	pause_touch_count = 0
	pause_buttons[0].pressed.connect(Callable(self, "_record_pause_touch"))
	layer.set_input_context(InputRouter.Context.PAUSE)
	await process_frame
	_expect(not (layer.get_node("TouchControlsRoot/Touch_Cancel") as Panel).visible, "pause uses its native BACK button instead of a floating cancel control", failures)
	_expect(pause_buttons[0].is_visible_in_tree() and not pause_buttons[0].disabled and layer.call("_menu_button_at", pause_buttons[0].get_global_rect().get_center()) == pause_buttons[0], "pause command is discoverable by the direct touch hit-test", failures)
	var pause_down := InputEventScreenTouch.new()
	pause_down.device = 0; pause_down.index = 19; pause_down.pressed = true; pause_down.position = pause_buttons[0].get_global_rect().get_center()
	layer._input(pause_down)
	var pause_up := InputEventScreenTouch.new()
	pause_up.device = 0; pause_up.index = 19; pause_up.pressed = false; pause_up.position = pause_down.position
	layer._input(pause_up)
	_expect(pause_touch_count == 1, "touching a pause command activates its direct button", failures)
	hub_host.free()
	hub_builder.free()
	layer.set_input_context(InputRouter.Context.MENU)
	_expect(layer.is_active(), "touch input remains available on title and other menus", failures)
	_expect(touch_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "menu touch overlay stays transparent to title Buttons", failures)
	var cancel_node := layer.get_node("TouchControlsRoot/Touch_Cancel") as Panel
	_expect(cancel_node != null and not cancel_node.visible, "menu back is owned by the active native footer", failures)

	# A real screen touch activates the same native Button that a desktop mouse
	# click would activate. The overlay captures the sequence so a browser's
	# emulated mouse echo cannot trigger the callback twice.
	var menu_host := Control.new()
	menu_host.size = TouchControlsLayer.BASE_CONTENT_SIZE
	get_root().add_child(menu_host)
	var menu_button := Button.new()
	menu_button.position = Vector2(20.0, 20.0)
	menu_button.size = Vector2(48.0, 20.0)
	menu_host.add_child(menu_button)
	await process_frame
	menu_button.set_meta("touch_pressed", false)
	menu_button.pressed.connect(func() -> void:
		menu_button.set_meta("touch_pressed", true)
	)
	var menu_down := InputEventScreenTouch.new()
	menu_down.device = 0; menu_down.index = 7; menu_down.pressed = true; menu_down.position = Vector2(30.0, 30.0)
	layer._input(menu_down)
	var menu_up := InputEventScreenTouch.new()
	menu_up.device = 0; menu_up.index = 7; menu_up.pressed = false; menu_up.position = Vector2(30.0, 30.0)
	layer._input(menu_up)
	_expect(bool(menu_button.get_meta("touch_pressed", false)), "screen touch activates a visible menu button", failures)
	menu_host.queue_free()

	# A blank non-dialogue menu tap stays inert; dialogue below owns the
	# tap-anywhere accept behavior explicitly.
	var menu_accept_down := InputEventScreenTouch.new()
	menu_accept_down.device = 0; menu_accept_down.index = 8; menu_accept_down.pressed = true; menu_accept_down.position = Vector2(150.0, 80.0)
	layer._input(menu_accept_down)
	router.poll(InputRouter.Context.MENU)
	_expect(not router.ui_accept_pressed() and not router.ui_accept_just_pressed(), "blank menu touch stays inert outside a button", failures)
	var menu_accept_up := InputEventScreenTouch.new()
	menu_accept_up.device = 0; menu_accept_up.index = 8; menu_accept_up.pressed = false; menu_accept_up.position = Vector2(150.0, 80.0)
	layer._input(menu_accept_up)
	router.poll(InputRouter.Context.MENU)

	layer.set_input_context(InputRouter.Context.DIALOGUE)
	var dialogue_box := ColorRect.new()
	dialogue_box.name = "NpcDialogueBox"
	dialogue_box.position = (layer._layout["buttons"][&"attack"] as Rect2).position
	dialogue_box.size = (layer._layout["buttons"][&"attack"] as Rect2).size
	dialogue_box.visible = true
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_root().add_child(dialogue_box)
	var dialogue_tap := InputEventScreenTouch.new()
	dialogue_tap.device = 0; dialogue_tap.index = 10; dialogue_tap.pressed = true; dialogue_tap.position = dialogue_box.get_global_rect().get_center()
	layer._input(dialogue_tap)
	router.poll(InputRouter.Context.DIALOGUE)
	_expect(router.ui_accept_pressed() and router.ui_accept_just_pressed(), "screen tap on the dialogue panel reaches dialogue accept", failures)
	var dialogue_release := InputEventScreenTouch.new()
	dialogue_release.device = 0; dialogue_release.index = 10; dialogue_release.pressed = false; dialogue_release.position = dialogue_tap.position
	layer._input(dialogue_release)
	router.poll(InputRouter.Context.DIALOGUE)
	dialogue_box.queue_free()

	router.set_touch_provider(null)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"magic") and router.movement(0.25) == Vector2.ZERO, "router remains desktop-compatible without a provider", failures)

	# The layout is always in viewport space. Test both portrait and landscape
	# shaped viewport values to ensure no control is placed in a letterbox-only
	# coordinate system that touch events cannot reach.
	for viewport_size in [Vector2(260.0, 563.0), Vector2(563.0, 260.0), TouchControlsLayer.BASE_CONTENT_SIZE]:
		var layout := layer._compute_layout(viewport_size, TouchControlsLayer.BASE_CONTENT_SIZE)
		var layout_window := layout["window_rect"] as Rect2
		_expect(layout_window.encloses(layout["stick_zone"] as Rect2), "stick zone stays inside the logical viewport", failures)
		_expect(layout_window.encloses(layout["pause"] as Rect2), "pause button stays inside the logical viewport", failures)
		_expect(layout_window.encloses(layout["cancel"] as Rect2), "cancel button stays inside the logical viewport", failures)
		var stick_zone: Rect2 = layout["stick_zone"]
		_expect(stick_zone.position.x <= layout_window.position.x + layout_window.size.x * 0.5 and stick_zone.end.x <= layout_window.position.x + layout_window.size.x * 0.5 + 1.0, "stick owns the left half of the viewport", failures)
		var layout_buttons: Dictionary = layout["buttons"]
		for action in layout_buttons:
			_expect(layout_window.encloses(layout_buttons[action] as Rect2), "action button stays inside the logical viewport", failures)
		var attack_rect: Rect2 = layout_buttons[&"attack"]
		var magic_rect: Rect2 = layout_buttons[&"magic"]
		var roll_rect: Rect2 = layout_buttons[&"roll"]
		var guard_rect: Rect2 = layout_buttons[&"guard"]
		var target_layout_rect: Rect2 = layout_buttons[&"target"]
		var roll_center := roll_rect.get_center()
		var attack_distance := attack_rect.get_center().distance_to(roll_center)
		var magic_distance := magic_rect.get_center().distance_to(roll_center)
		var guard_distance := guard_rect.get_center().distance_to(roll_center)
		var target_distance := target_layout_rect.get_center().distance_to(roll_center)
		_expect(roll_rect.size.x > attack_rect.size.x and roll_rect.size.y > attack_rect.size.y, "roll is the primary button, larger than the secondaries", failures)
		_expect(attack_distance < magic_distance and attack_distance < guard_distance and attack_distance < target_distance, "attack sits nearest the roll thumb home", failures)
		_expect(attack_rect.position.y > roll_rect.position.y or magic_rect.position.y < roll_rect.position.y, "secondary actions spread around the roll button", failures)
		_expect(magic_rect.get_center().x < roll_center.x and target_layout_rect.get_center().y < roll_center.y, "the left/up arc keeps Magic beside and Target above the roll", failures)
		_expect(is_equal_approx(magic_distance, guard_distance) and is_equal_approx(guard_distance, target_distance), "secondary actions sit on one even arc radius around roll", failures)
		_expect(not layout_buttons.has(&"interact"), "the USE button is removed from the action arc", failures)
	_expect(float((layer._compute_layout(TouchControlsLayer.BASE_CONTENT_SIZE, TouchControlsLayer.BASE_CONTENT_SIZE))["button_size"]) >= TouchControlsLayer.BUTTON_MIN, "buttons keep the minimum logical size", failures)

	router.free()
	layer.free()
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TOUCH_CONTROLS_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _record_stat_touch(stat_name: StringName, _direction: int) -> void:
	stat_touch_count += 1
	stat_touch_names.append(stat_name)


func _record_hub_row(_row: int) -> void:
	stat_row_touch_count += 1


func _record_item_row(_row: int) -> void:
	item_row_touch_count += 1


func _record_fusion_count(_direction: int) -> void:
	fusion_count_touch_count += 1


func _record_pause_touch() -> void:
	pause_touch_count += 1


func _pixel_texture(_text: String, color: Color) -> Texture2D:
	var image := Image.create(3, 5, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _noop() -> void:
	pass


func _noop_int(_value: int) -> void:
	pass
