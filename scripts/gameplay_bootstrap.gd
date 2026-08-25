extends Node
class_name GameplayBootstrap

const PLAYER_CHROMA_COMPONENT_SCRIPT = preload("res://scripts/player_chroma_component.gd")
const SOUL_PICKUP_CONTROLLER_SCRIPT = preload("res://scripts/soul_pickup_controller.gd")
const PLAYER_ASPECT_ABILITY_COMPONENT_SCRIPT = preload("res://scripts/player_aspect_ability_component.gd")
const PROFILE_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/profile_runtime_controller.gd")
const PICKUP_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/pickup_runtime_controller.gd")
const RUN_FLOW_CONTROLLER_SCRIPT = preload("res://scripts/run_flow_controller.gd")
const HUB_FLOW_CONTROLLER_SCRIPT = preload("res://scripts/hub_flow_controller.gd")
const SAVE_FLOW_CONTROLLER_SCRIPT = preload("res://scripts/save_flow_controller.gd")
const ROOM_PUZZLE_CONTROLLER_SCRIPT = preload("res://scripts/room_puzzle_controller.gd")
const MAGIC_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/magic_runtime_controller.gd")
const TARGETING_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/targeting_runtime_controller.gd")
const COMBAT_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/combat_runtime_controller.gd")
const SLIME_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/slime_runtime_controller.gd")
const ACTOR_PRESENTATION_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/actor_presentation_runtime_controller.gd")
const DUNGEON_MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const DUNGEON_MINIMAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_minimap_controller.gd")
const SLIME_ROSTER_SIZE := 13


func _add_runtime_node(root: GameplayState, script: Script, node_name: StringName, parent: Node = null) -> Node:
	var node := script.new() as Node
	node.name = node_name
	(parent if parent != null else root).add_child(node)
	return node


