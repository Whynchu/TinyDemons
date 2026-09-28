extends Resource
class_name EncounterDefinition

## Encounter composition contract (Slice C, T2). Captures the rank-gated enemy
## variant pool and matchup policy as editor-inspectable data, replacing the
## hardcoded rank constants that used to live in room_controller. RoomRuntime
## owns the mutable runtime state (claims, active actors, locks); this definition
## is immutable and reusable across rooms and runs.

const DEFAULT_DATA_PATH := "res://resources/definitions/encounter_definition.tres"
const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")
const SAVED_ROOM_SUPPORT_ROLL_SALT := 0x48534C4D


static func default_data() -> EncounterDefinition:
	return load(DEFAULT_DATA_PATH) as EncounterDefinition


const POLICY_RANK_DEFAULT := "rank_default"
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
## Matchup policy selects how authored primary/secondary families weight in.
@export var matchup_policy := POLICY_RANK_DEFAULT

var allowed_policies: Array[String] = [POLICY_RANK_DEFAULT, POLICY_BASE_ADVANTAGE, POLICY_BASE_COUNTER, POLICY_FLAME_MIXED, POLICY_SHADOW_BOUND]


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
	if not allowed_policies.has(matchup_policy):
		problems.append("unknown matchup_policy '%s'" % matchup_policy)
	return problems


## Late-run weighted entries that enter once the run rank passes their gate.
func late_pool_entries(run_rank: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for variant in SLIME_VARIANT_CATALOG_SCRIPT.variants():
		var definition := SLIME_VARIANT_CATALOG_SCRIPT.definition_resource(variant)
		if definition == null or definition.encounter_role != &"late":
			continue
		if run_rank >= definition.encounter_min_rank and definition.encounter_weight > 0.0:
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


static func boss_support_variant_pool(include_skeletons: bool) -> Array[Dictionary]:
	var support_pool := EnemyFactory.weighted_variants_for_type(&"slime")
	if include_skeletons:
		balance_enemy_family_weights(support_pool, EnemyFactory.weighted_variants_for_type(&"skeleton"))
	return support_pool


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
	base_level: int,
	level_spread: int,
	encounter_tier: StringName,
	enemy_level_cap: int
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
		ambush_flags, elite_flags, encounter_rng, room_policy, run_rank,
		base_level, level_spread, encounter_tier, enemy_level_cap)


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
	base_level: int,
	level_spread: int,
	encounter_tier: StringName,
	enemy_level_cap: int
) -> int:
	var enemy_companion_count := 0
	for variant in variants:
		var companion_definition := EnemyFactory.definition(StringName(variant))
		if companion_definition != null and companion_definition.type_id in [&"slime", &"skeleton"] and companion_definition.encounter_role != &"support":
			enemy_companion_count += 1
	var support_variant_pool := EnemyFactory.weighted_variants_for_role(&"slime", &"support", run_rank)
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
	enemy_level_cap: int,
	room_policy: RoomDefinition,
	allow_migration: bool
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
				ambush_flags, elite_flags, support_rng, room_policy, run_rank,
				base_level, level_spread, room.encounter_tier, enemy_level_cap)
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
