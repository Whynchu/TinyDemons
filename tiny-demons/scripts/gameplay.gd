extends Node2D

const PLAYER_SPEED := 36.0
const SLIME_SCOOT_DISTANCE := 5.0
const SLIME_SCOOT_DURATION := 0.34
const SLIME_ATTACK_FRAME_SIZE := Vector2i(16, 16)
const SLIME_ATTACK_FRAME_TIME := 0.08
const SLIME_ATTACK_HIT_FRAME := 5
const SLIME_ATTACK_RANGE := 14.0
const SLIME_ATTACK_HIT_RANGE := 16.0
const SLIME_ATTACK_VERTICAL_HIT_RANGE := 10.0
const SLIME_AGGRO_RANGE := 28.0
const SLIME_ATTACK_COOLDOWN := 1.0
const SLIME_ATTACK_LUNGE_DISTANCE := 4.0
const PLAYER_HIT_FLASH_TIME := 0.12
const PLAYER_HITSTUN_TIME := 1.0 / 30.0
const PLAYER_HIT_KNOCKBACK := 10.0
const PLAYER_HIT_KNOCKBACK_DURATION := 0.12
const SLIME_HOLD_MIN := 0.22
const SLIME_HOLD_MAX := 0.48
const SLIME_CHILL_CHANCE := 0.22
const SLIME_CHILL_MIN := 1.0
const SLIME_CHILL_MAX := 2.2
const SLIME_IDLE_BREATH_TIME := 1.4
const SLIME_REPATH_MIN := 0.7
const SLIME_REPATH_MAX := 1.8
const EDGE_MARGIN := 0.35
const SLIME_EDGE_PADDING := 3.0
const ACTOR_FOOT_OFFSET := Vector2(8, 15)
const DEPTH_Z_SCALE := 10.0
const EFFECT_RESOLUTION_SCALE := 2
const OVERWORLD_UI_Z := 4090
const VERTICAL_MOVEMENT_SCALE := 0.5
const PLAYER_FRAME_SIZE := Vector2i(36, 36)
const PLAYER_ATTACK_FRAME_SIZE := Vector2i(36, 36)
const PLAYER_IDLE_FRAME_TIME := 0.22
const PLAYER_WALK_FRAME_TIME := 0.18
const PLAYER_ATTACK_FRAME_TIME := 0.09
const PLAYER_ATTACK_HIT_FRAME := 2
const PLAYER_ROLL_FRAME_TIME := 0.05
const PLAYER_ROLL_DISTANCE := 30.0
const PLAYER_ROLL_DURATION := 0.30
const PLAYER_DEATH_PARTICLE_LIFETIME := 1.8
const PLAYER_DEATH_FADE_TIME := 0.7
const PLAYER_DEATH_PARTICLE_DELAY := 0.7
const HITSTOP_DURATION := 1.0 / 40.0
const PLAYER_DEATH_OBSERVE_TIME := 1.4
const GAME_OVER_FADE_TIME := 0.8
const PLAYER_TEXTURE_OFFSET := Vector2(-10, -10)
const PLAYER_ATTACK_LUNGE_DISTANCE := 6.0
const PLAYER_ATTACK_LUNGE_DURATION := 0.18
const HEALTH_BASE := 8.0
const HEALTH_PER_VIT := 2.0
const DAMAGE_BASE := 2.0
const DAMAGE_DEFENSE_SCALE := 12.0
const PLAYER_ATTACK_KNOCKBACK := 16.0
const PLAYER_ATTACK_HITBOX_SIZE := Vector2(24, 24)
const PLAYER_ATTACK_HITBOX_RIGHT_OFFSET := Vector2(6, -7)
const PLAYER_ATTACK_HITBOX_LEFT_OFFSET := Vector2(-14, -7)
const ENEMY_HIT_FLASH_TIME := 0.12
const ENEMY_HITSTUN_TIME := 1.0 / 30.0
const ENEMY_KNOCKBACK_DURATION := 0.14
const ENEMY_REGEN_DELAY := 3.0
const ENEMY_REGEN_INTERVAL := 0.5
const ENEMY_REGEN_AMOUNT := 1.0
const PLAYER_REGEN_DELAY := 2.0
const PLAYER_REGEN_INTERVAL := 1.0
const PLAYER_REGEN_AMOUNT := 1.0
const ENEMY_HEALTH_DRAIN_FILL_SPEED := 18.0
const ENEMY_HEALTH_REGEN_FILL_SPEED := 10.0
const ENEMY_HEALTH_DAMAGE_HANG_TIME := 0.14
const DAMAGE_NUMBER_LIFETIME := 0.65
const DAMAGE_NUMBER_FLOAT_SPEED := 12.0
const SLIME_DEATH_PARTICLE_COUNT := 26
const SLIME_DEATH_PARTICLE_LIFETIME := 0.7
const SLIME_DEATH_PARTICLE_SPEED_MIN := 14.0
const SLIME_DEATH_PARTICLE_SPEED_MAX := 38.0
const CHEST_INTERACT_DISTANCE := 16.0
const CHEST_REWARD_GOLD := 100
const INTERACT_PROMPT_BOB_TIME := 0.8
const CHEST_COLLECT_FLASH_TIME := 0.12
const CHEST_UNLOCK_FADE_TIME := 0.45
const CHEST_EVAPORATE_PARTICLE_COUNT := 34
const CHEST_EVAPORATE_LIFETIME_MIN := 0.45
const CHEST_EVAPORATE_LIFETIME_MAX := 0.9
const PLAYER_DOOR_FOOT_COLLIDER_SIZE := Vector2(3, 3)
const ACTOR_COLLISION_WIDTH := 9.0
const ACTOR_COLLISION_HEIGHT := 4.0
const ACTOR_CONTACT_RADIUS := 3.6
const CHEST_COLLISION_SIZE := Vector2(11, 6)
const SLIME_WEIGHT := 1.45
const PLAYER_WEIGHT := 1.0
const TARGET_HEALTH_MAX := 10.0
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
@onready var slime_blue: Sprite2D = $Actors/SlimeBlue
@onready var slime_green: Sprite2D = $Actors/SlimeGreen
@onready var slime_red: Sprite2D = $Actors/SlimeRed
@onready var door: Sprite2D = $Map/Walls/DoorRight
@onready var entrance_tile_a: Sprite2D = $Map/FloorTiles/Entrance
@onready var entrance_tile_b: Sprite2D = $"Map/FloorTiles/Entrance/Tile 2"
@onready var hp_overhead: Sprite2D = $Actors/SlimeGreen/HpOverhead
@onready var hp_overhead_fill: Sprite2D = $Actors/SlimeGreen/HpOverheadFill
@onready var chest: Sprite2D = $Actors/Chest
@onready var target_name_text: Sprite2D = $UI/SlimeText
@onready var target_health_bar: Sprite2D = $UI/EnemyHp
@onready var target_health_fill: Sprite2D = $UI/EnemyHpFill
@onready var player_health_fill: Sprite2D = $UI/HpBarFill
@onready var player_stats: StatsComponent = $Actors/TinyDemon/Stats
var player_equipment: EquipmentComponent = null

var player_idle_frames: Array[Texture2D] = []
var player_walk_frames: Array[Texture2D] = []
var player_attack_frames: Array[Texture2D] = []
var player_attack_left_frames: Array[Texture2D] = []
var player_anim_name := "idle"
var player_anim_frame := 0
var player_anim_timer := 0.0
var player_is_moving := false
var player_is_attacking := false
var player_is_rolling := false
var player_roll_frames: Array[Texture2D] = []
var player_roll_frame := 0
var player_roll_timer := 0.0
var player_roll_velocity := Vector2.ZERO
var player_roll_input_was_down := false
var player_attack_input_was_down := false
var player_attack_hit_done := false
var player_attack_hit_targets: Array[Sprite2D] = []
var player_attack_lunge_velocity := Vector2.ZERO
var player_attack_lunge_timer := 0.0
var player_attack_flip_h := false
var player_hit_flash_timer := 0.0
var player_hit_knockback_velocity := Vector2.ZERO
var player_hit_knockback_timer := 0.0
var player_hitstun_timer := 0.0
var slime_left_textures: Dictionary = {}
var slime_right_textures: Dictionary = {}
var slime_attack_left_frames: Dictionary = {}
var slime_attack_right_frames: Dictionary = {}
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
var slime_targets: Dictionary = {}
var slime_repath_timers: Dictionary = {}
var slime_scoot_starts: Dictionary = {}
var slime_scoot_targets: Dictionary = {}
var slime_scoot_timers: Dictionary = {}
var slime_hold_timers: Dictionary = {}
var slime_idle_breath_timers: Dictionary = {}
var slime_flash_timers: Dictionary = {}
var slime_hitstun_timers: Dictionary = {}
var slime_knockback_velocities: Dictionary = {}
var slime_knockback_timers: Dictionary = {}
var slime_attack_timers: Dictionary = {}
var slime_attack_frame_indices: Dictionary = {}
var slime_attack_hit_done: Dictionary = {}
var slime_attack_face_left: Dictionary = {}
var slime_attack_cooldowns: Dictionary = {}
var slime_persistent_aggro: Dictionary = {}
var dead_slimes: Dictionary = {}
var slime_start_positions: Dictionary = {}
var actor_stats: Dictionary = {}
var actor_default_textures: Dictionary = {}
var actor_default_materials: Dictionary = {}
var original_actor_textures: Dictionary = {}
var original_actor_images: Dictionary = {}
var original_actor_scales: Dictionary = {}
var actor_visual_scales: Dictionary = {}
var occluded_actor_textures: Dictionary = {}
var actor_occlusion_grace: Dictionary = {}
var highlighted_actor_textures: Dictionary = {}
var white_actor_textures: Dictionary = {}
var sprite_images: Dictionary = {}
var texture_image_cache: Dictionary = {}
var effect_image_cache: Dictionary = {}
var highlighted_image_cache: Dictionary = {}
var white_image_cache: Dictionary = {}
var damage_number_texture_cache: Dictionary = {}
var pixel_particle_texture_cache: Dictionary = {}
var player_shadow_offset := Vector2.ZERO
var player_shadow_scale := Vector2.ONE
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
var game_over_fade_timer := 0.0
var gold := 0
var interact_input_was_down := false
var chest_unlocked := false
var chest_claimed := false
var chest_collect_flash_timer := 0.0
var chest_unlock_fade_timer := 0.0
var chest_evaporated := false
var door_active := false
var entrance_open := false
var room_number := 1
var room_states: Dictionary = {}
var chest_normal_texture: Texture2D = null
var chest_gray_texture: Texture2D = null
var chest_unlock_overlay: Sprite2D = null
var chest_flash_overlay: Sprite2D = null
var interact_prompt: Sprite2D = null
var interact_prompt_base_position := Vector2.ZERO
var interact_prompt_timer := 0.0
var room_number_indicator: Sprite2D = null
var gold_indicator: Sprite2D = null
var target_health_text: Sprite2D = null
var player_health_text: Sprite2D = null
var player_start_position := Vector2.ZERO
var chest_start_position := Vector2.ZERO
var target_health: Dictionary = {}
var target_display_health: Dictionary = {}
var target_damage_fill_hold_timers: Dictionary = {}
var target_regen_delay_timers: Dictionary = {}
var target_regen_accumulators: Dictionary = {}
var target_health_fill_textures: Dictionary = {}
var target_health_damage_fill_textures: Dictionary = {}
var target_overhead_fill_textures: Dictionary = {}
var target_overhead_damage_fill_textures: Dictionary = {}
var target_overhead_frames: Dictionary = {}
var target_overhead_damage_fills: Dictionary = {}
var target_overhead_fills: Dictionary = {}
var target_overhead_offsets: Dictionary = {}
var target_overhead_fill_sizes: Dictionary = {}
var target_overhead_aggro_markers: Dictionary = {}
var target_health_damage_fill: Sprite2D = null
var target_health_bar_size := Vector2.ZERO
var player_health_fill_size := Vector2.ZERO
var damage_numbers: Array[Dictionary] = []
var pixel_particles: Array[Dictionary] = []
var player_regen_delay_timer := 0.0
var player_regen_accumulator := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	player_start_position = player.position
	chest_start_position = chest.position
	chest_gray_texture = chest.texture
	chest_normal_texture = _load_texture_or_null("res://assets/artwork/Chest.png")
	_set_door_active(false)
	_set_entrance_open(false)
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
	player_shadow_offset = player_shadow.global_position - player.global_position
	player_shadow_scale = player_shadow.global_scale
	player_shadow.z_as_relative = false
	player_attack_visual.z_as_relative = false
	player_attack_visual.visible = false
	_hide_editor_only_guides()
	hp_overhead.z_as_relative = false
	hp_overhead_fill.z_as_relative = false
	target_health_bar_size = target_health_fill.texture.get_size()
	player_health_fill_size = player_health_fill.texture.get_size()
	_build_depth_lists()
	_build_sprite_images()
	_build_player_animation_frames()
	_build_slime_direction_textures()
	_build_slime_attack_frames()
	_build_enemy_health_ui()
	_build_target_health_text()
	_build_interact_prompt()
	_build_room_number_indicator()
	_build_gold_indicator()
	_build_game_over_ui()
	player_equipment = player.get_node_or_null("Equipment") as EquipmentComponent
	if player_equipment == null:
		player_equipment = EquipmentComponent.new()
		player_equipment.name = "Equipment"
		player_equipment.equip_default_loadout()
		player.add_child(player_equipment)
	_set_target_ui_visible(false)
	player_health = _player_max_health()
	player_regen_delay_timer = 0.0
	player_regen_accumulator = 0.0
	_update_player_health_ui()
	use_walkable_polygon_direct = false
	_collect_walkable_tiles(floor_tiles)
	_build_entrance_block_polygons()
	_build_walkable_outline()
	if walkable_outline.is_empty():
		push_warning("No floor tiles found. Actor movement will be disabled.")
		return
	for slime in slimes:
		slime_start_positions[slime] = slime.position
		slime_targets[slime] = _nearest_slime_walkable_point(_actor_foot(slime))
		slime_repath_timers[slime] = rng.randf_range(SLIME_REPATH_MIN, SLIME_REPATH_MAX)
		slime_scoot_starts[slime] = slime.position
		slime_scoot_targets[slime] = slime.position
		slime_scoot_timers[slime] = 0.0
		slime_hold_timers[slime] = rng.randf_range(SLIME_HOLD_MIN, SLIME_HOLD_MAX)
		slime_idle_breath_timers[slime] = rng.randf_range(0.0, SLIME_IDLE_BREATH_TIME)
		slime_flash_timers[slime] = 0.0
		slime_hitstun_timers[slime] = 0.0
		slime_knockback_velocities[slime] = Vector2.ZERO
		slime_knockback_timers[slime] = 0.0
		slime_attack_timers[slime] = 0.0
		slime_attack_frame_indices[slime] = 0
		slime_attack_hit_done[slime] = false
		slime_attack_face_left[slime] = false
		_update_slime_attack_guides(slime)
		slime_attack_cooldowns[slime] = rng.randf_range(0.2, 0.6)
		slime_persistent_aggro[slime] = false
		dead_slimes[slime] = false
		actor_stats[slime] = slime.get_node_or_null("Stats") as StatsComponent
		_apply_enemy_room_level(slime)
		var max_health := _enemy_max_health(slime)
		target_health[slime] = max_health
		target_display_health[slime] = max_health
		target_damage_fill_hold_timers[slime] = 0.0
		target_regen_delay_timers[slime] = 0.0
		target_regen_accumulators[slime] = 0.0


