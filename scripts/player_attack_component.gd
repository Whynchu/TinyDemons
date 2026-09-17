extends Node
class_name PlayerAttackComponent

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const CircularInputRecognizerScript = preload("res://scripts/circular_input_recognizer.gd")

## Editor-facing attack tuning.
@export var sword_beam_chroma_cost := 30
@export var sword_beam_cooldown := 8.0
@export var spin_hitstun_duration := 0.18

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
## Each spin pulse owns its own target set. This makes the two contacts
## deterministic instead of depending on a per-target cooldown between frames.
var spin_pulse_targets: Dictionary = {}
var spin_pulse_sounds: Dictionary = {}
var spin_pending_knockback: Array[Sprite2D] = []
var combo_buffered := false
var combo_timer := 0.0
var combo_movement := Vector2.ZERO
var attack2_cooldown_timer := 0.0
var sword_beam_cooldown_remaining := 0.0
var lunge_velocity := Vector2.ZERO
var lunge_remaining := 0.0
var lunge_duration := 0.0
var lunge_elapsed := 0.0
var lunge_ease_out := false
var attack_element := ElementCatalogScript.Element.NEUTRAL
var attack_button_held := false
var charge_elapsed := 0.0
var charge_release_pending := false
var hit_sound_played := false
## Captured when the current swing starts. Movement is locked during attacks, so
## this latch keeps a running attack's bonuses stable through the hit frame.
var running_attack_active := false
var combo_running_attack := false
var spin_direction := Vector2.RIGHT
var spin_gesture = CircularInputRecognizerScript.new()
var _spin_gesture_configured := false
var _spin_gesture_signature := 0


func start_player_attack(root: GameplayState, new_variant: int) -> bool:
	var requested_kind := AttackKind.ATTACK2 if new_variant == 2 else AttackKind.ATTACK1
	return _start_attack(root, requested_kind, 2 if new_variant == 2 else 1, "attack2" if new_variant == 2 else "attack1")


## A running attack skips the first swing and commits directly to the regular
## Attack 2 animation with the running-specific movement, damage, knockback,
## hitstop, and recovery contract.
func start_running_attack(root: GameplayState) -> bool:
	if not root.player_is_running:
		return false
	var started := _start_attack(root, AttackKind.ATTACK2, 2, "attack2")
	if started:
		# The roll continuation has been spent. Holding the button through this
		# attack cannot silently create another run after the attack recovers.
		root.player_is_running = false
	return started


func start_spin_attack(root: GameplayState) -> bool:
	var animation := root.player_animation_component
	if animation == null or animation.spin_frames.is_empty():
		return false
	var started := _start_attack(root, AttackKind.SPIN, 1, "spin_attack")
	if started:
		spin_gesture.consume()
	return started


func start_charged_attack(root: GameplayState) -> bool:
	return _start_attack(root, AttackKind.CHARGED_ATTACK2, 2, "attack2_charged")


