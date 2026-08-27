extends Node
class_name PlayerAnimationComponent

var coordinator_root: Object = null
var using_baked := false
var idle_frames: Array[Texture2D] = []
var walk_frames: Array[Texture2D] = []
var defend_frames: Array[Texture2D] = []
var roll_frames: Array[Texture2D] = []
var attack_frames: Array[Texture2D] = []
var attack2_frames: Array[Texture2D] = []
var attack_left_frames: Array[Texture2D] = []
var attack2_left_frames: Array[Texture2D] = []
var spin_frames: Array[Texture2D] = []
var spin_left_frames: Array[Texture2D] = []
var magic_frames: Array[Texture2D] = []
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
var base_spin_frames: Array[Texture2D] = []
var base_spin_left_frames: Array[Texture2D] = []
var base_magic_frames: Array[Texture2D] = []
var base_between_attack_texture: Texture2D = null
var base_after_attack2_texture: Texture2D = null
var base_health_fill_texture: Texture2D = null
var frames_by_palette: Dictionary = {}


func build_frames(root: Object) -> void:
	coordinator_root = root
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary; var size := Vector2i(36, 36)
	idle_frames = library.slice_frames("res://assets/artwork/TinyDemon-idle.png", size); walk_frames = library.slice_frames("res://assets/artwork/TinyDemon-walk.png", size); defend_frames = library.slice_frames("res://assets/artwork/TinyDemon-Defend.png", size); roll_frames = library.slice_frames("res://assets/artwork/TinyDemon-roll.png", size); magic_frames = library.slice_frames("res://assets/artwork/TinyDemon-Magic.png", size)
	var raw_dust := library.slice_frames("res://assets/artwork/rolldust.png", Vector2i(16, 16)); var dust: Array[Texture2D] = []
	for index in raw_dust.size(): dust.append(library.dither_roll_dust_frame(raw_dust[index], float(index) / float(maxi(raw_dust.size(), 1))))
	root.set("roll_dust_frames", dust); root.set("roll_dust_flipped_frames", library.flip_effect_frames(dust, Vector2i(16, 16)))
	var attack_size: Vector2i = root.get("PLAYER_ATTACK_FRAME_SIZE") if root.get("PLAYER_ATTACK_FRAME_SIZE") != null else Vector2i(32, 32); attack_frames = library.slice_frames("res://assets/artwork/TinyDemon-attack1.png", attack_size); attack2_frames = library.slice_frames("res://assets/artwork/TinyDemon-attack2.png", attack_size); spin_frames = library.slice_frames("res://assets/artwork/TinyDemon-Spin_Attack.png", attack_size); if (attack2_frames as Array).is_empty(): attack2_frames = (attack_frames as Array).duplicate()
	attack_left_frames = library.flip_frames(attack_frames); attack2_left_frames = library.flip_frames(attack2_frames); spin_left_frames = library.flip_frames(spin_frames); between_attack_texture = root.call("_load_texture_or_null", "res://assets/artwork/TinyDemon-attack-between.png"); after_attack2_texture = root.call("_load_texture_or_null", "res://assets/artwork/TinyDemon-after-attack2.png")
	base_idle_frames = idle_frames.duplicate(); base_walk_frames = walk_frames.duplicate(); base_defend_frames = defend_frames.duplicate(); base_roll_frames = roll_frames.duplicate(); base_attack_frames = attack_frames.duplicate(); base_attack2_frames = attack2_frames.duplicate(); base_attack_left_frames = attack_left_frames.duplicate(); base_attack2_left_frames = attack2_left_frames.duplicate(); base_spin_frames = spin_frames.duplicate(); base_spin_left_frames = spin_left_frames.duplicate(); base_magic_frames = magic_frames.duplicate()
	base_between_attack_texture = between_attack_texture; base_after_attack2_texture = after_attack2_texture; using_baked = _detect_baked(); apply_palette(root, "blue"); precache_all_palettes(); warm_all_palette_caches(root)