func _physics_process(delta: float) -> void:
	if walkable_outline.is_empty():
		return
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(hitstop_timer - delta, 0.0)
		return
	if player_death_pending and not player_dead:
		_update_player_hit_reaction(delta)
		_update_damage_numbers(delta)
		if player_hit_knockback_timer <= 0.0:
			_start_player_death()
		return
	if player_dead:
		_update_pixel_particles(delta)
		_update_player_death(delta)
		_update_damage_numbers(delta)
		if player_death_particles_started and player_death_timer >= PLAYER_DEATH_PARTICLE_DELAY + PLAYER_DEATH_PARTICLE_LIFETIME:
			_move_slimes(delta)
			_update_enemy_hit_flashes(delta)
			_update_enemy_health(delta)
		_update_depth_sorting()
		_update_actor_occlusion(delta)
		_stabilize_collision_guides()
		_update_overworld_ui()
		_update_game_over_input()
		return
	_update_player_attack_input()
	_update_player_roll_input()
	_update_player_attack_lunge(delta)
	_update_player_roll(delta)
	_update_player_hit_reaction(delta)
	_move_player(delta)
	_update_player_animation(delta)
	_move_slimes(delta)
	_update_enemy_hit_flashes(delta)
	_update_enemy_health(delta)
	_update_player_health_regen(delta)
	_update_damage_numbers(delta)
	_update_pixel_particles(delta)
	_update_chest_interaction()
	_update_chest_visuals(delta)
	_update_door_transition()
	_update_depth_sorting()
	_update_targeting()
	_update_actor_occlusion(delta)
	_stabilize_collision_guides()
	_update_player_attack_visual()
	_update_player_shadow()
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
	player_attack_visual.visible = false
	player_death_origin = player.global_position
	player_death_offset = player.offset
	player_death_scale = player.scale
	player_death_texture = player.texture
	player.visible = false
	player_shadow.visible = false
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
		if player_death_timer < PLAYER_DEATH_PARTICLE_DELAY:
			player_death_overlay.modulate.a = clampf(player_death_timer / PLAYER_DEATH_FADE_TIME, 0.0, 1.0)
		elif not player_death_particles_started:
			player_death_particles_started = true
			_spawn_player_death_pixels()
			player_death_overlay.queue_free()
			player_death_overlay = null
	if not player_death_particles_started:
		return
	var death_effect_end := PLAYER_DEATH_PARTICLE_DELAY + PLAYER_DEATH_PARTICLE_LIFETIME
	if game_over_overlay != null and game_over_overlay.visible:
		game_over_fade_timer += delta
		game_over_overlay.modulate.a = clampf(game_over_fade_timer / GAME_OVER_FADE_TIME, 0.0, 1.0)
		if game_over_button != null:
			game_over_button.modulate.a = 0.55 + sin(game_over_fade_timer * 7.0) * 0.45
	elif player_death_timer >= death_effect_end + PLAYER_DEATH_OBSERVE_TIME:
		_show_game_over()


func _spawn_player_death_pixels() -> void:
	var texture := player_death_texture
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.32
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var candidates: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0 and noise.get_noise_2d(float(x), float(y)) > -0.22:
				candidates.append(Vector2i(x, y))
	candidates.shuffle()
	for source_pixel in candidates:
		var particle := Sprite2D.new()
		particle.texture = _pixel_particle_texture(Color.WHITE)
		particle.centered = false
		particle.scale = player_death_scale
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = int(round(_depth_key(player) * DEPTH_Z_SCALE)) + 2
		particle.position = player_death_origin + player_death_offset + Vector2(source_pixel) * player_death_scale
		add_child(particle)
		var lifetime := rng.randf_range(1.2, PLAYER_DEATH_PARTICLE_LIFETIME)
		pixel_particles.append({
			"sprite": particle,
			# Fizzle particles rise from their source pixel without horizontal drift.
			"velocity": Vector2(0.0, rng.randf_range(-18.0, -7.0)),
			"timer": lifetime,
			"lifetime": lifetime,
			"gravity": 0.0,
		})


func _build_game_over_ui() -> void:
	game_over_overlay = ColorRect.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.position = Vector2.ZERO
	game_over_overlay.size = Vector2(240, 160)
	game_over_overlay.color = Color(0, 0, 0, 0.82)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_overlay.visible = false
	game_over_overlay.modulate.a = 0.0
	ui.add_child(game_over_overlay)
	var title := Sprite2D.new()
	title.texture = _pixel_text_texture("GAME OVER", Color.WHITE)
	title.centered = false
	title.scale = Vector2(3, 3)
	title.position = Vector2((240.0 - title.texture.get_width() * 3.0) * 0.5, 50)
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game_over_overlay.add_child(title)
	game_over_button = Button.new()
	game_over_button.position = Vector2(99, 105)
	game_over_button.size = Vector2(42, 12)
	game_over_button.text = ""
	game_over_button.focus_mode = Control.FOCUS_ALL
	game_over_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1, 1, 1, 0.12)
	focus_style.border_color = Color.WHITE
	focus_style.set_border_width_all(1)
	game_over_button.add_theme_stylebox_override("normal", normal_style)
	game_over_button.add_theme_stylebox_override("hover", focus_style)
	game_over_button.add_theme_stylebox_override("focus", focus_style)
	var restart_text := Sprite2D.new()
	restart_text.texture = _pixel_text_texture("RESTART", Color.WHITE)
	restart_text.centered = true
	restart_text.position = game_over_button.size * 0.5
	restart_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	game_over_button.add_child(restart_text)
	game_over_button.pressed.connect(_restart_game)
	game_over_overlay.add_child(game_over_button)


func _show_game_over() -> void:
	if game_over_overlay == null or game_over_overlay.visible:
		return
	game_over_overlay.visible = true
	game_over_fade_timer = 0.0
	game_over_overlay.modulate.a = 0.0
	game_over_button.grab_focus()


func _update_game_over_input() -> void:
	if game_over_overlay == null or not game_over_overlay.visible:
		return
	if Input.is_action_just_pressed("ui_accept") or _is_interact_input_pressed():
		_restart_game()


func _restart_game() -> void:
	get_tree().reload_current_scene()


func _move_player(delta: float) -> void:
	if player_death_pending or player_is_attacking or player_is_rolling or player_hit_knockback_timer > 0.0 or player_hitstun_timer > 0.0:
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

	_try_move_actor(player, _perspective_movement(input.normalized() * PLAYER_SPEED * delta))


func _update_player_attack_input() -> void:
	var attack_input_down := _is_attack_input_pressed()
	if attack_input_down and not player_attack_input_was_down and not player_is_attacking and not player_is_rolling:
		_start_player_attack()
	player_attack_input_was_down = attack_input_down


func _update_player_roll_input() -> void:
	var roll_input_down := _is_roll_input_pressed()
	if roll_input_down and not player_roll_input_was_down and not player_is_attacking and not player_is_rolling and player_hit_knockback_timer <= 0.0:
		_start_player_roll()
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
	player_roll_frame = 0
	player_roll_timer = 0.0
	player_roll_velocity = _perspective_movement(direction * (PLAYER_ROLL_DISTANCE / PLAYER_ROLL_DURATION))
	player.visible = true
	_apply_player_animation_frame()


func _update_player_roll(delta: float) -> void:
	if not player_is_rolling:
		return
	var elapsed := player_roll_timer + float(player_roll_frame) * PLAYER_ROLL_FRAME_TIME
	var step_time := minf(delta, maxf(PLAYER_ROLL_DURATION - elapsed, 0.0))
	# Movement continues at quarter speed during the penultimate frame hold.
	if player_roll_frame >= player_roll_frames.size() - 2:
		step_time *= 0.25
	_try_move_actor_swept(player, player_roll_velocity * step_time, 0.75)
	player_roll_timer += delta
	var current_frame_time := PLAYER_ROLL_FRAME_TIME
	# Hold the penultimate frame for two additional animation frames.
	if player_roll_frame == player_roll_frames.size() - 2:
		current_frame_time *= 3.0
	if player_roll_timer >= current_frame_time:
		player_roll_timer = fmod(player_roll_timer, current_frame_time)
		player_roll_frame += 1
		if player_roll_frame >= player_roll_frames.size():
			player_is_rolling = false
			player_roll_frame = 0
			player_roll_timer = 0.0
			player_roll_velocity = Vector2.ZERO
			player_anim_name = "idle"
			_apply_player_animation_frame()
			return
		_apply_player_animation_frame()


func _start_player_attack() -> void:
	if player_attack_frames.is_empty():
		return

	player_is_attacking = true
	player_attack_hit_done = false
	player_attack_hit_targets.clear()
	player_attack_flip_h = player.flip_h
	player_attack_lunge_timer = PLAYER_ATTACK_LUNGE_DURATION
	player_attack_lunge_velocity = _perspective_movement(_player_facing_vector() * (PLAYER_ATTACK_LUNGE_DISTANCE / PLAYER_ATTACK_LUNGE_DURATION))
	player_anim_name = "attack1"
	player_anim_frame = 0
	player_anim_timer = 0.0
	player.visible = false
	player_attack_visual.visible = true
	_apply_player_animation_frame()


func _update_player_attack_lunge(delta: float) -> void:
	if player_attack_lunge_timer <= 0.0:
		return

	var step_time := minf(delta, player_attack_lunge_timer)
	player_attack_lunge_timer = maxf(player_attack_lunge_timer - delta, 0.0)
	_try_move_player_attack_lunge(player_attack_lunge_velocity * step_time)


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
	if player_hit_knockback_timer <= 0.0:
		return

	var step_time := minf(delta, player_hit_knockback_timer)
	player_hit_knockback_timer = maxf(player_hit_knockback_timer - delta, 0.0)
	_try_move_actor_swept(player, player_hit_knockback_velocity * step_time, 0.75)
	if player_hit_knockback_timer <= 0.0:
		player_hit_knockback_velocity = Vector2.ZERO


func _player_facing_vector() -> Vector2:
	if player_is_attacking:
		return Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT
	return Vector2.LEFT if player.flip_h else Vector2.RIGHT


func _update_player_animation(delta: float) -> void:
	if player_is_attacking or player_is_rolling:
		if player_is_rolling:
			_apply_player_animation_frame()
			return
		_update_player_attack_animation(delta)
		return

	var next_anim := "walk" if player_is_moving else "idle"
	if player_anim_name != next_anim:
		player_anim_name = next_anim
		player_anim_frame = 0
		player_anim_timer = 0.0
		_apply_player_animation_frame()
		return

	var frame_time := PLAYER_WALK_FRAME_TIME if player_anim_name == "walk" else PLAYER_IDLE_FRAME_TIME
	player_anim_timer += delta
	if player_anim_timer < frame_time:
		return

	player_anim_timer = fmod(player_anim_timer, frame_time)
	var frames := player_walk_frames if player_anim_name == "walk" else player_idle_frames
	if frames.is_empty():
		return

	player_anim_frame = (player_anim_frame + 1) % frames.size()
	_apply_player_animation_frame()


func _update_player_attack_animation(delta: float) -> void:
	player_anim_timer += delta
	if player_anim_timer < PLAYER_ATTACK_FRAME_TIME:
		return

	player_anim_timer = fmod(player_anim_timer, PLAYER_ATTACK_FRAME_TIME)
	player_anim_frame += 1

	if player_anim_frame >= player_attack_frames.size():
		player_is_attacking = false
		player_attack_hit_done = false
		player_attack_hit_targets.clear()
		player.visible = true
		player_attack_visual.visible = false
		player_anim_name = "walk" if player_is_moving else "idle"
		player_anim_frame = 0
		player_anim_timer = 0.0
		_apply_player_animation_frame()
		return

	_apply_player_animation_frame()
	if player_anim_frame == PLAYER_ATTACK_HIT_FRAME and not player_attack_hit_done:
		_apply_player_attack_hitbox()
		player_attack_hit_done = true


func _apply_player_animation_frame() -> void:
	var frames := player_roll_frames if player_is_rolling else player_attack_frames if player_anim_name == "attack1" else player_walk_frames if player_anim_name == "walk" else player_idle_frames
	if frames.is_empty():
		return
	if player_is_rolling:
		_set_actor_base_texture(player, frames[player_roll_frame])
		return
	if player_anim_name == "attack1":
		var attack_frames := player_attack_left_frames if player_attack_flip_h else player_attack_frames
		if attack_frames.is_empty():
			return
		player_attack_visual.texture = attack_frames[player_anim_frame]
		_update_player_attack_visual()
		return

	player.offset = PLAYER_TEXTURE_OFFSET
	_set_actor_base_texture(player, frames[player_anim_frame])


func _update_player_attack_visual() -> void:
	if not player_is_attacking:
		player_attack_visual.visible = false
		return

	player_attack_visual.visible = true
	player_attack_visual.flip_h = false
	player_attack_visual.global_position = player.global_position + PLAYER_TEXTURE_OFFSET
	player_attack_visual.global_scale = Vector2.ONE
	player_attack_visual.z_index = player.z_index


func _apply_player_attack_hitbox() -> void:
	var hitbox := _player_attack_hitbox()
	var hit_targets: Array[Sprite2D] = []
	for slime in slimes:
		if _is_slime_dead(slime):
			continue
		if player_attack_hit_targets.has(slime):
			continue
		if not hitbox.intersects(_collision_rect(slime), false):
			continue
		hit_targets.append(slime)

	var target_count := hit_targets.size()
	if target_count == 0:
		return
	for slime in hit_targets:
		player_attack_hit_targets.append(slime)
		var divided_damage := floorf(_player_attack_damage_against(slime) / float(target_count))
		_damage_slime(slime, maxf(divided_damage, 1.0))
		_knockback_slime(slime)


func _player_attack_hitbox() -> Rect2:
	var guide_name := "SwordHitboxLeft" if player_attack_flip_h else "SwordHitboxRight"
	var guide_rect := _collision_guide_rect_by_name(player, guide_name)
	if guide_rect.has_area():
		return guide_rect

	var offset := PLAYER_ATTACK_HITBOX_LEFT_OFFSET if player_attack_flip_h else PLAYER_ATTACK_HITBOX_RIGHT_OFFSET
	return Rect2(player.global_position + offset, PLAYER_ATTACK_HITBOX_SIZE)


func _damage_slime(slime: Sprite2D, amount: float) -> void:
	if _is_slime_dead(slime):
		return

	_mark_player_in_combat()
	var previous_health := float(target_health.get(slime, _enemy_max_health(slime)))
	slime_persistent_aggro[slime] = true
	target_health[slime] = maxf(previous_health - amount, 0.0)
	target_display_health[slime] = maxf(float(target_display_health.get(slime, previous_health)), previous_health)
	target_damage_fill_hold_timers[slime] = ENEMY_HEALTH_DAMAGE_HANG_TIME
	target_regen_delay_timers[slime] = ENEMY_REGEN_DELAY
	target_regen_accumulators[slime] = 0.0
	slime_flash_timers[slime] = ENEMY_HIT_FLASH_TIME
	slime_hitstun_timers[slime] = ENEMY_HITSTUN_TIME
	_spawn_damage_number(slime, amount)
	hitstop_timer = HITSTOP_DURATION
	if float(target_health[slime]) <= 0.0:
		_kill_slime(slime)


func _player_attack_damage_against(slime: Sprite2D) -> float:
	var slime_stats := actor_stats.get(slime) as StatsComponent
	return _combat_damage(player_stats, slime_stats)


