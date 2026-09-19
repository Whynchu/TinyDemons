extends Resource
class_name RewardDefinition

## Reward composition contract (Slice E, T2). Captures the chest reward drop
## policy (item-drop chance, drop-count thresholds, loot-grade bonuses) as
## editor-inspectable data, replacing the hardcoded curves in run_flow_controller.
## Immutable and reusable across rooms and runs; runtime reward resolution stays
## in RunFlowController.

const DEFAULT_DATA_PATH := "res://resources/definitions/reward_definition.tres"

static func default_data() -> RewardDefinition:
	return load(DEFAULT_DATA_PATH) as RewardDefinition

## Loot-grade flat bonus used by every reward curve.
@export var loot_grade_bonus_s := 3.0
@export var loot_grade_bonus_a := 2.0
@export var loot_grade_bonus_b := 1.0
@export var loot_grade_bonus_c := 0.5
@export var loot_grade_bonus_f := -0.5

## Chest item drop chance curve.
@export var drop_chance_base := 0.34
@export var drop_chance_per_rank := 0.035
@export var drop_chance_per_grade := 0.025
@export var drop_chance_floor := 0.30
@export var drop_chance_cap := 0.88
@export var drop_chance_risk_bonus := 0.12
@export var drop_chance_risk_cap := 0.95
@export var exploration_bonus_per_chest := 0.025
@export var exploration_bonus_cap := 0.20

## Chest item drop count thresholds.
@export var double_drop_base := 0.35
@export var double_drop_per_rank := 0.06
@export var double_drop_per_grade := 0.04
@export var double_drop_floor := 0.25
@export var double_drop_cap := 0.75
@export var triple_drop_base := 0.01
@export var triple_drop_per_rank := 0.0045
@export var triple_drop_per_grade := 0.006
@export var triple_drop_cap := 0.15
@export var quad_drop_base := 0.005
@export var quad_drop_per_rank := 0.0035
@export var quad_drop_per_grade := 0.004
@export var quad_drop_cap := 0.10


func validate() -> Array[String]:
	var problems: Array[String] = []
	if drop_chance_cap < drop_chance_floor: problems.append("drop_chance_cap must be >= drop_chance_floor")
	if drop_chance_risk_cap < drop_chance_cap: problems.append("drop_chance_risk_cap must be >= drop_chance_cap")
	if double_drop_cap < double_drop_floor: problems.append("double_drop_cap must be >= double_drop_floor")
	if triple_drop_cap < triple_drop_base: problems.append("triple_drop_cap must be >= triple_drop_base")
	if quad_drop_cap < quad_drop_base: problems.append("quad_drop_cap must be >= quad_drop_base")
	if exploration_bonus_cap < 0 or exploration_bonus_per_chest < 0: problems.append("exploration bonus values must be non-negative")
	return problems


func loot_grade_bonus(grade: String) -> float:
	var value := grade.to_upper()
	if value == "S": return loot_grade_bonus_s
	if value == "A": return loot_grade_bonus_a
	if value == "B": return loot_grade_bonus_b
	if value == "C": return loot_grade_bonus_c
	if value == "F": return loot_grade_bonus_f
	return 0.0


func item_drop_chance(exploration_bonus: float, run_rank: int, grade: String) -> float:
	var base := clampf(drop_chance_base + exploration_bonus + float(run_rank - 1) * drop_chance_per_rank + loot_grade_bonus(grade) * drop_chance_per_grade, drop_chance_floor, drop_chance_cap)
	return base


func risk_item_drop_chance(exploration_bonus: float, run_rank: int, grade: String) -> float:
	return clampf(item_drop_chance(exploration_bonus, run_rank, grade) + drop_chance_risk_bonus, drop_chance_floor, drop_chance_risk_cap)


func drop_count_for(roll: float, run_rank: int, grade: String) -> int:
	var double_chance := clampf(double_drop_base + float(run_rank - 1) * double_drop_per_rank + loot_grade_bonus(grade) * double_drop_per_grade, double_drop_floor, double_drop_cap)
	var triple_chance := clampf(triple_drop_base + float(run_rank - 1) * triple_drop_per_rank + loot_grade_bonus(grade) * triple_drop_per_grade, triple_drop_base, triple_drop_cap)
	var quad_chance := clampf(quad_drop_base + float(run_rank - 1) * quad_drop_per_rank + loot_grade_bonus(grade) * quad_drop_per_grade, quad_drop_base, quad_drop_cap)
	if roll < quad_chance: return 4
	if roll < triple_chance: return 3
	return 2 if roll < double_chance else 1