extends SceneTree

var _finished := false
var _accepted_name := ""


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for name-entry coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(screens != null and profile != null, "name-entry owner is composed", failures)
	if screens != null and profile != null:
		screens.show_name_entry(gameplay, 0)
		await process_frame
		_expect(screens.name_entry_overlay != null and screens.name_entry_overlay.visible and screens.state == &"name_entry", "new file opens a dedicated name-entry screen", failures)
		_expect(screens.name_entry_cell_buttons.size() == ScreenStateController.NAME_ENTRY_COLUMNS * ScreenStateController.NAME_ENTRY_ROWS, "name-entry owns a fixed controller grid", failures)
		_expect(screens.name_entry_cell_buttons[0].visible and not screens.name_entry_cell_buttons[31].visible, "name-entry only exposes the active page cells", failures)
		_expect(screens.name_entry_confirm_text.texture != null and screens.name_entry_back_text.texture != null, "name-entry shows one confirm and one back prompt", failures)
		screens.name_entry_finish_callback = Callable(self, "_capture_name")
		screens._activate_name_entry_cell(0)
		screens._activate_name_entry_cell(1)
		_expect(screens.name_entry_name == "AB", "name-entry controller selection appends letters", failures)
		screens._activate_name_entry_cell(28)
		_expect(_accepted_name == "AB", "name-entry DONE returns the normalized player name", failures)
		profile.player_name = _accepted_name
		var restored := PlayerProfile.new()
		restored.load_dictionary(profile.to_dictionary())
		_expect(restored.player_name == "AB", "player name survives profile serialization", failures)
		screens.show_name_entry(gameplay, 0)
		gameplay.call("_cancel_name_entry")
		_expect(not screens.name_entry_overlay.visible and screens.state == &"title", "BACK exits name-entry without creating a file", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _capture_name(value: String) -> void:
	_accepted_name = value


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: name entry scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("NAME_ENTRY_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
