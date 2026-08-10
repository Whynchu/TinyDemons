extends Node2D
const SLIME_ATTACK_FRAME_SIZE := Vector2i(16, 16)
const EDGE_MARGIN := 0.35
const SLIME_EDGE_PADDING := 3.0
const ACTOR_FOOT_OFFSET := Vector2(8, 15)
const DEPTH_Z_SCALE := 10.0
const OVERWORLD_UI_Z := 4090
const VERTICAL_MOVEMENT_SCALE := 0.5
const PLAYER_FRAME_SIZE := Vector2i(36, 36)
const PLAYER_ATTACK_FRAME_SIZE := Vector2i(36, 36)
const ROLL_DUST_FRAME_SIZE := Vector2i(16, 16)
const GAME_OVER_FADE_TIME := 0.8
const PLAYER_TEXTURE_OFFSET := Vector2(-10, -10)
const CHEST_INTERACT_DISTANCE := 16.0
const NPC_INTERACT_DISTANCE := 24.0
const CHEST_REWARD_GOLD := 100
const INTERACT_PROMPT_BOB_TIME := 0.8
const CHEST_COLLECT_FLASH_TIME := 0.12
const CHEST_UNLOCK_FADE_TIME := 0.45
const CHEST_EVAPORATE_PARTICLE_COUNT := 34
const CHEST_EVAPORATE_LIFETIME_MIN := 0.45
const CHEST_EVAPORATE_LIFETIME_MAX := 0.9
const FIRE_FRAME_TIME := 0.16
const FIRE_FRAME_SIZE := Vector2i(16, 16)
const CLOAKED_DEMON_FRAME_SIZE := Vector2i(36, 36)
const NPC_DIALOGUE_TIME := 3.2
const NPC_DIALOGUE_BUTTON_BOB_TIME := 1.6
const PLAYER_DOOR_FOOT_COLLIDER_SIZE := Vector2(3, 3)
const ACTOR_COLLISION_WIDTH := 9.0
const ACTOR_COLLISION_HEIGHT := 4.0
const ACTOR_CONTACT_RADIUS := 3.6
const CHEST_COLLISION_SIZE := Vector2(11, 6)
const SLIME_WEIGHT := 1.45
const PLAYER_WEIGHT := 1.0
const TARGET_LOCK_MAX_DISTANCE := 9999.0
const OCCLUSION_RELEASE_GRACE := 0.08
const CONTROLLER_DEADZONE := 0.25
const CONTROLLER_TRIGGER_DEADZONE := 0.35
const OCCLUDER_PATHS: Array[NodePath] = [
	^"Actors/Chest",
]
@onready var floor_tiles: Node2D = $Map/FloorTiles
@onready var ui: Node2D = $UI
@onready var player: Sprite2D = $Actors/TinyDemon
@onready var player_attack_visual: Sprite2D = $Actors/TinyDemonAttack
@onready var player_shadow: Sprite2D = $Actors/TinyDemonShadow
@onready var cloaked_demon_shadow: Sprite2D = $Actors/CloakedDemonShadow
@onready var slime_blue: Sprite2D = $Actors/SlimeBlue
@onready var slime_green: Sprite2D = $Actors/SlimeGreen
@onready var slime_red: Sprite2D = $Actors/SlimeRed
@onready var sockets_root: Node2D = $Map/Sockets
@onready var hp_overhead: Sprite2D = $Actors/SlimeGreen/HpOverhead
@onready var hp_overhead_fill: Sprite2D = $Actors/SlimeGreen/HpOverheadFill
@onready var chest: Sprite2D = $Actors/Chest
@onready var rest_fire: Sprite2D = $Actors/RestFire
@onready var rest_fire_depth_marker: Marker2D = $Actors/RestFire/DepthMarker
@onready var cloaked_demon: Sprite2D = $Actors/CloakedDemon
@onready var cloaked_demon_depth_marker: Marker2D = $Actors/CloakedDemon/DepthMarker
@onready var target_name_text: Sprite2D = $UI/SlimeText
@onready var target_health_bar: Sprite2D = $UI/EnemyHp
@onready var target_health_fill: Sprite2D = $UI/EnemyHpFill
@onready var player_health_fill: Sprite2D = $UI/HpBarFill
@onready var player_stats: StatsComponent = $Actors/TinyDemon/Stats
var player_equipment: EquipmentComponent = null
var player_health_component: HealthComponent = null
var player_motor: ActorMotor = null
var player_controller: PlayerController = null
var player_roll_component: PlayerRollComponent = null
var player_attack_component: PlayerAttackComponent = null
var player_animation_component: PlayerAnimationComponent = null
var walkable_area: WalkableArea = null
var actor_collision_system: ActorCollisionSystem = null
var depth_sorter: DepthSorter = null
var occlusion_renderer: OcclusionRenderer = null
var room_controller: RoomController = null
var shadow_controller: ShadowController = null
var interaction_component: InteractionComponent = null
var chest_controller: ChestController = null
var npc_controller: NpcController = null
var rest_fire_controller: RestFireController = null
var hud_controller: HudController = null
var effects_spawner: EffectsSpawner = null
var screen_state_controller: ScreenStateController = null
var player_idle_frames: Array[Texture2D] = []
var player_walk_frames: Array[Texture2D] = []
var player_attack_frames: Array[Texture2D] = []
var player_attack2_frames: Array[Texture2D] = []
var player_attack_left_frames: Array[Texture2D] = []
var player_attack2_left_frames: Array[Texture2D] = []
var player_between_attack_texture: Texture2D = null
var player_after_attack2_texture: Texture2D = null
var player_just_finished_attack2 := false
var player_between_timer := 0.0
var player_anim_name := "idle"
var player_anim_frame := 0
var player_anim_timer := 0.0
var player_is_moving := false
var player_is_attacking := false
var player_is_rolling := false
var player_roll_frames: Array[Texture2D] = []
var roll_dust_spawned_this_roll := false
var player_roll_input_was_down := false
var roll_dust_frames: Array[Texture2D] = []
var roll_dust_flipped_frames: Array[Texture2D] = []
var player_attack_input_was_down := false
var player_attack_hit_done := false
var player_attack_hit_targets: Array[Sprite2D] = []
var player_attack_flip_h := false
var player_hit_flash_timer := 0.0
var player_hitstun_timer := 0.0
var walkable_points: Array[Vector2] = []
var walkable_polygons: Array[PackedVector2Array] = []
var walkable_outline: PackedVector2Array = PackedVector2Array()
var entrance_block_polygons: Array[PackedVector2Array] = []
var use_walkable_polygon_direct := false
var slimes: Array[Sprite2D] = []
var depth_sprites: Array[Sprite2D] = []
var actor_sprites: Array[Sprite2D] = []
var collision_sprites: Array[Sprite2D] = []
var occluder_sprites: Array[Sprite2D] = []
var player_shadow_offset := Vector2.ZERO
var player_shadow_scale := Vector2.ONE
var cloaked_demon_shadow_offset := Vector2.ZERO
var cloaked_demon_shadow_scale := Vector2.ONE
var player_sprite_shadow: Sprite2D = null
var cloaked_demon_sprite_shadow: Sprite2D = null
var current_target: Sprite2D = null
var target_input_was_down := false
var player_health := 0.0
var player_death_pending := false
var player_dead := false
var player_death_timer := 0.0
var player_death_particles_started := false
var hitstop_timer := 0.0
var player_death_overlay: Sprite2D = null
var player_death_origin := Vector2.ZERO
var player_death_offset := Vector2.ZERO
var player_death_scale := Vector2.ONE
var player_death_texture: Texture2D = null
var game_over_overlay: ColorRect = null
var game_over_button: Button = null
var game_over_title_button: Button = null
var game_over_fade_timer := 0.0
var title_overlay: ColorRect = null
var title_start_button: Button = null
var title_frame_timer := 0.0
var title_screen_text: Sprite2D = null
var title_start_text: Sprite2D = null
var title_transition_active := false
var title_transition_timer := 0.0
var title_particle_layer: Node2D = null
var archetype_overlay: ColorRect = null
var archetype_hold_cover: ColorRect = null
var archetype_preview: Sprite2D = null
var archetype_name_text: Sprite2D = null
var archetype_start_button: Button = null
var archetype_left_buttons: Array[Button] = []
var archetype_right_buttons: Array[Button] = []
var archetype_type_left_button: Button = null
var archetype_type_right_button: Button = null
var archetype_frame_timer := 0.0
var archetype_index := 0
var archetype_color_index := 0
var archetype_menu_row := 0
var archetype_transition_active := false
var archetype_transition_timer := 0.0
var archetype_fade_out := false
var archetype_arrow_anim_timer := 0.0
var archetype_arrow_anim_direction := 0
var selected_archetype := StatsComponent.AllocationProfile.BALANCED
var player_palette_name := "blue"
var player_base_idle_frames: Array[Texture2D] = []
var player_base_walk_frames: Array[Texture2D] = []
var player_base_roll_frames: Array[Texture2D] = []
var player_base_attack_frames: Array[Texture2D] = []
var player_base_attack2_frames: Array[Texture2D] = []
var player_base_attack_left_frames: Array[Texture2D] = []
var player_base_attack2_left_frames: Array[Texture2D] = []
var player_base_between_attack_texture: Texture2D = null
var player_base_after_attack2_texture: Texture2D = null
var player_base_health_fill_texture: Texture2D = null
var scene_transition_overlay: ColorRect = null
var scene_transition_timer := 0.0
var scene_transition_active := false
var loading_screen_overlay: ColorRect = null
var loading_screen_text: Sprite2D = null
var loading_screen_active := false
var loading_screen_fading := false
var loading_screen_timer := 0.0
var gold := 0
var interact_input_was_down := false
var chest_unlocked := false
var chest_claimed := false
var chest_collect_flash_timer := 0.0
var chest_evaporated := false
var door_active := false
var entrance_open := false
var dungeon_graph := DungeonGraph.new()
var current_room_id: StringName = DungeonGraph.START_ROOM_ID
var current_room_depth := 0
var current_room_display_number := 1
var current_room_type: StringName = DungeonGraph.ROOM_START
var room_transition_locked := false
var chest_normal_texture: Texture2D = null
var chest_gray_texture: Texture2D = null
var chest_unlock_overlay: Sprite2D = null
var chest_flash_overlay: Sprite2D = null
var interact_prompt: Sprite2D = null
var interact_prompt_base_position := Vector2.ZERO
var npc_dialogue_box: ColorRect = null
var npc_dialogue_text: Sprite2D = null
var npc_dialogue_button: Sprite2D = null
var npc_dialogue_button_shadow: Sprite2D = null
var npc_dialogue_layer: CanvasLayer = null
var npc_dialogue_input_was_down := false
var npc_dialogue_index := 0
var npc_dialogue_messages := ["GO ON", "TRUST YOUR PATH", "THE FIRE KNOWS", "YOU ARE CLOSE"]
var room_number_indicator: Sprite2D = null
var gold_indicator: Sprite2D = null
var gold_amount_indicator: Sprite2D = null
var gold_animation_frames: Array[Texture2D] = []
var gold_animation_timer := 0.0
var button_hud_sprites: Array[Sprite2D] = []
var target_health_text: Sprite2D = null
var player_health_text: Sprite2D = null
var player_start_position := Vector2.ZERO
var chest_start_position := Vector2.ZERO
var cloaked_demon_start_position := Vector2.ZERO
var target_health_damage_fill: Sprite2D = null
var target_health_bar_size := Vector2.ZERO
var player_health_fill_size := Vector2.ZERO
var player_health_damage_fill: Sprite2D = null
var player_display_health := 0.0
var player_damage_fill_hold_timer := 0.0
var rest_fire_frames: Array[Texture2D] = []
var cloaked_demon_idle_frames: Array[Texture2D] = []
var cloaked_demon_walk_frames: Array[Texture2D] = []
var cloaked_demon_animation_timer := 0.0
var cloaked_demon_animation_frame := 0
var cloaked_demon_wander_timer := 0.0
var cloaked_demon_wander_origin := Vector2.ZERO
var cloaked_demon_patrol_direction := -1.0
var cloaked_demon_patrol_paused := false
var cloaked_demon_patrol_pause_timer := 0.0
var cloaked_demon_patrol_position_x := 0.0
var cloaked_demon_patrol_min_x := 0.0
var cloaked_demon_patrol_max_x := 0.0
var cloaked_demon_wander_target := Vector2.ZERO
var cloaked_demon_wander_has_target := false
var cloaked_demon_visual_bounds := Rect2(12, 10, 12, 16)
var rng := RandomNumberGenerator.new()
var sprite_frame_library := SpriteFrameLibrary.new()
var combat_tuning := CombatTuning.new()
var player_tuning := PlayerTuning.new()
var slime_tuning := SlimeTuning.new()
var effects_tuning := EffectsTuning.new()
var last_damage_was_critical := false
func _add_runtime_node(script: Script, node_name: StringName, parent: Node = self) -> Node:
	var node := script.new() as Node
	node.name = node_name
	parent.add_child(node)
	return node
func _ensure_player_component(script: Script, node_name: StringName) -> Node:
	var component := player.get_node_or_null(NodePath(node_name)) as Node
	if component == null:
		component = _add_runtime_node(script, node_name, player)
	return component
