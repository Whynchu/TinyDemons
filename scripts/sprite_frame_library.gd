extends RefCounted
class_name SpriteFrameLibrary

## Shared image-to-frame preparation for actors and effects.
## The library owns source-image caching so callers do not need gameplay state.

const EFFECT_RESOLUTION_SCALE := 2

var image_cache: Dictionary = {}
var recolor_cache: Dictionary = {}


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
	var cache_key := "%d:%s" % [source.get_instance_id(), palette_name]
	if recolor_cache.has(cache_key):
		return recolor_cache[cache_key] as Texture2D
	var target: Array[Color] = PaletteLibrary.triple(palette_name)
	var image := _cached_image(source).duplicate()
	var source_colors: Array[Color] = PaletteLibrary.triple("blue")
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			for color_index in source_colors.size():
				if _rgb_key(color) == _rgb_key(source_colors[color_index]):
					var replacement: Color = target[color_index]
					image.set_pixel(x, y, Color(replacement.r, replacement.g, replacement.b, color.a))
					break
	var texture := ImageTexture.create_from_image(image)
	recolor_cache[cache_key] = texture
	return texture


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