func apply_frame(root: Object) -> void:
	var player := root.get("player") as Sprite2D
	var animation_key := String(root.get("player_anim_name"))
	var frame := int(root.get("player_anim_frame"))
	var frames: Array[Texture2D] = idle_frames
	if bool(root.get("player_is_rolling")):
		frames = roll_frames
	elif animation_key == "spin_attack":
		frames = spin_frames
	elif animation_key == "attack2" or animation_key == "attack2_charged":
		frames = attack2_frames
	elif animation_key == "attack1":
		frames = attack_frames
	elif animation_key == "magic":
		frames = magic_frames
	elif animation_key == "defend":
		frames = defend_frames
	elif animation_key == "walk":
		frames = walk_frames
	if animation_key == "charge":
		player.offset = Vector2(-10, -10)
		player.flip_h = bool(root.get("player_attack_flip_h"))
		_set_render_visibility(player, root.get("player_attack_visual") as Sprite2D, false)
		var charge_grey_set: Dictionary = frames_by_palette.get("grey", {})
		var charge_grey := charge_grey_set.get("between") as Texture2D
		root.call("_set_mp_grey_texture", charge_grey)
		var charge_texture := between_attack_texture if between_attack_texture != null else (attack_frames[0] if not attack_frames.is_empty() else null)
		if charge_texture != null:
			root.call("_set_actor_base_texture", player, charge_texture)
		return
	if frames.is_empty():
		return
	var grey_set: Dictionary = frames_by_palette.get("grey", {})
	if bool(root.get("player_is_rolling")):
		var roll_frame := clampi(int(root.get("player_roll_component").frame), 0, frames.size() - 1)
		var grey_roll := grey_set.get("roll", []) as Array[Texture2D]
		root.call("_set_mp_grey_texture", grey_roll[mini(roll_frame, grey_roll.size() - 1)] if not grey_roll.is_empty() else null)
		root.call("_set_actor_base_texture", player, frames[roll_frame])
		return
	var is_spin := animation_key == "spin_attack"
	var is_attack2 := animation_key == "attack2" or animation_key == "attack2_charged"
	var is_attack_animation := is_spin or is_attack2 or animation_key == "attack1"
	if is_attack_animation:
		var flip := bool(root.get("player_attack_flip_h"))
		var active_attack_frames: Array[Texture2D] = spin_left_frames if is_spin and flip else spin_frames if is_spin else attack2_left_frames if is_attack2 and flip else attack_left_frames if flip else attack2_frames if is_attack2 else attack_frames
		if active_attack_frames.is_empty():
			return
		var resolved_frame := clampi(frame, 0, active_attack_frames.size() - 1)
		var grey_key := "spin_left" if is_spin and flip else "spin" if is_spin else "attack2_left" if is_attack2 and flip else "attack_left" if flip else "attack2" if is_attack2 else "attack"
		var grey_attack := grey_set.get(grey_key, []) as Array[Texture2D]
		root.call("_set_mp_grey_texture", grey_attack[mini(resolved_frame, grey_attack.size() - 1)] if not grey_attack.is_empty() else null)
		var visual := root.get("player_attack_visual") as Sprite2D
		# Assign the new frame while the attack layer is hidden. Exposing it first
		# can render the previous attack frame for one frame as a delayed ghost.
		visual.visible = false
		visual.texture = active_attack_frames[resolved_frame]
		_set_render_visibility(player, visual, bool(root.get("player_is_attacking")))
		update_attack_visual(player, visual, bool(root.get("player_is_attacking")), Vector2(-10, -10), player.z_index)
		return
	if animation_key == "magic":
		var flip := bool(root.get("player_magic_flip_h"))
		var grey_magic := grey_set.get("magic", []) as Array[Texture2D]
		var resolved_magic_frame := clampi(frame, 0, frames.size() - 1)
		player.offset = Vector2(-10, -10)
		player.flip_h = flip
		root.call("_set_mp_grey_texture", grey_magic[mini(resolved_magic_frame, grey_magic.size() - 1)] if not grey_magic.is_empty() else null)
		_set_render_visibility(player, root.get("player_attack_visual") as Sprite2D, false)
		root.call("_set_actor_base_texture", player, frames[resolved_magic_frame])
		return
	var resolved_frame := clampi(frame, 0, frames.size() - 1)
	player.offset = Vector2(-10, -10)
	_set_render_visibility(player, root.get("player_attack_visual") as Sprite2D, false)
	var grey_frames := grey_set.get(animation_key, []) as Array[Texture2D]
	root.call("_set_mp_grey_texture", grey_frames[mini(resolved_frame, grey_frames.size() - 1)] if not grey_frames.is_empty() else null)
	root.call("_set_actor_base_texture", player, frames[resolved_frame])


