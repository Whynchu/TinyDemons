extends Node
class_name PlayerEquipmentVisualComponent

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

const FRAME_SIZE := Vector2i(36, 36)
const INACTIVITY_TIME := 6.0
const FLASH_TIME := 0.16
const FADE_TIME := 1.5
const ATTACK_TRANSITION_HOLD := 0.16
const DRAW_WHITE_TIME := 0.18
const DRAW_COLOR_FADE_TIME := 0.09
const EQUIPMENT_TEXTURE_OFFSET := Vector2(-10, -10)
const OCCLUSION_MASK_REFRESH_TIME := 0.08
const IMBUE_FLASH_TIME := 0.16
const IMBUE_FADE_TIME := 2.50
const IMBUE_PARTICLE_INTERVAL := 0.08

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
var occlusion_texture_cache: Dictionary = {}
var occlusion_active := false
var palette_override := ""
var frames: Dictionary = {}
var frames_by_palette: Dictionary = {}
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
var mp_desaturation_materials: Dictionary = {}
var mp_saturation := 1.0
var death_breakup_started := false
var draw_white_timer := 0.0
var draw_color_fade_timer := 0.0
var guard_flash_timer := 0.0
var guard_flash_overlay: Sprite2D = null
var was_defending := false
var shield_is_out := false
var imbue_element := ElementCatalogScript.Element.NEUTRAL
var imbue_remaining := 0.0
var imbue_flash_timer := 0.0
var imbue_particle_timer := 0.0
var imbue_outline_overlays: Dictionary = {}
var imbue_flash_overlays: Dictionary = {}
var imbue_outline_texture_cache: Dictionary = {}
var imbue_color_texture_cache: Dictionary = {}
var imbue_bleed_positions_cache: Dictionary = {}
var imbue_noise := FastNoiseLite.new()
var frame_paths := {
	"sword_back_idle": "res://assets/artwork/TinyDemon_sword(back)_idle.png",
	"sword_back_walk": "res://assets/artwork/TinyDemon_sword(back)_walk.png",
	"sword_back_attack": "res://assets/artwork/TinyDemon_sword(back)_attack.png",
	"sword_back_defend": "res://assets/artwork/TinyDemon-Defend-sword(behind).png",
	"shield_front_defend": "res://assets/artwork/TinyDemon-Defend-Shield(front).png",
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
	"sword_back_spin": "res://assets/artwork/TinyDemon-Spin_Attack_swordBehind.png",
	"sword_front_spin": "res://assets/artwork/TinyDemon-Spin_Attack_swordFront.png",
	"shield_back_spin": "res://assets/artwork/TinyDemon-Spin_Attack_shieldBehind.png",
	"shield_front_spin": "res://assets/artwork/TinyDemon-Spin_Attack_shieldFront.png",
	"sword_magic": "res://assets/artwork/Sword-Magic.png",
	"shield_magic": "res://assets/artwork/Shield-Magic.png",
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
	precache_all_palettes(root)


func begin_imbue(root: Object, element: int, duration: float) -> void:
	gameplay_root = root
	imbue_element = ElementCatalogScript.normalize(element)
	imbue_remaining = maxf(duration, 0.0)
	imbue_flash_timer = IMBUE_FLASH_TIME
	imbue_particle_timer = 0.0
	imbue_noise.seed = int((root.get("rng") as RandomNumberGenerator).randi()) if root.get("rng") != null else Time.get_ticks_msec()
	imbue_noise.frequency = 0.28
	_clear_imbue_overlays()
	_update_imbue_overlays(root)


func end_imbue(root: Object) -> void:
	imbue_remaining = 0.0
	imbue_flash_timer = 0.0
	imbue_particle_timer = 0.0
	imbue_element = ElementCatalogScript.Element.NEUTRAL
	_clear_imbue_overlays()
	var imbue_effects := root.get("effects_spawner") as EffectsSpawner
	if imbue_effects != null:
		imbue_effects.clear_effect_particles(&"imbue_weapon")


func set_mp_desaturation(saturation: float) -> void:
	mp_saturation = clampf(saturation, 0.0, 1.0)
	_refresh_mp_materials()


func _refresh_mp_materials() -> void:
	for layer_value in layers.values():
		var layer := layer_value as Sprite2D
		if layer == null:
			continue
		_apply_mp_material(layer)


func _apply_mp_material(layer: Sprite2D) -> void:
	if layer == null or occlusion_active or mp_saturation >= 0.999:
		if not occlusion_active and layer != null:
			layer.material = null
		return
	var grey_key := String(layer.get_meta("mp_grey_key", ""))
	var grey_frame := int(layer.get_meta("mp_grey_frame", 0))
	var grey_set: Dictionary = frames_by_palette.get("grey", {}) as Dictionary
	var grey_frames: Array = grey_set.get(grey_key, [])
	if grey_frames.is_empty():
		layer.material = null
		return
	var material := mp_desaturation_materials.get(layer) as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = preload("res://shaders/mp_desaturation.gdshader")
		mp_desaturation_materials[layer] = material
	material.set_shader_parameter("grey_texture", grey_frames[mini(grey_frame, grey_frames.size() - 1)])
	material.set_shader_parameter("grey_mix", 1.0 - mp_saturation)
	layer.material = material


func _create_occlusion_material() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform sampler2D occlusion_mask : filter_nearest;\nvoid fragment() {\n    vec4 vertex_tint = COLOR;\n    vec4 source = texture(TEXTURE, UV);\n    if (texture(occlusion_mask, UV).r > 0.5) {\n        discard;\n    }\n    COLOR = source * vertex_tint;\n}"
	occlusion_shader = shader
	for layer in layers.values():
		var material := ShaderMaterial.new()
		material.shader = occlusion_shader
		occlusion_materials[layer] = material


func update_occlusion(root: Object, _delta: float) -> void:
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
	var any_occluded := false
	for layer in visible_layers:
		var candidates := renderer.active_occluders_for(layer, occluders, float(root.call("_equipment_occlusion_depth_key", layer)), root.call("_sprite_source_global_rect", layer) as Rect2, Callable(root, "_equipment_occlusion_depth_key"), Callable(root, "_sprite_source_global_rect"))
		var active_occluders := candidates["occluders"] as Array[Sprite2D]
		if active_occluders.is_empty():
			continue
		var signature := _occlusion_signature(layer, active_occluders)
		var layer_key := layer.get_instance_id()
		var cached_value: Variant = occlusion_texture_cache.get(layer_key)
		var cached: Dictionary = {}
		if cached_value is Dictionary:
			cached = cached_value
		var occluded_texture: Texture2D = null
		if cached != null and int(cached.get("signature", 0)) == signature and cached.has("texture"):
			occluded_texture = cached["texture"] as Texture2D
		else:
			occluded_texture = _build_occluded_texture(root, renderer, layer, active_occluders)
			if occluded_texture != null:
				occlusion_texture_cache[layer_key] = {"signature": signature, "texture": occluded_texture}
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
		_refresh_mp_materials()
		_update_equipment_shadows()


func _occlusion_signature(layer: Sprite2D, occluders: Array[Sprite2D]) -> int:
	var state: Array = [layer.texture, layer.flip_h, _occlusion_position_cell(layer.global_position)]
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
	var actors := root.get("actor_sprites") as Array[Sprite2D]
	for value in root.get("occluder_sprites") as Array:
		var sprite := value as Sprite2D
		# The fire is a light source, not a solid cover plane. Let its light
		# remain visible without making the equipment dither as the player walks
		# through the fire's depth range.
		if sprite != null and sprite != root.get("rest_fire") and not actors.has(sprite) and sprite.visible:
			result.append(sprite)
	var cloaked_demon := root.get("cloaked_demon") as Sprite2D
	if cloaked_demon != null and cloaked_demon.visible and not result.has(cloaked_demon):
		result.append(cloaked_demon)
	return result


func _is_layer_occlusion_flashing(_layer: Sprite2D) -> bool:
	return false


func apply_palette(root: Object) -> void:
	gameplay_root = root
	var screen_state_controller: Object = root.get("screen_state_controller")
	var palette_name := palette_override if not palette_override.is_empty() else String(screen_state_controller.get("player_palette_name"))
	if not frames_by_palette.has(palette_name):
		var library := root.get("sprite_frame_library") as SpriteFrameLibrary
		if library == null:
			return
		white_copy_cache.clear(); occlusion_texture_cache.clear()
		frames_by_palette[palette_name] = _build_palette_frames(library, palette_name)
	frames = frames_by_palette[palette_name]


func set_palette_override(palette_name: String) -> void:
	palette_override = palette_name


func _build_palette_frames(library: SpriteFrameLibrary, palette_name: String) -> Dictionary:
	var palette: Array[Color] = PaletteLibrary.pair(palette_name)
	var built: Dictionary = {}
	for key in frame_paths:
		var source_frames := library.slice_frames(frame_paths[key], FRAME_SIZE)
		var recolored: Array[Texture2D] = []
		for source in source_frames:
			recolored.append(_recolor_frame(source, palette[0], palette[1]))
		built[key] = recolored
	return built


func precache_all_palettes(root: Object) -> void:
	gameplay_root = root
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary
	if library == null:
		return
	for palette_name in PaletteLibrary.PALETTE_NAMES:
		if not frames_by_palette.has(palette_name):
			frames_by_palette[palette_name] = _build_palette_frames(library, palette_name)


func _recolor_frame(source: Texture2D, main_color: Color, highlight_color: Color) -> Texture2D:
	var image := source.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			var rgb := Color8(int(color.r * 255.0), int(color.g * 255.0), int(color.b * 255.0))
			if rgb == PaletteLibrary.normal("blue"):
				image.set_pixel(x, y, Color(highlight_color.r, highlight_color.g, highlight_color.b, color.a))
			elif rgb == PaletteLibrary.normal("grey"):
				var tinted := color.lerp(main_color, 0.35)
				image.set_pixel(x, y, Color(tinted.r, tinted.g, tinted.b, color.a))
			elif rgb == PaletteLibrary.accent("grey"):
				var brightened := color.lerp(Color.WHITE, 0.3)
				image.set_pixel(x, y, Color(brightened.r, brightened.g, brightened.b, color.a))
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
	if imbue_remaining > 0.0:
		imbue_remaining = maxf(imbue_remaining - maxf(delta, 0.0), 0.0)
		imbue_flash_timer = maxf(imbue_flash_timer - maxf(delta, 0.0), 0.0)
		imbue_particle_timer -= maxf(delta, 0.0)
		if imbue_particle_timer <= 0.0:
			_spawn_imbue_bleed(root)
			imbue_particle_timer = IMBUE_PARTICLE_INTERVAL
		if imbue_remaining <= 0.0:
			end_imbue(root)
	if bool(root.get("player_is_rolling")) and active and fade_timer <= 0.0:
		fade_timer = FLASH_TIME
		active = false
		shield_is_out = false
		roll_fizzle_active = true
		roll_fizzle_positions.clear()
		for layer in layers.values():
			var equipment_layer := layer as Sprite2D
			if equipment_layer.visible:
				roll_fizzle_positions[equipment_layer] = equipment_layer.global_position
		_create_fade_overlays(root)
		breakup_pending = true
		breakup_started = false
	guard_flash_timer = maxf(guard_flash_timer - delta, 0.0)
	_update_guard_flash(root)
	var attacking := bool(root.get("player_is_attacking"))
	var magic_casting := bool(root.get("player_is_magic_casting"))
	var defending := bool(root.get("player_is_defending"))
	if magic_casting:
		_clear_fade_overlays()
		_clear_draw_overlays()
		active = true
		shield_is_out = true
		inactivity_timer = 0.0
		fade_timer = 0.0
	if defending and not shield_is_out:
		# Guard deployment uses the same white draw flash as the sword.
		_clear_fade_overlays()
		_clear_draw_overlays()
		draw_white_timer = DRAW_WHITE_TIME
		draw_color_fade_timer = DRAW_COLOR_FADE_TIME
		active = true
		fade_timer = 0.0
		inactivity_timer = 0.0
		shield_is_out = true
	was_defending = defending
	if defending:
		active = true
		fade_timer = 0.0
		inactivity_timer = 0.0
	if attacking:
		_clear_fade_overlays()
		if not active:
			draw_white_timer = DRAW_WHITE_TIME
			draw_color_fade_timer = DRAW_COLOR_FADE_TIME
			shield_is_out = true
		var current_animation_name := String(root.get("player_anim_name"))
		if current_animation_name.begins_with("attack") or current_animation_name == "spin_attack":
			last_attack_name = current_animation_name
		active = true
		inactivity_timer = 0.0
		fade_timer = 0.0
		was_attacking = true
	elif not defending and not magic_casting:
		if was_attacking:
			transition_hold_timer = ATTACK_TRANSITION_HOLD
		was_attacking = false
		if active:
			inactivity_timer += delta
			if inactivity_timer >= INACTIVITY_TIME:
				fade_timer = maxf(fade_timer, FADE_TIME)
				inactivity_timer = 0.0
				active = false
				shield_is_out = false
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
	_update_imbue_overlays(root)


func begin_attack_visual(root: Object) -> void:
	# Attack sprites are initialized immediately by PlayerAttackComponent. Keep
	# equipment and shadow layers in lockstep instead of leaving the previous
	# idle/attack frame visible until the next gameplay tick.
	_clear_fade_overlays()
	_clear_draw_overlays()
	active = true
	shield_is_out = true
	was_attacking = true
	inactivity_timer = 0.0
	fade_timer = 0.0
	last_attack_name = String(root.get("player_anim_name"))
	_update_layers(root)


func finish_spin_attack_visual(root: Object) -> void:
	# Spin's authored final frames are the complete recovery. Clear the generic
	# attack hold immediately so the equipment cannot display a between/after
	# layer after the body has already returned to idle.
	was_attacking = false
	last_attack_name = ""
	transition_hold_timer = 0.0
	_update_layers(root)


func interrupt_attack(root: Object) -> void:
	# Orb knockback cancels the attack instead of entering the normal between-
	# attack presentation. Clear the component's own transition memory too, or
	# its equipment layers can leave a delayed attack sprite behind the player.
	was_attacking = false
	last_attack_name = "attack1"
	transition_hold_timer = 0.0
	draw_white_timer = 0.0
	draw_color_fade_timer = 0.0
	_clear_fade_overlays()
	_clear_draw_overlays()
	if active:
		inactivity_timer = 0.0
		_update_layers(root)


func begin_death(root: Object) -> void:
	# Death supersedes every equipment lifecycle. In particular, an inactivity or
	# roll fizzle may have active overlays while `active` is already false.
	end_imbue(root)
	active = false
	shield_is_out = false
	was_attacking = false
	inactivity_timer = 0.0
	fade_timer = 0.0
	transition_hold_timer = 0.0
	roll_fizzle_active = false
	roll_fizzle_positions.clear()
	breakup_pending = false
	breakup_started = false
	draw_white_timer = 0.0
	draw_color_fade_timer = 0.0
	_hide_equipment_shadows()
	_clear_fade_overlays()
	_clear_draw_overlays()
	occlusion_texture_cache.clear()
	var player := root.get("player") as Sprite2D
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if equipment_layer.visible:
			if player != null:
				equipment_layer.global_position = player.global_position + EQUIPMENT_TEXTURE_OFFSET
			_set_layer_opacity(equipment_layer, 1.0)
	_create_fade_overlays(root)
	death_active = true
	death_breakup_started = false


func reset_for_room(root: Object) -> void:
	# Room transitions keep this component alive. Preserve an applied IMBUE while
	# clearing only presentation artifacts that cannot safely cross the room
	# rebuild. Death and new-run resets call end_imbue separately.
	var restore_imbue := imbue_remaining > 0.0 and imbue_element != ElementCatalogScript.Element.NEUTRAL
	var preserved_imbue_element := imbue_element
	var preserved_imbue_remaining := imbue_remaining
	var restore_equipment := active
	_clear_imbue_overlays()
	var imbue_effects := root.get("effects_spawner") as EffectsSpawner
	if imbue_effects != null:
		imbue_effects.clear_effect_particles(&"imbue_weapon")
	active = false
	shield_is_out = false
	was_attacking = false
	was_defending = false
	inactivity_timer = 0.0
	fade_timer = 0.0
	transition_hold_timer = 0.0
	roll_fizzle_active = false
	roll_fizzle_positions.clear()
	breakup_pending = false
	breakup_started = false
	death_active = false
	death_breakup_started = false
	draw_white_timer = 0.0
	draw_color_fade_timer = 0.0
	guard_flash_timer = 0.0
	if guard_flash_overlay != null:
		guard_flash_overlay.queue_free()
		guard_flash_overlay = null
	_clear_fade_overlays()
	_clear_draw_overlays()
	var effects := root.get("effects_spawner") as EffectsSpawner
	if effects != null:
		effects.clear_effect_particles(&"equipment_fizzle")
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if equipment_layer == null:
			continue
		_set_layer_opacity(equipment_layer, 1.0)
		equipment_layer.visible = false
	_hide_equipment_shadows()
	if restore_imbue:
		imbue_element = preserved_imbue_element
		imbue_remaining = preserved_imbue_remaining
		imbue_flash_timer = 0.0
		imbue_particle_timer = 0.0
	else:
		imbue_element = ElementCatalogScript.Element.NEUTRAL
		imbue_remaining = 0.0
		imbue_flash_timer = 0.0
		imbue_particle_timer = 0.0
	if restore_equipment:
		active = true
		inactivity_timer = 0.0
		_update_layers(root)
	_update_imbue_overlays(root)


func tick_death_pending(root: Object) -> void:
	# The player may still be completing fatal-hit knockback before the death
	# effect starts. Keep equipment attached and cancel attack/draw artifacts.
	var player := root.get("player") as Sprite2D
	if player == null:
		return
	draw_white_timer = 0.0
	draw_color_fade_timer = 0.0
	_clear_draw_overlays()
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if equipment_layer.visible:
			equipment_layer.global_position = player.global_position + EQUIPMENT_TEXTURE_OFFSET
	_update_equipment_shadows()


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
		_clear_fade_overlays()
		_clear_draw_overlays()
		death_active = false


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
	# Guard deployment uses the same draw effect, but a blocked hit should read as
	# shield impact. Keep the sword layers completely out of this white overlay.
	var defending := gameplay_root != null and bool(gameplay_root.get("player_is_defending"))
	for layer in layers.values():
		var equipment_layer := layer as Sprite2D
		if defending and equipment_layer.name.begins_with("EquipmentSword"):
			var sword_overlay := draw_overlays.get(equipment_layer) as Sprite2D
			if sword_overlay != null:
				sword_overlay.visible = false
			_set_layer_opacity(equipment_layer, 1.0)
			continue
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
		effects.spawn_player_death_particles(root, equipment_layer.texture, equipment_layer.global_position, Vector2.ZERO, Vector2.ONE, equipment_layer.z_index + 1, 0.75, random_source.randi(), Callable(root, "_pixel_particle_texture"), equipment_layer.flip_h, &"equipment_fizzle")
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
	var currently_magic_casting := bool(root.get("player_is_magic_casting"))
	var state := "idle"
	if currently_magic_casting: state = "magic"
	elif bool(root.get("player_is_defending")): state = "defend"
	elif currently_attacking and animation_name == "spin_attack": state = "spin"
	elif currently_attacking and animation_name == "attack1": state = "attack1"
	elif currently_attacking and (animation_name == "attack2" or animation_name == "attack2_charged"): state = "attack2"
	elif currently_attacking and animation_name == "charge": state = "between"
	elif transition_hold_timer > 0.0 and last_attack_name == "attack2": state = "after"
	elif transition_hold_timer > 0.0: state = "between"
	elif float(root.get("player_between_timer")) > 0.0 and last_attack_name == "attack2": state = "after"
	elif float(root.get("player_between_timer")) > 0.0: state = "between"
	elif animation_name == "walk": state = "walk"
	elif animation_name == "between": state = "between"
	var guard := root.get("player_guard_component") as PlayerGuardComponent
	var equipment := root.get("player_equipment") as EquipmentComponent
	var shield_available := equipment != null and equipment.has_shield and (guard == null or guard.cooldown_timer <= 0.0)
	var sword_back_key := "sword_back_spin" if state == "spin" else "sword_back_%s" % ("attack" if state == "attack1" else state)
	var shield_back_key := "shield_back_spin" if state == "spin" else "shield_back_%s" % ("attack1" if state == "attack1" else "attack2" if state == "attack2" else "between")
	var shield_front_key := "shield_front_spin" if state == "spin" else "shield_front_%s" % ("attack1" if state == "attack1" else "attack2" if state == "attack2" else "between" if state == "between" else "after" if state == "after" else state)
	var sword_front_key := "sword_front_spin" if state == "spin" else "sword_front_%s" % ("attack1" if state == "attack1" else "attack2" if state == "attack2" else "between" if state == "between" else "after" if state == "after" else state)
	var sword_back_visible := state != "attack2"
	if state == "magic":
		_set_layer("EquipmentSwordBack", frames.get("sword_magic"), frame_index, opacity, true, "sword_magic")
		_set_layer("EquipmentShieldBack", null, frame_index, opacity, false)
		_set_layer("EquipmentShieldFront", frames.get("shield_magic"), frame_index, opacity, shield_available, "shield_magic")
		_set_layer("EquipmentSwordFront", null, frame_index, opacity, false)
	else:
		_set_layer("EquipmentSwordBack", frames.get(sword_back_key), frame_index, opacity, sword_back_visible, sword_back_key)
		_set_layer("EquipmentShieldBack", frames.get(shield_back_key), frame_index, opacity, shield_available and (state.begins_with("attack") or state == "spin" or state == "between"), shield_back_key)
		_set_layer("EquipmentShieldFront", frames.get(shield_front_key), frame_index, opacity, shield_available, shield_front_key)
		_set_layer("EquipmentSwordFront", frames.get(sword_front_key), frame_index, opacity, state.begins_with("attack") or state == "spin" or state == "between" or state == "after", sword_front_key)
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


func flash_guard(root: Object) -> void:
	guard_flash_timer = 0.12
	_update_guard_flash(root)


func break_guard(root: Object) -> void:
	shield_is_out = false
	var shield := layers.get("EquipmentShieldFront") as Sprite2D
	if shield == null or not shield.visible or shield.texture == null:
		shield = layers.get("EquipmentShieldBack") as Sprite2D
	if shield != null and shield.texture != null:
		var effects := root.get("effects_spawner") as EffectsSpawner
		var random_source := root.get("rng") as RandomNumberGenerator
		if effects != null and random_source != null:
			effects.spawn_player_death_particles(root, _white_copy(shield.texture), shield.global_position, Vector2.ZERO, Vector2.ONE, shield.z_index + 2, 0.75, random_source.randi(), Callable(root, "_pixel_particle_texture"), shield.flip_h, &"equipment_fizzle")
	for layer_name in ["EquipmentShieldFront", "EquipmentShieldBack"]:
		var layer := layers.get(layer_name) as Sprite2D
		if layer != null:
			layer.visible = false
	guard_flash_timer = 0.0
	if guard_flash_overlay != null:
		guard_flash_overlay.queue_free()
		guard_flash_overlay = null
	_hide_equipment_shadows()


func _update_guard_flash(root: Object) -> void:
	if guard_flash_timer <= 0.0:
		if guard_flash_overlay != null:
			guard_flash_overlay.queue_free()
			guard_flash_overlay = null
		return
	var shield := layers.get("EquipmentShieldFront") as Sprite2D
	if shield == null or not shield.visible or shield.texture == null:
		return
	if guard_flash_overlay == null:
		guard_flash_overlay = Sprite2D.new()
		guard_flash_overlay.name = "GuardHitWhite"
		guard_flash_overlay.centered = shield.centered
		guard_flash_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		guard_flash_overlay.z_as_relative = false
		root.add_child(guard_flash_overlay)
	guard_flash_overlay.texture = _white_copy(shield.texture)
	guard_flash_overlay.global_position = shield.global_position
	guard_flash_overlay.flip_h = shield.flip_h
	guard_flash_overlay.z_index = shield.z_index + 2
	guard_flash_overlay.modulate = Color.WHITE


func _clear_imbue_overlays() -> void:
	for overlay in imbue_outline_overlays.values():
		var sprite := overlay as Sprite2D
		if sprite != null:
			sprite.queue_free()
	imbue_outline_overlays.clear()
	for overlay in imbue_flash_overlays.values():
		var sprite := overlay as Sprite2D
		if sprite != null:
			sprite.queue_free()
	imbue_flash_overlays.clear()


func _update_imbue_overlays(root: Object) -> void:
	if imbue_remaining <= 0.0 or imbue_element == ElementCatalogScript.Element.NEUTRAL:
		_clear_imbue_overlays()
		return
	var outline_color := ElementCatalogScript.damage_number_color(imbue_element)
	var flash_color := PaletteLibrary.accent(ElementCatalogScript.palette_key(imbue_element)).lerp(Color.WHITE, 0.20)
	var outline_alpha := clampf(imbue_remaining / IMBUE_FADE_TIME, 0.0, 1.0) * 0.9
	var flash_alpha := clampf(imbue_flash_timer / IMBUE_FLASH_TIME, 0.0, 1.0)
	var visible_layers: Dictionary = {}
	for layer_name in [&"EquipmentSwordBack", &"EquipmentSwordFront"]:
		var layer := layers.get(layer_name) as Sprite2D
		if layer == null or not layer.visible or layer.texture == null:
			continue
		visible_layers[layer] = true
		var outline := imbue_outline_overlays.get(layer) as Sprite2D
		if outline == null:
			outline = Sprite2D.new()
			outline.name = "%sImbueOutline" % layer.name
			outline.centered = layer.centered
			outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			outline.z_as_relative = false
			root.add_child(outline)
			imbue_outline_overlays[layer] = outline
		outline.texture = _imbue_outline_texture(layer.texture, outline_color)
		outline.global_position = layer.global_position
		outline.offset = layer.offset + Vector2(-1.0, -1.0)
		outline.flip_h = layer.flip_h
		# Match the sword layer's depth exactly. The back sword must remain behind
		# the player instead of letting its outline render through the body.
		outline.z_index = layer.z_index
		outline.modulate = Color(1.0, 1.0, 1.0, outline_alpha)
		outline.visible = outline_alpha > 0.0
		var flash := imbue_flash_overlays.get(layer) as Sprite2D
		if flash == null:
			flash = Sprite2D.new()
			flash.name = "%sImbueFlash" % layer.name
			flash.centered = layer.centered
			flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			flash.z_as_relative = false
			root.add_child(flash)
			imbue_flash_overlays[layer] = flash
		flash.texture = _imbue_color_texture(layer.texture, flash_color)
		flash.global_position = layer.global_position
		flash.offset = layer.offset
		flash.flip_h = layer.flip_h
		flash.z_index = layer.z_index
		flash.modulate = Color(1.0, 1.0, 1.0, flash_alpha)
		flash.visible = flash_alpha > 0.0
	for layer in imbue_outline_overlays:
		if not visible_layers.has(layer):
			(imbue_outline_overlays[layer] as Sprite2D).visible = false
	for layer in imbue_flash_overlays:
		if not visible_layers.has(layer):
			(imbue_flash_overlays[layer] as Sprite2D).visible = false


func _imbue_color_texture(source: Texture2D, color: Color) -> Texture2D:
	if source == null:
		return null
	var key := "%s:%s" % [source.get_instance_id(), color.to_html(false)]
	if imbue_color_texture_cache.has(key):
		return imbue_color_texture_cache[key] as Texture2D
	var image := source.get_image().duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var source_color: Color = image.get_pixel(x, y)
			if source_color.a > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, source_color.a))
	var texture := ImageTexture.create_from_image(image)
	imbue_color_texture_cache[key] = texture
	return texture


