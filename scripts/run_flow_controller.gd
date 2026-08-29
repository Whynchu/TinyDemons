extends Node
class_name RunFlowController

const RunGradeEvaluator = preload("res://scripts/run_grade.gd")
const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")


func loot_grade_bonus(root: Object, grade: String = "") -> float:
	var value: String = grade.to_upper() if not grade.is_empty() else (root.player_profile.last_run_grade if root.player_profile != null else "D")
	return 3.0 if value == "S" else 2.0 if value == "A" else 1.0 if value == "B" else 0.5 if value == "C" else -0.5 if value == "F" else 0.0


func chest_item_drop_chance(root: Object) -> float:
	var exploration_bonus: float = minf(float(root.run_state.chests_opened) * 0.025, 0.20) if root.run_state != null else 0.0
	return clampf(0.34 + exploration_bonus + float(run_rank(root) - 1) * 0.035 + loot_grade_bonus(root) * 0.025, 0.30, 0.88)


func chest_item_drop_count(root: Object, roll: float) -> int:
	# Treasure rooms are less frequent now, so a successful gear reward can
	# occasionally pay out as a two-item burst. Keep the second item uncommon
	# enough that a chest still has a readable primary reward.
	var double_drop_chance := clampf(0.35 + float(run_rank(root) - 1) * 0.06 + loot_grade_bonus(root) * 0.04, 0.25, 0.75)
	return 2 if roll < double_drop_chance else 1


func chest_gold_reward(root: Object, base_gold: int) -> int:
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = int(root.current_dungeon_seed) ^ String(root.current_room_id).hash() ^ 0x474F4C44
	var rolled_gold: int = reward_rng.randi_range(roundi(base_gold * 0.75), roundi(base_gold * 1.30))
	var multiplier: float = 1.0 + float(run_rank(root) - 1) * 0.06 + loot_grade_bonus(root) * 0.04
	return maxi(1, roundi(float(rolled_gold) * clampf(multiplier, 0.80, 1.90)))


func sync_current_room_metadata(root: Object) -> void:
	var room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(root.current_room_id)
	if room != null:
		root.current_room_depth = room.depth
		root.current_room_display_number = room.display_number
		root.current_room_type = room.room_type
		if root.current_room_depth >= 1 and root.run_state != null and root.run_state.active:
			root.run_state.start_timer()
			root.run_state.record_room_visited(root.current_room_id)


func finalize_run_exploration(root: Object) -> void:
	if root.run_state == null or root.dungeon_graph == null: return
	var explorable_rooms: int = 0
	for room_id in root.dungeon_graph.get_room_ids():
		var room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(room_id)
		if room != null and room.depth >= 1: explorable_rooms += 1
	root.run_state.set_explorable_room_count(explorable_rooms)


func finalize_run_enemy_total(root: Object) -> void:
	if root.run_state == null or root.dungeon_graph == null or root.room_controller == null: return
	var total_enemies: int = 0
	for room_id in root.dungeon_graph.get_room_ids():
		var room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(room_id)
		total_enemies += root.room_controller.enemy_count_for_room(room)
	root.run_state.set_total_enemies(total_enemies)


func run_difficulty_bonus(root: Object) -> int:
	if root.player_profile == null:
		return 0
	# Difficulty rank also records performance-based progression. Only the part
	# that is ahead of the completed-run baseline should affect enemy levels;
	# otherwise a high Run 1 grade makes the opening of Run 2 jump too sharply.
	var completed_run_baseline: int = root.player_profile.completed_runs + 1
	return clampi(root.player_profile.difficulty_rank - completed_run_baseline, 0, 12)


func run_rank(root: Object) -> int:
	return maxi(root.player_profile.difficulty_rank if root.player_profile != null else 1, 1)


func apply_run_rank_grade(root: Object, grade: String) -> void:
	ProgressionController.apply_run_grade(root.player_profile, grade)


