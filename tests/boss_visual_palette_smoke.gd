extends SceneTree

const PALETTES := ["grey", "red", "blue", "yellow", "green", "purple", "orange", "aquamarine"]
const ARRAY_STATES := ["jump", "slam", "shocked", "shadow_jump", "shadow_slam", "shadow_attack_left", "shadow_attack_right", "shadow_spawn", "shadow_shocked"]
const MATERIAL_SCRIPT := preload("res://scripts/actor_palette_material.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	SlimeVisualComponent.frame_set_cache.clear()
	MATERIAL_SCRIPT.clear_cache()
	var library := SlimeVisualComponent._boss_ability_frame_library(SpriteFrameLibrary.new(), {}, Callable(self, "_warm"))
	for palette in PALETTES:
		_expect(library.has(palette), "%s boss palette exists" % palette, failures)
		var palette_set := library.get(palette, {}) as Dictionary
		_expect(palette_set.get("shadow_idle") is Texture2D, "%s idle shadow exists" % palette, failures)
		for state in ARRAY_STATES:
			var frames := palette_set.get(state, []) as Array
			_expect(not frames.is_empty(), "%s %s frames exist" % [palette, state], failures)
			for texture in frames:
				_expect(texture is Texture2D and (texture as Texture2D).get_width() > 0, "%s %s frame is valid" % [palette, state], failures)
	var green_jump := (library["green"] as Dictionary)["jump"] as Array
	for palette in PALETTES:
		if palette == "green":
			continue
		var frames := (library[palette] as Dictionary)["jump"] as Array
		_expect(frames.size() == green_jump.size(), "%s preserves boss frame count" % palette, failures)
		_expect((frames[0] as Texture2D).get_rid() == (green_jump[0] as Texture2D).get_rid(), "%s reuses the shared green boss frames" % palette, failures)
		var material := MATERIAL_SCRIPT.for_slime_palette(palette)
		var to_colors: PackedColorArray = material.get_shader_parameter("to_color")
		_expect(to_colors.size() >= 3 and to_colors[1].is_equal_approx(PaletteLibrary.normal(palette)), "%s shader targets its canonical normal tone" % palette, failures)
	if failures.is_empty():
		print("BOSS_VISUAL_PALETTE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _warm(_texture: Texture2D) -> void:
	pass

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
