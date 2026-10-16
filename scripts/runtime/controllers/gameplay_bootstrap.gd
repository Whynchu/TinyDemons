extends Node
class_name GameplayBootstrap

class BuildStep extends RefCounted:
	enum Phase {
		LOADING_SCREEN,
		PLAYER_ANIMATION,
		TITLE_SCREEN,
		CLOUD_PANEL,
		SETTINGS,
		SCENE_TRANSITION_AND_LAYOUT,
		TITLE_STATE,
		FINALIZE,
		FIRE_AND_DEMON,
		ENEMY_HEALTH_UI,
		INTERACT_PROMPT,
		NPC_DIALOGUE,
		ROOM_NUMBER,
		GAME_OVER,
		RUN_COMPLETE,
		HUB_UI,
		REFRESH_PLAYER_CLOAK_VISUAL,
		MUSIC_PRELOAD,
		PREWARM_TRANSITION_ASSETS,
		BUILD_SLIME_TEXTURES,
		INITIALIZE_PLAYER,
		INITIALIZE_WALKABLE_AREA,
		INITIALIZE_SLIMES,
		ROOM_STATE_AND_ROUTE,
		PLAYER_EQUIPMENT_VISUAL,
		PLAYER_AFTER_EQUIPMENT,
	}

	var name: StringName
	var phase: Phase
	var action: Callable
	var yield_after_frame := false

	func _init(step_name: StringName, step_phase: Phase, step_action: Callable, step_yield_after_frame: bool = false) -> void:
		name = step_name
		phase = step_phase
		action = step_action
		yield_after_frame = step_yield_after_frame

	static func diagnostic_label_for(build_phase: Phase) -> StringName:
		match build_phase:
			Phase.LOADING_SCREEN: return &"build_loading_screen"
			Phase.PLAYER_ANIMATION: return &"build_player_animation"
			Phase.TITLE_SCREEN: return &"build_ui_title"
			Phase.CLOUD_PANEL: return &"build_ui_cloud_panel"
			Phase.SETTINGS: return &"build_ui_settings"
			Phase.SCENE_TRANSITION_AND_LAYOUT: return &"build_ui_scene_transition_and_layout"
			Phase.TITLE_STATE: return &"set_title_state"
			Phase.FINALIZE: return &"finalize"
			Phase.FIRE_AND_DEMON: return &"build_fire_and_demon"
			Phase.ENEMY_HEALTH_UI: return &"build_ui_enemy_health"
			Phase.INTERACT_PROMPT: return &"build_ui_interact_prompt"
			Phase.NPC_DIALOGUE: return &"build_ui_npc_dialogue"
			Phase.ROOM_NUMBER: return &"build_ui_room_number"
			Phase.GAME_OVER: return &"build_ui_game_over"
			Phase.RUN_COMPLETE: return &"build_ui_run_complete"
			Phase.HUB_UI: return &"build_ui_hub"
			Phase.REFRESH_PLAYER_CLOAK_VISUAL: return &"refresh_player_cloak_visual"
			Phase.MUSIC_PRELOAD: return &"music_preload"
			Phase.PREWARM_TRANSITION_ASSETS: return &"prewarm_transition_assets"
			Phase.BUILD_SLIME_TEXTURES: return &"build_slime_textures"
			Phase.INITIALIZE_PLAYER: return &"initialize_player"
			Phase.INITIALIZE_WALKABLE_AREA: return &"initialize_walkable_area"
			Phase.INITIALIZE_SLIMES: return &"initialize_slimes"
			Phase.ROOM_STATE_AND_ROUTE: return &"room_state_and_route"
			Phase.PLAYER_EQUIPMENT_VISUAL: return &"initialize_player_equipment_visual"
			Phase.PLAYER_AFTER_EQUIPMENT: return &"initialize_player_after_equipment"
		return &""

	func diagnostic_label() -> StringName:
		return diagnostic_label_for(phase)

const PLAYER_CHROMA_COMPONENT_SCRIPT = preload("res://scripts/components/player_chroma_component.gd")
const FEEDBACK_ANIMATION_REGISTRY_SCRIPT = preload("res://scripts/services/feedback_animation_registry.gd")
const PLAYER_ASPECT_ABILITY_COMPONENT_SCRIPT = preload("res://scripts/components/player_aspect_ability_component.gd")
const ENEMY_CATALOG_SCRIPT = preload("res://scripts/content/enemy_catalog.gd")
const ACTIVE_RUN_SAVE_SERVICE_SCRIPT = preload("res://scripts/runtime/services/active_run_save_service.gd")
const INPUT_DEVICE_TRACKER_SCRIPT = preload("res://scripts/services/input_device_tracker.gd")
const TOUCH_CONTROLS_LAYER_SCRIPT = preload("res://scripts/ui/touch_controls_layer.gd")
const PERFORMANCE_CAPTURE_SERVICE_SCRIPT = preload("res://scripts/services/performance_capture_service.gd")
const DEBUG_RUN_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/debug_run_runtime_controller.gd")
## Runtime enemy capacity is a pool size, not an authored content roster. Every
## slot is materialized by EnemyFactory so a new definition never needs a scene
## node added to main.tscn.
const ENEMY_POOL_SIZE := 13

## Opt-in boot phase timing for the performance harness. Disabled by default.
static var boot_diagnostics_enabled := false
static var boot_phases: Dictionary = {}
static var _phase_start_usec := 0
static var _phase_label := &""


static func begin_boot_diagnostics() -> void:
	boot_phases.clear()
	_phase_start_usec = 0
	_phase_label = &""


static func _phase(phase: BuildStep.Phase) -> void:
	if not boot_diagnostics_enabled:
		return
	var label := BuildStep.diagnostic_label_for(phase)
	assert(not label.is_empty(), "Boot phases require a diagnostic label.")
	var now := Time.get_ticks_usec()
	if _phase_start_usec > 0:
		boot_phases[_phase_label] = int(boot_phases.get(_phase_label, 0)) + (now - _phase_start_usec)
	_phase_start_usec = now
	_phase_label = label

