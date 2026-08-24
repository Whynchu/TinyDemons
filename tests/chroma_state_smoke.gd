extends SceneTree

const Chroma = preload("res://scripts/player_chroma_component.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var chroma := Chroma.new()
	root.add_child(chroma)

	chroma.begin_new_run()
	_expect(chroma.current_aspect == Chroma.Aspect.NONE, "new run starts Gray", failures)
	_expect(chroma.current_chroma == 0, "new run starts at zero Chroma", failures)
	_expect(chroma.ability_mode() == Chroma.AbilityMode.GRAY, "Gray ability resolves at run start", failures)
	_expect(not chroma.restore_neutral_chroma(), "Gray cannot gain neutral Chroma", failures)
	_expect(chroma.current_chroma == 0, "Gray remains at zero after pickup", failures)

	_expect(chroma.attune(Chroma.Aspect.FIRE), "Fire attunement succeeds", failures)
	_expect(chroma.current_aspect == Chroma.Aspect.FIRE, "attunement stores Fire", failures)
	_expect(chroma.current_chroma == 100, "attunement fills to 100", failures)
	_expect(chroma.ability_mode() == Chroma.AbilityMode.ELEMENTAL, "charged Fire resolves elemental ability", failures)
	_expect(Chroma.ELEMENTAL_ABILITY_COST == 10, "Triangle costs 10 Chroma", failures)

	for expected in [90, 80, 70, 60, 50, 40, 30, 20, 10, 0]:
		_expect(chroma.spend_elemental_ability(), "elemental cast spends 10 Chroma", failures)
		_expect(chroma.current_chroma == expected, "Chroma reaches %d" % expected, failures)
		_expect(chroma.current_chroma % Chroma.ELEMENTAL_ABILITY_COST == 0, "Chroma remains 10-point aligned at %d" % expected, failures)

	_expect(chroma.current_aspect == Chroma.Aspect.NONE, "unbound depletion returns to Gray", failures)
	_expect(chroma.ability_mode() == Chroma.AbilityMode.GRAY, "unbound depletion resolves Gray ability", failures)

	_expect(chroma.attune(Chroma.Aspect.WATER), "Water attunement succeeds", failures)
	_expect(not chroma.restore_neutral_chroma(), "full Chroma rejects an extra pickup", failures)
	_expect(chroma.current_chroma == 100, "neutral pickup caps at 100", failures)
	chroma.spend_elemental_ability()
	chroma.spend_elemental_ability()
	_expect(chroma.current_chroma == 80, "two casts leave 80 Chroma", failures)
	_expect(chroma.restore_neutral_chroma(), "neutral pickup restores one charge", failures)
	_expect(chroma.current_chroma == 100, "neutral pickup adds exactly 20", failures)

	chroma.begin_new_run()
	chroma.attune(Chroma.Aspect.ELECTRIC)
	chroma.set_binding_active(true)
	for _i in 10:
		_expect(chroma.spend_elemental_ability(), "bound elemental cast spends 10 Chroma", failures)
	_expect(chroma.current_aspect == Chroma.Aspect.ELECTRIC, "Binding preserves Electric at zero", failures)
	_expect(chroma.current_chroma == 0, "bound aspect reaches zero", failures)
	_expect(chroma.ability_mode() == Chroma.AbilityMode.BOUND_WEAKENED, "bound zero resolves weakened ability", failures)
	_expect(chroma.restore_neutral_chroma(), "neutral pickup restores dormant bound aspect", failures)
	_expect(chroma.current_chroma == 20, "dormant bound aspect regains 20 Chroma", failures)
	_expect(chroma.ability_mode() == Chroma.AbilityMode.ELEMENTAL, "restored bound aspect resolves full ability", failures)

	chroma.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: chroma state smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CHROMA_STATE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