func _combat_damage(attacker_stats: StatsComponent, defender_stats: StatsComponent) -> float:
	if attacker_stats == null:
		return 1.0
	var attacker_str := float(attacker_stats.strength)
	var defender_def := float(defender_stats.def) if defender_stats != null else 0.0
	var attacker_equipment_damage := player_equipment.damage_bonus if attacker_stats == player_stats and player_equipment != null else 0.0
	var defender_equipment_defense := player_equipment.defense_bonus if defender_stats == player_stats and player_equipment != null else 0.0
	var raw_damage := DAMAGE_BASE + attacker_str + attacker_equipment_damage
	defender_def += defender_equipment_defense
	# Diminishing returns keep DEF useful without letting it erase damage.
	# At DEF equal to DAMAGE_DEFENSE_SCALE, the defender takes half damage;
	# every point beyond that has progressively less impact.
	var defense_multiplier := DAMAGE_DEFENSE_SCALE / (DAMAGE_DEFENSE_SCALE + maxf(defender_def, 0.0))
	return maxf(1.0, raw_damage * defense_multiplier)


func _max_health_for_stats(stats: StatsComponent) -> float:
	if stats == null:
		return TARGET_HEALTH_MAX
	var equipment_health := player_equipment.health_bonus if stats == player_stats and player_equipment != null else 0.0
	return HEALTH_BASE + float(stats.vit) * HEALTH_PER_VIT + equipment_health


func _player_max_health() -> float:
	return _max_health_for_stats(player_stats)


func _enemy_max_health(slime: Sprite2D) -> float:
	return _max_health_for_stats(actor_stats.get(slime) as StatsComponent)


func _enemy_level_for_room() -> int:
	return maxi(1, room_number)


func _apply_enemy_room_level(slime: Sprite2D) -> void:
	var stats := actor_stats.get(slime) as StatsComponent
	if stats == null:
		return
	stats.level = _enemy_level_for_room()


func _knockback_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime):
		return

	var direction := _actor_foot(slime) - _actor_foot(player)
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT

	slime_knockback_velocities[slime] = _perspective_movement(direction.normalized() * (PLAYER_ATTACK_KNOCKBACK / ENEMY_KNOCKBACK_DURATION))
	slime_knockback_timers[slime] = ENEMY_KNOCKBACK_DURATION
	slime_scoot_starts[slime] = slime.position
	slime_scoot_targets[slime] = slime.position
	slime_scoot_timers[slime] = 0.0
	slime_hold_timers[slime] = ENEMY_HITSTUN_TIME


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
	return bool(dead_slimes.get(slime, false))


func _are_all_slimes_dead() -> bool:
	for slime in slimes:
		if not _is_slime_dead(slime):
			return false
	return true


func _unlock_chest() -> void:
	if chest_unlocked:
		return

	chest_unlocked = true
	if chest_normal_texture != null:
		_start_chest_unlock_fade()


func _build_interact_prompt() -> void:
	interact_prompt = Sprite2D.new()
	interact_prompt.name = "InteractPrompt"
	interact_prompt.texture = _pixel_number_texture("!", Color8(255, 205, 117))
	interact_prompt.scale = Vector2(2.0, 2.0)
	interact_prompt.centered = false
	interact_prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	interact_prompt.z_as_relative = false
	interact_prompt.z_index = OVERWORLD_UI_Z + 1
	interact_prompt.visible = false
	interact_prompt_base_position = Vector2(5, -10)
	add_child(interact_prompt)


func _build_room_number_indicator() -> void:
	room_number_indicator = Sprite2D.new()
	room_number_indicator.name = "RoomNumber"
	room_number_indicator.centered = false
	room_number_indicator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room_number_indicator.z_index = 2
	room_number_indicator.position = Vector2(208, 4)
	ui.add_child(room_number_indicator)
	_update_room_number_indicator()


func _build_gold_indicator() -> void:
	gold_indicator = Sprite2D.new()
	gold_indicator.name = "GoldIndicator"
	gold_indicator.centered = false
	gold_indicator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gold_indicator.z_index = 2
	gold_indicator.position = Vector2(72, 4)
	ui.add_child(gold_indicator)
	_update_gold_indicator()


func _update_gold_indicator() -> void:
	if gold_indicator != null:
		gold_indicator.texture = _pixel_number_texture("G%d" % gold, Color8(255, 205, 117))


func _build_target_health_text() -> void:
	target_health_text = Sprite2D.new()
	target_health_text.name = "TargetHealthText"
	target_health_text.centered = true
	target_health_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target_health_text.z_index = 3
	target_health_text.position = target_health_bar.position + target_health_bar.texture.get_size() * 0.5
	target_health_text.visible = false
	ui.add_child(target_health_text)


	player_health_text = Sprite2D.new()
	player_health_text.name = "PlayerHealthText"
	player_health_text.centered = true
	player_health_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_health_text.z_index = 3
	player_health_text.position = player_health_fill.position + player_health_fill.texture.get_size() * 0.5 + Vector2(0, -1)
	ui.add_child(player_health_text)


func _update_room_number_indicator() -> void:
	if room_number_indicator == null:
		return
	room_number_indicator.texture = _pixel_number_texture("R%d" % room_number, Color8(244, 244, 244))


func _set_entrance_open(is_open: bool) -> void:
	entrance_open = is_open
	if entrance_tile_a != null:
		entrance_tile_a.visible = is_open
	if entrance_tile_b != null:
		entrance_tile_b.visible = is_open


func _start_chest_unlock_fade() -> void:
	if chest_unlock_overlay != null:
		chest_unlock_overlay.queue_free()

	chest.texture = chest_gray_texture
	chest.visible = true
	chest_unlock_fade_timer = CHEST_UNLOCK_FADE_TIME
	chest_unlock_overlay = Sprite2D.new()
	chest_unlock_overlay.name = "ChestUnlockOverlay"
	chest_unlock_overlay.texture = chest_normal_texture
	chest_unlock_overlay.centered = chest.centered
	chest_unlock_overlay.offset = chest.offset
	chest_unlock_overlay.scale = chest.scale
	chest_unlock_overlay.texture_filter = chest.texture_filter
	chest_unlock_overlay.z_as_relative = false
	chest_unlock_overlay.z_index = chest.z_index + 1
	chest_unlock_overlay.global_position = chest.global_position
	chest_unlock_overlay.modulate = Color(1, 1, 1, 0)
	add_child(chest_unlock_overlay)


func _update_chest_unlock_fade(delta: float) -> void:
	if chest_unlock_overlay == null:
		return

	chest_unlock_fade_timer = maxf(chest_unlock_fade_timer - delta, 0.0)
	chest_unlock_overlay.global_position = chest.global_position
	chest_unlock_overlay.z_index = chest.z_index + 1
	chest_unlock_overlay.modulate = Color(1, 1, 1, 1.0 - chest_unlock_fade_timer / CHEST_UNLOCK_FADE_TIME)
	if chest_unlock_fade_timer <= 0.0:
		chest.texture = chest_normal_texture
		sprite_images[chest] = _cached_texture_image(chest_normal_texture)
		chest_unlock_overlay.queue_free()
		chest_unlock_overlay = null


func _update_chest_interaction() -> void:
	var interact_input_down := _is_interact_input_pressed()
	if interact_input_down and not interact_input_was_down and chest_unlocked and not chest_claimed:
		if _can_interact_with_chest():
			chest_claimed = true
			room_states[room_number] = {"finished": true}
			chest_collect_flash_timer = CHEST_COLLECT_FLASH_TIME
			_start_chest_flash()
			gold += CHEST_REWARD_GOLD
			_update_gold_indicator()
			_spawn_gold_number(chest.global_position + Vector2(5, -8), CHEST_REWARD_GOLD)
			print("Gold: %d" % gold)
	interact_input_was_down = interact_input_down


func _update_chest_visuals(delta: float) -> void:
	_update_interact_prompt(delta)
	_update_chest_unlock_fade(delta)
	if chest_collect_flash_timer > 0.0:
		chest_collect_flash_timer = maxf(chest_collect_flash_timer - delta, 0.0)
		if chest_flash_overlay != null:
			chest_flash_overlay.global_position = chest.global_position
			chest_flash_overlay.z_index = chest.z_index + 1
			chest_flash_overlay.modulate = Color(1, 1, 1, 1.0 - chest_collect_flash_timer / CHEST_COLLECT_FLASH_TIME)
		if chest_collect_flash_timer <= 0.0 and not chest_evaporated:
			_start_chest_evaporation()
	elif not chest_claimed:
		chest.self_modulate = Color.WHITE


func _can_interact_with_chest() -> bool:
	return chest_unlocked and not chest_claimed and _actor_foot(player).distance_to(_collision_rect(chest).get_center()) <= CHEST_INTERACT_DISTANCE


func _update_interact_prompt(delta: float) -> void:
	if interact_prompt == null:
		return

	var should_show := _can_interact_with_chest()
	interact_prompt.visible = should_show
	if not should_show:
		return

	interact_prompt_timer = fmod(interact_prompt_timer + delta, INTERACT_PROMPT_BOB_TIME)
	var bob := sin((interact_prompt_timer / INTERACT_PROMPT_BOB_TIME) * TAU) * 1.0
	interact_prompt.global_position = chest.global_position + interact_prompt_base_position + Vector2(0, bob)
	interact_prompt.z_index = OVERWORLD_UI_Z + 1


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
	door.visible = is_active


func _update_door_transition() -> void:
	_try_enter_active_door()
	_try_enter_active_entrance()


func _try_enter_active_door() -> bool:
	if not door_active:
		return false
	var player_feet := _player_door_feet_rect()
	var trigger_polygon := _door_trigger_polygon()
	if trigger_polygon.size() >= 3:
		if _rect_touches_polygon(player_feet, trigger_polygon):
			_enter_fresh_room(1)
			return true
		return false

	var trigger := _door_trigger_rect()
	if trigger.intersects(player_feet, false):
		_enter_fresh_room(1)
		return true
	return false


func _try_enter_active_entrance() -> bool:
	if not entrance_open or room_number <= 1:
		return false

	var player_feet := _player_door_feet_rect()
	var trigger_polygon := _entrance_return_polygon()
	if trigger_polygon.size() >= 3 and _rect_touches_polygon(player_feet, trigger_polygon):
		_enter_fresh_room(-1)
		return true
	if trigger_polygon.size() < 3:
		for polygon in entrance_block_polygons:
			if _rect_touches_polygon(player_feet, polygon):
				_enter_fresh_room(-1)
				return true
	return false


func _door_trigger_rect() -> Rect2:
	return Rect2(door.global_position + Vector2(-18, 4), Vector2(38, 28))


func _door_trigger_polygon() -> PackedVector2Array:
	var guide := door.get_node_or_null("DoorExitGuide") as Polygon2D
	if guide == null or guide.polygon.size() < 3:
		return PackedVector2Array()

	return _guide_polygon_global(guide)


func _entrance_return_polygon() -> PackedVector2Array:
	if entrance_tile_a == null:
		return PackedVector2Array()

	var guide := entrance_tile_a.get_node_or_null("EntranceReturnGuide") as Polygon2D
	if guide == null or guide.polygon.size() < 3:
		return PackedVector2Array()

	return _guide_polygon_global(guide)


func _guide_polygon_global(guide: Polygon2D) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in guide.polygon:
		polygon.append(guide.to_global(point))
	return polygon


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()

	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()):
		bounds = bounds.expand(polygon[index])
	return bounds


func _player_door_feet_rect() -> Rect2:
	var guide_rect := _collision_guide_rect_by_name(player, "DoorFeetGuide")
	if guide_rect.has_area():
		return guide_rect

	var foot := _actor_foot(player)
	return Rect2(foot - PLAYER_DOOR_FOOT_COLLIDER_SIZE * 0.5, PLAYER_DOOR_FOOT_COLLIDER_SIZE)


