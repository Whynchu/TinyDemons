extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(10.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var host := Node.new()
	get_root().add_child(host)
	var npc := NpcController.new()
	host.add_child(npc)
	var built := npc.build_dialogue(host, _solid_texture(Color.WHITE))
	npc.dialogue_layer = built["layer"] as CanvasLayer
	npc.dialogue_box = built["box"] as ColorRect
	npc.dialogue_text = built["text"] as Sprite2D
	npc.dialogue_button = built["button"] as Sprite2D
	npc.dialogue_button_shadow = built["shadow"] as Sprite2D
	npc.dialogue_yes_text = built["yes"] as Sprite2D
	npc.dialogue_no_text = built["no"] as Sprite2D
	npc.dialogue_yes_button = built["yes_button"] as Button
	npc.dialogue_no_button = built["no_button"] as Button
	var mock := _MockRoot.new()
	npc.dialogue_box.position = Vector2(20, 30)
	npc.dialogue_box.size = Vector2(100, 40)
	npc.dialogue_box.visible = true
	npc.allocation_prompt_active = true
	npc.dialogue_complete = true
	npc.allocation_choice = 0
	npc.call("_update_allocation_choices", mock)

	var touch := TouchControlsLayer.new()
	get_root().add_child(touch)
	touch.build()
	touch.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	touch.set_input_context(InputRouter.Context.DIALOGUE)
	await process_frame
	_expect(npc.dialogue_yes_button.visible and npc.dialogue_no_button.visible, "dialogue exposes visible YES and NO touch controls", failures)
	_expect(npc.dialogue_yes_button.mouse_filter != Control.MOUSE_FILTER_IGNORE and npc.dialogue_no_button.mouse_filter != Control.MOUSE_FILTER_IGNORE, "dialogue choice controls participate in touch hit testing", failures)

	_tap(touch, npc.dialogue_yes_button.get_global_rect().get_center(), 20)
	npc.update_dialogue_input(mock)
	_expect(mock.hub_opened and not npc.dialogue_box.visible, "touching YES opens the Hub and closes dialogue", failures)

	mock.hub_opened = false
	npc.dialogue_box.visible = true
	npc.allocation_prompt_active = true
	npc.dialogue_complete = true
	npc.allocation_choice = 0
	npc.call("_update_allocation_choices", mock)
	await process_frame
	_tap(touch, npc.dialogue_no_button.get_global_rect().get_center(), 21)
	npc.update_dialogue_input(mock)
	_expect(not mock.hub_opened and not npc.dialogue_box.visible, "touching NO closes dialogue without opening the Hub", failures)

	touch.queue_free()
	host.queue_free()
	await process_frame
	_finished = true
	call_deferred("_finish", failures)


func _tap(touch: TouchControlsLayer, position: Vector2, finger_id: int) -> void:
	var down := InputEventScreenTouch.new()
	down.device = 0
	down.index = finger_id
	down.pressed = true
	down.position = position
	touch._input(down)
	var up := InputEventScreenTouch.new()
	up.device = 0
	up.index = finger_id
	up.pressed = false
	up.position = position
	touch._input(up)


func _solid_texture(color: Color) -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: dialogue choice smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("DIALOGUE_CHOICE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)


class _MockRoot:
	var hub_opened := false

	func _pixel_text_texture(_text: String, color: Color) -> Texture2D:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(color)
		return ImageTexture.create_from_image(image)

	func _snap_half_pixel(position: Vector2) -> Vector2:
		return position

	func _is_interact_input_pressed() -> bool:
		return false

	func _is_ui_direction_just_pressed(_direction: StringName) -> bool:
		return false

	func _is_ui_cancel_just_pressed() -> bool:
		return false

	func _is_ui_accept_just_pressed() -> bool:
		return false

	func _play_sound(_sound_name: String, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
		pass

	func _open_hub_from_cloaked_demon() -> void:
		hub_opened = true
