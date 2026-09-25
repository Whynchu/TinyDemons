extends Node
class_name GameplayFrameController

const PHASE_INPUT := &"input"
const PHASE_SIMULATION := &"simulation"
const PHASE_CONTACT := &"contact_resolution"
const PHASE_DAMAGE := &"damage_and_progression"
const PHASE_PRESENTATION := &"presentation"
const PHASE_TRANSITIONS := &"transitions"
const PHASE_ORDER: Array[StringName] = [PHASE_INPUT, PHASE_SIMULATION, PHASE_CONTACT, PHASE_DAMAGE, PHASE_PRESENTATION, PHASE_TRANSITIONS]
## A quick click on an enemy selects it; a deliberate hold also attacks it.
const MOUSE_TARGET_HOLD_ATTACK_DELAY := 0.18

enum MouseLeftHoldMode { NONE, ATTACK, TARGET, INTERACTION }

## Opt-in diagnostics for the performance harness. Disabled by default, so the
## disabled path is a single boolean test at each context builder. Access counts
## record every request; build counts record only real constructions, so a
## cached context shows high accesses and zero builds.
static var context_diagnostics_enabled := false
static var context_access_counts: Dictionary = {}
static var context_build_counts: Dictionary = {}

## Run-scoped cache for the closure-heavy context objects. Context closures read
## live state through the root, so a context only needs rebuilding when a direct
## field's source object is replaced. `occluder_sprites` is reassigned by the
## depth sorter and is refreshed on every access; every other direct field is
## stable for the lifetime of the runtime. Call invalidate_contexts() if a source
## object such as a tuning resource or equipment component is ever swapped.
var _context_cache: Dictionary = {}
var _mouse_left_hold_mode := MouseLeftHoldMode.NONE
var _mouse_target_hold_elapsed := 0.0
var _mouse_left_attack_held := false
var _mouse_interact_input_this_frame := false
var _mouse_click_aim_direction_this_frame := Vector2.ZERO


func invalidate_contexts() -> void:
	_context_cache.clear()


static func phase_order() -> Array[StringName]:
	return PHASE_ORDER.duplicate()


static func begin_context_diagnostics() -> void:
	context_access_counts.clear()
	context_build_counts.clear()
	context_diagnostics_enabled = true


static func end_context_diagnostics() -> void:
	context_diagnostics_enabled = false


static func _record_context_access(context_name: StringName) -> void:
	if not context_diagnostics_enabled:
		return
	context_access_counts[context_name] = int(context_access_counts.get(context_name, 0)) + 1


static func _record_context_build(context_name: StringName) -> void:
	if not context_diagnostics_enabled:
		return
	context_build_counts[context_name] = int(context_build_counts.get(context_name, 0)) + 1


func animation_context(root: GameplayState) -> PlayerAnimationContext:
	_record_context_access(&"animation_context")
	var context := _context_cache.get(&"animation_context") as PlayerAnimationContext
	if context != null:
		return context
	_record_context_build(&"animation_context")
	context = PlayerAnimationContext.new()
	_context_cache[&"animation_context"] = context
	context.player = root.player
	context.actor_root = root
	context.sprite_frame_library = root.sprite_frame_library
	context.occlusion_renderer = root.occlusion_renderer
	context.hud_controller = root.hud_controller
	context.player_attack_component = root.player_attack_component
	context.player_attack_visual = root.player_attack_visual
	context.player_equipment_visual_component = root.player_equipment_visual_component
	context.player_tuning = root.player_tuning
	context.attack_frame_size = root.PLAYER_ATTACK_FRAME_SIZE
	context.current_player_palette_name_get = func() -> Variant: return root.get("current_player_palette_name")
	context.player_anim_name_get = func() -> Variant: return root.get("player_anim_name")
	context.player_anim_name_set = func(value: Variant) -> void: root.set("player_anim_name", value)
	context.player_anim_frame_get = func() -> Variant: return root.get("player_anim_frame")
	context.player_anim_frame_set = func(value: Variant) -> void: root.set("player_anim_frame", value)
	context.player_anim_timer_get = func() -> Variant: return root.get("player_anim_timer")
	context.player_anim_timer_set = func(value: Variant) -> void: root.set("player_anim_timer", value)
	context.player_between_timer_get = func() -> Variant: return root.get("player_between_timer")
	context.player_between_timer_set = func(value: Variant) -> void: root.set("player_between_timer", value)
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_attacking_set = func(value: Variant) -> void: root.set("player_is_attacking", value)
	context.player_is_moving_get = func() -> Variant: return root.get("player_is_moving")
	context.player_is_running_get = func() -> Variant: return root.get("player_is_running")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_is_defending_get = func() -> Variant: return root.get("player_is_defending")
	context.player_is_magic_casting_get = func() -> Variant: return root.get("player_is_magic_casting")
	context.player_agi_get = func() -> Variant: return root.get("player_agi")
	context.player_spd_get = func() -> Variant: return root.get("player_spd")
	context.player_attack_hit_done_get = func() -> Variant: return root.get("player_attack_hit_done")
	context.player_attack_hit_done_set = func(value: Variant) -> void: root.set("player_attack_hit_done", value)
	context.player_just_finished_attack_set = func(value: Variant) -> void: root.set("player_just_finished_attack2", value)
	context.player_attack_flip_h_get = func() -> Variant: return root.get("player_attack_flip_h")
	context.player_magic_flip_h_get = func() -> Variant: return root.get("player_magic_flip_h")
	context.player_roll_component_frame = func() -> Variant: return root.player_roll_component.frame if root.player_roll_component != null else 0
	context.orb_knockback_animation_lock_get = func() -> Variant: return root.get("orb_knockback_animation_lock")
	context.orb_knockback_animation_grace_get = func() -> Variant: return root.get("orb_knockback_animation_grace")
	context.orb_knockback_animation_grace_set = func(value: Variant) -> void: root.set("orb_knockback_animation_grace", value)
	context.player_health_fill_get = func() -> Variant: return root.get("player_health_fill")
	context.player_health_damage_fill_get = func() -> Variant: return root.get("player_health_damage_fill")
	context.roll_dust_frames_get = func() -> Variant: return root.get("roll_dust_frames")
	context.roll_dust_frames_set = func(value: Variant) -> void: root.set("roll_dust_frames", value)
	context.roll_dust_flipped_frames_get = func() -> Variant: return root.get("roll_dust_flipped_frames")
	context.roll_dust_flipped_frames_set = func(value: Variant) -> void: root.set("roll_dust_flipped_frames", value)
	context.apply_player_attack_hitbox = Callable(root, "_apply_player_attack_hitbox")
	context.load_texture_or_null = Callable(root, "_load_texture_or_null")
	context.on_player_walk_step = Callable(root, "_on_player_walk_step")
	context.restore_actor_base_visual_scale = Callable(root, "_restore_actor_base_visual_scale")
	context.set_mp_grey_texture = Callable(root, "_set_mp_grey_texture")
	context.set_actor_base_texture = Callable(root, "_set_actor_base_texture")
	context.equipment_visual_context = func() -> PlayerEquipmentVisualContext: return equipment_visual_context(root)
	return context