func _rect_touches_polygon(rect: Rect2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	if not _polygon_bounds(polygon).intersects(rect, false):
		return false

	if Geometry2D.is_point_in_polygon(rect.get_center(), polygon):
		return true

	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	for corner in corners:
		if Geometry2D.is_point_in_polygon(corner, polygon):
			return true
	for point in polygon:
		if rect.has_point(point):
			return true
	return false


func _enter_fresh_room(direction: int) -> void:
	_save_current_room_state()
	room_number = maxi(1, room_number + direction)
	_update_room_number_indicator()
	player.position = _room_entry_position(direction)
	player.flip_h = false
	player_is_attacking = false
	player_attack_visual.visible = false
	current_target = null
	_set_target_ui_visible(false)
	_apply_room_state()
	_build_depth_lists()


func _room_entry_position(direction: int) -> Vector2:
	if direction > 0:
		return _entrance_spawn_position()
	return _exit_spawn_position()


func _entrance_spawn_position() -> Vector2:
	if entrance_tile_b == null:
		return player_start_position
	var tile_center := entrance_tile_b.to_global(Vector2(8, 4))
	return tile_center + Vector2(12, -10) - ACTOR_FOOT_OFFSET


func _exit_spawn_position() -> Vector2:
	var trigger_bounds := _polygon_bounds(_door_trigger_polygon())
	if trigger_bounds.has_area():
		return trigger_bounds.get_center() + Vector2(-16, 8) - ACTOR_FOOT_OFFSET
	return door.global_position + Vector2(-8, 20) - ACTOR_FOOT_OFFSET


func _save_current_room_state() -> void:
	room_states[room_number] = {
		"finished": chest_claimed,
	}


func _apply_room_state() -> void:
	var state := room_states.get(room_number, {}) as Dictionary
	if bool(state.get("finished", false)):
		_apply_finished_room_state()
	else:
		_reset_chest_for_room()
		_reset_slimes_for_room()


func _apply_finished_room_state() -> void:
	_reset_slimes_for_room()
	for slime in slimes:
		_kill_slime_without_effects(slime)

	chest.visible = false
	chest_unlocked = true
	chest_claimed = true
	chest_evaporated = true
	chest_collect_flash_timer = 0.0
	chest_unlock_fade_timer = 0.0
	_set_door_active(true)
	_set_entrance_open(true)
	collision_sprites.erase(chest)
	depth_sprites.erase(chest)
	occluder_sprites.erase(chest)
	if chest_unlock_overlay != null:
		chest_unlock_overlay.queue_free()
		chest_unlock_overlay = null
	if chest_flash_overlay != null:
		chest_flash_overlay.queue_free()
		chest_flash_overlay = null
	if interact_prompt != null:
		interact_prompt.visible = false


func _kill_slime_without_effects(slime: Sprite2D) -> void:
	dead_slimes[slime] = true
	slime.visible = false
	slime_attack_timers[slime] = 0.0
	slime_attack_frame_indices[slime] = 0
	slime_attack_hit_done[slime] = false
	collision_sprites.erase(slime)
	depth_sprites.erase(slime)
	occluder_sprites.erase(slime)
	actor_sprites.erase(slime)
	target_health[slime] = 0.0
	target_display_health[slime] = 0.0
	var frame := target_overhead_frames.get(slime) as Sprite2D
	var damage_fill := target_overhead_damage_fills.get(slime) as Sprite2D
	var fill := target_overhead_fills.get(slime) as Sprite2D
	if frame != null:
		frame.visible = false
	if damage_fill != null:
		damage_fill.visible = false
	if fill != null:
		fill.visible = false


func _reset_chest_for_room() -> void:
	chest.position = chest_start_position
	chest.texture = chest_gray_texture
	chest.visible = true
	chest.self_modulate = Color.WHITE
	chest_unlocked = false
	chest_claimed = false
	chest_evaporated = false
	chest_collect_flash_timer = 0.0
	chest_unlock_fade_timer = 0.0
	_set_door_active(false)
	_set_entrance_open(false)
	if chest_unlock_overlay != null:
		chest_unlock_overlay.queue_free()
		chest_unlock_overlay = null
	if chest_flash_overlay != null:
		chest_flash_overlay.queue_free()
		chest_flash_overlay = null
	if not collision_sprites.has(chest):
		collision_sprites.append(chest)
	sprite_images[chest] = _cached_texture_image(chest_gray_texture)


func _reset_slimes_for_room() -> void:
	for slime in slimes:
		slime.position = slime_start_positions.get(slime, slime.position) as Vector2
		slime.visible = true
		slime.flip_h = false
		dead_slimes[slime] = false
		_apply_enemy_room_level(slime)
		var max_health := _enemy_max_health(slime)
		target_health[slime] = max_health
		target_display_health[slime] = max_health
		target_damage_fill_hold_timers[slime] = 0.0
		target_regen_delay_timers[slime] = 0.0
		target_regen_accumulators[slime] = 0.0
		slime_flash_timers[slime] = 0.0
		slime_hitstun_timers[slime] = 0.0
		slime_knockback_velocities[slime] = Vector2.ZERO
		slime_knockback_timers[slime] = 0.0
		slime_attack_timers[slime] = 0.0
		slime_attack_frame_indices[slime] = 0
		slime_attack_hit_done[slime] = false
		slime_attack_cooldowns[slime] = rng.randf_range(0.2, 0.6)
		slime_scoot_starts[slime] = slime.position
		slime_scoot_targets[slime] = slime.position
		slime_scoot_timers[slime] = 0.0
		slime_hold_timers[slime] = rng.randf_range(SLIME_HOLD_MIN, SLIME_HOLD_MAX)
		slime_repath_timers[slime] = rng.randf_range(SLIME_REPATH_MIN, SLIME_REPATH_MAX)
		_set_actor_base_texture(slime, actor_default_textures[slime])
		_set_actor_visual_scale(slime, Vector2.ONE)
		if not actor_sprites.has(slime):
			actor_sprites.append(slime)
		if not collision_sprites.has(slime):
			collision_sprites.append(slime)


func _start_chest_flash() -> void:
	if chest_flash_overlay != null:
		chest_flash_overlay.queue_free()

	chest_flash_overlay = Sprite2D.new()
	chest_flash_overlay.name = "ChestFlashOverlay"
	chest_flash_overlay.texture = _white_texture(chest.texture)
	chest_flash_overlay.centered = chest.centered
	chest_flash_overlay.offset = chest.offset
	chest_flash_overlay.scale = chest.scale
	chest_flash_overlay.texture_filter = chest.texture_filter
	chest_flash_overlay.z_as_relative = false
	chest_flash_overlay.z_index = chest.z_index + 1
	chest_flash_overlay.global_position = chest.global_position
	chest_flash_overlay.modulate = Color(1, 1, 1, 0)
	add_child(chest_flash_overlay)


func _spawn_slime_death_pixels(slime: Sprite2D) -> void:
	# Death particles always use the stable base sprite, never an attack frame.
	var texture := actor_default_textures.get(slime) as Texture2D
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return

	var source_pixels: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				source_pixels.append(Vector2i(x, y))
	source_pixels.shuffle()

	var particle_count := mini(SLIME_DEATH_PARTICLE_COUNT, source_pixels.size())
	for index in particle_count:
		var source_pixel := source_pixels[index]
		var color := image.get_pixelv(source_pixel)
		var particle := Sprite2D.new()
		particle.texture = _pixel_particle_texture(color)
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = int(round(_actor_foot(slime).y * DEPTH_Z_SCALE)) + 1
		# Sprite2D is not centered, so source pixels map 1:1 to world pixels.
		particle.position = slime.global_position + Vector2(source_pixel) + Vector2(0, -2)
		add_child(particle)

		var horizontal_direction := -1.0 if float(source_pixel.x) < float(image.get_width()) * 0.5 else 1.0
		var horizontal_speed := rng.randf_range(SLIME_DEATH_PARTICLE_SPEED_MIN * 0.5, SLIME_DEATH_PARTICLE_SPEED_MAX * 0.75)
		pixel_particles.append({
			"sprite": particle,
			"velocity": Vector2(horizontal_direction * horizontal_speed, rng.randf_range(-10.0, -2.0)),
			"timer": SLIME_DEATH_PARTICLE_LIFETIME,
			"gravity": 30.0,
		})


func _spawn_gold_number(world_position: Vector2, amount: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _pixel_number_texture("+%d" % amount, Color8(255, 205, 117))
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.z_index = OVERWORLD_UI_Z + 2
	sprite.position = world_position
	add_child(sprite)
	damage_numbers.append({
		"sprite": sprite,
		"timer": DAMAGE_NUMBER_LIFETIME,
	})


func _spawn_chest_evaporation_pixels() -> void:
	var texture: Texture2D = chest.texture
	if texture == null:
		return
	var image: Image = texture.get_image()
	if image == null:
		return

	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.45
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	var candidates: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var sample := noise.get_noise_2d(float(x), float(y))
			if sample > -0.18:
				candidates.append(Vector2i(x, y))

	candidates.shuffle()
	var count := mini(CHEST_EVAPORATE_PARTICLE_COUNT, candidates.size())
	for index in count:
		var source_pixel := candidates[index]
		var particle := Sprite2D.new()
		particle.texture = _pixel_particle_texture(Color.WHITE)
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = int(round(_depth_key(chest) * DEPTH_Z_SCALE)) + 1
		particle.position = chest.global_position + Vector2(source_pixel)
		add_child(particle)

		var lifetime := rng.randf_range(CHEST_EVAPORATE_LIFETIME_MIN, CHEST_EVAPORATE_LIFETIME_MAX)
		# Keep chest fizzle columns vertically aligned with the source sprite.
		var drift := Vector2(0.0, rng.randf_range(-24.0, -12.0))
		pixel_particles.append({
			"sprite": particle,
			"velocity": drift,
			"timer": lifetime,
			"lifetime": lifetime,
			"gravity": 0.0,
		})


func _update_pixel_particles(delta: float) -> void:
	for index in range(pixel_particles.size() - 1, -1, -1):
		var particle_data := pixel_particles[index]
		var particle := particle_data["sprite"] as Sprite2D
		var timer := float(particle_data["timer"]) - delta
		if particle == null or timer <= 0.0:
			if particle != null:
				particle.queue_free()
			pixel_particles.remove_at(index)
			continue

		var velocity := particle_data["velocity"] as Vector2
		velocity.y += float(particle_data.get("gravity", 18.0)) * delta
		particle.position += velocity * delta
		var color := particle.modulate
		var lifetime := float(particle_data.get("lifetime", SLIME_DEATH_PARTICLE_LIFETIME))
		color.a = clampf(timer / lifetime, 0.0, 1.0)
		particle.modulate = color
		particle_data["velocity"] = velocity
		particle_data["timer"] = timer


func _pixel_particle_texture(color: Color, size: int = 1) -> Texture2D:
	var key := "%s:%d" % [_rgb_key(color), size]
	if pixel_particle_texture_cache.has(key):
		return pixel_particle_texture_cache[key]

	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	pixel_particle_texture_cache[key] = texture
	return texture


func _white_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var key := "%s:white_texture" % source.resource_path
	if white_image_cache.has(key):
		return white_image_cache[key]

	var image := _cached_texture_image(source).duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, color.a))
	var texture := ImageTexture.create_from_image(image)
	white_image_cache[key] = texture
	return texture


func _slime_base_color(slime: Sprite2D) -> Color:
	if slime == slime_blue:
		return Color8(59, 93, 201)
	if slime == slime_green:
		return Color8(56, 183, 100)
	if slime == slime_red:
		return Color8(177, 62, 83)
	return Color.WHITE


func _try_knockback_slime(slime: Sprite2D, movement: Vector2) -> void:
	_try_move_actor_swept(slime, movement, 1.0)
	_separate_slime_from_player(slime)


func _separate_slime_from_player(slime: Sprite2D) -> void:
	var overlap_push := _overlap_push_vector(slime, player)
	if overlap_push == Vector2.ZERO:
		return

	_try_move_actor_swept(slime, overlap_push, 0.75)


func _move_slimes(delta: float) -> void:
	for slime in slimes:
		if _is_slime_dead(slime):
			continue
		slime_attack_cooldowns[slime] = maxf(float(slime_attack_cooldowns.get(slime, 0.0)) - delta, 0.0)
		if _update_slime_knockback(slime, delta):
			continue

		slime_hitstun_timers[slime] = maxf(float(slime_hitstun_timers.get(slime, 0.0)) - delta, 0.0)
		if float(slime_hitstun_timers[slime]) > 0.0:
			continue
		if _update_slime_attack(slime, delta):
			continue
		if _is_slime_aggroed(slime):
			slime_targets[slime] = _aggro_slime_target(slime)
			_update_slime_scoot(slime, delta)
			continue
		slime_repath_timers[slime] = float(slime_repath_timers[slime]) - delta
		_update_slime_scoot(slime, delta)


func _update_slime_attack(slime: Sprite2D, delta: float) -> bool:
	if player_dead:
		slime_attack_timers[slime] = 0.0
		return false
	var timer := float(slime_attack_timers.get(slime, 0.0))
	if timer > 0.0:
		timer += delta
		var frames := _slime_attack_frames(slime)
		if frames.is_empty():
			slime_attack_timers[slime] = 0.0
			return false

		var frame_index := mini(int(floor(timer / SLIME_ATTACK_FRAME_TIME)), frames.size() - 1)
		slime_attack_timers[slime] = timer
		slime_attack_frame_indices[slime] = frame_index
		_set_actor_base_texture(slime, frames[frame_index])
		if frame_index == SLIME_ATTACK_HIT_FRAME and not bool(slime_attack_hit_done.get(slime, false)):
			_apply_slime_attack_lunge(slime)
			_apply_slime_attack_hit(slime)
			slime_attack_hit_done[slime] = true
		if timer >= SLIME_ATTACK_FRAME_TIME * float(frames.size()):
			slime_attack_timers[slime] = 0.0
			slime_attack_frame_indices[slime] = 0
			slime_attack_hit_done[slime] = false
			slime_attack_cooldowns[slime] = SLIME_ATTACK_COOLDOWN
			_restore_slime_idle_texture(slime)
		return true

	if float(slime_attack_cooldowns.get(slime, 0.0)) > 0.0:
		return false
	if not _can_slime_attack_player(slime):
		return false

	_start_slime_attack(slime)
	return true


func _start_slime_attack(slime: Sprite2D) -> void:
	var direction := _actor_foot(player) - _actor_foot(slime)
	var face_left := direction.x < 0.0
	slime_attack_face_left[slime] = face_left
	_set_slime_facing(slime, -1.0 if face_left else 1.0)
	slime_attack_timers[slime] = 0.001
	slime_attack_frame_indices[slime] = 0
	slime_attack_hit_done[slime] = false
	var frames := _slime_attack_frames(slime)
	if not frames.is_empty():
		_set_actor_base_texture(slime, frames[0])
	slime_scoot_timers[slime] = 0.0
	slime_scoot_starts[slime] = slime.position
	slime_scoot_targets[slime] = slime.position
	_set_actor_visual_scale(slime, Vector2.ONE)


func _slime_attack_frames(slime: Sprite2D) -> Array[Texture2D]:
	return slime_attack_left_frames.get(slime, []) if bool(slime_attack_face_left.get(slime, false)) else slime_attack_right_frames.get(slime, [])


func _restore_slime_idle_texture(slime: Sprite2D) -> void:
	_set_slime_facing(slime, -1.0 if bool(slime_attack_face_left.get(slime, false)) else 1.0)


func _can_slime_attack_player(slime: Sprite2D) -> bool:
	if player_dead:
		return false
	var to_player := _actor_foot(player) - _actor_foot(slime)
	if to_player.length() > SLIME_ATTACK_RANGE:
		return false
	return true


func _is_slime_aggroed(slime: Sprite2D) -> bool:
	if _is_slime_dead(slime) or player_dead:
		return false
	return bool(slime_persistent_aggro.get(slime, false)) or _actor_foot(slime).distance_to(_actor_foot(player)) <= SLIME_AGGRO_RANGE


func _is_any_slime_aggroed() -> bool:
	for slime in slimes:
		if _is_slime_aggroed(slime):
			return true
	return false


func _aggro_slime_target(slime: Sprite2D) -> Vector2:
	var slime_foot := _actor_foot(slime)
	var player_foot := _actor_foot(player)
	var approach := slime_foot - player_foot
	if approach.length_squared() < 0.01:
		approach = Vector2.RIGHT
	var desired := player_foot + approach.normalized() * (SLIME_ATTACK_RANGE * 0.72)
	var buddy_avoidance := Vector2.ZERO
	for buddy in slimes:
		if buddy == slime or _is_slime_dead(buddy):
			continue
		var buddy_delta := slime_foot - _actor_foot(buddy)
		var buddy_distance := buddy_delta.length()
		var clear_distance := _actor_contact_radius(slime) + _actor_contact_radius(buddy) + 4.0
		if buddy_distance > 0.01 and buddy_distance < clear_distance:
			buddy_avoidance += buddy_delta.normalized() * (clear_distance - buddy_distance) / clear_distance
	if buddy_avoidance.length_squared() > 0.001:
		desired += buddy_avoidance.normalized() * 7.0
	return _nearest_slime_walkable_point(desired)


func _move_slime_toward_player(slime: Sprite2D, delta: float) -> void:
	var scoot_timer := float(slime_scoot_timers.get(slime, 0.0))
	if scoot_timer > 0.0:
		slime_scoot_timers[slime] = maxf(scoot_timer - delta, 0.0)
		_set_slime_squish(slime, 1.0 - (scoot_timer / SLIME_SCOOT_DURATION), slime_scoot_targets.get(slime, Vector2.ZERO) as Vector2)
		return

	var offset := _actor_foot(player) - _actor_foot(slime)
	var distance := offset.length()
	if distance <= SLIME_ATTACK_RANGE:
		slime_scoot_timers[slime] = 0.0
		slime_hold_timers[slime] = 0.0
		_set_actor_visual_scale(slime, Vector2.ONE)
		return

	var direction := offset / distance
	var buddy_avoidance := Vector2.ZERO
	for buddy in slimes:
		if buddy == slime or _is_slime_dead(buddy):
			continue
		var buddy_delta := _actor_foot(slime) - _actor_foot(buddy)
		var buddy_distance := buddy_delta.length()
		var clear_distance := _actor_contact_radius(slime) + _actor_contact_radius(buddy) + 3.0
		if buddy_distance > 0.01 and buddy_distance < clear_distance:
			buddy_avoidance += buddy_delta.normalized() * (clear_distance - buddy_distance) / clear_distance
	if buddy_avoidance.length_squared() > 0.001:
		direction = (direction + buddy_avoidance * 1.35).normalized()
	_set_slime_facing(slime, direction.x)
	var step_distance := minf(SLIME_SCOOT_DISTANCE, maxf(distance - SLIME_ATTACK_RANGE, 0.0))
	var movement := _perspective_movement(direction * step_distance)
	_try_move_actor(slime, movement)
	slime_scoot_targets[slime] = movement
	slime_scoot_timers[slime] = SLIME_SCOOT_DURATION
	_set_slime_squish(slime, 0.0, movement)