func _start_attack(root: GameplayState, new_kind: int, new_variant: int, animation_name: String) -> bool:
	var anim := root.player_animation_component
	if anim == null:
		return false
	var frames: Array[Texture2D] = anim.spin_frames if new_kind == AttackKind.SPIN else anim.attack2_frames if new_variant == 2 else anim.attack_frames
	if frames.is_empty():
		return false
	var starts_from_run := new_kind == AttackKind.ATTACK2 and root.player_is_running
	if new_variant == 2 and combo_buffered:
		starts_from_run = combo_running_attack
	elif new_kind == AttackKind.CHARGED_ATTACK2 and attack_kind == AttackKind.CHARGING:
		starts_from_run = running_attack_active
	running_attack_active = starts_from_run and new_kind == AttackKind.ATTACK2
	var run_state := root.run_state
	if run_state != null:
		run_state.record_attack(new_variant, root._is_run_combat_active())
	root.player_is_attacking = true
	begin(new_variant, new_kind)
	root.player_just_finished_attack2 = false
	root.player_attack_hit_done = false
	hit_targets.clear()
	hit_sound_played = false
	charge_elapsed = 0.0
	attack_element = int(root._player_weapon_element()) as ElementCatalogScript.Element
	var player := root.player
	root.player_attack_flip_h = player.flip_h
	var tuning := root.player_tuning
	var agi_value: Variant = root.player_agi
	var effective_agi := float(agi_value) if agi_value != null else float(root.player_spd)
	var attack_multiplier := tuning.attack_multiplier_for_agi(effective_agi)
	if new_kind == AttackKind.SPIN:
		var input_direction: Vector2 = root._movement_input()
		if input_direction.length_squared() <= 0.0001:
			var remembered_direction: Variant = root.last_player_input_direction
			if remembered_direction is Vector2:
				input_direction = remembered_direction as Vector2
		if input_direction.length_squared() <= 0.0001:
			input_direction = root._player_facing_vector()
		spin_direction = input_direction.normalized() if input_direction.length_squared() > 0.0001 else Vector2.RIGHT
		var spin_distance := tuning.spin_lunge_distance if tuning != null else 3.5
		# Finish the spin's travel before frame 6 (the third-to-last frame). The
		# remaining recovery frames can settle visually without carrying motion.
		var spin_duration := tuning.spin_lunge_duration / attack_multiplier if tuning != null else 0.73
		if tuning != null:
			spin_duration = tuning.spin_frame_time * float(tuning.spin_recovery_start_frame) / attack_multiplier
		spin_duration = maxf(spin_duration, 0.001)
		start_lunge(root._perspective_movement(spin_direction * (spin_distance * 2.0 / spin_duration)), spin_duration, true)
		# A spin is a standalone attack. It cannot inherit a pending combo or
		# the recovery timer from an attack that happened immediately before it.
		combo_buffered = false
		combo_timer = 0.0
		root.player_between_timer = 0.0
	else:
		var lunge_multiplier := tuning.run_attack_lunge_multiplier if running_attack_active else 1.0
		if new_kind == AttackKind.CHARGED_ATTACK2:
			lunge_multiplier = tuning.charged_attack_lunge_multiplier
		var lunge_distance := tuning.attack_lunge_distance * lunge_multiplier
		var motion_duration := tuning.attack_lunge_duration / attack_multiplier
		start_lunge(root._perspective_movement(root._player_facing_vector() * (lunge_distance / motion_duration)), motion_duration)
	root.player_anim_name = animation_name
	if new_variant == 2:
		root.player_between_timer = 0.0
	root.player_anim_frame = 0
	root.player_anim_timer = 0.0
	root._restore_actor_base_visual_scale(player)
	root.player_attack_visual.visible = false
	player.visible = false
	anim.apply_frame(root)
	var equipment_visual := root.player_equipment_visual_component
	if equipment_visual != null:
		equipment_visual.begin_attack_visual(root._equipment_visual_context())
	if new_kind == AttackKind.CHARGED_ATTACK2:
		var chroma := root.player_chroma_component
		var beam_palette := String(root.current_player_palette_name)
		if sword_beam_cooldown_remaining <= 0.0 and chroma != null and bool(chroma.call("spend_chroma", sword_beam_chroma_cost)):
			root._sync_chroma_presentation()
			var direction: Vector2 = root._player_facing_vector()
			if direction.length_squared() <= 0.0001:
				direction = Vector2.LEFT if root.player_attack_flip_h else Vector2.RIGHT
			root._spawn_sword_beam(root._player_visual_center(), direction.normalized(), beam_palette)
			sword_beam_cooldown_remaining = sword_beam_cooldown
	var shadow_controller := root.shadow_controller
	if shadow_controller != null:
		shadow_controller.sync_player_attack_shadow(root, float(root.DEPTH_Z_SCALE))
	return true


func set_attack_input_held(held: bool) -> void:
	attack_button_held = held


func update_spin_input(root: GameplayState, movement: Vector2, delta: float, can_listen: bool) -> void:
	_configure_spin_gesture(root)
	if not can_listen or active or root.player_is_magic_casting or root.player_is_rolling or root.player_is_backflipping or root.player_is_defending:
		spin_gesture.reset()
		return
	spin_gesture.update(movement, delta)


func _configure_spin_gesture(root: GameplayState) -> void:
	var tuning := root.player_tuning
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


