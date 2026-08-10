extends Node
class_name SlimeBrain

## Decision-state boundary for slime actors.
## Movement and collision remain coordinated by gameplay during migration.

var aggroed := false
var holding := false
var repath_timer := 0.0
var hold_timer := 0.0
var attack_cooldown := 0.0
var target := Vector2.ZERO
var scoot_start := Vector2.ZERO
var scoot_target := Vector2.ZERO
var scoot_timer := 0.0
var persistent_aggro := false
var start_position := Vector2.ZERO
var idle_breath_timer := 0.0


func tick(delta: float) -> void:
	repath_timer = maxf(repath_timer - delta, 0.0)
	hold_timer = maxf(hold_timer - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)


func set_aggro(value: bool) -> void:
	aggroed = value


func begin_hold(duration: float) -> void:
	holding = true
	hold_timer = maxf(duration, 0.0)


func can_attack() -> bool:
	return aggroed and not holding and attack_cooldown <= 0.0


func start_attack(cooldown: float) -> void:
	attack_cooldown = maxf(cooldown, 0.0)


func needs_repath() -> bool:
	return repath_timer <= 0.0


func schedule_repath(delay: float) -> void:
	repath_timer = maxf(delay, 0.0)


func scoot_ease(progress: float) -> float:
	return 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)


func idle_breath_scale(delta: float, breath_time: float) -> Vector2:
	idle_breath_timer = fmod(idle_breath_timer + delta, breath_time)
	var pulse := (sin((idle_breath_timer / breath_time) * TAU - PI * 0.5) + 1.0) * 0.5
	return Vector2(1.0 + pulse * 0.05, 1.0 - pulse * 0.04)


func start_random_hold(tuning: SlimeTuning, random_source: RandomNumberGenerator) -> void:
	var hold_time := random_source.randf_range(tuning.hold_min, tuning.hold_max)
	if not aggroed and random_source.randf() < tuning.chill_chance:
		hold_time = random_source.randf_range(tuning.chill_min, tuning.chill_max)
	hold_timer = hold_time
	idle_breath_timer = 0.0


func start_scoot(actor: Sprite2D, tuning: SlimeTuning, random_source: RandomNumberGenerator, actor_foot: Callable, aggro_target: Callable, random_point: Callable, perspective: Callable, set_facing: Callable) -> void:
	var target_position: Vector2 = target
	var foot: Vector2 = actor_foot.call(actor)
	var is_aggroed := aggroed
	if is_aggroed:
		target_position = aggro_target.call(actor)
		target = target_position
		repath_timer = 0.08
	elif foot.distance_to(target_position) < 2.0 or repath_timer <= 0.0:
		target_position = random_point.call(foot, 5, actor)
		target = target_position
		repath_timer = random_source.randf_range(tuning.repath_min, tuning.repath_max)
	var direction := target_position - foot
	if direction.length_squared() < 0.01:
		if is_aggroed:
			target = aggro_target.call(actor)
			repath_timer = 0.0
		else:
			start_random_hold(tuning, random_source)
		return
	var steering_direction := direction.normalized()
	if is_aggroed:
		steering_direction.y *= 2.0
		steering_direction = steering_direction.normalized()
	var movement: Vector2 = perspective.call(steering_direction * minf(tuning.scoot_distance, direction.length()))
	set_facing.call(actor, movement.x)
	scoot_start = actor.position
	scoot_target = actor.position + movement
	scoot_timer = tuning.scoot_duration


func tick_scoot(actor: Sprite2D, delta: float, tuning: SlimeTuning, is_aggroed: Callable, try_move: Callable, set_scale: Callable, repath: Callable, start_hold: Callable, start_next: Callable) -> void:
	var timer := scoot_timer
	if timer > 0.0:
		var previous_progress := 1.0 - timer / tuning.scoot_duration
		timer = maxf(timer - delta, 0.0)
		var progress := 1.0 - timer / tuning.scoot_duration
		scoot_timer = timer
		var movement: Vector2 = (scoot_target - scoot_start) * (scoot_ease(progress) - scoot_ease(previous_progress))
		var did_move: bool = try_move.call(actor, movement)
		set_scale.call(actor, _squish_scale(progress, scoot_target - scoot_start))
		if not did_move and movement.length_squared() > 0.001:
			repath.call(actor)
			return
		if timer <= 0.0:
			start_hold.call(actor)
		return
	if hold_timer > 0.0:
		hold_timer = maxf(hold_timer - delta, 0.0)
		if is_aggroed.call(actor):
			set_scale.call(actor, Vector2.ONE)
		else:
			set_scale.call(actor, idle_breath_scale(delta, tuning.idle_breath_time))
		return
	start_next.call(actor)


func _squish_scale(progress: float, movement: Vector2) -> Vector2:
	var pulse := sin(clampf(progress, 0.0, 1.0) * PI)
	var x := 1.0 + pulse * 0.18
	var y := 1.0 - pulse * 0.14
	if absf(movement.y) > absf(movement.x):
		x = 1.0 + pulse * 0.12
		y = 1.0 - pulse * 0.18
	return Vector2(x, y)