func _ready() -> void:
	walkable_area = _add_runtime_node(WalkableArea, "WalkableArea") as WalkableArea
	actor_collision_system = _add_runtime_node(ActorCollisionSystem, "ActorCollisionSystem") as ActorCollisionSystem
	depth_sorter = _add_runtime_node(DepthSorter, "DepthSorter") as DepthSorter
	occlusion_renderer = _add_runtime_node(OcclusionRenderer, "OcclusionRenderer") as OcclusionRenderer
	occlusion_renderer.resolution_scale = effects_tuning.resolution_scale
	room_controller = _add_runtime_node(RoomController, "RoomController") as RoomController
	shadow_controller = _add_runtime_node(ShadowController, "ShadowController") as ShadowController
	interaction_component = _add_runtime_node(InteractionComponent, "InteractionComponent") as InteractionComponent
	chest_controller = _add_runtime_node(ChestController, "ChestController", chest) as ChestController
	npc_controller = _add_runtime_node(NpcController, "NpcController", cloaked_demon) as NpcController
	rest_fire_controller = _add_runtime_node(RestFireController, "RestFireController", rest_fire) as RestFireController
	hud_controller = _add_runtime_node(HudController, "HudController", ui) as HudController
	effects_spawner = _add_runtime_node(EffectsSpawner, "EffectsSpawner") as EffectsSpawner
	screen_state_controller = _add_runtime_node(ScreenStateController, "ScreenStateController") as ScreenStateController
	rng.randomize()
	dungeon_graph.initialize(rng.randi())
	current_room_id = dungeon_graph.start_room_id
	_sync_current_room_metadata()
	room_controller.set_current_room(current_room_id, current_room_type)
	_collect_dungeon_sockets()
	_validate_dungeon_socket_setup()
	_ensure_current_room_layout()
	player_start_position = player.position
	chest_start_position = chest.position
	cloaked_demon_start_position = cloaked_demon.position
	chest_gray_texture = chest.texture
	chest_normal_texture = _load_texture_or_null("res://assets/artwork/Chest.png")
	rest_fire.visible = false
	rest_fire.frame = 0
	_configure_room_sockets(false)
	slimes.clear()
	slimes.append(slime_blue)
	slimes.append(slime_green)
	slimes.append(slime_red)
	actor_sprites.clear()
	actor_sprites.append(player)
	actor_sprites.append(slime_blue)
	actor_sprites.append(slime_green)
	actor_sprites.append(slime_red)
	collision_sprites.clear()
	collision_sprites.append(player)
	collision_sprites.append(slime_blue)
	collision_sprites.append(slime_green)
	collision_sprites.append(slime_red)
	collision_sprites.append(chest)
	actor_collision_system.set_actors(collision_sprites)
	depth_sorter.set_sprites(actor_sprites)
	occlusion_renderer.set_occluders(occluder_sprites)
	player_shadow_offset = player_shadow.global_position - player.global_position
	player_shadow_scale = player_shadow.global_scale
	player_shadow.z_as_relative = false
	cloaked_demon_shadow_offset = cloaked_demon_shadow.global_position - cloaked_demon.global_position
	cloaked_demon_shadow_scale = cloaked_demon_shadow.global_scale
	cloaked_demon_shadow.z_as_relative = false
	player_attack_visual.z_as_relative = false
	player_attack_visual.visible = false
	_hide_editor_only_guides()
	hp_overhead.z_as_relative = false
	hp_overhead_fill.z_as_relative = false
	target_health_bar_size = target_health_fill.texture.get_size()
	player_health_fill_size = player_health_fill.texture.get_size()
	_build_depth_lists()
	occlusion_renderer.register_sprites(actor_sprites, occluder_sprites)
	_build_player_animation_frames()
	_build_rest_fire_frames()
	_build_cloaked_demon_frames()
	_build_cloaked_demon_sprite_shadow()
	_build_slime_direction_textures()
	_build_slime_attack_frames()
	_build_enemy_health_ui()
	_build_interact_prompt()
	_build_npc_dialogue()
	_build_room_number_indicator()
	_build_game_over_ui()
	_build_title_screen()
	_build_scene_transition()
	_build_loading_screen()
	screen_state_controller.set_state(&"title")
	player_equipment = player.get_node_or_null(^"Equipment") as EquipmentComponent
	if player_equipment == null:
		player_equipment = _ensure_player_component(EquipmentComponent, "Equipment") as EquipmentComponent
		player_equipment.equip_default_loadout()
	player_health_component = _ensure_player_component(HealthComponent, "Health") as HealthComponent
	player_health_component.set_process(false)
	player_health_component.regen_delay = player_tuning.regen_delay
	player_health_component.regen_interval = player_tuning.regen_interval
	player_health_component.regen_amount = player_tuning.regen_amount
	player_health_component.damaged.connect(_on_player_health_damaged)
	player_health_component.healed.connect(_on_player_health_healed)
	player_health_component.health_changed.connect(_on_player_health_changed)
	player_motor = _ensure_player_component(ActorMotor, "Motor") as ActorMotor
	player_motor.motion_requested.connect(_on_player_motor_motion)
	player_controller = _ensure_player_component(PlayerController, "Controller") as PlayerController
	player_roll_component = _ensure_player_component(PlayerRollComponent, "Roll") as PlayerRollComponent
	player_attack_component = _ensure_player_component(PlayerAttackComponent, "Attack") as PlayerAttackComponent
	player_animation_component = _ensure_player_component(PlayerAnimationComponent, "Animation") as PlayerAnimationComponent
	_set_target_ui_visible(false)
	player_health = _player_max_health()
	player_health_component.maximum_health = player_health
	player_health_component.reset(player_health)
	player_display_health = player_health
	_update_player_health_ui()
	use_walkable_polygon_direct = true
	_collect_walkable_tiles(floor_tiles)
	_build_entrance_block_polygons()
	_build_walkable_outline()
	if walkable_area != null:
		walkable_area.set_geometry(walkable_polygons, walkable_outline)
		walkable_area.edge_margin = EDGE_MARGIN
		walkable_area.slime_edge_padding = SLIME_EDGE_PADDING
		walkable_area.set_entrance_blocks(entrance_block_polygons)
	if walkable_outline.is_empty():
		push_warning("No floor tiles found. Actor movement will be disabled.")
		return
	for slime in slimes:
		var actor_owner := slime as SlimeActor
		if actor_owner != null:
			actor_owner.reset_runtime_state(
				slime.position,
				_nearest_slime_walkable_point(_actor_foot(slime)),
				rng.randf_range(slime_tuning.repath_min, slime_tuning.repath_max),
				rng.randf_range(slime_tuning.hold_min, slime_tuning.hold_max),
				rng.randf_range(0.0, slime_tuning.idle_breath_time),
				rng.randf_range(0.2, 0.6)
			)
		_update_slime_attack_guides(slime)
		_apply_enemy_room_level(slime)
		var max_health := _enemy_max_health(slime)
		var slime_actor := slime as SlimeActor
		if slime_actor != null:
			slime_actor.ensure_components()
		var health_component := _slime_health(slime)
		if slime_actor != null:
			health_component = slime_actor.configure_health(
				max_health,
				slime_tuning.regen_delay,
				slime_tuning.regen_interval,
				slime_tuning.regen_amount
			)
		health_component.damaged.connect(_on_slime_health_damaged.bind(slime))
		health_component.healed.connect(_on_slime_health_healed.bind(slime))
		health_component.health_changed.connect(_on_slime_health_changed.bind(slime))
		_slime_health_presenter(slime).display_health = max_health
		_slime_health_presenter(slime).damage_fill_hold_timer = 0.0
	_apply_room_state()
	_build_depth_lists()
func _physics_process(delta: float) -> void:
	if player_attack_component != null:
		player_attack_component.tick_combo(delta)
		player_attack_component.tick_attack2_cooldown(delta)
	if walkable_outline.is_empty():
		return
	if scene_transition_active:
		scene_transition_timer += delta
		scene_transition_overlay.modulate.a = clampf(scene_transition_timer / 0.28, 0.0, 1.0)
		if scene_transition_timer >= 0.34:
			get_tree().reload_current_scene()
		return
	if title_transition_active or (title_overlay != null and title_overlay.visible) or (archetype_overlay != null and archetype_overlay.visible):
		_update_title_screen(delta)
		if title_transition_active and title_transition_timer < 0.72:
			return
		if not title_transition_active:
			return
	if loading_screen_active:
		_update_loading_screen(delta)
		return
	var dialogue_was_active := npc_dialogue_box != null and npc_dialogue_box.visible
	var player_input_locked := dialogue_was_active
	if dialogue_was_active:
		_update_npc_dialogue(delta)
		_update_npc_dialogue_input()
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(hitstop_timer - delta, 0.0)
		return
	if player_death_pending and not player_dead:
		_update_player_hit_reaction(delta)
		_update_damage_numbers(delta)
		if player_motor == null or not player_motor.is_in_knockback():
			_start_player_death()
		return
	if player_dead:
		_update_pixel_particles(delta)
		_update_player_death(delta)
		_update_damage_numbers(delta)
		if player_death_particles_started and player_death_timer >= player_tuning.death_particle_delay + player_tuning.death_particle_lifetime:
			_move_slimes(delta)
			_update_enemy_hit_flashes(delta)
			_update_enemy_health(delta)
		_update_depth_sorting()
		_update_actor_occlusion(delta)
		actor_collision_system.stabilize_guides(actor_sprites, Callable(self, "_update_slime_attack_guides"))
		_update_overworld_ui()
		_update_game_over_input()
		return
	var prev_attack_input_was_down := player_attack_input_was_down
	var prev_player_was_attacking := player_is_attacking
	if not player_input_locked:
		_update_player_attack_input()
	var attack_input_down := _is_attack_input_pressed()
	if not player_input_locked and attack_input_down and not prev_attack_input_was_down and prev_player_was_attacking and player_anim_name == "attack1":
		if player_attack_component != null:
			player_attack_component.buffer_combo(player_tuning.combo_window)
			player_attack_component.set_combo_movement(_movement_input())
	if player_attack_component != null and player_attack_component.combo_buffered and player_is_attacking and player_anim_name == "attack1":
		var movement_input := _movement_input()
		var direction_changed := movement_input.length() > 0.25 and (
			player_attack_component.combo_movement.length() <= 0.25
			or movement_input.normalized().dot(player_attack_component.combo_movement.normalized()) < 0.99
		)
		if direction_changed:
			player_attack_component.consume_combo()
	if player_attack_component != null and player_attack_component.combo_buffered and not player_is_attacking and player_between_timer <= 0.0 and player_attack_component.can_start_attack2():
		_start_player_attack(2)
		player_attack_component.consume_combo()
	if not player_input_locked:
		_update_player_roll_input()
	_update_player_attack_lunge(delta)
	_update_player_roll(delta)
	_update_roll_dust(delta)
	_update_player_hit_reaction(delta)
	if not player_input_locked:
		_move_player(delta)
	_update_player_animation(delta)
	_move_slimes(delta)
	_update_enemy_hit_flashes(delta)
	_update_enemy_health(delta)
	_update_player_health_regen(delta)
	_update_player_health_ui(delta)
	_update_damage_numbers(delta)
	_update_pixel_particles(delta)
	if not dialogue_was_active:
		_update_chest_interaction()
	_update_chest_visuals(delta)
	_update_rest_fire_animation(delta)
	_update_cloaked_demon_animation(delta)
	_update_door_transition()
	_update_depth_sorting()
	_update_targeting()
	_update_actor_occlusion(delta)
	actor_collision_system.stabilize_guides(actor_sprites, Callable(self, "_update_slime_attack_guides"))
	_update_player_attack_visual()
	if prev_player_was_attacking and not player_is_attacking:
		if player_just_finished_attack2 and player_after_attack2_texture != null:
			player_between_timer = player_tuning.attack2_cooldown
			_set_actor_base_texture(player, player_after_attack2_texture)
		elif (player_attack_component == null or not player_attack_component.combo_buffered) and player_between_attack_texture != null:
			player_between_timer = player_tuning.between_attack_time
			_set_actor_base_texture(player, player_between_attack_texture)
		player_just_finished_attack2 = false
	if player_between_timer > 0.0:
		player_between_timer = maxf(player_between_timer - delta, 0.0)
		if player_between_timer <= 0.0:
			if not player_idle_frames.is_empty():
				_set_actor_base_texture(player, player_idle_frames[0])
	_update_player_shadow()
	_update_cloaked_demon_shadow()
	_update_overworld_ui()
func _start_player_death() -> void:
	if player_dead:
		return
	player_dead = true
	player_death_pending = false
	player_death_timer = 0.0
	player_death_particles_started = false
	player_is_attacking = false
	player_is_rolling = false
	_clear_roll_dust()
	player_attack_visual.visible = false
	player_death_origin = player.global_position
	player_death_offset = player.offset
	player_death_scale = player.scale
	player_death_texture = player.texture
	player.visible = false
	player_shadow.visible = false
	if player_sprite_shadow != null:
		player_sprite_shadow.visible = false
	player_death_overlay = Sprite2D.new()
	player_death_overlay.name = "PlayerDeathWhite"
	player_death_overlay.texture = _white_texture(player_death_texture)
	player_death_overlay.centered = player.centered
	player_death_overlay.offset = player_death_offset
	player_death_overlay.scale = player_death_scale
	player_death_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_death_overlay.z_as_relative = false
	player_death_overlay.z_index = int(round(_depth_key(player) * DEPTH_Z_SCALE)) + 2
	player_death_overlay.global_position = player_death_origin
	player_death_overlay.modulate = Color(1, 1, 1, 0)
	add_child(player_death_overlay)
func _update_player_death(delta: float) -> void:
	player_death_timer += delta
	if player_death_overlay != null:
		if player_death_timer < player_tuning.death_particle_delay:
			player_death_overlay.modulate.a = clampf(player_death_timer / player_tuning.death_fade_time, 0.0, 1.0)
		elif not player_death_particles_started:
			player_death_particles_started = true
			_spawn_player_death_pixels()
			player_death_overlay.queue_free()
			player_death_overlay = null
	if not player_death_particles_started:
		return
	var death_effect_end := player_tuning.death_particle_delay + player_tuning.death_particle_lifetime
	if game_over_overlay != null and game_over_overlay.visible:
		game_over_fade_timer += delta
		game_over_overlay.modulate.a = clampf(game_over_fade_timer / GAME_OVER_FADE_TIME, 0.0, 1.0)
		if game_over_button != null:
			game_over_button.modulate.a = _retro_button_alpha(game_over_fade_timer)
			game_over_button.position.y = 105.0 + _retro_button_bob(game_over_fade_timer)
		if game_over_title_button != null:
			game_over_title_button.modulate.a = _retro_button_alpha(game_over_fade_timer + 0.6)
			game_over_title_button.position.y = 121.0 + _retro_button_bob(game_over_fade_timer + 0.4)
	elif player_death_timer >= death_effect_end + player_tuning.death_observe_time:
		_show_game_over()
func _spawn_player_death_pixels() -> void:
	effects_spawner.spawn_player_death_particles(
		self,
		player_death_texture,
		player_death_origin,
		player_death_offset,
		player_death_scale,
		int(round(_depth_key(player) * DEPTH_Z_SCALE)) + 2,
		player_tuning.death_particle_lifetime,
		rng.randi(),
		Callable(self, "_pixel_particle_texture")
	)
func _build_game_over_ui() -> void:
	var controls := screen_state_controller.build_game_over(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_restart_game"), Callable(self, "_return_to_title")); game_over_overlay = controls["overlay"] as ColorRect; game_over_button = controls["restart"] as Button; game_over_title_button = controls["title"] as Button
func _show_game_over() -> void:
	if game_over_overlay == null or game_over_overlay.visible:
		return
	game_over_overlay.visible = true
	screen_state_controller.set_state(&"game_over")
	game_over_fade_timer = 0.0
	game_over_overlay.modulate.a = 0.0
	game_over_button.grab_focus()
func _build_title_screen() -> void:
	var controls := screen_state_controller.build_title(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_start_from_title")); title_overlay = controls["overlay"] as ColorRect; title_screen_text = controls["text"] as Sprite2D; title_start_button = controls["button"] as Button; title_start_text = controls["start_text"] as Sprite2D; _build_archetype_screen()
func _build_archetype_screen() -> void:
	var controls := screen_state_controller.build_archetype(ui, Callable(self, "_style_archetype_button"), Callable(self, "_shift_archetype"), Callable(self, "_shift_archetype_color"), Callable(self, "_start_selected_archetype"), Callable(self, "_pixel_text_texture")); archetype_overlay = controls["overlay"] as ColorRect; archetype_preview = controls["preview"] as Sprite2D; archetype_name_text = controls["name"] as Sprite2D
	archetype_left_buttons = controls["left"] as Array[Button]
	archetype_right_buttons = controls["right"] as Array[Button]
	archetype_type_left_button = controls["type_left"] as Button
	archetype_type_right_button = controls["type_right"] as Button
	archetype_start_button = controls["start"] as Button
	archetype_hold_cover = controls["cover"] as ColorRect
	_update_archetype_screen()
func _style_archetype_button(button: Button) -> void: screen_state_controller.style_archetype_button(button)
func _update_title_screen(delta: float) -> void:
	screen_state_controller.update_title_flow(self, delta)
func _retro_button_alpha(timer: float) -> float:
	var phase := fmod(timer, 2.4); var pulse := lerpf(1.0, 0.45, (phase - 0.6) / 0.9) if phase >= 0.6 and phase < 1.5 else lerpf(0.45, 1.0, (phase - 1.5) / 0.6) if phase >= 1.5 and phase < 2.1 else 1.0; return snappedf(snappedf(pulse, 0.08), 0.125)
func _retro_button_bob(timer: float) -> float:
	return snappedf(sin(timer / 3.6 * TAU) * 1.5, 0.5)
func _start_from_title() -> void:
	if title_overlay == null or not title_overlay.visible:
		return
	_spawn_title_pixel_breakup(title_screen_text)
	_spawn_title_pixel_breakup(title_start_text)
	_spawn_title_button_frame_breakup()
	title_overlay.visible = true
	title_overlay.modulate.a = 1.0
	title_transition_active = true
	title_transition_timer = 0.0
	if title_screen_text != null:
		title_screen_text.visible = false
	if title_start_text != null:
		title_start_text.visible = false
	if title_start_button != null:
		title_start_button.visible = false
	title_start_button.release_focus()
	archetype_overlay.visible = true
	screen_state_controller.set_state(&"archetype")
	archetype_overlay.modulate.a = 1.0
	archetype_hold_cover.visible = true
	archetype_transition_active = true
	archetype_transition_timer = -1.0
	archetype_fade_out = false
func _update_archetype_input(delta: float) -> void:
	screen_state_controller.update_archetype_input(self, delta)
func _shift_archetype(direction: int) -> void:
	archetype_index = posmod(archetype_index + direction, 4); selected_archetype = archetype_index as StatsComponent.AllocationProfile; _archetype_arrow_pulse(direction); _update_archetype_screen()
func _shift_archetype_color(direction: int) -> void:
	archetype_color_index = posmod(archetype_color_index + direction, 6); _archetype_arrow_pulse(direction); _update_archetype_screen()
func _archetype_arrow_pulse(direction: int) -> void:
	archetype_arrow_anim_direction = direction; archetype_arrow_anim_timer = 0.18
func _update_archetype_arrow_animation() -> void:
	var amount := clampf(archetype_arrow_anim_timer / 0.18, 0.0, 1.0)
	var pulse := 1.0 + amount * 0.22
	archetype_type_left_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction < 0 and archetype_menu_row == 0 else 1.0)
	archetype_type_right_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction > 0 and archetype_menu_row == 0 else 1.0)
	for button in archetype_left_buttons:
		button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction < 0 and archetype_menu_row == 1 else 1.0)
	for button in archetype_right_buttons:
		button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction > 0 and archetype_menu_row == 1 else 1.0)
