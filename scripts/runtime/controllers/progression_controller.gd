extends RefCounted
class_name ProgressionController

const StatAllocationPolicyScript = preload("res://scripts/algorithms/stat_allocation_policy.gd")

## Domain-facing progression commands. This type deliberately has no scene/UI
## dependencies so hub screens and gameplay can share the same rules.

static func award_xp(profile: PlayerProfile, amount: int, tuning: ProgressionTuning = null) -> Dictionary:
	if profile == null:
		return {"xp": 0, "levels": 0, "points": 0, "level": 0}
	return profile.award_xp(amount, tuning)

static func allocate_stats(profile: PlayerProfile, allocations: Dictionary) -> Dictionary:
	var result := {"accepted": false, "spent": 0, "remaining": 0, "changed": false, "reason": "INVALID PROFILE"}
	if profile == null:
		return result
	var proposed := profile.allocated_stat_values()
	var current_allocations := proposed.duplicate()
	for index in StatAllocationPolicyScript.STAT_NAMES.size():
		var stat_name: StringName = StatAllocationPolicyScript.STAT_NAMES[index]
		var primary_key := String(stat_name)
		var fallback_key := "SPD" if stat_name == &"AGI" else primary_key
		var amount := int(allocations.get(primary_key, allocations.get(fallback_key, 0)))
		if amount < 0:
			result["reason"] = "INVALID POINT COUNT"
			return result
		proposed[index] += amount
	var points_to_spend := 0
	for index in proposed.size():
		points_to_spend += proposed[index] - current_allocations[index]
	if points_to_spend <= 0:
		result["reason"] = "NO POINTS TO ALLOCATE"
		result["remaining"] = profile.unspent_stat_points
		return result
	if points_to_spend > profile.unspent_stat_points:
		result["reason"] = "NOT ENOUGH POINTS"
		result["remaining"] = profile.unspent_stat_points
		return result
	var committed := profile.commit_stat_allocations_atomic(proposed)
	if not bool(committed.get("accepted", false)):
		result["reason"] = str(committed.get("reason", "ALLOCATION REJECTED"))
		result["remaining"] = profile.unspent_stat_points
		result["policy"] = committed
		return result
	return committed


static func validate_draft(profile: PlayerProfile, pending: Array[int]) -> Dictionary:
	if profile == null or pending.size() != StatAllocationPolicyScript.STAT_NAMES.size():
		return {"accepted": false, "reason": "INVALID ALLOCATION"}
	var pending_total := 0
	var proposed: Array[int] = profile.allocated_stat_values()
	var base := profile.base_stat_values()
	for index in pending.size():
		if pending[index] < 0:
			return {"accepted": false, "reason": "INVALID ALLOCATION"}
		pending_total += pending[index]
		proposed[index] += pending[index]
	if pending_total > profile.unspent_stat_points:
		return {"accepted": false, "reason": "NOT ENOUGH POINTS"}
	var current := profile.permanent_stat_values()
	var ratio_enabled := StatAllocationPolicyScript.profile_uses_ratio(base)
	var policy: Dictionary = StatAllocationPolicyScript.evaluate_transition(current, _permanent_values(base, proposed), profile.level, ratio_enabled)
	if pending_total == 0 and not bool(policy.get("accepted", false)):
		policy["accepted"] = true
		policy["reason"] = "EXISTING BUILD OUTSIDE LIMIT"
	policy["pending_total"] = pending_total
	policy["pending_values"] = pending.duplicate()
	policy["current_values"] = _permanent_values(base, proposed)
	policy["committed_values"] = current
	policy["remaining_points"] = profile.unspent_stat_points - pending_total
	policy["ratio_enabled"] = ratio_enabled
	policy["minimum_indices"] = StatAllocationPolicyScript.minimum_stat_indices(policy["current_values"])
	policy["ceiling"] = StatAllocationPolicyScript.current_ceiling(policy["current_values"], profile.level, ratio_enabled)
	policy["spread_cap"] = StatAllocationPolicyScript.spread_cap_for_level(profile.level)
	policy["window_start"] = maxi(int(policy["ceiling"]) - StatAllocationPolicyScript.MAX_BAR_TICKS, 0)
	return policy


static func draft_presentation(profile: PlayerProfile, pending: Array[int]) -> Dictionary:
	var policy := validate_draft(profile, pending)
	var can_add: Array[bool] = []
	for stat_index in pending.size():
		var add_result: Dictionary = try_add_to_draft(profile, pending, stat_index)
		can_add.append(bool(add_result.get("accepted", false)))
	policy["can_add"] = can_add
	return policy


static func try_add_to_draft(profile: PlayerProfile, pending: Array[int], stat_index: int) -> Dictionary:
	if profile == null or stat_index < 0 or stat_index >= StatAllocationPolicyScript.STAT_NAMES.size():
		return {"accepted": false, "reason": "INVALID STAT"}
	var current: Dictionary = validate_draft(profile, pending)
	if int(current.get("remaining_points", 0)) <= 0:
		return {"accepted": false, "reason": "NO BANKED POINTS"}
	var candidate: Array[int] = pending.duplicate()
	candidate[stat_index] += 1
	return validate_draft(profile, candidate)


static func _permanent_values(base: Array[int], allocation: Array[int]) -> Array[int]:
	var values: Array[int] = []
	for index in base.size():
		values.append(base[index] + allocation[index])
	return values

static func points_remaining(profile: PlayerProfile, pending: Dictionary) -> int:
	if profile == null:
		return 0
	var reserved := 0
	for stat_name in StatsComponent.STAT_NAMES:
		var fallback_key := "SPD" if stat_name == &"AGI" else String(stat_name)
		reserved += maxi(int(pending.get(String(stat_name), pending.get(fallback_key, 0))), 0)
	return maxi(profile.unspent_stat_points - reserved, 0)

static func apply_run_grade(profile: PlayerProfile, grade: String) -> bool:
	if profile == null:
		return false
	var normalized := grade.to_upper()
	if normalized not in ["S", "A", "B", "C", "D", "F"]:
		return false
	var rank_change := 2 if normalized == "S" else 1 if normalized == "A" or normalized == "B" else -1 if normalized == "F" else 0
	profile.difficulty_rank = clampi(profile.difficulty_rank + rank_change, 1, 20)
	profile.last_run_grade = normalized
	return true
