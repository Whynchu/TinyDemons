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
	rooms.player_level = 10
	var boss_purple_count := 0
	var boss_minor_slot_count := 0
	for rank in [1, 3, 5, 8, 12]:
		rooms.progression_run_rank = rank
		for seed in 128:
			var encounter := rooms._generate_boss_encounter(seed + rank * 1000, 12)
			var variants := encounter["variants"] as Array
			var scales := encounter["scales"] as Array
			var popcorn := encounter["popcorn"] as Array
			var expected_minor_count := 0 if rank < 5 else 1 if rank == 5 else 2 if rank == 6 else 2 + floori(float(rank - 7) / 3.0)
			_expect(String(variants[0]) != "purple", "scaled lead boss excludes the purple variant at rank %d seed %d" % [rank, seed], failures)
			_expect(variants.size() == scales.size() and variants.size() == popcorn.size(), "boss support slots keep encounter arrays aligned at rank %d seed %d" % [rank, seed], failures)
			_expect(variants.size() == 1 + expected_minor_count + rooms._boss_support_popcorn_count(), "boss encounter uses the expected mixed-support roster at Run %d" % rank, failures)
			var last_support_index := variants.size() - 1
			_expect(last_support_index > 0 and String(variants[last_support_index]) == "grey" and bool(popcorn[last_support_index]) and int((encounter["levels"] as Array)[last_support_index]) == rooms._popcorn_enemy_level(), "boss encounter guarantees a Normal Slime popcorn slot at rank %d seed %d" % [rank, seed], failures)
			if rank < 5:
				for neutral_index in range(1, variants.size()):
					_expect(String(variants[neutral_index]) == "grey" and bool(popcorn[neutral_index]), "Runs 1–4 boss support stays neutral popcorn at rank %d seed %d" % [rank, seed], failures)
			var support_count := 0
			for popcorn_value in popcorn:
				if bool(popcorn_value):
					support_count += 1
			var expected_support_count := 2 if rank <= 2 else 3 if rank <= 6 else 4
			_expect(support_count == expected_support_count and support_count == rooms._boss_support_popcorn_count() and support_count >= 2, "boss encounter scales to %d Normal Slime popcorn supports at Run %d" % [expected_support_count, rank], failures)
			boss_minor_slot_count += variants.size() - 1
			for variant_index in range(1, variants.size()):
				if String(variants[variant_index]) == "purple":
					boss_purple_count += 1
			_expect(float(scales[0]) > 1.0, "boss encounter leads with a scaled boss at rank %d seed %d" % [rank, seed], failures)
	_expect(boss_purple_count > 0, "rare boss sampling still permits an occasional purple minor", failures)
	_expect(float(boss_purple_count) / float(boss_minor_slot_count) < 0.12, "purple minors stay rare in boss encounters", failures)
	var expected_caps := {1: 3, 2: 5, 3: 6, 4: 7}
	for tested_player_level in [1, 4, 5, 6, 10, 30]:
		rooms.player_level = tested_player_level
		var expected_popcorn_level := maxi(1, tested_player_level - 5)
		_expect(rooms._popcorn_enemy_level() == expected_popcorn_level, "player level %d produces level %d popcorn enemies" % [tested_player_level, expected_popcorn_level], failures)
	rooms.player_level = 1
	# Flat difficulty: enemy level no longer grows with room depth. The
	# generated base level is rank - 1 with a +/-20% spread (min spread 1), so
	# a rank N encounter peaks at level N (never at the depth-scaled cap).
	for rank in [1, 2, 3, 4]:
		rooms.progression_run_rank = rank
		var maximum_seen := 0
		var level_one_count := 0
		var level_count := 0
		for seed in 256:
			var encounter := rooms._generate_enemy_encounter(seed + rank * 3000, 12, false, false)
			for level_value in encounter["levels"] as Array:
				var level := int(level_value)
				maximum_seen = maxi(maximum_seen, level)
				level_one_count += 1 if level == 1 else 0
				level_count += 1
		_expect(maximum_seen <= rank, "Run %d flat enemy levels stay at or below rank %d" % [rank, rank], failures)
		_expect(maximum_seen == rank, "Run %d flat encounter generation peaks at level %d" % [rank, rank], failures)
		if rank == 2:
			_expect(float(level_one_count) / float(maxi(level_count, 1)) >= 0.30, "Run 2 keeps a substantial level 1 popcorn population", failures)
	rooms.progression_run_rank = 8
	var regular_purple_count := 0
	var regular_slot_count := 0
	var shadow_popcorn_count := 0
	for seed in 256:
		var encounter := rooms._generate_enemy_encounter(seed + 4000, 8, false, true)
		var variants := encounter["variants"] as Array
		var levels := encounter["levels"] as Array
		var popcorn := encounter["popcorn"] as Array
		regular_slot_count += variants.size()
		for variant in variants:
			if String(variant) == "purple":
				regular_purple_count += 1
		if variants.has("purple"):
			var has_shadow_popcorn := false
			for index in variants.size():
				if bool(popcorn[index]):
					has_shadow_popcorn = true
					_expect(String(variants[index]) == "grey", "Shadow encounters reserve popcorn slots for Normal Slimes", failures)
					_expect(int(levels[index]) == rooms._popcorn_enemy_level(), "Shadow popcorn slots use the low-level recovery curve", failures)
					shadow_popcorn_count += 1
			_expect(has_shadow_popcorn, "every Shadow encounter guarantees a Normal Slime popcorn slot", failures)
	_expect(regular_purple_count > 0, "regular encounter sampling still permits an occasional purple", failures)
	_expect(float(regular_purple_count) / float(regular_slot_count) < 0.12, "purple variants stay rare in regular encounters", failures)
	_expect(shadow_popcorn_count > 0, "shadow encounters produce a Normal Slime popcorn slot", failures)
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
