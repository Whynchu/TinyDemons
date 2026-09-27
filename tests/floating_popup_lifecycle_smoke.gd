extends SceneTree

var _finished := false


func _initialize() -> void:
	var failures: Array[String] = []
	var parent := Node2D.new()
	root.add_child(parent)
	var spawner := EffectsSpawner.new()
	root.add_child(spawner)
	spawner.spawn_health_number(parent, Vector2(40, 50), 7, Vector2(0, -12), true, false, Color.WHITE, Callable(self, "_number_texture"), Callable(self, "_snap"), 0.65, 0.10, "7")
	var entry := spawner.damage_numbers[0]
	var sprite := entry["sprite"] as Sprite2D
	spawner.update_damage_numbers(0.11, Callable(self, "_snap"), 0.65)
	var settled_position := sprite.global_position
	var settled_scale := sprite.scale
	var settled_timer := float(entry["timer"])
	for _frame in 4:
		spawner.update_damage_numbers(1.0 / 60.0, Callable(self, "_snap"), 0.65)
		_expect(sprite.global_position == settled_position, "floating text holds its position during the four-frame pause", failures)
		_expect(float(entry["timer"]) == settled_timer, "floating text lifetime does not drain during the pause", failures)
	_expect(sprite.scale == settled_scale and sprite.modulate.a == 1.0, "floating text remains at settled size and full opacity during the pause", failures)
	spawner.update_damage_numbers(1.0 / 60.0, Callable(self, "_snap"), 0.65)
	_expect(sprite.global_position != settled_position, "floating text resumes drifting after the four-frame pause", failures)
	parent.queue_free()
	spawner.queue_free()
	await process_frame
	_finish(failures)


func _number_texture(_text: String, _color: Color) -> Texture2D:
	var image := Image.create(8, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _snap(position: Vector2) -> Vector2:
	return position


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("FLOATING_POPUP_LIFECYCLE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
