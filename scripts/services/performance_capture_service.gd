extends Node

## Debug-only runtime capture. It is inert unless explicitly started.
const CAPTURE_DIR := "user://performance-captures"
const SAMPLE_INTERVAL := 0.25
const WARMUP_MSEC := 1000
const THROUGHPUT_WINDOW_USEC := 1000000
const HITCH_THRESHOLD_MSEC := 16.67
const MAX_SAMPLES := 2400

var capturing := false
var scope_capture_enabled := true
var _capture_started_usec := 0
var _started_msec := 0
var _started_usec := 0
var _last_frame_usec := 0
var _last_sample_msec := 0
var _samples: Array[Dictionary] = []
var _frame_intervals_msec: Array[float] = []
var _throughput_windows: Array[Dictionary] = []
var _window_started_usec := 0
var _window_frame_count := 0
var _hitches := 0
var _worst_frame_msec := 0.0
var _total_frame_msec := 0.0
var _frame_count := 0
var _last_report: Dictionary = {}
var _scope_totals: Dictionary = {}
var _scope_counts: Dictionary = {}
var _overlay: Label = null
var _overlay_elapsed := 0.0


func _ready() -> void:
	# Phone runs usually have no keyboard for the F9 shortcut. Keep this opt-in
	# so a debug build can start capture from project settings without changing
	# release behavior or adding a permanent HUD element.
	if bool(ProjectSettings.get_setting("debug/performance_capture_on_boot", false)):
		call_deferred("start_capture")

func _process(_delta: float) -> void:
	if not capturing:
		return
	var now := Time.get_ticks_msec()
	var now_usec := Time.get_ticks_usec()
	if _started_usec == 0:
		if now_usec - _capture_started_usec < WARMUP_MSEC * 1000:
			return
		_started_msec = now
		_started_usec = now_usec
		_last_frame_usec = now_usec
		_last_sample_msec = now
		_window_started_usec = now_usec
		_overlay_elapsed = 0.0
		_update_overlay()
		return
	var frame_msec := float(now_usec - _last_frame_usec) / 1000.0
	_last_frame_usec = now_usec
	var process_msec := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_frame_count += 1
	_total_frame_msec += process_msec
	_frame_intervals_msec.append(frame_msec)
	_window_frame_count += 1
	_worst_frame_msec = maxf(_worst_frame_msec, frame_msec)
	if frame_msec >= HITCH_THRESHOLD_MSEC:
		_hitches += 1
	if now_usec - _window_started_usec >= THROUGHPUT_WINDOW_USEC:
		_throughput_windows.append(_make_throughput_window(_window_started_usec, now_usec, _window_frame_count))
		_window_started_usec = now_usec
		_window_frame_count = 0
	if now - _last_sample_msec < int(SAMPLE_INTERVAL * 1000.0):
		_update_overlay()
		return
	_last_sample_msec = now
	if _samples.size() >= MAX_SAMPLES:
		_samples.pop_front()
	_samples.append(_engine_sample(now, frame_msec, process_msec))
	_update_overlay()
	if _samples.size() >= MAX_SAMPLES:
		stop_capture()

func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") and not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:
			if capturing:
				stop_capture()
			else:
				start_capture()

func start_capture(enable_scopes: bool = true) -> Dictionary:
	if capturing:
		return {"ok": false, "error": "capture_already_running"}
	capturing = true
	scope_capture_enabled = enable_scopes
	_create_overlay()
	_capture_started_usec = Time.get_ticks_usec()
	_started_msec = 0
	_started_usec = 0
	_last_frame_usec = 0
	_last_sample_msec = 0
	_samples.clear()
	_frame_intervals_msec.clear()
	_throughput_windows.clear()
	_window_started_usec = 0
	_window_frame_count = 0
	_hitches = 0
	_worst_frame_msec = 0.0
	_total_frame_msec = 0.0
	_frame_count = 0
	_last_report = {}
	_scope_totals.clear()
	_scope_counts.clear()
	_overlay_elapsed = 0.0
	return {"ok": true, "warming_up_msec": WARMUP_MSEC, "scopes_enabled": scope_capture_enabled}

