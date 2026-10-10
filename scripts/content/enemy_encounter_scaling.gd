extends RefCounted
class_name EnemyEncounterScaling


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
