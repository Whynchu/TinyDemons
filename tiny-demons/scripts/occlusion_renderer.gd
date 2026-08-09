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


func set_occluders(new_occluders: Array[Sprite2D]) -> void:
	occluders = new_occluders.duplicate()


func clear_cache() -> void:
	cached_images.clear()


func record_update(elapsed: float) -> void:
	update_count += 1
	update_time += maxf(elapsed, 0.0)


func average_update_time() -> float:
	return update_time / float(update_count) if update_count > 0 else 0.0
