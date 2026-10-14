@tool
extends Sprite2D
class_name EnemyActor

const BaseElementCatalogScript = preload("res://scripts/content/element_catalog.gd")
const BaseEnemyChromaComponentScript = preload("res://scripts/components/enemy_chroma_component.gd")
const BaseSlimeSpawnComponentScript = preload("res://scripts/components/slime_spawn_component.gd")

## Content ids come from EnemyDefinition resources. Keep this as a string
## rather than an editor enum so new authored variants do not require a script
## edit before the factory can materialize them.
@export var variant := "green"
var combat_element: int = BaseElementCatalogScript.Element.GRASS
var _brain_component: EnemyBrain
var _combat_component: SlimeCombatComponent
var _status_component: StatusComponent
var _health_presentation_component: Node
var _aura_component: ElementAuraComponent
var _tactics_component: EnemyTacticsComponent
var _visual_component: SlimeVisualComponent
var _ambush_component: SlimeAmbushComponent
var _spawn_component: BaseSlimeSpawnComponentScript
var _support_component: Node
var _component_cache_ready := false



@export var enemy_definition_id: StringName = &""
@export var enemy_variant_id: StringName = &""
@export var enemy_type_id: StringName = &""
var roster_slot_id: StringName = &""
var _health_component: HealthComponent

static func component(actor: Sprite2D, node_name: String, component_type: Variant) -> Node:
	var node := actor.get_node_or_null(node_name)
	if node != null:
		return node
	node = component_type.new()
	node.name = node_name
	actor.add_child(node)
	return node


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	ensure_components()


func ensure_components() -> void:
	var health := _ensure_component("Health", HealthComponent) as HealthComponent
	_ensure_component("EnemyChroma", BaseEnemyChromaComponentScript)
	var combat := _ensure_component("Combat", SlimeCombatComponent) as SlimeCombatComponent
	var status_component := _ensure_component("Status", StatusComponent) as StatusComponent
	status_component.health_component = health
	status_component.set_movement_lock_resistance_check(Callable(combat, "movement_lock_is_resisted"))
	var aura := _ensure_component("ElementAura", ElementAuraComponent) as ElementAuraComponent
	aura.configure(self, get_parent() as Node2D, status_component)
	_ensure_component("Brain", EnemyBrain)
	_ensure_component("BossJumpSlam", load("res://scripts/components/boss_jump_slam_component.gd"))
	_ensure_component("Tactics", EnemyTacticsComponent)
	_ensure_component("Animation", SlimeAnimationComponent)
	_ensure_component("Visual", SlimeVisualComponent)
	_ensure_component("Spawn", BaseSlimeSpawnComponentScript)
	_ensure_component("HealthPresenter", SlimeHealthPresenter)
	install_brain_behavior_component(brain_behavior_component_script())
	_refresh_component_refs()


func brain_behavior_component_script() -> Script:
	return null


func _refresh_component_refs() -> void:
	_health_component = get_node_or_null("Health") as HealthComponent
	_health_presentation_component = get_node_or_null("HealthPresenter")
	_brain_component = get_node_or_null("Brain") as EnemyBrain
	_combat_component = get_node_or_null("Combat") as SlimeCombatComponent
	_status_component = get_node_or_null("Status") as StatusComponent
	_aura_component = get_node_or_null("ElementAura") as ElementAuraComponent
	_tactics_component = get_node_or_null("Tactics") as EnemyTacticsComponent
	_visual_component = get_node_or_null("Visual") as SlimeVisualComponent
	_ambush_component = get_node_or_null("Ambush") as SlimeAmbushComponent
	_spawn_component = get_node_or_null("Spawn") as BaseSlimeSpawnComponentScript
	_support_component = get_node_or_null("Support")
	if _brain_component != null:
		_brain_component.status_component = _status_component
		_brain_component.behavior_component = _brain_component.get_node_or_null("FamilyBehavior") as EnemyBrainBehaviorComponent
	_component_cache_ready = true


func _on_component_child_entered(_child: Node) -> void:
	if _component_cache_ready:
		_refresh_component_refs()


func _on_component_child_exiting(_child: Node) -> void:
	if _component_cache_ready:
		call_deferred("_refresh_component_refs")


