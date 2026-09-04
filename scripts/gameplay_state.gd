extends Node2D
class_name GameplayState

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

@export_category("Debug")
@export var debug_start_in_boss_room := false
@export var debug_actor_geometry := false
@export var debug_stat_breakdown := false

const SLIME_ATTACK_FRAME_SIZE := Vector2i(16, 16)
const SLIME_NOTICE_FRAME_TIME := 0.10
const EDGE_MARGIN := 0.35
const SLIME_EDGE_PADDING := 1.25
const ACTOR_FOOT_OFFSET := Vector2(8, 15)
const DEPTH_Z_SCALE := 10.0
const OVERWORLD_UI_Z := 4090
const VERTICAL_MOVEMENT_SCALE := 0.5
const MAX_ACTIVE_ENEMY_ATTACKERS := 3
const PLAYER_ATTACK_FRAME_SIZE := Vector2i(36, 36)
const GAME_OVER_FADE_TIME := 0.8
const PLAYER_TEXTURE_OFFSET := Vector2(-10, -10)
const CHEST_INTERACT_DISTANCE := 16.0
const NPC_INTERACT_DISTANCE := 24.0
const FIRE_INTERACT_DISTANCE := 20.0
const PLAYER_PALETTE_FADE_IN := 0.06
const PLAYER_PALETTE_HOLD_TIME := 0.10
const PLAYER_PALETTE_FADE_OUT := 0.12
const CHEST_REWARD_GOLD := 100
const CHEST_COLLECT_FLASH_TIME := 0.12
const CHEST_UNLOCK_FADE_TIME := 0.45
const CHEST_EVAPORATE_PARTICLE_COUNT := 34
const CHEST_EVAPORATE_LIFETIME_MIN := 0.45
const CHEST_EVAPORATE_LIFETIME_MAX := 0.9
const FIRE_FRAME_TIME := 0.16
const FIRE_FRAME_SIZE := Vector2i(16, 16)
const CLOAKED_DEMON_FRAME_SIZE := Vector2i(36, 36)
const NPC_DIALOGUE_BUTTON_BOB_TIME := 1.6
const PLAYER_DOOR_FOOT_COLLIDER_SIZE := Vector2(3, 3)
const ACTOR_COLLISION_WIDTH := 9.0
const ACTOR_COLLISION_HEIGHT := 4.0
const CHEST_COLLISION_SIZE := Vector2(11, 6)
const TARGET_LOCK_MAX_DISTANCE := 9999.0
const FOCUS_TEXT_WIDTH := 19.0
const FOCUS_TEXT_HEIGHT := 5.0
const FOCUS_FLASH_TIME := 0.25
const OCCLUSION_RELEASE_GRACE := 0.08
const CONTROLLER_DEADZONE := 0.25
const CONTROLLER_TRIGGER_DEADZONE := 0.35
const PLAYER_MAX_MP := 100.0
const CHROMA_SATURATION_CURVE_EXPONENT := 0.65
const MAGIC_MP_COST := 10.0
const MAGIC_COOLDOWN := 2.0
const GREY_MAGIC_COOLDOWN := 2.5
const IMBUE_MP_COST := 40.0
const IMBUE_DURATION := 15.0
const IMBUE_COOLDOWN := 20.0
const IMBUE_HOLD_THRESHOLD := 0.35
const CHROMA_PICKUP_VALUE := 20
const CHROMA_PICKUP_DROP_CHANCE := 0.35
const CHROMA_PICKUP_COLLECTION_DISTANCE := 10.0
const CHROMA_PICKUP_AIR_TIME := 0.38
const SOUL_PICKUP_VALUE := 1
const SOUL_PICKUP_COLLECTION_DISTANCE := 10.0
const SOUL_PICKUP_AIR_TIME := 0.38
const SOUL_PICKUP_LAUNCH_SPEED := 18.0
const SOUL_PICKUP_LAUNCH_SPREAD := 10.0
const FLAME_SWAP_SOUL_COST := 5
const FLAME_FUSION_SOUL_COST := 5
const FLAME_FUSION_HOLD_THRESHOLD := 0.35
## Compatibility name retained for older dialogue/tests. A normal flame use is
## now the five-Soul Swap transaction.
const FIRE_SOUL_COST := FLAME_SWAP_SOUL_COST
const ELEMENT_BIND_SOUL_COST := 50
const SOUL_COLOR := Color8(167, 59, 167)
const SOUL_HIGHLIGHT_COLOR := Color8(234, 122, 197)
const MAGIC_PROJECTILE_SPEED := 70.0
const MAGIC_PROJECTILE_LIFETIME := 2.2
const MAGIC_PROJECTILE_SIZE := 3
const OCCLUDER_PATHS: Array[NodePath] = [
	^"Actors/Chest",
]
@onready var floor_tiles: Node2D = $Map/FloorTiles
@onready var map_root: Node2D = $Map
@onready var background_environment: Sprite2D = $BackgroundCanvas/Background
@onready var ui: Node2D = $InterfaceCanvas/UI
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
@onready var target_name_text: Sprite2D = $InterfaceCanvas/UI/SlimeText
@onready var target_health_bar: Sprite2D = $InterfaceCanvas/UI/EnemyHp
@onready var target_health_fill: Sprite2D = $InterfaceCanvas/UI/EnemyHpFill
@onready var player_health_fill: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/Health/HpBarFill
@onready var player_health_bar: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/Health/HpBar
@onready var player_health_text: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/Health/HpText
@onready var player_level_text: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/LevelXp/LevelTextAnchor/LevelText
@onready var player_xp_fill: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/LevelXp/XpBarFill
@onready var player_xp_text: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/LevelXp/XpText
@onready var player_mp_fill: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/Mana/MpBarFill
@onready var player_mp_text: Sprite2D = $InterfaceCanvas/UI/PlayerHud/PlayerStatus/Mana/MpText
@onready var player_stats: StatsComponent = $Actors/TinyDemon/Stats
var player_equipment: EquipmentComponent = null
var player_profile: PlayerProfile = null
var settings_service: SettingsService = null
var display_controller: DisplayController = null
var display_world_offset := Vector2.ZERO
var run_state: RunState = null
var current_dungeon_seed := 0
var has_persistent_profile := false
var player_health_component: HealthComponent = null
var player_motor: ActorMotor = null
var player_controller: PlayerController = null
var input_router: InputRouter = null
var input_device_tracker: Node = null
var touch_controls_layer: Node = null
var player_roll_component: PlayerRollComponent = null
var player_attack_component: PlayerAttackComponent = null
var player_chroma_component: Node = null
var player_aspect_ability_component: Node = null
var player_guard_component: PlayerGuardComponent = null
var equipment_transmutation_component: EquipmentTransmutationComponent = null
var player_animation_component: PlayerAnimationComponent = null
var player_equipment_visual_component: PlayerEquipmentVisualComponent = null
var profile_runtime_controller: Node = null
var pickup_runtime_controller: Node = null
var run_flow_controller: Node = null
var hub_flow_controller: Node = null
var save_flow_controller: Node = null
var cloud_save_service: CloudSaveService = null
var cloud_save_panel: CloudSavePanel = null
var room_puzzle_controller: Node = null
var magic_runtime_controller: Node = null
var targeting_runtime_controller: Node = null
var combat_runtime_controller: Node = null
var slime_runtime_controller: Node = null
var actor_presentation_runtime_controller: Node = null
var walkable_area: WalkableArea = null
var actor_collision_system: ActorCollisionSystem = null
var actor_geometry_debug_drawer: ActorGeometryDebugDrawer = null
var depth_sorter: DepthSorter = null
var occlusion_renderer: OcclusionRenderer = null
var room_controller: RoomController = null
var dungeon_map_controller: Node = null
var dungeon_minimap_controller: Node = null
var shadow_controller: ShadowController = null
var interaction_component: InteractionComponent = null
var chest_controller: ChestController = null
var npc_controller: NpcController = null
var rest_fire_controller: RestFireController = null
var hud_controller: HudController = null
var sound_manager: SoundManager = null
var music_wanted := false
var music_track_wanted: StringName = &""
var title_menu_frames := 0
var effects_spawner: EffectsSpawner = null
var screen_state_controller: Node = null
var gameplay_frame_controller: GameplayFrameController = null
var slime_attack_frames_by_palette: Dictionary = {}
var slime_shocked_frames_by_palette: Dictionary = {}
var slime_spawn_frames_by_palette: Dictionary = {}
var player_just_finished_attack2 := false
var player_between_timer := 0.0
var player_anim_name := "idle"
var player_anim_frame := 0
var player_anim_timer := 0.0
var orb_knockback_animation_lock := false
var orb_knockback_animation_grace := false
var orb_knockback_attack_cancelled := false
var player_footstep_cooldown := 0.0
var player_is_moving := false
var player_is_running := false
var player_is_attacking := false
var player_is_magic_casting := false
var player_is_rolling := false
var player_is_backflipping := false
var player_is_defending := false
## True while the player holds the lock-on/target input. Movement stays walk
## speed while targeting so the player cannot sprint into a lock.
var player_is_targeting := false
## Facing captured the frame the lock-on button was pressed, so a no-target
## backflip retreats while keeping the player's pre-target facing.
var player_facing_left_before_target := false
var last_player_input_direction := Vector2.RIGHT
var last_player_facing_left := false
var roll_dust_spawned_this_roll := false
var player_roll_input_was_down := false
## Whether the roll button is held this frame. The player runs while holding it
## (after a roll during the same hold) and moving.
var player_roll_input_held := false
## Latched true for the current roll-button hold when a roll dodge actually
## started. Released with the button so running is only a roll continuation.
var player_roll_hold_armed := false
var roll_dust_frames: Array[Texture2D] = []
var roll_dust_flipped_frames: Array[Texture2D] = []
var player_attack_input_was_down := false
var player_attack_hit_done := false
var player_attack_flip_h := false
var player_magic_flip_h := false
var player_imbued_element := ElementCatalogScript.Element.NEUTRAL
var player_hit_flash_timer := 0.0
var player_hitstun_timer := 0.0
var walkable_points: Array[Vector2] = []
var walkable_polygons: Array[PackedVector2Array] = []
var walkable_outline: PackedVector2Array = PackedVector2Array()
var entrance_block_polygons: Array[PackedVector2Array] = []
var use_walkable_polygon_direct := false
var slimes: Array[Sprite2D] = []
var puzzle_torches: Array[Sprite2D] = []
var orb_tutorial_prompt: Sprite2D = null
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
var combat_momentum: CombatMomentumComponent = null
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
var last_game_over_focus: Button = null
var player_agi := 0.0
## Temporary compatibility property for pre-AGI runtime callers and saved
## characterization tests. New gameplay code should read player_agi.
var player_spd:
	get:
		return player_agi
	set(value):
		player_agi = float(value)
var player_speed_multiplier := 1.0
var final_exit_open := false
var settlement_room_active := false
var scene_transition_overlay: ColorRect = null
var scene_transition_timer := 0.0
var scene_transition_active := false
var loading_screen_overlay: ColorRect = null
var loading_screen_text: Sprite2D = null
var loading_screen_active := false
var boot_active := false
var loading_screen_fading := false
var loading_screen_timer := 0.0
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
var current_room_type: StringName = DungeonGraph.ROOM_START
var room_transition_locked := false
var normal_room_geometry: Dictionary = {}
var chest_normal_texture: Texture2D = null
var chest_gray_texture: Texture2D = null
var chest_unlock_overlay: Sprite2D = null
var chest_flash_overlay: Sprite2D = null
var interact_prompt: Sprite2D = null
var interact_prompt_base_position := Vector2.ZERO
var world_item_drops: Array[Dictionary] = []
var chroma_pickup_controller: ChromaPickupController = null
var soul_pickup_controller: SoulPickupController = null
var target_health_text: Sprite2D = null
var focus_label: Sprite2D = null
var focus_label_base: Sprite2D = null
var focus_flash_timer := 0.0
var player_start_position := Vector2.ZERO
var chest_start_position := Vector2.ZERO
var cloaked_demon_start_position := Vector2.ZERO
var target_health_damage_fill: Sprite2D = null
var target_health_bar_size := Vector2.ZERO
var player_health_fill_size := Vector2.ZERO
var health_bar_texture_cache: Dictionary = {}
var player_health_damage_fill: Sprite2D = null
var player_display_health := 0.0
var player_damage_fill_hold_timer := 0.0
var current_player_palette_name := "blue"
var player_mp_fill_size := Vector2.ZERO
var mp_desaturation_material: ShaderMaterial = null
var mp_desaturation_attack_material: ShaderMaterial = null
var magic_input_was_down := false
var magic_projectile_controller: MagicProjectileController = null
var slime_last_valid_positions: Dictionary = {}
## Per-frame enemy data is shared by movement, combat, and HUD updates.  Keeping
## it here avoids each slime repeatedly re-scanning the whole encounter.
var slime_frame_aggro: Dictionary = {}
var slime_frame_slots: Dictionary = {}
var slime_frame_active_attackers := 0
var slime_frame_cache_valid := false
var rest_fire_frames: Array[Texture2D] = []
var rest_fire_base_frames: Array[Texture2D] = []
var rest_fire_frames_by_palette: Dictionary = {}
var current_fire_palette_name := ""
var run_start_palette_name := ""
var starter_flame_attuned_this_run := false
var player_palette_flash_timer := 0.0
var player_palette_flash_phase := 0
var player_palette_flash_overlay: Sprite2D = null
var rng := RandomNumberGenerator.new()
var sprite_frame_library := SpriteFrameLibrary.new()
var combat_tuning := CombatTuning.new()
var progression_tuning := ProgressionTuning.new()
var player_tuning := PlayerTuning.new()
var slime_tuning := SlimeTuning.new()
var effects_tuning := EffectsTuning.new()
var chroma_tuning := ChromaTuning.new()

