extends RefCounted
class_name RoomEnemyRuntimeContext

## Typed snapshot input for the enemy runtime state of one room.

var room_id: StringName = &""
var active_variants: Array = []
var slimes: Array[Sprite2D] = []
var combat_components: Array[SlimeCombatComponent] = []
var health_components: Array[HealthComponent] = []


func _init(
	new_room_id: StringName,
	new_active_variants: Array,
	new_slimes: Array[Sprite2D],
	new_combat_components: Array[SlimeCombatComponent],
	new_health_components: Array[HealthComponent]
) -> void:
	room_id = new_room_id
	active_variants = new_active_variants
	slimes = new_slimes
	combat_components = new_combat_components
	health_components = new_health_components


func is_valid() -> bool:
	return not room_id.is_empty()
