extends Node
class_name PlayerAttackComponent

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const CircularInputRecognizerScript = preload("res://scripts/circular_input_recognizer.gd")

enum AttackKind { NONE, ATTACK1, ATTACK2, SPIN, CHARGING, CHARGED_ATTACK2 }

signal attack_started(variant: int)
signal attack_finished
signal attack_hit_resolved(variant: int, targets: Array)

var active := false
## Kept as 1/2 for the existing transmutation and run-grade hooks. Spin is a
## primary swing (1); a charged finisher is a finisher (2).
var variant := 1
var attack_kind := AttackKind.NONE
var hit_targets: Array[Sprite2D] = []
var combo_buffered := false
var combo_timer := 0.0
var combo_movement := Vector2.ZERO
var attack2_cooldown_timer := 0.0
var lunge_velocity := Vector2.ZERO
var lunge_remaining := 0.0
var attack_element := ElementCatalogScript.Element.NEUTRAL
var attack_button_held := false
var charge_elapsed := 0.0
var hit_sound_played := false
## Captured when the current swing starts. Movement is locked during attacks, so
## this latch keeps a running attack's bonuses stable through the hit frame.
var running_attack_active := false
var combo_running_attack := false
var spin_gesture = CircularInputRecognizerScript.new()
var _spin_gesture_configured := false
var _spin_gesture_signature := 0


func start_player_attack(root: Object, new_variant: int) -> bool:
	var requested_kind := AttackKind.ATTACK2 if new_variant == 2 else AttackKind.ATTACK1
	return _start_attack(root, requested_kind, 2 if new_variant == 2 else 1, "attack2" if new_variant == 2 else "attack1")


func start_spin_attack(root: Object) -> bool:
	var animation := root.get("player_animation_component") as PlayerAnimationComponent
	if animation == null or animation.spin_frames.is_empty():
		return false
	var started := _start_attack(root, AttackKind.SPIN, 1, "spin_attack")
	if started:
		spin_gesture.consume()
	return started


func start_charged_attack(root: Object) -> bool:
	return _start_attack(root, AttackKind.CHARGED_ATTACK2, 2, "attack2_charged")


func _start_attack(root: Object, new_kind: int, new_variant: int, animation_name: String) -> bool:
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	if anim == null:
		return false
	var frames: Array[Texture2D] = anim.spin_frames if new_kind == AttackKind.SPIN else anim.attack2_frames if new_variant == 2 else anim.attack_frames
	if frames.is_empty():
		return false
	var starts_from_run := bool(root.get("player_is_running"))
	if new_variant == 2 and combo_buffered:
		starts_from_run = combo_running_attack
	elif new_kind == AttackKind.CHARGED_ATTACK2 and attack_kind == AttackKind.CHARGING:
		starts_from_run = running_attack_active
	running_attack_active = starts_from_run and new_kind != AttackKind.SPIN
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_attack(new_variant, bool(root.call("_is_run_combat_active")))
	root.set("player_is_attacking", true)
	begin(new_variant, new_kind)
	root.set("player_just_finished_attack2", false)
	root.set("player_attack_hit_done", false)
	hit_targets.clear()
	hit_sound_played = false
	charge_elapsed = 0.0
	attack_element = int(root.call("_player_weapon_element")) if root.has_method("_player_weapon_element") else ElementCatalogScript.Element.NEUTRAL
	var player := root.get("player") as Sprite2D
	root.set("player_attack_flip_h", player.flip_h)
	var tuning := root.get("player_tuning") as PlayerTuning
	var agi_value: Variant = root.get("player_agi")
	var effective_agi := float(agi_value) if agi_value != null else float(root.get("player_spd"))
	var attack_multiplier := tuning.attack_multiplier_for_agi(effective_agi)
	if new_kind == AttackKind.SPIN:
		cancel_lunge()
		# A spin is a standalone attack. It cannot inherit a pending combo or
		# the recovery timer from an attack that happened immediately before it.
		combo_buffered = false
		combo_timer = 0.0
		root.set("player_between_timer", 0.0)
	else:
		var run_lunge_multiplier := tuning.run_attack_lunge_multiplier if running_attack_active else 1.0
		start_lunge(root.call("_perspective_movement", root.call("_player_facing_vector") * (tuning.attack_lunge_distance * run_lunge_multiplier * attack_multiplier / tuning.attack_lunge_duration)), tuning.attack_lunge_duration / attack_multiplier)
	root.set("player_anim_name", animation_name)
	if new_variant == 2:
		root.set("player_between_timer", 0.0)
	root.set("player_anim_frame", 0)
	root.set("player_anim_timer", 0.0)
	root.call("_restore_actor_base_visual_scale", player)
	(root.get("player_attack_visual") as Sprite2D).visible = false
	player.visible = false
	anim.apply_frame(root)
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.begin_attack_visual(root)
	var shadow_controller := root.get("shadow_controller") as ShadowController
	if shadow_controller != null:
		shadow_controller.sync_player_attack_shadow(root, float(root.get("DEPTH_Z_SCALE")))
	return true


