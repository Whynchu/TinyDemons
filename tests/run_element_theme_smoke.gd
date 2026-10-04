extends SceneTree

const EncounterDefinitionScript = preload("res://scripts/content/encounter_definition.gd")
const RunStateScript = preload("res://scripts/runtime/state/run_state.gd")
const RoomControllerScript = preload("res://scripts/runtime/controllers/room_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var three_element_runs := 0
	var sample_count := 1000
	for seed in range(1, sample_count + 1):
		var teaching_theme := EncounterDefinitionScript.select_run_element_theme(seed, 1)
		var second_run_theme := EncounterDefinitionScript.select_run_element_theme(seed, 2)
		var later_run_theme := EncounterDefinitionScript.select_run_element_theme(seed, 3)
		_expect(teaching_theme.is_empty(), "Run 1 remains Normal-only", failures)
		_expect(second_run_theme.size() == 1, "Run 2 introduces one elemental theme independent of difficulty", failures)
		_expect(not later_run_theme.is_empty(), "every run number at or above 3 has a theme", failures)
		_expect(later_run_theme == EncounterDefinitionScript.select_run_element_theme(seed, 3), "run theme selection is deterministic for a seed", failures)
		_expect(later_run_theme.size() == 2 or later_run_theme.size() == 3, "later runs select two elements or the occasional third", failures)
		_expect(later_run_theme.size() <= 3, "run theme never exceeds the three-element cap", failures)
		if later_run_theme.size() == 3:
			three_element_runs += 1
		for run_number in range(2, 9):
			var run_theme := EncounterDefinitionScript.select_run_element_theme(seed, run_number)
			_expect(not run_theme.is_empty(), "every run number >= 2 has an elemental theme", failures)
	var configured_chance := EncounterDefinitionScript.default_data().three_element_theme_chance
	var observed_chance := float(three_element_runs) / float(sample_count)
	print("RUN_ELEMENT_THEME_SMOKE_FREQUENCY configured=%.3f observed=%.3f (%d/%d)" % [configured_chance, observed_chance, three_element_runs, sample_count])
	_expect(observed_chance > 0.0 and observed_chance < 0.5, "two-element runs remain more common than three-element runs", failures)
	_expect(absf(observed_chance - configured_chance) < 0.06, "seed sweep frequency stays near its configured chance", failures)
	_expect(EncounterDefinitionScript.available_run_elements_for_number(2).size() > 0, "element availability is derived from run number", failures)
	var rank_one_legacy_variants: Array[String] = ["healer_slime"]
	var rank_one_legacy := EncounterDefinitionScript.constrain_roster_to_theme(rank_one_legacy_variants, [], 1, 77)
	_expect((rank_one_legacy.get("errors", []) as Array).is_empty() and rank_one_legacy.variants == ["grey"], "a Normal-only roster can remap an unsupported legacy healer without breaking its slot", failures)

	var run_state := RunStateScript.new() as RunState
	run_state.begin(7789, 0, 1.0, 3)
	var expected_theme := run_state.enemy_element_theme.duplicate()
	var restored := RunStateScript.new() as RunState
	_expect(restored.restore_from_dictionary(run_state.to_dictionary()), "active run state restores from its serialized data", failures)
	_expect(restored.enemy_element_theme == expected_theme and restored.element_theme_initialized, "serialized run theme survives restore without rerolling", failures)
	_expect(restored.element_theme_run_number == 3, "run theme stores its campaign run number", failures)
	var legacy_run_state := RunStateScript.new() as RunState
	var legacy_data := run_state.to_dictionary()
	legacy_data.erase("element_theme_run_number")
	legacy_data["element_theme_run_rank"] = 3
	_expect(legacy_run_state.restore_from_dictionary(legacy_data) and legacy_run_state.element_theme_run_number == 3, "legacy saved theme rank restores through the compatibility key", failures)

	var healer_pool := EnemyFactory.weighted_variants_for_role(&"slime", &"support", 3)
	for entry in healer_pool:
		var support_definition := EnemyFactory.definition(StringName(str(entry.get("variant", ""))))
		_expect(support_definition != null and support_definition.behavior_id == &"support_caster", "every elemental healer variant retains shared ally healing", failures)
	var water_electric_theme: Array[int] = [ElementCatalog.Element.WATER, ElementCatalog.Element.ELECTRIC]
	var water_electric_healers := EncounterDefinitionScript.filter_weighted_pool_for_theme(healer_pool, water_electric_theme, 3)
	var found_water_healer := false
	var found_electric_healer := false
	for entry in water_electric_healers:
		var definition := EnemyFactory.definition(StringName(str(entry.get("variant", ""))))
		_expect(definition != null and definition.behavior_id == &"support_caster" and definition.encounter_role == &"support", "elemental support variants retain the shared healing role", failures)
		if definition != null:
			found_water_healer = found_water_healer or definition.element == ElementCatalog.Element.WATER
			found_electric_healer = found_electric_healer or definition.element == ElementCatalog.Element.ELECTRIC
			_expect(definition.element in [ElementCatalog.Element.WATER, ElementCatalog.Element.ELECTRIC], "Water/Electric theme excludes out-of-theme healers", failures)
	_expect(found_water_healer and found_electric_healer, "Water/Electric theme can draw a healer of either allowed element", failures)
	var grass_theme: Array[int] = [ElementCatalog.Element.GRASS]
	var grass_healers := EncounterDefinitionScript.filter_weighted_pool_for_theme(healer_pool, grass_theme, 3)
	_expect(grass_healers.size() == 1 and EnemyFactory.definition(StringName(str(grass_healers[0].get("variant", "")))).element == ElementCatalog.Element.GRASS, "Grass theme can use the original Grass healer", failures)

	var legacy_states := {
		&"room_a": {
			"enemy_variants": ["grey", "red", "blue", "yellow"],
			"enemy_levels": [5, 6, 7, 8],
			"enemy_popcorn": [false, false, false, true],
			"enemy_ambush": [false, false, false, false],
			"enemy_runtime": {
				"0": {"alive": true, "health": 11.0, "chroma": {"current": 4, "maximum": 20}},
				"2": {"alive": false, "health": 0.0, "chroma": {"current": 0, "maximum": 20}},
			},
			"pickups": [{"value": 1, "position": Vector2(12, 18)}],
		}
	}
	var migration := EncounterDefinitionScript.migrate_cached_rosters(legacy_states, water_electric_theme, 3, 7789)
	var migrated_states: Dictionary = migration.get("room_states", {})
	var migrated_room: Dictionary = migrated_states.get(&"room_a", {})
	_expect((migration.get("errors", []) as Array).is_empty(), "legacy room rosters migrate into the chosen theme", failures)
	_expect((migration.get("remaps", []) as Array).size() == 1, "migration reports an off-theme slot remap", failures)
	_expect(migrated_room.get("enemy_levels", []) == legacy_states[&"room_a"].enemy_levels, "migration preserves enemy levels", failures)
	_expect(migrated_room.get("enemy_runtime", {}) == legacy_states[&"room_a"].enemy_runtime, "migration preserves health and Chroma runtime state", failures)
	_expect(migrated_room.get("pickups", []) == legacy_states[&"room_a"].pickups, "migration preserves saved pickup values and positions", failures)
	_expect(EncounterDefinitionScript.validate_roster_theme(migrated_room.get("enemy_variants", []) as Array, water_electric_theme, 3).is_empty(), "migrated roster stays inside its theme", failures)

	var first_room_controller := RoomControllerScript.new() as Node
	var second_room_controller := RoomControllerScript.new() as Node
	first_room_controller.set("matchup_policy", EncounterDefinitionScript.POLICY_BASE_COUNTER)
	second_room_controller.set("matchup_policy", EncounterDefinitionScript.POLICY_BASE_ADVANTAGE)
	first_room_controller.set("progression_run_rank", 2)
	first_room_controller.set("progression_run_number", 5)
	second_room_controller.set("progression_run_rank", 8)
	second_room_controller.set("progression_run_number", 5)
	_expect(int(first_room_controller.call("_generated_enemy_base_level", 0)) < int(second_room_controller.call("_generated_enemy_base_level", 0)), "enemy level still follows difficulty rank at a fixed campaign run", failures)
	var first_definition := first_room_controller.call("_encounter_definition") as EncounterDefinition
	var second_definition := second_room_controller.call("_encounter_definition") as EncounterDefinition
	_expect(first_definition != second_definition and first_definition.matchup_policy != second_definition.matchup_policy, "room controllers own isolated matchup definitions", failures)
	_expect(EncounterDefinitionScript.default_data().matchup_policy == EncounterDefinitionScript.POLICY_RUN_DEFAULT, "runtime matchup policy never mutates the cached shared definition", failures)
	first_room_controller.free()
	second_room_controller.free()

	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN_ELEMENT_THEME_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