func _select_archetype_menu_row(row: int) -> void:
	archetype_menu_row = posmod(row, 3); _update_archetype_button_styles(); if archetype_menu_row == 2: archetype_start_button.grab_focus()
func _update_archetype_screen() -> void:
	var names := ["BALANCED", "VIT", "STR", "DEF"]
	var colors := ["blue", "orange", "green", "red", "yellow", "grey"]
	archetype_name_text.texture = _pixel_text_texture(names[archetype_index], Color.WHITE)
	archetype_name_text.position = Vector2((240.0 - archetype_name_text.texture.get_width()) * 0.5, 21)
	if not player_idle_frames.is_empty():
		archetype_preview.texture = _recolor_player_texture(player_idle_frames[0], colors[archetype_color_index])
		archetype_preview.position.x = (240.0 - archetype_preview.texture.get_width() * archetype_preview.scale.x) * 0.5
	_update_archetype_button_styles()
func _update_archetype_button_styles() -> void:
	var highlight_colors := [Color8(65, 166, 246), Color8(255, 205, 117), Color8(167, 240, 112), Color8(239, 125, 87), Color8(255, 240, 150), Color8(148, 176, 194)]
	var color: Color = highlight_colors[archetype_color_index]
	var type_active := archetype_menu_row == 0
	var sprite_active := archetype_menu_row == 1
	var start_active := archetype_menu_row == 2
	_set_archetype_button_state(archetype_type_left_button, type_active, color)
	_set_archetype_button_state(archetype_type_right_button, type_active, color)
	for button in archetype_left_buttons:
		_set_archetype_button_state(button, sprite_active, color)
	for button in archetype_right_buttons:
		_set_archetype_button_state(button, sprite_active, color)
	_set_archetype_button_state(archetype_start_button, start_active, color)
func _set_archetype_button_state(button: Button, active: bool, color: Color) -> void:
	if button == null: return
	var normal := StyleBoxFlat.new(); normal.bg_color = Color(0, 0, 0, 0); normal.border_color = Color(color if active else Color.WHITE, 0.95 if active else 0.0); normal.set_border_width_all(1 if active else 0)
	var focus := StyleBoxFlat.new(); focus.bg_color = Color(color, 0.18 if active else 0.0); focus.border_color = color if active else Color.WHITE; focus.set_border_width_all(1 if active else 0)
	button.add_theme_color_override("font_color", color if active else Color.WHITE); button.add_theme_color_override("font_hover_color", color if active else Color.WHITE); button.add_theme_color_override("font_focus_color", color if active else Color.WHITE); button.add_theme_stylebox_override("normal", normal); button.add_theme_stylebox_override("hover", focus); button.add_theme_stylebox_override("focus", focus)
func _start_selected_archetype() -> void:
	if archetype_overlay == null or not archetype_overlay.visible or loading_screen_active:
		return
	player_stats.allocation_profile = selected_archetype
	player_palette_name = ["blue", "orange", "green", "red", "yellow", "grey"][archetype_color_index]
	loading_screen_active = true
	screen_state_controller.set_state(&"loading")
	loading_screen_fading = false
	loading_screen_timer = 0.0
	loading_screen_overlay.visible = true
	loading_screen_overlay.modulate.a = 1.0
	archetype_overlay.visible = false
	archetype_hold_cover.visible = false
	if title_overlay != null:
		title_overlay.visible = false
	await get_tree().process_frame
	await _apply_player_palette_async(player_palette_name)
	_update_player_aggro_marker_colors()
	player_health = _player_max_health()
	if player_health_component != null:
		player_health_component.maximum_health = player_health
		player_health_component.reset(player_health)
	player_display_health = player_health
	player_damage_fill_hold_timer = 0.0
	_update_player_health_ui()
	player.visible = true
	_apply_player_animation_frame()
	loading_screen_fading = true
	loading_screen_timer = 0.0
func _build_loading_screen() -> void:
	var controls := screen_state_controller.build_loading(ui, Callable(self, "_pixel_text_texture")); loading_screen_overlay = controls["overlay"] as ColorRect; loading_screen_text = controls["text"] as Sprite2D
func _update_loading_screen(delta: float) -> void:
	var result := screen_state_controller.update_loading(loading_screen_overlay, loading_screen_text, loading_screen_fading, loading_screen_timer, delta, Callable(self, "_pixel_text_texture")); loading_screen_fading = result["fading"]; loading_screen_timer = result["timer"]; if result["finished"]: loading_screen_active = false
func _apply_player_palette_async(palette_name: String) -> void:
	player_idle_frames = _recolor_player_frames(player_base_idle_frames, palette_name)
	await get_tree().process_frame
	player_walk_frames = _recolor_player_frames(player_base_walk_frames, palette_name)
	await get_tree().process_frame
	player_roll_frames = _recolor_player_frames(player_base_roll_frames, palette_name)
	await get_tree().process_frame
	player_attack_frames = _recolor_player_frames(player_base_attack_frames, palette_name)
	player_attack2_frames = _recolor_player_frames(player_base_attack2_frames, palette_name)
	await get_tree().process_frame
	player_attack_left_frames = _recolor_player_frames(player_base_attack_left_frames, palette_name)
	player_attack2_left_frames = _recolor_player_frames(player_base_attack2_left_frames, palette_name)
	player_between_attack_texture = _recolor_player_texture(player_base_between_attack_texture, palette_name)
	player_after_attack2_texture = _recolor_player_texture(player_base_after_attack2_texture, palette_name)
	await get_tree().process_frame
	if player_base_health_fill_texture != null:
		player_health_fill.texture = _recolor_player_texture(player_base_health_fill_texture, palette_name)
		if player_health_damage_fill != null:
			player_health_damage_fill.texture = hud_controller.brighter_bar_texture(player_health_fill.texture)
	_warm_player_frame_caches()
func _update_player_aggro_marker_colors() -> void:
	hud_controller.update_aggro_markers(hud_controller.target_overhead_aggro_markers, player_palette_name, Callable(self, "_pixel_particle_texture"))
