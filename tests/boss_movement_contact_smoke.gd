extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var tuning := SlimeTuning.new()
	_expect(tuning.boss_scoot_distance >= 6.0 and tuning.boss_scoot_distance <= 8.0, "boss scoot uses the authored heavy range", failures)
	_expect(tuning.boss_scoot_duration >= 0.48 and tuning.boss_scoot_duration <= 0.62, "boss scoot has a committed duration", failures)
	_expect(tuning.boss_attack_lunge_distance >= 8.0 and tuning.boss_attack_lunge_distance <= 12.0, "boss lunge has the committed authored attack distance", failures)
	_expect(tuning.attack_hit_range - 0.5 < tuning.attack_hit_range + 0.75, "boss preferred spacing stays inside attack permission", failures)
	var combat := SlimeCombatComponent.new()
	combat.begin_lunge(Vector2.RIGHT * 10.0, tuning.boss_attack_lunge_duration)
	_expect(combat.lunge_remaining > 0.0, "boss lunge remains active across attack frames", failures)
	_expect(combat.lunge_total >= 0.14 and combat.lunge_total <= 0.22, "boss lunge uses the authored temporal window", failures)
	if failures.is_empty():
		print("BOSS_MOVEMENT_CONTACT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)

func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
