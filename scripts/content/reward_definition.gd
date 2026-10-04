extends Resource
class_name RewardDefinition

## Reward composition contract (Slice E, T2). Captures gear drop chance,
## drop-count thresholds, run-clear rewards, rarity progression, and loot-grade
## bonuses as editor-inspectable data. Runtime resolution stays in
## RunFlowController.

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
@export var drop_chance_base := 0.45
@export var drop_chance_per_rank := 0.035
@export var drop_chance_per_grade := 0.025
@export var drop_chance_floor := 0.40
@export var drop_chance_cap := 0.92
@export var drop_chance_risk_bonus := 0.12
@export var drop_chance_risk_cap := 0.95
@export var exploration_bonus_per_chest := 0.025
@export var exploration_bonus_cap := 0.20
## Vaults guarantee this many premium gear items after their guaranteed drop.
@export_range(1, 4, 1) var vault_item_drop_count := 2

## Persistent gear progression. Only saved completed runs count; the progress
## stops increasing after the configured cap. Current-run depth is not used.
@export var completed_run_loot_cap := 20
@export var drop_chance_per_completed_run := 0.015
@export var double_drop_per_completed_run := 0.015
@export var triple_drop_per_completed_run := 0.005
@export var quad_drop_per_completed_run := 0.002
@export var clear_drop_chance_base := 0.40
@export var clear_drop_chance_per_score := 0.0065
@export var clear_drop_chance_per_completed_run := 0.0025
@export var clear_drop_chance_cap := 1.0
## Each completed run adds this much total rare-or-better probability, split
## across Rare/Epic/Legendary/Mythic at 60/30/8/2 percent.
@export var rarity_bonus_budget_per_completed_run := 0.005

## Chest item drop count thresholds.
@export var double_drop_base := 0.50
@export var double_drop_per_rank := 0.06
@export var double_drop_per_grade := 0.04
@export var double_drop_floor := 0.25
@export var double_drop_cap := 0.85
@export var triple_drop_base := 0.025
@export var triple_drop_per_rank := 0.0045
@export var triple_drop_per_grade := 0.006
@export var triple_drop_cap := 0.22
@export var quad_drop_base := 0.01
@export var quad_drop_per_rank := 0.0035
@export var quad_drop_per_grade := 0.004
@export var quad_drop_cap := 0.12


func validate() -> Array[String]:
	var problems: Array[String] = []
	if vault_item_drop_count < 1 or vault_item_drop_count > 4: problems.append("vault_item_drop_count must be between 1 and 4")
	if drop_chance_cap < drop_chance_floor: problems.append("drop_chance_cap must be >= drop_chance_floor")
	if drop_chance_risk_cap < drop_chance_cap: problems.append("drop_chance_risk_cap must be >= drop_chance_cap")
	if double_drop_cap < double_drop_floor: problems.append("double_drop_cap must be >= double_drop_floor")
	if triple_drop_cap < triple_drop_base: problems.append("triple_drop_cap must be >= triple_drop_base")
	if quad_drop_cap < quad_drop_base: problems.append("quad_drop_cap must be >= quad_drop_base")
	if exploration_bonus_cap < 0 or exploration_bonus_per_chest < 0: problems.append("exploration bonus values must be non-negative")
	if completed_run_loot_cap < 0: problems.append("completed_run_loot_cap must be non-negative")
	for value in [drop_chance_per_completed_run, double_drop_per_completed_run, triple_drop_per_completed_run, quad_drop_per_completed_run, clear_drop_chance_per_score, clear_drop_chance_per_completed_run, rarity_bonus_budget_per_completed_run]:
		if float(value) < 0.0: problems.append("completed-run reward bonuses must be non-negative")
	if clear_drop_chance_base < 0.0 or clear_drop_chance_cap > 1.0 or clear_drop_chance_cap < clear_drop_chance_base:
		problems.append("clear reward chance must stay within [0, 1] and cap at or above its base")
	return problems


func _completed_run_progress(completed_runs: int) -> int:
	return clampi(completed_runs, 0, completed_run_loot_cap)


func completed_run_rarity_bonus(completed_runs: int) -> Array[float]:
	var bonus_budget := float(_completed_run_progress(completed_runs)) * rarity_bonus_budget_per_completed_run
	var result: Array[float] = []
	result.append(bonus_budget * 0.60)
	result.append(bonus_budget * 0.30)
	result.append(bonus_budget * 0.08)
	result.append(bonus_budget * 0.02)
	return result


func clear_item_drop_chance(score: int, completed_runs: int) -> float:
	var score_bonus := float(clampi(score, 0, 100)) * clear_drop_chance_per_score
	var run_bonus := float(_completed_run_progress(completed_runs)) * clear_drop_chance_per_completed_run
	return clampf(clear_drop_chance_base + score_bonus + run_bonus, clear_drop_chance_base, clear_drop_chance_cap)


func loot_grade_bonus(grade: String) -> float:
	var value := grade.to_upper()
	if value == "S": return loot_grade_bonus_s
	if value == "A": return loot_grade_bonus_a
	if value == "B": return loot_grade_bonus_b
	if value == "C": return loot_grade_bonus_c
	if value == "F": return loot_grade_bonus_f
	return 0.0


func item_drop_chance(exploration_bonus: float, run_rank: int, grade: String, completed_runs: int = 0) -> float:
	var run_bonus := float(_completed_run_progress(completed_runs)) * drop_chance_per_completed_run
	var base := clampf(drop_chance_base + exploration_bonus + float(run_rank - 1) * drop_chance_per_rank + loot_grade_bonus(grade) * drop_chance_per_grade + run_bonus, drop_chance_floor, drop_chance_cap)
	return base


func risk_item_drop_chance(exploration_bonus: float, run_rank: int, grade: String, completed_runs: int = 0) -> float:
	return clampf(item_drop_chance(exploration_bonus, run_rank, grade, completed_runs) + drop_chance_risk_bonus, drop_chance_floor, drop_chance_risk_cap)


func drop_count_for(roll: float, run_rank: int, grade: String, completed_runs: int = 0) -> int:
	var completed_run_progress := float(_completed_run_progress(completed_runs))
	var double_chance := clampf(double_drop_base + float(run_rank - 1) * double_drop_per_rank + loot_grade_bonus(grade) * double_drop_per_grade + completed_run_progress * double_drop_per_completed_run, double_drop_floor, double_drop_cap)
	var triple_chance := clampf(triple_drop_base + float(run_rank - 1) * triple_drop_per_rank + loot_grade_bonus(grade) * triple_drop_per_grade + completed_run_progress * triple_drop_per_completed_run, triple_drop_base, triple_drop_cap)
	var quad_chance := clampf(quad_drop_base + float(run_rank - 1) * quad_drop_per_rank + loot_grade_bonus(grade) * quad_drop_per_grade + completed_run_progress * quad_drop_per_completed_run, quad_drop_base, quad_drop_cap)
	if roll < quad_chance: return 4
	if roll < triple_chance: return 3
	return 2 if roll < double_chance else 1
