extends Node
class_name PlayerAnimationComponent

signal animation_changed(name: StringName)

var animation_name: StringName = &"idle"
var frame := 0
var timer := 0.0


func play(new_name: StringName, restart := true) -> void:
	if animation_name != new_name:
		animation_name = new_name
		animation_changed.emit(animation_name)
	if restart:
		frame = 0
		timer = 0.0


func reset() -> void:
	frame = 0
	timer = 0.0


func tick_coordinator_animation(root: Object, delta: float) -> void:
	var attacking := bool(root.get("player_is_attacking"))
	var rolling := bool(root.get("player_is_rolling"))
	if attacking or rolling:
		if rolling:
			root.call("_apply_player_animation_frame")
			return
		var attack_timer := float(root.get("player_anim_timer")) + delta
		var attack_tuning := root.get("player_tuning") as PlayerTuning
		if attack_timer < attack_tuning.attack_frame_time:
			root.set("player_anim_timer", attack_timer)
			return
		attack_timer = fmod(attack_timer, attack_tuning.attack_frame_time)
		var animation_frame := int(root.get("player_anim_frame")) + 1
		var attack_name := String(root.get("player_anim_name"))
		var attack_frames := (root.get("player_attack2_frames") as Array[Texture2D]) if attack_name == "attack2" else (root.get("player_attack_frames") as Array[Texture2D])
		var hit_frame := attack_tuning.attack2_hit_frame if attack_name == "attack2" else attack_tuning.attack_hit_frame
		if animation_frame >= attack_frames.size():
			var attack_component := root.get("player_attack_component") as PlayerAttackComponent
			var combo := attack_name == "attack1" and attack_component != null and attack_component.combo_buffered and root.get("player_between_attack_texture") != null
			if attack_name == "attack2" and attack_component != null:
				attack_component.start_attack2_cooldown(attack_tuning.attack2_cooldown)
			root.set("player_just_finished_attack2", attack_name == "attack2")
			root.set("player_is_attacking", false)
			if attack_component != null: attack_component.finish()
			root.set("player_attack_hit_done", false)
			(root.get("player_attack_hit_targets") as Array[Sprite2D]).clear()
			root.call("_restore_actor_base_visual_scale", root.get("player"))
			(root.get("player") as Sprite2D).visible = true
			(root.get("player_attack_visual") as Sprite2D).visible = false
			attack_name = "walk" if bool(root.get("player_is_moving")) else "idle"
			root.set("player_anim_name", attack_name)
			root.set("player_anim_frame", 0)
			root.set("player_anim_timer", 0.0)
			root.call("_apply_player_animation_frame")
			if combo:
				root.set("player_between_timer", attack_tuning.between_attack_time)
				root.call("_set_actor_base_texture", root.get("player"), root.get("player_between_attack_texture"))
			return
		root.set("player_anim_timer", attack_timer)
		root.set("player_anim_frame", animation_frame)
		root.call("_apply_player_animation_frame")
		if animation_frame == hit_frame and not bool(root.get("player_attack_hit_done")):
			root.call("_apply_player_attack_hitbox")
			root.set("player_attack_hit_done", true)
		return
	var idle_name := "walk" if bool(root.get("player_is_moving")) else "idle"
	if String(root.get("player_anim_name")) != idle_name:
		root.set("player_anim_name", idle_name)
		root.set("player_anim_frame", 0)
		root.set("player_anim_timer", 0.0)
		root.call("_apply_player_animation_frame")
		return
	var idle_tuning := root.get("player_tuning") as PlayerTuning
	var idle_timer := float(root.get("player_anim_timer")) + delta
	var idle_frame_time := idle_tuning.walk_frame_time if idle_name == "walk" else idle_tuning.idle_frame_time
	if idle_timer < idle_frame_time:
		root.set("player_anim_timer", idle_timer)
		return
	root.set("player_anim_timer", fmod(idle_timer, idle_frame_time))
	var idle_frames := (root.get("player_walk_frames") as Array[Texture2D]) if idle_name == "walk" else (root.get("player_idle_frames") as Array[Texture2D])
	if idle_frames.is_empty(): return
	root.set("player_anim_frame", (int(root.get("player_anim_frame")) + 1) % idle_frames.size())
	root.call("_apply_player_animation_frame")


func update_attack_visual(player: Sprite2D, attack_visual: Sprite2D, active: bool, texture_offset: Vector2, z_index_value: int) -> void:
	if not active:
		attack_visual.visible = false
		return
	attack_visual.visible = true
	attack_visual.flip_h = false
	attack_visual.global_position = player.global_position + texture_offset
	attack_visual.global_scale = Vector2.ONE
	attack_visual.z_index = z_index_value
