extends SceneTree

const SLIME_TUNING := preload("res://resources/tuning/slime_default.tres")
const EnemySteeringWorldScript = preload("res://scripts/runtime/contexts/enemy_steering_world.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var scene_root := Node2D.new()
	root.add_child(scene_root)
	var unrelated_parent := Node2D.new()
	scene_root.add_child(unrelated_parent)
	var actor := Sprite2D.new()
	actor.centered = false
	actor.position = Vector2(100.0, 100.0)
	unrelated_parent.add_child(actor)
	var collision_polygon := Polygon2D.new()
	collision_polygon.name = "CollisionPolygon"
	collision_polygon.polygon = PackedVector2Array([
		Vector2(-4.0, -2.0), Vector2(4.0, -2.0),
		Vector2(4.0, 2.0), Vector2(-4.0, 2.0),
	])
	actor.add_child(collision_polygon)
	var player := Sprite2D.new()
	player.position = Vector2(100.0, 500.0)
	scene_root.add_child(player)
	var area := WalkableArea.new()
	var bounds := PackedVector2Array([
		Vector2(-1000.0, -1000.0), Vector2(1000.0, -1000.0),
		Vector2(1000.0, 1000.0), Vector2(-1000.0, 1000.0),
	])
	area.set_geometry([bounds], bounds)
	area.build_outline(false)
	var world := EnemySteeringWorldScript.new() as EnemySteeringWorldScript
	world.configure(player, null, area)
	var nearby: Array[Sprite2D] = world.nearby_enemies(actor.position, 32.0)
	_expect(nearby.is_empty(), "missing collision service returns a typed empty enemy query", failures)
	_expect(world.actor_foot(actor).is_equal_approx(Vector2(108.0, 115.0)), "steering world uses the shared actor foot geometry", failures)
	actor.centered = true
	_expect(world.actor_foot(actor).is_equal_approx(actor.global_position), "centered targets retain their world-space geometry anchor", failures)
	actor.centered = false
	_expect(world.is_collision_rect_walkable_at(actor, Vector2(108.0, 115.0)), "steering world uses the actor collision polygon for walkability", failures)
	_expect(not world.is_walkable_point(Vector2(2000.0, 2000.0)), "steering world rejects points outside the authored walkable outline", failures)
	var brain := EnemyBrain.new()
	root.add_child(brain)
	brain.orbit_direction = 1.0
	var tuning := SLIME_TUNING.duplicate(true) as SlimeTuning
	tuning.steering_direction_count = 8
	var random_source := RandomNumberGenerator.new()
	random_source.seed = 24681357
	var direction := brain.context_steering_direction(actor, tuning, random_source, world, Callable(self, "_identity_movement"))
	_expect(direction.dot(Vector2.DOWN) > 0.95, "brain steers toward its injected player without a GameplayState ancestor", failures)
	brain.free()
	scene_root.free()
	area.free()

	if failures.is_empty():
		print("ENEMY_STEERING_WORLD_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _identity_movement(movement: Vector2) -> Vector2:
	return movement


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
