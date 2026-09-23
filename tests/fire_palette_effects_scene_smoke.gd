extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const TEST_PALETTES := ["blue", "yellow", "purple"]

var finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed_scene := load(MAIN_SCENE) as PackedScene
	_expect(packed_scene != null, "main scene loads for fire palette coverage", failures)
	if packed_scene == null:
		_finish(failures)
		return
	var gameplay := packed_scene.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame

	var fire_light := gameplay.get_node_or_null("Actors/Props/RestFire/FireLight") as PointLight2D
	var fire := gameplay.get("rest_fire") as Sprite2D
	var effects := gameplay.get("effects_spawner") as EffectsSpawner
	_expect(fire_light != null and fire != null and effects != null, "fire glow and effect owners are composed", failures)
	if fire_light != null and fire != null and effects != null:
		var authored_texture := fire_light.texture as Texture2D
		for palette in TEST_PALETTES:
			gameplay.call("_apply_rest_fire_palette", palette)
			_expect(authored_texture != null and fire_light.texture == authored_texture, "%s keeps the renderer-safe authored glow texture" % palette, failures)
			var expected_tip: Color = PaletteLibrary.fire_triple(palette)[2]
			_expect(_rgb_close(fire_light.color, expected_tip), "%s glow color follows the flame tip color" % palette, failures)

		# Sparks read the same current flame palette at spawn and carry that
		# palette through their upward fade instead of using a fixed red ramp.
		gameplay.call("_apply_rest_fire_palette", "blue")
		fire.visible = true
		effects.fire_spark_timer = 0.0
		effects.update_fire_sparks_from_root(gameplay, 0.0)
		var spark_data: Dictionary = {}
		for particle_value in effects.pixel_particles:
			var particle_candidate := particle_value as Dictionary
			if bool(particle_candidate.get("fire_spark", false)):
				spark_data = particle_candidate
				break
		_expect(not spark_data.is_empty(), "fire spark spawns when the flame is visible", failures)
		if not spark_data.is_empty():
			_expect(spark_data.get("fire_palette", "") == "blue", "fire spark records the current flame palette", failures)
			var spark := spark_data.get("sprite") as Sprite2D
			var blue_tones := PaletteLibrary.fire_triple("blue")
			_expect(spark != null and spark.modulate.is_equal_approx(blue_tones[0]), "fire spark starts on the current flame tone", failures)
			var lifetime := float(spark_data.get("lifetime", 0.0))
			effects.update_pixel_particles(0.01, Callable(gameplay, "_snap_half_pixel"), 0.4)
			var updated_data: Dictionary = {}
			for particle_value in effects.pixel_particles:
				var particle_candidate := particle_value as Dictionary
				if particle_candidate.get("sprite") == spark:
					updated_data = particle_candidate
					break
			if spark != null and not updated_data.is_empty():
				var progress := 1.0 - clampf(float(updated_data.get("timer", 0.0)) / lifetime, 0.0, 1.0)
				var expected_color: Color = blue_tones[0].lerp(blue_tones[2], clampf(progress / 0.35, 0.0, 1.0))
				_expect(_rgb_close(spark.modulate, expected_color), "fire spark fade remains on the current flame palette", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _rgb_close(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) <= 0.03 and absf(actual.g - expected.g) <= 0.03 and absf(actual.b - expected.b) <= 0.03


func _watchdog() -> void:
	if finished:
		return
	push_error("TEST_ABORTED: fire palette effects smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	finished = true
	if failures.is_empty():
		print("FIRE_PALETTE_EFFECTS_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
