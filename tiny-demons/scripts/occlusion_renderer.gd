extends Node
class_name OcclusionRenderer

var occluders: Array[Sprite2D] = []
var cached_images: Dictionary = {}
var texture_image_cache: Dictionary = {}
var effect_image_cache: Dictionary = {}
var highlighted_image_cache: Dictionary = {}
var white_image_cache: Dictionary = {}
var occluded_actor_textures: Dictionary = {}
var highlighted_actor_textures: Dictionary = {}
var white_actor_textures: Dictionary = {}
var actor_default_textures: Dictionary = {}
var actor_default_materials: Dictionary = {}
var original_actor_textures: Dictionary = {}
var original_actor_images: Dictionary = {}
var original_actor_scales: Dictionary = {}
var actor_visual_scales: Dictionary = {}
var sprite_images: Dictionary = {}
var actor_occlusion_grace: Dictionary = {}
var update_count := 0
var update_time := 0.0
var resolution_scale := 2


func set_occluders(new_occluders: Array[Sprite2D]) -> void:
	occluders = new_occluders.duplicate()


func clear_cache() -> void:
	cached_images.clear()


func record_update(elapsed: float) -> void:
	update_count += 1
	update_time += maxf(elapsed, 0.0)


func average_update_time() -> float:
	return update_time / float(update_count) if update_count > 0 else 0.0


func cached_texture_image(texture: Texture2D) -> Image:
	if texture_image_cache.has(texture):
		return texture_image_cache[texture]
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	texture_image_cache[texture] = image
	return image


func cached_effect_image(texture: Texture2D, source_image: Image) -> Image:
	if effect_image_cache.has(texture):
		return effect_image_cache[texture]
	var image := make_effect_image(source_image)
	effect_image_cache[texture] = image
	return image


func cached_highlighted_image(texture: Texture2D, source_image: Image) -> Image:
	if highlighted_image_cache.has(texture):
		return highlighted_image_cache[texture]
	var image := make_highlighted_effect_image(source_image)
	highlighted_image_cache[texture] = image
	return image


func cached_white_image(texture: Texture2D, source_image: Image) -> Image:
	if white_image_cache.has(texture):
		return white_image_cache[texture]
	var image := make_white_image(source_image)
	white_image_cache[texture] = image
	return image


func make_effect_image(source_image: Image) -> Image:
	var width := source_image.get_width() * resolution_scale
	var height := source_image.get_height() * resolution_scale
	var image := Image.create_empty(width, height, false, source_image.get_format())
	for y in range(height):
		for x in range(width):
			image.set_pixel(x, y, source_image.get_pixel(
				int(float(x) / float(resolution_scale)),
				int(float(y) / float(resolution_scale))
			))
	return image


func make_highlighted_effect_image(source_image: Image) -> Image:
	var image := make_effect_image(source_image)
	apply_half_pixel_outline(image)
	return image


func make_white_image(source_image: Image) -> Image:
	var image := Image.create_empty(source_image.get_width(), source_image.get_height(), false, source_image.get_format())
	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			var color := source_image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, color.a) if color.a > 0.05 else Color(0.0, 0.0, 0.0, 0.0))
	return image


func apply_half_pixel_outline(image: Image) -> void:
	var outline_points: Array[Vector2i] = []
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.05 and has_opaque_neighbor(image, x, y):
				outline_points.append(Vector2i(x, y))
	for point in outline_points:
		image.set_pixel(point.x, point.y, Color.WHITE)


func has_opaque_neighbor(image: Image, x: int, y: int) -> bool:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var sample_x := x + offset_x
			var sample_y := y + offset_y
			if sample_x >= 0 and sample_y >= 0 and sample_x < image.get_width() and sample_y < image.get_height() and image.get_pixel(sample_x, sample_y).a > 0.05:
				return true
	return false


func effect_texture_with_display_size(image: Image, display_size: Vector2i) -> ImageTexture:
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(display_size)
	return texture
