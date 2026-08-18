extends Node
class_name PlayerAnimationComponent

var coordinator_root: Object = null
var idle_frames: Array[Texture2D] = []
var walk_frames: Array[Texture2D] = []
var defend_frames: Array[Texture2D] = []
var roll_frames: Array[Texture2D] = []
var attack_frames: Array[Texture2D] = []
var attack2_frames: Array[Texture2D] = []
var attack_left_frames: Array[Texture2D] = []
var attack2_left_frames: Array[Texture2D] = []
var between_attack_texture: Texture2D = null
var after_attack2_texture: Texture2D = null
var base_idle_frames: Array[Texture2D] = []
var base_walk_frames: Array[Texture2D] = []
var base_defend_frames: Array[Texture2D] = []
var base_roll_frames: Array[Texture2D] = []
var base_attack_frames: Array[Texture2D] = []
var base_attack2_frames: Array[Texture2D] = []
var base_attack_left_frames: Array[Texture2D] = []
var base_attack2_left_frames: Array[Texture2D] = []
var base_between_attack_texture: Texture2D = null
var base_after_attack2_texture: Texture2D = null
var base_health_fill_texture: Texture2D = null


func build_frames(root: Object) -> void:
	coordinator_root = root
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary; var size := Vector2i(36, 36)
	idle_frames = library.slice_frames("res://assets/artwork/TinyDemon-idle.png", size); walk_frames = library.slice_frames("res://assets/artwork/TinyDemon-walk.png", size); defend_frames = library.slice_frames("res://assets/artwork/TinyDemon-Defend.png", size); roll_frames = library.slice_frames("res://assets/artwork/TinyDemon-roll.png", size)
	var raw_dust := library.slice_frames("res://assets/artwork/rolldust.png", Vector2i(16, 16)); var dust: Array[Texture2D] = []
	for index in raw_dust.size(): dust.append(library.dither_roll_dust_frame(raw_dust[index], float(index) / float(maxi(raw_dust.size(), 1))))
	root.set("roll_dust_frames", dust); root.set("roll_dust_flipped_frames", library.flip_effect_frames(dust, Vector2i(16, 16)))
	var attack_size: Vector2i = root.get("PLAYER_ATTACK_FRAME_SIZE") if root.get("PLAYER_ATTACK_FRAME_SIZE") != null else Vector2i(32, 32); attack_frames = library.slice_frames("res://assets/artwork/TinyDemon-attack1.png", attack_size); attack2_frames = library.slice_frames("res://assets/artwork/TinyDemon-attack2.png", attack_size); if (attack2_frames as Array).is_empty(): attack2_frames = (attack_frames as Array).duplicate()
	attack_left_frames = library.flip_frames(attack_frames); attack2_left_frames = library.flip_frames(attack2_frames); between_attack_texture = root.call("_load_texture_or_null", "res://assets/artwork/TinyDemon-attack-between.png"); after_attack2_texture = root.call("_load_texture_or_null", "res://assets/artwork/TinyDemon-after-attack2.png")
	base_idle_frames = idle_frames.duplicate(); base_walk_frames = walk_frames.duplicate(); base_defend_frames = defend_frames.duplicate(); base_roll_frames = roll_frames.duplicate(); base_attack_frames = attack_frames.duplicate(); base_attack2_frames = attack2_frames.duplicate(); base_attack_left_frames = attack_left_frames.duplicate(); base_attack2_left_frames = attack2_left_frames.duplicate()
	base_between_attack_texture = between_attack_texture; base_after_attack2_texture = after_attack2_texture; apply_palette(root, "blue"); warm_player_caches(root)


func apply_frame(root: Object) -> void:
	var player := root.get("player") as Sprite2D; var animation_key: String = root.get("player_anim_name"); var frame := int(root.get("player_anim_frame")); var frames: Array[Texture2D] = roll_frames if bool(root.get("player_is_rolling")) else attack2_frames if animation_key == "attack2" else attack_frames if animation_key == "attack1" else defend_frames if animation_key == "defend" else walk_frames if animation_key == "walk" else idle_frames
	if frames.is_empty(): return
	if bool(root.get("player_is_rolling")): root.call("_set_actor_base_texture", player, frames[int(root.get("player_roll_component").frame)]); return
	if animation_key == "attack1" or animation_key == "attack2":
		var flip: bool = root.get("player_attack_flip_h"); var active_attack_frames: Array[Texture2D] = attack2_left_frames if animation_key == "attack2" and flip else attack_left_frames if flip else attack2_frames if animation_key == "attack2" else attack_frames
		if active_attack_frames.is_empty(): return
		var visual := root.get("player_attack_visual") as Sprite2D; visual.texture = active_attack_frames[frame]; update_attack_visual(player, visual, bool(root.get("player_is_attacking")), Vector2(-10, -10), player.z_index); return
	player.offset = Vector2(-10, -10); root.call("_set_actor_base_texture", player, frames[frame])


