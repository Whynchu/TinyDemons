extends Node
class_name EffectsSpawner

signal effect_requested(kind: StringName, position: Vector2)
var damage_number_texture_cache: Dictionary = {}
var pixel_particle_texture_cache: Dictionary = {}
var damage_numbers: Array[Dictionary] = []
var pixel_particles: Array[Dictionary] = []


func request_effect(kind: StringName, position: Vector2) -> void:
	effect_requested.emit(kind, position)


func update_pixel_particles(delta: float, snap_position: Callable, default_lifetime: float) -> void:
	for index in range(pixel_particles.size() - 1, -1, -1):
		var particle_data := pixel_particles[index]
		var particle := particle_data["sprite"] as Sprite2D
		var timer := float(particle_data["timer"]) - delta
		if particle == null or timer <= 0.0:
			if particle != null:
				particle.queue_free()
			pixel_particles.remove_at(index)
			continue
		var velocity := particle_data["velocity"] as Vector2
		velocity.y += float(particle_data.get("gravity", 18.0)) * delta
		var logical_position := particle_data.get("logical_position", particle.position) as Vector2
		logical_position += velocity * delta
		particle_data["logical_position"] = logical_position
		particle.position = snap_position.call(logical_position)
		var color := particle.modulate
		var lifetime := float(particle_data.get("lifetime", default_lifetime))
		color.a = clampf(timer / lifetime, 0.0, 1.0)
		particle.modulate = color
		particle_data["velocity"] = velocity
		particle_data["timer"] = timer


func update_damage_numbers(delta: float, snap_position: Callable, default_lifetime: float) -> void:
	for index in range(damage_numbers.size() - 1, -1, -1):
		var damage_number := damage_numbers[index]
		var sprite := damage_number["sprite"] as Sprite2D
		var shadow := damage_number.get("shadow") as Sprite2D
		if sprite == null:
			if shadow != null:
				shadow.queue_free()
			damage_numbers.remove_at(index)
			continue
		var pop_timer := float(damage_number.get("pop_timer", 0.0))
		if pop_timer > 0.0:
			damage_number["pop_timer"] = maxf(pop_timer - delta, 0.0)
			sprite.modulate = Color.WHITE
			continue
		var timer := float(damage_number["timer"]) - delta
		if timer <= 0.0:
			sprite.queue_free()
			if shadow != null:
				shadow.queue_free()
			damage_numbers.remove_at(index)
			continue
		var logical_position := damage_number.get("logical_position", sprite.position) as Vector2
		logical_position += damage_number.get("velocity", Vector2.ZERO) as Vector2 * delta
		damage_number["logical_position"] = logical_position
		sprite.position = snap_position.call(logical_position)
		if shadow != null:
			shadow.position = snap_position.call(logical_position + Vector2(0.0, 0.5))
		var alpha := clampf(timer / default_lifetime, 0.0, 1.0)
		sprite.modulate.a = alpha
		if shadow != null:
			shadow.modulate.a = alpha
		damage_number["timer"] = timer