func _apply_slime_attack_hit(slime: Sprite2D) -> void:
	if player_is_rolling:
		return
	# Attack range and damage must use the same coordinate space.  The old
	# AttackGuide was positioned relative to the sprite artwork, which put its
	# coverage above the slime's foot and made attacks miss players above it.
	# Using the stable foot points also keeps squish/attack animation scaling
	# from changing the effective hitbox.
	var attack_delta := _actor_foot(player) - _actor_foot(slime)
	var attack_ellipse := Vector2(
		attack_delta.x / SLIME_ATTACK_HIT_RANGE,
		attack_delta.y / SLIME_ATTACK_VERTICAL_HIT_RANGE
	)
	if attack_ellipse.length_squared() > 1.0:
		return

	var damage := _slime_attack_damage(slime)
	_mark_player_in_combat()
	player_health = maxf(player_health - damage, 0.0)
	player_hit_flash_timer = PLAYER_HIT_FLASH_TIME
	player_hitstun_timer = PLAYER_HITSTUN_TIME
	_apply_player_hit_knockback(slime)
	_spawn_player_damage_number(damage)
	_update_player_health_ui()
	hitstop_timer = HITSTOP_DURATION
	if player_health <= 0.0:
		player_death_pending = true
		player_is_attacking = false
		player_is_rolling = false
		player_attack_visual.visible = false


func _slime_attack_rect(slime: Sprite2D) -> Rect2:
	# Kept as a helper for debug/tools that may still query the attack area.
	var foot := _actor_foot(slime)
	var diameter := SLIME_ATTACK_HIT_RANGE * 2.0
	return Rect2(foot - Vector2.ONE * SLIME_ATTACK_HIT_RANGE, Vector2.ONE * diameter)


func _slime_attack_damage(slime: Sprite2D) -> float:
	var slime_stats := actor_stats.get(slime) as StatsComponent
	return _combat_damage(slime_stats, player_stats)


func _mark_player_in_combat() -> void:
	player_regen_delay_timer = PLAYER_REGEN_DELAY
	player_regen_accumulator = 0.0


func _update_player_health_regen(delta: float) -> void:
	var max_health := _player_max_health()
	if player_health >= max_health:
		player_regen_delay_timer = maxf(player_regen_delay_timer - delta, 0.0)
		player_regen_accumulator = 0.0
		return

	if _is_any_slime_aggroed():
		_mark_player_in_combat()
		return

	player_regen_delay_timer = maxf(player_regen_delay_timer - delta, 0.0)
	if player_regen_delay_timer > 0.0:
		return

	player_regen_accumulator += delta
	while player_regen_accumulator >= PLAYER_REGEN_INTERVAL and player_health < max_health:
		player_health = minf(player_health + PLAYER_REGEN_AMOUNT, max_health)
		player_regen_accumulator -= PLAYER_REGEN_INTERVAL
	_update_player_health_ui()


func _apply_slime_attack_lunge(slime: Sprite2D) -> void:
	var direction := _actor_foot(player) - _actor_foot(slime)
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if bool(slime_attack_face_left.get(slime, false)) else Vector2.RIGHT
	else:
		direction = direction.normalized()
	# Perspective compresses vertical movement, so give the attack lunge a
	# little extra vertical reach while preserving horizontal movement.
	direction.y *= 1.5
	direction = direction.normalized()
	_try_move_actor_swept(slime, _perspective_movement(direction * SLIME_ATTACK_LUNGE_DISTANCE), 0.75)


func _apply_player_hit_knockback(slime: Sprite2D) -> void:
	var direction := _actor_foot(player) - _actor_foot(slime)
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT if player.global_position.x >= slime.global_position.x else Vector2.LEFT
	player_hit_knockback_velocity = _perspective_movement(direction.normalized() * (PLAYER_HIT_KNOCKBACK / PLAYER_HIT_KNOCKBACK_DURATION))
	player_hit_knockback_timer = PLAYER_HIT_KNOCKBACK_DURATION


func _update_slime_knockback(slime: Sprite2D, delta: float) -> bool:
	var timer := float(slime_knockback_timers.get(slime, 0.0))
	if timer <= 0.0:
		return false

	var step_time := minf(delta, timer)
	slime_knockback_timers[slime] = maxf(timer - delta, 0.0)
	_try_knockback_slime(slime, (slime_knockback_velocities[slime] as Vector2) * step_time)
	if float(slime_knockback_timers[slime]) <= 0.0:
		slime_knockback_velocities[slime] = Vector2.ZERO
		slime_scoot_starts[slime] = slime.position
		slime_scoot_targets[slime] = slime.position
	return true


func _update_enemy_hit_flashes(delta: float) -> void:
	for slime in slimes:
		if _is_slime_dead(slime):
			continue
		var timer := maxf(float(slime_flash_timers.get(slime, 0.0)) - delta, 0.0)
		slime_flash_timers[slime] = timer


func _update_enemy_health(delta: float) -> void:
	for slime in slimes:
		if _is_slime_dead(slime):
			continue
		var max_health := _enemy_max_health(slime)
		var health := float(target_health.get(slime, max_health))
		var regen_delay := maxf(float(target_regen_delay_timers.get(slime, 0.0)) - delta, 0.0)
		target_regen_delay_timers[slime] = regen_delay

		if health < max_health and regen_delay <= 0.0:
			var regen_accumulator := float(target_regen_accumulators.get(slime, 0.0)) + delta
			while regen_accumulator >= ENEMY_REGEN_INTERVAL and health < max_health:
				health = minf(health + ENEMY_REGEN_AMOUNT, max_health)
				regen_accumulator -= ENEMY_REGEN_INTERVAL
			target_health[slime] = health
			target_regen_accumulators[slime] = regen_accumulator
		elif health >= max_health:
			target_regen_accumulators[slime] = 0.0

		var display_health := float(target_display_health.get(slime, max_health))
		if not is_equal_approx(display_health, health):
			var display_goal := health
			var fill_speed := ENEMY_HEALTH_REGEN_FILL_SPEED
			if display_health > health:
				var hold_timer := maxf(float(target_damage_fill_hold_timers.get(slime, 0.0)) - delta, 0.0)
				target_damage_fill_hold_timers[slime] = hold_timer
				if hold_timer <= 0.0:
					display_goal = maxf(health, ceilf(display_health) - 1.0)
					fill_speed = ENEMY_HEALTH_DRAIN_FILL_SPEED
					display_health = move_toward(display_health, display_goal, fill_speed * delta)
			else:
				display_goal = minf(health, floorf(display_health) + 1.0)
				display_health = move_toward(display_health, display_goal, fill_speed * delta)
		target_display_health[slime] = display_health

func _spawn_damage_number(slime: Sprite2D, amount: float) -> void:
	_spawn_floating_number(slime.global_position + Vector2(5, -9), int(round(amount)), Vector2(0.0, -DAMAGE_NUMBER_FLOAT_SPEED))


func _spawn_player_damage_number(amount: float) -> void:
	_spawn_floating_number(player.global_position + Vector2(5, -2), int(round(amount)), Vector2(0.0, DAMAGE_NUMBER_FLOAT_SPEED))


