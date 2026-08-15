extends Node
class_name PlayerAttackComponent

signal attack_started(variant: int)
signal attack_finished
signal attack_hit_resolved(variant: int, targets: Array)

var active := false
var variant := 1
var hit_targets: Array[Sprite2D] = []
var combo_buffered := false
var combo_timer := 0.0
var combo_movement := Vector2.ZERO
var attack2_cooldown_timer := 0.0
var lunge_velocity := Vector2.ZERO
var lunge_remaining := 0.0


func start_player_attack(root: Object, new_variant: int) -> void:
	var frames: Array = root.get("player_attack_frames") if new_variant == 1 else root.get("player_attack2_frames")
	if frames.is_empty(): return
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_attack(new_variant, bool(root.call("_is_run_combat_active")))
	root.set("player_is_attacking", true); begin(new_variant); root.set("player_just_finished_attack2", false); root.set("player_attack_hit_done", false); hit_targets.clear()
	var player := root.get("player") as Sprite2D; root.set("player_attack_flip_h", player.flip_h)
	var tuning := root.get("player_tuning") as PlayerTuning
	start_lunge(root.call("_perspective_movement", root.call("_player_facing_vector") * (tuning.attack_lunge_distance / tuning.attack_lunge_duration)), tuning.attack_lunge_duration)
	root.set("player_anim_name", "attack2" if new_variant == 2 else "attack1")
	if new_variant == 2: root.set("player_between_timer", 0.0)
	root.set("player_anim_frame", 0); root.set("player_anim_timer", 0.0); root.call("_restore_actor_base_visual_scale", player); player.visible = false; (root.get("player_attack_visual") as Sprite2D).visible = true; (root.get("player_animation_component") as PlayerAnimationComponent).apply_frame(root)


func apply_hitbox(root: Object) -> void:
	var hitbox := attack_polygon(root)
	if hitbox.size() < 3: return
	var slimes := root.get("slimes") as Array[Sprite2D]
	var attack_component := root.get("player_attack_component") as PlayerAttackComponent
	var eligible_targets: Array[Sprite2D] = []
	for slime in slimes:
		if bool(root.call("_is_slime_dead", slime)) or eligible_targets.has(slime) or (attack_component != null and attack_component.hit_targets.has(slime)): continue
		if not polygon_intersects_rect(hitbox, root.call("_collision_rect", slime)): continue
		eligible_targets.append(slime)
	if eligible_targets.is_empty(): return
	var target_count := eligible_targets.size()
	var tuning := root.get("player_tuning") as PlayerTuning
	for slime in eligible_targets:
		(root.get("player_attack_hit_targets") as Array[Sprite2D]).append(slime); register_hit(slime)
		var base_damage := float(root.call("_player_attack_damage_against", slime))
		var damage := base_damage
		var divisor := float(root.call("_player_attack_damage_share_divisor", slime, target_count))
		if variant == 2 and tuning != null:
			damage = maxf(base_damage * tuning.attack2_damage_multiplier, base_damage + 1.0)
			if target_count > 1:
				damage = maxf(damage * tuning.attack2_multi_target_damage_multiplier, damage + 1.0)
		var divided_damage := floorf(damage / maxf(divisor, 1.0))
		if variant == 2:
			# A combo finisher must always beat the equivalent first-swing share,
			# including at tiny damage values after defensive mitigation.
			var first_swing_share := floorf(base_damage / maxf(divisor, 1.0))
			divided_damage = maxf(divided_damage, first_swing_share + 1.0)
		root.call("_damage_slime", slime, maxf(divided_damage, 1.0), bool(root.get("last_damage_was_critical"))); root.call("_knockback_slime", slime)
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_attack_hits(variant, eligible_targets.size())
	attack_hit_resolved.emit(variant, eligible_targets)


func attack_polygon(root: Object) -> PackedVector2Array:
	var player := root.get("player") as Sprite2D
	var guide_name := "Attack2HitboxShape" if variant == 2 else "Attack1HitboxShape"
	var guide := player.get_node_or_null(guide_name) as AttackHitboxGuide
	return guide.world_polygon(bool(root.get("player_attack_flip_h"))) if guide != null else PackedVector2Array()


func polygon_intersects_rect(polygon: PackedVector2Array, rect: Rect2) -> bool:
	return not Geometry2D.intersect_polygons(polygon, rect_polygon(rect)).is_empty()


func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func begin(new_variant: int) -> void:
	active = true
	variant = new_variant
	hit_targets.clear()
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
	hit_targets.clear()


func cancel() -> void:
	finish()


func buffer_combo(window: float) -> void:
	combo_buffered = true
	combo_timer = maxf(window, 0.0)


func set_combo_movement(movement: Vector2) -> void:
	combo_movement = movement


func tick_combo(delta: float) -> void:
	if combo_timer <= 0.0:
		return
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo_buffered = false


func consume_combo() -> bool:
	if not combo_buffered:
		return false
	combo_buffered = false
	combo_timer = 0.0
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
	if not has_lunge(): return
	var player := root.get("player") as Sprite2D; var original := player.position; var movement := consume_lunge(delta)
	player.position.x += movement.x; if not root.call("_is_walkable", root.call("_actor_foot", player)) or root.call("_collides_with_static", player): player.position.x = original.x
	player.position.y += movement.y; if not root.call("_is_walkable", root.call("_actor_foot", player)) or root.call("_collides_with_static", player): player.position.y = original.y
