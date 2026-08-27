extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var native := Vector2(DisplayLayout.NATIVE_SIZE)
	var wide := Vector2(DisplayLayout.view_size("16:9"))
	_expect(DisplayLayout.view_size("3:2") == Vector2i(240, 160), "3:2 uses the native content size", failures)
	_expect(DisplayLayout.view_size("16:10") == Vector2i(256, 160), "16:10 keeps height and adds width", failures)
	_expect(DisplayLayout.view_size("16:9") == Vector2i(284, 160), "16:9 keeps height and adds width", failures)
	_expect(DisplayLayout.offset_for(&"gold", native) == Vector2.ZERO, "right HUD offset is zero at native width", failures)
	_expect(DisplayLayout.offset_for(&"hp_mp", native) == Vector2.ZERO, "center HUD offset is zero at native width", failures)
	_expect(DisplayLayout.offset_for(&"player_status", native) == Vector2.ZERO, "left HUD offset is zero at native width", failures)
	_expect(DisplayLayout.offset_for(&"gold", wide) == Vector2(44, 0), "right HUD moves to the 16:9 edge", failures)
	_expect(DisplayLayout.offset_for(&"run_timer", wide) == Vector2(44, 0), "right timer moves to the 16:9 edge", failures)
	_expect(DisplayLayout.offset_for(&"hp_mp", wide) == Vector2(22, 0), "center HUD moves by half the extra width", failures)
	_expect(DisplayLayout.offset_for(&"target_name", wide) == Vector2(22, 0), "center target text moves by half the extra width", failures)
	_expect(DisplayLayout.offset_for(&"minimap", wide) == Vector2.ZERO, "minimap stays left anchored", failures)
	_expect(DisplayLayout.offset_for(&"room_number", wide) == Vector2.ZERO, "room number stays left anchored", failures)
	_expect(DisplayLayout.bottom_y(160.0) == 0.0, "bottom anchor has no native vertical offset", failures)
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
