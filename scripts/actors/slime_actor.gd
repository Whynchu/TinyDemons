@tool
extends EnemyActor
class_name SlimeActor

const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")
const SlimeBrainBehaviorComponentScript = preload("res://scripts/components/slime_brain_behavior_component.gd")


func brain_behavior_component_script() -> Script:
	return SlimeBrainBehaviorComponentScript


static func _guard_context(root: Object) -> PlayerGuardContext:
	var context := PlayerGuardContext.new()
	context.ui_parent = root
	context.player = root.get("player") as Sprite2D
	context.equipment = root.get("player_equipment") as EquipmentComponent
	context.visuals = root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	context.overworld_ui_z = int(root.get("OVERWORLD_UI_Z"))
	context.is_defending_get = func() -> Variant: return root.get("player_is_defending")
	context.is_defending_set = func(value: Variant) -> void: root.set("player_is_defending", value)
	context.player_dead_get = func() -> Variant: return root.get("player_dead")
	context.player_death_pending_get = func() -> Variant: return root.get("player_death_pending")
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_is_targeting_get = func() -> Variant: return root.player_is_targeting
	context.player_hitstun_timer_get = func() -> Variant: return root.get("player_hitstun_timer")
	context.actor_foot = Callable(root, "_actor_foot")
	context.build_equipment_visual_context = func() -> PlayerEquipmentVisualContext: return root.gameplay_frame_controller.equipment_visual_context(root)
	return context

@export var tuning: SlimeTuning


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if tuning == null:
		tuning = SlimeTuning.new()
	super._ready()


static func tick_legacy_runtime(actor: Sprite2D, delta: float, is_dead: Callable, update_knockback: Callable, update_attack: Callable, is_aggroed: Callable, update_scoot: Callable, allow_movement: bool = true, update_scoot_aggro: Callable = Callable()) -> void:
	var spawn := actor.get_node_or_null("Spawn") as Node
	if bool(is_dead.call(actor)) or (spawn != null and bool(spawn.call("is_active"))):
		return
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null:
		return
	var status := actor.get_node_or_null("Status") as StatusComponent
	var movement_locked: bool = status != null and status.is_movement_locked()
	var action_delta := _action_delta_for(actor, delta)
	combat.cooldown = maxf(combat.cooldown - action_delta, 0.0)
	if movement_locked:
		var locked_brain := actor.get_node_or_null("Brain") as EnemyBrain
		if locked_brain != null:
			locked_brain.scoot_timer = 0.0
			locked_brain.scoot_start = actor.position
			locked_brain.scoot_target = actor.position
		update_scoot.call(actor, 0.0)
	if bool(update_knockback.call(actor, delta)):
		return
	if status != null and status.is_attack_locked():
		return
	combat.hitstun_timer = maxf(combat.hitstun_timer - delta, 0.0)
	if combat.hitstun_timer > 0.0 or bool(update_attack.call(actor, action_delta)):
		return
	if movement_locked:
		return
	if not allow_movement:
		return
	var brain := actor.get_node_or_null("Brain") as EnemyBrain
	var aggroed := bool(is_aggroed.call(actor))
	if aggroed:
		if brain != null and brain.repath_timer <= 0.0:
			brain.repath_timer = 0.08
	elif brain != null:
		brain.repath_timer = float(brain.repath_timer) - delta
	if update_scoot_aggro.is_valid():
		update_scoot_aggro.call(actor, delta, aggroed)
	else:
		update_scoot.call(actor, delta)


static func _action_delta_for(actor: Node, delta: float) -> float:
	var status := actor.get_node_or_null("Status") as StatusComponent
	var multiplier := status.attack_speed_multiplier() if status != null else 1.0
	return maxf(delta, 0.0) * clampf(multiplier, 0.05, 1.0)


