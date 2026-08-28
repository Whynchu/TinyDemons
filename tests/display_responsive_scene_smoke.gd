extends SceneTree

const TEST_PATH := "res://.godot_user/display_responsive_scene_smoke.cfg"

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for responsive display coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var display := gameplay.get("display_controller") as DisplayController
	var settings := gameplay.get("settings_service") as SettingsService
	var touch := gameplay.get("touch_controls_layer") as TouchControlsLayer
	_expect(display != null and settings != null and touch != null, "display, settings, and touch owners are composed", failures)
	if display != null and settings != null and touch != null:
		settings.file_path = TEST_PATH
		settings.reset_to_defaults()
		var view_sizes := {"3:2": Vector2i(240, 160), "16:10": Vector2i(256, 160), "16:9": Vector2i(284, 160)}
		for aspect in view_sizes.keys():
			settings.set_setting(&"aspect", aspect)
			await process_frame
			var expected: Vector2i = view_sizes[aspect]
			var screens := gameplay.get("screen_state_controller") as ScreenStateController
			_expect(display.view_size_value() == expected, "%s applies its logical view size" % aspect, failures)
			_expect(gameplay.get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT, "%s preserves the full vertical scale" % aspect, failures)
			var ui := gameplay.get_node("InterfaceCanvas/UI") as Node
			var top_bar := ui.get_node_or_null("DisplayTopBar") as ColorRect
			var bottom_bar := ui.get_node_or_null("DisplayBottomBar") as ColorRect
			var void_background := gameplay.get_node_or_null("BackgroundCanvas/DisplayVoidBackground") as ColorRect
			_expect(top_bar != null and top_bar.size == Vector2(expected.x, 16), "%s top bar covers the full width" % aspect, failures)
			_expect(bottom_bar != null and bottom_bar.position == Vector2(0, 145) and bottom_bar.size == Vector2(expected.x, 15), "%s bottom bar keeps its exact height" % aspect, failures)
			_expect(void_background != null and void_background.size == Vector2(expected), "%s void background covers the full logical view" % aspect, failures)
			var title_overlay := (gameplay.get("screen_state_controller") as ScreenStateController).title_overlay
			_expect(title_overlay != null and title_overlay.size == Vector2(expected), "%s title overlay covers the full view" % aspect, failures)
			_expect(screens.settings_overlay != null and screens.settings_overlay.size == Vector2(expected), "%s settings overlay covers the full view" % aspect, failures)
			if screens.settings_title_text != null and screens.settings_title_text.texture != null:
				_expect(is_equal_approx(screens.settings_title_text.position.x, (expected.x - screens.settings_title_text.texture.get_width()) * 0.5), "%s settings title recenters with the view" % aspect, failures)
			if not screens.settings_value_buttons.is_empty():
				_expect(is_equal_approx(screens.settings_value_buttons[0].position.x, expected.x * 0.5 + 36.0), "%s settings controls expand from the view center" % aspect, failures)
			var floor_layer := gameplay.get_node("Map/FloorTiles/FloorLayer") as Node2D
			_expect(floor_layer != null and is_equal_approx(floor_layer.global_position.x, expected.x * 0.5), "%s room diamond remains centered" % aspect, failures)
			var content_size := touch._content_size()
			_expect(content_size == Vector2(expected), "%s touch layer reads the live logical size" % aspect, failures)
			var player_hud := ui.get_node("PlayerHud") as Node2D
			var gold_display := player_hud.get_node("GoldDisplay") as Node2D
			var health := player_hud.get_node("PlayerStatus/Health") as Node2D
			var right_shift := float(expected.x - 240)
			var center_shift := right_shift * 0.5
			_expect(is_equal_approx(gold_display.position.x, 205.0 + right_shift), "%s right HUD cluster reaches the edge" % aspect, failures)
			_expect(is_equal_approx(health.position.x, 66.0 + center_shift), "%s center HUD cluster shifts by half the expansion" % aspect, failures)
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
	push_error("TEST_ABORTED: responsive display scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("DISPLAY_RESPONSIVE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
