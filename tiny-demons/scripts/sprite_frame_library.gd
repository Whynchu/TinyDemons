extends RefCounted
class_name SpriteFrameLibrary

## Shared image-to-frame preparation for actors and effects.
## The library owns source-image caching so callers do not need gameplay state.

const EFFECT_RESOLUTION_SCALE := 2

var image_cache: Dictionary = {}


func slice_frames(path: String, frame_size: Vector2i) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if not ResourceLoader.exists(path):
		return frames
	var texture := load(path) as Texture2D
	if texture == null:
		return frames
	var sheet := _cached_image(texture)
	var frame_count := int(float(sheet.get_width()) / float(frame_size.x))
	for frame_index in range(frame_count):
		var frame := Image.create_empty(frame_size.x, frame_size.y, false, sheet.get_format())
		frame.blit_rect(
			sheet,
			Rect2i(frame_index * frame_size.x, 0, frame_size.x, frame_size.y),
			Vector2i.ZERO
		)
		frames.append(ImageTexture.create_from_image(frame))
	return frames


func dither_roll_dust_frame(source: Texture2D, dissolve: float) -> Texture2D:
	var source_image := _cached_image(source)
	var image := source_image.duplicate()
	image.resize(source_image.get_width() * EFFECT_RESOLUTION_SCALE, source_image.get_height() * EFFECT_RESOLUTION_SCALE, Image.INTERPOLATE_NEAREST)
	var bayer := PackedInt32Array([0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5])
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var threshold := (float(bayer[(y % 4) * 4 + x % 4]) + 1.0) / 16.0
			if threshold <= dissolve:
				color.a = 0.0
				image.set_pixel(x, y, color)
	return _effect_texture_with_display_size(image, source_image.get_size())


func flip_frames(frames: Array[Texture2D]) -> Array[Texture2D]:
	var flipped_frames: Array[Texture2D] = []
	for texture in frames:
		var image := _cached_image(texture).duplicate()
		image.flip_x()
		flipped_frames.append(ImageTexture.create_from_image(image))
	return flipped_frames


func flip_effect_frames(frames: Array[Texture2D], display_size: Vector2i) -> Array[Texture2D]:
	var flipped_frames: Array[Texture2D] = []
	for texture in frames:
		var image := _cached_image(texture).duplicate()
		image.flip_x()
		flipped_frames.append(_effect_texture_with_display_size(image, display_size))
	return flipped_frames


func recolor_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]:
	var recolored: Array[Texture2D] = []
	for texture in frames:
		recolored.append(recolor_texture(texture, palette_name))
	return recolored


func recolor_texture(source: Texture2D, palette_name: String) -> Texture2D:
	if source == null:
		return null
	var palette := {
		"blue": [Color8(41, 54, 111), Color8(59, 93, 201), Color8(244, 244, 244)],
		"orange": [Color8(171, 82, 54), Color8(239, 125, 87), Color8(244, 244, 244)],
		"green": [Color8(37, 113, 121), Color8(56, 183, 100), Color8(244, 244, 244)],
		"red": [Color8(93, 39, 93), Color8(177, 62, 83), Color8(244, 244, 244)],
		"yellow": [Color8(181, 97, 55), Color8(255, 205, 117), Color8(244, 244, 244)],
		"grey": [Color8(59, 63, 82), Color8(86, 108, 134), Color8(244, 244, 244)],
		"purple": [Color8(67, 47, 102), Color8(118, 78, 142), Color8(244, 244, 244)],
		"aquamarine": [Color8(39, 84, 116), Color8(58, 138, 151), Color8(244, 244, 244)],
	}
	var target: Array = palette.get(palette_name, palette["blue"])
	var image := _cached_image(source).duplicate()
	var source_colors: Array[Color] = [Color8(41, 54, 111), Color8(59, 93, 201), Color8(244, 244, 244)]
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			for color_index in source_colors.size():
				if _rgb_key(color) == _rgb_key(source_colors[color_index]):
					var replacement: Color = target[color_index]
					image.set_pixel(x, y, Color(replacement.r, replacement.g, replacement.b, color.a))
					break
	return ImageTexture.create_from_image(image)


func _cached_image(texture: Texture2D) -> Image:
	if texture == null:
		return Image.create_empty(0, 0, false, Image.FORMAT_RGBA8)
	if image_cache.has(texture):
		return image_cache[texture] as Image
	var image := texture.get_image()
	image_cache[texture] = image
	return image


func _effect_texture_with_display_size(image: Image, display_size: Vector2i) -> ImageTexture:
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(display_size)
	return texture


func _rgb_key(color: Color) -> String:
	return "%02X%02X%02X" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0))]
