extends Resource
class_name EncounterDefinition

## Encounter composition contract (Slice C, T2). Captures the run-gated enemy
## variant pool and matchup policy as editor-inspectable data, replacing the
## hardcoded rank constants that used to live in room_controller. RoomRuntime
## owns the mutable runtime state (claims, active actors, locks); this definition
## is immutable and reusable across rooms and runs.

const DEFAULT_DATA_PATH := "res://resources/definitions/encounter_definition.tres"
const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/content/slime_variant_catalog.gd")
const SAVED_ROOM_SUPPORT_ROLL_SALT := 0x48534C4D


static func default_data() -> EncounterDefinition:
	return load(DEFAULT_DATA_PATH) as EncounterDefinition


const POLICY_RUN_DEFAULT := "run_default"
const POLICY_BASE_ADVANTAGE := "base_advantage"
const POLICY_BASE_COUNTER := "base_counter"
const POLICY_FLAME_MIXED := "flame_mixed"
const POLICY_SHADOW_BOUND := "shadow_bound"

## Grey is the neutral baseline present in every normal encounter.
@export var grey_weight := 1.0
## Shadow Slimes are a rare pressure spike, not a normal roster member.
@export var shadow_weight := 0.12
@export var shadow_min_rank := 5
## Shadow-bound encounters replace most normal slots with Shadow Slimes.
@export var shadow_bound_normal_weight := 0.20
@export var shadow_bound_variant_weight := 0.80
@export_range(0.0, 1.0, 0.01) var three_element_theme_chance := 0.20
@export_range(0.0, 10.0, 0.1) var synergy_pair_weight_bonus := 3.0
@export var synergy_element_pairs: Array[Vector2i] = [Vector2i(2, 3)]
## Matchup policy selects how authored primary/secondary families weight in.
@export var matchup_policy := POLICY_RUN_DEFAULT

var allowed_policies: Array[String] = [POLICY_RUN_DEFAULT, POLICY_BASE_ADVANTAGE, POLICY_BASE_COUNTER, POLICY_FLAME_MIXED, POLICY_SHADOW_BOUND]


## Validates the definition: non-negative weights, ordered rank gates, and a
## known policy. Returns an array of human-readable problems (empty when valid).
func validate() -> Array[String]:
	var problems: Array[String] = []
	if grey_weight < 0.0: problems.append("grey_weight must be non-negative")
	if shadow_weight < 0.0: problems.append("shadow_weight must be non-negative")
	if shadow_bound_normal_weight < 0.0 or shadow_bound_variant_weight < 0.0:
		problems.append("shadow-bound weights must be non-negative")
	if shadow_min_rank < 1:
		problems.append("shadow_min_rank must be >= 1")
	if three_element_theme_chance < 0.0 or three_element_theme_chance > 1.0:
		problems.append("three_element_theme_chance must be between 0 and 1")
	if synergy_pair_weight_bonus < 0.0:
		problems.append("synergy_pair_weight_bonus must be non-negative")
	for pair in synergy_element_pairs:
		if pair.x <= ElementCatalog.Element.NEUTRAL or pair.y <= ElementCatalog.Element.NEUTRAL or pair.x >= ElementCatalog.element_count() or pair.y >= ElementCatalog.element_count() or pair.x == pair.y:
			problems.append("synergy pairs must contain two distinct non-Normal elements")
	if not allowed_policies.has(matchup_policy):
		problems.append("unknown matchup_policy '%s'" % matchup_policy)
	return problems


static func available_run_elements_for_number(run_number: int) -> Array[int]:
	var elements: Array[int] = []
	for variant_id in EnemyFactory.variants_for_type(&"slime", &"support"):
		var definition := EnemyFactory.definition(variant_id)
		if definition == null or definition.element <= ElementCatalog.Element.NEUTRAL or definition.encounter_min_run_number > maxi(run_number, 1):
			continue
		if definition.matchup_weight <= 0.0 and definition.encounter_weight <= 0.0 and definition.preferred_weight <= 0.0:
			continue
		if not elements.has(definition.element):
			elements.append(definition.element)
	elements.sort()
	return elements


