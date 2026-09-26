extends Resource
class_name EncounterDefinition

## Encounter composition contract (Slice C, T2). Captures the rank-gated enemy
## variant pool and matchup policy as editor-inspectable data, replacing the
## hardcoded rank constants that used to live in room_controller. RoomRuntime
## owns the mutable runtime state (claims, active actors, locks); this definition
## is immutable and reusable across rooms and runs.

const DEFAULT_DATA_PATH := "res://resources/definitions/encounter_definition.tres"
const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")


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


func is_shadow_bound() -> bool:
	return matchup_policy == POLICY_SHADOW_BOUND
