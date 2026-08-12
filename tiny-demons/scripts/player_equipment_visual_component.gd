extends Node
class_name PlayerEquipmentVisualComponent

const FRAME_SIZE := Vector2i(36, 36)
const INACTIVITY_TIME := 6.0
const FLASH_TIME := 0.16
const FADE_TIME := 1.5
const ATTACK_TRANSITION_HOLD := 0.16
const DRAW_WHITE_TIME := 0.18
const DRAW_COLOR_FADE_TIME := 0.09
const EQUIPMENT_TEXTURE_OFFSET := Vector2(-10, -10)
const OCCLUSION_MASK_REFRESH_TIME := 0.08

var layers: Dictionary = {}
var shadows: Dictionary = {}
var fade_overlays: Dictionary = {}
var draw_overlays: Dictionary = {}
var white_copy_cache: Dictionary = {}
var occlusion_shader: Shader = null
var occlusion_materials: Dictionary = {}
var layer_opacities: Dictionary = {}
var occlusion_mask_texture: Texture2D = null
var occlusion_signature: int = 0
var occlusion_mask_refresh_timer := 0.0
var occlusion_active := false
var frames: Dictionary = {}
var active := false
var inactivity_timer := 0.0
var fade_timer := 0.0
var was_attacking := false
var gameplay_root: Object = null
var breakup_pending := false
var breakup_started := false
var last_attack_name := "attack1"
var transition_hold_timer := 0.0
var roll_fizzle_active := false
var roll_fizzle_positions: Dictionary = {}
var death_active := false
var death_breakup_started := false
var draw_white_timer := 0.0
var draw_color_fade_timer := 0.0
var frame_paths := {
	"sword_back_idle": "res://assets/artwork/TinyDemon_sword(back)_idle.png",
	"sword_back_walk": "res://assets/artwork/TinyDemon_sword(back)_walk.png",
	"sword_back_attack": "res://assets/artwork/TinyDemon_sword(back)_attack.png",
	"shield_back_attack1": "res://assets/artwork/TinyDemon_shield(back)_attack1.png",
	"shield_back_attack2": "res://assets/artwork/TinyDemon_shield(back)_attack2.png",
	"shield_back_between": "res://assets/artwork/TinyDemon_shield(back)_betweenattacks.png",
	"shield_front_idle": "res://assets/artwork/TinyDemon_shield(front)_idle.png",
	"shield_front_walk": "res://assets/artwork/TinyDemon_shield(front)_walk.png",
	"shield_front_attack1": "res://assets/artwork/TinyDemon_shield(front)_attack1.png",
	"shield_front_attack2": "res://assets/artwork/TinyDemon_shield(front)_attack2.png",
	"shield_front_between": "res://assets/artwork/TinyDemon_shield(front)_betweenattacks.png",
	"shield_front_after": "res://assets/artwork/TinyDemon_shield(front)_afterattack2.png",
	"sword_front_attack1": "res://assets/artwork/TinyDemon_sword(front)_attack1.png",
	"sword_front_attack2": "res://assets/artwork/TinyDemon_sword(front)_attack2.png",
	"sword_front_between": "res://assets/artwork/TinyDemon_sword(front)_betweenattack1.png",
	"sword_front_after": "res://assets/artwork/TinyDemon_sword(front)_afterattack2.png",
}


func initialize(root: Object) -> void:
	gameplay_root = root
	var parent := root.get("player") as Sprite2D
	if parent == null:
		return
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary
	if library == null:
		return
	apply_palette(root)
	_create_layer(parent, "EquipmentSwordBack", -1)
	_create_layer(parent, "EquipmentShieldBack", -1)
	_create_layer(parent, "EquipmentShieldFront", 1)
	_create_layer(parent, "EquipmentSwordFront", 1)
	_create_occlusion_material()


func _create_occlusion_material() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform sampler2D occlusion_mask : filter_nearest;\nvoid fragment() {\n    vec4 vertex_tint = COLOR;\n    vec4 source = texture(TEXTURE, UV);\n    if (texture(occlusion_mask, UV).r > 0.5) {\n        discard;\n    }\n    COLOR = source * vertex_tint;\n}"
	occlusion_shader = shader
	for layer in layers.values():
		var material := ShaderMaterial.new()
		material.shader = occlusion_shader
		occlusion_materials[layer] = material


