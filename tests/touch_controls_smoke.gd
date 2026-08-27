extends SceneTree

var stat_touch_count := 0
var stat_row_touch_count := 0
var item_row_touch_count := 0
var fusion_count_touch_count := 0


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
	for action in [&"attack", &"interact", &"roll", &"magic", &"cancel", &"pause", &"target", &"guard", &"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	router.set_touch_provider(layer)
	layer.set_button_state(&"attack", true)
	layer.set_virtual_stick(Vector2(1.0, 0.0))
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"attack") and router.just_pressed(&"attack"), "touch button reaches router held and edge state", failures)
	_expect(router.movement(0.25).x > 0.9, "touch stick reaches router movement snapshot", failures)
	layer.set_button_state(&"interact", true)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.ui_accept_pressed() and router.ui_accept_just_pressed(), "touch interact aliases UI accept", failures)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"attack") and not router.just_pressed(&"attack"), "held touch action does not repeat its edge", failures)
	layer.set_button_state(&"attack", false)
	layer.set_button_state(&"interact", false)
	layer.set_virtual_stick(Vector2.ZERO)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.just_released(&"attack"), "touch release reaches router release edge", failures)
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

	layer.set_last_input_device(InputDeviceTracker.Device.KEYBOARD_MOUSE)
	layer.set_button_state(&"magic", true)
	layer.set_virtual_stick(Vector2.RIGHT)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"magic") and router.movement(0.25) == Vector2.ZERO, "hidden touch provider is inert", failures)
	layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	var hub_host := Node.new()
	get_root().add_child(hub_host)
	var hub_builder := ScreenStateController.new()
	var hub_controls := hub_builder.build_hub(hub_host, Callable(self, "_pixel_texture"), Callable(self, "_record_stat_touch"), Callable(self, "_noop"), Callable(self, "_noop"), Callable(self, "_noop"), Callable(self, "_noop"), Callable(self, "_noop"), Callable(self, "_noop"), Callable(self, "_noop_int"), Callable(self, "_noop"), Callable(self, "_noop_int"), Callable(self, "_noop"), Callable(self, "_noop_int"), Callable(self, "_record_hub_row"), Callable(self, "_record_item_row"), Callable(self, "_record_fusion_count"))
	var hub_overlay := hub_controls["overlay"] as ColorRect
	hub_overlay.visible = true
	for child in hub_overlay.get_children():
		if child is BaseButton:
			(child as BaseButton).visible = false
	for stat_button in hub_controls["stat_buttons"] as Array[Button]:
		stat_button.visible = true
	for stat_row in hub_controls["stat_rows"] as Array[Button]:
		stat_row.visible = true
	await process_frame
	layer.set_input_context(InputRouter.Context.HUB)
	_expect(layer.is_active(), "touch input remains available behind hub/menu overlays", failures)
	_expect(touch_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "inactive touch overlay does not intercept menu taps", failures)
	var hub_cancel_rect: Rect2 = layer._layout["cancel"]
	_expect(hub_overlay.get_global_rect().encloses(hub_cancel_rect), "hub cancel control is nested inside the hub panel", failures)
	var hub_blank_down := InputEventScreenTouch.new()
	hub_blank_down.device = 0; hub_blank_down.index = 13; hub_blank_down.pressed = true; hub_blank_down.position = hub_overlay.global_position + Vector2(78.0, 110.0)
	layer._input(hub_blank_down)
	router.poll(InputRouter.Context.HUB)
	_expect(not router.ui_accept_just_pressed(), "blank hub touch does not move the hidden menu cursor", failures)
	var hub_blank_up := InputEventScreenTouch.new()
	hub_blank_up.device = 0; hub_blank_up.index = 13; hub_blank_up.pressed = false; hub_blank_up.position = hub_blank_down.position
	layer._input(hub_blank_up)
	var stat_right := (hub_controls["stat_right"] as Array[Button])[0]
	var stat_down := InputEventScreenTouch.new()
	stat_down.device = 0; stat_down.index = 14; stat_down.pressed = true; stat_down.position = stat_right.get_global_rect().get_center()
	layer._input(stat_down)
	var stat_up := InputEventScreenTouch.new()
	stat_up.device = 0; stat_up.index = 14; stat_up.pressed = false; stat_up.position = stat_down.position
	layer._input(stat_up)
	_expect(stat_touch_count == 1, "touching a hub stat arrow activates its enlarged hit target", failures)
	var stat_rows := hub_controls["stat_rows"] as Array[Button]
	_expect(stat_rows.size() == 4 and stat_rows[0].size.x >= 100.0 and stat_rows[0].size.y >= 12.0, "hub stat rows expose direct touch targets", failures)
	var stat_row_down := InputEventScreenTouch.new()
	stat_row_down.device = 0; stat_row_down.index = 15; stat_row_down.pressed = true; stat_row_down.position = stat_rows[2].get_global_rect().get_center()
	layer._input(stat_row_down)
	var stat_row_up := InputEventScreenTouch.new()
	stat_row_up.device = 0; stat_row_up.index = 15; stat_row_up.pressed = false; stat_row_up.position = stat_row_down.position
	layer._input(stat_row_up)
	_expect(stat_row_touch_count == 1, "touching a hub stat row selects it directly", failures)
	# The first touch regression was caused by a one-shot cursor advance. A
	# second arrow touch must still reach its own button after the row touch.
	var stat_down_again := InputEventScreenTouch.new()
	stat_down_again.device = 0; stat_down_again.index = 16; stat_down_again.pressed = true; stat_down_again.position = stat_right.get_global_rect().get_center()
	layer._input(stat_down_again)
	var stat_up_again := InputEventScreenTouch.new()
	stat_up_again.device = 0; stat_up_again.index = 16; stat_up_again.pressed = false; stat_up_again.position = stat_down_again.position
	layer._input(stat_up_again)
	_expect(stat_touch_count == 2, "repeated hub stat touches remain responsive", failures)
	for child in hub_overlay.get_children():
		if child is BaseButton:
			(child as BaseButton).visible = false
	for item_row in hub_controls["item_rows"] as Array[Button]:
		item_row.visible = true
	(hub_controls["fusion_decrease"] as Button).visible = true
	(hub_controls["fusion_increase"] as Button).visible = true
	var item_rows := hub_controls["item_rows"] as Array[Button]
	_expect(item_rows.size() == 5 and item_rows[0].size.x >= 140.0, "shop and fusion rows expose direct touch targets", failures)
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
	hub_host.free()
	hub_builder.free()
	layer.set_input_context(InputRouter.Context.MENU)
	_expect(layer.is_active(), "touch input remains available on title and other menus", failures)
	_expect(touch_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "menu touch overlay stays transparent to title Buttons", failures)
	var cancel_node := layer.get_node("TouchControlsRoot/Touch_Cancel") as Panel
	var cancel_rect: Rect2 = layer._layout["cancel"]
	_expect(cancel_node != null and cancel_node.visible, "menu cancel control is visible for touch input", failures)
	var cancel_down := InputEventScreenTouch.new()
	cancel_down.device = 0; cancel_down.index = 6; cancel_down.pressed = true; cancel_down.position = cancel_rect.get_center()
	layer._input(cancel_down)
	router.poll(InputRouter.Context.MENU)
	_expect(router.ui_cancel_pressed() and router.ui_cancel_just_pressed(), "menu cancel touch reaches UI cancel", failures)
	var cancel_up := InputEventScreenTouch.new()
	cancel_up.device = 0; cancel_up.index = 6; cancel_up.pressed = false; cancel_up.position = cancel_rect.get_center()
	layer._input(cancel_up)
	router.poll(InputRouter.Context.MENU)
	_expect(not router.ui_cancel_pressed(), "menu cancel touch releases cleanly", failures)

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

	# A tap outside a Button still provides the menu's normal accept edge.
	var menu_accept_down := InputEventScreenTouch.new()
	menu_accept_down.device = 0; menu_accept_down.index = 8; menu_accept_down.pressed = true; menu_accept_down.position = Vector2(150.0, 80.0)
	layer._input(menu_accept_down)
	router.poll(InputRouter.Context.MENU)
	_expect(router.ui_accept_pressed() and router.ui_accept_just_pressed(), "screen tap outside a button reaches menu accept", failures)
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
		var layout_buttons: Dictionary = layout["buttons"]
		for action in layout_buttons:
			_expect(layout_window.encloses(layout_buttons[action] as Rect2), "action button stays inside the logical viewport", failures)
		var attack_rect: Rect2 = layout_buttons[&"attack"]
		var magic_rect: Rect2 = layout_buttons[&"magic"]
		var use_rect: Rect2 = layout_buttons[&"interact"]
		var roll_rect: Rect2 = layout_buttons[&"roll"]
		var guard_rect: Rect2 = layout_buttons[&"guard"]
		var target_layout_rect: Rect2 = layout_buttons[&"target"]
		_expect(magic_rect.position.y < attack_rect.position.y and attack_rect.position.y == use_rect.position.y and roll_rect.position.y > attack_rect.position.y, "touch actions form a diamond with Magic top and Roll bottom", failures)
		_expect(attack_rect.position.x < roll_rect.position.x and roll_rect.position.x < use_rect.position.x and guard_rect.position.x < roll_rect.position.x and target_layout_rect.position.x > roll_rect.position.x, "touch actions place Use right and Guard/Target around Roll", failures)
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


func _record_stat_touch(_stat_name: StringName, _direction: int) -> void:
	stat_touch_count += 1


func _record_hub_row(_row: int) -> void:
	stat_row_touch_count += 1


func _record_item_row(_row: int) -> void:
	item_row_touch_count += 1


func _record_fusion_count(_direction: int) -> void:
	fusion_count_touch_count += 1


func _pixel_texture(_text: String, color: Color) -> Texture2D:
	var image := Image.create(3, 5, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _noop() -> void:
	pass


func _noop_int(_value: int) -> void:
	pass
