extends SceneTree

const HubFlowControllerScript = preload("res://scripts/hub_flow_controller.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var controller := HubFlowControllerScript.new()
	get_root().add_child(controller)
	var root := _MockRoot.new()
	root.screen_state_controller = _MockScreenState.new()
	root.player_profile = PlayerProfile.new()
	var catalog := ItemCatalog.new()
	var target := ItemInstance.new()
	target.instance_id = "cache-target"
	target.definition_id = &"basic_sword"
	target.rarity = &"common"
	root.player_profile.grant_item(target)
	root.player_profile.equipped_instance_ids["weapon"] = target.instance_id

	controller.refresh_hub_fusion_candidates(root)
	_expect(controller.hub_fusion_candidates(root).is_empty(), "fusion cache starts empty without a duplicate", failures)

	var material := ItemInstance.new()
	material.instance_id = "cache-material"
	material.definition_id = &"basic_sword"
	material.rarity = &"common"
	root.player_profile.grant_item(material)
	_expect(controller.hub_fusion_candidates(root).is_empty(), "cached result stays stable until invalidated", failures)

	controller.set_hub_page(root, 3)
	var candidates := controller.hub_fusion_candidates(root)
	_expect(candidates.size() == 1 and candidates[0].instance_id == target.instance_id, "entering FUSE refreshes a target made eligible by newly acquired gear", failures)
	_expect(root.screen_state_controller.hub_fusion_candidates_dirty == false, "refreshed fusion cache is clean", failures)
	_expect(root.player_profile.fusion_material_count(target.instance_id, catalog) == 1, "matching basic sword is usable as material", failures)

	controller.queue_free()
	_finished = true
	if failures.is_empty():
		print("FUSION_CANDIDATE_CACHE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: fusion candidate cache smoke failed before completion")
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)


class _MockScreenState:
	var hub_page := 0
	var hub_item_index := 0
	var hub_gear_browsing := false
	var hub_fusion_message := ""
	var hub_binding_message := ""
	var hub_fusion_count := 1
	var hub_fusion_candidates: Array[ItemInstance] = []
	var hub_fusion_candidates_dirty := true

	func update_hub_ui(_root: Object, _pixel_text: Callable) -> void:
		pass


class _MockRoot:
	var screen_state_controller: _MockScreenState
	var player_profile: PlayerProfile
	var run_state: RunState = null

	func _play_sound(_sound_name: String, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
		pass
