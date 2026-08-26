extends SceneTree


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

	layer.set_last_input_device(InputDeviceTracker.Device.KEYBOARD_MOUSE)
	layer.set_button_state(&"magic", true)
	layer.set_virtual_stick(Vector2.RIGHT)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"magic") and router.movement(0.25) == Vector2.ZERO, "hidden touch provider is inert", failures)
	layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	layer.set_input_context(InputRouter.Context.HUB)
	_expect(not layer.is_active(), "touch controls hide behind hub/menu overlays", failures)
	_expect(touch_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "inactive touch overlay does not intercept menu taps", failures)
	layer.set_input_context(InputRouter.Context.MENU)
	_expect(touch_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "menu touch overlay stays transparent to title Buttons", failures)

	router.set_touch_provider(null)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"magic") and router.movement(0.25) == Vector2.ZERO, "router remains desktop-compatible without a provider", failures)

	# Adaptive layout: portrait windows put the controls in the bottom
	# letterbox bar, clear of the game area.
	var content_rect := Rect2(Vector2.ZERO, TouchControlsLayer.BASE_CONTENT_SIZE)
	var portrait := layer._compute_layout(Vector2(260.0, 563.0), TouchControlsLayer.BASE_CONTENT_SIZE)
	var portrait_zone := portrait["stick_zone"] as Rect2
	_expect(portrait_zone.position.y >= TouchControlsLayer.BASE_CONTENT_SIZE.y - 0.01, "portrait stick zone sits in the bottom bar", failures)
	var portrait_window := portrait["window_rect"] as Rect2
	var portrait_buttons: Dictionary = portrait["buttons"]
	var portrait_buttons_inside := true
	var portrait_buttons_clear := true
	for action in portrait_buttons:
		var rect := portrait_buttons[action] as Rect2
		if not portrait_window.encloses(rect):
			portrait_buttons_inside = false
		if rect.intersects(content_rect):
			portrait_buttons_clear = false
	_expect(portrait_buttons_inside, "portrait buttons stay inside the window", failures)
	_expect(portrait_buttons_clear, "portrait buttons do not cover the game", failures)
	_expect(float(portrait["button_size"]) >= TouchControlsLayer.BUTTON_MIN, "portrait buttons keep the minimum physical size", failures)
	_expect(portrait_window.encloses(portrait["pause"] as Rect2), "portrait pause button stays inside the window", failures)

	# Landscape windows with side bars park the stick in the left bar and the
	# buttons in the right bar.
	var landscape := layer._compute_layout(Vector2(563.0, 260.0), TouchControlsLayer.BASE_CONTENT_SIZE)
	_expect((landscape["stick_zone"] as Rect2).end.x <= 0.01, "landscape stick zone sits in the left bar", failures)
	var landscape_buttons: Dictionary = landscape["buttons"]
	var landscape_right := true
	for action in landscape_buttons:
		if (landscape_buttons[action] as Rect2).position.x < TouchControlsLayer.BASE_CONTENT_SIZE.x - 0.01:
			landscape_right = false
	_expect(landscape_right, "landscape buttons sit in the right bar", failures)

	# An exact-fit window (desktop-like) falls back to a bottom-corner overlay
	# that still stays inside the window.
	var fitted := layer._compute_layout(Vector2(240.0, 160.0), TouchControlsLayer.BASE_CONTENT_SIZE)
	_expect((fitted["window_rect"] as Rect2).encloses(fitted["stick_zone"] as Rect2), "exact-fit stick zone stays inside the window", failures)

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
