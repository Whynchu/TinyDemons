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


func register_sprites(actors: Array[Sprite2D], occluder_sprites: Array[Sprite2D]) -> void:
	original_actor_textures.clear()
	actor_default_textures.clear()
	actor_default_materials.clear()
	original_actor_images.clear()
	original_actor_scales.clear()
	actor_visual_scales.clear()
	occluded_actor_textures.clear()
	actor_occlusion_grace.clear()
	highlighted_actor_textures.clear()
	white_actor_textures.clear()
	sprite_images.clear()
	for actor in actors:
		_register_sprite(actor)
	for occluder in occluder_sprites:
		if not sprite_images.has(occluder):
			sprite_images[occluder] = cached_texture_image(occluder.texture)


func register_additional_sprites(actors: Array[Sprite2D]) -> void:
	for actor in actors:
		_register_sprite(actor)


func _register_sprite(actor: Sprite2D) -> void:
	if actor == null or actor.texture == null:
		return
	actor_default_textures[actor] = actor.texture
	actor_default_materials[actor] = actor.material
	original_actor_textures[actor] = actor.texture
	original_actor_scales[actor] = actor.scale
	actor_visual_scales[actor] = Vector2.ONE
	var image := cached_texture_image(actor.texture)
	original_actor_images[actor] = image
	sprite_images[actor] = image
	occluded_actor_textures[actor] = effect_texture_with_display_size(cached_effect_image(actor.texture, image), image.get_size())
	actor_occlusion_grace[actor] = 0.0
	highlighted_actor_textures[actor] = effect_texture_with_display_size(cached_highlighted_image(actor.texture, image), image.get_size())
	white_actor_textures[actor] = ImageTexture.create_from_image(cached_white_image(actor.texture, image))


func set_actor_base_texture(actor: Sprite2D, texture: Texture2D) -> void:
	if texture == null: return
	if original_actor_textures.get(actor) == texture:
		actor.texture = texture; return
	original_actor_textures[actor] = texture
	var image := cached_texture_image(texture)
	original_actor_images[actor] = image; sprite_images[actor] = image
	occluded_actor_textures[actor] = effect_texture_with_display_size(cached_effect_image(texture, image), image.get_size())
	highlighted_actor_textures[actor] = effect_texture_with_display_size(cached_highlighted_image(texture, image), image.get_size())
	white_actor_textures[actor] = ImageTexture.create_from_image(cached_white_image(texture, image)); actor.texture = texture


func white_texture(source: Texture2D) -> Texture2D:
	if source == null: return null
	var key := "%s:white_texture" % source.resource_path
	if white_image_cache.has(key): return white_image_cache[key]
	var image := cached_texture_image(source).duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.0: image.set_pixel(x, y, Color(1, 1, 1, color.a))
	var texture := ImageTexture.create_from_image(image); white_image_cache[key] = texture; return texture


func apply_unoccluded_actor_texture(actor: Sprite2D, is_target: bool, delta: float, apply_actor_scale: Callable, _grace_duration: float) -> void:
	var grace := maxf(float(actor_occlusion_grace.get(actor, 0.0)) - delta, 0.0)
	actor_occlusion_grace[actor] = grace
	if grace > 0.0 and actor.texture == occluded_actor_textures.get(actor):
		apply_actor_scale.call(actor, true)
		return
	if is_target:
		actor.texture = highlighted_actor_textures[actor]
		apply_actor_scale.call(actor, true)
	else:
		actor.texture = original_actor_textures[actor]
		apply_actor_scale.call(actor, false)


func active_occluders_for(actor: Sprite2D, occluder_sprites: Array[Sprite2D], actor_depth: float, actor_rect: Rect2, depth_key: Callable, source_rect: Callable) -> Dictionary:
	var active_occluders: Array[Sprite2D] = []
	var highest_occluder_z := actor.z_index
	for occluder in occluder_sprites:
		# Moving actors already cross correctly through foot-based depth sorting.
		# Exact actor-on-actor masks are prohibitively expensive in crowded rooms.
		if occluder == actor or original_actor_textures.has(occluder) or float(depth_key.call(occluder)) <= actor_depth:
			continue
		var overlap := actor_rect.intersection(source_rect.call(occluder) as Rect2)
		if overlap.has_area():
			active_occluders.append(occluder)
			highest_occluder_z = maxi(highest_occluder_z, occluder.z_index)
	return {"occluders": active_occluders, "highest_z": highest_occluder_z}


