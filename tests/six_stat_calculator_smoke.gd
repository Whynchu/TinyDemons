extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const CombatDamageRequestScript = preload("res://scripts/combat_damage_request.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := CombatTuning.new()
	tuning.damage_roll_min = 1.0
	tuning.damage_roll_max = 1.0
	tuning.critical_hit_chance = 0.0
	var rng := RandomNumberGenerator.new()

	var physical := CombatDamageRequestScript.physical(tuning.damage_base, tuning.damage_per_strength)
	var magic := CombatDamageRequestScript.magic(tuning.magic_base, tuning.magic_per_int)
	var base_defender := _snapshot(0.0, 0.0, 2.0, 1.0, 0.0, 2.0)
	var low_strength := _snapshot(2.0, 4.0, 0.0, 1.0, 8.0, 2.0)
	var high_strength := _snapshot(2.0, 8.0, 0.0, 1.0, 8.0, 2.0)
	var low_strength_physical := CombatCalculator.calculate_request(physical, low_strength, base_defender, rng, tuning)
	var high_strength_physical := CombatCalculator.calculate_request(physical, high_strength, base_defender, rng, tuning)
	var low_strength_magic := CombatCalculator.calculate_request(magic, low_strength, base_defender, rng, tuning)
	var high_strength_magic := CombatCalculator.calculate_request(magic, high_strength, base_defender, rng, tuning)
	_expect(high_strength_physical.physical_raw > low_strength_physical.physical_raw, "STR raises the physical portion", failures)
	_expect(is_equal_approx(high_strength_magic.magic_raw, low_strength_magic.magic_raw), "STR does not raise pure magic", failures)

	var low_intelligence := _snapshot(2.0, 8.0, 0.0, 1.0, 2.0, 2.0)
	var high_intelligence := _snapshot(2.0, 8.0, 0.0, 1.0, 8.0, 2.0)
	var low_intelligence_physical := CombatCalculator.calculate_request(physical, low_intelligence, base_defender, rng, tuning)
	var high_intelligence_physical := CombatCalculator.calculate_request(physical, high_intelligence, base_defender, rng, tuning)
	var low_intelligence_magic := CombatCalculator.calculate_request(magic, low_intelligence, base_defender, rng, tuning)
	var high_intelligence_magic := CombatCalculator.calculate_request(magic, high_intelligence, base_defender, rng, tuning)
	_expect(is_equal_approx(high_intelligence_physical.physical_raw, low_intelligence_physical.physical_raw), "INT does not raise pure physical", failures)
	_expect(high_intelligence_magic.magic_raw > low_intelligence_magic.magic_raw, "INT raises the magic portion", failures)

	var low_vitality := _snapshot(1.0, 8.0, 2.0, 1.0, 8.0, 2.0)
	var high_vitality := _snapshot(10.0, 8.0, 2.0, 1.0, 8.0, 2.0)
	_expect(CombatCalculator.max_health_for_snapshot(high_vitality, tuning) > CombatCalculator.max_health_for_snapshot(low_vitality, tuning), "VIT raises maximum HP", failures)
	_expect(is_equal_approx(CombatCalculator.calculate_request(physical, high_vitality, base_defender, rng, tuning).amount, CombatCalculator.calculate_request(physical, low_vitality, base_defender, rng, tuning).amount), "VIT does not directly alter damage", failures)

	var imbue := CombatDamageRequestScript.imbued_weapon(2.0, 0.5, 1.0, 0.5, ElementCatalogScript.Element.FIRE, ElementCatalogScript.Element.GRASS)
	var low_defender := _snapshot(0.0, 0.0, 2.0, 1.0, 0.0, 2.0)
	var high_defender := _snapshot(0.0, 0.0, 12.0, 1.0, 0.0, 2.0)
	var low_def_result := CombatCalculator.calculate_request(imbue, low_strength, low_defender, rng, tuning)
	var high_def_result := CombatCalculator.calculate_request(imbue, low_strength, high_defender, rng, tuning)
	_expect(high_def_result.physical_after_mitigation < low_def_result.physical_after_mitigation and is_equal_approx(high_def_result.magic_after_mitigation, low_def_result.magic_after_mitigation), "DEF mitigates only the physical composite portion", failures)

	var low_mnd_defender := _snapshot(0.0, 0.0, 2.0, 1.0, 0.0, 2.0)
	var high_mnd_defender := _snapshot(0.0, 0.0, 2.0, 1.0, 0.0, 12.0)
	var low_mnd_result := CombatCalculator.calculate_request(imbue, low_strength, low_mnd_defender, rng, tuning)
	var high_mnd_result := CombatCalculator.calculate_request(imbue, low_strength, high_mnd_defender, rng, tuning)
	_expect(is_equal_approx(high_mnd_result.physical_after_mitigation, low_mnd_result.physical_after_mitigation) and high_mnd_result.magic_after_mitigation < low_mnd_result.magic_after_mitigation, "MND-derived M.DEF mitigates only the magic composite portion", failures)

	var player_tuning := PlayerTuning.new()
	_expect(is_equal_approx(player_tuning.agi_multiplier(player_tuning.movement_agi_reference), 1.0) and player_tuning.agi_multiplier(21.0) > 1.0, "AGI movement specs off the reference value", failures)
	_expect(player_tuning.agi_multiplier(0.0) < 1.0 and player_tuning.agi_multiplier(0.0) < player_tuning.agi_multiplier(1.0), "zero AGI is clearly slower than the neutral reference", failures)
	_expect(player_tuning.agi_multiplier(2.0) < 1.0, "a starting 2-AGI build is below neutral movement", failures)
	_expect(is_equal_approx(tuning.knockback_multiplier_for_strength(5.0), 1.0) and tuning.knockback_multiplier_for_strength(20.0) > 1.0, "STR is the knockback reference stat", failures)

	var player_stats := StatsComponent.new()
	player_stats.configure_manual_growth(3, 2, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0)
	var starter_equipment := EquipmentComponent.new()
	starter_equipment.equip_default_loadout()
	var player_snapshot := CombatStatSnapshot.from_components(player_stats, starter_equipment)
	var neutral_slime := _snapshot(2.0, 0.0, 2.0, 2.0, 0.0, 1.0)
	var benchmark := CombatCalculator.calculate_request(physical, player_snapshot, neutral_slime, rng, tuning)
	_expect(benchmark.amount >= 3.0 and benchmark.amount <= 5.0, "level-one starter physical damage lands in the 3-5 neutral-slime band", failures)
	var breakdown := player_snapshot.debug_breakdown(tuning)
	_expect(breakdown.has_all(["VIT", "STR", "DEF", "AGI", "INT", "MND", "HP", "P.ATK", "P.DEF", "M.ATK", "M.DEF"]), "shared snapshot exposes the six-stat debug breakdown", failures)
	_expect(player_snapshot.debug_summary(tuning).contains("INT") and player_snapshot.debug_summary(tuning).contains("M.DEF"), "debug summary includes canonical magical stat outputs", failures)

	player_stats.free()
	starter_equipment.free()
	_finished = true
	call_deferred("_finish", failures)


func _snapshot(vitality: float, strength: float, defense: float, agi: float, intelligence: float, mnd: float) -> CombatStatSnapshot:
	var snapshot := CombatStatSnapshot.new()
	snapshot.vit = vitality
	snapshot.strength = strength
	snapshot.def = defense
	snapshot.agi = agi
	snapshot.intelligence = intelligence
	snapshot.mnd = mnd
	return snapshot


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: six-stat calculator smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SIX_STAT_CALCULATOR_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