## Legacy callback bridge

# These methods preserve the callback surface used by older runtime components.
# Feature state and behavior remain owned by the dedicated controllers; this
# bridge is intentionally isolated from the composition root for removal in the
# typed-context cleanup phase.
func _update_mp_desaturation() -> void:
	var saturation := _chroma_visual_saturation()
	var material_was_created := false
	if mp_desaturation_material == null:
		mp_desaturation_material = _new_mp_desaturation_material()
		material_was_created = true
	if mp_desaturation_attack_material == null:
		mp_desaturation_attack_material = _new_mp_desaturation_material()
		material_was_created = true
	mp_desaturation_material.set_shader_parameter("grey_mix", 1.0 - saturation)
	mp_desaturation_attack_material.set_shader_parameter("grey_mix", 1.0 - saturation)
	if player != null:
		player.material = mp_desaturation_material
	if player_attack_visual != null:
		player_attack_visual.material = mp_desaturation_attack_material
	if player_equipment_visual_component != null:
		player_equipment_visual_component.set_mp_desaturation(saturation)
	if material_was_created and player_animation_component != null:
		# The first animation frame may have been assigned before the material
		# existed, so initialize the sampler with its matching grey frame now.
		player_animation_component.apply_frame(self)


func _new_mp_desaturation_material() -> ShaderMaterial:
	var desaturation_material := ShaderMaterial.new()
	desaturation_material.shader = preload("res://shaders/mp_desaturation.gdshader")
	return desaturation_material


func _set_mp_grey_texture(texture: Texture2D) -> void:
	var animation_name := String(player_anim_name)
	# Charge deliberately renders through the base player sprite: the attack
	# overlay is hidden while the authored between-attacks pose is held. Do not
	# route its grey reference frame to the attack material, or the base sprite
	# keeps sampling the previous attack frame. That stale sample only becomes
	# visible as Chroma falls, which makes the charge look like a ghostly,
	# Chroma-dependent animation.
	var attack_animation := animation_name.begins_with("attack") or animation_name == "spin_attack"
	var active_desaturation_material := mp_desaturation_attack_material if player_is_attacking and attack_animation else mp_desaturation_material
	if active_desaturation_material != null:
		active_desaturation_material.set_shader_parameter("grey_texture", texture)
		active_desaturation_material.set_shader_parameter("grey_mix", 1.0 - _chroma_visual_saturation())
func _chroma_visual_saturation() -> float:
	var normalized := clampf(_current_player_chroma() / PLAYER_MAX_MP, 0.0, 1.0)
	if normalized <= 0.0:
		return 0.0
	if normalized >= 1.0:
		return 1.0
	# Keep the character colorful through most of the bar, then let the low end
	# fall toward Gray more sharply. With the current exponent, 80/50/20 map
	# approximately to 86/64/31 percent visual saturation.
	return pow(normalized, CHROMA_SATURATION_CURVE_EXPONENT)
func _play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sound_manager != null:
		sound_manager.play(sound_name, volume_db, pitch_scale)
func _is_ui_accept_pressed() -> bool: return input_router != null and input_router.ui_accept_pressed()
func _is_ui_accept_just_pressed() -> bool: return input_router != null and input_router.ui_accept_just_pressed()
func _is_ui_cancel_just_pressed() -> bool: return input_router != null and input_router.menu_cancel_just_pressed()
func _is_menu_confirm_pressed() -> bool: return input_router != null and input_router.menu_confirm_pressed()
func _is_menu_confirm_just_pressed() -> bool: return input_router != null and input_router.menu_confirm_just_pressed()
func _is_menu_back_pressed() -> bool: return input_router != null and input_router.menu_back_pressed()
func _is_menu_back_just_pressed() -> bool: return input_router != null and input_router.menu_back_just_pressed()
func _is_menu_direction_just_pressed(direction: StringName) -> bool: return input_router != null and input_router.menu_direction_just_pressed(direction)
func _input_touch_scroll_y() -> float: return input_router.touch_scroll_y() if input_router != null else 0.0
func _is_touch_input_device() -> bool: return input_device_tracker != null and int(input_device_tracker.get("current_device")) == InputDeviceTracker.Device.TOUCH
func _menu_confirm_prompt() -> String: return input_device_tracker.menu_confirm_prompt() if input_device_tracker != null else "ENTER SELECT"
func _menu_back_prompt() -> String: return input_device_tracker.menu_back_prompt() if input_device_tracker != null else "ESC BACK"
func _is_ui_direction_just_pressed(direction: StringName) -> bool: return input_router != null and input_router.ui_direction_just_pressed(direction)
func _apply_player_palette_async(palette_name: String) -> void:
	if player_animation_component != null: player_animation_component.apply_palette_async(self, palette_name)
	if player_equipment_visual_component != null: player_equipment_visual_component.apply_palette(self)
	var player_hud := ui.get_node_or_null("PlayerHud") as Node2D
	if player_hud != null:
		player_hud.call("apply_bar_colors", _health_feedback_color(palette_name), PaletteLibrary.accent(palette_name))
		player_hud.call("apply_portrait_palette", palette_name, sprite_frame_library)
	_update_player_progression_ui()
	_update_mp_desaturation()
func _set_entrance_open(is_open: bool) -> void:
	# The boss arrival route remains sealed for the entire encounter. The only
	# path that opens it is _open_final_exit after all encounter actors are dead.
	if is_open and current_room_type == DungeonGraph.ROOM_DOWNSTAIRS and not final_exit_open:
		is_open = false
	entrance_open = is_open; _refresh_room_socket_visuals(door_active)
func _is_interaction_target_in_front(target_position: Vector2) -> bool:
	return interaction_component == null or interaction_component.target_is_in_front(self, target_position)


func _current_player_element() -> int:
	if player_chroma_component == null or not is_instance_valid(player_chroma_component):
		return ElementCatalogScript.Element.NEUTRAL
	return ElementCatalogScript.element_for_aspect(int(player_chroma_component.get("current_aspect")))


func _sync_current_element_state() -> void:
	if dungeon_map_controller == null or not dungeon_map_controller.has_method("set_current_element"):
		return
	dungeon_map_controller.call("set_current_element", _current_player_element())


func _can_bind_current_element() -> bool:
	if player_chroma_component == null:
		return false
	var current := StringName(player_chroma_component.call("aspect_name"))
	return AspectCatalogScript.is_elemental_flame(current) and not bool(player_chroma_component.call("current_is_bound"))


func _bind_current_element() -> bool:
	if player_profile == null or player_chroma_component == null:
		return false
	var current := StringName(player_chroma_component.call("aspect_name"))
	if not AspectCatalogScript.is_elemental_flame(current):
		return false
	if bool(player_chroma_component.call("current_is_bound")):
		_show_fire_exchange_text("%s ALREADY BOUND" % String(current).to_upper(), _health_feedback_color(AspectCatalogScript.palette_for_flame(current)))
		_play_sound("ui_no_input", 0.0, 1.0)
		return true
	if not player_profile.bind_element(current):
		_show_fire_exchange_text("NEED %d SOULS" % ELEMENT_BIND_SOUL_COST, Color8(255, 105, 105))
		_play_sound("ui_no_input", 0.0, 1.0)
		return false
	player_chroma_component.call("set_bound_flame", current)
	var palette := AspectCatalogScript.palette_for_flame(current)
	player_profile.palette_name = palette
	call("_save_player_profile")
	_update_soul_indicator()
	_sync_current_element_state()
	if current_room_type == DungeonGraph.ROOM_START:
		run_start_palette_name = palette
		call("_apply_rest_fire_palette", palette)
	_show_fire_exchange_text("BOUND %s" % String(current).to_upper(), _health_feedback_color(palette))
	_play_sound("use_flame", 0.0, 1.0)
	return true


func _hub_bind_current_element() -> bool:
	if hub_flow_controller == null:
		return false
	return bool(hub_flow_controller.call("hub_bind_current_element", self))


func _can_interact_with_npc() -> bool:
	if cloaked_demon == null or not cloaked_demon.visible:
		return false
	var target_position := _cloaked_demon_visual_center()
	return _actor_foot(player).distance_to(target_position) <= NPC_INTERACT_DISTANCE and _is_interaction_target_in_front(target_position)
func _fire_anchor() -> Vector2:
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	if firepit != null:
		return _collision_rect(firepit).get_center()
	return rest_fire.global_position
func _white_texture(source: Texture2D) -> Texture2D: return occlusion_renderer.white_texture(source)
func _load_texture_or_null(path: String) -> Texture2D: return load(path) as Texture2D if ResourceLoader.exists(path) else null
func _cloaked_demon_texture_origin() -> Vector2:
	return cloaked_demon.global_position + cloaked_demon.offset - cloaked_demon.texture.get_size() * 0.5 if cloaked_demon.centered and cloaked_demon.texture != null else cloaked_demon.global_position + cloaked_demon.offset
func _apply_profile_to_runtime() -> void:
	profile_runtime_controller.call("apply_profile_to_runtime", self)
func _reapply_equipment_preserving_health() -> void:
	profile_runtime_controller.call("reapply_equipment_preserving_health", self)
func _refresh_player_cloak_visual() -> void:
	if player_profile == null or player_animation_component == null:
		return
	var body_instance_id := player_profile.get_equipped_instance_id(&"body")
	var body_item := player_profile.find_item(body_instance_id)
	player_animation_component.set_cloaked(self, body_item != null and body_item.definition_id == &"demon_cloak")
func _equip_profile_item(instance_id: String) -> bool:
	return bool(profile_runtime_controller.call("equip_profile_item", self, instance_id))
func _unequip_profile_slot(slot: StringName) -> bool:
	return bool(profile_runtime_controller.call("unequip_profile_slot", self, slot))
func _spawn_chest_item_drops(items: Array[ItemInstance]) -> void:
	pickup_runtime_controller.call("spawn_chest_item_drops", self, items)
func _restore_chest_item_drops(saved_drops: Array) -> void:
	pickup_runtime_controller.call("restore_chest_item_drops", self, saved_drops)
func _clear_world_item_drops() -> void:
	pickup_runtime_controller.call("clear_world_item_drops", self)
func _constrain_world_item_drops() -> void:
	pickup_runtime_controller.call("constrain_world_item_drops", self)
func _update_world_item_drops(delta: float) -> void:
	pickup_runtime_controller.call("update_world_item_drops", self, delta)
func _world_item_drop_position() -> Vector2:
	return pickup_runtime_controller.call("world_item_drop_position", self) as Vector2
func _can_interact_with_world_item() -> bool:
	return bool(pickup_runtime_controller.call("can_interact_with_world_item", self))
func _collect_world_item_drop() -> bool:
	return bool(pickup_runtime_controller.call("collect_world_item_drop", self))
func _spawn_chroma_pickup(spawn_position: Vector2, value: int = CHROMA_PICKUP_VALUE, launch_seed: int = 0, launch_direction: Vector2 = Vector2.ZERO, avoid_position: Variant = null) -> Vector2:
	return pickup_runtime_controller.call("spawn_chroma_pickup", self, spawn_position, value, launch_seed, launch_direction, avoid_position) as Vector2
func _restore_chroma_pickups(saved_pickups: Array) -> void:
	pickup_runtime_controller.call("restore_chroma_pickups", self, saved_pickups)
func _update_chroma_pickups(delta: float) -> void:
	pickup_runtime_controller.call("update_chroma_pickups", self, delta)
func _collect_chroma_pickup(index: int) -> void:
	pickup_runtime_controller.call("collect_chroma_pickup", self, index)
func _spawn_chroma_pickup_burst(spawn_position: Vector2) -> void:
	if effects_spawner != null:
		effects_spawner.spawn_chroma_pickup_burst_from_root(self, spawn_position)
func _remove_chroma_pickup(index: int) -> void:
	pickup_runtime_controller.call("remove_chroma_pickup", self, index)
func _clear_chroma_pickups() -> void:
	pickup_runtime_controller.call("clear_chroma_pickups", self)
func _spawn_soul_pickup(spawn_position: Vector2, value: int = SOUL_PICKUP_VALUE, launch_seed: int = 0, launch_direction: Vector2 = Vector2.ZERO, avoid_position: Variant = null) -> Vector2:
	return pickup_runtime_controller.call("spawn_soul_pickup", self, spawn_position, value, launch_seed, launch_direction, avoid_position) as Vector2
func _update_soul_pickups(delta: float) -> void:
	pickup_runtime_controller.call("update_soul_pickups", self, delta)
func _collect_soul_pickup(index: int) -> void:
	pickup_runtime_controller.call("collect_soul_pickup", self, index)
func _remove_soul_pickup(index: int) -> void:
	pickup_runtime_controller.call("remove_soul_pickup", self, index)
func _clear_soul_pickups() -> void:
	pickup_runtime_controller.call("clear_soul_pickups", self)
func _loot_grade_bonus(grade: String = "") -> float:
	return float(run_flow_controller.call("loot_grade_bonus", self, grade))
func _chest_item_drop_chance() -> float:
	return float(run_flow_controller.call("chest_item_drop_chance", self))
func _chest_item_drop_count(roll: float) -> int:
	return int(run_flow_controller.call("chest_item_drop_count", self, roll))
func _chest_gold_reward(base_gold: int) -> int:
	return int(run_flow_controller.call("chest_gold_reward", self, base_gold))
func _set_gold_value(value: int) -> void:
	profile_runtime_controller.call("set_gold_value", self, value)
func _sync_runtime_progression_to_profile() -> void:
	profile_runtime_controller.call("sync_runtime_progression_to_profile", self)
func _respec_player_stats() -> int:
	return int(profile_runtime_controller.call("respec_player_stats", self))
func _start_player_death() -> void:
	_cancel_magic_animation()
	_reset_magic_runtime(true)
	effects_spawner.begin_player_death(self, DEPTH_Z_SCALE)
	if player_equipment_visual_component != null: player_equipment_visual_component.begin_death(self)
