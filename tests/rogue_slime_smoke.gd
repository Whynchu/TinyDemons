extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var stats := StatsComponent.new()
	stats.allocation_profile = StatsComponent.AllocationProfile.FAVOR_STR_DEF
	stats.level = 1
	_expect(stats.vit < stats.strength, "rogue profile favors STR over VIT", failures)
	_expect(stats.vit < stats.def, "rogue profile favors DEF over VIT", failures)
	_expect(stats.strength >= 3, "rogue base STR is strong", failures)
	_expect(stats.def >= 3, "rogue base DEF is strong", failures)
	var level_high := StatsComponent.new()
	level_high.allocation_profile = StatsComponent.AllocationProfile.FAVOR_STR_DEF
	level_high.level = 25
	var level_balanced := StatsComponent.new()
	level_balanced.allocation_profile = StatsComponent.AllocationProfile.BALANCED
	level_balanced.level = 25
	_expect(float(level_high.vit) / float(level_high.strength) < float(level_balanced.vit) / float(level_balanced.strength), "rogue growth keeps VIT relatively lower than balanced profile", failures)

	var rooms := RoomController.new()
	for rank in [1, 3, 5, 8, 12]:
		rooms.progression_run_rank = rank
		for seed in 128:
			var encounter := rooms._generate_boss_encounter(seed + rank * 1000, 12)
			var variants := encounter["variants"] as Array
			_expect("purple" in variants, "boss encounter includes a rogue at rank %d seed %d" % [rank, seed], failures)
	rooms.free()

	var source := load("res://assets/artwork/SlimeGreenLeft.png") as Texture2D
	_expect(source != null, "green direction texture loads", failures)
	if source != null:
		var purple := SlimeVisualComponent.recolor_direction_texture(source, "purple", {})
		_expect(purple != null, "purple direction texture recolors", failures)
		if purple != null:
			var image := purple.get_image()
			var found_purple := false
			var found_green := false
			for y in image.get_height():
				for x in image.get_width():
					var color: Color = image.get_pixel(x, y)
					if color.a <= 0.0:
						continue
					if color.is_equal_approx(Color8(118, 78, 142)):
						found_purple = true
					elif color.is_equal_approx(Color8(56, 183, 100)) or color.is_equal_approx(Color8(37, 113, 121)):
						found_green = true
			_expect(found_purple, "purple recolor actually introduces purple mid tone", failures)
			_expect(not found_green, "purple recolor removes green tones", failures)

	var actor := Sprite2D.new()
	actor.texture = source
	var ambush := SlimeAmbushComponent.new()
	actor.add_child(ambush)
	ambush.configure(true, 0.5, 1.0, 0.5)
	ambush.apply_hidden(actor)
	_expect(ambush.is_hidden(), "ambush starts hidden", failures)
	_expect(actor.self_modulate.a < 1.0, "hidden actor is transparent", failures)
	ambush.reveal(actor)
	ambush.begin_rehide(actor, 0.5)
	_expect(not ambush.is_hidden(), "reveal clears hidden", failures)
	_expect(actor.self_modulate.a >= 1.0, "revealed actor is opaque", failures)
	ambush.tick(actor, 0.25)
	_expect(not ambush.is_hidden(), "rogue stays revealed inside reveal window", failures)
	ambush.tick(actor, 0.24)
	_expect(not ambush.is_hidden(), "rogue revealed just before 0.5s window elapses", failures)
	ambush.tick(actor, 0.02)
	_expect(ambush.is_hidden(), "rogue re-hides as the 0.5s reveal window expires", failures)
	ambush.reveal(actor)
	ambush.begin_block_stun(actor)
	_expect(not ambush.is_hidden(), "block stun keeps rogue revealed", failures)
	ambush.tick(actor, 0.5)
	_expect(not ambush.is_hidden(), "block stun holds past normal reveal window", failures)
	ambush.tick(actor, 0.49)
	_expect(not ambush.is_hidden(), "block stun holds at 0.99s", failures)
	ambush.tick(actor, 0.02)
	_expect(ambush.is_hidden(), "block stun ends and rogue re-hides", failures)
	ambush.reveal(actor)
	ambush.begin_rehide(actor, 0.5)
	ambush.extend_rehide(actor, 0.5)
	ambush.tick(actor, 0.5)
	_expect(not ambush.is_hidden(), "hit extension delays re-hide past base window", failures)
	ambush.tick(actor, 0.6)
	_expect(ambush.is_hidden(), "extended window eventually completes", failures)
	actor.free()
	stats.free()
	level_high.free()
	level_balanced.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: rogue slime smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ROGUE_SLIME_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)