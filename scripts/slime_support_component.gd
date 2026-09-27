extends Node

const ENEMY_TARGET_ARC_SCRIPT := preload("res://scripts/enemy_target_arc.gd")
const CASTING_PHASE := &"casting"
const SPELL_PHASE := &"spell"

enum State { READY, CASTING, RELEASE }

var enabled := false
var state := State.READY
var cooldown_remaining := 0.0
var cast_elapsed := 0.0
var release_elapsed := 0.0
var charge_timer := 0.0
var heal_resolved := false
var heal_target: Sprite2D
var cast_position := Vector2.ZERO
var cast_bar: Node2D
var cast_arc: Node2D
var _runtime_root: Object
var _heal_cooldown_remaining := 0.0


func _ready() -> void:
	var actor := get_parent() as Sprite2D
	var health := actor.get_node_or_null("Health") as HealthComponent if actor != null else null
	if health != null and not health.damaged.is_connected(_on_health_damaged):
		health.damaged.connect(_on_health_damaged)


func configure(is_enabled: bool) -> void:
	var actor := get_parent() as Sprite2D
	if actor != null:
		actor.set_meta("support_heal_available", false)
	if not is_enabled:
		cancel_cast(&"disabled")
	enabled = is_enabled
	if not is_enabled:
		state = State.READY
		cooldown_remaining = 0.0


func is_cast_active() -> bool:
	return state != State.READY


func tick(root: Object, actor: Sprite2D, delta: float) -> bool:
	if actor != null and is_instance_valid(actor):
		actor.set_meta("support_heal_available", false)
	if not enabled or root == null or actor == null or not is_instance_valid(actor):
		return false
	_runtime_root = root
	var tuning := root.get("slime_tuning") as SlimeTuning
	if tuning == null:
		return false
	_heal_cooldown_remaining = maxf(_heal_cooldown_remaining - maxf(delta, 0.0), 0.0)
	if state == State.READY:
		cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)
		if _can_seek_heal_target(root, actor):
			var target := _select_heal_target(root, actor, tuning)
			if target != null:
				actor.set_meta("support_heal_available", true)
				if _heal_cooldown_remaining <= 0.0 and _is_heal_target_in_range(root, actor, target, tuning):
					_begin_cast(root, actor, target, tuning)
					return true
		return false
	if state == State.CASTING:
		# Contact separation should not turn a rooted channel into a sliding cast.
		if actor.position.distance_squared_to(cast_position) > 0.01:
			actor.position = cast_position
		if not _is_heal_target_valid(root, actor, heal_target, tuning):
			cancel_cast(&"target_lost")
			return false
		cast_elapsed += maxf(delta, 0.0)
		if cast_bar != null and is_instance_valid(cast_bar):
			cast_bar.call("set_progress", cast_elapsed / maxf(tuning.support_cast_time, 0.01))
		var casting_frame_count := _support_animation_frame_count(root, actor, CASTING_PHASE)
		if casting_frame_count > 0:
			var frame_time := maxf(tuning.support_animation_frame_time, 0.01)
			var frame_index := floori(cast_elapsed / frame_time) % casting_frame_count
			root.call("_set_slime_support_animation_frame", actor, CASTING_PHASE, frame_index)
		charge_timer -= maxf(delta, 0.0)
		if charge_timer <= 0.0:
			var effects := root.get("effects_spawner") as EffectsSpawner
			if effects != null:
				effects.spawn_heal_charge_from_root(root, actor, clampf(cast_elapsed / maxf(tuning.support_cast_time, 0.01), 0.0, 1.0))
			charge_timer = maxf(tuning.support_charge_interval, 0.02)
		if cast_elapsed >= maxf(tuning.support_cast_time, 0.01):
			state = State.RELEASE
			release_elapsed = 0.0
			root.call("_set_slime_support_animation_frame", actor, SPELL_PHASE, 0)
			if cast_bar != null and is_instance_valid(cast_bar):
				cast_bar.call("set_progress", 1.0)
			_clear_charge_effect()
			return true
		return true
	if state == State.RELEASE:
		release_elapsed += maxf(delta, 0.0)
		var spell_frame_count := _support_animation_frame_count(root, actor, SPELL_PHASE)
		var frame_time := maxf(tuning.support_animation_frame_time, 0.01)
		var spell_duration := float(spell_frame_count) * frame_time
		if spell_frame_count > 0:
			var frame_index := mini(floori(release_elapsed / frame_time), spell_frame_count - 1)
			root.call("_set_slime_support_animation_frame", actor, SPELL_PHASE, frame_index)
			var heal_frame := clampi(tuning.support_heal_frame, 0, spell_frame_count - 1)
			if not heal_resolved and frame_index >= heal_frame:
				_resolve_heal(root, actor, tuning)
		elif not heal_resolved and release_elapsed >= float(maxi(tuning.support_heal_frame, 0)) * frame_time:
			_resolve_heal(root, actor, tuning)
		if release_elapsed >= maxf(tuning.support_cast_release_time, spell_duration):
			_finish_cast(root, actor)
			return false
		return true
	return false


