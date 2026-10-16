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
var sound_manager: SoundManager = null
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
var trigger_slime_notice: Callable = Callable()
var set_door_active: Callable = Callable()
var set_entrance_open: Callable = Callable()
var build_depth_lists: Callable = Callable()


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


func play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sound_manager == null:
		return
	sound_manager.play(sound_name, volume_db, pitch_scale)
