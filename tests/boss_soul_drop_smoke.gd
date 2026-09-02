extends SceneTree

const COMBAT_RUNTIME_SCRIPT = preload("res://scripts/combat_runtime_controller.gd")


class SoulRoot extends RefCounted:
	var player_profile: PlayerProfile = null


func _initialize() -> void:
	var failures: Array[String] = []
	var runtime := COMBAT_RUNTIME_SCRIPT.new()
	var root := SoulRoot.new()
	root.player_profile = PlayerProfile.new()
	var ordinary := Sprite2D.new()
	var boss := Sprite2D.new()
	boss.set_meta("encounter_scale", 3.0)
	_expect(runtime.soul_drop_value_for_slime(root, ordinary) == 1, "ordinary enemies keep the one-Soul drop", failures)
	for completed_runs in [0, 1, 2, 4, 7]:
		root.player_profile.completed_runs = completed_runs
		_expect(runtime.soul_drop_value_for_slime(root, boss) == 5 + int(completed_runs) * 2, "boss Soul reward follows completed-run scaling at run %d" % (int(completed_runs) + 1), failures)
	root.player_profile.completed_runs = 0
	boss.set_meta("encounter_scale", 4.0)
	_expect(runtime.soul_drop_value_for_slime(root, boss) == 6, "future boss encounter-scale growth adds to the Soul reward", failures)
	ordinary.free()
	boss.free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("BOSS_SOUL_DROP_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
