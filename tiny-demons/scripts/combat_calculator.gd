extends RefCounted
class_name CombatCalculator

## Stateless combat formulas shared by player and enemy attacks.
##
## Randomness is supplied by the caller so the gameplay coordinator retains
## control of run-level determinism while this class remains reusable.

class DamageResult extends RefCounted:
	var amount: float
	var critical: bool


static func calculate_damage(
	attacker_stats: StatsComponent,
	defender_stats: StatsComponent,
	attacker_damage_bonus: float,
	defender_defense_bonus: float,
	can_critical: bool,
	rng: RandomNumberGenerator,
	tuning: CombatTuning = null
) -> DamageResult:
	var config := tuning if tuning != null else CombatTuning.new()
	var result := DamageResult.new()
	result.amount = 1.0
	result.critical = false
	if attacker_stats == null:
		return result

	var attacker_str := float(attacker_stats.strength)
	var defender_def := float(defender_stats.def) if defender_stats != null else 0.0
	var raw_damage := config.damage_base + attacker_str + attacker_damage_bonus
	defender_def += defender_defense_bonus
	# Diminishing returns keep DEF useful without letting it erase damage.
	var defense_multiplier := config.defense_scale / (config.defense_scale + maxf(defender_def, 0.0))
	var calculated_damage := raw_damage * defense_multiplier
	var damage_roll := maxf(rng.randf_range(config.damage_roll_min, config.damage_roll_max), config.damage_roll_min)
	var damage := calculated_damage * damage_roll
	if can_critical and rng.randf() < config.critical_hit_chance:
		result.critical = true
		damage *= config.critical_damage_multiplier
	result.amount = maxf(1.0, floorf(damage))
	return result


static func max_health_for_stats(stats: StatsComponent, equipment_health_bonus: float = 0.0, tuning: CombatTuning = null) -> float:
	var config := tuning if tuning != null else CombatTuning.new()
	if stats == null:
		return config.target_health_max
	return config.health_base + float(stats.vit) * config.health_per_vit + float(maxi(stats.level - 1, 0)) * config.health_per_level + equipment_health_bonus
