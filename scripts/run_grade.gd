extends RefCounted
class_name RunGrade

## Room completion remains visible and provides a small route-discipline bonus.
## Map discovery is deliberately informational and does not affect the grade.
const COMPLETION_WEIGHT := 10.0
const TIME_WEIGHT := 30.0
const COMBAT_WEIGHT := 30.0
const STYLE_WEIGHT := 20.0
const COMBO_WEIGHT := 10.0
const STYLE_MAX := 10

# These are intentionally route-scaled rather than a single hard-coded clear
# time. They give short and long generated routes a comparable time target.
const TIME_BASE_SECONDS := 24.0
const TIME_PER_ROOM_SECONDS := 17.0
const TIME_FAST_FACTOR := 0.72
const TIME_SLOW_FACTOR := 1.70


static func evaluate(run: RunState, _starting_health: float = 1.0) -> Dictionary:
	var map_discovered_rooms := run.map_discovered_rooms.size()
	var map_room_count := maxi(run.map_room_count, map_discovered_rooms)
	var completed_rooms := run.completed_run_rooms.size()
	var room_count := maxi(run.run_room_count, completed_rooms)
	var map_completion_ratio := _ratio(map_discovered_rooms, map_room_count)
	var room_completion_ratio := _ratio(completed_rooms, room_count)
	var time_quality := time_quality_for(run)
	var style := evaluate_style(run)
	var combat_quality := combat_quality_for(run)
	var combo_quality := combo_quality_for(run)
	var completion_score := COMPLETION_WEIGHT * room_completion_ratio
	var time_score := TIME_WEIGHT * time_quality
	var combat_score := COMBAT_WEIGHT * combat_quality
	var style_quality := float(style["style_score"]) / float(STYLE_MAX)
	var style_score := STYLE_WEIGHT * style_quality
	var combo_score := COMBO_WEIGHT * combo_quality
	var score := clampi(roundi(completion_score + time_score + combat_score + style_score + combo_score), 0, 100)
	var grade := _grade_for_score(score)
	return {
		"score": score,
		"grade": grade,
		"full_clear": room_completion_ratio >= 1.0,
		"map_complete": map_completion_ratio >= 1.0,
		"map_discovered_rooms": map_discovered_rooms,
		"map_room_count": map_room_count,
		"map_completion_ratio": map_completion_ratio,
		"completed_rooms": completed_rooms,
		"room_count": room_count,
		"room_completion_ratio": room_completion_ratio,
		"completion_score": roundi(completion_score),
		"time_score": roundi(time_score),
		"combat_score": roundi(combat_score),
		"combat_quality": combat_quality,
		"combo_score": roundi(combo_score),
		"combo_quality": combo_quality,
		"time_quality": time_quality,
		"time_target": target_time_seconds(run),
		"style_score": int(style["style_score"]),
		"style_max": STYLE_MAX,
		"style_quality": style_quality,
		"style_actions": style["actions"],
		"style_attack_points": int(style["attack_points"]),
		"style_technique_points": int(style["technique_points"]),
		"style_defense_points": int(style["defense_points"]),
		"style_element_points": int(style["element_points"]),
		"style_flow_points": int(style["flow_points"]),
		"max_combo": run.max_combo_count,
		"combo_hits": run.combo_hit_count,
	}


static func combat_quality_for(run: RunState) -> float:
	# Combat quality measures how well the player trades damage, rather than
	# whether the room eventually ended. Enemy damage uses a two-point base, so
	# incoming damage is normalized against the pressure the run faced.
	var incoming_attempts := maxi(run.enemy_attack_attempts, run.encountered_enemy_count)
	var damage_quality := 1.0 if incoming_attempts <= 0 else 1.0 - clampf(run.damage_taken / float(incoming_attempts * 2), 0.0, 1.0)
	var hit_quality := 1.0 if run.attack_count <= 0 else _ratio(run.attack_swing_hit_count, run.attack_count)
	return clampf(damage_quality * 0.60 + hit_quality * 0.40, 0.0, 1.0)


static func combo_quality_for(run: RunState) -> float:
	return clampf(float(run.max_combo_count) / 10.0, 0.0, 1.0)


static func evaluate_style(run: RunState) -> Dictionary:
	var attack_points := 0
	if _has_action(run, &"attack1"):
		attack_points += 1
	if _has_action(run, &"attack2"):
		attack_points += 1
	var technique_points := 0
	if _has_action(run, &"spin"):
		technique_points += 1
	if _has_action(run, &"charged"):
		technique_points += 1
	var defense_actions := 0
	for action in [&"dodge_roll", &"backflip", &"block"]:
		if _has_action(run, action):
			defense_actions += 1
	var defense_points := mini(defense_actions, 2)
	var element_actions := 0
	for action in [&"magic", &"imbued"]:
		if _has_action(run, action):
			element_actions += 1
	var element_points := mini(element_actions, 2)
	var flow_points := 0
	if run.max_combo_count >= 3:
		flow_points += 1
	if run.max_combo_count >= 5:
		flow_points += 1
	if run.style_actions.size() >= 6:
		flow_points += 1
	var style_score := mini(STYLE_MAX, attack_points + technique_points + defense_points + element_points + flow_points)
	return {
		"style_score": style_score,
		"attack_points": attack_points,
		"technique_points": technique_points,
		"defense_points": defense_points,
		"element_points": element_points,
		"flow_points": mini(flow_points, 3),
		"actions": run.style_actions.duplicate(),
	}


static func target_time_seconds(run: RunState) -> float:
	if run.route_par_seconds > 0.0:
		return run.route_par_seconds
	var room_count := maxi(run.run_room_count, 1)
	return TIME_BASE_SECONDS + float(room_count) * TIME_PER_ROOM_SECONDS


static func time_quality_for(run: RunState) -> float:
	var target := target_time_seconds(run)
	var fast_target := target * TIME_FAST_FACTOR
	var slow_target := target * TIME_SLOW_FACTOR
	return clampf((slow_target - maxf(run.elapsed_time, 0.0)) / maxf(slow_target - fast_target, 1.0), 0.0, 1.0)


static func _has_action(run: RunState, action: StringName) -> bool:
	return int(run.style_actions.get(action, 0)) > 0


static func _ratio(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 1.0
	return clampf(float(numerator) / float(denominator), 0.0, 1.0)


static func _grade_for_score(score: int) -> String:
	if score >= 90:
		return "S"
	if score >= 78:
		return "A"
	if score >= 64:
		return "B"
	if score >= 48:
		return "C"
	return "D"