static func select_run_element_theme(seed: int, run_number: int) -> Array[int]:
	var theme_run := maxi(run_number, 1)
	if theme_run <= 1:
		return []
	var available := available_run_elements_for_number(theme_run)
	if available.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ 0x454C5448
	var target_count := 1 if theme_run == 2 else (3 if rng.randf() < default_data().three_element_theme_chance else 2)
	target_count = mini(target_count, available.size())
	if target_count == 1:
		return [available[rng.randi_range(0, available.size() - 1)]]
	var pair_options: Array[Dictionary] = []
	var total_weight := 0.0
	var data := default_data()
	for left_index in available.size():
		for right_index in range(left_index + 1, available.size()):
			var first := available[left_index]
			var second := available[right_index]
			var weight := 1.0 + (data.synergy_pair_weight_bonus if _pair_is_synergistic(data.synergy_element_pairs, first, second) else 0.0)
			pair_options.append({"first": first, "second": second, "weight": weight})
			total_weight += weight
	var roll := rng.randf_range(0.0, total_weight)
	var selected_pair: Dictionary = pair_options.back()
	for option in pair_options:
		roll -= float(option.weight)
		if roll <= 0.0:
			selected_pair = option
			break
	var result: Array[int] = [int(selected_pair.first), int(selected_pair.second)]
	if target_count >= 3:
		var remaining: Array[int] = []
		for element in available:
			if not result.has(element):
				remaining.append(element)
		if not remaining.is_empty():
			result.append(remaining[rng.randi_range(0, remaining.size() - 1)])
	result.sort()
	return result


static func normalize_run_element_theme(theme: Array[int]) -> Array[int]:
	var normalized: Array[int] = []
	for element in theme:
		if element > ElementCatalog.Element.NEUTRAL and element < ElementCatalog.element_count() and not normalized.has(element):
			normalized.append(element)
	normalized.sort()
	if normalized.size() > 3:
		normalized.resize(3)
	return normalized


static func _pair_is_synergistic(pairs: Array[Vector2i], first: int, second: int) -> bool:
	for pair in pairs:
		if (pair.x == first and pair.y == second) or (pair.x == second and pair.y == first):
			return true
	return false


static func filter_variants_for_theme(variants: Array[StringName], theme: Array[int], run_number: int, allow_shadow: bool = true, include_supports: bool = true) -> Array[StringName]:
	var result: Array[StringName] = []
	for variant_id in variants:
		var definition := EnemyFactory.definition(variant_id)
		if definition == null or definition.encounter_min_run_number > maxi(run_number, 1):
			continue
		if definition.element != ElementCatalog.Element.NEUTRAL and not theme.has(definition.element):
			continue
		if not include_supports and definition.encounter_role == &"support":
			continue
		if not allow_shadow and definition.element == ElementCatalog.Element.SHADOW:
			continue
		result.append(variant_id)
	return result


static func filter_weighted_pool_for_theme(entries: Array[Dictionary], theme: Array[int], run_number: int, allow_shadow: bool = true, include_supports: bool = true) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for entry in entries:
		var variant_id := StringName(str(entry.get("variant", "")))
		var definition := EnemyFactory.definition(variant_id)
		if definition == null or definition.encounter_min_run_number > maxi(run_number, 1):
			continue
		if definition.element != ElementCatalog.Element.NEUTRAL and not theme.has(definition.element):
			continue
		if not include_supports and definition.encounter_role == &"support":
			continue
		if not allow_shadow and definition.element == ElementCatalog.Element.SHADOW:
			continue
		filtered.append(entry.duplicate(true))
	return filtered


