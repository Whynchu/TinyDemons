extends RefCounted

## Builds the opt-in fixed-size roster used by the Run 30 profile fixture.
class_name DebugBossStressEncounterBuilder


static func build(boss_variant_selection: StringName, run_element_theme: Array[int], progression_run_number: int, generation_seed: int, boss_level: int, enemy_level_cap: int) -> Dictionary:
	var boss_rng := RandomNumberGenerator.new()
	boss_rng.seed = generation_seed + 991
	var boss_selection := EncounterDefinition.select_boss_variant(boss_variant_selection, run_element_theme, progression_run_number, generation_seed, boss_rng)
	var boss_variant := boss_selection.variant as StringName
	if boss_variant.is_empty() or run_element_theme.is_empty():
		return {}
	var variants: Array[String] = [String(boss_variant)]
	var levels: Array[int] = [mini(boss_level + 1, enemy_level_cap)]
	var scales: Array[float] = [3.0]
	var popcorn_flags: Array[bool] = [false]
	var popcorn_types: Array[String] = [""]
	var ambush_flags: Array[bool] = [false]
	for index in 3:
		_append_enemy(variants, levels, scales, popcorn_flags, popcorn_types, ambush_flags, _variant_for(&"slime", run_element_theme[index % run_element_theme.size()], false, progression_run_number), boss_level, enemy_level_cap)
	_append_enemy(variants, levels, scales, popcorn_flags, popcorn_types, ambush_flags, _variant_for(&"skeleton", ElementCatalog.Element.NEUTRAL, false, progression_run_number), boss_level, enemy_level_cap)
	for index in 3:
		_append_enemy(variants, levels, scales, popcorn_flags, popcorn_types, ambush_flags, _variant_for(&"skeleton", run_element_theme[index % run_element_theme.size()], false, progression_run_number), boss_level, enemy_level_cap)
	for index in 4:
		_append_enemy(variants, levels, scales, popcorn_flags, popcorn_types, ambush_flags, _variant_for(&"slime", run_element_theme[index % run_element_theme.size()], true, progression_run_number), boss_level, enemy_level_cap)
	EncounterDefinition.constrain_generated_roster(variants, ambush_flags, run_element_theme, progression_run_number, generation_seed, "Debug boss stress")
	return {"variants": variants, "levels": levels, "scales": scales, "popcorn": popcorn_flags, "popcorn_types": popcorn_types, "ambush": ambush_flags}


static func _variant_for(type_id: StringName, element: int, require_support_caster: bool, progression_run_number: int) -> StringName:
	for variant_id in EnemyFactory.variants_for_type(type_id):
		var definition := EnemyFactory.definition(variant_id)
		if definition == null or definition.element != element or definition.encounter_min_run_number > progression_run_number:
			continue
		if require_support_caster != (definition.behavior_id == &"support_caster"):
			continue
		return variant_id
	return &""


static func _append_enemy(variants: Array[String], levels: Array[int], scales: Array[float], popcorn_flags: Array[bool], popcorn_types: Array[String], ambush_flags: Array[bool], variant_id: StringName, boss_level: int, enemy_level_cap: int) -> void:
	if variant_id.is_empty():
		return
	variants.append(String(variant_id))
	levels.append(mini(boss_level, enemy_level_cap))
	scales.append(1.0)
	popcorn_flags.append(false)
	popcorn_types.append("")
	ambush_flags.append(false)
