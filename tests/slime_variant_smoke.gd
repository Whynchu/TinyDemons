extends SceneTree

const CatalogScript = preload("res://scripts/slime_variant_catalog.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const MATERIAL_SCRIPT = preload("res://scripts/actor_palette_material.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var stats := StatsComponent.new()
	for variant in CatalogScript.variants():
		var definition := EnemyFactoryScript.definition(variant)
		_expect(definition != null and definition.id == variant, "%s resolves to its typed registry definition" % variant, failures)
		if definition == null:
			continue
		stats.apply_enemy_variant_profile(definition.base_stats, definition.growth_weights, variant)
		stats.level = 1
		_expect(stats.vit >= int(definition.base_stats.get("VIT", 0)) and stats.strength >= int(definition.base_stats.get("STR", 0)) and stats.def >= int(definition.base_stats.get("DEF", 0)) and stats.agi >= int(definition.base_stats.get("AGI", 0)) and stats.intelligence >= int(definition.base_stats.get("INT", 0)) and stats.mnd >= int(definition.base_stats.get("MND", 0)), "%s level-one stats honor the authored base profile" % variant, failures)
		_expect(ElementCatalogScript.is_valid(definition.element), "%s element is valid" % variant, failures)
		_expect(not definition.damage_contract.is_empty(), "%s damage contract is explicit" % variant, failures)
		_expect(not definition.display_name.is_empty() and not definition.visual_source.is_empty(), "%s has display and visual identity" % variant, failures)
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
	var yellow_seen_at_rank_five := false
	var yellow_seen_before_rank_five := false
	var ground_seen_at_rank_five := false
	var ground_seen_before_rank_five := false
	var ice_seen_at_rank_five := false
	var ice_seen_before_rank_five := false
	rooms.progression_run_rank = 1
	for seed in 256:
		for variant in rooms._generate_enemy_encounter(seed, 0, false, false)["variants"] as Array:
			gray_seen = gray_seen or String(variant) == "grey"
			yellow_seen_before_rank_five = yellow_seen_before_rank_five or String(variant) == "yellow"
			ground_seen_before_rank_five = ground_seen_before_rank_five or String(variant) == "orange"
			ice_seen_before_rank_five = ice_seen_before_rank_five or String(variant) == "aquamarine"
	rooms.progression_run_rank = 4
	for seed in 256:
		for variant in rooms._generate_enemy_encounter(seed + 4000, 0, false, false)["variants"] as Array:
			yellow_seen_before_rank_five = yellow_seen_before_rank_five or String(variant) == "yellow"
			ground_seen_before_rank_five = ground_seen_before_rank_five or String(variant) == "orange"
			ice_seen_before_rank_five = ice_seen_before_rank_five or String(variant) == "aquamarine"
	rooms.progression_run_rank = 5
	for seed in 256:
		for variant in rooms._generate_enemy_encounter(seed + 8000, 0, false, false)["variants"] as Array:
			yellow_seen_at_rank_five = yellow_seen_at_rank_five or String(variant) == "yellow"
			ground_seen_at_rank_five = ground_seen_at_rank_five or String(variant) == "orange"
			ice_seen_at_rank_five = ice_seen_at_rank_five or String(variant) == "aquamarine"
	_expect(gray_seen, "Gray can appear in base encounters", failures)
	_expect(not yellow_seen_before_rank_five, "Electric is gated below run rank five", failures)
	_expect(yellow_seen_at_rank_five, "Electric can appear from run rank five", failures)
	_expect(not ground_seen_before_rank_five, "Ground is gated below run rank five", failures)
	_expect(ground_seen_at_rank_five, "Ground can appear from run rank five", failures)
	_expect(not ice_seen_before_rank_five, "Ice is gated below run rank five", failures)
	_expect(ice_seen_at_rank_five, "Ice can appear from run rank five", failures)
	rooms.matchup_policy = "shadow_bound"
	rooms.progression_run_rank = 1
	var shadow_bound_grey := 0
	var shadow_bound_purple := 0
	var shadow_ambush_count := 0
	for seed in 512:
		var shadow_encounter := rooms._generate_enemy_encounter(seed + 16000, 0, false, true)
		var shadow_variants := shadow_encounter["variants"] as Array
		var shadow_ambush := shadow_encounter["ambush"] as Array
		for index in shadow_variants.size():
			var variant = shadow_variants[index]
			if String(variant) == "grey":
				shadow_bound_grey += 1
			elif String(variant) == "purple":
				shadow_bound_purple += 1
				if index < shadow_ambush.size() and bool(shadow_ambush[index]):
					shadow_ambush_count += 1
	_expect(shadow_bound_purple > shadow_bound_grey, "Shadow-bound encounters replace most normal slots with Shadow Slimes", failures)
	_expect(shadow_bound_grey > 0, "Shadow-bound encounters retain normal slime relief", failures)
	_expect(shadow_bound_purple + shadow_bound_grey > 0 and float(shadow_bound_grey) / float(shadow_bound_purple + shadow_bound_grey) > 0.10 and float(shadow_bound_grey) / float(shadow_bound_purple + shadow_bound_grey) < 0.35, "Shadow-bound normal relief stays near the planned 20 percent", failures)
	_expect(shadow_ambush_count > 0 and shadow_ambush_count < shadow_bound_purple, "Shadow Slime ambush is an ability granted to only some Shadow Slimes", failures)
	rooms.free()

	for palette in ["grey", "yellow", "orange", "aquamarine"]:
		var material := MATERIAL_SCRIPT.for_slime_palette(palette)
		var from_colors: PackedColorArray = material.get_shader_parameter("from_color")
		var to_colors: PackedColorArray = material.get_shader_parameter("to_color")
		_expect(from_colors.size() >= 3 and from_colors[1].is_equal_approx(Color8(56, 183, 100)), "%s shader keeps the green source normal" % palette, failures)
		_expect(to_colors.size() >= 3 and to_colors[1].is_equal_approx(PaletteLibrary.normal(palette)), "%s shader targets the palette normal" % palette, failures)

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