func set_attack_input_held(held: bool) -> void:
	attack_button_held = held


func update_spin_input(root: Object, movement: Vector2, delta: float, can_listen: bool) -> void:
	_configure_spin_gesture(root)
	if not can_listen or active or bool(root.get("player_is_magic_casting")) or bool(root.get("player_is_rolling")) or bool(root.get("player_is_backflipping")) or bool(root.get("player_is_defending")):
		spin_gesture.reset()
		return
	spin_gesture.update(movement, delta)


func _configure_spin_gesture(root: Object) -> void:
	var tuning := root.get("player_tuning") as PlayerTuning
	if tuning == null:
		return
	var signature := [tuning.spin_circle_min_magnitude, tuning.spin_circle_max_duration, tuning.spin_circle_required_turn, tuning.spin_circle_arm_duration].hash()
	if _spin_gesture_configured and signature == _spin_gesture_signature:
		return
	_spin_gesture_signature = signature
	_spin_gesture_configured = true
	spin_gesture.configure(tuning.spin_circle_min_magnitude, tuning.spin_circle_max_duration, tuning.spin_circle_required_turn, tuning.spin_circle_arm_duration)


func is_spin_attack() -> bool:
	return attack_kind == AttackKind.SPIN


func is_charging() -> bool:
	return attack_kind == AttackKind.CHARGING


func is_charged_attack2() -> bool:
	return attack_kind == AttackKind.CHARGED_ATTACK2


func is_finisher() -> bool:
	return attack_kind == AttackKind.ATTACK2 or attack_kind == AttackKind.CHARGED_ATTACK2


func should_enter_charge() -> bool:
	return active and attack_kind == AttackKind.ATTACK1 and attack_button_held and not combo_buffered


func begin_charge(root: Object) -> bool:
	if not should_enter_charge():
		return false
	attack_kind = AttackKind.CHARGING
	charge_elapsed = 0.0
	combo_buffered = false
	combo_timer = 0.0
	cancel_lunge()
	root.set("player_is_attacking", true)
	root.set("player_anim_name", "charge")
	root.set("player_anim_frame", 0)
	root.set("player_anim_timer", 0.0)
	root.set("player_attack_hit_done", false)
	var player := root.get("player") as Sprite2D
	player.visible = true
	(root.get("player_attack_visual") as Sprite2D).visible = false
	(root.get("player_animation_component") as PlayerAnimationComponent).apply_frame(root)
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.begin_attack_visual(root)
	return true


func tick_charge(root: Object, delta: float) -> void:
	if attack_kind != AttackKind.CHARGING:
		return
	var tuning := root.get("player_tuning") as PlayerTuning
	var agi_value: Variant = root.get("player_agi")
	var effective_agi := float(agi_value) if agi_value != null else float(root.get("player_spd"))
	var charge_multiplier := tuning.charge_multiplier_for_agi(effective_agi) if tuning != null else 1.0
	charge_elapsed = minf(charge_elapsed + maxf(delta, 0.0) * charge_multiplier, tuning.charge_maximum_time if tuning != null else 1.0)
	if attack_button_held:
		return
	if tuning != null and charge_elapsed >= tuning.charge_minimum_time:
		start_charged_attack(root)
	else:
		# A release before the threshold is a canceled charge, not an accidental
		# weak finisher. The shared interrupt path restores all visual layers.
		root.call("_interrupt_player_attack")


