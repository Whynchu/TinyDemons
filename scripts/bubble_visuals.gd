extends RefCounted
class_name BubbleVisuals


static func texture(cache: Dictionary, cache_prefix: String, base_color: Color, accent_color: Color, size: int) -> Texture2D:
	var normalized_size := maxi(size, 3)
	var key := "%s:%s:%s:%d" % [cache_prefix, base_color.to_html(false), accent_color.to_html(false), normalized_size]
	if cache.has(key):
		return cache[key] as Texture2D
	var image := Image.create(normalized_size, normalized_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := float(normalized_size - 1) * 0.5
	var white := PaletteLibrary.white()
	for y in normalized_size:
		for x in normalized_size:
			if not _contains(normalized_size, x, y):
				continue
			var on_rim := not (
				_contains(normalized_size, x - 1, y)
				and _contains(normalized_size, x + 1, y)
				and _contains(normalized_size, x, y - 1)
				and _contains(normalized_size, x, y + 1)
			)
			var color := Color(base_color.r, base_color.g, base_color.b, 0.48)
			if on_rim:
				color = Color(accent_color.r, accent_color.g, accent_color.b, 0.92)
			elif absi(x - (int(center) + 1)) + absi(y - (int(center) - 1)) <= 1:
				color = Color(white.r, white.g, white.b, 0.94)
			image.set_pixel(x, y, color)
	var result := ImageTexture.create_from_image(image)
	cache[key] = result
	return result


static func _contains(size: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	var center := float(size - 1) * 0.5
	var radius := float(size) * 0.5
	var dx := float(x) - center
	var dy := float(y) - center
	return dx * dx + dy * dy <= radius * radius
