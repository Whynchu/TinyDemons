extends Node
class_name OcclusionRenderer

var occluders: Array[Sprite2D] = []
var cached_images: Dictionary = {}
var texture_image_cache: Dictionary = {}
var effect_image_cache: Dictionary = {}
var highlighted_image_cache: Dictionary = {}
var grey_highlighted_image_cache: Dictionary = {}
var white_image_cache: Dictionary = {}
# The pixel Images above are cached, but their ImageTexture wrappers are not:
# set_actor_base_texture would upload a fresh GPU texture on every animation
# frame change. These caches key the wrapper by source texture so an already
# processed frame is reused instead of re-uploaded.
var effect_texture_cache: Dictionary = {}
var highlighted_effect_texture_cache: Dictionary = {}
var grey_highlighted_effect_texture_cache: Dictionary = {}
var white_effect_texture_cache: Dictionary = {}
var highlighted_texture_cache: Dictionary = {}
var orb_highlighted_texture_cache: Dictionary = {}
var occluded_actor_textures: Dictionary = {}
var highlighted_actor_textures: Dictionary = {}
var grey_highlighted_actor_textures: Dictionary = {}
var white_actor_textures: Dictionary = {}
var actor_default_textures: Dictionary = {}
var actor_default_materials: Dictionary = {}
var original_actor_textures: Dictionary = {}
var original_actor_images: Dictionary = {}
var original_actor_scales: Dictionary = {}
var actor_visual_scales: Dictionary = {}
var sprite_images: Dictionary = {}
var actor_occlusion_grace: Dictionary = {}
var resolution_scale := 2


func set_occluders(new_occluders: Array[Sprite2D]) -> void:
	occluders = new_occluders.duplicate()


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
	grey_highlighted_actor_textures.clear()
	white_actor_textures.clear()
	sprite_images.clear()
	for actor in actors:
		_register_sprite(actor)
	for occluder in occluder_sprites:
		if not sprite_images.has(occluder):
			sprite_images[occluder] = cached_texture_image(occluder.texture)


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
	occluded_actor_textures[actor] = effect_texture_for(actor.texture, image)
	actor_occlusion_grace[actor] = 0.0
	highlighted_actor_textures[actor] = highlighted_effect_texture_for(actor.texture, image)
	grey_highlighted_actor_textures[actor] = grey_highlighted_effect_texture_for(actor.texture, image)
	white_actor_textures[actor] = white_effect_texture_for(actor.texture, image)


func set_actor_base_texture(actor: Sprite2D, texture: Texture2D) -> void:
	if texture == null: return
	if original_actor_textures.get(actor) == texture:
		actor.texture = texture; return
	original_actor_textures[actor] = texture
	var image := cached_texture_image(texture)
	original_actor_images[actor] = image; sprite_images[actor] = image
	occluded_actor_textures[actor] = effect_texture_for(texture, image)
	highlighted_actor_textures[actor] = highlighted_effect_texture_for(texture, image)
	grey_highlighted_actor_textures[actor] = grey_highlighted_effect_texture_for(texture, image)
	white_actor_textures[actor] = white_effect_texture_for(texture, image); actor.texture = texture


func white_texture(source: Texture2D) -> Texture2D:
	if source == null: return null
	# Runtime animation frames have no resource path, so resource_path made every
	# generated texture share one cache entry (and could show a slime during the
	# player's death flash). The RID remains unique for each texture instance.
	var key := "%s:white_texture" % source.get_rid()
	if white_image_cache.has(key): return white_image_cache[key]
	var image := cached_texture_image(source).duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.0: image.set_pixel(x, y, Color(1, 1, 1, color.a))
	var texture := ImageTexture.create_from_image(image); white_image_cache[key] = texture; return texture


func highlighted_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	if highlighted_texture_cache.has(source):
		return highlighted_texture_cache[source] as Texture2D
	var image := cached_texture_image(source)
	var texture := effect_texture_with_display_size(cached_highlighted_image(source, image), image.get_size())
	highlighted_texture_cache[source] = texture
	return texture


func orb_highlighted_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	if orb_highlighted_texture_cache.has(source):
		return orb_highlighted_texture_cache[source] as Texture2D
	var image := cached_texture_image(source)
	var texture := effect_texture_with_display_size(make_orb_highlighted_effect_image(image), image.get_size() + Vector2i(2, 2))
	orb_highlighted_texture_cache[source] = texture
	return texture