func _resolve_heal(root: Object, actor: Sprite2D, tuning: SlimeTuning) -> void:
	if heal_resolved:
		return
	heal_resolved = true
	var healed_amount := 0.0
	if heal_target != null and is_instance_valid(heal_target) and heal_target != actor and heal_target != root.get("player") and not bool(root.call("_is_slime_dead", heal_target)):
		var target_health := heal_target.get_node_or_null("Health") as HealthComponent
		if target_health != null:
			healed_amount = target_health.apply_healing(tuning.support_heal_amount)
	if healed_amount > 0.0:
		root.call("_play_sound_with_perlin_pitch", "healing", 0.0, 1.0, 0.025)
		var effects := root.get("effects_spawner") as EffectsSpawner
		if effects != null:
			effects.spawn_heal_burst_from_root(root, root.call("_actor_foot", heal_target), tuning.support_heal_particle_count)
		_heal_cooldown_remaining = maxf(tuning.support_heal_cooldown, 0.0)
	if cast_bar != null and is_instance_valid(cast_bar):
		cast_bar.call("set_progress", 1.0)
		cast_bar.call("finish", false)
	cast_bar = null
	if cast_arc != null and is_instance_valid(cast_arc):
		cast_arc.call("finish", false)
	cast_arc = null
	_clear_charge_effect()


func cancel_cast(reason: StringName = &"cancelled") -> void:
	if state == State.READY:
		return
	var actor := get_parent() as Sprite2D
	var tuning := _runtime_root.get("slime_tuning") as SlimeTuning if _runtime_root != null and is_instance_valid(_runtime_root) else null
	if state == State.CASTING:
		cooldown_remaining = maxf(tuning.support_cancel_recovery if tuning != null else 0.0, 0.0)
	_clear_charge_effect()
	if cast_bar != null and is_instance_valid(cast_bar):
		cast_bar.call("finish", true)
	cast_bar = null
	if cast_arc != null and is_instance_valid(cast_arc):
		cast_arc.call("finish", true)
	cast_arc = null
	state = State.READY
	cast_elapsed = 0.0
	release_elapsed = 0.0
	heal_resolved = false
	heal_target = null
	if actor != null and is_instance_valid(actor):
		actor.set_meta("support_cast_active", false)
		actor.set_meta("support_animation_phase", &"")
		actor.set_meta("support_heal_available", false)
		if _runtime_root != null and is_instance_valid(_runtime_root) and _runtime_root.has_method("_restore_slime_idle_texture"):
			_runtime_root.call("_restore_slime_idle_texture", actor)


func reset() -> void:
	cancel_cast(&"reset")
	state = State.READY
	cooldown_remaining = 0.0
	_heal_cooldown_remaining = 0.0
	cast_elapsed = 0.0
	release_elapsed = 0.0
	heal_resolved = false
	heal_target = null


func _on_health_damaged(_amount: float) -> void:
	cancel_cast(&"damaged")
	var actor := get_parent() as Sprite2D
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent if actor != null else null
	var tuning := _runtime_root.get("slime_tuning") as SlimeTuning if _runtime_root != null and is_instance_valid(_runtime_root) else null
	if combat != null and tuning != null:
		combat.hitstun_timer = maxf(combat.hitstun_timer, tuning.hitstun_time)
		combat.cooldown = maxf(combat.cooldown, tuning.support_cancel_recovery)


func _can_seek_heal_target(root: Object, actor: Sprite2D) -> bool:
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null or combat.active or combat.hitstun_timer > 0.0 or combat.knockback_timer > 0.0:
		return false
	if cooldown_remaining > 0.0 or bool(root.call("_is_slime_dead", actor)):
		return false
	var spawn := actor.get_node_or_null("Spawn")
	if spawn != null and bool(spawn.call("is_active")):
		return false
	return bool(root.call("_is_slime_aggroed", actor))


func _select_heal_target(root: Object, actor: Sprite2D, tuning: SlimeTuning) -> Sprite2D:
	var actor_foot: Vector2 = root.call("_actor_foot", actor)
	var actor_pool: Variant = root.get("slimes")
	if not actor_pool is Array:
		return null
	var player := root.get("player") as Sprite2D
	var best_in_range: Sprite2D
	var best_in_range_missing := 0.0
	var best_in_range_distance := INF
	var nearest_out_of_range: Sprite2D
	var nearest_out_of_range_distance := INF
	var nearest_out_of_range_missing := 0.0
	for candidate_value in actor_pool:
		var candidate := candidate_value as Sprite2D
		if candidate == null or candidate == actor or candidate == player or not is_instance_valid(candidate) or not candidate.visible:
			continue
		if bool(root.call("_is_slime_dead", candidate)):
			continue
		var health := candidate.get_node_or_null("Health") as HealthComponent
		if health == null or health.current_health <= 0.0:
			continue
		var missing := health.maximum_health - health.current_health
		if missing <= 0.0:
			continue
		var candidate_foot: Vector2 = root.call("_actor_foot", candidate)
		var distance := actor_foot.distance_to(candidate_foot)
		if distance <= tuning.support_heal_radius:
			if missing > best_in_range_missing or (is_equal_approx(missing, best_in_range_missing) and distance < best_in_range_distance):
				best_in_range = candidate
				best_in_range_missing = missing
				best_in_range_distance = distance
		elif distance < nearest_out_of_range_distance or (is_equal_approx(distance, nearest_out_of_range_distance) and missing > nearest_out_of_range_missing):
			nearest_out_of_range = candidate
			nearest_out_of_range_distance = distance
			nearest_out_of_range_missing = missing
	return best_in_range if best_in_range != null else nearest_out_of_range


