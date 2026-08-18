extends Node
class_name GameplayBootstrap


func initialize(root: Object) -> void:
	var has_active_profile := ProfileSaveService.has_profile_save()
	var has_profile := ProfileSaveService.has_any_profile_save()
	var profile := ProfileSaveService.load_profile()
	root.set("player_profile", profile)
	root.set("has_persistent_profile", has_profile)
	root.call("_apply_profile_to_runtime")
	root.set("gameplay_frame_controller", root.call("_add_runtime_node", GameplayFrameController, "GameplayFrameController"))
	var effects_tuning := root.get("effects_tuning") as EffectsTuning
	root.set("walkable_area", root.call("_add_runtime_node", WalkableArea, "WalkableArea"))
	root.set("actor_collision_system", root.call("_add_runtime_node", ActorCollisionSystem, "ActorCollisionSystem"))
	root.set("depth_sorter", root.call("_add_runtime_node", DepthSorter, "DepthSorter"))
	var occlusion := root.call("_add_runtime_node", OcclusionRenderer, "OcclusionRenderer") as OcclusionRenderer
	occlusion.resolution_scale = effects_tuning.resolution_scale; root.set("occlusion_renderer", occlusion)
	root.set("room_controller", root.call("_add_runtime_node", RoomController, "RoomController"))
	root.set("shadow_controller", root.call("_add_runtime_node", ShadowController, "ShadowController"))
	root.set("interaction_component", root.call("_add_runtime_node", InteractionComponent, "InteractionComponent"))
	root.set("chest_controller", root.call("_add_runtime_node", ChestController, "ChestController", root.get("chest")))
	root.set("npc_controller", root.call("_add_runtime_node", NpcController, "NpcController", root.get("cloaked_demon")))
	root.set("rest_fire_controller", root.call("_add_runtime_node", RestFireController, "RestFireController", root.get("rest_fire")))
	root.set("hud_controller", root.call("_add_runtime_node", HudController, "HudController", root.get("ui")))
	root.set("effects_spawner", root.call("_add_runtime_node", EffectsSpawner, "EffectsSpawner"))
	root.set("screen_state_controller", root.call("_add_runtime_node", ScreenStateController, "ScreenStateController"))
	var rng := root.get("rng") as RandomNumberGenerator
	rng.randomize()
	var run_state := RunState.new()
	root.set("run_state", run_state)
	var dungeon_graph := root.get("dungeon_graph") as DungeonGraph
	dungeon_graph.configure_progression(profile.completed_runs)
	var dungeon_seed := rng.randi()
	root.set("current_dungeon_seed", dungeon_seed)
	dungeon_graph.initialize(dungeon_seed)
	var initial_room_id := dungeon_graph.start_room_id
	if bool(root.get("debug_start_in_boss_room")):
		var boss_connection: DungeonGraph.ConnectionRecord = dungeon_graph.ensure_connection(
			dungeon_graph.start_room_id,
			DungeonGraph.WALL_RIGHT,
			DungeonGraph.ROOM_DOWNSTAIRS
		)
		initial_room_id = boss_connection.destination_room_id
	root.set("current_room_id", initial_room_id)
	root.call("_sync_current_room_metadata")
	(root.get("room_controller") as RoomController).set_current_room(root.get("current_room_id"), root.get("current_room_type"))
	root.call("_collect_dungeon_sockets"); (root.get("room_controller") as RoomController).validate_socket_setup(); root.call("_ensure_current_room_layout")
	var player := root.get("player") as Sprite2D; var chest := root.get("chest") as Sprite2D; var demon := root.get("cloaked_demon") as Sprite2D; var fire := root.get("rest_fire") as Sprite2D
	root.set("player_start_position", player.position); root.set("chest_start_position", chest.position); root.set("cloaked_demon_start_position", demon.position); root.set("chest_gray_texture", chest.texture); root.set("chest_normal_texture", root.call("_load_texture_or_null", "res://assets/artwork/Chest.png"))
	fire.visible = false; fire.frame = 0; root.call("_configure_room_sockets", false)
	var slimes: Array[Sprite2D] = [root.get("slime_blue"), root.get("slime_green"), root.get("slime_red")]; _expand_slime_roster(root, slimes); root.set("slimes", slimes)
	var actors: Array[Sprite2D] = [player]; actors.append_array(slimes); root.set("actor_sprites", actors)
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
	root.set("player_animation_component", root.call("_ensure_player_component", PlayerAnimationComponent, "Animation"))
	(root.get("player_animation_component") as PlayerAnimationComponent).build_frames(root); root.call("_build_rest_fire_frames"); root.call("_build_cloaked_demon_frames"); root.call("_build_player_sprite_shadow"); root.call("_build_cloaked_demon_sprite_shadow"); root.call("_build_slime_direction_textures"); root.call("_build_slime_attack_frames"); root.call("_build_slime_shocked_frames"); root.call("_build_enemy_health_ui"); root.call("_build_interact_prompt"); root.call("_build_npc_dialogue"); root.call("_build_room_number_indicator"); root.call("_build_game_over_ui"); root.call("_build_run_complete_ui"); root.call("_build_title_screen"); root.call("_build_hub_ui"); root.call("_build_scene_transition"); root.call("_build_loading_screen")
	(root.get("screen_state_controller") as ScreenStateController).set_state(&"title")
	_initialize_player(root, player)
	_initialize_walkable_area(root, root.get("EDGE_MARGIN") if root.get("EDGE_MARGIN") != null else 0.35, root.get("SLIME_EDGE_PADDING") if root.get("SLIME_EDGE_PADDING") != null else 3.0)
	_initialize_slimes(root, slimes)
	root.call("_apply_room_state"); root.call("_build_depth_lists")
	if bool(root.get("debug_start_in_boss_room")):
		root.call("_begin_new_run")
		_enter_debug_gameplay(root)
	else:
		var route := profile.pending_route
		profile.pending_route = "title"
		profile.open_hub_on_load = false
		if has_active_profile: root.call("_save_player_profile")
		if (route == "hub" or route == "run") and profile.has_started:
			root.call_deferred("_enter_starting_room_from_menu")


