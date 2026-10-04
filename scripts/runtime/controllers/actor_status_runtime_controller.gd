extends RefCounted
class_name ActorStatusRuntimeController


func try_apply_status(root: GameplayState, target: Node, element: int, effectiveness: float, guaranteed := false) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var health := target.get_node_or_null("Health") as HealthComponent
	if health != null and health.is_dead():
		return false
	var combat := target.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null and combat.dead:
		return false
	var request := StatusApplicationRequest.new()
	request.configure(target, element, effectiveness, StatusApplicationRequest.SourceKind.ELEMENTAL_HIT, root.rng, guaranteed)
	return StatusApplication.apply(request)


func tick_actor_statuses(root: GameplayState, actor: Sprite2D, delta: float, is_player: bool) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if is_player and (root.player_dead or root.player_death_pending):
		return
	if not is_player and root._is_slime_dead(actor):
		return
	var component := actor.get_node_or_null("Status") as StatusComponent
	if component == null:
		return
	for result in component.advance(delta):
		if result.kind == StatusTickResult.Kind.DAMAGE:
			_apply_status_damage_tick(root, actor, result, is_player)
		elif result.kind == StatusTickResult.Kind.STUN_PULSE:
			_apply_status_stun_pulse(root, actor, result, is_player)
	var aura := actor.get_node_or_null("ElementAura") as ElementAuraComponent
	if aura != null and is_instance_valid(aura):
		aura.advance_status_visuals(
			delta,
			root.effects_spawner,
			root.rng,
			Callable(root, "_pixel_particle_texture")
		)


func _apply_status_damage_tick(root: GameplayState, actor: Sprite2D, result: StatusTickResult, is_player: bool) -> void:
	var health := actor.get_node_or_null("Health") as HealthComponent
	if health == null or health.current_health <= 0.0:
		return
	var amount := maxf(result.amount, 0.0)
	var status := actor.get_node_or_null("Status") as StatusComponent
	if status != null:
		amount *= status.damage_taken_multiplier()
		amount *= status.incoming_damage_multiplier_for(result.element, false)
	if amount <= 0.0:
		return
	if not is_player and not _enemy_status_tick_may_kill(root, actor):
		amount = minf(amount, maxf(health.current_health - 1.0, 0.0))
	if amount <= 0.0:
		return
	health.apply_damage(amount)
	var slime_tuning := root.slime_tuning
	if not is_player and slime_tuning != null:
		health.regen_delay_timer = slime_tuning.regen_delay
		health.regen_accumulator = 0.0
	if is_player:
		root._spawn_player_damage_number(amount, result.element, false)
		root._update_player_health_ui()
		if health.is_dead():
			root.player_death_pending = true
			root._interrupt_player_attack()
			root.player_is_rolling = false
	else:
		root._spawn_damage_number(actor, amount, false, result.element, false)
		if health.is_dead():
			root._kill_slime(actor)


func _enemy_status_tick_may_kill(root: GameplayState, actor: Sprite2D) -> bool:
	if not actor.visible or not actor.is_visible_in_tree():
		return false
	var viewport := actor.get_viewport()
	if viewport == null or not viewport.get_visible_rect().has_point(actor.get_global_transform_with_canvas().origin):
		return false
	var map_controller := root.dungeon_map_controller
	if map_controller == null:
		return false
	return map_controller.is_room_engaged(root.current_room_id)


func _apply_status_stun_pulse(root: GameplayState, actor: Sprite2D, result: StatusTickResult, is_player: bool) -> void:
	var duration := maxf(result.lock_duration, 0.0)
	if duration <= 0.0:
		return
	if is_player:
		root.player_hitstun_timer = maxf(root.player_hitstun_timer, duration)
		if root.player_is_attacking:
			root._interrupt_player_attack()
		if root.player_is_magic_casting:
			root._cancel_magic_animation()
		return
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null or combat.boss_jump_phase_stun_resistant:
		return
	combat.status_stun_timer = maxf(combat.status_stun_timer, duration)
	combat.active = false
	combat.timer = 0.0
	combat.hit_done = true
	combat.attack_committed = false
	combat.hitstun_timer = maxf(combat.hitstun_timer, duration)
	combat.knockback_velocity = Vector2.ZERO
	combat.knockback_timer = 0.0
	var aura := actor.get_node_or_null("ElementAura") as ElementAuraComponent
	if aura != null:
		aura.trigger_status_stun_shake(duration, result.is_initial_stun_pulse)
	var support := actor.get_node_or_null("Support") as SlimeSupportComponent
	if support != null:
		support.cancel_cast(&"status_stun")
