extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := CombatTuning.new()
	var attacker := CombatStatSnapshot.new()
	attacker.strength = 10.0
	var defender := CombatStatSnapshot.new()
	defender.def = 2.0
	var neutral_a := _calculate(attacker, defender, ElementCatalogScript.Element.NEUTRAL, ElementCatalogScript.Element.FIRE, 404, tuning)
	var neutral_b := _calculate(attacker, defender, ElementCatalogScript.Element.NEUTRAL, ElementCatalogScript.Element.FIRE, 404, tuning)
	_expect(is_equal_approx(neutral_a.amount, neutral_b.amount), "neutral calculation is deterministic with the same RNG seed", failures)
	_expect(neutral_a.element == ElementCatalog.Element.NEUTRAL, "neutral result records its attack element", failures)
	_expect(is_equal_approx(neutral_a.effectiveness, 1.0), "neutral damage has neutral effectiveness", failures)
	_expect(not neutral_a.immune, "neutral damage is not immune into Fire", failures)

	var fire_into_grass := _calculate(attacker, defender, ElementCatalogScript.Element.FIRE, ElementCatalogScript.Element.GRASS, 404, tuning)
	var fire_baseline := _calculate(attacker, defender, ElementCatalogScript.Element.FIRE, ElementCatalogScript.Element.NEUTRAL, 404, tuning)
	_expect(fire_into_grass.amount >= fire_baseline.amount, "Fire weakness increases damage", failures)
	_expect(is_equal_approx(fire_into_grass.effectiveness, 1.25), "Fire into Grass is 1.25x", failures)

	var water_into_grass := _calculate(attacker, defender, ElementCatalogScript.Element.WATER, ElementCatalogScript.Element.GRASS, 404, tuning)
	var water_baseline := _calculate(attacker, defender, ElementCatalogScript.Element.WATER, ElementCatalogScript.Element.NEUTRAL, 404, tuning)
	_expect(water_into_grass.amount <= water_baseline.amount, "Water resistance reduces damage", failures)
	_expect(is_equal_approx(water_into_grass.effectiveness, 0.8), "Water into Grass is 0.8x", failures)

	var immune := _calculate(attacker, defender, ElementCatalogScript.Element.NEUTRAL, ElementCatalogScript.Element.SHADOW, 404, tuning)
	_expect(is_zero_approx(immune.amount), "immunity bypasses the minimum-one rule", failures)
	_expect(immune.immune, "immune result is marked", failures)
	_expect(is_equal_approx(immune.effectiveness, 0.0), "immune result records zero effectiveness", failures)

	var crit := _calculate_forced_critical(attacker, defender, ElementCatalogScript.Element.FIRE, ElementCatalogScript.Element.GRASS, tuning)
	_expect(crit.critical, "forced critical result is marked critical", failures)
	_expect(is_equal_approx(crit.effectiveness, 1.25), "critical keeps matchup effectiveness", failures)
	_expect(crit.amount > fire_baseline.amount, "critical and weakness compose as increased damage", failures)

	_finished = true
	call_deferred("_finish", failures)


func _calculate(attacker: CombatStatSnapshot, defender: CombatStatSnapshot, attack_element: int, defense_element: int, seed_value: int, tuning: CombatTuning) -> CombatCalculator.DamageResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CombatCalculator.calculate_snapshot_damage(attacker, defender, false, rng, tuning, tuning.damage_per_strength, attack_element, defense_element)


func _calculate_forced_critical(attacker: CombatStatSnapshot, defender: CombatStatSnapshot, attack_element: int, defense_element: int, tuning: CombatTuning) -> CombatCalculator.DamageResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	var critical_tuning := tuning.duplicate() as CombatTuning
	critical_tuning.critical_hit_chance = 1.0
	return CombatCalculator.calculate_snapshot_damage(attacker, defender, true, rng, critical_tuning, tuning.damage_per_strength, attack_element, defense_element)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: elemental damage smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ELEMENTAL_DAMAGE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
