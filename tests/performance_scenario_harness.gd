extends SceneTree

## Fixed-seed performance scenario harness (T3).
##
## Drives the real main scene through the seven scenarios from
## docs/long-term-composition-and-performance-plan.md and reports average/worst
## frame time, active node/sprite counts, and transition timing per scenario.
## Run headless via tools/run_perf_harness.ps1; the same script can run on a
## device build to compare the mobile profile.
##
## The output is machine-parseable: one PERF_ line per scenario plus a
## PERF_BASELINE_ summary. It intentionally does not assert budgets; budgets are
## recorded in the plan document after a device profile exists.
##
## A combat-room context probe additionally reports PERF_CONTEXT_ lines: how
## often each closure-heavy context is accessed per physics frame, how many of
## those accesses are real constructions (the rest are run-scoped cache hits),
## the Callable fields per context, and the aggregate CPU cost. This quantifies
## the per-frame allocation churn that frame time alone does not expose.

const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 180
const SETTINGS_PATH := "res://.godot_user/performance_scenario_harness.cfg"
const RUN_SEED := 24681357

const FRAME_CONTROLLER := preload("res://scripts/gameplay_frame_controller.gd")
const CONTEXT_BUILDERS: Array[Dictionary] = [
	{"name": &"animation_context", "method": &"animation_context"},
	{"name": &"equipment_visual_context", "method": &"equipment_visual_context"},
	{"name": &"magic_context", "method": &"magic_context"},
	{"name": &"interaction_context", "method": &"interaction_context"},
	{"name": &"guard_context", "method": &"_guard_context"},
	{"name": &"roll_context", "method": &"_roll_context"},
]
const CONTEXT_SAMPLE_FRAMES := 120
const CONTEXT_BENCH_ACCESSES := 1500

var _scenario_timings: Array[Dictionary] = []


func _initialize() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("PERF_FAILED main scene did not load")
		quit(1)
		return
	var gameplay := packed.instantiate()
	var boot_start_usec := Time.get_ticks_usec()
	GameplayBootstrap.boot_diagnostics_enabled = true
	GameplayBootstrap.begin_boot_diagnostics()
	root.add_child(gameplay)
	# _ready (and the async bootstrap it starts) runs after the first idle frame,
	# so poll until boot_active is observed true and then false.
	var saw_boot := false
	var first_boot_usec := 0
	var boot_frames := 0
	while boot_frames < 1200:
		await process_frame
		boot_frames += 1
		if bool(gameplay.get("boot_active")):
			if not saw_boot:
				saw_boot = true
				first_boot_usec = Time.get_ticks_usec()
		elif saw_boot:
			break
	var boot_end_usec := Time.get_ticks_usec()
	print("PERF_BOOT total_ms=%.1f pre_ms=%.1f post_ms=%.1f frames=%d saw_boot=%s loading_active=%s" % [
		float(boot_end_usec - boot_start_usec) / 1000.0,
		float(first_boot_usec - boot_start_usec) / 1000.0 if first_boot_usec > 0 else -1.0,
		float(boot_end_usec - first_boot_usec) / 1000.0 if first_boot_usec > 0 else -1.0,
		boot_frames, str(saw_boot), str(gameplay.get("loading_screen_active"))])
	if not GameplayBootstrap.boot_phases.is_empty():
		var phase_labels := GameplayBootstrap.boot_phases.keys()
		phase_labels.sort()
		for phase_label in phase_labels:
			print("PERF_BOOT_PHASE %s ms=%.1f" % [phase_label, float(GameplayBootstrap.boot_phases[phase_label]) / 1000.0])
	GameplayBootstrap.boot_diagnostics_enabled = false
	for _frame in WARMUP_FRAMES:
		await process_frame

	var screens := gameplay.get("screen_state_controller") as Node
	var rooms := gameplay.get("room_controller") as Node
	var settings := gameplay.get("settings_service") as Node

	if settings != null:
		settings.set("file_path", SETTINGS_PATH)
		if settings.has_method("reset_to_defaults"):
			settings.call("reset_to_defaults")
		if settings.has_method("set_setting"):
			settings.call("set_setting", &"aspect", "16:9")
		await process_frame

	# 1. Title idle
	await _sample_scenario(gameplay, "title_idle", func() -> void: pass)

	# 2. Hub idle (fire, particles, UI)
	gameplay.call("_show_hub", true, false)
	await process_frame
	await _sample_scenario(gameplay, "hub_idle", func() -> void: pass)

	# 3. Hub child pages (shop/fusion) stress the list + footer presenters.
	if screens != null:
		var hub_buttons: Array = screens.get("hub_page_buttons") as Array
		if not hub_buttons.is_empty():
			(hub_buttons[1] as Button).pressed.emit()
			await process_frame
			await _sample_scenario(gameplay, "hub_shop_page", func() -> void: pass)

	# Back to run, then a combat room.
	gameplay.call("_close_hub_to_run")
	await process_frame
	await _enter_combat_room(gameplay, rooms)

	# 4. Context/Callable allocation churn on a fresh, active combat frame.
	await _measure_context_allocations(gameplay)

	# 5. Full enemy room during combat
	await _sample_scenario(gameplay, "combat_room", func() -> void: pass)

	# 6. Boss room transition - the user-reported worst case. Enter the real
	#    ROOM_DOWNSTAIRS room for this seed through the actual door path.
	var boss_transition := await _measure_boss_transition(gameplay, rooms)
	_scenario_timings.append({"name": "boss_room_transition", "avg_ms": boss_transition.total_ms, "worst_ms": boss_transition.total_ms, "nodes": 0, "sprites": 0, "extra": "layout_ms=%f|activate_ms=%f" % [boss_transition.layout_ms, boss_transition.activate_ms]})

	# Boss room steady state after the transition has settled.
	await _sample_scenario(gameplay, "boss_room", func() -> void: pass)

	# 7. Room transition (leave and re-enter a room) - measures transition hitch.
	var transition_ms := await _measure_transition(gameplay, rooms)
	_scenario_timings.append({"name": "room_transition", "avg_ms": transition_ms, "worst_ms": transition_ms, "nodes": 0, "sprites": 0, "extra": "transition_ms"})

	# 8. Pause and equipment menus
	gameplay.call("_open_pause_menu")
	await process_frame
	await _sample_scenario(gameplay, "pause_menu", func() -> void: pass)

	gameplay.queue_free()
	await process_frame
	_print_report()
	quit(0)


