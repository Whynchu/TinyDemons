extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for pause menu coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(screens != null and profile != null, "pause menu owners are composed", failures)
	if screens != null and profile != null:
		var starting_gold := profile.gold
		var starting_runs := profile.completed_runs
		gameplay.call("_open_pause_menu")
		await process_frame
		_expect(screens.hub_overlay.visible and screens.hub_pause_mode, "pause opens the hub in pause mode", failures)
		_expect(screens.pause_menu_buttons.size() == 3, "pause exposes Resume, Settings, and Quit to Title", failures)
		for button in screens.pause_menu_buttons:
			_expect(button.visible, "pause menu action is visible", failures)
		_expect(screens.hub_gear_stat_panel != null and screens.hub_gear_stat_panel.visible, "pause shows the character status panel", failures)
		_expect(screens.hub_gear_stat_texts.size() >= 5 and screens.hub_gear_stat_texts[0].visible, "pause status panel shows HP and core stats", failures)
		if screens.hub_gear_stat_panel != null and not screens.pause_menu_buttons.is_empty():
			_expect(screens.pause_menu_buttons[0].position.x + screens.pause_menu_buttons[0].size.x < screens.hub_gear_stat_panel.position.x, "pause actions do not overlap the status panel", failures)
		if screens.pause_resume_button != null:
			screens.pause_resume_button.pressed.emit()
		await process_frame
		_expect(not screens.hub_overlay.visible and not screens.hub_pause_mode, "Resume returns to gameplay", failures)
		_expect(screens.state == &"gameplay", "Resume restores gameplay state", failures)
		gameplay.call("_open_pause_menu")
		await process_frame
		var pause_quit := screens.pause_quit_button
		_expect(pause_quit != null and not pause_quit.disabled, "Quit to Title is available from pause", failures)
		if pause_quit != null:
			pause_quit.pressed.emit()
		_expect(not screens.hub_overlay.visible, "Quit to Title closes the pause overlay", failures)
		_expect(bool(gameplay.get("scene_transition_active")), "Quit to Title reuses the scene teardown transition", failures)
		_expect(profile.gold == starting_gold and profile.completed_runs == starting_runs, "Quit to Title leaves settled profile progress intact", failures)
		_expect(profile.pending_route == "title", "Quit to Title records the title route", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: pause menu scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("PAUSE_MENU_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