func _set_transition_grey(root: Object, transition_name: String) -> void:
	var grey_set: Dictionary = frames_by_palette.get("grey", {})
	var grey_texture := grey_set.get(transition_name) as Texture2D
	if grey_texture != null:
		root.call("_set_mp_grey_texture", grey_texture)


func begin_transition(root: Object, transition_name: String, texture: Texture2D, duration: float) -> void:
	if texture == null:
		return
	root.set("player_between_timer", maxf(duration, 0.0))
	root.set("player_anim_name", transition_name)
	root.set("player_anim_frame", 0)
	root.set("player_anim_timer", 0.0)
	_set_transition_grey(root, transition_name)
	root.call("_set_actor_base_texture", root.get("player"), texture)


func apply_palette(root: Object, palette_name: String) -> void:
	_load_palette(palette_name)
	warm_player_caches(root)


func _store_palette(palette_name: String) -> void:
	frames_by_palette[palette_name] = {
		"idle": _baked_or_recolor(palette_name, "idle", base_idle_frames),
		"walk": _baked_or_recolor(palette_name, "walk", base_walk_frames),
		"defend": _baked_or_recolor(palette_name, "defend", base_defend_frames),
		"roll": _baked_or_recolor(palette_name, "roll", base_roll_frames),
		"attack": _baked_or_recolor(palette_name, "attack", base_attack_frames),
		"attack2": _baked_or_recolor(palette_name, "attack2", base_attack2_frames),
		"attack_left": _baked_or_recolor(palette_name, "attack_left", base_attack_left_frames),
		"attack2_left": _baked_or_recolor(palette_name, "attack2_left", base_attack2_left_frames),
		"spin": _baked_or_recolor(palette_name, "spin", base_spin_frames),
		"spin_left": _baked_or_recolor(palette_name, "spin_left", base_spin_left_frames),
		"magic": _baked_or_recolor(palette_name, "magic", base_magic_frames),
		"between": _baked_or_recolor_texture(palette_name, "between", base_between_attack_texture),
		"after": _baked_or_recolor_texture(palette_name, "after", base_after_attack2_texture),
	}


func _detect_baked() -> bool:
	var path := "res://assets/baked/player/blue/idle.png"
	if not ResourceLoader.exists(path):
		return false
	# Baked attack sheets use the fixed attack frame size.
	return true


## Loads a palette's animation from the baked sprite sheet if present, otherwise
## falls back to the runtime recolor of the source frames.
func _baked_or_recolor(palette_name: String, anim: String, source_frames: Array[Texture2D]) -> Array[Texture2D]:
	if not using_baked:
		return recolor_frames(source_frames, palette_name)
	var sheet_path := "res://assets/baked/player/%s/%s.png" % [palette_name, anim]
	if not ResourceLoader.exists(sheet_path):
		return recolor_frames(source_frames, palette_name)
	var frame_size := _anim_frame_size(anim)
	var frames := (coordinator_root.get("sprite_frame_library") as SpriteFrameLibrary).slice_frames(sheet_path, frame_size)
	if frames.is_empty():
		return recolor_frames(source_frames, palette_name)
	return frames


func _baked_or_recolor_texture(palette_name: String, anim: String, source_texture: Texture2D) -> Texture2D:
	if not using_baked:
		return recolor_texture(source_texture, palette_name)
	var texture_path := "res://assets/baked/player/%s/%s.png" % [palette_name, anim]
	if not ResourceLoader.exists(texture_path):
		return recolor_texture(source_texture, palette_name)
	var texture := load(texture_path) as Texture2D
	return texture if texture != null else recolor_texture(source_texture, palette_name)


