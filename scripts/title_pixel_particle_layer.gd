extends Node2D
class_name TitlePixelParticleLayer

## Batched title-breakup renderer. Each opaque source pixel remains an
## independent particle, but all particles are drawn by one CanvasItem instead
## of becoming one Sprite2D/node each. This keeps the full-screen breakup
## readable without reintroducing the title-transition node spike that caused
## the old particle cap.

const DEFAULT_LIFETIME := 1.14

var particles: Array[Dictionary] = []


func add_pixel_particle(position: Vector2, size: Vector2, color: Color, velocity: Vector2, lifetime: float = DEFAULT_LIFETIME) -> void:
	particles.append({
		"position": position,
		"size": size,
		"color": color,
		"velocity": velocity,
		"timer": lifetime,
		"lifetime": lifetime,
	})


func clear_particles() -> void:
	particles.clear()
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func update_particles(delta: float, snap_position: Callable) -> void:
	for index in range(particles.size() - 1, -1, -1):
		var particle := particles[index]
		var timer := float(particle["timer"]) - delta
		if timer <= 0.0:
			particles.remove_at(index)
			continue
		var position: Vector2 = particle["position"]
		position += particle["velocity"] as Vector2 * delta
		particle["position"] = snap_position.call(position)
		particle["timer"] = timer
		particles[index] = particle
	queue_redraw()


func _draw() -> void:
	for particle in particles:
		var lifetime := maxf(float(particle.get("lifetime", DEFAULT_LIFETIME)), 0.001)
		var fade := clampf(float(particle.get("timer", 0.0)) / lifetime, 0.0, 1.0)
		var source_color: Color = particle["color"]
		var draw_color := Color(source_color.r, source_color.g, source_color.b, source_color.a * fade)
		draw_rect(Rect2(particle["position"] as Vector2, particle["size"] as Vector2), draw_color, true)