func boot_phase_report() -> Dictionary:
	return boot_phases.duplicate()


func _add_runtime_node(root: GameplayState, script: Script, node_name: StringName, parent: Node = null) -> Node:
	var node := script.new() as Node
	node.name = node_name
	(parent if parent != null else root).add_child(node)
	return node


func _run_build_steps(root: Node, steps: Array[BuildStep]) -> void:
	for step in steps:
		assert(step != null and step.action.is_valid(), "Build steps require an executable action.")
		_phase(step.phase)
		step.action.call()
		if step.yield_after_frame:
			await root.get_tree().process_frame


func _loading_screen_build_steps(root: GameplayState) -> Array[BuildStep]:
	var steps: Array[BuildStep] = []
	steps.append(BuildStep.new(&"loading_screen", BuildStep.Phase.LOADING_SCREEN, func() -> void:
		root._build_loading_screen()
		root.loading_screen_active = true
		root.loading_screen_fading = false
		root.loading_screen_timer = 0.0
		var boot_loading := root.loading_screen_overlay
		if boot_loading != null:
			boot_loading.visible = true
			boot_loading.modulate.a = 1.0
		root.boot_active = true
	))
	return steps


func _player_animation_build_step(root: GameplayState, yield_after_frame: bool = false) -> BuildStep:
	return BuildStep.new(&"player_animation", BuildStep.Phase.PLAYER_ANIMATION, func() -> void:
		root.player_animation_component = _ensure_player_component(root.player, PlayerAnimationComponent, "Animation") as PlayerAnimationComponent
		root.player_animation_component.build_frames(root.gameplay_frame_controller.animation_context(root))
	, yield_after_frame)


func _gameplay_player_animation_build_steps(root: GameplayState) -> Array[BuildStep]:
	var steps: Array[BuildStep] = []
	steps.append(_player_animation_build_step(root, true))
	return steps


func _title_only_build_steps(root: GameplayState, boot_loading: CanvasItem) -> Array[BuildStep]:
	var steps: Array[BuildStep] = []
	steps.append(_player_animation_build_step(root))
	steps.append(BuildStep.new(&"title_screen", BuildStep.Phase.TITLE_SCREEN, func() -> void:
		root._build_title_screen()
	))
	steps.append(BuildStep.new(&"cloud_panel", BuildStep.Phase.CLOUD_PANEL, func() -> void:
		root.cloud_save_panel.build(root.ui)
	))
	steps.append(BuildStep.new(&"settings", BuildStep.Phase.SETTINGS, func() -> void:
		root._build_settings_ui()
	))
	steps.append(BuildStep.new(&"scene_transition_and_layout", BuildStep.Phase.SCENE_TRANSITION_AND_LAYOUT, func() -> void:
		root._build_scene_transition()
		root._on_display_view_size_changed(root.display_controller.view_size_value())
	))
	steps.append(BuildStep.new(&"title_state", BuildStep.Phase.TITLE_STATE, func() -> void:
		root.screen_state_controller.set_state(&"title")
		_show_title_after_boot(root, boot_loading)
		root.gameplay_frame_controller.invalidate_contexts()
	))
	steps.append(BuildStep.new(&"finalize", BuildStep.Phase.FINALIZE, func() -> void:
		root.boot_active = false
	))
	return steps


func _gameplay_visual_build_steps(root: GameplayState) -> Array[BuildStep]:
	var steps: Array[BuildStep] = []
	steps.append(BuildStep.new(&"fire_and_demon", BuildStep.Phase.FIRE_AND_DEMON, func() -> void:
		root._build_rest_fire_frames()
		root._build_cloaked_demon_frames()
		root._build_player_sprite_shadow()
		root._build_cloaked_demon_sprite_shadow()
	, true))
	return steps


func _gameplay_ui_build_steps(root: GameplayState, profile: PlayerProfile, requested_route: String) -> Array[BuildStep]:
	var steps: Array[BuildStep] = []
	steps.append(BuildStep.new(&"enemy_health_ui", BuildStep.Phase.ENEMY_HEALTH_UI, func() -> void:
		root._build_enemy_health_ui()
	, true))
	steps.append(BuildStep.new(&"interact_prompt", BuildStep.Phase.INTERACT_PROMPT, func() -> void:
		root._build_interact_prompt()
	, true))
	steps.append(BuildStep.new(&"npc_dialogue", BuildStep.Phase.NPC_DIALOGUE, func() -> void:
		root._build_npc_dialogue()
	, true))
	steps.append(BuildStep.new(&"room_number", BuildStep.Phase.ROOM_NUMBER, func() -> void:
		root._build_room_number_indicator()
	, true))
	steps.append(BuildStep.new(&"game_over_ui", BuildStep.Phase.GAME_OVER, func() -> void:
		root._build_game_over_ui()
	, true))
	steps.append(BuildStep.new(&"run_complete_ui", BuildStep.Phase.RUN_COMPLETE, func() -> void:
		root._build_run_complete_ui()
	, true))
	steps.append(BuildStep.new(&"title_screen", BuildStep.Phase.TITLE_SCREEN, func() -> void:
		root._build_title_screen()
		if profile.has_started and (requested_route == "hub" or requested_route == "run"):
			var route_screens := root.screen_state_controller as ScreenStateController
			if route_screens.title_presenter.overlay != null:
				route_screens.title_presenter.overlay.visible = false
	, true))
	steps.append(BuildStep.new(&"cloud_panel", BuildStep.Phase.CLOUD_PANEL, func() -> void:
		root.cloud_save_panel.build(root.ui)
	, true))
	steps.append(BuildStep.new(&"settings", BuildStep.Phase.SETTINGS, func() -> void:
		root._build_settings_ui()
	, true))
	steps.append(BuildStep.new(&"hub_ui", BuildStep.Phase.HUB_UI, func() -> void:
		root._build_hub_ui()
	, true))
	steps.append(BuildStep.new(&"scene_transition_and_layout", BuildStep.Phase.SCENE_TRANSITION_AND_LAYOUT, func() -> void:
		root._build_scene_transition()
		root._on_display_view_size_changed(root.display_controller.view_size_value())
	))
	steps.append(BuildStep.new(&"refresh_player_cloak_visual", BuildStep.Phase.REFRESH_PLAYER_CLOAK_VISUAL, func() -> void:
		root._refresh_player_cloak_visual()
	))
	steps.append(BuildStep.new(&"title_state", BuildStep.Phase.TITLE_STATE, func() -> void:
		var screens := root.screen_state_controller as ScreenStateController
		var enters_saved_route: bool = profile.has_started and (requested_route == "hub" or requested_route == "run")
		if enters_saved_route:
			# Full run boot may still construct the title scene for shared UI assets, but
			# an active save route must never expose that overlay between loading and play.
			if screens.title_presenter.overlay != null:
				screens.title_presenter.overlay.visible = false
			if screens.archetype_presenter.overlay != null:
				screens.archetype_presenter.overlay.visible = false
			screens.set_state(&"loading")
		else:
			screens.set_state(&"title")
	))
	return steps


