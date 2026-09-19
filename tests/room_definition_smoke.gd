extends SceneTree

## Slice C characterization: RoomDefinition captures the rank-curve difficulty
## and traffic policy (enemy cap, popcorn rates, boss support/minor counts,
## treasure chance) as validated, editor-inspectable data. RoomController reads
## the policy through it instead of hardcoded rank constants.

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []

	var definition := RoomDefinition.new()
	_expect(definition.validate().is_empty(), "default room definition validates", failures)
	_expect(definition.normal_enemy_cap == 7, "default keeps the seven-enemy cap", failures)
	_expect(is_equal_approx(definition.regular_room_treasure_chance, 0.50), "default keeps the 50 percent treasure chance", failures)
	_expect(is_equal_approx(definition.popcorn_chance_for_rank(1), 0.25), "early popcorn rate is preserved", failures)
	_expect(is_equal_approx(definition.popcorn_chance_for_rank(2), 0.40), "run-two popcorn rate is preserved", failures)
	_expect(is_equal_approx(definition.popcorn_chance_for_rank(5), 0.24), "later popcorn rate is preserved", failures)

	_expect(definition.boss_support_popcorn_for_rank(1) == 3, "early boss support popcorn is preserved", failures)
	_expect(definition.boss_support_popcorn_for_rank(5) == 4, "mid boss support popcorn is preserved", failures)
	_expect(definition.boss_support_popcorn_for_rank(8) == 6, "late boss support popcorn is preserved", failures)
	_expect(definition.boss_minor_count_for_rank(4) == 0, "no boss minors before the mixed-support rank", failures)
	_expect(definition.boss_minor_count_for_rank(5) == 1, "one boss minor at the mixed-support rank", failures)
	_expect(definition.boss_minor_count_for_rank(6) == 2, "two boss minors at the second mixed-support rank", failures)

	var cap_chance := definition.additional_enemy_chance_for(1, 1)
	_expect(cap_chance > 0.4 and cap_chance <= 0.85, "first extra-enemy roll is bounded", failures)
	var falloff_chance := definition.additional_enemy_chance_for(1, 4)
	_expect(falloff_chance < cap_chance, "extra-enemy chance falls off with more slots", failures)

	var bad := RoomDefinition.new()
	bad.normal_enemy_cap = 0
	bad.regular_room_treasure_chance = 2.0
	bad.boss_support_popcorn_max = 1
	_expect(not bad.validate().is_empty(), "invalid room definition is rejected", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: room definition failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ROOM_DEFINITION_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)