func apply_hitbox(root: Object) -> void:
	var hitbox := attack_polygon(root)
	if hitbox.size() < 3:
		return
	if not hit_sound_played and root.has_method("_play_sound"):
		root.call("_play_sound", "miss", -6.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
		hit_sound_played = true
	var slimes := root.get("slimes") as Array[Sprite2D]
	var puzzle_torches := root.get("puzzle_torches") as Array[Sprite2D]
	var eligible_targets: Array[Sprite2D] = []
	var slime_targets: Array[Sprite2D] = []
	var orb_targets: Array[Sprite2D] = []
	for slime in slimes:
		if not bool(root.call("_is_slime_targetable", slime)) or eligible_targets.has(slime) or hit_targets.has(slime):
			continue
		var slime_body := root.call("_slime_body_polygon", slime) as PackedVector2Array
		if slime_body.size() < 3 or Geometry2D.intersect_polygons(hitbox, slime_body).is_empty():
			continue
		eligible_targets.append(slime)
		slime_targets.append(slime)
	for orb in puzzle_torches:
		if not bool(root.call("_is_slime_targetable", orb)) or eligible_targets.has(orb) or hit_targets.has(orb):
			continue
		if not polygon_intersects_rect(hitbox, sprite_world_rect(orb)):
			continue
		eligible_targets.append(orb)
		orb_targets.append(orb)
	if eligible_targets.is_empty():
		return
	var target_count := slime_targets.size()
	var tuning := root.get("player_tuning") as PlayerTuning
	var successful_damage_count := 0
	var used_imbue := false
	var imbued_element_value = root.get("player_imbued_element")
	var active_imbued_element := int(imbued_element_value) if imbued_element_value != null else ElementCatalogScript.Element.NEUTRAL
	for orb in orb_targets:
		register_hit(orb)
		root.call("_activate_puzzle_torch", orb, orb.global_position, ElementCatalogScript.palette_key(attack_element))
	for slime in slime_targets:
		register_hit(slime)
		var damage_result := root.call("_player_attack_damage_result_against", slime, attack_element) as CombatCalculator.DamageResult
		var base_damage := damage_result.amount
		var damage := base_damage
		# Spin is the player's area-control option: its single-target coefficient
		# is lower than Attack 1, but each enemy receives the full spin hit instead
		# of the normal multi-target damage share.
		var divisor := 1.0 if is_spin_attack() else float(root.call("_player_attack_damage_share_divisor", slime, target_count))
		if not damage_result.immune and tuning != null:
			if is_charged_attack2():
				damage = maxf(base_damage * tuning.charged_attack2_damage_multiplier, base_damage + 1.0)
			elif variant == 2:
				damage = maxf(base_damage * tuning.attack2_damage_multiplier, base_damage + 1.0)
			elif is_spin_attack():
				damage = base_damage * tuning.spin_damage_multiplier
			if target_count > 1 and variant == 2:
				damage = maxf(damage * tuning.attack2_multi_target_damage_multiplier, damage + 1.0)
			if running_attack_active:
				damage *= tuning.run_attack_damage_multiplier
		var divided_damage := 0.0 if damage_result.immune else floorf(damage / maxf(divisor, 1.0))
		if is_finisher() and not damage_result.immune:
			# A combo finisher must always beat the equivalent first-swing share,
			# including at tiny damage values after defensive mitigation.
			var first_swing_share := floorf(base_damage / maxf(divisor, 1.0))
			divided_damage = maxf(divided_damage, first_swing_share + 1.0)
		damage_result.amount = 0.0 if damage_result.immune else maxf(divided_damage, 1.0)
		root.call("_damage_slime", slime, damage_result.amount, damage_result.critical, damage_result.element, damage_result.immune)
		if not damage_result.immune and damage_result.amount > 0.0:
			successful_damage_count += 1
			if active_imbued_element != ElementCatalogScript.Element.NEUTRAL and ElementCatalogScript.normalize(attack_element) == ElementCatalogScript.normalize(active_imbued_element):
				used_imbue = true
		if running_attack_active and not damage_result.immune and tuning != null:
			root.set("hitstop_timer", maxf(float(root.get("hitstop_timer")), tuning.hitstop_duration * tuning.run_attack_hitstop_multiplier))
		if not damage_result.immune:
			root.call("_knockback_slime", slime, special_knockback_multiplier(tuning))
		if not damage_result.immune and root.has_method("_apply_player_lifesteal"):
			root.call("_apply_player_lifesteal", maxf(divided_damage, 1.0))
	if successful_damage_count > 0 and root.has_method("_record_run_style_action"):
		if is_spin_attack():
			root.call("_record_run_style_action", &"spin")
		elif is_charged_attack2():
			root.call("_record_run_style_action", &"charged")
			root.call("_record_run_style_action", &"attack2")
		elif variant == 2:
			root.call("_record_run_style_action", &"attack2")
		else:
			root.call("_record_run_style_action", &"attack1")
		if used_imbue:
			root.call("_record_run_style_action", &"imbued")
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_attack_hits(variant, eligible_targets.size())
	attack_hit_resolved.emit(variant, eligible_targets)


func knockback_multiplier(tuning: PlayerTuning) -> float:
	return base_knockback_multiplier(tuning) * special_knockback_multiplier(tuning)


func base_knockback_multiplier(tuning: PlayerTuning) -> float:
	if tuning == null:
		return 1.0 if is_finisher() else 0.60
	return 1.0 if variant == 2 else tuning.attack1_knockback_multiplier


func special_knockback_multiplier(tuning: PlayerTuning) -> float:
	if tuning == null:
		return 1.0
	if is_spin_attack():
		return tuning.spin_knockback_multiplier
	if is_charged_attack2():
		return tuning.charged_attack2_knockback_multiplier
	return 1.0


func has_frame_hitboxes() -> bool:
	return is_spin_attack()


func frame_uses_hitbox(frame: int, tuning: PlayerTuning) -> bool:
	return is_spin_attack() and tuning != null and frame >= tuning.spin_hit_start_frame and frame <= tuning.spin_hit_end_frame


func attack_polygon(root: Object) -> PackedVector2Array:
	var player := root.get("player") as Sprite2D
	var guide_name := "SpinAttackHitboxShape" if is_spin_attack() else "Attack2HitboxShape" if variant == 2 else "Attack1HitboxShape"
	var guide := player.get_node_or_null(guide_name) as AttackHitboxGuide
	if guide == null:
		return PackedVector2Array()
	return guide.world_polygon(bool(root.get("player_attack_flip_h")), int(root.get("player_anim_frame")) if is_spin_attack() else -1)


func polygon_intersects_rect(polygon: PackedVector2Array, rect: Rect2) -> bool:
	return not Geometry2D.intersect_polygons(polygon, rect_polygon(rect)).is_empty()


func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func sprite_world_rect(sprite: Sprite2D) -> Rect2:
	var local_rect := sprite.get_rect()
	var corners := PackedVector2Array([
		sprite.to_global(local_rect.position),
		sprite.to_global(Vector2(local_rect.end.x, local_rect.position.y)),
		sprite.to_global(local_rect.end),
		sprite.to_global(Vector2(local_rect.position.x, local_rect.end.y)),
	])
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	return bounds


func begin(new_variant: int, new_kind: int = -1) -> void:
	active = true
	variant = new_variant
	attack_kind = (AttackKind.ATTACK2 if new_variant == 2 else AttackKind.ATTACK1) if new_kind < 0 else new_kind
	hit_targets.clear()
	hit_sound_played = false
	attack_started.emit(variant)


func register_hit(target: Sprite2D) -> bool:
	if hit_targets.has(target):
		return false
	hit_targets.append(target)
	return true


func finish() -> void:
	if active:
		active = false
		attack_finished.emit()
	running_attack_active = false
	attack_kind = AttackKind.NONE
	charge_elapsed = 0.0
	hit_targets.clear()
	cancel_lunge()


func cancel() -> void:
	finish()
	combo_buffered = false
	combo_timer = 0.0
	combo_running_attack = false
	attack_button_held = false


func buffer_combo(window: float) -> void:
	combo_buffered = true
	combo_timer = maxf(window, 0.0)
	combo_running_attack = running_attack_active


func set_combo_movement(movement: Vector2) -> void:
	combo_movement = movement


func tick_combo(delta: float) -> void:
	if combo_timer <= 0.0:
		return
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo_buffered = false
		combo_running_attack = false


func consume_combo() -> bool:
	if not combo_buffered:
		return false
	combo_buffered = false
	combo_timer = 0.0
	combo_running_attack = false
	return true


func tick_attack2_cooldown(delta: float) -> void:
	attack2_cooldown_timer = maxf(attack2_cooldown_timer - delta, 0.0)


func can_start_attack2() -> bool:
	return attack2_cooldown_timer <= 0.0


func start_attack2_cooldown(duration: float) -> void:
	attack2_cooldown_timer = maxf(duration, 0.0)


func start_lunge(velocity: Vector2, duration: float) -> void:
	lunge_velocity = velocity
	lunge_remaining = maxf(duration, 0.0)


func cancel_lunge() -> void:
	lunge_velocity = Vector2.ZERO
	lunge_remaining = 0.0


func has_lunge() -> bool:
	return lunge_remaining > 0.0


func consume_lunge(delta: float) -> Vector2:
	if lunge_remaining <= 0.0:
		return Vector2.ZERO
	var step := minf(delta, lunge_remaining)
	lunge_remaining = maxf(lunge_remaining - delta, 0.0)
	var motion := lunge_velocity * step
	if lunge_remaining <= 0.0:
		lunge_velocity = Vector2.ZERO
	return motion


func update_lunge(root: Object, delta: float) -> void:
	if not has_lunge():
		return
	var player := root.get("player") as Sprite2D
	var original := player.position
	var movement := consume_lunge(delta)
	player.position.x += movement.x
	if not root.call("_is_walkable", root.call("_actor_foot", player)) or root.call("_collides_with_static", player):
		player.position.x = original.x
	player.position.y += movement.y
	if not root.call("_is_walkable", root.call("_actor_foot", player)) or root.call("_collides_with_static", player):
		player.position.y = original.y
