extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var bootstrap_probe := GameplayBootstrap.new()
	var diagnostics_were_enabled := GameplayBootstrap.boot_diagnostics_enabled
	GameplayBootstrap.boot_diagnostics_enabled = false
	var remaining_boot_phase_labels: Array[StringName] = [
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.MUSIC_PRELOAD),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.PREWARM_TRANSITION_ASSETS),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.BUILD_SLIME_TEXTURES),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.INITIALIZE_PLAYER),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.INITIALIZE_WALKABLE_AREA),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.INITIALIZE_SLIMES),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.ROOM_STATE_AND_ROUTE),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.PLAYER_EQUIPMENT_VISUAL),
		GameplayBootstrap.BuildStep.diagnostic_label_for(GameplayBootstrap.BuildStep.Phase.PLAYER_AFTER_EQUIPMENT),
	]
	_expect(remaining_boot_phase_labels == [&"music_preload", &"prewarm_transition_assets", &"build_slime_textures", &"initialize_player", &"initialize_walkable_area", &"initialize_slimes", &"room_state_and_route", &"initialize_player_equipment_visual", &"initialize_player_after_equipment"], "remaining boot phase enums preserve their diagnostic keys", failures)
	var executed_step_names: Array[StringName] = []
	var step_fixture: Array[GameplayBootstrap.BuildStep] = []
	step_fixture.append(GameplayBootstrap.BuildStep.new(&"first", GameplayBootstrap.BuildStep.Phase.LOADING_SCREEN, func() -> void:
		executed_step_names.append(&"first")
	))
	step_fixture.append(GameplayBootstrap.BuildStep.new(&"second", GameplayBootstrap.BuildStep.Phase.TITLE_SCREEN, func() -> void:
		executed_step_names.append(&"second")
	))
	await bootstrap_probe._run_build_steps(get_root(), step_fixture)
	_expect(executed_step_names == [&"first", &"second"], "named build steps execute in their declared order", failures)
	GameplayBootstrap.boot_diagnostics_enabled = diagnostics_were_enabled
	var row_test_parent := Node.new()
	var early_service_rows := RuntimeServiceRegistrationPlan.early_service_registrations(row_test_parent)
	_expect(RuntimeServiceRegistrationPlan.registration_errors(early_service_rows).is_empty(), "valid early service registration rows are accepted", failures)
	var forward_service_rows := early_service_rows.duplicate()
	forward_service_rows.reverse()
	_expect(not RuntimeServiceRegistrationPlan.registration_errors(forward_service_rows).is_empty(), "forward service dependency is rejected", failures)
	var missing_service_rows := early_service_rows.duplicate()
	for index in range(missing_service_rows.size() - 1, -1, -1):
		if missing_service_rows[index].node_name == &"InputRouter":
			missing_service_rows.remove_at(index)
	_expect(not RuntimeServiceRegistrationPlan.registration_errors(missing_service_rows).is_empty(), "missing service dependency is rejected", failures)
	var duplicate_service_rows := early_service_rows.duplicate()
	duplicate_service_rows.append(early_service_rows[0])
	_expect(not RuntimeServiceRegistrationPlan.registration_errors(duplicate_service_rows).is_empty(), "duplicate service registration is rejected", failures)
	row_test_parent.free()
	var generic_registration_parent := Node.new()
	var generic_registration_rows := RuntimeServiceRegistrationPlan.early_service_registrations(generic_registration_parent)
	generic_registration_rows.append(RuntimeServiceRegistrationPlan.Row.new(
		&"RegistrationProbe",
		generic_registration_rows[0].service_script,
		generic_registration_parent,
		[&"TouchControlsLayer"]
	))
	var generic_registration_errors := RuntimeServiceRegistrationPlan.register_all(generic_registration_rows)
	_expect(generic_registration_errors.is_empty(), "generic registrar accepts an appended no-setup production service row", failures)
	_expect(generic_registration_parent.get_node_or_null("RegistrationProbe") != null, "generic registrar creates the appended no-setup node", failures)
	generic_registration_parent.free()
	var wrong_script_parent := Node.new()
	var wrong_script_rows := RuntimeServiceRegistrationPlan.early_service_registrations(wrong_script_parent)
	_add_registration_fixture(wrong_script_rows, &"DisplayController")
	_expect(not RuntimeServiceRegistrationPlan.live_registration_errors(wrong_script_rows).is_empty(), "unexpected live service script is rejected", failures)
	wrong_script_parent.free()
	var wrong_parent := Node.new()
	var wrong_parent_rows := RuntimeServiceRegistrationPlan.early_service_registrations(wrong_parent)
	_add_registration_fixture(wrong_parent_rows, &"", &"DisplayController")
	_expect(not RuntimeServiceRegistrationPlan.live_registration_errors(wrong_parent_rows).is_empty(), "unexpected live service parent is rejected", failures)
	wrong_parent.free()
	var wrong_order_parent := Node.new()
	var wrong_order_rows := RuntimeServiceRegistrationPlan.early_service_registrations(wrong_order_parent)
	_add_registration_fixture(wrong_order_rows)
	var settings_node := wrong_order_parent.get_node("SettingsService")
	var display_node := wrong_order_parent.get_node("DisplayController")
	wrong_order_parent.move_child(settings_node, display_node.get_index() + 1)
	_expect(not RuntimeServiceRegistrationPlan.live_registration_errors(wrong_order_rows).is_empty(), "live prerequisite order is enforced", failures)
	wrong_order_parent.free()
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for title boot characterization", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 120:
		await process_frame
	var live_service_rows := RuntimeServiceRegistrationPlan.early_service_registrations(gameplay)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(live_service_rows).is_empty(), "live early service nodes match their registration rows", failures)
	var live_gameplay_service_rows := RuntimeServiceRegistrationPlan.gameplay_service_registrations(gameplay as GameplayState)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(live_gameplay_service_rows).is_empty(), "live gameplay service nodes match their registration rows", failures)
	var production_extension_rows: Array[RuntimeServiceRegistrationPlan.Row] = live_gameplay_service_rows.duplicate()
	var production_extension_row := RuntimeServiceRegistrationPlan.Row.new(
		&"ProductionExtensionProbe",
		generic_registration_rows[0].service_script,
		gameplay,
		[&"ProfileRuntimeController"]
	)
	production_extension_rows.append(production_extension_row)
	_expect(RuntimeServiceRegistrationPlan.registration_errors(production_extension_rows).is_empty(), "a single appended production row resolves its existing prerequisite", failures)
	var missing_production_dependency: Array[RuntimeServiceRegistrationPlan.Row] = production_extension_rows.duplicate()
	for index in range(missing_production_dependency.size() - 1, -1, -1):
		if missing_production_dependency[index].node_name == &"ProfileRuntimeController":
			missing_production_dependency.remove_at(index)
	_expect(not RuntimeServiceRegistrationPlan.registration_errors(missing_production_dependency).is_empty(), "a production-row extension rejects a missing prerequisite", failures)
	var production_extension_node := production_extension_row.service_script.new() as Node
	production_extension_node.name = production_extension_row.node_name
	gameplay.add_child(production_extension_node)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(production_extension_rows).is_empty(), "one appended production row validates against the live cohort and dependency order", failures)
	production_extension_node.queue_free()
	await process_frame
	var live_world_service_rows := RuntimeServiceRegistrationPlan.world_service_registrations(gameplay as GameplayState)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(live_world_service_rows).is_empty(), "live world support nodes match their registration rows", failures)
	var live_actor_service_rows := RuntimeServiceRegistrationPlan.actor_service_registrations(gameplay as GameplayState)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(live_actor_service_rows).is_empty(), "live actor service nodes match their registration rows", failures)
	var live_ui_service_rows := RuntimeServiceRegistrationPlan.gameplay_ui_service_registrations(gameplay as GameplayState)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(live_ui_service_rows).is_empty(), "live gameplay UI service nodes match their registration rows", failures)
	var live_screen_state_rows := RuntimeServiceRegistrationPlan.screen_state_service_registrations(gameplay as GameplayState)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(live_screen_state_rows).is_empty(), "live screen state service nodes match their registration rows", failures)
	var live_gameplay_frame_rows := RuntimeServiceRegistrationPlan.gameplay_frame_service_registrations(gameplay as GameplayState)
	_expect(RuntimeServiceRegistrationPlan.live_registration_errors(live_gameplay_frame_rows).is_empty(), "live gameplay frame service nodes match their registration rows", failures)
	var live_gameplay_state := gameplay as GameplayState
	var room_prefab_host := live_gameplay_state.map_root.get_node_or_null("RoomPrefabHost") as RoomPrefabHost if live_gameplay_state != null else null
	_expect(room_prefab_host != null, "room prefab host registers under the map root", failures)
	if live_gameplay_state != null and room_prefab_host != null and live_gameplay_state.hub_stone_accent_layer != null:
		_expect(room_prefab_host.get_index() < live_gameplay_state.hub_stone_accent_layer.get_index(), "room prefab host retains its position ahead of the stone accent layer", failures)
	_expect(live_gameplay_state != null and live_gameplay_state.room_controller != null, "room controller is configured through the world service cohort", failures)
	_expect(live_gameplay_state != null and live_gameplay_state.chest_controller != null and live_gameplay_state.chest_controller.reward_controller == live_gameplay_state.run_flow_controller, "chest reward boundary retains its registered run service", failures)
	_expect(live_gameplay_state != null and live_gameplay_state.hud_controller.feedback_animation_registry == live_gameplay_state.feedback_animation_registry, "HUD uses the registered feedback animation registry", failures)
	_expect(live_gameplay_state != null and live_gameplay_state.effects_spawner.item_delivery_hud == live_gameplay_state.hud_controller and live_gameplay_state.effects_spawner.item_delivery_minimap == live_gameplay_state.dungeon_minimap_controller, "pickup effects retain the configured HUD and minimap services", failures)
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var frame_controller := gameplay.get("gameplay_frame_controller") as GameplayFrameController
	var settings := gameplay.get("settings_service") as SettingsService
	var display := gameplay.get("display_controller") as DisplayController
	var router := gameplay.get("input_router") as InputRouter
	var tracker := gameplay.get("input_device_tracker") as InputDeviceTracker
	var touch := gameplay.get("touch_controls_layer") as TouchControlsLayer
	var debug_session := gameplay.get_node_or_null("DebugSessionController") as DebugSessionController
	_expect(settings != null and settings.get_parent() == gameplay, "settings service is registered on the gameplay root", failures)
	_expect(display != null and display.get_parent() == gameplay, "display controller is registered on the gameplay root", failures)
	_expect(router != null and router.get_parent() == gameplay, "input router is registered on the gameplay root", failures)
	_expect(tracker != null and tracker.get_parent() == gameplay, "device tracker is registered on the gameplay root", failures)
	_expect(touch != null and touch.get_parent() == gameplay, "touch controls are registered on the gameplay root", failures)
	_expect(debug_session != null and debug_session.get_parent() == gameplay, "debug session controller is registered on the gameplay root", failures)
	if settings != null and display != null and router != null and tracker != null and touch != null:
		_expect(display.settings_service == settings, "display setup binds the registered settings service", failures)
		_expect(touch.get_node_or_null("TouchControlsRoot") != null, "touch setup builds controls before input binding", failures)
		_expect(router.touch_provider == touch, "input router binds the touch layer after construction", failures)
		_expect(tracker.device_changed.is_connected(Callable(touch, "set_last_input_device")), "device changes are wired to touch prompts", failures)
		_expect(router.context == InputRouter.Context.MENU, "touch controls start in menu input context", failures)
	_expect(screens != null, "screen state owner is composed during boot", failures)
	_expect(frame_controller != null and frame_controller.get_parent() == gameplay, "frame controller is registered after profile application", failures)
	if screens != null and frame_controller != null:
		_expect(screens.get_index() < frame_controller.get_index(), "screen state attaches before the gameplay frame controller", failures)
	if screens != null:
		var gameplay_state := gameplay as GameplayState
		var background: CanvasItem = gameplay_state.background_environment if gameplay_state != null else null
		var map: CanvasItem = gameplay_state.map_root if gameplay_state != null else null
		var actors := gameplay.get_node_or_null("Actors") as CanvasItem
		_expect(background != null and map != null and actors != null, "menu visibility contract has all three world layers", failures)
		if background != null and map != null and actors != null:
			var background_was_visible := background.visible
			var map_was_visible := map.visible
			var actors_were_visible := actors.visible
			screens.set_menu_world_hidden(gameplay, true)
			_expect(not background.visible and not map.visible and not actors.visible, "full-screen menu hides background, map, and actors", failures)
			screens.set_menu_world_hidden(gameplay, true)
			screens.set_menu_world_hidden(gameplay, false)
			_expect(background.visible == background_was_visible and map.visible == map_was_visible and actors.visible == actors_were_visible, "menu visibility restores each layer's captured state after repeated hide", failures)
			screens.set_menu_world_hidden(gameplay, false)
		_expect(screens.title_presenter.overlay != null, "title overlay is built during boot", failures)
		_expect(screens.title_presenter.overlay != null and screens.title_presenter.overlay.visible, "title overlay is visible after boot", failures)
		var ui := gameplay.get("ui") as Node
		var player_hud := ui.get_node_or_null("PlayerHud") as CanvasItem if ui != null else null
		_expect(player_hud != null and not player_hud.visible, "player HUD stays hidden while the title screen is active", failures)
		_expect(screens.title_presenter.cloud_button != null, "title screen exposes the Cloud Save button", failures)
		if screens.title_presenter.cloud_button != null:
			screens.title_presenter.cloud_button.pressed.emit()
			var cloud_panel := gameplay.get("cloud_save_panel") as CloudSavePanel
			_expect(cloud_panel != null and cloud_panel.overlay != null and cloud_panel.overlay.visible, "Cloud Save button opens the management window", failures)
			_expect(cloud_panel != null and cloud_panel.service == gameplay.get("cloud_save_service"), "Cloud Save panel is configured by its registered prerequisite", failures)
			if cloud_panel != null: cloud_panel.close()
		var version := screens.title_presenter.overlay.get_node_or_null("TitleVersion") as Sprite2D
		_expect(version != null and version.texture != null and version.position.is_equal_approx(Vector2(4, screens.display_view_size.y - 8.0)), "title screen shows the game version in the bottom-left", failures)
		screens.refresh_title_menu_layout(false)
		_expect(not screens.title_presenter.continue_button.visible, "fresh title hides Continue instead of leaving an empty row", failures)
		_expect(is_equal_approx(screens.title_presenter.cloud_button.position.y, 109.0) and is_equal_approx(screens.title_presenter.settings_button.position.y, 125.0), "fresh title compacts visible menu cards", failures)
		screens.refresh_title_menu_layout(true)
		_expect(screens.title_presenter.continue_button.visible and not screens.title_presenter.continue_button.disabled, "restored profile reveals Continue immediately", failures)
		_expect(is_equal_approx(screens.title_presenter.continue_button.position.y, 109.0) and is_equal_approx(screens.title_presenter.settings_button.position.y, 141.0), "profile title lays out all visible cards without gaps", failures)
		screens.menu_input_release_lock = false
		gameplay.call("_continue_game")
		await create_timer(1.5).timeout
		_expect(not screens.title_presenter.transition_active, "Continue transition completes without blocking the title loop", failures)
		_expect(screens.save_select_presenter.overlay != null and screens.save_select_presenter.overlay.visible, "Continue opens the save-slot screen after its transition", failures)
		_expect(screens.state == &"title", "screen state settles on title after boot", failures)
	_expect(not bool(gameplay.get("boot_active")), "boot sequence completes", failures)
	var loading := gameplay.get("loading_screen_overlay") as CanvasItem
	_expect(loading == null or not loading.visible, "loading cover releases after title boot", failures)
	var loading_build_steps := bootstrap_probe._loading_screen_build_steps(live_gameplay_state)
	_expect(loading_build_steps.size() == 1 and loading_build_steps[0].name == &"loading_screen" and loading_build_steps[0].diagnostic_label() == &"build_loading_screen", "loading screen has a named step with its original diagnostic phase", failures)
	var title_build_steps := bootstrap_probe._title_only_build_steps(live_gameplay_state, loading)
	var title_step_names: Array[StringName] = []
	var title_phase_labels: Array[StringName] = []
	for step in title_build_steps:
		title_step_names.append(step.name)
		title_phase_labels.append(step.diagnostic_label())
	_expect(title_step_names == [&"player_animation", &"title_screen", &"cloud_panel", &"settings", &"scene_transition_and_layout", &"title_state", &"finalize"], "title-only build operations are explicitly ordered", failures)
	_expect(title_phase_labels == [&"build_player_animation", &"build_ui_title", &"build_ui_cloud_panel", &"build_ui_settings", &"build_ui_scene_transition_and_layout", &"set_title_state", &"finalize"], "title-only steps retain every existing diagnostic phase key", failures)
	var gameplay_visual_steps := bootstrap_probe._gameplay_visual_build_steps(live_gameplay_state)
	_expect(gameplay_visual_steps.size() == 1 and gameplay_visual_steps[0].name == &"fire_and_demon" and gameplay_visual_steps[0].diagnostic_label() == &"build_fire_and_demon" and gameplay_visual_steps[0].yield_after_frame, "gameplay visual build is a named step with its frame boundary", failures)
	var gameplay_ui_steps := bootstrap_probe._gameplay_ui_build_steps(live_gameplay_state, PlayerProfile.new(), "")
	var gameplay_ui_step_names: Array[StringName] = []
	var gameplay_ui_phase_labels: Array[StringName] = []
	var gameplay_ui_frame_boundaries: Array[bool] = []
	for step in gameplay_ui_steps:
		gameplay_ui_step_names.append(step.name)
		gameplay_ui_phase_labels.append(step.diagnostic_label())
		gameplay_ui_frame_boundaries.append(step.yield_after_frame)
	_expect(gameplay_ui_step_names == [&"enemy_health_ui", &"interact_prompt", &"npc_dialogue", &"room_number", &"game_over_ui", &"run_complete_ui", &"title_screen", &"cloud_panel", &"settings", &"hub_ui", &"scene_transition_and_layout", &"refresh_player_cloak_visual", &"title_state"], "gameplay UI build operations are explicitly ordered", failures)
	_expect(gameplay_ui_phase_labels == [&"build_ui_enemy_health", &"build_ui_interact_prompt", &"build_ui_npc_dialogue", &"build_ui_room_number", &"build_ui_game_over", &"build_ui_run_complete", &"build_ui_title", &"build_ui_cloud_panel", &"build_ui_settings", &"build_ui_hub", &"build_ui_scene_transition_and_layout", &"refresh_player_cloak_visual", &"set_title_state"], "gameplay UI steps retain every existing diagnostic phase key", failures)
	_expect(gameplay_ui_frame_boundaries == [true, true, true, true, true, true, true, true, true, true, false, false, false], "gameplay UI steps preserve their original frame boundaries", failures)
	bootstrap_probe.free()
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TITLE_BOOT_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)

func _add_registration_fixture(
	registrations: Array[RuntimeServiceRegistrationPlan.Row],
	wrong_script_for: StringName = &"",
	wrong_parent_for: StringName = &""
) -> void:
	var unexpected_parent := Node.new()
	unexpected_parent.name = &"UnexpectedParent"
	registrations[0].parent.add_child(unexpected_parent)
	for registration in registrations:
		var script := registration.service_script
		var parent := registration.parent
		if registration.node_name == wrong_script_for:
			script = registrations[0].service_script
		if registration.node_name == wrong_parent_for:
			parent = unexpected_parent
		var node := script.new() as Node
		node.name = registration.node_name
		parent.add_child(node)