func _imbue_outline_texture(source: Texture2D, color: Color) -> Texture2D:
	if source == null:
		return null
	var key := "%s:%s" % [source.get_instance_id(), color.to_html(false)]
	if imbue_outline_texture_cache.has(key):
		return imbue_outline_texture_cache[key] as Texture2D
	var image := source.get_image()
	var output := Image.create(image.get_width() + 2, image.get_height() + 2, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = Vector2i(x, y) + offset
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= image.get_width() or neighbor.y >= image.get_height() or image.get_pixelv(neighbor).a <= 0.0:
					output.set_pixel(x + 1 + offset.x, y + 1 + offset.y, color)
	var texture := ImageTexture.create_from_image(output)
	imbue_outline_texture_cache[key] = texture
	return texture


func _imbue_bleed_positions(source: Texture2D) -> Array:
	if source == null:
		return []
	var key := source.get_instance_id()
	if imbue_bleed_positions_cache.has(key):
		return imbue_bleed_positions_cache[key] as Array
	var image := source.get_image()
	var positions: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			var edge := false
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = Vector2i(x, y) + offset
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= image.get_width() or neighbor.y >= image.get_height() or image.get_pixelv(neighbor).a <= 0.0:
					edge = true
			if edge:
				positions.append(Vector2i(x, y))
	if positions.is_empty():
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.0:
					positions.append(Vector2i(x, y))
	imbue_bleed_positions_cache[key] = positions
	return positions


func _spawn_imbue_bleed(root: Object) -> void:
	var effects := root.get("effects_spawner") as EffectsSpawner
	if effects == null:
		return
	var random_source := root.get("rng") as RandomNumberGenerator
	if random_source == null:
		random_source = RandomNumberGenerator.new()
	var bleed_color := ElementCatalogScript.damage_number_color(imbue_element)
	for layer_name in [&"EquipmentSwordBack", &"EquipmentSwordFront"]:
		var layer := layers.get(layer_name) as Sprite2D
		if layer == null or not layer.visible or layer.texture == null:
			continue
		var positions := _imbue_bleed_positions(layer.texture)
		if positions.is_empty():
			continue
		var source_pixel: Vector2i = positions[random_source.randi_range(0, positions.size() - 1)]
		var pixel_x := layer.texture.get_width() - 1 - source_pixel.x if layer.flip_h else source_pixel.x
		var particle := Sprite2D.new()
		particle.name = "ImbueWeaponPixel"
		particle.texture = root.call("_pixel_particle_texture", bleed_color) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		# Keep bleed pixels on the same depth plane as the sword that spawned them.
		particle.z_index = layer.z_index
		var origin := layer.global_position + Vector2(pixel_x, source_pixel.y)
		particle.position = origin
		root.add_child(particle)
		var noise_value := imbue_noise.get_noise_2d(float(source_pixel.x), float(source_pixel.y) + float(Time.get_ticks_msec()) * 0.002)
		var lifetime := random_source.randf_range(0.45, 0.90)
		effects.pixel_particles.append({"sprite": particle, "velocity": Vector2(noise_value * 5.0, -(8.0 + (noise_value + 1.0) * 14.0)), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0, "effect_tag": &"imbue_weapon", "logical_position": origin})


func _set_layer(layer_name: String, source: Variant, frame_index: int, opacity: float, should_show := true, grey_key: String = "") -> void:
	var layer := layers.get(layer_name) as Sprite2D
	if layer == null or source == null or not should_show:
		if layer != null: layer.visible = false
		return
	var texture_frames := source as Array
	if texture_frames == null or texture_frames.is_empty():
		layer.visible = false
		return
	var resolved_frame := mini(frame_index, texture_frames.size() - 1)
	layer.texture = texture_frames[resolved_frame]
	layer.set_meta("mp_grey_key", grey_key)
	layer.set_meta("mp_grey_frame", resolved_frame)
	_apply_mp_material(layer)
	var player := gameplay_root.get("player") as Sprite2D
	if player == null:
		layer.visible = false
		return
	layer.global_position = player.global_position + EQUIPMENT_TEXTURE_OFFSET
	var animation_name := String(gameplay_root.get("player_anim_name"))
	var attack_animation := animation_name.begins_with("attack") or animation_name == "spin_attack"
	var facing_left := bool(gameplay_root.get("player_magic_flip_h")) if animation_name == "magic" else player.flip_h
	if animation_name != "magic":
		var guard := gameplay_root.get("player_guard_component") as PlayerGuardComponent
		if guard != null and bool(gameplay_root.get("player_is_defending")):
			facing_left = guard.facing_left
		elif not attack_animation and bool(gameplay_root.call("_is_target_input_held")):
			var target := gameplay_root.call("_valid_current_target") as Sprite2D
			if target != null and not bool(gameplay_root.get("player_is_attacking")):
				facing_left = bool(gameplay_root.call("_target_facing_left", target))
	layer.flip_h = bool(gameplay_root.get("player_attack_flip_h")) if attack_animation else facing_left
	_set_layer_opacity(layer, opacity)
	layer.visible = true


func _set_layer_opacity(layer: Sprite2D, opacity: float) -> void:
	var clamped_opacity := clampf(opacity, 0.0, 1.0)
	layer_opacities[layer] = clamped_opacity
	layer.modulate = Color(1.0, 1.0, 1.0, clamped_opacity)