func initialize(root: GameplayState, preview_session: RefCounted = null) -> void:
	if preview_session != null:
		var preview_errors := _preview_session_errors(preview_session)
		if not preview_errors.is_empty():
			for error in preview_errors:
				push_error("PREVIEW_SESSION_REJECTED: %s" % error)
			root.get_tree().quit(1)
			return
		root.debug_enemy_test_id = preview_session.get("content_id") as StringName
		root.debug_start_in_boss_room = true
		root.rng.seed = int(preview_session.get("seed"))
	SkeletonActor.warm_authored_frames()
	var has_active_profile := ProfileSaveService.has_profile_save()
	var has_profile := ProfileSaveService.has_any_profile_save()
	var profile := ProfileSaveService.load_profile()
	var requested_route := ProfileSaveService.consume_next_boot_route()
	if requested_route.is_empty():
		requested_route = profile.pending_route
	var benchmark_mode := bool(ProjectSettings.get_setting("debug/benchmark_start_in_boss_room", false))
	var configured_debug_enemy_id := root.debug_enemy_test_id
	var debug_enemy_test_id := EnemyFactory.resolve_variant_id(configured_debug_enemy_id)
	var debug_enemy_test_enabled := not debug_enemy_test_id.is_empty()
	if not configured_debug_enemy_id.is_empty() and not debug_enemy_test_enabled:
		push_warning("Unknown debug_enemy_test_id '%s'; starting the normal title flow." % configured_debug_enemy_id)
	elif debug_enemy_test_enabled:
		print("DEBUG ENEMY TEST ACTIVE: %s (%s)" % [debug_enemy_test_id, EnemyFactory.definition(debug_enemy_test_id).display_name])
	root.debug_enemy_test_id = debug_enemy_test_id
	var title_only_boot := not root.debug_start_in_boss_room and not debug_enemy_test_enabled and not benchmark_mode and not (profile.has_started and (requested_route == "hub" or requested_route == "run"))
	var early_service_rows := RuntimeServiceRegistrationPlan.early_service_registrations(root)
	var early_service_registration_errors := RuntimeServiceRegistrationPlan.register_all(early_service_rows)
	assert(early_service_registration_errors.is_empty(), "Invalid early service registration: %s" % "; ".join(early_service_registration_errors))
	if not early_service_registration_errors.is_empty():
		return
	var tracker_registration := RuntimeServiceRegistrationPlan.row_for(early_service_rows, &"InputDeviceTracker")
	var touch_registration := RuntimeServiceRegistrationPlan.row_for(early_service_rows, &"TouchControlsLayer")
	var input_device_tracker := tracker_registration.parent.get_node(NodePath(String(tracker_registration.node_name))) as InputDeviceTracker
	var touch_controls_layer := touch_registration.parent.get_node(NodePath(String(touch_registration.node_name))) as TouchControlsLayer
	root.input_device_tracker = input_device_tracker
	root.touch_controls_layer = touch_controls_layer
	input_device_tracker.device_changed.connect(Callable(touch_controls_layer, "set_last_input_device"))
	touch_controls_layer.build()
	touch_controls_layer.set_last_input_device(input_device_tracker.current_device)
	touch_controls_layer.set_input_context(InputRouter.Context.MENU)
	root.input_router.set_touch_provider(touch_controls_layer)
	var gameplay_service_rows := RuntimeServiceRegistrationPlan.gameplay_service_registrations(root)
	var gameplay_service_errors := RuntimeServiceRegistrationPlan.register_all(gameplay_service_rows)
	assert(gameplay_service_errors.is_empty(), "Invalid gameplay service registration: %s" % "; ".join(gameplay_service_errors))
	if not gameplay_service_errors.is_empty():
		return
	root.player_profile = profile
	root.has_persistent_profile = has_profile
	var screen_state_rows := RuntimeServiceRegistrationPlan.screen_state_service_registrations(root)
	var screen_state_errors := RuntimeServiceRegistrationPlan.register_all(screen_state_rows)
	assert(screen_state_errors.is_empty(), "Invalid screen state service registration: %s" % "; ".join(screen_state_errors))
	if not screen_state_errors.is_empty():
		return
	root._apply_profile_to_runtime()
	var gameplay_frame_rows := RuntimeServiceRegistrationPlan.gameplay_frame_service_registrations(root)
	var gameplay_frame_errors := RuntimeServiceRegistrationPlan.register_all(gameplay_frame_rows)
	assert(gameplay_frame_errors.is_empty(), "Invalid gameplay frame service registration: %s" % "; ".join(gameplay_frame_errors))
	if not gameplay_frame_errors.is_empty():
		return
	root.feedback_animation_registry = FEEDBACK_ANIMATION_REGISTRY_SCRIPT.new() as FeedbackAnimationRegistry
	root.performance_capture_service = _add_runtime_node(root, PERFORMANCE_CAPTURE_SERVICE_SCRIPT, "PerformanceCaptureService")
	var world_service_rows := RuntimeServiceRegistrationPlan.world_service_registrations(root)
	var world_service_errors := RuntimeServiceRegistrationPlan.register_all(world_service_rows)
	assert(world_service_errors.is_empty(), "Invalid world service registration: %s" % "; ".join(world_service_errors))
	if not world_service_errors.is_empty():
		return
	var geometry_debug := root.actor_geometry_debug_drawer
	var occlusion := root.occlusion_renderer
	root.dungeon_map_controller.connect(&"map_state_changed", Callable(root, "_on_dungeon_map_state_changed"))
	var actor_service_rows := RuntimeServiceRegistrationPlan.actor_service_registrations(root)
	var actor_service_errors := RuntimeServiceRegistrationPlan.register_all(actor_service_rows)
	assert(actor_service_errors.is_empty(), "Invalid actor service registration: %s" % "; ".join(actor_service_errors))
	if not actor_service_errors.is_empty():
		return
	var cloaked_demon := root.cloaked_demon
	_initialize_npc_status(cloaked_demon)
	var gameplay_ui_rows := RuntimeServiceRegistrationPlan.gameplay_ui_service_registrations(root)
	var gameplay_ui_errors := RuntimeServiceRegistrationPlan.register_all(gameplay_ui_rows)
	assert(gameplay_ui_errors.is_empty(), "Invalid gameplay UI service registration: %s" % "; ".join(gameplay_ui_errors))
	if not gameplay_ui_errors.is_empty():
		return
	# Establish a visible loading boundary before dungeon generation, room layout,
	# actor setup, and presentation caches begin. The browser must get a rendered
	# frame before the expensive gameplay preparation starts.
	await _run_build_steps(root, _loading_screen_build_steps(root))
	var boot_loading := root.loading_screen_overlay
	await root.get_tree().process_frame
	if title_only_boot:
		# A title boot does not need room generation, actor initialization, enemy
		# visuals, gameplay HUDs, or hub presentation. Keep only the player frame
		# library needed by character creation previews and the menu surfaces that
		# can be reached before a run. Starting a run transitions into a fresh scene,
		# where the complete gameplay path below is initialized with its normal
		# dependencies.
		await _run_build_steps(root, _title_only_build_steps(root, boot_loading))
		return
	var rng := root.rng
	if preview_session == null:
		rng.randomize()
	else:
		rng.seed = int(preview_session.get("seed"))
	var run_state := RunState.new()
	root.run_state = run_state
	var debug_progression_run: int = DEBUG_RUN_RUNTIME_CONTROLLER_SCRIPT.progression_run(root)
	var progression_completed_runs: int = debug_progression_run - 1 if debug_progression_run > 0 else profile.completed_runs
	var dungeon_graph := root.dungeon_graph
	dungeon_graph.configure_progression(progression_completed_runs)
	var dungeon_seed: int = DEBUG_RUN_RUNTIME_CONTROLLER_SCRIPT.dungeon_seed(root, preview_session, rng)
	root.current_dungeon_seed = dungeon_seed
	var initial_room_id: StringName = root.dungeon_map_controller.begin_run(dungeon_graph, dungeon_seed, progression_completed_runs, profile.starter_flame, profile.persistent_flame() if profile.has_bound_element else &"", profile.puzzle_attempt_rotation_quarter_turns)
	root.dungeon_minimap_controller.call("configure", root.dungeon_map_controller)
	await root.get_tree().process_frame
	var minimap_travel_callback := Callable(root, "_on_minimap_flame_travel_requested")
	if not root.dungeon_minimap_controller.is_connected(&"flame_travel_requested", minimap_travel_callback):
		root.dungeon_minimap_controller.connect(&"flame_travel_requested", minimap_travel_callback)
	if root.debug_start_in_boss_room or bool(ProjectSettings.get_setting("debug/benchmark_start_in_boss_room", false)):
		if root.dungeon_map_controller.has_complete_layout():
			for candidate_id in dungeon_graph.get_room_ids():
				var candidate := dungeon_graph.get_room(candidate_id)
				if candidate != null and candidate.room_type == DungeonGraph.ROOM_BOSS:
					initial_room_id = candidate.id
					break
		else:
			var boss_connection: DungeonGraph.ConnectionRecord = dungeon_graph.ensure_connection(
				dungeon_graph.start_room_id,
				DungeonGraph.WALL_RIGHT,
				DungeonGraph.ROOM_DOWNSTAIRS
			)
			initial_room_id = boss_connection.destination_room_id
	root.current_room_id = initial_room_id
	root._sync_current_room_metadata()
	root.room_controller.boss_variant_selection = root.debug_boss_variant
	root.room_controller.debug_enemy_variant = debug_enemy_test_id if debug_enemy_test_enabled else &""
	DEBUG_RUN_RUNTIME_CONTROLLER_SCRIPT.configure_room(root, profile, debug_progression_run, dungeon_seed)
	root.room_controller.set_current_room(root.current_room_id, root.current_room_type)
	root._collect_dungeon_sockets(); root.room_controller.validate_socket_setup(); root._ensure_current_room_layout()
	await root.get_tree().process_frame
	var player := root.get("player") as Sprite2D; var chest := root.get("chest") as Sprite2D; var demon := root.get("cloaked_demon") as Sprite2D; var fire := root.get("rest_fire") as Sprite2D
	_place_debug_player_at_boss_entry(root, player)
	root.set("player_start_position", player.global_position); root.set("chest_start_position", chest.position); root.set("cloaked_demon_start_position", demon.position); root.set("chest_gray_texture", chest.texture); root.set("chest_normal_texture", root._load_texture_or_null("res://assets/artwork/Chest.png"))
	fire.visible = false; fire.frame = 0; root._configure_room_sockets(false)
	var slimes: Array[Sprite2D] = _build_slime_roster(root); root.set("slimes", slimes)
	var actors: Array[Sprite2D] = [player]; actors.append_array(slimes); root.set("actor_sprites", actors)
	geometry_debug.configure(actors, Callable(root, "_actor_foot"), Callable(root, "_collision_rect"), Callable(root, "_slime_body_polygon"))
	var collision: Array[Sprite2D] = [player]; collision.append_array(slimes); collision.append(chest); root.set("collision_sprites", collision)
	var enemy_services := RoomEnemySpawnServices.new()
	var actor_runtime := enemy_services.actor_runtime
	actor_runtime.enemy_roster.replace_members(slimes)
	actor_runtime.actor_sprites = actors
	actor_runtime.collision_sprites = collision
	actor_runtime.depth_sprites = root.depth_sprites
	actor_runtime.occluder_sprites = root.occluder_sprites
	actor_runtime.last_valid_positions = root.slime_last_valid_positions
	actor_runtime.hud_controller = root.hud_controller
	actor_runtime.occlusion_renderer = occlusion
	actor_runtime.enemy_health_damaged_callback = Callable(root, "_on_slime_health_damaged")
	actor_runtime.enemy_health_healed_callback = Callable(root, "_on_slime_health_healed")
	actor_runtime.enemy_health_changed_callback = Callable(root, "_on_slime_health_changed")
	actor_runtime.clear_enemy_max_health_cache_callback = Callable(root.combat_runtime_controller, "clear_enemy_max_health_frame_cache")
	enemy_services.actor_runtime = actor_runtime
	enemy_services.slime_tuning = root.slime_tuning; enemy_services.rng = root.rng; enemy_services.player_profile = root.player_profile; enemy_services.run_state = root.run_state; enemy_services.walkable_area = root.walkable_area; enemy_services.dungeon_graph = root.dungeon_graph; enemy_services.dungeon_map_controller = root.dungeon_map_controller; enemy_services.effects_spawner = root.effects_spawner; enemy_services.collision_rect = Callable(root, "_collision_rect"); enemy_services.actor_foot_offset = root.ACTOR_FOOT_OFFSET
	enemy_services.sound_manager = root.sound_manager
	enemy_services.set_actor_visual_scale = Callable(root, "_set_actor_visual_scale"); enemy_services.apply_actor_scale = Callable(root, "_apply_actor_scale"); enemy_services.apply_enemy_room_level = Callable(root, "_apply_enemy_room_level"); enemy_services.enemy_max_health = Callable(root, "_enemy_max_health"); enemy_services.prepare_slime_idle_visual = Callable(root, "_prepare_slime_idle_visual"); enemy_services.begin_slime_spawn = Callable(root, "_begin_slime_spawn"); enemy_services.build_slime_direction_textures = Callable(root, "_build_slime_direction_textures"); enemy_services.assign_slime_attack_frames = Callable(root, "_assign_slime_attack_frames"); enemy_services.assign_slime_shocked_frames = Callable(root, "_assign_slime_shocked_frames"); enemy_services.assign_slime_spawn_frames = Callable(root, "_assign_slime_spawn_frames")
	enemy_services.trigger_slime_notice = Callable(root, "_trigger_slime_notice"); enemy_services.set_door_active = Callable(root, "_set_door_active"); enemy_services.set_entrance_open = Callable(root, "_set_entrance_open"); enemy_services.build_depth_lists = Callable(root, "_build_depth_lists")
	root.room_controller.configure_enemy_spawn_services(enemy_services, player, chest)
	(root.get("depth_sorter") as DepthSorter).set_sprites(actors); occlusion.set_occluders(root.get("occluder_sprites"))
	var player_shadow := root.get("player_shadow") as Sprite2D; var demon_shadow := root.get("cloaked_demon_shadow") as Sprite2D
	# Store the authored shadow correction relative to the gameplay foot. The
	# shadow may have been updated once before debug-room repositioning, so
	# deriving this from its current runtime position can capture a stale offset.
	root.set("player_shadow_offset", Vector2(-8.0, -9.0)); root.set("player_shadow_scale", player_shadow.global_scale); player_shadow.z_as_relative = false
	root.set("cloaked_demon_shadow_offset", demon_shadow.global_position - demon.global_position); root.set("cloaked_demon_shadow_scale", demon_shadow.global_scale); demon_shadow.z_as_relative = false
	var attack_visual := root.get("player_attack_visual") as Sprite2D; attack_visual.z_as_relative = false; attack_visual.visible = false
	root._hide_editor_only_guides()
	(root.get("hp_overhead") as Sprite2D).z_as_relative = false; (root.get("hp_overhead_fill") as Sprite2D).z_as_relative = false
	var ui := root.get("ui") as Node
	var player_hud := ui.get_node_or_null("PlayerHud") as Node2D
	if player_hud != null: player_hud.visible = true
	root.set("target_health_bar_size", (root.get("target_health_fill") as Sprite2D).texture.get_size()); root.set("player_health_fill_size", (root.get("player_health_fill") as Sprite2D).texture.get_size())
	root._build_depth_lists(); occlusion.register_sprites(actors, root.get("occluder_sprites"))
	await root.get_tree().process_frame
	# Warm long-running music after the loading screen has had a frame to draw;
	# the first flame-room transition can then start its track from memory.
	_phase(BuildStep.Phase.MUSIC_PRELOAD)
	root.sound_manager.preload_music_tracks()
	# Parse and instantiate the boss authoring templates while the boot loading
	# screen is visible. Room entry can then reuse them without loading a second
	# main-scene tree or cloning a fresh boss guide source on the transition
	# frame.
	_phase(BuildStep.Phase.PREWARM_TRANSITION_ASSETS)
	if not title_only_boot:
		root.room_controller.prewarm_transition_assets(root.hub_stone_accent_layer)
	await root.get_tree().process_frame
	await _run_build_steps(root, _gameplay_player_animation_build_steps(root))
	await _run_build_steps(root, _gameplay_visual_build_steps(root))
	_phase(BuildStep.Phase.BUILD_SLIME_TEXTURES)
	var starts_in_title := title_only_boot
	if starts_in_title:
		# Slime frame generation is the largest boot phase. The loading screen at
		# run entry owns this work; title/menu boot does not need enemy visuals.
		pass
	else:
		await root.actor_presentation_runtime_controller.ensure_slime_visuals_ready(root)
	await _run_build_steps(root, _gameplay_ui_build_steps(root, profile, requested_route))
	_phase(BuildStep.Phase.INITIALIZE_PLAYER)
	_initialize_player(root, player)
	await root.get_tree().process_frame
	_phase(BuildStep.Phase.INITIALIZE_WALKABLE_AREA)
	_initialize_walkable_area(root, 0.35, 1.25)
	await root.get_tree().process_frame
	_phase(BuildStep.Phase.INITIALIZE_SLIMES)
	_initialize_slimes(root, slimes)
	await root.get_tree().process_frame
	_phase(BuildStep.Phase.ROOM_STATE_AND_ROUTE)
	root.room_controller.initialize_boss_jump_phase_pool(root)
	root._apply_room_state(); root._build_depth_lists()
	await root.get_tree().process_frame
	if bool(root.get("debug_start_in_boss_room")) or bool(ProjectSettings.get_setting("debug/benchmark_start_in_boss_room", false)):
		# Initialize normal run resources without replacing the dungeon and boss room
		# that were already selected and applied above.
		root._begin_new_run(true)
		_place_debug_player_at_boss_entry(root, player)
		root.set("player_start_position", player.global_position)
		root.player_animation_component.apply_frame(root.gameplay_frame_controller.animation_context(root))
		root._update_player_shadow()
		root._build_depth_lists()
		root.actor_presentation_runtime_controller.set_title_world_visible(root, true)
		_enter_debug_gameplay(root)
		root.set("loading_screen_active", false)
		ProjectSettings.set_setting("debug/benchmark_start_in_boss_room", false)
	else:
		var route := requested_route
		profile.pending_route = "title"
		profile.open_hub_on_load = false
		if has_active_profile: root.call("_save_player_profile")
		var has_recovery_checkpoint := ACTIVE_RUN_SAVE_SERVICE_SCRIPT.has_valid_snapshot(ProfileSaveService.current_slot())
		if (route == "hub" or route == "run") and profile.has_started:
			# A normal browser reload returns to the title screen so Continue can
			# offer the explicit resume/discard choice. A confirmed Continue flow
			# persists the "run" route and can enter directly on the next scene.
			root.pending_run_restore = route == "run" and has_recovery_checkpoint
			# Await the room handoff so bootstrap cannot release its boot lock while
			# the async loading path is still between title and gameplay.
			await (root.save_flow_controller as SaveFlowController).enter_starting_room_from_menu(root)
		else:
			_show_title_after_boot(root, boot_loading)
	# Contexts built earlier in bootstrap (build_frames runs before
	# _initialize_player creates the player components) may have captured null
	# dependencies. Discard them so the first active frame rebuilds against fully
	# wired state.
	root.gameplay_frame_controller.invalidate_contexts()
	_phase(BuildStep.Phase.FINALIZE)
	root.set("boot_active", false)