func begin_new_run(root: Object) -> void:
	# Every run begins at the hub in Gray. The selected starter flame is present
	# at the fire, but the hub exits stay a real gate until the player attunes to
	# it, just like the first run's tutorial gate.
	root.starter_flame_attuned_this_run = false
	_reset_dungeon_for_new_run(root)
	root.call("_reset_magic_runtime", true)
	var momentum := root.call("_combat_momentum") as CombatMomentumComponent
	if momentum != null:
		momentum.reset_all()
	if root.player_chroma_component != null:
		root.player_chroma_component.call("begin_new_run")
	root.call("_sync_current_element_state")
	var starter_palette: String = "red"
	if root.player_profile != null:
		starter_palette = root.player_profile.hub_palette()
	root.run_start_palette_name = starter_palette
	# The initial room may have been laid out before new-file selection was
	# confirmed. Reassign the hub flame here so its visual and interaction target
	# always match the persisted starter flame for this run.
	if root.current_room_type == DungeonGraph.ROOM_START and root.rest_fire != null:
		root.call("_apply_rest_fire_palette", starter_palette)
	# The selected flame is present in the hub, but every run opens Gray at zero.
	root.screen_state_controller.player_palette_name = "grey"
	root.current_player_palette_name = "grey"
	root.call("_apply_player_palette_async", "grey")
	root.call("_update_player_mp_ui")
	# The first room is the starter-flame lesson on every run. The player must
	# attune before the hub exit becomes usable, but this gate is opened
	# permanently after touch.
	if root.current_room_type == DungeonGraph.ROOM_START and not root.starter_flame_attuned_this_run:
		root.call("_set_door_active", false)
		root.call("_set_entrance_open", false)
	if root.run_state != null:
		root.run_state.begin(root.current_dungeon_seed, run_difficulty_bonus(root), float(root.call("_player_max_health")))


func _reset_dungeon_for_new_run(root: Object) -> void:
	var map_controller := root.get("dungeon_map_controller") as Node
	var graph := root.get("dungeon_graph") as DungeonGraph
	var room_controller := root.get("room_controller") as RoomController
	if map_controller == null or graph == null or room_controller == null:
		return
	var new_seed: int = (root.get("rng") as RandomNumberGenerator).randi()
	root.set("current_dungeon_seed", new_seed)
	var start_starter_flame: StringName = root.player_profile.starter_flame if root.player_profile != null else &"fire"
	var start_bound_flame: StringName = root.player_profile.bound_element if root.player_profile != null and root.player_profile.has_bound_element else &""
	var start_room_id: StringName = StringName(map_controller.call("begin_run", graph, new_seed, root.player_profile.completed_runs if root.player_profile != null else 0, start_starter_flame, start_bound_flame))
	room_controller.room_states.clear()
	var next_room_id := start_room_id
	if bool(root.get("debug_start_in_boss_room")):
		for candidate_id in graph.get_room_ids():
			var candidate := graph.get_room(candidate_id)
			if candidate != null and candidate.room_type == DungeonGraph.ROOM_BOSS:
				next_room_id = candidate.id
				break
		if next_room_id == start_room_id and not bool(map_controller.call("has_complete_layout")):
			var boss_connection := graph.ensure_connection(start_room_id, DungeonGraph.WALL_RIGHT, DungeonGraph.ROOM_DOWNSTAIRS)
			if boss_connection != null:
				next_room_id = boss_connection.destination_room_id
	root.set("current_room_id", next_room_id)
	root.call("_sync_current_room_metadata")
	room_controller.set_current_room(next_room_id, root.get("current_room_type"))
	root.call("_ensure_current_room_layout")
	root.call("_apply_room_state")
	var minimap := root.get("dungeon_minimap_controller") as Node
	if minimap != null:
		minimap.call("configure", map_controller)


func return_to_hub(root: Object) -> void:
	root.call("_settle_current_run", &"defeat" if root.player_dead else &"return_to_hub")
	if root.player_profile != null:
		root.player_profile.open_hub_on_load = false
		root.player_profile.pending_route = "run"
		root.call("_save_player_profile")
	root.call("_begin_scene_transition")


func settle_current_run(root: Object, result: StringName) -> bool:
	if not RunSettlement.can_settle(root.run_state, result):
		return false
	root.call("_sync_runtime_progression_to_profile")
	return RunSettlement.settle(root.player_profile, root.run_state, result)


