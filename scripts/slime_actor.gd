extends Sprite2D
class_name SlimeActor

@export_enum("blue", "green", "red", "purple") var variant := "green"
@export var tuning: SlimeTuning


static func component(actor: Sprite2D, node_name: String, component_type: Variant) -> Node:
	var node := actor.get_node_or_null(node_name)
	if node != null:
		return node
	node = component_type.new()
	node.name = node_name
	actor.add_child(node)
	return node


func _ready() -> void:
	if tuning == null:
		tuning = SlimeTuning.new()
	ensure_components()


func ensure_components() -> void:
	_ensure_component("Health", HealthComponent)
	_ensure_component("Brain", SlimeBrain)
	_ensure_component("Combat", SlimeCombatComponent)
	_ensure_component("Tactics", EnemyTacticsComponent)
	_ensure_component("Animation", SlimeAnimationComponent)
	_ensure_component("Visual", SlimeVisualComponent)
	_ensure_component("HealthPresenter", SlimeHealthPresenter)


func configure_health(max_health: float, regen_delay: float, regen_interval: float, regen_amount: float) -> HealthComponent:
	var health := get_node_or_null("Health") as HealthComponent
	if health == null:
		return null
	health.set_process(false)
	health.maximum_health = max_health
	health.regen_delay = regen_delay
	health.regen_interval = regen_interval
	health.regen_amount = regen_amount
	health.reset(max_health)
	return health


func tick_components(delta: float) -> void:
	var brain := get_node_or_null("Brain") as SlimeBrain
	if brain != null:
		brain.tick(delta)
	var combat := get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null:
		combat.tick(delta)
	var tactics := get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		tactics.tick(delta)
	var ambush := get_node_or_null("Ambush") as SlimeAmbushComponent
	if ambush != null:
		ambush.tick(self, delta)


func tick_runtime(delta: float, is_dead: Callable, update_knockback: Callable, update_attack: Callable, is_aggroed: Callable, aggro_target: Callable, update_scoot: Callable) -> void:
	var combat := get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null or is_dead.call(self):
		return
	combat.cooldown = maxf(combat.cooldown - delta, 0.0)
	if update_knockback.call(self, delta):
		return
	combat.hitstun_timer = maxf(combat.hitstun_timer - delta, 0.0)
	if combat.hitstun_timer > 0.0:
		return
	if update_attack.call(self, delta):
		return
	var brain := get_node_or_null("Brain") as SlimeBrain
	if is_aggroed.call(self):
		if brain != null:
			if brain.repath_timer <= 0.0:
				brain.target = aggro_target.call(self)
				brain.repath_timer = 0.08
			brain.repath_timer = maxf(brain.repath_timer - delta, 0.0)
		update_scoot.call(self, delta)
		return
	if brain != null: brain.repath_timer = float(brain.repath_timer) - delta
	update_scoot.call(self, delta)


static func tick_legacy_runtime(actor: Sprite2D, delta: float, is_dead: Callable, update_knockback: Callable, update_attack: Callable, is_aggroed: Callable, aggro_target: Callable, update_scoot: Callable) -> void:
	if bool(is_dead.call(actor)):
		return
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null:
		return
	combat.cooldown = maxf(combat.cooldown - delta, 0.0)
	if bool(update_knockback.call(actor, delta)):
		return
	combat.hitstun_timer = maxf(combat.hitstun_timer - delta, 0.0)
	if combat.hitstun_timer > 0.0 or bool(update_attack.call(actor, delta)):
		return
	var brain := actor.get_node_or_null("Brain") as SlimeBrain
	if bool(is_aggroed.call(actor)):
		if brain != null:
			if brain.repath_timer <= 0.0:
				brain.target = aggro_target.call(actor)
				brain.repath_timer = 0.08
			brain.repath_timer = maxf(brain.repath_timer - delta, 0.0)
		update_scoot.call(actor, delta)
		return
	if brain != null:
		brain.repath_timer = float(brain.repath_timer) - delta
	update_scoot.call(actor, delta)


