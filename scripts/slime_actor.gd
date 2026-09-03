extends Sprite2D
class_name SlimeActor

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

@export_enum("blue", "green", "red", "purple", "grey", "yellow", "orange", "aquamarine") var variant := "green"
@export var tuning: SlimeTuning
var combat_element: int = ElementCatalogScript.Element.GRASS


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
	_ensure_component("Spawn", load("res://scripts/slime_spawn_component.gd"))
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


func begin_spawn(spawn_frames: Array[Texture2D], frame_time: float) -> void:
	var spawn := get_node_or_null("Spawn") as Node
	if spawn == null:
		spawn = _ensure_component("Spawn", load("res://scripts/slime_spawn_component.gd"))
	spawn.call("begin", spawn_frames, frame_time)


func tick_spawn(delta: float, set_frame: Callable, finish: Callable) -> bool:
	var spawn := get_node_or_null("Spawn") as Node
	return spawn != null and bool(spawn.call("tick", delta, set_frame, finish))


func cancel_spawn() -> void:
	var spawn := get_node_or_null("Spawn") as Node
	if spawn != null:
		spawn.call("cancel")


func is_spawn_locked() -> bool:
	var spawn := get_node_or_null("Spawn") as Node
	return spawn != null and bool(spawn.call("is_active"))


func tick_runtime(delta: float, is_dead: Callable, update_knockback: Callable, update_attack: Callable, is_aggroed: Callable, aggro_target: Callable, update_scoot: Callable, allow_movement: bool = true) -> void:
	var combat := get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null or is_dead.call(self) or is_spawn_locked():
		return
	combat.cooldown = maxf(combat.cooldown - delta, 0.0)
	if update_knockback.call(self, delta):
		return
	combat.hitstun_timer = maxf(combat.hitstun_timer - delta, 0.0)
	if combat.hitstun_timer > 0.0:
		return
	if update_attack.call(self, delta):
		return
	# Movement is the expensive per-frame cost (walkability sampling). The frame
	# controller rotates a movement budget across the crowd, so a slime can be
	# asked to skip its scoot this frame while combat/knockback stay live.
	if not allow_movement:
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


static func tick_legacy_runtime(actor: Sprite2D, delta: float, is_dead: Callable, update_knockback: Callable, update_attack: Callable, is_aggroed: Callable, aggro_target: Callable, update_scoot: Callable, allow_movement: bool = true) -> void:
	var spawn := actor.get_node_or_null("Spawn") as Node
	if bool(is_dead.call(actor)) or (spawn != null and bool(spawn.call("is_active"))):
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
	if not allow_movement:
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


static func damage_actor(root: Object, slime: Sprite2D, amount: float, was_critical: bool, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false, show_damage_number := true) -> void:
	if bool(root.call("_is_slime_dead", slime)) or (root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", slime))): return
	root.call("_mark_player_in_combat")
	if immune:
		if show_damage_number:
			root.call("_spawn_damage_number", slime, 0.0, false, attack_element, true)
		return
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
	if root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", slime)):
		return
	var player := root.get("player") as Sprite2D
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if root.has_method("_play_sound"):
		root.call("_play_sound", "bite", -8.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
	var slime_body := root.call("_slime_body_polygon", slime) as PackedVector2Array
	var player_rect := (root.call("_collision_rect", player) as Rect2).grow(0.75)
	var player_body := PackedVector2Array([player_rect.position, Vector2(player_rect.end.x, player_rect.position.y), player_rect.end, Vector2(player_rect.position.x, player_rect.end.y)])
	if slime_body.size() < 3 or Geometry2D.intersect_polygons(slime_body, player_body).is_empty(): return
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
	var player_tuning := root.get("player_tuning") as PlayerTuning; root.set("player_hit_flash_timer", 0.0 if blocked else player_tuning.hit_flash_time); root.set("player_hitstun_timer", player_tuning.hitstun_time); root.call("_apply_player_hit_knockback", slime); if damage > 0.0: root.call("_spawn_player_damage_number", damage, damage_result.element if damage_result != null else ElementCatalogScript.Element.NEUTRAL, false); root.call("_update_player_health_ui"); root.set("hitstop_timer", player_tuning.hitstop_duration)
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
		# A Shadow Slime blocked mid-swing is stunned for a full second before it can
		# resume its routine, and it stays revealed (hittable) during the stun.
		var ambush := slime.get_node_or_null("Ambush") as SlimeAmbushComponent
		if ambush != null:
			ambush.begin_block_stun(slime)
			combat.hitstun_timer = maxf(combat.hitstun_timer, ambush.block_stun)
			combat.cooldown = maxf(combat.cooldown, ambush.block_stun)
	var player_health := root.get("player_health_component") as HealthComponent
	if player_health != null and player_health.current_health <= 0.0: root.set("player_death_pending", true); root.call("_interrupt_player_attack"); root.set("player_is_rolling", false)


func reset_runtime_state(start_pos: Vector2, initial_target: Vector2, repath_delay: float, hold_delay: float, idle_breath_delay: float, attack_cooldown_delay: float) -> void:
	cancel_spawn()
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