func equipment_visual_context(root: GameplayState) -> PlayerEquipmentVisualContext:
	_record_context_access(&"equipment_visual_context")
	var context := _context_cache.get(&"equipment_visual_context") as PlayerEquipmentVisualContext
	if context != null:
		# The depth sorter reassigns these arrays, so refresh them on each access.
		context.actor_sprites = root.actor_sprites
		context.occluder_sprites = root.occluder_sprites
		return context
	_record_context_build(&"equipment_visual_context")
	context = PlayerEquipmentVisualContext.new()
	_context_cache[&"equipment_visual_context"] = context
	context.player = root.player
	context.rest_fire = root.rest_fire
	context.cloaked_demon = root.cloaked_demon
	context.screen_state_controller = root.screen_state_controller
	context.sprite_frame_library = root.sprite_frame_library
	context.occlusion_renderer = root.occlusion_renderer
	context.effects_spawner = root.effects_spawner
	context.rng = root.rng
	context.player_equipment = root.player_equipment
	context.player_guard_component = root.player_guard_component
	context.combat_tuning = root.combat_tuning
	context.player_tuning = root.player_tuning
	context.actor_sprites = root.actor_sprites
	context.occluder_sprites = root.occluder_sprites
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_magic_casting_get = func() -> Variant: return root.get("player_is_magic_casting")
	context.player_is_defending_get = func() -> Variant: return root.get("player_is_defending")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_anim_name_get = func() -> Variant: return root.get("player_anim_name")
	context.player_anim_frame_get = func() -> Variant: return root.get("player_anim_frame")
	context.player_between_timer_get = func() -> Variant: return root.get("player_between_timer")
	context.player_death_timer_get = func() -> Variant: return root.get("player_death_timer")
	context.player_death_particles_started_get = func() -> Variant: return root.get("player_death_particles_started")
	context.player_stat_snapshot = Callable(root, "_player_stat_snapshot")
	context.equipment_occlusion_depth_key = Callable(root, "_equipment_occlusion_depth_key")
	context.sprite_source_global_rect = Callable(root, "_sprite_source_global_rect")
	context.pixel_particle_texture = Callable(root, "_pixel_particle_texture")
	context.actor_screen_scale = Callable(root, "_actor_screen_scale")
	context.actor_visual_offset = Callable(root, "_actor_visual_offset")
	return context


