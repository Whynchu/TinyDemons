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
var blocked_repath_cooldown := 0.0
var detour_target := Vector2.ZERO
var detour_timer := 0.0
var orbit_direction := 0.0
var notice_timer := 0.0
var notice_duration := 0.0
var notice_started := false
var notice_animation_finished := false


static func aggro_target(root: Object, slime: Sprite2D) -> Vector2:
	var slime_foot: Vector2 = root.call("_actor_foot", slime); var player_foot: Vector2 = root.call("_actor_foot", root.get("player")); var approach := slime_foot - player_foot; if approach.length_squared() < 0.01: approach = Vector2.RIGHT
	var tuning := root.get("slime_tuning") as SlimeTuning; var desired := player_foot + approach.normalized() * (tuning.attack_range * 0.72); var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		desired += tactics.approach_offset(approach)
	var buddy_avoidance := Vector2.ZERO
	var collision := root.get("actor_collision_system") as ActorCollisionSystem
	for buddy in root.get("slimes") as Array[Sprite2D]:
		if buddy == slime or bool(root.call("_is_slime_dead", buddy)): continue
		var buddy_delta: Vector2 = slime_foot - root.call("_actor_foot", buddy); var buddy_distance: float = buddy_delta.length(); var clear_distance: float = collision.actor_contact_radius(root, slime) + collision.actor_contact_radius(root, buddy) + 4.0
		if buddy_distance > 0.01 and buddy_distance < clear_distance: buddy_avoidance += buddy_delta.normalized() * (clear_distance - buddy_distance) / clear_distance
	if buddy_avoidance.length_squared() > 0.001: desired += buddy_avoidance.normalized() * 7.0
	return root.call("_nearest_slime_walkable_point", desired)
var start_position := Vector2.ZERO
var idle_breath_timer := 0.0