static func extend_pool_with_theme_variants(entries: Array[Dictionary], theme: Array[int], run_number: int, allow_shadow: bool = true) -> void:
	var included: Dictionary = {}
	for entry in entries:
		included[StringName(str(entry.get("variant", "")))] = true
	for type_id in [&"slime"]:
		for variant_id in EnemyFactory.variants_for_type(type_id, &"support"):
			var definition := EnemyFactory.definition(variant_id)
			if definition == null or definition.element == ElementCatalog.Element.NEUTRAL or not theme.has(definition.element) or definition.encounter_min_run_number > maxi(run_number, 1):
				continue
			if not allow_shadow and definition.element == ElementCatalog.Element.SHADOW:
				continue
			if included.has(variant_id):
				continue
			var weight := definition.matchup_weight
			if weight <= 0.0:
				weight = definition.encounter_weight
			if weight <= 0.0:
				weight = definition.preferred_weight
			if weight <= 0.0:
				weight = 0.25
			entries.append({"variant": String(variant_id), "weight": weight})
			included[variant_id] = true


static func prepare_variant_pools_for_theme(
	variant_pool: Array[Dictionary],
	skeleton_variant_pool: Array[Dictionary],
	theme: Array[int],
	run_number: int,
	allow_shadow: bool,
	force_debug_enemy: bool
) -> void:
	if not skeleton_variant_pool.is_empty():
		var filtered_skeletons := filter_weighted_pool_for_theme(skeleton_variant_pool, theme, run_number, allow_shadow, false)
		skeleton_variant_pool.clear()
		skeleton_variant_pool.append_array(filtered_skeletons)
	extend_pool_with_theme_variants(variant_pool, theme, run_number, allow_shadow)
	if not force_debug_enemy:
		var filtered_variants := filter_weighted_pool_for_theme(variant_pool, theme, run_number, allow_shadow, false)
		variant_pool.clear()
		variant_pool.append_array(filtered_variants)
	if not skeleton_variant_pool.is_empty():
		balance_enemy_family_weights(variant_pool, skeleton_variant_pool)


static func constrain_roster_to_theme(variants: Array[String], theme: Array[int], run_number: int, seed: int) -> Dictionary:
	var constrained := variants.duplicate()
	var remaps: Array[String] = []
	var lost_shadow_indices: Array[int] = []
	var errors: Array[String] = []
	for slot in constrained.size():
		var old_id := StringName(constrained[slot])
		if not EnemyFactory.is_variant(old_id):
			errors.append("unknown enemy variant '%s' at slot %d" % [String(old_id), slot])
			continue
		var old_definition := EnemyFactory.definition(old_id)
		if _definition_allowed_by_theme(old_definition, theme, run_number):
			continue
		var replacement_candidates := _replacement_candidates(old_definition, theme, run_number, true)
		if replacement_candidates.is_empty():
			replacement_candidates = _replacement_candidates(old_definition, theme, run_number, false)
		if replacement_candidates.is_empty():
			replacement_candidates = _replacement_candidates(old_definition, theme, run_number, true, false)
		if replacement_candidates.is_empty():
			replacement_candidates = _replacement_candidates(old_definition, theme, run_number, false, false)
		if replacement_candidates.is_empty():
			replacement_candidates = _replacement_candidates(old_definition, theme, run_number, false, false, false)
		if replacement_candidates.is_empty():
			errors.append("no same-family %s replacement for '%s' inside theme %s" % ["elemental" if old_definition.element != 0 else "Normal", String(old_id), str(theme)])
			continue
		replacement_candidates.sort()
		var replacement_rng := RandomNumberGenerator.new()
		replacement_rng.seed = seed ^ (slot + 1) * 0x4D494752
		var new_id: StringName = replacement_candidates[replacement_rng.randi_range(0, replacement_candidates.size() - 1)]
		constrained[slot] = String(new_id)
		remaps.append("%s -> %s" % [String(old_id), String(new_id)])
		var new_definition := EnemyFactory.definition(new_id)
		if old_definition.element == ElementCatalog.Element.SHADOW and (new_definition == null or new_definition.element != ElementCatalog.Element.SHADOW):
			lost_shadow_indices.append(slot)
	return {"variants": constrained, "remaps": remaps, "lost_shadow_indices": lost_shadow_indices, "errors": errors}