static func damage_actor(root: Object, slime: Sprite2D, amount: float, was_critical: bool, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false, show_damage_number := true) -> void:
	if bool(root.call("_is_slime_dead", slime)) or (root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", slime))): return
	var phase_combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if phase_combat != null and phase_combat.boss_jump_phase_invulnerable:
		if show_damage_number:
			root.call("_spawn_damage_number", slime, 0.0, false, attack_element, true)
		return
	root.call("_mark_player_in_combat")
	if immune:
		if show_damage_number:
			root.call("_spawn_damage_number", slime, 0.0, false, attack_element, true)
		return
	var health := slime.get_node_or_null("Health") as HealthComponent
	var maximum := float(root.call("_enemy_max_health", slime))
	var previous_health := health.current_health if health != null else maximum
	var health_before_damage := previous_health
	var brain := slime.get_node_or_null("Brain") as EnemyBrain
	if brain != null: brain.persistent_aggro = true
	if health != null: health.apply_damage(amount)
	else: previous_health = maxf(previous_health - amount, 0.0); (slime.get_node_or_null("HealthPresenter") as SlimeHealthPresenter).display_health = maxf((slime.get_node_or_null("HealthPresenter") as SlimeHealthPresenter).display_health, previous_health)
	var health_after_damage := health.current_health if health != null else previous_health
	var applied_damage := maxf(health_before_damage - health_after_damage, 0.0)
	var enemy_chroma := slime.get_node_or_null("EnemyChroma")
	if enemy_chroma != null and applied_damage > 0.0:
		var health_maximum := health.maximum_health if health != null else maximum
		var is_lethal := health.is_dead() if health != null else health_after_damage <= 0.0
		enemy_chroma.call("on_health_damage", root, applied_damage, health_maximum, is_lethal)
	var slime_config := root.get("slime_tuning") as SlimeTuning
	if health != null: health.regen_delay_timer = slime_config.regen_delay; health.regen_accumulator = 0.0
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null:
		combat.flash_timer = slime_config.hit_flash_time
		if not combat.boss_jump_phase_stun_resistant:
			combat.hitstun_timer = slime_config.hitstun_time
	root.call("_show_slime_hit_flash", slime)
	if show_damage_number:
		root.call("_spawn_damage_number", slime, amount, was_critical, attack_element, false)
	root.set("hitstop_timer", (root.get("player_tuning") as PlayerTuning).hitstop_duration)
	if health != null and health.is_dead(): root.call("_kill_slime", slime)


static func start_attack_actor(root: Object, slime: Sprite2D) -> void:
	if root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", slime)):
		return
	var player := root.get("player") as Sprite2D
	var direction: Vector2 = root.call("_actor_foot", player) - root.call("_actor_foot", slime)
	var face_left := direction.x < 0.0
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null:
		combat.face_left = face_left; combat.timer = 0.001; combat.begin(); combat.frame = 0; combat.hit_done = false
		# The attack direction is only committed shortly before impact. Starting
		# the animation establishes the initial facing, but it must not freeze a
		# stale target several frames before the actual decision point.
		combat.attack_target_point = Vector2.ZERO
		combat.attack_lunge_vector = Vector2.ZERO
		combat.attack_committed = false
		slime.set_meta("attack_target_point", Vector2.ZERO)
		slime.set_meta("attack_lunge_vector", Vector2.ZERO)
	var animation := slime.get_node_or_null("Animation") as SlimeAnimationComponent
	if animation != null: animation.set_facing(face_left)
	root.call("_set_slime_facing", slime, -1.0 if face_left else 1.0)
	var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
	var frames: Array[Texture2D] = [] if visual == null else visual.attack_left_frames if face_left else visual.attack_right_frames
	if frames.is_empty(): return
	root.call("_set_slime_attack_frame", slime, 0)
	var brain := slime.get_node_or_null("Brain") as EnemyBrain
	if brain != null: brain.scoot_timer = 0.0; brain.scoot_start = slime.position; brain.scoot_target = slime.position
	root.call("_set_actor_visual_scale", slime, Vector2.ONE)


static func apply_attack_hit(root: Object, slime: Sprite2D, ranged_hit: bool = false) -> void:
	if root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", slime)):
		return
	var player := root.get("player") as Sprite2D
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if not ranged_hit and root.has_method("_play_sound"):
		root.call("_play_sound", "bite", -8.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
	var slime_body := root.call("_slime_body_polygon", slime) as PackedVector2Array
	var player_rect := root.call("_collision_rect", player) as Rect2
	var player_body := PackedVector2Array([player_rect.position, Vector2(player_rect.end.x, player_rect.position.y), player_rect.end, Vector2(player_rect.position.x, player_rect.end.y)])
	if slime_body.size() < 3:
		return
	if not ranged_hit and Geometry2D.intersect_polygons(slime_body, player_body).is_empty():
		return
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_enemy_attack_attempt()
	if bool(root.get("player_is_rolling")) or bool(root.get("player_is_backflipping")):
		if run_state != null:
			run_state.record_dodge()
		if root.has_method("_record_run_style_action"):
			root.call("_record_run_style_action", &"backflip" if bool(root.get("player_is_backflipping")) else &"dodge_roll")
		return
	var damage_result := root.call("_slime_attack_damage_result", slime) as CombatCalculator.DamageResult
	root.call("_mark_player_in_combat")
	if damage_result != null and damage_result.immune:
		root.call("_spawn_player_damage_number", 0.0, damage_result.element, true)
		return
	var damage := damage_result.amount if damage_result != null else float(root.call("_slime_attack_damage", slime))
	var player_status := player.get_node_or_null("Status") as StatusComponent
	if player_status != null and damage_result != null:
		damage *= player_status.damage_taken_multiplier()
		damage *= player_status.incoming_damage_multiplier_for(damage_result.element)
	var guard := root.get("player_guard_component") as PlayerGuardComponent
	var blocked := false
	var perfect_block := false
	var block_stun := 0.0
	var player_knockback_multiplier := 1.0
	var counter_knockback_multiplier := 0.0
	if guard != null:
		var guard_result := guard.absorb_damage(_guard_context(root), damage, root.call("_actor_foot", slime))
		blocked = bool(guard_result["blocked"])
		perfect_block = bool(guard_result.get("perfect", false))
		block_stun = float(guard_result.get("stun", 0.0))
		player_knockback_multiplier = float(guard_result.get("player_knockback_multiplier", 1.0))
		counter_knockback_multiplier = float(guard_result.get("counter_knockback_multiplier", 0.0))
		var shield_damage := float(guard_result["shield_damage"])
		if shield_damage > 0.0: root.call("_spawn_player_shield_damage_number", shield_damage)
		damage = float(guard_result["health_damage"])
	var health := root.get("player_health_component") as HealthComponent
	if health != null: health.apply_damage(damage)
	var state := root as GameplayState
	if damage > 0.0 and damage_result != null:
		var combat_runtime := state.combat_runtime_controller as CombatRuntimeController if state != null else null
		if combat_runtime != null:
			combat_runtime.try_apply_status(state, player, damage_result.element, damage_result.effectiveness)
	if blocked or damage > 0.0:
		if state != null:
			var impact_position := state._actor_foot(player)
			if blocked:
				impact_position = impact_position.lerp(state._actor_foot(slime), 0.35)
			if state.effects_spawner != null:
				if blocked:
					state.effects_spawner.spawn_shield_block_burst_from_root(root, impact_position, perfect_block)
				else:
					var impact_color := ElementCatalogScript.damage_number_color(damage_result.element if damage_result != null else ElementCatalogScript.Element.NEUTRAL)
					state.effects_spawner.spawn_combat_hit_burst_from_root(root, impact_position, impact_color)
			if state.display_controller != null:
				var shake_strength := 1.8 if perfect_block else (1.3 if blocked else 2.2)
				var shake_duration := 0.13 if perfect_block else (0.10 if blocked else 0.16)
				state.display_controller.request_screen_shake(shake_strength, shake_duration)
	# A bone projectile deals its normal damage, hit flash, hitstop, and
	# knockback, but it does not cancel an in-progress player attack or charge.
	if bool(root.get("player_is_attacking")) and not ranged_hit: root.call("_interrupt_player_attack")
	var player_tuning := root.get("player_tuning") as PlayerTuning
	# Shielding changes damage and knockback, but a successful hit still needs
	# to read clearly on the player as well as the equipment.
	root.set("player_hit_flash_timer", player_tuning.hit_flash_time)
	root.set("player_hitstun_timer", player_tuning.hitstun_time)
	root.call("_apply_player_hit_knockback", slime, player_knockback_multiplier)
	if damage > 0.0: root.call("_spawn_player_damage_number", damage, damage_result.element if damage_result != null else ElementCatalogScript.Element.NEUTRAL, false)
	root.call("_update_player_health_ui")
	root.set("hitstop_timer", player_tuning.hitstop_duration)
	if blocked and combat != null:
		combat.active = false
		combat.timer = 0.0
		combat.hit_done = true
		# A blocked ranged bone throw can interrupt/stun the skeleton, but the
		# shield counter should only shove attackers whose strike is in melee.
		if counter_knockback_multiplier > 0.0 and not slime is SkeletonActor:
			root.call("_knockback_slime", slime, counter_knockback_multiplier, false, false)
		# Blocking interrupts the swing, but it still consumes the enemy's normal
		# attack recovery. Without this, the interrupted attack can restart on the
		# very next frame and turn a successful block into a punishment.
		var slime_tuning := root.get("slime_tuning") as SlimeTuning
		combat.cooldown = slime_tuning.attack_cooldown if slime_tuning != null else 1.0
		combat.hitstun_timer = maxf(combat.hitstun_timer, block_stun)
		# A Shadow Slime blocked mid-swing is stunned for a full second before it can
		# resume its routine, and it stays revealed (hittable) during the stun.
		var ambush := slime.get_node_or_null("Ambush") as SlimeAmbushComponent
		if ambush != null:
			ambush.begin_block_stun(slime)
			combat.hitstun_timer = maxf(combat.hitstun_timer, ambush.block_stun)
			combat.cooldown = maxf(combat.cooldown, ambush.block_stun)
	var player_health := root.get("player_health_component") as HealthComponent
	if player_health != null and player_health.current_health <= 0.0: root.set("player_death_pending", true); root.call("_interrupt_player_attack"); root.set("player_is_rolling", false)