func _preview_session_errors(session: RefCounted) -> Array[String]:
	var errors: Array[String] = session.call("validation_errors")
	if session.get("content_kind") != &"enemy":
		errors.append("This preview runner currently supports enemy content only.")
	if session.get("requested_mode") != &"enemy_boss_encounter":
		errors.append("Enemy preview mode must be enemy_boss_encounter.")
	if session.get("arrival_socket_id") != &"auto":
		errors.append("Enemy preview mode currently requires automatic boss-room entry.")
	var loadout: Dictionary = session.get("loadout") as Dictionary
	if String(loadout.get("preset", "")) != "starter":
		errors.append("Enemy preview mode requires the starter loadout preset.")
	var content_id := session.get("content_id") as StringName
	if not ENEMY_CATALOG_SCRIPT.contains_id(content_id):
		errors.append("Unknown enemy content ID '%s'." % content_id)
	return errors


func _place_debug_player_at_boss_entry(root: GameplayState, player: Sprite2D) -> void:
	if not bool(root.get("debug_start_in_boss_room")) or root.get("current_room_type") != DungeonGraph.ROOM_DOWNSTAIRS:
		return
	var graph := root.get("dungeon_graph") as DungeonGraph
	var rooms := root.get("room_controller") as RoomController
	if graph == null or rooms == null:
		return
	for socket_value in rooms.active_entrance_sockets.values():
		var socket := socket_value as DungeonSocket
		if socket == null:
			continue
		var connection := graph.get_connection_for_entry(root.get("current_room_id"), socket.socket_id())
		if connection == null:
			continue
		# Debug scenes bypass the normal doorway transition, so record the same
		# arrival socket that a live transition would pass to RoomController. This
		# keeps boss final-exit routing and resumed-room geometry deterministic.
		rooms.arrival_socket_id = socket.socket_id()
		root._sync_current_room_metadata(socket.socket_id())
		player.global_position = rooms.call("_arrival_player_position", root, socket)
		player.flip_h = socket.inward_facing.x < 0.0
		root.set("last_player_facing_left", player.flip_h)
		return


