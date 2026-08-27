extends SceneTree

const Recognizer = preload("res://scripts/circular_input_recognizer.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var recognizer := Recognizer.new()
	recognizer.configure(0.55, 0.50, TAU * 0.80, 0.28)
	var circle := [
		Vector2.RIGHT,
		Vector2(0.707, 0.707),
		Vector2.DOWN,
		Vector2(-0.707, 0.707),
		Vector2.LEFT,
		Vector2(-0.707, -0.707),
		Vector2.UP,
		Vector2(0.707, -0.707),
		Vector2.RIGHT,
	]
	var recognized := false
	for movement in circle:
		recognized = recognizer.update(movement, 0.045) or recognized
	_expect(recognized and recognizer.is_armed(), "a fast clockwise circle arms the spin gesture", failures)
	_expect(recognizer.consume(), "an armed spin gesture can be consumed", failures)
	_expect(not recognizer.is_armed(), "consuming the gesture clears its armed state", failures)
	var counter_clockwise := [Vector2.RIGHT, Vector2(0.707, -0.707), Vector2.UP, Vector2(-0.707, -0.707), Vector2.LEFT, Vector2(-0.707, 0.707), Vector2.DOWN, Vector2(0.707, 0.707), Vector2.RIGHT]
	for movement in counter_clockwise:
		recognizer.update(movement, 0.045)
	_expect(recognizer.is_armed(), "a fast counter-clockwise circle also arms the spin gesture", failures)
	recognizer.reset()
	for movement in [Vector2.RIGHT, Vector2.LEFT, Vector2.RIGHT, Vector2.LEFT, Vector2.RIGHT, Vector2.LEFT]:
		recognizer.update(movement, 0.045)
	_expect(not recognizer.is_armed(), "back-and-forth movement does not count as a circle", failures)
	recognizer.reset()
	for movement in circle:
		recognizer.update(movement, 0.10)
	_expect(not recognizer.is_armed(), "a circle that exceeds the speed window is rejected", failures)
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CIRCULAR_INPUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
