extends RefCounted
class_name RoomEnemySpawnServices

const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")

## Explicit services used by room enemy spawn/respawn workflows.
##
## The context owns room-specific data; this object owns the small set of
## cross-feature operations that the composition root wires at boot. It never
## stores the gameplay state root itself.

var slime_tuning: SlimeTuning = null
var rng: RandomNumberGenerator = null
var player_profile: PlayerProfile = null
var run_state: RunState = null
var walkable_area: WalkableArea = null
var dungeon_graph: DungeonGraph = null
var dungeon_map_controller: DungeonMapController = null
var effects_spawner: EffectsSpawner = null
var hud_controller: HudController = null
var player: Sprite2D = null
var chest: Sprite2D = null
var slimes: Array[Sprite2D] = []
var collision_rect: Callable = Callable()
var actor_sprites: Array[Sprite2D] = []
var collision_sprites: Array[Sprite2D] = []
var depth_sprites: Array[Sprite2D] = []
var occluder_sprites: Array[Sprite2D] = []
var last_valid_positions: Dictionary = {}
var actor_foot_offset := Vector2.ZERO

var set_actor_visual_scale: Callable = Callable()
var apply_actor_scale: Callable = Callable()
var apply_enemy_room_level: Callable = Callable()
var enemy_max_health: Callable = Callable()
var prepare_slime_idle_visual: Callable = Callable()
var begin_slime_spawn: Callable = Callable()
var build_slime_direction_textures: Callable = Callable()
var assign_slime_attack_frames: Callable = Callable()
var assign_slime_shocked_frames: Callable = Callable()
var assign_slime_spawn_frames: Callable = Callable()
var prepare_boss_jump_phase_pool: Callable = Callable()
var trigger_slime_notice: Callable = Callable()
var play_sound: Callable = Callable()
var set_door_active: Callable = Callable()
var set_entrance_open: Callable = Callable()
var build_depth_lists: Callable = Callable()
var clear_enemy_max_health_cache: Callable = Callable()
var enemy_health_damaged_callback: Callable = Callable()
var enemy_health_healed_callback: Callable = Callable()
var enemy_health_changed_callback: Callable = Callable()


func is_valid() -> bool:
	return slime_tuning != null and rng != null


func prepare_enemy_visuals_direct() -> void:
	for callback in [build_slime_direction_textures, assign_slime_attack_frames, assign_slime_shocked_frames, assign_slime_spawn_frames]:
		if callback.is_valid():
			callback.call()


func actor_foot(actor: Sprite2D) -> Vector2:
	return ActorGeometry.foot(actor, actor_foot_offset)


func current_chest_rect() -> Rect2:
	if chest == null or not collision_rect.is_valid():
		return Rect2()
	return collision_rect.call(chest) as Rect2


func slime_brain(slime: Sprite2D) -> SlimeBrain:
	return SlimeActor.component(slime, "Brain", SlimeBrain) as SlimeBrain


func slime_combat(slime: Sprite2D) -> SlimeCombatComponent:
	return SlimeActor.component(slime, "Combat", SlimeCombatComponent) as SlimeCombatComponent


func slime_health(slime: Sprite2D) -> HealthComponent:
	return slime.get_node_or_null("Health") as HealthComponent


func slime_health_presenter(slime: Sprite2D) -> SlimeHealthPresenter:
	return SlimeActor.component(slime, "HealthPresenter", SlimeHealthPresenter) as SlimeHealthPresenter


func is_slime_dead(slime: Sprite2D) -> bool:
	var combat := slime_combat(slime)
	return combat != null and combat.dead


func slime_spawn(slime: Sprite2D) -> Node:
	if slime == null or not is_instance_valid(slime):
		return null
	var actor := slime as SlimeActor
	if actor != null:
		return actor.get_node_or_null("Spawn") as Node
	return SlimeActor.component(slime, "Spawn", load("res://scripts/slime_spawn_component.gd")) as Node


func is_slime_spawn_locked(slime: Sprite2D) -> bool:
	var spawn := slime_spawn(slime)
	return spawn != null and bool(spawn.call("is_active"))


func configure_slime_variant(slime: Sprite2D, variant: String) -> void:
	var definition := EnemyFactory.definition(StringName(variant))
	if definition == null:
		return
	slime = _replace_actor_family_for_definition(slime, definition)
	if slime == null:
		return
	var palette := String(definition.variant_id)
	slime.set("variant", palette)
	slime.set_meta("element", definition.element)
	slime.set_meta("damage_contract", String(definition.damage_contract))
	slime.set_meta("visual_source", definition.visual_source)
	var actor := slime as SlimeActor
	if actor != null:
		EnemyFactory.configure_actor(actor, definition)
	var stats := slime.get_node_or_null("Stats") as StatsComponent
	if stats != null and actor == null:
		stats.apply_enemy_variant_profile(definition.base_stats, definition.growth_weights, definition.variant_id)
	configure_slime_ambush(slime, false)
	if clear_enemy_max_health_cache.is_valid():
		clear_enemy_max_health_cache.call()


