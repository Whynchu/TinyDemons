extends SceneTree

const PALETTES := ["grey", "red", "blue", "yellow", "green", "purple", "orange", "aquamarine"]
const ARRAY_STATES := ["jump", "slam", "shocked", "shadow_jump", "shadow_slam", "shadow_attack_left", "shadow_attack_right", "shadow_spawn", "shadow_shocked"]

func _initialize() -> void:
	var failures: Array[String] = []
	SlimeVisualComponent.frame_set_cache.clear()
	SlimeVisualComponent.recolor_cache.clear()
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
		_expect(_image_differs(frames[0] as Texture2D, green_jump[0] as Texture2D), "%s recolors boss pixels" % palette, failures)
	if failures.is_empty():
		print("BOSS_VISUAL_PALETTE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _warm(_texture: Texture2D) -> void:
	pass

func _image_differs(left: Texture2D, right: Texture2D) -> bool:
	var left_image := left.get_image()
	var right_image := right.get_image()
	if left_image.get_size() != right_image.get_size():
		return true
	for y in left_image.get_height():
		for x in left_image.get_width():
			if not left_image.get_pixel(x, y).is_equal_approx(right_image.get_pixel(x, y)):
				return true
	return false

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