func apply_unoccluded_actor_texture(actor: Sprite2D, is_target: bool, use_grey_highlight: bool, delta: float, apply_actor_scale: Callable, _grace_duration: float) -> void:
	var grace := maxf(float(actor_occlusion_grace.get(actor, 0.0)) - delta, 0.0)
	actor_occlusion_grace[actor] = grace
	if grace > 0.0 and actor.texture == occluded_actor_textures.get(actor):
		apply_actor_scale.call(actor, true)
		return
	if is_target:
		actor.texture = grey_highlighted_actor_textures[actor] if use_grey_highlight else highlighted_actor_textures[actor]
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
	target_focus_lost: bool,
	delta: float,
	release_grace: float,
	is_flashing: Callable,
	depth_key: Callable,
	source_rect: Callable,
	build_exact_texture: Callable,
	apply_actor_scale: Callable,
	restore_actor_scale: Callable
) -> void:
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
		var use_grey_highlight := is_target and target_focus_lost
		var actor_depth := float(depth_key.call(actor))
		var actor_rect := source_rect.call(actor) as Rect2
		var occlusion_candidates := active_occluders_for(actor, occluder_sprites, actor_depth, actor_rect, depth_key, source_rect)
		var active_occluders := occlusion_candidates["occluders"] as Array[Sprite2D]
		var highest_occluder_z := int(occlusion_candidates["highest_z"])
		if active_occluders.is_empty():
			apply_unoccluded_actor_texture(actor, is_target, use_grey_highlight, delta, apply_actor_scale, release_grace)
			continue
		var texture := build_exact_texture.call(actor, active_occluders, is_target, use_grey_highlight) as Texture2D
		if texture == null:
			apply_unoccluded_actor_texture(actor, is_target, use_grey_highlight, delta, apply_actor_scale, release_grace)
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


func cached_grey_highlighted_image(texture: Texture2D, source_image: Image) -> Image:
	if grey_highlighted_image_cache.has(texture):
		return grey_highlighted_image_cache[texture]
	var image := make_grey_highlighted_effect_image(source_image)
	grey_highlighted_image_cache[texture] = image
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


func make_full_highlighted_effect_image(source_image: Image) -> Image:
	var image := make_effect_image(source_image)
	apply_pixel_outline(image, resolution_scale, Color.WHITE, true)
	return image


func make_orb_highlighted_effect_image(source_image: Image) -> Image:
	# Build the stepped outline at the art's native resolution first.  Expanding
	# the already-upscaled image causes diagonal samples to smear into sideways
	# bars instead of reading as individual pixel steps.
	# The authored orb touches the edge of its 9x9 frame, so it needs a one-pixel
	# transparent border before the outline pass or the left/right silhouette
	# cannot be drawn at all.
	var outlined := Image.create_empty(source_image.get_width() + 2, source_image.get_height() + 2, false, source_image.get_format())
	for y in source_image.get_height():
		for x in source_image.get_width():
			outlined.set_pixel(x + 1, y + 1, source_image.get_pixel(x, y))
	# Match the slime highlight exactly: cardinal neighbors produce the clean
	# stepped pixel edge, while diagonal neighbors make the corners fill in.
	apply_pixel_outline(outlined, 1, Color.WHITE)
	return make_effect_image(outlined)


func make_grey_highlighted_effect_image(source_image: Image) -> Image:
	var image := make_effect_image(source_image)
	apply_pixel_outline(image, resolution_scale, Color8(150, 150, 150))
	return image


func make_white_image(source_image: Image) -> Image:
	var image := Image.create_empty(source_image.get_width(), source_image.get_height(), false, source_image.get_format())
	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			var color := source_image.get_pixel(x, y)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, color.a) if color.a > 0.05 else Color(0.0, 0.0, 0.0, 0.0))
	return image


func apply_pixel_outline(image: Image, pixel_size: int = 1, outline_color: Color = Color.WHITE, include_diagonals: bool = false) -> void:
	var outline_points: Array[Vector2i] = []
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.05 and has_opaque_neighbor(image, x, y, pixel_size, include_diagonals):
				outline_points.append(Vector2i(x, y))
	for point in outline_points:
		image.set_pixel(point.x, point.y, outline_color)