func _show_title_after_boot(root: GameplayState, boot_loading: CanvasItem) -> void:
	root.loading_screen_active = false
	root.actor_presentation_runtime_controller.set_title_world_visible(root, false)
	if boot_loading != null:
		boot_loading.visible = false
	var screens := root.screen_state_controller as ScreenStateController
	if screens == null or screens.title_presenter.overlay == null:
		push_error("Title screen was not constructed before bootstrap completed.")
		return
	root.ui.visible = true
	root.screen_state_controller.set_hud_visibility(root, false)
	screens.title_presenter.overlay.visible = true
	screens.title_presenter.overlay.modulate.a = 1.0
	if screens.title_presenter.title_text != null: screens.title_presenter.title_text.visible = true
	if screens.title_presenter.start_text != null: screens.title_presenter.start_text.visible = true
	if screens.title_presenter.start_button != null: screens.title_presenter.start_button.visible = true
	if screens.title_presenter.continue_button != null: screens.title_presenter.continue_button.visible = not screens.title_presenter.continue_button.disabled
	if screens.title_presenter.settings_button != null: screens.title_presenter.settings_button.visible = true
	if screens.title_presenter.cloud_button != null: screens.title_presenter.cloud_button.visible = true
	if screens.title_presenter.cursor_text != null: screens.title_presenter.cursor_text.visible = true
	screens.title_presenter.transition_active = false
	screens.title_presenter.pending_destination = ""
	screens.set_state(&"title")


