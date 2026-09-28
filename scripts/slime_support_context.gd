extends RefCounted
class_name SlimeSupportContext

## Typed runtime dependencies shared by support-caster slimes and their effects.

var world_root: Node2D
var player: Sprite2D
var slimes: Array[Sprite2D] = []
var slime_tuning: SlimeTuning
var rng: RandomNumberGenerator
var effects_spawner: Node
var player_guard_component: PlayerGuardComponent
var occlusion_renderer: OcclusionRenderer
var overworld_ui_z := 0
var depth_z_scale := 1.0

var actor_foot: Callable = Callable()
var is_dead: Callable = Callable()
var is_aggroed: Callable = Callable()
var magic_target_point: Callable = Callable()
var pixel_particle_texture: Callable = Callable()
var snap_half_pixel: Callable = Callable()
var set_animation_frame: Callable = Callable()
var play_healing_sound: Callable = Callable()
var restore_idle_texture: Callable = Callable()


func is_valid() -> bool:
	return world_root != null and slime_tuning != null and effects_spawner != null and actor_foot.is_valid() and is_dead.is_valid() and snap_half_pixel.is_valid()
