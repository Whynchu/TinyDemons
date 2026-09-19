extends SceneTree

## Characterizes that the GPU palette-swap material reproduces the legacy CPU
## actor recolor exactly, for every palette, before the player animation path is
## migrated to it. The actor recolor rule is:
##   source shadow("blue") -> target shadow(palette)
##   source normal("blue") -> target normal(palette)
##   source white           -> white
##   source eye highlight   -> target shadow(palette) for green/yellow, else normal

const MATERIAL_SCRIPT := preload("res://scripts/actor_palette_material.gd")


func _initialize() -> void:
	var library := SpriteFrameLibrary.new()
	var source: Array[Color] = PaletteLibrary.triple("blue")
	var eye: Color = SpriteFrameLibrary.PLAYER_EYE_HIGHLIGHT_COLOR
	var samples: Array[Color] = [source[0], source[1], source[2], eye, Color8(1, 2, 3)]
	var image := Image.create(samples.size(), 1, false, Image.FORMAT_RGBA8)
	for index in samples.size():
		image.set_pixel(index, 0, samples[index])
	var texture := ImageTexture.create_from_image(image)
	var failures := 0
	var shader := MATERIAL_SCRIPT.for_palette("blue").shader
	var shader_code := shader.code if shader != null else ""
	if "COLOR = tex * COLOR" in shader_code or not "COLOR = tex * vertex_tint" in shader_code:
		failures += 1
		push_error("PALETTE_MATERIAL_PARITY_FAIL shader must preserve vertex tint without multiplying the source texture twice")
	var palettes: Array = PaletteLibrary.PALETTE_NAMES
	for palette_value in palettes:
		var palette := String(palette_value)
		library.recolor_cache.clear()
		var expected_texture := library.recolor_texture(texture, palette)
		var expected_image := expected_texture.get_image()
		var material: ShaderMaterial = MATERIAL_SCRIPT.for_palette(palette)
		var from_colors: PackedColorArray = material.get_shader_parameter("from_color")
		var to_colors: PackedColorArray = material.get_shader_parameter("to_color")
		for index in samples.size():
			var expected := expected_image.get_pixel(index, 0)
			var mapped := samples[index]
			for pair in from_colors.size():
				if _matches(mapped, from_colors[pair]):
					mapped = to_colors[pair]
					break
			if not _matches(expected, mapped):
				failures += 1
				push_error("PALETTE_MATERIAL_PARITY_FAIL palette=%s sample=%d expected=%s mapped=%s" % [palette, index, expected, mapped])
	if failures == 0:
		print("PALETTE_MATERIAL_PARITY_SMOKE_OK palettes=%d samples=%d" % [palettes.size(), samples.size()])
	else:
		print("PALETTE_MATERIAL_PARITY_SMOKE_FAILED failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _matches(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.002
