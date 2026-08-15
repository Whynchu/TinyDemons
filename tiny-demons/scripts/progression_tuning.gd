extends Resource
class_name ProgressionTuning

@export var xp_base := 20.0
@export var xp_scale := 12.0
@export var xp_exponent := 1.6
@export var point_band_max_levels := PackedInt32Array([5, 10, 20, 35, 99])
@export var point_band_awards := PackedInt32Array([1, 2, 3, 4, 5])


func xp_required_for_level(level: int) -> int:
	return maxi(1, roundi(xp_base + xp_scale * pow(float(maxi(level, 1)), xp_exponent)))


func stat_points_for_level(level: int) -> int:
	var count := mini(point_band_max_levels.size(), point_band_awards.size())
	for index in count:
		if level <= point_band_max_levels[index]:
			return clampi(point_band_awards[index], 0, 5)
	return clampi(point_band_awards[count - 1], 0, 5) if count > 0 else 0