func _anim_frame_size(anim: String) -> Vector2i:
	if anim == "attack" or anim == "attack2" or anim == "attack_left" or anim == "attack2_left" or anim == "spin" or anim == "spin_left":
		var attack_size: Vector2i = coordinator_root.get("PLAYER_ATTACK_FRAME_SIZE") if coordinator_root != null and coordinator_root.get("PLAYER_ATTACK_FRAME_SIZE") != null else Vector2i(36, 36)
		return attack_size
	return Vector2i(36, 36)


func _load_palette(palette_name: String) -> void:
	if not frames_by_palette.has(palette_name):
		_store_palette(palette_name)
	var palette_frames: Dictionary = frames_by_palette[palette_name]
	idle_frames = palette_frames["idle"]; walk_frames = palette_frames["walk"]; defend_frames = palette_frames["defend"]; roll_frames = palette_frames["roll"]
	attack_frames = palette_frames["attack"]; attack2_frames = palette_frames["attack2"]; attack_left_frames = palette_frames["attack_left"]; attack2_left_frames = palette_frames["attack2_left"]; spin_frames = palette_frames["spin"]; spin_left_frames = palette_frames["spin_left"]; magic_frames = palette_frames["magic"]
	between_attack_texture = palette_frames["between"]; after_attack2_texture = palette_frames["after"]


func precache_all_palettes() -> void:
	for palette_name in PaletteLibrary.PALETTE_NAMES:
		if not frames_by_palette.has(palette_name):
			_store_palette(palette_name)


func recolor_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]: return (coordinator_root.get("sprite_frame_library") as SpriteFrameLibrary).recolor_frames(frames, palette_name)
func recolor_texture(source: Texture2D, palette_name: String) -> Texture2D: return (coordinator_root.get("sprite_frame_library") as SpriteFrameLibrary).recolor_texture(source, palette_name)
func warm_texture_cache(texture: Texture2D) -> void: (coordinator_root.get("occlusion_renderer") as OcclusionRenderer).warm_actor_texture(texture)
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
	for texture in spin_frames: warm_texture_cache(texture)
	for texture in spin_left_frames: warm_texture_cache(texture)
	for texture in magic_frames: warm_texture_cache(texture)


## Warms the occlusion caches for every palette's frames at startup so that a
## runtime palette swap (fire color, or the grey-on-empty-MP state) never
## triggers a first-use image-processing hitch.  Uses the renderer's shared warm
## pass (upscale + silhouette outline computed once), so this is cheap enough to
## do for all palettes up front.
func warm_all_palette_caches(_root: Object) -> void:
	for palette_name: String in frames_by_palette:
		var palette_frames: Dictionary = frames_by_palette[palette_name]
		for texture in palette_frames.get("idle") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("walk") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("defend") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("roll") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("attack") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("attack2") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("attack2_left") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("attack_left") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("spin") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("spin_left") as Array[Texture2D]: warm_texture_cache(texture)
		for texture in palette_frames.get("magic") as Array[Texture2D]: warm_texture_cache(texture)


func apply_palette_async(root: Object, palette_name: String) -> void:
	_load_palette(palette_name)
	# All player palettes are precomputed and occlusion-warmed during startup.
	# Repeating that full cache walk during an interaction causes a visible hitch
	# when the player attunes at a flame.
	var health_texture := base_health_fill_texture as Texture2D
	if health_texture != null:
		var fill := root.get("player_health_fill") as Sprite2D; fill.texture = recolor_texture(health_texture, palette_name); var damage_fill := root.get("player_health_damage_fill") as Sprite2D
		if damage_fill != null: damage_fill.texture = (root.get("hud_controller") as HudController).brighter_bar_texture(fill.texture)


