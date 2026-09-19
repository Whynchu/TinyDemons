extends Node
class_name MagicRuntimeController

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const ChromaComponentScript = preload("res://scripts/player_chroma_component.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

const GREY_MAGIC_DAMAGE_MULTIPLIER := 1.10
const ELEMENTAL_MAGIC_DAMAGE_MULTIPLIER := 1.15
const MAGIC_KNOCKBACK_MULTIPLIER := 0.25
const MAGIC_FRAME_COUNT := 5
const MAGIC_CAST_FRAME_INDEX := 2
const MAGIC_FRAME_TIME_SCALE := 1.20
const IMBUE_MAGIC_FRAME_COUNT := 9
const IMBUE_EFFECT_FRAME_INDEX := 4
const IMBUE_COST := 40
const IMBUE_DURATION := 15.0
const IMBUE_COOLDOWN := 20.0
const IMBUE_HOLD_THRESHOLD := 0.35

var magic_animation_active := false
var magic_animation_timer := 0.0
var magic_animation_frame := 0
var pending_magic_direction := Vector2.RIGHT
var pending_magic_target: Sprite2D = null
var pending_magic_mode := ChromaComponentScript.AbilityMode.GRAY
var pending_magic_projectile_spawned := false
var magic_animation_is_imbue := false
var pending_imbue_element := ElementCatalogScript.Element.NEUTRAL
var pending_imbue_activated := false
var magic_cast_decided := false
var magic_hold_timer := 0.0
var magic_hold_active := false
var magic_hold_triggered := false
var imbue_cooldown_remaining := 0.0
var imbue_remaining := 0.0
var imbued_element := ElementCatalogScript.Element.NEUTRAL


func update_player_mp_ui(context: MagicRuntimeContext) -> void:
	# The visual state must update even while the MP HUD is not built or visible.
	# In particular, a spell can consume MP before the HUD is ready.
	context.update_mp_desaturation.call()
	var fill := context.player_mp_fill_get.call() as Sprite2D
	if fill == null:
		return
	var fill_size: Vector2 = context.player_mp_fill_size_get.call()
	if fill_size == Vector2.ZERO and fill.texture != null:
		fill_size = fill.texture.get_size()
	if fill_size == Vector2.ZERO:
		fill_size = Vector2(82, 16)
	context.player_mp_fill_size_set.call(fill_size)
	var max_mp := float(context.imbue_mp_cost) if context.player_tuning == null else 100.0
	var chroma := current_player_chroma(context)
	if context.hud_controller != null:
		context.hud_controller.call("set_fill_ratio", fill, fill_size, clampf(chroma / max_mp, 0.0, 1.0))
	var text := context.player_mp_text_get.call() as Sprite2D
	if text != null:
		text.texture = context.pixel_text_texture.call("%d/%d" % [ceili(chroma), int(max_mp)], Color.WHITE)


func current_player_chroma(context: MagicRuntimeContext) -> float:
	var component := context.player_chroma_component
	return float(component.get("current_chroma")) if component != null and is_instance_valid(component) else 0.0


func restore_player_mp(context: MagicRuntimeContext) -> void:
	var component := context.player_chroma_component
	if component == null or not is_instance_valid(component):
		return
	# refill_chroma() reawakens that identity before restoring the bar.
	component.call("refill_chroma")
	context.sync_chroma_presentation.call()
	context.update_player_mp_ui.call()


func update_magic_input(context: MagicRuntimeContext, magic_down: bool, was_down: bool, delta: float) -> bool:
	var hold_threshold := _hold_threshold(context)
	if magic_down:
		if not was_down:
			magic_hold_active = _begin_magic_candidate(context)
			magic_hold_triggered = false
			magic_hold_timer = 0.0
			return false
		if magic_hold_active and not magic_hold_triggered:
			magic_hold_timer += maxf(delta, 0.0)
			if magic_hold_timer >= hold_threshold:
				magic_hold_triggered = true
				return try_cast_imbue(context, true)
		return false
	if was_down and magic_hold_active:
		var imbue_was_triggered := magic_hold_triggered
		var accepted := false
		if not imbue_was_triggered:
			accepted = try_cast_magic(context, true)
		magic_hold_active = false
		magic_hold_triggered = false
		magic_hold_timer = 0.0
		if imbue_was_triggered:
			# A failed IMBUE attempt must not fall through into a normal spell.
			if magic_animation_active and not magic_animation_is_imbue:
				cancel_magic_animation(context)
		elif not accepted:
			cancel_magic_animation(context)
		return accepted
	return false


func _begin_magic_candidate(context: MagicRuntimeContext) -> bool:
	if _magic_action_blocked(context):
		return false
	var current := context.valid_current_target.call() as Sprite2D
	var target := current if current != null and bool(context.is_slime_targetable.call(current)) else context.closest_target.call() as Sprite2D
	var player := context.player
	var direction := Vector2.RIGHT
	if target != null:
		var to_target: Vector2 = magic_target_point(context, target) - player_visual_center(context)
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else direction
	else:
		var last_input: Vector2 = context.last_player_input_direction_get.call()
		direction = last_input.normalized() if last_input.length_squared() > 0.0001 else (Vector2.LEFT if player != null and player.flip_h else Vector2.RIGHT)
	return begin_magic_animation(context, direction, target, ChromaComponentScript.AbilityMode.GRAY, false, true)


func _magic_action_blocked(context: MagicRuntimeContext, allow_candidate := false) -> bool:
	if bool(context.player_is_attacking_get.call()) or bool(context.player_is_rolling_get.call()) or bool(context.player_is_backflipping_get.call()) or bool(context.player_is_defending_get.call()) or bool(context.player_dead_get.call()):
		return true
	if bool(context.player_is_magic_casting_get.call()) and not (allow_candidate and magic_animation_active and magic_hold_active and not magic_animation_is_imbue):
		return true
	return false


func _hold_threshold(context: MagicRuntimeContext) -> float:
	return maxf(context.imbue_hold_threshold, 0.01)


func try_cast_magic(context: MagicRuntimeContext, allow_candidate := false) -> bool:
	if _magic_action_blocked(context, allow_candidate):
		return false
	var ability := context.player_aspect_ability_component
	var chroma := context.player_chroma_component
	if ability == null or chroma == null:
		return false
	var accepted := bool(ability.call("try_activate", chroma, context.execute_current_aspect_ability))
	if accepted:
		context.sync_chroma_presentation.call()
		context.update_player_mp_ui.call()
	return accepted


func try_cast_imbue(context: MagicRuntimeContext, allow_candidate := false) -> bool:
	if _magic_action_blocked(context, allow_candidate):
		return false
	if imbue_cooldown_remaining > 0.0:
		return false
	var chroma := context.player_chroma_component
	if chroma == null or not is_instance_valid(chroma):
		return false
	var aspect := int(chroma.get("current_aspect"))
	var element := ElementCatalogScript.element_for_aspect(aspect)
	var cost := context.imbue_mp_cost
	if element == ElementCatalogScript.Element.NEUTRAL or not bool(chroma.call("can_spend_chroma", cost)):
		return false
	var player := context.player
	var direction := Vector2.LEFT if player != null and player.flip_h else Vector2.RIGHT
	var target := context.valid_current_target.call() as Sprite2D
	if target != null and bool(context.is_slime_targetable.call(target)):
		var to_target: Vector2 = magic_target_point(context, target) - player_visual_center(context)
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else direction
	pending_imbue_element = element as ElementCatalogScript.Element
	var candidate := allow_candidate and magic_animation_active and magic_hold_active and not magic_animation_is_imbue
	if candidate:
		magic_animation_is_imbue = true
		magic_cast_decided = true
		pending_magic_target = null
		pending_magic_mode = ChromaComponentScript.AbilityMode.GRAY
		pending_imbue_activated = false
		if magic_animation_frame >= IMBUE_EFFECT_FRAME_INDEX:
			magic_animation_frame = IMBUE_EFFECT_FRAME_INDEX
			_apply_magic_animation_frame(context, magic_animation_frame)
			_activate_pending_imbue(context)
		return true
	return begin_magic_animation(context, direction, null, ChromaComponentScript.AbilityMode.GRAY, true)


func sync_chroma_presentation(context: MagicRuntimeContext) -> void:
	var component := context.player_chroma_component
	if component == null:
		return
	var flame := String(component.call("aspect_name"))
	# Zero Chroma desaturates through the shared MP material. It does not erase
	# the bound elemental identity or make the palette flash back to Gray.
	var palette := "grey" if flame == "gray" else AspectCatalogScript.palette_for_flame(StringName(flame))
	if palette.is_empty() or palette == String(context.current_player_palette_name_get.call()):
		return
	context.start_player_palette_flash.call(palette)


func execute_current_aspect_ability(context: MagicRuntimeContext, mode: int) -> bool:
	if magic_animation_active and magic_hold_active and not magic_animation_is_imbue:
		pending_magic_mode = mode as ChromaComponentScript.AbilityMode
		magic_cast_decided = true
		if magic_animation_frame >= MAGIC_CAST_FRAME_INDEX and not pending_magic_projectile_spawned:
			_spawn_pending_magic_projectile(context)
		return true
	var current := context.valid_current_target.call() as Sprite2D
	var target := current if current != null and bool(context.is_slime_targetable.call(current)) else context.closest_target.call() as Sprite2D
	var direction := Vector2.RIGHT
	if target != null:
		var to_target: Vector2 = magic_target_point(context, target) - player_visual_center(context)
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.RIGHT
	else:
		var last_input: Vector2 = context.last_player_input_direction_get.call()
		direction = last_input.normalized() if last_input.length_squared() > 0.0001 else Vector2.RIGHT
	return begin_magic_animation(context, direction, target, mode)


func begin_magic_animation(context: MagicRuntimeContext, direction: Vector2, target: Sprite2D, mode: int, is_imbue := false, is_candidate := false) -> bool:
	if magic_animation_active:
		return false
	magic_animation_active = true
	magic_animation_timer = 0.0
	magic_animation_frame = 0
	pending_magic_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	pending_magic_target = target if target != null and is_instance_valid(target) else null
	pending_magic_mode = mode as ChromaComponentScript.AbilityMode
	pending_magic_projectile_spawned = false
	magic_animation_is_imbue = is_imbue
	pending_imbue_activated = false
	magic_cast_decided = not is_candidate
	context.player_is_magic_casting_set.call(true)
	var remembered_facing_left := bool(context.last_player_facing_left_get.call())
	var magic_facing_left := pending_magic_direction.x < 0.0 if absf(pending_magic_direction.x) > ActorMotor.HORIZONTAL_FACING_DEADZONE else remembered_facing_left
	context.player_magic_flip_h_set.call(magic_facing_left)
	context.player_anim_name_set.call("magic")
	context.player_anim_frame_set.call(0)
	context.player_anim_timer_set.call(0.0)
	var player := context.player
	if player != null:
		player.flip_h = magic_facing_left
	_apply_magic_animation_frame(context, 0)
	return true


func _apply_magic_animation_frame(context: MagicRuntimeContext, frame: int) -> void:
	# Magic owns the player presentation until the cast finishes. A leftover
	# walk/attack frame can otherwise be selected while an IMBUE timeline is
	# still advancing. Magic uses the authored five-frame cast timeline.
	context.player_anim_name_set.call("magic")
	context.player_anim_frame_set.call(frame)
	var animation := context.player_animation_component
	if animation != null:
		animation.apply_frame(context.build_animation_context.call())


func magic_frame_time(context: MagicRuntimeContext) -> float:
	var tuning := context.player_tuning
	if tuning == null:
		return 0.108
	var agi_value: Variant = context.player_agi_get.call()
	var effective_agi := float(agi_value) if agi_value != null else float(context.player_spd_get.call())
	var attack_multiplier := tuning.attack_multiplier_for_agi(effective_agi)
	return maxf(tuning.attack_frame_time * MAGIC_FRAME_TIME_SCALE / attack_multiplier, 0.001)


func tick_magic_animation(context: MagicRuntimeContext, delta: float) -> void:
	_tick_imbue_timers(context, delta)
	if not magic_animation_active:
		return
	magic_animation_timer += maxf(delta, 0.0)
	var frame_time := magic_frame_time(context)
	var frame_count := IMBUE_MAGIC_FRAME_COUNT if magic_animation_is_imbue else MAGIC_FRAME_COUNT
	while magic_animation_active and magic_animation_timer >= frame_time:
		magic_animation_timer -= frame_time
		magic_animation_frame += 1
		if magic_animation_frame >= frame_count:
			_finish_magic_animation(context)
			break
		_apply_magic_animation_frame(context, magic_animation_frame)
		if magic_animation_is_imbue and magic_animation_frame == IMBUE_EFFECT_FRAME_INDEX and not pending_imbue_activated:
			_activate_pending_imbue(context)
		elif not magic_animation_is_imbue and magic_cast_decided and magic_animation_frame == MAGIC_CAST_FRAME_INDEX and not pending_magic_projectile_spawned:
			_spawn_pending_magic_projectile(context)


func _tick_imbue_timers(context: MagicRuntimeContext, delta: float) -> void:
	imbue_cooldown_remaining = maxf(imbue_cooldown_remaining - maxf(delta, 0.0), 0.0)
	if imbue_remaining <= 0.0:
		return
	imbue_remaining = maxf(imbue_remaining - maxf(delta, 0.0), 0.0)
	if imbue_remaining > 0.0:
		return
	imbued_element = ElementCatalogScript.Element.NEUTRAL
	context.player_imbued_element_set.call(imbued_element)
	var equipment_visual := context.player_equipment_visual_component
	if equipment_visual != null:
		equipment_visual.end_imbue(context.build_equipment_visual_context.call())


func _activate_pending_imbue(context: MagicRuntimeContext) -> void:
	pending_imbue_activated = true
	var chroma := context.player_chroma_component
	if chroma == null or not is_instance_valid(chroma):
		return
	var cost := context.imbue_mp_cost
	if not bool(chroma.call("spend_chroma", cost)):
		return
	imbued_element = pending_imbue_element
	context.player_imbued_element_set.call(imbued_element)
	var duration := context.imbue_duration
	var cooldown := context.imbue_cooldown
	imbue_remaining = duration
	imbue_cooldown_remaining = cooldown
	var equipment_visual := context.player_equipment_visual_component
	if equipment_visual != null:
		equipment_visual.begin_imbue(context.build_equipment_visual_context.call(), imbued_element, duration)
	context.sync_chroma_presentation.call()
	context.update_player_mp_ui.call()
	context.play_sound.call("magic_cast", -8.0, 0.85)


func _spawn_pending_magic_projectile(context: MagicRuntimeContext) -> void:
	pending_magic_projectile_spawned = true
	var target := pending_magic_target if pending_magic_target != null and is_instance_valid(pending_magic_target) else null
	var origin := player_visual_center(context) + Vector2(signf(pending_magic_direction.x) * 5.0, 1.0)
	spawn_magic_projectile(context, origin, pending_magic_direction, target, pending_magic_mode)
	context.play_sound.call("magic_cast", -8.0, 1.0)


func _finish_magic_animation(context: MagicRuntimeContext) -> void:
	if magic_hold_active and not magic_animation_is_imbue and not magic_cast_decided:
		# The short-press path may not be known yet. Hold the last magic frame
		# until release or until the hold threshold converts this into IMBUE.
		magic_animation_frame = MAGIC_FRAME_COUNT - 1
		magic_animation_timer = 0.0
		context.player_anim_frame_set.call(magic_animation_frame)
		var held_animation := context.player_animation_component
		if held_animation != null:
			held_animation.apply_frame(context.build_animation_context.call())
		return
	magic_animation_active = false
	magic_animation_timer = 0.0
	magic_animation_frame = 0
	pending_magic_target = null
	pending_magic_projectile_spawned = false
	magic_animation_is_imbue = false
	pending_imbue_element = ElementCatalogScript.Element.NEUTRAL
	pending_imbue_activated = false
	magic_cast_decided = false
	context.player_is_magic_casting_set.call(false)
	var player := context.player
	if player != null:
		player.flip_h = bool(context.last_player_facing_left_get.call())
	var animation := context.player_animation_component
	var movement_name := ""
	if animation != null:
		movement_name = String(animation.movement_anim_name(context.build_animation_context.call()))
	context.player_anim_name_set.call(movement_name)
	context.player_anim_frame_set.call(0)
	context.player_anim_timer_set.call(0.0)
	if animation != null:
		animation.apply_frame(context.build_animation_context.call())


func cancel_magic_animation(context: MagicRuntimeContext) -> void:
	if not magic_animation_active and not bool(context.player_is_magic_casting_get.call()):
		return
	magic_animation_active = false
	magic_animation_timer = 0.0
	magic_animation_frame = 0
	pending_magic_target = null
	pending_magic_projectile_spawned = false
	magic_animation_is_imbue = false
	pending_imbue_element = ElementCatalogScript.Element.NEUTRAL
	pending_imbue_activated = false
	magic_cast_decided = false
	magic_hold_active = false
	magic_hold_triggered = false
	magic_hold_timer = 0.0
	context.player_is_magic_casting_set.call(false)
	var player := context.player
	if player != null:
		player.flip_h = bool(context.last_player_facing_left_get.call())
	var animation := context.player_animation_component
	var movement_name := ""
	if animation != null:
		movement_name = String(animation.movement_anim_name(context.build_animation_context.call()))
	context.player_anim_name_set.call(movement_name)
	context.player_anim_frame_set.call(0)
	context.player_anim_timer_set.call(0.0)
	if animation != null:
		animation.apply_frame(context.build_animation_context.call())


func player_weapon_element(_context: MagicRuntimeContext) -> int:
	return imbued_element if imbue_remaining > 0.0 else ElementCatalogScript.Element.NEUTRAL


func reset_for_room(context: MagicRuntimeContext, reset_cooldown := false) -> void:
	cancel_magic_animation(context)
	magic_hold_active = false
	magic_hold_triggered = false
	magic_hold_timer = 0.0
	if not reset_cooldown:
		# A room transition cancels an in-progress cast, but the already-applied
		# weapon effect and its cooldown belong to the run rather than the room.
		return
	imbue_cooldown_remaining = 0.0
	imbue_remaining = 0.0
	imbued_element = ElementCatalogScript.Element.NEUTRAL
	context.player_imbued_element_set.call(imbued_element)
	var equipment_visual := context.player_equipment_visual_component
	if equipment_visual != null:
		equipment_visual.end_imbue(context.build_equipment_visual_context.call())


func player_visual_center(context: MagicRuntimeContext) -> Vector2:
	var player := context.player
	return player.global_position + Vector2(8, 7)


func slime_visual_center(_context: MagicRuntimeContext, slime: Sprite2D) -> Vector2:
	return slime.global_position + Vector2(8, 2)


func magic_target_point(context: MagicRuntimeContext, slime: Sprite2D) -> Vector2:
	var torches := context.puzzle_torches
	if torches.has(slime):
		return slime.global_position
	var body := context.slime_body_polygon.call(slime) as PackedVector2Array
	if body.size() >= 3:
		return ActorGeometry.polygon_center(body)
	return ActorGeometry.combat_target_point(context.collision_rect.call(slime) as Rect2)


func spawn_magic_projectile(context: MagicRuntimeContext, origin: Vector2, direction: Vector2, homing_target: Sprite2D = null, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY) -> void:
	var palette := String(context.current_player_palette_name_get.call())
	var base_color := PaletteLibrary.normal(palette)
	var accent_color := PaletteLibrary.accent(palette)
	var player := context.player
	var projectile := Sprite2D.new()
	projectile.name = "MagicProjectile"
	projectile.texture = context.pixel_particle_texture.call(base_color, context.magic_projectile_size) as Texture2D
	projectile.centered = true
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_as_relative = false
	projectile.z_index = player.z_index + 1
	projectile.position = origin
	_add_child_to_runtime(context, projectile)
	var outline := Sprite2D.new()
	outline.name = "MagicProjectileOutline"
	outline.texture = magic_projectile_outline_texture(context, base_color, accent_color)
	outline.centered = true
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	outline.z_as_relative = false
	outline.z_index = player.z_index + 1
	outline.position = origin
	_add_child_to_runtime(context, outline)
	var controller := context.magic_projectile_controller
	controller.spawn(projectile, outline, direction, context.magic_projectile_lifetime, palette, homing_target, ability_mode)


func _add_child_to_runtime(context: MagicRuntimeContext, node: Node) -> void:
	var parent := context.player.get_parent() if context.player != null else null
	if parent != null:
		parent.add_child(node)


func spawn_sword_beam(context: MagicRuntimeContext, origin: Vector2, direction: Vector2, palette_override: String = "") -> void:
	var player := context.player
	var palette := palette_override if not palette_override.is_empty() else String(context.current_player_palette_name_get.call())
	context.play_sound.call("sword_beam", -2.0, 1.0)
	var beam := Sprite2D.new()
	beam.name = "SwordBeam"
	beam.texture = sword_beam_texture(context, palette)
	beam.hframes = 6
	beam.frame = 0
	beam.centered = true
	beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	beam.flip_h = direction.x < 0.0
	beam.z_as_relative = false
	beam.z_index = player.z_index + 1
	beam.global_position = origin + direction.normalized() * 10.0
	_add_child_to_runtime(context, beam)
	var controller := context.magic_projectile_controller
	var ability_mode := int(context.player_chroma_component.call("ability_mode")) if context.player_chroma_component != null else ChromaComponentScript.AbilityMode.GRAY
	controller.spawn_beam(beam, direction, 0.75, palette, ability_mode)


func sword_beam_texture(context: MagicRuntimeContext, palette: String) -> Texture2D:
	var effects := context.effects_spawner
	var key := "sword_beam:%s" % palette
	if effects.pixel_particle_texture_cache.has(key):
		return effects.pixel_particle_texture_cache[key] as Texture2D
	var source := context.load_texture_or_null.call("res://assets/artwork/SwordBeam.png") as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				image.set_pixel(x, y, Color(PaletteLibrary.accent(palette), color.a))
	var texture := ImageTexture.create_from_image(image)
	effects.pixel_particle_texture_cache[key] = texture
	return texture


func magic_projectile_outline_texture(context: MagicRuntimeContext, base_color: Color, accent_color: Color) -> Texture2D:
	var effects := context.effects_spawner
	var key := "magic_outline:%s:%s" % [base_color.to_html(false), accent_color.to_html(false)]
	if effects.pixel_particle_texture_cache.has(key):
		return effects.pixel_particle_texture_cache[key]
	var size := context.magic_projectile_size + 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in size:
		for x in size:
			if x == 0 or y == 0 or x == size - 1 or y == size - 1:
				image.set_pixel(x, y, accent_color)
	var texture := ImageTexture.create_from_image(image)
	effects.pixel_particle_texture_cache[key] = texture
	return texture


func update_magic_projectiles(context: MagicRuntimeContext, delta: float) -> void:
	var controller := context.magic_projectile_controller
	controller.tick(delta, 70.0, context.snap_half_pixel, Callable(self, "_magic_target_point_callback").bind(context), context.is_slime_targetable, Callable(self, "_magic_projectile_hit_target_callback").bind(context), Callable(self, "_resolve_magic_projectile_hit_callback").bind(context), Callable(self, "_spawn_magic_trail_callback").bind(context))


func _magic_target_point_callback(slime: Sprite2D, context: MagicRuntimeContext) -> Vector2:
	return magic_target_point(context, slime)


func _magic_projectile_hit_target_callback(sprite: Sprite2D, is_beam: bool, context: MagicRuntimeContext) -> Variant:
	if is_beam:
		return magic_projectile_hit_targets(context, sprite)
	return magic_projectile_hit_target(context, sprite)


func _resolve_magic_projectile_hit_callback(target: Sprite2D, world_position: Vector2, palette: String, ability_mode: int, is_beam: bool, context: MagicRuntimeContext) -> void:
	resolve_magic_projectile_hit(context, target, world_position, palette, ability_mode, is_beam)


func _spawn_magic_trail_callback(world_position: Vector2, palette: String, is_beam: bool, facing_left: bool, context: MagicRuntimeContext) -> void:
	spawn_magic_trail(context, world_position, palette, is_beam, facing_left)


func resolve_magic_projectile_hit(context: MagicRuntimeContext, target: Sprite2D, world_position: Vector2, palette: String, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY, is_beam: bool = false) -> void:
	var torches := context.puzzle_torches
	if torches.has(target):
		context.activate_puzzle_torch.call(target, world_position, palette, false)
	else:
		context.magic_hit_slime.call(target, world_position, palette, ability_mode, is_beam)


func magic_projectile_hit_target(context: MagicRuntimeContext, sprite: Sprite2D) -> Sprite2D:
	var radius := context.magic_projectile_size * 0.5 + 2.0
	var torches := context.puzzle_torches
	for torch in torches:
		if not bool(context.is_slime_targetable.call(torch)):
			continue
		var torch_rect := Rect2(torch.global_position - Vector2(3.0, 3.0), Vector2(6.0, 6.0))
		if torch_rect.grow(radius).has_point(sprite.global_position):
			return torch
	var slimes := context.slimes
	for slime in slimes:
		if not bool(context.is_slime_targetable.call(slime)):
			continue
		if _circle_intersects_polygon(sprite.global_position, radius, context.slime_body_polygon.call(slime) as PackedVector2Array):
			return slime
	return null


func magic_projectile_hit_targets(context: MagicRuntimeContext, sprite: Sprite2D) -> Array:
	var radius := context.magic_projectile_size * 0.5 + 2.0
	if sprite.texture != null and sprite.hframes > 1:
		# The beam's collision follows its authored frame instead of the tiny
		# magic-projectile radius. This makes the complete visible blade connect.
		var frame_size := sprite.texture.get_size() / float(sprite.hframes)
		radius = maxi(radius, int(maxf(frame_size.x, frame_size.y) * 0.5 + 3.0))
	var hits: Array = []
	var slimes := context.slimes
	for slime in slimes:
		if bool(context.is_slime_targetable.call(slime)) and _circle_intersects_polygon(sprite.global_position, radius, context.slime_body_polygon.call(slime) as PackedVector2Array):
			hits.append(slime)
	return hits


func _circle_intersects_polygon(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	for index in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(center, polygon[index], polygon[(index + 1) % polygon.size()])
		if center.distance_squared_to(closest) <= radius * radius:
			return true
	return false


func magic_damage_for_mode(base_damage: float, ability_mode: int) -> float:
	var grey_damage := maxf(floorf(base_damage * GREY_MAGIC_DAMAGE_MULTIPLIER), 1.0)
	if ability_mode == ChromaComponentScript.AbilityMode.ELEMENTAL:
		var elemental_damage := floorf(base_damage * ELEMENTAL_MAGIC_DAMAGE_MULTIPLIER)
		return maxf(elemental_damage, grey_damage + 1.0)
	return grey_damage


func magic_knockback_multiplier() -> float:
	return MAGIC_KNOCKBACK_MULTIPLIER


func magic_attack_element(palette: String, ability_mode: int) -> int:
	if ability_mode == ChromaComponentScript.AbilityMode.BOUND_WEAKENED:
		return ElementCatalogScript.Element.NEUTRAL
	return ElementCatalogScript.element_for_palette(palette)


func magic_hit_slime(context: MagicRuntimeContext, slime: Sprite2D, world_position: Vector2, palette: String, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY, is_beam: bool = false) -> void:
	if slime == null or not is_instance_valid(slime) or not bool(context.is_slime_targetable.call(slime)):
		return
	var attack_element := magic_attack_element(palette, ability_mode)
	var combat_tuning := context.combat_tuning
	var magic_base_bonus := combat_tuning.elemental_magic_bonus if ability_mode == ChromaComponentScript.AbilityMode.ELEMENTAL and combat_tuning != null else 0.0
	var damage_result := context.player_magic_damage_result_against.call(slime, attack_element, magic_base_bonus) as CombatCalculator.DamageResult
	var damage := 0.0 if damage_result == null or damage_result.immune else damage_result.amount
	if is_beam and damage > 0.0:
		damage = maxf(floorf(damage * 0.35), 1.0)
	var was_critical := damage_result != null and damage_result.critical
	var immune := damage_result != null and damage_result.immune
	var resolved_element := damage_result.element if damage_result != null else attack_element
	context.damage_slime_with_number.call(slime, damage, was_critical, false, resolved_element, immune)
	if not immune and damage > 0.0 and context.record_run_style_action.is_valid():
		context.record_run_style_action.call(&"magic")
	if not immune:
		context.knockback_slime.call(slime, MAGIC_KNOCKBACK_MULTIPLIER, false)
	context.spawn_damage_number.call(slime, damage, was_critical, resolved_element, immune)
	context.play_sound.call("magic_hit", -8.0, 1.0)
	spawn_magic_impact(context, world_position, palette)


func spawn_magic_trail(context: MagicRuntimeContext, world_position: Vector2, palette: String, is_beam: bool = false, facing_left: bool = false) -> void:
	var player := context.player
	var effects := context.effects_spawner
	var rng := context.rng
	var color := PaletteLibrary.normal(palette)
	# Keep the original restrained one-pixel trail for every projectile.
	var particle := Sprite2D.new()
	if is_beam:
		# Beam trail stamps use the complete authored beam frame, not a single
		# pixel, so the fading trail preserves the weapon's silhouette.
		particle.texture = sword_beam_texture(context, palette)
		particle.hframes = 6; particle.frame = 0; particle.centered = true; particle.flip_h = facing_left
	else:
		particle.texture = context.pixel_particle_texture.call(color, 1) as Texture2D
		particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = false; particle.z_index = player.z_index if is_beam else player.z_index + 1; particle.position = world_position
	_add_child_to_runtime(context, particle)
	var lifetime := 0.35
	effects.pixel_particles.append({"sprite": particle, "velocity": Vector2.ZERO, "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})
	if is_beam:
		# Beam-only end-cap: a delayed vertical fizzle, like the sword/shield
		# put-away spark, without changing regular magic trails.
		var fizzle_lifetime := 0.22
		var fizzle := Sprite2D.new()
		fizzle.texture = sword_beam_texture(context, palette)
		fizzle.hframes = 6; fizzle.frame = 0; fizzle.centered = true; fizzle.flip_h = facing_left
		fizzle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fizzle.z_as_relative = false; fizzle.z_index = player.z_index
		fizzle.position = world_position
		_add_child_to_runtime(context, fizzle)
		var return_velocity := Vector2(24.0 if facing_left else -24.0, rng.randf_range(-3.0, 3.0))
		effects.pixel_particles.append({"sprite": fizzle, "velocity": return_velocity, "timer": lifetime + fizzle_lifetime, "lifetime": fizzle_lifetime, "gravity": 0.0, "delay": lifetime})


func spawn_magic_impact(context: MagicRuntimeContext, world_position: Vector2, palette: String) -> void:
	var player := context.player
	var rng := context.rng
	var effects := context.effects_spawner
	var color := PaletteLibrary.normal(palette)
	for i in 8:
		var particle := Sprite2D.new()
		particle.texture = context.pixel_particle_texture.call(color, 1) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		particle.position = world_position
		_add_child_to_runtime(context, particle)
		var angle := float(i) / 8.0 * TAU
		var speed := float(rng.randf_range(14.0, 30.0))
		var lifetime := float(rng.randf_range(0.3, 0.5))
		effects.pixel_particles.append({"sprite": particle, "velocity": Vector2(cos(angle), sin(angle)) * speed, "timer": lifetime, "lifetime": lifetime, "gravity": 20.0})
