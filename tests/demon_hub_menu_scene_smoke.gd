extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Demon Hub menu coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var input_router := gameplay.get("input_router") as InputRouter
	_expect(screens != null and input_router != null, "hub and input owners are composed", failures)
	if screens != null and input_router != null:
		gameplay.call("_show_hub", true, false)
		await process_frame
		_expect(screens.hub_overlay.visible and not screens.pause_overlay.visible and screens.hub_pause_mode == false, "Demon interaction opens only the preparation overlay", failures)
		_expect(screens.hub_overlay.size == screens.display_view_size and screens.hub_overlay.position == Vector2.ZERO and screens.hub_overlay.get_node_or_null("HubRootPage/HubPlayerCard") != null, "Demon Hub owns the full-screen player card shell", failures)
		_expect(screens.hub_overlay.get_node_or_null("HubCommandStart") == null, "Demon Hub does not construct a hidden Start Run button", failures)
		_expect(screens.hub_page_buttons.all(func(button: Button) -> bool: return button.get_meta("hub_page_target", -1) >= 0), "hub commands use explicit page targets", failures)
		gameplay.call("_close_hub_to_run")

		gameplay.call("_open_pause_menu")
		await process_frame
		_expect(screens.pause_overlay.visible and not screens.hub_overlay.visible and screens.state == &"pause", "pause opens a distinct overlay and state", failures)
		_expect(screens.pause_overlay.size == screens.display_view_size and screens.pause_overlay.position == Vector2.ZERO and screens.pause_menu_buttons.size() == 5, "pause uses its own full-screen command shell", failures)
		_expect(gameplay.call("_input_context") == InputRouter.Context.PAUSE, "pause routes through the dedicated input context", failures)
		if screens.pause_status_button != null:
			screens.pause_status_button.pressed.emit()
		_expect(screens.pause_page == 1 and not screens.hub_overlay.visible and screens.pause_status_texts[0].visible, "pause Status stays read-only and cannot expose hub transactions", failures)
		if screens.pause_back_button != null:
			screens.pause_back_button.pressed.emit()
		_expect(screens.pause_page == 0 and screens.pause_description_text.visible, "pause BACK returns from a read-only subpage", failures)
		if screens.pause_settings_button != null:
			screens.pause_settings_button.pressed.emit()
		await process_frame
		_expect(screens.settings_overlay.visible and not screens.pause_overlay.visible and not screens.hub_overlay.visible, "pause Settings replaces pause without overlay overlap", failures)
		gameplay.call("_close_settings")
		_expect(screens.pause_overlay.visible and not screens.settings_overlay.visible and not screens.hub_overlay.visible and screens.state == &"pause", "closing pause Settings restores only pause", failures)
		gameplay.call("_close_hub_to_run")
		_expect(not screens.pause_overlay.visible and not screens.hub_overlay.visible and screens.state == &"gameplay", "pause cancellation returns to gameplay", failures)
	gameplay.queue_free()
	await process_frame
	_finished = true
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Demon Hub menu scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("DEMON_HUB_MENU_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
