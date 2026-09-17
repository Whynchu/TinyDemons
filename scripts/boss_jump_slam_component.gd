extends Node
class_name BossJumpSlamComponent

enum State { READY, JUMP, SLAM }

## Editor-facing phase tuning.
@export var jump_frame_count := 12
@export var slam_frame_count := 15
@export var initial_cooldown_seconds := 10.0

var state := State.READY
var cooldown := initial_cooldown_seconds
var elapsed := 0.0
var frame := -1
var launch_committed := false
var impact_resolved := false
var landing_anchor := Vector2.ZERO
var popcorn_remaining := 0
var completed_phases := 0
var base_sprite_offset := Vector2.ZERO
var airborne_offset := Vector2.ZERO
var presentation_offset := Vector2.ZERO


func is_active() -> bool:
	return state != State.READY


func tick(context: BossJumpSlamContext, slime: Sprite2D, delta: float) -> bool:
	if float(slime.get_meta("encounter_scale", 1.0)) <= 1.0:
		return false
	if state == State.READY:
		cooldown = maxf(cooldown - maxf(delta, 0.0), 0.0)
		if (_phase_health_trigger(context, slime) or cooldown <= 0.0) and _can_begin(context, slime):
			_begin(context, slime)
			return true
		return false
	elapsed += maxf(delta, 0.0)
	if state == State.JUMP:
		_tick_jump(context, slime)
	else:
		_tick_slam(context, slime)
	return true


func _can_begin(context: BossJumpSlamContext, slime: Sprite2D) -> bool:
	var combat := context.get_combat.call(slime) as SlimeCombatComponent
	return combat != null and not combat.active and combat.knockback_timer <= 0.0 and combat.hitstun_timer <= 0.0 and bool(context.is_aggroed.call(slime))


func _phase_health_trigger(_context: BossJumpSlamContext, slime: Sprite2D) -> bool:
	var health := slime.get_node_or_null("Health") as HealthComponent
	if health == null or health.maximum_health <= 0.0:
		return false
	var ratio := health.current_health / health.maximum_health
	return (completed_phases == 0 and ratio <= 0.75) or (completed_phases == 1 and ratio <= 0.40)


func _begin(context: BossJumpSlamContext, slime: Sprite2D) -> void:
	state = State.JUMP
	elapsed = 0.0
	frame = 0
	launch_committed = false
	impact_resolved = false
	completed_phases += 1
	base_sprite_offset = slime.offset
	airborne_offset = _airborne_offset(context)
	presentation_offset = base_sprite_offset
	landing_anchor = _choose_landing_anchor(context, slime)
	var combat := context.get_combat.call(slime) as SlimeCombatComponent
	combat.boss_jump_phase_active = true
	combat.boss_jump_phase_stun_resistant = true
	combat.boss_jump_phase_invulnerable = false
	_set_visual(context, slime, false)


func _tick_jump(context: BossJumpSlamContext, slime: Sprite2D) -> void:
	var next_frame := mini(int(floor(elapsed / _frame_time(context))), jump_frame_count - 1)
	if next_frame != frame:
		frame = next_frame
	# The artwork advances on authored frame boundaries, while the body and
	# shadow motion are continuous. Updating the visual transform every tick
	# prevents the slam/jump from moving in visible steps between frames.
	_set_visual(context, slime, false)
	if not launch_committed and frame >= 5:
		launch_committed = true
		var combat := context.get_combat.call(slime) as SlimeCombatComponent
		combat.boss_jump_phase_invulnerable = true
		slime.set_meta("boss_jump_ui_suppressed", true)
		if context.begin_boss_jump_phase_popcorn.is_valid():
			popcorn_remaining = int(context.begin_boss_jump_phase_popcorn.call(slime, landing_anchor))
		slime.set_meta("boss_airborne", true)
		var ordinary_shadow := slime.get_node_or_null("SlimeFloorShadow") as Sprite2D
		if ordinary_shadow != null:
			ordinary_shadow.visible = false
		if context.actor_collision_system != null:
			context.actor_collision_system.invalidate_slime_grid()
	if frame < jump_frame_count - 1:
		return
	# The boss waits in the air until the temporary phase popcorn is cleared.
	# The boss remains airborne for the entire support wave; living support
	# enemies are the only condition that keeps this phase open.
	if popcorn_remaining > 0 and context.boss_jump_phase_popcorn_alive.is_valid() and bool(context.boss_jump_phase_popcorn_alive.call(slime)):
		return
	state = State.SLAM
	elapsed = 0.0
	frame = 0
	landing_anchor = _choose_landing_anchor(context, slime)
	_move_to_landing_anchor(context, slime)
	_set_visual(context, slime, true)


