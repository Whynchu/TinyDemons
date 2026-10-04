extends Node
class_name DebugSessionController

## Transient overrides used only while the opt-in pause debug page is active.
## These values intentionally never serialize to PlayerProfile or run snapshots.
## Owns the pause debug page's dispatch so GameplayState stays a thin wiring root.

const DEBUG_PAUSE_PAGE := 3
const MAX_DEBUG_PLAYER_LEVEL := 999

var active := false
var selected_run_number := 1
var original_player_level := 1
var player_level_override := 0
var debug_unassigned_stat_points := 0
var _base_unassigned_stat_points := 0
var _base_debug_allocations: Dictionary = {}
var _base_manual_growth: Dictionary = {}
var _base_manual_allocation_enabled := false
var invulnerable := false
var unlimited_chroma := false
var enemies_paused := false
var reset_confirmation_armed := false
var original_geometry_enabled := false


func _root() -> GameplayState:
	return get_parent() as GameplayState


func open_page() -> void:
	var root := _root()
	if root == null or root.run_state == null or not root.run_state.active:
		return
	if not bool(root.settings_service.get_setting(&"debug_menu_enabled", false)):
		return
	begin(root)
	root.screen_state_controller.set_pause_page(root, DEBUG_PAUSE_PAGE)
	root.screen_state_controller.refresh_debug_menu(root)


func handle_action(action: StringName, _amount: int = 0) -> void:
	var root := _root()
	if root == null:
		return
	match action:
		&"run_decrease": change_run_number(-1)
		&"run_increase": change_run_number(1)
		&"level_decrease": change_player_level(root, -1)
		&"level_increase": change_player_level(root, 1)
		&"toggle_invulnerable": toggle(root, &"invulnerable")
		&"toggle_unlimited_chroma": toggle(root, &"unlimited_chroma")
		&"toggle_pause_enemies": toggle(root, &"pause_enemies")
		&"toggle_geometry_guides": toggle(root, &"geometry_guides")
		&"reset_run": reset_run(root)
		&"back": root.screen_state_controller.set_pause_page(root, 0)
		&"end_session":
			end(root)
			root.screen_state_controller.set_pause_page(root, 0)
	root.screen_state_controller.refresh_debug_menu(root)


func effective_player_level(default_level: int) -> int:
	return player_level_override if player_level_override > 0 else default_level


func begin(root: GameplayState) -> void:
	if active:
		return
	active = true
	var run_flow := root.run_flow_controller
	selected_run_number = run_flow.debug_run_number if run_flow != null and run_flow.debug_run_number > 0 else maxi(root.player_profile.completed_runs + 1 if root.player_profile != null else 1, 1)
	original_player_level = maxi(root.player_stats.level if root.player_stats != null else 1, 1)
	player_level_override = 0
	_base_unassigned_stat_points = root.player_profile.unspent_stat_points if root.player_profile != null else 0
	_base_debug_allocations.clear()
	_base_manual_growth.clear()
	_base_manual_allocation_enabled = root.player_stats != null and root.player_stats.manual_allocation_enabled
	if _base_manual_allocation_enabled:
		var stats := root.player_stats
		var allocation := stats.manual_allocation()
		for stat_name: StringName in StatsComponent.STAT_NAMES:
			_base_debug_allocations[stat_name] = int(allocation.get(String(stat_name), 0))
		_base_manual_growth = {
			"base_vit": stats.manual_base_vit,
			"base_str": stats.manual_base_str,
			"base_def": stats.manual_base_def,
			"base_agi": stats.manual_base_agi,
			"base_int": stats.manual_base_int,
			"base_mnd": stats.manual_base_mnd,
		}
	elif root.player_profile != null:
		for stat_name: StringName in StatsComponent.STAT_NAMES:
			var field := "allocated_%s" % String(stat_name).to_lower()
			_base_debug_allocations[stat_name] = int(root.player_profile.get(field))
	debug_unassigned_stat_points = _base_unassigned_stat_points
	original_geometry_enabled = root.actor_geometry_debug_drawer.enabled if root.actor_geometry_debug_drawer != null else false


func end(root: GameplayState) -> void:
	if not active:
		return
	var stats := root.player_stats
	if stats != null:
		stats.level = original_player_level
		if _base_manual_allocation_enabled:
			stats.configure_manual_growth(
				int(_base_manual_growth.get("base_vit", stats.manual_base_vit)),
				int(_base_manual_growth.get("base_str", stats.manual_base_str)),
				int(_base_manual_growth.get("base_def", stats.manual_base_def)),
				int(_base_manual_growth.get("base_agi", stats.manual_base_agi)),
				int(_base_debug_allocations.get(&"VIT", 0)),
				int(_base_debug_allocations.get(&"STR", 0)),
				int(_base_debug_allocations.get(&"DEF", 0)),
				int(_base_debug_allocations.get(&"AGI", 0)),
				int(_base_manual_growth.get("base_int", stats.manual_base_int)),
				int(_base_manual_growth.get("base_mnd", stats.manual_base_mnd)),
				int(_base_debug_allocations.get(&"INT", 0)),
				int(_base_debug_allocations.get(&"MND", 0))
			)
	var health := root.player_health_component
	if health != null:
		health.set_maximum_health(float(root._player_max_health()), true)
		root.player_display_health = health.current_health
	var room_controller := root.room_controller
	if room_controller != null:
		room_controller.player_level = original_player_level
	if health != null: health.debug_invulnerable = false
	var chroma := root.player_chroma_component
	if chroma != null: chroma.debug_unlimited_chroma = false
	var geometry := root.actor_geometry_debug_drawer
	if geometry != null: geometry.enabled = original_geometry_enabled
	active = false
	player_level_override = 0
	invulnerable = false
	unlimited_chroma = false
	enemies_paused = false
	reset_confirmation_armed = false
	root._update_player_health_ui()
	root._update_player_progression_ui()
	root._update_room_number_indicator()


