extends RefCounted
class_name RuntimeServiceRegistrationPlan

# Owner: GameplayBootstrap
# Responsibility: declare and validate ordered runtime-service registration cohorts.

const PROFILE_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/profile_runtime_controller.gd")
const PICKUP_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/pickup_runtime_controller.gd")
const RUN_FLOW_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/run_flow_controller.gd")
const DUNGEON_MAP_CONTROLLER_SCRIPT = preload("res://scripts/ui/dungeon_map_controller.gd")
const HUB_FLOW_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/hub_flow_controller.gd")
const SAVE_FLOW_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/save_flow_controller.gd")
const CLOUD_SAVE_SERVICE_SCRIPT = preload("res://scripts/services/cloud_save_service.gd")
const CLOUD_SAVE_PANEL_SCRIPT = preload("res://scripts/ui/cloud_save_panel.gd")
const ROOM_PUZZLE_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/room_puzzle_controller.gd")
const MAGIC_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/magic_runtime_controller.gd")
const TARGETING_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/targeting_runtime_controller.gd")
const COMBAT_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/combat_runtime_controller.gd")
const SLIME_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/slime_runtime_controller.gd")
const ACTOR_PRESENTATION_RUNTIME_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/actor_presentation_runtime_controller.gd")
const ROOM_PREFAB_HOST_SCRIPT = preload("res://scripts/runtime/controllers/room_prefab_host.gd")
const DUNGEON_MINIMAP_CONTROLLER_SCRIPT = preload("res://scripts/ui/dungeon_minimap_controller.gd")
const GOLD_PICKUP_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/gold_pickup_controller.gd")
const SOUL_PICKUP_CONTROLLER_SCRIPT = preload("res://scripts/runtime/controllers/soul_pickup_controller.gd")

## GameplayBootstrap-owned declarations and validation for ordered runtime services.
class Row:
	extends RefCounted

	var node_name: StringName
	var service_script: Script
	var parent: Node
	var dependencies: Array[StringName] = []
	var configure_callable: Callable

	func _init(
		registered_name: StringName,
		registered_script: Script,
		registered_parent: Node,
		registered_dependencies: Array[StringName] = [],
		registered_configure_callable: Callable = Callable()
	) -> void:
		node_name = registered_name
		service_script = registered_script
		parent = registered_parent
		dependencies = registered_dependencies.duplicate()
		configure_callable = registered_configure_callable


## This bounded cohort proves that actual registrations can be checked as rows.
## Configuration remains at the call site so its existing typed setup order is
## visible and unchanged.
static func early_service_registrations(root: Node) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(
		&"SettingsService",
		SettingsService,
		root,
		[],
		func(service: Node) -> void:
			var gameplay := root as GameplayState
			if gameplay == null:
				return
			gameplay.settings_service = service as SettingsService
			gameplay.settings_service.load_settings()
	))
	registrations.append(Row.new(
		&"DisplayController",
		DisplayController,
		root,
		[&"SettingsService"],
		func(service: Node) -> void:
			var gameplay := root as GameplayState
			if gameplay == null:
				return
			gameplay.display_controller = service as DisplayController
			gameplay.display_controller.initialize(gameplay, gameplay.settings_service)
	))
	registrations.append(Row.new(
		&"InputRouter",
		InputRouter,
		root,
		[],
		func(service: Node) -> void:
			var gameplay := root as GameplayState
			if gameplay == null:
				return
			gameplay.input_router = service as InputRouter
	))
	registrations.append(Row.new(&"InputDeviceTracker", preload("res://scripts/services/input_device_tracker.gd"), root))
	registrations.append(Row.new(&"TouchControlsLayer", preload("res://scripts/ui/touch_controls_layer.gd"), root, [&"InputRouter", &"InputDeviceTracker"]))
	registrations.append(Row.new(&"DebugSessionController", DebugSessionController, root))
	return registrations


