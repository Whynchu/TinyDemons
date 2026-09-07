extends Node
class_name SlimeVisualComponent

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

## Palette recolor results keyed by "<source RID>:<palette>". The source Images
## are cached by the caller, but the per-pixel recolor itself was recomputed on
## every room entry and popcorn respawn; the result is deterministic, so cache it.
static var recolor_cache: Dictionary = {}
static var frame_set_cache: Dictionary = {}
static var direction_texture_cache: Dictionary = {}
const PALETTES := ["grey", "red", "blue", "yellow", "green", "purple", "orange", "aquamarine"]


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


static func _cached_direction_texture(path: String, load_texture: Callable) -> Texture2D:
	if direction_texture_cache.has(path):
		return direction_texture_cache[path] as Texture2D
	var texture := load_texture.call(path) as Texture2D
	direction_texture_cache[path] = texture
	return texture


static func recolor_direction_textures(slimes: Array[Sprite2D], palette: String, texture_cache: Dictionary) -> void:
	for slime in slimes:
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			continue
		if visual.left_texture != null:
			visual.left_texture = recolor_direction_texture(visual.left_texture, palette, texture_cache)
		if visual.right_texture != null:
			visual.right_texture = recolor_direction_texture(visual.right_texture, palette, texture_cache)


static func recolor_direction_texture(source: Texture2D, palette: String, texture_cache: Dictionary) -> Texture2D:
	var cache_key := "%d:%s" % [source.get_rid().get_id(), palette]
	if recolor_cache.has(cache_key):
		return recolor_cache[cache_key] as Texture2D
	var source_image: Image = texture_cache[source] if texture_cache.has(source) else source.get_image()
	var image: Image = source_image.duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var key := "%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]
			var mapped := _palette_color(color, key, palette)
			image.set_pixel(x, y, Color(mapped.r, mapped.g, mapped.b, color.a))
	var result := ImageTexture.create_from_image(image)
	recolor_cache[cache_key] = result
	return result