func update_occlusion(root: Object, delta: float) -> void:
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	if renderer == null:
		return
	_sync_depth_order(root)
	if fade_timer > 0.0 or death_active:
		_set_occlusion_enabled(false)
		return
	var visible_layers: Array[Sprite2D] = []
	for value in layers.values():
		var equipment_layer := value as Sprite2D
		if equipment_layer != null and equipment_layer.visible and equipment_layer.texture != null:
			visible_layers.append(equipment_layer)
	if visible_layers.is_empty():
		_set_occlusion_enabled(false)
		return
	var occluders := _equipment_occluders(root)
	occlusion_mask_refresh_timer = maxf(occlusion_mask_refresh_timer - delta, 0.0)
	var any_occluded := false
	for layer in visible_layers:
		var candidates := renderer.active_occluders_for(layer, occluders, float(root.call("_equipment_occlusion_depth_key", layer)), root.call("_sprite_source_global_rect", layer) as Rect2, Callable(root, "_equipment_occlusion_depth_key"), Callable(root, "_sprite_source_global_rect"))
		var active_occluders := candidates["occluders"] as Array[Sprite2D]
		if active_occluders.is_empty():
			continue
		var occluded_texture := _build_occluded_texture(root, renderer, layer, active_occluders)
		if occluded_texture != null:
			layer.texture = occluded_texture
			any_occluded = true
	_set_occlusion_enabled(any_occluded)


func _first_visible_layer() -> Sprite2D:
	for value in layers.values():
		var layer := value as Sprite2D
		if layer != null and layer.visible and layer.texture != null:
			return layer
	return null


func _build_occluded_texture(root: Object, renderer: OcclusionRenderer, layer: Sprite2D, active_occluders: Array[Sprite2D]) -> Texture2D:
	var source_texture := layer.texture
	var source_image := source_texture.get_image()
	var source_size := source_image.get_size()
	var mask_size := Vector2i(maxi(1, int(source_size.x * 2.0)), maxi(1, int(source_size.y * 2.0)))
	var image := Image.create(mask_size.x, mask_size.y, false, Image.FORMAT_RGBA8)
	var source_rect := root.call("_sprite_source_global_rect", layer) as Rect2
	var scale := layer.scale.abs()
	var has_covered_pixel := false
	for y in range(mask_size.y):
		for x in range(mask_size.x):
			var source_pixel := Vector2((float(x) + 0.5) * 0.5, (float(y) + 0.5) * 0.5)
			var source_x := clampi(int(source_pixel.x), 0, source_size.x - 1)
			var source_y := clampi(int(source_pixel.y), 0, source_size.y - 1)
			var color := source_image.get_pixel(source_x, source_y)
			image.set_pixel(x, y, color)
			if color.a <= 0.0:
				continue
			var world_pixel := source_rect.position + source_pixel * scale
			if renderer.is_pixel_covered_by_occluder(world_pixel, active_occluders, Callable(root, "_actor_screen_scale"), Callable(root, "_actor_visual_offset")):
				has_covered_pixel = true
				if (x + y) % 2 == 0:
					color.a = 0.0
					image.set_pixel(x, y, color)
	if not has_covered_pixel:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(source_size)
	return texture


func _set_occlusion_enabled(enabled: bool) -> void:
	occlusion_active = enabled
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if equipment_layer == null:
			continue
		equipment_layer.material = null
	if enabled:
		_hide_equipment_shadows()
	else:
		_update_equipment_shadows()


func _occlusion_signature(layer: Sprite2D, occluders: Array[Sprite2D]) -> int:
	var state: Array = [layer.flip_h, _occlusion_position_cell(layer.global_position)]
	for occluder in occluders:
		state.append(occluder)
		state.append(occluder.get_instance_id())
		state.append(_occlusion_position_cell(occluder.global_position))
	return state.hash()


func _occlusion_position_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / 4.0), floori(position.y / 4.0))