## Keeps the next contiguous GameplayBootstrap creation block in its original
## sibling order while making each service's parent, script, prerequisite, and
## root binding part of the registration declaration.
static func gameplay_service_registrations(root: GameplayState) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(
		&"ProfileRuntimeController",
		PROFILE_RUNTIME_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.profile_runtime_controller = service
	))
	registrations.append(Row.new(
		&"PickupRuntimeController",
		PICKUP_RUNTIME_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.pickup_runtime_controller = service as PickupRuntimeController
	))
	registrations.append(Row.new(
		&"RunFlowController",
		RUN_FLOW_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.run_flow_controller = service as RunFlowController
	))
	registrations.append(Row.new(
		&"DungeonMapController",
		DUNGEON_MAP_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.dungeon_map_controller = service as DungeonMapController
	))
	registrations.append(Row.new(
		&"HubFlowController",
		HUB_FLOW_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.hub_flow_controller = service
	))
	registrations.append(Row.new(
		&"SaveFlowController",
		SAVE_FLOW_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.save_flow_controller = service
	))
	registrations.append(Row.new(
		&"CloudSaveService",
		CLOUD_SAVE_SERVICE_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.cloud_save_service = service as CloudSaveService
	))
	registrations.append(Row.new(
		&"CloudSavePanel",
		CLOUD_SAVE_PANEL_SCRIPT,
		root,
		[&"CloudSaveService"],
		func(service: Node) -> void:
			root.cloud_save_panel = service as CloudSavePanel
			root.cloud_save_panel.configure(root, root.cloud_save_service)
	))
	registrations.append(Row.new(
		&"RoomPuzzleController",
		ROOM_PUZZLE_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.room_puzzle_controller = service
	))
	registrations.append(Row.new(
		&"MagicRuntimeController",
		MAGIC_RUNTIME_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.magic_runtime_controller = service as MagicRuntimeController
	))
	registrations.append(Row.new(
		&"TargetingRuntimeController",
		TARGETING_RUNTIME_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.targeting_runtime_controller = service
	))
	registrations.append(Row.new(
		&"CombatRuntimeController",
		COMBAT_RUNTIME_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.combat_runtime_controller = service
	))
	registrations.append(Row.new(
		&"SlimeRuntimeController",
		SLIME_RUNTIME_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.slime_runtime_controller = service
	))
	registrations.append(Row.new(
		&"ActorPresentationRuntimeController",
		ACTOR_PRESENTATION_RUNTIME_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.actor_presentation_runtime_controller = service
	))
	return registrations


## Declares the adjacent world-support cohort at the point where it is built.
## Setup callbacks preserve the debug-drawer and occlusion configuration that
## previously ran immediately after each add_child call.
static func world_service_registrations(root: GameplayState) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(
		&"WalkableArea",
		WalkableArea,
		root,
		[],
		func(service: Node) -> void:
			root.walkable_area = service as WalkableArea
	))
	registrations.append(Row.new(
		&"ActorCollisionSystem",
		ActorCollisionSystem,
		root,
		[],
		func(service: Node) -> void:
			root.actor_collision_system = service as ActorCollisionSystem
	))
	registrations.append(Row.new(
		&"ActorGeometryDebugDrawer",
		ActorGeometryDebugDrawer,
		root,
		[],
		func(service: Node) -> void:
			var geometry_debug := service as ActorGeometryDebugDrawer
			geometry_debug.enabled = root.debug_actor_geometry
			geometry_debug.z_as_relative = false
			geometry_debug.z_index = 4096
			root.actor_geometry_debug_drawer = geometry_debug
	))
	registrations.append(Row.new(
		&"DepthSorter",
		DepthSorter,
		root,
		[],
		func(service: Node) -> void:
			root.depth_sorter = service as DepthSorter
	))
	registrations.append(Row.new(
		&"OcclusionRenderer",
		OcclusionRenderer,
		root,
		[],
		func(service: Node) -> void:
			var occlusion := service as OcclusionRenderer
			# Web keeps the same visuals but uses the lowest exact-pixel occlusion
			# pass; desktop keeps the inspector-selected scale unchanged.
			occlusion.resolution_scale = 1 if OS.has_feature("web") else root.effects_tuning.resolution_scale
			root.occlusion_renderer = occlusion
	))
	registrations.append(Row.new(
		&"RoomPrefabHost",
		ROOM_PREFAB_HOST_SCRIPT,
		root.map_root,
		[],
		func(service: Node) -> void:
			if root.hub_stone_accent_layer == null:
				return
			var accent_index := root.map_root.get_children().find(root.hub_stone_accent_layer)
			if accent_index >= 0:
				root.map_root.move_child(service, accent_index)
	))
	registrations.append(Row.new(
		&"RoomController",
		RoomController,
		root,
		[],
		func(service: Node) -> void:
			root.room_controller = service as RoomController
			root.room_controller.configure_geometry(
				root.floor_tiles.get_parent() as Node2D,
				root.floor_tiles,
				root.player,
				root.display_controller,
				root.scene_file_path)
			if root.hub_stone_accent_layer != null:
				root.room_controller.room_entered.connect(
					Callable(root.hub_stone_accent_layer, "on_room_entered"))
			root.room_controller.room_cleared.connect(
				Callable(root.dungeon_map_controller, "on_room_completed_result"))
			root.room_controller.room_cleared.connect(
				Callable(root, "_on_room_cleared_for_checkpoint"))
	))
	return registrations