static func build_attack_frames(slimes: Array[Sprite2D], frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> void:
	var frames_by_palette := build_attack_frame_library(frame_library, frame_size, cache, warm_texture)
	assign_attack_frames(slimes, frames_by_palette)


static func build_attack_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var left_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreen_AttackL.png", frame_size)
	var right_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreen_AttackR.png", frame_size)
	var boss_left_frames := frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenAttackL.png", Vector2i(32, 32))
	var boss_right_frames := frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenAttackR.png", Vector2i(32, 32))
	var frames_by_palette := {
		"green": {"left": left_frames, "right": right_frames},
		"blue": {"left": recolor_attack_frame_set(left_frames, "blue", cache), "right": recolor_attack_frame_set(right_frames, "blue", cache)},
		"red": {"left": recolor_attack_frame_set(left_frames, "red", cache), "right": recolor_attack_frame_set(right_frames, "red", cache)},
		"grey": {"left": recolor_attack_frame_set(left_frames, "grey", cache), "right": recolor_attack_frame_set(right_frames, "grey", cache)},
		"yellow": {"left": recolor_attack_frame_set(left_frames, "yellow", cache), "right": recolor_attack_frame_set(right_frames, "yellow", cache)},
		"purple": {"left": recolor_attack_frame_set(left_frames, "purple", cache), "right": recolor_attack_frame_set(right_frames, "purple", cache)},
		"orange": {"left": recolor_attack_frame_set(left_frames, "orange", cache), "right": recolor_attack_frame_set(right_frames, "orange", cache)},
		"aquamarine": {"left": recolor_attack_frame_set(left_frames, "aquamarine", cache), "right": recolor_attack_frame_set(right_frames, "aquamarine", cache)},
	}
	var boss_frames := {}
	for palette in ["green", "blue", "red", "grey", "yellow", "purple", "orange", "aquamarine"]:
		boss_frames[palette] = {"left": boss_left_frames if palette == "green" else recolor_attack_frame_set(boss_left_frames, palette, cache), "right": boss_right_frames if palette == "green" else recolor_attack_frame_set(boss_right_frames, palette, cache)}
	frames_by_palette["boss"] = boss_frames
	for palette_frames in frames_by_palette.values():
		if not (palette_frames as Dictionary).has("left"):
			continue
		var left_palette_frames := palette_frames["left"] as Array[Texture2D]
		var right_palette_frames := palette_frames["right"] as Array[Texture2D]
		for texture in left_palette_frames: warm_texture.call(texture)
		for texture in right_palette_frames: warm_texture.call(texture)
	return frames_by_palette


static func assign_attack_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var palette := String(slime.get("variant")); if not frames_by_palette.has(palette): palette = "green"
		var source_frames: Dictionary = frames_by_palette if float(slime.get_meta("encounter_scale", 1.0)) <= 1.0 else frames_by_palette.get("boss", frames_by_palette) as Dictionary
		var palette_frames := (source_frames as Dictionary)[palette] as Dictionary
		visual.attack_left_frames = palette_frames["left"] as Array[Texture2D]
		visual.attack_right_frames = palette_frames["right"] as Array[Texture2D]


static func build_shocked_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var green_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreenshocked.png", frame_size)
	var frames_by_palette := {
		"green": green_frames,
		"blue": recolor_attack_frame_set(green_frames, "blue", cache),
		"red": recolor_attack_frame_set(green_frames, "red", cache),
		"grey": recolor_attack_frame_set(green_frames, "grey", cache),
		"yellow": recolor_attack_frame_set(green_frames, "yellow", cache),
		"purple": recolor_attack_frame_set(green_frames, "purple", cache),
		"orange": recolor_attack_frame_set(green_frames, "orange", cache),
		"aquamarine": recolor_attack_frame_set(green_frames, "aquamarine", cache),
	}
	for palette_frames in frames_by_palette.values():
		if palette_frames is Dictionary:
			continue
		for texture in palette_frames as Array[Texture2D]:
			warm_texture.call(texture)
	return frames_by_palette


static func assign_shocked_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var palette := String(slime.get("variant"))
		if not frames_by_palette.has(palette):
			palette = "green"
		visual.shocked_frames = frames_by_palette[palette] as Array[Texture2D]


static func build_spawn_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var green_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreenSpawn.png", frame_size)
	var boss_frames_raw := frame_library.slice_frames("res://assets/artwork/BOSSSlimeGreenSpawn.png", Vector2i(32, 32))
	var frames_by_palette := {
		"green": green_frames,
		"blue": recolor_attack_frame_set(green_frames, "blue", cache),
		"red": recolor_attack_frame_set(green_frames, "red", cache),
		"grey": recolor_attack_frame_set(green_frames, "grey", cache),
		"yellow": recolor_attack_frame_set(green_frames, "yellow", cache),
		"purple": recolor_attack_frame_set(green_frames, "purple", cache),
		"orange": recolor_attack_frame_set(green_frames, "orange", cache),
		"aquamarine": recolor_attack_frame_set(green_frames, "aquamarine", cache),
	}
	frames_by_palette["boss"] = {}
	for palette in ["green", "blue", "red", "grey", "yellow", "purple", "orange", "aquamarine"]:
		frames_by_palette["boss"][palette] = boss_frames_raw if palette == "green" else recolor_attack_frame_set(boss_frames_raw, palette, cache)
	for palette_frames in frames_by_palette.values():
		if palette_frames is Dictionary:
			continue
		for texture in palette_frames as Array[Texture2D]:
			warm_texture.call(texture)
	return frames_by_palette


static func assign_spawn_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual: SlimeVisualComponent = slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var palette := String(slime.get("variant"))
		if not frames_by_palette.has(palette):
			palette = "green"
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
		var palette := String(slime.get("variant"))
		if not frame_sets.has(palette): palette = "green"
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
		var palette := String(slime.get("variant"))
		if not frame_sets.has(palette): palette = "green"
		var palette_set := frame_sets[palette] as Dictionary
		visual.shadow_idle_texture = palette_set["idle"] as Texture2D
		visual.shadow_attack_left_frames = palette_set["attack_left"]
		visual.shadow_attack_right_frames = palette_set["attack_right"]
		visual.shadow_spawn_frames = palette_set["spawn"]


static func _boss_ability_frame_library(frame_library: SpriteFrameLibrary, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	const key := "boss-ability-v1"
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
			var output := frames if palette == "green" else recolor_attack_frame_set(frames, palette, cache)
			palette_set[state] = output[0] if state == "shadow_idle" and not output.is_empty() else output
			for texture in output: if texture != null: warm_texture.call(texture)
		result[palette] = palette_set
	frame_set_cache[key] = result
	return result


static func _regular_shadow_frame_library(frame_library: SpriteFrameLibrary, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	const key := "regular-shadow-v1"
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
			var output := frames if palette == "green" else recolor_attack_frame_set(frames, palette, cache)
			palette_set[state] = output[0] if state == "idle" and not output.is_empty() else output
			for texture in output: if texture != null: warm_texture.call(texture)
		result[palette] = palette_set
	frame_set_cache[key] = result
	return result


static func recolor_attack_frame_set(source_frames: Array[Texture2D], palette: String, texture_cache: Dictionary) -> Array[Texture2D]:
	var recolored: Array[Texture2D] = []
	for texture in source_frames:
		var cache_key := "slime-frame:%d:%s" % [texture.get_rid().get_id(), palette]
		if frame_set_cache.has(cache_key):
			recolored.append(frame_set_cache[cache_key] as Texture2D)
			continue
		var source_image: Image = texture_cache[texture] if texture_cache.has(texture) else texture.get_image()
		var image: Image = source_image.duplicate()
		for y in image.get_height():
			for x in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a <= 0.0: continue
				var key := "%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]
				var mapped := _palette_color(color, key, palette)
				image.set_pixel(x, y, Color(mapped.r, mapped.g, mapped.b, color.a))
		var result := ImageTexture.create_from_image(image)
		frame_set_cache[cache_key] = result
		recolored.append(result)
	return recolored


static func set_facing(root: Object, slime: Sprite2D, direction_x: float) -> void:
	if absf(direction_x) < 0.1: return
	var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
	var texture: Texture2D = visual.left_texture if direction_x < 0.0 and visual != null else visual.right_texture if visual != null else null
	if direction_x < 0.0: slime.flip_h = false
	elif texture == null and visual != null and visual.left_texture != null: texture = visual.left_texture; slime.flip_h = true
	else: slime.flip_h = false
	if texture == null: texture = (root.get("occlusion_renderer") as OcclusionRenderer).actor_default_textures.get(slime)
	root.call("_set_actor_base_texture", slime, texture); root.call("_update_slime_attack_guides", slime)


func squish_scale(progress: float, movement: Vector2) -> Vector2:
	var pulse := sin(clampf(progress, 0.0, 1.0) * PI)
	var stretch_x := 1.0 + pulse * 0.18
	var stretch_y := 1.0 - pulse * 0.14
	if absf(movement.y) > absf(movement.x):
		stretch_x = 1.0 + pulse * 0.12
		stretch_y = 1.0 - pulse * 0.18
	return Vector2(stretch_x, stretch_y)


static func _palette_color(original: Color, key: String, palette: String) -> Color:
	if not PaletteLibrary.ACCENT.has(palette):
		return original
	var mapping := {
		"257179": PaletteLibrary.shadow(palette), "38B764": PaletteLibrary.normal(palette), "A7F070": PaletteLibrary.accent(palette),
	}
	return mapping.get(key, original)