func _sync_depth_order(root: Object) -> void:
	var player := root.get("player") as Sprite2D
	if player == null:
		return
	for layer_name in layers:
		var layer := layers[layer_name] as Sprite2D
		if layer != null:
			layer.z_index = player.z_index + (-1 if String(layer_name).ends_with("Back") else 1)


func _equipment_occluders(root: Object) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for value in root.get("occluder_sprites") as Array:
		var sprite := value as Sprite2D
		# The fire is a light source, not a solid cover plane. Let its light
		# remain visible without making the equipment dither as the player walks
		# through the fire's depth range.
		if sprite != null and sprite != root.get("rest_fire") and sprite.visible:
			result.append(sprite)
	var cloaked_demon := root.get("cloaked_demon") as Sprite2D
	if cloaked_demon != null and cloaked_demon.visible and not result.has(cloaked_demon):
		result.append(cloaked_demon)
	return result


func _is_layer_occlusion_flashing(_layer: Sprite2D) -> bool:
	return false


func apply_palette(root: Object) -> void:
	gameplay_root = root
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary
	if library == null:
		return
	var palettes := {
		"blue": [Color8(41, 54, 111), Color8(59, 93, 201)], "orange": [Color8(171, 82, 54), Color8(239, 125, 87)],
		"green": [Color8(37, 113, 121), Color8(56, 183, 100)], "red": [Color8(93, 39, 93), Color8(177, 62, 83)],
		"yellow": [Color8(181, 97, 55), Color8(255, 205, 117)], "grey": [Color8(59, 63, 82), Color8(86, 108, 134)],
		"purple": [Color8(67, 47, 102), Color8(118, 78, 142)], "aquamarine": [Color8(39, 84, 116), Color8(58, 138, 151)]
	}
	var palette: Array = palettes.get(String(root.get("player_palette_name")), palettes["blue"])
	frames.clear()
	white_copy_cache.clear()
	for key in frame_paths:
		var source_frames := library.slice_frames(frame_paths[key], FRAME_SIZE)
		var recolored: Array[Texture2D] = []
		for source in source_frames:
			recolored.append(_recolor_frame(source, palette[0], palette[1]))
		frames[key] = recolored


func _recolor_frame(source: Texture2D, main_color: Color, highlight_color: Color) -> Texture2D:
	var image := source.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			var rgb := Color8(int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0))
			if rgb == Color8(59, 93, 201):
				image.set_pixel(x, y, Color(highlight_color.r, highlight_color.g, highlight_color.b, color.a))
			elif rgb == Color8(86, 108, 134):
				var dark_tinted := color.lerp(main_color, 0.45)
				image.set_pixel(x, y, Color(dark_tinted.r, dark_tinted.g, dark_tinted.b, color.a))
			elif rgb == Color8(148, 176, 194):
				var darkened := color.lerp(Color.BLACK, 0.1)
				var tinted := darkened.lerp(highlight_color, 0.25)
				image.set_pixel(x, y, Color(tinted.r, tinted.g, tinted.b, color.a))
	return ImageTexture.create_from_image(image)


func _create_layer(parent: Sprite2D, layer_name: String, z_offset: int) -> void:
	var layer := Sprite2D.new()
	layer.name = layer_name
	layer.centered = parent.centered
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_as_relative = false
	layer.z_index = parent.z_index + z_offset
	layer.visible = false
	parent.get_parent().add_child(layer)
	layers[layer_name] = layer
	var shadow := Sprite2D.new()
	shadow.name = "%sShadow" % layer_name
	shadow.centered = parent.centered
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_as_relative = false
	shadow.self_modulate = Color(0.0, 0.0, 0.0, 0.25)
	shadow.visible = false
	parent.get_parent().add_child(shadow)
	shadows[layer_name] = shadow


