extends RefCounted
class_name RoomEnemySpawnServices


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
var player: Sprite2D = null
var chest: Sprite2D = null
var actor_runtime: EnemyActorRuntimeServices = EnemyActorRuntimeServices.new()
var collision_rect: Callable = Callable()
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


func is_valid() -> bool:
	return slime_tuning != null and rng != null and actor_runtime != null and actor_runtime.enemy_roster != null


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


func configure_slime_variant(slime: Sprite2D, variant: String) -> void:
	var definition := EnemyFactory.definition(StringName(variant))
	if definition == null:
		return
	slime = actor_runtime.replace_actor_family(slime, definition)
	if slime == null:
		return
	var palette := String(definition.variant_id)
	slime.set("variant", palette)
	slime.set_meta("element", definition.element)
	slime.set_meta("damage_contract", String(definition.damage_contract))
	slime.set_meta("visual_source", definition.visual_source)
	var actor := slime as EnemyActor
	if actor != null:
		EnemyFactory.configure_actor(actor, definition)
	var stats := slime.get_node_or_null("Stats") as StatsComponent
	if stats != null and actor == null:
		stats.apply_enemy_variant_profile(definition.base_stats, definition.growth_weights, definition.variant_id)
	configure_slime_ambush(slime, false)
	if clear_enemy_max_health_cache.is_valid():
		clear_enemy_max_health_cache.call()

func configure_slime_ambush(slime: Sprite2D, enabled: bool) -> void:
	var ambush := slime.get_node_or_null("Ambush") as SlimeAmbushComponent
	if enabled:
		if ambush == null:
			ambush = SlimeAmbushComponent.new()
			ambush.name = "Ambush"
			slime.add_child(ambush)
		ambush.configure(true, slime_tuning.ambush_reveal_window, slime_tuning.ambush_block_stun, slime_tuning.ambush_hit_extension)
		ambush.apply_hidden(slime)
	else:
		if ambush != null:
			ambush.configure(false, 0.0, 0.0, 0.0)
		slime.self_modulate = Color.WHITE
		slime.modulate = Color.WHITE