## Preserves the actor/service attach order and the chest's immediate reward
## boundary setup. NPC status components are configured by GameplayBootstrap
## immediately after this cohort returns, as before.
static func actor_service_registrations(root: GameplayState) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(
		&"ShadowController",
		ShadowController,
		root,
		[],
		func(service: Node) -> void:
			root.shadow_controller = service as ShadowController
	))
	registrations.append(Row.new(
		&"InteractionComponent",
		InteractionComponent,
		root,
		[],
		func(service: Node) -> void:
			root.interaction_component = service as InteractionComponent
	))
	registrations.append(Row.new(
		&"ChestController",
		ChestController,
		root.chest,
		[],
		func(service: Node) -> void:
			root.chest_controller = service as ChestController
			root.chest_controller.configure_reward_boundary(
				root.run_flow_controller,
				root.room_controller,
				root.pickup_runtime_controller)
	))
	registrations.append(Row.new(
		&"NpcController",
		NpcController,
		root.cloaked_demon,
		[],
		func(service: Node) -> void:
			root.npc_controller = service as NpcController
	))
	return registrations


## Declares the presentation/acquisition cohort in its existing order. Each
## configuration callback runs before the next row is attached so downstream
## effect delivery and pickup ownership are ready before gameplay starts.
static func gameplay_ui_service_registrations(root: GameplayState) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(
		&"RestFireController",
		RestFireController,
		root.rest_fire,
		[],
		func(service: Node) -> void:
			root.rest_fire_controller = service as RestFireController
	))
	registrations.append(Row.new(
		&"HudController",
		HudController,
		root.ui,
		[],
		func(service: Node) -> void:
			root.hud_controller = service as HudController
			root.hud_controller.feedback_animation_registry = root.feedback_animation_registry
	))
	registrations.append(Row.new(
		&"DungeonMinimapController",
		DUNGEON_MINIMAP_CONTROLLER_SCRIPT,
		root.ui,
		[],
		func(service: Node) -> void:
			root.dungeon_minimap_controller = service
	))
	registrations.append(Row.new(
		&"SoundManager",
		SoundManager,
		root,
		[],
		func(service: Node) -> void:
			root.sound_manager = service as SoundManager
			root.sound_manager.configure_settings(root.settings_service)
	))
	registrations.append(Row.new(
		&"EffectsSpawner",
		EffectsSpawner,
		root,
		[],
		func(service: Node) -> void:
			root.effects_spawner = service as EffectsSpawner
			root.effects_spawner.configure_item_acquisition_delivery(
				root.ui,
				root.hud_controller,
				root.feedback_animation_registry,
				root.screen_state_controller,
				root.dungeon_minimap_controller,
				Callable(root, "_play_sound"))
			root.pickup_runtime_controller.configure_acquisition_presentation(
				Callable(root.effects_spawner, "spawn_pickup_acquisition_delivery"))
	))
	registrations.append(Row.new(
		&"GoldPickupController",
		GOLD_PICKUP_CONTROLLER_SCRIPT,
		root.pickup_runtime_controller,
		[],
		func(service: Node) -> void:
			root.pickup_runtime_controller.gold_pickup_controller = service as GoldPickupController
	))
	registrations.append(Row.new(
		&"MagicProjectileController",
		MagicProjectileController,
		root,
		[],
		func(service: Node) -> void:
			root.magic_projectile_controller = service as MagicProjectileController
	))
	registrations.append(Row.new(
		&"ChromaPickupController",
		ChromaPickupController,
		root,
		[],
		func(service: Node) -> void:
			root.chroma_pickup_controller = service as ChromaPickupController
	))
	registrations.append(Row.new(
		&"SoulPickupController",
		SOUL_PICKUP_CONTROLLER_SCRIPT,
		root,
		[],
		func(service: Node) -> void:
			root.soul_pickup_controller = service as SoulPickupController
	))
	return registrations