func _tick_slam(context: BossJumpSlamContext, slime: Sprite2D) -> void:
	var next_frame := mini(int(floor(elapsed / _frame_time(context))), slam_frame_count - 1)
	if next_frame != frame:
		frame = next_frame
	_set_visual(context, slime, true)
	if not impact_resolved and frame >= 10:
		impact_resolved = true
		# Frame 10 is the authored ground-contact frame. Play one impact sound
		# here, alongside the slam damage, so it cannot repeat during recovery.
		if context.play_sound.is_valid():
			context.play_sound.call("bite", -5.0, 0.78)
		slime.set_meta("boss_airborne", false)
		if context.actor_collision_system != null:
			context.actor_collision_system.invalidate_slime_grid()
		if context.apply_boss_jump_slam.is_valid():
			context.apply_boss_jump_slam.call(slime, landing_anchor)
	if frame < slam_frame_count - 1:
		return
	state = State.READY
	var random_source := context.rng
	var tuning := context.slime_tuning
	cooldown = random_source.randf_range(tuning.boss_jump_repeat_cooldown_min, tuning.boss_jump_repeat_cooldown_max) if random_source != null else tuning.boss_jump_repeat_cooldown_min
	frame = -1
	var combat := context.get_combat.call(slime) as SlimeCombatComponent
	combat.clear_boss_jump_phase()
	slime.set_meta("boss_airborne", false)
	slime.self_modulate.a = 1.0
	slime.offset = base_sprite_offset
	presentation_offset = base_sprite_offset
	slime.set_meta("boss_jump_ui_suppressed", false)
	_set_visual(context, slime, false)
	if context.restore_idle_texture.is_valid():
		context.restore_idle_texture.call(slime)
	var ordinary_shadow := slime.get_node_or_null("SlimeFloorShadow") as Sprite2D
	if ordinary_shadow != null:
		ordinary_shadow.visible = true
	if context.clear_boss_jump_phase_popcorn.is_valid():
		context.clear_boss_jump_phase_popcorn.call(slime)


func _frame_time(context: BossJumpSlamContext) -> float:
	return context.slime_tuning.boss_jump_frame_time


func _choose_landing_anchor(context: BossJumpSlamContext, slime: Sprite2D) -> Vector2:
	var player := context.player
	var origin: Vector2 = context.slime_shadow_anchor.call(slime)
	if player == null:
		return origin
	var player_foot: Vector2 = context.actor_foot.call(player)
	return context.nearest_slime_walkable_point.call(player_foot) as Vector2


func _move_to_landing_anchor(context: BossJumpSlamContext, slime: Sprite2D) -> void:
	var anchor_offset: Vector2 = (context.slime_shadow_anchor.call(slime) as Vector2) - slime.global_position
	slime.global_position = landing_anchor - anchor_offset


func _set_visual(context: BossJumpSlamContext, slime: Sprite2D, slam: bool) -> void:
	var visual := context.get_visual.call(slime) as SlimeVisualComponent
	if visual == null:
		return
	var frames := visual.boss_slam_frames if slam else visual.boss_jump_frames
	if frame >= 0 and frame < frames.size():
		context.set_actor_base_texture.call(slime, frames[frame])
	if slam:
		# Slam frame 10 is the authored landing/impact frame. Recovery frames
		# 11-14 stay grounded rather than continuing to descend.
		var descent_progress := clampf(elapsed / (_frame_time(context) * 10.0), 0.0, 1.0)
		presentation_offset = base_sprite_offset + airborne_offset * (1.0 - descent_progress)
	else:
		# Frames 0-4 are a strictly grounded telegraph. Movement begins only
		# when frame 5 is reached, so faster playback cannot advance the launch.
		if frame <= 4:
			presentation_offset = base_sprite_offset
		else:
			var jump_progress := clampf((elapsed - _frame_time(context) * 5.0) / (_frame_time(context) * float(jump_frame_count - 1 - 5)), 0.0, 1.0)
			var eased_progress := sin(jump_progress * PI * 0.5)
			presentation_offset = base_sprite_offset + airborne_offset * eased_progress
	slime.offset = presentation_offset
	var shadow := slime.get_node_or_null("BossFloorShadow") as Sprite2D
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.name = "BossFloorShadow"
		shadow.centered = false
		slime.add_child(shadow)
	if slam:
		shadow.texture = visual.boss_shadow_slam_frames[clampi(frame, 0, visual.boss_shadow_slam_frames.size() - 1)] if not visual.boss_shadow_slam_frames.is_empty() else visual.boss_shadow_left_texture
	else:
		shadow.texture = visual.boss_shadow_jump_frames[clampi(frame, 0, visual.boss_shadow_jump_frames.size() - 1)] if not visual.boss_shadow_jump_frames.is_empty() else visual.boss_shadow_left_texture
	# This warning shadow is a world-space floor marker. It must stay at the
	# selected landing anchor while the boss sprite rises or descends, rather
	# than inheriting the boss's current position and squash transform.
	shadow.top_level = true
	shadow.global_position = landing_anchor - ActorGeometry.slime_floor_canvas_point(slime)
	shadow.scale = Vector2.ONE
	shadow.visible = is_active() and slam
	shadow.self_modulate = Color(1.0, 1.0, 1.0, 0.25)
	shadow.z_index = -1


func _airborne_offset(context: BossJumpSlamContext) -> Vector2:
	# The boss should read as a jump in the room, not disappear above the
	# viewport. The animated shadow remains on the floor anchor while the body
	# rises by this authored world-space amount and descends back to contact.
	return Vector2(0.0, -maxf(context.slime_tuning.boss_jump_height, 1.0))