func _is_heal_target_in_range(root: Object, actor: Sprite2D, target: Sprite2D, tuning: SlimeTuning) -> bool:
	var actor_foot: Vector2 = root.call("_actor_foot", actor)
	var target_foot: Vector2 = root.call("_actor_foot", target)
	return actor_foot.distance_to(target_foot) <= tuning.support_heal_radius


func _is_heal_target_valid(root: Object, actor: Sprite2D, target: Sprite2D, tuning: SlimeTuning) -> bool:
	if target == null or target == actor or target == root.get("player") or not is_instance_valid(target) or not target.visible:
		return false
	if bool(root.call("_is_slime_dead", target)):
		return false
	var health := target.get_node_or_null("Health") as HealthComponent
	if health == null or health.current_health <= 0.0 or health.current_health >= health.maximum_health:
		return false
	return _is_heal_target_in_range(root, actor, target, tuning)


func _begin_cast(root: Object, actor: Sprite2D, target: Sprite2D, tuning: SlimeTuning) -> void:
	state = State.CASTING
	heal_target = target
	heal_resolved = false
	cast_elapsed = 0.0
	release_elapsed = 0.0
	charge_timer = 0.0
	cast_position = actor.position
	actor.set_meta("support_cast_active", true)
	actor.set_meta("support_animation_phase", CASTING_PHASE)
	actor.set_meta("support_heal_available", true)
	root.call("_set_slime_support_animation_frame", actor, CASTING_PHASE, 0)
	if cast_bar != null and is_instance_valid(cast_bar):
		cast_bar.queue_free()
	if cast_arc != null and is_instance_valid(cast_arc):
		cast_arc.queue_free()
	cast_bar = load("res://scripts/enemy_cast_bar.gd").new() as Node2D
	cast_bar.name = "SupportCastBar"
	cast_bar.top_level = true
	cast_bar.z_as_relative = false
	cast_bar.z_index = int(root.get("OVERWORLD_UI_Z"))
	actor.add_child(cast_bar)
	var player_guard := root.get("player_guard_component") as PlayerGuardComponent
	var bar_offset := player_guard.bar_offset if player_guard != null else PlayerGuardComponent.BLOCK_BAR_OFFSET
	var support_bar_offset := bar_offset + Vector2(0.0, -2.0)
	cast_bar.global_position = actor.global_position + support_bar_offset
	cast_bar.call("set_anchor_offset", support_bar_offset)
	cast_bar.call("set_progress", 0.0)
	cast_arc = ENEMY_TARGET_ARC_SCRIPT.new() as Node2D
	cast_arc.name = "SupportTargetArc"
	cast_arc.top_level = true
	cast_arc.z_as_relative = false
	actor.add_child(cast_arc)
	var source_point: Vector2 = root.call("_magic_target_point", actor)
	var target_point: Vector2 = root.call("_magic_target_point", target)
	cast_arc.global_position = Vector2.ZERO
	cast_arc.call("configure", actor, target, source_point, target_point)


func _finish_cast(root: Object, actor: Sprite2D) -> void:
	state = State.READY
	cast_elapsed = 0.0
	release_elapsed = 0.0
	heal_target = null
	heal_resolved = false
	actor.set_meta("support_cast_active", false)
	actor.set_meta("support_animation_phase", &"")
	actor.set_meta("support_heal_available", false)
	root.call("_restore_slime_idle_texture", actor)


func _support_animation_frame_count(root: Object, actor: Sprite2D, phase: StringName) -> int:
	var visual := root.call("_slime_visual", actor) as SlimeVisualComponent
	if visual == null:
		return 0
	return visual.support_spell_frames.size() if phase == SPELL_PHASE else visual.support_casting_frames.size()


func _clear_charge_effect() -> void:
	if _runtime_root == null or not is_instance_valid(_runtime_root):
		return
	var effects := _runtime_root.get("effects_spawner") as EffectsSpawner
	if effects != null:
		effects.clear_effect_particles(EffectsSpawner.SUPPORT_HEAL_CHARGE_TAG)
