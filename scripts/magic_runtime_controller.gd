extends Node
class_name MagicRuntimeController

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const ChromaComponentScript = preload("res://scripts/player_chroma_component.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const SpellFormCatalogScript = preload("res://scripts/spell_form_catalog.gd")
const SpellFormDefinitionScript = preload("res://scripts/spell_form_definition.gd")

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
const CHROMA_FILL_TWEEN_SPEED := 180.0

var magic_animation_active := false
var magic_animation_timer := 0.0
var magic_animation_frame := 0
var pending_magic_direction := Vector2.RIGHT
var pending_magic_target: Sprite2D = null
var pending_magic_mode := ChromaComponentScript.AbilityMode.GRAY
var pending_magic_projectile_spawned := false
var pending_magic_form: Resource = null
var pending_magic_palette := "grey"
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
var displayed_chroma := -1.0


func update_player_mp_ui(context: MagicRuntimeContext, delta := 0.0) -> void:
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
	if displayed_chroma < 0.0:
		displayed_chroma = chroma
	else:
		displayed_chroma = move_toward(displayed_chroma, chroma, CHROMA_FILL_TWEEN_SPEED * maxf(float(delta), 0.0))
	if is_equal_approx(displayed_chroma, chroma):
		displayed_chroma = chroma
	if context.hud_controller != null:
		context.hud_controller.set_chroma_bar_values(fill, context.hud_controller.chroma_highlight_target, fill_size, chroma, displayed_chroma, max_mp)
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
	var player := context.player
	var direction := Vector2.RIGHT
	var target: Sprite2D = null
	var pointer_aim_active := context.mouse_aim_active.is_valid() and bool(context.mouse_aim_active.call())
	if pointer_aim_active:
		var pointer_direction: Variant = context.mouse_aim_direction.call() if context.mouse_aim_direction.is_valid() else Vector2.ZERO
		if pointer_direction is Vector2 and (pointer_direction as Vector2).length_squared() > 0.0001:
			direction = pointer_direction as Vector2
		elif player != null:
			direction = Vector2.LEFT if player.flip_h else Vector2.RIGHT
	else:
		var current := context.valid_current_target.call() as Sprite2D
		target = current if current != null and bool(context.is_slime_targetable.call(current)) else context.closest_target.call() as Sprite2D
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
	var selected_form := SpellFormCatalogScript.selected_form_for(chroma)
	var neutral_stub := SpellFormCatalogScript.form_for_element(ElementCatalogScript.Element.NEUTRAL)
	var chroma_before := current_player_chroma(context)
	var feedback_color := chroma_highlight_color(context)
	var accepted := bool(ability.call("try_activate", chroma, context.execute_current_aspect_ability, false, int(selected_form.get("chroma_cost")), float(selected_form.get("cooldown")), float(neutral_stub.get("cooldown"))))
	if accepted:
		context.sync_chroma_presentation.call()
		context.update_player_mp_ui.call()
		if current_player_chroma(context) < chroma_before:
			_acknowledge_chroma_use(context, feedback_color)
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
		var candidate_form := SpellFormCatalogScript.cast_form_for(context.player_chroma_component, mode)
		var candidate_delivery := SpellFormCatalogScript.delivery_of(candidate_form)
		var candidate_target := pending_magic_target if pending_magic_target != null and is_instance_valid(pending_magic_target) and bool(context.is_slime_targetable.call(pending_magic_target)) else null
		if candidate_delivery == SpellFormDefinitionScript.Delivery.INSTANT_TARGET or candidate_delivery == SpellFormDefinitionScript.Delivery.BEAM:
			if candidate_target == null:
				var current := context.valid_current_target.call() as Sprite2D
				candidate_target = current if current != null and bool(context.is_slime_targetable.call(current)) else context.closest_target.call() as Sprite2D
			if not _form_has_required_target(context, candidate_form, candidate_target):
				return false
			pending_magic_target = candidate_target
		elif not _form_has_required_target(context, candidate_form, candidate_target):
			return false
		pending_magic_mode = mode as ChromaComponentScript.AbilityMode
		_capture_spell_selection(context, mode)
		magic_cast_decided = true
		if magic_animation_frame >= MAGIC_CAST_FRAME_INDEX and not pending_magic_projectile_spawned:
			_spawn_pending_magic_projectile(context)
		return true
	var current := context.valid_current_target.call() as Sprite2D
	var target := current if current != null and bool(context.is_slime_targetable.call(current)) else context.closest_target.call() as Sprite2D
	var selected_form := SpellFormCatalogScript.cast_form_for(context.player_chroma_component, mode)
	if not _form_has_required_target(context, selected_form, target):
		return false
	var direction := Vector2.RIGHT
	if target != null:
		var to_target: Vector2 = magic_target_point(context, target) - player_visual_center(context)
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.RIGHT
	else:
		var last_input: Vector2 = context.last_player_input_direction_get.call()
		direction = last_input.normalized() if last_input.length_squared() > 0.0001 else Vector2.RIGHT
	return begin_magic_animation(context, direction, target, mode)


func _form_has_required_target(context: MagicRuntimeContext, form: Resource, target: Sprite2D) -> bool:
	var delivery := SpellFormCatalogScript.delivery_of(form)
	if delivery != SpellFormDefinitionScript.Delivery.INSTANT_TARGET and delivery != SpellFormDefinitionScript.Delivery.BEAM:
		return true
	if target == null or not is_instance_valid(target) or not bool(context.is_slime_targetable.call(target)):
		return false
	if delivery == SpellFormDefinitionScript.Delivery.BEAM:
		return player_visual_center(context).distance_to(magic_target_point(context, target)) <= float(form.get("delivery_range"))
	return true


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
	if not is_imbue and not is_candidate:
		_capture_spell_selection(context, mode)
	else:
		pending_magic_form = null
		pending_magic_palette = "grey"
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


func _capture_spell_selection(context: MagicRuntimeContext, mode: int) -> void:
	pending_magic_form = SpellFormCatalogScript.cast_form_for(context.player_chroma_component, mode)
	var payload := ElementCatalogScript.Element.NEUTRAL
	if mode == ChromaComponentScript.AbilityMode.ELEMENTAL:
		var chroma := context.player_chroma_component
		if chroma != null and is_instance_valid(chroma):
			var current_aspect := int(chroma.get("current_aspect"))
			if current_aspect == ChromaComponentScript.Aspect.NONE:
				current_aspect = int(chroma.get("bound_aspect"))
			payload = ElementCatalogScript.element_for_aspect(current_aspect)
	pending_magic_palette = ElementCatalogScript.palette_key(payload)


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
	var feedback_color := chroma_highlight_color(context)
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
	_acknowledge_chroma_use(context, feedback_color)
	context.play_sound.call("magic_cast", -8.0, 0.85)


func chroma_highlight_color(context: MagicRuntimeContext) -> Color:
	var component := context.player_chroma_component
	if component == null or not is_instance_valid(component):
		return PaletteLibrary.accent("grey")
	var flame := String(component.call("aspect_name"))
	var palette := "grey" if flame == "gray" else AspectCatalogScript.palette_for_flame(StringName(flame))
	return PaletteLibrary.accent(palette if not palette.is_empty() else "grey")


func _acknowledge_chroma_use(context: MagicRuntimeContext, color: Color) -> void:
	if context.acknowledge_chroma_feedback.is_valid():
		context.acknowledge_chroma_feedback.call(color)


func _spawn_pending_magic_projectile(context: MagicRuntimeContext) -> void:
	pending_magic_projectile_spawned = true
	var target := pending_magic_target if pending_magic_target != null and is_instance_valid(pending_magic_target) else null
	var origin := player_visual_center(context) + Vector2(signf(pending_magic_direction.x) * 5.0, 1.0)
	deliver_spell(context, origin, pending_magic_direction, target, pending_magic_mode, pending_magic_form, pending_magic_palette)
	context.play_sound.call("magic_cast", -8.0, 1.0)


func deliver_spell(context: MagicRuntimeContext, origin: Vector2, direction: Vector2, target: Sprite2D, mode: int, form: Resource = null, palette: String = "grey") -> void:
	var resolved_form := form if form != null else SpellFormCatalogScript.cast_form_for(context.player_chroma_component, mode)
	match SpellFormCatalogScript.delivery_of(resolved_form):
		SpellFormDefinitionScript.Delivery.PROJECTILE, SpellFormDefinitionScript.Delivery.PROJECTILE_SPLASH:
			spawn_magic_projectile(context, origin, direction, target, mode, resolved_form, palette)
		SpellFormDefinitionScript.Delivery.CONE:
			deliver_cone(context, player_visual_center(context), direction, mode, resolved_form, palette)
		SpellFormDefinitionScript.Delivery.INSTANT_TARGET:
			deliver_instant_strike(context, target, mode, resolved_form, palette)
		SpellFormDefinitionScript.Delivery.BEAM:
			deliver_leechvine(context, target, mode, resolved_form, palette)
		SpellFormDefinitionScript.Delivery.RADIAL_SELF:
			deliver_quake(context, player_visual_center(context), mode, resolved_form, palette)


func deliver_instant_strike(context: MagicRuntimeContext, target: Sprite2D, mode: int, form: Resource, palette: String) -> void:
	var strike_target := target if target != null and is_instance_valid(target) else context.closest_target.call() as Sprite2D
	if strike_target == null or not is_instance_valid(strike_target) or not bool(context.is_slime_targetable.call(strike_target)):
		return
	var hit_point := magic_target_point(context, strike_target)
	spawn_sky_strike(context, hit_point, palette)
	if _try_activate_puzzle_torch(context, strike_target, hit_point, palette):
		return
	magic_hit_slime(context, strike_target, hit_point, palette, mode, false, form)


func deliver_cone(context: MagicRuntimeContext, origin: Vector2, direction: Vector2, mode: int, form: Resource, palette: String) -> void:
	var radius := float(form.get("delivery_radius"))
	var half_angle := deg_to_rad(float(form.get("delivery_angle_degrees")) * 0.5)
	var sector := _sector_polygon(origin, direction, radius, half_angle)
	for slime in context.slimes:
		if not bool(context.is_slime_targetable.call(slime)):
			continue
		var body := context.slime_body_polygon.call(slime) as PackedVector2Array
		if body.size() >= 3 and not Geometry2D.intersect_polygons(body, sector).is_empty():
			magic_hit_slime(context, slime, magic_target_point(context, slime), palette, mode, false, form)
	_activate_puzzle_torches_in_sector(context, sector, palette)
	spawn_cone_effect(context, origin, direction, radius, half_angle, palette)


func deliver_quake(context: MagicRuntimeContext, origin: Vector2, mode: int, form: Resource, palette: String) -> void:
	var hits := magic_targets_in_radius(context, origin, float(form.get("delivery_radius")))
	for slime in hits:
		var push_direction := (magic_target_point(context, slime) - origin).normalized()
		magic_hit_slime(context, slime, magic_target_point(context, slime), palette, mode, false, form, push_direction)
	_activate_puzzle_torches_in_radius(context, origin, float(form.get("delivery_radius")), palette)
	spawn_radial_burst(context, origin, palette, 16, 32.0, 52.0)


func deliver_leechvine(context: MagicRuntimeContext, target: Sprite2D, mode: int, form: Resource, palette: String) -> void:
	var beam_target := target if target != null and is_instance_valid(target) else context.closest_target.call() as Sprite2D
	if beam_target == null or not bool(context.is_slime_targetable.call(beam_target)):
		return
	var source_point := player_visual_center(context)
	if source_point.distance_to(magic_target_point(context, beam_target)) > float(form.get("delivery_range")):
		return
	if _try_activate_puzzle_torch(context, beam_target, magic_target_point(context, beam_target), palette):
		return
	var player := context.player
	var tether := Line2D.new()
	tether.name = "LeechvineTether"
	tether.width = 2.0
	tether.default_color = PaletteLibrary.normal(palette)
	tether.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tether.antialiased = false
	tether.z_as_relative = false
	tether.z_index = player.z_index + 1
	tether.add_point(Vector2.ZERO)
	tether.add_point(Vector2.ZERO)
	_add_child_to_runtime(context, tether, source_point)
	(context.magic_projectile_controller as MagicProjectileController).spawn_tether(tether, player, beam_target, float(form.get("delivery_duration")), float(form.get("delivery_range")), palette, mode, form)


func _sector_polygon(origin: Vector2, direction: Vector2, radius: float, half_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array([origin])
	var base_angle := direction.angle()
	const ARC_SEGMENTS := 12
	for index in range(ARC_SEGMENTS + 1):
		var angle := base_angle - half_angle + (2.0 * half_angle * float(index) / float(ARC_SEGMENTS))
		points.append(origin + Vector2(cos(angle), sin(angle)) * radius)
	return points


func magic_targets_in_radius(context: MagicRuntimeContext, center: Vector2, radius: float) -> Array[Sprite2D]:
	var targets: Array[Sprite2D] = []
	for slime in context.slimes:
		if bool(context.is_slime_targetable.call(slime)) and _circle_intersects_polygon(center, radius, context.slime_body_polygon.call(slime) as PackedVector2Array):
			targets.append(slime)
	return targets


func _is_puzzle_torch(context: MagicRuntimeContext, target: Sprite2D) -> bool:
	return target != null and is_instance_valid(target) and context.puzzle_torches.has(target)


func _try_activate_puzzle_torch(context: MagicRuntimeContext, target: Sprite2D, world_position: Vector2, palette: String) -> bool:
	if not _is_puzzle_torch(context, target):
		return false
	if context.activate_puzzle_torch.is_valid():
		context.activate_puzzle_torch.call(target, world_position, palette, false)
	return true


func _puzzle_torch_rect(torch: Sprite2D) -> Rect2:
	return Rect2(torch.global_position - Vector2(3.0, 3.0), Vector2(6.0, 6.0))


func _puzzle_torch_snapshot(context: MagicRuntimeContext) -> Array[Sprite2D]:
	var snapshot: Array[Sprite2D] = []
	for torch in context.puzzle_torches:
		if torch != null and is_instance_valid(torch):
			snapshot.append(torch)
	return snapshot


func _activate_puzzle_torches_in_sector(context: MagicRuntimeContext, sector: PackedVector2Array, palette: String) -> void:
	for torch in _puzzle_torch_snapshot(context):
		if not is_instance_valid(torch) or not bool(context.is_slime_targetable.call(torch)):
			continue
		if not Geometry2D.intersect_polygons(_rect_polygon(_puzzle_torch_rect(torch)), sector).is_empty():
			_try_activate_puzzle_torch(context, torch, torch.global_position, palette)


func _activate_puzzle_torches_in_radius(context: MagicRuntimeContext, center: Vector2, radius: float, palette: String, direct_target: Sprite2D = null) -> void:
	var torch_snapshot := _puzzle_torch_snapshot(context)
	var activated_instance_ids: Dictionary = {}
	if _is_puzzle_torch(context, direct_target):
		activated_instance_ids[direct_target.get_instance_id()] = true
		_try_activate_puzzle_torch(context, direct_target, center, palette)
	for torch in torch_snapshot:
		if not is_instance_valid(torch) or activated_instance_ids.has(torch.get_instance_id()) or not bool(context.is_slime_targetable.call(torch)):
			continue
		if _circle_intersects_rect(center, radius, _puzzle_torch_rect(torch)):
			activated_instance_ids[torch.get_instance_id()] = true
			_try_activate_puzzle_torch(context, torch, torch.global_position, palette)


func _circle_intersects_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
	return center.distance_squared_to(closest) <= radius * radius


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


func spawn_cone_effect(context: MagicRuntimeContext, origin: Vector2, direction: Vector2, radius: float, half_angle: float, palette: String) -> void:
	var rng := context.rng
	var player := context.player
	var effects := context.effects_spawner
	var color := PaletteLibrary.normal(palette)
	for index in 12:
		var angle := direction.angle() + rng.randf_range(-half_angle, half_angle)
		var ray := Vector2(cos(angle), sin(angle))
		var particle := Sprite2D.new()
		particle.texture = context.pixel_particle_texture.call(color, 1) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		_add_child_to_runtime(context, particle, origin + ray * rng.randf_range(4.0, radius))
		var lifetime := 0.2
		effects.pixel_particles.append({"sprite": particle, "velocity": ray * rng.randf_range(12.0, 24.0), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})


func spawn_radial_burst(context: MagicRuntimeContext, origin: Vector2, palette: String, count: int, speed_min: float, speed_max: float) -> void:
	var player := context.player
	var effects := context.effects_spawner
	var color := PaletteLibrary.normal(palette)
	for index in count:
		var particle := Sprite2D.new()
		particle.texture = context.pixel_particle_texture.call(color, 1) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		_add_child_to_runtime(context, particle, origin)
		var angle := TAU * float(index) / float(count)
		var lifetime := 0.24
		effects.pixel_particles.append({"sprite": particle, "velocity": Vector2(cos(angle), sin(angle)) * context.rng.randf_range(speed_min, speed_max), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})


func spawn_magic_splash_ring(context: MagicRuntimeContext, origin: Vector2, palette: String) -> void:
	var player := context.player
	var effects := context.effects_spawner
	var rng := context.rng
	var texture := _magic_impact_particle_texture(context, palette, &"droplet", 3)
	for index in 10:
		var side := -1.0 if index % 2 == 0 else 1.0
		var particle := Sprite2D.new()
		particle.texture = texture
		particle.centered = true
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		_add_child_to_runtime(context, particle, origin)
		var lifetime := rng.randf_range(0.28, 0.42)
		var velocity := Vector2(side * rng.randf_range(14.0, 30.0), -rng.randf_range(12.0, 24.0))
		effects.pixel_particles.append({"sprite": particle, "velocity": velocity, "timer": lifetime, "lifetime": lifetime, "gravity": 42.0})


func spawn_sky_strike(context: MagicRuntimeContext, world_position: Vector2, palette: String) -> void:
	var player := context.player
	var effects := context.effects_spawner
	var rng := context.rng
	var color := PaletteLibrary.normal(palette)
	for i in 10:
		var particle := Sprite2D.new()
		particle.texture = context.pixel_particle_texture.call(color, 1) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		_add_child_to_runtime(context, particle, world_position + Vector2(rng.randf_range(-3.0, 3.0), -float(6 + i * 2)))
		var lifetime := 0.16
		effects.pixel_particles.append({"sprite": particle, "velocity": Vector2(0.0, 220.0), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})


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
	pending_magic_form = null
	pending_magic_palette = "grey"
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
	pending_magic_form = null
	pending_magic_palette = "grey"
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


func spawn_magic_projectile(context: MagicRuntimeContext, origin: Vector2, direction: Vector2, homing_target: Sprite2D = null, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY, form: Resource = null, palette_override: String = "") -> void:
	var resolved_form := form if form != null else SpellFormCatalogScript.cast_form_for(context.player_chroma_component, ability_mode)
	var palette := palette_override
	if palette.is_empty():
		var payload := ElementCatalogScript.Element.NEUTRAL
		if ability_mode == ChromaComponentScript.AbilityMode.ELEMENTAL and context.player_chroma_component != null:
			var current_aspect := int(context.player_chroma_component.get("current_aspect"))
			if current_aspect == ChromaComponentScript.Aspect.NONE:
				current_aspect = int(context.player_chroma_component.get("bound_aspect"))
			payload = ElementCatalogScript.element_for_aspect(current_aspect)
		palette = ElementCatalogScript.palette_key(payload)
	var base_color := PaletteLibrary.normal(palette)
	var accent_color := PaletteLibrary.accent(palette)
	var player := context.player
	var projectile_size := context.magic_projectile_size if resolved_form == null else int(resolved_form.get("projectile_size"))
	var projectile_lifetime := context.magic_projectile_lifetime if resolved_form == null else float(resolved_form.get("projectile_lifetime"))
	var projectile_speed := 70.0 if resolved_form == null else float(resolved_form.get("projectile_speed"))
	var projectile_shape := SpellFormDefinitionScript.ProjectileShape.ORB if resolved_form == null else int(resolved_form.get("projectile_shape"))
	var orient_to_direction := projectile_shape == SpellFormDefinitionScript.ProjectileShape.DROPLET
	var projectile := Sprite2D.new()
	projectile.name = "MagicProjectile"
	projectile.texture = magic_projectile_texture(context, base_color, accent_color, projectile_size, resolved_form)
	projectile.centered = true
	if orient_to_direction:
		projectile.rotation = direction.angle() + PI * 0.5
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_as_relative = false
	projectile.z_index = player.z_index + 1
	_add_child_to_runtime(context, projectile, origin)
	var outline := Sprite2D.new()
	outline.name = "MagicProjectileOutline"
	outline.texture = magic_projectile_outline_texture(context, base_color, accent_color, projectile_size, resolved_form)
	outline.centered = true
	outline.rotation = projectile.rotation
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	outline.z_as_relative = false
	outline.z_index = player.z_index + 1
	_add_child_to_runtime(context, outline, origin)
	var controller := context.magic_projectile_controller as MagicProjectileController
	controller.spawn(projectile, outline, direction, projectile_lifetime, palette, homing_target, ability_mode, resolved_form, projectile_speed)


func _add_child_to_runtime(context: MagicRuntimeContext, node: Node2D, world_position: Vector2) -> void:
	var parent := context.player.get_parent() if context.player != null else null
	if parent != null:
		parent.add_child(node)
		node.global_position = world_position


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
	_add_child_to_runtime(context, beam, origin + direction.normalized() * 10.0)
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


func magic_projectile_texture(context: MagicRuntimeContext, base_color: Color, accent_color: Color, size: int, form: Resource) -> Texture2D:
	if form == null:
		return context.pixel_particle_texture.call(base_color, size) as Texture2D
	var shape := int(form.get("projectile_shape"))
	if shape == SpellFormDefinitionScript.ProjectileShape.ORB:
		return context.pixel_particle_texture.call(base_color, size) as Texture2D
	var effects := context.effects_spawner
	var key := "magic_projectile:%d:%s:%s:%d" % [shape, base_color.to_html(false), accent_color.to_html(false), size]
	if effects.pixel_particle_texture_cache.has(key):
		return effects.pixel_particle_texture_cache[key] as Texture2D
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := size >> 1
	for y in size:
		for x in size:
			if not _magic_projectile_shape_contains(shape, size, x, y):
				continue
			var highlight := x == center and (shape == SpellFormDefinitionScript.ProjectileShape.DROPLET or y <= center)
			image.set_pixel(x, y, accent_color if highlight else base_color)
	var texture := ImageTexture.create_from_image(image)
	effects.pixel_particle_texture_cache[key] = texture
	return texture


func _magic_projectile_shape_contains(shape: int, size: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	var center := float(size - 1) * 0.5
	match shape:
		SpellFormDefinitionScript.ProjectileShape.SHARD:
			return absi(x - int(center)) + absi(y - int(center)) <= int(center)
		SpellFormDefinitionScript.ProjectileShape.DROPLET:
			var progress := float(y) / maxf(float(size - 1), 1.0)
			var radius := center * sqrt(progress)
			return absf(float(x) - center) <= radius
		SpellFormDefinitionScript.ProjectileShape.HEX:
			var dx := absf(float(x) - center)
			var dy := absf(float(y) - center)
			return maxf(dx, dy) <= center and dx + dy <= center + 1.0
	return true


func magic_projectile_outline_texture(context: MagicRuntimeContext, base_color: Color, accent_color: Color, projectile_size: int = -1, form: Resource = null) -> Texture2D:
	var effects := context.effects_spawner
	var size := context.magic_projectile_size if projectile_size < 0 else projectile_size
	var shape := int(form.get("projectile_shape")) if form != null else SpellFormDefinitionScript.ProjectileShape.ORB
	var key := "magic_outline:%s:%s:%d:%d" % [base_color.to_html(false), accent_color.to_html(false), size, shape]
	if effects.pixel_particle_texture_cache.has(key):
		return effects.pixel_particle_texture_cache[key]
	var outline_size := size + 2
	var image := Image.create(outline_size, outline_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := (outline_size - 1) >> 1
	for y in outline_size:
		for x in outline_size:
			var on_outline := false
			if shape == SpellFormDefinitionScript.ProjectileShape.SHARD:
				on_outline = absi(x - center) + absi(y - center) == center
			elif shape in [SpellFormDefinitionScript.ProjectileShape.DROPLET, SpellFormDefinitionScript.ProjectileShape.HEX]:
				var source_x := x - 1
				var source_y := y - 1
				var outside_shape := not _magic_projectile_shape_contains(shape, size, source_x, source_y)
				var touches_shape := (
					_magic_projectile_shape_contains(shape, size, source_x - 1, source_y)
					or _magic_projectile_shape_contains(shape, size, source_x + 1, source_y)
					or _magic_projectile_shape_contains(shape, size, source_x, source_y - 1)
					or _magic_projectile_shape_contains(shape, size, source_x, source_y + 1)
				)
				on_outline = outside_shape and touches_shape
			else:
				on_outline = x == 0 or y == 0 or x == outline_size - 1 or y == outline_size - 1
			if on_outline:
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


func _resolve_magic_projectile_hit_callback(target: Sprite2D, world_position: Vector2, palette: String, ability_mode: int, is_beam: bool, form: Resource, context: MagicRuntimeContext) -> void:
	resolve_magic_projectile_hit(context, target, world_position, palette, ability_mode, is_beam, form)


func _spawn_magic_trail_callback(world_position: Vector2, palette: String, is_beam: bool, facing_left: bool, context: MagicRuntimeContext) -> void:
	spawn_magic_trail(context, world_position, palette, is_beam, facing_left)


func resolve_magic_projectile_hit(context: MagicRuntimeContext, target: Sprite2D, world_position: Vector2, palette: String, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY, is_beam: bool = false, form: Resource = null) -> void:
	if form != null and SpellFormCatalogScript.delivery_of(form) == SpellFormDefinitionScript.Delivery.PROJECTILE_SPLASH:
		var splash_radius := float(form.get("delivery_radius"))
		var target_is_puzzle_torch := _is_puzzle_torch(context, target)
		_activate_puzzle_torches_in_radius(context, world_position, splash_radius, palette, target)
		var direct_target_is_slime := (
			not target_is_puzzle_torch
			and target != null
			and is_instance_valid(target)
			and context.slimes.has(target)
			and bool(context.is_slime_targetable.call(target))
		)
		if direct_target_is_slime:
			var direct_direction := (magic_target_point(context, target) - world_position).normalized()
			magic_hit_slime(context, target, magic_target_point(context, target), palette, ability_mode, false, form, direct_direction)
		var victims := magic_targets_in_radius(context, world_position, splash_radius)
		for victim in victims:
			if direct_target_is_slime and victim == target:
				continue
			var push_direction := (magic_target_point(context, victim) - world_position).normalized()
			var secondary_ratio := clampf(float(form.get("splash_secondary_damage_ratio")), 0.0, 1.0)
			var secondary_damage_multiplier := float(form.get("damage_multiplier")) * secondary_ratio
			magic_hit_slime(
				context, victim, magic_target_point(context, victim), palette,
				ability_mode, false, form, push_direction, secondary_damage_multiplier)
		spawn_magic_splash_ring(context, world_position, palette)
		return
	if _try_activate_puzzle_torch(context, target, world_position, palette):
		return
	magic_hit_slime(context, target, world_position, palette, ability_mode, is_beam, form)


func magic_projectile_hit_target(context: MagicRuntimeContext, sprite: Sprite2D) -> Sprite2D:
	var projectile_size := context.magic_projectile_size if sprite.texture == null else int(maxf(sprite.texture.get_size().x, sprite.texture.get_size().y))
	var radius := float(projectile_size) * 0.5 + 2.0
	var torches := context.puzzle_torches
	for torch in torches:
		if torch == null or not is_instance_valid(torch) or not bool(context.is_slime_targetable.call(torch)):
			continue
		if _puzzle_torch_rect(torch).grow(radius).has_point(sprite.global_position):
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


func magic_hit_slime(
	context: MagicRuntimeContext,
	slime: Sprite2D,
	world_position: Vector2,
	palette: String,
	ability_mode: int = ChromaComponentScript.AbilityMode.GRAY,
	is_beam: bool = false,
	form: Resource = null,
	knockback_direction: Vector2 = Vector2.ZERO,
	damage_multiplier_override: float = -1.0
) -> void:
	if slime == null or not is_instance_valid(slime) or not bool(context.is_slime_targetable.call(slime)):
		return
	var attack_element := magic_attack_element(palette, ability_mode)
	var combat_tuning := context.combat_tuning
	var magic_base_bonus := combat_tuning.elemental_magic_bonus if ability_mode == ChromaComponentScript.AbilityMode.ELEMENTAL and combat_tuning != null else 0.0
	var damage_result := context.player_magic_damage_result_against.call(slime, attack_element, magic_base_bonus) as CombatCalculator.DamageResult
	var damage := 0.0 if damage_result == null or damage_result.immune else damage_result.amount
	var was_critical := damage_result != null and damage_result.critical
	var immune := damage_result != null and damage_result.immune
	var damage_multiplier := float(form.get("damage_multiplier")) if form != null else (0.35 if is_beam else 1.0)
	if damage_multiplier_override >= 0.0:
		damage_multiplier = damage_multiplier_override
	if damage > 0.0:
		if damage_multiplier_override >= 0.0 and form != null:
			var primary_damage := maxf(floorf(damage * float(form.get("damage_multiplier"))), 1.0)
			var splash_damage := floorf(damage * damage_multiplier)
			damage = minf(maxf(splash_damage, 0.0), maxf(primary_damage - 1.0, 0.0))
		else:
			damage = maxf(floorf(damage * damage_multiplier), 1.0)
	if damage_multiplier_override >= 0.0 and damage <= 0.0 and not immune:
		spawn_magic_impact(context, world_position, palette)
		return
	var resolved_element := damage_result.element if damage_result != null else attack_element
	var target_health := slime.get_node_or_null("Health") as HealthComponent
	var health_before := target_health.current_health if target_health != null else -1.0
	context.damage_slime_with_number.call(slime, damage, was_critical, false, resolved_element, immune, damage_result.effectiveness if damage_result != null else 0.0, form != null or not is_beam)
	var damage_dealt := damage
	if target_health != null:
		damage_dealt = maxf(health_before - target_health.current_health, 0.0)
	if not immune and damage_dealt > 0.0 and context.record_run_style_action.is_valid():
		context.record_run_style_action.call(&"magic")
	var knockback_multiplier := MAGIC_KNOCKBACK_MULTIPLIER if form == null else float(form.get("knockback_multiplier"))
	if not immune and damage_dealt > 0.0 and knockback_multiplier > 0.0:
		if knockback_direction.length_squared() > 0.0001:
			context.knockback_slime.call(slime, knockback_multiplier, false, true, false, knockback_direction)
		else:
			context.knockback_slime.call(slime, knockback_multiplier, false)
	if damage_dealt > 0.0 or immune:
		context.spawn_damage_number.call(slime, damage_dealt, was_critical, resolved_element, immune)
	if form != null and not immune and damage_dealt > 0.0:
		var mark_duration := float(form.get("mark_duration"))
		if (
			mark_duration > 0.0
			and float(form.get("mark_damage_multiplier")) > 1.0
			and is_instance_valid(slime)
			and bool(context.is_slime_targetable.call(slime))
		):
			var status := slime.get_node_or_null("Status") as StatusComponent
			if status != null:
				status.apply_damage_mark(mark_duration, float(form.get("mark_damage_multiplier")), ElementCatalogScript.element_for_palette(palette))
		var lifesteal_ratio := float(form.get("lifesteal_ratio"))
		if lifesteal_ratio > 0.0 and context.apply_player_lifesteal.is_valid():
			context.apply_player_lifesteal.call(damage_dealt, lifesteal_ratio)
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
	particle.z_as_relative = false; particle.z_index = player.z_index if is_beam else player.z_index + 1
	_add_child_to_runtime(context, particle, world_position)
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
		_add_child_to_runtime(context, fizzle, world_position)
		var return_velocity := Vector2(24.0 if facing_left else -24.0, rng.randf_range(-3.0, 3.0))
		effects.pixel_particles.append({"sprite": fizzle, "velocity": return_velocity, "timer": lifetime + fizzle_lifetime, "lifetime": fizzle_lifetime, "gravity": 0.0, "delay": lifetime})


func spawn_magic_impact(context: MagicRuntimeContext, world_position: Vector2, palette: String) -> void:
	var player := context.player
	var rng := context.rng
	var effects := context.effects_spawner
	var profile := _magic_impact_profile(ElementCatalogScript.element_for_palette(palette))
	var shape := StringName(profile.get("shape", &"spark"))
	var particle_size := int(profile.get("size", 3))
	var texture := _magic_impact_particle_texture(context, palette, shape, particle_size)
	var count := int(profile.get("count", 8))
	var speed_min := float(profile.get("speed_min", 14.0))
	var speed_max := float(profile.get("speed_max", 30.0))
	var motion := StringName(profile.get("motion", &"burst"))
	var gravity := float(profile.get("gravity", 20.0))
	var lifetime_min := float(profile.get("lifetime_min", 0.3))
	var lifetime_max := float(profile.get("lifetime_max", 0.5))
	var alpha_scale := float(profile.get("alpha", 1.0))
	for index in count:
		var particle := Sprite2D.new()
		particle.texture = texture
		particle.centered = true
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		particle.modulate = Color(1.0, 1.0, 1.0, alpha_scale)
		_add_child_to_runtime(context, particle, world_position)
		var speed := rng.randf_range(speed_min, speed_max)
		var velocity := _magic_impact_velocity(motion, speed, rng)
		var lifetime := rng.randf_range(lifetime_min, lifetime_max)
		effects.pixel_particles.append({
			"sprite": particle,
			"velocity": velocity,
			"timer": lifetime,
			"lifetime": lifetime,
			"gravity": gravity,
			"alpha_scale": alpha_scale,
		})


func _magic_impact_profile(element: int) -> Dictionary:
	match element:
		ElementCatalogScript.Element.FIRE:
			return {"shape": &"flame", "motion": &"rise", "count": 8, "size": 3, "speed_min": 14.0, "speed_max": 26.0, "gravity": -5.0, "lifetime_min": 0.25, "lifetime_max": 0.42}
		ElementCatalogScript.Element.WATER:
			return {"shape": &"droplet", "motion": &"splash", "count": 9, "size": 3, "speed_min": 16.0, "speed_max": 29.0, "gravity": 36.0, "lifetime_min": 0.24, "lifetime_max": 0.42}
		ElementCatalogScript.Element.ELECTRIC:
			return {"shape": &"spark", "motion": &"burst", "count": 10, "size": 5, "speed_min": 28.0, "speed_max": 42.0, "gravity": 0.0, "lifetime_min": 0.12, "lifetime_max": 0.24}
		ElementCatalogScript.Element.GRASS:
			return {"shape": &"leaf", "motion": &"rise", "count": 8, "size": 4, "speed_min": 12.0, "speed_max": 21.0, "gravity": -2.0, "lifetime_min": 0.3, "lifetime_max": 0.5}
		ElementCatalogScript.Element.SHADOW:
			return {"shape": &"mote", "motion": &"drift", "count": 7, "size": 3, "speed_min": 5.0, "speed_max": 12.0, "gravity": -3.0, "lifetime_min": 0.42, "lifetime_max": 0.68, "alpha": 0.86}
		ElementCatalogScript.Element.GROUND:
			return {"shape": &"rock", "motion": &"burst", "count": 8, "size": 4, "speed_min": 14.0, "speed_max": 26.0, "gravity": 52.0, "lifetime_min": 0.28, "lifetime_max": 0.48}
		ElementCatalogScript.Element.ICE:
			return {"shape": &"crystal", "motion": &"burst", "count": 9, "size": 5, "speed_min": 18.0, "speed_max": 31.0, "gravity": 5.0, "lifetime_min": 0.25, "lifetime_max": 0.45}
	return {"shape": &"spark", "motion": &"burst", "count": 8, "size": 3, "speed_min": 14.0, "speed_max": 30.0, "gravity": 20.0, "lifetime_min": 0.3, "lifetime_max": 0.5}


func _magic_impact_velocity(motion: StringName, speed: float, rng: RandomNumberGenerator) -> Vector2:
	match motion:
		&"rise":
			return Vector2(rng.randf_range(-0.55, 0.55) * speed, -speed)
		&"splash":
			return Vector2(rng.randf_range(-0.9, 0.9) * speed, -rng.randf_range(0.45, 1.0) * speed)
		&"drift":
			return Vector2(rng.randf_range(-0.65, 0.65) * speed, -rng.randf_range(0.1, 0.75) * speed)
	return Vector2.from_angle(rng.randf_range(0.0, TAU)) * speed


func _magic_impact_particle_texture(context: MagicRuntimeContext, palette: String, shape: StringName, size: int) -> Texture2D:
	var effects := context.effects_spawner
	var base_color := PaletteLibrary.normal(palette)
	var accent_color := PaletteLibrary.accent(palette)
	var key := "magic_impact:%s:%s:%s:%d" % [String(shape), base_color.to_html(false), accent_color.to_html(false), size]
	if effects.pixel_particle_texture_cache.has(key):
		return effects.pixel_particle_texture_cache[key] as Texture2D
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := size >> 1
	for y in size:
		for x in size:
			if not _magic_impact_shape_contains(shape, size, x, y):
				continue
			var highlight := _magic_impact_pixel_highlight(shape, center, x, y)
			image.set_pixel(x, y, accent_color if highlight else base_color)
	var texture := ImageTexture.create_from_image(image)
	effects.pixel_particle_texture_cache[key] = texture
	return texture


func _magic_impact_shape_contains(shape: StringName, size: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	var center := size >> 1
	match shape:
		&"flame", &"droplet":
			var progress := float(y) / maxf(float(size - 1), 1.0)
			return absf(float(x - center)) <= float(center) * sqrt(progress)
		&"spark":
			return x == center or y == center or absi(x - center) == absi(y - center)
		&"leaf":
			return absi(x - y) <= 1 and x + y >= center and x + y <= (size - 1) * 2 - center
		&"mote", &"crystal":
			return absi(x - center) + absi(y - center) <= center
		&"rock":
			return not ((x == 0 or x == size - 1) and (y == 0 or y == size - 1))
	return true


func _magic_impact_pixel_highlight(shape: StringName, center: int, x: int, y: int) -> bool:
	match shape:
		&"spark", &"crystal":
			return x == center or y == 0
		&"leaf":
			return x == y
		&"rock":
			return y == 0
		&"mote":
			return x == center and y <= center
	return x == center and y <= 1
