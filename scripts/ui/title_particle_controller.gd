extends RefCounted
class_name TitleParticleController

var _particles: Array[Dictionary] = []


func add_particle(particle_data: Dictionary) -> void:
	_particles.append(particle_data)


func clear_title_particles() -> void:
	for particle_data in _particles:
		var particle := particle_data.get("sprite") as Node
		if particle != null and is_instance_valid(particle):
			particle.queue_free()
	_particles.clear()


func update_particles(delta: float, snap_position: Callable) -> void:
	for index in range(_particles.size() - 1, -1, -1):
		var particle_data := _particles[index]
		var particle := particle_data["sprite"] as Sprite2D
		var timer := float(particle_data["timer"]) - delta
		if particle == null or timer <= 0.0:
			if particle != null:
				particle.queue_free()
			_particles.remove_at(index)
			continue
		var logical_position := particle_data.get("logical_position", particle.position) as Vector2
		logical_position += particle_data["velocity"] as Vector2 * delta
		particle_data["logical_position"] = logical_position
		particle.position = snap_position.call(logical_position)
		particle.modulate.a = clampf(timer / float(particle_data.get("lifetime", 1.14)), 0.0, 1.0)
		particle_data["timer"] = timer


func spawn_pixel_breakup(source_sprite: Sprite2D, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	if source_sprite == null or source_sprite.texture == null:
		return
	var image := source_sprite.texture.get_image()
	if image == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.28
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var pixel_position := source_sprite.global_position
			var pixel_size := source_sprite.scale
			if source_sprite.centered:
				pixel_position -= Vector2(image.get_width(), image.get_height()) * pixel_size * 0.5
			pixel_position += Vector2(x, y) * pixel_size
			var particle := Sprite2D.new()
			particle.texture = pixel_texture.call(color) as Texture2D
			particle.centered = false
			particle.scale = pixel_size
			particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			particle.z_as_relative = true
			particle.z_index = 3
			particle.position = pixel_position
			particle_parent.add_child(particle)
			add_particle({"sprite": particle, "velocity": Vector2(0.0, -(8.0 + (noise.get_noise_2d(float(x), float(y)) + 1.0) * 14.0)), "timer": 1.14, "lifetime": 1.14, "gravity": 0.0})


func spawn_button_frame_breakup(button: Button, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	if button == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.28
	var origin := button.position
	if particle_parent is Node2D:
		origin = (particle_parent as Node2D).to_local(button.global_position)
	var width := int(button.size.x)
	var height := int(button.size.y)
	for x in range(width):
		_spawn_frame_particle(origin + Vector2(x, 0), particle_parent, pixel_texture, noise.get_noise_2d(float(x), 0.0))
		_spawn_frame_particle(origin + Vector2(x, height - 1), particle_parent, pixel_texture, noise.get_noise_2d(float(x), float(height - 1)))
	for y in range(1, height - 1):
		_spawn_frame_particle(origin + Vector2(0, y), particle_parent, pixel_texture, noise.get_noise_2d(0.0, float(y)))
		_spawn_frame_particle(origin + Vector2(width - 1, y), particle_parent, pixel_texture, noise.get_noise_2d(float(width - 1), float(y)))


func _spawn_frame_particle(frame_position: Vector2, particle_parent: Node, pixel_texture: Callable, noise_value: float) -> void:
	var particle := Sprite2D.new()
	particle.texture = pixel_texture.call(Color.WHITE) as Texture2D
	particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = true
	particle.z_index = 3
	particle.position = frame_position
	particle_parent.add_child(particle)
	var rise_speed := 8.0 + (noise_value + 1.0) * 14.0
	add_particle({"sprite": particle, "velocity": Vector2(0.0, -rise_speed), "timer": 1.14, "lifetime": 1.14, "gravity": 0.0})
