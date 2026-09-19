extends SceneTree

## Catalog report (Slice F, T2). Loads every authored definition resource and
## prints a deterministic, human-readable summary: surface counts, catalog
## sizes, and the stable IDs/content each surface owns. Run via
## tools/report_catalogs.ps1.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== TINY DEMONS DEFINITION CATALOG REPORT ===")
	_report_items()
	_report_slime_variants()
	_report_encounter_definition()
	_report_room_definition()
	_report_generation_policy()
	_report_reward_definition()
	_report_run_layouts()
	_report_puzzle_plans()
	print("=== END DEFINITION CATALOG REPORT ===")
	quit(0)


func _report_items() -> void:
	var data := load("res://resources/definitions/item_catalog.tres") as Resource
	if data == null:
		print("item_catalog: LOAD_FAILED")
		return
	var definitions := data.get("definitions") as Dictionary
	var live := data.get("live_base_definitions") as Dictionary
	var sets := data.get("set_definitions") as Dictionary
	var transmutations := data.get("transmutations") as Dictionary
	print("item_catalog: %d expansion definitions, %d live bases, %d sets, %d transmutations" % [definitions.size(), live.size(), sets.size(), transmutations.size()])
	var ids: Array = definitions.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	print("  ids: %s" % ", ".join(ids.map(func(id): return String(id))))


func _report_slime_variants() -> void:
	var data := load("res://resources/definitions/slime_variant_catalog.tres") as Resource
	if data == null:
		print("slime_variant_catalog: LOAD_FAILED")
		return
	var definitions := data.get("definitions") as Dictionary
	print("slime_variant_catalog: %d variants" % definitions.size())
	var ids: Array = definitions.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	print("  ids: %s" % ", ".join(ids.map(func(id): return String(id))))


func _report_encounter_definition() -> void:
	var definition := EncounterDefinition.default_data()
	print("encounter_definition: weights grey=%.2f shadow=%.2f crimson=%.2f, gates yellow=%d ground=%d ice=%d crimson=%d, policy=%s" % [definition.grey_weight, definition.shadow_weight, definition.crimson_weight, definition.yellow_min_rank, definition.ground_min_rank, definition.ice_min_rank, definition.crimson_min_rank, definition.matchup_policy])


func _report_room_definition() -> void:
	var definition := RoomDefinition.default_data()
	print("room_definition: cap=%d treasure=%.2f popcorn(early/r2/late)=%.2f/%.2f/%.2f boss_minors_start=%d" % [definition.normal_enemy_cap, definition.regular_room_treasure_chance, definition.popcorn_chance_early, definition.popcorn_chance_run2, definition.popcorn_chance_later, definition.boss_mixed_support_start_rank])


func _report_generation_policy() -> void:
	var policy := DungeonGenerationPolicy.default_data()
	print("dungeon_generation_policy: candidates=%d risk_candidates=%d first_orb=%d first_special=%d flames=%s" % [policy.generated_candidate_count, policy.risk_reward_candidate_count, policy.first_orb_depth, policy.first_special_depth, ", ".join(policy.primary_flames.map(func(f): return String(f)))])


func _report_reward_definition() -> void:
	var definition := RewardDefinition.default_data()
	print("reward_definition: base_drop=%.2f risk_bonus=%.2f double=%.2f triple=%.2f quad=%.2f grade(S/A/B/C/F)=%.1f/%.1f/%.1f/%.1f/%.1f" % [definition.drop_chance_base, definition.drop_chance_risk_bonus, definition.double_drop_base, definition.triple_drop_base, definition.quad_drop_base, definition.loot_grade_bonus("S"), definition.loot_grade_bonus("A"), definition.loot_grade_bonus("B"), definition.loot_grade_bonus("C"), definition.loot_grade_bonus("F")])


func _report_run_layouts() -> void:
	for path in ["res://resources/definitions/dungeon_layout_run1.tres", "res://resources/definitions/dungeon_layout_run2.tres"]:
		var data := load(path) as Resource
		if data == null:
			print("%s: LOAD_FAILED" % path)
			continue
		print("%s: id=%s rooms=%d connections=%d" % [path.get_file(), StringName(data.get("layout_id")), (data.get("rooms") as Array).size(), (data.get("connections") as Array).size()])


func _report_puzzle_plans() -> void:
	for path in ["res://resources/definitions/puzzle_map_r3.tres", "res://resources/definitions/puzzle_map_r4.tres", "res://resources/definitions/puzzle_map_r5.tres", "res://resources/definitions/puzzle_map_r3_new.tres"]:
		var data := load(path) as Resource
		if data == null:
			print("%s: LOAD_FAILED" % path)
			continue
		print("%s: plan_id=%s markers=%d" % [path.get_file(), StringName(data.get("plan_id")), (data.get("markers") as Array).size()])