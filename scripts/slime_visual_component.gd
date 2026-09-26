@tool
extends Node
class_name SlimeVisualComponent

const ACTOR_PALETTE_MATERIAL_SCRIPT := preload("res://scripts/actor_palette_material.gd")

var left_texture: Texture2D = null
var right_texture: Texture2D = null
var attack_left_frames: Array[Texture2D] = []
var attack_right_frames: Array[Texture2D] = []
var shocked_frames: Array[Texture2D] = []
var spawn_frames: Array[Texture2D] = []
var shadow_idle_texture: Texture2D = null
var shadow_attack_left_frames: Array[Texture2D] = []
var shadow_attack_right_frames: Array[Texture2D] = []
var shadow_spawn_frames: Array[Texture2D] = []
var shadow_shocked_frames: Array[Texture2D] = []
var boss_jump_frames: Array[Texture2D] = []
var boss_slam_frames: Array[Texture2D] = []
var boss_shocked_frames: Array[Texture2D] = []
var boss_shadow_left_texture: Texture2D = null
var boss_shadow_jump_frames: Array[Texture2D] = []
var boss_shadow_slam_frames: Array[Texture2D] = []

## All runtime slime frames contain one shared green source set. Palette
## variation is applied by a shared GPU material on the slime body and floor
## shadow, including the idle direction textures.
static var frame_set_cache: Dictionary = {}
static var direction_texture_cache: Dictionary = {}
const PALETTES := ["grey", "red", "blue", "yellow", "green", "purple", "orange", "aquamarine"]


## Resolves the selected definition's explicit palette key. Variant identity
## and appearance stay separate; the variant ID is only a fallback for older
## definitions whose visual_source is not a recognized palette.
static func frame_palette_for(slime: Sprite2D) -> String:
	var variant := String(slime.get("variant"))
	var definition := EnemyFactory.definition(StringName(variant))
	return palette_for_definition(definition, variant)


static func palette_for_definition(definition: EnemyDefinition, fallback_variant: String = "") -> String:
	if definition != null and definition.visual_source in PALETTES:
		return definition.visual_source
	if definition != null:
		var definition_variant := String(definition.variant_id)
		if definition_variant in PALETTES:
			return definition_variant
	return fallback_variant if fallback_variant in PALETTES else "green"


static func direction_texture_paths(is_boss: bool) -> Array[String]:
	# Direction sprites deliberately use the green source sheet; the shared
	# palette material recolors it for each enemy definition.
	var prefix := "BOSS" if is_boss else ""
	return [
		"res://assets/artwork/%sSlimeGreenLeft.png" % prefix,
		"res://assets/artwork/%sSlimeGreenRight.png" % prefix,
	]


static func apply_palette_material(slime: Sprite2D) -> void:
	if slime == null or not is_instance_valid(slime):
		return
	if slime.get_meta("enemy_type_id", &"") == &"skeleton":
		var skeleton_palette := String(slime.get_meta("visual_source", "grey"))
		var skeleton_material: ShaderMaterial = ACTOR_PALETTE_MATERIAL_SCRIPT.for_skeleton_palette(skeleton_palette)
		if slime.material != skeleton_material:
			slime.material = skeleton_material
		return
	var palette := frame_palette_for(slime)
	var material: ShaderMaterial = null
	if palette != "green":
		material = ACTOR_PALETTE_MATERIAL_SCRIPT.for_slime_palette(palette)
	if slime.material != material:
		slime.material = material
	var shadow := slime.get_node_or_null("SlimeFloorShadow") as Sprite2D
	if shadow != null and shadow.material != material:
		shadow.material = material


static func build_direction_textures(slimes: Array[Sprite2D], paths: Dictionary, load_texture: Callable) -> void:
	for slime in slimes:
		if not paths.has(slime):
			continue
		var visual := slime.get_node_or_null("SlimeVisualComponent") as SlimeVisualComponent
		if visual == null:
			visual = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var slime_paths: Array = paths[slime]
		visual.left_texture = _cached_direction_texture(slime_paths[0], load_texture)
		visual.right_texture = _cached_direction_texture(slime_paths[1], load_texture)
		apply_palette_material(slime)


static func _cached_direction_texture(path: String, load_texture: Callable) -> Texture2D:
	if direction_texture_cache.has(path):
		return direction_texture_cache[path] as Texture2D
	var texture := load_texture.call(path) as Texture2D
	direction_texture_cache[path] = texture
	return texture