func magic_context(root: GameplayState) -> MagicRuntimeContext:
	_record_context_access(&"magic_context")
	var context := _context_cache.get(&"magic_context") as MagicRuntimeContext
	if context != null:
		return context
	_record_context_build(&"magic_context")
	context = MagicRuntimeContext.new()
	_context_cache[&"magic_context"] = context
	context.player = root.player
	context.slimes = root.slimes
	context.puzzle_torches = root.puzzle_torches if root.get("puzzle_torches") != null else []
	context.player_tuning = root.player_tuning
	context.combat_tuning = root.combat_tuning
	context.player_animation_component = root.player_animation_component
	context.player_chroma_component = root.player_chroma_component
	context.player_aspect_ability_component = root.player_aspect_ability_component
	context.player_equipment_visual_component = root.player_equipment_visual_component
	context.magic_projectile_controller = root.magic_projectile_controller
	context.effects_spawner = root.effects_spawner
	context.hud_controller = root.hud_controller
	context.rng = root.rng
	context.player_is_magic_casting_get = func() -> Variant: return root.get("player_is_magic_casting")
	context.player_is_magic_casting_set = func(value: Variant) -> void: root.set("player_is_magic_casting", value)
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_is_defending_get = func() -> Variant: return root.get("player_is_defending")
	context.player_dead_get = func() -> Variant: return root.get("player_dead")
	context.last_player_facing_left_get = func() -> Variant: return root.get("last_player_facing_left")
	context.last_player_input_direction_get = func() -> Variant: return root.get("last_player_input_direction")
	context.mouse_aim_active = Callable(self, "mouse_aim_active").bind(root)
	context.mouse_aim_direction = Callable(self, "mouse_aim_direction").bind(root)
	context.current_player_palette_name_get = func() -> Variant: return root.get("current_player_palette_name")
	context.player_agi_get = func() -> Variant: return root.get("player_agi")
	context.player_spd_get = func() -> Variant: return root.get("player_spd")
	context.player_mp_fill_get = func() -> Variant: return root.get("player_mp_fill")
	context.player_mp_fill_size_get = func() -> Variant: return root.get("player_mp_fill_size")
	context.player_mp_fill_size_set = func(value: Variant) -> void: root.set("player_mp_fill_size", value)
	context.player_mp_text_get = func() -> Variant: return root.get("player_mp_text")
	context.player_anim_name_set = func(value: Variant) -> void: root.set("player_anim_name", value)
	context.player_anim_frame_set = func(value: Variant) -> void: root.set("player_anim_frame", value)
	context.player_anim_timer_set = func(value: Variant) -> void: root.set("player_anim_timer", value)
	context.player_magic_flip_h_set = func(value: Variant) -> void: root.set("player_magic_flip_h", value)
	context.player_imbued_element_set = func(value: Variant) -> void: root.set("player_imbued_element", value)
	context.imbue_mp_cost = int(root.get("IMBUE_MP_COST")) if root.get("IMBUE_MP_COST") != null else 40
	context.imbue_duration = float(root.get("IMBUE_DURATION")) if root.get("IMBUE_DURATION") != null else 15.0
	context.imbue_cooldown = float(root.get("IMBUE_COOLDOWN")) if root.get("IMBUE_COOLDOWN") != null else 20.0
	context.imbue_hold_threshold = float(root.get("IMBUE_HOLD_THRESHOLD")) if root.get("IMBUE_HOLD_THRESHOLD") != null else 0.35
	context.magic_projectile_size = int(root.get("MAGIC_PROJECTILE_SIZE")) if root.get("MAGIC_PROJECTILE_SIZE") != null else 4
	context.magic_projectile_lifetime = float(root.get("MAGIC_PROJECTILE_LIFETIME")) if root.get("MAGIC_PROJECTILE_LIFETIME") != null else 0.6
	context.execute_current_aspect_ability = Callable(root, "_execute_current_aspect_ability")
	context.valid_current_target = Callable(root, "_valid_current_target")
	context.closest_target = Callable(root, "_closest_target")
	context.is_slime_targetable = Callable(root, "_is_slime_targetable")
	context.slime_body_polygon = Callable(root, "_slime_body_polygon")
	context.collision_rect = Callable(root, "_collision_rect")
	context.player_magic_damage_result_against = Callable(root, "_player_magic_damage_result_against")
	context.damage_slime_with_number = Callable(root, "_damage_slime_with_number")
	context.knockback_slime = Callable(root, "_knockback_slime")
	context.magic_hit_slime = Callable(root, "_magic_hit_slime")
	context.activate_puzzle_torch = Callable(root, "_activate_puzzle_torch")
	context.spawn_damage_number = Callable(root, "_spawn_damage_number")
	context.play_sound = Callable(root, "_play_sound")
	context.record_run_style_action = Callable(root, "_record_run_style_action")
	context.load_texture_or_null = Callable(root, "_load_texture_or_null")
	context.pixel_particle_texture = Callable(root, "_pixel_particle_texture")
	context.pixel_text_texture = Callable(root, "_pixel_text_texture")
	context.start_player_palette_flash = Callable(root, "_start_player_palette_flash")
	context.sync_chroma_presentation = Callable(root, "_sync_chroma_presentation")
	context.acknowledge_chroma_feedback = Callable(root.hud_controller, "acknowledge_chroma_use") if root.hud_controller != null else Callable()
	context.update_player_mp_ui = Callable(root, "_update_player_mp_ui")
	context.update_mp_desaturation = Callable(root, "_update_mp_desaturation")
	context.snap_half_pixel = Callable(root, "_snap_half_pixel")
	context.build_equipment_visual_context = func() -> PlayerEquipmentVisualContext: return equipment_visual_context(root)
	context.build_animation_context = func() -> PlayerAnimationContext: return animation_context(root)
	return context


func _guard_context(root: GameplayState) -> PlayerGuardContext:
	_record_context_access(&"guard_context")
	var context := _context_cache.get(&"guard_context") as PlayerGuardContext
	if context != null:
		return context
	_record_context_build(&"guard_context")
	context = PlayerGuardContext.new()
	_context_cache[&"guard_context"] = context
	context.ui_parent = root
	context.player = root.player
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
	context.build_equipment_visual_context = func() -> PlayerEquipmentVisualContext: return equipment_visual_context(root)
	return context


