extends RefCounted
class_name CombatStatSnapshot

var level := 1
var vit := 0.0
var strength := 0.0
var def := 0.0
var agi := 0.0
var intelligence := 0.0
var mnd := 0.0
## Temporary compatibility mirror for callers that still read SPD directly.
var speed:
	get:
		return agi
	set(value):
		agi = maxf(float(value), 0.0)
var gear_vit := 0.0
var gear_strength := 0.0
var gear_def := 0.0
var gear_agi := 0.0
var gear_intelligence := 0.0
var gear_mnd := 0.0
var gear_speed:
	get:
		return gear_agi
	set(value):
		gear_agi = float(value)
var gear_vit_rate := 0.0
var gear_strength_rate := 0.0
var gear_def_rate := 0.0
var gear_agi_rate := 0.0
var gear_intelligence_rate := 0.0
var gear_mnd_rate := 0.0
var gear_speed_rate:
	get:
		return gear_agi_rate
	set(value):
		gear_agi_rate = float(value)
var core_health_rate_bonus := 0.0
var vit_health_multiplier_bonus := 0.0


static func from_components(stats: StatsComponent, equipment: EquipmentComponent = null) -> CombatStatSnapshot:
	var snapshot := CombatStatSnapshot.new()
	if stats == null:
		return snapshot
	snapshot.level = stats.level
	snapshot.gear_vit = equipment.vitality_bonus if equipment != null else 0.0
	snapshot.gear_strength = equipment.strength_bonus if equipment != null else 0.0
	snapshot.gear_def = equipment.defense_bonus if equipment != null else 0.0
	snapshot.gear_agi = equipment.agi_bonus if equipment != null else 0.0
	snapshot.gear_intelligence = equipment.intelligence_bonus if equipment != null else 0.0
	snapshot.gear_mnd = equipment.mnd_bonus if equipment != null else 0.0
	snapshot.gear_vit_rate = equipment.vitality_rate_bonus if equipment != null else 0.0
	snapshot.gear_strength_rate = equipment.strength_rate_bonus if equipment != null else 0.0
	snapshot.gear_def_rate = equipment.defense_rate_bonus if equipment != null else 0.0
	snapshot.gear_agi_rate = equipment.agi_rate_bonus if equipment != null else 0.0
	snapshot.gear_intelligence_rate = equipment.intelligence_rate_bonus if equipment != null else 0.0
	snapshot.gear_mnd_rate = equipment.mnd_rate_bonus if equipment != null else 0.0
	snapshot.core_health_rate_bonus = equipment.core_health_rate_bonus if equipment != null else 0.0
	snapshot.vit_health_multiplier_bonus = equipment.vit_health_multiplier_bonus if equipment != null else 0.0
	# Flat gear points land first; rarity then buffs the resulting affected
	# player stat. This keeps the two parts of the tier package visible and
	# deterministic in the hub and in combat.
	snapshot.vit = (float(stats.vit) + snapshot.gear_vit) * (1.0 + snapshot.gear_vit_rate)
	snapshot.strength = (float(stats.strength) + snapshot.gear_strength) * (1.0 + snapshot.gear_strength_rate)
	snapshot.def = (float(stats.def) + snapshot.gear_def) * (1.0 + snapshot.gear_def_rate)
	snapshot.agi = maxf((float(stats.agi) + snapshot.gear_agi) * (1.0 + snapshot.gear_agi_rate), 0.0)
	snapshot.intelligence = maxf((float(stats.intelligence) + snapshot.gear_intelligence) * (1.0 + snapshot.gear_intelligence_rate), 0.0)
	snapshot.mnd = maxf((float(stats.mnd) + snapshot.gear_mnd) * (1.0 + snapshot.gear_mnd_rate), 0.0)
	return snapshot


func debug_breakdown(tuning: CombatTuning = null) -> Dictionary:
	## Compact, read-only balance-review data. Keeping this on the shared
	## snapshot prevents debug output from growing a second stat calculation
	## path that can disagree with combat or the menus.
	return {
		"LV": level,
		"VIT": vit,
		"STR": strength,
		"DEF": def,
		"AGI": agi,
		"INT": intelligence,
		"MND": mnd,
		"HP": CombatCalculator.max_health_for_snapshot(self, tuning),
		"P.ATK": CombatCalculator.attack_power_for_snapshot(self, tuning),
		"P.DEF": CombatCalculator.physical_defense_for_snapshot(self),
		"M.ATK": CombatCalculator.magic_power_for_snapshot(self, tuning),
		"M.DEF": CombatCalculator.magic_defense_for_snapshot(self),
	}


func debug_summary(tuning: CombatTuning = null) -> String:
	var values := debug_breakdown(tuning)
	return "LV %d | VIT %.1f STR %.1f DEF %.1f AGI %.1f INT %.1f MND %.1f | HP %.1f P.ATK %.1f P.DEF %.2f M.ATK %.1f M.DEF %.2f" % [
		int(values["LV"]), float(values["VIT"]), float(values["STR"]), float(values["DEF"]), float(values["AGI"]), float(values["INT"]), float(values["MND"]),
		float(values["HP"]), float(values["P.ATK"]), float(values["P.DEF"]), float(values["M.ATK"]), float(values["M.DEF"]),
	]
