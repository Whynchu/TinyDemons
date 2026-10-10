extends SceneTree

## Short CPU-side diagnostic for the fixed-seed mixed Run 30 encounter.
## Run with tools/run_headless.ps1 -Script res://tools/profile_run30_headless.gd.
const RUN_SCENE := "res://scenes/debug/boss_room_debug.tscn"
const CAPTURE_SECONDS := 10.0
const WARMUP_SECONDS := 1.0
const SERVICE_NAME := "PerformanceCaptureService"


func _initialize() -> void:
	call_deferred("_launch_profile")


func _launch_profile() -> void:
	var packed_scene := load(RUN_SCENE) as PackedScene
	if packed_scene == null:
		push_error("HEADLESS_PROFILE_FAILED: could not load %s" % RUN_SCENE)
		quit(2)
		return

	var startup_started_usec := Time.get_ticks_usec()
	var gameplay_root := packed_scene.instantiate()
	root.add_child(gameplay_root)

	var capture_service: Node = null
	for _attempt in range(120):
		capture_service = root.find_child(SERVICE_NAME, true, false)
		if capture_service != null:
			break
		await process_frame
	if capture_service == null:
		push_error("HEADLESS_PROFILE_FAILED: PerformanceCaptureService did not start")
		quit(2)
		return

	var start_result: Dictionary = capture_service.call("start_capture") as Dictionary
	if not bool(start_result.get("ok", false)):
		push_error("HEADLESS_PROFILE_FAILED: %s" % JSON.stringify(start_result))
		quit(2)
		return

	var boot_observed := false
	var boot_completed := false
	for _frame in range(600):
		await process_frame
		if bool(gameplay_root.get("boot_active")):
			boot_observed = true
		elif boot_observed:
			boot_completed = true
			break
	var startup_wall_msec := float(Time.get_ticks_usec() - startup_started_usec) / 1000.0

	var status: Dictionary = capture_service.call("get_status") as Dictionary
	var remaining_warmup := WARMUP_SECONDS if bool(status.get("warming_up", false)) else 0.0
	await create_timer(CAPTURE_SECONDS + remaining_warmup).timeout

	var report: Dictionary = capture_service.call("stop_capture", {
		"startup_wall_msec": startup_wall_msec,
		"startup_observed": boot_observed,
		"startup_completed": boot_completed,
	}) as Dictionary
	print("HEADLESS_PROFILE_SUMMARY=%s" % JSON.stringify({
		"capture_kind": "headless_cpu_diagnostic",
		"report_path": report.get("output_path", ""),
		"scene": RUN_SCENE,
		"startup_wall_msec": report.get("startup_wall_msec", 0.0),
		"startup_observed": report.get("startup_observed", false),
		"startup_completed": report.get("startup_completed", false),
		"duration_msec": report.get("duration_msec", 0),
		"frames": report.get("frames", 0),
		"average_fps": report.get("average_fps", 0.0),
		"wall_frame_p95_msec": report.get("wall_frame_p95_msec", 0.0),
		"scope_msec_per_rendered_frame": report.get("scope_msec_per_rendered_frame", {}),
		"boot_phases_usec": report.get("boot_phases_usec", {}),
	}))
	quit()
