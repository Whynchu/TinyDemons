extends Resource
class_name DungeonGenerationPolicy

## Explicit dungeon-generation inputs (Slice D, T2). Captures the numeric and
## candidate policy the generated layout solver uses, so the generator consumes
## editor-inspectable data instead of hardcoded constants. The heavy topology,
## route, and milestone logic stays in DungeonLayoutGenerator; this resource is
## the authored policy surface.

const DEFAULT_DATA_PATH := "res://resources/definitions/dungeon_generation_policy.tres"


static func default_data() -> DungeonGenerationPolicy:
	return load(DEFAULT_DATA_PATH) as DungeonGenerationPolicy

const GENERATED_LAYOUT_ID: StringName = &"RUN_GENERATED"
const COMPACT_MAP_SIZE := Vector2i(35, 35)
const COMPACT_MAP_ORIGIN := Vector2i(17, 32)
const RISK_REWARD_GENERATION_MODE: StringName = &"risk_reward_r6_plus"

@export var generated_candidate_count := 1
@export var risk_reward_candidate_count := 3
@export var first_orb_depth := 3
@export var first_special_depth := 4
@export var primary_flames: Array[StringName] = [&"fire", &"water", &"electric"]

## Route policy: risk shortcuts must sit between the first dig depth and a
## band below the boss, and the risk route must be at least this many
## transitions shorter than the safe route.
@export var risk_choice_min_y := 4
@export var risk_choice_boss_margin := 2
@export var elemental_vault_cap := 2
@export var risk_route_shortcut_advantage := 1


func validate() -> Array[String]:
	var problems: Array[String] = []
	if generated_candidate_count < 1: problems.append("generated_candidate_count must be >= 1")
	if risk_reward_candidate_count < 1: problems.append("risk_reward_candidate_count must be >= 1")
	if first_orb_depth < 1: problems.append("first_orb_depth must be >= 1")
	if first_special_depth < 1: problems.append("first_special_depth must be >= 1")
	if primary_flames.is_empty(): problems.append("primary_flames must not be empty")
	if risk_choice_min_y < 1: problems.append("risk_choice_min_y must be >= 1")
	if risk_choice_boss_margin < 1: problems.append("risk_choice_boss_margin must be >= 1")
	if elemental_vault_cap < 0: problems.append("elemental_vault_cap must be >= 0")
	if risk_route_shortcut_advantage < 0: problems.append("risk_route_shortcut_advantage must be >= 0")
	return problems


func is_valid_risk_choice_y(room_y: int, boss_depth: int) -> bool:
	return room_y >= risk_choice_min_y and room_y < boss_depth - risk_choice_boss_margin