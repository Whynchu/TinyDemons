extends SceneTree

const CatalogScript = preload("res://scripts/slime_variant_catalog.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var expected_stats := {
		&"grey": [2, 2, 2, 2, 0, 1],
		&"red": [1, 4, 2, 1, 2, 1],
		&"blue": [2, 1, 4, 1, 2, 3],
		&"yellow": [2, 2, 1, 3, 3, 1],
		&"green": [4, 1, 2, 1, 2, 2],
		&"purple": [1, 3, 1, 3, 3, 1],
		&"orange": [3, 1, 3, 1, 2, 2],
		&"aquamarine": [2, 2, 1, 3, 3, 2],
	}
	var expected_elements := {
		&"grey": ElementCatalogScript.Element.NEUTRAL,
		&"red": ElementCatalogScript.Element.FIRE,
		&"blue": ElementCatalogScript.Element.WATER,
		&"yellow": ElementCatalogScript.Element.ELECTRIC,
		&"green": ElementCatalogScript.Element.GRASS,
		&"purple": ElementCatalogScript.Element.SHADOW,
		&"orange": ElementCatalogScript.Element.GROUND,
		&"aquamarine": ElementCatalogScript.Element.ICE,
	}
	var stats := StatsComponent.new()
	for variant in CatalogScript.VARIANTS:
		var definition := CatalogScript.definition(variant)
		stats.apply_enemy_variant_profile(definition["base_stats"], definition["growth_weights"], variant)
		stats.level = 1
		var expected: Array = expected_stats[variant]
		_expect([stats.vit, stats.strength, stats.def, stats.agi, stats.intelligence, stats.mnd] == expected, "%s level-one six-stat profile is exact" % variant, failures)
		_expect(CatalogScript.element_for_variant(variant) == expected_elements[variant], "%s element is exact" % variant, failures)
		_expect(CatalogScript.damage_contract_for_variant(variant) == (&"physical" if variant == &"grey" else &"elemental_slime"), "%s damage contract is explicit" % variant, failures)
		_expect(CatalogScript.is_elemental_variant(variant) == (variant != &"grey") and stats.intelligence == expected[4], "%s INT contract matches neutral/elemental rule" % variant, failures)
		_expect(stats.mnd == expected[5], "%s MND is present as defensive magic stat" % variant, failures)
		_expect(CatalogScript.display_name_for_variant(variant) != "", "%s has a display name" % variant, failures)
	_expect(CatalogScript.display_name_for_variant(&"grey") == "Normal Slime", "Gray variant displays as Normal Slime", failures)

	var yellow := StatsComponent.new()
	var yellow_definition := CatalogScript.definition(&"yellow")
	yellow.apply_enemy_variant_profile(yellow_definition["base_stats"], yellow_definition["growth_weights"], &"yellow")
	yellow.level = 25
	_expect(yellow.speed > yellow.def, "Yellow growth favors SPD over DEF", failures)

	var purple := StatsComponent.new()
	var purple_definition := CatalogScript.definition(&"purple")
	purple.apply_enemy_variant_profile(purple_definition["base_stats"], purple_definition["growth_weights"], &"purple")
	purple.level = 25
	_expect(purple.speed > purple.vit and purple.strength > purple.def, "Purple growth preserves SPD/STR pressure", failures)
	_expect(purple.speed + purple.strength > purple.vit + purple.def, "Purple growth stays offensively weighted", failures)

	var ground := StatsComponent.new()
	var ground_definition := CatalogScript.definition(&"orange")
	ground.apply_enemy_variant_profile(ground_definition["base_stats"], ground_definition["growth_weights"], &"orange")
	ground.level = 25
	_expect(ground.def > ground.speed and ground.vit > ground.strength, "Ground growth preserves sturdy pressure", failures)

	var ice := StatsComponent.new()
	var ice_definition := CatalogScript.definition(&"aquamarine")
	ice.apply_enemy_variant_profile(ice_definition["base_stats"], ice_definition["growth_weights"], &"aquamarine")
	ice.level = 25
	_expect(ice.speed > ice.def and ice.speed > ice.vit, "Ice growth preserves SPD pressure", failures)

	var rooms := RoomController.new()
	var gray_seen := false
	var yellow_seen_at_rank_two := false
	var yellow_seen_before_rank_two := false
	var ground_seen_at_rank_three := false
	var ground_seen_before_rank_three := false
	var ice_seen_at_rank_four := false
	var ice_seen_before_rank_four := false
	rooms.progression_run_rank = 1
	for seed in 256:
		for variant in rooms._generate_enemy_encounter(seed, 0, false, false)["variants"] as Array:
			gray_seen = gray_seen or String(variant) == "grey"
			yellow_seen_before_rank_two = yellow_seen_before_rank_two or String(variant) == "yellow"
			ground_seen_before_rank_three = ground_seen_before_rank_three or String(variant) == "orange"
			ice_seen_before_rank_four = ice_seen_before_rank_four or String(variant) == "aquamarine"
	rooms.progression_run_rank = 2
	for seed in 256:
		for variant in rooms._generate_enemy_encounter(seed + 4000, 0, false, false)["variants"] as Array:
			yellow_seen_at_rank_two = yellow_seen_at_rank_two or String(variant) == "yellow"
			ground_seen_before_rank_three = ground_seen_before_rank_three or String(variant) == "orange"
			ice_seen_before_rank_four = ice_seen_before_rank_four or String(variant) == "aquamarine"
	rooms.progression_run_rank = 3
	for seed in 256:
		for variant in rooms._generate_enemy_encounter(seed + 8000, 0, false, false)["variants"] as Array:
			ground_seen_at_rank_three = ground_seen_at_rank_three or String(variant) == "orange"
			ice_seen_before_rank_four = ice_seen_before_rank_four or String(variant) == "aquamarine"
	rooms.progression_run_rank = 4
	for seed in 256:
		for variant in rooms._generate_enemy_encounter(seed + 12000, 0, false, false)["variants"] as Array:
			ice_seen_at_rank_four = ice_seen_at_rank_four or String(variant) == "aquamarine"
	_expect(gray_seen, "Gray can appear in base encounters", failures)
	_expect(not yellow_seen_before_rank_two, "Yellow is gated below run rank two", failures)
	_expect(yellow_seen_at_rank_two, "Yellow can appear from run rank two", failures)
	_expect(not ground_seen_before_rank_three, "Ground is gated below run rank three", failures)
	_expect(ground_seen_at_rank_three, "Ground can appear from run rank three", failures)
	_expect(not ice_seen_before_rank_four, "Ice is gated below run rank four", failures)
	_expect(ice_seen_at_rank_four, "Ice can appear from run rank four", failures)
	rooms.free()

	var source := load("res://assets/artwork/SlimeGreenLeft.png") as Texture2D
	_expect(source != null, "green direction texture loads for fallback recolors", failures)
	if source != null:
		for palette in ["grey", "yellow", "orange", "aquamarine"]:
			var recolored := SlimeVisualComponent.recolor_direction_texture(source, palette, {})
			_expect(recolored != null, "%s direction texture recolors" % palette, failures)
			if recolored == null:
				continue
			var image := recolored.get_image()
			var found_palette := false
			var found_green := false
			for y in image.get_height():
				for x in image.get_width():
					var color: Color = image.get_pixel(x, y)
					if color.a <= 0.0:
						continue
					if color.is_equal_approx(PaletteLibrary.normal(palette)):
						found_palette = true
					elif color.is_equal_approx(Color8(56, 183, 100)) or color.is_equal_approx(Color8(37, 113, 121)):
						found_green = true
			_expect(found_palette, "%s recolor introduces its palette tone" % palette, failures)
			_expect(not found_green, "%s recolor removes green tones" % palette, failures)

	stats.free()
	yellow.free()
	purple.free()
	ground.free()
	ice.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: slime variant smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SLIME_VARIANT_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
