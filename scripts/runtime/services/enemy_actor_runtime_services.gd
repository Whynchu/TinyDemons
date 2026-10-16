extends RefCounted
class_name EnemyActorRuntimeServices

## Owns ordered enemy slots and enemy component/lifecycle work that updates
## runtime actor collections during replacement, reset, and health restoration.

var enemy_roster: EnemyRoster = EnemyRoster.new()
var actor_sprites: Array[Sprite2D] = []
var collision_sprites: Array[Sprite2D] = []
var depth_sprites: Array[Sprite2D] = []
var occluder_sprites: Array[Sprite2D] = []
var last_valid_positions: Dictionary = {}
var hud_controller: HudController = null
var occlusion_renderer: OcclusionRenderer = null
var enemy_health_damaged_callback: Callable = Callable()
var enemy_health_healed_callback: Callable = Callable()
var enemy_health_changed_callback: Callable = Callable()


func enemy_brain(actor: Sprite2D) -> EnemyBrain:
	return EnemyActor.component(actor, "Brain", EnemyBrain) as EnemyBrain


func slime_combat(actor: Sprite2D) -> SlimeCombatComponent:
	return EnemyActor.component(actor, "Combat", SlimeCombatComponent) as SlimeCombatComponent


func slime_health(actor: Sprite2D) -> HealthComponent:
	return actor.get_node_or_null("Health") as HealthComponent


func slime_health_presenter(actor: Sprite2D) -> SlimeHealthPresenter:
	return EnemyActor.component(actor, "HealthPresenter", SlimeHealthPresenter) as SlimeHealthPresenter


func is_slime_dead(actor: Sprite2D) -> bool:
	var combat := slime_combat(actor)
	return combat != null and combat.dead


func slime_spawn(actor: Sprite2D) -> Node:
	if actor == null or not is_instance_valid(actor):
		return null
	if actor is EnemyActor:
		return actor.get_node_or_null("Spawn") as Node
	return EnemyActor.component(actor, "Spawn", load("res://scripts/components/slime_spawn_component.gd")) as Node


func is_slime_spawn_locked(actor: Sprite2D) -> bool:
	var spawn := slime_spawn(actor)
	return spawn != null and bool(spawn.call("is_active"))


func replace_actor_family(current_actor: Sprite2D, definition: EnemyDefinition) -> Sprite2D:
	if current_actor == null or definition == null:
		return current_actor
	var current_enemy := current_actor as EnemyActor
	if current_enemy == null:
		push_error("Enemy roster slot '%s' is not an EnemyActor." % current_actor.name)
		return null
	var needs_skeleton_actor := definition.type_id == &"skeleton"
	if (current_enemy is SkeletonActor) == needs_skeleton_actor:
		return current_actor
	if enemy_roster == null:
		push_error("Enemy roster slot '%s' has no configured EnemyRoster owner." % current_actor.name)
		return null
	var parent := current_actor.get_parent()
	if parent == null:
		push_error("Cannot replace detached enemy roster slot '%s'." % current_actor.name)
		return null
	var replacement := EnemyFactory.assemble(definition)
	if replacement == null:
		return null
	replacement.name = current_actor.name
	replacement.position = current_actor.position
	replacement.rotation = current_actor.rotation
	# The previous family's scale can contain a slime squish or boss transform.
	# Keep the new actor's authored scale when a room slot changes family.
	replacement.skew = current_actor.skew
	# Room slots are reused across enemy families. Never carry a transient
	# ambush tint (including alpha 0.5) into the replacement actor.
	replacement.modulate = Color.WHITE
	replacement.self_modulate = Color.WHITE
	replacement.visible = false
	replacement.z_index = current_actor.z_index
	replacement.z_as_relative = current_actor.z_as_relative
	var old_sibling_index := current_actor.get_index()
	parent.add_child(replacement)
	parent.move_child(replacement, old_sibling_index)
	if enemy_roster.replace(current_actor, replacement) < 0:
		push_error("Enemy roster no longer contains replacement slot '%s'." % current_actor.name)
		replacement.queue_free()
		return null
	_transfer_enemy_hud_children(current_actor, replacement)
	_replace_actor_reference(actor_sprites, current_actor, replacement)
	_replace_actor_reference(collision_sprites, current_actor, replacement)
	_replace_actor_reference(depth_sprites, current_actor, replacement)
	_replace_actor_reference(occluder_sprites, current_actor, replacement)
	if occlusion_renderer != null:
		occlusion_renderer.rebind_actor(current_actor, replacement)
	if last_valid_positions.has(current_actor):
		last_valid_positions[replacement] = last_valid_positions[current_actor]
		last_valid_positions.erase(current_actor)
	if hud_controller != null:
		hud_controller.rebind_enemy_actor(current_actor, replacement)
	_bind_enemy_health_signals(replacement)
	current_actor.queue_free()
	return replacement


