extends SceneTree

var _finished := false


func _initialize() -> void:
	var failures: Array[String] = []
	var layer := TouchControlsLayer.new()
	get_root().add_child(layer)
	layer.build()
	layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	layer.set_input_context(InputRouter.Context.HUB)
	var router := InputRouter.new()
	get_root().add_child(router)
	router.set_touch_provider(layer)

	# Blank hub drag reports a pixel scroll delta (the menu translates its content
# rather than moving the cursor).
	var scroll_down := InputEventScreenTouch.new()
	scroll_down.device = 0; scroll_down.index = 1; scroll_down.pressed = true; scroll_down.position = Vector2(120.0, 120.0)
	layer._input(scroll_down)
	for i in 4:
		var drag := InputEventScreenDrag.new()
		drag.device = 0; drag.index = 1; drag.position = Vector2(120.0, 120.0 + 10.0 * float(i + 1))
		layer._input(drag)
	router.poll(InputRouter.Context.HUB)
	_expect(router.touch_scroll_y() > 20.0, "blank hub drag down reports a downward scroll delta", failures)
	var scroll_up := InputEventScreenDrag.new()
	scroll_up.device = 0; scroll_up.index = 1; scroll_up.position = Vector2(120.0, 90.0)
	layer._input(scroll_up)
	router.poll(InputRouter.Context.HUB)
	_expect(router.touch_scroll_y() < -20.0, "blank hub drag up reports an upward scroll delta", failures)
	var scroll_release := InputEventScreenTouch.new()
	scroll_release.device = 0; scroll_release.index = 1; scroll_release.pressed = false; scroll_release.position = Vector2(120.0, 90.0)
	layer._input(scroll_release)
	router.poll(InputRouter.Context.HUB)
	_expect(router.touch_scroll_y() == 0.0, "scroll delta stops after release", failures)

	# A missed touchend leaves a ghost accept finger that holds interact/accept
	# pressed and blocks dialogue advancement. The stale-hold timeout drops it so
	# the next tap advances again. This mechanism lives in the dialogue context:
	# non-dialogue menus deliberately keep blank taps inert.
	layer.set_input_context(InputRouter.Context.DIALOGUE)
	var dialogue_box := ColorRect.new()
	dialogue_box.name = "NpcDialogueBox"
	# Keep the dialogue panel clear of the bottom-right cancel control so the
	# tap registers as a dialogue accept rather than a cancel.
	dialogue_box.position = Vector2(30.0, 60.0)
	dialogue_box.size = Vector2(100.0, 50.0)
	dialogue_box.visible = true
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_root().add_child(dialogue_box)
	var ghost := InputEventScreenTouch.new()
	ghost.device = 0; ghost.index = 7; ghost.pressed = true; ghost.position = dialogue_box.get_global_rect().get_center()
	layer._input(ghost)
	router.poll(InputRouter.Context.DIALOGUE)
	_expect(router.ui_accept_just_pressed(), "first dialogue tap produces an accept edge", failures)
	router.poll(InputRouter.Context.DIALOGUE)
	_expect(router.ui_accept_pressed(), "ghost accept finger keeps accept held without an up event", failures)
	var accept_fingers: Dictionary = layer.get("_menu_accept_fingers")
	accept_fingers[7] = -1000000
	layer.call("_clear_stale_menu_accepts")
	router.poll(InputRouter.Context.DIALOGUE)
	_expect(not router.ui_accept_pressed(), "stale accept hold is dropped without an up event", failures)
	var follow_up := InputEventScreenTouch.new()
	follow_up.device = 0; follow_up.index = 8; follow_up.pressed = true; follow_up.position = dialogue_box.get_global_rect().get_center() + Vector2(8.0, 0.0)
	layer._input(follow_up)
	router.poll(InputRouter.Context.DIALOGUE)
	_expect(router.ui_accept_just_pressed(), "after the stale hold clears, the next tap advances the dialogue", failures)
	dialogue_box.queue_free()

	router.free()
	layer.free()
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("TOUCH_MENU_SCROLL_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)