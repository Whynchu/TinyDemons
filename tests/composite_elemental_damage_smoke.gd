extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const CombatDamageRequestScript = preload("res://scripts/combat_damage_request.gd")
const SlimeVariantCatalogScript = preload("res://scripts/slime_variant_catalog.gd")

class CombatRoot extends Node:
	var player_stats: StatsComponent
	var player_equipment: EquipmentComponent = null
	var combat_tuning: CombatTuning
	var rng: RandomNumberGenerator
	var player_imbued_element := ElementCatalogScript.Element.NEUTRAL

	func _slime_stats(slime: Sprite2D) -> StatsComponent:
		return slime.get_node_or_null("Stats") as StatsComponent


var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := CombatTuning.new()
	tuning.damage_roll_min = 1.0
	tuning.damage_roll_max = 1.0
	tuning.critical_hit_chance = 0.0
	var attacker := CombatStatSnapshot.new()
	attacker.strength = 10.0
	attacker.intelligence = 10.0
	var defender := CombatStatSnapshot.new()
	defender.def = 2.0
	defender.mnd = 2.0
	var rng := RandomNumberGenerator.new()

	var physical := CombatDamageRequestScript.physical(2.0, 0.5)
	var physical_result := CombatCalculator.calculate_request(physical, attacker, defender, rng, tuning)
	_expect(physical_result.category == CombatDamageRequestScript.DamageCategory.PHYSICAL and physical_result.contract_id == CombatDamageRequestScript.CONTRACT_PHYSICAL, "physical actions use the physical contract", failures)
	_expect(is_zero_approx(physical_result.magic_raw) and physical_result.physical_raw > 0.0, "physical actions are STR-led without a magic portion", failures)

	var magic := CombatDamageRequestScript.magic(2.0, 0.75, ElementCatalogScript.Element.FIRE, ElementCatalogScript.Element.GRASS)
	var magic_result := CombatCalculator.calculate_request(magic, attacker, defender, rng, tuning)
	_expect(magic_result.category == CombatDamageRequestScript.DamageCategory.MAGIC and magic_result.contract_id == CombatDamageRequestScript.CONTRACT_MAGIC, "Triangle-style actions use the pure magic contract", failures)
	_expect(is_zero_approx(magic_result.physical_raw) and magic_result.magic_raw > 0.0 and is_equal_approx(magic_result.magic_after_mitigation, magic_result.magic_raw * CombatCalculator.magic_defense_multiplier(defender.mnd, tuning)), "pure magic scales from INT and uses M.DEF from MND", failures)

	var imbue := CombatDamageRequestScript.imbued_weapon(2.0, 0.5, 1.0, 0.5, ElementCatalogScript.Element.FIRE, ElementCatalogScript.Element.GRASS)
	var imbue_result := CombatCalculator.calculate_request(imbue, attacker, defender, rng, tuning)
	_expect(imbue_result.category == CombatDamageRequestScript.DamageCategory.IMBUED_WEAPON and imbue_result.contract_id == CombatDamageRequestScript.CONTRACT_IMBUE, "Imbue uses its separate composite contract", failures)
	_expect(imbue_result.physical_raw > 0.0 and imbue_result.magic_raw > 0.0 and imbue_result.physical_after_mitigation > 0.0 and imbue_result.magic_after_mitigation > 0.0, "Imbue carries both STR physical and INT magic portions", failures)
	var expected_combined := floorf(imbue_result.physical_after_mitigation + imbue_result.magic_after_mitigation)
	_expect(imbue_result.amount == floorf((imbue_result.physical_after_mitigation + imbue_result.magic_after_mitigation) * 1.25), "one elemental weakness multiplier applies to the full combined packet", failures)
	_expect(imbue_result.amount > expected_combined, "full-packet weakness increases one readable Imbue result", failures)

	var higher_defender := CombatStatSnapshot.new()
	higher_defender.def = 20.0
	higher_defender.mnd = defender.mnd
	var def_result := CombatCalculator.calculate_request(imbue, attacker, higher_defender, rng, tuning)
	_expect(def_result.physical_after_mitigation < imbue_result.physical_after_mitigation and is_equal_approx(def_result.magic_after_mitigation, imbue_result.magic_after_mitigation), "DEF mitigates only the physical composite portion", failures)
	var higher_mnd_defender := CombatStatSnapshot.new()
	higher_mnd_defender.def = defender.def
	higher_mnd_defender.mnd = 20.0
	var mnd_result := CombatCalculator.calculate_request(imbue, attacker, higher_mnd_defender, rng, tuning)
	_expect(is_equal_approx(mnd_result.physical_after_mitigation, imbue_result.physical_after_mitigation) and mnd_result.magic_after_mitigation < imbue_result.magic_after_mitigation, "MND-derived M.DEF mitigates only the magic composite portion", failures)
	_expect(CombatCalculator.physical_defense_for_snapshot(higher_defender) == higher_defender.def and CombatCalculator.magic_defense_for_snapshot(higher_mnd_defender) == higher_mnd_defender.mnd, "derived defense helpers remain distinct", failures)

	var immune := CombatDamageRequestScript.elemental_slime(1.5, 0.85, 0.75, 0.5, ElementCatalogScript.Element.ELECTRIC, ElementCatalogScript.Element.GROUND)
	var immune_result := CombatCalculator.calculate_request(immune, attacker, defender, rng, tuning)
	_expect(immune_result.category == CombatDamageRequestScript.DamageCategory.ELEMENTAL_SLIME and immune_result.contract_id == CombatDamageRequestScript.CONTRACT_ELEMENTAL_SLIME, "elemental slimes use their separate composite contract", failures)
	_expect(immune_result.physical_raw > 0.0 and immune_result.magic_raw > 0.0 and immune_result.immune and is_zero_approx(immune_result.amount), "elemental immunity zeros the full composite packet", failures)
	_expect(is_equal_approx(ElementCatalogScript.effectiveness(ElementCatalogScript.Element.SHADOW, ElementCatalogScript.Element.NEUTRAL), 1.0), "Shadow damages normal slimes", failures)
	_expect(is_zero_approx(ElementCatalogScript.effectiveness(ElementCatalogScript.Element.NEUTRAL, ElementCatalogScript.Element.SHADOW)), "normal damage remains ineffective against Shadow slimes", failures)

	var root := CombatRoot.new()
	root.player_stats = StatsComponent.new()
	root.player_stats.configure_manual_growth(3, 2, 2, 1, 1, 0, 0, 0, 8, 1, 0, 0)
	root.combat_tuning = tuning
	root.rng = rng
	get_root().add_child(root)
	var red := _make_slime(root, &"red", ElementCatalogScript.Element.FIRE, 7)
	var grey := _make_slime(root, &"grey", ElementCatalogScript.Element.NEUTRAL, 0)
	var runtime := CombatRuntimeController.new()
	var red_result := runtime.slime_attack_damage_result(root, red)
	var grey_result := runtime.slime_attack_damage_result(root, grey)
	_expect(red_result.contract_id == CombatDamageRequestScript.CONTRACT_ELEMENTAL_SLIME and red_result.magic_raw > 0.0, "runtime colored slime attacks include their authored INT bonus", failures)
	_expect(grey_result.contract_id == CombatDamageRequestScript.CONTRACT_PHYSICAL and is_zero_approx(grey_result.magic_raw), "runtime neutral slime attacks remain physical-only", failures)
	root.player_imbued_element = ElementCatalogScript.Element.FIRE
	var player_imbue_result := runtime.player_weapon_damage_result_against(root, grey, ElementCatalogScript.Element.FIRE)
	_expect(player_imbue_result.contract_id == CombatDamageRequestScript.CONTRACT_IMBUE and player_imbue_result.magic_raw > 0.0, "runtime imbued weapon hits use the player composite contract", failures)

	root.free()
	runtime.free()
	_finished = true
	call_deferred("_finish", failures)


func _make_slime(root: CombatRoot, variant: StringName, element: int, intelligence: int) -> SlimeActor:
	var slime := SlimeActor.new()
	slime.variant = String(variant)
	slime.combat_element = element
	var stats := StatsComponent.new()
	stats.intelligence = intelligence
	slime.add_child(stats)
	root.add_child(slime)
	return slime


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: composite elemental damage smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("COMPOSITE_ELEMENTAL_DAMAGE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