func remove_actor_from_runtime_lists(actor: Sprite2D) -> void:
	actor_sprites.erase(actor)
	collision_sprites.erase(actor)
	depth_sprites.erase(actor)
	occluder_sprites.erase(actor)


func add_actor_to_runtime_lists(actor: Sprite2D) -> void:
	if actor == null:
		return
	if not actor_sprites.has(actor):
		actor_sprites.append(actor)
	if not collision_sprites.has(actor):
		collision_sprites.append(actor)
	if not depth_sprites.has(actor):
		depth_sprites.append(actor)
	if not occluder_sprites.has(actor):
		occluder_sprites.append(actor)


func remove_actor_from_collision_list(actor: Sprite2D) -> void:
	collision_sprites.erase(actor)


func clear_enemy_without_effects(actor: Sprite2D) -> void:
	if actor == null:
		return
	var statuses := actor.get_node_or_null("Status") as StatusComponent
	if statuses != null:
		statuses.clear_all()
	var aura := actor.get_node_or_null("ElementAura") as ElementAuraComponent
	if aura != null:
		aura.clear_status_visuals()
	var combat := slime_combat(actor)
	if combat != null:
		combat.dead = true
		combat.active = false
		combat.timer = 0.0
		combat.frame = 0
		combat.hit_done = false
	actor.visible = false
	var spawn := slime_spawn(actor)
	if spawn != null:
		spawn.call("cancel")
	var brain := enemy_brain(actor)
	if brain != null:
		brain.attack_cooldown = 0.0
		brain.aggroed = false
	var tactics := actor.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		tactics.reset()
	remove_actor_from_runtime_lists(actor)
	var health := slime_health(actor)
	if health != null:
		health.reset(0.0)
	var presenter := slime_health_presenter(actor)
	if presenter != null:
		presenter.display_health = 0.0
	hide_target_overheads(actor)


func restore_enemy_health(actor: Sprite2D, runtime_entry: Dictionary) -> void:
	var health := slime_health(actor)
	if health == null:
		return
	var maximum := health.maximum_health
	var current := clampf(float(runtime_entry.get("health", maximum)), 0.0, maximum)
	health.reset(current)
	var enemy_chroma := actor.get_node_or_null("EnemyChroma")
	if enemy_chroma != null and bool(enemy_chroma.get("enabled")):
		enemy_chroma.call("restore_runtime_state", runtime_entry.get("chroma", {}) as Dictionary, current, maximum)
	var presenter := slime_health_presenter(actor)
	if presenter != null:
		presenter.display_health = current
		presenter.damage_fill_hold_timer = 0.0


func hide_target_overheads(actor: Sprite2D) -> void:
	if hud_controller == null:
		return
	for item in [hud_controller.target_overhead_frames.get(actor), hud_controller.target_overhead_damage_fills.get(actor), hud_controller.target_overhead_fills.get(actor)]:
		if item != null:
			(item as Sprite2D).visible = false


func _transfer_enemy_hud_children(old_actor: Sprite2D, new_actor: Sprite2D) -> void:
	for child_name in ["HpOverhead", "HpOverheadFill", "HpOverheadDamageFill", "AggroMarker", "EliteOverheadSymbol"]:
		var child := old_actor.get_node_or_null(child_name)
		if child != null:
			old_actor.remove_child(child)
			new_actor.add_child(child)


func _bind_enemy_health_signals(actor: EnemyActor) -> void:
	var health := actor.get_node_or_null("Health") as HealthComponent
	if health == null:
		return
	if enemy_health_damaged_callback.is_valid():
		health.damaged.connect(enemy_health_damaged_callback.bind(actor))
	if enemy_health_healed_callback.is_valid():
		health.healed.connect(enemy_health_healed_callback.bind(actor))
	if enemy_health_changed_callback.is_valid():
		health.health_changed.connect(enemy_health_changed_callback.bind(actor))


func _replace_actor_reference(actors_to_update: Array[Sprite2D], old_actor: Sprite2D, new_actor: Sprite2D) -> void:
	var actor_index := actors_to_update.find(old_actor)
	if actor_index >= 0:
		actors_to_update[actor_index] = new_actor
