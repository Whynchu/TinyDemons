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

@export_range(1, 99, 1) var points_per_level := 10:
	set(value):
		points_per_level = maxi(value, 1)
		_recalculate()

@export var allocation_profile: AllocationProfile = AllocationProfile.BALANCED:
	set(value):
		allocation_profile = value
		_recalculate()

var vit := 0
var str := 0
var def := 0


func _ready() -> void:
	_recalculate()


func total_stat_points() -> int:
	return level * points_per_level


func get_stat(stat: Stat) -> int:
	match stat:
		Stat.VIT:
			return vit
		Stat.STR:
			return str
		Stat.DEF:
			return def
	return 0


func get_stats() -> Dictionary:
	return {
		"VIT": vit,
		"STR": str,
		"DEF": def,
	}


func _recalculate() -> void:
	var total := total_stat_points()
	var weights := _profile_weights()
	var weight_total := 0.0
	for stat in weights.keys():
		weight_total += float(weights[stat])

	var values := {}
	var fractional_remainders: Array[Dictionary] = []
	var spent := 0
	for stat in [Stat.VIT, Stat.STR, Stat.DEF]:
		var exact_value := (float(total) * float(weights[stat])) / weight_total
		var base_value := int(floor(exact_value))
		values[stat] = base_value
		spent += base_value
		fractional_remainders.append({
			"stat": stat,
			"remainder": exact_value - float(base_value),
		})

	fractional_remainders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["remainder"]), float(b["remainder"])):
			return _stat_priority(a["stat"] as Stat) < _stat_priority(b["stat"] as Stat)
		return float(a["remainder"]) > float(b["remainder"])
	)

	var remainder := total - spent
	for index in remainder:
		var stat: Stat = fractional_remainders[index]["stat"]
		values[stat] += 1

	vit = values[Stat.VIT]
	str = values[Stat.STR]
	def = values[Stat.DEF]
	stats_changed.emit(self)


func _profile_weights() -> Dictionary:
	match allocation_profile:
		AllocationProfile.FAVOR_VIT:
			return {
				Stat.VIT: 6.0,
				Stat.STR: 3.0,
				Stat.DEF: 1.0,
			}
		AllocationProfile.FAVOR_STR:
			return {
				Stat.VIT: 3.0,
				Stat.STR: 6.0,
				Stat.DEF: 1.0,
			}
		AllocationProfile.FAVOR_DEF:
			return {
				Stat.VIT: 4.0,
				Stat.STR: 1.0,
				Stat.DEF: 5.0,
			}
		_:
			return {
				Stat.VIT: 4.0,
				Stat.STR: 3.0,
				Stat.DEF: 3.0,
			}


func _stat_priority(stat: Stat) -> int:
	match stat:
		Stat.VIT:
			return 0
		Stat.STR:
			return 1
		Stat.DEF:
			return 2
	return 99