func tick(root: Object, delta: float) -> void:
	if layers.is_empty():
		return
	if bool(root.get("player_is_rolling")) and active and fade_timer <= 0.0:
		fade_timer = FLASH_TIME
		active = false
		roll_fizzle_active = true
		roll_fizzle_positions.clear()
		for layer in layers.values():
			var equipment_layer := layer as Sprite2D
			if equipment_layer.visible:
				roll_fizzle_positions[equipment_layer] = equipment_layer.global_position
		_create_fade_overlays(root)
		breakup_pending = true
		breakup_started = false
	var attacking := bool(root.get("player_is_attacking"))
	if attacking:
		_clear_fade_overlays()
		if not active:
			draw_white_timer = DRAW_WHITE_TIME
			draw_color_fade_timer = DRAW_COLOR_FADE_TIME
		last_attack_name = String(root.get("player_anim_name")) if String(root.get("player_anim_name")).begins_with("attack") else last_attack_name
		active = true
		inactivity_timer = 0.0
		fade_timer = 0.0
		was_attacking = true
	else:
		if was_attacking:
			transition_hold_timer = ATTACK_TRANSITION_HOLD
		was_attacking = false
		if active:
			inactivity_timer += delta
			if inactivity_timer >= INACTIVITY_TIME:
				fade_timer = maxf(fade_timer, FADE_TIME)
				inactivity_timer = 0.0
				active = false
				roll_fizzle_active = false
				roll_fizzle_positions.clear()
				_create_fade_overlays(root)
				breakup_pending = true
				breakup_started = false
	draw_white_timer = maxf(draw_white_timer - delta, 0.0)
	if draw_white_timer <= 0.0:
		draw_color_fade_timer = maxf(draw_color_fade_timer - delta, 0.0)
	transition_hold_timer = maxf(transition_hold_timer - delta, 0.0)
	if fade_timer > 0.0:
		fade_timer = maxf(fade_timer - delta, 0.0)
	if breakup_pending and not breakup_started and fade_timer <= 0.0:
		_spawn_breakup(root)
	_update_layers(root)


func begin_death(root: Object) -> void:
	if not active:
		return
	_hide_equipment_shadows()
	_clear_fade_overlays()
	_create_fade_overlays(root)
	death_active = true
	death_breakup_started = false


func tick_death(root: Object) -> void:
	if not death_active:
		return
	var player := root.get("player") as Sprite2D
	var tuning := root.get("player_tuning") as PlayerTuning
	if player == null or tuning == null:
		return
	var death_timer := float(root.get("player_death_timer"))
	var fade_progress := clampf(death_timer / tuning.death_fade_time, 0.0, 1.0)
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if not equipment_layer.visible:
			continue
		equipment_layer.global_position = player.global_position + EQUIPMENT_TEXTURE_OFFSET
		_set_layer_opacity(equipment_layer, 1.0 - fade_progress)
		var overlay := fade_overlays.get(equipment_layer) as Sprite2D
		if overlay != null:
			overlay.global_position = equipment_layer.global_position
			overlay.modulate.a = fade_progress
	if bool(root.get("player_death_particles_started")) and not death_breakup_started:
		_spawn_breakup(root)
		death_breakup_started = true


func _clear_fade_overlays() -> void:
	if fade_overlays.is_empty():
		return
	for overlay in fade_overlays.values():
		(overlay as Sprite2D).queue_free()
	fade_overlays.clear()


func _clear_draw_overlays() -> void:
	for overlay in draw_overlays.values():
		(overlay as Sprite2D).queue_free()
	draw_overlays.clear()


func _update_equipment_shadows() -> void:
	for layer_name in layers:
		var layer := layers[layer_name] as Sprite2D
		var shadow := shadows.get(layer_name) as Sprite2D
		if shadow == null:
			continue
		shadow.texture = layer.texture
		shadow.global_position = layer.global_position + Vector2(-0.5, 0.0)
		shadow.offset = layer.offset
		shadow.scale = layer.scale
		shadow.flip_h = layer.flip_h
		shadow.z_index = layer.z_index - 1
		shadow.modulate.a = float(layer_opacities.get(layer, 1.0))
		shadow.visible = layer.visible and layer.texture != null and not occlusion_active


func _hide_equipment_shadows() -> void:
	for shadow in shadows.values():
		(shadow as Sprite2D).visible = false


