extends RefCounted
class_name PlayerAnimationContext

## Typed dependencies for PlayerAnimationComponent. The gameplay controller
## builds this from the runtime so the component stays blind (no root or
## coordinator_root reach-ins).

var player: Sprite2D = null
var actor_root: Node = null
var sprite_frame_library: SpriteFrameLibrary = null
var occlusion_renderer: OcclusionRenderer = null
var hud_controller: Node = null
var player_attack_component: PlayerAttackComponent = null
var player_attack_visual: Sprite2D = null
var player_equipment_visual_component: Node = null
var player_tuning: PlayerTuning = null
var attack_frame_size := Vector2i(36, 36)

var current_player_palette_name_get: Callable = Callable()
var player_anim_name_get: Callable = Callable()
var player_anim_name_set: Callable = Callable()
var player_anim_frame_get: Callable = Callable()
var player_anim_frame_set: Callable = Callable()
var player_anim_timer_get: Callable = Callable()
var player_anim_timer_set: Callable = Callable()
var player_between_timer_get: Callable = Callable()
var player_between_timer_set: Callable = Callable()
var player_is_attacking_get: Callable = Callable()
var player_is_attacking_set: Callable = Callable()
var player_is_moving_get: Callable = Callable()
var player_is_running_get: Callable = Callable()
var player_is_rolling_get: Callable = Callable()
var player_is_backflipping_get: Callable = Callable()
var player_is_defending_get: Callable = Callable()
var player_is_magic_casting_get: Callable = Callable()
var player_agi_get: Callable = Callable()
var player_spd_get: Callable = Callable()
var player_attack_hit_done_get: Callable = Callable()
var player_attack_hit_done_set: Callable = Callable()
var player_just_finished_attack_set: Callable = Callable()
var player_attack_flip_h_get: Callable = Callable()
var player_magic_flip_h_get: Callable = Callable()
var player_roll_component_frame: Callable = Callable()
var orb_knockback_animation_lock_get: Callable = Callable()
var orb_knockback_animation_grace_get: Callable = Callable()
var orb_knockback_animation_grace_set: Callable = Callable()
var player_health_fill_get: Callable = Callable()
var player_health_damage_fill_get: Callable = Callable()
var roll_dust_frames_get: Callable = Callable()
var roll_dust_frames_set: Callable = Callable()
var roll_dust_flipped_frames_get: Callable = Callable()
var roll_dust_flipped_frames_set: Callable = Callable()

var apply_player_attack_hitbox: Callable = Callable()
var load_texture_or_null: Callable = Callable()
var on_player_walk_step: Callable = Callable()
var restore_actor_base_visual_scale: Callable = Callable()
var set_mp_grey_texture: Callable = Callable()
var set_actor_base_texture: Callable = Callable()
var equipment_visual_context: Callable = Callable()


func is_valid() -> bool:
	return player != null and sprite_frame_library != null