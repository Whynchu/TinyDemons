extends RefCounted
class_name EnemyEncounterScaling

const ELITE_LEVEL_BONUS := 2


static func roll_non_popcorn_level(
	rng: RandomNumberGenerator,
	base: int,
	spread: int,
	encounter_tier: StringName,
	normal_cap: int,
) -> int:
	var floor_level := base - spread
	var cap := normal_cap
	if encounter_tier == DungeonGraph.ENCOUNTER_ELITE:
		# The caller already includes the tier's base offset. Every elite-marked
		# enemy, including appended supports, uses the lead enemy's raised band.
		floor_level = base + 1
		cap += ELITE_LEVEL_BONUS
	return clampi(rng.randi_range(floor_level, base + spread), 1, cap)


static func level_cap(run_rank: int) -> int:
	return run_rank + 2 if run_rank <= 3 else run_rank + 4


static func base_level(run_rank: int) -> int:
	return run_rank + 1 if run_rank <= 3 else run_rank + 2


static func popcorn_chance(definition: RoomDefinition, run_rank: int) -> float:
	return definition.popcorn_chance_for_rank(run_rank)


static func popcorn_level(player_level: int) -> int:
	return maxi(1, player_level - 5)


static func popcorn_level_for_profile(profile: PlayerProfile, player_level: int) -> int:
	return maxi(1, profile.level - 5) if profile != null else popcorn_level(player_level)
