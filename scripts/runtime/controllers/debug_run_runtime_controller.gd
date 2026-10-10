extends RefCounted
class_name DebugRunRuntimeController


static func progression_run(root: GameplayState) -> int:
	var configuration := root.debug_run_configuration
	return configuration.run_number if root.debug_start_in_boss_room and configuration != null else 0


static func dungeon_seed(root: GameplayState, preview_session: RefCounted, rng: RandomNumberGenerator) -> int:
	if preview_session != null:
		return int(preview_session.get("seed"))
	var configuration := root.debug_run_configuration
	return configuration.dungeon_seed if configuration != null and configuration.dungeon_seed > 0 else rng.randi()


static func configure_room(root: GameplayState, profile: PlayerProfile, run_number: int, dungeon_seed: int) -> void:
	var room := root.room_controller
	var configuration := root.debug_run_configuration
	room.debug_boss_stress_encounter = configuration != null and configuration.boss_stress_encounter
	if run_number <= 0:
		return
	root.run_flow_controller.debug_run_number = run_number
	root.run_flow_controller.debug_boss_fixture_start = true
	var theme_run_number := root.run_flow_controller.element_theme_run_number(profile)
	room.progression_run_rank = root.run_flow_controller.run_rank(root)
	room.progression_run_number = theme_run_number
	room.set_run_element_theme(EncounterDefinition.select_run_element_theme(dungeon_seed, theme_run_number))


static func configure_health(root: GameplayState, health: HealthComponent) -> void:
	var configuration := root.debug_run_configuration
	health.debug_invulnerable = configuration != null and configuration.player_invulnerable
