extends SceneTree

const LIBRARY_SCRIPT = preload("res://scripts/sprite_frame_library.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var base_texture := load("res://assets/artwork/DoorRightOrbshut.png") as Texture2D
	_expect(base_texture != null, "Orb-locked door art loads", failures)
	if base_texture != null:
		var library = LIBRARY_SCRIPT.new()
		var blue_image: Image = library.recolor_door_texture(base_texture, "blue").get_image()
		var green_image: Image = library.recolor_door_texture(base_texture, "green").get_image()
		var yellow_image: Image = library.recolor_door_texture(base_texture, "yellow").get_image()
		_expect(blue_image.get_pixel(4, 5) == Color8(59, 93, 201), "Puzzle Color A door uses the blue map color", failures)
		_expect(blue_image.get_pixel(5, 6) == Color8(65, 166, 246), "Puzzle Color A door preserves a stepped highlight", failures)
		_expect(green_image.get_pixel(4, 5) == Color8(56, 183, 100), "Puzzle Color B door uses the green map color", failures)
		_expect(green_image.get_pixel(5, 6) == Color8(167, 240, 112), "Puzzle Color B door preserves a stepped highlight", failures)
		_expect(yellow_image.get_pixel(4, 5) == Color8(255, 205, 117), "Yellow door uses the yellow map color", failures)
		_expect(yellow_image.get_pixel(5, 6) == Color8(255, 240, 150), "Yellow door preserves a stepped highlight", failures)
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN1_DOOR_COLOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
