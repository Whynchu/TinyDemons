extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var progression: ProgressionTuning = ProgressionTuning.new()
	var level_50_points: int = progression.cumulative_stat_points_at_level(50)
	_expect(level_50_points == 179, "level 50 enemy uses the player's cumulative level-up point schedule", failures)

	var stats: StatsComponent = StatsComponent.new()
	stats.apply_enemy_variant_profile(
		{"VIT": 2, "STR": 2, "DEF": 2, "AGI": 2, "INT": 2, "MND": 2},
		{"VIT": 0.3, "STR": 0.28, "DEF": 0.28, "AGI": 0.14, "INT": 0.0, "MND": 0.0},
		&"growth_smoke"
	)
	stats.set_enemy_progression_tuning(progression)
	stats.level = 50
	var total_stats := stats.vit + stats.strength + stats.def + stats.agi + stats.intelligence + stats.mnd
	_expect(total_stats == 12 + level_50_points, "enemy growth distributes every player progression point on top of authored base stats", failures)
	stats.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: enemy stat growth smoke failed before completion")
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_STAT_GROWTH_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
