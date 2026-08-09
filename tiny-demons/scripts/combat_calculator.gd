extends RefCounted
class_name CombatCalculator

## Stateless combat formulas shared by player and enemy attacks.
##
## Randomness is supplied by the caller so the gameplay coordinator retains
## control of run-level determinism while this class remains reusable.

const HEALTH_BASE := 8.0
const HEALTH_PER_VIT := 2.0
const DAMAGE_BASE := 2.0
const DAMAGE_DEFENSE_SCALE := 12.0
const DAMAGE_ROLL_MIN := 0.85
const DAMAGE_ROLL_MAX := 1.15
const CRITICAL_HIT_CHANCE := 0.10
const CRITICAL_DAMAGE_MULTIPLIER := 1.5
const TARGET_HEALTH_MAX := 10.0


class DamageResult extends RefCounted:
	var amount: float
	var critical: bool


static func calculate_damage(
	attacker_stats: StatsComponent,
	defender_stats: StatsComponent,
	attacker_damage_bonus: float,
	defender_defense_bonus: float,
	can_critical: bool,
	rng: RandomNumberGenerator
) -> DamageResult:
	var result := DamageResult.new()
	result.amount = 1.0
	result.critical = false
	if attacker_stats == null:
		return result

	var attacker_str := float(attacker_stats.strength)
	var defender_def := float(defender_stats.def) if defender_stats != null else 0.0
	var raw_damage := DAMAGE_BASE + attacker_str + attacker_damage_bonus
	defender_def += defender_defense_bonus
	# Diminishing returns keep DEF useful without letting it erase damage.
	var defense_multiplier := DAMAGE_DEFENSE_SCALE / (DAMAGE_DEFENSE_SCALE + maxf(defender_def, 0.0))
	var calculated_damage := raw_damage * defense_multiplier
	var damage_roll := maxf(rng.randf_range(DAMAGE_ROLL_MIN, DAMAGE_ROLL_MAX), DAMAGE_ROLL_MIN)
	var damage := calculated_damage * damage_roll
	if can_critical and rng.randf() < CRITICAL_HIT_CHANCE:
		result.critical = true
		damage *= CRITICAL_DAMAGE_MULTIPLIER
	result.amount = maxf(1.0, floorf(damage))
	return result


static func max_health_for_stats(stats: StatsComponent, equipment_health_bonus: float = 0.0) -> float:
	if stats == null:
		return TARGET_HEALTH_MAX
	return HEALTH_BASE + float(stats.vit) * HEALTH_PER_VIT + equipment_health_bonus