func _spawn_floating_number(world_position: Vector2, value: int, velocity: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _damage_number_texture(value)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.z_index = OVERWORLD_UI_Z + 2
	sprite.position = world_position
	add_child(sprite)
	damage_numbers.append({
		"sprite": sprite,
		"timer": DAMAGE_NUMBER_LIFETIME,
		"velocity": velocity,
	})


func _update_damage_numbers(delta: float) -> void:
	for index in range(damage_numbers.size() - 1, -1, -1):
		var damage_number := damage_numbers[index]
		var sprite := damage_number["sprite"] as Sprite2D
		var timer := float(damage_number["timer"]) - delta
		if sprite == null or timer <= 0.0:
			if sprite != null:
				sprite.queue_free()
			damage_numbers.remove_at(index)
			continue

		sprite.position += damage_number.get("velocity", Vector2.ZERO) as Vector2 * delta
		var color := Color.WHITE
		color.a = clampf(timer / DAMAGE_NUMBER_LIFETIME, 0.0, 1.0)
		sprite.modulate = color
		damage_number["timer"] = timer


func _damage_number_texture(value: int) -> Texture2D:
	return _pixel_number_texture(str(maxi(value, 0)), Color.WHITE)


func _pixel_text_texture(text: String, color: Color) -> Texture2D:
	return _pixel_number_texture(text, color)


func _pixel_number_texture(text: String, color: Color) -> Texture2D:
	var cache_key := "%s:%s" % [text, _rgb_key(color)]
	if damage_number_texture_cache.has(cache_key):
		return damage_number_texture_cache[cache_key]
	var digit_patterns := {
		"+": ["000", "010", "111", "010", "000"],
		"!": ["010", "010", "010", "000", "010"],
		"/": ["001", "001", "010", "100", "100"],
		"R": ["110", "101", "110", "101", "101"],
		"S": ["111", "100", "111", "001", "111"],
		"T": ["111", "010", "010", "010", "010"],
		"0": ["111", "101", "101", "101", "111"],
		"1": ["010", "110", "010", "010", "111"],
		"2": ["111", "001", "111", "100", "111"],
		"3": ["111", "001", "111", "001", "111"],
		"4": ["101", "101", "111", "001", "001"],
		"5": ["111", "100", "111", "001", "111"],
		"6": ["111", "100", "111", "101", "111"],
		"7": ["111", "001", "010", "010", "010"],
		"8": ["111", "101", "111", "101", "111"],
		"9": ["111", "101", "111", "001", "111"],
		"G": ["111", "100", "101", "101", "111"],
		"A": ["010", "101", "111", "101", "101"],
		"M": ["10001", "11011", "10101", "10001", "10001"],
		"E": ["111", "100", "110", "100", "111"],
		"O": ["111", "101", "101", "101", "111"],
		"V": ["101", "101", "101", "101", "010"],
		" ": ["0", "0", "0", "0", "0"],
	}
	var digit_height := 5
	var spacing := 1
	var image_width := 0
	for digit in text:
		var pattern: Array = digit_patterns.get(digit, digit_patterns["0"])
		image_width += (pattern[0] as String).length() + spacing
	image_width = maxi(image_width - spacing, 1)
	var image := Image.create(image_width, digit_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	for digit_index in text.length():
		var digit := text[digit_index]
		var pattern: Array = digit_patterns.get(digit, digit_patterns["0"])
		var x_offset := 0
		for prior_index in digit_index:
			var prior_pattern: Array = digit_patterns.get(text[prior_index], digit_patterns["0"])
			x_offset += (prior_pattern[0] as String).length() + spacing
		for y in digit_height:
			var row := pattern[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)

	var texture := ImageTexture.create_from_image(image)
	damage_number_texture_cache[cache_key] = texture
	return texture


func _update_slime_scoot(slime: Sprite2D, delta: float) -> void:
	var scoot_timer := float(slime_scoot_timers[slime])
	if scoot_timer > 0.0:
		var previous_progress := 1.0 - (scoot_timer / SLIME_SCOOT_DURATION)
		scoot_timer = maxf(scoot_timer - delta, 0.0)
		var progress := 1.0 - (scoot_timer / SLIME_SCOOT_DURATION)
		slime_scoot_timers[slime] = scoot_timer

		var start := slime_scoot_starts[slime] as Vector2
		var target := slime_scoot_targets[slime] as Vector2
		var previous_ease := _scoot_ease(previous_progress)
		var eased_progress := _scoot_ease(progress)
		var movement := (target - start) * (eased_progress - previous_ease)
		var did_move := _try_move_actor(slime, movement)
		_set_slime_squish(slime, progress, target - start)
		if not did_move and movement.length_squared() > 0.001:
			_repath_slime_after_block(slime)
			return

		if scoot_timer <= 0.0:
			_start_slime_hold(slime)
		return

	var hold_timer := float(slime_hold_timers[slime])
	if hold_timer > 0.0:
		slime_hold_timers[slime] = maxf(hold_timer - delta, 0.0)
		if _is_slime_aggroed(slime):
			_set_actor_visual_scale(slime, Vector2.ONE)
		else:
			_set_slime_idle_breath(slime, delta)
		return

	_start_slime_scoot(slime)


func _start_slime_scoot(slime: Sprite2D) -> void:
	_set_actor_visual_scale(slime, Vector2.ONE)
	var target: Vector2 = slime_targets[slime]
	var foot := _actor_foot(slime)
	var is_aggroed := _is_slime_aggroed(slime)
	if is_aggroed:
		target = _aggro_slime_target(slime)
		slime_targets[slime] = target
		slime_repath_timers[slime] = 0.08
	elif foot.distance_to(target) < 2.0 or float(slime_repath_timers[slime]) <= 0.0:
		target = _random_slime_walkable_point_near(foot, 5, slime)
		slime_targets[slime] = target
		slime_repath_timers[slime] = rng.randf_range(SLIME_REPATH_MIN, SLIME_REPATH_MAX)

	var direction := target - foot
	if direction.length_squared() < 0.01:
		if is_aggroed:
			slime_targets[slime] = _aggro_slime_target(slime)
			slime_repath_timers[slime] = 0.0
			return
		_start_slime_hold(slime)
		return

	var steering_direction := direction.normalized()
	if is_aggroed:
		# Perspective movement compresses vertical travel; compensate during
		# pursuit so slimes above/below the player close distance decisively.
		steering_direction.y *= 2.0
		steering_direction = steering_direction.normalized()
	var movement := _perspective_movement(steering_direction * minf(SLIME_SCOOT_DISTANCE, direction.length()))
	var desired_position := slime.position + movement
	_set_slime_facing(slime, movement.x)

	slime_scoot_starts[slime] = slime.position
	slime_scoot_targets[slime] = desired_position
	slime_scoot_timers[slime] = SLIME_SCOOT_DURATION


func _repath_slime_after_block(slime: Sprite2D) -> void:
	if _is_slime_dead(slime):
		return
	slime_scoot_timers[slime] = 0.0
	slime_scoot_starts[slime] = slime.position
	slime_scoot_targets[slime] = slime.position
	slime_repath_timers[slime] = 0.0
	if _is_slime_aggroed(slime):
		slime_targets[slime] = _aggro_slime_target(slime)
		slime_hold_timers[slime] = 0.0
	else:
		slime_targets[slime] = _random_slime_walkable_point_near(_actor_foot(slime), 8, slime)
		slime_hold_timers[slime] = rng.randf_range(0.08, 0.18)
	_set_actor_visual_scale(slime, Vector2.ONE)


func _start_slime_hold(slime: Sprite2D) -> void:
	var hold_time := rng.randf_range(SLIME_HOLD_MIN, SLIME_HOLD_MAX)
	if not _is_slime_aggroed(slime) and rng.randf() < SLIME_CHILL_CHANCE:
		hold_time = rng.randf_range(SLIME_CHILL_MIN, SLIME_CHILL_MAX)
	slime_hold_timers[slime] = hold_time
	slime_idle_breath_timers[slime] = 0.0


func _scoot_ease(progress: float) -> float:
	return 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)


func _set_slime_squish(slime: Sprite2D, progress: float, movement: Vector2) -> void:
	var pulse := sin(clampf(progress, 0.0, 1.0) * PI)
	var stretch_x := 1.0 + pulse * 0.18
	var stretch_y := 1.0 - pulse * 0.14
	if absf(movement.y) > absf(movement.x):
		stretch_x = 1.0 + pulse * 0.12
		stretch_y = 1.0 - pulse * 0.18
	_set_actor_visual_scale(slime, Vector2(stretch_x, stretch_y))


func _set_slime_idle_breath(slime: Sprite2D, delta: float) -> void:
	var timer := float(slime_idle_breath_timers.get(slime, 0.0)) + delta
	slime_idle_breath_timers[slime] = fmod(timer, SLIME_IDLE_BREATH_TIME)
	var pulse := (sin((timer / SLIME_IDLE_BREATH_TIME) * TAU - PI * 0.5) + 1.0) * 0.5
	var stretch_x := 1.0 + pulse * 0.05
	var stretch_y := 1.0 - pulse * 0.04
	_set_actor_visual_scale(slime, Vector2(stretch_x, stretch_y))


func _set_actor_visual_scale(actor: Sprite2D, visual_scale: Vector2) -> void:
	actor_visual_scales[actor] = visual_scale


func _try_move_actor(actor: Sprite2D, movement: Vector2) -> bool:
	var original := actor.position

	actor.position.x += movement.x
	if actor == player and _try_enter_active_door():
		return true
	if not _can_actor_stand_at_current_position(actor):
		actor.position.x = original.x
	else:
		_resolve_actor_contacts(actor, Vector2(movement.x, 0.0))

	actor.position.y += movement.y
	if actor == player and _try_enter_active_door():
		return true
	if not _can_actor_stand_at_current_position(actor):
		actor.position.y = original.y
	else:
		_resolve_actor_contacts(actor, Vector2(0.0, movement.y))

	return actor.position.distance_squared_to(original) > 0.0001


func _try_move_actor_swept(actor: Sprite2D, movement: Vector2, max_step: float) -> bool:
	var original := actor.position
	var distance := movement.length()
	if distance <= 0.001:
		return false

	var steps := maxi(1, int(ceil(distance / max_step)))
	var step := movement / float(steps)
	for index in steps:
		var before_step := actor.position
		actor.position += step
		if not _can_actor_stand_at_current_position(actor) or _collides_with_static(actor):
			actor.position = before_step
			break

	return actor.position.distance_squared_to(original) > 0.0001


func _resolve_actor_contacts(actor: Sprite2D, movement: Vector2) -> void:
	for other in collision_sprites:
		if other == actor:
			continue
		if not _actors_are_in_contact(actor, other):
			continue

		if other == chest:
			_separate_from_static(actor, other)
		elif slimes.has(actor) and slimes.has(other):
			_push_actor(actor, other, movement)
		elif actor != player and other == player and _is_enemy_control_locked(actor):
			_separate_actor_from_actor(actor, other)
		else:
			_push_actor(actor, other, movement)


func _resolve_slime_contact(slime: Sprite2D, other: Sprite2D) -> void:
	var push := _overlap_push_vector(slime, other)
	if push == Vector2.ZERO:
		return

	# Resolve the pair once. Recursive movement here makes dense groups jitter
	# and can apply the same contact multiple times in one frame.
	var separation := push * 0.5
	slime.position += separation
	other.position -= separation
	if not _can_actor_stand_at_current_position(slime):
		slime.position -= separation
	if not _can_actor_stand_at_current_position(other):
		other.position += separation



func _push_actor(actor: Sprite2D, other: Sprite2D, movement: Vector2) -> void:
	var push := _overlap_push_vector(actor, other)
	if push == Vector2.ZERO:
		return

	var actor_weight := _actor_weight(actor)
	var other_weight := _actor_weight(other)
	var total_weight := actor_weight + other_weight
	var actor_share := other_weight / total_weight
	var other_share := actor_weight / total_weight

	actor.position += push * actor_share
	_try_push_other_actor(other, -push * other_share + movement * other_share * 0.45)


func _try_push_other_actor(actor: Sprite2D, movement: Vector2) -> void:
	_try_move_actor_swept(actor, movement, 0.75)


func _separate_from_static(actor: Sprite2D, other: Sprite2D) -> void:
	actor.position += _overlap_push_vector(actor, other)


func _separate_actor_from_actor(actor: Sprite2D, other: Sprite2D) -> void:
	actor.position += _overlap_push_vector(actor, other)


func _is_enemy_control_locked(actor: Sprite2D) -> bool:
	return float(slime_hitstun_timers.get(actor, 0.0)) > 0.0 or float(slime_knockback_timers.get(actor, 0.0)) > 0.0


func _collides_with_static(actor: Sprite2D) -> bool:
	for other in collision_sprites:
		if other == actor or other != chest:
			continue
		if _collision_rect(actor).intersects(_collision_rect(other), false):
			return true
	return false


func _overlap_push_vector(actor: Sprite2D, other: Sprite2D) -> Vector2:
	if other != chest and actor != chest:
		return _actor_contact_push_vector(actor, other)

	var rect := _collision_rect(actor)
	var other_rect := _collision_rect(other)
	var overlap := rect.intersection(other_rect)
	if not overlap.has_area():
		return Vector2.ZERO

	var actor_center := rect.get_center()
	var other_center := other_rect.get_center()
	if overlap.size.x < overlap.size.y:
		return Vector2(-overlap.size.x if actor_center.x < other_center.x else overlap.size.x, 0.0)
	return Vector2(0.0, -overlap.size.y if actor_center.y < other_center.y else overlap.size.y)


func _actors_are_in_contact(actor: Sprite2D, other: Sprite2D) -> bool:
	if actor == chest or other == chest:
		return _collision_rect(actor).intersects(_collision_rect(other), false)
	return _actor_contact_push_vector(actor, other) != Vector2.ZERO


func _actor_contact_push_vector(actor: Sprite2D, other: Sprite2D) -> Vector2:
	var actor_foot := _actor_foot(actor)
	var other_foot := _actor_foot(other)
	var delta := actor_foot - other_foot
	var distance := delta.length()
	var min_distance := _actor_contact_radius(actor) + _actor_contact_radius(other)
	if distance >= min_distance:
		return Vector2.ZERO
	if distance <= 0.001:
		delta = Vector2(1.0, 0.0)
		distance = 1.0
	var overlap := min_distance - distance
	return delta.normalized() * overlap


func _actor_contact_radius(actor: Sprite2D) -> float:
	if actor == chest:
		return maxf(CHEST_COLLISION_SIZE.x, CHEST_COLLISION_SIZE.y) * 0.5
	var guide := _collision_guide_rect_by_name(actor, "CollisionGuide")
	if guide.has_area():
		return maxf(minf(guide.size.x, guide.size.y) * 0.5, 2.0)
	return ACTOR_CONTACT_RADIUS


func _actor_weight(actor: Sprite2D) -> float:
	return PLAYER_WEIGHT if actor == player else SLIME_WEIGHT


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


func _stabilize_collision_guides() -> void:
	for actor in actor_sprites:
		var actor_scale := actor.scale
		if absf(actor_scale.x) < 0.001 or absf(actor_scale.y) < 0.001:
			continue
		for child in actor.get_children():
			if child is Node2D and (child.name.ends_with("Guide") or child.name.begins_with("AttackGuide") or child.name.begins_with("SwordHitbox")):
				(child as Node2D).scale = Vector2(1.0 / actor_scale.x, 1.0 / actor_scale.y)
		if actor == slime_blue or actor == slime_green or actor == slime_red:
			_update_slime_attack_guides(actor)


func _build_depth_lists() -> void:
	depth_sprites.clear()
	occluder_sprites.clear()

	_add_depth_sprite(player)
	for slime in slimes:
		if not _is_slime_dead(slime):
			_add_depth_sprite(slime)
	if chest.visible:
		_add_depth_sprite(chest)

	occluder_sprites.append(player)
	for slime in slimes:
		if not _is_slime_dead(slime):
			occluder_sprites.append(slime)

	if chest.visible:
		for path in OCCLUDER_PATHS:
			var node := get_node_or_null(path)
			if node != null:
				_collect_occluders(node)

	_update_depth_sorting()


func _hide_editor_only_guides() -> void:
	var floor_collision_guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as CanvasItem
	if floor_collision_guide != null:
		floor_collision_guide.visible = false
	var door_exit_guide := door.get_node_or_null("DoorExitGuide") as CanvasItem
	if door_exit_guide != null:
		door_exit_guide.visible = false
	if entrance_tile_a != null:
		var entrance_return_guide := entrance_tile_a.get_node_or_null("EntranceReturnGuide") as CanvasItem
		if entrance_return_guide != null:
			entrance_return_guide.visible = false


func _build_sprite_images() -> void:
	original_actor_textures.clear()
	actor_default_textures.clear()
	actor_default_materials.clear()
	original_actor_images.clear()
	original_actor_scales.clear()
	actor_visual_scales.clear()
	occluded_actor_textures.clear()
	actor_occlusion_grace.clear()
	highlighted_actor_textures.clear()
	white_actor_textures.clear()
	sprite_images.clear()

	for actor in actor_sprites:
		actor_default_textures[actor] = actor.texture
		actor_default_materials[actor] = actor.material
		original_actor_textures[actor] = actor.texture
		original_actor_scales[actor] = actor.scale
		actor_visual_scales[actor] = Vector2.ONE
		var image := _cached_texture_image(actor.texture)
		original_actor_images[actor] = image
		sprite_images[actor] = image
		occluded_actor_textures[actor] = ImageTexture.create_from_image(_cached_effect_image(actor.texture, image))
		actor_occlusion_grace[actor] = 0.0
		highlighted_actor_textures[actor] = ImageTexture.create_from_image(_cached_highlighted_image(actor.texture, image))
		white_actor_textures[actor] = ImageTexture.create_from_image(_cached_white_image(actor.texture, image))

	for occluder in occluder_sprites:
		if not sprite_images.has(occluder):
			sprite_images[occluder] = _cached_texture_image(occluder.texture)


func _build_slime_direction_textures() -> void:
	slime_left_textures = {
		slime_blue: _load_texture_or_null("res://assets/artwork/SlimeBlueLeft.png"),
		slime_green: _load_texture_or_null("res://assets/artwork/SlimeGreenLeft.png"),
		slime_red: _load_texture_or_null("res://assets/artwork/SlimeRedLeft.png"),
	}
	slime_right_textures = {
		slime_blue: _load_texture_or_null("res://assets/artwork/SlimeBlueRight.png"),
		slime_green: _load_texture_or_null("res://assets/artwork/SlimeGreenRight.png"),
		slime_red: _load_texture_or_null("res://assets/artwork/SlimeRedRight.png"),
	}


func _build_slime_attack_frames() -> void:
	var green_left_frames := _slice_frames("res://assets/artwork/SlimeGreen_AttackL.png", SLIME_ATTACK_FRAME_SIZE)
	var green_right_frames := _slice_frames("res://assets/artwork/SlimeGreen_AttackR.png", SLIME_ATTACK_FRAME_SIZE)
	slime_attack_left_frames.clear()
	slime_attack_right_frames.clear()
	slime_attack_left_frames[slime_green] = green_left_frames
	slime_attack_right_frames[slime_green] = green_right_frames
	slime_attack_left_frames[slime_red] = _recolor_slime_attack_frames(green_left_frames, slime_red)
	slime_attack_right_frames[slime_red] = _recolor_slime_attack_frames(green_right_frames, slime_red)
	slime_attack_left_frames[slime_blue] = _recolor_slime_attack_frames(green_left_frames, slime_blue)
	slime_attack_right_frames[slime_blue] = _recolor_slime_attack_frames(green_right_frames, slime_blue)
	for slime in slimes:
		for texture in slime_attack_left_frames.get(slime, []):
			_warm_texture_cache(texture)
		for texture in slime_attack_right_frames.get(slime, []):
			_warm_texture_cache(texture)


func _recolor_slime_attack_frames(source_frames: Array[Texture2D], slime: Sprite2D) -> Array[Texture2D]:
	var recolored_frames: Array[Texture2D] = []
	for texture in source_frames:
		var image := _cached_texture_image(texture).duplicate()
		for y in image.get_height():
			for x in image.get_width():
				var color: Color = image.get_pixel(x, y)
				if color.a <= 0.0:
					continue
				image.set_pixel(x, y, _slime_attack_palette_color(color, slime))
		recolored_frames.append(ImageTexture.create_from_image(image))
	return recolored_frames


func _slime_attack_palette_color(color: Color, slime: Sprite2D) -> Color:
	var key := _rgb_key(color)
	var mapping: Dictionary = {}
	if slime == slime_red:
		mapping = {
			"257179": Color8(93, 39, 93),
			"38B764": Color8(177, 62, 83),
			"A7F070": Color8(239, 125, 87),
		}
	elif slime == slime_blue:
		mapping = {
			"257179": Color8(41, 54, 111),
			"38B764": Color8(59, 93, 201),
			"A7F070": Color8(65, 166, 246),
		}
	else:
		return color

	if not mapping.has(key):
		return color
	var mapped := mapping[key] as Color
	return Color(mapped.r, mapped.g, mapped.b, color.a)


func _build_enemy_health_ui() -> void:
	target_health_fill_textures = {
		slime_blue: _load_texture_or_null("res://assets/artwork/EnemyHpBlueBar.png"),
		slime_green: _load_texture_or_null("res://assets/artwork/EnemyHpGreenBar.png"),
		slime_red: _load_texture_or_null("res://assets/artwork/EnemyHpRedBar.png"),
	}
	target_overhead_fill_textures = {
		slime_blue: _load_texture_or_null("res://assets/artwork/HpOverheadBlueBar.png"),
		slime_green: _load_texture_or_null("res://assets/artwork/HpOverheadGreenBar.png"),
		slime_red: _load_texture_or_null("res://assets/artwork/HpOverheadRedBar.png"),
	}
	target_health_damage_fill_textures.clear()
	target_overhead_damage_fill_textures.clear()
	for slime in slimes:
		target_health_damage_fill_textures[slime] = _brighter_bar_texture(target_health_fill_textures.get(slime) as Texture2D)
		target_overhead_damage_fill_textures[slime] = _brighter_bar_texture(target_overhead_fill_textures.get(slime) as Texture2D)

	target_overhead_frames.clear()
	target_overhead_damage_fills.clear()
	target_overhead_fills.clear()
	target_overhead_offsets.clear()
	target_overhead_fill_sizes.clear()
	target_overhead_aggro_markers.clear()

	target_health_damage_fill = _duplicate_fill_sprite(target_health_fill, "EnemyHpDamageFill")
	target_health_bar.z_index = 0
	target_health_bar.z_as_relative = true
	target_health_damage_fill.z_index = 1
	target_health_fill.z_index = 2
	target_health_damage_fill.z_as_relative = true
	target_health_fill.z_as_relative = true
	target_health_damage_fill.get_parent().move_child(target_health_damage_fill, target_health_fill.get_index())

	var green_offset := hp_overhead.global_position - slime_green.global_position
	_register_overhead_bar(slime_green, hp_overhead, hp_overhead_fill, green_offset)

	for slime in slimes:
		if slime == slime_green:
			continue

		var frame := Sprite2D.new()
		frame.name = "HpOverhead"
		frame.texture = hp_overhead.texture
		frame.centered = hp_overhead.centered
		frame.position = hp_overhead.position
		frame.z_index = 0
		frame.z_as_relative = false
		slime.add_child(frame)

		var damage_fill := Sprite2D.new()
		damage_fill.name = "HpOverheadDamageFill"
		damage_fill.texture = target_overhead_damage_fill_textures.get(slime, hp_overhead_fill.texture)
		damage_fill.centered = hp_overhead_fill.centered
		damage_fill.position = hp_overhead_fill.position
		damage_fill.z_index = 1
		damage_fill.z_as_relative = false
		slime.add_child(damage_fill)

		var fill := Sprite2D.new()
		fill.name = "HpOverheadFill"
		fill.texture = target_overhead_fill_textures.get(slime, hp_overhead_fill.texture)
		fill.centered = hp_overhead_fill.centered
		fill.position = hp_overhead_fill.position
		fill.z_index = 2
		fill.z_as_relative = false
		slime.add_child(fill)

		_register_overhead_bar(slime, frame, fill, green_offset)


func _register_overhead_bar(slime: Sprite2D, frame: Sprite2D, fill: Sprite2D, offset: Vector2) -> void:
	var fill_texture := target_overhead_fill_textures.get(slime, fill.texture) as Texture2D
	if fill_texture != null:
		fill.texture = fill_texture
	var damage_fill := fill.get_parent().get_node_or_null("HpOverheadDamageFill") as Sprite2D
	if damage_fill == null:
		damage_fill = _duplicate_fill_sprite(fill, "HpOverheadDamageFill")
		damage_fill.z_index = 1
	fill.z_index = 2
	var damage_fill_texture := target_overhead_damage_fill_textures.get(slime, damage_fill.texture) as Texture2D
	if damage_fill_texture != null:
		damage_fill.texture = damage_fill_texture
	var aggro_marker := fill.get_parent().get_node_or_null("AggroMarker") as Sprite2D
	if aggro_marker == null:
		aggro_marker = Sprite2D.new()
		aggro_marker.name = "AggroMarker"
		aggro_marker.texture = _pixel_particle_texture(Color8(59, 93, 201))
		aggro_marker.centered = false
		aggro_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		aggro_marker.position = fill.position + Vector2((fill.texture.get_size().x if fill.texture != null else 0.0) + 1.0, 2.0)
		aggro_marker.z_index = 3
		aggro_marker.z_as_relative = false
		fill.get_parent().add_child(aggro_marker)

	target_overhead_frames[slime] = frame
	target_overhead_damage_fills[slime] = damage_fill
	target_overhead_fills[slime] = fill
	target_overhead_offsets[slime] = offset
	target_overhead_fill_sizes[slime] = fill.texture.get_size() if fill.texture != null else Vector2.ZERO
	target_overhead_aggro_markers[slime] = aggro_marker
	frame.visible = false
	damage_fill.visible = false
	fill.visible = false
	aggro_marker.visible = false


func _duplicate_fill_sprite(source: Sprite2D, sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = source.texture
	sprite.centered = source.centered
	sprite.position = source.position
	sprite.offset = source.offset
	sprite.scale = source.scale
	sprite.region_enabled = source.region_enabled
	sprite.region_rect = source.region_rect
	sprite.texture_filter = source.texture_filter
	sprite.z_as_relative = source.z_as_relative
	sprite.z_index = source.z_index
	source.get_parent().add_child(sprite)
	return sprite


func _brighter_bar_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	if texture_image_cache.has("%s:bright_bar" % source.resource_path):
		return texture_image_cache["%s:bright_bar" % source.resource_path]

	var image := source.get_image()
	if image == null:
		return source

	var palette_step := {
		"B13E53": Color8(239, 125, 87),
		"3B5DC9": Color8(65, 166, 246),
		"38B764": Color8(167, 240, 112),
	}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var bright_color := palette_step.get(_rgb_key(color), color) as Color
			image.set_pixel(x, y, Color(bright_color.r, bright_color.g, bright_color.b, color.a))

	var texture := ImageTexture.create_from_image(image)
	texture_image_cache["%s:bright_bar" % source.resource_path] = texture
	return texture


func _rgb_key(color: Color) -> String:
	var red := int(round(color.r * 255.0))
	var green := int(round(color.g * 255.0))
	var blue := int(round(color.b * 255.0))
	return "%02X%02X%02X" % [red, green, blue]


func _load_texture_or_null(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _build_player_animation_frames() -> void:
	player_idle_frames = _slice_frames("res://assets/artwork/TinyDemon-idle.png", PLAYER_FRAME_SIZE)
	player_walk_frames = _slice_frames("res://assets/artwork/TinyDemon-walk.png", PLAYER_FRAME_SIZE)
	player_roll_frames = _slice_frames("res://assets/artwork/TinyDemon-roll.png", PLAYER_FRAME_SIZE)
	player_attack_frames = _slice_frames("res://assets/artwork/TinyDemon-attack1.png", PLAYER_ATTACK_FRAME_SIZE)
	player_attack_left_frames = _flip_frames_horizontally(player_attack_frames)
	_warm_player_frame_caches()
	if not player_idle_frames.is_empty():
		_set_actor_base_texture(player, player_idle_frames[0])


func _slice_frames(path: String, frame_size: Vector2i) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var texture := _load_texture_or_null(path)
	if texture == null:
		return frames

	var sheet := _cached_texture_image(texture)
	var frame_count := int(float(sheet.get_width()) / float(frame_size.x))
	for frame_index in range(frame_count):
		var frame := Image.create_empty(frame_size.x, frame_size.y, false, sheet.get_format())
		frame.blit_rect(
			sheet,
			Rect2i(frame_index * frame_size.x, 0, frame_size.x, frame_size.y),
			Vector2i.ZERO
		)
		frames.append(ImageTexture.create_from_image(frame))

	return frames


func _warm_player_frame_caches() -> void:
	for texture in player_idle_frames:
		_warm_texture_cache(texture)
	for texture in player_walk_frames:
		_warm_texture_cache(texture)
	for texture in player_roll_frames:
		_warm_texture_cache(texture)
	for texture in player_attack_frames:
		_warm_texture_cache(texture)
	for texture in player_attack_left_frames:
		_warm_texture_cache(texture)


func _flip_frames_horizontally(frames: Array[Texture2D]) -> Array[Texture2D]:
	var flipped_frames: Array[Texture2D] = []
	for texture in frames:
		var image := _cached_texture_image(texture).duplicate()
		image.flip_x()
		flipped_frames.append(ImageTexture.create_from_image(image))
	return flipped_frames


func _warm_texture_cache(texture: Texture2D) -> void:
	var image := _cached_texture_image(texture)
	_cached_effect_image(texture, image)
	_cached_highlighted_image(texture, image)
	_cached_white_image(texture, image)


func _set_slime_facing(slime: Sprite2D, direction_x: float) -> void:
	if absf(direction_x) < 0.1:
		return

	var texture: Texture2D = null
	if direction_x < 0.0:
		texture = slime_left_textures.get(slime)
		slime.flip_h = false
	else:
		texture = slime_right_textures.get(slime)
		if texture == null and slime_left_textures.get(slime) != null:
			texture = slime_left_textures.get(slime)
			slime.flip_h = true
		else:
			slime.flip_h = false

	if texture == null:
		texture = actor_default_textures[slime]

	_set_actor_base_texture(slime, texture)
	_update_slime_attack_guides(slime)


func _update_slime_attack_guides(slime: Sprite2D) -> void:
	# These are debug visuals only. Exactly one directional guide is visible;
	# guides never participate in movement or actor separation.
	var active_name := "AttackGuideL" if bool(slime_attack_face_left.get(slime, false)) else "AttackGuideR"
	for child in slime.get_children():
		if child is Node2D and child.name.begins_with("AttackGuide"):
			(child as Node2D).visible = child.name == active_name


func _set_actor_base_texture(actor: Sprite2D, texture: Texture2D) -> void:
	if texture == null:
		return
	if original_actor_textures[actor] == texture:
		actor.texture = texture
		return

	original_actor_textures[actor] = texture
	var image := _cached_texture_image(texture)
	original_actor_images[actor] = image
	sprite_images[actor] = image
	occluded_actor_textures[actor] = ImageTexture.create_from_image(_cached_effect_image(texture, image))
	highlighted_actor_textures[actor] = ImageTexture.create_from_image(_cached_highlighted_image(texture, image))
	white_actor_textures[actor] = ImageTexture.create_from_image(_cached_white_image(texture, image))
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
	if not depth_sprites.has(sprite):
		sprite.z_as_relative = false
		depth_sprites.append(sprite)


func _update_depth_sorting() -> void:
	for sprite in depth_sprites:
		sprite.z_index = int(round(_depth_key(sprite) * DEPTH_Z_SCALE))


func _update_actor_occlusion(delta: float) -> void:
	for actor in actor_sprites:
		var is_flashing := float(slime_flash_timers.get(actor, 0.0)) > 0.0
		if actor == player:
			is_flashing = player_hit_flash_timer > 0.0
		if is_flashing:
			actor.texture = white_actor_textures[actor]
			_apply_actor_scale(actor, false)
			continue

		var is_target := actor == current_target
		var actor_depth := _depth_key(actor)
		var actor_rect := _sprite_source_global_rect(actor)
		var active_occluders: Array[Sprite2D] = []
		var highest_occluder_z := actor.z_index

		for occluder in occluder_sprites:
			if occluder == actor:
				continue
			if _depth_key(occluder) <= actor_depth:
				continue
			var overlap := actor_rect.intersection(_sprite_source_global_rect(occluder))
			if overlap.has_area():
				active_occluders.append(occluder)
				highest_occluder_z = maxi(highest_occluder_z, occluder.z_index)

		if active_occluders.is_empty():
			_apply_unoccluded_actor_texture(actor, is_target, delta)
		else:
			var texture := _build_exact_occluded_actor_texture(actor, active_occluders, is_target)
			if texture == null:
				_apply_unoccluded_actor_texture(actor, is_target, delta)
			else:
				actor_occlusion_grace[actor] = OCCLUSION_RELEASE_GRACE
				actor.texture = texture
				_apply_actor_scale(actor, true)
				if not active_occluders.has(player):
					actor.z_index = min(highest_occluder_z + 1, 4095)


func _apply_unoccluded_actor_texture(actor: Sprite2D, is_target: bool, delta: float) -> void:
	var grace := maxf(float(actor_occlusion_grace.get(actor, 0.0)) - delta, 0.0)
	actor_occlusion_grace[actor] = grace
	if grace > 0.0 and actor.texture == occluded_actor_textures.get(actor):
		_apply_actor_scale(actor, true)
		return

	if is_target:
		actor.texture = highlighted_actor_textures[actor]
		_apply_actor_scale(actor, true)
	else:
		actor.texture = original_actor_textures[actor]
		_apply_actor_scale(actor, false)


func _update_player_shadow() -> void:
	player_shadow.global_position = player.global_position + player_shadow_offset
	player_shadow.global_scale = player_shadow_scale
	player_shadow.self_modulate = Color(1, 1, 1, 0.25)
	player_shadow.flip_h = player.flip_h
	player_shadow.z_index = int(round(_actor_foot(player).y * DEPTH_Z_SCALE)) - 1


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
	var input := Vector2.ZERO

	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		input.y -= 1.0

	input += _controller_movement_input()
	return input.limit_length(1.0)


func _controller_movement_input() -> Vector2:
	var input := Vector2.ZERO
	for device in _controller_devices():
		var stick := Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		)
		if stick.length() >= CONTROLLER_DEADZONE:
			input += stick

		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
			input.x += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
			input.x -= 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
			input.y += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
			input.y -= 1.0

	return input.limit_length(1.0)


func _is_target_input_held() -> bool:
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_TAB):
		return true

	for device in _controller_devices():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER):
			return true
		if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
			return true
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > CONTROLLER_TRIGGER_DEADZONE:
			return true
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > CONTROLLER_TRIGGER_DEADZONE:
			return true

	return false