func _enter_debug_gameplay(root: Object) -> void:
	var ssc := root.get("screen_state_controller") as ScreenStateController
	var title_overlay := ssc.title_presenter.overlay as CanvasItem
	var archetype_overlay := ssc.archetype_presenter.overlay as CanvasItem
	var loading_overlay := root.get("loading_screen_overlay") as CanvasItem
	if title_overlay != null: title_overlay.visible = false
	if archetype_overlay != null: archetype_overlay.visible = false
	if loading_overlay != null: loading_overlay.visible = false
	var ui := root.get("ui") as CanvasItem
	if ui != null: ui.visible = true
	(root.get("screen_state_controller") as ScreenStateController).set_state(&"gameplay")


func _guard_context(root: GameplayState, player: Sprite2D) -> PlayerGuardContext:
	var context := PlayerGuardContext.new()
	context.ui_parent = root
	context.player = player
	context.equipment = root.player_equipment
	context.visuals = root.player_equipment_visual_component
	context.overworld_ui_z = root.OVERWORLD_UI_Z
	context.is_defending_get = func() -> Variant: return root.get("player_is_defending")
	context.is_defending_set = func(value: Variant) -> void: root.set("player_is_defending", value)
	context.player_dead_get = func() -> Variant: return root.get("player_dead")
	context.player_death_pending_get = func() -> Variant: return root.get("player_death_pending")
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_is_targeting_get = func() -> Variant: return root.player_is_targeting
	context.player_hitstun_timer_get = func() -> Variant: return root.get("player_hitstun_timer")
	context.actor_foot = Callable(root, "_actor_foot")
	context.build_equipment_visual_context = func() -> PlayerEquipmentVisualContext: return root.gameplay_frame_controller.equipment_visual_context(root)
	return context


