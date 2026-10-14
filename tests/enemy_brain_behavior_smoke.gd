extends SceneTree

const SLIME_TUNING := preload("res://resources/tuning/slime_default.tres")
const ENEMY_STEERING_WORLD_SCRIPT := preload("res://scripts/runtime/contexts/enemy_steering_world.gd")
const BOSS_SLIME_SCENE := preload("res://scenes/authoring/previews/boss_slime_authoring.tscn")


class EnemyBrainRootProbe extends RefCounted:
	var player: Sprite2D
	var slime_tuning: SlimeTuning
	var actor_collision_system: ActorCollisionSystem


	func _actor_foot(actor: Sprite2D) -> Vector2:
		return actor.position


	func _nearest_slime_walkable_point(point: Vector2) -> Vector2:
		return point


func _initialize() -> void:
	var failures: Array[String] = []
	var slime_variants := EnemyFactory.variants_for_type(&"slime")
	var skeleton_variants := EnemyFactory.variants_for_type(&"skeleton")
	_expect(not slime_variants.is_empty(), "catalog exposes at least one Slime definition", failures)
	_expect(not skeleton_variants.is_empty(), "catalog exposes at least one Skeleton definition", failures)
	if slime_variants.is_empty() or skeleton_variants.is_empty():
		_finish(failures)
		return

	var slime_actor := EnemyFactory.assemble(EnemyFactory.definition(slime_variants[0]))
	var skeleton_actor := EnemyFactory.assemble(EnemyFactory.definition(skeleton_variants[0]))
	_expect(slime_actor != null and slime_actor is EnemyActor, "Slime definition assembles through EnemyFactory", failures)
	_expect(skeleton_actor != null and skeleton_actor is EnemyActor, "Skeleton definition assembles through EnemyFactory", failures)
	if slime_actor == null or skeleton_actor == null:
		_finish(failures)
		return

	var slime_brain := slime_actor.get_node_or_null("Brain") as EnemyBrain
	var skeleton_brain := skeleton_actor.get_node_or_null("Brain") as EnemyBrain
	_expect(slime_brain != null, "Slime uses the shared EnemyBrain host", failures)
	_expect(skeleton_brain != null, "Skeleton uses the shared EnemyBrain host", failures)
	var slime_behavior := slime_brain.behavior_component if slime_brain != null else null
	var skeleton_behavior := skeleton_brain.behavior_component if skeleton_brain != null else null
	_expect(slime_behavior is SlimeBrainBehaviorComponent, "Slime factory route installs Slime brain behavior", failures)
	_expect(skeleton_behavior is SkeletonBrainBehaviorComponent, "Skeleton factory route installs Skeleton brain behavior", failures)

	var direct_slime := SlimeActor.new()
	direct_slime.ensure_components()
	var direct_skeleton := SkeletonActor.new()
	direct_skeleton.ensure_components()
	var direct_slime_brain := direct_slime.get_node_or_null("Brain") as EnemyBrain
	var direct_skeleton_brain := direct_skeleton.get_node_or_null("Brain") as EnemyBrain
	_expect(direct_slime_brain != null and direct_slime_brain.behavior_component is SlimeBrainBehaviorComponent, "direct Slime setup installs Slime brain behavior", failures)
	_expect(direct_skeleton_brain != null and direct_skeleton_brain.behavior_component is SkeletonBrainBehaviorComponent, "direct Skeleton setup installs Skeleton brain behavior", failures)
	var authored_slime := BOSS_SLIME_SCENE.instantiate() as SlimeActor
	_expect(authored_slime != null, "authored boss Slime scene loads", failures)
	if authored_slime != null:
		authored_slime.ensure_components()
		var authored_brain := authored_slime.get_node_or_null("Brain") as EnemyBrain
		_expect(authored_brain != null and authored_brain.behavior_component is SlimeBrainBehaviorComponent, "authored boss Slime scene receives Slime brain behavior", failures)

	var tuning := SLIME_TUNING.duplicate(true) as SlimeTuning
	if slime_behavior != null and skeleton_behavior != null:
		var slime_range := slime_behavior.preferred_attack_distance(0.0, tuning.attack_range, tuning.support_preferred_range, false)
		var support_range := slime_behavior.preferred_attack_distance(0.0, tuning.attack_range, tuning.support_preferred_range, true)
		var skeleton_range := skeleton_behavior.preferred_attack_distance(0.0, tuning.attack_range, tuning.support_preferred_range, false)
		_expect(is_equal_approx(slime_range, tuning.attack_range * 0.72), "Slime retains its attack-range preference", failures)
		_expect(is_equal_approx(support_range, maxf(tuning.attack_range * 0.72, tuning.support_preferred_range)), "Slime support behavior retains its wider preferred range", failures)
		_expect(is_equal_approx(skeleton_range, 72.0), "Skeleton retains its authored family range", failures)
		_expect(is_equal_approx(slime_behavior.adjust_approach_interest(1.0, slime_range - 1.0, slime_range), -1.0), "Slime keeps approaching when inside its preferred range", failures)
		if slime_brain != null and skeleton_brain != null:
			var player := Sprite2D.new()
			player.position = Vector2(145.0, 100.0)
			var area := WalkableArea.new()
			var bounds := PackedVector2Array([
				Vector2(-1000.0, -1000.0), Vector2(1000.0, -1000.0),
				Vector2(1000.0, 1000.0), Vector2(-1000.0, 1000.0),
			])
			area.set_geometry([bounds], bounds)
			area.build_outline(false)
			var steering_world := ENEMY_STEERING_WORLD_SCRIPT.new() as EnemySteeringWorld
			steering_world.configure(player, null, area)
			var steering_tuning := tuning.duplicate(true) as SlimeTuning
			steering_tuning.attack_range = 14.0
			steering_tuning.steering_direction_count = 4
			steering_tuning.steering_approach_weight = 1.0
			steering_tuning.steering_attack_cone_weight = 0.0
			steering_tuning.steering_orbit_weight = 0.0
			steering_tuning.steering_blocked_danger_weight = 0.0
			steering_tuning.steering_clearance = 0.1
			slime_actor.position = Vector2(100.0, 100.0)
			skeleton_actor.position = Vector2(100.0, 100.0)
			slime_brain.orbit_direction = 1.0
			var random_source := RandomNumberGenerator.new()
			random_source.seed = 24681357
			var slime_direction := slime_brain.context_steering_direction(slime_actor, steering_tuning, random_source, steering_world, Callable(self, "_identity_movement"))
			_expect(slime_direction.dot(Vector2.RIGHT) > 0.95, "shared brain uses Slime behavior to approach its melee range", failures)
			var brain_root := EnemyBrainRootProbe.new()
			brain_root.player = player
			brain_root.slime_tuning = steering_tuning
			var slime_target := slime_brain.aggro_target(brain_root, slime_actor)
			var skeleton_target := skeleton_brain.aggro_target(brain_root, skeleton_actor)
			var steering_slime_range := steering_tuning.attack_range * 0.72
			_expect(is_equal_approx(slime_target.distance_to(player.position), steering_slime_range), "shared brain places Slime target at its family preferred range", failures)
			_expect(is_equal_approx(skeleton_target.distance_to(player.position), skeleton_range), "shared brain places live Skeleton walk target at its family preferred range", failures)
			player.free()
			area.free()

	slime_actor.free()
	skeleton_actor.free()
	direct_slime.free()
	direct_skeleton.free()
	if authored_slime != null:
		authored_slime.free()
	_finish(failures)


func _identity_movement(movement: Vector2) -> Vector2:
	return movement


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_BRAIN_BEHAVIOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