func _is_attack_input_pressed() -> bool:
	if Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_SPACE):
		return true

	for device in _controller_devices():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_X):
			return true

	return false


func _is_interact_input_pressed() -> bool:
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER):
		return true

	for device in _controller_devices():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_B):
			return true

	return false


func _is_roll_input_pressed() -> bool:
	if Input.is_key_pressed(KEY_K):
		return true

	for device in _controller_devices():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_A):
			return true

	return false


func _controller_devices() -> Array[int]:
	var devices: Array[int] = []
	for device in Input.get_connected_joypads():
		devices.append(int(device))
	if devices.is_empty():
		devices.append(0)
	return devices


func _closest_target() -> Sprite2D:
	var closest: Sprite2D = null
	var closest_distance := TARGET_LOCK_MAX_DISTANCE
	var player_foot := _actor_foot(player)

	for slime in slimes:
		if _is_slime_dead(slime):
			continue
		var distance := player_foot.distance_squared_to(_actor_foot(slime))
		if distance < closest_distance:
			closest = slime
			closest_distance = distance

	return closest


func _set_current_target(target: Sprite2D) -> void:
	if current_target == target:
		return

	current_target = target


func _update_target_ui() -> void:
	if current_target == null:
		_set_target_ui_visible(false)
		return

	_set_target_ui_visible(true)
	var fill_texture := target_health_fill_textures.get(current_target, target_health_fill.texture) as Texture2D
	if fill_texture != null and target_health_fill.texture != fill_texture:
		target_health_fill.texture = fill_texture
		target_health_bar_size = fill_texture.get_size()
	var damage_fill_texture := target_health_damage_fill_textures.get(current_target, target_health_fill.texture) as Texture2D
	if target_health_damage_fill != null and damage_fill_texture != null:
		target_health_damage_fill.texture = damage_fill_texture

	var max_health := _enemy_max_health(current_target)
	var health := float(target_health.get(current_target, max_health))
	var display_health := float(target_display_health.get(current_target, max_health))
	target_health_text.texture = _pixel_number_texture("%d/%d" % [ceili(health), ceili(max_health)], Color.WHITE)
	_set_fill_ratio(target_health_fill, target_health_bar_size, health / max_health)
	if target_health_damage_fill != null:
		_set_fill_ratio(target_health_damage_fill, target_health_bar_size, display_health / max_health)


func _set_target_ui_visible(target_visible: bool) -> void:
	target_name_text.visible = target_visible
	target_health_bar.visible = target_visible
	if target_health_damage_fill != null:
		target_health_damage_fill.visible = target_visible
	target_health_fill.visible = target_visible
	if target_health_text != null:
		target_health_text.visible = target_visible


func _update_player_health_ui() -> void:
	var max_health := _player_max_health()
	_set_fill_ratio(player_health_fill, player_health_fill_size, clampf(player_health / max_health, 0.0, 1.0))
	if player_health_text != null:
		player_health_text.texture = _pixel_number_texture("%d/%d" % [ceili(player_health), ceili(max_health)], Color.WHITE)


func _set_fill_ratio(fill: Sprite2D, fill_size: Vector2, ratio: float) -> void:
	fill.region_enabled = true
	fill.region_rect = Rect2(Vector2.ZERO, Vector2(fill_size.x * clampf(ratio, 0.0, 1.0), fill_size.y))


func _update_overworld_ui() -> void:
	for slime in slimes:
		var frame := target_overhead_frames.get(slime) as Sprite2D
		var damage_fill := target_overhead_damage_fills.get(slime) as Sprite2D
		var fill := target_overhead_fills.get(slime) as Sprite2D
		var aggro_marker := target_overhead_aggro_markers.get(slime) as Sprite2D
		if frame == null or damage_fill == null or fill == null or aggro_marker == null:
			continue
		if _is_slime_dead(slime):
			frame.visible = false
			damage_fill.visible = false
			fill.visible = false
			aggro_marker.visible = false
			continue

		var max_health := _enemy_max_health(slime)
		var health := float(target_health.get(slime, max_health))
		var is_aggroed := _is_slime_aggroed(slime)
		var should_show := health < max_health or is_aggroed
		frame.visible = should_show
		damage_fill.visible = should_show
		fill.visible = should_show
		aggro_marker.visible = is_aggroed
		if not should_show:
			continue

		var overhead_position := slime.global_position + (target_overhead_offsets.get(slime, Vector2.ZERO) as Vector2)
		frame.global_position = overhead_position
		frame.global_scale = Vector2.ONE
		frame.z_index = OVERWORLD_UI_Z
		damage_fill.global_position = overhead_position
		damage_fill.global_scale = Vector2.ONE
		damage_fill.z_index = OVERWORLD_UI_Z + 1
		fill.global_position = overhead_position
		fill.global_scale = Vector2.ONE
		fill.z_index = OVERWORLD_UI_Z + 2
		aggro_marker.global_position = overhead_position
		aggro_marker.global_scale = Vector2.ONE
		aggro_marker.z_index = OVERWORLD_UI_Z + 3
		var display_health := float(target_display_health.get(slime, max_health))
		var fill_size := target_overhead_fill_sizes.get(slime, Vector2.ZERO) as Vector2
		_set_fill_ratio(damage_fill, fill_size, display_health / max_health)
		_set_fill_ratio(fill, fill_size, health / max_health)


