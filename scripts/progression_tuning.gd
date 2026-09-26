extends Resource
class_name ProgressionTuning

@export var xp_base := 100.0
@export var xp_scale := 20.0
@export var xp_exponent := 1.4
@export var point_band_max_levels := PackedInt32Array([5, 10, 20, 35, 99])
@export var point_band_awards := PackedInt32Array([1, 2, 3, 4, 5])
@export_range(0.0, 1.0, 0.05) var enemy_stat_growth_multiplier := 0.5


func xp_required_for_level(level: int) -> int:
	var current_level := maxi(level, 1)
	# Level 1 starts at a meaningful 100 XP requirement. The exponent supplies
	# the main grind, while the smaller ramp keeps later levels from flattening
	# into a simple percentage increase.
	return maxi(1, roundi(xp_base * pow(float(current_level), xp_exponent) + xp_scale * float(maxi(current_level - 1, 0))))


func stat_points_for_level(level: int) -> int:
	var count := mini(point_band_max_levels.size(), point_band_awards.size())
	for index in count:
		if level <= point_band_max_levels[index]:
			return clampi(point_band_awards[index], 0, 5)
	return clampi(point_band_awards[count - 1], 0, 5) if count > 0 else 0


func cumulative_stat_points_at_level(level: int) -> int:
	var total := 0
	for reached_level in range(2, clampi(level, 1, 99) + 1):
		total += stat_points_for_level(reached_level)
	return total


func cumulative_enemy_stat_points_at_level(level: int) -> int:
	return floori(float(cumulative_stat_points_at_level(level)) * clampf(enemy_stat_growth_multiplier, 0.0, 1.0))