func begin_charge(root: GameplayState) -> bool:
	if not should_enter_charge():
		return false
	attack_kind = AttackKind.CHARGING
	charge_release_pending = false
	var charge_chroma := root.player_chroma_component
	if sword_beam_cooldown_remaining <= 0.0 and (charge_chroma == null or bool(charge_chroma.call("can_spend_chroma", sword_beam_chroma_cost))):
		root._play_sound("sword_beam_charge", 0.0, 1.0)
	charge_elapsed = 0.0
	combo_buffered = false
	combo_timer = 0.0
	cancel_lunge()
	root.player_is_attacking = true
	root.player_anim_name = "charge"
	root.player_anim_frame = 0
	root.player_anim_timer = 0.0
	root.player_attack_hit_done = false
	var player := root.player
	player.visible = true
	root.player_attack_visual.visible = false
	root.player_animation_component.apply_frame(root)
	var equipment_visual := root.player_equipment_visual_component
	if equipment_visual != null:
		equipment_visual.begin_attack_visual(root._equipment_visual_context())
	return true


func tick_charge(root: GameplayState, delta: float) -> void:
	if attack_kind != AttackKind.CHARGING:
		return
	var tuning := root.player_tuning
	var agi_value: Variant = root.player_agi
	var effective_agi := float(agi_value) if agi_value != null else float(root.player_spd)
	var charge_multiplier := tuning.charge_multiplier_for_agi(effective_agi) if tuning != null else 1.0
	charge_elapsed = minf(charge_elapsed + maxf(delta, 0.0) * charge_multiplier, tuning.charge_maximum_time if tuning != null else 1.0)
	if attack_button_held:
		return
	if tuning == null or charge_elapsed < tuning.charge_minimum_time:
		# A release before the threshold is a canceled charge, not an accidental
		# weak finisher. The shared interrupt path restores all visual layers.
		root._interrupt_player_attack()
		return
	# Releasing arms the finisher, but it cannot fire until the charge reaches its
	# cap and the outline's opaque ready flash has completed.
	charge_release_pending = true
	if charge_elapsed < tuning.charge_maximum_time:
		return
	var effects := root.effects_spawner
	var chroma := root.player_chroma_component
	var beam_available: bool = sword_beam_cooldown_remaining <= 0.0 and chroma != null and bool(chroma.call("can_spend_chroma", sword_beam_chroma_cost))
	if beam_available and effects != null and not effects.charge_ready_flash_complete():
		return
	start_charged_attack(root)


