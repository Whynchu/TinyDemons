extends SceneTree

const TEST_PATH := "res://.godot_user/settings_panel_scene_smoke.cfg"

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for settings panel coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var settings := gameplay.get("settings_service") as SettingsService
	var sound := gameplay.get("sound_manager") as SoundManager
	var input_router := gameplay.get("input_router") as InputRouter
	_expect(screens != null and settings != null and sound != null and input_router != null, "settings, screen, sound, and input owners are composed", failures)
	if screens != null and settings != null and sound != null and input_router != null:
		settings.file_path = TEST_PATH
		settings.reset_to_defaults()
		_expect(screens.title_settings_button != null, "title screen exposes a Settings button", failures)
		if screens.title_settings_button != null:
			screens.title_settings_button.pressed.emit()
		await process_frame
		_expect(screens.settings_overlay != null and screens.settings_overlay.visible, "title Settings button opens the shared panel", failures)
		_expect(screens.state == &"settings" and screens.settings_value_buttons.size() == 5, "settings panel enters its five-row state", failures)
		gameplay.call("_select_setting_option", 1, 2)
		gameplay.call("_adjust_setting", 3, -1)
		_expect(str(settings.get_setting(&"aspect")) == "16:10", "aspect row applies immediately", failures)
		_expect(int(settings.get_setting(&"music_volume")) == 90, "volume row applies in ten-point steps", failures)
		_expect(sound.music_volume() == 90, "music volume applies to the live sound manager", failures)
		settings.set_setting(&"sfx_volume", 40)
		_expect(sound.sfx_volume() == 40, "SFX volume applies to the live sound manager", failures)
		_expect(settings.load_settings().get("aspect") == "16:10", "settings changes persist through ConfigFile", failures)
		_expect(settings.load_settings().get("sfx_volume") == 40, "audio settings persist through ConfigFile", failures)
		_expect(screens.settings_option_buttons.size() == 5 and screens.settings_option_buttons[1].size() == 4 and screens.settings_option_buttons[3].size() == 11, "settings exposes direct horizontal option controls", failures)
		# Confirming the navigable BACK row must close Settings without allowing the
		# same held input to fall through to the title screen's New Game button.
		screens.settings_row = screens.settings_value_buttons.size()
		screens.call("update_settings_ui", gameplay, Callable(gameplay, "_pixel_text_texture"))
		screens.call("_focus_settings_selection")
		_expect(screens.settings_back_button.focus_mode == Control.FOCUS_NONE and screens.settings_cursor_text.visible, "title Settings exposes BACK as a rendered selection", failures)
		input_router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
		input_router.set("_current", {&"menu_confirm": true, &"menu_back": false})
		gameplay.call("_update_settings_input")
		await process_frame
		_expect(not screens.settings_overlay.visible and screens.title_overlay.visible, "confirming Settings BACK restores the title", failures)
		_expect(screens.state == &"title", "confirming Settings BACK restores title state", failures)
		_expect(not screens.title_transition_active, "Settings BACK confirm does not fall through to New Game", failures)
		input_router.set("_previous", {&"menu_confirm": true, &"menu_back": false})
		input_router.set("_current", {&"menu_confirm": false, &"menu_back": false})
		await process_frame
		var focus_owner := gameplay.get_viewport().gui_get_focus_owner()
		_expect(focus_owner == null and screens.title_menu_row == 2, "closing settings restores title selection", failures)
		gameplay.call("_open_pause_menu")
		await process_frame
		_expect(screens.hub_pause_mode and screens.pause_settings_button != null, "pause menu exposes Settings", failures)
		if screens.pause_settings_button != null:
			screens.pause_settings_button.pressed.emit()
		await process_frame
		_expect(screens.settings_overlay.visible and screens.settings_origin == &"pause", "pause Settings opens the same panel", failures)
		_expect(not screens.hub_overlay.visible, "pause panel is hidden while settings is open", failures)
		# The sixth virtual selection is the visible BACK button, so a controller
		# can leave the panel without relying on a separate keyboard-only action.
		screens.settings_row = screens.settings_value_buttons.size()
		screens.call("update_settings_ui", gameplay, Callable(gameplay, "_pixel_text_texture"))
		screens.call("_focus_settings_selection")
		_expect(screens.settings_back_button.focus_mode == Control.FOCUS_NONE and screens.settings_cursor_text.visible, "settings exposes BACK as a rendered selection", failures)
		input_router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
		input_router.set("_current", {&"menu_confirm": false, &"menu_back": true})
		gameplay.call("_update_settings_input")
		await process_frame
		_expect(not screens.settings_overlay.visible and screens.hub_pause_mode, "mapped cancel closes pause settings", failures)
		_expect(screens.pause_overlay.visible and not screens.hub_overlay.visible and screens.pause_page == 0, "closing settings restores the dedicated pause command panel", failures)
	gameplay.queue_free()
	await process_frame
	_cleanup()
	_finish(failures)


func _cleanup() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: settings panel scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("SETTINGS_PANEL_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