func _depth_key(sprite: Sprite2D) -> float:
	if actor_sprites.has(sprite):
		return _actor_foot(sprite).y
	if sprite.name.begins_with("WallLeft") or sprite.name.begins_with("WallRight"):
		return sprite.global_position.y + 28.0
	if sprite.name == "DoorRight":
		return sprite.global_position.y + 30.0
	return sprite.global_position.y + float(sprite.texture.get_height() if sprite.texture != null else 0)


func _sprite_global_rect(sprite: Sprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2(sprite.global_position, Vector2.ZERO)

	var size := sprite.texture.get_size() * sprite.scale.abs()
	var origin := sprite.global_position + sprite.offset * sprite.scale
	if sprite.centered:
		origin -= size * 0.5
	return Rect2(origin, size)


func _sprite_source_global_rect(sprite: Sprite2D) -> Rect2:
	var texture := _source_texture_for_rect(sprite)
	if texture == null:
		return Rect2(sprite.global_position, Vector2.ZERO)

	var sprite_scale := sprite.scale.abs()
	if original_actor_scales.has(sprite):
		sprite_scale = _actor_screen_scale(sprite).abs()

	var size := texture.get_size() * sprite_scale
	var origin := sprite.global_position + _sprite_source_offset(sprite) * sprite_scale
	if sprite.centered:
		origin -= size * 0.5
	return Rect2(origin, size)


func _source_texture_for_rect(sprite: Sprite2D) -> Texture2D:
	if original_actor_textures.has(sprite):
		return original_actor_textures[sprite]
	return sprite.texture


func _build_exact_occluded_actor_texture(actor: Sprite2D, active_occluders: Array[Sprite2D], include_outline: bool) -> Texture2D:
	var source_image := original_actor_images[actor] as Image
	var result_image := _make_effect_image(source_image)
	var width := result_image.get_width()
	var height := result_image.get_height()
	var any_occluded_pixel := false

	for y in range(height):
		for x in range(width):
			var color := result_image.get_pixel(x, y)
			if color.a <= 0.0:
				continue

			var source_x := (float(x) + 0.5) / float(EFFECT_RESOLUTION_SCALE)
			var source_y := (float(y) + 0.5) / float(EFFECT_RESOLUTION_SCALE)
			if actor.flip_h:
				source_x = float(source_image.get_width()) - source_x

			var world_pixel := actor.global_position + _actor_visual_offset(actor) * (original_actor_scales[actor] as Vector2) + Vector2(source_x, source_y) * (original_actor_scales[actor] as Vector2)
			if not _is_pixel_covered_by_occluder(world_pixel, active_occluders):
				continue

			any_occluded_pixel = true
			if (x + y) % 2 == 0:
				color.a = 0.0
				result_image.set_pixel(x, y, color)

	if not any_occluded_pixel:
		if not include_outline:
			return null

	if include_outline:
		_apply_half_pixel_outline(result_image)

	var texture := occluded_actor_textures[actor] as ImageTexture
	texture.update(result_image)
	return texture


func _make_effect_image(source_image: Image) -> Image:
	var width := source_image.get_width() * EFFECT_RESOLUTION_SCALE
	var height := source_image.get_height() * EFFECT_RESOLUTION_SCALE
	var image := Image.create_empty(width, height, false, source_image.get_format())

	for y in range(height):
		for x in range(width):
			image.set_pixel(
				x,
				y,
				source_image.get_pixel(
					int(float(x) / float(EFFECT_RESOLUTION_SCALE)),
					int(float(y) / float(EFFECT_RESOLUTION_SCALE))
				)
			)

	return image


func _make_highlighted_effect_image(source_image: Image) -> Image:
	var image := _make_effect_image(source_image)
	_apply_half_pixel_outline(image)
	return image


func _make_white_image(source_image: Image) -> Image:
	var image := Image.create_empty(source_image.get_width(), source_image.get_height(), false, source_image.get_format())
	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			var color := source_image.get_pixel(x, y)
			if color.a > 0.05:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, color.a))
			else:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return image


func _apply_half_pixel_outline(image: Image) -> void:
	var outline_points: Array[Vector2i] = []
	var width := image.get_width()
	var height := image.get_height()

	for y in range(height):
		for x in range(width):
			if image.get_pixel(x, y).a > 0.05:
				continue
			if _has_opaque_neighbor(image, x, y):
				outline_points.append(Vector2i(x, y))

	for point in outline_points:
		image.set_pixel(point.x, point.y, Color.WHITE)


func _has_opaque_neighbor(image: Image, x: int, y: int) -> bool:
	for offset_y in range(-1, 2):
		for offset_x in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var sample_x := x + offset_x
			var sample_y := y + offset_y
			if sample_x < 0 or sample_y < 0 or sample_x >= image.get_width() or sample_y >= image.get_height():
				continue
			if image.get_pixel(sample_x, sample_y).a > 0.05:
				return true
	return false


func _is_pixel_covered_by_occluder(world_pixel: Vector2, active_occluders: Array[Sprite2D]) -> bool:
	for occluder in active_occluders:
		var image := sprite_images[occluder] as Image
		var local_pixel := _source_pixel_position(occluder, world_pixel)
		var x := int(floor(local_pixel.x))
		var y := int(floor(local_pixel.y))

		if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
			continue
		if image.get_pixel(x, y).a > 0.0:
			return true

	return false


func _source_pixel_position(sprite: Sprite2D, world_pixel: Vector2) -> Vector2:
	var sprite_scale := sprite.scale
	var offset := sprite.offset
	if original_actor_scales.has(sprite):
		sprite_scale = _actor_screen_scale(sprite)
		offset = _actor_visual_offset(sprite)

	var local_pixel := world_pixel - sprite.global_position - offset * sprite_scale
	if sprite.centered and sprite.texture != null:
		local_pixel += sprite.texture.get_size() * sprite_scale * 0.5

	var source_pixel := Vector2(
		local_pixel.x / sprite_scale.x,
		local_pixel.y / sprite_scale.y
	)
	if sprite.flip_h and sprite_images.has(sprite):
		var image := sprite_images[sprite] as Image
		source_pixel.x = float(image.get_width()) - source_pixel.x - 1.0
	return source_pixel


func _apply_actor_scale(actor: Sprite2D, use_effect_texture: bool) -> void:
	var screen_scale := _actor_screen_scale(actor)
	if use_effect_texture:
		actor.scale = screen_scale / float(EFFECT_RESOLUTION_SCALE)
		actor.offset = _actor_visual_offset(actor) * float(EFFECT_RESOLUTION_SCALE)
	else:
		actor.scale = screen_scale
		actor.offset = _actor_visual_offset(actor)


func _actor_screen_scale(actor: Sprite2D) -> Vector2:
	return (original_actor_scales[actor] as Vector2) * (actor_visual_scales.get(actor, Vector2.ONE) as Vector2)


func _actor_visual_offset(actor: Sprite2D) -> Vector2:
	return PLAYER_TEXTURE_OFFSET if actor == player else Vector2.ZERO


func _sprite_source_offset(sprite: Sprite2D) -> Vector2:
	if original_actor_scales.has(sprite):
		return _actor_visual_offset(sprite)
	return sprite.offset


func _cached_texture_image(texture: Texture2D) -> Image:
	if texture_image_cache.has(texture):
		return texture_image_cache[texture]

	var image := _texture_image(texture)
	texture_image_cache[texture] = image
	return image


func _cached_effect_image(texture: Texture2D, source_image: Image) -> Image:
	if effect_image_cache.has(texture):
		return effect_image_cache[texture]

	var image := _make_effect_image(source_image)
	effect_image_cache[texture] = image
	return image


func _cached_highlighted_image(texture: Texture2D, source_image: Image) -> Image:
	if highlighted_image_cache.has(texture):
		return highlighted_image_cache[texture]

	var image := _make_highlighted_effect_image(source_image)
	highlighted_image_cache[texture] = image
	return image


func _cached_white_image(texture: Texture2D, source_image: Image) -> Image:
	if white_image_cache.has(texture):
		return white_image_cache[texture]

	var image := _make_white_image(source_image)
	white_image_cache[texture] = image
	return image


func _texture_image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _collect_walkable_tiles(node: Node) -> void:
	if node == floor_tiles and _collect_floor_collision_guide():
		return

	for child in node.get_children():
		if child is Sprite2D and child.texture != null:
			var tile := child as Sprite2D
			walkable_points.append(tile.to_global(Vector2(8, 4)))
			walkable_polygons.append(_tile_top_polygon(tile))
		_collect_walkable_tiles(child)


func _build_walkable_outline() -> void:
	if walkable_polygons.is_empty():
		return

	if use_walkable_polygon_direct:
		walkable_outline = walkable_polygons[0]
		return

	var points := PackedVector2Array()
	for polygon in walkable_polygons:
		for point in polygon:
			points.append(point)

	walkable_outline = Geometry2D.convex_hull(points)


func _collect_floor_collision_guide() -> bool:
	var guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as Node2D
	if guide == null:
		return false

	var local_points := PackedVector2Array()
	if guide is Polygon2D:
		local_points = (guide as Polygon2D).polygon
	elif guide.get("points") != null:
		local_points = guide.get("points")

	if local_points.size() < 3:
		return false

	var polygon := PackedVector2Array()
	var center := Vector2.ZERO
	for point in local_points:
		var global_point := guide.to_global(point)
		polygon.append(global_point)
		walkable_points.append(global_point)
		center += global_point

	center /= float(local_points.size())
	walkable_points.append(center)
	walkable_polygons.append(polygon)
	use_walkable_polygon_direct = true
	return true


func _build_entrance_block_polygons() -> void:
	entrance_block_polygons.clear()
	if entrance_tile_a != null:
		entrance_block_polygons.append(_tile_top_polygon(entrance_tile_a))
	if entrance_tile_b != null:
		entrance_block_polygons.append(_tile_top_polygon(entrance_tile_b))


func _is_walkable(point: Vector2) -> bool:
	if not entrance_open and _is_point_in_entrance_block(point):
		return false
	if Geometry2D.is_point_in_polygon(point, walkable_outline):
		return true
	return _is_point_near_polygon_edge(point, walkable_outline)


func _can_actor_stand_at_current_position(actor: Sprite2D) -> bool:
	if not slimes.has(actor):
		return _is_walkable(_actor_foot(actor))

	var foot := _actor_foot(actor)
	if not _is_slime_walkable_point(foot):
		return false

	var rect := _collision_rect(actor)
	var sample_y := rect.position.y + rect.size.y
	var samples := [
		Vector2(rect.position.x, sample_y),
		Vector2(rect.position.x + rect.size.x * 0.5, sample_y),
		Vector2(rect.position.x + rect.size.x, sample_y),
	]
	for sample in samples:
		if not _is_slime_walkable_point(sample):
			return false
	return true


func _is_slime_walkable_point(point: Vector2) -> bool:
	if not entrance_open and _is_point_in_entrance_block(point):
		return false
	if not Geometry2D.is_point_in_polygon(point, walkable_outline):
		return false
	return _distance_to_polygon_edge(point, walkable_outline) >= SLIME_EDGE_PADDING


func _is_point_in_entrance_block(point: Vector2) -> bool:
	for polygon in entrance_block_polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func _tile_top_polygon(tile: Sprite2D) -> PackedVector2Array:
	return PackedVector2Array([
		tile.to_global(Vector2(8, 0)),
		tile.to_global(Vector2(16, 4)),
		tile.to_global(Vector2(8, 7)),
		tile.to_global(Vector2(0, 4)),
	])


func _is_point_near_polygon_edge(point: Vector2, polygon: PackedVector2Array) -> bool:
	return _distance_to_polygon_edge(point, polygon) <= EDGE_MARGIN


func _distance_to_polygon_edge(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest_distance := INF
	for index in range(polygon.size()):
		var next_index := (index + 1) % polygon.size()
		nearest_distance = minf(nearest_distance, _distance_to_segment(point, polygon[index], polygon[next_index]))
	return nearest_distance


func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared == 0.0:
		return point.distance_to(segment_start)

	var amount := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * amount)


func _nearest_walkable_point(point: Vector2) -> Vector2:
	var nearest := walkable_points[0]
	var nearest_distance := point.distance_squared_to(nearest)
	for walkable_point in walkable_points:
		var distance := point.distance_squared_to(walkable_point)
		if distance < nearest_distance:
			nearest = walkable_point
			nearest_distance = distance
	return nearest


func _nearest_slime_walkable_point(point: Vector2) -> Vector2:
	if _is_slime_walkable_point(point):
		return point
	var nearest := _nearest_walkable_point(point)
	var nearest_distance := INF
	for walkable_point in walkable_points:
		if not _is_slime_walkable_point(walkable_point):
			continue
		var distance := point.distance_squared_to(walkable_point)
		if distance < nearest_distance:
			nearest = walkable_point
			nearest_distance = distance
	return nearest


func _clamp_actor_to_walkable(actor: Sprite2D) -> void:
	var foot := _actor_foot(actor)
	if _can_actor_stand_at_current_position(actor):
		return
	var target := _nearest_slime_walkable_point(foot) if slimes.has(actor) else _nearest_walkable_point(foot)
	actor.global_position += target - foot


func _random_walkable_point_near(point: Vector2, sample_count: int) -> Vector2:
	var nearest := _nearest_walkable_point(point)
	var candidates: Array[Vector2] = []
	for walkable_point in walkable_points:
		if walkable_point.distance_to(nearest) <= 8.0 * float(sample_count):
			candidates.append(walkable_point)

	if candidates.is_empty():
		return nearest

	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _random_slime_walkable_point_near(point: Vector2, sample_count: int, ignored_slime: Sprite2D = null) -> Vector2:
	var nearest := _nearest_slime_walkable_point(point)
	var candidates: Array[Vector2] = []
	var radius := 8.0 * float(sample_count)
	var bounds := _polygon_bounds(walkable_outline)
	for index in 24:
		var candidate := point + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if not bounds.has_point(candidate):
			continue
		if _is_slime_walkable_point(candidate) and not _is_point_near_other_slime(candidate, ignored_slime):
			candidates.append(candidate)

	for walkable_point in walkable_points:
		if not _is_slime_walkable_point(walkable_point):
			continue
		if _is_point_near_other_slime(walkable_point, ignored_slime):
			continue
		if walkable_point.distance_to(nearest) <= radius:
			candidates.append(walkable_point)

	if candidates.is_empty():
		return nearest

	return candidates[rng.randi_range(0, candidates.size() - 1)]


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
	return actor.global_position + ACTOR_FOOT_OFFSET
