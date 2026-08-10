extends Sprite2D
class_name SlimeActor

@export_enum("blue", "green", "red") var variant := "green"
@export var tuning: SlimeTuning


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
	if is_aggroed.call(self):
		var brain := get_node_or_null("Brain") as SlimeBrain
		if brain != null: brain.target = aggro_target.call(self)
		update_scoot.call(self, delta)
		return
	var brain := get_node_or_null("Brain") as SlimeBrain
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
	var component := get_node_or_null(node_name)
	if component != null:
		return component
	component = component_type.new()
	component.name = node_name
	add_child(component)
	return component