func tick_coordinator_animation(root: Object, delta: float) -> void:
	var attacking := bool(root.get("player_is_attacking"))
	var rolling := bool(root.get("player_is_rolling"))
	if bool(root.get("player_is_magic_casting")):
		apply_frame(root)
		return
	if attacking or rolling:
		if rolling:
			apply_frame(root)
			return
		if bool(root.get("orb_knockback_animation_lock")):
			if bool(root.get("orb_knockback_animation_grace")):
				# The hit callback has just displayed the attack frame. Leave it
				# visible for one animation tick before rewinding to frame 1.
				root.set("orb_knockback_animation_grace", false)
				return
			# Keep the first attack frame visible while the orb reaction owns the
			# player motion. The reaction releases this lock when knockback ends.
			root.set("player_anim_name", "attack1")
			root.set("player_anim_frame", 0)
			root.set("player_anim_timer", 0.0)
			apply_frame(root)
			return
		var attack_component := root.get("player_attack_component") as PlayerAttackComponent
		var attack_name := String(root.get("player_anim_name"))
		if attack_name == "charge" or (attack_component != null and attack_component.is_charging()):
			apply_frame(root)
			return
		var attack_tuning := root.get("player_tuning") as PlayerTuning
		var attack_multiplier := attack_tuning.attack_multiplier(float(root.get("player_spd")))
		var is_spin := attack_name == "spin_attack"
		var is_attack2 := attack_name == "attack2" or attack_name == "attack2_charged"
		var active_frames: Array[Texture2D] = spin_frames if is_spin else attack2_frames if is_attack2 else attack_frames
		if active_frames.is_empty():
			return
		var current_frame := clampi(int(root.get("player_anim_frame")), 0, active_frames.size() - 1)
		var attack_frame_time := attack_tuning.attack_frame_time
		if is_spin:
			attack_frame_time = attack_tuning.spin_recovery_frame_time if current_frame >= attack_tuning.spin_recovery_start_frame else attack_tuning.spin_frame_time
		elif attack_name == "attack2_charged":
			attack_frame_time *= attack_tuning.charged_attack2_frame_time_multiplier
		attack_frame_time = maxf(attack_frame_time / attack_multiplier, 0.001)
		var attack_timer := float(root.get("player_anim_timer")) + delta
		if attack_timer < attack_frame_time:
			root.set("player_anim_timer", attack_timer)
			return
		attack_timer = fmod(attack_timer, attack_frame_time)
		var animation_frame := current_frame + 1
		var hit_frame := attack_tuning.attack2_hit_frame if is_attack2 else attack_tuning.attack_hit_frame
		if animation_frame >= active_frames.size():
			if attack_name == "attack1" and attack_component != null and attack_component.should_enter_charge():
				attack_component.begin_charge(root)
				return
			var combo := attack_name == "attack1" and attack_component != null and attack_component.combo_buffered and between_attack_texture != null
			var attack2_finished := is_attack2
			var transition_texture: Texture2D = after_attack2_texture if attack2_finished else between_attack_texture
			var transition_time := attack_tuning.attack2_cooldown / attack_multiplier if attack2_finished else attack_tuning.between_attack_time / attack_multiplier
			if attack2_finished and attack_component != null:
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
				begin_transition(root, "after" if attack2_finished else "between", transition_texture, transition_time)
			elif combo:
				begin_transition(root, "between", between_attack_texture, attack_tuning.between_attack_time / attack_multiplier)
			else:
				root.set("player_anim_name", "walk" if bool(root.get("player_is_moving")) else "idle")
				apply_frame(root)
			return
		root.set("player_anim_timer", attack_timer)
		root.set("player_anim_frame", animation_frame)
		apply_frame(root)
		if attack_component != null and attack_component.frame_uses_hitbox(animation_frame, attack_tuning):
			root.call("_apply_player_attack_hitbox")
		elif animation_frame == hit_frame and not bool(root.get("player_attack_hit_done")):
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
	if idle_name == "walk":
		var step_frame := int(root.get("player_anim_frame"))
		# Four-frame walk cycle: trigger on visual frames 2 and 4.
		if step_frame == 1 or step_frame == 3:
			root.call("_on_player_walk_step", step_frame)
	apply_frame(root)


func update_attack_visual(player: Sprite2D, attack_visual: Sprite2D, active: bool, texture_offset: Vector2, z_index_value: int) -> void:
	if not active:
		_set_render_visibility(player, attack_visual, false)
		return
	_set_render_visibility(player, attack_visual, true)
	attack_visual.flip_h = false
	attack_visual.global_position = player.global_position + texture_offset
	attack_visual.global_scale = Vector2.ONE
	attack_visual.z_index = z_index_value


func _set_render_visibility(player: Sprite2D, attack_visual: Sprite2D, attacking: bool) -> void:
	if player != null:
		player.visible = not attacking
	if attack_visual != null:
		attack_visual.visible = attacking