func install_brain_behavior_component(component_script: Script) -> void:
	var brain := get_node_or_null("Brain") as EnemyBrain
	if brain == null or component_script == null:
		return
	var previous := brain.get_node_or_null("FamilyBehavior")
	if previous != null and previous.get_script() == component_script:
		brain.behavior_component = previous as EnemyBrainBehaviorComponent
		return
	if previous != null:
		brain.remove_child(previous)
		previous.queue_free()
	var component := component_script.new() as EnemyBrainBehaviorComponent
	if component == null:
		push_error("Enemy brain behavior script must extend EnemyBrainBehaviorComponent.")
		return
	component.name = "FamilyBehavior"
	brain.add_child(component)
	brain.behavior_component = component


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


func health_capability() -> HealthComponent:
	if not _component_cache_ready:
		_refresh_component_refs()
	return _health_component


func displayed_health_value() -> float:
	if not _component_cache_ready:
		_refresh_component_refs()
	if _health_presentation_component != null and _health_presentation_component.has_method("displayed_value"):
		return float(_health_presentation_component.call("displayed_value"))
	var health := _health_component
	return health.current_health if health != null else 0.0


func status_capability() -> StatusComponent:
	if not _component_cache_ready:
		_refresh_component_refs()
	return _status_component


func is_dead() -> bool:
	var health := health_capability()
	if health != null:
		return health.is_dead()
	if not _component_cache_ready:
		_refresh_component_refs()
	return _combat_component != null and _combat_component.dead


## Combat lifecycle state is authoritative for active enemy behavior. Keep the
## legacy combat component lookup behind this generic actor capability.
func is_defeated() -> bool:
	if not _component_cache_ready:
		_refresh_component_refs()
	return _combat_component != null and _combat_component.dead


func tick_components(delta: float) -> void:
	if not _component_cache_ready:
		_refresh_component_refs()
	if _brain_component != null:
		_brain_component.tick(delta)
	if _combat_component != null:
		_combat_component.tick(delta)
	if _tactics_component != null:
		_tactics_component.tick(delta)
	if _ambush_component != null:
		_ambush_component.tick(self, delta)


func spawn_component() -> BaseSlimeSpawnComponentScript:
	if not _component_cache_ready:
		_refresh_component_refs()
	return _spawn_component


func begin_spawn(spawn_frames: Array[Texture2D], frame_time: float) -> void:
	if not _component_cache_ready:
		_refresh_component_refs()
	var spawn := _spawn_component
	if spawn == null:
		spawn = _ensure_component("Spawn", BaseSlimeSpawnComponentScript) as BaseSlimeSpawnComponentScript
		_spawn_component = spawn
	if spawn != null:
		spawn.begin(spawn_frames, frame_time)


func tick_spawn(delta: float, _set_frame: Callable, finish: Callable) -> bool:
	if not _component_cache_ready:
		_refresh_component_refs()
	var spawn := _spawn_component
	return spawn != null and spawn.tick(delta, _set_frame, finish)


func cancel_spawn() -> void:
	if not _component_cache_ready:
		_refresh_component_refs()
	var spawn := _spawn_component
	if spawn != null:
		spawn.cancel()


func is_spawn_locked() -> bool:
	if not _component_cache_ready:
		_refresh_component_refs()
	var spawn := _spawn_component
	return spawn != null and spawn.is_active()


func tick_runtime(delta: float, update_knockback: Callable, update_attack: Callable, is_aggroed: Callable, update_scoot: Callable, allow_movement: bool = true, update_scoot_aggro: Callable = Callable(), capture_service: Node = null) -> void:
	if not _component_cache_ready:
		_refresh_component_refs()
	var combat := _combat_component
	if combat == null or is_defeated() or is_spawn_locked():
		return
	var status := _status_component
	var movement_locked: bool = status != null and status.is_movement_locked()
	var action_delta := _action_delta(delta)
	combat.cooldown = maxf(combat.cooldown - action_delta, 0.0)
	if movement_locked:
		var locked_brain := _brain_component
		if locked_brain != null:
			locked_brain.scoot_timer = 0.0
			locked_brain.scoot_start = position
			locked_brain.scoot_target = position
		# Reset active locomotion/squash presentation without advancing or moving.
		update_scoot.call(self, 0.0)
	if combat.status_stun_timer > 0.0:
		combat.status_stun_timer = maxf(combat.status_stun_timer - delta, 0.0)
		combat.hitstun_timer = maxf(combat.hitstun_timer - delta, 0.0)
		return
	var capture_enabled := capture_service != null
	var callback_started_usec := Time.get_ticks_usec() if capture_enabled else 0
	var was_knocked_back: bool = update_knockback.call(self, delta)
	if capture_enabled: capture_service.call("record_scope", &"enemy_actor_knockback_callback", Time.get_ticks_usec() - callback_started_usec)
	if was_knocked_back:
		var support := _support_component
		if support != null:
			support.call("cancel_cast", &"knockback")
		return
	if status != null and status.is_attack_locked():
		return
	combat.hitstun_timer = maxf(combat.hitstun_timer - delta, 0.0)
	if combat.hitstun_timer > 0.0:
		return
	callback_started_usec = Time.get_ticks_usec() if capture_enabled else 0
	var attack_started: bool = update_attack.call(self, action_delta)
	if capture_enabled: capture_service.call("record_scope", &"enemy_actor_attack_callback", Time.get_ticks_usec() - callback_started_usec)
	if attack_started:
		return
	if movement_locked:
		return
	# Frozen actors retain their combat timers but do not integrate movement.
	if not allow_movement:
		return
	var brain := _brain_component
	var aggroed := bool(is_aggroed.call(self))
	if aggroed:
		if brain != null and brain.repath_timer <= 0.0:
			brain.repath_timer = 0.08
	if update_scoot_aggro.is_valid():
		update_scoot_aggro.call(self, delta, aggroed)
	else:
		update_scoot.call(self, delta)


