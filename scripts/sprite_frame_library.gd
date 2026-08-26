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


## Recolors flame frames to a palette using the flame's own source colors:
## the darkest (base red) becomes the palette NORMAL, the mid (orange) becomes
## the palette ACCENT, and the brightest (yellow) becomes the lightened tip.
func recolor_fire_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]:
	var target: Array[Color] = PaletteLibrary.fire_triple(palette_name)
	var source := [PaletteLibrary.NORMAL["red"], PaletteLibrary.NORMAL["orange"], PaletteLibrary.NORMAL["yellow"]]
	var source_keys: Array[int] = []
	for source_color: Color in source:
		source_keys.append(_rgb_int(source_color))
	var recolored: Array[Texture2D] = []
	for texture in frames:
		if texture == null:
			continue
		var image := _cached_image(texture).duplicate()
		for y in image.get_height():
			for x in image.get_width():
				var color: Color = image.get_pixel(x, y)
				var key := _rgb_int(color)
				for color_index in source.size():
					if key == source_keys[color_index]:
						var replacement: Color = target[color_index]
						image.set_pixel(x, y, Color(replacement.r, replacement.g, replacement.b, color.a))
						break
		recolored.append(ImageTexture.create_from_image(image))
	return recolored


## Recolors the Entry Orb art while preserving its white highlight.
## The grey state uses the authored artwork directly. Colored states use the
## grayscale sheet as a luminance ramp for the selected puzzle palette.
func recolor_orb_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]:
	if palette_name == "grey":
		return frames
	var target: Array[Color] = []
	target = [PaletteLibrary.shadow(palette_name), PaletteLibrary.normal(palette_name), PaletteLibrary.accent(palette_name)]
	var recolored: Array[Texture2D] = []
	for texture in frames:
		if texture == null:
			continue
		var image := _cached_image(texture).duplicate()
		var minimum_luminance := 1.0
		var maximum_luminance := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var sample: Color = image.get_pixel(x, y)
				if sample.a <= 0.0 or _is_orb_white(sample):
					continue
				var sample_luminance := sample.r * 0.299 + sample.g * 0.587 + sample.b * 0.114
				minimum_luminance = minf(minimum_luminance, sample_luminance)
				maximum_luminance = maxf(maximum_luminance, sample_luminance)
		var luminance_span := maxf(maximum_luminance - minimum_luminance, 0.001)
		for y in image.get_height():
			for x in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a <= 0.0:
					continue
				if _is_orb_white(color):
					image.set_pixel(x, y, Color.WHITE * Color(1.0, 1.0, 1.0, color.a))
					continue
				var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
				var tone := clampf((luminance - minimum_luminance) / luminance_span, 0.0, 1.0)
				var replacement: Color = target[0].lerp(target[1], tone * 2.0) if tone < 0.5 else target[1].lerp(target[2], (tone - 0.5) * 2.0)
				image.set_pixel(x, y, Color(replacement.r, replacement.g, replacement.b, color.a))
		recolored.append(ImageTexture.create_from_image(image))
	return recolored


func _is_orb_white(color: Color) -> bool:
	# The authored white is the game's 244/255 white, not literal 1.0 white.
	# Keep it out of the palette ramp so the orb's glint stays pure white.
	return color.r >= 0.94 and color.g >= 0.94 and color.b >= 0.94


func recolor_texture(source: Texture2D, palette_name: String) -> Texture2D:
	if source == null:
		return null
	var cache_key := "%d:%s" % [source.get_instance_id(), palette_name]
	if recolor_cache.has(cache_key):
		return recolor_cache[cache_key] as Texture2D
	var target: Array[Color] = PaletteLibrary.triple(palette_name)
	var image := _cached_image(source).duplicate()
	var source_colors: Array[Color] = PaletteLibrary.triple("blue")
	var source_keys: Array[int] = []
	for source_color: Color in source_colors:
		source_keys.append(_rgb_int(source_color))
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			var key := _rgb_int(color)
			for color_index in source_colors.size():
				if key == source_keys[color_index]:
					var replacement: Color = target[color_index]
					image.set_pixel(x, y, Color(replacement.r, replacement.g, replacement.b, color.a))
					break
	var texture := ImageTexture.create_from_image(image)
	recolor_cache[cache_key] = texture
	return texture


## Recolors the neutral closed Orb-door art into the semantic map-door color.
## The source asset uses the grey normal/highlight pair, so this intentionally
## does not use recolor_texture(), whose source contract is the blue actor pair.
func recolor_door_texture(source: Texture2D, palette_name: String) -> Texture2D:
	if source == null:
		return null
	var cache_key := "door:%d:%s" % [source.get_instance_id(), palette_name]
	if recolor_cache.has(cache_key):
		return recolor_cache[cache_key] as Texture2D
	var source_colors: Array[Color] = [PaletteLibrary.normal("grey"), PaletteLibrary.accent("grey")]
	var target_colors: Array[Color] = [PaletteLibrary.normal(palette_name), _door_highlight(palette_name)]
	var source_keys: Array[int] = []
	for source_color: Color in source_colors:
		source_keys.append(_rgb_int(source_color))
	var image := _cached_image(source).duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			var key := _rgb_int(color)
			for color_index in source_keys.size():
				if key == source_keys[color_index]:
					var replacement: Color = target_colors[color_index]
					image.set_pixel(x, y, Color(replacement.r, replacement.g, replacement.b, color.a))
					break
	var texture := ImageTexture.create_from_image(image)
	recolor_cache[cache_key] = texture
	return texture


func _door_highlight(palette_name: String) -> Color:
	if palette_name == "green":
		return Color8(167, 240, 112)
	return PaletteLibrary.accent(palette_name)


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


func _rgb_int(color: Color) -> int:
	return (int(round(color.r * 255.0)) << 16) | (int(round(color.g * 255.0)) << 8) | int(round(color.b * 255.0))