func _update_draw_overlays() -> void:
	if draw_white_timer <= 0.0 and draw_color_fade_timer <= 0.0:
		_clear_draw_overlays()
		return
	var normal_opacity := 0.0 if draw_white_timer > 0.0 else 1.0 - draw_color_fade_timer / DRAW_COLOR_FADE_TIME
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if not equipment_layer.visible or equipment_layer.texture == null:
			continue
		var overlay := draw_overlays.get(equipment_layer) as Sprite2D
		if overlay == null:
			overlay = Sprite2D.new()
			overlay.name = "%sDrawWhite" % equipment_layer.name
			overlay.centered = equipment_layer.centered
			overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			overlay.z_as_relative = false
			equipment_layer.get_parent().add_child(overlay)
			draw_overlays[equipment_layer] = overlay
		_set_layer_opacity(equipment_layer, normal_opacity)
		overlay.texture = _white_copy(equipment_layer.texture)
		overlay.global_position = equipment_layer.global_position
		overlay.flip_h = equipment_layer.flip_h
		overlay.z_index = equipment_layer.z_index
		var white_opacity := 0.5 if draw_white_timer > 0.0 else 1.0 - normal_opacity
		overlay.modulate = Color(1.0, 1.0, 1.0, white_opacity)


func _create_fade_overlays(root: Object) -> void:
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if equipment_layer.visible and equipment_layer.texture != null:
			var overlay := Sprite2D.new()
			overlay.name = "%sFadeWhite" % equipment_layer.name
			overlay.centered = equipment_layer.centered
			overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			overlay.z_as_relative = false
			overlay.z_index = equipment_layer.z_index + 2
			overlay.texture = _white_copy(equipment_layer.texture)
			overlay.global_position = equipment_layer.global_position
			overlay.flip_h = equipment_layer.flip_h
			overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
			root.add_child(overlay)
			fade_overlays[equipment_layer] = overlay


func _white_copy(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	if white_copy_cache.has(source):
		return white_copy_cache[source] as Texture2D
	var image := source.get_image().duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, color.a))
	var texture := ImageTexture.create_from_image(image)
	white_copy_cache[source] = texture
	return texture


func _spawn_breakup(root: Object) -> void:
	breakup_started = true
	breakup_pending = false
	var effects := root.get("effects_spawner") as EffectsSpawner
	var random_source := root.get("rng") as RandomNumberGenerator
	if effects == null or random_source == null:
		return
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if not equipment_layer.visible or equipment_layer.texture == null:
			continue
		effects.spawn_player_death_particles(root, equipment_layer.texture, equipment_layer.global_position, Vector2.ZERO, Vector2.ONE, equipment_layer.z_index + 1, 0.75, random_source.randi(), Callable(root, "_pixel_particle_texture"), equipment_layer.flip_h)
		equipment_layer.visible = false
		var overlay := fade_overlays.get(equipment_layer) as Sprite2D
		if overlay != null:
			overlay.visible = false
	_hide_equipment_shadows()


