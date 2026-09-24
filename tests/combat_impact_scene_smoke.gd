extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for combat impact coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	gameplay.set("debug_start_in_boss_room", true)
	root.add_child(gameplay)
	var boot_ready := false
	for _frame in 600:
		await process_frame
		if not bool(gameplay.get("boot_active")) and gameplay.get("chest_gray_texture") != null:
			boot_ready = true
			break
	_expect(boot_ready, "gameplay bootstrap is ready for combat impact coverage", failures)
	if not boot_ready:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return
	for _frame in 60:
		await process_frame

	var effects := gameplay.get("effects_spawner") as EffectsSpawner
	var display := gameplay.get("display_controller") as DisplayController
	var camera := gameplay.get_viewport().get_camera_2d() as Camera2D
	var target: Sprite2D = null
	var critical_target: Sprite2D = null
	for slime in gameplay.get("slimes") as Array[Sprite2D]:
		if not bool(gameplay.call("_is_slime_dead", slime)):
			if target == null:
				target = slime
			else:
				critical_target = slime
				break
	if critical_target == null:
		critical_target = target
	if target != null:
		gameplay.call("_finish_slime_spawn", target)
	if critical_target != null and critical_target != target:
		gameplay.call("_finish_slime_spawn", critical_target)
	_expect(effects != null and display != null and camera != null, "combat impact owners and active camera are composed", failures)
	_expect(target != null and critical_target != null, "combat impact scene provides a targetable slime", failures)
	if effects != null and display != null and camera != null and target != null and critical_target != null:
		var base_offset := camera.offset
		gameplay.call("_damage_slime", target, 1.0, false, 0, false)
		var normal_burst_count := _count_effects(effects, &"combat_hit")
		_expect(normal_burst_count == 7, "normal landed hit emits a flash and six impact sparks", failures)
		_expect(display.screen_shake_remaining_value() > 0.0 and camera.offset != base_offset, "normal landed hit requests light screen shake", failures)
		_expect(effects.damage_numbers.size() > 0, "normal landed hit still emits its damage number", failures)
		gameplay.call("_damage_slime", critical_target, 1.0, true, 0, false)
		_expect(_count_effects(effects, &"combat_hit") == 18, "critical hit emits the denser impact burst", failures)
		_expect(display.screen_shake_offset_value().length() <= 3.0, "critical hit remains inside the camera shake budget", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _count_effects(effects: EffectsSpawner, tag: StringName) -> int:
	var count := 0
	for particle_data: Dictionary in effects.pixel_particles:
		if particle_data.get("effect_tag", &"") == tag:
			count += 1
	return count


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("COMBAT_IMPACT_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