func initialize(root: GameplayState) -> void:
	var has_active_profile := ProfileSaveService.has_profile_save()
	var has_profile := ProfileSaveService.has_any_profile_save()
	root.input_router = _add_runtime_node(root, InputRouter, "InputRouter") as InputRouter
	root.profile_runtime_controller = _add_runtime_node(root, PROFILE_RUNTIME_CONTROLLER_SCRIPT, "ProfileRuntimeController")
	root.pickup_runtime_controller = _add_runtime_node(root, PICKUP_RUNTIME_CONTROLLER_SCRIPT, "PickupRuntimeController")
	root.run_flow_controller = _add_runtime_node(root, RUN_FLOW_CONTROLLER_SCRIPT, "RunFlowController")
	root.dungeon_map_controller = _add_runtime_node(root, DUNGEON_MAP_CONTROLLER_SCRIPT, "DungeonMapController") as Node
	root.hub_flow_controller = _add_runtime_node(root, HUB_FLOW_CONTROLLER_SCRIPT, "HubFlowController")
	root.save_flow_controller = _add_runtime_node(root, SAVE_FLOW_CONTROLLER_SCRIPT, "SaveFlowController")
	root.room_puzzle_controller = _add_runtime_node(root, ROOM_PUZZLE_CONTROLLER_SCRIPT, "RoomPuzzleController")
	root.magic_runtime_controller = _add_runtime_node(root, MAGIC_RUNTIME_CONTROLLER_SCRIPT, "MagicRuntimeController")
	root.targeting_runtime_controller = _add_runtime_node(root, TARGETING_RUNTIME_CONTROLLER_SCRIPT, "TargetingRuntimeController")
	root.combat_runtime_controller = _add_runtime_node(root, COMBAT_RUNTIME_CONTROLLER_SCRIPT, "CombatRuntimeController")
	root.slime_runtime_controller = _add_runtime_node(root, SLIME_RUNTIME_CONTROLLER_SCRIPT, "SlimeRuntimeController")
	root.actor_presentation_runtime_controller = _add_runtime_node(root, ACTOR_PRESENTATION_RUNTIME_CONTROLLER_SCRIPT, "ActorPresentationRuntimeController")
	var profile := ProfileSaveService.load_profile()
	root.player_profile = profile
	root.has_persistent_profile = has_profile
	root.screen_state_controller = _add_runtime_node(root, ScreenStateController, "ScreenStateController") as ScreenStateController
	root.call("_apply_profile_to_runtime")
	root.gameplay_frame_controller = _add_runtime_node(root, GameplayFrameController, "GameplayFrameController") as GameplayFrameController
	var effects_tuning := root.effects_tuning
	root.walkable_area = _add_runtime_node(root, WalkableArea, "WalkableArea") as WalkableArea
	root.actor_collision_system = _add_runtime_node(root, ActorCollisionSystem, "ActorCollisionSystem") as ActorCollisionSystem
	var geometry_debug := _add_runtime_node(root, ActorGeometryDebugDrawer, "ActorGeometryDebugDrawer") as ActorGeometryDebugDrawer
	geometry_debug.enabled = root.debug_actor_geometry; geometry_debug.z_as_relative = false; geometry_debug.z_index = 4096; root.actor_geometry_debug_drawer = geometry_debug
	root.depth_sorter = _add_runtime_node(root, DepthSorter, "DepthSorter") as DepthSorter
	var occlusion := _add_runtime_node(root, OcclusionRenderer, "OcclusionRenderer") as OcclusionRenderer
	occlusion.resolution_scale = effects_tuning.resolution_scale; root.occlusion_renderer = occlusion
	root.room_controller = _add_runtime_node(root, RoomController, "RoomController") as RoomController
	root.room_controller.room_cleared.connect(Callable(root.dungeon_map_controller, "on_room_completed"))
	root.dungeon_map_controller.connect(&"map_state_changed", Callable(root, "_on_dungeon_map_state_changed"))
	root.shadow_controller = _add_runtime_node(root, ShadowController, "ShadowController") as ShadowController
	root.interaction_component = _add_runtime_node(root, InteractionComponent, "InteractionComponent") as InteractionComponent
	root.chest_controller = _add_runtime_node(root, ChestController, "ChestController", root.chest) as ChestController
	root.npc_controller = _add_runtime_node(root, NpcController, "NpcController", root.cloaked_demon) as NpcController
	root.rest_fire_controller = _add_runtime_node(root, RestFireController, "RestFireController", root.rest_fire) as RestFireController
	root.hud_controller = _add_runtime_node(root, HudController, "HudController", root.ui) as HudController
	root.dungeon_minimap_controller = _add_runtime_node(root, DUNGEON_MINIMAP_CONTROLLER_SCRIPT, "DungeonMinimapController", root.ui) as Node
	root.sound_manager = _add_runtime_node(root, SoundManager, "SoundManager") as SoundManager
	root.effects_spawner = _add_runtime_node(root, EffectsSpawner, "EffectsSpawner") as EffectsSpawner
	root.magic_projectile_controller = _add_runtime_node(root, MagicProjectileController, "MagicProjectileController") as MagicProjectileController
	root.chroma_pickup_controller = _add_runtime_node(root, ChromaPickupController, "ChromaPickupController") as ChromaPickupController
	root.soul_pickup_controller = _add_runtime_node(root, SOUL_PICKUP_CONTROLLER_SCRIPT, "SoulPickupController") as SoulPickupController
	var rng := root.rng
	rng.randomize()
	var run_state := RunState.new()
	root.run_state = run_state
	var dungeon_graph := root.dungeon_graph
	dungeon_graph.configure_progression(profile.completed_runs)
	var dungeon_seed := rng.randi()
	root.current_dungeon_seed = dungeon_seed
	var initial_room_id: StringName = root.dungeon_map_controller.begin_run(dungeon_graph, dungeon_seed, profile.completed_runs, profile.starter_flame)
	root.dungeon_minimap_controller.call("configure", root.dungeon_map_controller)
	if root.debug_start_in_boss_room:
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
	root.room_controller.set_current_room(root.current_room_id, root.current_room_type)
	root._collect_dungeon_sockets(); root.room_controller.validate_socket_setup(); root._ensure_current_room_layout()
	var player := root.get("player") as Sprite2D; var chest := root.get("chest") as Sprite2D; var demon := root.get("cloaked_demon") as Sprite2D; var fire := root.get("rest_fire") as Sprite2D
	_place_debug_player_at_boss_entry(root, player)
	root.set("player_start_position", player.position); root.set("chest_start_position", chest.position); root.set("cloaked_demon_start_position", demon.position); root.set("chest_gray_texture", chest.texture); root.set("chest_normal_texture", root.call("_load_texture_or_null", "res://assets/artwork/Chest.png"))
	fire.visible = false; fire.frame = 0; root.call("_configure_room_sockets", false)
	var slimes: Array[Sprite2D] = [root.get("slime_blue"), root.get("slime_green"), root.get("slime_red")]; _expand_slime_roster(root, slimes); root.set("slimes", slimes)
	var actors: Array[Sprite2D] = [player]; actors.append_array(slimes); root.set("actor_sprites", actors)
	geometry_debug.configure(actors, Callable(root, "_actor_foot"), Callable(root, "_collision_rect"), Callable(root, "_slime_body_polygon"))
	var collision: Array[Sprite2D] = [player]; collision.append_array(slimes); collision.append(chest); root.set("collision_sprites", collision)
	(root.get("depth_sorter") as DepthSorter).set_sprites(actors); occlusion.set_occluders(root.get("occluder_sprites"))
	var player_shadow := root.get("player_shadow") as Sprite2D; var demon_shadow := root.get("cloaked_demon_shadow") as Sprite2D
	root.set("player_shadow_offset", player_shadow.global_position - player.global_position); root.set("player_shadow_scale", player_shadow.global_scale); player_shadow.z_as_relative = false
	root.set("cloaked_demon_shadow_offset", demon_shadow.global_position - demon.global_position); root.set("cloaked_demon_shadow_scale", demon_shadow.global_scale); demon_shadow.z_as_relative = false
	var attack_visual := root.get("player_attack_visual") as Sprite2D; attack_visual.z_as_relative = false; attack_visual.visible = false
	root.call("_hide_editor_only_guides")
	(root.get("hp_overhead") as Sprite2D).z_as_relative = false; (root.get("hp_overhead_fill") as Sprite2D).z_as_relative = false
	var ui := root.get("ui") as Node
	var player_hud := ui.get_node_or_null("PlayerHud") as Node2D
	if player_hud != null: player_hud.visible = true
	root.set("target_health_bar_size", (root.get("target_health_fill") as Sprite2D).texture.get_size()); root.set("player_health_fill_size", (root.get("player_health_fill") as Sprite2D).texture.get_size())
	root.call("_build_depth_lists"); occlusion.register_sprites(actors, root.get("occluder_sprites"))
	# Build and show the loading screen BEFORE the heavy frame/reticle build work,
	# then yield one frame so it actually renders (the first frame would otherwise
	# be blocked by this synchronous boot).  The build chain below must NOT rebuild
	# the loading screen.
	root.call("_build_loading_screen")
	root.set("loading_screen_active", true)
	root.set("loading_screen_fading", false)
	root.set("loading_screen_timer", 0.0)
	var boot_loading := root.get("loading_screen_overlay") as ColorRect
	if boot_loading != null:
		boot_loading.visible = true
		boot_loading.modulate.a = 1.0
	root.set("boot_active", true)
	await root.get_tree().process_frame
	root.player_animation_component = _ensure_player_component(player, PlayerAnimationComponent, "Animation") as PlayerAnimationComponent
	root.player_animation_component.build_frames(root); root.call("_build_rest_fire_frames"); root.call("_build_cloaked_demon_frames"); root.call("_build_player_sprite_shadow"); root.call("_build_cloaked_demon_sprite_shadow"); root.call("_build_slime_direction_textures"); root.call("_build_slime_attack_frames"); root.call("_build_slime_shocked_frames"); root.call("_build_enemy_health_ui"); root.call("_build_interact_prompt"); root.call("_build_npc_dialogue"); root.call("_build_room_number_indicator"); root.call("_build_game_over_ui"); root.call("_build_run_complete_ui"); root.call("_build_title_screen"); root.call("_build_hub_ui"); root.call("_build_scene_transition")
	(root.get("screen_state_controller") as ScreenStateController).set_state(&"title")
	_initialize_player(root, player)
	_initialize_walkable_area(root, root.EDGE_MARGIN, root.SLIME_EDGE_PADDING)
	_initialize_slimes(root, slimes)
	root._apply_room_state(); root._build_depth_lists()
	if bool(root.get("debug_start_in_boss_room")):
		root.call("_begin_new_run")
		# begin_new_run regenerates the debug dungeon with a fresh seed. Reapply the
		# authored boss arrival after that reset so the debug player and the active
		# socket belong to the same room layout.
		_place_debug_player_at_boss_entry(root, player)
		root.set("player_start_position", player.position)
		_enter_debug_gameplay(root)
		root.set("loading_screen_active", false)
	else:
		var route := profile.pending_route
		profile.pending_route = "title"
		profile.open_hub_on_load = false
		if has_active_profile: root.call("_save_player_profile")
		if (route == "hub" or route == "run") and profile.has_started:
			# Enter the room directly (not deferred) so the title screen never
			# flashes before the hub/run; _enter_starting_room_from_menu hides the
			# title and fades the loading screen out.
			root.call("_enter_starting_room_from_menu")
		else:
			_show_title_after_boot(root, boot_loading)
	root.set("boot_active", false)


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
		player.global_position = rooms.call("_arrival_player_position", root, socket)
		player.flip_h = socket.inward_facing.x < 0.0
		root.set("last_player_facing_left", player.flip_h)
		return