func apply_palette(root: Object, palette_name: String) -> void:
	idle_frames = recolor_frames(base_idle_frames, palette_name); walk_frames = recolor_frames(base_walk_frames, palette_name); defend_frames = recolor_frames(base_defend_frames, palette_name); roll_frames = recolor_frames(base_roll_frames, palette_name); attack_frames = recolor_frames(base_attack_frames, palette_name); attack2_frames = recolor_frames(base_attack2_frames, palette_name); attack_left_frames = recolor_frames(base_attack_left_frames, palette_name); attack2_left_frames = recolor_frames(base_attack2_left_frames, palette_name)
	between_attack_texture = recolor_texture(base_between_attack_texture, palette_name); after_attack2_texture = recolor_texture(base_after_attack2_texture, palette_name); warm_player_caches(root)


func recolor_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]: return (coordinator_root.get("sprite_frame_library") as SpriteFrameLibrary).recolor_frames(frames, palette_name)
func recolor_texture(source: Texture2D, palette_name: String) -> Texture2D: return (coordinator_root.get("sprite_frame_library") as SpriteFrameLibrary).recolor_texture(source, palette_name)
func warm_texture_cache(texture: Texture2D) -> void: var renderer := coordinator_root.get("occlusion_renderer") as OcclusionRenderer; var image := renderer.cached_texture_image(texture); renderer.cached_effect_image(texture, image); renderer.cached_highlighted_image(texture, image); renderer.cached_white_image(texture, image)
func warm_player_caches(root: Object) -> void:
	for texture in idle_frames: warm_texture_cache(texture)
	for texture in walk_frames: warm_texture_cache(texture)
	for texture in defend_frames: warm_texture_cache(texture)
	for texture in roll_frames: warm_texture_cache(texture)
	for texture in root.get("roll_dust_frames") as Array[Texture2D]: warm_texture_cache(texture)
	for texture in root.get("roll_dust_flipped_frames") as Array[Texture2D]: warm_texture_cache(texture)
	for texture in attack_frames: warm_texture_cache(texture)
	for texture in attack2_frames: warm_texture_cache(texture)
	for texture in attack2_left_frames: warm_texture_cache(texture)
	for texture in attack_left_frames: warm_texture_cache(texture)


func apply_palette_async(root: Object, palette_name: String) -> void:
	idle_frames = recolor_frames(base_idle_frames, palette_name); await root.get_tree().process_frame
	walk_frames = recolor_frames(base_walk_frames, palette_name); await root.get_tree().process_frame
	defend_frames = recolor_frames(base_defend_frames, palette_name); await root.get_tree().process_frame
	roll_frames = recolor_frames(base_roll_frames, palette_name); await root.get_tree().process_frame
	attack_frames = recolor_frames(base_attack_frames, palette_name); attack2_frames = recolor_frames(base_attack2_frames, palette_name); await root.get_tree().process_frame
	attack_left_frames = recolor_frames(base_attack_left_frames, palette_name); attack2_left_frames = recolor_frames(base_attack2_left_frames, palette_name); between_attack_texture = recolor_texture(base_between_attack_texture, palette_name); after_attack2_texture = recolor_texture(base_after_attack2_texture, palette_name); await root.get_tree().process_frame
	var health_texture := base_health_fill_texture as Texture2D
	if health_texture != null:
		var fill := root.get("player_health_fill") as Sprite2D; fill.texture = recolor_texture(health_texture, palette_name); var damage_fill := root.get("player_health_damage_fill") as Sprite2D
		if damage_fill != null: damage_fill.texture = (root.get("hud_controller") as HudController).brighter_bar_texture(fill.texture)
	warm_player_caches(root)