static func build_attack_frames(slimes: Array[Sprite2D], frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> void:
	var frames_by_palette := build_attack_frame_library(frame_library, frame_size, cache, warm_texture)
	assign_attack_frames(slimes, frames_by_palette)


static func build_attack_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, _cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var left_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreen_AttackL.png", frame_size)
	var right_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreen_AttackR.png", frame_size)
	var boss_left_frames := frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenAttackL.png", Vector2i(32, 32))
	var boss_right_frames := frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenAttackR.png", Vector2i(32, 32))
	var frames_by_palette := _direction_frame_sets(left_frames, right_frames)
	frames_by_palette["boss"] = _direction_frame_sets(boss_left_frames, boss_right_frames)
	for texture in left_frames:
		warm_texture.call(texture)
	for texture in right_frames:
		warm_texture.call(texture)
	for texture in boss_left_frames:
		warm_texture.call(texture)
	for texture in boss_right_frames:
		warm_texture.call(texture)
	return frames_by_palette


static func _direction_frame_sets(left_frames: Array[Texture2D], right_frames: Array[Texture2D]) -> Dictionary:
	var result := {}
	for palette in PALETTES:
		result[palette] = {"left": left_frames, "right": right_frames}
	return result


static func assign_attack_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var palette := frame_palette_for(slime)
		var source_frames: Dictionary = frames_by_palette if float(slime.get_meta("encounter_scale", 1.0)) <= 1.0 else frames_by_palette.get("boss", frames_by_palette) as Dictionary
		var palette_frames := (source_frames as Dictionary)[palette] as Dictionary
		visual.attack_left_frames = palette_frames["left"] as Array[Texture2D]
		visual.attack_right_frames = palette_frames["right"] as Array[Texture2D]


static func build_shocked_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, _cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var green_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreenshocked.png", frame_size)
	var frames_by_palette := {}
	for palette in PALETTES:
		frames_by_palette[palette] = green_frames
	for texture in green_frames:
		warm_texture.call(texture)
	return frames_by_palette


static func assign_shocked_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		visual.shocked_frames = frames_by_palette[frame_palette_for(slime)] as Array[Texture2D]


static func build_spawn_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, _cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var green_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreenSpawn.png", frame_size)
	var boss_frames_raw := frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenSpawn.png", Vector2i(32, 32))
	var frames_by_palette := {}
	for palette in PALETTES:
		frames_by_palette[palette] = green_frames
	frames_by_palette["boss"] = {}
	for palette in PALETTES:
		frames_by_palette["boss"][palette] = boss_frames_raw
	for texture in green_frames:
		warm_texture.call(texture)
	for texture in boss_frames_raw:
		warm_texture.call(texture)
	return frames_by_palette


static func assign_spawn_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var palette := frame_palette_for(slime)
		var source_frames: Dictionary = frames_by_palette if float(slime.get_meta("encounter_scale", 1.0)) <= 1.0 else frames_by_palette.get("boss", frames_by_palette) as Dictionary
		visual.spawn_frames = (source_frames as Dictionary)[palette] as Array[Texture2D]


static func assign_boss_ability_frames(slimes: Array[Sprite2D], frame_library: SpriteFrameLibrary, cache: Dictionary, warm_texture: Callable) -> void:
	var frame_sets := _boss_ability_frame_library(frame_library, cache, warm_texture)
	for slime in slimes:
		if float(slime.get_meta("encounter_scale", 1.0)) <= 1.0:
			continue
		var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			continue
		var palette := frame_palette_for(slime)
		var palette_set := frame_sets[palette] as Dictionary
		var jump: Array[Texture2D] = palette_set["jump"]
		var slam: Array[Texture2D] = palette_set["slam"]
		var shadow_jump: Array[Texture2D] = palette_set["shadow_jump"]
		var shadow_slam: Array[Texture2D] = palette_set["shadow_slam"]
		var shadow_attack_left: Array[Texture2D] = palette_set["shadow_attack_left"]
		var shadow_attack_right: Array[Texture2D] = palette_set["shadow_attack_right"]
		var shadow_spawn: Array[Texture2D] = palette_set["shadow_spawn"]
		var shadow_shocked: Array[Texture2D] = palette_set["shadow_shocked"]
		var shocked: Array[Texture2D] = palette_set["shocked"]
		visual.boss_jump_frames = jump
		visual.boss_slam_frames = slam
		visual.boss_shocked_frames = shocked
		visual.boss_shadow_jump_frames = shadow_jump
		visual.boss_shadow_slam_frames = shadow_slam
		visual.shadow_attack_left_frames = shadow_attack_left
		visual.shadow_attack_right_frames = shadow_attack_right
		visual.shadow_spawn_frames = shadow_spawn
		visual.shadow_shocked_frames = shadow_shocked
		var shadow_idle := palette_set["shadow_idle"] as Texture2D
		visual.shadow_idle_texture = shadow_idle
		visual.boss_shadow_left_texture = shadow_idle


static func assign_regular_shadow_frames(slimes: Array[Sprite2D], frame_library: SpriteFrameLibrary, cache: Dictionary, warm_texture: Callable) -> void:
	var frame_sets := _regular_shadow_frame_library(frame_library, cache, warm_texture)
	for slime in slimes:
		if float(slime.get_meta("encounter_scale", 1.0)) > 1.0:
			continue
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			continue
		var palette := frame_palette_for(slime)
		var palette_set := frame_sets[palette] as Dictionary
		visual.shadow_idle_texture = palette_set["idle"] as Texture2D
		visual.shadow_attack_left_frames = palette_set["attack_left"]
		visual.shadow_attack_right_frames = palette_set["attack_right"]
		visual.shadow_spawn_frames = palette_set["spawn"]


static func _boss_ability_frame_library(frame_library: SpriteFrameLibrary, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	const key := "boss-ability-shader-v2"
	if frame_set_cache.has(key):
		return frame_set_cache[key] as Dictionary
	var sources := {
		"jump": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenJump.png", Vector2i(32, 32)),
		"slam": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenSlam.png", Vector2i(32, 32)),
		"shadow_jump": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreen_Shadow_Jump.png", Vector2i(32, 32)),
		"shadow_slam": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreen_Shadow_Slam.png", Vector2i(32, 32)),
		"shadow_attack_left": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreen_Shadow_AttackL.png", Vector2i(32, 32)),
		"shadow_attack_right": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreen_Shadow_AttackR.png", Vector2i(32, 32)),
		"shadow_spawn": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreen_Shadow_Spawn.png", Vector2i(32, 32)),
		"shadow_shocked": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreen_Shadow_Shocked.png", Vector2i(32, 32)),
		"shocked": frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreen_Shocked.png", Vector2i(32, 32)),
		"shadow_idle": [load("res://assets/artwork/BOSSSlimeGreen_Shadow_Left.png") as Texture2D],
	}
	var result := {}
	for palette in PALETTES:
		var palette_set := {}
		for state in sources:
			var frames: Array[Texture2D] = []
			for frame in sources[state] as Array:
				frames.append(frame as Texture2D)
			palette_set[state] = frames[0] if state == "shadow_idle" and not frames.is_empty() else frames
		result[palette] = palette_set
	for state in sources:
		for frame in sources[state] as Array:
			var texture := frame as Texture2D
			if texture != null:
				warm_texture.call(texture)
	frame_set_cache[key] = result
	return result


static func _regular_shadow_frame_library(frame_library: SpriteFrameLibrary, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	const key := "regular-shadow-shader-v2"
	if frame_set_cache.has(key):
		return frame_set_cache[key] as Dictionary
	var sources := {
		"idle": frame_library.slice_frames("res://assets/artwork/SlimeGreen_Shadow_Left.png", Vector2i(16, 16)),
		"attack_left": frame_library.slice_frames("res://assets/artwork/SlimeGreen_Shadow_AttackL.png", Vector2i(16, 16)),
		"attack_right": frame_library.slice_frames("res://assets/artwork/SlimeGreen_Shadow_AttackR.png", Vector2i(16, 16)),
		"spawn": frame_library.slice_frames("res://assets/artwork/SlimeGreen_Shadow_Spawn.png", Vector2i(16, 16)),
	}
	var result := {}
	for palette in PALETTES:
		var palette_set := {}
		for state in sources:
			var frames: Array[Texture2D] = []
			for frame in sources[state] as Array:
				frames.append(frame as Texture2D)
			palette_set[state] = frames[0] if state == "idle" and not frames.is_empty() else frames
		result[palette] = palette_set
	for state in sources:
		for frame in sources[state] as Array:
			var texture := frame as Texture2D
			if texture != null:
				warm_texture.call(texture)
	frame_set_cache[key] = result
	return result


static func set_facing(occlusion_renderer: OcclusionRenderer, slime: Sprite2D, direction_x: float, set_base_texture: Callable, update_attack_guides: Callable) -> void:
	if absf(direction_x) < 0.1: return
	apply_palette_material(slime)
	var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
	var texture: Texture2D = visual.left_texture if direction_x < 0.0 and visual != null else visual.right_texture if visual != null else null
	if direction_x < 0.0: slime.flip_h = false
	elif texture == null and visual != null and visual.left_texture != null: texture = visual.left_texture; slime.flip_h = true
	else: slime.flip_h = false
	if texture == null and occlusion_renderer != null: texture = occlusion_renderer.actor_default_textures.get(slime)
	if set_base_texture.is_valid(): set_base_texture.call(slime, texture)
	if update_attack_guides.is_valid(): update_attack_guides.call(slime)


## Editor-facing squish/impact visual tuning.
@export var squish_stretch := 0.18
@export var squish_vertical_scale := 0.14
@export var squish_lateral_scale := 0.12

func squish_scale(progress: float, movement: Vector2) -> Vector2:
	var pulse := sin(clampf(progress, 0.0, 1.0) * PI)
	var stretch_x := 1.0 + pulse * squish_stretch
	var stretch_y := 1.0 - pulse * squish_vertical_scale
	if absf(movement.y) > absf(movement.x):
		stretch_x = 1.0 + pulse * squish_lateral_scale
		stretch_y = 1.0 - pulse * squish_vertical_scale
	return Vector2(stretch_x, stretch_y)