func _show_title_after_boot(root: GameplayState, boot_loading: CanvasItem) -> void:
	root.loading_screen_active = false
	if boot_loading != null:
		boot_loading.visible = false
	var screens := root.screen_state_controller as ScreenStateController
	if screens == null or screens.title_overlay == null:
		push_error("Title screen was not constructed before bootstrap completed.")
		return
	root.ui.visible = true
	screens.title_overlay.visible = true
	screens.title_overlay.modulate.a = 1.0
	if screens.title_screen_text != null: screens.title_screen_text.visible = true
	if screens.title_start_text != null: screens.title_start_text.visible = true
	if screens.title_start_button != null: screens.title_start_button.visible = true
	if screens.title_continue_button != null: screens.title_continue_button.visible = not screens.title_continue_button.disabled
	if screens.title_cursor_text != null: screens.title_cursor_text.visible = true
	screens.title_transition_active = false
	screens.pending_title_destination = ""
	screens.set_state(&"title")
	var focus_target := screens.title_continue_button if screens.title_continue_button != null and not screens.title_continue_button.disabled else screens.title_start_button
	if focus_target != null:
		focus_target.grab_focus()


func _enter_debug_gameplay(root: Object) -> void:
	var ssc := root.get("screen_state_controller") as ScreenStateController
	var title_overlay := ssc.title_overlay as CanvasItem
	var archetype_overlay := ssc.archetype_overlay as CanvasItem
	var loading_overlay := root.get("loading_screen_overlay") as CanvasItem
	if title_overlay != null: title_overlay.visible = false
	if archetype_overlay != null: archetype_overlay.visible = false
	if loading_overlay != null: loading_overlay.visible = false
	var ui := root.get("ui") as CanvasItem
	if ui != null: ui.visible = true
	(root.get("screen_state_controller") as ScreenStateController).set_state(&"gameplay")


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
	if profile != null:
		profile.ensure_starter_items()
		equipment.configure_from_profile(profile)
	var tuning := root.player_tuning
	var health := _ensure_player_component(player, HealthComponent, "Health") as HealthComponent
	health.set_process(false); health.regen_delay = tuning.regen_delay; health.regen_interval = tuning.regen_interval; health.regen_amount = tuning.regen_amount
	health.damaged.connect(Callable(root, "_on_player_health_damaged")); health.healed.connect(Callable(root, "_on_player_health_healed")); health.health_changed.connect(Callable(root, "_on_player_health_changed"))
	root.player_health_component = health
	var motor := _ensure_player_component(player, ActorMotor, "Motor") as ActorMotor; motor.motion_requested.connect(Callable(root, "_on_player_motor_motion")); root.player_motor = motor
	root.player_controller = _ensure_player_component(player, PlayerController, "Controller") as PlayerController; root.player_controller.configure_input_router(root.input_router); root.player_roll_component = _ensure_player_component(player, PlayerRollComponent, "Roll") as PlayerRollComponent; root.player_attack_component = _ensure_player_component(player, PlayerAttackComponent, "Attack") as PlayerAttackComponent; root.player_animation_component = _ensure_player_component(player, PlayerAnimationComponent, "Animation") as PlayerAnimationComponent
	var guard := _ensure_player_component(player, PlayerGuardComponent, "Guard") as PlayerGuardComponent; guard.initialize(root); root.player_guard_component = guard
	var transmutations := _ensure_player_component(player, EquipmentTransmutationComponent, "Transmutations") as EquipmentTransmutationComponent
	transmutations.configure(equipment); guard.successful_block.connect(Callable(transmutations, "record_successful_block")); guard.successful_block.connect(Callable(root, "_on_player_successful_block"))
	var attack := root.player_attack_component
	attack.attack_started.connect(Callable(transmutations, "begin_attack")); attack.attack_finished.connect(Callable(transmutations, "finish_attack")); attack.attack_hit_resolved.connect(Callable(transmutations, "record_attack_hits"))
	transmutations.effect_triggered.connect(Callable(root, "_on_transmutation_effect_triggered")); root.equipment_transmutation_component = transmutations; root._configure_equipment_transmutations()
	root.player_chroma_component = _ensure_player_component(player, PLAYER_CHROMA_COMPONENT_SCRIPT, "Chroma")
	root.player_aspect_ability_component = _ensure_player_component(player, PLAYER_ASPECT_ABILITY_COMPONENT_SCRIPT, "AspectAbility")
	root.player_aspect_ability_component.call("configure_mode_cooldowns", root.MAGIC_COOLDOWN, root.GREY_MAGIC_COOLDOWN)
	var equipment_visual := _ensure_player_component(player, PlayerEquipmentVisualComponent, "EquipmentVisual") as PlayerEquipmentVisualComponent
	equipment_visual.initialize(root); root.player_equipment_visual_component = equipment_visual
	root._set_target_ui_visible(false)
	var player_health: float = root._player_max_health(); health.maximum_health = player_health; health.reset(player_health); root.player_display_health = player_health; root._update_player_health_ui()
	root._update_player_mp_ui()


