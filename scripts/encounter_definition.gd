extends Resource
class_name EncounterDefinition

## Encounter composition contract (Slice C, T2). Captures the rank-gated enemy
## variant pool and matchup policy as editor-inspectable data, replacing the
## hardcoded rank constants that used to live in room_controller. RoomRuntime
## owns the mutable runtime state (claims, active actors, locks); this definition
## is immutable and reusable across rooms and runs.

const POLICY_RANK_DEFAULT := "rank_default"
const POLICY_BASE_ADVANTAGE := "base_advantage"
const POLICY_BASE_COUNTER := "base_counter"
const POLICY_FLAME_MIXED := "flame_mixed"
const POLICY_SHADOW_BOUND := "shadow_bound"

## Grey is the neutral baseline present in every normal encounter.
@export var grey_weight := 1.0
## Late-run elemental families enter the rotation at these run ranks. Weight 0
## disables the family entirely.
@export var yellow_weight := 1.0
@export var yellow_min_rank := 5
@export var ground_weight := 1.0
@export var ground_min_rank := 5
@export var ice_weight := 1.0
@export var ice_min_rank := 5
## Shadow Slimes are a rare pressure spike, not a normal roster member.
@export var shadow_weight := 0.12
@export var shadow_min_rank := 5
## Content-driven tanky Fire variant (added via EnemyDefinition).
@export var crimson_weight := 0.6
@export var crimson_min_rank := 5
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
	for key in ["yellow", "ground", "ice", "crimson"]:
		var weight := float(get("%s_weight" % key))
		if weight < 0.0: problems.append("%s_weight must be non-negative" % key)
	if shadow_weight < 0.0: problems.append("shadow_weight must be non-negative")
	if shadow_bound_normal_weight < 0.0 or shadow_bound_variant_weight < 0.0:
		problems.append("shadow-bound weights must be non-negative")
	if yellow_min_rank < 1 or ground_min_rank < 1 or ice_min_rank < 1 or crimson_min_rank < 1:
		problems.append("min ranks must be >= 1")
	if not allowed_policies.has(matchup_policy):
		problems.append("unknown matchup_policy '%s'" % matchup_policy)
	return problems


## Late-run weighted entries that enter once the run rank passes their gate.
func late_pool_entries(run_rank: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if run_rank >= yellow_min_rank and yellow_weight > 0.0: entries.append({"variant": "yellow", "weight": yellow_weight})
	if run_rank >= ground_min_rank and ground_weight > 0.0: entries.append({"variant": "orange", "weight": ground_weight})
	if run_rank >= ice_min_rank and ice_weight > 0.0: entries.append({"variant": "aquamarine", "weight": ice_weight})
	if run_rank >= crimson_min_rank and crimson_weight > 0.0: entries.append({"variant": "crimson", "weight": crimson_weight})
	return entries


func is_shadow_bound() -> bool:
	return matchup_policy == POLICY_SHADOW_BOUND