func tick(delta: float) -> void:
	repath_timer = maxf(repath_timer - delta, 0.0)
	hold_timer = maxf(hold_timer - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	blocked_repath_cooldown = maxf(blocked_repath_cooldown - delta, 0.0)
	detour_timer = maxf(detour_timer - delta, 0.0)
	notice_timer = maxf(notice_timer - delta, 0.0)


func begin_notice(duration: float) -> void:
	notice_duration = maxf(duration, 0.01)
	notice_timer = notice_duration
	notice_started = true
	notice_animation_finished = false
	hold_timer = 0.0
	scoot_timer = 0.0
	scoot_start = Vector2.ZERO
	scoot_target = Vector2.ZERO


func is_noticing() -> bool:
	return notice_timer > 0.0


func notice_wiggle_scale() -> Vector2:
	if notice_duration <= 0.0:
		return Vector2.ONE
	var progress := 1.0 - clampf(notice_timer / notice_duration, 0.0, 1.0)
	var wobble := sin(progress * TAU) * 0.14
	return Vector2(1.0 + wobble, 1.0 - absf(wobble) * 0.42)


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
	if aggroed:
		hold_timer = random_source.randf_range(tuning.aggro_hold_min, tuning.aggro_hold_max)
		idle_breath_timer = 0.0
		return
	var hold_time := random_source.randf_range(tuning.hold_min, tuning.hold_max)
	if random_source.randf() < tuning.chill_chance:
		hold_time = random_source.randf_range(tuning.chill_min, tuning.chill_max)
	hold_timer = hold_time
	idle_breath_timer = 0.0


func start_scoot(actor: Sprite2D, tuning: SlimeTuning, random_source: RandomNumberGenerator, actor_foot: Callable, aggro_target_callable: Callable, random_point: Callable, perspective: Callable, set_facing: Callable) -> void:
	var target_position: Vector2 = target
	var foot: Vector2 = actor_foot.call(actor)
	var is_aggroed := aggroed
	if is_aggroed:
		if detour_timer > 0.0 and foot.distance_to(detour_target) > 2.0:
			target_position = detour_target
		else:
			detour_timer = 0.0
			target_position = aggro_target_callable.call(actor)
		target = target_position
		repath_timer = 0.08
	elif foot.distance_to(target_position) < 2.0 or repath_timer <= 0.0:
		target_position = random_point.call(foot, 5, actor)
		target = target_position
		repath_timer = random_source.randf_range(tuning.repath_min, tuning.repath_max)
	var direction := target_position - foot
	if direction.length_squared() < 0.01:
		if is_aggroed:
			# Context steering can orbit while already inside the preferred
			# attack ring; the old target-point approach would stop here.
			direction = Vector2.RIGHT
		else:
			start_random_hold(tuning, random_source)
			return
	var steering_direction := direction.normalized()
	if is_aggroed:
		steering_direction = context_steering_direction(actor, tuning, random_source, actor_foot, perspective)
	var movement_distance := tuning.scoot_distance if is_aggroed else minf(tuning.scoot_distance, direction.length())
	var movement: Vector2 = perspective.call(steering_direction * movement_distance)
	set_facing.call(actor, movement.x)
	scoot_start = actor.position
	scoot_target = actor.position + movement
	scoot_timer = tuning.scoot_duration


func context_steering_direction(actor: Sprite2D, tuning: SlimeTuning, random_source: RandomNumberGenerator, actor_foot: Callable, perspective: Callable) -> Vector2:
	var root := actor.get_parent()
	while root != null and not root.has_method("_is_slime_collision_rect_walkable_at"):
		root = root.get_parent()
	if root == null:
		return Vector2.RIGHT
	var player := root.get("player") as Sprite2D
	if player == null:
		return Vector2.RIGHT
	var slime_foot: Vector2 = actor_foot.call(actor)
	var player_foot: Vector2 = actor_foot.call(player)
	var to_player := player_foot - slime_foot
	if to_player.length_squared() < 0.01:
		return Vector2.RIGHT

	if is_zero_approx(orbit_direction):
		var tactics := actor.get_node_or_null("Tactics") as EnemyTacticsComponent
		if tactics != null and tactics.formation_slot != 0:
			orbit_direction = float(tactics.formation_slot)
		else:
			orbit_direction = -1.0 if random_source.randf() < 0.5 else 1.0

	var distance := to_player.length()
	var towards_player := to_player.normalized()
	var desired_distance := tuning.attack_range * 0.72
	var best_direction := towards_player
	var best_score := -INF
	var direction_count := maxi(tuning.steering_direction_count, 4)

	for index in direction_count:
		var angle := TAU * float(index) / float(direction_count)
		var candidate := Vector2(cos(angle), sin(angle))
		var candidate_movement: Vector2 = perspective.call(candidate * tuning.scoot_distance)
		var candidate_foot := slime_foot + candidate_movement
		var danger := 0.0
		if not bool(root.call("_is_slime_collision_rect_walkable_at", actor, candidate_foot)):
			danger += tuning.steering_blocked_danger_weight

		for buddy in root.get("slimes") as Array[Sprite2D]:
			if buddy == actor or bool(root.call("_is_slime_dead", buddy)):
				continue
			var buddy_delta: Vector2 = slime_foot - actor_foot.call(buddy)
			var buddy_distance := buddy_delta.length()
			if buddy_distance > 0.01 and buddy_distance < tuning.steering_clearance:
				var repulsion := buddy_delta.normalized()
				var overlap := maxf(candidate.dot(-repulsion), 0.0)
				danger += overlap * (tuning.steering_clearance - buddy_distance) / tuning.steering_clearance * tuning.steering_ally_danger_weight

		var approach_interest := candidate.dot(towards_player)
		if distance < desired_distance:
			approach_interest = -approach_interest
		var orbit := Vector2(-towards_player.y, towards_player.x) * orbit_direction
		var orbit_factor := clampf(1.0 - absf(distance - desired_distance) / tuning.attack_range, 0.0, 1.0)
		var interest := approach_interest * tuning.steering_approach_weight
		interest += candidate.dot(orbit) * orbit_factor * tuning.steering_orbit_weight
		var score := interest - danger
		if score > best_score:
			best_score = score
			best_direction = candidate

	if distance > tuning.attack_range:
		best_direction.y *= 2.0
		best_direction = best_direction.normalized()
	return best_direction


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