func _ensure_player_component(player: Sprite2D, script: Script, node_name: StringName) -> Node:
	var component := player.get_node_or_null(NodePath(node_name)) as Node
	if component == null:
		component = script.new() as Node
		component.name = node_name
		player.add_child(component)
	return component


func _initialize_player(root: GameplayState, player: Sprite2D) -> void:
	var equipment := player.get_node_or_null(^"Equipment") as EquipmentComponent
	if equipment == null:
		equipment = _ensure_player_component(player, EquipmentComponent, "Equipment") as EquipmentComponent; equipment.equip_default_loadout()
	root.player_equipment = equipment
	var profile := root.player_profile
	root.puzzle_attempt_rotation_quarter_turns = profile.puzzle_attempt_rotation_quarter_turns
	if profile != null:
		profile.ensure_starter_items()
		equipment.configure_from_profile(profile)
	var tuning := root.player_tuning
	var health := _ensure_player_component(player, HealthComponent, "Health") as HealthComponent
	var status_component := _ensure_player_component(player, StatusComponent, "Status") as StatusComponent
	status_component.health_component = health
	status_component.set_duration_bonus_for_status(&"freeze", PlayerController.PLAYER_FREEZE_DURATION_BONUS)
	var element_aura := _ensure_player_component(player, ElementAuraComponent, "ElementAura") as ElementAuraComponent
	element_aura.configure(player, player.get_parent() as Node2D, status_component, root.player_attack_visual)
	health.set_process(false); health.regen_delay = tuning.regen_delay; health.regen_interval = tuning.regen_interval; health.regen_amount = tuning.regen_amount
	health.damaged.connect(Callable(root, "_on_player_health_damaged")); health.healed.connect(Callable(root, "_on_player_health_healed")); health.health_changed.connect(Callable(root, "_on_player_health_changed"))
	root.player_health_component = health
	DEBUG_RUN_RUNTIME_CONTROLLER_SCRIPT.configure_health(root, health)
	var motor := _ensure_player_component(player, ActorMotor, "Motor") as ActorMotor; motor.status_component = status_component; motor.motion_requested.connect(Callable(root, "_on_player_motor_motion")); root.player_motor = motor
	root.player_controller = _ensure_player_component(player, PlayerController, "Controller") as PlayerController; root.player_controller.configure_input_router(root.input_router); root.player_roll_component = _ensure_player_component(player, PlayerRollComponent, "Roll") as PlayerRollComponent; root.player_attack_component = _ensure_player_component(player, PlayerAttackComponent, "Attack") as PlayerAttackComponent; root.player_animation_component = _ensure_player_component(player, PlayerAnimationComponent, "Animation") as PlayerAnimationComponent
	var guard := _ensure_player_component(player, PlayerGuardComponent, "Guard") as PlayerGuardComponent; guard.initialize(_guard_context(root, player)); root.player_guard_component = guard
	var transmutations := _ensure_player_component(player, EquipmentTransmutationComponent, "Transmutations") as EquipmentTransmutationComponent
	transmutations.configure(equipment); guard.successful_block.connect(Callable(transmutations, "record_successful_block")); guard.successful_block.connect(Callable(root, "_on_player_successful_block"))
	var attack := root.player_attack_component
	attack.status_component = status_component
	attack.attack_started.connect(Callable(transmutations, "begin_attack")); attack.attack_finished.connect(Callable(transmutations, "finish_attack")); attack.attack_hit_resolved.connect(Callable(transmutations, "record_attack_hits"))
	transmutations.effect_triggered.connect(Callable(root, "_on_transmutation_effect_triggered")); root.equipment_transmutation_component = transmutations; root._configure_equipment_transmutations()
	root.player_chroma_component = _ensure_player_component(player, PLAYER_CHROMA_COMPONENT_SCRIPT, "Chroma") as PlayerChromaComponent
	if profile != null and profile.has_bound_element:
		root.player_chroma_component.call("set_bound_flame", profile.bound_element)
	root.player_aspect_ability_component = _ensure_player_component(player, PLAYER_ASPECT_ABILITY_COMPONENT_SCRIPT, "AspectAbility")
	root.player_aspect_ability_component.call("configure_mode_cooldowns", 2.0, root.GREY_MAGIC_COOLDOWN)
	var equipment_visual := _ensure_player_component(player, PlayerEquipmentVisualComponent, "EquipmentVisual") as PlayerEquipmentVisualComponent
	_phase(BuildStep.Phase.PLAYER_EQUIPMENT_VISUAL)
	equipment_visual.initialize(root.gameplay_frame_controller.equipment_visual_context(root)); root.player_equipment_visual_component = equipment_visual
	_phase(BuildStep.Phase.PLAYER_AFTER_EQUIPMENT)
	root._set_target_ui_visible(false)
	var player_health: float = root._player_max_health(); health.maximum_health = player_health; health.reset(player_health); root.player_display_health = player_health; root._update_player_health_ui()
	root._update_player_mp_ui()