func _initialize_walkable_area(root: GameplayState, edge_margin: float, slime_edge_padding: float) -> void:
	root.use_walkable_polygon_direct = true; root._collect_walkable_tiles(root.floor_tiles); root._build_entrance_block_polygons(); root._build_walkable_outline()
	var area := root.walkable_area
	if area != null:
		area.set_geometry(root.walkable_polygons, root.walkable_outline); area.edge_margin = edge_margin; area.slime_edge_padding = slime_edge_padding; area.set_entrance_blocks(root.entrance_block_polygons)
	if root.walkable_outline.is_empty(): push_warning("No floor tiles found. Actor movement will be disabled.")


func _initialize_slimes(root: Object, slimes: Array[Sprite2D]) -> void:
	var rng := root.get("rng") as RandomNumberGenerator; var tuning := root.get("slime_tuning") as SlimeTuning
	for slime in slimes:
		var actor := slime as SlimeActor
		if actor != null: actor.reset_runtime_state(slime.position, root.call("_nearest_slime_walkable_point", root.call("_actor_foot", slime)), rng.randf_range(tuning.repath_min, tuning.repath_max), rng.randf_range(tuning.hold_min, tuning.hold_max), rng.randf_range(0.0, tuning.idle_breath_time), rng.randf_range(0.2, 0.6))
		root.call("_update_slime_attack_guides", slime); root.call("_apply_enemy_room_level", slime)
		var maximum := float(root.call("_enemy_max_health", slime)); var slime_actor := slime as SlimeActor
		if slime_actor != null: slime_actor.ensure_components()
		var health := root.call("_slime_health", slime) as HealthComponent
		if slime_actor != null: health = slime_actor.configure_health(maximum, tuning.regen_delay, tuning.regen_interval, tuning.regen_amount)
		health.damaged.connect(Callable(root, "_on_slime_health_damaged").bind(slime)); health.healed.connect(Callable(root, "_on_slime_health_healed").bind(slime)); health.health_changed.connect(Callable(root, "_on_slime_health_changed").bind(slime)); var presenter := root.call("_slime_health_presenter", slime) as SlimeHealthPresenter; presenter.display_health = maximum; presenter.damage_fill_hold_timer = 0.0


func _expand_slime_roster(root: Object, slimes: Array[Sprite2D]) -> void:
	var template := root.get("slime_blue") as Sprite2D
	if template == null:
		return
	var parent := template.get_parent()
	for slot in range(slimes.size(), SLIME_ROSTER_SIZE):
		var clone := template.duplicate() as Sprite2D
		clone.name = "SlimeSlot%d" % (slot + 1)
		clone.position = template.position
		parent.add_child(clone)
		slimes.append(clone)
