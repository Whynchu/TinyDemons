extends SceneTree

const CombatRequestScript = preload("res://scripts/combat_damage_request.gd")

class CombatRoot extends Node:
	var player_stats: StatsComponent
	var player_equipment: EquipmentComponent = null
	var combat_tuning: CombatTuning
	var rng: RandomNumberGenerator
	var player_imbued_element := ElementCatalogScript.Element.NEUTRAL
	var player: Sprite2D
	var player_profile: PlayerProfile

	func _slime_stats(actor: Sprite2D) -> StatsComponent:
		return actor.get_node_or_null("Stats") as StatsComponent


const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := CombatTuning.new()
	tuning.damage_roll_min = 1.0
	tuning.damage_roll_max = 1.0
	tuning.critical_hit_chance = 0.0
	var attacker := CombatStatSnapshot.new()
	attacker.strength = 20.0
	var defender := CombatStatSnapshot.new()
	defender.def = 24.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 481516
	var request = CombatRequestScript.physical(2.0, tuning.enemy_damage_per_strength)
	var early := CombatCalculator.calculate_request(request, attacker, defender, rng, tuning)
	var late_multiplier := CombatRuntimeController.enemy_late_run_damage_multiplier(40, tuning)
	request = CombatRequestScript.physical(2.0, tuning.enemy_damage_per_strength * late_multiplier)
	var late := CombatCalculator.calculate_request(request, attacker, defender, rng, tuning)
	_expect(is_equal_approx(CombatRuntimeController.enemy_late_run_damage_multiplier(1, tuning), 1.0), "early run enemy damage multiplier remains unchanged", failures)
	_expect(is_equal_approx(CombatRuntimeController.enemy_late_run_damage_multiplier(20, tuning), 1.0), "late run damage ramp begins after its authored threshold", failures)
	_expect(is_equal_approx(late_multiplier, 1.4), "rank 40 uses the capped 40 percent strength scaling bonus", failures)
	_expect(late.amount > early.amount, "higher enemy damage multiplier closes part of late-game defense gap", failures)
	_expect(is_equal_approx(CombatRuntimeController.enemy_late_run_damage_multiplier(60, tuning), late_multiplier), "late-run damage scaling stays capped after rank 40", failures)
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: enemy late-run damage smoke failed before completion")
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_LATE_RUN_DAMAGE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
