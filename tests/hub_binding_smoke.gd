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
		var original_profile := profile.to_dictionary()
		profile.has_started = true
		profile.completed_runs = 1
		profile.souls = PlayerProfile.ELEMENT_BIND_SOUL_COST
		profile.starter_soul_gift_claimed = true
		profile.has_bound_element = false
		profile.bound_element = &""
		gameplay.set("starter_flame_attuned_this_run", true)
		chroma.call("clear_bound_aspect")
		chroma.call("attune_flame", &"fire")
		npc.show_dialogue(gameplay)
		_expect(not String(npc.full_message).contains("BIND"), "Cloaked Demon dialogue remains the normal Hub invitation", failures)
		npc.hide_dialogue(gameplay)
		gameplay.call("_open_hub_from_cloaked_demon")
		var pause_overlay := screen.get("pause_overlay") as ColorRect
		_expect(not bool(screen.get("hub_pause_mode")) and (pause_overlay == null or not pause_overlay.is_visible_in_tree()), "Cloaked Demon Hub does not retain the pause overlay underneath it", failures)
		gameplay.call("_set_hub_page", 4)
		var binding_panel := screen.get("hub_binding_panel") as Panel
		var binding_action := screen.get("hub_binding_action_button") as Button
		var page_buttons := screen.get("hub_page_buttons") as Array[Button]
		_expect(bool(screen.get("hub_overlay").visible), "Demon interaction opens the Hub", failures)
		_expect(page_buttons.size() == 6, "Hub exposes Status, Allocate, Equipment, Shop, Fusion, and Bind commands", failures)
		_expect(binding_panel != null and binding_panel.visible, "Binding panel is visible on the BIND tab", failures)
		_expect(binding_action != null and not binding_action.disabled, "eligible current element enables Binding", failures)
		if binding_action != null:
			binding_action.pressed.emit()
		_expect(profile.has_bound_element and profile.bound_element == &"fire", "Hub Binding commits the current element", failures)
		_expect(profile.souls == 0, "Hub Binding charges 50 Souls", failures)
		_expect(binding_action == null or binding_action.disabled, "bound element disables repeat Binding", failures)
		# Binding is intentionally tested against the live profile, so restore the
		# developer's save after the assertion instead of leaking test state into
		# later scene tests or a real local run.
		profile.load_dictionary(original_profile)
		ProfileSaveService.save_profile(profile)
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
