extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for cloud panel touch coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var panel := gameplay.get("cloud_save_panel") as CloudSavePanel
	var layer := gameplay.get("touch_controls_layer") as TouchControlsLayer
	_expect(panel != null and layer != null, "cloud panel and touch layer are composed", failures)
	if panel != null and layer != null:
		gameplay.call("_open_cloud_save")
		await process_frame
		_expect(panel.overlay.visible, "Cloud Save button opens the management window", failures)
		layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
		layer.set_input_context(InputRouter.Context.MENU)
		await process_frame
		var back_button: Button = panel.buttons[5]
		_expect(back_button.is_visible_in_tree(), "cloud BACK button is a live touch target", failures)
		_tap(layer, back_button.get_global_rect().get_center(), 5)
		await process_frame
		_expect(not panel.overlay.visible, "tapping BACK closes the cloud overlay on touch", failures)
		# CREATE must never hang the panel: with no Web build it reports the
		# not-configured error and stays closable.
		panel.open()
		await process_frame
		_tap(layer, panel.buttons[0].get_global_rect().get_center(), 6)
		await process_frame
		_expect(panel.overlay.visible, "cloud panel stays open after CREATE without crashing", failures)
		_tap(layer, back_button.get_global_rect().get_center(), 7)
		await process_frame
		_expect(not panel.overlay.visible, "cloud overlay remains closable after CREATE", failures)
		# Tapping the recovery key field focuses it for paste instead of
		# confirming whatever button is highlighted.
		panel.open()
		await process_frame
		var key_rect := panel.key_input.get_global_rect()
		_tap(layer, key_rect.get_center(), 8)
		await process_frame
		_expect(panel.key_input.has_focus(), "tapping the key field focuses it for paste", failures)
		_expect(panel.overlay.visible, "focusing the key field does not trigger a button", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _tap(layer: TouchControlsLayer, position: Vector2, finger: int) -> void:
	var down := InputEventScreenTouch.new()
	down.device = 0; down.index = finger; down.pressed = true; down.position = position
	layer._input(down)
	var up := InputEventScreenTouch.new()
	up.device = 0; up.index = finger; up.pressed = false; up.position = position
	layer._input(up)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: cloud panel touch smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("CLOUD_PANEL_TOUCH_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)