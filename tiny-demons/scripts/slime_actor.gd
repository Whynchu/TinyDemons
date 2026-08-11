extends Sprite2D
class_name SlimeActor

@export_enum("blue", "green", "red") var variant := "green"
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
		if brain != null: brain.target = aggro_target.call(self)
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
			brain.target = aggro_target.call(actor)
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
	if bool(root.get("player_is_rolling")): return
	var player := root.get("player") as Sprite2D; var slime_config := root.get("slime_tuning") as SlimeTuning
	var delta: Vector2 = root.call("_actor_foot", player) - root.call("_actor_foot", slime); var ellipse := Vector2(delta.x / slime_config.attack_hit_range, delta.y / slime_config.attack_vertical_hit_range)
	if ellipse.length_squared() > 1.0: return
	var damage := float(root.call("_slime_attack_damage", slime)); root.call("_mark_player_in_combat")
	var health := root.get("player_health_component") as HealthComponent
	if health != null: health.apply_damage(damage); root.set("player_health", health.current_health)
	else: root.set("player_health", maxf(float(root.get("player_health")) - damage, 0.0))
	if bool(root.get("player_is_attacking")): root.call("_interrupt_player_attack")
	var player_tuning := root.get("player_tuning") as PlayerTuning; root.set("player_hit_flash_timer", player_tuning.hit_flash_time); root.set("player_hitstun_timer", player_tuning.hitstun_time); root.call("_apply_player_hit_knockback", slime); root.call("_spawn_player_damage_number", damage); root.call("_update_player_health_ui"); root.set("hitstop_timer", player_tuning.hitstop_duration)
	if float(root.get("player_health")) <= 0.0: root.set("player_death_pending", true); root.call("_interrupt_player_attack"); root.set("player_is_rolling", false)


func tick_health(delta: float) -> float:
	var health := get_node_or_null("Health") as HealthComponent
	if health == null:
		return 0.0
	var previous_health := health.current_health
	health.tick_regeneration(delta)
	return previous_health


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
		brain.blocked_repath_cooldown = 0.0
	var combat := get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null:
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


func _ensure_component(node_name: String, component_type: Variant) -> Node:
	var node := get_node_or_null(node_name)
	if node != null:
		return node
	node = component_type.new()
	node.name = node_name
	add_child(node)
	return node