func update_actor_occlusion(
	actors: Array[Sprite2D],
	occluder_sprites: Array[Sprite2D],
	player: Sprite2D,
	current_target: Sprite2D,
	delta: float,
	release_grace: float,
	is_flashing: Callable,
	depth_key: Callable,
	source_rect: Callable,
	build_exact_texture: Callable,
	apply_actor_scale: Callable,
	restore_actor_scale: Callable
) -> void:
	record_update(delta)
	for actor in actors:
		if not actor.visible:
			if actor == player:
				restore_actor_scale.call(actor)
			continue
		if bool(is_flashing.call(actor)):
			actor.texture = white_actor_textures[actor]
			apply_actor_scale.call(actor, false)
			continue
		var is_target := actor == current_target
		var actor_depth := float(depth_key.call(actor))
		var actor_rect := source_rect.call(actor) as Rect2
		var occlusion_candidates := active_occluders_for(actor, occluder_sprites, actor_depth, actor_rect, depth_key, source_rect)
		var active_occluders := occlusion_candidates["occluders"] as Array[Sprite2D]
		var highest_occluder_z := int(occlusion_candidates["highest_z"])
		if active_occluders.is_empty():
			apply_unoccluded_actor_texture(actor, is_target, delta, apply_actor_scale, release_grace)
			continue
		var texture := build_exact_texture.call(actor, active_occluders, is_target) as Texture2D
		if texture == null:
			apply_unoccluded_actor_texture(actor, is_target, delta, apply_actor_scale, release_grace)
			continue
		actor_occlusion_grace[actor] = release_grace
		actor.texture = texture
		apply_actor_scale.call(actor, true)
		if not active_occluders.has(player):
			actor.z_index = mini(highest_occluder_z + 1, 4095)


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
	apply_pixel_outline(image, resolution_scale)
	return image


func make_white_image(source_image: Image) -> Image:
	var image := Image.create_empty(source_image.get_width(), source_image.get_height(), false, source_image.get_format())
	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			var color := source_image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, color.a) if color.a > 0.05 else Color(0.0, 0.0, 0.0, 0.0))
	return image


func apply_pixel_outline(image: Image, pixel_size: int = 1) -> void:
	var outline_points: Array[Vector2i] = []
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.05 and has_opaque_cardinal_neighbor(image, x, y, pixel_size):
				outline_points.append(Vector2i(x, y))
	for point in outline_points:
		image.set_pixel(point.x, point.y, Color.WHITE)



func has_opaque_cardinal_neighbor(image: Image, x: int, y: int, pixel_size: int) -> bool:
	var offsets := [Vector2i(-pixel_size, 0), Vector2i(pixel_size, 0), Vector2i(0, -pixel_size), Vector2i(0, pixel_size)]
	for offset in offsets:
		var sample_x: int = x + offset.x
		var sample_y: int = y + offset.y
		if sample_x >= 0 and sample_y >= 0 and sample_x < image.get_width() and sample_y < image.get_height() and image.get_pixel(sample_x, sample_y).a > 0.05:
			return true
	return false


func effect_texture_with_display_size(image: Image, display_size: Vector2i) -> ImageTexture:
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(display_size)
	return texture


func is_pixel_covered_by_occluder(world_pixel: Vector2, active_occluders: Array[Sprite2D], actor_screen_scale: Callable, actor_visual_offset: Callable) -> bool:
	for occluder in active_occluders:
		var image := sprite_images.get(occluder) as Image
		if image == null:
			continue
		var local_pixel := source_pixel_position(occluder, world_pixel, actor_screen_scale, actor_visual_offset)
		var x := int(floor(local_pixel.x))
		var y := int(floor(local_pixel.y))
		if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a > 0.0:
			return true
	return false


func source_pixel_position(sprite: Sprite2D, world_pixel: Vector2, actor_screen_scale: Callable, actor_visual_offset: Callable) -> Vector2:
	var sprite_scale: Vector2 = sprite.scale
	var offset: Vector2 = sprite.offset
	if original_actor_scales.has(sprite):
		sprite_scale = actor_screen_scale.call(sprite) as Vector2
		offset = actor_visual_offset.call(sprite) as Vector2
	var local_pixel := world_pixel - sprite.global_position - offset * sprite_scale
	if sprite.centered and sprite.texture != null:
		local_pixel += sprite.texture.get_size() * sprite_scale * 0.5
	var source_pixel := Vector2(local_pixel.x / sprite_scale.x, local_pixel.y / sprite_scale.y)
	if sprite.flip_h and sprite_images.has(sprite):
		var image := sprite_images[sprite] as Image
		source_pixel.x = float(image.get_width()) - source_pixel.x - 1.0
	return source_pixel


func build_exact_occluded_actor_texture(actor: Sprite2D, active_occluders: Array[Sprite2D], include_outline: bool, is_pixel_covered: Callable, actor_visual_offset: Callable) -> Texture2D:
	var source_image := original_actor_images[actor] as Image
	var result_image := make_effect_image(source_image)
	var original_scale := original_actor_scales[actor] as Vector2
	var visual_offset := actor_visual_offset.call(actor) as Vector2
	var any_occluded_pixel := false
	for y in range(result_image.get_height()):
		for x in range(result_image.get_width()):
			var color := result_image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var source_x := (float(x) + 0.5) / float(resolution_scale)
			var source_y := (float(y) + 0.5) / float(resolution_scale)
			if actor.flip_h:
				source_x = float(source_image.get_width()) - source_x
			var world_pixel := actor.global_position + visual_offset * original_scale + Vector2(source_x, source_y) * original_scale
			if not is_pixel_covered.call(world_pixel, active_occluders):
				continue
			any_occluded_pixel = true
			if (x + y) % 2 == 0:
				color.a = 0.0
				result_image.set_pixel(x, y, color)
	if not any_occluded_pixel and not include_outline:
		return null
	if include_outline:
		apply_pixel_outline(result_image, resolution_scale)
	var texture := occluded_actor_textures[actor] as ImageTexture
	texture.set_image(result_image)
	texture.set_size_override(source_image.get_size())
	return texture
