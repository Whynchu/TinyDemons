extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Hub Binding coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var profile := gameplay.get("player_profile") as PlayerProfile
	var chroma := gameplay.get("player_chroma_component") as Node
	var npc := gameplay.get("npc_controller") as NpcController
	var screen := gameplay.get("screen_state_controller") as Node
	_expect(profile != null and chroma != null and npc != null and screen != null, "Hub Binding owners are composed", failures)
	if profile != null and chroma != null and npc != null and screen != null:
		profile.has_started = true
		profile.completed_runs = 1
		profile.souls = PlayerProfile.ELEMENT_BIND_SOUL_COST
		profile.starter_soul_gift_claimed = true
		gameplay.set("starter_flame_attuned_this_run", true)
		chroma.call("attune_flame", &"fire")
		npc.show_dialogue(gameplay)
		_expect(not String(npc.full_message).contains("BIND"), "Cloaked Demon dialogue remains the normal Hub invitation", failures)
		npc.hide_dialogue(gameplay)
		gameplay.call("_open_hub_from_cloaked_demon")
		gameplay.call("_set_hub_page", 4)
		var binding_panel := screen.get("hub_binding_panel") as Panel
		var binding_action := screen.get("hub_binding_action_button") as Button
		var page_buttons := screen.get("hub_page_buttons") as Array[Button]
		_expect(bool(screen.get("hub_overlay").visible), "Demon interaction opens the Hub", failures)
		_expect(page_buttons.size() == 5, "Hub exposes a fifth Binding panel", failures)
		_expect(binding_panel != null and binding_panel.visible, "Binding panel is visible on the BIND tab", failures)
		_expect(binding_action != null and not binding_action.disabled, "eligible current element enables Binding", failures)
		if binding_action != null:
			binding_action.pressed.emit()
		_expect(profile.has_bound_element and profile.bound_element == &"fire", "Hub Binding commits the current element", failures)
		_expect(profile.souls == 0, "Hub Binding charges 50 Souls", failures)
		_expect(binding_action == null or binding_action.disabled, "bound element disables repeat Binding", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Hub Binding smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("HUB_BINDING_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
