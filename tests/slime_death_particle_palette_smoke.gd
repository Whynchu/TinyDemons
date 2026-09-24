extends SceneTree

const EffectsSpawnerScript = preload("res://scripts/effects_spawner.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var source := load("res://assets/artwork/SlimeGreenRight.png") as Texture2D
	_expect(source != null, "green slime source art loads for death-particle coverage", failures)
	if source != null:
		for palette in ["grey", "red", "blue", "purple"]:
			var mapped := EffectsSpawnerScript.slime_death_particle_color(PaletteLibrary.normal("green"), palette)
			_expect(mapped.is_equal_approx(PaletteLibrary.normal(palette)), "%s death particles map the slime normal tone" % palette, failures)

		var effects := EffectsSpawnerScript.new()
		root.add_child(effects)
		var random_source := RandomNumberGenerator.new()
		random_source.seed = 731
		effects.spawn_slime_death_particles(root, source, Vector2.ZERO, 1, 256, 8.0, 16.0, 0.4, random_source, Callable(self, "_pixel_texture"), "grey")
		var grey_colors := [PaletteLibrary.shadow("grey"), PaletteLibrary.normal("grey"), PaletteLibrary.accent("grey")]
		var saw_mapped_color := false
		var saw_green_source := false
		for particle_data: Dictionary in effects.pixel_particles:
			var particle := particle_data.get("sprite") as Sprite2D
			var image := particle.texture.get_image() if particle != null and particle.texture != null else null
			if image == null:
				continue
			var color := image.get_pixel(0, 0)
			for expected in grey_colors:
				if color.is_equal_approx(expected as Color):
					saw_mapped_color = true
			for source_color in [PaletteLibrary.shadow("green"), PaletteLibrary.normal("green"), PaletteLibrary.accent("green")]:
				if color.is_equal_approx(source_color as Color):
					saw_green_source = true
		_expect(saw_mapped_color, "neutral slime death particles use the neutral palette", failures)
		_expect(not saw_green_source, "neutral slime death particles do not leak green source pixels", failures)
		effects.queue_free()
		await process_frame
	_finish(failures)


func _pixel_texture(color: Color, size: int = 1) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SLIME_DEATH_PARTICLE_PALETTE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