func _replace_actor_family_for_definition(current_actor: Sprite2D, definition: EnemyDefinition) -> Sprite2D:
	if current_actor == null or definition == null:
		return current_actor
	var current_slime := current_actor as SlimeActor
	if current_slime == null:
		push_error("Enemy roster slot '%s' is not a SlimeActor." % current_actor.name)
		return null
	var needs_skeleton_actor := definition.type_id == &"skeleton"
	if (current_slime is SkeletonActor) == needs_skeleton_actor:
		return current_actor
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
	replacement.scale = current_actor.scale
	replacement.skew = current_actor.skew
	replacement.modulate = current_actor.modulate
	replacement.self_modulate = current_actor.self_modulate
	replacement.visible = false
	replacement.z_index = current_actor.z_index
	replacement.z_as_relative = current_actor.z_as_relative
	var old_sibling_index := current_actor.get_index()
	parent.add_child(replacement)
	parent.move_child(replacement, old_sibling_index)
	if slime_tuning != null:
		replacement.tuning = slime_tuning
	_transfer_enemy_hud_children(current_actor, replacement)
	_replace_actor_reference(slimes, current_actor, replacement)
	_replace_actor_reference(actor_sprites, current_actor, replacement)
	_replace_actor_reference(collision_sprites, current_actor, replacement)
	_replace_actor_reference(depth_sprites, current_actor, replacement)
	_replace_actor_reference(occluder_sprites, current_actor, replacement)
	if last_valid_positions.has(current_actor):
		last_valid_positions[replacement] = last_valid_positions[current_actor]
		last_valid_positions.erase(current_actor)
	if hud_controller != null:
		hud_controller.rebind_enemy_actor(current_actor, replacement)
	_bind_enemy_health_signals(replacement)
	current_actor.queue_free()
	return replacement


func _transfer_enemy_hud_children(old_actor: Sprite2D, new_actor: Sprite2D) -> void:
	for child_name in ["HpOverhead", "HpOverheadFill", "HpOverheadDamageFill", "AggroMarker", "EliteOverheadSymbol"]:
		var child := old_actor.get_node_or_null(child_name)
		if child != null:
			old_actor.remove_child(child)
			new_actor.add_child(child)


func _bind_enemy_health_signals(actor: SlimeActor) -> void:
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


func configure_slime_ambush(slime: Sprite2D, enabled: bool) -> void:
	var ambush := slime.get_node_or_null("Ambush") as SlimeAmbushComponent
	if enabled:
		if ambush == null:
			ambush = SlimeAmbushComponent.new()
			ambush.name = "Ambush"
			slime.add_child(ambush)
		ambush.configure(true, slime_tuning.ambush_reveal_window, slime_tuning.ambush_block_stun, slime_tuning.ambush_hit_extension)
		ambush.apply_hidden(slime)
	elif ambush != null:
		ambush.configure(false, 0.0, 0.0, 0.0)
		slime.self_modulate = Color.WHITE


func clear_slime_without_effects(slime: Sprite2D) -> void:
	if slime == null:
		return
	var combat := slime_combat(slime)
	if combat != null:
		combat.dead = true
		combat.active = false
		combat.timer = 0.0
		combat.frame = 0
		combat.hit_done = false
	slime.visible = false
	var spawn := slime_spawn(slime)
	if spawn != null:
		spawn.call("cancel")
	var brain := slime_brain(slime)
	if brain != null:
		brain.attack_cooldown = 0.0
		brain.aggroed = false
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		tactics.reset()
	collision_sprites.erase(slime)
	depth_sprites.erase(slime)
	occluder_sprites.erase(slime)
	actor_sprites.erase(slime)
	var health := slime_health(slime)
	if health != null:
		health.reset(0.0)
	var presenter := slime_health_presenter(slime)
	if presenter != null:
		presenter.display_health = 0.0
	if hud_controller == null:
		return
	for item in [hud_controller.target_overhead_frames.get(slime), hud_controller.target_overhead_damage_fills.get(slime), hud_controller.target_overhead_fills.get(slime)]:
		if item != null:
			(item as Sprite2D).visible = false


func restore_enemy_health(slime: Sprite2D, runtime_entry: Dictionary) -> void:
	var health := slime_health(slime)
	if health == null:
		return
	var maximum := health.maximum_health
	var current := clampf(float(runtime_entry.get("health", maximum)), 0.0, maximum)
	health.reset(current)
	var presenter := slime_health_presenter(slime)
	if presenter != null:
		presenter.display_health = current
		presenter.damage_fill_hold_timer = 0.0
