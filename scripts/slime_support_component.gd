extends Node
class_name SlimeSupportComponent

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
var _runtime_context: SlimeSupportContext
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


func tick(context: SlimeSupportContext, actor: Sprite2D, delta: float) -> bool:
	if actor != null and is_instance_valid(actor):
		actor.set_meta("support_heal_available", false)
	if not enabled or context == null or not context.is_valid() or actor == null or not is_instance_valid(actor):
		return false
	_runtime_context = context
	var tuning := context.slime_tuning
	if tuning == null:
		return false
	if state != State.READY and actor.position.distance_squared_to(cast_position) > 0.01:
		actor.position = cast_position
	_heal_cooldown_remaining = maxf(_heal_cooldown_remaining - maxf(delta, 0.0), 0.0)
	if state == State.READY:
		cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)
		if _can_seek_heal_target(context, actor):
			var target := _select_heal_target(context, actor, tuning)
			if target != null:
				actor.set_meta("support_heal_available", true)
				if _heal_cooldown_remaining <= 0.0 and _is_heal_target_in_range(context, actor, target, tuning):
					_begin_cast(context, actor, target, tuning)
					return true
		return false
	if state == State.CASTING:
		if not _is_heal_target_valid(context, actor, heal_target, tuning):
			cancel_cast(&"target_lost")
			return false
		cast_elapsed += maxf(delta, 0.0)
		if cast_bar != null and is_instance_valid(cast_bar):
			cast_bar.call("set_progress", cast_elapsed / maxf(tuning.support_cast_time, 0.01))
		var casting_frame_count := _support_animation_frame_count(actor, CASTING_PHASE)
		if casting_frame_count > 0:
			var frame_time := maxf(tuning.support_animation_frame_time, 0.01)
			var frame_index := floori(cast_elapsed / frame_time) % casting_frame_count
			context.set_animation_frame.call(actor, CASTING_PHASE, frame_index)
		charge_timer -= maxf(delta, 0.0)
		if charge_timer <= 0.0:
			var effects := context.effects_spawner as EffectsSpawner
			if effects != null:
				effects.spawn_heal_charge(context, actor, clampf(cast_elapsed / maxf(tuning.support_cast_time, 0.01), 0.0, 1.0))
			charge_timer = maxf(tuning.support_charge_interval, 0.02)
		if cast_elapsed >= maxf(tuning.support_cast_time, 0.01):
			state = State.RELEASE
			release_elapsed = 0.0
			context.set_animation_frame.call(actor, SPELL_PHASE, 0)
			if cast_bar != null and is_instance_valid(cast_bar):
				cast_bar.call("set_progress", 1.0)
			_clear_charge_effect()
			return true
		return true
	if state == State.RELEASE:
		release_elapsed += maxf(delta, 0.0)
		var spell_frame_count := _support_animation_frame_count(actor, SPELL_PHASE)
		var frame_time := maxf(tuning.support_animation_frame_time, 0.01)
		var spell_duration := float(spell_frame_count) * frame_time
		var heal_delay := float(maxi(tuning.support_heal_frame, 0)) * frame_time
		if spell_frame_count > 0:
			var frame_index := mini(floori(release_elapsed / frame_time), spell_frame_count - 1)
			context.set_animation_frame.call(actor, SPELL_PHASE, frame_index)
		if not heal_resolved and release_elapsed >= heal_delay:
			_resolve_heal(context, actor, tuning)
		var release_duration := maxf(tuning.support_cast_release_time, spell_duration)
		if not heal_resolved:
			release_duration = maxf(release_duration, heal_delay)
		if release_elapsed >= release_duration:
			_finish_cast(context, actor)
			return false
		return true
	return false


