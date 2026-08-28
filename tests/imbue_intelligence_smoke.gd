extends SceneTree

class VisualRoot extends Node:
	var combat_tuning: CombatTuning
	var snapshot: CombatStatSnapshot

	func _player_stat_snapshot() -> CombatStatSnapshot:
		return snapshot


var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := CombatTuning.new()
	var root := VisualRoot.new()
	root.combat_tuning = tuning
	get_root().add_child(root)
	var visual := PlayerEquipmentVisualComponent.new()
	root.add_child(visual)
	var low := CombatStatSnapshot.new()
	low.intelligence = 1.0
	root.snapshot = low
	_expect(is_equal_approx(tuning.imbue_visual_intensity_for_intelligence(1.0), 1.0), "reference INT keeps Imbue visual intensity neutral", failures)
	_expect(tuning.imbue_visual_intensity_for_intelligence(60.0) <= tuning.imbue_visual_intensity_max and tuning.imbue_visual_intensity_for_intelligence(-20.0) >= tuning.imbue_visual_intensity_min, "Imbue visual intensity is bounded", failures)
	visual.begin_imbue(root, ElementCatalog.Element.FIRE, 15.0)
	var low_intensity := visual.last_imbue_visual_intensity
	var low_remaining := visual.imbue_remaining
	var high := CombatStatSnapshot.new()
	high.intelligence = 20.0
	root.snapshot = high
	visual.begin_imbue(root, ElementCatalog.Element.FIRE, 15.0)
	var high_intensity := visual.last_imbue_visual_intensity
	_expect(high_intensity > low_intensity and high_intensity <= tuning.imbue_visual_intensity_max, "higher INT increases Imbue visual intensity without exceeding the cap", failures)
	_expect(is_equal_approx(low_remaining, visual.imbue_remaining), "INT visual intensity does not change Imbue duration", failures)
	_expect(is_equal_approx(tuning.imbue_base + high.intelligence * tuning.imbue_per_int, 11.0), "Imbue mechanical INT scaling remains the separate magic contract", failures)
	visual.end_imbue(root)
	_expect(is_equal_approx(visual.last_imbue_visual_intensity, 1.0) and is_zero_approx(visual.imbue_remaining), "ending Imbue clears presentation state", failures)

	visual.free()
	root.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Imbue intelligence smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("IMBUE_INTELLIGENCE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