static func damage_actor(root: Object, slime: Sprite2D, amount: float, was_critical: bool) -> void:
	if bool(root.call("_is_slime_dead", slime)): return
	root.call("_mark_player_in_combat")
	var health := slime.get_node_or_null("Health") as HealthComponent
	var maximum := float(root.call("_enemy_max_health", slime))
	var previous_health := health.current_health if health != null else maximum
	var brain := slime.get_node_or_null("Brain") as SlimeBrain
	if brain != null: brain.persistent_aggro = true
	if health != null: health.apply_damage(amount)
	else: previous_health = maxf(previous_health - amount, 0.0); (slime.get_node_or_null("HealthPresenter") as SlimeHealthPresenter).display_health = maxf((slime.get_node_or_null("HealthPresenter") as SlimeHealthPresenter).display_health, previous_health)
	var slime_config := root.get("slime_tuning") as SlimeTuning
	if health != null: health.regen_delay_timer = slime_config.regen_delay; health.regen_accumulator = 0.0
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null: combat.flash_timer = slime_config.hit_flash_time; combat.hitstun_timer = slime_config.hitstun_time
	root.call("_show_slime_hit_flash", slime)
	root.call("_spawn_damage_number", slime, amount, was_critical); root.set("hitstop_timer", (root.get("player_tuning") as PlayerTuning).hitstop_duration)
	if health != null and health.is_dead(): root.call("_kill_slime", slime)


static func start_attack_actor(root: Object, slime: Sprite2D) -> void:
	var player := root.get("player") as Sprite2D
	var direction: Vector2 = root.call("_actor_foot", player) - root.call("_actor_foot", slime)
	var face_left := direction.x < 0.0
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null: combat.face_left = face_left; combat.timer = 0.001; combat.begin(); combat.frame = 0; combat.hit_done = false
	var animation := slime.get_node_or_null("Animation") as SlimeAnimationComponent
	if animation != null: animation.set_facing(face_left)
	root.call("_set_slime_facing", slime, -1.0 if face_left else 1.0)
	var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
	var frames: Array[Texture2D] = [] if visual == null else visual.attack_left_frames if face_left else visual.attack_right_frames
	if frames.is_empty(): return
	root.call("_set_actor_base_texture", slime, frames[0])
	var brain := slime.get_node_or_null("Brain") as SlimeBrain
	if brain != null: brain.scoot_timer = 0.0; brain.scoot_start = slime.position; brain.scoot_target = slime.position
	root.call("_set_actor_visual_scale", slime, Vector2.ONE)


