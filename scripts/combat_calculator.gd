extends RefCounted
class_name CombatCalculator

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const CombatDamageRequestScript = preload("res://scripts/combat_damage_request.gd")

## Stateless combat formulas shared by player and enemy attacks.
##
## Randomness is supplied by the caller so the gameplay coordinator retains
## control of run-level determinism while this class remains reusable. Every
## request resolves to one packet: component mitigation happens first, then
## one roll, one critical result, and one element matchup are applied.

class DamageResult extends RefCounted:
	var amount: float
	var critical: bool
	var element: int
	var effectiveness: float
	var immune: bool
	var category: int = CombatDamageRequestScript.DamageCategory.PHYSICAL
	var contract_id: StringName = CombatDamageRequestScript.CONTRACT_PHYSICAL
	var physical_raw := 0.0
	var magic_raw := 0.0
	var physical_after_mitigation := 0.0
	var magic_after_mitigation := 0.0


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
	var request := CombatDamageRequestScript.physical(config.damage_base, config.damage_per_strength, attack_element, defense_element, can_critical)
	request.defense_bonus = defender_defense_bonus
	return calculate_request(request, CombatStatSnapshot.from_components(attacker_stats), CombatStatSnapshot.from_components(defender_stats), rng, config)


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
	var scale := config.damage_per_strength if strength_damage_scale < 0.0 else strength_damage_scale
	var request := CombatDamageRequestScript.physical(config.damage_base, scale, attack_element, defense_element, can_critical)
	return calculate_request(request, attacker, defender, rng, config)


static func calculate_snapshot_magic_damage(
	attacker: CombatStatSnapshot,
	defender: CombatStatSnapshot,
	can_critical: bool,
	rng: RandomNumberGenerator,
	tuning: CombatTuning = null,
	intelligence_damage_scale: float = -1.0,
	magic_base_power: float = -1.0,
	attack_element: int = ElementCatalogScript.Element.NEUTRAL,
	defense_element: int = ElementCatalogScript.Element.NEUTRAL
) -> DamageResult:
	var config := tuning if tuning != null else CombatTuning.new()
	var scale := config.magic_per_int if intelligence_damage_scale < 0.0 else intelligence_damage_scale
	var base_power := config.magic_base if magic_base_power < 0.0 else magic_base_power
	var request := CombatDamageRequestScript.magic(base_power, scale, attack_element, defense_element, can_critical)
	return calculate_request(request, attacker, defender, rng, config)


static func calculate_request(
	request: RefCounted,
	attacker: CombatStatSnapshot,
	defender: CombatStatSnapshot,
	rng: RandomNumberGenerator,
	tuning: CombatTuning = null
) -> DamageResult:
	var config := tuning if tuning != null else CombatTuning.new()
	var result := DamageResult.new()
	if request != null:
		_initialize_result(result, request)
	else:
		_initialize_result(result, CombatDamageRequestScript.physical(config.damage_base, config.damage_per_strength))
	if request == null or attacker == null:
		return result

	var uses_physical: bool = request.category != CombatDamageRequestScript.DamageCategory.MAGIC
	var uses_magic: bool = request.category != CombatDamageRequestScript.DamageCategory.PHYSICAL
	var physical_raw: float = request.physical_base + attacker.strength * request.physical_stat_scale if uses_physical else 0.0
	var magic_raw: float = request.magic_base + attacker.intelligence * request.magic_stat_scale if uses_magic else 0.0
	var defender_def := float(defender.def) if defender != null else 0.0
	var defender_mnd := float(defender.mnd) if defender != null else 0.0
	var physical_multiplier := physical_defense_multiplier(defender_def + request.defense_bonus, config)
	var magic_multiplier := magic_defense_multiplier(defender_mnd + request.magic_defense_bonus, config)
	var physical_after: float = physical_raw * physical_multiplier if uses_physical else 0.0
	var magic_after: float = magic_raw * magic_multiplier if uses_magic else 0.0
	var composite_damage: float = physical_after + magic_after
	result.physical_raw = physical_raw
	result.magic_raw = magic_raw
	result.physical_after_mitigation = physical_after
	result.magic_after_mitigation = magic_after

	var random_source := rng if rng != null else RandomNumberGenerator.new()
	var damage_roll := maxf(random_source.randf_range(config.damage_roll_min, config.damage_roll_max), config.damage_roll_min)
	var damage: float = composite_damage * damage_roll
	if request.critical_eligible and random_source.randf() < config.critical_hit_chance:
		result.critical = true
		damage *= config.critical_damage_multiplier
	_finalize_damage(result, damage)
	return result


static func physical_defense_for_snapshot(snapshot: CombatStatSnapshot) -> float:
	return snapshot.def if snapshot != null else 0.0


static func magic_defense_for_snapshot(snapshot: CombatStatSnapshot) -> float:
	# M.DEF is intentionally a derived read of MND in this first release. The
	# named helper keeps the UI/combat contract explicit for future status rules.
	return snapshot.mnd if snapshot != null else 0.0


static func physical_defense_multiplier(defense: float, tuning: CombatTuning = null) -> float:
	var config := tuning if tuning != null else CombatTuning.new()
	return config.defense_scale / (config.defense_scale + maxf(defense, 0.0))


static func magic_defense_multiplier(mind: float, tuning: CombatTuning = null) -> float:
	var config := tuning if tuning != null else CombatTuning.new()
	return config.magic_defense_scale / (config.magic_defense_scale + maxf(mind, 0.0))


static func _initialize_result(result: DamageResult, request: RefCounted) -> void:
	result.amount = 1.0
	result.critical = false
	result.element = ElementCatalogScript.normalize(request.attack_element)
	result.effectiveness = ElementCatalogScript.effectiveness(request.attack_element, request.defense_element)
	result.immune = is_zero_approx(result.effectiveness)
	result.category = request.category
	result.contract_id = request.contract_id
	result.physical_raw = 0.0
	result.magic_raw = 0.0
	result.physical_after_mitigation = 0.0
	result.magic_after_mitigation = 0.0


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


static func magic_power_for_snapshot(snapshot: CombatStatSnapshot, tuning: CombatTuning = null, intelligence_damage_scale: float = -1.0, magic_base_power: float = -1.0) -> float:
	var config := tuning if tuning != null else CombatTuning.new()
	var base_power := config.magic_base if magic_base_power < 0.0 else magic_base_power
	if snapshot == null:
		return base_power
	var scale := config.magic_per_int if intelligence_damage_scale < 0.0 else intelligence_damage_scale
	return base_power + snapshot.intelligence * scale
