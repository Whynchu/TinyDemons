extends SceneTree

const RUN_FLOW_SCRIPT = preload("res://scripts/run_flow_controller.gd")

class RewardRoomController extends RefCounted:
	var room_states: Dictionary = {}


class RewardRoot extends RefCounted:
	var current_dungeon_seed := 0
	var current_room_id: StringName = &""
	var player_profile: PlayerProfile = null
	var run_state: RunState = null
	var room_controller: RewardRoomController = null
	var regular_room_treasure := false
	var spawned_items: Array[ItemInstance] = []
	var played_sounds: Array[StringName] = []

	func _spawn_chest_item_drops(items: Array[ItemInstance]) -> void:
		spawned_items = items.duplicate()

	func _play_sound(sound_name: StringName, _volume_db := 0.0, _pitch_scale := 1.0) -> void:
		played_sounds.append(sound_name)

	func _loot_grade_bonus(_grade: String = "") -> float:
		return 0.0


func _initialize() -> void:
	var failures: Array[String] = []
	var run_flow := RUN_FLOW_SCRIPT.new()
	var stub := RewardRoot.new()
	stub.player_profile = PlayerProfile.new()
	stub.player_profile.difficulty_rank = 1
	stub.room_controller = RewardRoomController.new()
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
	var granted_result: ChestRewardResult = null
	for seed_value in 64:
		stub.current_dungeon_seed = 8100 + seed_value
		stub.current_room_id = StringName("typed_treasure_%d" % seed_value)
		stub.run_state = RunState.new()
		stub.run_state.begin(stub.current_dungeon_seed, 0, 100.0)
		stub.spawned_items.clear()
		var result := run_flow.claim_chest_item_reward(stub)
		_expect(result != null and result.is_resolved(), "typed chest reward always resolves its deterministic decision", failures)
		if result != null and result.granted_items():
			granted_result = result
			break
	_expect(granted_result != null, "typed chest reward reports a generated item in the characterization sample", failures)
	if granted_result != null:
		_expect(granted_result.items.size() == stub.spawned_items.size(), "typed result matches spawned chest items", failures)
		stub.player_profile.grant_item(granted_result.items[0])
		var duplicate := run_flow.claim_chest_item_reward(stub)
		_expect(duplicate.status == ChestRewardResult.Status.ALREADY_RESOLVED, "typed chest reward remains idempotent after generation", failures)
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
