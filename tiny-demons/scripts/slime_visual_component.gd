extends Node
class_name SlimeVisualComponent

var left_texture: Texture2D = null
var right_texture: Texture2D = null
var attack_left_frames: Array[Texture2D] = []
var attack_right_frames: Array[Texture2D] = []


func recolor_attack_frames(source_frames: Array[Texture2D], palette: String, texture_cache: Dictionary) -> Array[Texture2D]:
	var recolored: Array[Texture2D] = []
	for texture in source_frames:
		var image: Image = texture_cache.get(texture, texture.get_image()).duplicate()
		for y in image.get_height():
			for x in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a <= 0.0:
					continue
				var key := "%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]
				var mapped := _palette_color(color, key, palette)
				image.set_pixel(x, y, Color(mapped.r, mapped.g, mapped.b, color.a))
		recolored.append(ImageTexture.create_from_image(image))
	return recolored


func _palette_color(original: Color, key: String, palette: String) -> Color:
	var mapping := {
		"red": {"257179": Color8(93, 39, 93), "38B764": Color8(177, 62, 83), "A7F070": Color8(239, 125, 87)},
		"blue": {"257179": Color8(41, 54, 111), "38B764": Color8(59, 93, 201), "A7F070": Color8(65, 166, 246)},
	}
	return (mapping.get(palette, {}) as Dictionary).get(key, original)