func tick_run_telemetry(root: Object, delta: float) -> void:
	if root.run_state == null or not root.run_state.active:
		return
	root.run_state.tick(delta)
	if is_run_combat_active(root):
		root.run_state.record_combat_time(delta, root.player_is_moving)
	if root.player_is_moving:
		root.run_state.record_movement(delta)


func is_run_combat_active(root: Object) -> bool:
	return root.run_state != null and root.run_state.active and bool(root.call("_is_any_slime_aggroed"))


func on_player_successful_block(root: Object, _shield_damage: float, _health_damage: float) -> void:
	if root.run_state != null and is_run_combat_active(root):
		root.run_state.record_block()
	root.call("_play_sound", "block", -8.0, 0.95 + root.rng.randf_range(-0.08, 0.08))


func record_run_action_input(root: Object, action: StringName, accepted: bool) -> void:
	if root.run_state != null and root.run_state.active:
		root.run_state.record_action_input(action, accepted)


func clear_reward_rarity(root: Object, score: int, roll: float) -> StringName:
	return roll_run_loot_rarity(root, roll, clampf(float(score) / 100.0, 0.0, 1.0))


func roll_run_loot_rarity(root: Object, roll: float, score_quality: float = -1.0) -> StringName:
	var performance_bonus: float = score_quality * 3.0 if score_quality >= 0.0 else float(root.call("_loot_grade_bonus"))
	return ItemCatalog.new().roll_run_rarity(roll, run_rank(root), performance_bonus)


func complete_run(root: Object) -> void:
	if root.run_state == null or root.run_state.settled or root.screen_state_controller.run_complete_overlay == null or root.screen_state_controller.run_complete_overlay.visible:
		return
	root.call("_finalize_run_exploration")
	root.call("_finalize_run_enemy_total")
	var grade: Dictionary = RunGradeEvaluator.evaluate(root.run_state, root.run_state.starting_health)
	var score: int = int(grade["score"])
	apply_run_rank_grade(root, str(grade["grade"]))
	var gold_reward: int = 45 + score * 3 + int(grade["variety_count"]) * 8
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = root.current_dungeon_seed ^ root.run_state.run_id.hash() ^ score * 7919
	var dropped_item: ItemInstance = null
	if reward_rng.randf() < clampf(0.30 + float(score) * 0.0065, 0.30, 0.95):
		var catalog := ItemCatalog.new()
		var slot: StringName = ItemCatalog.SLOTS[reward_rng.randi_range(0, ItemCatalog.SLOTS.size() - 1)]
		var rarity := clear_reward_rarity(root, score, reward_rng.randf())
		dropped_item = catalog.generate_item(slot, reward_rng.randi(), root.player_profile.level, rarity)
		dropped_item.instance_id = root.player_profile.create_item_id("clear")
		root.player_profile.grant_item(dropped_item)
	if root.player_profile != null:
		root.player_profile.gold += gold_reward
		root.player_profile.completed_runs += 1
		root.player_profile.last_clear_score = score
	root.call("_update_gold_indicator")
	var drop_label: String = "NO GEAR DROP"
	var drop_color := Color8(150, 156, 170)
	if dropped_item != null:
		var reward_catalog := ItemCatalog.new()
		drop_label = reward_catalog.display_name(dropped_item)
		drop_color = reward_catalog.rarity_color(dropped_item.rarity)
	root.run_state.clear_summary = {"score": score, "grade": str(grade["grade"]), "gold": gold_reward, "drop": drop_label, "difficulty": run_difficulty_bonus(root), "run_rank": run_rank(root), "time": root.run_state.elapsed_time, "damage": root.run_state.damage_taken, "variety": int(grade["variety_count"]), "variety_max": int(grade["variety_max"]), "kills": root.run_state.enemies_killed, "total_enemies": root.run_state.total_enemies, "blocks": root.run_state.block_count, "attacks": root.run_state.attack_count, "attack_hits": root.run_state.attack_swing_hit_count, "accuracy": float(grade["accuracy"]), "wasted_inputs": root.run_state.total_wasted_inputs(), "explored_rooms": int(grade["explored_rooms"]), "explorable_rooms": int(grade["explorable_rooms"]), "dodges": root.run_state.dodge_count, "time_quality": float(grade["time_score"]) / 28.0, "survival_quality": float(grade["survival_score"]) / 25.0, "control_quality": float(grade["control_score"]) / 2.0}
	root.call("_sync_runtime_progression_to_profile")
	settle_current_run(root, &"complete")
	root.call("_play_sound", "run_clear", -6.0, 1.0)
	show_run_complete(root, drop_color)