func _roll_context(root: GameplayState) -> PlayerRollContext:
	_record_context_access(&"roll_context")
	var context := _context_cache.get(&"roll_context") as PlayerRollContext
	if context != null:
		return context
	_record_context_build(&"roll_context")
	context = PlayerRollContext.new()
	_context_cache[&"roll_context"] = context
	context.player = root.player
	context.player_motor = root.player_motor
	context.player_animation_component = root.player_animation_component
	context.player_attack_visual = root.player_attack_visual
	context.run_state = root.run_state
	context.player_tuning = root.player_tuning
	context.player_agi_get = func() -> Variant: return root.get("player_agi")
	context.player_spd_get = func() -> Variant: return root.get("player_spd")
	context.player_is_targeting_get = func() -> Variant: return root.get("player_is_targeting")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_is_rolling_set = func(value: Variant) -> void: root.set("player_is_rolling", value)
	context.player_is_backflipping_set = func(value: Variant) -> void: root.set("player_is_backflipping", value)
	context.player_facing_left_before_target_get = func() -> Variant: return root.get("player_facing_left_before_target")
	context.last_player_facing_left_set = func(value: Variant) -> void: root.set("last_player_facing_left", value)
	context.roll_dust_spawned_this_roll_get = func() -> Variant: return root.get("roll_dust_spawned_this_roll")
	context.roll_dust_spawned_this_roll_set = func(value: Variant) -> void: root.set("roll_dust_spawned_this_roll", value)
	context.player_anim_name_set = func(value: Variant) -> void: root.set("player_anim_name", value)
	context.apply_animation_frame = func() -> void: root.player_animation_component.apply_frame(animation_context(root)) if root.player_animation_component != null else null
	context.movement_anim_name = func() -> Variant: return root.player_animation_component.movement_anim_name(animation_context(root)) if root.player_animation_component != null else ""
	context.update_motor_facing = func(direction: Vector2) -> void: root.player_motor.update_horizontal_facing(root, direction) if root.player_motor != null else null
	context.movement_input = Callable(root, "_movement_input")
	context.player_facing_vector = Callable(root, "_player_facing_vector")
	context.perspective_movement = Callable(root, "_perspective_movement")
	context.try_move_actor = Callable(root, "_try_move_actor")
	context.actor_foot = Callable(root, "_actor_foot")
	context.valid_current_target = Callable(root, "_valid_current_target")
	context.is_run_combat_active = Callable(root, "_is_run_combat_active")
	context.play_sound = Callable(root, "_play_sound")
	context.start_roll_dust = Callable(root, "_start_roll_dust")
	return context


func interaction_context(root: GameplayState) -> InteractionContext:
	_record_context_access(&"interaction_context")
	var context := _context_cache.get(&"interaction_context") as InteractionContext
	if context != null:
		return context
	_record_context_build(&"interaction_context")
	context = InteractionContext.new()
	_context_cache[&"interaction_context"] = context
	context.player = root.player
	context.chest = root.chest
	context.cloaked_demon = root.cloaked_demon
	context.npc_controller = root.npc_controller
	context.interact_prompt = root.interact_prompt
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_magic_casting_get = func() -> Variant: return root.get("player_is_magic_casting")
	context.target_input_was_down_get = func() -> Variant: return root.get("target_input_was_down")
	context.target_input_was_down_set = func(value: Variant) -> void: root.set("target_input_was_down", value)
	context.last_player_facing_left_get = func() -> Variant: return root.get("last_player_facing_left")
	context.last_player_facing_left_set = func(value: Variant) -> void: root.set("last_player_facing_left", value)
	context.actor_foot = Callable(root, "_actor_foot")
	context.is_target_input_held = Callable(root, "_is_target_input_held")
	context.set_current_target = Callable(root, "_set_current_target")
	context.set_target_ui_visible = Callable(root, "_set_target_ui_visible")
	context.closest_target = Callable(root, "_closest_target")
	context.valid_current_target = Callable(root, "_valid_current_target")
	context.is_slime_targetable = Callable(root, "_is_slime_targetable")
	context.target_cycle_direction = Callable(root, "_target_cycle_direction")
	context.cycle_target = Callable(root, "_cycle_target")
	context.update_target_ui = Callable(root, "_update_target_ui")
	context.player_facing_vector = Callable(root, "_player_facing_vector")
	context.mouse_aim_active = Callable(self, "mouse_aim_active").bind(root)
	context.mouse_aim_direction = Callable(self, "mouse_aim_direction").bind(root)
	context.can_interact_with_chest = Callable(root, "_can_interact_with_chest")
	context.can_interact_with_npc = Callable(root, "_can_interact_with_npc")
	context.can_interact_with_world_item = Callable(root, "_can_interact_with_world_item")
	context.can_interact_with_fire = Callable(root, "_can_interact_with_fire")
	context.collision_rect = Callable(root, "_collision_rect")
	context.world_item_drop_position = Callable(root, "_world_item_drop_position")
	context.cloaked_demon_head_position = Callable(root, "_cloaked_demon_head_position")
	context.fire_anchor = Callable(root, "_fire_anchor")
	context.snap_half_pixel = Callable(root, "_snap_half_pixel")
	return context


func mouse_aim_active(root: GameplayState) -> bool:
	return _mouse_click_aim_direction_this_frame.length_squared() > 0.0001 or (root.input_router != null and root.input_router.mouse_aim_active() and root.input_router.has_mouse_position())


func mouse_aim_direction(root: GameplayState) -> Vector2:
	if _mouse_click_aim_direction_this_frame.length_squared() > 0.0001:
		return _mouse_click_aim_direction_this_frame.normalized()
	if root.input_router == null or not root.input_router.mouse_aim_active() or not root.input_router.has_mouse_position() or root.player == null:
		return Vector2.ZERO
	return mouse_aim_direction_at(root, root.input_router.mouse_position())


func mouse_world_position_at(root: GameplayState, screen_position: Vector2) -> Vector2:
	return root.get_viewport().get_canvas_transform().affine_inverse() * screen_position