static func apply_attack_hit(root: Object, slime: Sprite2D) -> void:
	var player := root.get("player") as Sprite2D
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	# The guides are authored around the visible lunge.  Testing against them
	# keeps left/right reach and vertical reach in the same isometric space as
	# the artwork.  A boss expands the lane from its feet rather than stretching
	# a world-axis rectangle, which previously let it hit far below itself.
	var guide_name := "AttackGuideL" if combat != null and combat.face_left else "AttackGuideR"
	var guide := slime.get_node_or_null(guide_name) as Node2D
	if guide == null: return
	var guide_position: Vector2 = guide.get("rect_position")
	var guide_size: Vector2 = guide.get("rect_size")
	var base_rect := Rect2(slime.global_position + guide.position + guide_position + Vector2(minf(guide_size.x, 0.0), minf(guide_size.y, 0.0)), guide_size.abs())
	var foot := root.call("_actor_foot", slime) as Vector2
	var encounter_scale := float(slime.get_meta("encounter_scale", 1.0))
	var hit_rect := Rect2(foot + (base_rect.position - foot) * encounter_scale, base_rect.size * encounter_scale).grow(0.75)
	# The lunge remains left/right authored, but isometric movement compresses
	# vertical travel.  Give that lane a symmetric vertical allowance so a slime
	# can reliably threaten players directly above or below its body.
	var vertical_reach := 7.0 * encounter_scale
	hit_rect.position.y = foot.y - vertical_reach
	hit_rect.size.y = vertical_reach * 2.0
	if not hit_rect.has_point(root.call("_actor_foot", player) as Vector2): return
	if root.has_method("_play_sound"):
		root.call("_play_sound", "bite", 0.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.06, 0.06))
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_enemy_attack_attempt()
	if bool(root.get("player_is_rolling")):
		if run_state != null:
			run_state.record_dodge()
		return
	var damage := float(root.call("_slime_attack_damage", slime)); root.call("_mark_player_in_combat")
	var guard := root.get("player_guard_component") as PlayerGuardComponent
	var blocked := false
	var block_stun := 0.0
	if guard != null:
		var guard_result := guard.absorb_damage(root, damage, root.call("_actor_foot", slime))
		blocked = bool(guard_result["blocked"])
		block_stun = float(guard_result.get("stun", 0.0))
		var shield_damage := float(guard_result["shield_damage"])
		if shield_damage > 0.0: root.call("_spawn_player_shield_damage_number", shield_damage)
		damage = float(guard_result["health_damage"])
	var health := root.get("player_health_component") as HealthComponent
	if health != null: health.apply_damage(damage)
	if bool(root.get("player_is_attacking")): root.call("_interrupt_player_attack")
	var player_tuning := root.get("player_tuning") as PlayerTuning; root.set("player_hit_flash_timer", 0.0 if blocked else player_tuning.hit_flash_time); root.set("player_hitstun_timer", player_tuning.hitstun_time); root.call("_apply_player_hit_knockback", slime); if damage > 0.0: root.call("_spawn_player_damage_number", damage); root.call("_update_player_health_ui"); root.set("hitstop_timer", player_tuning.hitstop_duration)
	if blocked and combat != null:
		combat.active = false
		combat.timer = 0.0
		combat.hit_done = true
		# Blocking interrupts the swing, but it still consumes the enemy's normal
		# attack recovery. Without this, the interrupted attack can restart on the
		# very next frame and turn a successful block into a punishment.
		var slime_tuning := root.get("slime_tuning") as SlimeTuning
		combat.cooldown = slime_tuning.attack_cooldown if slime_tuning != null else 1.0
		combat.hitstun_timer = maxf(combat.hitstun_timer, block_stun)
		# A rogue blocked mid-swing is stunned for a full second before it can
		# resume its routine, and it stays revealed (hittable) during the stun.
		var ambush := slime.get_node_or_null("Ambush") as SlimeAmbushComponent
		if ambush != null:
			ambush.begin_block_stun(slime)
			combat.hitstun_timer = maxf(combat.hitstun_timer, ambush.block_stun)
			combat.cooldown = maxf(combat.cooldown, ambush.block_stun)
	var player_health := root.get("player_health_component") as HealthComponent
	if player_health != null and player_health.current_health <= 0.0: root.set("player_death_pending", true); root.call("_interrupt_player_attack"); root.set("player_is_rolling", false); if root.has_method("_play_sound"): root.call("_play_sound", "death", 0.0, 1.0)


func reset_runtime_state(start_pos: Vector2, initial_target: Vector2, repath_delay: float, hold_delay: float, idle_breath_delay: float, attack_cooldown_delay: float) -> void:
	var brain := get_node_or_null("Brain") as SlimeBrain
	if brain != null:
		brain.start_position = start_pos
		brain.target = initial_target
		brain.repath_timer = repath_delay
		brain.scoot_start = position
		brain.scoot_target = position
		brain.scoot_timer = 0.0
		brain.hold_timer = hold_delay
		brain.idle_breath_timer = idle_breath_delay
		brain.persistent_aggro = false
		brain.aggroed = false
		brain.notice_timer = 0.0
		brain.notice_duration = 0.0
		brain.notice_started = false
		brain.notice_animation_finished = false
		brain.orbit_direction = 0.0
		brain.attack_cooldown = 0.0
		brain.blocked_repath_cooldown = 0.0
	var combat := get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null:
		combat.active = false
		combat.flash_timer = 0.0
		combat.hitstun_timer = 0.0
		combat.knockback_velocity = Vector2.ZERO
	combat.knockback_timer = 0.0
	combat.timer = 0.0
	combat.frame = 0
	combat.hit_done = false
	combat.face_left = false
	combat.cooldown = attack_cooldown_delay
	combat.dead = false
	var flash_overlay := get_node_or_null("HitFlashOverlay") as Sprite2D
	if flash_overlay != null:
		flash_overlay.visible = false
	var tactics := get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		tactics.reset()


func _ensure_component(node_name: String, component_type: Variant) -> Node:
	var node := get_node_or_null(node_name)
	if node != null:
		return node
	node = component_type.new()
	node.name = node_name
	add_child(node)
	return node
