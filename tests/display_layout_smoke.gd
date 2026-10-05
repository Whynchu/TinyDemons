extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var native := Vector2(DisplayLayout.NATIVE_SIZE)
	var wide := Vector2(DisplayLayout.view_size("16:9"))
	_expect(DisplayLayout.view_size("3:2") == Vector2i(240, 160), "3:2 uses the native content size", failures)
	_expect(DisplayLayout.view_size("16:10") == Vector2i(256, 160), "16:10 keeps height and adds width", failures)
	_expect(DisplayLayout.view_size("16:9") == Vector2i(284, 160), "16:9 keeps height and adds width", failures)
	_expect(DisplayLayout.view_size("FULL", 346) == Vector2i(346, 160) and DisplayLayout.is_full_aspect("FULL"), "FULL uses the live width while preserving height", failures)
	_expect(DisplayLayout.offset_for(&"gold", native) == Vector2.ZERO, "right HUD offset is zero at native width", failures)
	_expect(DisplayLayout.offset_for(&"hp_mp", native) == Vector2.ZERO, "center HUD offset is zero at native width", failures)
	_expect(DisplayLayout.offset_for(&"player_status", native) == Vector2.ZERO, "left HUD offset is zero at native width", failures)
	_expect(DisplayLayout.offset_for(&"gold", wide) == Vector2(44, 0), "right HUD moves to the 16:9 edge", failures)
	_expect(DisplayLayout.offset_for(&"run_timer", wide) == Vector2(44, 0), "right timer moves to the 16:9 edge", failures)
	_expect(DisplayLayout.offset_for(&"hp_mp", wide) == Vector2(22, 0), "center HUD moves by half the extra width", failures)
	_expect(DisplayLayout.offset_for(&"target_name", wide) == Vector2(22, 0), "center target text moves by half the extra width", failures)
	_expect(DisplayLayout.offset_for(&"minimap", wide) == Vector2.ZERO, "minimap stays left anchored", failures)
	_expect(DisplayLayout.offset_for(&"room_number", wide) == Vector2.ZERO, "room number stays left anchored", failures)
	_expect(DisplayLayout.offset_for(&"ability_icons", wide) == Vector2.ZERO, "ability icons stay beside the player status strip", failures)
	_expect(DisplayLayout.bottom_y(160.0) == 0.0, "bottom anchor has no native vertical offset", failures)
	var expanded := DisplayLayout.visible_size_for_window(Vector2(844, 390), native, true)
	_expect(expanded == Vector2(346, 160), "wide surfaces expose their full logical width", failures)
	_expect(DisplayLayout.centered_origin(expanded, native) == Vector2(53, 0), "native frame centers inside a wide logical surface", failures)
	var phone_surface := DisplayLayout.browser_surface_size(Vector2(1280, 576), Vector2(1126, 576), 1.0)
	_expect(phone_surface == Vector2(1280, 576), "adaptive layout follows the wider mobile canvas viewport", failures)
	var phone_visible := DisplayLayout.visible_size_for_window(phone_surface, wide, true)
	var phone_origin := DisplayLayout.centered_origin(phone_visible, wide)
	_expect(is_equal_approx(phone_origin.x + wide.x * 0.5, phone_visible.x * 0.5), "fixed-width landscape menus center on the full phone surface", failures)
	_expect(DisplayLayout.browser_surface_size(Vector2(844, 390), Vector2(422, 195), 2.0) == Vector2(844, 390), "mobile browser zoom does not shrink the layout surface", failures)
	_expect(DisplayLayout.browser_surface_size(Vector2.ZERO, Vector2(900, 420), 1.0) == Vector2(900, 420), "visual viewport remains a fallback when layout dimensions are missing", failures)
	_expect(DisplayLayout.visible_size_for_window(Vector2(390, 844), wide, true) == wide, "narrow surfaces do not crop a fixed frame", failures)
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("DISPLAY_LAYOUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
