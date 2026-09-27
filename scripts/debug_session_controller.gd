extends Node
class_name DebugSessionController

## Transient overrides used only while the opt-in pause debug page is active.
## These values intentionally never serialize to PlayerProfile or run snapshots.
var active := false
var selected_run_number := 1
var original_player_level := 1
var player_level_override := 0
var invulnerable := false
var unlimited_chroma := false
var enemies_paused := false
var reset_confirmation_armed := false
var original_geometry_enabled := false


func begin(root: Object) -> void:
	if active:
		return
	active = true
	var profile := root.get("player_profile") as PlayerProfile
	var run_flow := root.get("run_flow_controller") as RunFlowController
	selected_run_number = run_flow.debug_run_number if run_flow != null and run_flow.debug_run_number > 0 else maxi(profile.completed_runs + 1 if profile != null else 1, 1)
	var stats := root.get("player_stats") as StatsComponent
	original_player_level = maxi(stats.level if stats != null else 1, 1)
	player_level_override = 0
	var geometry := root.get("actor_geometry_debug_drawer") as ActorGeometryDebugDrawer
	original_geometry_enabled = geometry.enabled if geometry != null else false


func end(root: Object) -> void:
	if not active:
		return
	var stats := root.get("player_stats") as StatsComponent
	if stats != null:
		stats.level = original_player_level
	var health := root.get("player_health_component") as HealthComponent
	if health != null:
		health.set_maximum_health(float(root.call("_player_max_health")), true)
		root.set("player_display_health", health.current_health)
	var room_controller := root.get("room_controller") as RoomController
	if room_controller != null:
		room_controller.player_level = original_player_level
	if health != null: health.debug_invulnerable = false
	var chroma := root.get("player_chroma_component") as PlayerChromaComponent
	if chroma != null: chroma.debug_unlimited_chroma = false
	var geometry := root.get("actor_geometry_debug_drawer") as ActorGeometryDebugDrawer
	if geometry != null: geometry.enabled = original_geometry_enabled
	active = false
	player_level_override = 0
	invulnerable = false
	unlimited_chroma = false
	enemies_paused = false
	reset_confirmation_armed = false
	root.call("_update_player_health_ui")
	root.call("_update_player_progression_ui")
	root.call("_update_room_number_indicator")


func set_player_level(root: Object, level: int) -> void:
	if not active:
		return
	var stats := root.get("player_stats") as StatsComponent
	if stats == null:
		return
	player_level_override = clampi(level, 1, 99)
	stats.level = player_level_override
	var room_controller := root.get("room_controller") as RoomController
	if room_controller != null:
		room_controller.player_level = player_level_override
	var health := root.get("player_health_component") as HealthComponent
	if health != null:
		var maximum := float(root.call("_player_max_health"))
		health.set_maximum_health(maximum, true)
		root.set("player_display_health", health.current_health)
	root.call("_update_player_health_ui")
	root.call("_update_player_progression_ui")


func set_run_number(root: Object, run_number: int) -> void:
	if not active:
		return
	selected_run_number = clampi(run_number, 1, 99)
	var run_flow := root.get("run_flow_controller") as RunFlowController
	if run_flow != null:
		run_flow.debug_run_number = selected_run_number


func reset_run(root: Object) -> void:
	if not active:
		return
	if not reset_confirmation_armed:
		reset_confirmation_armed = true
		return
	reset_confirmation_armed = false
	var run_flow := root.get("run_flow_controller") as RunFlowController
	if run_flow != null:
		run_flow.debug_run_number = selected_run_number
	root.call("_begin_new_run")
	root.call("_update_room_number_indicator")


func change_run_number(direction: int) -> void:
	if active:
		selected_run_number = clampi(selected_run_number + direction, 1, 99)
		reset_confirmation_armed = false


func change_player_level(root: Object, direction: int) -> void:
	if not active:
		return
	var current_level := player_level_override if player_level_override > 0 else original_player_level
	set_player_level(root, clampi(current_level + direction, 1, 99))


func toggle(root: Object, option: StringName) -> void:
	if not active:
		return
	match option:
		&"invulnerable":
			invulnerable = not invulnerable
			var health := root.get("player_health_component") as HealthComponent
			if health != null: health.debug_invulnerable = invulnerable
		&"unlimited_chroma":
			unlimited_chroma = not unlimited_chroma
			var chroma := root.get("player_chroma_component") as PlayerChromaComponent
			if chroma != null: chroma.debug_unlimited_chroma = unlimited_chroma
		&"pause_enemies": enemies_paused = not enemies_paused
		&"geometry_guides":
			var geometry := root.get("actor_geometry_debug_drawer") as ActorGeometryDebugDrawer
			if geometry != null: geometry.enabled = not geometry.enabled
