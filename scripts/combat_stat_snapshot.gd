extends RefCounted
class_name CombatStatSnapshot

var level := 1
var vit := 0
var strength := 0
var def := 0
var speed := 0
var gear_vit := 0
var gear_strength := 0
var gear_def := 0
var gear_speed := 0
var gear_health_rate := 0.0
var gear_damage_rate := 0.0
var core_health_rate_bonus := 0.0
var vit_health_multiplier_bonus := 0.0


static func from_components(stats: StatsComponent, equipment: EquipmentComponent = null) -> CombatStatSnapshot:
	var snapshot := CombatStatSnapshot.new()
	if stats == null:
		return snapshot
	snapshot.level = stats.level
	snapshot.gear_vit = _gear_points(stats.vit, equipment.vitality_bonus) if equipment != null else 0
	snapshot.gear_strength = _gear_points(stats.strength, equipment.strength_bonus) if equipment != null else 0
	snapshot.gear_def = _gear_points(stats.def, equipment.defense_bonus) if equipment != null else 0
	snapshot.gear_speed = _gear_points_signed(stats.speed, equipment.speed_bonus) if equipment != null else 0
	snapshot.gear_health_rate = equipment.health_rate_bonus if equipment != null else 0.0
	snapshot.gear_damage_rate = equipment.damage_rate_bonus if equipment != null else 0.0
	snapshot.core_health_rate_bonus = equipment.core_health_rate_bonus if equipment != null else 0.0
	snapshot.vit_health_multiplier_bonus = equipment.vit_health_multiplier_bonus if equipment != null else 0.0
	snapshot.vit = stats.vit + snapshot.gear_vit
	snapshot.strength = stats.strength + snapshot.gear_strength
	snapshot.def = stats.def + snapshot.gear_def
	snapshot.speed = maxi(stats.speed + snapshot.gear_speed, 0)
	return snapshot


static func _gear_points(base: int, bonus: float) -> int:
	if bonus <= 0.0:
		return 0
	return maxi(roundi(float(base) * bonus), 1)


static func _gear_points_signed(base: int, bonus: float) -> int:
	if bonus == 0.0:
		return 0
	var points := roundi(float(base) * bonus)
	if points == 0:
		points = 1 if bonus > 0.0 else -1
	return clampi(points, -maxi(base, 1), 99)