static func constrain_cached_room_theme(
	room_states: Dictionary,
	room_id: StringName,
	state: Dictionary,
	theme: Array[int],
	run_number: int,
	seed: int,
	debug_bypass: bool = false
) -> void:
	if debug_bypass or not state.has("enemy_variants"):
		return
	var variants: Array[String] = []
	for value in state.get("enemy_variants", []) as Array:
		variants.append(str(value))
	var constrained := constrain_roster_to_theme(variants, theme, run_number, seed)
	for problem in constrained.errors:
		push_error("Room '%s' elemental theme: %s" % [String(room_id), str(problem)])
	if constrained.errors.is_empty() and not constrained.remaps.is_empty():
		push_warning("Room '%s' seed %d remapped %d cached enemy slots into run theme %s." % [String(room_id), seed, constrained.remaps.size(), str(theme)])
		state["enemy_variants"] = constrained.variants
		var ambush := state.get("enemy_ambush", []) as Array
		for slot in constrained.lost_shadow_indices:
			if slot < ambush.size():
				ambush[slot] = false
		state["enemy_ambush"] = ambush
	room_states[room_id] = state
	for problem in validate_roster_theme(state.get("enemy_variants", []) as Array, theme, run_number):
		push_error("Room '%s' elemental theme invariant: %s" % [String(room_id), problem])
	for problem in validate_run_rosters(room_states, theme):
		push_error("Run elemental theme invariant: %s" % problem)


static func constrain_generated_roster(
	variants: Array[String],
	ambush_flags: Array[bool],
	theme: Array[int],
	run_number: int,
	seed: int,
	label: String
) -> void:
	var constrained := constrain_roster_to_theme(variants, theme, run_number, seed)
	if not constrained.remaps.is_empty():
		push_warning("%s seed %d remapped %d enemy slots into run theme %s." % [label, seed, constrained.remaps.size(), str(theme)])
	for problem in constrained.errors:
		push_error("%s seed %d elemental theme: %s" % [label, seed, str(problem)])
	for slot in constrained.lost_shadow_indices:
		if slot < ambush_flags.size():
			ambush_flags[slot] = false
	for index in constrained.variants.size():
		variants[index] = constrained.variants[index]
	for problem in validate_roster_theme(variants, theme, run_number):
		push_error("%s seed %d elemental theme invariant: %s" % [label, seed, problem])


static func select_boss_variant(candidate: StringName, theme: Array[int], run_number: int, seed: int, rng: RandomNumberGenerator) -> Dictionary:
	if run_number <= 1 and candidate == &"purple":
		candidate = &"grey"
	var definition := SLIME_VARIANT_CATALOG_SCRIPT.definition_resource(candidate)
	var has_explicit_variant := definition != null and definition.type_id == &"slime"
	if has_explicit_variant:
		if definition.element != ElementCatalog.Element.NEUTRAL and not theme.has(definition.element):
			push_warning("Authored boss variant '%s' conflicts with run theme %s; a same-family elemental replacement will be used." % [String(candidate), str(theme)])
			var constrained := constrain_roster_to_theme([String(candidate)], theme, run_number, seed)
			if not constrained.errors.is_empty():
				for problem in constrained.errors:
					push_error("Authored boss elemental theme: %s" % str(problem))
			elif not constrained.variants.is_empty():
				candidate = StringName(constrained.variants[0])
		return {"variant": candidate, "has_explicit_variant": true}
	var roster := EnemyFactory.variants_for_type(&"slime", &"support")
	if run_number <= 1:
		roster.erase(&"purple")
	roster = filter_variants_for_theme(roster, theme, run_number, true, false)
	if roster.is_empty():
		push_error("No legal themed slime boss exists for run theme %s at run %d." % [str(theme), run_number])
		return {"variant": &"", "has_explicit_variant": false}
	return {"variant": roster[rng.randi_range(0, roster.size() - 1)], "has_explicit_variant": false}