func tick_coordinator_animation(root: Object, delta: float) -> void:
	var attacking := bool(root.get("player_is_attacking"))
	var rolling := bool(root.get("player_is_rolling"))
	if attacking or rolling:
		if rolling:
			apply_frame(root)
			return
		var attack_timer := float(root.get("player_anim_timer")) + delta
		var attack_tuning := root.get("player_tuning") as PlayerTuning
		var attack_multiplier := attack_tuning.attack_multiplier(int(root.get("player_spd")))
		var attack_frame_time := attack_tuning.attack_frame_time / attack_multiplier
		if attack_timer < attack_frame_time:
			root.set("player_anim_timer", attack_timer)
			return
		attack_timer = fmod(attack_timer, attack_frame_time)
		var animation_frame := int(root.get("player_anim_frame")) + 1
		var attack_name := String(root.get("player_anim_name"))
		var active_frames := attack2_frames if attack_name == "attack2" else attack_frames
		var hit_frame := attack_tuning.attack2_hit_frame if attack_name == "attack2" else attack_tuning.attack_hit_frame
		if animation_frame >= active_frames.size():
			var attack_component := root.get("player_attack_component") as PlayerAttackComponent
			var combo := attack_name == "attack1" and attack_component != null and attack_component.combo_buffered and between_attack_texture != null
			var attack2_finished := attack_name == "attack2"
			var transition_texture: Texture2D = after_attack2_texture if attack2_finished else between_attack_texture
			var transition_time := attack_tuning.attack2_cooldown / attack_multiplier if attack2_finished else attack_tuning.between_attack_time / attack_multiplier
			if attack_name == "attack2" and attack_component != null:
				attack_component.start_attack2_cooldown(attack_tuning.attack2_cooldown / attack_multiplier)
			root.set("player_just_finished_attack2", attack2_finished)
			root.set("player_is_attacking", false)
			if attack_component != null: attack_component.finish()
			root.set("player_attack_hit_done", false)
			root.call("_restore_actor_base_visual_scale", root.get("player"))
			(root.get("player") as Sprite2D).visible = true
			(root.get("player_attack_visual") as Sprite2D).visible = false
			root.set("player_anim_frame", 0)
			root.set("player_anim_timer", 0.0)
			if (attack2_finished or combo) and transition_texture != null:
				root.set("player_between_timer", transition_time)
				root.set("player_anim_name", "after" if attack2_finished else "between")
				root.call("_set_actor_base_texture", root.get("player"), transition_texture)
			elif combo:
				root.set("player_anim_name", "between")
				root.set("player_between_timer", attack_tuning.between_attack_time / attack_multiplier)
				root.call("_set_actor_base_texture", root.get("player"), between_attack_texture)
			else:
				root.set("player_anim_name", "walk" if bool(root.get("player_is_moving")) else "idle")
				apply_frame(root)
			return
		root.set("player_anim_timer", attack_timer)
		root.set("player_anim_frame", animation_frame)
		apply_frame(root)
		if animation_frame == hit_frame and not bool(root.get("player_attack_hit_done")):
			root.call("_apply_player_attack_hitbox")
			root.set("player_attack_hit_done", true)
		return
	if float(root.get("player_between_timer")) > 0.0:
		return
	var idle_name := "defend" if bool(root.get("player_is_defending")) else "walk" if bool(root.get("player_is_moving")) else "idle"
	if String(root.get("player_anim_name")) != idle_name:
		root.set("player_anim_name", idle_name)
		root.set("player_anim_frame", 0)
		root.set("player_anim_timer", 0.0)
		apply_frame(root)
		return
	var idle_tuning := root.get("player_tuning") as PlayerTuning
	var idle_timer := float(root.get("player_anim_timer")) + delta
	var idle_frame_time := idle_tuning.walk_frame_time if idle_name == "walk" or idle_name == "defend" else idle_tuning.idle_frame_time
	if idle_timer < idle_frame_time:
		root.set("player_anim_timer", idle_timer)
		return
	root.set("player_anim_timer", fmod(idle_timer, idle_frame_time))
	var idle_frame_set := defend_frames if idle_name == "defend" else walk_frames if idle_name == "walk" else idle_frames
	if idle_frame_set.is_empty(): return
	root.set("player_anim_frame", (int(root.get("player_anim_frame")) + 1) % idle_frame_set.size())
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
