extends Node
class_name PlayerAnimationComponent

signal animation_changed(name: StringName)

var animation_name: StringName = &"idle"
var frame := 0
var timer := 0.0
var coordinator_root: Object = null


func build_frames(root: Object) -> void:
	coordinator_root = root
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary; var size := Vector2i(36, 36)
	root.set("player_idle_frames", library.slice_frames("res://assets/artwork/TinyDemon-idle.png", size)); root.set("player_walk_frames", library.slice_frames("res://assets/artwork/TinyDemon-walk.png", size)); root.set("player_roll_frames", library.slice_frames("res://assets/artwork/TinyDemon-roll.png", size))
	var raw_dust := library.slice_frames("res://assets/artwork/rolldust.png", Vector2i(16, 16)); var dust: Array[Texture2D] = []
	for index in raw_dust.size(): dust.append(library.dither_roll_dust_frame(raw_dust[index], float(index) / float(maxi(raw_dust.size(), 1))))
	root.set("roll_dust_frames", dust); root.set("roll_dust_flipped_frames", library.flip_effect_frames(dust, Vector2i(16, 16)))
	var attack_size: Vector2i = root.get("PLAYER_ATTACK_FRAME_SIZE") if root.get("PLAYER_ATTACK_FRAME_SIZE") != null else Vector2i(32, 32); root.set("player_attack_frames", library.slice_frames("res://assets/artwork/TinyDemon-attack1.png", attack_size)); root.set("player_attack2_frames", library.slice_frames("res://assets/artwork/TinyDemon-attack2.png", attack_size)); if (root.get("player_attack2_frames") as Array).is_empty(): root.set("player_attack2_frames", (root.get("player_attack_frames") as Array).duplicate())
	root.set("player_attack_left_frames", library.flip_frames(root.get("player_attack_frames"))); root.set("player_attack2_left_frames", library.flip_frames(root.get("player_attack2_frames"))); root.set("player_between_attack_texture", root.call("_load_texture_or_null", "res://assets/artwork/TinyDemon-attack-between.png")); root.set("player_after_attack2_texture", root.call("_load_texture_or_null", "res://assets/artwork/TinyDemon-after-attack2.png"))
	for key in ["idle", "walk", "roll", "attack", "attack2", "attack_left", "attack2_left"]: root.set("player_base_%s_frames" % key, (root.get("player_%s_frames" % key) as Array).duplicate())
	root.set("player_base_between_attack_texture", root.get("player_between_attack_texture")); root.set("player_base_after_attack2_texture", root.get("player_after_attack2_texture")); apply_palette(root, "blue"); warm_player_caches(root)


func apply_frame(root: Object) -> void:
	var player := root.get("player") as Sprite2D; animation_name = StringName(root.get("player_anim_name")); frame = int(root.get("player_anim_frame")); timer = float(root.get("player_anim_timer")); var name: String = root.get("player_anim_name"); var frames: Array[Texture2D] = root.get("player_roll_frames") if bool(root.get("player_is_rolling")) else root.get("player_attack2_frames") if name == "attack2" else root.get("player_attack_frames") if name == "attack1" else root.get("player_walk_frames") if name == "walk" else root.get("player_idle_frames")
	if frames.is_empty(): return
	if bool(root.get("player_is_rolling")): root.call("_set_actor_base_texture", player, frames[int(root.get("player_roll_component").frame)]); return
	if name == "attack1" or name == "attack2":
		var flip: bool = root.get("player_attack_flip_h"); var attack_frames: Array[Texture2D] = root.get("player_attack2_left_frames") if name == "attack2" and flip else root.get("player_attack_left_frames") if flip else root.get("player_attack2_frames") if name == "attack2" else root.get("player_attack_frames")
		if attack_frames.is_empty(): return
		var visual := root.get("player_attack_visual") as Sprite2D; visual.texture = attack_frames[frame]; update_attack_visual(player, visual, bool(root.get("player_is_attacking")), Vector2(-10, -10), player.z_index); return
	player.offset = Vector2(-10, -10); root.call("_set_actor_base_texture", player, frames[frame])


