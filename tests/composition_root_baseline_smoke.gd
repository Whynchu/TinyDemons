extends SceneTree

const BASELINE_GAMEPLAY_LINES := 2863
const BASELINE_GAMEPLAY_FUNCTIONS := 424
const COMPOSITION_ROOT_TARGET_LINES := 2000


func _initialize() -> void:
	var failures: Array[String] = []
	var gameplay_source := FileAccess.get_file_as_string("res://scripts/gameplay.gd")
	var gameplay_lines := gameplay_source.split("\n").size() - (1 if gameplay_source.ends_with("\n") else 0)
	var gameplay_functions := 0
	for line in gameplay_source.split("\n"):
		if line.begins_with("func "):
			gameplay_functions += 1
	_expect(gameplay_lines <= BASELINE_GAMEPLAY_LINES, "gameplay.gd does not grow beyond the R0 baseline", failures)
	_expect(gameplay_lines <= COMPOSITION_ROOT_TARGET_LINES, "gameplay.gd meets the 2,000-line composition milestone", failures)
	_expect(gameplay_functions <= BASELINE_GAMEPLAY_FUNCTIONS, "gameplay.gd function count does not grow beyond the R0 baseline", failures)
	_expect(load("res://scripts/gameplay_bootstrap.gd") != null, "bootstrap script remains loadable", failures)
	_expect(load("res://scripts/gameplay_frame_controller.gd") != null, "frame controller remains loadable", failures)
	var tuning_paths := [
		"res://resources/tuning/player_default.tres",
		"res://resources/tuning/slime_default.tres",
		"res://resources/tuning/combat_default.tres",
		"res://resources/tuning/progression_default.tres",
		"res://resources/tuning/effects_default.tres",
		"res://resources/tuning/chroma_default.tres",
	]
	for tuning_path in tuning_paths:
		_expect(load(tuning_path) is Resource, "external tuning resource loads: %s" % tuning_path, failures)
	var first_runtime := GameplayState.new()
	var second_runtime := GameplayState.new()
	_expect(first_runtime.player_tuning != second_runtime.player_tuning, "runtime tuning copies are isolated per GameplayState", failures)
	_expect(first_runtime.combat_tuning != second_runtime.combat_tuning, "combat tuning overrides cannot leak between runtimes", failures)
	first_runtime.free()
	second_runtime.free()
	var phase_order := GameplayFrameController.phase_order()
	_expect(phase_order == [&"input", &"simulation", &"contact_resolution", &"damage_and_progression", &"presentation", &"transitions"], "frame phase order remains explicit", failures)
	if failures.is_empty():
		print("COMPOSITION_ROOT_BASELINE_SMOKE_OK lines=%d functions=%d" % [gameplay_lines, gameplay_functions])
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
