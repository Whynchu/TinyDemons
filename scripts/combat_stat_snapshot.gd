extends RefCounted
class_name CombatStatSnapshot

var level := 1
var vit := 0.0
var strength := 0.0
var def := 0.0
var speed := 0.0
var gear_vit := 0.0
var gear_strength := 0.0
var gear_def := 0.0
var gear_speed := 0.0
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
	snapshot.gear_speed = equipment.speed_bonus if equipment != null else 0.0
	snapshot.core_health_rate_bonus = equipment.core_health_rate_bonus if equipment != null else 0.0
	snapshot.vit_health_multiplier_bonus = equipment.vit_health_multiplier_bonus if equipment != null else 0.0
	snapshot.vit = stats.vit + snapshot.gear_vit
	snapshot.strength = stats.strength + snapshot.gear_strength
	snapshot.def = stats.def + snapshot.gear_def
	snapshot.speed = maxf(float(stats.speed) + snapshot.gear_speed, 0.0)
	return snapshot
