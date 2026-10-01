extends Node
class_name MagicProjectileController

const SpellFormDefinitionScript = preload("res://scripts/spell_form_definition.gd")

## Owns active projectile records. Movement, collision, and effects remain
## callback-driven while gameplay migrates off coordinator-held arrays.

var projectiles: Array[Dictionary] = []


func spawn(
	sprite: Sprite2D,
	outline: Sprite2D,
	direction: Vector2,
	lifetime: float,
	palette: String,
	target: Sprite2D = null,
	ability_mode: int = 0,
	form: Resource = null,
	speed: float = 70.0
) -> void:
	var minimum_travel_time: float = float(form.get("projectile_minimum_travel_time")) if form != null else 0.0
	var orient_to_direction := form != null and int(form.get("projectile_shape")) == SpellFormDefinitionScript.ProjectileShape.DROPLET
	var bubble_pulse := form != null and int(form.get("projectile_shape")) == SpellFormDefinitionScript.ProjectileShape.BUBBLE
	projectiles.append({
		"sprite": sprite,
		"outline": outline,
		"direction": direction,
		"timer": lifetime,
		"travel_age": 0.0,
		"minimum_travel_time": maxf(minimum_travel_time, 0.0),
		"orient_to_direction": orient_to_direction,
		"bubble_pulse": bubble_pulse,
		"hit": false,
		"palette": palette,
		"target": target,
		"ability_mode": ability_mode,
		"form": form,
		"speed": speed,
	})


func spawn_beam(sprite: Sprite2D, direction: Vector2, lifetime: float, palette: String, ability_mode: int) -> void:
	projectiles.append({"sprite": sprite, "outline": null, "direction": direction, "timer": lifetime, "hit": false, "palette": palette, "target": null, "ability_mode": ability_mode, "form": null, "beam": true, "speed": 60.0, "beam_hit_counts": {}, "beam_hit_cooldowns": {}})


func spawn_tether(line: Line2D, source: Sprite2D, target: Sprite2D, lifetime: float, max_range: float, palette: String, ability_mode: int, form: Resource) -> void:
	projectiles.append({"tether": true, "line": line, "source": source, "target": target, "timer": lifetime, "max_range": max_range, "palette": palette, "ability_mode": ability_mode, "form": form, "tick_timer": 0.0, "tick_interval": float(form.get("tick_interval"))})


func remove(index: int) -> void:
	if index >= 0 and index < projectiles.size():
		projectiles.remove_at(index)


func clear() -> void:
	for data in projectiles:
		var sprite := _valid_sprite(data.get("sprite"))
		var outline := _valid_sprite(data.get("outline"))
		var line := _valid_line(data.get("line"))
		if sprite != null and is_instance_valid(sprite): sprite.queue_free()
		if outline != null and is_instance_valid(outline): outline.queue_free()
		if line != null and is_instance_valid(line): line.queue_free()
	projectiles.clear()


func tick(delta: float, speed: float, snap_position: Callable, target_point: Callable, is_targetable: Callable, hit_query: Callable, hit_resolve: Callable, trail: Callable) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var data: Dictionary = projectiles[index]
		var timer := float(data.get("timer", 0.0)) - delta
		var travel_age := float(data.get("travel_age", 0.0)) + maxf(delta, 0.0)
		if bool(data.get("tether", false)):
			var line := _valid_line(data.get("line"))
			var source := _valid_sprite(data.get("source"))
			var tether_target := _valid_sprite(data.get("target"))
			if line == null or source == null or tether_target == null or timer <= 0.0 or not bool(is_targetable.call(tether_target)):
				if line != null: line.queue_free()
				remove(index)
				continue
			var source_position: Vector2 = source.global_position + Vector2(8.0, 7.0)
			var target_position: Vector2 = target_point.call(tether_target)
			if source_position.distance_to(target_position) > float(data.get("max_range", 0.0)):
				line.queue_free()
				remove(index)
				continue
			line.global_position = snap_position.call(source_position)
			line.points = PackedVector2Array([Vector2.ZERO, line.to_local(snap_position.call(target_position))])
			var line_tint := line.modulate
			line_tint.a = 0.72 + 0.18 * sin((float(data.get("initial_timer", timer + delta)) - timer) * 18.0)
			line.modulate = line_tint
			var tick_timer := float(data.get("tick_timer", 0.0)) - delta
			var target_died := false
			while tick_timer <= 0.0 and timer > 0.0:
				hit_resolve.call(tether_target, target_position, String(data.get("palette", "grey")), int(data.get("ability_mode", 0)), true, data.get("form") as Resource)
				if not bool(is_targetable.call(tether_target)):
					target_died = true
					break
				tick_timer += maxf(float(data.get("tick_interval", 0.45)), 0.05)
			if target_died:
				line.queue_free()
				remove(index)
				continue
			data["tick_timer"] = tick_timer
			data["timer"] = timer
			data["initial_timer"] = float(data.get("initial_timer", timer + delta))
			projectiles[index] = data
			continue
		# Do not cast a freed Object before checking it. Godot reports the cast
		# itself, so the old `as Sprite2D` followed by is_instance_valid() still
		# logged errors during scene transitions.
		var sprite := _valid_sprite(data.get("sprite"))
		var outline := _valid_sprite(data.get("outline"))
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
		sprite.global_position = snap_position.call(sprite.global_position + direction * travel_speed * delta)
		if bool(data.get("orient_to_direction", false)):
			sprite.rotation = direction.angle() + PI * 0.5
		if bool(data.get("bubble_pulse", false)):
			var bubble_wobble := sin(travel_age * 13.0) * 0.07
			sprite.scale = Vector2(1.0 + bubble_wobble, 1.0 - bubble_wobble)
			sprite.rotation = sin(travel_age * 8.0) * 0.06
		if outline != null: outline.global_position = sprite.global_position
		if outline != null and bool(data.get("orient_to_direction", false)):
			outline.rotation = sprite.rotation
		if outline != null and bool(data.get("bubble_pulse", false)):
			outline.scale = sprite.scale
			outline.rotation = sprite.rotation
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
				hit_resolve.call(target, sprite.global_position, String(data.get("palette", "grey")), int(data.get("ability_mode", 0)), true, data.get("form") as Resource)
				beam_hit_counts[target_id] = int(beam_hit_counts.get(target_id, 0)) + 1
				beam_hit_cooldowns[target_id] = 0.12
			data["beam_hit_counts"] = beam_hit_counts
			data["beam_hit_cooldowns"] = beam_hit_cooldowns
		elif not bool(data.get("hit", false)) and travel_age >= float(data.get("minimum_travel_time", 0.0)):
			var target := hit_query.call(sprite, false) as Sprite2D
			if target != null:
				hit_resolve.call(target, sprite.global_position, String(data.get("palette", "grey")), int(data.get("ability_mode", 0)), false, data.get("form") as Resource)
				if sprite != null and is_instance_valid(sprite): sprite.queue_free()
				if outline != null and is_instance_valid(outline): outline.queue_free()
				remove(index)
				continue
		if not bool(data.get("beam", false)):
			trail.call(sprite.global_position, String(data.get("palette", "grey")), false, false)
		data["timer"] = timer
		data["travel_age"] = travel_age
		data["initial_timer"] = float(data.get("initial_timer", timer + delta))
		projectiles[index] = data


func _valid_sprite(value: Variant) -> Sprite2D:
	return value as Sprite2D if is_instance_valid(value) else null


func _valid_line(value: Variant) -> Line2D:
	return value as Line2D if is_instance_valid(value) else null