func _initialize_npc_status(actor: Sprite2D) -> void:
	if actor == null:
		return
	var status := actor.get_node_or_null(^"Status") as StatusComponent
	if status == null:
		status = StatusComponent.new()
		status.name = "Status"
		actor.add_child(status)
	var aura := actor.get_node_or_null(^"ElementAura") as ElementAuraComponent
	if aura == null:
		aura = ElementAuraComponent.new()
		aura.name = "ElementAura"
		actor.add_child(aura)
	aura.configure(actor, actor.get_parent() as Node2D, status)


func _initialize_walkable_area(root: GameplayState, edge_margin: float, slime_edge_padding: float) -> void:
	root.use_walkable_polygon_direct = true; root._collect_walkable_tiles(root.floor_tiles); root._build_entrance_block_polygons(); root._build_walkable_outline()
	var area := root.walkable_area
	if area != null:
		area.set_geometry(root.walkable_polygons, root.walkable_outline); area.edge_margin = edge_margin; area.slime_edge_padding = slime_edge_padding; area.set_entrance_blocks(root.entrance_block_polygons)
	if root.walkable_outline.is_empty(): push_warning("No floor tiles found. Actor movement will be disabled.")


func _initialize_slimes(root: Object, slimes: Array[Sprite2D]) -> void:
	var rng := root.get("rng") as RandomNumberGenerator; var tuning := root.get("slime_tuning") as SlimeTuning
	for slime in slimes:
		var actor := slime as EnemyActor
		if actor != null: actor.reset_runtime_state(slime.position, root._nearest_slime_walkable_point(root._actor_foot(slime)), rng.randf_range(tuning.repath_min, tuning.repath_max), rng.randf_range(tuning.hold_min, tuning.hold_max), rng.randf_range(0.0, tuning.idle_breath_time), rng.randf_range(0.2, 0.6))
		root._update_slime_attack_guides(slime); root._apply_enemy_room_level(slime)
		var maximum: float = root._enemy_max_health(slime); var slime_actor := slime as EnemyActor
		if slime_actor != null: slime_actor.ensure_components()
		var health := slime.get_node_or_null("Health") as HealthComponent
		if slime_actor != null: health = slime_actor.configure_health(maximum, tuning.regen_delay, tuning.regen_interval, tuning.regen_amount)
		health.damaged.connect(Callable(root, "_on_slime_health_damaged").bind(slime)); health.healed.connect(Callable(root, "_on_slime_health_healed").bind(slime)); health.health_changed.connect(Callable(root, "_on_slime_health_changed").bind(slime)); var presenter := EnemyActor.component(slime, "HealthPresenter", SlimeHealthPresenter) as SlimeHealthPresenter; presenter.display_health = maximum; presenter.damage_fill_hold_timer = 0.0


func _build_slime_roster(root: Object) -> Array[Sprite2D]:
	var gameplay := root as GameplayState
	var template := root.get("slime_green") as Sprite2D
	var parent := template.get_parent() if template != null else null
	var result: Array[Sprite2D] = []
	if parent == null:
		return result
	# The three scene-authored slimes remain as editor/reference templates for
	# shared HUD assets, but they are not gameplay roster slots anymore.
	for template_node in [root.get("slime_blue"), root.get("slime_green"), root.get("slime_red")]:
		var scene_template := template_node as Sprite2D
		if scene_template != null:
			scene_template.visible = false
	var template_positions: Array[Vector2] = []
	for template_node in [root.get("slime_blue"), root.get("slime_green"), root.get("slime_red")]:
		var scene_template := template_node as Sprite2D
		if scene_template != null:
			template_positions.append(scene_template.position)
	while template_positions.size() < 3:
		template_positions.append(Vector2.ZERO)
	var debug_enemy_id := EnemyFactory.resolve_variant_id(gameplay.debug_enemy_test_id)
	var initial_enemy_id := debug_enemy_id if not debug_enemy_id.is_empty() else &"grey"
	var initial_enemy_definition := EnemyFactory.definition(initial_enemy_id)
	for slot in ENEMY_POOL_SIZE:
		var actor := EnemyFactory.assemble(initial_enemy_definition)
		actor.name = "EnemySlot%d" % (slot + 1)
		actor.position = template_positions[slot % template_positions.size()]
		parent.add_child(actor)
		result.append(actor)
	return result