func _action_delta(delta: float) -> float:
	var multiplier := _status_component.attack_speed_multiplier() if _status_component != null else 1.0
	return maxf(delta, 0.0) * clampf(multiplier, 0.05, 1.0)


func reset_runtime_state(start_pos: Vector2, initial_target: Vector2, repath_delay: float, hold_delay: float, idle_breath_delay: float, attack_cooldown_delay: float) -> void:
	cancel_spawn()
	var brain := get_node_or_null("Brain") as EnemyBrain
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
		brain.notice_stagger_pending = false
		brain.notice_stagger_timer = 0.0
		brain.orbit_direction = 0.0
		brain.attack_cooldown = 0.0
		brain.blocked_repath_cooldown = 0.0
	var combat := get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null:
		combat.active = false
		combat.flash_timer = 0.0
		combat.hitstun_timer = 0.0
		combat.status_stun_timer = 0.0
		combat.knockback_velocity = Vector2.ZERO
	var statuses := get_node_or_null("Status") as StatusComponent
	if statuses != null:
		statuses.reset_for_spawn()
	set_meta("status_spawn_generation", int(get_meta("status_spawn_generation", 0)) + 1)
	var enemy_chroma := get_node_or_null("EnemyChroma")
	if enemy_chroma != null:
		enemy_chroma.call("reset_pool")
	var aura := get_node_or_null("ElementAura") as ElementAuraComponent
	if aura != null:
		aura.clear_status_visuals()
	combat.knockback_timer = 0.0
	combat.timer = 0.0
	combat.frame = 0
	combat.hit_done = false
	combat.face_left = false
	combat.lunge_remaining = 0.0
	combat.lunge_total = 0.0
	combat.lunge_progress = 0.0
	combat.lunge_applied_progress = 0.0
	combat.lunge_vector = Vector2.ZERO
	combat.attack_target_point = Vector2.ZERO
	combat.attack_lunge_vector = Vector2.ZERO
	combat.attack_committed = false
	combat.cooldown = attack_cooldown_delay
	combat.dead = false
	var flash_overlay := get_node_or_null("HitFlashOverlay") as Sprite2D
	if flash_overlay != null:
		flash_overlay.visible = false
	var tactics := get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		tactics.reset()
	var boss_jump_slam := get_node_or_null("BossJumpSlam") as BossJumpSlamComponent
	if boss_jump_slam != null:
		boss_jump_slam.state = BossJumpSlamComponent.State.READY
		boss_jump_slam.cooldown = boss_jump_slam.initial_cooldown_seconds
		boss_jump_slam.elapsed = 0.0
		boss_jump_slam.frame = -1
		boss_jump_slam.launch_committed = false
		boss_jump_slam.impact_resolved = false
		boss_jump_slam.completed_phases = 0
		boss_jump_slam.presentation_offset = Vector2.ZERO
		set_meta("boss_airborne", false)
		self_modulate.a = 1.0
	var support := get_node_or_null("Support") as Node
	if support != null:
		support.call("reset")


func _ensure_component(node_name: String, component_type: Variant) -> Node:
	var node := get_node_or_null(node_name)
	if node != null:
		return node
	node = component_type.new()
	node.name = node_name
	add_child(node)
	return node