func show_run_complete(root: Object, drop_color: Color) -> void:
	if root.screen_state_controller.run_complete_overlay == null or root.run_state == null:
		return
	# The player can reach the final exit while still holding the same input used
	# to move through the room. Require a release before the completion action is
	# allowed, otherwise the result screen is accepted and skipped next frame.
	root.screen_state_controller.menu_input_release_lock = true
	var summary: Dictionary = root.run_state.clear_summary
	var elapsed: int = int(round(float(summary.get("time", 0.0))))
	var kills: int = int(summary.get("kills", 0))
	var total_enemies: int = maxi(int(summary.get("total_enemies", 0)), kills)
	var exploration_quality: float = float(summary.get("explored_rooms", 0)) / float(maxi(int(summary.get("explorable_rooms", 0)), 1))
	var kill_quality: float = float(kills) / float(maxi(total_enemies, 1))
	var accuracy_quality: float = float(summary.get("accuracy", 0.0))
	var style_quality: float = float(summary.get("variety", 0)) / float(maxi(int(summary.get("variety_max", 0)), 1))
	var lines: Array[String] = ["GRADE %s    SCORE %03d" % [str(summary.get("grade", "D")), int(summary.get("score", 0))], "TIME %02d:%02d  DMG %d" % [floori(float(elapsed) / 60.0), elapsed % 60, roundi(float(summary.get("damage", 0.0)))], "EXPLORE %d/%d" % [int(summary.get("explored_rooms", 0)), int(summary.get("explorable_rooms", 0))], "KILLS %d/%d  BLOCKS %d  DODGES %d" % [kills, total_enemies, int(summary.get("blocks", 0)), int(summary.get("dodges", 0))], "ATTACKS %d  HITS %d" % [int(summary.get("attacks", 0)), int(summary.get("attack_hits", 0))], "ACCURACY %d%%" % roundi(accuracy_quality * 100.0), "MISINPUTS %d" % int(summary.get("wasted_inputs", 0)), "STYLE %d/%d" % [int(summary.get("variety", 0)), int(summary.get("variety_max", 3))], "SPOILS", "+%d GOLD" % int(summary.get("gold", 0)), str(summary.get("drop", "NO GEAR DROP"))]
	var line_colors: Array[Color] = [Color8(255, 205, 117), metric_color((float(summary.get("time_quality", 0.0)) + float(summary.get("survival_quality", 0.0))) * 0.5), metric_color(exploration_quality), metric_color(kill_quality), metric_color(accuracy_quality), metric_color(accuracy_quality), metric_color(float(summary.get("control_quality", 0.0))), metric_color(style_quality), Color8(255, 205, 117), Color8(255, 205, 117), drop_color]
	for index in mini(root.screen_state_controller.run_complete_texts.size(), lines.size()):
		root.screen_state_controller.run_complete_texts[index].texture = root.call("_pixel_text_texture", lines[index], line_colors[index])
	root.screen_state_controller.run_complete_overlay.visible = true
	root.screen_state_controller.set_state(&"run_complete")


func metric_color(quality: float) -> Color:
	var value := clampf(quality, 0.0, 1.0)
	if value >= 0.95: return Color8(177, 62, 83)
	if value >= 0.85: return Color8(255, 205, 117)
	if value >= 0.70: return Color8(118, 66, 138)
	if value >= 0.50: return Color8(65, 166, 246)
	return Color.WHITE


func return_from_run_complete(root: Object) -> void:
	if root.screen_state_controller.run_complete_overlay != null:
		root.screen_state_controller.run_complete_overlay.visible = false
	if root.player_profile != null:
		root.player_profile.open_hub_on_load = false
		root.player_profile.pending_route = "run"
		root.call("_save_player_profile")
	root.call("_begin_scene_transition")