func _spawn_title_pixel_breakup(source_sprite: Sprite2D) -> void:
	if title_particle_layer == null:
		title_particle_layer = Node2D.new()
		title_particle_layer.name = "TitleParticleLayer"
		title_particle_layer.z_index = 10
		ui.add_child(title_particle_layer)
	screen_state_controller.spawn_pixel_breakup(source_sprite, title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _spawn_title_button_frame_breakup() -> void:
	screen_state_controller.spawn_button_frame_breakup(title_start_button, title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _update_title_particles(delta: float) -> void:
	screen_state_controller.update_particles(delta, Callable(self, "_snap_half_pixel"))
func _update_game_over_input() -> void:
	if game_over_overlay == null or not game_over_overlay.visible: return
	if Input.is_action_just_pressed("ui_accept") or _is_interact_input_pressed(): _restart_game()
func _restart_game() -> void:
	_begin_scene_transition()
func _return_to_title() -> void:
	_begin_scene_transition()
func _build_scene_transition() -> void:
	scene_transition_overlay = screen_state_controller.create_overlay(ui, "SceneTransitionOverlay", Vector2(240, 160), Color.BLACK, 200); scene_transition_overlay.modulate.a = 0.0
func _begin_scene_transition() -> void:
	if scene_transition_active or scene_transition_overlay == null:
		return
	scene_transition_active = true
	screen_state_controller.set_state(&"transition")
	scene_transition_timer = 0.0
	scene_transition_overlay.visible = true
func _move_player(delta: float) -> void:
	if player_controller != null and not player_controller.can_receive_input():
		player_is_moving = false
		return
	if player_death_pending or player_is_attacking or player_is_rolling or (player_motor != null and player_motor.is_in_knockback()) or player_hitstun_timer > 0.0:
		player_is_moving = false
		return
	var input := _movement_input()
	player_is_moving = input.length_squared() > 0.0
	if not player_is_moving:
		return
	if input.x < 0.0:
		player.flip_h = true
	elif input.x > 0.0:
		player.flip_h = false
	if player_motor != null:
		player_motor.request_motion(_perspective_movement(input.normalized() * player_tuning.speed * delta))
	else:
		_try_move_actor(player, _perspective_movement(input.normalized() * player_tuning.speed * delta))
func _on_player_motor_motion(motion: Vector2) -> void:
	_try_move_actor(player, motion)
func _update_player_attack_input() -> void:
	var attack_input_down := _is_attack_input_pressed()
	if attack_input_down and not player_attack_input_was_down and not player_is_attacking and not player_is_rolling and (player_attack_component == null or player_attack_component.can_start_attack2()):
		if player_between_timer > 0.0:
			if player_attack_component != null:
				player_attack_component.buffer_combo(player_tuning.combo_window)
				player_attack_component.set_combo_movement(_movement_input())
		else:
			_start_player_attack()
	player_attack_input_was_down = attack_input_down
func _update_player_roll_input() -> void:
	var roll_input_down := _is_roll_input_pressed()
	if roll_input_down and not player_roll_input_was_down and not player_is_attacking and not player_is_rolling and (player_motor == null or not player_motor.is_in_knockback()): _start_player_roll()
	player_roll_input_was_down = roll_input_down
func _start_player_roll() -> void:
	if player_roll_frames.is_empty():
		return
	var direction := _movement_input()
	if direction.length_squared() <= 0.0:
		direction = _player_facing_vector()
	else:
		direction = direction.normalized()
	if direction.x < 0.0:
		player.flip_h = true
	elif direction.x > 0.0:
		player.flip_h = false
	player_is_rolling = true
	if player_roll_component != null:
		player_roll_component.begin(direction)
	if player_motor != null:
		player_motor.begin_roll()
	roll_dust_spawned_this_roll = false
	player_attack_visual.visible = false
	player_roll_component.start_motion(_perspective_movement(direction * (player_tuning.roll_distance / player_tuning.roll_duration)))
	player.visible = true
	_apply_player_animation_frame()
func _update_player_roll(delta: float) -> void:
	if not player_is_rolling or player_roll_component == null: return
	var position_before_roll_step := player.global_position
	var result := player_roll_component.tick_motion(delta, player_tuning.roll_duration, player_tuning.roll_frame_time, player_roll_frames.size(), Callable(self, "_move_player_roll"))
	if not roll_dust_spawned_this_roll:
		var resolved_direction := player.global_position - position_before_roll_step
		if resolved_direction.length_squared() <= 0.0001: resolved_direction = _perspective_movement(player_roll_component.direction)
		_start_roll_dust(resolved_direction.normalized()); roll_dust_spawned_this_roll = true
	if bool(result["finished"]):
		player_is_rolling = false
		if player_motor != null: player_motor.end_roll()
		player_anim_name = "idle"
		_apply_player_animation_frame()
	else:
		_apply_player_animation_frame()
func _move_player_roll(movement: Vector2) -> bool:
	return actor_collision_system.try_move_swept(player, movement, 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _start_roll_dust(direction: Vector2) -> void:
	effects_spawner.start_roll_dust(self, player, direction, roll_dust_frames, roll_dust_flipped_frames, Callable(self, "_actor_foot"), Callable(self, "_snap_half_pixel"))
func _update_roll_dust(delta: float) -> void:
	effects_spawner.update_roll_dust(delta, player.z_index, roll_dust_frames, roll_dust_flipped_frames, effects_tuning.roll_dust_frame_time, Callable(self, "_snap_half_pixel"))
func _clear_roll_dust() -> void:
	effects_spawner.clear_roll_dust()
func _start_player_attack(variant: int = 1) -> void:
	if variant == 1 and player_attack_frames.is_empty():
		return
	if variant == 2 and player_attack2_frames.is_empty():
		return
	player_is_attacking = true
	if player_attack_component != null:
		player_attack_component.begin(variant)
	player_just_finished_attack2 = false
	player_attack_hit_done = false
	player_attack_hit_targets.clear()
	player_attack_flip_h = player.flip_h
	if player_attack_component != null:
		var lunge_velocity := _perspective_movement(_player_facing_vector() * (player_tuning.attack_lunge_distance / player_tuning.attack_lunge_duration))
		player_attack_component.start_lunge(lunge_velocity, player_tuning.attack_lunge_duration)
	player_anim_name = "attack2" if variant == 2 else "attack1"
	if variant == 2:
		player_between_timer = 0.0
	player_anim_frame = 0
	player_anim_timer = 0.0
	_restore_actor_base_visual_scale(player)
	player.visible = false
	player_attack_visual.visible = true
	_apply_player_animation_frame()
func _interrupt_player_attack() -> void:
	player_is_attacking = false
	if player_attack_component != null:
		player_attack_component.cancel()
	player_attack_hit_done = false
	player_attack_hit_targets.clear()
	player_attack_visual.visible = false
	player.visible = true
	_restore_actor_base_visual_scale(player)
	player_anim_name = "walk" if player_is_moving else "idle"
	player_anim_frame = 0
	player_anim_timer = 0.0
	_apply_player_animation_frame()
func _update_player_attack_lunge(delta: float) -> void:
	if player_attack_component == null or not player_attack_component.has_lunge(): return
	_try_move_player_attack_lunge(player_attack_component.consume_lunge(delta))
func _try_move_player_attack_lunge(movement: Vector2) -> void:
	var original := player.position
	player.position.x += movement.x
	if not _is_walkable(_actor_foot(player)) or _collides_with_static(player):
		player.position.x = original.x
	player.position.y += movement.y
	if not _is_walkable(_actor_foot(player)) or _collides_with_static(player):
		player.position.y = original.y
func _update_player_hit_reaction(delta: float) -> void:
	player_hit_flash_timer = maxf(player_hit_flash_timer - delta, 0.0)
	player_hitstun_timer = maxf(player_hitstun_timer - delta, 0.0)
	if player_motor == null or not player_motor.is_in_knockback():
		return
	var motion := player_motor.consume_knockback(delta)
	actor_collision_system.try_move_swept(player, motion, 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _player_facing_vector() -> Vector2:
	return Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT if player_is_attacking else Vector2.LEFT if player.flip_h else Vector2.RIGHT
func _update_player_animation(delta: float) -> void:
	player_animation_component.tick_coordinator_animation(self, delta)
func _apply_player_animation_frame() -> void:
	if player_animation_component != null:
		player_animation_component.animation_name = StringName(player_anim_name); player_animation_component.frame = player_anim_frame; player_animation_component.timer = player_anim_timer
	var frames := player_roll_frames if player_is_rolling else player_attack2_frames if player_anim_name == "attack2" else player_attack_frames if player_anim_name == "attack1" else player_walk_frames if player_anim_name == "walk" else player_idle_frames
	if frames.is_empty(): return
	if player_is_rolling:
		_set_actor_base_texture(player, frames[player_roll_component.frame]); return
	if player_anim_name == "attack1" or player_anim_name == "attack2":
		var attack_frames := player_attack2_left_frames if player_anim_name == "attack2" and player_attack_flip_h else player_attack_left_frames if player_attack_flip_h else player_attack2_frames if player_anim_name == "attack2" else player_attack_frames
		if attack_frames.is_empty(): return
		player_attack_visual.texture = attack_frames[player_anim_frame]; _update_player_attack_visual(); return
	player.offset = PLAYER_TEXTURE_OFFSET; _set_actor_base_texture(player, frames[player_anim_frame])
func _update_player_attack_visual() -> void:
	player_animation_component.update_attack_visual(player, player_attack_visual, player_is_attacking, PLAYER_TEXTURE_OFFSET, player.z_index)
func _apply_player_attack_hitbox() -> void:
	var hitbox := _player_attack_hitbox()
	var hit_targets: Array[Sprite2D] = []
	for slime in slimes:
		if _is_slime_dead(slime):
			continue
		if player_attack_hit_targets.has(slime) or (player_attack_component != null and player_attack_component.hit_targets.has(slime)):
			continue
		if not hitbox.intersects(_collision_rect(slime), false):
			continue
		hit_targets.append(slime)
	var target_count := hit_targets.size()
	if target_count == 0:
		return
	for slime in hit_targets:
		player_attack_hit_targets.append(slime)
		if player_attack_component != null:
			player_attack_component.register_hit(slime)
		var damage := _player_attack_damage_against(slime)
		var was_critical := last_damage_was_critical
		var divided_damage := floorf(damage / float(target_count))
		_damage_slime(slime, maxf(divided_damage, 1.0), was_critical)
		_knockback_slime(slime)
func _player_attack_hitbox() -> Rect2:
	var guide_name := "SwordHitboxLeft" if player_attack_flip_h else "SwordHitboxRight"
	var guide_rect := _collision_guide_rect_by_name(player, guide_name)
	if guide_rect.has_area():
		return guide_rect
	var offset := player_tuning.attack_hitbox_left_offset if player_attack_flip_h else player_tuning.attack_hitbox_right_offset
	return Rect2(player.global_position + offset, player_tuning.attack_hitbox_size)
func _damage_slime(slime: Sprite2D, amount: float, was_critical: bool = false) -> void:
	if _is_slime_dead(slime):
		return
	_mark_player_in_combat()
	var health_component := _slime_health(slime)
	var previous_health := health_component.current_health if health_component != null else _enemy_max_health(slime)
	_slime_brain(slime).persistent_aggro = true
	if health_component != null:
		health_component.apply_damage(amount)
	else:
		previous_health = maxf(previous_health - amount, 0.0)
	_slime_health_presenter(slime).display_health = maxf(_slime_health_presenter(slime).display_health, previous_health)
	if health_component != null:
		health_component.regen_delay_timer = slime_tuning.regen_delay
		health_component.regen_accumulator = 0.0
	_slime_combat(slime).flash_timer = slime_tuning.hit_flash_time
	_slime_combat(slime).hitstun_timer = slime_tuning.hitstun_time
	_spawn_damage_number(slime, amount, was_critical)
	hitstop_timer = player_tuning.hitstop_duration
	if health_component != null and health_component.is_dead():
		_kill_slime(slime)
func _player_attack_damage_against(slime: Sprite2D) -> float:
	return _combat_damage(player_stats, _slime_stats(slime))
func _combat_damage(attacker_stats: StatsComponent, defender_stats: StatsComponent) -> float:
	var attacker_equipment_damage := player_equipment.damage_bonus if attacker_stats == player_stats and player_equipment != null else 0.0
	var defender_equipment_defense := player_equipment.defense_bonus if defender_stats == player_stats and player_equipment != null else 0.0
	var result := CombatCalculator.calculate_damage(
		attacker_stats,
		defender_stats,
		attacker_equipment_damage,
		defender_equipment_defense,
		attacker_stats == player_stats,
		rng,
		combat_tuning
	)
	last_damage_was_critical = result.critical
	return result.amount
func _max_health_for_stats(stats: StatsComponent) -> float:
	return CombatCalculator.max_health_for_stats(stats, player_equipment.health_bonus if stats == player_stats and player_equipment != null else 0.0, combat_tuning)
func _player_max_health() -> float:
	return _max_health_for_stats(player_stats)
func _enemy_max_health(slime: Sprite2D) -> float:
	return _max_health_for_stats(_slime_stats(slime))
func _enemy_level_for_room() -> int:
	return maxi(1, current_room_depth)
func _apply_enemy_room_level(slime: Sprite2D) -> void:
	var stats := _slime_stats(slime); if stats != null: stats.level = _enemy_level_for_room()
func _knockback_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime):
		return
	var direction := _actor_foot(slime) - _actor_foot(player)
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT
	_slime_combat(slime).knockback_velocity = _perspective_movement(direction.normalized() * (player_tuning.attack_knockback / slime_tuning.knockback_duration))
	_slime_combat(slime).knockback_timer = slime_tuning.knockback_duration
	_slime_brain(slime).scoot_start = slime.position
	_slime_brain(slime).scoot_target = slime.position
	_slime_brain(slime).scoot_timer = 0.0
	_slime_brain(slime).hold_timer = slime_tuning.hitstun_time
func _kill_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime):
		return
	_spawn_slime_death_pixels(slime)
	_kill_slime_without_effects(slime)
	if current_target == slime:
		if _is_target_input_held():
			_set_current_target(_closest_target())
		else:
			_set_current_target(null)
			_set_target_ui_visible(false)
	if _are_all_slimes_dead():
		_unlock_chest()
func _is_slime_dead(slime: Sprite2D) -> bool:
	return _slime_combat(slime).dead
func _are_all_slimes_dead() -> bool:
	for slime in slimes:
		if not _is_slime_dead(slime): return false
	return true
func _unlock_chest() -> void:
	if chest_unlocked: return
	chest_unlocked = true; if chest_normal_texture != null: _start_chest_unlock_fade()
func _build_interact_prompt() -> void:
	interact_prompt = interaction_component.build_prompt(self, _pixel_number_texture("!", Color8(255, 205, 117)), OVERWORLD_UI_Z + 1); interact_prompt_base_position = Vector2(6, -7)
func _build_npc_dialogue() -> void:
	var dialogue := npc_controller.build_dialogue(self, _load_texture_or_null("res://assets/artwork/circle55.png")); npc_dialogue_layer = dialogue["layer"] as CanvasLayer; npc_dialogue_box = dialogue["box"] as ColorRect; npc_dialogue_text = dialogue["text"] as Sprite2D; npc_dialogue_button = dialogue["button"] as Sprite2D; npc_dialogue_button_shadow = dialogue["shadow"] as Sprite2D
func _build_room_number_indicator() -> void:
	var hud := hud_controller.build_world_hud(ui, sprite_frame_library, Callable(self, "_load_texture_or_null"), target_health_bar, target_health_fill, player_health_fill)
	room_number_indicator = hud["room"] as Sprite2D
	gold_indicator = hud["gold"] as Sprite2D
	gold_amount_indicator = hud["gold_amount"] as Sprite2D
	gold_animation_frames = hud["gold_frames"] as Array[Texture2D]
	button_hud_sprites = hud["buttons"] as Array[Sprite2D]
	target_health_text = hud["target_text"] as Sprite2D
	player_health_text = hud["player_text"] as Sprite2D
	_update_room_number_indicator()
func _update_gold_indicator() -> void:
	if gold_indicator != null:
		gold_amount_indicator.texture = _pixel_number_texture(str(gold), Color8(255, 205, 117))
func _update_room_number_indicator() -> void:
	if room_number_indicator == null:
		return
	var room_label := "D%d" % current_room_display_number
	if current_room_type == DungeonGraph.ROOM_START:
		room_label = "START"
	elif current_room_type == DungeonGraph.ROOM_REST:
		room_label = "REST"
	elif current_room_type == DungeonGraph.ROOM_TRADER:
		room_label = "TRADER"
	elif current_room_type == DungeonGraph.ROOM_NPC:
		room_label = "CLOAKED"
	room_number_indicator.texture = _pixel_number_texture(room_label, Color8(244, 244, 244))
func _set_entrance_open(is_open: bool) -> void:
	entrance_open = is_open
	for socket_value in room_controller.active_entrance_sockets.values():
		var socket := socket_value as DungeonSocket
		var visual := socket.visual()
		if visual != null: visual.visible = true
func _start_chest_unlock_fade() -> void:
	if chest_unlock_overlay != null: chest_unlock_overlay.queue_free()
	chest.texture = chest_gray_texture; chest.visible = true; chest_controller.begin_unlock_fade(CHEST_UNLOCK_FADE_TIME); chest_unlock_overlay = Sprite2D.new(); chest_unlock_overlay.name = "ChestUnlockOverlay"; chest_unlock_overlay.texture = chest_normal_texture; chest_unlock_overlay.centered = chest.centered; chest_unlock_overlay.offset = chest.offset; chest_unlock_overlay.scale = chest.scale; chest_unlock_overlay.texture_filter = chest.texture_filter; chest_unlock_overlay.z_as_relative = false; chest_unlock_overlay.z_index = chest.z_index + 1; chest_unlock_overlay.global_position = chest.global_position; chest_unlock_overlay.modulate = Color(1, 1, 1, 0); add_child(chest_unlock_overlay)
func _update_chest_unlock_fade(delta: float) -> void:
	if chest_unlock_overlay == null: return
	if chest_controller.update_unlock_fade(delta, chest, chest_unlock_overlay, chest_normal_texture, CHEST_UNLOCK_FADE_TIME):
		occlusion_renderer.sprite_images[chest] = occlusion_renderer.cached_texture_image(chest_normal_texture); chest_unlock_overlay.queue_free(); chest_unlock_overlay = null
func _update_chest_interaction() -> void:
	var interact_input_down := _is_interact_input_pressed()
	if interact_input_down and not interact_input_was_down:
		if chest_unlocked and not chest_claimed and _can_interact_with_chest():
			chest_claimed = true
			var state := room_controller.room_states.get(current_room_id, {}) as Dictionary
			state["finished"] = true
			room_controller.room_states[current_room_id] = state
			chest_collect_flash_timer = CHEST_COLLECT_FLASH_TIME
			_start_chest_flash()
			gold += CHEST_REWARD_GOLD
			_update_gold_indicator()
			_spawn_gold_number(chest.global_position + Vector2(5, -8), CHEST_REWARD_GOLD)
			print("Gold: %d" % gold)
		elif _can_interact_with_npc():
			_show_npc_dialogue()
	interact_input_was_down = interact_input_down
func _update_chest_visuals(delta: float) -> void:
	_update_interact_prompt(delta); _update_chest_unlock_fade(delta)
	if chest_collect_flash_timer > 0.0:
		chest_collect_flash_timer = maxf(chest_collect_flash_timer - delta, 0.0)
		if chest_flash_overlay != null: chest_flash_overlay.global_position = chest.global_position; chest_flash_overlay.z_index = chest.z_index + 1; chest_flash_overlay.modulate = Color(1, 1, 1, 1.0 - chest_collect_flash_timer / CHEST_COLLECT_FLASH_TIME)
		if chest_collect_flash_timer <= 0.0 and not chest_evaporated:
			_start_chest_evaporation()
	elif not chest_claimed:
		chest.self_modulate = Color.WHITE
func _update_rest_fire_animation(delta: float) -> void:
	rest_fire_controller.update_animation(rest_fire, rest_fire_frames, delta, FIRE_FRAME_TIME, Callable(self, "_refresh_rest_fire_image"))
func _refresh_rest_fire_image(fire: Sprite2D) -> void:
	occlusion_renderer.sprite_images[fire] = occlusion_renderer.cached_texture_image(fire.texture)
func _set_rest_fire_frame(frame_index: int) -> void:
	if rest_fire_frames.is_empty(): return
	rest_fire_controller.frame_index = posmod(frame_index, rest_fire_frames.size()); rest_fire.texture = rest_fire_frames[rest_fire_controller.frame_index]; rest_fire.hframes = 1; rest_fire.frame = 0; occlusion_renderer.sprite_images[rest_fire] = occlusion_renderer.cached_texture_image(rest_fire.texture)
func _update_cloaked_demon_animation(delta: float) -> void:
	var near_player := _can_interact_with_npc()
	var patrolling := (current_room_type == DungeonGraph.ROOM_START or current_room_type == DungeonGraph.ROOM_NPC) and not near_player and (npc_dialogue_box == null or not npc_dialogue_box.visible)
	var result := npc_controller.update_patrol_animation(cloaked_demon, cloaked_demon_idle_frames, cloaked_demon_walk_frames, delta, near_player, patrolling, cloaked_demon_patrol_paused, cloaked_demon_wander_target, cloaked_demon_wander_has_target, cloaked_demon_patrol_pause_timer, cloaked_demon_patrol_direction, player.global_position.x, rng, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_random_npc_walkable_point_near"), Callable(self, "_move_cloaked_demon"), Callable(self, "_perspective_movement"), Callable(self, "_cache_npc_texture"), cloaked_demon_animation_timer, cloaked_demon_animation_frame)
	cloaked_demon_wander_target = result["wander_target"]
	cloaked_demon_wander_has_target = result["has_target"]
	cloaked_demon_patrol_paused = result["paused"]
	cloaked_demon_patrol_pause_timer = result["pause_timer"]
	cloaked_demon_patrol_direction = result["direction"]
	cloaked_demon_animation_timer = result["timer"]
	cloaked_demon_animation_frame = result["frame"]
func _move_cloaked_demon(movement: Vector2, max_step: float) -> bool:
	return actor_collision_system.try_move_swept(cloaked_demon, movement, max_step, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _cache_npc_texture(_actor: Sprite2D, texture: Texture2D) -> void:
	occlusion_renderer.sprite_images[cloaked_demon] = occlusion_renderer.cached_texture_image(texture)
func _update_npc_dialogue(delta: float) -> void:
	if npc_dialogue_box == null or not npc_dialogue_box.visible: return
	if not cloaked_demon.visible:
		_hide_npc_dialogue(); return
	npc_controller.update_dialogue(delta, npc_dialogue_box, npc_dialogue_text, npc_dialogue_button, npc_dialogue_button_shadow, _cloaked_demon_head_position(), Callable(self, "_pixel_text_texture"), Callable(self, "_snap_half_pixel"), 0.045, NPC_DIALOGUE_BUTTON_BOB_TIME)
func _show_npc_dialogue() -> void:
	if npc_dialogue_box == null or not cloaked_demon.visible: return
	var message := npc_dialogue_messages[npc_dialogue_index % npc_dialogue_messages.size()] as String; npc_dialogue_index += 1; npc_controller.begin_dialogue(message); npc_dialogue_text.texture = _pixel_text_texture("", Color.WHITE); npc_dialogue_text.visible = true; npc_dialogue_button.visible = false; npc_dialogue_input_was_down = _is_interact_input_pressed(); npc_dialogue_box.visible = true; player_is_moving = false; player_is_attacking = false
	player_is_rolling = false
	player_attack_visual.visible = false
	player_anim_name = "idle"
	player_anim_frame = 0
	player_anim_timer = 0.0
	_apply_player_animation_frame()
	interact_prompt.visible = false
	_update_npc_dialogue(0.0)
func _hide_npc_dialogue() -> void:
	npc_controller.end_dialogue()
	if npc_dialogue_box != null: npc_dialogue_box.visible = false
	if npc_dialogue_text != null: npc_dialogue_text.visible = false
	if npc_dialogue_button != null: npc_dialogue_button.visible = false
	if npc_dialogue_button_shadow != null: npc_dialogue_button_shadow.visible = false
	npc_dialogue_input_was_down = false
func _update_npc_dialogue_input() -> void:
	var input_down := _is_interact_input_pressed()
	if npc_controller.dialogue_complete and input_down and not npc_dialogue_input_was_down: _hide_npc_dialogue()
	npc_dialogue_input_was_down = input_down
func _can_interact_with_chest() -> bool:
	return chest_unlocked and not chest_claimed and _actor_foot(player).distance_to(_collision_rect(chest).get_center()) <= CHEST_INTERACT_DISTANCE
func _can_interact_with_npc() -> bool:
	return cloaked_demon != null and cloaked_demon.visible and _actor_foot(player).distance_to(_cloaked_demon_visual_center()) <= NPC_INTERACT_DISTANCE
func _update_interact_prompt(delta: float) -> void:
	var near_chest := _can_interact_with_chest()
	var near_npc := _can_interact_with_npc()
	interaction_component.update_prompt(
		delta,
		interact_prompt,
		npc_dialogue_box != null and npc_dialogue_box.visible,
		near_chest,
		near_npc,
		chest.global_position,
		_cloaked_demon_head_position(),
		interact_prompt_base_position,
		Callable(self, "_snap_half_pixel"),
		INTERACT_PROMPT_BOB_TIME,
		OVERWORLD_UI_Z + 1
	)
func _start_chest_evaporation() -> void:
	chest_evaporated = true
	_spawn_chest_evaporation_pixels()
	chest.visible = false
	_set_door_active(true)
	_set_entrance_open(true)
	if chest_flash_overlay != null:
		chest_flash_overlay.queue_free()
		chest_flash_overlay = null
	collision_sprites.erase(chest)
	depth_sprites.erase(chest)
	occluder_sprites.erase(chest)
	if interact_prompt != null:
		interact_prompt.visible = false
func _set_door_active(is_active: bool) -> void:
	door_active = is_active
	for socket_value in room_controller.active_door_sockets.values():
		var socket := socket_value as DungeonSocket
		var visual := socket.visual()
		if visual != null: visual.visible = is_active
func _collect_dungeon_sockets() -> void:
	room_controller.dungeon_sockets.clear()
	if sockets_root == null:
		return
	for child in sockets_root.get_children():
		var socket := child as DungeonSocket
		if socket != null:
			room_controller.dungeon_sockets[socket.socket_id()] = socket
func _validate_dungeon_socket_setup() -> void:
	var expected_pairs := {
		DungeonGraph.WALL_LEFT: DungeonGraph.BOTTOM_RIGHT,
		DungeonGraph.WALL_RIGHT: DungeonGraph.BOTTOM_LEFT,
		DungeonGraph.BOTTOM_LEFT: DungeonGraph.WALL_RIGHT,
		DungeonGraph.BOTTOM_RIGHT: DungeonGraph.WALL_LEFT,
	}
	for socket_id_value in expected_pairs.keys():
		var socket_id := StringName(socket_id_value)
		var socket := room_controller.dungeon_sockets.get(socket_id) as DungeonSocket
		if socket == null:
			push_error("Missing dungeon socket: %s" % socket_id)
			continue
		if socket.paired_socket_id != StringName(expected_pairs[socket_id]):
			push_error("Dungeon socket %s has the wrong paired socket." % socket_id)
		if socket.visual() == null or socket.trigger() == null or socket.spawn_marker() == null:
			push_error("Dungeon socket %s is missing a visual, trigger, or spawn marker." % socket_id)
func _sync_current_room_metadata() -> void:
	var room := dungeon_graph.get_room(current_room_id)
	if room != null: current_room_depth = room.depth; current_room_display_number = room.display_number; current_room_type = room.room_type
func _ensure_current_room_layout() -> void:
	var room := dungeon_graph.get_room(current_room_id)
	if room == null: return
	var state := room_controller.ensure_layout(dungeon_graph, current_room_id, room, current_room_type, current_room_depth); _configure_room_sockets(bool(state.get("finished", false)))
func _configure_room_sockets(is_unlocked: bool) -> void:
	room_controller.configure_sockets(dungeon_graph, current_room_id, is_unlocked, Callable(self, "_build_entrance_block_polygons")); door_active = is_unlocked; entrance_open = is_unlocked; _set_door_active(is_unlocked)
func _update_door_transition() -> void:
	if not room_transition_locked: _try_enter_any_active_socket()
func _try_enter_any_active_socket() -> bool:
	return true if _try_enter_active_door() else _try_enter_active_entrance()
func _try_enter_active_door() -> bool:
	if not door_active or room_transition_locked: return false
	var player_feet := _player_door_feet_rect()
	for socket_id_value in room_controller.active_door_sockets.keys():
		var socket_id := StringName(socket_id_value); var socket := room_controller.active_door_sockets.get(socket_id) as DungeonSocket; var trigger_polygon := _socket_trigger_polygon(socket)
		if trigger_polygon.size() >= 3 and _rect_touches_polygon(player_feet, trigger_polygon):
			var connection := dungeon_graph.get_connection(current_room_id, socket_id)
			if connection != null:
				_enter_connected_room(connection.destination_room_id, connection.destination_entry); return true
	return false
func _try_enter_active_entrance() -> bool:
	if not entrance_open or room_transition_locked: return false
	var player_feet := _player_door_feet_rect()
	for socket_id_value in room_controller.active_entrance_sockets.keys():
		var socket_id := StringName(socket_id_value); var socket := room_controller.active_entrance_sockets.get(socket_id) as DungeonSocket; var trigger_polygon := _socket_trigger_polygon(socket)
		if trigger_polygon.size() >= 3 and _rect_touches_polygon(player_feet, trigger_polygon):
			var connection := dungeon_graph.get_connection_for_entry(current_room_id, socket_id)
			if connection != null:
				_enter_connected_room(connection.source_room_id, connection.exit_socket); return true
	return false
func _socket_trigger_polygon(socket: DungeonSocket) -> PackedVector2Array:
	if socket == null:
		return PackedVector2Array()
	var guide := socket.trigger()
	if guide == null or guide.polygon.size() < 3:
		return PackedVector2Array()
	return _guide_polygon_global(guide)
func _guide_polygon_global(guide: Polygon2D) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in guide.polygon: polygon.append(guide.to_global(point))
	return polygon
func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty(): return Rect2()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()): bounds = bounds.expand(polygon[index])
	return bounds
func _player_door_feet_rect() -> Rect2:
	var guide_rect := _collision_guide_rect_by_name(player, "DoorFeetGuide")
	if guide_rect.has_area(): return guide_rect
	var foot := _actor_foot(player)
	return Rect2(foot - PLAYER_DOOR_FOOT_COLLIDER_SIZE * 0.5, PLAYER_DOOR_FOOT_COLLIDER_SIZE)
func _rect_touches_polygon(rect: Rect2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3 or not _polygon_bounds(polygon).intersects(rect, false): return false
	if Geometry2D.is_point_in_polygon(rect.get_center(), polygon): return true
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	for corner in corners:
		if Geometry2D.is_point_in_polygon(corner, polygon): return true
	for point in polygon:
		if rect.has_point(point): return true
	return false
func _enter_connected_room(destination_room_id: StringName, arrival_socket_id: StringName) -> void:
	room_transition_locked = true
	if room_controller != null:
		room_controller.begin_transition()
	_save_current_room_state()
	current_room_id = destination_room_id
	_sync_current_room_metadata()
	if room_controller != null:
		room_controller.enter_room(current_room_id, current_room_type, arrival_socket_id)
	_ensure_current_room_layout()
	_update_room_number_indicator()
	var arrival_socket := room_controller.dungeon_sockets.get(arrival_socket_id) as DungeonSocket
	var spawn_marker: Marker2D = null
	if arrival_socket != null:
		spawn_marker = arrival_socket.spawn_marker()
	player.global_position = spawn_marker.global_position if spawn_marker != null else player_start_position
	player.flip_h = arrival_socket != null and arrival_socket.inward_facing.x < 0.0
	player_is_attacking = false
	player_attack_visual.visible = false
	current_target = null
	target_input_was_down = false
	_hide_npc_dialogue()
	_set_target_ui_visible(false)
	_apply_room_state()
	_build_depth_lists()
	call_deferred("_release_room_transition_lock")
func _release_room_transition_lock() -> void:
	room_transition_locked = false; if room_controller != null: room_controller.end_transition()
func _save_current_room_state() -> void:
	var state := room_controller.room_states.get(current_room_id, {}) as Dictionary
	state["finished"] = chest_claimed
	room_controller.room_states[current_room_id] = state
	if room_controller != null and chest_claimed:
		room_controller.mark_cleared(current_room_id)
func _apply_room_state() -> void:
	var state := room_controller.room_states.get(current_room_id, {}) as Dictionary
	if room_controller != null and room_controller.is_cleared(current_room_id):
		state["finished"] = true
	if current_room_type == DungeonGraph.ROOM_START or current_room_type == DungeonGraph.ROOM_REST:
		_apply_rest_room_state()
	elif current_room_type == DungeonGraph.ROOM_NPC:
		_apply_npc_room_state()
	elif bool(state.get("finished", false)):
		_apply_finished_room_state()
	else:
		cloaked_demon.visible = false
		collision_sprites.erase(cloaked_demon)
		_reset_chest_for_room()
		_reset_slimes_for_room()
func _apply_rest_room_state() -> void:
	room_controller.apply_rest_state(self)
func _apply_npc_room_state() -> void:
	room_controller.apply_npc_state(self)
func _apply_finished_room_state() -> void:
	room_controller.apply_finished_state(self)
func _kill_slime_without_effects(slime: Sprite2D) -> void:
	var combat := _slime_combat(slime); combat.dead = true; slime.visible = false; combat.timer = 0.0; combat.frame = 0; combat.hit_done = false; collision_sprites.erase(slime); depth_sprites.erase(slime); occluder_sprites.erase(slime); actor_sprites.erase(slime)
	var health_component := _slime_health(slime)
	if health_component != null: health_component.reset(0.0)
	_slime_health_presenter(slime).display_health = 0.0
	var frame := hud_controller.target_overhead_frames.get(slime) as Sprite2D
	var damage_fill := hud_controller.target_overhead_damage_fills.get(slime) as Sprite2D
	var fill := hud_controller.target_overhead_fills.get(slime) as Sprite2D
	if frame != null: frame.visible = false
	if damage_fill != null: damage_fill.visible = false
	if fill != null: fill.visible = false
func _reset_chest_for_room() -> void:
	rest_fire.visible = false; cloaked_demon.visible = false; chest.position = chest_start_position; chest.texture = chest_gray_texture; chest.visible = true; chest.self_modulate = Color.WHITE; chest_unlocked = false; chest_claimed = false; chest_evaporated = false; chest_collect_flash_timer = 0.0; _set_door_active(false); _set_entrance_open(false)
	if chest_unlock_overlay != null: chest_unlock_overlay.queue_free(); chest_unlock_overlay = null
	if chest_flash_overlay != null: chest_flash_overlay.queue_free(); chest_flash_overlay = null
	if not collision_sprites.has(chest): collision_sprites.append(chest)
	occlusion_renderer.sprite_images[chest] = occlusion_renderer.cached_texture_image(chest_gray_texture)
func _reset_slimes_for_room() -> void:
	for slime in slimes:
		var actor := slime as SlimeActor; var brain := _slime_brain(slime); slime.position = brain.start_position; slime.visible = true; slime.flip_h = false
		_apply_enemy_room_level(slime)
		var max_health := _enemy_max_health(slime)
		if actor != null: actor.configure_health(max_health, slime_tuning.regen_delay, slime_tuning.regen_interval, slime_tuning.regen_amount); actor.reset_runtime_state(brain.start_position, slime.position, rng.randf_range(slime_tuning.repath_min, slime_tuning.repath_max), rng.randf_range(slime_tuning.hold_min, slime_tuning.hold_max), 0.0, rng.randf_range(0.2, 0.6))
		_slime_health_presenter(slime).display_health = max_health; _slime_health_presenter(slime).damage_fill_hold_timer = 0.0
		_set_actor_base_texture(slime, occlusion_renderer.actor_default_textures[slime])
		_set_actor_visual_scale(slime, Vector2.ONE)
		if not actor_sprites.has(slime):
			actor_sprites.append(slime)
		if not collision_sprites.has(slime):
			collision_sprites.append(slime)
func _start_chest_flash() -> void:
	if chest_flash_overlay != null: chest_flash_overlay.queue_free()
	chest_flash_overlay = Sprite2D.new(); chest_flash_overlay.name = "ChestFlashOverlay"; chest_flash_overlay.texture = _white_texture(chest.texture); chest_flash_overlay.centered = chest.centered; chest_flash_overlay.offset = chest.offset; chest_flash_overlay.scale = chest.scale; chest_flash_overlay.texture_filter = chest.texture_filter; chest_flash_overlay.z_as_relative = false; chest_flash_overlay.z_index = chest.z_index + 1; chest_flash_overlay.global_position = chest.global_position; chest_flash_overlay.modulate = Color.WHITE; add_child(chest_flash_overlay)
func _spawn_slime_death_pixels(slime: Sprite2D) -> void:
	effects_spawner.spawn_slime_death_particles(self, occlusion_renderer.actor_default_textures.get(slime) as Texture2D, slime.global_position, int(round(_actor_foot(slime).y * DEPTH_Z_SCALE)) + 1, effects_tuning.slime_death_particle_count, effects_tuning.slime_death_particle_speed_min, effects_tuning.slime_death_particle_speed_max, effects_tuning.slime_death_particle_lifetime, rng, Callable(self, "_pixel_particle_texture"))
func _spawn_gold_number(world_position: Vector2, amount: int) -> void:
	var sprite := Sprite2D.new(); sprite.texture = _pixel_number_texture("+%d" % amount, Color8(255, 205, 117)); sprite.centered = false; sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; sprite.z_as_relative = false; sprite.z_index = OVERWORLD_UI_Z + 2; sprite.position = world_position; add_child(sprite); effects_spawner.damage_numbers.append({"sprite": sprite, "timer": effects_tuning.damage_number_lifetime})
func _spawn_chest_evaporation_pixels() -> void:
	effects_spawner.spawn_chest_evaporation_particles(self, chest.texture, chest.global_position, int(round(_depth_key(chest) * DEPTH_Z_SCALE)) + 1, CHEST_EVAPORATE_PARTICLE_COUNT, CHEST_EVAPORATE_LIFETIME_MIN, CHEST_EVAPORATE_LIFETIME_MAX, rng, Callable(self, "_pixel_particle_texture"))
func _update_pixel_particles(delta: float) -> void:
	effects_spawner.update_pixel_particles(delta, Callable(self, "_snap_half_pixel"), effects_tuning.slime_death_particle_lifetime)
func _snap_half_pixel(world_position: Vector2) -> Vector2:
	return Vector2(snappedf(world_position.x, 0.5), snappedf(world_position.y, 0.5))
func _pixel_particle_texture(color: Color, size: int = 1) -> Texture2D:
	var key := "%02X%02X%02X:%d" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0)), size]
	if effects_spawner.pixel_particle_texture_cache.has(key):
		return effects_spawner.pixel_particle_texture_cache[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	effects_spawner.pixel_particle_texture_cache[key] = texture
	return texture
func _white_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var key := "%s:white_texture" % source.resource_path
	if occlusion_renderer.white_image_cache.has(key):
		return occlusion_renderer.white_image_cache[key]
	var image := occlusion_renderer.cached_texture_image(source).duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, color.a))
	var texture := ImageTexture.create_from_image(image)
	occlusion_renderer.white_image_cache[key] = texture
	return texture