func apply_hitbox(root: GameplayState) -> void:
	var hitbox := attack_polygon(root)
	if hitbox.size() < 3:
		return
	var tuning := root.player_tuning
	var spin_pulse := _spin_pulse_index(root.player_anim_frame, tuning) if is_spin_attack() else -1
	# Spin has two explicit pulse windows; never let the generic attack hit-frame
	# fallback create an extra contact before pulse one.
	if is_spin_attack() and spin_pulse < 0:
		return
	var should_play_spin_sound := spin_pulse >= 0 and not spin_pulse_sounds.has(spin_pulse)
	if should_play_spin_sound:
		root._play_sound("miss", -6.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
		spin_pulse_sounds[spin_pulse] = true
	elif not is_spin_attack() and not hit_sound_played:
		root._play_sound("miss", -6.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
		hit_sound_played = true
	var slimes := root.slimes
	var puzzle_torches := root.puzzle_torches
	var eligible_targets: Array[Sprite2D] = []
	var slime_targets: Array[Sprite2D] = []
	var orb_targets: Array[Sprite2D] = []
	var pulse_targets: Dictionary = {}
	if spin_pulse >= 0:
		if not spin_pulse_targets.has(spin_pulse):
			spin_pulse_targets[spin_pulse] = {}
		pulse_targets = spin_pulse_targets[spin_pulse]
	for slime in slimes:
		var slime_id := slime.get_instance_id()
		var already_hit := hit_targets.has(slime) if not is_spin_attack() else pulse_targets.has(slime_id)
		if not root._is_slime_targetable(slime) or eligible_targets.has(slime) or already_hit:
			continue
		var slime_body := root._slime_body_polygon(slime)
		if slime_body.size() < 3 or Geometry2D.intersect_polygons(hitbox, slime_body).is_empty():
			continue
		if is_spin_attack():
			pulse_targets[slime_id] = true
		eligible_targets.append(slime)
		slime_targets.append(slime)
	for orb in puzzle_torches:
		if not root._is_slime_targetable(orb) or eligible_targets.has(orb) or hit_targets.has(orb):
			continue
		if not polygon_intersects_rect(hitbox, sprite_world_rect(orb)):
			continue
		eligible_targets.append(orb)
		orb_targets.append(orb)
	if eligible_targets.is_empty():
		return
	var target_count := slime_targets.size()
	var successful_damage_count := 0
	var used_imbue := false
	var imbued_element_value = root.player_imbued_element
	var active_imbued_element := int(imbued_element_value) if imbued_element_value != null else ElementCatalogScript.Element.NEUTRAL
	for orb in orb_targets:
		register_hit(orb)
		root._activate_puzzle_torch(orb, orb.global_position, ElementCatalogScript.palette_key(attack_element))
	for slime in slime_targets:
		if not is_spin_attack():
			register_hit(slime)
		var imbued_contact := active_imbued_element != ElementCatalogScript.Element.NEUTRAL and ElementCatalogScript.normalize(attack_element) == ElementCatalogScript.normalize(active_imbued_element)
		var damage_result := root._player_attack_damage_result_against(slime, attack_element)
		var base_damage := damage_result.amount
		var damage := base_damage
		# Spin is the player's area-control option: its single-target coefficient
		# is lower than Attack 1, but each enemy receives the full spin hit instead
		# of the normal multi-target damage share.
		var divisor := 1.0 if is_spin_attack() else float(root._player_attack_damage_share_divisor(slime, target_count))
		if not damage_result.immune and tuning != null:
			if is_charged_attack2():
				damage = maxf(base_damage * tuning.charged_attack2_damage_multiplier, base_damage + 1.0)
			elif variant == 2:
				damage = maxf(base_damage * tuning.attack2_damage_multiplier, base_damage + 1.0)
			elif is_spin_attack():
				var final_spin_pulse := spin_pulse == 1
				damage = base_damage * (tuning.spin_damage_multiplier if final_spin_pulse else 0.40)
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
		root._damage_slime(slime, damage_result.amount, damage_result.critical, damage_result.element, damage_result.immune)
		if imbued_contact:
			root._play_sound_with_perlin_pitch("imbue_impact", 0.0, 1.0, 0.03)
		if not damage_result.immune and damage_result.amount > 0.0:
			successful_damage_count += 1
			if imbued_contact:
				used_imbue = true
		if running_attack_active and not damage_result.immune and tuning != null:
			root.hitstop_timer = maxf(root.hitstop_timer, tuning.hitstop_duration * tuning.run_attack_hitstop_multiplier)
		if not damage_result.immune:
			if is_spin_attack():
				var slime_combat: SlimeCombatComponent = root._slime_combat(slime)
				if slime_combat != null:
					slime_combat.hitstun_timer = maxf(slime_combat.hitstun_timer, spin_hitstun_duration)
			if is_spin_attack():
				if spin_pulse == 1:
					root._knockback_slime(slime, special_knockback_multiplier(tuning))
				else:
					root._knockback_slime(slime, special_knockback_multiplier(tuning) * 0.25)
			else:
				root._knockback_slime(slime, special_knockback_multiplier(tuning))
		if not damage_result.immune:
			root._apply_player_lifesteal(maxf(divided_damage, 1.0))
	if successful_damage_count > 0:
		if is_spin_attack():
			root._record_run_style_action(&"spin")
		elif is_charged_attack2():
			root._record_run_style_action(&"charged")
			root._record_run_style_action(&"attack2")
		elif variant == 2:
			root._record_run_style_action(&"attack2")
		else:
			root._record_run_style_action(&"attack1")
		if used_imbue:
			root._record_run_style_action(&"imbued")
	var run_state := root.run_state
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
	var multiplier := 1.0
	if is_spin_attack():
		multiplier *= tuning.spin_knockback_multiplier
	elif is_charged_attack2():
		multiplier *= tuning.charged_attack2_knockback_multiplier
	if running_attack_active:
		multiplier *= tuning.run_attack_knockback_multiplier
	return multiplier


func attack2_cooldown_duration(tuning: PlayerTuning) -> float:
	if tuning == null:
		return 0.0
	var extra_frames := tuning.run_attack_extra_cooldown_frames if running_attack_active else 0.0
	return maxf(tuning.attack2_cooldown + tuning.attack_frame_time * maxf(extra_frames, 0.0), 0.0)


func has_frame_hitboxes() -> bool:
	return is_spin_attack()


func frame_uses_hitbox(frame: int, tuning: PlayerTuning) -> bool:
	return is_spin_attack() and _spin_pulse_index(frame, tuning) >= 0


func _spin_pulse_index(frame: int, tuning: PlayerTuning) -> int:
	if tuning == null or frame < tuning.spin_hit_start_frame or frame > tuning.spin_hit_start_frame + 2:
		return -1
	if frame == tuning.spin_hit_start_frame:
		return 0
	if frame == tuning.spin_hit_start_frame + 2:
		return 1
	return -1


func attack_polygon(root: GameplayState) -> PackedVector2Array:
	var player := root.player
	var guide_name := "SpinAttackHitboxShape" if is_spin_attack() else "Attack2HitboxShape" if variant == 2 else "Attack1HitboxShape"
	var guide := player.get_node_or_null(guide_name) as AttackHitboxGuide
	if guide == null:
		return PackedVector2Array()
	return guide.world_polygon(root.player_attack_flip_h, root.player_anim_frame if is_spin_attack() else -1)


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
	spin_pulse_targets.clear()
	spin_pulse_sounds.clear()
	spin_pending_knockback.clear()
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
	charge_release_pending = false
	hit_targets.clear()
	spin_pulse_targets.clear()
	spin_pulse_sounds.clear()
	cancel_lunge()


func release_spin_knockback(root: GameplayState) -> void:
	if not is_spin_attack():
		return
	for slime in spin_pending_knockback:
		if slime != null and is_instance_valid(slime) and root._is_slime_targetable(slime):
			root._knockback_slime(slime, special_knockback_multiplier(root.player_tuning))
	spin_pending_knockback.clear()


func tick_spin_hits(_delta: float) -> void:
	# Kept as a scheduler seam for callers; spin contacts are pulse-based now.
	pass


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
	sword_beam_cooldown_remaining = maxf(sword_beam_cooldown_remaining - delta, 0.0)


func can_start_attack2() -> bool:
	return attack2_cooldown_timer <= 0.0


func start_attack2_cooldown(duration: float) -> void:
	attack2_cooldown_timer = maxf(duration, 0.0)


func start_lunge(velocity: Vector2, duration: float, ease_out: bool = false) -> void:
	lunge_velocity = velocity
	lunge_duration = maxf(duration, 0.0)
	lunge_remaining = lunge_duration
	lunge_elapsed = 0.0
	lunge_ease_out = ease_out


func cancel_lunge() -> void:
	lunge_velocity = Vector2.ZERO
	lunge_remaining = 0.0
	lunge_duration = 0.0
	lunge_elapsed = 0.0
	lunge_ease_out = false


func has_lunge() -> bool:
	return lunge_remaining > 0.0


func consume_lunge(delta: float) -> Vector2:
	if lunge_remaining <= 0.0:
		return Vector2.ZERO
	var step := minf(delta, lunge_remaining)
	lunge_remaining = maxf(lunge_remaining - delta, 0.0)
	var motion := lunge_velocity * step
	if lunge_ease_out and lunge_duration > 0.0:
		var start_progress := clampf(lunge_elapsed / lunge_duration, 0.0, 1.0)
		var end_progress := clampf((lunge_elapsed + step) / lunge_duration, 0.0, 1.0)
		var start_speed := 1.0 - start_progress
		var end_speed := 1.0 - end_progress
		motion = lunge_velocity * step * (start_speed + end_speed) * 0.5
	lunge_elapsed = minf(lunge_elapsed + step, lunge_duration)
	if lunge_remaining <= 0.0:
		lunge_velocity = Vector2.ZERO
	return motion


func update_lunge(root: GameplayState, delta: float) -> void:
	if not has_lunge():
		return
	var player := root.player
	var original := player.position
	var movement := consume_lunge(delta)
	player.position.x += movement.x
	if not root._is_walkable(root._actor_foot(player)) or root._collides_with_static(player):
		player.position.x = original.x
	player.position.y += movement.y
	if not root._is_walkable(root._actor_foot(player)) or root._collides_with_static(player):
		player.position.y = original.y
