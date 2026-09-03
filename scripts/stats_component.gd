@tool
extends Node
class_name StatsComponent

signal stats_changed(component: StatsComponent)

enum Stat {
	VIT,
	STR,
	DEF,
	AGI,
	INT,
	MND,
}

const STAT_NAMES: Array[StringName] = [&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"]
const LEGACY_SPEED_NAME: StringName = &"SPD"

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
var agi := 0
var intelligence := 0
var mnd := 0
## Temporary compatibility mirror for callers that still read SPD directly.
var speed:
	get:
		return agi
	set(value):
		agi = maxi(int(value), 0)
var manual_allocation_enabled := false
var manual_base_vit := 2
var manual_base_str := 2
var manual_base_def := 2
var manual_base_agi := 2
var manual_base_int := 2
var manual_base_mnd := 2
var manual_vit := 0
var manual_str := 0
var manual_def := 0
var manual_agi := 0
var manual_int := 0
var manual_mnd := 0
## Temporary compatibility aliases for schema-8 callers.
var manual_base_spd:
	get:
		return manual_base_agi
	set(value):
		manual_base_agi = maxi(int(value), 0)
var manual_spd:
	get:
		return manual_agi
	set(value):
		manual_agi = maxi(int(value), 0)
var enemy_variant_profile_enabled := false
var enemy_variant_base_values: Dictionary = {}
var enemy_variant_growth_weights: Dictionary = {}
var enemy_variant_seed_token := &""


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
		Stat.AGI:
			return agi
		Stat.INT:
			return intelligence
		Stat.MND:
			return mnd
	return 0


func get_stats() -> Dictionary:
	return {
		"VIT": vit,
		"STR": strength,
		"DEF": def,
		"AGI": agi,
		"INT": intelligence,
		"MND": mnd,
		# Temporary read compatibility for pre-schema-9 consumers.
		"SPD": agi,
	}


func configure_manual_growth(base_vit_value: int, base_str_value: int, base_def_value: int, base_agi_value: int, vit_points: int, str_points: int, def_points: int, agi_points: int, base_int_value: int = 2, base_mnd_value: int = 2, int_points: int = 0, mnd_points: int = 0) -> void:
	manual_allocation_enabled = true
	manual_base_vit = maxi(base_vit_value, 0)
	manual_base_str = maxi(base_str_value, 0)
	manual_base_def = maxi(base_def_value, 0)
	manual_base_agi = maxi(base_agi_value, 0)
	manual_base_int = maxi(base_int_value, 0)
	manual_base_mnd = maxi(base_mnd_value, 0)
	manual_vit = maxi(vit_points, 0)
	manual_str = maxi(str_points, 0)
	manual_def = maxi(def_points, 0)
	manual_agi = maxi(agi_points, 0)
	manual_int = maxi(int_points, 0)
	manual_mnd = maxi(mnd_points, 0)
	_recalculate()


func manual_allocation() -> Dictionary:
	return {
		"VIT": manual_vit,
		"STR": manual_str,
		"DEF": manual_def,
		"AGI": manual_agi,
		"INT": manual_int,
		"MND": manual_mnd,
		"SPD": manual_agi,
	}


func apply_enemy_variant_profile(base_values: Dictionary, growth_weights: Dictionary, seed_token: StringName) -> void:
	## Enemy variants use the same deterministic growth algorithm as player
	## profiles, but keep their authored level-one values and weights separate
	## from the player's allocation choices.
	enemy_variant_profile_enabled = true
	enemy_variant_base_values = {
		Stat.VIT: maxi(int(base_values.get("VIT", 0)), 0),
		Stat.STR: maxi(int(base_values.get("STR", 0)), 0),
		Stat.DEF: maxi(int(base_values.get("DEF", 0)), 0),
		Stat.AGI: maxi(int(base_values.get("AGI", base_values.get("SPD", 0))), 0),
		Stat.INT: maxi(int(base_values.get("INT", 0)), 0),
		Stat.MND: maxi(int(base_values.get("MND", 0)), 0),
	}
	enemy_variant_growth_weights = {
		Stat.VIT: maxf(float(growth_weights.get("VIT", 0.0)), 0.0),
		Stat.STR: maxf(float(growth_weights.get("STR", 0.0)), 0.0),
		Stat.DEF: maxf(float(growth_weights.get("DEF", 0.0)), 0.0),
		Stat.AGI: maxf(float(growth_weights.get("AGI", growth_weights.get("SPD", 0.0))), 0.0),
		Stat.INT: maxf(float(growth_weights.get("INT", 0.0)), 0.0),
		Stat.MND: maxf(float(growth_weights.get("MND", 0.0)), 0.0),
	}
	enemy_variant_seed_token = seed_token
	_recalculate()


func clear_enemy_variant_profile() -> void:
	enemy_variant_profile_enabled = false
	enemy_variant_base_values.clear()
	enemy_variant_growth_weights.clear()
	enemy_variant_seed_token = &""
	_recalculate()


func _recalculate() -> void:
	var values: Dictionary
	if manual_allocation_enabled:
		values = {
			Stat.VIT: manual_base_vit + manual_vit,
			Stat.STR: manual_base_str + manual_str,
			Stat.DEF: manual_base_def + manual_def,
			Stat.AGI: manual_base_agi + manual_agi,
			Stat.INT: manual_base_int + manual_int,
			Stat.MND: manual_base_mnd + manual_mnd,
		}
	else:
		values = enemy_variant_base_values.duplicate() if enemy_variant_profile_enabled else _base_profile_values()
		var allocated := 0
		for stat in STAT_NAMES:
			allocated += int(values[_stat_from_name(stat)])
		var extra_points := maxi(total_stat_points() - allocated, 0)
		var rng := RandomNumberGenerator.new()
		rng.seed = _growth_seed()
		for point_index in extra_points:
			var stat := _roll_growth_stat(rng, point_index, values)
			values[stat] += 1

	vit = values[Stat.VIT]
	strength = values[Stat.STR]
	def = values[Stat.DEF]
	agi = values[Stat.AGI]
	intelligence = values[Stat.INT]
	mnd = values[Stat.MND]
	stats_changed.emit(self)


func _stat_from_name(stat_name: StringName) -> Stat:
	match stat_name:
		&"VIT":
			return Stat.VIT
		&"STR":
			return Stat.STR
		&"DEF":
			return Stat.DEF
		&"AGI":
			return Stat.AGI
		&"INT":
			return Stat.INT
		&"MND":
			return Stat.MND
	return Stat.VIT


func _base_profile_values() -> Dictionary:
	match allocation_profile:
		AllocationProfile.FAVOR_VIT:
			return {
				Stat.VIT: 4,
				Stat.STR: 2,
				Stat.DEF: 1,
				Stat.AGI: 3,
				Stat.INT: 1,
				Stat.MND: 1,
			}
		AllocationProfile.FAVOR_STR:
			return {
				Stat.VIT: 2,
				Stat.STR: 4,
				Stat.DEF: 1,
				Stat.AGI: 1,
				Stat.INT: 1,
				Stat.MND: 1,
			}
		AllocationProfile.FAVOR_DEF:
			return {
				Stat.VIT: 3,
				Stat.STR: 1,
				Stat.DEF: 3,
				Stat.AGI: 1,
				Stat.INT: 1,
				Stat.MND: 1,
			}
		AllocationProfile.FAVOR_STR_DEF:
			return {
				Stat.VIT: 1,
				Stat.STR: 3,
				Stat.DEF: 3,
				Stat.AGI: 1,
				Stat.INT: 1,
				Stat.MND: 1,
			}
		_:
			return {
				Stat.VIT: 2,
				Stat.STR: 2,
				Stat.DEF: 2,
				Stat.AGI: 2,
				Stat.INT: 2,
				Stat.MND: 2,
			}


func _growth_weights() -> Dictionary:
	if enemy_variant_profile_enabled:
		return enemy_variant_growth_weights
	match allocation_profile:
		AllocationProfile.FAVOR_VIT:
			return {
				Stat.VIT: 0.58,
				Stat.STR: 0.22,
				Stat.DEF: 0.10,
				Stat.AGI: 0.10,
				Stat.INT: 0.0,
				Stat.MND: 0.0,
			}
		AllocationProfile.FAVOR_STR:
			return {
				Stat.VIT: 0.22,
				Stat.STR: 0.60,
				Stat.DEF: 0.10,
				Stat.AGI: 0.08,
				Stat.INT: 0.0,
				Stat.MND: 0.0,
			}
		AllocationProfile.FAVOR_DEF:
			return {
				Stat.VIT: 0.22,
				Stat.STR: 0.10,
				Stat.DEF: 0.60,
				Stat.AGI: 0.08,
				Stat.INT: 0.0,
				Stat.MND: 0.0,
			}
		AllocationProfile.FAVOR_STR_DEF:
			return {
				Stat.VIT: 0.10,
				Stat.STR: 0.42,
				Stat.DEF: 0.42,
				Stat.AGI: 0.06,
				Stat.INT: 0.0,
				Stat.MND: 0.0,
			}
		_:
			return {
				Stat.VIT: 0.30,
				Stat.STR: 0.28,
				Stat.DEF: 0.28,
				Stat.AGI: 0.14,
				Stat.INT: 0.0,
				Stat.MND: 0.0,
			}


func _roll_growth_stat(rng: RandomNumberGenerator, point_index: int, current_values: Dictionary) -> Stat:
	var weights := _growth_weights()
	var weighted_stats: Array[Dictionary] = []
	var total_weight := 0.0
	for stat in [Stat.VIT, Stat.STR, Stat.DEF, Stat.AGI, Stat.INT, Stat.MND]:
		var base_weight := float(weights[stat])
		if base_weight <= 0.0:
			continue
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
	# sequence instead of rerolling every previously allocated stat point. Enemy
	# variants use their token instead of the player allocation enum so two
	# variants on the same node path still receive different stable sequences.
	var profile_seed := String(enemy_variant_seed_token).hash() if enemy_variant_profile_enabled else allocation_profile * 197
	return int(points_per_level * 313 + base_points * 733 + profile_seed + path_hash)
