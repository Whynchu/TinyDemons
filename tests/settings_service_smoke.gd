extends SceneTree

const TEST_PATH := "res://.godot_user/settings_service_smoke.cfg"


func _initialize() -> void:
	var failures: Array[String] = []
	_remove_test_file()
	var service := SettingsService.new(TEST_PATH)
	root.add_child(service)
	var defaults := service.load_settings()
	_expect(defaults.get("fullscreen", null) == false, "missing settings use windowed default", failures)
	_expect(defaults.get("aspect", "") == "3:2", "missing settings use 3:2 default", failures)
	_expect(defaults.get("pixel_perfect", null) == true, "missing settings use pixel-perfect default", failures)
	_expect(defaults.get("music_volume", -1) == 100 and defaults.get("sfx_volume", -1) == 100, "missing settings use full volume defaults", failures)

	service.set_setting(&"fullscreen", true)
	service.set_setting(&"aspect", "16:9")
	service.set_setting(&"pixel_perfect", false)
	service.set_setting(&"music_volume", 60)
	service.set_setting(&"sfx_volume", 30)
	var round_trip := SettingsService.new(TEST_PATH)
	root.add_child(round_trip)
	var loaded := round_trip.load_settings()
	_expect(loaded.get("fullscreen", false) == true and loaded.get("aspect", "") == "16:9", "settings round-trip booleans and aspect", failures)
	_expect(loaded.get("pixel_perfect", true) == false and loaded.get("music_volume", -1) == 60 and loaded.get("sfx_volume", -1) == 30, "settings round-trip scaling and volumes", failures)

	service.set_setting(&"music_volume", -5)
	service.set_setting(&"sfx_volume", 155)
	service.set_setting(&"aspect", "4:3")
	_expect(service.get_setting(&"music_volume", -1) == 0 and service.get_setting(&"sfx_volume", -1) == 100, "settings clamp volume values", failures)
	_expect(service.get_setting(&"aspect", "") == "3:2", "settings reject unsupported aspect", failures)

	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if corrupt != null:
		corrupt.store_string("[settings\nnot valid")
		corrupt.close()
	var recovered := SettingsService.new(TEST_PATH)
	root.add_child(recovered)
	var recovered_values := recovered.load_settings()
	_expect(recovered_values.get("aspect", "") == "3:2" and recovered_values.get("music_volume", -1) == 100, "corrupt settings fall back to defaults", failures)

	service.free()
	round_trip.free()
	recovered.free()
	_remove_test_file()
	_finish(failures)


func _remove_test_file() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SETTINGS_SERVICE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