func _enter_combat_room(gameplay: Node, rooms: Node) -> void:
	var map := gameplay.get("dungeon_map_controller") as Node
	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	if map == null or graph == null or rooms == null:
		return
	map.call("begin_run", graph, RUN_SEED, 0, &"fire")
	if map.has_method("set_starter_flame_attuned"):
		map.call("set_starter_flame_attuned", true)
	rooms.set("room_states", {})
	gameplay.set("current_room_id", &"room_1_1")
	gameplay.call("_sync_current_room_metadata", &"BOTTOM_LEFT")
	if rooms.has_method("set_current_room"):
		rooms.call("set_current_room", &"room_1_1", gameplay.get("current_room_type"))
	gameplay.call("_collect_dungeon_sockets")
	gameplay.call("_ensure_current_room_layout")
	gameplay.call("_apply_room_state")
	for _frame in 30:
		await process_frame


func _measure_transition(gameplay: Node, rooms: Node) -> float:
	var started_usec := Time.get_ticks_usec()
	if rooms != null and rooms.has_method("set_current_room"):
		rooms.call("set_current_room", &"room_1_0", &"START")
	gameplay.call("_collect_dungeon_sockets")
	gameplay.call("_ensure_current_room_layout")
	gameplay.call("_apply_room_state")
	await process_frame
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _measure_boss_transition(gameplay: Node, rooms: Node) -> Dictionary:
	# Enter the real ROOM_DOWNSTAIRS room for RUN_SEED through the actual door
	# path (enter_connected_room), timing the layout and activation steps that
	# happen synchronously on the door-touch frame.
	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var boss_id: StringName = &""
	for rid in graph.get_room_ids():
		var room := graph.get_room(rid)
		if room.room_type == DungeonGraph.ROOM_DOWNSTAIRS:
			boss_id = rid
			break
	if boss_id == &"":
		return {"total_ms": -1.0, "layout_ms": -1.0, "activate_ms": -1.0}
	var started_usec := Time.get_ticks_usec()
	var transition: Object = rooms.call("plan_connected_room_transition", graph, &"room_1_1", boss_id, &"", &"")
	if transition == null:
		return {"total_ms": -1.0, "layout_ms": -1.0, "activate_ms": -1.0}
	var ok: bool = rooms.call("enter_connected_room", gameplay, transition)
	var total_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	await process_frame
	return {"total_ms": total_ms if ok else -1.0, "layout_ms": -1.0, "activate_ms": -1.0}