func _allocation_total(values: Dictionary) -> int:
	var total := 0
	for stat_name: StringName in StatsComponent.STAT_NAMES:
		total += maxi(int(values.get(stat_name, 0)), 0)
	return total


func _trim_allocation_evenly(values: Dictionary, points_to_keep: int) -> Dictionary:
	var total := _allocation_total(values)
	var keep := clampi(points_to_keep, 0, total)
	if total <= keep:
		return values.duplicate()
	var result: Dictionary = {}
	var remainders: Dictionary = {}
	var assigned := 0
	for stat_name: StringName in StatsComponent.STAT_NAMES:
		var original := maxi(int(values.get(stat_name, 0)), 0)
		var exact := float(original * keep) / float(total)
		var whole := mini(floori(exact), original)
		result[stat_name] = whole
		remainders[stat_name] = exact - float(whole)
		assigned += whole
	while assigned < keep:
		var selected: StringName = &""
		var greatest_remainder := -1.0
		for stat_name: StringName in StatsComponent.STAT_NAMES:
			if int(result.get(stat_name, 0)) >= int(values.get(stat_name, 0)):
				continue
			var remainder := float(remainders.get(stat_name, -1.0))
			if remainder > greatest_remainder:
				greatest_remainder = remainder
				selected = stat_name
		if selected == &"":
			break
		result[selected] = int(result[selected]) + 1
		remainders[selected] = -1.0
		assigned += 1
	return result


func set_player_level(root: GameplayState, level: int) -> void:
	if not active:
		return
	var stats := root.player_stats
	if stats == null:
		return
	player_level_override = clampi(level, 1, MAX_DEBUG_PLAYER_LEVEL)
	var point_budget := _base_unassigned_stat_points
	for stat_name: StringName in StatsComponent.STAT_NAMES:
		point_budget += int(_base_debug_allocations.get(stat_name, 0))
	if player_level_override > original_player_level:
		for reached_level in range(original_player_level + 1, player_level_override + 1):
			point_budget += PlayerProfile.stat_points_for_level(reached_level)
	elif player_level_override < original_player_level:
		for removed_level in range(player_level_override + 1, original_player_level + 1):
			point_budget -= PlayerProfile.stat_points_for_level(removed_level)
	point_budget = maxi(point_budget, 0)
	var original_allocated := _allocation_total(_base_debug_allocations)
	var allowed_allocated := mini(original_allocated, point_budget)
	var current_allocation := _base_debug_allocations.duplicate()
	if allowed_allocated < original_allocated:
		current_allocation = _trim_allocation_evenly(_base_debug_allocations, allowed_allocated)
	debug_unassigned_stat_points = maxi(point_budget - allowed_allocated, 0)
	stats.level = player_level_override
	if stats.manual_allocation_enabled:
		stats.configure_manual_growth(
			stats.manual_base_vit, stats.manual_base_str, stats.manual_base_def, stats.manual_base_agi,
			int(current_allocation.get(&"VIT", 0)), int(current_allocation.get(&"STR", 0)),
			int(current_allocation.get(&"DEF", 0)), int(current_allocation.get(&"AGI", 0)),
			stats.manual_base_int, stats.manual_base_mnd,
			int(current_allocation.get(&"INT", 0)), int(current_allocation.get(&"MND", 0))
		)
	var room_controller := root.room_controller
	if room_controller != null:
		room_controller.player_level = player_level_override
	var health := root.player_health_component
	if health != null:
		health.set_maximum_health(float(root._player_max_health()), true)
		root.player_display_health = health.current_health
	root._update_player_health_ui()
	root._update_player_progression_ui()


func set_run_number(root: GameplayState, run_number: int) -> void:
	if not active:
		return
	selected_run_number = clampi(run_number, 1, 99)
	root.run_flow_controller.debug_run_number = selected_run_number


func reset_run(root: GameplayState) -> void:
	if not active:
		return
	if not reset_confirmation_armed:
		reset_confirmation_armed = true
		return
	reset_confirmation_armed = false
	root.run_flow_controller.debug_run_number = selected_run_number
	root._begin_new_run()
	root._update_room_number_indicator()


func change_run_number(direction: int) -> void:
	if active:
		selected_run_number = clampi(selected_run_number + direction, 1, 99)
		reset_confirmation_armed = false


func change_player_level(root: GameplayState, direction: int) -> void:
	if not active:
		return
	var current_level := player_level_override if player_level_override > 0 else original_player_level
	set_player_level(root, clampi(current_level + direction, 1, MAX_DEBUG_PLAYER_LEVEL))


func toggle(root: GameplayState, option: StringName) -> void:
	if not active:
		return
	match option:
		&"invulnerable":
			invulnerable = not invulnerable
			var health := root.player_health_component
			if health != null: health.debug_invulnerable = invulnerable
		&"unlimited_chroma":
			unlimited_chroma = not unlimited_chroma
			var chroma := root.player_chroma_component
			if chroma != null: chroma.debug_unlimited_chroma = unlimited_chroma
		&"pause_enemies": enemies_paused = not enemies_paused
		&"geometry_guides":
			var geometry := root.actor_geometry_debug_drawer
			if geometry != null: geometry.enabled = not geometry.enabled
