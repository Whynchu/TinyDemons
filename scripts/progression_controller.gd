extends RefCounted
class_name ProgressionController

## Domain-facing progression commands. This type deliberately has no scene/UI
## dependencies so hub screens and gameplay can share the same rules.

static func award_xp(profile: PlayerProfile, amount: int, tuning: ProgressionTuning = null) -> Dictionary:
	if profile == null:
		return {"xp": 0, "levels": 0, "points": 0, "level": 0}
	return profile.award_xp(amount, tuning)

static func allocate_stats(profile: PlayerProfile, allocations: Dictionary) -> Dictionary:
	var result := {"spent": 0, "remaining": 0, "changed": false}
	if profile == null:
		return result
	for stat_name in [&"VIT", &"STR", &"DEF", &"SPD"]:
		var amount := maxi(int(allocations.get(String(stat_name), 0)), 0)
		if amount <= 0:
			continue
		var before := profile.unspent_stat_points
		if profile.allocate_stat(stat_name, amount):
			result["spent"] = int(result["spent"]) + (before - profile.unspent_stat_points)
			result["changed"] = true
	result["remaining"] = profile.unspent_stat_points
	return result

static func points_remaining(profile: PlayerProfile, pending: Dictionary) -> int:
	if profile == null:
		return 0
	var reserved := 0
	for stat_name in [&"VIT", &"STR", &"DEF", &"SPD"]:
		reserved += maxi(int(pending.get(String(stat_name), 0)), 0)
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