func _update_player_death(delta: float) -> void: screen_state_controller.update_player_death(self, delta, GAME_OVER_FADE_TIME)
func _spawn_player_death_pixels() -> void: effects_spawner.spawn_player_death_particles(self, player_death_texture, player_death_origin, player_death_offset, player_death_scale, int(round(_depth_key(player) * DEPTH_Z_SCALE)) + 2, player_tuning.death_particle_lifetime, rng.randi(), Callable(self, "_pixel_particle_texture"))
func _build_game_over_ui() -> void: var controls: Dictionary = screen_state_controller.build_game_over(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_return_to_hub"), Callable(self, "_return_to_title")); game_over_overlay = controls["overlay"] as ColorRect; game_over_button = controls["restart"] as Button; game_over_title_button = controls["title"] as Button; screen_state_controller.game_over_cursor_text = controls["cursor"] as Sprite2D; screen_state_controller.game_over_footer_text = controls["footer"] as Sprite2D
func _build_run_complete_ui() -> void:
	var controls: Dictionary = screen_state_controller.build_run_complete(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_return_from_run_complete"))
	screen_state_controller.run_complete_overlay = controls["overlay"] as ColorRect
	screen_state_controller.run_complete_texts = controls["lines"] as Array[Sprite2D]
	screen_state_controller.run_complete_button = controls["return"] as Button
	screen_state_controller.run_complete_cursor = controls["cursor"] as Sprite2D
	screen_state_controller.run_complete_footer_text = controls["footer"] as Sprite2D
func _build_settings_ui() -> void:
	var controls: Dictionary = screen_state_controller.build_settings(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_adjust_setting"), Callable(self, "_close_settings"), Callable(self, "_select_setting_option"))
	screen_state_controller.settings_overlay = controls["overlay"] as ColorRect
	screen_state_controller.settings_title_text = controls["title"] as Sprite2D
	screen_state_controller.settings_row_labels = controls["labels"] as Array[Sprite2D]
	screen_state_controller.settings_value_buttons = controls["values"] as Array[Button]
	screen_state_controller.settings_left_buttons = controls["left"] as Array[Button]
	screen_state_controller.settings_right_buttons = controls["right"] as Array[Button]
	screen_state_controller.settings_option_buttons = controls["options"] as Array[Array]
	screen_state_controller.settings_back_button = controls["back"] as Button
	screen_state_controller.settings_description_text = controls["description"] as Sprite2D
	screen_state_controller.settings_cursor_text = controls["cursor"] as Sprite2D
func _open_settings_from_title() -> void:
	screen_state_controller.open_settings(self, &"title")
func _open_settings_from_pause() -> void:
	screen_state_controller.open_settings(self, &"pause")
func _adjust_setting(row: int, direction: int) -> void:
	screen_state_controller.adjust_setting(self, row, direction)
func _select_setting_option(row: int, option_index: int) -> void:
	screen_state_controller.select_setting_option(self, row, option_index)
func _update_settings_input() -> void:
	screen_state_controller.update_settings_input(self)
func _close_settings() -> void:
	screen_state_controller.close_settings(self)
func _quit_to_title_from_pause() -> void:
	if screen_state_controller.pause_overlay != null:
		screen_state_controller.pause_overlay.visible = false
	if screen_state_controller.hub_overlay != null:
		screen_state_controller.hub_overlay.visible = false
	call("_return_to_title")
func _build_hub_ui() -> void:
	hub_flow_controller.call("build_hub_ui", self)
func _on_display_view_size_changed(_view_size: Vector2i = DisplayLayout.NATIVE_SIZE) -> void:
	if hud_controller != null and hud_controller.has_method("apply_display_layout"):
		hud_controller.apply_display_layout(self)
	if screen_state_controller != null and screen_state_controller.has_method("apply_display_layout"):
		screen_state_controller.apply_display_layout(self)
	var view_size := Vector2(_view_size)
	if scene_transition_overlay != null:
		scene_transition_overlay.size = view_size
	if loading_screen_overlay != null:
		loading_screen_overlay.size = view_size
		if loading_screen_text != null and loading_screen_text.texture != null:
			loading_screen_text.position = view_size - loading_screen_text.texture.get_size() - Vector2(4, 4)
	if touch_controls_layer != null and touch_controls_layer.has_method("refresh_layout"):
		touch_controls_layer.refresh_layout()
func _show_hub(from_npc: bool = false, pause_mode: bool = false) -> void:
	hub_flow_controller.call("show_hub", self, from_npc, pause_mode)
func _open_pause_menu() -> void:
	hub_flow_controller.call("open_pause_menu", self)
func _open_hub_from_cloaked_demon() -> void:
	hub_flow_controller.call("open_hub_from_cloaked_demon", self)
func _close_hub_to_run() -> void:
	hub_flow_controller.call("close_hub_to_run", self)
func _hub_back_or_close() -> void:
	if screen_state_controller.pause_overlay != null and screen_state_controller.pause_overlay.visible:
		_pause_back()
	elif screen_state_controller.hub_overlay != null and screen_state_controller.hub_overlay.visible:
		hub_flow_controller.call("back_from_hub_route", self)
func _update_hub_input() -> void: hub_flow_controller.call("update_hub_input", self)
func _update_pause_input() -> void: screen_state_controller.update_pause_input(self)
func _is_hub_previous_page_input_pressed() -> bool: return player_controller.guard_held(_controller_devices(), 0.35)
func _is_hub_next_page_input_pressed() -> bool: return player_controller.target_held(_controller_devices(), 0.35)
func _is_menu_cancel_input_pressed() -> bool: return player_controller.action_pressed(&"cancel", _controller_devices(), JOY_BUTTON_A)
func _is_pause_input_just_pressed() -> bool:
	var is_down := input_router != null and input_router.pressed(&"pause")
	var just_pressed: bool = is_down and not bool(screen_state_controller.pause_input_was_down)
	screen_state_controller.pause_input_was_down = is_down
	return just_pressed
func _input_context() -> int:
	if screen_state_controller == null: return InputRouter.Context.GAMEPLAY
	var ssc := screen_state_controller as ScreenStateController
	if loading_screen_active or scene_transition_active:
		return InputRouter.Context.MENU
	if game_over_overlay != null and game_over_overlay.visible:
		return InputRouter.Context.MENU
	if ssc.run_complete_overlay != null and ssc.run_complete_overlay.visible:
		return InputRouter.Context.MENU
	if ssc.save_select_overlay != null and ssc.save_select_overlay.visible: return InputRouter.Context.MENU
	if ssc.settings_overlay != null and ssc.settings_overlay.visible: return InputRouter.Context.MENU
	if ssc.name_entry_overlay != null and ssc.name_entry_overlay.visible: return InputRouter.Context.MENU
	if ssc.title_overlay != null and ssc.title_overlay.visible: return InputRouter.Context.MENU
	if ssc.archetype_overlay != null and ssc.archetype_overlay.visible: return InputRouter.Context.MENU
	if ssc.pause_overlay != null and ssc.pause_overlay.visible: return InputRouter.Context.PAUSE
	if ssc.hub_overlay != null and ssc.hub_overlay.visible: return InputRouter.Context.HUB
	if npc_controller != null and npc_controller.dialogue_box != null and npc_controller.dialogue_box.visible: return InputRouter.Context.DIALOGUE
	return InputRouter.Context.GAMEPLAY
func _set_hub_page(page: int) -> void:
	hub_flow_controller.call("set_hub_page", self, page)
func _shift_hub_item(direction: int) -> void:
	hub_flow_controller.call("shift_hub_item", self, direction)
func _shift_hub_slot_grid(column_direction: int, row_direction: int) -> void:
	hub_flow_controller.call("shift_hub_slot_grid", self, column_direction, row_direction)
func _select_hub_item_row(row: int) -> void:
	hub_flow_controller.call("select_hub_item_row", self, row)
func _hub_gear_candidates(slot: StringName) -> Array[ItemInstance]:
	return hub_flow_controller.call("hub_gear_candidates", self, slot) as Array[ItemInstance]
func _shift_hub_gear_candidate(direction: int) -> void:
	hub_flow_controller.call("shift_hub_gear_candidate", self, direction)
func _shift_hub_gear_candidate_grid(column_direction: int, row_direction: int) -> void:
	hub_flow_controller.call("shift_hub_gear_candidate_grid", self, column_direction, row_direction)
func _select_hub_gear_slot(slot_index: int) -> void:
	hub_flow_controller.call("select_hub_gear_slot", self, slot_index)
func _select_hub_gear_candidate(choice_row: int) -> void:
	hub_flow_controller.call("select_hub_gear_candidate", self, choice_row)
func _close_hub_gear_browse() -> void:
	hub_flow_controller.call("close_hub_gear_browse", self)
func _refresh_hub_fusion_candidates() -> void:
	hub_flow_controller.call("refresh_hub_fusion_candidates", self)
func _invalidate_hub_fusion_candidates() -> void:
	hub_flow_controller.call("invalidate_hub_fusion_candidates", self)
func _hub_fusion_candidates() -> Array[ItemInstance]:
	return hub_flow_controller.call("hub_fusion_candidates", self) as Array[ItemInstance]
func _fuse_profile_target(instance_id: String, count: int) -> bool:
	return bool(hub_flow_controller.call("fuse_profile_target", self, instance_id, count))
func _shift_hub_fusion_count(direction: int) -> void:
	hub_flow_controller.call("shift_hub_fusion_count", self, direction)
func _salvage_profile_overflow(instance_id: String) -> int:
	return int(hub_flow_controller.call("salvage_profile_overflow", self, instance_id))
func _hub_item_action() -> void:
	hub_flow_controller.call("hub_item_action", self)
func _remove_hub_gear() -> void:
	hub_flow_controller.call("remove_hub_gear", self)
func _remove_all_hub_gear() -> void:
	hub_flow_controller.call("remove_all_hub_gear", self)
func _cancel_hub_remove_all() -> void:
	hub_flow_controller.call("cancel_remove_all_hub_gear", self)
func _select_hub_menu_row(row: int) -> void:
	hub_flow_controller.call("select_hub_menu_row", self, row)
func _select_hub_stat_row(row: int) -> void:
	hub_flow_controller.call("select_hub_stat_row", self, row)
func _set_pause_status_page() -> void:
	screen_state_controller.set_pause_page(self, 1)
func _set_pause_equipment_page() -> void:
	screen_state_controller.set_pause_page(self, 2)
func _pause_back() -> void:
	screen_state_controller.pause_back(self)
func _pause_equipment_back() -> void:
	screen_state_controller.pause_equipment_back(self)
func _shift_hub_action_column(direction: int) -> void:
	hub_flow_controller.call("shift_hub_action_column", self, direction)
func _hub_adjust_stat(stat_name: StringName, direction: int) -> void:
	hub_flow_controller.call("hub_adjust_stat", self, stat_name, direction)
func _hub_allocate_stat(stat_name: StringName) -> void:
	hub_flow_controller.call("hub_allocate_stat", self, stat_name)
func _hub_points_remaining() -> int: return int(hub_flow_controller.call("hub_points_remaining", self))
func _hub_confirm_stats() -> void:
	hub_flow_controller.call("hub_confirm_stats", self)
func _hub_cancel_stats(play_feedback: bool = true) -> void:
	hub_flow_controller.call("hub_cancel_stats", self, play_feedback)
func _hub_auto_allocate() -> void:
	hub_flow_controller.call("hub_auto_allocate", self)
func _hub_respec() -> void:
	hub_flow_controller.call("hub_respec", self)
func _start_from_hub() -> void:
	hub_flow_controller.call("start_from_hub", self)
func _run_difficulty_bonus() -> int:
	return int(run_flow_controller.call("run_difficulty_bonus", self))
func _run_rank() -> int:
	return int(run_flow_controller.call("run_rank", self))
func _apply_run_rank_grade(grade: String) -> void:
	run_flow_controller.call("apply_run_rank_grade", self, grade)
func _begin_new_run() -> void:
	run_flow_controller.call("begin_new_run", self)
func _return_to_hub() -> void:
	run_flow_controller.call("return_to_hub", self)
func _settle_current_run(result: StringName) -> bool:
	return bool(run_flow_controller.call("settle_current_run", self, result))
func _tick_run_telemetry(delta: float) -> void:
	run_flow_controller.call("tick_run_telemetry", self, delta)
func _is_run_combat_active() -> bool:
	return bool(run_flow_controller.call("is_run_combat_active", self))
func _on_player_successful_block(_shield_damage: float, _health_damage: float) -> void:
	run_flow_controller.call("on_player_successful_block", self, _shield_damage, _health_damage)
func _record_run_style_action(action: StringName) -> void:
	run_flow_controller.call("record_style_action", self, action)
func _record_run_action_input(action: StringName, accepted: bool) -> void:
	run_flow_controller.call("record_run_action_input", self, action, accepted)
func _clear_reward_rarity(score: int, roll: float) -> StringName:
	return run_flow_controller.call("clear_reward_rarity", self, score, roll) as StringName
func _roll_run_loot_rarity(roll: float, score_quality: float = -1.0) -> StringName:
	return run_flow_controller.call("roll_run_loot_rarity", self, roll, score_quality) as StringName
func _complete_run() -> void:
	run_flow_controller.call("complete_run", self)
func _show_run_complete(drop_color: Color) -> void:
	run_flow_controller.call("show_run_complete", self, drop_color)
func _run_metric_color(quality: float) -> Color:
	return run_flow_controller.call("metric_color", quality) as Color
func _update_run_complete_input() -> void:
	if screen_state_controller.run_complete_button == null:
		return
	if screen_state_controller.run_complete_footer_text != null:
		screen_state_controller.run_complete_footer_text.texture = screen_state_controller._pixel_prompt_texture(Callable(self, "_pixel_text_texture"), _menu_back_prompt(), Color8(148, 220, 255))
	if screen_state_controller.menu_input_release_lock:
		var released := not _is_menu_confirm_pressed() and not _is_menu_back_pressed()
		if released:
			screen_state_controller.menu_input_release_lock = false
		return
	if _is_menu_confirm_just_pressed() or _is_menu_back_just_pressed():
		screen_state_controller.run_complete_button.pressed.emit()
func _return_from_run_complete() -> void:
	run_flow_controller.call("return_from_run_complete", self)
func _show_game_over() -> void:
	if game_over_overlay == null or game_over_overlay.visible: return
	_apply_run_rank_grade("F")
	_settle_current_run(&"defeat")
	game_over_overlay.visible = true
	screen_state_controller.set_state(&"game_over")
	game_over_fade_timer = 0.0
	game_over_overlay.modulate.a = 0.0
	screen_state_controller.game_over_row = 0
	screen_state_controller.menu_input_release_lock = true
	last_game_over_focus = null
	if game_over_button != null: game_over_button.release_focus()
	if game_over_title_button != null: game_over_title_button.release_focus()
func _build_title_screen() -> void: save_flow_controller.call("build_title_screen", self)
func _open_cloud_save() -> void: cloud_save_panel.open()
func _build_archetype_screen() -> void: save_flow_controller.call("build_archetype_screen", self)
func _update_title_screen(delta: float) -> void: save_flow_controller.call("update_title_screen", self, delta)
func _start_new_game() -> void: save_flow_controller.call("start_new_game", self)
func _continue_game() -> void: save_flow_controller.call("continue_game", self)
func _open_save_select_after_title_transition() -> void:
	save_flow_controller.call("open_save_select_after_title_transition", self)
func _update_save_select_cursor() -> void:
	save_flow_controller.call("update_save_select_cursor", self)
func _save_preview_texture(palette_name: String) -> Texture2D:
	return save_flow_controller.call("save_preview_texture", self, palette_name) as Texture2D

func _save_portrait_texture(palette_name: String) -> Texture2D:
	return save_flow_controller.call("save_portrait_texture", self, palette_name) as Texture2D
func _select_save_slot(slot: int) -> void:
	save_flow_controller.call("select_save_slot", self, slot)
func _finish_name_entry(player_name: String) -> void:
	save_flow_controller.call("finish_name_entry", self, player_name)
func _cancel_name_entry() -> void:
	screen_state_controller.cancel_name_entry(self)
func _set_overwrite_prompt(active: bool) -> void:
	save_flow_controller.call("set_overwrite_prompt", self, active)
func _cancel_overwrite() -> void:
	save_flow_controller.call("cancel_overwrite", self)
func _confirm_overwrite() -> void:
	save_flow_controller.call("confirm_overwrite", self)
func _reset_runtime_for_new_save() -> void:
	save_flow_controller.call("reset_runtime_for_new_save", self)
func _update_overwrite_cursor() -> void:
	save_flow_controller.call("update_overwrite_cursor", self)
func _close_save_select() -> void:
	save_flow_controller.call("close_save_select", self)
func _cancel_character_creation() -> void:
	save_flow_controller.call("cancel_character_creation", self)
func _select_continue_slot(slot: int) -> void:
	save_flow_controller.call("select_continue_slot", self, slot)
func _enter_starting_room_from_menu() -> void:
	save_flow_controller.call("enter_starting_room_from_menu", self)
func _place_player_at_hub_fire() -> void:
	save_flow_controller.call("place_player_at_hub_fire", self)
func _update_archetype_input(delta: float) -> void: save_flow_controller.call("update_archetype_input", self, delta)
func _shift_archetype(direction: int) -> void: save_flow_controller.call("shift_archetype", self, direction)
func _shift_archetype_color(direction: int) -> void: save_flow_controller.call("shift_archetype_color", self, direction)
func _archetype_arrow_pulse(direction: int) -> void: save_flow_controller.call("archetype_arrow_pulse", self, direction)
func _update_archetype_arrow_animation() -> void: save_flow_controller.call("update_archetype_arrow_animation", self)
func _select_archetype_menu_row(row: int) -> void: save_flow_controller.call("select_archetype_menu_row", self, row)
func _update_archetype_screen() -> void: save_flow_controller.call("update_archetype_screen", self)
func _update_archetype_preview_animation() -> void: save_flow_controller.call("update_archetype_preview_animation", self)
func _update_archetype_button_styles() -> void: save_flow_controller.call("update_archetype_button_styles", self)
func _start_selected_archetype() -> void: save_flow_controller.call("start_selected_archetype", self)
func _build_loading_screen() -> void: save_flow_controller.call("build_loading_screen", self)
func _update_loading_screen(delta: float) -> void: save_flow_controller.call("update_loading_screen", self, delta)
func _update_player_aggro_marker_colors() -> void: hud_controller.update_aggro_markers(hud_controller.target_overhead_aggro_markers, screen_state_controller.player_palette_name, Callable(self, "_pixel_particle_texture"))
func _spawn_title_pixel_breakup(source_sprite: Sprite2D) -> void:
	if screen_state_controller.title_particle_layer == null:
		screen_state_controller.title_particle_layer = Node2D.new(); screen_state_controller.title_particle_layer.name = "TitleParticleLayer"; screen_state_controller.title_particle_layer.z_index = 10; ui.add_child(screen_state_controller.title_particle_layer)
	screen_state_controller.spawn_pixel_breakup(source_sprite, screen_state_controller.title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _spawn_title_ui_breakup() -> void:
	_spawn_title_pixel_breakup(screen_state_controller.title_screen_text)
	var version: Sprite2D = screen_state_controller.title_overlay.get_node_or_null("TitleVersion") as Sprite2D if screen_state_controller.title_overlay != null else null
	_spawn_title_pixel_breakup(version)
	var buttons: Array[Button] = [screen_state_controller.title_start_button, screen_state_controller.title_continue_button, screen_state_controller.title_cloud_button, screen_state_controller.title_settings_button]
	for button in buttons:
		if button == null or button.disabled or not button.visible: continue
		var label: Sprite2D = button.get_child(0) as Sprite2D if button.get_child_count() > 0 else null
		_spawn_title_pixel_breakup(label)
		screen_state_controller.spawn_button_frame_breakup(button, screen_state_controller.title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
	if screen_state_controller.title_cursor_text != null and screen_state_controller.title_cursor_text.visible:
		_spawn_title_pixel_breakup(screen_state_controller.title_cursor_text)
func _build_scene_transition() -> void:
	var view_size := Vector2(display_controller.view_size_value()) if display_controller != null else Vector2(DisplayLayout.NATIVE_SIZE)
	scene_transition_overlay = screen_state_controller.create_overlay(ui, "SceneTransitionOverlay", view_size, Color.BLACK, 200); scene_transition_overlay.set_meta("display_full_view", true); scene_transition_overlay.modulate.a = 0.0
func _begin_scene_transition() -> void:
	if scene_transition_active or scene_transition_overlay == null: return
	if input_device_tracker != null:
		input_device_tracker.call("persist_current_device")
	scene_transition_active = true; screen_state_controller.set_state(&"transition"); scene_transition_timer = 0.0; scene_transition_overlay.visible = true
func _start_roll_dust(direction: Vector2) -> void: effects_spawner.start_roll_dust(self, player, direction, roll_dust_frames, roll_dust_flipped_frames, Callable(self, "_actor_foot"), Callable(self, "_snap_half_pixel"))
func _update_roll_dust(delta: float) -> void: effects_spawner.update_roll_dust(delta, player.z_index, roll_dust_frames, roll_dust_flipped_frames, effects_tuning.roll_dust_frame_time, Callable(self, "_snap_half_pixel"))
func _clear_roll_dust() -> void: effects_spawner.clear_roll_dust()
func _damage_slime(slime: Sprite2D, amount: float, was_critical: bool = false, attack_element: int = 0, immune: bool = false) -> void: combat_runtime_controller.call("damage_slime", self, slime, amount, was_critical, attack_element, immune)
func _damage_slime_with_number(slime: Sprite2D, amount: float, was_critical: bool, show_damage_number: bool, attack_element: int = 0, immune: bool = false) -> void: combat_runtime_controller.call("damage_slime_with_number", self, slime, amount, was_critical, show_damage_number, attack_element, immune)
func _player_attack_damage_result_against(slime: Sprite2D, attack_element: int = 0) -> CombatCalculator.DamageResult: return combat_runtime_controller.call("player_attack_damage_result_against", self, slime, attack_element) as CombatCalculator.DamageResult
func _player_magic_damage_result_against(slime: Sprite2D, attack_element: int, magic_base_bonus: float = 0.0) -> CombatCalculator.DamageResult: return combat_runtime_controller.call("player_magic_damage_result_against", self, slime, attack_element, magic_base_bonus) as CombatCalculator.DamageResult
func _player_attack_damage_against(slime: Sprite2D) -> float: return float(combat_runtime_controller.call("player_attack_damage_against", self, slime))
func _combat_momentum() -> CombatMomentumComponent: return combat_runtime_controller.call("combat_momentum", self) as CombatMomentumComponent
func _register_combo_hit() -> void: combat_runtime_controller.call("register_combo_hit", self)
func _tick_focus_combo(delta: float) -> void: combat_runtime_controller.call("tick_focus_combo", self, delta)
func _reset_combo() -> void: combat_runtime_controller.call("reset_combo", self)
func _player_attack_damage_share_divisor(slime: Sprite2D, target_count: int) -> float: return float(combat_runtime_controller.call("player_attack_damage_share_divisor", self, slime, target_count))
func _combat_damage(attacker_stats: StatsComponent, defender_stats: StatsComponent, attack_element: int = 0, defense_element: int = 0) -> CombatCalculator.DamageResult: return combat_runtime_controller.call("combat_damage", self, attacker_stats, defender_stats, attack_element, defense_element) as CombatCalculator.DamageResult
func _max_health_for_stats(stats: StatsComponent) -> float: return float(combat_runtime_controller.call("max_health_for_stats", self, stats))
func _player_stat_snapshot() -> CombatStatSnapshot: return combat_runtime_controller.call("player_stat_snapshot", self) as CombatStatSnapshot
func _player_stat_debug_breakdown() -> Dictionary: return combat_runtime_controller.call("player_stat_debug_breakdown", self) as Dictionary
func _player_stat_debug_summary() -> String: return str(combat_runtime_controller.call("player_stat_debug_summary", self))
func _recompute_player_speed_multiplier() -> void: combat_runtime_controller.call("recompute_player_speed_multiplier", self)
func _player_max_health() -> float: return float(combat_runtime_controller.call("player_max_health", self))
func _enemy_max_health(slime: Sprite2D) -> float: return float(combat_runtime_controller.call("enemy_max_health", self, slime))
func _enemy_level_for_room() -> int: return int(combat_runtime_controller.call("enemy_level_for_room", self))
func _enemy_level_cap_for_run() -> int: return int(combat_runtime_controller.call("enemy_level_cap_for_run", self))
func _run_enemy_level_bonus() -> int: return int(combat_runtime_controller.call("run_enemy_level_bonus", self))
func _apply_enemy_room_level(slime: Sprite2D, level_override: int = 0) -> void: combat_runtime_controller.call("apply_enemy_room_level", self, slime, level_override)
func _configure_slime_variant(slime: Sprite2D, variant: String) -> void: combat_runtime_controller.call("configure_slime_variant", self, slime, variant)
func _knockback_slime(slime: Sprite2D, knockback_multiplier: float = 1.0, strength_scaled: bool = true) -> void: combat_runtime_controller.call("knockback_slime", self, slime, knockback_multiplier, strength_scaled)
func _slime_knockback_direction(slime: Sprite2D) -> Vector2: return combat_runtime_controller.call("slime_knockback_direction", self, slime) as Vector2
func _kill_slime(slime: Sprite2D) -> void: combat_runtime_controller.call("kill_slime", self, slime)
func _is_slime_dead(slime: Sprite2D) -> bool: return bool(combat_runtime_controller.call("is_slime_dead", self, slime))
func _are_all_slimes_dead() -> bool: return bool(combat_runtime_controller.call("are_all_slimes_dead", self))
func _unlock_chest() -> void:
	var room: DungeonGraph.RoomRecord = dungeon_graph.get_room(current_room_id) if dungeon_graph != null else null
	if room == null or room.room_type != DungeonGraph.ROOM_TREASURE:
		return
	if chest_unlocked: return
	chest_unlocked = true; if chest_normal_texture != null: chest_controller.start_unlock_fade(self)
	_play_sound("chest_unlock", -6.0, 1.0)
func _build_interact_prompt() -> void:
	var interaction_marker := _load_texture_or_null("res://assets/artwork/circle55.png")
	interact_prompt = interaction_component.build_prompt(self, interaction_marker, OVERWORLD_UI_Z + 1)
	interact_prompt_base_position = Vector2(6, -7)
	if interact_prompt != null:
		var fire_cost := Sprite2D.new()
		fire_cost.name = "FireCost"
		fire_cost.texture = _pixel_text_texture(str(FIRE_SOUL_COST), SOUL_HIGHLIGHT_COLOR)
		fire_cost.centered = true
		fire_cost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fire_cost.z_as_relative = false
		fire_cost.z_index = OVERWORLD_UI_Z + 2
		var marker_height: float = float(interaction_marker.get_height()) if interaction_marker != null else 5.0
		var cost_height: float = float(fire_cost.texture.get_height()) if fire_cost.texture != null else 5.0
		fire_cost.position = Vector2(0, -marker_height * 0.5 - cost_height * 0.5 - 1.0)
		fire_cost.visible = false
		interact_prompt.add_child(fire_cost)
func _build_npc_dialogue() -> void:
	var dialogue := npc_controller.build_dialogue(self, _load_texture_or_null("res://assets/artwork/circle55.png"))
	npc_controller.dialogue_layer = dialogue["layer"] as CanvasLayer
	npc_controller.dialogue_box = dialogue["box"] as ColorRect
	npc_controller.dialogue_text = dialogue["text"] as Sprite2D
	npc_controller.dialogue_button = dialogue["button"] as Sprite2D
	npc_controller.dialogue_button_shadow = dialogue["shadow"] as Sprite2D
	npc_controller.dialogue_yes_text = dialogue["yes"] as Sprite2D
	npc_controller.dialogue_no_text = dialogue["no"] as Sprite2D
	npc_controller.dialogue_yes_button = dialogue["yes_button"] as Button
	npc_controller.dialogue_no_button = dialogue["no_button"] as Button
func _build_room_number_indicator() -> void:
	var hud: Dictionary = hud_controller.build_world_hud(ui, sprite_frame_library, Callable(self, "_load_texture_or_null"), target_health_bar, target_health_fill, player_health_fill)
	hud_controller.room_number_indicator = hud["room"] as Sprite2D; hud_controller.dungeon_run_indicator = hud["dungeon_run"] as Sprite2D; hud_controller.gold_indicator = hud["gold"] as Sprite2D; hud_controller.gold_amount_indicator = hud["gold_amount"] as Sprite2D; hud_controller.soul_icon_indicator = hud["soul"] as Sprite2D; hud_controller.soul_amount_indicator = hud["soul_amount"] as Sprite2D; hud_controller.run_timer_indicator = hud["timer"] as Sprite2D; hud_controller.combo_label = hud["combo_label"] as Sprite2D; hud_controller.combo_base = hud["combo_base"] as Sprite2D; hud_controller.combo_fill = hud["combo_fill"] as Sprite2D; hud_controller.gold_animation_frames = hud["gold_frames"] as Array[Texture2D]; hud_controller.button_hud_sprites = hud["buttons"] as Array[Sprite2D]; hud_controller.ability_prompt_hud = hud["ability_prompts"] as Array[Sprite2D]; hud_controller.cooldown_hud = hud["cooldowns"] as Dictionary; target_health_text = hud["target_text"] as Sprite2D; focus_label = hud["focus_label"] as Sprite2D; focus_label_base = hud["focus_label_base"] as Sprite2D; player_health_text = hud["player_text"] as Sprite2D; _update_room_number_indicator(); _update_gold_indicator(); _update_soul_indicator()
	var hud_root := ui.get_node("PlayerHud") as Node2D
	var player_hud_color := _health_feedback_color(screen_state_controller.player_palette_name)
	hud_root.call("set_static_text", "lv. 1", player_hud_color)
	hud_root.call("apply_bar_colors", player_hud_color, PaletteLibrary.accent(screen_state_controller.player_palette_name))
	_update_player_progression_ui()
func _update_gold_indicator() -> void: if hud_controller.gold_indicator != null: hud_controller.gold_amount_indicator.texture = _pixel_text_texture(str(player_profile.gold if player_profile != null else 0), Color8(255, 205, 117))
func _update_soul_indicator() -> void: if hud_controller.soul_amount_indicator != null: hud_controller.soul_amount_indicator.texture = _pixel_text_texture(str(player_profile.souls if player_profile != null else 0), SOUL_HIGHLIGHT_COLOR)
func _update_room_number_indicator() -> void: hud_controller.update_room_number(self)
func _update_cloaked_demon_animation(delta: float) -> void:
	var near_player := _can_interact_with_npc(); var patrolling := (current_room_type == DungeonGraph.ROOM_START or current_room_type == DungeonGraph.ROOM_NPC) and not near_player and (npc_controller.dialogue_box == null or not npc_controller.dialogue_box.visible)
	var result := npc_controller.update_patrol_animation(cloaked_demon, npc_controller.demon_idle_frames, npc_controller.demon_walk_frames, delta, near_player, patrolling, npc_controller.demon_patrol_paused, npc_controller.demon_wander_target, npc_controller.demon_wander_has_target, npc_controller.demon_patrol_pause_timer, npc_controller.demon_patrol_direction, player.global_position.x, rng, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_random_npc_walkable_point_near"), Callable(self, "_move_cloaked_demon"), Callable(self, "_perspective_movement"), Callable(self, "_cache_npc_texture"), npc_controller.demon_animation_timer, npc_controller.demon_animation_frame)
	npc_controller.demon_wander_target = result["wander_target"]; npc_controller.demon_wander_has_target = result["has_target"]; npc_controller.demon_patrol_paused = result["paused"]; npc_controller.demon_patrol_pause_timer = result["pause_timer"]; npc_controller.demon_patrol_direction = result["direction"]; npc_controller.demon_animation_timer = result["timer"]; npc_controller.demon_animation_frame = result["frame"]
func _move_cloaked_demon(movement: Vector2, max_step: float) -> bool: return actor_collision_system.try_move_swept(cloaked_demon, movement, max_step, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _open_final_exit() -> void:
	if settlement_room_active:
		return
	final_exit_open = true
	var exit_socket := room_controller.dungeon_sockets.get(DungeonGraph.WALL_RIGHT) as DungeonSocket
	if exit_socket != null:
		room_controller.active_door_sockets[DungeonGraph.WALL_RIGHT] = exit_socket
		door_active = true
	# Victory opens both choices: the right-side stairs complete the run, while
	# the arrival entrance becomes a real reverse route back into the dungeon.
	entrance_open = true
	_refresh_room_socket_visuals(true)
	_build_entrance_block_polygons()
func _fire_target_palette() -> String:
	if current_fire_palette_name.is_empty():
		return ""
	# Generated Fire Rooms declare their flame in the layout. The map controller
	# decides which primary flames this run has earned; this keeps non-starter
	# fires inert until their run progression makes them legitimate sources.
	if dungeon_map_controller != null and dungeon_map_controller.has_method("fire_palette_available"):
		return current_fire_palette_name if bool(dungeon_map_controller.call("fire_palette_available", current_fire_palette_name)) else ""
	var starter_palette := run_start_palette_name
	if starter_palette.is_empty() and screen_state_controller != null:
		starter_palette = screen_state_controller.player_palette_name
	return current_fire_palette_name if current_fire_palette_name == starter_palette else ""


func _fire_target_flame() -> StringName:
	return AspectCatalogScript.flame_for_palette(_fire_target_palette())


func _current_player_flame() -> StringName:
	return StringName(player_chroma_component.call("aspect_name")) if player_chroma_component != null else &"gray"


func _show_fire_exchange_text(text: String, color: Color) -> void:
	var origin: Vector2 = _player_floating_number_origin(text, color)
	_spawn_floating_number(origin + Vector2(0, -18), 0, Vector2(0, -12), false, false, color, text)


func _can_interact_with_fire() -> bool:
	var target_palette := _fire_target_palette()
	if rest_fire == null or not rest_fire.visible or target_palette.is_empty() or AspectCatalogScript.flame_for_palette(target_palette).is_empty():
		return false
	var target_flame := AspectCatalogScript.flame_for_palette(target_palette)
	var current_flame := _current_player_flame()
	if current_flame == target_flame:
		var health_full := player_health_component == null or player_health_component.current_health >= player_health_component.maximum_health
		var chroma_full := player_chroma_component == null or int(player_chroma_component.get("current_chroma")) >= PlayerChromaComponent.MAX_CHROMA
		if health_full and chroma_full:
			# Do not expose a paid interaction when the flame would have no effect.
			return false
	var fire_position := _fire_anchor()
	return _actor_foot(player).distance_to(fire_position) <= FIRE_INTERACT_DISTANCE and _is_interaction_target_in_front(fire_position)


func _fire_fusion_result() -> StringName:
	var target_palette := _fire_target_palette()
	var target_flame := AspectCatalogScript.flame_for_palette(target_palette)
	if target_flame.is_empty() or player_chroma_component == null:
		return &""
	var current_flame := StringName(player_chroma_component.call("aspect_name"))
	return AspectCatalogScript.fusion_result(current_flame, target_flame)


func _can_fuse_with_fire() -> bool:
	return _can_interact_with_fire() and not _fire_fusion_result().is_empty()


func _complete_flame_service(flame: StringName, is_fusion: bool) -> bool:
	var cost := FLAME_FUSION_SOUL_COST if is_fusion else FLAME_SWAP_SOUL_COST
	if player_chroma_component == null or not is_instance_valid(player_chroma_component):
		return false
	if player_profile == null or not player_profile.spend_souls(cost):
		_show_fire_exchange_text("NEED %d SOULS" % cost, Color8(255, 105, 105))
		_play_sound("ui_no_input", 0.0, 1.0)
		return false
	var applied := false
	if is_fusion:
		var result := _fire_fusion_result()
		if not result.is_empty():
			applied = bool(player_chroma_component.call("attune_flame", result))
	else:
		applied = bool(player_chroma_component.call("attune_flame", flame))
	if not applied:
		player_profile.add_souls(cost)
		call("_save_player_profile")
		_update_soul_indicator()
		_play_sound("ui_no_input", 0.0, 1.0)
		return false
	var target_palette := AspectCatalogScript.palette_for_flame(flame)
	var result_flame := StringName(player_chroma_component.call("aspect_name"))
	var result_palette := AspectCatalogScript.palette_for_flame(result_flame)
	var healed := 0.0
	if player_health_component != null:
		healed = player_health_component.apply_healing(player_health_component.maximum_health)
		_update_player_health_ui()
		if healed > 0.0:
			combat_runtime_controller.call("spawn_player_healing_number", self, healed, _health_feedback_color(result_palette if not result_palette.is_empty() else target_palette))
	if screen_state_controller != null and result_palette != screen_state_controller.player_palette_name:
		_start_player_palette_flash(result_palette)
	_update_player_mp_ui()
	_sync_current_element_state()
	var is_starter_attunement := current_room_type == DungeonGraph.ROOM_START and not starter_flame_attuned_this_run
	if is_starter_attunement:
		starter_flame_attuned_this_run = true
		if dungeon_map_controller != null and dungeon_map_controller.has_method("set_starter_flame_attuned"):
			dungeon_map_controller.call("set_starter_flame_attuned", true)
		_set_door_active(true)
		_set_entrance_open(true)
	call("_save_player_profile")
	_update_soul_indicator()
	var action_name := "FUSED %s" % String(result_flame).to_upper() if is_fusion else "%s USED" % String(flame).to_upper()
	_show_fire_exchange_text(action_name, _health_feedback_color(result_palette if not result_palette.is_empty() else target_palette))
	_play_sound("use_flame", 0.0, 1.0)
	return true


func _interact_with_fire() -> bool:
	if not _can_interact_with_fire():
		return false
	var target_palette := _fire_target_palette()
	var flame := AspectCatalogScript.flame_for_palette(target_palette)
	if target_palette.is_empty() or flame.is_empty():
		return false
	return _complete_flame_service(flame, false)


func _fuse_with_fire() -> bool:
	if not _can_interact_with_fire():
		return false
	var target_palette := _fire_target_palette()
	var flame := AspectCatalogScript.flame_for_palette(target_palette)
	var result := _fire_fusion_result()
	if target_palette.is_empty() or flame.is_empty() or result.is_empty():
		return false
	return _complete_flame_service(flame, true)
func _start_player_palette_flash(new_palette: String) -> void:
	screen_state_controller.player_palette_name = new_palette
	current_player_palette_name = new_palette
	_apply_player_palette_async(new_palette)
	_update_player_aggro_marker_colors()
	var old_overlay := player_palette_flash_overlay
	if old_overlay != null: old_overlay.queue_free()
	var overlay := Sprite2D.new()
	overlay.name = "PlayerPaletteFlash"
	var source := occlusion_renderer.original_actor_textures.get(player, player.texture) as Texture2D
	overlay.texture = _white_texture(source)
	overlay.centered = player.centered
	overlay.texture_filter = player.texture_filter
	overlay.z_as_relative = true
	overlay.z_index = 2
	ActorGeometry.sync_overlay(overlay, player)
	overlay.modulate = Color(1, 1, 1, 0.0)
	player.add_child(overlay)
	player_palette_flash_overlay = overlay
	player_palette_flash_phase = 0
	player_palette_flash_timer = 0.0
func _input_prompt_texture(action: StringName) -> Texture2D:
	if input_device_tracker == null:
		return _load_texture_or_null("res://assets/artwork/circle55.png")
	var device := int(input_device_tracker.get("current_device"))
	if device == InputDeviceTracker.Device.GAMEPAD and action == &"interact":
		return _load_texture_or_null("res://assets/artwork/circle55.png")
	var label := String(input_device_tracker.call("prompt_label", action))
	if device == InputDeviceTracker.Device.TOUCH and effects_spawner != null:
		return effects_spawner.prompt_texture(label, Color.BLACK)
	if effects_spawner != null:
		return effects_spawner.keyboard_prompt_texture(label)
	return _pixel_text_texture(label, Color.WHITE)


func _update_interact_prompt(delta: float) -> void:
	if interaction_component != null and interact_prompt != null:
		interaction_component.set_prompt_texture(interact_prompt, _input_prompt_texture(&"interact"))
	if npc_controller != null:
		npc_controller.set_continue_prompt_texture(_input_prompt_texture(&"interact"))
	interaction_component.update_world_prompt(self, delta, NPC_DIALOGUE_BUTTON_BOB_TIME, OVERWORLD_UI_Z + 1)
func _set_door_active(is_active: bool) -> void:
	room_puzzle_controller.call("set_door_active", self, is_active)
func _collect_dungeon_sockets() -> void:
	room_controller.dungeon_sockets.clear()
	if sockets_root == null: return
	for child in sockets_root.get_children(): var socket := child as DungeonSocket; if socket != null: room_controller.dungeon_sockets[socket.socket_id()] = socket
func _sync_current_room_metadata() -> void:
	run_flow_controller.call("sync_current_room_metadata", self)
	if dungeon_map_controller != null:
		dungeon_map_controller.on_room_entered(current_room_id)
func _finalize_run_metrics() -> void:
	run_flow_controller.call("finalize_run_metrics", self)
func _finalize_run_exploration() -> void:
	# Compatibility entry point for older probes; settlement now finalizes both
	# physical map discovery and local room completion.
	_finalize_run_metrics()
func _finalize_run_enemy_total() -> void:
	run_flow_controller.call("finalize_run_enemy_total", self)
func _ensure_current_room_layout() -> void:
	var room := dungeon_graph.get_room(current_room_id)
	if room == null: return
	# Encounter composition follows completed dungeon runs, not the separate
	# grade/loot rank. A strong Run 1 grade should not turn the first rooms of
	# Run 2 into an immediate difficulty spike.
	room_controller.progression_run_rank = maxi(1, dungeon_graph.completed_run_count + 1)
	room_controller.player_level = maxi(1, player_profile.level if player_profile != null else player_stats.level)
	_apply_room_geometry()
	_collect_walkable_tiles(floor_tiles)
	_build_entrance_block_polygons()
	_build_walkable_outline()
	var state := room_controller.ensure_layout(dungeon_graph, current_room_id, room, current_room_type, current_room_depth)
	var required_aspect: StringName = &""
	if current_room_type == DungeonGraph.ROOM_PUZZLE:
		required_aspect = _puzzle_required_aspect(room)
		state["puzzle_required_flame"] = String(required_aspect)
		if not state.has("puzzle_torch_colors"):
			var initial_palette := AspectCatalogScript.palette_for_flame(_current_run_puzzle_flame()) if required_aspect == &"gray" else "grey"
			state["puzzle_torch_colors"] = [initial_palette, initial_palette]
		_build_puzzle_torches(state)
		state["finished"] = _puzzle_torches_solved(_puzzle_palette_for_aspect(required_aspect))
		room_controller.room_states[current_room_id] = state
	elif current_room_type == DungeonGraph.ROOM_ORB:
		_build_orb_room_orb(state)
	else:
		_clear_puzzle_torches()
	_configure_room_sockets(bool(state.get("finished", false)))
	_update_puzzle_room_tint(room if current_room_type == DungeonGraph.ROOM_PUZZLE else null, required_aspect)
func _configure_room_sockets(is_unlocked: bool) -> void:
	room_puzzle_controller.call("configure_room_sockets", self, is_unlocked)
func _current_run_puzzle_flame() -> StringName:
	return room_puzzle_controller.call("current_run_puzzle_flame", self) as StringName
func _puzzle_required_aspect(room: DungeonGraph.RoomRecord) -> StringName:
	return room_puzzle_controller.call("puzzle_required_aspect", self, room) as StringName
func _puzzle_palette_for_aspect(aspect: StringName) -> String:
	return str(room_puzzle_controller.call("puzzle_palette_for_aspect", aspect))
func _update_puzzle_room_tint(room: DungeonGraph.RoomRecord, required_flame: StringName) -> void:
	if dungeon_map_controller != null and bool(dungeon_map_controller.call("uses_global_orb_state")):
		room_puzzle_controller.call("update_map_environment_tint", self)
		return
	room_puzzle_controller.call("update_puzzle_room_tint", self, room, required_flame)
func _apply_puzzle_environment_tint(tint: Color) -> void:
	room_puzzle_controller.call("apply_puzzle_environment_tint", self, tint)
func _apply_chest_map_tint() -> void:
	room_puzzle_controller.call("apply_chest_map_tint", self)
func _set_puzzle_surface_tint(node: Node, tint: Color) -> void:
	room_puzzle_controller.call("set_puzzle_surface_tint", node, tint)
func _build_puzzle_torches(state: Dictionary) -> void:
	room_puzzle_controller.call("build_puzzle_torches", self, state)
func _build_orb_room_orb(state: Dictionary) -> void:
	room_puzzle_controller.call("build_orb_room_orb", self, state)
func _clear_puzzle_torches() -> void:
	room_puzzle_controller.call("clear_puzzle_torches", self)
func _puzzle_torches_solved(required_palette: String) -> bool:
	return bool(room_puzzle_controller.call("puzzle_torches_solved", self, required_palette))
func _refresh_puzzle_torch_puzzle_state() -> void:
	room_puzzle_controller.call("refresh_puzzle_torch_puzzle_state", self)
func _activate_puzzle_torch(torch: Sprite2D, world_position: Vector2, palette: String, apply_player_reaction: bool = true) -> void:
	room_puzzle_controller.call("activate_puzzle_torch", self, torch, world_position, palette, apply_player_reaction)
func _update_entry_orb_animation(delta: float) -> void:
	room_puzzle_controller.call("update_entry_orb_animation", self, delta)
func _update_entry_orb_player_reaction() -> void:
	room_puzzle_controller.call("update_entry_orb_player_reaction", self)
func _map_orb_display_palette() -> String:
	if dungeon_map_controller == null:
		return "grey"
	return str(dungeon_map_controller.call("orb_display_palette"))
func _orb_puzzle_color_for_palette(palette: String) -> StringName:
	if dungeon_map_controller == null:
		return &""
	return dungeon_map_controller.call("puzzle_color_for_palette", palette) as StringName
func _change_orb_color_from_room(next_puzzle_color: StringName = &"") -> bool:
	return dungeon_map_controller != null and bool(dungeon_map_controller.call("change_orb_from_room", current_room_id, next_puzzle_color))
func _change_orb_palette_from_room(palette: String) -> bool:
	return dungeon_map_controller != null and bool(dungeon_map_controller.call("change_orb_from_palette", current_room_id, palette))
func _on_room_enemies_cleared() -> void:
	if current_room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		room_controller.mark_cleared(current_room_id)
		_open_final_exit()
		return
	if current_room_type != DungeonGraph.ROOM_COMBAT and current_room_type != DungeonGraph.ROOM_SPECIAL_ENEMY and current_room_type != DungeonGraph.ROOM_TREASURE:
		return
	room_controller.mark_cleared(current_room_id)
	_set_door_active(room_controller.is_cleared(current_room_id))
	_set_entrance_open(true)
func _map_connection_available(connection: DungeonGraph.ConnectionRecord, is_entrance: bool = false) -> bool:
	if current_room_type == DungeonGraph.ROOM_START and not starter_flame_attuned_this_run:
		return false
	_sync_current_element_state()
	return dungeon_map_controller == null or dungeon_map_controller.is_connection_available(connection, is_entrance)
func _mark_current_room_engaged() -> void:
	if dungeon_map_controller != null:
		dungeon_map_controller.call("mark_room_engaged", current_room_id)
func _map_connection_visual_state(connection: DungeonGraph.ConnectionRecord, is_entrance: bool = false) -> StringName:
	if current_room_type == DungeonGraph.ROOM_START and not starter_flame_attuned_this_run:
		return &"room_locked"
	_sync_current_element_state()
	return dungeon_map_controller.connection_visual_state(connection, is_entrance) if dungeon_map_controller != null else &"open"
func _on_dungeon_map_state_changed() -> void:
	if dungeon_map_controller == null:
		return
	if current_room_type == DungeonGraph.ROOM_SPECIAL_ENEMY:
		room_controller.call("refresh_special_enemy_color_policy", self)
	if current_room_type == DungeonGraph.ROOM_ORB:
		var state: Dictionary = room_controller.room_states.get(current_room_id, {}) as Dictionary
		state["orb_display_palette"] = _map_orb_display_palette()
		room_controller.room_states[current_room_id] = state
		_build_orb_room_orb(state)
	_refresh_room_socket_visuals(door_active)
	_update_puzzle_room_tint(dungeon_graph.get_room(current_room_id) if dungeon_graph != null else null, &"")
	_build_entrance_block_polygons()
func _refresh_room_socket_visuals(is_unlocked: bool) -> void:
	room_puzzle_controller.call("refresh_room_socket_visuals", self, is_unlocked)
func _apply_room_geometry() -> void: room_controller.call("apply_room_geometry", self)
func _apply_authored_boss_room_geometry() -> void: room_controller.call("apply_authored_boss_room_geometry", self)
func _copy_authored_room_sprite(template: Node, path: NodePath) -> void: room_controller.call("copy_authored_room_sprite", self, template, path)
func _copy_boss_floor_underlay(template: Node) -> void: room_controller.call("copy_boss_floor_underlay", self, template)
func _copy_authored_tile_layer(source: TileMapLayer, destination: TileMapLayer) -> void: room_controller.call("copy_authored_tile_layer", source, destination)
func _copy_authored_polygon(template: Node, path: NodePath) -> void: room_controller.call("copy_authored_polygon", self, template, path)
func _capture_normal_room_geometry() -> void: room_controller.call("capture_normal_room_geometry", self)
func _restore_normal_room_geometry() -> void: room_controller.call("restore_normal_room_geometry", self)
func _configure_large_room_camera(enabled: bool) -> void: room_controller.call("configure_large_room_camera", self, enabled)
func _update_large_room_camera() -> void: room_controller.call("update_large_room_camera", self)
func _update_door_transition() -> void: if not room_transition_locked: room_controller.try_enter_active_socket(self, door_active, entrance_open, room_transition_locked)
func _try_enter_any_active_socket() -> bool: return room_controller.try_enter_active_socket(self, door_active, entrance_open, room_transition_locked)
func _enter_connected_room(destination_room_id: StringName, arrival_socket_id: StringName) -> void: room_controller.enter_connected_room(self, destination_room_id, arrival_socket_id)
func _release_room_transition_lock() -> void: room_transition_locked = false; if room_controller != null: room_controller.end_transition()
func _save_current_room_state() -> void:
	var state := room_controller.room_states.get(current_room_id, {}) as Dictionary
	room_controller.save_enemy_runtime_state(self)
	state = room_controller.room_states.get(current_room_id, state) as Dictionary
	var room: DungeonGraph.RoomRecord = dungeon_graph.get_room(current_room_id) if dungeon_graph != null else null
	if current_room_type == DungeonGraph.ROOM_PUZZLE:
		var required_aspect := StringName(state.get("puzzle_required_flame", _puzzle_required_aspect(room)))
		state["finished"] = _puzzle_torches_solved(_puzzle_palette_for_aspect(required_aspect))
	elif room != null and room.room_type == DungeonGraph.ROOM_TREASURE:
		# Treasure completion belongs to the enemy encounter. The chest is an
		# optional reward and must not reopen or clear the room on a revisit.
		state["chest_claimed"] = chest_claimed
		state["chest_evaporated"] = chest_evaporated
		state["finished"] = bool(state.get("finished", false)) or room_controller.is_cleared(current_room_id)
	else:
		# Combat and boss rooms are completed by enemy defeat, not by opening a
		# chest. Preserve the clear state when the player leaves before re-entry.
		state["finished"] = bool(state.get("finished", false)) or room_controller.is_cleared(current_room_id)
	var saved_drops: Array = []
	for drop in world_item_drops:
		var sprite := drop.get("sprite") as Sprite2D
		var item := drop.get("item") as ItemInstance
		if sprite != null and is_instance_valid(sprite) and item != null:
			var saved_position := sprite.global_position
			if float(drop.get("air_time", 0.0)) > 0.0 and drop.has("landing_position"):
				saved_position = drop.get("landing_position") as Vector2
			saved_drops.append({"item": item.to_dictionary(), "position": saved_position})
	if saved_drops.is_empty():
		state.erase("world_item_drops")
	else:
		state["world_item_drops"] = saved_drops
	state.erase("world_item_drop")
	var saved_pickups: Array = []
	for index in chroma_pickup_controller.sprites.size():
		var pickup := chroma_pickup_controller.sprites[index]
		if pickup != null and is_instance_valid(pickup):
			saved_pickups.append({"position": pickup.global_position, "value": chroma_pickup_controller.values[index]})
	if saved_pickups.is_empty(): state.erase("chroma_pickups")
	else: state["chroma_pickups"] = saved_pickups
	room_controller.room_states[current_room_id] = state
	if room_controller != null and bool(state.get("finished", false)): room_controller.mark_cleared(current_room_id)
func _apply_room_state() -> void: room_controller.apply_state(self)
func _apply_rest_room_state() -> void: room_controller.apply_rest_state(self)
func _apply_npc_room_state() -> void: room_controller.apply_npc_state(self)
func _apply_finished_room_state() -> void: room_controller.apply_finished_state(self)
func _pixel_particle_texture(color: Color, size: int = 1) -> Texture2D:
	var key := "%02X%02X%02X:%d" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0)), size]
	if effects_spawner.pixel_particle_texture_cache.has(key):
		return effects_spawner.pixel_particle_texture_cache[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8); image.fill(color); var texture := ImageTexture.create_from_image(image)
	effects_spawner.pixel_particle_texture_cache[key] = texture
	return texture
func _try_knockback_slime(slime: Sprite2D, movement: Vector2) -> bool: return bool(slime_runtime_controller.call("try_knockback_slime", self, slime, movement))
func _separate_slime_from_player(slime: Sprite2D) -> void: slime_runtime_controller.call("separate_slime_from_player", self, slime)
func _configure_slime_ambush(slime: Sprite2D, palette: String) -> void: slime_runtime_controller.call("configure_slime_ambush", self, slime, palette)
func _slime_ambush(slime: Sprite2D) -> SlimeAmbushComponent: return slime_runtime_controller.call("slime_ambush", self, slime) as SlimeAmbushComponent
func _slime_spawn(slime: Sprite2D) -> Node: return slime_runtime_controller.call("slime_spawn", self, slime) as Node
func _is_slime_spawn_locked(slime: Sprite2D) -> bool: return bool(slime_runtime_controller.call("is_slime_spawn_locked", self, slime))
func _begin_slime_spawn(slime: Sprite2D) -> bool: return bool(slime_runtime_controller.call("begin_slime_spawn", self, slime))
func _set_slime_spawn_frame(slime: Sprite2D, frame_index: int) -> void: slime_runtime_controller.call("set_slime_spawn_frame", self, slime, frame_index)
func _finish_slime_spawn(slime: Sprite2D) -> void: slime_runtime_controller.call("finish_slime_spawn", self, slime)
func _is_slime_hidden(slime: Sprite2D) -> bool: return bool(slime_runtime_controller.call("is_slime_hidden", self, slime))
func _is_slime_targetable(slime: Sprite2D) -> bool: return bool(slime_runtime_controller.call("is_slime_targetable", self, slime))
func _is_target_actor_dead(target: Sprite2D) -> bool: return bool(slime_runtime_controller.call("is_target_actor_dead", self, target))
func _move_slimes(delta: float) -> void: slime_runtime_controller.call("move_slimes", self, delta)
func _prepare_slime_frame_cache() -> void: slime_runtime_controller.call("prepare_slime_frame_cache", self)
func _trigger_slime_notice(slime: Sprite2D) -> void: slime_runtime_controller.call("trigger_slime_notice", self, slime)
func _slime_position_is_valid(slime: Sprite2D) -> bool: return bool(slime_runtime_controller.call("slime_position_is_valid", self, slime))
func _recover_slime_position(slime: Sprite2D) -> void: slime_runtime_controller.call("recover_slime_position", self, slime)
func _update_slime_attack(slime: Sprite2D, delta: float) -> bool: return bool(slime_runtime_controller.call("update_slime_attack", self, slime, delta))
func _set_slime_attack_frame(slime: Sprite2D, frame_index: int) -> void: slime_runtime_controller.call("set_slime_attack_frame", self, slime, frame_index)
func _start_slime_attack(slime: Sprite2D) -> void: slime_runtime_controller.call("start_slime_attack", self, slime)
func _slime_attack_frames(slime: Sprite2D) -> Array[Texture2D]: return slime_runtime_controller.call("attack_frames_for", self, slime) as Array[Texture2D]
func _slime_shocked_frames(slime: Sprite2D) -> Array[Texture2D]: return slime_runtime_controller.call("shocked_frames_for", self, slime) as Array[Texture2D]
func _set_slime_notice_frame(slime: Sprite2D, frame_index: int) -> void: slime_runtime_controller.call("set_slime_notice_frame", self, slime, frame_index)
func _restore_slime_idle_texture(slime: Sprite2D) -> void: slime_runtime_controller.call("restore_slime_idle_texture", self, slime)
func _can_slime_attack_player(slime: Sprite2D) -> bool: return bool(slime_runtime_controller.call("can_slime_attack_player", self, slime))
func _is_slime_aggroed(slime: Sprite2D) -> bool: return bool(slime_runtime_controller.call("is_slime_aggroed", self, slime))
func _is_any_slime_aggroed() -> bool: return bool(slime_runtime_controller.call("is_any_slime_aggroed", self))
func _update_special_enemy_respawns(delta: float) -> void: room_controller.call("update_special_enemy_respawns", self, delta); room_controller.call("update_popcorn_respawns", self, delta)
func _slime_attack_reach(slime: Sprite2D) -> float: return float(slime_runtime_controller.call("slime_attack_reach", self, slime))
func _slime_attack_contact_gap(slime: Sprite2D, direction: Vector2) -> float: return float(slime_runtime_controller.call("slime_attack_contact_gap", self, slime, direction))
func _slime_attack_offset(slime: Sprite2D) -> Vector2: return slime_runtime_controller.call("slime_attack_offset", self, slime) as Vector2
func _aggro_slime_target(slime: Sprite2D) -> Vector2: return slime_runtime_controller.call("aggro_slime_target", self, slime) as Vector2
func _apply_slime_attack_hit(slime: Sprite2D) -> void: slime_runtime_controller.call("apply_slime_attack_hit", self, slime)
func _slime_attack_damage_result(slime: Sprite2D) -> CombatCalculator.DamageResult: return combat_runtime_controller.call("slime_attack_damage_result", self, slime) as CombatCalculator.DamageResult
func _slime_attack_damage(slime: Sprite2D) -> float: return float(combat_runtime_controller.call("slime_attack_damage", self, slime))
func _mark_player_in_combat() -> void: combat_runtime_controller.call("mark_player_in_combat", self)
func _on_player_health_damaged(amount: float) -> void: combat_runtime_controller.call("on_player_health_damaged", self, amount)
func _on_player_health_changed(_current: float, _maximum: float) -> void: combat_runtime_controller.call("on_player_health_changed", self)
func _on_player_health_healed(amount: float) -> void: combat_runtime_controller.call("on_player_health_healed", self, amount)
func _on_slime_health_damaged(_amount: float, slime: Sprite2D) -> void: combat_runtime_controller.call("on_slime_health_damaged", self, slime)
func _on_slime_health_changed(_current: float, _maximum: float, slime: Sprite2D) -> void: combat_runtime_controller.call("on_slime_health_changed", self, slime)
func _on_slime_health_healed(amount: float, slime: Sprite2D) -> void: combat_runtime_controller.call("on_slime_health_healed", self, slime, amount)
func _update_player_health_regen(delta: float) -> void: combat_runtime_controller.call("update_player_health_regen", self, delta)
func _apply_slime_attack_lunge(slime: Sprite2D) -> void: combat_runtime_controller.call("apply_slime_attack_lunge", self, slime)
func _slime_attack_lunge_vector(slime: Sprite2D) -> Vector2: return combat_runtime_controller.call("slime_attack_lunge_vector", self, slime) as Vector2
func _apply_player_hit_knockback(slime: Sprite2D) -> void: combat_runtime_controller.call("apply_player_hit_knockback", self, slime)
func _update_slime_knockback(slime: Sprite2D, delta: float) -> bool: return bool(combat_runtime_controller.call("update_slime_knockback", self, slime, delta))
func _reset_slime_scoot(slime: Sprite2D) -> void: combat_runtime_controller.call("reset_slime_scoot", self, slime)
func _show_slime_hit_flash(slime: Sprite2D) -> void: combat_runtime_controller.call("show_slime_hit_flash", self, slime)
func _update_enemy_hit_flashes(delta: float) -> void: combat_runtime_controller.call("update_enemy_hit_flashes", self, delta)
func _update_enemy_health(delta: float) -> void: combat_runtime_controller.call("update_enemy_health", self, delta)
func _spawn_damage_number(slime: Sprite2D, amount: float, was_critical: bool = false, attack_element: int = 0, immune: bool = false) -> void: combat_runtime_controller.call("spawn_damage_number", self, slime, amount, was_critical, attack_element, immune)
func _spawn_player_number(text: String, value: int, color: Color, is_healing: bool, display_text: String) -> void: combat_runtime_controller.call("spawn_player_number", self, text, value, color, is_healing, display_text)
func _spawn_player_damage_number(amount: float, attack_element: int = 0, immune: bool = false) -> void: combat_runtime_controller.call("spawn_player_damage_number", self, amount, attack_element, immune)
func _spawn_player_shield_damage_number(amount: float) -> void: combat_runtime_controller.call("spawn_player_shield_damage_number", self, amount)
func _spawn_player_healing_number(amount: float, color: Color) -> void: combat_runtime_controller.call("spawn_player_healing_number", self, amount, color)
func _apply_player_lifesteal(damage: float) -> void: combat_runtime_controller.call("apply_player_lifesteal", self, damage)
func _player_floating_number_origin(text: String, color: Color) -> Vector2: return combat_runtime_controller.call("player_floating_number_origin", self, text, color) as Vector2
func _spawn_slime_healing_number(slime: Sprite2D, amount: float, color: Color) -> void: combat_runtime_controller.call("spawn_slime_healing_number", self, slime, amount, color)
func _spawn_floating_number(world_position: Vector2, value: int, velocity: Vector2, was_critical: bool = false, is_healing: bool = false, healing_color: Color = Color.WHITE, display_text := "") -> void: combat_runtime_controller.call("spawn_floating_number", self, world_position, value, velocity, was_critical, is_healing, healing_color, display_text)
func _health_feedback_color(palette_name: String) -> Color: return combat_runtime_controller.call("health_feedback_color", self, palette_name) as Color
func _configure_equipment_transmutations() -> void: combat_runtime_controller.call("configure_equipment_transmutations", self)
func _on_transmutation_effect_triggered(effect_id: StringName, message: String) -> void: combat_runtime_controller.call("on_transmutation_effect_triggered", self, effect_id, message)
func _xp_required_for_level(level: int) -> int: return int(combat_runtime_controller.call("xp_required_for_level", self, level))
func _xp_reward_for_slime(slime: Sprite2D) -> int: return int(combat_runtime_controller.call("xp_reward_for_slime", self, slime))
func _award_slime_xp(slime: Sprite2D) -> void: combat_runtime_controller.call("award_slime_xp", self, slime)
func _apply_player_level() -> void: combat_runtime_controller.call("apply_player_level", self)
func _update_player_progression_ui() -> void: combat_runtime_controller.call("update_player_progression_ui", self)
func _spawn_player_xp_number(amount: int) -> void: combat_runtime_controller.call("spawn_player_xp_number", self, amount)
func _spawn_player_level_number(level: int) -> void: combat_runtime_controller.call("spawn_player_level_number", self, level)
func _update_damage_numbers(delta: float) -> void: combat_runtime_controller.call("update_damage_numbers", self, delta)
func _pixel_text_texture(text: String, color: Color) -> Texture2D: return combat_runtime_controller.call("pixel_text_texture", self, text, color) as Texture2D
func _pixel_name_texture(text: String, color: Color) -> Texture2D: return combat_runtime_controller.call("pixel_name_texture", self, text, color) as Texture2D
func _update_slime_scoot(slime: Sprite2D, delta: float) -> void: slime_runtime_controller.call("update_slime_scoot", self, slime, delta)
func _start_slime_scoot(slime: Sprite2D) -> void: slime_runtime_controller.call("start_slime_scoot", self, slime)
func _repath_slime_after_block(slime: Sprite2D) -> void: slime_runtime_controller.call("repath_slime_after_block", self, slime)
func _slime_wall_detour_target(slime: Sprite2D) -> Vector2: return slime_runtime_controller.call("slime_wall_detour_target", self, slime) as Vector2
func _start_slime_hold(slime: Sprite2D) -> void: slime_runtime_controller.call("start_slime_hold", self, slime)
func _set_actor_visual_scale(actor: Sprite2D, visual_scale: Vector2) -> void: actor_presentation_runtime_controller.call("set_actor_visual_scale", self, actor, visual_scale)
func _try_move_actor(actor: Sprite2D, movement: Vector2) -> bool: return bool(slime_runtime_controller.call("try_move_actor", self, actor, movement))
func _try_move_actor_axes(actor: Sprite2D, movement: Vector2) -> bool: return bool(slime_runtime_controller.call("try_move_actor_axes", self, actor, movement))
func _resolve_actor_contacts(actor: Sprite2D, movement: Vector2) -> void: slime_runtime_controller.call("resolve_actor_contacts", self, actor, movement)
func _collides_with_static(actor: Sprite2D) -> bool: return bool(slime_runtime_controller.call("collides_with_static", self, actor))
func _collision_polygon_intersects_actor(actor: Sprite2D, polygon_owner: Sprite2D) -> bool: return bool(slime_runtime_controller.call("collision_polygon_intersects_actor", self, actor, polygon_owner))
func _perspective_movement(movement: Vector2) -> Vector2: return slime_runtime_controller.call("perspective_movement", self, movement) as Vector2
func _collision_rect(actor: Sprite2D) -> Rect2: return slime_runtime_controller.call("collision_rect", self, actor) as Rect2
func _collision_guide_rect(actor: Sprite2D) -> Rect2: return slime_runtime_controller.call("collision_guide_rect", self, actor) as Rect2
func _collision_guide_rect_by_name(actor: Sprite2D, guide_name: String) -> Rect2: return slime_runtime_controller.call("collision_guide_rect_by_name", self, actor, guide_name) as Rect2
func _build_depth_lists() -> void: actor_presentation_runtime_controller.call("build_depth_lists", self)
func _hide_editor_only_guides() -> void: actor_presentation_runtime_controller.call("hide_editor_only_guides", self)
func _build_slime_direction_textures() -> void: actor_presentation_runtime_controller.call("build_slime_direction_textures", self)
func _build_slime_attack_frames() -> void: actor_presentation_runtime_controller.call("build_slime_attack_frames", self)
func _assign_slime_attack_frames() -> void: actor_presentation_runtime_controller.call("assign_slime_attack_frames", self)
func _build_slime_shocked_frames() -> void: actor_presentation_runtime_controller.call("build_slime_shocked_frames", self)
func _build_slime_spawn_frames() -> void: actor_presentation_runtime_controller.call("build_slime_spawn_frames", self)
func _assign_slime_spawn_frames() -> void: actor_presentation_runtime_controller.call("assign_slime_spawn_frames", self)
func _assign_slime_shocked_frames() -> void: actor_presentation_runtime_controller.call("assign_slime_shocked_frames", self)
func _build_enemy_health_ui() -> void: actor_presentation_runtime_controller.call("build_enemy_health_ui", self)
func _refresh_enemy_palette_textures() -> void: actor_presentation_runtime_controller.call("refresh_enemy_palette_textures", self)
func _build_cloaked_demon_frames() -> void: var frames := npc_controller.build_cloaked_demon_frames(sprite_frame_library, cloaked_demon, CLOAKED_DEMON_FRAME_SIZE, Callable(occlusion_renderer, "cached_texture_image")); npc_controller.demon_idle_frames = frames["idle"]; npc_controller.demon_walk_frames = frames["walk"]; npc_controller.demon_visual_bounds = frames["bounds"]
func _cloaked_demon_head_position() -> Vector2: return _cloaked_demon_texture_origin() + Vector2(npc_controller.demon_visual_bounds.get_center().x, npc_controller.demon_visual_bounds.position.y)
func _cloaked_demon_visual_center() -> Vector2: return _cloaked_demon_texture_origin() + npc_controller.demon_visual_bounds.get_center()
func _cloaked_demon_foot_position() -> Vector2: return _cloaked_demon_texture_origin() + Vector2(npc_controller.demon_visual_bounds.get_center().x, npc_controller.demon_visual_bounds.end.y - 1.0)
func _configure_cloaked_demon_patrol_route() -> void:
	var route := npc_controller.configure_patrol_route(cloaked_demon, walkable_outline, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_is_walkable"))
	if route.is_empty(): return
	npc_controller.demon_patrol_min_x = route["min_x"]; npc_controller.demon_patrol_max_x = route["max_x"]; npc_controller.demon_wander_origin = route["origin"]; npc_controller.demon_patrol_position_x = route["position_x"]; npc_controller.demon_wander_target = route["target"]; npc_controller.demon_wander_has_target = route["has_target"]
func _set_slime_facing(slime: Sprite2D, direction_x: float) -> void: actor_presentation_runtime_controller.call("set_slime_facing", self, slime, direction_x)
func _update_slime_attack_guides(slime: Sprite2D) -> void: actor_presentation_runtime_controller.call("update_slime_attack_guides", self, slime)
func _set_actor_base_texture(actor: Sprite2D, texture: Texture2D) -> void: actor_presentation_runtime_controller.call("set_actor_base_texture", self, actor, texture)
func _collect_occluders(node: Node) -> void: actor_presentation_runtime_controller.call("collect_occluders", self, node)
func _add_depth_sprite(sprite: Sprite2D) -> void: actor_presentation_runtime_controller.call("add_depth_sprite", self, sprite)
func _update_depth_sorting() -> void: actor_presentation_runtime_controller.call("update_depth_sorting", self)
func _update_actor_occlusion(delta: float) -> void: actor_presentation_runtime_controller.call("update_actor_occlusion", self, delta)
func _is_actor_occlusion_flashing(actor: Sprite2D) -> bool: return bool(actor_presentation_runtime_controller.call("is_actor_occlusion_flashing", self, actor))
func _update_player_shadow() -> void: shadow_controller.update_player_shadow(self, DEPTH_Z_SCALE)
func _update_cloaked_demon_shadow() -> void: shadow_controller.update_cloaked_demon_shadow(self, DEPTH_Z_SCALE)
func _update_targeting() -> void: interaction_component.update_targeting(self)
func _target_facing_left(target: Sprite2D) -> bool: return interaction_component.target_facing_left(self, target)
func _movement_input() -> Vector2: return player_controller.movement_input(_controller_devices(), CONTROLLER_DEADZONE)
func _raw_movement_input() -> Vector2: return input_router.raw_movement() if input_router != null else Vector2.ZERO
func _is_target_input_held() -> bool: return player_controller.target_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _target_cycle_direction() -> int: return player_controller.target_cycle_direction(_controller_devices(), CONTROLLER_DEADZONE)
func _is_guard_input_held() -> bool: return player_controller.guard_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _is_attack_input_pressed() -> bool: return player_controller.action_pressed(&"attack", _controller_devices(), JOY_BUTTON_X)
func _is_interact_input_pressed() -> bool: return player_controller.action_pressed(&"interact", _controller_devices(), JOY_BUTTON_B)
func _is_roll_input_pressed() -> bool: return player_controller.action_pressed(&"roll", _controller_devices(), JOY_BUTTON_A)
func _is_magic_input_pressed() -> bool: return player_controller.action_pressed(&"magic", _controller_devices(), JOY_BUTTON_Y)
func _controller_devices() -> Array[int]: return player_controller.connected_devices()
func _closest_target() -> Sprite2D:
	return targeting_runtime_controller.call("closest_target", self) as Sprite2D
func _valid_current_target() -> Sprite2D:
	return targeting_runtime_controller.call("valid_current_target", self) as Sprite2D
func _cycle_target(direction: int) -> void:
	targeting_runtime_controller.call("cycle_target", self, direction)
func _set_current_target(target: Sprite2D, play_feedback: bool = true) -> void:
	targeting_runtime_controller.call("set_current_target", self, target, play_feedback)
func _set_puzzle_torch_target_highlight(torch: Sprite2D, highlighted: bool) -> void:
	targeting_runtime_controller.call("set_puzzle_torch_target_highlight", self, torch, highlighted)
func _update_target_ui() -> void:
	targeting_runtime_controller.call("update_target_ui", self)
func _update_puzzle_torch_target_ui(torch: Sprite2D) -> void:
	targeting_runtime_controller.call("update_puzzle_torch_target_ui", self, torch)
func _set_target_ui_visible(target_visible: bool) -> void: targeting_runtime_controller.call("set_target_ui_visible", self, target_visible)
func _update_focus_indicator(delta: float = 0.0) -> void:
	targeting_runtime_controller.call("update_focus_indicator", self, delta)
func _slime_display_name(slime: Sprite2D) -> String:
	return str(targeting_runtime_controller.call("slime_display_name", self, slime))
func _update_player_health_ui(delta: float = 0.0) -> void: var result: Dictionary = hud_controller.update_player_health_ui(player_health_component.current_health if player_health_component != null else 0.0, player_display_health, player_damage_fill_hold_timer, delta, slime_tuning.health_regen_fill_speed, slime_tuning.health_drain_fill_speed, _player_max_health(), player_health_fill, player_health_damage_fill, player_health_fill_size, player_health_text, Callable(self, "_pixel_text_texture"), Callable(hud_controller, "set_health_bar_values")); player_display_health = result["display_health"]; player_damage_fill_hold_timer = result["damage_hold"]
func _update_player_mp_ui(_delta: float = 0.0) -> void: magic_runtime_controller.call("update_player_mp_ui", self)
func _current_player_chroma() -> float: return float(magic_runtime_controller.call("current_player_chroma", self))
func _restore_player_mp() -> void: magic_runtime_controller.call("restore_player_mp", self)
func _try_cast_magic() -> bool: return bool(magic_runtime_controller.call("try_cast_magic", self))
func _update_magic_input(magic_down: bool, was_down: bool, delta: float) -> bool: return bool(magic_runtime_controller.call("update_magic_input", self, magic_down, was_down, delta))
func _try_cast_imbue() -> bool: return bool(magic_runtime_controller.call("try_cast_imbue", self))
func _cancel_magic_animation() -> void: magic_runtime_controller.call("cancel_magic_animation", self)
func _reset_magic_runtime(reset_cooldown: bool = false) -> void: magic_runtime_controller.call("reset_for_room", self, reset_cooldown)
func _sync_chroma_presentation() -> void:
	magic_runtime_controller.call("sync_chroma_presentation", self)
	_sync_current_element_state()
func _execute_current_aspect_ability(mode: int) -> bool: return bool(magic_runtime_controller.call("execute_current_aspect_ability", self, mode))
func _player_visual_center() -> Vector2: return magic_runtime_controller.call("player_visual_center", self) as Vector2
func _slime_visual_center(slime: Sprite2D) -> Vector2: return magic_runtime_controller.call("slime_visual_center", self, slime) as Vector2
func _magic_target_point(slime: Sprite2D) -> Vector2: return magic_runtime_controller.call("magic_target_point", self, slime) as Vector2
func _spawn_magic_projectile(origin: Vector2, direction: Vector2, homing_target: Sprite2D = null, ability_mode: int = 0) -> void: magic_runtime_controller.call("spawn_magic_projectile", self, origin, direction, homing_target, ability_mode)
func _magic_projectile_outline_texture(base_color: Color, accent_color: Color) -> Texture2D: return magic_runtime_controller.call("magic_projectile_outline_texture", self, base_color, accent_color) as Texture2D
func _update_magic_projectiles(delta: float) -> void: magic_runtime_controller.call("update_magic_projectiles", self, delta)
func _resolve_magic_projectile_hit(target: Sprite2D, world_position: Vector2, palette: String, ability_mode: int = 0) -> void: magic_runtime_controller.call("resolve_magic_projectile_hit", self, target, world_position, palette, ability_mode)
func _magic_projectile_hit_target(sprite: Sprite2D) -> Sprite2D: return magic_runtime_controller.call("magic_projectile_hit_target", self, sprite) as Sprite2D
func _circle_intersects_polygon(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool: return bool(magic_runtime_controller.call("_circle_intersects_polygon", center, radius, polygon))
func _magic_hit_slime(slime: Sprite2D, world_position: Vector2, palette: String, ability_mode: int = 0) -> void: magic_runtime_controller.call("magic_hit_slime", self, slime, world_position, palette, ability_mode)
func _player_weapon_element() -> int: return int(magic_runtime_controller.call("player_weapon_element", self))
func _spawn_magic_trail(world_position: Vector2, palette: String) -> void: magic_runtime_controller.call("spawn_magic_trail", self, world_position, palette)
func _spawn_magic_impact(world_position: Vector2, palette: String) -> void: magic_runtime_controller.call("spawn_magic_impact", self, world_position, palette)
func _update_overworld_ui() -> void: hud_controller.update_overworld(self, get_process_delta_time(), OVERWORLD_UI_Z)
func _depth_key(sprite: Sprite2D) -> float: return float(actor_presentation_runtime_controller.call("depth_key", self, sprite))
func _equipment_occlusion_depth_key(sprite: Sprite2D) -> float: return float(actor_presentation_runtime_controller.call("equipment_occlusion_depth_key", self, sprite))
func _sprite_source_global_rect(sprite: Sprite2D) -> Rect2: return actor_presentation_runtime_controller.call("sprite_source_global_rect", self, sprite) as Rect2
func _build_exact_occluded_actor_texture(actor: Sprite2D, active_occluders: Array[Sprite2D], is_target: bool, use_grey_highlight: bool) -> Texture2D: return actor_presentation_runtime_controller.call("build_exact_occluded_actor_texture", self, actor, active_occluders, is_target, use_grey_highlight) as Texture2D
func _is_pixel_covered_by_occluder(world_pixel: Vector2, active_occluders: Array[Sprite2D]) -> bool: return bool(actor_presentation_runtime_controller.call("is_pixel_covered_by_occluder", self, world_pixel, active_occluders))
func _apply_actor_scale(actor: Sprite2D, use_effect_texture: bool) -> void: actor_presentation_runtime_controller.call("apply_actor_scale", self, actor, use_effect_texture)
func _restore_actor_base_visual_scale(actor: Sprite2D) -> void: actor_presentation_runtime_controller.call("restore_actor_base_visual_scale", self, actor)
func _actor_screen_scale(actor: Sprite2D) -> Vector2: return actor_presentation_runtime_controller.call("actor_screen_scale", self, actor) as Vector2
func _actor_visual_offset(actor: Sprite2D) -> Vector2: return actor_presentation_runtime_controller.call("actor_visual_offset", self, actor) as Vector2
func _sync_actor_geometry_offset(actor: Sprite2D) -> void: actor_presentation_runtime_controller.call("sync_actor_geometry_offset", self, actor)
func _collect_walkable_tiles(node: Node) -> void: slime_runtime_controller.call("collect_walkable_tiles", self, node)
func _build_walkable_outline() -> void: slime_runtime_controller.call("build_walkable_outline", self)
func _build_entrance_block_polygons() -> void: slime_runtime_controller.call("build_entrance_block_polygons", self)
func _is_walkable(point: Vector2) -> bool: return bool(slime_runtime_controller.call("is_walkable", self, point))
func _can_actor_stand_at_current_position(actor: Sprite2D) -> bool: return bool(slime_runtime_controller.call("can_actor_stand_at_current_position", self, actor))
func _is_slime_walkable_point(point: Vector2) -> bool: return bool(slime_runtime_controller.call("is_slime_walkable_point", self, point))
func _tile_top_polygon(tile: Sprite2D) -> PackedVector2Array: return slime_runtime_controller.call("tile_top_polygon", self, tile) as PackedVector2Array
func _nearest_slime_walkable_point(point: Vector2) -> Vector2: return slime_runtime_controller.call("nearest_slime_walkable_point", self, point) as Vector2
func _random_slime_walkable_point_near(point: Vector2, sample_count: int, ignored_slime: Sprite2D = null) -> Vector2: return slime_runtime_controller.call("random_slime_walkable_point_near", self, point, sample_count, ignored_slime) as Vector2
func _nearest_valid_slime_walkable_point(point: Vector2, slime: Sprite2D) -> Vector2: return slime_runtime_controller.call("nearest_valid_slime_walkable_point", self, point, slime) as Vector2
func _is_slime_collision_rect_walkable_at(slime: Sprite2D, foot: Vector2) -> bool: return bool(slime_runtime_controller.call("is_slime_collision_rect_walkable_at", self, slime, foot))
func _slime_collision_polygon(slime: Sprite2D, foot: Vector2 = Vector2.INF) -> PackedVector2Array: return slime_runtime_controller.call("slime_collision_polygon", self, slime, foot) as PackedVector2Array
func _slime_body_polygon(slime: Sprite2D) -> PackedVector2Array: return slime_runtime_controller.call("slime_body_polygon", self, slime) as PackedVector2Array
func _is_slime_collision_polygon_walkable(polygon: PackedVector2Array) -> bool: return bool(slime_runtime_controller.call("is_slime_collision_polygon_walkable", self, polygon))
func _is_point_near_other_slime(point: Vector2, ignored_slime: Sprite2D = null) -> bool: return bool(slime_runtime_controller.call("is_point_near_other_slime", self, point, ignored_slime))
func _actor_foot(actor: Sprite2D) -> Vector2: return slime_runtime_controller.call("actor_foot", self, actor) as Vector2