func _enter_debug_gameplay(root: Object) -> void:
	var title_overlay := root.get("title_overlay") as CanvasItem
	var archetype_overlay := root.get("archetype_overlay") as CanvasItem
	var loading_overlay := root.get("loading_screen_overlay") as CanvasItem
	if title_overlay != null: title_overlay.visible = false
	if archetype_overlay != null: archetype_overlay.visible = false
	if loading_overlay != null: loading_overlay.visible = false
	var ui := root.get("ui") as CanvasItem
	if ui != null: ui.visible = true
	(root.get("screen_state_controller") as ScreenStateController).set_state(&"gameplay")


func _initialize_player(root: Object, player: Sprite2D) -> void:
	var equipment := player.get_node_or_null(^"Equipment") as EquipmentComponent
	if equipment == null:
		equipment = root.call("_ensure_player_component", EquipmentComponent, "Equipment") as EquipmentComponent; equipment.equip_default_loadout()
	root.set("player_equipment", equipment)
	var profile := root.get("player_profile") as PlayerProfile
	if profile != null:
		profile.ensure_starter_items()
		equipment.configure_from_profile(profile)
	var tuning := root.get("player_tuning") as PlayerTuning
	var health := root.call("_ensure_player_component", HealthComponent, "Health") as HealthComponent
	health.set_process(false); health.regen_delay = tuning.regen_delay; health.regen_interval = tuning.regen_interval; health.regen_amount = tuning.regen_amount
	health.damaged.connect(Callable(root, "_on_player_health_damaged")); health.healed.connect(Callable(root, "_on_player_health_healed")); health.health_changed.connect(Callable(root, "_on_player_health_changed")); root.set("player_health_component", health)
	var motor := root.call("_ensure_player_component", ActorMotor, "Motor") as ActorMotor; motor.motion_requested.connect(Callable(root, "_on_player_motor_motion")); root.set("player_motor", motor)
	root.set("player_controller", root.call("_ensure_player_component", PlayerController, "Controller")); root.set("player_roll_component", root.call("_ensure_player_component", PlayerRollComponent, "Roll")); root.set("player_attack_component", root.call("_ensure_player_component", PlayerAttackComponent, "Attack")); root.set("player_animation_component", root.call("_ensure_player_component", PlayerAnimationComponent, "Animation"))
	var guard := root.call("_ensure_player_component", PlayerGuardComponent, "Guard") as PlayerGuardComponent; guard.initialize(root); root.set("player_guard_component", guard)
	var transmutations := root.call("_ensure_player_component", EquipmentTransmutationComponent, "Transmutations") as EquipmentTransmutationComponent
	transmutations.configure(equipment); guard.successful_block.connect(Callable(transmutations, "record_successful_block")); guard.successful_block.connect(Callable(root, "_on_player_successful_block"))
	var attack := root.get("player_attack_component") as PlayerAttackComponent
	attack.attack_started.connect(Callable(transmutations, "begin_attack")); attack.attack_finished.connect(Callable(transmutations, "finish_attack")); attack.attack_hit_resolved.connect(Callable(transmutations, "record_attack_hits"))
	transmutations.effect_triggered.connect(Callable(root, "_on_transmutation_effect_triggered")); root.set("equipment_transmutation_component", transmutations); root.call("_configure_equipment_transmutations")
	var equipment_visual := root.call("_ensure_player_component", PlayerEquipmentVisualComponent, "EquipmentVisual") as PlayerEquipmentVisualComponent
	equipment_visual.initialize(root); root.set("player_equipment_visual_component", equipment_visual)
	root.call("_set_target_ui_visible", false)
	var player_health := float(root.call("_player_max_health")); health.maximum_health = player_health; health.reset(player_health); root.set("player_display_health", player_health); root.call("_update_player_health_ui")


func _initialize_walkable_area(root: Object, edge_margin: float, slime_edge_padding: float) -> void:
	root.set("use_walkable_polygon_direct", true); root.call("_collect_walkable_tiles", root.get("floor_tiles")); root.call("_build_entrance_block_polygons"); root.call("_build_walkable_outline")
	var area := root.get("walkable_area") as WalkableArea
	if area != null:
		area.set_geometry(root.get("walkable_polygons"), root.get("walkable_outline")); area.edge_margin = edge_margin; area.slime_edge_padding = slime_edge_padding; area.set_entrance_blocks(root.get("entrance_block_polygons"))
	if (root.get("walkable_outline") as PackedVector2Array).is_empty(): push_warning("No floor tiles found. Actor movement will be disabled.")


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
	for slot in range(slimes.size(), 7):
		var clone := template.duplicate() as Sprite2D
		clone.name = "SlimeSlot%d" % (slot + 1)
		clone.position = template.position
		parent.add_child(clone)
		slimes.append(clone)