func mouse_aim_direction_at(root: GameplayState, screen_position: Vector2) -> Vector2:
	if root.player == null:
		return Vector2.ZERO
	var mouse_world := mouse_world_position_at(root, screen_position)
	return (mouse_world - root._actor_foot(root.player)).normalized()


func mouse_interaction_pressed() -> bool:
	return _mouse_interact_input_this_frame


func _resolve_mouse_left_click(root: GameplayState, delta: float) -> bool:
	_mouse_left_attack_held = false
	if root.input_router == null:
		_mouse_left_hold_mode = MouseLeftHoldMode.NONE
		_mouse_target_hold_elapsed = 0.0
		return false
	var click_pressed := root.input_router.consume_mouse_left_press()
	var button_held := root.input_router.mouse_left_button_pressed()
	var mouse_attack_click := false
	if click_pressed:
		var click_position := root.input_router.mouse_left_click_position()
		_mouse_click_aim_direction_this_frame = mouse_aim_direction_at(root, click_position)
		_update_mouse_facing(root)
		var world_position := mouse_world_position_at(root, click_position)
		var target: Sprite2D = root.targeting_runtime_controller.target_at_position(root, world_position)
		_mouse_target_hold_elapsed = 0.0
		if target != null:
			if not root.interaction_component.mouse_target_locked:
				root.player_facing_left_before_target = root.last_player_facing_left
			root.interaction_component.mouse_target_locked = true
			root._set_current_target(target)
			_mouse_left_hold_mode = MouseLeftHoldMode.TARGET
		elif root.interaction_component.mouse_interaction_at(interaction_context(root), world_position):
			_mouse_interact_input_this_frame = true
			_mouse_left_hold_mode = MouseLeftHoldMode.INTERACTION
		else:
			_mouse_left_hold_mode = MouseLeftHoldMode.ATTACK
			mouse_attack_click = true
	elif not button_held:
		_mouse_left_hold_mode = MouseLeftHoldMode.NONE
		_mouse_target_hold_elapsed = 0.0

	if button_held:
		if _mouse_left_hold_mode == MouseLeftHoldMode.ATTACK:
			_mouse_left_attack_held = true
		elif _mouse_left_hold_mode == MouseLeftHoldMode.TARGET:
			_mouse_target_hold_elapsed += maxf(delta, 0.0)
			_mouse_left_attack_held = _mouse_target_hold_elapsed >= MOUSE_TARGET_HOLD_ATTACK_DELAY
	elif not click_pressed:
		_mouse_left_hold_mode = MouseLeftHoldMode.NONE
		_mouse_target_hold_elapsed = 0.0
	return mouse_attack_click


func _update_mouse_facing(root: GameplayState) -> void:
	if not mouse_aim_active(root) or root.player == null:
		return
	if root.player_is_attacking or root.player_is_magic_casting or root.player_is_rolling or root.player_is_backflipping:
		return
	var direction: Vector2 = mouse_aim_direction(root)
	if absf(direction.x) <= ActorMotor.HORIZONTAL_FACING_DEADZONE:
		return
	var facing_left := direction.x < 0.0
	root.player.flip_h = facing_left
	root.last_player_facing_left = facing_left


func update_player_input(root: GameplayState, delta: float) -> void:
	var mouse_attack_click := _resolve_mouse_left_click(root, delta)
	var mouse_roll_click := root.input_router.consume_mouse_right_press() if root.input_router != null else false
	var mouse_magic_click := root.input_router.consume_mouse_middle_press() if root.input_router != null else false
	if mouse_magic_click and root.input_router != null:
		_mouse_click_aim_direction_this_frame = mouse_aim_direction_at(root, root.input_router.mouse_middle_click_position())
	_update_mouse_facing(root)
	var attack_down: bool = root._is_attack_input_pressed() or _mouse_left_attack_held; var attack := root.player_attack_component
	if attack != null:
		attack.set_attack_input_held(attack_down)
		attack.update_spin_input(root, root._raw_movement_input(), delta, not root.player_is_attacking and not root.player_is_magic_casting and not root.player_is_rolling and not root.player_is_backflipping and not root.player_is_defending)
	if (attack_down and not root.player_attack_input_was_down) or mouse_attack_click:
		var accepted_attack := false
		if not root.player_is_attacking and not root.player_is_magic_casting and not root.player_is_rolling and not root.player_is_backflipping and not root.player_is_defending and (attack == null or attack.can_start_attack2()):
			if attack != null and attack.spin_gesture.is_armed():
				accepted_attack = attack.start_spin_attack(root)
			elif attack != null and root.player_is_running:
				# A roll-continuation run commits directly to the stronger Attack 2
				# variant; it does not spend the run on a weaker opening swing.
				accepted_attack = attack.start_running_attack(root)
			elif root.player_between_timer > 0.0:
				if attack != null and not attack.combo_buffered:
					attack.buffer_combo(root.player_tuning.combo_window); attack.set_combo_movement(root._movement_input()); accepted_attack = true
			elif attack != null:
				attack.start_player_attack(root, 1); accepted_attack = true
		elif root.player_is_attacking and root.player_anim_name == "attack1" and attack != null and not attack.combo_buffered:
			attack.buffer_combo(root.player_tuning.combo_window); attack.set_combo_movement(root._movement_input()); accepted_attack = true
		root._record_run_action_input(&"attack", accepted_attack)
	root.player_attack_input_was_down = attack_down
	var roll_down: bool = root._is_roll_input_pressed() or mouse_roll_click
	if roll_down and not root.player_roll_input_was_down:
		var accepted_roll := false
		if not root.player_is_attacking and not root.player_is_magic_casting and not root.player_is_rolling and not root.player_is_backflipping and not root.player_is_defending and (root.player_motor == null or not root.player_motor.is_in_knockback()):
			var roll := root.player_roll_component
			if roll != null:
				var roll_context := _roll_context(root)
				if roll.should_backflip(roll_context):
					roll.start_backflip_from_root(roll_context)
				else:
					roll.start_from_root(roll_context)
				accepted_roll = true
		if accepted_roll:
			# Running is a continuation of this roll-button hold: while the button
			# stays held after the dodge, movement becomes a run instead of a walk.
			root.player_roll_hold_armed = true
		root._record_run_action_input(&"roll", accepted_roll)
	root.player_roll_input_was_down = roll_down
	root.player_roll_input_held = roll_down
	if not roll_down:
		root.player_roll_hold_armed = false
	var target_down: bool = root._is_target_input_held()
	if target_down and not root.target_input_was_down:
		# Remember the facing from just before the lock-on so a no-target backflip
		# retreats while keeping the player's original facing.
		root.player_facing_left_before_target = root.last_player_facing_left
		root.interaction_component.mouse_target_locked = false
	root.player_is_targeting = target_down or root.interaction_component.mouse_target_locked
	_update_magic_input(root, delta, mouse_magic_click)


