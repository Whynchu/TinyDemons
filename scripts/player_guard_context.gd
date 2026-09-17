extends RefCounted
class_name PlayerGuardContext

## Typed dependencies for PlayerGuardComponent. The gameplay controller builds
## this from the runtime so the component stays blind (no root reach-ins). The
## shared player-state reads/writes cross as callables so the owner keeps its
## authority over that state.

var ui_parent: Node = null
var player: Sprite2D = null
var equipment: EquipmentComponent = null
var visuals: PlayerEquipmentVisualComponent = null
var overworld_ui_z := 0

var is_defending_get: Callable = Callable()
var is_defending_set: Callable = Callable()
var player_dead_get: Callable = Callable()
var player_death_pending_get: Callable = Callable()
var player_is_attacking_get: Callable = Callable()
var player_is_rolling_get: Callable = Callable()
var player_is_backflipping_get: Callable = Callable()
var player_hitstun_timer_get: Callable = Callable()
var actor_foot: Callable = Callable()


func is_valid() -> bool:
	return ui_parent != null and player != null and is_defending_get.is_valid() and is_defending_set.is_valid()