extends RefCounted
class_name InteractionContext

## Typed dependencies for InteractionComponent (targeting and world prompts).
## The gameplay controller builds this from the runtime so the component stays
## blind (no root reach-ins). Shared state reads/writes cross as callables so
## the owner keeps authority over that state.

var player: Sprite2D = null
var chest: Sprite2D = null
var cloaked_demon: Sprite2D = null
var npc_controller: NpcController = null
var interact_prompt: Sprite2D = null

var player_is_attacking_get: Callable = Callable()
var player_is_magic_casting_get: Callable = Callable()
var target_input_was_down_get: Callable = Callable()
var target_input_was_down_set: Callable = Callable()
var last_player_facing_left_get: Callable = Callable()
var last_player_facing_left_set: Callable = Callable()
var mouse_target_locked_get: Callable = Callable()
var mouse_target_locked_set: Callable = Callable()

var actor_foot: Callable = Callable()
var is_target_input_held: Callable = Callable()
var set_current_target: Callable = Callable()
var set_target_ui_visible: Callable = Callable()
var closest_target: Callable = Callable()
var valid_current_target: Callable = Callable()
var is_slime_targetable: Callable = Callable()
var target_cycle_direction: Callable = Callable()
var cycle_target: Callable = Callable()
var update_target_ui: Callable = Callable()
var player_facing_vector: Callable = Callable()
var mouse_aim_active: Callable = Callable()
var mouse_aim_direction: Callable = Callable()
var can_interact_with_chest: Callable = Callable()
var can_interact_with_npc: Callable = Callable()
var can_interact_with_world_item: Callable = Callable()
var can_interact_with_fire: Callable = Callable()
var collision_rect: Callable = Callable()
var world_item_drop_position: Callable = Callable()
var cloaked_demon_head_position: Callable = Callable()
var fire_anchor: Callable = Callable()
var snap_half_pixel: Callable = Callable()


func is_valid() -> bool:
	return player != null and is_target_input_held.is_valid() and set_current_target.is_valid()