func _update_magic_input(root: GameplayState, delta: float, mouse_magic_click: bool = false) -> void:
	var magic_down: bool = root._is_magic_input_pressed() or mouse_magic_click
	var accepted_magic: bool = root._update_magic_input(magic_down, root.magic_input_was_down, delta)
	if accepted_magic:
		root._record_run_action_input(&"magic", accepted_magic)
	root.magic_input_was_down = magic_down


func tick(root: GameplayState, delta: float) -> void:
	_mouse_interact_input_this_frame = false
	_mouse_click_aim_direction_this_frame = Vector2.ZERO
	if root.display_controller != null:
		root.display_controller.tick_screen_shake(delta, root.hitstop_timer > 0.0)
	root._update_mp_desaturation()
	root._update_music_state()
	if root.boot_active:
		if root.loading_screen_active: root._update_loading_screen(delta)
		return
	if root.scene_transition_active:
		var transition_timer: float = root.scene_transition_timer + delta; root.scene_transition_timer = transition_timer
		root.scene_transition_overlay.modulate.a = clampf(transition_timer / 0.28, 0.0, 1.0)
		if transition_timer >= 0.34: root.get_tree().reload_current_scene()
		return
	var ssc := root.screen_state_controller as ScreenStateController
	if ssc.save_select_overlay != null and ssc.save_select_overlay.visible:
		if ssc.save_select_footer_text != null:
			ssc.save_select_footer_text.texture = ssc._pixel_prompt_texture(Callable(root, "_pixel_text_texture"), str(root._menu_back_prompt()), Color8(148, 220, 255)) as Texture2D
		if root._is_menu_back_just_pressed():
			if ssc.save_overwrite_prompt_active: root._cancel_overwrite()
			else: root._close_save_select()
			return
		if ssc.menu_input_release_lock:
			if not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed():
				ssc.menu_input_release_lock = false
			else:
				return
		if ssc.save_overwrite_prompt_active:
			var choice := ssc.save_overwrite_choice
			if root._is_menu_direction_just_pressed(&"ui_left") or root._is_menu_direction_just_pressed(&"ui_right"):
				ssc.save_overwrite_choice = 1 - choice; root._update_overwrite_cursor(); root._play_sound("ui_hover", -6.0, 1.0)
			elif root._is_menu_confirm_just_pressed():
				if choice == 0: (ssc.save_select_overlay.get_node("OverwriteYes") as Button).pressed.emit()
				else: (ssc.save_select_overlay.get_node("OverwriteNo") as Button).pressed.emit()
			return
		var slot := ssc.save_select_index
		if root._is_menu_direction_just_pressed(&"ui_up"): slot -= 1
		elif root._is_menu_direction_just_pressed(&"ui_down"): slot += 1
		if slot != ssc.save_select_index:
			ssc.save_select_index = posmod(slot, ProfileSaveService.SLOT_COUNT)
			root._update_save_select_cursor()
			root._play_sound("ui_hover", -6.0, 1.0)
		elif root._is_menu_confirm_just_pressed():
			for child in ssc.save_select_overlay.get_children():
				if child is Button and child.has_meta("save_slot") and int(child.get_meta("save_slot")) == ssc.save_select_index:
					(child as Button).pressed.emit()
					break
		return
	if ssc.settings_overlay != null and ssc.settings_overlay.visible:
		root._update_settings_input()
		return
	if ssc.name_entry_overlay != null and ssc.name_entry_overlay.visible:
		ssc.update_name_entry_input(root)
		return
	var title_overlay := ssc.title_overlay; var archetype_overlay := ssc.archetype_overlay
	if ssc.title_transition_active or (title_overlay != null and title_overlay.visible) or (archetype_overlay != null and archetype_overlay.visible):
		root._update_title_screen(delta)
		if ssc.title_transition_active and ssc.title_transition_timer < 0.72: return
		if not ssc.title_transition_active: return
	if root.loading_screen_active: root._update_loading_screen(delta); return
	if root.walkable_outline.is_empty(): return
	var minimap := root.dungeon_minimap_controller
	var input_router := root.input_router
	if minimap != null and bool(minimap.call("is_map_open")):
		if root.effects_spawner != null:
			root.effects_spawner.resolve_item_acquisition_deliveries_if_blocked()
		if input_router != null and input_router.just_pressed(&"pause"):
			minimap.call("close_map")
			root._open_pause_menu()
			return
		minimap.call("handle_input", root)
		return
	if minimap != null and input_router != null and input_router.just_pressed(&"open_minimap") and bool(minimap.call("can_open_map", root)):
		if bool(minimap.call("open_map", root)):
			root._play_sound("ui_pause", 0.0, 1.0)
			if root.effects_spawner != null:
				root.effects_spawner.resolve_item_acquisition_deliveries_if_blocked()
		return
	var pause_overlay := ssc.pause_overlay
	if pause_overlay != null and pause_overlay.visible:
		if root._is_pause_input_just_pressed():
			root._close_hub_to_run()
			return
		root._update_pause_input()
		# The HUD remains alive above the menu. Continue ticking it so the coin
		# animation and top-bar status do not freeze while the game is paused.
		root._update_overworld_ui()
		return
	var hub_overlay := ssc.hub_overlay
	if hub_overlay != null and hub_overlay.visible:
		root._update_hub_input()
		# The HUD remains alive above the nested hub panel. Continue ticking it so
		# the coin animation and gold display do not freeze while shopping.
		root._update_overworld_ui()
		return
	var run_complete_overlay := ssc.run_complete_overlay
	if run_complete_overlay != null and run_complete_overlay.visible:
		if root.effects_spawner != null:
			root.effects_spawner.resolve_item_acquisition_deliveries_if_blocked()
		root._update_run_complete_input()
		return
	if ssc.menu_input_release_lock:
		if not root._is_menu_back_pressed() and not root._is_menu_confirm_pressed():
			ssc.menu_input_release_lock = false
		else:
			return
	# Cooldowns, combo timers, and spin-hit windows are gameplay state. Keep them
	# frozen while an overlay owns input so menu idling does not spend CPU on
	# combat bookkeeping or silently advance a paused action.
	var aspect_ability := root.player_aspect_ability_component
	if aspect_ability != null:
		aspect_ability.call("tick", delta)
	var attack := root.player_attack_component
	if attack != null: attack.tick_combo(delta); attack.tick_attack2_cooldown(delta); attack.tick_spin_hits(delta)
	# Entry Orb presentation remains alive during active gameplay and dialogue,
	# but not underneath pause/Hub/map overlays where it cannot be seen.
	root._update_entry_orb_animation(delta)
	var npc := root.npc_controller; var dialogue_was_active: bool = npc != null and npc.dialogue_box != null and npc.dialogue_box.visible
	if dialogue_was_active: npc.update_dialogue_from_root(root, delta); npc.update_dialogue_input(root); root._update_cloaked_demon_animation(delta)
	var hitstop: float = root.hitstop_timer
	if hitstop > 0.0: root.hitstop_timer = maxf(hitstop - delta, 0.0); return
	if root.player_death_pending and not root.player_dead:
		root.player_motor.update_player_hit_reaction(root, delta); root.player_equipment_visual_component.tick_death_pending(root.gameplay_frame_controller.equipment_visual_context(root)); root._update_damage_numbers(delta)
		var motor := root.player_motor
		if motor == null or not motor.is_in_knockback(): root._start_player_death()
		return
	if root.player_dead:
		if root.feedback_animation_registry != null: root.feedback_animation_registry.tick(delta)
		root.effects_spawner.update_pixel_particles_from_root(root, delta); root._update_player_death(delta); root.player_equipment_visual_component.tick_death(root.gameplay_frame_controller.equipment_visual_context(root)); root._update_damage_numbers(delta)
		var tuning := root.player_tuning
		if root.player_death_particles_started and root.player_death_timer >= tuning.death_particle_delay + tuning.death_particle_lifetime: root._move_slimes(delta); root._update_enemy_hit_flashes(delta); root._update_enemy_health(delta)
		root._update_depth_sorting(); root._update_actor_occlusion(delta); _stabilize(root); root._update_overworld_ui(); root._update_game_over_input(); return
	if root._is_pause_input_just_pressed():
		root._open_pause_menu()
		return
	var player_input_locked: bool = dialogue_was_active or root.player_is_magic_casting
	var player_tuning := root.player_tuning
	var previous_attacking: bool = root.player_is_attacking
	var previous_attack_animation := root.player_anim_name
	var guard := root.player_guard_component
	if guard != null: guard.tick(_guard_context(root), delta, not player_input_locked and root._is_guard_input_held())
	if not player_input_locked:
		update_player_input(root, delta)
	else:
		if root.input_router != null:
			root.input_router.consume_mouse_left_press()
			root.input_router.consume_mouse_right_press()
			root.input_router.consume_mouse_middle_press()
		_mouse_left_hold_mode = MouseLeftHoldMode.NONE
		_mouse_target_hold_elapsed = 0.0
		_mouse_left_attack_held = false
		if root.player_is_magic_casting or root.magic_input_was_down:
			# The shared magic animation is also the hold-to-IMBUE decision window.
			# Keep polling Triangle while that window is active, even though movement
			# and the other player actions remain locked.
			_update_magic_input(root, delta)
	player_input_locked = dialogue_was_active or root.player_is_magic_casting
	var player_attack := root.player_attack_component
	if player_attack != null and not player_input_locked:
		player_attack.tick_charge(root, delta)
	if player_attack != null and player_attack.combo_buffered and root.player_is_attacking and root.player_anim_name == "attack1":
		var movement: Vector2 = root._movement_input(); var combo_direction_changed := movement.length() > 0.25 and (player_attack.combo_movement.length() <= 0.25 or movement.normalized().dot(player_attack.combo_movement.normalized()) < 0.99)
		if combo_direction_changed: player_attack.consume_combo()
	if player_attack != null and player_attack.combo_buffered and not root.player_is_attacking and root.player_between_timer <= 0.0 and player_attack.can_start_attack2(): player_attack.start_player_attack(root, 2); player_attack.consume_combo()
	if player_attack != null: player_attack.update_lunge(root, delta)
	if root.player_roll_component != null: root.player_roll_component.update_from_root(_roll_context(root), delta)
	root._update_roll_dust(delta); root.player_motor.update_player_hit_reaction(root, delta); root._update_entry_orb_player_reaction()
	if not player_input_locked and root.player_motor != null: root.player_motor.move_player(root, delta, mouse_aim_active(root))
	root.magic_runtime_controller.tick_magic_animation(magic_context(root), delta); root.player_animation_component.tick_coordinator_animation(animation_context(root), delta); root._tick_run_telemetry(delta); root._move_slimes(delta); root._update_special_enemy_respawns(delta); root._update_enemy_hit_flashes(delta); root._update_enemy_health(delta); root._update_target_ui(); root._update_player_health_regen(delta); root._update_player_health_ui(delta); root._update_player_mp_ui(delta); root._update_magic_projectiles(delta); root._update_damage_numbers(delta); if root.feedback_animation_registry != null: root.feedback_animation_registry.tick(delta); root.effects_spawner.update_pixel_particles_from_root(root, delta); root.player_equipment_visual_component.tick(root.gameplay_frame_controller.equipment_visual_context(root), delta)
	if not dialogue_was_active:
		var chest_controller := root.chest_controller; chest_controller.update_interaction(root, root._is_interact_input_pressed(), root.interact_input_was_down, GameplayState.CHEST_REWARD_GOLD, GameplayState.CHEST_COLLECT_FLASH_TIME, delta); chest_controller.update_visuals_from_root(root, delta); root._update_world_item_drops(delta); root._update_chroma_pickups(delta); root._update_soul_pickups(delta); root.pickup_runtime_controller.update_gold_pickups(root, delta); root._update_rest_fire_animation(delta); root._update_cloaked_demon_animation(delta); root._update_door_transition(); root._update_depth_sorting(); root._update_targeting(); root._update_actor_occlusion(delta); root._update_player_palette_flash(delta); _stabilize(root)
		# The charge pose is rendered by the base player sprite. The shared attack
		# visual updater must not turn the previous attack frame back on after the
		# animation component has deliberately hidden it.
		var attack_visual_active := root.player_is_attacking and root.player_anim_name != "charge"
		root.player_animation_component.update_attack_visual(root.player, root.player_attack_visual, attack_visual_active, Vector2(-10, -10), root.player.z_index)
	else:
		root._update_player_palette_flash(delta)
	var now_attacking: bool = root.player_is_attacking
	var anim := root.player_animation_component
	if previous_attacking and not now_attacking:
		var orb_cancelled := root.orb_knockback_attack_cancelled
		root.orb_knockback_attack_cancelled = false
		if not orb_cancelled and previous_attack_animation != "spin_attack":
			# Spin owns its full recovery in the authored animation. Do not let the
			# generic attack completion bridge add a between/after pose afterward.
			var agi_value: Variant = root.player_agi
			var effective_agi := float(agi_value) if agi_value != null else float(root.player_spd)
			var attack_multiplier := player_tuning.attack_multiplier_for_agi(effective_agi)
			if root.player_just_finished_attack2 and anim.after_attack2_texture != null:
				anim.begin_transition(animation_context(root), "after", anim.after_attack2_texture, player_tuning.attack2_cooldown / attack_multiplier)
			elif (player_attack == null or not player_attack.combo_buffered) and anim.between_attack_texture != null:
				anim.begin_transition(animation_context(root), "between", anim.between_attack_texture, player_tuning.between_attack_time / attack_multiplier)
		root.player_just_finished_attack2 = false
	var between_timer: float = root.player_between_timer
	if between_timer > 0.0:
		between_timer = maxf(between_timer - delta, 0.0); root.player_between_timer = between_timer
		if between_timer <= 0.0:
			if player_attack != null and player_attack.combo_buffered and player_attack.can_start_attack2():
				player_attack.start_player_attack(root, 2); player_attack.consume_combo()
			elif not root.player_is_magic_casting and not (anim.idle_frames as Array[Texture2D]).is_empty():
				root.player_anim_name = anim.movement_anim_name(animation_context(root))
				root.player_anim_frame = 0
				root.player_anim_timer = 0.0
				anim.apply_frame(root.gameplay_frame_controller.animation_context(root))
	root._update_player_shadow(); root._update_cloaked_demon_shadow(); root._update_overworld_ui(); root._tick_focus_combo(delta); root._update_focus_indicator(delta)


func _stabilize(root: GameplayState) -> void:
	root.actor_collision_system.stabilize_guides(root.actor_sprites, Callable(root, "_update_slime_attack_guides"))
	var geometry_debug := root.actor_geometry_debug_drawer
	if geometry_debug != null: geometry_debug.refresh()
