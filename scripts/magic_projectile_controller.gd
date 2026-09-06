extends Node
class_name MagicProjectileController

## Owns active projectile records. Movement, collision, and effects remain
## callback-driven while gameplay migrates off coordinator-held arrays.

var projectiles: Array[Dictionary] = []


func spawn(sprite: Sprite2D, outline: Sprite2D, direction: Vector2, lifetime: float, palette: String, target: Sprite2D = null, ability_mode: int = 0) -> void:
	projectiles.append({"sprite": sprite, "outline": outline, "direction": direction, "timer": lifetime, "hit": false, "palette": palette, "target": target, "ability_mode": ability_mode})


func spawn_beam(sprite: Sprite2D, direction: Vector2, lifetime: float, palette: String, ability_mode: int) -> void:
	projectiles.append({"sprite": sprite, "outline": null, "direction": direction, "timer": lifetime, "hit": false, "palette": palette, "target": null, "ability_mode": ability_mode, "beam": true, "speed": 60.0, "beam_hit_counts": {}, "beam_hit_cooldowns": {}})


func remove(index: int) -> void:
	if index >= 0 and index < projectiles.size():
		projectiles.remove_at(index)


func clear() -> void:
	for data in projectiles:
		var sprite := _valid_sprite(data.get("sprite"))
		var outline := _valid_sprite(data.get("outline"))
		if sprite != null and is_instance_valid(sprite): sprite.queue_free()
		if outline != null and is_instance_valid(outline): outline.queue_free()
	projectiles.clear()


func tick(delta: float, speed: float, snap_position: Callable, target_point: Callable, is_targetable: Callable, hit_query: Callable, hit_resolve: Callable, trail: Callable) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var data: Dictionary = projectiles[index]
		# Do not cast a freed Object before checking it. Godot reports the cast
		# itself, so the old `as Sprite2D` followed by is_instance_valid() still
		# logged errors during scene transitions.
		var sprite := _valid_sprite(data.get("sprite"))
		var outline := _valid_sprite(data.get("outline"))
		var timer := float(data.get("timer", 0.0)) - delta
		if sprite == null or not is_instance_valid(sprite) or timer <= 0.0:
			if sprite != null and is_instance_valid(sprite): sprite.queue_free()
			if outline != null and is_instance_valid(outline): outline.queue_free()
			remove(index)
			continue
		var direction := data.get("direction") as Vector2
		if bool(data.get("beam", false)) and sprite.hframes > 1:
			var elapsed := maxf(float(data.get("initial_timer", timer)) - timer, 0.0)
			sprite.frame = mini(int(elapsed / 0.13), sprite.hframes - 1)
		var homing := _valid_sprite(data.get("target"))
		if homing != null and is_instance_valid(homing) and bool(is_targetable.call(homing)):
			var to_target: Vector2 = target_point.call(homing) - sprite.global_position
			if to_target.dot(direction) < 0.0:
				data["target"] = null
				homing = null
			elif to_target.length_squared() > 0.0001:
				direction = direction.lerp(to_target.normalized(), 0.10).normalized()
				data["direction"] = direction
		var travel_speed := float(data.get("speed", speed))
		sprite.position = snap_position.call(sprite.position + direction * travel_speed * delta)
		if outline != null: outline.position = sprite.position
		var is_beam := bool(data.get("beam", false))
		if is_beam:
			var beam_hit_cooldowns: Dictionary = data.get("beam_hit_cooldowns", {})
			for target_id in beam_hit_cooldowns.keys():
				beam_hit_cooldowns[target_id] = maxf(float(beam_hit_cooldowns[target_id]) - delta, 0.0)
			data["beam_hit_cooldowns"] = beam_hit_cooldowns
			var beam_hit_counts: Dictionary = data.get("beam_hit_counts", {})
			var targets: Array = hit_query.call(sprite, true)
			for target in targets:
				if not is_instance_valid(target):
					continue
				var target_id: int = target.get_instance_id()
				if int(beam_hit_counts.get(target_id, 0)) >= 3:
					continue
				if float(beam_hit_cooldowns.get(target_id, 0.0)) > 0.0:
					continue
				hit_resolve.call(target, sprite.global_position, String(data.get("palette", "grey")), int(data.get("ability_mode", 0)), true)
				beam_hit_counts[target_id] = int(beam_hit_counts.get(target_id, 0)) + 1
				beam_hit_cooldowns[target_id] = 0.12
			data["beam_hit_counts"] = beam_hit_counts
			data["beam_hit_cooldowns"] = beam_hit_cooldowns
		elif not bool(data.get("hit", false)):
			var target := hit_query.call(sprite, false) as Sprite2D
			if target != null:
				hit_resolve.call(target, sprite.global_position, String(data.get("palette", "grey")), int(data.get("ability_mode", 0)), false)
				if sprite != null and is_instance_valid(sprite): sprite.queue_free()
				if outline != null and is_instance_valid(outline): outline.queue_free()
				remove(index)
				continue
		if not bool(data.get("beam", false)):
			trail.call(sprite.global_position, String(data.get("palette", "grey")), false, false)
		data["timer"] = timer
		data["initial_timer"] = float(data.get("initial_timer", timer + delta))
		projectiles[index] = data


func _valid_sprite(value: Variant) -> Sprite2D:
	return value as Sprite2D if is_instance_valid(value) else null