## Warms every occlusion-derived image for a texture in one pass, sharing the
## upscale and the silhouette outline scan across the highlighted variants.  This
## is ~3x faster than warming each cache independently, so pre-warming all
## palettes at startup is cheap and no runtime palette swap (fire color or the
## grey-on-empty-MP state) triggers a first-use image-processing hitch.
func warm_actor_texture(texture: Texture2D) -> void:
	var source := cached_texture_image(texture)
	var effect := make_effect_image(source)
	effect_image_cache[texture] = effect
	var w := effect.get_width()
	var h := effect.get_height()
	var px := resolution_scale
	var outline_points: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if effect.get_pixel(x, y).a > 0.05:
				continue
			var edge := false
			if x - px >= 0 and effect.get_pixel(x - px, y).a > 0.05: edge = true
			elif x + px < w and effect.get_pixel(x + px, y).a > 0.05: edge = true
			elif y - px >= 0 and effect.get_pixel(x, y - px).a > 0.05: edge = true
			elif y + px < h and effect.get_pixel(x, y + px).a > 0.05: edge = true
			if edge:
				outline_points.append(Vector2i(x, y))
	var highlighted := effect.duplicate()
	for point in outline_points:
		highlighted.set_pixel(point.x, point.y, Color.WHITE)
	highlighted_image_cache[texture] = highlighted
	var grey_highlighted := effect.duplicate()
	for point in outline_points:
		grey_highlighted.set_pixel(point.x, point.y, Color8(150, 150, 150))
	grey_highlighted_image_cache[texture] = grey_highlighted
	white_image_cache[texture] = make_white_image(source)



func has_opaque_neighbor(image: Image, x: int, y: int, pixel_size: int, include_diagonals: bool = false) -> bool:
	var offsets := [Vector2i(-pixel_size, 0), Vector2i(pixel_size, 0), Vector2i(0, -pixel_size), Vector2i(0, pixel_size)]
	if include_diagonals:
		offsets.append_array([Vector2i(-pixel_size, -pixel_size), Vector2i(pixel_size, -pixel_size), Vector2i(-pixel_size, pixel_size), Vector2i(pixel_size, pixel_size)])
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


func effect_texture_for(texture: Texture2D, source_image: Image) -> ImageTexture:
	var cached: Variant = effect_texture_cache.get(texture)
	if cached != null:
		return cached as ImageTexture
	var result := effect_texture_with_display_size(cached_effect_image(texture, source_image), source_image.get_size())
	effect_texture_cache[texture] = result
	return result


func highlighted_effect_texture_for(texture: Texture2D, source_image: Image) -> ImageTexture:
	var cached: Variant = highlighted_effect_texture_cache.get(texture)
	if cached != null:
		return cached as ImageTexture
	var result := effect_texture_with_display_size(cached_highlighted_image(texture, source_image), source_image.get_size())
	highlighted_effect_texture_cache[texture] = result
	return result


func grey_highlighted_effect_texture_for(texture: Texture2D, source_image: Image) -> ImageTexture:
	var cached: Variant = grey_highlighted_effect_texture_cache.get(texture)
	if cached != null:
		return cached as ImageTexture
	var result := effect_texture_with_display_size(cached_grey_highlighted_image(texture, source_image), source_image.get_size())
	grey_highlighted_effect_texture_cache[texture] = result
	return result


func white_effect_texture_for(texture: Texture2D, source_image: Image) -> ImageTexture:
	var cached: Variant = white_effect_texture_cache.get(texture)
	if cached != null:
		return cached as ImageTexture
	var result := ImageTexture.create_from_image(cached_white_image(texture, source_image))
	white_effect_texture_cache[texture] = result
	return result


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


func build_exact_occluded_actor_texture(actor: Sprite2D, active_occluders: Array[Sprite2D], is_target: bool, use_grey_highlight: bool, is_pixel_covered: Callable, actor_visual_offset: Callable) -> Texture2D:
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
	if not any_occluded_pixel and not is_target:
		return null
	if is_target:
		apply_pixel_outline(result_image, resolution_scale, Color8(150, 150, 150) if use_grey_highlight else Color.WHITE)
	var texture := occluded_actor_textures[actor] as ImageTexture
	texture.set_image(result_image)
	texture.set_size_override(source_image.get_size())
	return texture