static func _definition_allowed_by_theme(definition: EnemyDefinition, theme: Array[int], run_number: int) -> bool:
	if definition == null or definition.encounter_min_run_number > maxi(run_number, 1):
		return false
	return definition.element == ElementCatalog.Element.NEUTRAL or theme.has(definition.element)


static func _replacement_candidates(
	source: EnemyDefinition,
	theme: Array[int],
	run_number: int,
	require_same_role: bool,
	preserve_elemental_kind: bool = true,
	preserve_support_class: bool = true
) -> Array[StringName]:
	var matches: Array[StringName] = []
	if source == null:
		return matches
	var source_is_elemental := source.element != ElementCatalog.Element.NEUTRAL
	for variant_id in EnemyFactory.variants_for_type(source.type_id):
		var candidate := EnemyFactory.definition(variant_id)
		if candidate == null or not _definition_allowed_by_theme(candidate, theme, run_number):
			continue
		if preserve_elemental_kind and ((candidate.element != ElementCatalog.Element.NEUTRAL) != source_is_elemental):
			continue
		if require_same_role and candidate.encounter_role != source.encounter_role:
			continue
		if preserve_support_class and not require_same_role and (candidate.encounter_role == &"support") != (source.encounter_role == &"support"):
			continue
		matches.append(variant_id)
	return matches


static func validate_roster_theme(variants: Array, theme: Array[int], _run_number: int = 99) -> Array[String]:
	var problems: Array[String] = []
	var non_normal_elements: Dictionary = {}
	for value in variants:
		var variant_id := StringName(str(value))
		if not EnemyFactory.is_variant(variant_id):
			problems.append("unknown roster variant '%s'" % String(variant_id))
			continue
		var definition := EnemyFactory.definition(variant_id)
		if definition.element == ElementCatalog.Element.NEUTRAL:
			continue
		non_normal_elements[definition.element] = true
		if not theme.has(definition.element):
			problems.append("variant '%s' element %d is outside run theme %s" % [String(variant_id), definition.element, str(theme)])
	if non_normal_elements.size() > 3:
		problems.append("roster uses %d non-Normal elements; the cap is three" % non_normal_elements.size())
	return problems


static func validate_run_rosters(room_states: Dictionary, theme: Array[int]) -> Array[String]:
	var problems: Array[String] = []
	var run_elements: Dictionary = {}
	for room_id in room_states.keys():
		var state := room_states[room_id] as Dictionary
		var variants := state.get("enemy_variants", []) as Array
		for problem in validate_roster_theme(variants, theme):
			problems.append("room '%s': %s" % [str(room_id), problem])
		for value in variants:
			var variant_id := StringName(str(value))
			if EnemyFactory.is_variant(variant_id):
				var element := EnemyFactory.definition(variant_id).element
				if element != ElementCatalog.Element.NEUTRAL:
					run_elements[element] = true
	if run_elements.size() > 3:
		problems.append("run uses %d non-Normal elements; the cap is three" % run_elements.size())
	return problems


static func legacy_theme_for_rosters(room_states: Dictionary, seed: int, run_number: int) -> Array[int]:
	var counts: Dictionary = {}
	for state_value in room_states.values():
		if not state_value is Dictionary:
			continue
		for value in (state_value as Dictionary).get("enemy_variants", []) as Array:
			var variant_id := StringName(str(value))
			if not EnemyFactory.is_variant(variant_id):
				continue
			var element := EnemyFactory.definition(variant_id).element
			if element != ElementCatalog.Element.NEUTRAL:
				counts[element] = int(counts.get(element, 0)) + 1
	var elements: Array[int] = []
	for element: Variant in counts.keys():
		elements.append(int(element))
	elements.sort_custom(func(a: int, b: int) -> bool:
		var a_count := int(counts.get(a, 0))
		var b_count := int(counts.get(b, 0))
		return a_count > b_count if a_count != b_count else a < b
	)
	if elements.size() > 3:
		elements.resize(3)
	if elements.is_empty():
		return select_run_element_theme(seed, run_number)
	elements.sort()
	return elements


