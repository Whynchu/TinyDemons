extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := PlayerTuning.new()
	var m := CombatMomentumComponent.new()
	m.configure(tuning)

	_expect(is_equal_approx(m.focus_multiplier(false), 1.0), "no target is baseline", failures)
	m.on_target_changed(true)
	_expect(m.focus_active, "locking a target activates focus", failures)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_bonus), "focus bonus inside window", failures)
	m.tick(1.0, true)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_bonus), "focus still active before window elapses", failures)
	m.tick(tuning.focus_window - 1.0, true)
	_expect(not m.focus_active, "focus lost once window elapses", failures)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_penalty), "focus penalty after window", failures)
	m.on_target_changed(false)
	_expect(not m.focus_active, "untargeting clears focus", failures)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_penalty), "penalty persists when no target locked", failures)
	m.on_target_changed(true)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_bonus), "retarget resets the focus window", failures)
	m.tick(999.0, true)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_penalty), "long hold falls to penalty", failures)
	m.on_target_changed(false)
	m.on_target_changed(true)

	_expect(is_equal_approx(m.combo_multiplier(), 1.0), "combo starts neutral", failures)
	m.register_hit()
	_expect(is_equal_approx(m.combo_multiplier(), 1.0 + tuning.combo_damage_per_hit), "one hit grants one step", failures)
	for i in 8:
		m.register_hit()
	_expect(is_equal_approx(m.combo_multiplier(), 1.0 + tuning.combo_damage_cap), "combo caps at configured ceiling", failures)
	m.tick(tuning.combo_hit_window, true)
	_expect(is_equal_approx(m.combo_multiplier(), 1.0), "combo decays to neutral after window", failures)
	m.register_hit()
	m.register_hit()
	m.reset_combo()
	_expect(is_equal_approx(m.combo_multiplier(), 1.0), "reset clears the combo", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: combat momentum smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("COMBAT_MOMENTUM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
