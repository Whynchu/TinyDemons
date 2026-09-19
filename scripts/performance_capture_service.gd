extends Node

## Debug-only runtime capture. It is inert unless explicitly started.
const CAPTURE_DIR := "user://performance-captures"
const SAMPLE_INTERVAL := 0.25
const HITCH_THRESHOLD_MSEC := 16.67
const MAX_SAMPLES := 2400

var capturing := false
var _started_msec := 0
var _last_sample_msec := 0
var _samples: Array[Dictionary] = []
var _hitches := 0
var _worst_frame_msec := 0.0
var _total_frame_msec := 0.0
var _frame_count := 0
var _last_report: Dictionary = {}
var _scope_totals: Dictionary = {}
var _scope_counts: Dictionary = {}

func _process(_delta: float) -> void:
	if not capturing:
		return
	var now := Time.get_ticks_msec()
	var frame_msec := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_frame_count += 1
	_total_frame_msec += frame_msec
	_worst_frame_msec = maxf(_worst_frame_msec, frame_msec)
	if frame_msec >= HITCH_THRESHOLD_MSEC:
		_hitches += 1
	if now - _last_sample_msec < int(SAMPLE_INTERVAL * 1000.0):
		return
	_last_sample_msec = now
	if _samples.size() >= MAX_SAMPLES:
		_samples.pop_front()
	_samples.append(_engine_sample(now, frame_msec))

func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") and not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			if capturing:
				stop_capture()
			else:
				start_capture()

func start_capture() -> Dictionary:
	if capturing:
		return {"ok": false, "error": "capture_already_running"}
	capturing = true
	_started_msec = Time.get_ticks_msec()
	_last_sample_msec = _started_msec
	_samples.clear()
	_hitches = 0
	_worst_frame_msec = 0.0
	_total_frame_msec = 0.0
	_frame_count = 0
	_last_report = {}
	_scope_totals.clear()
	_scope_counts.clear()
	return {"ok": true, "started_msec": _started_msec}

func record_scope(scope_name: StringName, elapsed_usec: int) -> void:
	if not capturing:
		return
	var key := String(scope_name)
	_scope_totals[key] = int(_scope_totals.get(key, 0)) + elapsed_usec
	_scope_counts[key] = int(_scope_counts.get(key, 0)) + 1

func stop_capture() -> Dictionary:
	if not capturing:
		return _last_report if not _last_report.is_empty() else {"ok": false, "error": "capture_not_running"}
	capturing = false
	var report := _build_report()
	_last_report = report
	_write_report(report)
	return report

func get_status() -> Dictionary:
	return {"capturing": capturing, "samples": _samples.size(), "last_report": _last_report}

func get_last_report_json() -> String:
	return JSON.stringify(_last_report if not _last_report.is_empty() else get_status())

func prepare_benchmark_run() -> Dictionary:
	if not OS.has_feature("editor") and not OS.is_debug_build():
		return {"ok": false, "error": "debug_only"}
	ProjectSettings.set_setting("debug/benchmark_start_in_boss_room", true)
	get_tree().reload_current_scene()
	return {"ok": true, "reloading": true, "route": "boss_room"}

func _engine_sample(now: int, frame_msec: float) -> Dictionary:
	return {
		"t_msec": now - _started_msec,
		"frame_msec": frame_msec,
		"physics_msec": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
	}

func _build_report() -> Dictionary:
	var duration_msec := maxi(1, Time.get_ticks_msec() - _started_msec)
	var average := _total_frame_msec / float(maxi(1, _frame_count))
	var sorted_frames: Array[float] = []
	for sample in _samples:
		sorted_frames.append(float(sample.get("frame_msec", 0.0)))
	sorted_frames.sort()
	var p99_index := clampi(int(sorted_frames.size() * 0.99), 0, maxi(0, sorted_frames.size() - 1))
	var scope_average_usec: Dictionary = {}
	for scope_name in _scope_totals:
		scope_average_usec[scope_name] = float(_scope_totals[scope_name]) / float(maxi(1, int(_scope_counts.get(scope_name, 1))))
	return {
		"schema": 1,
		"duration_msec": duration_msec,
		"frames": _frame_count,
		"average_frame_msec": average,
		"worst_frame_msec": _worst_frame_msec,
		"p99_frame_msec": sorted_frames[p99_index] if not sorted_frames.is_empty() else 0.0,
		"hitches_over_16_67ms": _hitches,
		"scopes_usec": _scope_totals.duplicate(),
		"scope_calls": _scope_counts.duplicate(),
		"scope_average_usec": scope_average_usec,
		"boot_phases_usec": _boot_phase_report(),
		"samples": _samples,
		"engine": {"version": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "platform": OS.get_name()},
	}

func _boot_phase_report() -> Dictionary:
	var bootstrap := get_parent().get_node_or_null("GameplayBootstrap")
	if bootstrap == null or not bootstrap.has_method("boot_phase_report"):
		return {}
	return bootstrap.call("boot_phase_report") as Dictionary

func _write_report(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := CAPTURE_DIR + "/capture-" + stamp + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
