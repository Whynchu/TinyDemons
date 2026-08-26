extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var layer := TouchControlsLayer.new()
	get_root().add_child(layer)
	layer.build()
	layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	layer.set_input_context(InputRouter.Context.GAMEPLAY)
	_expect(layer.is_active(), "touch controls activate for touch gameplay input", failures)

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

	router.set_touch_provider(null)
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(not router.pressed(&"magic") and router.movement(0.25) == Vector2.ZERO, "router remains desktop-compatible without a provider", failures)
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
