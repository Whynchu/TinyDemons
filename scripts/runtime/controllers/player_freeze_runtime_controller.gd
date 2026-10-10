extends RefCounted

## Owns the player's frozen pose, input-edge suppression, and shake-off response.
class_name PlayerFreezeRuntimeController


static func enter_freeze_pose(root: GameplayState, animation_context: PlayerAnimationContext) -> void:
	root._interrupt_player_attack()
	if root.player_roll_component != null:
		root.player_roll_component.cancel()
	if root.player_motor != null:
		root.player_motor.end_roll()
	root.player_is_attacking = false
	root.player_is_magic_casting = false
	root.player_is_rolling = false
	root.player_is_backflipping = false
	root.player_is_defending = false
	root.player_is_moving = false
	root.player_is_running = false
	root.player_is_targeting = false
	root.player_roll_input_held = false
	root.player_roll_hold_armed = false
	root.player_between_timer = 0.0
	root.player_attack_hit_done = false
	root.player_attack_visual.visible = false
	root.player.visible = true
	root._restore_actor_base_visual_scale(root.player)
	root.player_anim_name = "idle"
	root.player_anim_frame = 0
	root.player_anim_timer = 0.0
	if root.player_animation_component != null:
		root.player_animation_component.apply_frame(animation_context)


static func sync_input_edges(root: GameplayState) -> void:
	root.player_attack_input_was_down = root._is_attack_input_pressed()
	root.player_roll_input_was_down = root._is_roll_input_pressed()
	root.player_roll_input_held = false
	root.magic_input_was_down = root._is_magic_input_pressed()
	root.interact_input_was_down = root._is_interact_input_pressed()
	root.target_input_was_down = root._is_target_input_held()


static func shake_off_on_input(root: GameplayState, status: StatusComponent, seconds_per_input: float) -> void:
	if root.input_router != null and root.input_router.consume_frozen_gameplay_input_press():
		var aura := root.player.get_node_or_null("ElementAura") as ElementAuraComponent if root.player != null else null
		if aura != null:
			aura.trigger_freeze_input_shake()
		status.shorten_applied_status_duration(&"freeze", seconds_per_input)