func _update_layers(root: Object) -> void:
	var player := root.get("player") as Sprite2D
	if player == null:
		return
	for layer_name in layers:
		var depth_layer := layers[layer_name] as Sprite2D
		depth_layer.z_index = player.z_index + (-1 if String(layer_name).ends_with("Back") else 1)
	if bool(root.get("player_is_rolling")) and fade_timer <= 0.0:
		for layer in layers.values():
			(layer as Sprite2D).visible = false
		_update_equipment_shadows()
		return
	var opacity := 1.0
	if fade_timer > 0.0:
		opacity = fade_timer / FADE_TIME
	if not active and fade_timer <= 0.0:
		for layer in layers.values():
			(layer as Sprite2D).visible = false
		for overlay in fade_overlays.values():
			(overlay as Sprite2D).queue_free()
		fade_overlays.clear()
		_clear_draw_overlays()
		_update_equipment_shadows()
		return
	var animation_name := String(root.get("player_anim_name"))
	var frame_index := int(root.get("player_anim_frame"))
	if fade_timer > 0.0 and roll_fizzle_active:
		for layer in layers.values():
			var fading_layer := layer as Sprite2D
			if fading_layer.visible:
				if roll_fizzle_active and roll_fizzle_positions.has(fading_layer):
					fading_layer.global_position = roll_fizzle_positions[fading_layer]
				else:
					fading_layer.global_position = player.global_position + EQUIPMENT_TEXTURE_OFFSET
				_set_layer_opacity(fading_layer, 1.0)
				var overlay := fade_overlays.get(fading_layer) as Sprite2D
				if overlay != null:
					overlay.global_position = fading_layer.global_position
					overlay.flip_h = fading_layer.flip_h
					overlay.z_index = fading_layer.z_index + 2
					overlay.modulate.a = 1.0 - opacity
		_update_equipment_shadows()
		return
	var currently_attacking := bool(root.get("player_is_attacking"))
	var state := "idle"
	if currently_attacking and animation_name == "attack1": state = "attack1"
	elif currently_attacking and animation_name == "attack2": state = "attack2"
	elif transition_hold_timer > 0.0 and last_attack_name == "attack2": state = "after"
	elif transition_hold_timer > 0.0: state = "between"
	elif float(root.get("player_between_timer")) > 0.0 and last_attack_name == "attack2": state = "after"
	elif float(root.get("player_between_timer")) > 0.0: state = "between"
	elif animation_name == "walk": state = "walk"
	elif animation_name == "between": state = "between"
	var sword_back_visible := state != "attack2"
	_set_layer("EquipmentSwordBack", frames.get("sword_back_%s" % ("attack" if state == "attack1" else state)), frame_index, opacity, sword_back_visible)
	_set_layer("EquipmentShieldBack", frames.get("shield_back_%s" % ("attack1" if state == "attack1" else "attack2" if state == "attack2" else "between")), frame_index, opacity, state.begins_with("attack") or state == "between")
	_set_layer("EquipmentShieldFront", frames.get("shield_front_%s" % ("attack1" if state == "attack1" else "attack2" if state == "attack2" else "between" if state == "between" else "after" if state == "after" else state)), frame_index, opacity)
	_set_layer("EquipmentSwordFront", frames.get("sword_front_%s" % ("attack1" if state == "attack1" else "attack2" if state == "attack2" else "between" if state == "between" else "after")), frame_index, opacity, state.begins_with("attack") or state == "between" or state == "after")
	_update_draw_overlays()
	if fade_timer > 0.0:
		var white_fade_progress := pow(1.0 - opacity, 2.2)
		for layer in layers.values():
			var fading_layer := layer as Sprite2D
			if not fading_layer.visible:
				continue
			_set_layer_opacity(fading_layer, 1.0 - white_fade_progress)
			var overlay := fade_overlays.get(fading_layer) as Sprite2D
			if overlay != null:
				overlay.texture = _white_copy(fading_layer.texture)
				overlay.global_position = fading_layer.global_position
				overlay.flip_h = fading_layer.flip_h
				overlay.modulate.a = white_fade_progress
	_update_equipment_shadows()


func _set_layer(layer_name: String, source: Variant, frame_index: int, opacity: float, should_show := true) -> void:
	var layer := layers.get(layer_name) as Sprite2D
	if layer == null or source == null or not should_show:
		if layer != null: layer.visible = false
		return
	var texture_frames := source as Array
	if texture_frames == null or texture_frames.is_empty():
		layer.visible = false
		return
	layer.texture = texture_frames[mini(frame_index, texture_frames.size() - 1)]
	var player := gameplay_root.get("player") as Sprite2D
	if player == null:
		layer.visible = false
		return
	layer.global_position = player.global_position + EQUIPMENT_TEXTURE_OFFSET
	layer.flip_h = bool(gameplay_root.get("player_attack_flip_h")) if String(gameplay_root.get("player_anim_name")).begins_with("attack") else player.flip_h
	_set_layer_opacity(layer, opacity)
	layer.visible = true


func _set_layer_opacity(layer: Sprite2D, opacity: float) -> void:
	var clamped_opacity := clampf(opacity, 0.0, 1.0)
	layer_opacities[layer] = clamped_opacity
	layer.modulate = Color(1.0, 1.0, 1.0, clamped_opacity)
