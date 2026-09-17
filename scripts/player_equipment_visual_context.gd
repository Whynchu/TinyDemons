extends RefCounted
class_name PlayerEquipmentVisualContext

## Typed dependencies for PlayerEquipmentVisualComponent. The gameplay
## controller builds this from the runtime so the component stays blind (no
## root reach-ins). Shared player-state reads cross as callables so the owner
## keeps authority over that state.

var player: Sprite2D = null
var rest_fire: Sprite2D = null
var cloaked_demon: Sprite2D = null
var screen_state_controller: Node = null
var sprite_frame_library: SpriteFrameLibrary = null
var occlusion_renderer: OcclusionRenderer = null
var effects_spawner: EffectsSpawner = null
var rng: RandomNumberGenerator = null
var player_equipment: EquipmentComponent = null
var player_guard_component: PlayerGuardComponent = null
var combat_tuning: CombatTuning = null
var player_tuning: PlayerTuning = null

var actor_sprites: Array[Sprite2D] = []
var occluder_sprites: Array = []

var player_is_attacking_get: Callable = Callable()
var player_is_magic_casting_get: Callable = Callable()
var player_is_defending_get: Callable = Callable()
var player_is_rolling_get: Callable = Callable()
var player_is_backflipping_get: Callable = Callable()
var player_anim_name_get: Callable = Callable()
var player_anim_frame_get: Callable = Callable()
var player_between_timer_get: Callable = Callable()
var player_death_timer_get: Callable = Callable()
var player_death_particles_started_get: Callable = Callable()
var player_attack_flip_h_get: Callable = Callable()
var player_magic_flip_h_get: Callable = Callable()

var player_stat_snapshot: Callable = Callable()
var equipment_occlusion_depth_key: Callable = Callable()
var sprite_source_global_rect: Callable = Callable()
var pixel_particle_texture: Callable = Callable()
var is_target_input_held: Callable = Callable()
var valid_current_target: Callable = Callable()
var target_facing_left: Callable = Callable()
var actor_screen_scale: Callable = Callable()
var actor_visual_offset: Callable = Callable()


func is_valid() -> bool:
	return player != null and sprite_frame_library != null