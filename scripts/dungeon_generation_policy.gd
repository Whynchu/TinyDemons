extends Resource
class_name DungeonGenerationPolicy

## Explicit dungeon-generation inputs (Slice D, T2). Captures the numeric and
## candidate policy the generated layout solver uses, so the generator consumes
## editor-inspectable data instead of hardcoded constants. The heavy topology,
## route, and milestone logic stays in DungeonLayoutGenerator; this resource is
## the authored policy surface.

const GENERATED_LAYOUT_ID: StringName = &"RUN_GENERATED"
const COMPACT_MAP_SIZE := Vector2i(35, 35)
const COMPACT_MAP_ORIGIN := Vector2i(17, 32)
const RISK_REWARD_GENERATION_MODE: StringName = &"risk_reward_r6_plus"

@export var generated_candidate_count := 1
@export var risk_reward_candidate_count := 3
@export var first_orb_depth := 3
@export var first_special_depth := 4
@export var primary_flames: Array[StringName] = [&"fire", &"water", &"electric"]


func validate() -> Array[String]:
	var problems: Array[String] = []
	if generated_candidate_count < 1: problems.append("generated_candidate_count must be >= 1")
	if risk_reward_candidate_count < 1: problems.append("risk_reward_candidate_count must be >= 1")
	if first_orb_depth < 1: problems.append("first_orb_depth must be >= 1")
	if first_special_depth < 1: problems.append("first_special_depth must be >= 1")
	if primary_flames.is_empty(): problems.append("primary_flames must not be empty")
	return problems