func _resolve_heal(context: SlimeSupportContext, actor: Sprite2D, tuning: SlimeTuning) -> void:
	if heal_resolved:
		return
	heal_resolved = true
	var target_healed_amount := 0.0
	var caster_healed_amount := 0.0
	var heal_amount := _heal_potency(actor, tuning)
	if _is_heal_target_valid(context, actor, heal_target, tuning):
		var target_health := heal_target.get_node_or_null("Health") as HealthComponent
		if target_health != null:
			# A direct self-cast restores full potency. The reduced self-heal is
			# only the bonus reflected when this cast heals a different ally.
			target_healed_amount = target_health.apply_healing(heal_amount)
			if heal_target != actor and target_healed_amount > 0.0:
				var caster_health := actor.get_node_or_null("Health") as HealthComponent
				if caster_health != null:
					var reflected_heal := heal_amount * clampf(tuning.support_reflected_self_heal_multiplier, 0.0, 1.0)
					caster_healed_amount = caster_health.apply_healing(reflected_heal)
	if target_healed_amount > 0.0 or caster_healed_amount > 0.0:
		context.play_healing_sound.call("healing", 0.0, 1.0, 0.025)
		var effects := context.effects_spawner as EffectsSpawner
		if effects != null:
			if target_healed_amount > 0.0:
				effects.spawn_heal_burst(context, context.actor_foot.call(heal_target) as Vector2, tuning.support_heal_particle_count)
			if caster_healed_amount > 0.0:
				var self_burst_count := maxi(2, ceili(float(tuning.support_heal_particle_count) * 0.5))
				effects.spawn_heal_burst(context, context.actor_foot.call(actor) as Vector2, self_burst_count)
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
	var tuning := _runtime_context.slime_tuning if _runtime_context != null and _runtime_context.is_valid() else null
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
		if _runtime_context != null and _runtime_context.restore_idle_texture.is_valid():
			_runtime_context.restore_idle_texture.call(actor)


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
	var tuning := _runtime_context.slime_tuning if _runtime_context != null and _runtime_context.is_valid() else null
	if combat != null and tuning != null:
		combat.hitstun_timer = maxf(combat.hitstun_timer, tuning.hitstun_time)
		combat.cooldown = maxf(combat.cooldown, tuning.support_cancel_recovery)


func _can_seek_heal_target(context: SlimeSupportContext, actor: Sprite2D) -> bool:
	var tuning := context.slime_tuning
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null or combat.active or combat.hitstun_timer > 0.0 or combat.knockback_timer > 0.0:
		return false
	if cooldown_remaining > 0.0 or bool(context.is_dead.call(actor)):
		return false
	var spawn := actor.get_node_or_null("Spawn")
	if spawn != null and bool(spawn.call("is_active")):
		return false
	if context.is_aggroed.is_valid() and bool(context.is_aggroed.call(actor)):
		return true
	return has_nearby_alerted_ally(context, actor, tuning)


func _select_heal_target(context: SlimeSupportContext, actor: Sprite2D, tuning: SlimeTuning) -> Sprite2D:
	var actor_foot: Vector2 = context.actor_foot.call(actor)
	var actor_pool := context.slimes
	var player := context.player
	var can_self_heal := _has_living_ally(context, actor)
	var self_health := actor.get_node_or_null("Health") as HealthComponent
	var self_missing := 0.0
	if self_health != null:
		self_missing = maxf(self_health.maximum_health - self_health.current_health, 0.0)
		var health_ratio := self_health.current_health / maxf(self_health.maximum_health, 0.01)
		if can_self_heal and self_missing > 0.0 and health_ratio <= clampf(tuning.support_self_heal_threshold, 0.0, 1.0):
			return actor
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
		if bool(context.is_dead.call(candidate)):
			continue
		var health := candidate.get_node_or_null("Health") as HealthComponent
		if health == null or health.current_health <= 0.0:
			continue
		var missing := health.maximum_health - health.current_health
		if missing <= 0.0:
			continue
		var candidate_foot: Vector2 = context.actor_foot.call(candidate)
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
	if best_in_range != null:
		return best_in_range
	if nearest_out_of_range != null:
		return nearest_out_of_range
	return actor if can_self_heal and self_missing > 0.0 else null


func _is_heal_target_in_range(context: SlimeSupportContext, actor: Sprite2D, target: Sprite2D, tuning: SlimeTuning) -> bool:
	var actor_foot: Vector2 = context.actor_foot.call(actor)
	var target_foot: Vector2 = context.actor_foot.call(target)
	return actor_foot.distance_to(target_foot) <= tuning.support_heal_radius


func _is_heal_target_valid(context: SlimeSupportContext, actor: Sprite2D, target: Sprite2D, tuning: SlimeTuning) -> bool:
	if target == null or target == context.player or not is_instance_valid(target) or not target.visible:
		return false
	if target == actor and not _has_living_ally(context, actor):
		return false
	if bool(context.is_dead.call(target)):
		return false
	var health := target.get_node_or_null("Health") as HealthComponent
	if health == null or health.current_health <= 0.0 or health.current_health >= health.maximum_health:
		return false
	return _is_heal_target_in_range(context, actor, target, tuning)


func _heal_potency(actor: Sprite2D, tuning: SlimeTuning) -> float:
	var caster_stats := actor.get_node_or_null("Stats") as StatsComponent
	var intelligence := caster_stats.get_stat(StatsComponent.Stat.INT) if caster_stats != null else 0
	return maxf(tuning.support_heal_amount, 0.0) + float(intelligence) * maxf(tuning.support_heal_per_intelligence, 0.0)


