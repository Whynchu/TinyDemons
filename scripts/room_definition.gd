extends Resource
class_name RoomDefinition

## Room composition contract (Slice C, T2). Captures the rank-curve difficulty
## and traffic policy (enemy count cap, extra-enemy chance, popcorn rates, boss
## support/minor counts, treasure chance) as editor-inspectable data, replacing
## the hardcoded rank curves that used to live in RoomController. Immutable and
## reusable across rooms and runs; RoomController owns the runtime state.

const DEFAULT_DATA_PATH := "res://resources/definitions/room_definition.tres"


static func default_data() -> RoomDefinition:
	return load(DEFAULT_DATA_PATH) as RoomDefinition

@export var regular_room_treasure_chance := 0.50

@export var popcorn_chance_early := 0.25
@export var popcorn_chance_run2 := 0.40
@export var popcorn_chance_later := 0.24

@export var normal_enemy_cap := 7

## Base extra-enemy chance at rank 1, and per-rank growth/clamp.
@export var extra_enemy_base := 0.50
@export var extra_enemy_per_rank := 0.05
@export var extra_enemy_cap := 0.78
## Per-slot falloff so five-to-seven enemy rooms stay rare tails.
@export var extra_enemy_per_slot_falloff := 0.14
@export var extra_enemy_rank_bonus := 0.015
@export var extra_enemy_rank_bonus_cap := 0.10

@export var boss_support_popcorn_base := 3
@export var boss_support_popcorn_max := 6
@export var boss_mixed_support_start_rank := 5


func validate() -> Array[String]:
	var problems: Array[String] = []
	if normal_enemy_cap < 1: problems.append("normal_enemy_cap must be >= 1")
	if regular_room_treasure_chance < 0.0 or regular_room_treasure_chance > 1.0:
		problems.append("regular_room_treasure_chance must be in [0,1]")
	for key in ["popcorn_chance_early", "popcorn_chance_run2", "popcorn_chance_later"]:
		var value := float(get(key))
		if value < 0.0 or value > 1.0: problems.append("%s must be in [0,1]" % key)
	if extra_enemy_cap < extra_enemy_base: problems.append("extra_enemy_cap must be >= extra_enemy_base")
	if boss_support_popcorn_base < 0 or boss_support_popcorn_max < boss_support_popcorn_base:
		problems.append("boss support popcorn counts must be ordered")
	if boss_mixed_support_start_rank < 1: problems.append("boss_mixed_support_start_rank must be >= 1")
	return problems


func popcorn_chance_for_rank(run_rank: int) -> float:
	if run_rank <= 1: return popcorn_chance_early
	if run_rank == 2: return popcorn_chance_run2
	return popcorn_chance_later


func boss_support_popcorn_for_rank(run_rank: int) -> int:
	if run_rank <= 2: return boss_support_popcorn_base
	if run_rank <= 6: return boss_support_popcorn_base + 1
	return boss_support_popcorn_max


func boss_minor_count_for_rank(run_rank: int) -> int:
	if run_rank < boss_mixed_support_start_rank: return 0
	if run_rank == boss_mixed_support_start_rank: return 1
	if run_rank == boss_mixed_support_start_rank + 1: return 2
	# After the first two mixed-support steps, add one minor every three runs.
	return 2 + floori(float(run_rank - 7) / 3.0)


func additional_enemy_chance_for(run_rank: int, current_count: int) -> float:
	var first_extra := clampf(extra_enemy_base + float(run_rank - 1) * extra_enemy_per_rank, extra_enemy_base, extra_enemy_cap)
	var rank_bonus := clampf(float(run_rank - 1) * extra_enemy_rank_bonus, 0.0, extra_enemy_rank_bonus_cap)
	# The steep falloff keeps five-to-seven enemy rooms as rare tails rather
	# than letting early and mid-rank rooms snowball past four too often.
	return clampf(first_extra - float(current_count - 1) * extra_enemy_per_slot_falloff + rank_bonus, 0.01, 0.85)