func record_scope(scope_name: StringName, elapsed_usec: int) -> void:
	if not capturing or not scope_capture_enabled or _started_usec == 0:
		return
	var key := String(scope_name)
	_scope_totals[key] = int(_scope_totals.get(key, 0)) + elapsed_usec
	_scope_counts[key] = int(_scope_counts.get(key, 0)) + 1

func stop_capture(additional_report: Dictionary = {}) -> Dictionary:
	if not capturing:
		return _last_report if not _last_report.is_empty() else {"ok": false, "error": "capture_not_running"}
	capturing = false
	_hide_overlay()
	var stopped_usec := Time.get_ticks_usec()
	if _started_usec > 0 and _window_started_usec > 0:
		var current_window := _make_throughput_window(_window_started_usec, stopped_usec, _window_frame_count)
		if int(current_window.get("frames", 0)) > 0:
			_throughput_windows.append(current_window)
	var report := _build_report()
	report.merge(additional_report, true)
	var report_path := _write_report(report)
	if not report_path.is_empty():
		report["output_path"] = report_path
		print("PERFORMANCE_CAPTURE_REPORT=%s" % report_path)
	else:
		push_error("PERFORMANCE_CAPTURE_REPORT_WRITE_FAILED")
	_last_report = report
	return report

func get_status() -> Dictionary:
	return {"capturing": capturing, "warming_up": capturing and _started_usec == 0, "samples": _samples.size(), "frames": _frame_count, "scopes_enabled": scope_capture_enabled, "last_report": _last_report}

func get_last_report_json() -> String:
	return JSON.stringify(_last_report if not _last_report.is_empty() else get_status())


func _create_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = true
		return
	var layer := CanvasLayer.new()
	layer.name = "PerformanceCaptureOverlay"
	layer.layer = 200
	add_child(layer)
	_overlay = Label.new()
	_overlay.name = "Readout"
	_overlay.position = Vector2(4, 4)
	_overlay.add_theme_font_size_override("font_size", 12)
	_overlay.add_theme_color_override("font_color", Color8(255, 235, 120))
	_overlay.add_theme_color_override("font_shadow_color", Color.BLACK)
	_overlay.add_theme_constant_override("shadow_offset_x", 1)
	_overlay.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_overlay)


func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.visible = false


func _update_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	if _started_usec == 0:
		_overlay.text = "PERF warming up... %d ms" % WARMUP_MSEC
		return
	_overlay_elapsed += get_process_delta_time()
	if _overlay_elapsed < SAMPLE_INTERVAL:
		return
	_overlay_elapsed = 0.0
	var elapsed_sec := float(Time.get_ticks_usec() - _started_usec) / 1000000.0
	var fps := float(_frame_count) / maxf(elapsed_sec, 0.001)
	var average_process_msec := _total_frame_msec / float(maxi(1, _frame_count))
	var wall_average_msec := float(Time.get_ticks_usec() - _started_usec) / 1000.0 / float(maxi(1, _frame_count))
	_overlay.text = "PERF  %.1f FPS  CPU %.1f ms\nWALL %.1f ms  worst %.1f ms\nNodes %d  Draw %d  Hitches %d" % [
		fps,
		average_process_msec,
		wall_average_msec,
		_worst_frame_msec,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_hitches,
	]

func prepare_benchmark_run() -> Dictionary:
	if not OS.has_feature("editor") and not OS.is_debug_build():
		return {"ok": false, "error": "debug_only"}
	ProjectSettings.set_setting("debug/benchmark_start_in_boss_room", true)
	get_tree().reload_current_scene()
	return {"ok": true, "reloading": true, "route": "boss_room"}

func _engine_sample(now: int, frame_msec: float, process_msec: float) -> Dictionary:
	return {
		"t_msec": now - _started_msec,
		"frame_msec": frame_msec,
		"process_msec": process_msec,
		"physics_msec": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_memory": Performance.get_monitor(Performance.MEMORY_STATIC),
	}

