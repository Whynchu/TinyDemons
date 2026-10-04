extends RefCounted
class_name PlayerRollContext

## Typed dependencies for PlayerRollComponent. The gameplay controller builds
## this from the runtime so the component stays blind (no root reach-ins).

var player: Sprite2D = null
var player_motor: ActorMotor = null
var player_animation_component: PlayerAnimationComponent = null
var player_attack_visual: Sprite2D = null
var run_state: RunState = null
var player_tuning: PlayerTuning = null

var player_agi_get: Callable = Callable()
var player_spd_get: Callable = Callable()
var player_is_targeting_get: Callable = Callable()
var player_is_rolling_get: Callable = Callable()
var player_is_backflipping_get: Callable = Callable()
var player_is_rolling_set: Callable = Callable()
var player_is_backflipping_set: Callable = Callable()
var player_facing_left_before_target_get: Callable = Callable()
var last_player_facing_left_set: Callable = Callable()
var roll_dust_spawned_this_roll_get: Callable = Callable()
var roll_dust_spawned_this_roll_set: Callable = Callable()
var player_anim_name_set: Callable = Callable()
var apply_animation_frame: Callable = Callable()
var movement_anim_name: Callable = Callable()
var update_motor_facing: Callable = Callable()

var movement_input: Callable = Callable()
var player_facing_vector: Callable = Callable()
var perspective_movement: Callable = Callable()
var try_move_actor: Callable = Callable()
var actor_foot: Callable = Callable()
var valid_current_target: Callable = Callable()
var is_run_combat_active: Callable = Callable()
var play_sound: Callable = Callable()
var start_roll_dust: Callable = Callable()


func is_valid() -> bool:
	return player != null and player_tuning != null and movement_input.is_valid()