static func migrate_cached_rosters(room_states: Dictionary, theme: Array[int], run_number: int, seed: int) -> Dictionary:
	var migrated := room_states.duplicate(true)
	var remaps: Array[String] = []
	var errors: Array[String] = []
	for room_id in migrated.keys():
		var state := migrated[room_id] as Dictionary
		if not state.has("enemy_variants"):
			continue
		var variants: Array[String] = []
		for value in state.get("enemy_variants", []) as Array:
			variants.append(str(value))
		var result := constrain_roster_to_theme(variants, theme, run_number, seed ^ str(room_id).hash())
		for message in result.errors:
			errors.append("room '%s': %s" % [str(room_id), str(message)])
		for mapping in result.remaps:
			remaps.append("room '%s': %s" % [str(room_id), str(mapping)])
		state["enemy_variants"] = result.variants
		if not result.lost_shadow_indices.is_empty():
			var ambush := state.get("enemy_ambush", []) as Array
			for slot in result.lost_shadow_indices:
				if slot < ambush.size():
					ambush[slot] = false
			state["enemy_ambush"] = ambush
		for problem in validate_roster_theme(result.variants, theme, run_number):
			errors.append("room '%s': %s" % [str(room_id), problem])
		migrated[room_id] = state
	for problem in validate_run_rosters(migrated, theme):
		errors.append(problem)
	return {"room_states": migrated, "remaps": remaps, "errors": errors}


