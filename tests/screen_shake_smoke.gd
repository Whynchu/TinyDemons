extends SceneTree


class ShakeRoot extends Node2D:
	var display_world_offset := Vector2.ZERO


func _initialize() -> void:
	var failures: Array[String] = []
	var scene_root := ShakeRoot.new()
	root.add_child(scene_root)
	var display := DisplayController.new()
	scene_root.add_child(display)
	display.initialize(scene_root, null)
	await process_frame
	var camera := display.world_camera()
	_expect(camera != null and camera.enabled, "display controller creates an enabled world camera", failures)
	if camera != null:
		var base_offset := camera.offset
		display.request_screen_shake(2.0, 0.12)
		_expect(display.screen_shake_remaining_value() > 0.0, "combat shake registers a bounded camera reaction", failures)
		_expect(camera.offset != base_offset, "combat shake offsets the world camera", failures)
		var held_offset := camera.offset
		display.tick_screen_shake(0.0, true)
		_expect(camera.offset == held_offset, "combat shake holds during hitstop", failures)
		display.tick_screen_shake(0.12)
		_expect(is_zero_approx(display.screen_shake_remaining_value()) and camera.offset.is_equal_approx(base_offset), "combat shake decays to the authored camera offset", failures)
		display.request_screen_shake(3.0, 0.20)
		_expect(display.screen_shake_offset_value().length() <= 3.0, "combat shake remains inside the pixel budget", failures)
		display.clear_screen_shake()
		_expect(camera.offset.is_equal_approx(base_offset), "combat shake can be cleared without moving the camera", failures)
	scene_root.queue_free()
	await process_frame
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SCREEN_SHAKE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
