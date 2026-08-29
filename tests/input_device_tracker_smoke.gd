extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var tracker := InputDeviceTracker.new()
	get_root().add_child(tracker)
	var changes: Array[int] = []
	tracker.device_changed.connect(func(device: int) -> void: changes.append(device))

	var key := InputEventKey.new()
	key.pressed = true
	key.echo = false
	_expect(tracker.classify_event(key) == InputDeviceTracker.Device.KEYBOARD_MOUSE, "pressed non-echo key selects keyboard/mouse", failures)
	key.echo = true
	_expect(tracker.classify_event(key) < 0, "key repeat does not change the last device", failures)

	var mouse := InputEventMouseButton.new()
	mouse.device = 0
	mouse.pressed = true
	_expect(tracker.classify_event(mouse) == InputDeviceTracker.Device.KEYBOARD_MOUSE, "physical mouse press selects keyboard/mouse", failures)
	mouse.device = InputDeviceTracker.EMULATED_DEVICE_ID
	_expect(tracker.classify_event(mouse) < 0, "emulated touch mouse does not bounce to keyboard/mouse", failures)

	var touch := InputEventScreenTouch.new()
	touch.device = 0
	touch.pressed = true
	_expect(tracker.classify_event(touch) == InputDeviceTracker.Device.TOUCH, "real screen touch selects touch", failures)
	var drag := InputEventScreenDrag.new()
	drag.device = 0
	_expect(tracker.classify_event(drag) == InputDeviceTracker.Device.TOUCH, "screen drag remains touch input", failures)
	var touch_release := InputEventScreenTouch.new()
	touch_release.device = 0
	touch_release.index = touch.index
	touch_release.pressed = false
	_expect(tracker.classify_event(touch_release) == InputDeviceTracker.Device.TOUCH, "screen touch release remains touch input", failures)
	var echoed_motion := InputEventMouseMotion.new()
	echoed_motion.device = 0
	echoed_motion.relative = Vector2(4.0, 0.0)
	_expect(tracker.classify_event(echoed_motion) < 0, "mouse-motion echo after touch does not switch to keyboard", failures)

	var motion := InputEventJoypadMotion.new()
	motion.axis_value = 0.49
	_expect(tracker.classify_event(motion) < 0, "sub-threshold stick drift is ignored", failures)
	motion.axis_value = -0.51
	_expect(tracker.classify_event(motion) == InputDeviceTracker.Device.GAMEPAD, "deliberate stick motion selects gamepad", failures)
	var button := InputEventJoypadButton.new()
	button.pressed = true
	_expect(tracker.classify_event(button) == InputDeviceTracker.Device.GAMEPAD, "gamepad button selects gamepad", failures)

	tracker.set_device(InputDeviceTracker.Device.GAMEPAD)
	var unchanged_count := changes.size()
	tracker.set_device(InputDeviceTracker.Device.GAMEPAD)
	_expect(changes.size() == unchanged_count, "device signal fires only for a change", failures)
	tracker.set_device(InputDeviceTracker.Device.KEYBOARD_MOUSE)
	_expect(changes.size() == unchanged_count + 1, "device signal fires after a real change", failures)
	_expect(tracker.prompt_label(&"interact") == "E", "keyboard interaction prompt uses E", failures)
	tracker.set_device(InputDeviceTracker.Device.TOUCH)
	_expect(tracker.prompt_label(&"interact") == "TAP", "touch interaction prompt uses TAP", failures)
	_expect(tracker.prompt_label(&"attack") == "TOUCH", "touch action prompt remains device-aware", failures)
	tracker.set_device(InputDeviceTracker.Device.GAMEPAD)
	var rebuilt := InputDeviceTracker.new()
	get_root().add_child(rebuilt)
	await process_frame
	_expect(rebuilt.current_device == InputDeviceTracker.Device.GAMEPAD, "last controller device survives tracker rebuild", failures)
	var startup_mouse_motion := InputEventMouseMotion.new()
	startup_mouse_motion.device = 0
	startup_mouse_motion.relative = Vector2(4.0, 0.0)
	rebuilt._input(startup_mouse_motion)
	_expect(rebuilt.current_device == InputDeviceTracker.Device.GAMEPAD, "startup mouse-motion echo does not replace a restored controller", failures)
	await create_timer(0.80).timeout
	rebuilt._input(startup_mouse_motion)
	_expect(rebuilt.current_device == InputDeviceTracker.Device.KEYBOARD_MOUSE, "real mouse movement can switch devices after the handoff", failures)
	rebuilt.queue_free()

	tracker.free()
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("INPUT_DEVICE_TRACKER_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
