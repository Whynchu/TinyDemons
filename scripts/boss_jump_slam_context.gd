extends RefCounted
class_name BossJumpSlamContext

## Typed dependencies for BossJumpSlamComponent. The gameplay controller builds
## this from the runtime so the component stays blind (no root reach-ins).

## Diagnostic construction count. The performance harness resets and reads this
## to confirm the context is cached instead of rebuilt per slime per frame.
static var build_count := 0


func _init() -> void:
	build_count += 1


var player: Sprite2D = null
var rng: RandomNumberGenerator = null
var slime_tuning: SlimeTuning = null
var actor_collision_system: ActorCollisionSystem = null

var get_combat: Callable = Callable()
var is_aggroed: Callable = Callable()
var get_visual: Callable = Callable()
var set_actor_base_texture: Callable = Callable()
var restore_idle_texture: Callable = Callable()
var play_sound: Callable = Callable()
var begin_boss_jump_phase_popcorn: Callable = Callable()
var boss_jump_phase_popcorn_alive: Callable = Callable()
var clear_boss_jump_phase_popcorn: Callable = Callable()
var apply_boss_jump_slam: Callable = Callable()
var slime_shadow_anchor: Callable = Callable()
var actor_foot: Callable = Callable()
var nearest_slime_walkable_point: Callable = Callable()


func is_valid() -> bool:
	return slime_tuning != null and get_combat.is_valid() and get_visual.is_valid()