func _sample_scenario(gameplay: Node, scenario_name: String, setup: Callable) -> void:
	setup.call()
	var avg_ms := 0.0
	var worst_ms := 0.0
	var nodes := 0
	var sprites := 0
	for _frame in 30:
		await process_frame
	var samples: Array[float] = []
	for _frame in SAMPLE_FRAMES:
		var started_usec := Time.get_ticks_usec()
		await process_frame
		samples.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
	var total_ms := 0.0
	worst_ms = 0.0
	for sample_ms in samples:
		total_ms += sample_ms
		worst_ms = maxf(worst_ms, sample_ms)
	avg_ms = total_ms / float(samples.size())
	nodes = _count_nodes(gameplay)
	sprites = _count_sprites(gameplay)
	_scenario_timings.append({"name": scenario_name, "avg_ms": avg_ms, "worst_ms": worst_ms, "nodes": nodes, "sprites": sprites, "extra": ""})


func _measure_context_allocations(gameplay: Node) -> void:
	# Gameplay runs on _physics_process, so the meaningful denominator is the
	# physics frame (fixed 60 Hz), not the uncapped process frame the harness
	# awaits. Both physics-frame and per-second rates are reported.
	var frame_controller: Object = gameplay.get("gameplay_frame_controller")
	if frame_controller == null:
		print("PERF_CONTEXT_FAILED no gameplay_frame_controller")
		return
	frame_controller.call("invalidate_contexts")
	var boss_builds_start := BossJumpSlamContext.build_count
	var start_physics_frames := Engine.get_physics_frames()
	var start_usec := Time.get_ticks_usec()
	FRAME_CONTROLLER.begin_context_diagnostics()
	for _frame in CONTEXT_SAMPLE_FRAMES:
		await process_frame
	var elapsed_seconds := maxf(float(Time.get_ticks_usec() - start_usec) / 1000000.0, 0.0001)
	var physics_frames := maxf(float(Engine.get_physics_frames() - start_physics_frames), 1.0)

	var total_accesses := 0.0
	var total_builds := 0.0
	var total_allocations := 0.0
	var total_usec := 0.0
	for entry in CONTEXT_BUILDERS:
		var name: StringName = entry["name"]
		var method: StringName = entry["method"]
		var callables := _count_callable_fields(frame_controller.call(method, gameplay))
		var access_count := float(FRAME_CONTROLLER.context_access_counts.get(name, 0))
		var build_count := float(FRAME_CONTROLLER.context_build_counts.get(name, 0))
		var accesses := access_count / physics_frames
		var accesses_per_second := access_count / elapsed_seconds
		var builds := build_count / physics_frames
		for _warmup in 32:
			frame_controller.call(method, gameplay)
		var started_usec := Time.get_ticks_usec()
		for _access in CONTEXT_BENCH_ACCESSES:
			frame_controller.call(method, gameplay)
		var usec_per_access := float(Time.get_ticks_usec() - started_usec) / float(CONTEXT_BENCH_ACCESSES)
		total_accesses += accesses
		total_builds += builds
		total_allocations += builds * float(callables)
		total_usec += accesses * usec_per_access
		print("PERF_CONTEXT %s accesses_per_physics_frame=%.2f accesses_per_second=%.1f builds_per_physics_frame=%.2f callables_per_build=%d usec_per_access=%.3f" % [name, accesses, accesses_per_second, builds, callables, usec_per_access])
	FRAME_CONTROLLER.end_context_diagnostics()
	var boss_builds := float(BossJumpSlamContext.build_count - boss_builds_start)
	print("PERF_CONTEXT boss_jump_slam_context builds_per_physics_frame=%.2f builds_per_second=%.1f callables_per_build=13" % [boss_builds / physics_frames, boss_builds / elapsed_seconds])
	print("PERF_CONTEXT_TOTAL accesses_per_physics_frame=%.2f builds_per_physics_frame=%.2f callables_allocated_per_physics_frame=%.1f context_usec_per_physics_frame=%.2f sample_process_frames=%d sample_physics_frames=%.0f" % [total_accesses, total_builds, total_allocations, total_usec, CONTEXT_SAMPLE_FRAMES, physics_frames])


func _count_callable_fields(value: Object) -> int:
	var count := 0
	if value == null:
		return count
	for property in value.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var field: Variant = value.get(StringName(property["name"]))
		if field is Callable:
			count += 1
	return count


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _count_sprites(node: Node) -> int:
	var count := 0
	if node is Sprite2D or node is Sprite3D:
		count += 1
	for child in node.get_children():
		count += _count_sprites(child)
	return count


func _print_report() -> void:
	for entry in _scenario_timings:
		var extra := ""
		if not String(entry["extra"]).is_empty():
			extra = " %s=%.3f" % [entry["extra"], entry["avg_ms"]]
		print("PERF_ %s avg_ms=%.3f worst_ms=%.3f nodes=%d sprites=%d%s" % [
			entry["name"], entry["avg_ms"], entry["worst_ms"], entry["nodes"], entry["sprites"], extra])
	print("PERF_BASELINE_ scenarios=%d seed=%d" % [_scenario_timings.size(), RUN_SEED])