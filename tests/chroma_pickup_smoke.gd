extends SceneTree

const Chroma = preload("res://scripts/player_chroma_component.gd")
const ChromaTuningScript = preload("res://scripts/chroma_tuning.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := ChromaTuningScript.new()
	_expect(tuning.pickup_value == 20, "neutral pickup is worth 20 Chroma", failures)
	_expect(is_equal_approx(tuning.enemy_drop_chance, 0.35), "enemy drop chance has the first-pass tuning", failures)

	var chroma := Chroma.new()
	root.add_child(chroma)
	chroma.begin_new_run()
	_expect(chroma.restore_neutral_chroma(tuning.pickup_value), "Gray pickup restores neutral Chroma", failures)
	_expect(chroma.current_chroma == tuning.pickup_value, "Gray stores the pickup without changing identity", failures)
	_expect(chroma.current_aspect == Chroma.Aspect.NONE, "Gray pickup keeps the player normal", failures)
	chroma.begin_new_run()
	chroma.attune(Chroma.Aspect.FIRE)
	chroma.spend_elemental_ability()
	_expect(chroma.current_chroma == 90, "pickup test starts from a partial bar after a 10-point cast", failures)
	_expect(chroma.restore_neutral_chroma(tuning.pickup_value), "charged aspect accepts neutral pickup", failures)
	_expect(chroma.current_chroma == 100, "neutral pickup adds 20 and caps at 100", failures)
	_expect(not chroma.restore_neutral_chroma(tuning.pickup_value), "full bar rejects extra resource", failures)

	chroma.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Chroma pickup smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CHROMA_PICKUP_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