func _try_knockback_slime(slime: Sprite2D, movement: Vector2) -> void:
	actor_collision_system.try_move_swept(slime, movement, 1.0, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static")); _separate_slime_from_player(slime)
func _separate_slime_from_player(slime: Sprite2D) -> void:
	var overlap_push := actor_collision_system.overlap_push_vector(self, slime, player)
	if overlap_push != Vector2.ZERO: actor_collision_system.try_move_swept(slime, overlap_push, 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _slime_brain(slime: Sprite2D) -> SlimeBrain:
	var brain := slime.get_node_or_null("Brain") as SlimeBrain
	if brain == null:
		brain = SlimeBrain.new()
		brain.name = "Brain"
		slime.add_child(brain)
	return brain
func _slime_combat(slime: Sprite2D) -> SlimeCombatComponent:
	var combat := slime.get_node_or_null("Combat") as SlimeCombatComponent
	if combat == null:
		combat = SlimeCombatComponent.new()
		combat.name = "Combat"
		slime.add_child(combat)
	return combat
func _slime_stats(slime: Sprite2D) -> StatsComponent:
	return slime.get_node_or_null("Stats") as StatsComponent
func _slime_visual(slime: Sprite2D) -> SlimeVisualComponent:
	var visual := slime.get_node_or_null("Visual") as SlimeVisualComponent
	if visual == null:
		visual = SlimeVisualComponent.new()
		visual.name = "Visual"
		slime.add_child(visual)
	return visual
func _slime_animation(slime: Sprite2D) -> SlimeAnimationComponent:
	var animation := slime.get_node_or_null("Animation") as SlimeAnimationComponent
	if animation == null:
		animation = SlimeAnimationComponent.new()
		animation.name = "Animation"
		slime.add_child(animation)
	return animation
func _slime_health_presenter(slime: Sprite2D) -> SlimeHealthPresenter:
	var presenter := slime.get_node_or_null("HealthPresenter") as SlimeHealthPresenter
	if presenter == null:
		presenter = SlimeHealthPresenter.new()
		presenter.name = "HealthPresenter"
		slime.add_child(presenter)
	return presenter
func _slime_health(slime: Sprite2D) -> HealthComponent:
	return slime.get_node_or_null("Health") as HealthComponent
func _move_slimes(delta: float) -> void:
	for slime in slimes:
		var slime_actor := slime as SlimeActor
		if slime_actor != null:
			slime_actor.tick_components(delta); slime_actor.tick_runtime(delta, Callable(self, "_is_slime_dead"), Callable(self, "_update_slime_knockback"), Callable(self, "_update_slime_attack"), Callable(self, "_is_slime_aggroed"), Callable(self, "_aggro_slime_target"), Callable(self, "_update_slime_scoot")); continue
		SlimeActor.tick_legacy_runtime(slime, delta, Callable(self, "_is_slime_dead"), Callable(self, "_update_slime_knockback"), Callable(self, "_update_slime_attack"), Callable(self, "_is_slime_aggroed"), Callable(self, "_aggro_slime_target"), Callable(self, "_update_slime_scoot"))
func _update_slime_attack(slime: Sprite2D, delta: float) -> bool:
	return _slime_combat(slime).tick_attack(delta, slime, slime_tuning, _slime_attack_frames(slime), player_dead, Callable(self, "_set_slime_attack_frame"), Callable(self, "_set_actor_base_texture"), Callable(self, "_apply_slime_attack_lunge"), Callable(self, "_apply_slime_attack_hit"), Callable(self, "_restore_slime_idle_texture"), Callable(self, "_can_slime_attack_player"), Callable(self, "_start_slime_attack"))
func _set_slime_attack_frame(slime: Sprite2D, frame_index: int) -> void: _slime_animation(slime).set_attack_frame(frame_index)
func _start_slime_attack(slime: Sprite2D) -> void:
	var direction := _actor_foot(player) - _actor_foot(slime)
	var face_left := direction.x < 0.0
	_slime_combat(slime).face_left = face_left
	var animation := _slime_animation(slime)
	if animation != null:
		animation.set_facing(face_left)
	_set_slime_facing(slime, -1.0 if face_left else 1.0)
	_slime_combat(slime).timer = 0.001
	var combat := _slime_combat(slime)
	if combat != null:
		combat.begin()
	_slime_combat(slime).frame = 0
	_slime_combat(slime).hit_done = false
	var frames := _slime_attack_frames(slime)
	if not frames.is_empty():
		_set_actor_base_texture(slime, frames[0])
	_slime_brain(slime).scoot_timer = 0.0
	_slime_brain(slime).scoot_start = slime.position
	_slime_brain(slime).scoot_target = slime.position
	_set_actor_visual_scale(slime, Vector2.ONE)
func _slime_attack_frames(slime: Sprite2D) -> Array[Texture2D]:
	var visual := _slime_visual(slime); return [] if visual == null else visual.attack_left_frames if _slime_combat(slime).face_left else visual.attack_right_frames
func _restore_slime_idle_texture(slime: Sprite2D) -> void:
	_set_slime_facing(slime, -1.0 if _slime_combat(slime).face_left else 1.0)
func _can_slime_attack_player(slime: Sprite2D) -> bool:
	return not player_dead and _actor_foot(player).distance_to(_actor_foot(slime)) <= slime_tuning.attack_range
func _is_slime_aggroed(slime: Sprite2D) -> bool:
	return not _is_slime_dead(slime) and not player_dead and (_slime_brain(slime).persistent_aggro or _actor_foot(slime).distance_to(_actor_foot(player)) <= slime_tuning.aggro_range)
func _is_any_slime_aggroed() -> bool:
	for slime in slimes:
		if _is_slime_aggroed(slime): return true
	return false
func _aggro_slime_target(slime: Sprite2D) -> Vector2:
	var slime_foot := _actor_foot(slime); var player_foot := _actor_foot(player); var approach := slime_foot - player_foot; if approach.length_squared() < 0.01: approach = Vector2.RIGHT
	var desired := player_foot + approach.normalized() * (slime_tuning.attack_range * 0.72)
	var buddy_avoidance := Vector2.ZERO
	for buddy in slimes:
		if buddy == slime or _is_slime_dead(buddy): continue
		var buddy_delta := slime_foot - _actor_foot(buddy); var buddy_distance := buddy_delta.length(); var clear_distance := actor_collision_system.actor_contact_radius(self, slime) + actor_collision_system.actor_contact_radius(self, buddy) + 4.0
		if buddy_distance > 0.01 and buddy_distance < clear_distance: buddy_avoidance += buddy_delta.normalized() * (clear_distance - buddy_distance) / clear_distance
	if buddy_avoidance.length_squared() > 0.001: desired += buddy_avoidance.normalized() * 7.0
	return _nearest_slime_walkable_point(desired)
func _apply_slime_attack_hit(slime: Sprite2D) -> void:
	if player_is_rolling: return
	var attack_delta := _actor_foot(player) - _actor_foot(slime)
	var attack_ellipse := Vector2(attack_delta.x / slime_tuning.attack_hit_range, attack_delta.y / slime_tuning.attack_vertical_hit_range)
	if attack_ellipse.length_squared() > 1.0: return
	var damage := _slime_attack_damage(slime)
	_mark_player_in_combat()
	if player_health_component != null:
		player_health_component.apply_damage(damage); player_health = player_health_component.current_health
	else:
		player_health = maxf(player_health - damage, 0.0)
	if player_is_attacking: _interrupt_player_attack()
	player_hit_flash_timer = player_tuning.hit_flash_time; player_hitstun_timer = player_tuning.hitstun_time; _apply_player_hit_knockback(slime); _spawn_player_damage_number(damage); _update_player_health_ui(); hitstop_timer = player_tuning.hitstop_duration
	if player_health <= 0.0:
		player_death_pending = true; _interrupt_player_attack(); player_is_rolling = false
func _slime_attack_damage(slime: Sprite2D) -> float:
	return _combat_damage(_slime_stats(slime), player_stats)
func _mark_player_in_combat() -> void:
	if player_health_component != null:
		player_health_component.regen_delay_timer = player_tuning.regen_delay; player_health_component.regen_accumulator = 0.0
func _on_player_health_damaged(_amount: float) -> void:
	player_damage_fill_hold_timer = player_tuning.health_damage_hang_time
func _on_player_health_changed(current: float, _maximum: float) -> void:
	player_health = current; if is_instance_valid(player_health_fill): _update_player_health_ui()
func _on_player_health_healed(_amount: float) -> void:
	player_display_health = minf(player_display_health, player_health_component.current_health if player_health_component != null else player_health)
func _on_slime_health_damaged(_amount: float, slime: Sprite2D) -> void:
	_slime_health_presenter(slime).damage_fill_hold_timer = slime_tuning.health_damage_hang_time
func _on_slime_health_changed(current: float, _maximum: float, slime: Sprite2D) -> void:
	_slime_health_presenter(slime).display_health = minf(_slime_health_presenter(slime).display_health, current)
	if slime == current_target and is_instance_valid(target_health_fill): _update_target_ui()
func _on_slime_health_healed(_amount: float, slime: Sprite2D) -> void:
	var health_component := _slime_health(slime)
	if health_component != null: _slime_health_presenter(slime).display_health = minf(_slime_health_presenter(slime).display_health, health_component.current_health)
func _update_player_health_regen(delta: float) -> void:
	if current_room_type != DungeonGraph.ROOM_START and current_room_type != DungeonGraph.ROOM_REST:
		return
	var max_health := _player_max_health()
	if player_health >= max_health:
		return
	if _is_any_slime_aggroed():
		_mark_player_in_combat()
		return
	if player_health_component != null:
		player_health_component.tick_regeneration(delta)
	_update_player_health_ui()
func _apply_slime_attack_lunge(slime: Sprite2D) -> void:
	var direction := _actor_foot(player) - _actor_foot(slime)
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if _slime_combat(slime).face_left else Vector2.RIGHT
	else:
		direction = direction.normalized()
	direction.y *= 1.5
	direction = direction.normalized()
	actor_collision_system.try_move_swept(slime, _perspective_movement(direction * slime_tuning.attack_lunge_distance), 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _apply_player_hit_knockback(slime: Sprite2D) -> void:
	var direction := _actor_foot(player) - _actor_foot(slime)
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT if player.global_position.x >= slime.global_position.x else Vector2.LEFT
	if player_motor != null:
		player_motor.start_knockback(_perspective_movement(direction.normalized() * (player_tuning.hit_knockback / player_tuning.hit_knockback_duration)), player_tuning.hit_knockback_duration)
func _update_slime_knockback(slime: Sprite2D, delta: float) -> bool:
	return _slime_combat(slime).tick_knockback(delta, slime, Callable(self, "_try_knockback_slime"), Callable(self, "_reset_slime_scoot"))
func _reset_slime_scoot(slime: Sprite2D) -> void: _slime_brain(slime).scoot_start = slime.position; _slime_brain(slime).scoot_target = slime.position
func _update_enemy_hit_flashes(delta: float) -> void:
	for slime in slimes:
		if not _is_slime_dead(slime): _slime_combat(slime).flash_timer = maxf(_slime_combat(slime).flash_timer - delta, 0.0)
func _update_enemy_health(delta: float) -> void:
	for slime in slimes:
		if not _is_slime_dead(slime): _slime_health_presenter(slime).update(delta, _slime_health(slime), _enemy_max_health(slime), slime_tuning)
func _spawn_damage_number(slime: Sprite2D, amount: float, was_critical: bool = false) -> void:
	_spawn_floating_number(slime.global_position + Vector2(5, -9), int(round(amount)), Vector2(0.0, -effects_tuning.damage_number_float_speed), was_critical)
func _spawn_player_damage_number(amount: float) -> void:
	_spawn_floating_number(player.global_position + Vector2(5, 6), int(round(amount)), Vector2(0.0, effects_tuning.damage_number_float_speed))
func _spawn_floating_number(world_position: Vector2, value: int, velocity: Vector2, was_critical: bool = false) -> void:
	effects_spawner.spawn_damage_number(self, world_position, value, velocity, was_critical, Callable(self, "_pixel_number_texture"), Callable(self, "_snap_half_pixel"), effects_tuning.damage_number_lifetime, effects_tuning.damage_number_pop_time)
func _update_damage_numbers(delta: float) -> void: effects_spawner.update_damage_numbers(delta, Callable(self, "_snap_half_pixel"), effects_tuning.damage_number_lifetime)
func _pixel_text_texture(text: String, color: Color) -> Texture2D: return effects_spawner.number_texture(text, color)
func _pixel_name_texture(text: String, color: Color) -> Texture2D: return effects_spawner.name_texture(text, color)
func _pixel_number_texture(text: String, color: Color) -> Texture2D: return effects_spawner.number_texture(text, color)
func _update_slime_scoot(slime: Sprite2D, delta: float) -> void:
	_slime_brain(slime).tick_scoot(slime, delta, slime_tuning, Callable(self, "_is_slime_aggroed"), Callable(self, "_try_move_actor"), Callable(self, "_set_actor_visual_scale"), Callable(self, "_repath_slime_after_block"), Callable(self, "_start_slime_hold"), Callable(self, "_start_slime_scoot"))
func _start_slime_scoot(slime: Sprite2D) -> void: _set_actor_visual_scale(slime, Vector2.ONE); _slime_brain(slime).start_scoot(slime, slime_tuning, rng, Callable(self, "_actor_foot"), Callable(self, "_aggro_slime_target"), Callable(self, "_random_slime_walkable_point_near"), Callable(self, "_perspective_movement"), Callable(self, "_set_slime_facing"))
func _repath_slime_after_block(slime: Sprite2D) -> void:
	if _is_slime_dead(slime):
		return
	_slime_brain(slime).scoot_timer = 0.0
	_slime_brain(slime).scoot_start = slime.position
	_slime_brain(slime).scoot_target = slime.position
	_slime_brain(slime).repath_timer = 0.0
	if _is_slime_aggroed(slime):
		_slime_brain(slime).target = _aggro_slime_target(slime)
		_slime_brain(slime).hold_timer = 0.0
	else:
		_slime_brain(slime).target = _random_slime_walkable_point_near(_actor_foot(slime), 8, slime)
		_slime_brain(slime).hold_timer = rng.randf_range(0.08, 0.18)
	_set_actor_visual_scale(slime, Vector2.ONE)
func _start_slime_hold(slime: Sprite2D) -> void: _slime_brain(slime).start_random_hold(slime_tuning, rng)
func _set_actor_visual_scale(actor: Sprite2D, visual_scale: Vector2) -> void:
	occlusion_renderer.actor_visual_scales[actor] = visual_scale
func _try_move_actor(actor: Sprite2D, movement: Vector2) -> bool:
	var original := actor.position
	actor.position.x += movement.x
	if actor == player and _try_enter_any_active_socket():
		return true
	if not _can_actor_stand_at_current_position(actor):
		actor.position.x = original.x
	else:
		_resolve_actor_contacts(actor, Vector2(movement.x, 0.0))
	actor.position.y += movement.y
	if actor == player and _try_enter_any_active_socket():
		return true
	if not _can_actor_stand_at_current_position(actor):
		actor.position.y = original.y
	else:
		_resolve_actor_contacts(actor, Vector2(0.0, movement.y))
	return actor.position.distance_squared_to(original) > 0.0001
func _resolve_actor_contacts(actor: Sprite2D, movement: Vector2) -> void:
	if actor_collision_system != null:
		actor_collision_system.set_actors(collision_sprites)
		actor_collision_system.resolve_contacts(actor, movement, Callable(actor_collision_system, "resolve_contact_pair").bind(self))
		return
	for other in collision_sprites:
		actor_collision_system.resolve_contact_pair(actor, other, movement, self)
func _is_enemy_control_locked(actor: Sprite2D) -> bool:
	return _slime_combat(actor).hitstun_timer > 0.0 or _slime_combat(actor).knockback_timer > 0.0
func _collides_with_static(actor: Sprite2D) -> bool:
	for other in collision_sprites:
		if other == actor or other != chest:
			continue
		if _collision_rect(actor).intersects(_collision_rect(other), false):
			return true
	return false
func _perspective_movement(movement: Vector2) -> Vector2:
	return Vector2(movement.x, movement.y * VERTICAL_MOVEMENT_SCALE)
func _collision_rect(actor: Sprite2D) -> Rect2:
	var guide_rect := _collision_guide_rect(actor)
	if guide_rect.has_area():
		return guide_rect
	if actor == chest:
		var chest_center := actor.global_position + Vector2(8, 13)
		return Rect2(chest_center - CHEST_COLLISION_SIZE * 0.5, CHEST_COLLISION_SIZE)
	var foot := _actor_foot(actor)
	var size := Vector2(ACTOR_COLLISION_WIDTH, ACTOR_COLLISION_HEIGHT)
	return Rect2(foot - Vector2(size.x * 0.5, size.y * 0.55), size)
func _collision_guide_rect(actor: Sprite2D) -> Rect2:
	return _collision_guide_rect_by_name(actor, "CollisionGuide")
func _collision_guide_rect_by_name(actor: Sprite2D, guide_name: String) -> Rect2:
	var guide := actor.get_node_or_null(guide_name) as Node2D
	if guide == null:
		return Rect2()
	var rect_position: Vector2 = guide.get("rect_position")
	var rect_size: Vector2 = guide.get("rect_size")
	var scaled_position := rect_position
	var scaled_size := rect_size
	var origin := actor.global_position + guide.position + scaled_position
	if scaled_size.x < 0.0:
		origin.x += scaled_size.x
		scaled_size.x = absf(scaled_size.x)
	if scaled_size.y < 0.0:
		origin.y += scaled_size.y
		scaled_size.y = absf(scaled_size.y)
	return Rect2(origin, scaled_size)
func _build_depth_lists() -> void:
	var lists := depth_sorter.visible_lists(player, slimes, chest, rest_fire, cloaked_demon, Callable(self, "_is_slime_dead"))
	depth_sprites = lists["depth"] as Array[Sprite2D]
	occluder_sprites = lists["occluders"] as Array[Sprite2D]
	if cloaked_demon.visible:
		occlusion_renderer.sprite_images[cloaked_demon] = occlusion_renderer.cached_texture_image(cloaked_demon.texture)
	if rest_fire.visible:
		occlusion_renderer.sprite_images[rest_fire] = occlusion_renderer.cached_texture_image(rest_fire.texture)
	if chest.visible:
		for path in OCCLUDER_PATHS:
			var node := get_node_or_null(path)
			if node != null:
				_collect_occluders(node)
	_update_depth_sorting()
func _hide_editor_only_guides() -> void:
	room_controller.hide_editor_only_guides(floor_tiles)
func _build_slime_direction_textures() -> void:
	var paths := {
		slime_blue: ["res://assets/artwork/SlimeBlueLeft.png", "res://assets/artwork/SlimeBlueRight.png"],
		slime_green: ["res://assets/artwork/SlimeGreenLeft.png", "res://assets/artwork/SlimeGreenRight.png"],
		slime_red: ["res://assets/artwork/SlimeRedLeft.png", "res://assets/artwork/SlimeRedRight.png"],
	}
	SlimeVisualComponent.build_direction_textures(slimes, paths, Callable(self, "_load_texture_or_null"))
func _build_slime_attack_frames() -> void:
	SlimeVisualComponent.build_attack_frames(slimes, sprite_frame_library, SLIME_ATTACK_FRAME_SIZE, occlusion_renderer.texture_image_cache, Callable(self, "_warm_texture_cache"))
func _build_enemy_health_ui() -> void:
	player_base_health_fill_texture = hud_controller.build_enemy_health_ui(slimes, target_health_fill, target_health_bar, player_health_fill, player_health_damage_fill, hp_overhead, hp_overhead_fill, slime_green, Callable(self, "_load_health_bar_texture"), Callable(hud_controller, "brighter_bar_texture"), Callable(hud_controller, "duplicate_fill_sprite"), Callable(hud_controller, "register_overhead_bar"), Callable(self, "_pixel_particle_texture"))
	target_health_damage_fill = target_health_fill.get_parent().get_node_or_null("EnemyHpDamageFill") as Sprite2D
	player_health_damage_fill = player_health_fill.get_parent().get_node_or_null("HpBarDamageFill") as Sprite2D
	var player_base_texture := _load_health_bar_texture("res://assets/artwork/HpBarBlueBar.png")
	if player_base_texture != null:
		player_base_health_fill_texture = player_base_texture
		player_health_fill.texture = player_base_texture
		if player_health_damage_fill != null: player_health_damage_fill.texture = hud_controller.brighter_bar_texture(player_base_texture)
func _load_texture_or_null(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
func _load_health_bar_texture(path: String) -> Texture2D:
	return ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D if ResourceLoader.exists(path) else null
func _build_rest_fire_frames() -> void:
	rest_fire_frames = sprite_frame_library.slice_frames("res://assets/artwork/Fire.png", FIRE_FRAME_SIZE)
	if not rest_fire_frames.is_empty(): _set_rest_fire_frame(0)
func _build_cloaked_demon_frames() -> void:
	var frames := npc_controller.build_cloaked_demon_frames(sprite_frame_library, cloaked_demon, CLOAKED_DEMON_FRAME_SIZE, Callable(occlusion_renderer, "cached_texture_image")); cloaked_demon_idle_frames = frames["idle"]; cloaked_demon_walk_frames = frames["walk"]; cloaked_demon_visual_bounds = frames["bounds"]
func _cloaked_demon_head_position() -> Vector2:
	return _cloaked_demon_texture_origin() + Vector2(cloaked_demon_visual_bounds.get_center().x, cloaked_demon_visual_bounds.position.y)
func _cloaked_demon_visual_center() -> Vector2:
	return _cloaked_demon_texture_origin() + cloaked_demon_visual_bounds.get_center()
func _cloaked_demon_foot_position() -> Vector2:
	return _cloaked_demon_texture_origin() + Vector2(cloaked_demon_visual_bounds.get_center().x, cloaked_demon_visual_bounds.end.y - 1.0)
func _configure_cloaked_demon_patrol_route() -> void:
	var route := npc_controller.configure_patrol_route(cloaked_demon, walkable_outline, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_is_walkable")); if route.is_empty(): return
	cloaked_demon_patrol_min_x = route["min_x"]; cloaked_demon_patrol_max_x = route["max_x"]; cloaked_demon_wander_origin = route["origin"]; cloaked_demon_patrol_position_x = route["position_x"]; cloaked_demon_wander_target = route["target"]; cloaked_demon_wander_has_target = route["has_target"]
func _random_npc_walkable_point_near(point: Vector2, radius: float) -> Vector2:
	var candidates: Array[Vector2] = []
	for index in 32:
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(3.0, radius)
		var candidate := point + _perspective_movement(Vector2(cos(angle), sin(angle)) * distance)
		if _is_walkable(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		return point
	return candidates[rng.randi_range(0, candidates.size() - 1)]
func _cloaked_demon_texture_origin() -> Vector2:
	var origin := cloaked_demon.global_position + cloaked_demon.offset
	if cloaked_demon.centered and cloaked_demon.texture != null:
		origin -= cloaked_demon.texture.get_size() * 0.5
	return origin
func _build_player_animation_frames() -> void:
	player_idle_frames = sprite_frame_library.slice_frames("res://assets/artwork/TinyDemon-idle.png", PLAYER_FRAME_SIZE); player_walk_frames = sprite_frame_library.slice_frames("res://assets/artwork/TinyDemon-walk.png", PLAYER_FRAME_SIZE); player_roll_frames = sprite_frame_library.slice_frames("res://assets/artwork/TinyDemon-roll.png", PLAYER_FRAME_SIZE); roll_dust_frames.clear(); var raw_roll_dust_frames := sprite_frame_library.slice_frames("res://assets/artwork/rolldust.png", ROLL_DUST_FRAME_SIZE)
	for frame_index in raw_roll_dust_frames.size():
		roll_dust_frames.append(sprite_frame_library.dither_roll_dust_frame(raw_roll_dust_frames[frame_index], float(frame_index) / float(maxi(raw_roll_dust_frames.size(), 1))))
	roll_dust_flipped_frames = _flip_effect_frames_horizontally(roll_dust_frames, ROLL_DUST_FRAME_SIZE); player_attack_frames = sprite_frame_library.slice_frames("res://assets/artwork/TinyDemon-attack1.png", PLAYER_ATTACK_FRAME_SIZE); player_attack2_frames = sprite_frame_library.slice_frames("res://assets/artwork/TinyDemon-attack2.png", PLAYER_ATTACK_FRAME_SIZE); if player_attack2_frames.is_empty(): player_attack2_frames = player_attack_frames.duplicate()
	player_attack2_left_frames = sprite_frame_library.flip_frames(player_attack2_frames); player_between_attack_texture = _load_texture_or_null("res://assets/artwork/TinyDemon-attack-between.png"); player_after_attack2_texture = _load_texture_or_null("res://assets/artwork/TinyDemon-after-attack2.png"); player_attack_left_frames = sprite_frame_library.flip_frames(player_attack_frames)
	player_base_idle_frames = player_idle_frames.duplicate(); player_base_walk_frames = player_walk_frames.duplicate(); player_base_roll_frames = player_roll_frames.duplicate(); player_base_attack_frames = player_attack_frames.duplicate(); player_base_attack2_frames = player_attack2_frames.duplicate(); player_base_attack_left_frames = player_attack_left_frames.duplicate(); player_base_attack2_left_frames = player_attack2_left_frames.duplicate(); player_base_between_attack_texture = player_between_attack_texture; player_base_after_attack2_texture = player_after_attack2_texture; _apply_player_palette("blue"); _warm_player_frame_caches()
	if not player_idle_frames.is_empty():
		_set_actor_base_texture(player, player_idle_frames[0])
func _warm_player_frame_caches() -> void:
	for frames in [player_idle_frames, player_walk_frames, player_roll_frames, roll_dust_frames, roll_dust_flipped_frames, player_attack_frames, player_attack2_frames, player_attack2_left_frames, player_attack_left_frames]:
		for texture in frames: _warm_texture_cache(texture)
func _flip_effect_frames_horizontally(frames: Array[Texture2D], display_size: Vector2i) -> Array[Texture2D]:
	return sprite_frame_library.flip_effect_frames(frames, display_size)
func _apply_player_palette(palette_name: String) -> void:
	player_idle_frames = _recolor_player_frames(player_base_idle_frames, palette_name)
	player_walk_frames = _recolor_player_frames(player_base_walk_frames, palette_name)
	player_roll_frames = _recolor_player_frames(player_base_roll_frames, palette_name)
	player_attack_frames = _recolor_player_frames(player_base_attack_frames, palette_name)
	player_attack2_frames = _recolor_player_frames(player_base_attack2_frames, palette_name)
	player_attack_left_frames = _recolor_player_frames(player_base_attack_left_frames, palette_name)
	player_attack2_left_frames = _recolor_player_frames(player_base_attack2_left_frames, palette_name)
	player_between_attack_texture = _recolor_player_texture(player_base_between_attack_texture, palette_name)
	player_after_attack2_texture = _recolor_player_texture(player_base_after_attack2_texture, palette_name)
	if player_base_health_fill_texture != null:
		player_health_fill.texture = _recolor_player_texture(player_base_health_fill_texture, palette_name)
		if player_health_damage_fill != null:
			player_health_damage_fill.texture = hud_controller.brighter_bar_texture(player_health_fill.texture)
	_warm_player_frame_caches()
func _recolor_player_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]:
	return sprite_frame_library.recolor_frames(frames, palette_name)
func _recolor_player_texture(source: Texture2D, palette_name: String) -> Texture2D:
	return sprite_frame_library.recolor_texture(source, palette_name)
func _warm_texture_cache(texture: Texture2D) -> void:
	var image := occlusion_renderer.cached_texture_image(texture); occlusion_renderer.cached_effect_image(texture, image); occlusion_renderer.cached_highlighted_image(texture, image); occlusion_renderer.cached_white_image(texture, image)
func _set_slime_facing(slime: Sprite2D, direction_x: float) -> void:
	if absf(direction_x) < 0.1:
		return
	var texture: Texture2D = null
	if direction_x < 0.0:
		var visual := _slime_visual(slime)
		texture = visual.left_texture if visual != null else null
		slime.flip_h = false
	else:
		var visual := _slime_visual(slime)
		texture = visual.right_texture if visual != null else null
		if texture == null and visual != null and visual.left_texture != null:
			texture = visual.left_texture
			slime.flip_h = true
		else:
			slime.flip_h = false
	if texture == null:
		texture = occlusion_renderer.actor_default_textures[slime]
	_set_actor_base_texture(slime, texture)
	_update_slime_attack_guides(slime)
func _update_slime_attack_guides(slime: Sprite2D) -> void:
	var active_name := "AttackGuideL" if _slime_combat(slime).face_left else "AttackGuideR"
	for child in slime.get_children():
		if child is Node2D and child.name.begins_with("AttackGuide"):
			(child as Node2D).visible = child.name == active_name
func _set_actor_base_texture(actor: Sprite2D, texture: Texture2D) -> void:
	if texture == null:
		return
	if occlusion_renderer.original_actor_textures[actor] == texture:
		actor.texture = texture
		return
	occlusion_renderer.original_actor_textures[actor] = texture
	var image := occlusion_renderer.cached_texture_image(texture)
	occlusion_renderer.original_actor_images[actor] = image
	occlusion_renderer.sprite_images[actor] = image
	occlusion_renderer.occluded_actor_textures[actor] = occlusion_renderer.effect_texture_with_display_size(
		occlusion_renderer.cached_effect_image(texture, image),
		image.get_size()
	)
	occlusion_renderer.highlighted_actor_textures[actor] = occlusion_renderer.effect_texture_with_display_size(
		occlusion_renderer.cached_highlighted_image(texture, image),
		image.get_size()
	)
	occlusion_renderer.white_actor_textures[actor] = ImageTexture.create_from_image(occlusion_renderer.cached_white_image(texture, image))
	actor.texture = texture
func _collect_occluders(node: Node) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.visible:
			_add_depth_sprite(sprite)
			if not occluder_sprites.has(sprite):
				occluder_sprites.append(sprite)
	for child in node.get_children():
		_collect_occluders(child)
func _add_depth_sprite(sprite: Sprite2D) -> void:
	if not depth_sprites.has(sprite): sprite.z_as_relative = false; depth_sprites.append(sprite)
func _update_depth_sorting() -> void:
	for sprite in depth_sprites: sprite.z_index = depth_sorter.z_index_for(sprite, _depth_key(sprite), DEPTH_Z_SCALE) if depth_sorter != null else int(round(_depth_key(sprite) * DEPTH_Z_SCALE))
func _update_actor_occlusion(delta: float) -> void:
	occlusion_renderer.update_actor_occlusion(
		actor_sprites,
		occluder_sprites,
		player,
		current_target,
		delta,
		OCCLUSION_RELEASE_GRACE,
		Callable(self, "_is_actor_occlusion_flashing"),
		Callable(self, "_depth_key"),
		Callable(self, "_sprite_source_global_rect"),
		Callable(self, "_build_exact_occluded_actor_texture"),
		Callable(self, "_apply_actor_scale"),
		Callable(self, "_restore_actor_base_visual_scale")
	)
func _is_actor_occlusion_flashing(actor: Sprite2D) -> bool:
	return player_hit_flash_timer > 0.0 if actor == player else _slime_combat(actor).flash_timer > 0.0
func _update_player_shadow() -> void:
	player_shadow.global_position = player.global_position + player_shadow_offset; player_shadow.global_scale = player_shadow_scale; player_shadow.self_modulate = Color(1, 1, 1, 0.25); player_shadow.flip_h = player.flip_h; player_shadow.z_index = shadow_controller.z_index_for(_actor_foot(player).y, DEPTH_Z_SCALE) if shadow_controller != null else int(round(_actor_foot(player).y * DEPTH_Z_SCALE)) - 1
	if player_sprite_shadow != null:
		var source_sprite := player_attack_visual if player_is_attacking else player
		player_sprite_shadow.texture = source_sprite.texture
		player_sprite_shadow.global_position = source_sprite.global_position + Vector2(-0.5, 0.0)
		player_sprite_shadow.offset = source_sprite.offset
		player_sprite_shadow.scale = source_sprite.scale
		player_sprite_shadow.flip_h = source_sprite.flip_h
		player_sprite_shadow.visible = source_sprite.visible and source_sprite.texture != null
		player_sprite_shadow.z_index = source_sprite.z_index - 1
func _update_cloaked_demon_shadow() -> void:
	if cloaked_demon_shadow == null: return
	cloaked_demon_shadow.visible = cloaked_demon.visible
	if cloaked_demon_sprite_shadow != null: cloaked_demon_sprite_shadow.visible = cloaked_demon.visible
	if not cloaked_demon.visible: return
	cloaked_demon_shadow.global_position = cloaked_demon.global_position + cloaked_demon_shadow_offset; cloaked_demon_shadow.global_scale = cloaked_demon_shadow_scale; cloaked_demon_shadow.flip_h = cloaked_demon.flip_h; cloaked_demon_shadow.self_modulate = Color(1, 1, 1, 0.25); cloaked_demon_shadow.z_index = shadow_controller.z_index_for(_cloaked_demon_foot_position().y, DEPTH_Z_SCALE) if shadow_controller != null else int(round(_cloaked_demon_foot_position().y * DEPTH_Z_SCALE)) - 1
	if cloaked_demon_sprite_shadow != null:
		cloaked_demon_sprite_shadow.texture = cloaked_demon.texture; cloaked_demon_sprite_shadow.global_position = cloaked_demon.global_position + Vector2(-0.5, 0.0); cloaked_demon_sprite_shadow.offset = cloaked_demon.offset; cloaked_demon_sprite_shadow.scale = cloaked_demon.scale; cloaked_demon_sprite_shadow.flip_h = cloaked_demon.flip_h; cloaked_demon_sprite_shadow.visible = cloaked_demon.texture != null; cloaked_demon_sprite_shadow.z_index = cloaked_demon.z_index - 1
func _build_cloaked_demon_sprite_shadow() -> void:
	cloaked_demon_sprite_shadow = Sprite2D.new(); cloaked_demon_sprite_shadow.name = "CloakedDemonSpriteShadow"; cloaked_demon_sprite_shadow.centered = cloaked_demon.centered; cloaked_demon_sprite_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; cloaked_demon_sprite_shadow.self_modulate = Color(0.0, 0.0, 0.0, 0.25); cloaked_demon_sprite_shadow.z_as_relative = false; cloaked_demon_sprite_shadow.z_index = cloaked_demon.z_index - 1; cloaked_demon.get_parent().add_child(cloaked_demon_sprite_shadow)
func _update_targeting() -> void:
	var should_target := _is_target_input_held()
	if not should_target:
		_set_current_target(null)
		_set_target_ui_visible(false)
		target_input_was_down = false
		return
	if not target_input_was_down:
		_set_current_target(_closest_target())
		target_input_was_down = true
	if current_target != null and _is_slime_dead(current_target):
		_set_current_target(null)
	if current_target != null and not player_is_attacking:
		player.flip_h = _actor_foot(current_target).x < _actor_foot(player).x
	_update_target_ui()
func _movement_input() -> Vector2:
	return player_controller.movement_input(_controller_devices(), CONTROLLER_DEADZONE)
func _is_target_input_held() -> bool:
	return player_controller.target_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _is_attack_input_pressed() -> bool:
	return player_controller.action_pressed([KEY_J, KEY_SPACE], _controller_devices(), JOY_BUTTON_X)
func _is_interact_input_pressed() -> bool:
	return player_controller.action_pressed([KEY_E, KEY_ENTER], _controller_devices(), JOY_BUTTON_B)
func _is_roll_input_pressed() -> bool:
	return player_controller.action_pressed([KEY_K], _controller_devices(), JOY_BUTTON_A)
func _controller_devices() -> Array[int]:
	return player_controller.connected_devices()
func _closest_target() -> Sprite2D:
	return interaction_component.closest_target(player, slimes, TARGET_LOCK_MAX_DISTANCE, Callable(self, "_actor_foot"), Callable(self, "_is_slime_dead"))
func _set_current_target(target: Sprite2D) -> void:
	if current_target != target: current_target = target; if hud_controller != null: hud_controller.set_target(target)
func _update_target_ui() -> void:
	if current_target == null:
		_set_target_ui_visible(false)
		return
	_set_target_ui_visible(true)
	target_health_bar_size = hud_controller.update_target_ui(current_target, target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_health_bar_size, Callable(self, "_slime_display_name"), Callable(self, "_enemy_max_health"), Callable(self, "_slime_current_health"), Callable(self, "_slime_display_health"), Callable(self, "_pixel_name_texture"), Callable(self, "_pixel_number_texture"), Callable(hud_controller, "set_health_bar_values"))
func _set_target_ui_visible(target_visible: bool) -> void:
	hud_controller.set_visible(target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_visible)
func _slime_display_name(slime: Sprite2D) -> String:
	return "Blue Slime" if slime == slime_blue else "Red Slime" if slime == slime_red else "Green Slime"
func _update_player_health_ui(delta: float = 0.0) -> void:
	var result := hud_controller.update_player_health_ui(player_health, player_display_health, player_damage_fill_hold_timer, delta, slime_tuning.health_regen_fill_speed, slime_tuning.health_drain_fill_speed, _player_max_health(), player_health_fill, player_health_damage_fill, player_health_fill_size, player_health_text, Callable(self, "_pixel_number_texture"), Callable(hud_controller, "set_health_bar_values")); player_display_health = result["display_health"]; player_damage_fill_hold_timer = result["damage_hold"]
func _update_overworld_ui() -> void:
	hud_controller.update_button_hud(button_hud_sprites, _controller_devices())
	gold_animation_timer = fmod(gold_animation_timer + get_process_delta_time(), 0.48)
	hud_controller.update_gold_indicator(gold_indicator, gold_animation_frames, gold_animation_timer)
	hud_controller.update_overhead_bars(
		slimes,
		Callable(self, "_enemy_max_health"),
		Callable(self, "_slime_current_health"),
		Callable(self, "_slime_display_health"),
		Callable(self, "_is_slime_dead"),
		Callable(self, "_is_slime_aggroed"),
		Callable(hud_controller, "set_health_bar_values"),
		OVERWORLD_UI_Z
	)
func _slime_current_health(slime: Sprite2D) -> float:
	var max_health := _enemy_max_health(slime); var health_component := _slime_health(slime); return health_component.current_health if health_component != null else max_health
func _slime_display_health(slime: Sprite2D) -> float:
	return _slime_health_presenter(slime).display_health
func _depth_key(sprite: Sprite2D) -> float:
	if actor_sprites.has(sprite): return _actor_foot(sprite).y
	if sprite == rest_fire: return rest_fire_depth_marker.global_position.y
	if sprite == cloaked_demon: return _cloaked_demon_foot_position().y
	if sprite.name.begins_with("WallLeft") or sprite.name.begins_with("WallRight"): return sprite.global_position.y + 28.0
	if sprite.name.begins_with("Door"): return sprite.global_position.y + 30.0
	return sprite.global_position.y + float(sprite.texture.get_height() if sprite.texture != null else 0)
func _sprite_source_global_rect(sprite: Sprite2D) -> Rect2:
	var texture: Texture2D = occlusion_renderer.original_actor_textures[sprite] if occlusion_renderer.original_actor_textures.has(sprite) else sprite.texture
	if texture == null: return Rect2(sprite.global_position, Vector2.ZERO)
	var sprite_scale := sprite.scale.abs()
	if occlusion_renderer.original_actor_scales.has(sprite):
		sprite_scale = _actor_screen_scale(sprite).abs()
	var size: Vector2 = texture.get_size() * sprite_scale
	var source_offset := _actor_visual_offset(sprite) if occlusion_renderer.original_actor_scales.has(sprite) else sprite.offset
	var origin := sprite.global_position + source_offset * sprite_scale
	if sprite.centered:
		origin -= size * 0.5
	return Rect2(origin, size)
func _build_exact_occluded_actor_texture(actor: Sprite2D, active_occluders: Array[Sprite2D], include_outline: bool) -> Texture2D:
	return occlusion_renderer.build_exact_occluded_actor_texture(actor, active_occluders, include_outline, Callable(self, "_is_pixel_covered_by_occluder"), Callable(self, "_actor_visual_offset"))
func _is_pixel_covered_by_occluder(world_pixel: Vector2, active_occluders: Array[Sprite2D]) -> bool:
	return occlusion_renderer.is_pixel_covered_by_occluder(world_pixel, active_occluders, Callable(self, "_actor_screen_scale"), Callable(self, "_actor_visual_offset"))
func _apply_actor_scale(actor: Sprite2D, _use_effect_texture: bool) -> void:
	actor.scale = _actor_screen_scale(actor); actor.offset = _actor_visual_offset(actor)
func _restore_actor_base_visual_scale(actor: Sprite2D) -> void:
	if occlusion_renderer.original_actor_scales.has(actor): actor.scale = occlusion_renderer.original_actor_scales[actor] as Vector2; actor.offset = _actor_visual_offset(actor)
func _actor_screen_scale(actor: Sprite2D) -> Vector2:
	return (occlusion_renderer.original_actor_scales[actor] as Vector2) * (occlusion_renderer.actor_visual_scales.get(actor, Vector2.ONE) as Vector2)
func _actor_visual_offset(actor: Sprite2D) -> Vector2:
	return PLAYER_TEXTURE_OFFSET if actor == player else Vector2.ZERO
func _collect_walkable_tiles(node: Node) -> void:
	if walkable_area != null: walkable_area.collect_geometry(node, Callable(self, "_tile_top_polygon")); walkable_points = walkable_area.points.duplicate(); walkable_polygons = walkable_area.polygons.duplicate()
func _build_walkable_outline() -> void:
	if walkable_area != null: walkable_area.build_outline(use_walkable_polygon_direct); walkable_outline = walkable_area.outline
func _build_entrance_block_polygons() -> void:
	entrance_block_polygons.clear()
	for socket_id in room_controller.dungeon_sockets.keys():
		if room_controller.active_door_sockets.has(socket_id) or room_controller.active_entrance_sockets.has(socket_id):
			continue
		var socket := room_controller.dungeon_sockets.get(socket_id) as DungeonSocket
		if socket == null:
			continue
		for tile in socket.block_tiles():
			entrance_block_polygons.append(_tile_top_polygon(tile))
	if walkable_area != null:
		walkable_area.set_entrance_blocks(entrance_block_polygons)
func _is_walkable(point: Vector2) -> bool:
	return walkable_area == null or walkable_area.is_walkable(point)
func _can_actor_stand_at_current_position(actor: Sprite2D) -> bool:
	return actor_collision_system.can_actor_stand(actor, slimes, Callable(self, "_actor_foot"), Callable(self, "_is_walkable"), Callable(self, "_is_slime_walkable_point"), Callable(self, "_collision_rect"))
func _is_slime_walkable_point(point: Vector2) -> bool:
	return walkable_area != null and walkable_area.is_slime_walkable(point)
func _tile_top_polygon(tile: Sprite2D) -> PackedVector2Array:
	return PackedVector2Array([tile.to_global(Vector2(8, 0)), tile.to_global(Vector2(16, 4)), tile.to_global(Vector2(8, 7)), tile.to_global(Vector2(0, 4))])
func _nearest_slime_walkable_point(point: Vector2) -> Vector2:
	return walkable_area.nearest_slime_walkable_point(point) if walkable_area != null and not walkable_area.is_empty() else point
func _random_slime_walkable_point_near(point: Vector2, sample_count: int, ignored_slime: Sprite2D = null) -> Vector2:
	return walkable_area.random_slime_walkable_point_near(point, sample_count, ignored_slime, rng, Callable(self, "_is_point_near_other_slime"))
func _is_point_near_other_slime(point: Vector2, ignored_slime: Sprite2D = null) -> bool:
	for slime in slimes:
		if slime == ignored_slime:
			continue
		if _is_slime_dead(slime):
			continue
		if _collision_rect(slime).grow(4.0).has_point(point):
			return true
	return false
func _actor_foot(actor: Sprite2D) -> Vector2:
	if actor == cloaked_demon: return _cloaked_demon_foot_position()
	return actor.global_position + ACTOR_FOOT_OFFSET
