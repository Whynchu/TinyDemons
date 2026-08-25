extends Node
class_name SoulPickupController

## Owns Soul pickup instances and their transient launch state.

var sprites: Array[Sprite2D] = []
var values: Array[int] = []
var velocities: Array[Vector2] = []
var air_times: Array[float] = []


func add_pickup(sprite: Sprite2D, value: int, velocity: Vector2, air_time: float) -> void:
	sprites.append(sprite)
	values.append(maxi(value, 1))
	velocities.append(velocity)
	air_times.append(maxf(air_time, 0.0))


func remove(index: int) -> void:
	if index < 0 or index >= sprites.size():
		return
	var sprite := sprites[index]
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	sprites.remove_at(index)
	values.remove_at(index)
	velocities.remove_at(index)
	air_times.remove_at(index)


func clear() -> void:
	for sprite in sprites:
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	sprites.clear()
	values.clear()
	velocities.clear()
	air_times.clear()
