extends Node
class_name SlimeVisualComponent

var left_texture: Texture2D = null
var right_texture: Texture2D = null
var attack_left_frames: Array[Texture2D] = []
var attack_right_frames: Array[Texture2D] = []
var shocked_frames: Array[Texture2D] = []


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
		visual.left_texture = load_texture.call(slime_paths[0])
		visual.right_texture = load_texture.call(slime_paths[1])


static func recolor_direction_textures(slimes: Array[Sprite2D], palette: String, texture_cache: Dictionary) -> void:
	for slime in slimes:
		var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			continue
		if visual.left_texture != null:
			visual.left_texture = recolor_direction_texture(visual.left_texture, palette, texture_cache)
		if visual.right_texture != null:
			visual.right_texture = recolor_direction_texture(visual.right_texture, palette, texture_cache)


static func recolor_direction_texture(source: Texture2D, palette: String, texture_cache: Dictionary) -> Texture2D:
	var image: Image = texture_cache.get(source, source.get_image()).duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var key := "%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]
			var mapped := _palette_color(color, key, palette)
			image.set_pixel(x, y, Color(mapped.r, mapped.g, mapped.b, color.a))
	return ImageTexture.create_from_image(image)


static func build_attack_frames(slimes: Array[Sprite2D], frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> void:
	var frames_by_palette := build_attack_frame_library(frame_library, frame_size, cache, warm_texture)
	assign_attack_frames(slimes, frames_by_palette)


static func build_attack_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var left_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreen_AttackL.png", frame_size)
	var right_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreen_AttackR.png", frame_size)
	var frames_by_palette := {
		"green": {"left": left_frames, "right": right_frames},
		"blue": {"left": recolor_attack_frame_set(left_frames, "blue", cache), "right": recolor_attack_frame_set(right_frames, "blue", cache)},
		"red": {"left": recolor_attack_frame_set(left_frames, "red", cache), "right": recolor_attack_frame_set(right_frames, "red", cache)},
		"purple": {"left": recolor_attack_frame_set(left_frames, "purple", cache), "right": recolor_attack_frame_set(right_frames, "purple", cache)},
	}
	for palette_frames in frames_by_palette.values():
		var left_palette_frames := palette_frames["left"] as Array[Texture2D]
		var right_palette_frames := palette_frames["right"] as Array[Texture2D]
		for texture in left_palette_frames: warm_texture.call(texture)
		for texture in right_palette_frames: warm_texture.call(texture)
	return frames_by_palette


static func assign_attack_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var palette := String(slime.get("variant")); if not frames_by_palette.has(palette): palette = "green"
		var palette_frames := frames_by_palette[palette] as Dictionary
		visual.attack_left_frames = palette_frames["left"] as Array[Texture2D]
		visual.attack_right_frames = palette_frames["right"] as Array[Texture2D]


static func build_shocked_frame_library(frame_library: SpriteFrameLibrary, frame_size: Vector2i, cache: Dictionary, warm_texture: Callable) -> Dictionary:
	var green_frames := frame_library.slice_frames("res://assets/artwork/SlimeGreenshocked.png", frame_size)
	var frames_by_palette := {
		"green": green_frames,
		"blue": recolor_attack_frame_set(green_frames, "blue", cache),
		"red": recolor_attack_frame_set(green_frames, "red", cache),
		"purple": recolor_attack_frame_set(green_frames, "purple", cache),
	}
	for palette_frames in frames_by_palette.values():
		for texture in palette_frames as Array[Texture2D]:
			warm_texture.call(texture)
	return frames_by_palette


static func assign_shocked_frames(slimes: Array[Sprite2D], frames_by_palette: Dictionary) -> void:
	for slime in slimes:
		var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
		if visual == null:
			visual = SlimeVisualComponent.new()
			visual.name = "Visual"
			slime.add_child(visual)
		var palette := String(slime.get("variant"))
		if not frames_by_palette.has(palette):
			palette = "green"
		visual.shocked_frames = frames_by_palette[palette] as Array[Texture2D]


static func recolor_attack_frame_set(source_frames: Array[Texture2D], palette: String, texture_cache: Dictionary) -> Array[Texture2D]:
	var recolored: Array[Texture2D] = []
	for texture in source_frames:
		var image: Image = texture_cache.get(texture, texture.get_image()).duplicate()
		for y in image.get_height():
			for x in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a <= 0.0: continue
				var key := "%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]
				var mapped := _palette_color(color, key, palette)
				image.set_pixel(x, y, Color(mapped.r, mapped.g, mapped.b, color.a))
		recolored.append(ImageTexture.create_from_image(image))
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


func recolor_attack_frames(source_frames: Array[Texture2D], palette: String, texture_cache: Dictionary) -> Array[Texture2D]:
	var recolored: Array[Texture2D] = []
	for texture in source_frames:
		var image: Image = texture_cache.get(texture, texture.get_image()).duplicate()
		for y in image.get_height():
			for x in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a <= 0.0:
					continue
				var key := "%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]
				var mapped := _palette_color(color, key, palette)
				image.set_pixel(x, y, Color(mapped.r, mapped.g, mapped.b, color.a))
		recolored.append(ImageTexture.create_from_image(image))
	return recolored


static func _palette_color(original: Color, key: String, palette: String) -> Color:
	var mapping := {
		"red": {"257179": Color8(93, 39, 93), "38B764": Color8(177, 62, 83), "A7F070": Color8(239, 125, 87)},
		"blue": {"257179": Color8(41, 54, 111), "38B764": Color8(59, 93, 201), "A7F070": Color8(65, 166, 246)},
		"purple": {"257179": Color8(67, 47, 102), "38B764": Color8(118, 78, 142), "A7F070": Color8(200, 184, 210)},
	}
	return (mapping.get(palette, {}) as Dictionary).get(key, original)
