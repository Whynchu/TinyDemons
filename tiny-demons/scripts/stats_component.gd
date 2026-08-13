@tool
extends Node
class_name StatsComponent

signal stats_changed(component: StatsComponent)

enum Stat {
	VIT,
	STR,
	DEF,
}

enum AllocationProfile {
	BALANCED,
	FAVOR_VIT,
	FAVOR_STR,
	FAVOR_DEF,
}

@export_range(1, 99, 1) var level := 1:
	set(value):
		level = maxi(value, 1)
		_recalculate()

@export_range(1, 99, 1) var base_points := 10:
	set(value):
		base_points = maxi(value, 1)
		_recalculate()

@export_range(1, 99, 1) var points_per_level := 1:
	set(value):
		points_per_level = maxi(value, 1)
		_recalculate()

@export var allocation_profile: AllocationProfile = AllocationProfile.BALANCED:
	set(value):
		allocation_profile = value
		_recalculate()

var vit := 0
var strength := 0
var def := 0


func _ready() -> void:
	_recalculate()


func total_stat_points() -> int:
	return base_points + ((level - 1) * points_per_level)


func get_stat(stat: Stat) -> int:
	match stat:
		Stat.VIT:
			return vit
		Stat.STR:
			return strength
		Stat.DEF:
			return def
	return 0


func get_stats() -> Dictionary:
	return {
		"VIT": vit,
		"STR": strength,
		"DEF": def,
	}


func _recalculate() -> void:
	var values: Dictionary = _base_profile_values()
	var allocated := int(values[Stat.VIT]) + int(values[Stat.STR]) + int(values[Stat.DEF])
	var extra_points := maxi(total_stat_points() - allocated, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = _growth_seed()
	for point_index in extra_points:
		var stat := _roll_growth_stat(rng, point_index, values)
		values[stat] += 1

	vit = values[Stat.VIT]
	strength = values[Stat.STR]
	def = values[Stat.DEF]
	stats_changed.emit(self)


func _base_profile_values() -> Dictionary:
	match allocation_profile:
		AllocationProfile.FAVOR_VIT:
			return {
				Stat.VIT: 6,
				Stat.STR: 3,
				Stat.DEF: 1,
			}
		AllocationProfile.FAVOR_STR:
			return {
				Stat.VIT: 3,
				Stat.STR: 6,
				Stat.DEF: 1,
			}
		AllocationProfile.FAVOR_DEF:
			return {
				Stat.VIT: 4,
				Stat.STR: 1,
				Stat.DEF: 5,
			}
		_:
			return {
				Stat.VIT: 4,
				Stat.STR: 3,
				Stat.DEF: 3,
			}


func _growth_weights() -> Dictionary:
	match allocation_profile:
		AllocationProfile.FAVOR_VIT:
			return {
				Stat.VIT: 0.64,
				Stat.STR: 0.24,
				Stat.DEF: 0.12,
			}
		AllocationProfile.FAVOR_STR:
			return {
				Stat.VIT: 0.24,
				Stat.STR: 0.64,
				Stat.DEF: 0.12,
			}
		AllocationProfile.FAVOR_DEF:
			return {
				Stat.VIT: 0.24,
				Stat.STR: 0.12,
				Stat.DEF: 0.64,
			}
		_:
			return {
				Stat.VIT: 0.34,
				Stat.STR: 0.33,
				Stat.DEF: 0.33,
			}


func _roll_growth_stat(rng: RandomNumberGenerator, point_index: int, current_values: Dictionary) -> Stat:
	var weights := _growth_weights()
	var weighted_stats: Array[Dictionary] = []
	var total_weight := 0.0
	for stat in [Stat.VIT, Stat.STR, Stat.DEF]:
		var base_weight := float(weights[stat])
		var current_value := int(current_values[stat])
		var variance := rng.randf_range(-0.06, 0.06)
		var anti_run_bias := 1.0 / (1.0 + maxf(float(current_value - 1), 0.0) * 0.04)
		var point_curve := 1.0 + (float(point_index) * 0.003)
		var final_weight := maxf((base_weight + variance) * anti_run_bias * point_curve, 0.01)
		weighted_stats.append({
			"stat": stat,
			"weight": final_weight,
		})
		total_weight += final_weight

	var roll := rng.randf_range(0.0, total_weight)
	for entry in weighted_stats:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry["stat"] as Stat
	return weighted_stats.back()["stat"] as Stat


func _growth_seed() -> int:
	var path_hash := 0
	if not is_inside_tree():
		path_hash = String(name).hash()
	else:
		path_hash = str(get_path()).hash()
	# Keep one stable growth sequence per actor/profile. Leveling extends that
	# sequence instead of rerolling every previously allocated stat point.
	return int(points_per_level * 313 + base_points * 733 + allocation_profile * 197 + path_hash)


func _stat_priority(stat: Stat) -> int:
	match stat:
		Stat.VIT:
			return 0
		Stat.STR:
			return 1
		Stat.DEF:
			return 2
	return 99
