extends RefCounted
class_name CombatCalculator

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

## Stateless combat formulas shared by player and enemy attacks.
##
## Randomness is supplied by the caller so the gameplay coordinator retains
## control of run-level determinism while this class remains reusable.

class DamageResult extends RefCounted:
	var amount: float
	var critical: bool
	var element: int
	var effectiveness: float
	var immune: bool


static func calculate_damage(
	attacker_stats: StatsComponent,
	defender_stats: StatsComponent,
	_attacker_damage_rate_bonus: float,
	defender_defense_bonus: float,
	can_critical: bool,
	rng: RandomNumberGenerator,
	tuning: CombatTuning = null,
	attack_element: int = ElementCatalogScript.Element.NEUTRAL,
	defense_element: int = ElementCatalogScript.Element.NEUTRAL
) -> DamageResult:
	var config := tuning if tuning != null else CombatTuning.new()
	var result := DamageResult.new()
	_initialize_result(result, attack_element, defense_element)
	if attacker_stats == null:
		return result

	var attacker_str := float(attacker_stats.strength)
	var defender_def := float(defender_stats.def) if defender_stats != null else 0.0
	var raw_damage := config.damage_base + attacker_str * config.damage_per_strength
	defender_def += defender_defense_bonus
	# Diminishing returns keep DEF useful without letting it erase damage.
	var defense_multiplier := config.defense_scale / (config.defense_scale + maxf(defender_def, 0.0))
	var calculated_damage := raw_damage * defense_multiplier
	var damage_roll := maxf(rng.randf_range(config.damage_roll_min, config.damage_roll_max), config.damage_roll_min)
	var damage := calculated_damage * damage_roll
	if can_critical and rng.randf() < config.critical_hit_chance:
		result.critical = true
		damage *= config.critical_damage_multiplier
	_finalize_damage(result, damage)
	return result


static func max_health_for_stats(stats: StatsComponent, _equipment_health_rate_bonus: float = 0.0, tuning: CombatTuning = null) -> float:
	if stats == null:
		return (tuning if tuning != null else CombatTuning.new()).target_health_max
	var snapshot := CombatStatSnapshot.from_components(stats)
	return max_health_for_snapshot(snapshot, tuning)


static func max_health_for_snapshot(snapshot: CombatStatSnapshot, tuning: CombatTuning = null) -> float:
	var config := tuning if tuning != null else CombatTuning.new()
	if snapshot == null:
		return config.target_health_max
	var core_health := config.health_base + float(maxi(snapshot.level - 1, 0)) * config.health_per_level
	var core_health_bonus := core_health * maxf(snapshot.core_health_rate_bonus, 0.0)
	var base_vit_health := float(snapshot.vit) * config.health_per_vit + core_health * float(snapshot.vit) * config.health_vit_core_rate
	var vit_health := base_vit_health * (1.0 + maxf(snapshot.vit_health_multiplier_bonus, 0.0))
	var calculated_health := core_health + core_health_bonus + vit_health
	return calculated_health


static func calculate_snapshot_damage(
	attacker: CombatStatSnapshot,
	defender: CombatStatSnapshot,
	can_critical: bool,
	rng: RandomNumberGenerator,
	tuning: CombatTuning = null,
	strength_damage_scale: float = 1.0,
	attack_element: int = ElementCatalogScript.Element.NEUTRAL,
	defense_element: int = ElementCatalogScript.Element.NEUTRAL
) -> DamageResult:
	var config := tuning if tuning != null else CombatTuning.new()
	var result := DamageResult.new()
	_initialize_result(result, attack_element, defense_element)
	if attacker == null:
		return result
	var raw_damage := attack_power_for_snapshot(attacker, config, strength_damage_scale)
	var defender_def := float(defender.def) if defender != null else 0.0
	var defense_multiplier := config.defense_scale / (config.defense_scale + maxf(defender_def, 0.0))
	var damage := raw_damage * defense_multiplier * maxf(rng.randf_range(config.damage_roll_min, config.damage_roll_max), config.damage_roll_min)
	if can_critical and rng.randf() < config.critical_hit_chance:
		result.critical = true
		damage *= config.critical_damage_multiplier
	_finalize_damage(result, damage)
	return result


static func _initialize_result(result: DamageResult, attack_element: int, defense_element: int) -> void:
	result.amount = 1.0
	result.critical = false
	result.element = ElementCatalogScript.normalize(attack_element)
	result.effectiveness = ElementCatalogScript.effectiveness(attack_element, defense_element)
	result.immune = is_zero_approx(result.effectiveness)


static func _finalize_damage(result: DamageResult, damage: float) -> void:
	if result.immune:
		result.amount = 0.0
		return
	result.amount = maxf(1.0, floorf(damage * result.effectiveness))


static func attack_power_for_snapshot(snapshot: CombatStatSnapshot, tuning: CombatTuning = null, strength_damage_scale: float = -1.0) -> float:
	var config := tuning if tuning != null else CombatTuning.new()
	if snapshot == null:
		return config.damage_base
	var scale := config.damage_per_strength if strength_damage_scale < 0.0 else strength_damage_scale
	return config.damage_base + snapshot.strength * scale