func _make_throughput_window(started_usec: int, stopped_usec: int, frames: int) -> Dictionary:
	var duration_msec := float(maxi(1, stopped_usec - started_usec)) / 1000.0
	return {
		"duration_msec": duration_msec,
		"frames": frames,
		"fps": float(frames) * 1000.0 / duration_msec,
	}

func _percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	var index := clampi(ceili(quantile * float(sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]

func _build_report() -> Dictionary:
	var duration_msec := maxi(1, int((Time.get_ticks_usec() - _started_usec) / 1000)) if _started_usec > 0 else 1
	var average_process_msec := _total_frame_msec / float(maxi(1, _frame_count))
	var average_frame_msec := float(duration_msec) / float(maxi(1, _frame_count))
	var sorted_frames: Array[float] = []
	for sample in _samples:
		sorted_frames.append(float(sample.get("process_msec", 0.0)))
	sorted_frames.sort()
	var scope_average_usec: Dictionary = {}
	var scope_msec_per_rendered_frame: Dictionary = {}
	var scope_msec_per_second: Dictionary = {}
	for scope_name in _scope_totals:
		scope_average_usec[scope_name] = float(_scope_totals[scope_name]) / float(maxi(1, int(_scope_counts.get(scope_name, 1))))
		scope_msec_per_rendered_frame[scope_name] = float(_scope_totals[scope_name]) / 1000.0 / float(maxi(1, _frame_count))
		scope_msec_per_second[scope_name] = float(_scope_totals[scope_name]) / 1000.0 / (float(duration_msec) / 1000.0)
	return {
		"schema": 3,
		"capture_kind": "headless_cpu_diagnostic" if DisplayServer.get_name() == "headless" else "runtime_capture",
		"scene_path": get_parent().scene_file_path if get_parent() != null else "",
		"rendering_metrics_available": DisplayServer.get_name() != "headless",
		"warmup_msec": WARMUP_MSEC,
		"scopes_enabled": scope_capture_enabled,
		"duration_msec": duration_msec,
		"frames": _frame_count,
		"average_fps": float(_frame_count) * 1000.0 / float(duration_msec),
		"average_frame_msec": average_frame_msec,
		"wall_frame_p50_msec": _percentile(_frame_intervals_msec, 0.50),
		"wall_frame_p95_msec": _percentile(_frame_intervals_msec, 0.95),
		"wall_frame_p99_msec": _percentile(_frame_intervals_msec, 0.99),
		"average_process_msec": average_process_msec,
		"worst_frame_msec": _worst_frame_msec,
		"p99_sampled_process_msec": _percentile(sorted_frames, 0.99),
		"throughput_windows": _throughput_windows.duplicate(true),
		"hitches_over_16_67ms": _hitches,
		"scopes_usec": _scope_totals.duplicate(),
		"scope_calls": _scope_counts.duplicate(),
		"scope_average_usec": scope_average_usec,
		"scope_msec_per_rendered_frame": scope_msec_per_rendered_frame,
		"scope_msec_per_second": scope_msec_per_second,
		"boot_phases_usec": _boot_phase_report(),
		"samples": _samples,
		"environment": {
			"version": Engine.get_version_info(),
			"renderer": RenderingServer.get_current_rendering_method(),
			"platform": OS.get_name(),
			"processor": OS.get_processor_name(),
			"processor_count": OS.get_processor_count(),
			"debug_build": OS.is_debug_build(),
			"editor": OS.has_feature("editor"),
			"window_size": [get_window().size.x, get_window().size.y] if get_window() != null else [],
			"window_focused": get_window().has_focus() if get_window() != null else false,
			"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(),
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
			"max_fps": Engine.max_fps,
		},
	}

func _boot_phase_report() -> Dictionary:
	var bootstrap := get_parent().get_node_or_null("GameplayBootstrap")
	if bootstrap == null or not bootstrap.has_method("boot_phase_report"):
		return {}
	return bootstrap.call("boot_phase_report") as Dictionary

func _write_report(report: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := CAPTURE_DIR + "/capture-" + stamp + ".json"
	var absolute_path := ProjectSettings.globalize_path(path)
	report["output_path"] = absolute_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	return absolute_path