## Keeps screen state attachment before profile application, with the frame
## controller registered immediately after that application as in the bootstrap.
static func screen_state_service_registrations(root: GameplayState) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(
		&"ScreenStateController",
		ScreenStateController,
		root,
		[],
		func(service: Node) -> void:
			root.screen_state_controller = service as ScreenStateController
	))
	return registrations


static func gameplay_frame_service_registrations(root: GameplayState) -> Array[Row]:
	var registrations: Array[Row] = []
	registrations.append(Row.new(
		&"GameplayFrameController",
		GameplayFrameController,
		root,
		[],
		func(service: Node) -> void:
			root.gameplay_frame_controller = service as GameplayFrameController
	))
	return registrations


static func row_for(registrations: Array[Row], node_name: StringName) -> Row:
	for registration in registrations:
		if registration.node_name == node_name:
			return registration
	return null


## Instantiates each validated row in order, running its optional setup callback
## before creating the next sibling so setup-sensitive boot order is preserved.
static func register_all(registrations: Array[Row]) -> Array[String]:
	var errors := registration_errors(registrations)
	if not errors.is_empty():
		return errors
	for registration in registrations:
		var node := registration.service_script.new() as Node
		if node == null:
			errors.append("%s script did not instantiate a Node" % registration.node_name)
			return errors
		node.name = registration.node_name
		registration.parent.add_child(node)
		if registration.configure_callable.is_valid():
			registration.configure_callable.call(node)
	return live_registration_errors(registrations)


## Rejects incomplete, duplicate, or forward references in the declared rows.
static func registration_errors(registrations: Array[Row]) -> Array[String]:
	var errors: Array[String] = []
	var positions: Dictionary = {}
	for index in registrations.size():
		var registration := registrations[index]
		if registration.node_name.is_empty():
			errors.append("service row %d has an empty name" % index)
			continue
		if positions.has(registration.node_name):
			errors.append("duplicate service %s" % registration.node_name)
		else:
			positions[registration.node_name] = index
		if registration.service_script == null:
			errors.append("service %s has no script" % registration.node_name)
		if registration.parent == null:
			errors.append("service %s has no parent" % registration.node_name)
	for index in registrations.size():
		var registration := registrations[index]
		var seen_dependencies: Dictionary = {}
		for dependency: StringName in registration.dependencies:
			if seen_dependencies.has(dependency):
				errors.append("%s repeats dependency %s" % [registration.node_name, dependency])
				continue
			seen_dependencies[dependency] = true
			if not positions.has(dependency):
				errors.append("%s requires missing service %s" % [registration.node_name, dependency])
			elif int(positions[dependency]) >= index:
				errors.append("%s requires %s to be registered earlier" % [registration.node_name, dependency])
	return errors


## Checks row metadata against live nodes, parents, scripts, and prerequisite
## order after the cohort has been attached to the scene tree.
static func live_registration_errors(registrations: Array[Row]) -> Array[String]:
	var errors := registration_errors(registrations)
	if not errors.is_empty():
		return errors
	var live_nodes: Dictionary = {}
	for registration in registrations:
		var node := registration.parent.get_node_or_null(NodePath(String(registration.node_name)))
		if node == null:
			errors.append("%s is not registered under its declared parent" % registration.node_name)
			continue
		if node.get_parent() != registration.parent:
			errors.append("%s has an unexpected parent" % registration.node_name)
		if node.get_script() != registration.service_script:
			errors.append("%s has an unexpected script" % registration.node_name)
		live_nodes[registration.node_name] = node
	for registration in registrations:
		if not live_nodes.has(registration.node_name):
			continue
		var node := live_nodes[registration.node_name] as Node
		for dependency: StringName in registration.dependencies:
			if not live_nodes.has(dependency):
				continue
			var dependency_row := row_for(registrations, dependency)
			if dependency_row.parent != registration.parent:
				errors.append("%s and prerequisite %s must share a parent for ordered registration" % [registration.node_name, dependency])
				continue
			var dependency_node := live_nodes[dependency] as Node
			if dependency_node.get_index() >= node.get_index():
				errors.append("%s was registered before prerequisite %s" % [registration.node_name, dependency])
	return errors