## Late-run weighted entries that enter once the run rank passes their gate.
func late_pool_entries(run_number: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for variant in SLIME_VARIANT_CATALOG_SCRIPT.variants():
		var definition := SLIME_VARIANT_CATALOG_SCRIPT.definition_resource(variant)
		if definition == null or definition.encounter_role != &"late":
			continue
		if run_number >= definition.encounter_min_run_number and definition.encounter_weight > 0.0:
			entries.append({"variant": String(definition.variant_id), "weight": definition.encounter_weight})
	return entries


static func select_weighted_variant(entries: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	var total_weight := 0.0
	for entry in entries:
		total_weight += float(entry["weight"])
	var roll := rng.randf_range(0.0, total_weight)
	for entry in entries:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry["variant"] as String
	return "grey"


static func balance_enemy_family_weights(slime_pool: Array[Dictionary], skeleton_pool: Array[Dictionary]) -> void:
	var slime_weight := 0.0
	for entry in slime_pool:
		slime_weight += float(entry.get("weight", 0.0))
	var skeleton_weight := 0.0
	for entry in skeleton_pool:
		skeleton_weight += float(entry.get("weight", 0.0))
	if slime_weight <= 0.0 or skeleton_weight <= 0.0:
		return
	# Balance families independently from the count of authored variants.
	var skeleton_scale := slime_weight / skeleton_weight
	for entry in skeleton_pool:
		var balanced_entry := entry.duplicate()
		balanced_entry["weight"] = float(balanced_entry["weight"]) * skeleton_scale
		slime_pool.append(balanced_entry)


static func boss_support_variant_pool(include_skeletons: bool, theme: Array[int] = [], run_number: int = 99) -> Array[Dictionary]:
	var support_pool := EnemyFactory.weighted_variants_for_type(&"slime")
	if include_skeletons:
		balance_enemy_family_weights(support_pool, EnemyFactory.weighted_variants_for_type(&"skeleton"))
	return filter_weighted_pool_for_theme(support_pool, theme, run_number)


static func ensure_room_popcorn_slot(
	force_debug_enemy: bool,
	shadow_bound: bool,
	variants: Array[String],
	levels: Array[int],
	popcorn_flags: Array[bool],
	popcorn_types: Array[String],
	ambush_flags: Array[bool],
	elite_flags: Array[bool],
	popcorn_level: int,
	room_popcorn_id: String
) -> void:
	if force_debug_enemy or popcorn_flags.has(true) or shadow_bound:
		return
	for index in range(variants.size() - 1, -1, -1):
		if variants[index] == "purple" or not EnemyFactory.variant_is_type(StringName(variants[index]), &"slime"):
			continue
		variants[index] = "grey"
		levels[index] = popcorn_level
		popcorn_flags[index] = true
		popcorn_types[index] = room_popcorn_id
		ambush_flags[index] = false
		elite_flags[index] = false
		break


func finalize_room_encounter(
	force_debug_enemy: bool,
	variants: Array[String],
	levels: Array[int],
	popcorn_flags: Array[bool],
	popcorn_types: Array[String],
	ambush_flags: Array[bool],
	elite_flags: Array[bool],
	popcorn_level: int,
	room_popcorn_id: String,
	elite_popcorn_id: String,
	encounter_rng: RandomNumberGenerator,
	room_policy: RoomDefinition,
	run_rank: int,
	run_number: int,
	base_level: int,
	level_spread: int,
	encounter_tier: StringName,
	enemy_level_cap: int,
	run_theme: Array[int] = [],
	generation_seed: int = 0
) -> void:
	# Preserve the room's relief slot and its shadow-bound identity ratio before
	# adding any support-role companions.
	ensure_room_popcorn_slot(force_debug_enemy, is_shadow_bound(), variants, levels, popcorn_flags, popcorn_types, ambush_flags, elite_flags, popcorn_level, room_popcorn_id)
	if variants.has("purple"):
		for index in variants.size():
			if popcorn_flags[index]:
				variants[index] = "grey"
				popcorn_types[index] = elite_popcorn_id
				ambush_flags[index] = false
				elite_flags[index] = false
	append_support_companions(
		force_debug_enemy, variants, levels, popcorn_flags, popcorn_types,
		ambush_flags, elite_flags, encounter_rng, room_policy, run_rank, run_number,
		base_level, level_spread, encounter_tier, enemy_level_cap, run_theme)
	if not force_debug_enemy:
		constrain_generated_roster(variants, ambush_flags, run_theme, run_number, generation_seed, "Generated room")


static func append_support_companions(
	force_debug_enemy: bool,
	variants: Array[String],
	levels: Array[int],
	popcorn_flags: Array[bool],
	popcorn_types: Array[String],
	ambush_flags: Array[bool],
	elite_flags: Array[bool],
	encounter_rng: RandomNumberGenerator,
	room_policy: RoomDefinition,
	run_rank: int,
	run_number: int,
	base_level: int,
	level_spread: int,
	encounter_tier: StringName,
	enemy_level_cap: int,
	run_theme: Array[int] = []
) -> int:
	var enemy_companion_count := 0
	for variant in variants:
		var companion_definition := EnemyFactory.definition(StringName(variant))
		if companion_definition != null and companion_definition.type_id in [&"slime", &"skeleton"] and companion_definition.encounter_role != &"support":
			enemy_companion_count += 1
	var support_variant_pool := filter_weighted_pool_for_theme(
		EnemyFactory.weighted_variants_for_role(&"slime", &"support", run_number), run_theme, run_number)
	var support_roll_count := room_policy.support_companion_roll_count(enemy_companion_count)
	if force_debug_enemy or support_variant_pool.is_empty():
		return 0
	var appended_count := 0
	for _support_roll in range(support_roll_count):
		if encounter_rng.randf() >= clampf(room_policy.support_companion_chance_per_group, 0.0, 1.0):
			continue
		var support_variant := select_weighted_variant(support_variant_pool, encounter_rng)
		var support_definition := EnemyFactory.definition(StringName(support_variant))
		if support_definition == null or support_definition.encounter_role != &"support":
			continue
		variants.append(support_variant)
		var support_level := encounter_rng.randi_range(base_level - level_spread, base_level + level_spread)
		levels.append(clampi(support_level, 1, enemy_level_cap))
		popcorn_flags.append(false)
		popcorn_types.append("")
		ambush_flags.append(false)
		elite_flags.append(encounter_tier == DungeonGraph.ENCOUNTER_ELITE)
		appended_count += 1
	return appended_count


static func migrate_saved_room_support_companions(
	state: Dictionary,
	room: DungeonGraph.RoomRecord,
	room_type: StringName,
	normal_base_level: int,
	run_rank: int,
	run_number: int,
	enemy_level_cap: int,
	room_policy: RoomDefinition,
	allow_migration: bool,
	run_theme: Array[int] = []
) -> void:
	if bool(state.get("support_companions_processed", false)):
		return
	var variants := state.get("enemy_variants", []) as Array
	if allow_migration and not bool(state.get("finished", false)) and not variants.is_empty():
		var has_existing_support := false
		for value in variants:
			var definition := EnemyFactory.definition(StringName(str(value)))
			if definition != null and definition.type_id == &"slime" and definition.encounter_role == &"support":
				has_existing_support = true
				break
		if not has_existing_support:
			var is_extra_room := room_type == DungeonGraph.ROOM_SPECIAL_ENEMY or room_type == DungeonGraph.ROOM_TREASURE
			var base_level := normal_base_level + (1 if is_extra_room else 0)
			if room.encounter_tier == DungeonGraph.ENCOUNTER_DANGEROUS:
				base_level += 1
			elif room.encounter_tier == DungeonGraph.ENCOUNTER_ELITE:
				base_level += 2
			var level_spread := 1 if run_rank <= 3 else 2
			var levels: Array[int] = []
			var popcorn_flags: Array[bool] = []
			var popcorn_types: Array[String] = []
			var ambush_flags: Array[bool] = []
			var elite_flags: Array[bool] = []
			var stored_levels := state.get("enemy_levels", []) as Array
			var stored_popcorn := state.get("enemy_popcorn", []) as Array
			var stored_popcorn_types := state.get("enemy_popcorn_types", []) as Array
			var stored_ambush := state.get("enemy_ambush", []) as Array
			var stored_elite := state.get("enemy_elite", []) as Array
			for slot in variants.size():
				var is_popcorn := bool(stored_popcorn[slot]) if slot < stored_popcorn.size() else false
				levels.append(int(stored_levels[slot]) if slot < stored_levels.size() else base_level)
				popcorn_flags.append(is_popcorn)
				popcorn_types.append(str(stored_popcorn_types[slot]) if slot < stored_popcorn_types.size() else "")
				ambush_flags.append(bool(stored_ambush[slot]) if slot < stored_ambush.size() else false)
				elite_flags.append(bool(stored_elite[slot]) if slot < stored_elite.size() else room.encounter_tier == DungeonGraph.ENCOUNTER_ELITE and not is_popcorn)
			var typed_variants: Array[String] = []
			for value in variants:
				typed_variants.append(str(value))
			var support_rng := RandomNumberGenerator.new()
			support_rng.seed = room.generation_seed ^ SAVED_ROOM_SUPPORT_ROLL_SALT
			var added := append_support_companions(
				false, typed_variants, levels, popcorn_flags, popcorn_types,
				ambush_flags, elite_flags, support_rng, room_policy, run_rank, run_number,
				base_level, level_spread, room.encounter_tier, enemy_level_cap, run_theme)
			if added > 0:
				state["enemy_variants"] = typed_variants
				state["enemy_levels"] = levels
				state["enemy_popcorn"] = popcorn_flags
				state["enemy_popcorn_types"] = popcorn_types
				state["enemy_ambush"] = ambush_flags
				state["enemy_elite"] = elite_flags
	state["support_companions_processed"] = true


func is_shadow_bound() -> bool:
	return matchup_policy == POLICY_SHADOW_BOUND
