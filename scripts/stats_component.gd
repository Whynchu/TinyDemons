@tool
extends Node
class_name StatsComponent

signal stats_changed(component: StatsComponent)

enum Stat {
	VIT,
	STR,
	DEF,
	SPD,
}

enum AllocationProfile {
	BALANCED,
	FAVOR_VIT,
	FAVOR_STR,
	FAVOR_DEF,
	FAVOR_STR_DEF,
}

@export_range(1, 99, 1) var level := 1:
	set(value):
		level = maxi(value, 1)
		_recalculate()

@export_range(1, 99, 1) var base_points := 7:
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
var speed := 0
var manual_allocation_enabled := false
var manual_base_vit := 3
var manual_base_str := 2
var manual_base_def := 2
var manual_base_spd := 1
var manual_vit := 0
var manual_str := 0
var manual_def := 0
var manual_spd := 0


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
		Stat.SPD:
			return speed
	return 0


func get_stats() -> Dictionary:
	return {
		"VIT": vit,
		"STR": strength,
		"DEF": def,
		"SPD": speed,
	}


func configure_manual_growth(base_vit_value: int, base_str_value: int, base_def_value: int, base_spd_value: int, vit_points: int, str_points: int, def_points: int, spd_points: int) -> void:
	manual_allocation_enabled = true
	manual_base_vit = maxi(base_vit_value, 0)
	manual_base_str = maxi(base_str_value, 0)
	manual_base_def = maxi(base_def_value, 0)
	manual_base_spd = maxi(base_spd_value, 0)
	manual_vit = maxi(vit_points, 0)
	manual_str = maxi(str_points, 0)
	manual_def = maxi(def_points, 0)
	manual_spd = maxi(spd_points, 0)
	_recalculate()


func manual_allocation() -> Dictionary:
	return {"VIT": manual_vit, "STR": manual_str, "DEF": manual_def, "SPD": manual_spd}


func _recalculate() -> void:
	var values: Dictionary
	if manual_allocation_enabled:
		values = {
			Stat.VIT: manual_base_vit + manual_vit,
			Stat.STR: manual_base_str + manual_str,
			Stat.DEF: manual_base_def + manual_def,
			Stat.SPD: manual_base_spd + manual_spd,
		}
	else:
		values = _base_profile_values()
		var allocated := int(values[Stat.VIT]) + int(values[Stat.STR]) + int(values[Stat.DEF]) + int(values[Stat.SPD])
		var extra_points := maxi(total_stat_points() - allocated, 0)
		var rng := RandomNumberGenerator.new()
		rng.seed = _growth_seed()
		for point_index in extra_points:
			var stat := _roll_growth_stat(rng, point_index, values)
			values[stat] += 1

	vit = values[Stat.VIT]
	strength = values[Stat.STR]
	def = values[Stat.DEF]
	speed = values[Stat.SPD]
	stats_changed.emit(self)


func _base_profile_values() -> Dictionary:
	match allocation_profile:
		AllocationProfile.FAVOR_VIT:
			return {
				Stat.VIT: 4,
				Stat.STR: 2,
				Stat.DEF: 1,
				Stat.SPD: 3,
			}
		AllocationProfile.FAVOR_STR:
			return {
				Stat.VIT: 2,
				Stat.STR: 4,
				Stat.DEF: 1,
				Stat.SPD: 1,
			}
		AllocationProfile.FAVOR_DEF:
			return {
				Stat.VIT: 3,
				Stat.STR: 1,
				Stat.DEF: 3,
				Stat.SPD: 1,
			}
		AllocationProfile.FAVOR_STR_DEF:
			return {
				Stat.VIT: 1,
				Stat.STR: 3,
				Stat.DEF: 3,
				Stat.SPD: 1,
			}
		_:
			return {
				Stat.VIT: 3,
				Stat.STR: 2,
				Stat.DEF: 2,
				Stat.SPD: 2,
			}


func _growth_weights() -> Dictionary:
	match allocation_profile:
		AllocationProfile.FAVOR_VIT:
			return {
				Stat.VIT: 0.58,
				Stat.STR: 0.22,
				Stat.DEF: 0.10,
				Stat.SPD: 0.10,
			}
		AllocationProfile.FAVOR_STR:
			return {
				Stat.VIT: 0.22,
				Stat.STR: 0.60,
				Stat.DEF: 0.10,
				Stat.SPD: 0.08,
			}
		AllocationProfile.FAVOR_DEF:
			return {
				Stat.VIT: 0.22,
				Stat.STR: 0.10,
				Stat.DEF: 0.60,
				Stat.SPD: 0.08,
			}
		AllocationProfile.FAVOR_STR_DEF:
			return {
				Stat.VIT: 0.10,
				Stat.STR: 0.42,
				Stat.DEF: 0.42,
				Stat.SPD: 0.06,
			}
		_:
			return {
				Stat.VIT: 0.30,
				Stat.STR: 0.28,
				Stat.DEF: 0.28,
				Stat.SPD: 0.14,
			}


func _roll_growth_stat(rng: RandomNumberGenerator, point_index: int, current_values: Dictionary) -> Stat:
	var weights := _growth_weights()
	var weighted_stats: Array[Dictionary] = []
	var total_weight := 0.0
	for stat in [Stat.VIT, Stat.STR, Stat.DEF, Stat.SPD]:
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