func _has_living_ally(context: SlimeSupportContext, actor: Sprite2D) -> bool:
	for candidate_value in context.slimes:
		var candidate := candidate_value as Sprite2D
		if candidate == null or candidate == actor or candidate == context.player or not is_instance_valid(candidate) or not candidate.visible:
			continue
		if bool(context.is_dead.call(candidate)):
			continue
		var health := candidate.get_node_or_null("Health") as HealthComponent
		if health != null and health.current_health > 0.0:
			return true
	return false


func has_nearby_alerted_ally(context: SlimeSupportContext, actor: Sprite2D, tuning: SlimeTuning) -> bool:
	var radius := maxf(tuning.support_heal_radius, tuning.aggro_range)
	var radius_squared := radius * radius
	var actor_foot: Vector2 = context.actor_foot.call(actor)
	for candidate_value in context.slimes:
		var candidate := candidate_value as Sprite2D
		if candidate == null or candidate == actor or candidate == context.player or not is_instance_valid(candidate) or not candidate.visible:
			continue
		if bool(context.is_dead.call(candidate)):
			continue
		var health := candidate.get_node_or_null("Health") as HealthComponent
		if health != null and health.current_health <= 0.0:
			continue
		var candidate_foot: Vector2 = context.actor_foot.call(candidate)
		if actor_foot.distance_squared_to(candidate_foot) > radius_squared:
			continue
		var brain := candidate.get_node_or_null("Brain") as SlimeBrain
		var is_noticing := brain != null and (brain.is_noticing() or (brain.notice_started and not brain.notice_animation_finished))
		if is_noticing or (context.is_aggroed.is_valid() and bool(context.is_aggroed.call(candidate))):
			return true
	return false


func _begin_cast(context: SlimeSupportContext, actor: Sprite2D, target: Sprite2D, tuning: SlimeTuning) -> void:
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
	context.set_animation_frame.call(actor, CASTING_PHASE, 0)
	if cast_bar != null and is_instance_valid(cast_bar):
		cast_bar.queue_free()
	if cast_arc != null and is_instance_valid(cast_arc):
		cast_arc.queue_free()
	cast_bar = load("res://scripts/enemy_cast_bar.gd").new() as Node2D
	cast_bar.name = "SupportCastBar"
	cast_bar.top_level = true
	cast_bar.z_as_relative = false
	cast_bar.z_index = context.overworld_ui_z
	actor.add_child(cast_bar)
	var player_guard := context.player_guard_component
	var bar_offset := player_guard.bar_offset if player_guard != null else PlayerGuardComponent.BLOCK_BAR_OFFSET
	var support_bar_offset := bar_offset + Vector2(0.0, -5.0)
	cast_bar.global_position = actor.global_position + support_bar_offset
	cast_bar.call("set_anchor_offset", support_bar_offset)
	cast_bar.call("set_progress", 0.0)
	cast_arc = ENEMY_TARGET_ARC_SCRIPT.new() as Node2D
	cast_arc.name = "SupportTargetArc"
	cast_arc.top_level = true
	cast_arc.z_as_relative = false
	actor.add_child(cast_arc)
	var source_point: Vector2 = context.magic_target_point.call(actor)
	var target_point: Vector2 = context.magic_target_point.call(target)
	cast_arc.global_position = Vector2.ZERO
	cast_arc.call("configure", actor, target, source_point, target_point, context.occlusion_renderer)


func _finish_cast(context: SlimeSupportContext, actor: Sprite2D) -> void:
	state = State.READY
	cast_elapsed = 0.0
	release_elapsed = 0.0
	heal_target = null
	heal_resolved = false
	actor.set_meta("support_cast_active", false)
	actor.set_meta("support_animation_phase", &"")
	actor.set_meta("support_heal_available", false)
	context.restore_idle_texture.call(actor)


func _support_animation_frame_count(actor: Sprite2D, phase: StringName) -> int:
	var visual := SlimeActor.component(actor, "Visual", SlimeVisualComponent) as SlimeVisualComponent
	if visual == null:
		return 0
	return visual.support_spell_frames.size() if phase == SPELL_PHASE else visual.support_casting_frames.size()


func _clear_charge_effect() -> void:
	if _runtime_context == null or not _runtime_context.is_valid():
		return
	var effects := _runtime_context.effects_spawner as EffectsSpawner
	if effects != null:
		effects.clear_effect_particles(EffectsSpawner.SUPPORT_HEAL_CHARGE_TAG)
