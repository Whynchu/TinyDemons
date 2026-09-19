extends SceneTree

## Slice E characterization: RewardDefinition captures the chest reward drop
## policy as validated, editor-inspectable data. RunFlowController reads the
## curves through it; the authored defaults must reproduce the prior behavior.

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []

	var definition := RewardDefinition.default_data()
	_expect(definition.validate().is_empty(), "default reward definition validates", failures)
	_expect(is_equal_approx(definition.drop_chance_base, 0.34), "default keeps the base drop chance", failures)
	_expect(is_equal_approx(definition.loot_grade_bonus("S"), 3.0) and is_equal_approx(definition.loot_grade_bonus("F"), -0.5), "grade bonuses are preserved", failures)

	var exploration := minf(3.0 * definition.exploration_bonus_per_chest, definition.exploration_bonus_cap)
	var chance := definition.item_drop_chance(exploration, 1, "D")
	_expect(chance >= definition.drop_chance_floor and chance <= definition.drop_chance_cap, "item drop chance stays within its clamp", failures)
	var risk := definition.risk_item_drop_chance(exploration, 1, "D")
	_expect(risk >= chance and risk <= definition.drop_chance_risk_cap, "risk-tier drop chance exceeds the standard tier", failures)

	_expect(definition.drop_count_for(0.5, 1, "D") == 1, "roll above the double threshold yields a single drop", failures)
	var high_rank_count := definition.drop_count_for(0.001, 8, "S")
	_expect(high_rank_count > 1, "high rank and grade can yield multiple drops", failures)

	var bad := RewardDefinition.new()
	bad.drop_chance_cap = 0.1
	bad.double_drop_cap = 0.1
	bad.quad_drop_cap = 0.001
	_expect(not bad.validate().is_empty(), "invalid reward definition is rejected", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: reward definition failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("REWARD_DEFINITION_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)