func apply_palette(root: Object, palette_name: String) -> void:
	for key in ["idle", "walk", "roll", "attack", "attack2", "attack_left", "attack2_left"]: root.set("player_%s_frames" % key, recolor_frames(root.get("player_base_%s_frames" % key), palette_name))
	root.set("player_between_attack_texture", recolor_texture(root.get("player_base_between_attack_texture"), palette_name)); root.set("player_after_attack2_texture", recolor_texture(root.get("player_base_after_attack2_texture"), palette_name)); warm_player_caches(root)


func recolor_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]: return (coordinator_root.get("sprite_frame_library") as SpriteFrameLibrary).recolor_frames(frames, palette_name)
func recolor_texture(source: Texture2D, palette_name: String) -> Texture2D: return (coordinator_root.get("sprite_frame_library") as SpriteFrameLibrary).recolor_texture(source, palette_name)
func warm_texture_cache(texture: Texture2D) -> void: var renderer := coordinator_root.get("occlusion_renderer") as OcclusionRenderer; var image := renderer.cached_texture_image(texture); renderer.cached_effect_image(texture, image); renderer.cached_highlighted_image(texture, image); renderer.cached_white_image(texture, image)
func warm_player_caches(root: Object) -> void:
	for key in ["player_idle_frames", "player_walk_frames", "player_roll_frames", "roll_dust_frames", "roll_dust_flipped_frames", "player_attack_frames", "player_attack2_frames", "player_attack2_left_frames", "player_attack_left_frames"]:
		for texture in root.get(key) as Array[Texture2D]: warm_texture_cache(texture)


func apply_palette_async(root: Object, palette_name: String) -> void:
	root.set("player_idle_frames", recolor_frames(root.get("player_base_idle_frames"), palette_name)); await root.get_tree().process_frame
	root.set("player_walk_frames", recolor_frames(root.get("player_base_walk_frames"), palette_name)); await root.get_tree().process_frame
	root.set("player_roll_frames", recolor_frames(root.get("player_base_roll_frames"), palette_name)); await root.get_tree().process_frame
	root.set("player_attack_frames", recolor_frames(root.get("player_base_attack_frames"), palette_name)); root.set("player_attack2_frames", recolor_frames(root.get("player_base_attack2_frames"), palette_name)); await root.get_tree().process_frame
	root.set("player_attack_left_frames", recolor_frames(root.get("player_base_attack_left_frames"), palette_name)); root.set("player_attack2_left_frames", recolor_frames(root.get("player_base_attack2_left_frames"), palette_name)); root.set("player_between_attack_texture", recolor_texture(root.get("player_base_between_attack_texture"), palette_name)); root.set("player_after_attack2_texture", recolor_texture(root.get("player_base_after_attack2_texture"), palette_name)); await root.get_tree().process_frame
	var health_texture := root.get("player_base_health_fill_texture") as Texture2D
	if health_texture != null:
		var fill := root.get("player_health_fill") as Sprite2D; fill.texture = recolor_texture(health_texture, palette_name); var damage_fill := root.get("player_health_damage_fill") as Sprite2D
		if damage_fill != null: damage_fill.texture = (root.get("hud_controller") as HudController).brighter_bar_texture(fill.texture)
	warm_player_caches(root)


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
			apply_frame(root)
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
			apply_frame(root)
			if combo:
				root.set("player_between_timer", attack_tuning.between_attack_time)
				root.call("_set_actor_base_texture", root.get("player"), root.get("player_between_attack_texture"))
			return
		root.set("player_anim_timer", attack_timer)
		root.set("player_anim_frame", animation_frame)
		apply_frame(root)
		if animation_frame == hit_frame and not bool(root.get("player_attack_hit_done")):
			root.call("_apply_player_attack_hitbox")
			root.set("player_attack_hit_done", true)
		return
	var idle_name := "walk" if bool(root.get("player_is_moving")) else "idle"
	if String(root.get("player_anim_name")) != idle_name:
		root.set("player_anim_name", idle_name)
		root.set("player_anim_frame", 0)
		root.set("player_anim_timer", 0.0)
		apply_frame(root)
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
	apply_frame(root)


func update_attack_visual(player: Sprite2D, attack_visual: Sprite2D, active: bool, texture_offset: Vector2, z_index_value: int) -> void:
	if not active:
		attack_visual.visible = false
		return
	attack_visual.visible = true
	attack_visual.flip_h = false
	attack_visual.global_position = player.global_position + texture_offset
	attack_visual.global_scale = Vector2.ONE
	attack_visual.z_index = z_index_value
