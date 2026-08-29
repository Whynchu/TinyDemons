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
		var stable_floor := (gameplay.get_node("Map/FloorTiles/FloorLayer") as Node2D).global_position
		var view_sizes := {"3:2": Vector2i(240, 160), "16:10": Vector2i(256, 160), "16:9": Vector2i(284, 160)}
		for aspect in view_sizes.keys():
			settings.set_setting(&"aspect", aspect)
			await process_frame
			var expected: Vector2i = view_sizes[aspect]
			var screens := gameplay.get("screen_state_controller") as ScreenStateController
			_expect(display.view_size_value() == expected, "%s applies its logical view size" % aspect, failures)
			var live_surface := display.live_window_size_value()
			var should_preserve_height := live_surface.x / maxf(live_surface.y, 1.0) >= float(expected.x) / maxf(float(expected.y), 1.0)
			var expected_scale_aspect := Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT if should_preserve_height else Window.CONTENT_SCALE_ASPECT_KEEP
			_expect(gameplay.get_window().content_scale_aspect == expected_scale_aspect, "%s selects a crop-safe content scale mode" % aspect, failures)
			var visible_size := display.visible_view_size_value()
			_expect(visible_size.x >= expected.x and visible_size.y >= expected.y, "%s presentation frame fits the visible logical surface" % aspect, failures)
			_expect(display.presentation_origin_value().is_equal_approx(DisplayLayout.centered_origin(visible_size, Vector2(expected))), "%s centers its active frame in the visible surface" % aspect, failures)
			var ui := gameplay.get_node("InterfaceCanvas/UI") as Node
			var top_bar := ui.get_node_or_null("DisplayTopBar") as ColorRect
			var bottom_bar := ui.get_node_or_null("DisplayBottomBar") as ColorRect
			var void_background := gameplay.get_node_or_null("BackgroundCanvas/DisplayVoidBackground") as ColorRect
			_expect(top_bar != null and top_bar.size == Vector2(expected.x, 16), "%s top bar covers the full width" % aspect, failures)
			_expect(bottom_bar != null and bottom_bar.position == Vector2(0, 145) and bottom_bar.size == Vector2(expected.x, 15), "%s bottom bar keeps its exact height" % aspect, failures)
			_expect(void_background != null and void_background.size.is_equal_approx(visible_size), "%s void background covers the full logical view" % aspect, failures)
			_expect((gameplay.get_node("InterfaceCanvas") as CanvasLayer).offset.is_equal_approx(display.presentation_origin_value()), "%s interface canvas follows the centered presentation frame" % aspect, failures)
			var title_overlay := (gameplay.get("screen_state_controller") as ScreenStateController).title_overlay
			_expect(title_overlay != null and title_overlay.size == Vector2(expected), "%s title overlay covers the full view" % aspect, failures)
			_expect(screens.settings_overlay != null and screens.settings_overlay.size == Vector2(expected), "%s settings overlay covers the full view" % aspect, failures)
			var result_metrics := screens.run_complete_overlay.get_node_or_null("RunCompleteMetrics") as Panel if screens.run_complete_overlay != null else null
			var result_width := minf(220.0, maxf(float(expected.x) - 20.0, 100.0))
			var result_x := floorf(maxf((float(expected.x) - result_width) * 0.5, 10.0))
			_expect(result_metrics != null and is_equal_approx(result_metrics.position.x, result_x), "%s result metrics stay centered in the active frame" % aspect, failures)
			if not screens.run_complete_texts.is_empty():
				_expect(is_equal_approx(screens.run_complete_texts[0].position.x, result_x + 9.0), "%s result text follows its centered card" % aspect, failures)
			if screens.settings_title_text != null and screens.settings_title_text.texture != null:
				_expect(is_equal_approx(screens.settings_title_text.position.x, 13.0), "%s settings title stays in its title tab" % aspect, failures)
			if not screens.settings_value_buttons.is_empty():
				_expect(screens.settings_value_buttons[0].position.x >= 90.0 and screens.settings_value_buttons[0].position.x < expected.x, "%s settings controls stay in their option column" % aspect, failures)
			for option_row in screens.settings_option_buttons:
				for option_value in option_row:
					var option_button := option_value as Button
					_expect(Rect2(option_button.position, option_button.size).end.x <= float(expected.x), "%s settings option fits inside the active frame" % aspect, failures)
			var floor_layer := gameplay.get_node("Map/FloorTiles/FloorLayer") as Node2D
			_expect(floor_layer != null and floor_layer.global_position.is_equal_approx(stable_floor), "%s room geometry remains in authored coordinates" % aspect, failures)
			_expect(display.world_camera() != null and display.world_camera().enabled and display.world_camera().global_position.is_equal_approx(Vector2(120, 80)), "%s display camera keeps the room centered" % aspect, failures)
			var content_size := touch._content_size()
			_expect(content_size == Vector2(expected), "%s touch layer reads the live logical size" % aspect, failures)
			var player_hud := ui.get_node("PlayerHud") as Node2D
			var gold_display := player_hud.get_node("GoldDisplay") as Node2D
			var health := player_hud.get_node("PlayerStatus/Health") as Node2D
			var right_shift := float(expected.x - 240)
			var center_shift := right_shift * 0.5
			_expect(is_equal_approx(gold_display.position.x, 205.0 + right_shift), "%s right HUD cluster reaches the edge" % aspect, failures)
			_expect(is_equal_approx(health.position.x, 66.0 + center_shift), "%s center HUD cluster shifts by half the expansion" % aspect, failures)
		var original_window_size := gameplay.get_window().size
		gameplay.get_window().size = Vector2i(960, 720)
		settings.set_setting(&"aspect", "FULL")
		await process_frame
		var live_window := gameplay.get_window().size
		var expected_full := Vector2i(maxi(240, roundi(160.0 * float(live_window.x) / maxf(float(live_window.y), 1.0))), 160)
		_expect(display.view_size_value() == expected_full, "FULL follows the live window aspect", failures)
		var full_should_preserve_height := live_window.x / maxf(live_window.y, 1.0) >= float(expected_full.x) / maxf(float(expected_full.y), 1.0)
		var full_expected_scale_aspect := Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT if full_should_preserve_height else Window.CONTENT_SCALE_ASPECT_KEEP
		_expect(gameplay.get_window().content_scale_aspect == full_expected_scale_aspect, "FULL chooses a crop-safe content scale mode", failures)
		_expect(display.visible_view_size_value().is_equal_approx(Vector2(expected_full)), "FULL uses the complete active logical frame", failures)
		_expect(display.presentation_origin_value().is_equal_approx(Vector2.ZERO), "FULL has no extra presentation offset", failures)
		_expect((gameplay.get_node("Map/FloorTiles/FloorLayer") as Node2D).global_position.is_equal_approx(stable_floor), "FULL preserves authored collision geometry", failures)
		# Simulate a live mobile orientation change while FULL is active. The
		# logical frame must be recalculated after the viewport settles, and the
		# full-screen menu frame must follow it instead of retaining old geometry.
		var orientation_screens := gameplay.get("screen_state_controller") as ScreenStateController
		gameplay.get_window().size = Vector2i(720, 960)
		await process_frame
		await process_frame
		var portrait_expected := Vector2i(240, 160)
		_expect(display.view_size_value() == portrait_expected, "portrait orientation clamps FULL to the native logical width", failures)
		_expect(gameplay.get_window().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "portrait orientation switches to crop-safe keep scaling", failures)
		_expect(orientation_screens != null and (orientation_screens.settings_overlay as ColorRect).size == Vector2(portrait_expected), "portrait orientation resizes settings overlay", failures)
		gameplay.get_window().size = Vector2i(960, 540)
		await process_frame
		await process_frame
		var landscape_expected := Vector2i(284, 160)
		_expect(display.view_size_value() == landscape_expected, "landscape orientation restores FULL logical width", failures)
		_expect(orientation_screens != null and (orientation_screens.run_complete_overlay as ColorRect).size == Vector2(landscape_expected), "landscape orientation resizes result overlay", failures)
		gameplay.get_window().size = original_window_size
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
