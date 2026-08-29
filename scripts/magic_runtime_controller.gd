extends Node
class_name MagicRuntimeController

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const ChromaComponentScript = preload("res://scripts/player_chroma_component.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

const GREY_MAGIC_DAMAGE_MULTIPLIER := 1.10
const ELEMENTAL_MAGIC_DAMAGE_MULTIPLIER := 1.15
const MAGIC_KNOCKBACK_MULTIPLIER := 0.25
const MAGIC_FRAME_COUNT := 4
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


func update_player_mp_ui(root: Object) -> void:
	# The visual state must update even while the MP HUD is not built or visible.
	# In particular, a spell can consume MP before the HUD is ready.
	root.call("_update_mp_desaturation")
	var fill := root.get("player_mp_fill") as Sprite2D
	if fill == null:
		return
	var fill_size: Vector2 = root.get("player_mp_fill_size")
	if fill_size == Vector2.ZERO and fill.texture != null:
		fill_size = fill.texture.get_size()
	if fill_size == Vector2.ZERO:
		fill_size = Vector2(82, 16)
	root.set("player_mp_fill_size", fill_size)
	var max_mp := float(root.get("PLAYER_MAX_MP")) if root.get("PLAYER_MAX_MP") != null else 100.0
	var chroma := current_player_chroma(root)
	var hud := root.get("hud_controller") as HudController
	if hud != null:
		hud.set_fill_ratio(fill, fill_size, clampf(chroma / max_mp, 0.0, 1.0))
	var text := root.get("player_mp_text") as Sprite2D
	if text != null:
		text.texture = root.call("_pixel_text_texture", "%d/%d" % [ceili(chroma), int(max_mp)], Color.WHITE)


func current_player_chroma(root: Object) -> float:
	var component := root.get("player_chroma_component") as Node
	return float(component.get("current_chroma")) if component != null and is_instance_valid(component) else 0.0


func restore_player_mp(root: Object) -> void:
	var component := root.get("player_chroma_component") as Node
	if component != null and is_instance_valid(component):
		# Resting/refill callers must respect the current/bound split. Calling
		# attune() with Aspect.NONE silently fails for a dormant bound identity;
		# refill_chroma() reawakens that identity before restoring the bar.
		component.call("refill_chroma")
	root.call("_sync_chroma_presentation")
	root.call("_update_player_mp_ui")


func update_magic_input(root: Object, magic_down: bool, was_down: bool, delta: float) -> bool:
	var hold_threshold := _hold_threshold(root)
	if magic_down:
		if not was_down:
			magic_hold_active = _begin_magic_candidate(root)
			magic_hold_triggered = false
			magic_hold_timer = 0.0
			return false
		if magic_hold_active and not magic_hold_triggered:
			magic_hold_timer += maxf(delta, 0.0)
			if magic_hold_timer >= hold_threshold:
				magic_hold_triggered = true
				return try_cast_imbue(root, true)
		return false
	if was_down and magic_hold_active:
		var imbue_was_triggered := magic_hold_triggered
		var accepted := false
		if not imbue_was_triggered:
			accepted = try_cast_magic(root, true)
		magic_hold_active = false
		magic_hold_triggered = false
		magic_hold_timer = 0.0
		if imbue_was_triggered:
			# A failed IMBUE attempt must not fall through into a normal spell.
			if magic_animation_active and not magic_animation_is_imbue:
				cancel_magic_animation(root)
		elif not accepted:
			cancel_magic_animation(root)
		return accepted
	return false


func _begin_magic_candidate(root: Object) -> bool:
	if _magic_action_blocked(root):
		return false
	var current := root.call("_valid_current_target") as Sprite2D
	var target := current if current != null and bool(root.call("_is_slime_targetable", current)) else root.call("_closest_target") as Sprite2D
	var player := root.get("player") as Sprite2D
	var direction := Vector2.RIGHT
	if target != null:
		var to_target: Vector2 = magic_target_point(root, target) - player_visual_center(root)
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else direction
	else:
		var last_input: Vector2 = root.get("last_player_input_direction")
		direction = last_input.normalized() if last_input.length_squared() > 0.0001 else (Vector2.LEFT if player != null and player.flip_h else Vector2.RIGHT)
	return begin_magic_animation(root, direction, target, ChromaComponentScript.AbilityMode.GRAY, false, true)


func _magic_action_blocked(root: Object, allow_candidate := false) -> bool:
	if bool(root.get("player_is_attacking")) or bool(root.get("player_is_rolling")) or bool(root.get("player_is_backflipping")) or bool(root.get("player_is_defending")) or bool(root.get("player_dead")):
		return true
	if bool(root.get("player_is_magic_casting")) and not (allow_candidate and magic_animation_active and magic_hold_active and not magic_animation_is_imbue):
		return true
	return false


func _hold_threshold(root: Object) -> float:
	var configured: Variant = root.get("IMBUE_HOLD_THRESHOLD")
	return maxf(float(configured), 0.01) if configured != null else IMBUE_HOLD_THRESHOLD


func try_cast_magic(root: Object, allow_candidate := false) -> bool:
	if _magic_action_blocked(root, allow_candidate):
		return false
	var ability := root.get("player_aspect_ability_component") as Node
	var chroma := root.get("player_chroma_component") as Node
	if ability == null or chroma == null:
		return false
	var accepted := bool(ability.call("try_activate", chroma, Callable(root, "_execute_current_aspect_ability")))
	if accepted:
		root.call("_sync_chroma_presentation")
		root.call("_update_player_mp_ui")
	return accepted


func try_cast_imbue(root: Object, allow_candidate := false) -> bool:
	if _magic_action_blocked(root, allow_candidate):
		return false
	if imbue_cooldown_remaining > 0.0:
		return false
	var chroma := root.get("player_chroma_component") as Node
	if chroma == null or not is_instance_valid(chroma):
		return false
	var aspect := int(chroma.get("current_aspect"))
	var element := ElementCatalogScript.element_for_aspect(aspect)
	var cost := int(root.get("IMBUE_MP_COST")) if root.get("IMBUE_MP_COST") != null else IMBUE_COST
	if element == ElementCatalogScript.Element.NEUTRAL or not bool(chroma.call("can_spend_chroma", cost)):
		return false
	var player := root.get("player") as Sprite2D
	var direction := Vector2.LEFT if player != null and player.flip_h else Vector2.RIGHT
	var target := root.call("_valid_current_target") as Sprite2D
	if target != null and bool(root.call("_is_slime_targetable", target)):
		var to_target: Vector2 = magic_target_point(root, target) - player_visual_center(root)
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else direction
	pending_imbue_element = element
	var candidate := allow_candidate and magic_animation_active and magic_hold_active and not magic_animation_is_imbue
	if candidate:
		magic_animation_is_imbue = true
		magic_cast_decided = true
		pending_magic_target = null
		pending_magic_mode = ChromaComponentScript.AbilityMode.GRAY
		pending_imbue_activated = false
		if magic_animation_frame >= IMBUE_EFFECT_FRAME_INDEX:
			magic_animation_frame = IMBUE_EFFECT_FRAME_INDEX
			_apply_magic_animation_frame(root, magic_animation_frame)
			_activate_pending_imbue(root)
		return true
	return begin_magic_animation(root, direction, null, ChromaComponentScript.AbilityMode.GRAY, true)


func sync_chroma_presentation(root: Object) -> void:
	var component := root.get("player_chroma_component") as Node
	if component == null:
		return
	var flame := String(component.call("aspect_name"))
	var palette := "grey" if flame == "gray" else AspectCatalogScript.palette_for_flame(StringName(flame))
	if palette.is_empty() or palette == String(root.get("current_player_palette_name")):
		return
	root.call("_start_player_palette_flash", palette)


func execute_current_aspect_ability(root: Object, mode: int) -> bool:
	if magic_animation_active and magic_hold_active and not magic_animation_is_imbue:
		pending_magic_mode = mode
		magic_cast_decided = true
		if magic_animation_frame >= MAGIC_CAST_FRAME_INDEX and not pending_magic_projectile_spawned:
			_spawn_pending_magic_projectile(root)
		return true
	var current := root.call("_valid_current_target") as Sprite2D
	var target := current if current != null and bool(root.call("_is_slime_targetable", current)) else root.call("_closest_target") as Sprite2D
	var player := root.get("player") as Sprite2D
	var direction := Vector2.RIGHT
	if target != null:
		var to_target: Vector2 = magic_target_point(root, target) - player_visual_center(root)
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.RIGHT
	else:
		var last_input: Vector2 = root.get("last_player_input_direction")
		direction = last_input.normalized() if last_input.length_squared() > 0.0001 else Vector2.RIGHT
	return begin_magic_animation(root, direction, target, mode)


func begin_magic_animation(root: Object, direction: Vector2, target: Sprite2D, mode: int, is_imbue := false, is_candidate := false) -> bool:
	if magic_animation_active:
		return false
	magic_animation_active = true
	magic_animation_timer = 0.0
	magic_animation_frame = 0
	pending_magic_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	pending_magic_target = target if target != null and is_instance_valid(target) else null
	pending_magic_mode = mode
	pending_magic_projectile_spawned = false
	magic_animation_is_imbue = is_imbue
	pending_imbue_activated = false
	magic_cast_decided = not is_candidate
	root.set("player_is_magic_casting", true)
	var remembered_facing_left := bool(root.get("last_player_facing_left"))
	var magic_facing_left := pending_magic_direction.x < 0.0 if absf(pending_magic_direction.x) > ActorMotor.HORIZONTAL_FACING_DEADZONE else remembered_facing_left
	root.set("player_magic_flip_h", magic_facing_left)
	root.set("player_anim_name", "magic")
	root.set("player_anim_frame", 0)
	root.set("player_anim_timer", 0.0)
	var player := root.get("player") as Sprite2D
	if player != null:
		player.flip_h = magic_facing_left
	_apply_magic_animation_frame(root, 0)
	return true


func _apply_magic_animation_frame(root: Object, frame: int) -> void:
	# Magic owns the player presentation until the cast finishes. A leftover
	# walk/attack frame can otherwise be selected while an IMBUE timeline is
	# still advancing, and those shorter frame sets cannot represent frame 4+.
	root.set("player_anim_name", "magic")
	root.set("player_anim_frame", frame)
	var animation := root.get("player_animation_component") as PlayerAnimationComponent
	if animation != null:
		animation.apply_frame(root)


func magic_frame_time(root: Object) -> float:
	var tuning := root.get("player_tuning") as PlayerTuning
	if tuning == null:
		return 0.108
	var agi_value: Variant = root.get("player_agi")
	var effective_agi := float(agi_value) if agi_value != null else float(root.get("player_spd"))
	var attack_multiplier := tuning.attack_multiplier_for_agi(effective_agi)
	return maxf(tuning.attack_frame_time * MAGIC_FRAME_TIME_SCALE / attack_multiplier, 0.001)


func tick_magic_animation(root: Object, delta: float) -> void:
	_tick_imbue_timers(root, delta)
	if not magic_animation_active:
		return
	magic_animation_timer += maxf(delta, 0.0)
	var frame_time := magic_frame_time(root)
	var frame_count := IMBUE_MAGIC_FRAME_COUNT if magic_animation_is_imbue else MAGIC_FRAME_COUNT
	while magic_animation_active and magic_animation_timer >= frame_time:
		magic_animation_timer -= frame_time
		magic_animation_frame += 1
		if magic_animation_frame >= frame_count:
			_finish_magic_animation(root)
			break
		_apply_magic_animation_frame(root, magic_animation_frame)
		if magic_animation_is_imbue and magic_animation_frame == IMBUE_EFFECT_FRAME_INDEX and not pending_imbue_activated:
			_activate_pending_imbue(root)
		elif not magic_animation_is_imbue and magic_cast_decided and magic_animation_frame == MAGIC_CAST_FRAME_INDEX and not pending_magic_projectile_spawned:
			_spawn_pending_magic_projectile(root)


func _tick_imbue_timers(root: Object, delta: float) -> void:
	imbue_cooldown_remaining = maxf(imbue_cooldown_remaining - maxf(delta, 0.0), 0.0)
	if imbue_remaining <= 0.0:
		return
	imbue_remaining = maxf(imbue_remaining - maxf(delta, 0.0), 0.0)
	if imbue_remaining > 0.0:
		return
	imbued_element = ElementCatalogScript.Element.NEUTRAL
	root.set("player_imbued_element", imbued_element)
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.end_imbue(root)


func _activate_pending_imbue(root: Object) -> void:
	pending_imbue_activated = true
	var chroma := root.get("player_chroma_component") as Node
	if chroma == null or not is_instance_valid(chroma):
		return
	var cost := int(root.get("IMBUE_MP_COST")) if root.get("IMBUE_MP_COST") != null else IMBUE_COST
	if not bool(chroma.call("spend_chroma", cost)):
		return
	imbued_element = pending_imbue_element
	root.set("player_imbued_element", imbued_element)
	var duration := float(root.get("IMBUE_DURATION")) if root.get("IMBUE_DURATION") != null else IMBUE_DURATION
	var cooldown := float(root.get("IMBUE_COOLDOWN")) if root.get("IMBUE_COOLDOWN") != null else IMBUE_COOLDOWN
	imbue_remaining = duration
	imbue_cooldown_remaining = cooldown
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.begin_imbue(root, imbued_element, duration)
	root.call("_sync_chroma_presentation")
	root.call("_update_player_mp_ui")
	root.call("_play_sound", "magic_cast", -8.0, 0.85)


func _spawn_pending_magic_projectile(root: Object) -> void:
	pending_magic_projectile_spawned = true
	var target := pending_magic_target if pending_magic_target != null and is_instance_valid(pending_magic_target) else null
	var origin := player_visual_center(root) + Vector2(signf(pending_magic_direction.x) * 5.0, 1.0)
	spawn_magic_projectile(root, origin, pending_magic_direction, target, pending_magic_mode)
	root.call("_play_sound", "magic_cast", -8.0, 1.0)


func _finish_magic_animation(root: Object) -> void:
	if magic_hold_active and not magic_animation_is_imbue and not magic_cast_decided:
		# The short-press path may not be known yet. Hold the last magic frame
		# until release or until the hold threshold converts this into IMBUE.
		magic_animation_frame = MAGIC_FRAME_COUNT - 1
		magic_animation_timer = 0.0
		root.set("player_anim_frame", magic_animation_frame)
		var held_animation := root.get("player_animation_component") as PlayerAnimationComponent
		if held_animation != null:
			held_animation.apply_frame(root)
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
	root.set("player_is_magic_casting", false)
	var player := root.get("player") as Sprite2D
	if player != null:
		player.flip_h = bool(root.get("last_player_facing_left"))
	root.set("player_anim_name", (root.get("player_animation_component") as PlayerAnimationComponent).movement_anim_name(root))
	root.set("player_anim_frame", 0)
	root.set("player_anim_timer", 0.0)
	var animation := root.get("player_animation_component") as PlayerAnimationComponent
	if animation != null:
		animation.apply_frame(root)


func cancel_magic_animation(root: Object) -> void:
	if not magic_animation_active and not bool(root.get("player_is_magic_casting")):
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
	root.set("player_is_magic_casting", false)
	var player := root.get("player") as Sprite2D
	if player != null:
		player.flip_h = bool(root.get("last_player_facing_left"))
	root.set("player_anim_name", (root.get("player_animation_component") as PlayerAnimationComponent).movement_anim_name(root))
	root.set("player_anim_frame", 0)
	root.set("player_anim_timer", 0.0)
	var animation := root.get("player_animation_component") as PlayerAnimationComponent
	if animation != null:
		animation.apply_frame(root)


func player_weapon_element(_root: Object) -> int:
	return imbued_element if imbue_remaining > 0.0 else ElementCatalogScript.Element.NEUTRAL


func reset_for_room(root: Object, reset_cooldown := false) -> void:
	cancel_magic_animation(root)
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
	root.set("player_imbued_element", imbued_element)
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.end_imbue(root)


func player_visual_center(root: Object) -> Vector2:
	var player := root.get("player") as Sprite2D
	return player.global_position + Vector2(8, 7)


func slime_visual_center(root: Object, slime: Sprite2D) -> Vector2:
	return slime.global_position + Vector2(8, 2)


func magic_target_point(root: Object, slime: Sprite2D) -> Vector2:
	var torches := root.get("puzzle_torches") as Array[Sprite2D]
	if torches.has(slime):
		return slime.global_position
	var body := root.call("_slime_body_polygon", slime) as PackedVector2Array
	if body.size() >= 3:
		return ActorGeometry.polygon_center(body)
	return ActorGeometry.combat_target_point(root.call("_collision_rect", slime) as Rect2)


func spawn_magic_projectile(root: Object, origin: Vector2, direction: Vector2, homing_target: Sprite2D = null, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY) -> void:
	var palette := String(root.get("current_player_palette_name"))
	var base_color := PaletteLibrary.normal(palette)
	var accent_color := PaletteLibrary.accent(palette)
	var player := root.get("player") as Sprite2D
	var projectile := Sprite2D.new()
	projectile.name = "MagicProjectile"
	projectile.texture = root.call("_pixel_particle_texture", base_color, int(root.get("MAGIC_PROJECTILE_SIZE"))) as Texture2D
	projectile.centered = true
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_as_relative = false
	projectile.z_index = player.z_index + 1
	projectile.position = origin
	(root as Node).add_child(projectile)
	var outline := Sprite2D.new()
	outline.name = "MagicProjectileOutline"
	outline.texture = magic_projectile_outline_texture(root, base_color, accent_color)
	outline.centered = true
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	outline.z_as_relative = false
	outline.z_index = player.z_index + 1
	outline.position = origin
	(root as Node).add_child(outline)
	var controller := root.get("magic_projectile_controller") as MagicProjectileController
	controller.spawn(projectile, outline, direction, float(root.get("MAGIC_PROJECTILE_LIFETIME")), palette, homing_target, ability_mode)


func magic_projectile_outline_texture(root: Object, base_color: Color, accent_color: Color) -> Texture2D:
	var effects := root.get("effects_spawner") as EffectsSpawner
	var key := "magic_outline:%s:%s" % [base_color.to_html(false), accent_color.to_html(false)]
	if effects.pixel_particle_texture_cache.has(key):
		return effects.pixel_particle_texture_cache[key]
	var size := int(root.get("MAGIC_PROJECTILE_SIZE")) + 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in size:
		for x in size:
			if x == 0 or y == 0 or x == size - 1 or y == size - 1:
				image.set_pixel(x, y, accent_color)
	var texture := ImageTexture.create_from_image(image)
	effects.pixel_particle_texture_cache[key] = texture
	return texture


func update_magic_projectiles(root: Object, delta: float) -> void:
	var controller := root.get("magic_projectile_controller") as MagicProjectileController
	controller.tick(delta, 70.0, Callable(root, "_snap_half_pixel"), Callable(self, "_magic_target_point_callback").bind(root), Callable(root, "_is_slime_targetable"), Callable(self, "_magic_projectile_hit_target_callback").bind(root), Callable(self, "_resolve_magic_projectile_hit_callback").bind(root), Callable(self, "_spawn_magic_trail_callback").bind(root))


func _magic_target_point_callback(slime: Sprite2D, root: Object) -> Vector2:
	return magic_target_point(root, slime)


func _magic_projectile_hit_target_callback(sprite: Sprite2D, root: Object) -> Sprite2D:
	return magic_projectile_hit_target(root, sprite)


func _resolve_magic_projectile_hit_callback(target: Sprite2D, world_position: Vector2, palette: String, ability_mode: int, root: Object) -> void:
	resolve_magic_projectile_hit(root, target, world_position, palette, ability_mode)


func _spawn_magic_trail_callback(world_position: Vector2, palette: String, root: Object) -> void:
	spawn_magic_trail(root, world_position, palette)


func resolve_magic_projectile_hit(root: Object, target: Sprite2D, world_position: Vector2, palette: String, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY) -> void:
	var torches := root.get("puzzle_torches") as Array[Sprite2D]
	if torches.has(target):
		root.call("_activate_puzzle_torch", target, world_position, palette, false)
	else:
		root.call("_magic_hit_slime", target, world_position, palette, ability_mode)


func magic_projectile_hit_target(root: Object, sprite: Sprite2D) -> Sprite2D:
	var radius := int(root.get("MAGIC_PROJECTILE_SIZE")) * 0.5 + 2.0
	var torches := root.get("puzzle_torches") as Array[Sprite2D]
	for torch in torches:
		if not bool(root.call("_is_slime_targetable", torch)):
			continue
		var torch_rect := Rect2(torch.global_position - Vector2(3.0, 3.0), Vector2(6.0, 6.0))
		if torch_rect.grow(radius).has_point(sprite.global_position):
			return torch
	var slimes := root.get("slimes") as Array[Sprite2D]
	for slime in slimes:
		if not bool(root.call("_is_slime_targetable", slime)):
			continue
		if _circle_intersects_polygon(sprite.global_position, radius, root.call("_slime_body_polygon", slime) as PackedVector2Array):
			return slime
	return null


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


func magic_hit_slime(root: Object, slime: Sprite2D, world_position: Vector2, palette: String, ability_mode: int = ChromaComponentScript.AbilityMode.GRAY) -> void:
	var attack_element := magic_attack_element(palette, ability_mode)
	var combat_tuning := root.get("combat_tuning") as CombatTuning
	var magic_base_bonus := combat_tuning.elemental_magic_bonus if ability_mode == ChromaComponentScript.AbilityMode.ELEMENTAL and combat_tuning != null else 0.0
	var damage_result := root.call("_player_magic_damage_result_against", slime, attack_element, magic_base_bonus) as CombatCalculator.DamageResult
	var damage := 0.0 if damage_result == null or damage_result.immune else damage_result.amount
	var was_critical := damage_result != null and damage_result.critical
	var immune := damage_result != null and damage_result.immune
	var resolved_element := damage_result.element if damage_result != null else attack_element
	root.call("_damage_slime_with_number", slime, damage, was_critical, false, resolved_element, immune)
	if not immune and damage > 0.0 and root.has_method("_record_run_style_action"):
		root.call("_record_run_style_action", &"magic")
	if not immune:
		root.call("_knockback_slime", slime, MAGIC_KNOCKBACK_MULTIPLIER, false)
	root.call("_spawn_damage_number", slime, damage, was_critical, resolved_element, immune)
	root.call("_play_sound", "magic_hit", -8.0, 1.0)
	spawn_magic_impact(root, world_position, palette)


func spawn_magic_trail(root: Object, world_position: Vector2, palette: String) -> void:
	var player := root.get("player") as Sprite2D
	var particle := Sprite2D.new()
	particle.texture = root.call("_pixel_particle_texture", PaletteLibrary.normal(palette), 1) as Texture2D
	particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = false
	particle.z_index = player.z_index + 1
	particle.position = world_position
	(root as Node).add_child(particle)
	var lifetime := 0.35
	(root.get("effects_spawner") as EffectsSpawner).pixel_particles.append({"sprite": particle, "velocity": Vector2.ZERO, "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})


func spawn_magic_impact(root: Object, world_position: Vector2, palette: String) -> void:
	var player := root.get("player") as Sprite2D
	var rng := root.get("rng") as RandomNumberGenerator
	var effects := root.get("effects_spawner") as EffectsSpawner
	var color := PaletteLibrary.normal(palette)
	for i in 8:
		var particle := Sprite2D.new()
		particle.texture = root.call("_pixel_particle_texture", color, 1) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		particle.position = world_position
		(root as Node).add_child(particle)
		var angle := float(i) / 8.0 * TAU
		var speed := float(rng.randf_range(14.0, 30.0))
		var lifetime := float(rng.randf_range(0.3, 0.5))
		effects.pixel_particles.append({"sprite": particle, "velocity": Vector2(cos(angle), sin(angle)) * speed, "timer": lifetime, "lifetime": lifetime, "gravity": 20.0})
