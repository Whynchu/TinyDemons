extends RefCounted
class_name RunGrade

static func evaluate(run: RunState, starting_health: float) -> Dictionary:
	var elapsed := maxf(run.elapsed_time, 1.0)
	# A quick straight-line clear should not beat a deliberate, well-played route.
	var time_score := clampf(28.0 - elapsed / 28.0, 5.0, 28.0)
	var damage_ratio := run.damage_taken / maxf(starting_health, 1.0)
	var survival_score := clampf(25.0 - damage_ratio * 12.0, 3.0, 25.0)
	var explored_rooms := run.visited_rooms.size()
	var explorable_rooms := maxi(run.explorable_room_count, explored_rooms)
	var exploration_ratio := 1.0 if explorable_rooms <= 0 else float(explored_rooms) / float(explorable_rooms)
	var exploration_score := 23.0 * clampf(exploration_ratio, 0.0, 1.0)
	var encounters := maxi(run.encountered_enemy_count, 1)
	var variety_count := 0
	var variety_max := 3
	if run.attack_hit_count >= encounters: variety_count += 1
	if run.attack2_hit_count >= maxi(1, ceili(float(encounters) * 0.25)): variety_count += 1
	if run.combat_movement_time >= maxf(2.0, float(encounters) * 0.45): variety_count += 1
	if run.enemy_attack_attempts >= 1:
		var defence_goal := maxi(1, ceili(float(run.enemy_attack_attempts) * 0.15))
		variety_max += 2
		if run.dodge_count >= defence_goal: variety_count += 1
		if run.block_count >= defence_goal: variety_count += 1
	var variety_score := 18.0 * float(variety_count) / float(variety_max)
	var accuracy := float(run.attack_swing_hit_count) / float(maxi(run.attack_count, 1))
	var accuracy_score := 4.0 * clampf(accuracy, 0.0, 1.0)
	var wasted_inputs := run.total_wasted_inputs()
	var input_budget := maxf(4.0, float(run.total_action_inputs()) * 0.35)
	var control_score := 2.0 * clampf(1.0 - float(wasted_inputs) / input_budget, 0.0, 1.0)
	var score := clampi(roundi(time_score + survival_score + exploration_score + variety_score + accuracy_score + control_score), 0, 100)
	var grade := "S" if score >= 90 else "A" if score >= 78 else "B" if score >= 64 else "C" if score >= 48 else "D"
	return {"score": score, "grade": grade, "time_score": roundi(time_score), "survival_score": roundi(survival_score), "exploration_score": roundi(exploration_score), "explored_rooms": explored_rooms, "explorable_rooms": explorable_rooms, "exploration_ratio": exploration_ratio, "variety_score": roundi(variety_score), "variety_count": variety_count, "variety_max": variety_max, "accuracy": accuracy, "accuracy_score": roundi(accuracy_score), "control_score": roundi(control_score), "wasted_inputs": wasted_inputs}
