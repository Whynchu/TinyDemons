extends Node
class_name MagicProjectileController

## Owns active projectile records. Movement, collision, and effects remain
## callback-driven while gameplay migrates off coordinator-held arrays.

var projectiles: Array[Dictionary] = []


func spawn(sprite: Sprite2D, outline: Sprite2D, direction: Vector2, lifetime: float, palette: String, target: Sprite2D = null, ability_mode: int = 0) -> void:
	projectiles.append({"sprite": sprite, "outline": outline, "direction": direction, "timer": lifetime, "hit": false, "palette": palette, "target": target, "ability_mode": ability_mode})


func remove(index: int) -> void:
	if index >= 0 and index < projectiles.size():
		projectiles.remove_at(index)


func clear() -> void:
	for data in projectiles:
		var sprite := data.get("sprite") as Sprite2D
		var outline := data.get("outline") as Sprite2D
		if sprite != null and is_instance_valid(sprite): sprite.queue_free()
		if outline != null and is_instance_valid(outline): outline.queue_free()
	projectiles.clear()


func tick(delta: float, speed: float, snap_position: Callable, target_point: Callable, is_targetable: Callable, hit_query: Callable, hit_resolve: Callable, trail: Callable) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var data: Dictionary = projectiles[index]
		var sprite := data.get("sprite") as Sprite2D
		var outline := data.get("outline") as Sprite2D
		var timer := float(data.get("timer", 0.0)) - delta
		if sprite == null or not is_instance_valid(sprite) or timer <= 0.0:
			if sprite != null and is_instance_valid(sprite): sprite.queue_free()
			if outline != null and is_instance_valid(outline): outline.queue_free()
			remove(index)
			continue
		var direction := data.get("direction") as Vector2
		var homing := data.get("target") as Sprite2D
		if homing != null and is_instance_valid(homing) and bool(is_targetable.call(homing)):
			var to_target: Vector2 = target_point.call(homing) - sprite.global_position
			if to_target.dot(direction) < 0.0:
				data["target"] = null
				homing = null
			elif to_target.length_squared() > 0.0001:
				direction = direction.lerp(to_target.normalized(), 0.10).normalized()
				data["direction"] = direction
		sprite.position = snap_position.call(sprite.position + direction * speed * delta)
		if outline != null: outline.position = sprite.position
		if not bool(data.get("hit", false)):
			var target := hit_query.call(sprite) as Sprite2D
			if target != null:
				hit_resolve.call(target, sprite.global_position, String(data.get("palette", "grey")), int(data.get("ability_mode", 0)))
				if sprite != null and is_instance_valid(sprite): sprite.queue_free()
				if outline != null and is_instance_valid(outline): outline.queue_free()
				remove(index)
				continue
		trail.call(sprite.global_position, String(data.get("palette", "grey")))
		data["timer"] = timer
		projectiles[index] = data
