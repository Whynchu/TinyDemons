extends SceneTree

const RUN_FLOW_SCRIPT = preload("res://scripts/run_flow_controller.gd")

class RewardRoot extends RefCounted:
	var current_dungeon_seed := 0
	var current_room_id: StringName = &""
	var player_profile: PlayerProfile = null


func _initialize() -> void:
	var failures: Array[String] = []
	var run_flow := RUN_FLOW_SCRIPT.new()
	var stub := RewardRoot.new()
	stub.player_profile = PlayerProfile.new()
	stub.player_profile.difficulty_rank = 1
	var total := 0
	var minimum := 999999
	var maximum := 0
	for seed_value in 12:
		stub.current_dungeon_seed = 7000 + seed_value
		stub.current_room_id = StringName("treasure_%d" % seed_value)
		var reward := run_flow.chest_gold_reward(stub, 100)
		total += reward
		minimum = mini(minimum, reward)
		maximum = maxi(maximum, reward)
	_expect(minimum >= 75 and maximum <= 130, "chest gold stays inside the new reward band", failures)
	_expect(float(total) / 12.0 >= 90.0, "chest gold average is materially above the old 75G base", failures)
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CHEST_REWARD_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
