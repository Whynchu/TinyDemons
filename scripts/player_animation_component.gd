extends Node
class_name PlayerAnimationComponent

var context: PlayerAnimationContext = null
var using_baked := false
var baked_root := "res://assets/baked/player"
var cloaked := false
var cloaked_requested := false
var frames_built := false

## Editor-facing animation tuning.
@export var magic_frame_count := 5
@export var base_frame_size := Vector2i(36, 36)
@export var attack_frame_size_export := Vector2i(36, 36)

const BAKED_ROOT := "res://assets/baked/player"
const CLOAKED_BAKED_ROOT := "res://assets/baked/player_cloaked"
const BASE_DEFEND_SHEET_PATH := "res://assets/artwork/TinyDemon-Defend.png"
const ActorPaletteMaterialScript = preload("res://scripts/actor_palette_material.gd")
const BASE_FULL_SHEET_PATH := "res://assets/artwork/TinyDemon_fullsheet.png"
const CLOAKED_SHEET_PATH := "res://assets/artwork/TinyDemon_fullsheet_cloaked.png"
const CLOAKED_DEFEND_SHEET_PATH := "res://assets/artwork/TinyDemon-Defend-Cloaked.png"
const MAGIC_FRAME_COUNT := 5
const CLOAKED_SHEET_ROWS := {
	"idle": 0,
	"walk": 1,
	"run": 2,
	"attack": 3,
	"between": 4,
	"attack2": 5,
	"after": 6,
	"roll": 7,
	"backflip": 8,
	"magic": 9,
	"spin": 10,
}
const BASE_MAGIC_SHEET_ROW := 9
const CLOAKED_FRAME_COUNTS := {
	"idle": 5,
	"walk": 4,
	"run": 4,
	"attack": 4,
	"between": 1,
	"attack2": 4,
	"after": 1,
	"roll": 6,
	"backflip": 7,
	"magic": MAGIC_FRAME_COUNT,
	"spin": 9,
}
var idle_frames: Array[Texture2D] = []
var walk_frames: Array[Texture2D] = []
var run_frames: Array[Texture2D] = []
var backflip_frames: Array[Texture2D] = []
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
var base_run_frames: Array[Texture2D] = []
var base_backflip_frames: Array[Texture2D] = []
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


func build_frames(new_context: PlayerAnimationContext) -> void:
	context = new_context
	var library := new_context.sprite_frame_library; var size := base_frame_size
	cloaked = false
	cloaked_requested = false
	_slice_shader_sources(BASE_FULL_SHEET_PATH, BASE_DEFEND_SHEET_PATH, size)
	var raw_dust := library.slice_frames("res://assets/artwork/rolldust.png", Vector2i(16, 16)); var dust: Array[Texture2D] = []
	for index in raw_dust.size(): dust.append(library.dither_roll_dust_frame(raw_dust[index], float(index) / float(maxi(raw_dust.size(), 1))))
	new_context.roll_dust_frames_set.call(dust); new_context.roll_dust_flipped_frames_set.call(library.flip_effect_frames(dust, Vector2i(16, 16)))
	baked_root = BAKED_ROOT
	using_baked = _detect_baked()
	_build_shader_palette_cache(new_context)
	frames_built = true
	_apply_cloaked_state()


## Shader path: only the grey reference set is baked. Every other palette is
## applied on the GPU, so there is no per-palette texture generation or warming.
func _build_shader_palette_cache(new_context: PlayerAnimationContext) -> void:
	frames_by_palette.clear()
	_store_palette("grey")
	warm_player_caches(new_context)
	_warm_grey_caches()


func _warm_grey_caches() -> void:
	var grey_set: Dictionary = frames_by_palette.get("grey", {})
	for key in grey_set:
		var value: Variant = grey_set[key]
		if value is Array:
			for texture: Texture2D in value as Array[Texture2D]:
				warm_texture_cache(texture)
		elif value is Texture2D:
			warm_texture_cache(value)


## Shader-source frames: the raw fullsheet rows with blank slots dropped, exactly
## like tools/bake_palettes.gd. The fullsheet carries the eye/horn highlight
## color the strip files omit, so the palette shader can darken eyes and horns
## for the green and yellow palettes, and the blank filter removes empty spin
## frames. Mirrors the offline baker's frame set so the GPU output matches the
## baked reference exactly.
func _slice_shader_sources(sheet_path: String, defend_path: String, size: Vector2i) -> void:
	var library := context.sprite_frame_library
	idle_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["idle"], size)
	walk_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["walk"], size)
	run_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["run"], size)
	backflip_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["backflip"], size)
	roll_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["roll"], size)
	magic_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["magic"], size)
	attack_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["attack"], size)
	attack2_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["attack2"], size)
	spin_frames = library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["spin"], size)
	var between_frames := library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["between"], size)
	var after_frames := library.slice_full_row_visible(sheet_path, CLOAKED_SHEET_ROWS["after"], size)
	defend_frames = library.slice_frames(defend_path, size)
	between_attack_texture = between_frames[0] if not between_frames.is_empty() else null
	after_attack2_texture = after_frames[0] if not after_frames.is_empty() else null
	attack_left_frames = library.flip_frames(attack_frames)
	attack2_left_frames = library.flip_frames(attack2_frames)
	spin_left_frames = library.flip_frames(spin_frames)
	base_idle_frames = idle_frames.duplicate(); base_walk_frames = walk_frames.duplicate(); base_run_frames = run_frames.duplicate(); base_backflip_frames = backflip_frames.duplicate(); base_defend_frames = defend_frames.duplicate(); base_roll_frames = roll_frames.duplicate(); base_attack_frames = attack_frames.duplicate(); base_attack2_frames = attack2_frames.duplicate(); base_attack_left_frames = attack_left_frames.duplicate(); base_attack2_left_frames = attack2_left_frames.duplicate(); base_spin_frames = spin_frames.duplicate(); base_spin_left_frames = spin_left_frames.duplicate(); base_magic_frames = magic_frames.duplicate()
	base_between_attack_texture = between_attack_texture; base_after_attack2_texture = after_attack2_texture


## Requests the cloaked art variant. Before the frames are built this only
## records the request; build_frames() applies it once the sources exist.
func set_cloaked(new_context: PlayerAnimationContext, enabled: bool) -> void:
	context = new_context
	cloaked_requested = enabled
	if not frames_built:
		return
	_apply_cloaked_state()


func _apply_cloaked_state() -> void:
	if cloaked == cloaked_requested:
		return
	cloaked = cloaked_requested
	var size := base_frame_size
	if cloaked:
		_slice_shader_sources(CLOAKED_SHEET_PATH, CLOAKED_DEFEND_SHEET_PATH, size)
		baked_root = CLOAKED_BAKED_ROOT
	else:
		_slice_shader_sources(BASE_FULL_SHEET_PATH, BASE_DEFEND_SHEET_PATH, size)
		baked_root = BAKED_ROOT
	using_baked = _detect_baked()
	frames_by_palette.clear()
	_build_shader_palette_cache(context)
	apply_frame(context)


## Resolves the locomotion animation name from shared root state so every
## transition (attack/magic/between recovery) returns to the correct state:
## defend > run > walk > idle.
func movement_anim_name(new_context: PlayerAnimationContext) -> String:
	if bool(new_context.player_is_defending_get.call()):
		return "defend"
	if bool(new_context.player_is_running_get.call()):
		return "run"
	if bool(new_context.player_is_moving_get.call()):
		return "walk"
	return "idle"


## Shader path: the sprite materials own the palette. Keep the swap pairs in
## sync with the active palette, gated by material metadata so the uniforms are
## only rewritten when the palette actually changes.
func _sync_material_palette(new_context: PlayerAnimationContext) -> void:
	if not new_context.current_player_palette_name_get.is_valid():
		return
	var palette_value: Variant = new_context.current_player_palette_name_get.call()
	var palette := String(palette_value) if palette_value != null else "blue"
	_apply_material_palette(new_context.player, palette)
	_apply_material_palette(new_context.player_attack_visual, palette)


func _apply_material_palette(sprite: Sprite2D, palette: String) -> void:
	if sprite == null:
		return
	var material := sprite.material as ShaderMaterial
	if material == null or material.get_meta("actor_palette", "") == palette:
		return
	ActorPaletteMaterialScript.apply_to(material, palette)
	material.set_meta("actor_palette", palette)


func apply_frame(new_context: PlayerAnimationContext) -> void:
	_sync_material_palette(new_context)
	var player := new_context.player
	var animation_key := String(new_context.player_anim_name_get.call())
	var frame := int(new_context.player_anim_frame_get.call())
	var frames: Array[Texture2D] = idle_frames
	if bool(new_context.player_is_rolling_get.call()):
		frames = roll_frames
	elif bool(new_context.player_is_backflipping_get.call()):
		frames = backflip_frames
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
	elif animation_key == "run":
		frames = run_frames
	if animation_key == "charge":
		player.offset = Vector2(-10, -10)
		player.flip_h = new_context.player_attack_flip_h_get.call()
		_set_render_visibility(player, new_context.player_attack_visual, false)
		var charge_grey_set: Dictionary = frames_by_palette.get("grey", {})
		var charge_grey := charge_grey_set.get("between") as Texture2D
		new_context.set_mp_grey_texture.call(charge_grey)
		var charge_texture := between_attack_texture if between_attack_texture != null else (attack_frames[0] if not attack_frames.is_empty() else null)
		if charge_texture != null:
			new_context.set_actor_base_texture.call(player, charge_texture)
		return
	if frames.is_empty():
		return
	var grey_set: Dictionary = frames_by_palette.get("grey", {})
	if bool(new_context.player_is_rolling_get.call()):
		var roll_frame := clampi(new_context.player_roll_component_frame.call(), 0, frames.size() - 1)
		var grey_roll := grey_set.get("roll", []) as Array[Texture2D]
		new_context.set_mp_grey_texture.call(grey_roll[mini(roll_frame, grey_roll.size() - 1)] if not grey_roll.is_empty() else null)
		new_context.set_actor_base_texture.call(player, frames[roll_frame])
		return
	if bool(new_context.player_is_backflipping_get.call()):
		var backflip_frame := clampi(new_context.player_roll_component_frame.call(), 0, frames.size() - 1)
		var grey_backflip := grey_set.get("backflip", []) as Array[Texture2D]
		new_context.set_mp_grey_texture.call(grey_backflip[mini(backflip_frame, grey_backflip.size() - 1)] if not grey_backflip.is_empty() else null)
		new_context.set_actor_base_texture.call(player, frames[backflip_frame])
		return
	var is_spin := animation_key == "spin_attack"
	var is_attack2 := animation_key == "attack2" or animation_key == "attack2_charged"
	var is_attack_animation := is_spin or is_attack2 or animation_key == "attack1"
	if is_attack_animation:
		var flip := bool(new_context.player_attack_flip_h_get.call())
		var active_attack_frames: Array[Texture2D] = spin_left_frames if is_spin and flip else spin_frames if is_spin else attack2_left_frames if is_attack2 and flip else attack_left_frames if flip else attack2_frames if is_attack2 else attack_frames
		if active_attack_frames.is_empty():
			return
		var attack_frame_index := clampi(frame, 0, active_attack_frames.size() - 1)
		var grey_key := "spin_left" if is_spin and flip else "spin" if is_spin else "attack2_left" if is_attack2 and flip else "attack_left" if flip else "attack2" if is_attack2 else "attack"
		var grey_attack := grey_set.get(grey_key, []) as Array[Texture2D]
		new_context.set_mp_grey_texture.call(grey_attack[mini(attack_frame_index, grey_attack.size() - 1)] if not grey_attack.is_empty() else null)
		var visual := new_context.player_attack_visual
		# Assign the new frame while the attack layer is hidden. Exposing it first
		# can render the previous attack frame for one frame as a delayed ghost.
		visual.visible = false
		visual.texture = active_attack_frames[attack_frame_index]
		_set_render_visibility(player, visual, bool(new_context.player_is_attacking_get.call()))
		update_attack_visual(player, visual, bool(new_context.player_is_attacking_get.call()), Vector2(-10, -10), player.z_index)
		return
	if animation_key == "magic":
		var flip := bool(new_context.player_magic_flip_h_get.call())
		var grey_magic := grey_set.get("magic", []) as Array[Texture2D]
		var resolved_magic_frame := clampi(frame, 0, frames.size() - 1)
		player.offset = Vector2(-10, -10)
		player.flip_h = flip
		new_context.set_mp_grey_texture.call(grey_magic[mini(resolved_magic_frame, grey_magic.size() - 1)] if not grey_magic.is_empty() else null)
		_set_render_visibility(player, new_context.player_attack_visual, false)
		new_context.set_actor_base_texture.call(player, frames[resolved_magic_frame])
		return
	var base_frame_index := clampi(frame, 0, frames.size() - 1)
	player.offset = Vector2(-10, -10)
	_set_render_visibility(player, new_context.player_attack_visual, false)
	var grey_frames := grey_set.get(animation_key, []) as Array[Texture2D]
	new_context.set_mp_grey_texture.call(grey_frames[mini(base_frame_index, grey_frames.size() - 1)] if not grey_frames.is_empty() else null)
	new_context.set_actor_base_texture.call(player, frames[base_frame_index])


func _set_transition_grey(new_context: PlayerAnimationContext, transition_name: String) -> void:
	var grey_set: Dictionary = frames_by_palette.get("grey", {})
	var grey_texture := grey_set.get(transition_name) as Texture2D
	if grey_texture != null:
		new_context.set_mp_grey_texture.call(grey_texture)


func begin_transition(new_context: PlayerAnimationContext, transition_name: String, texture: Texture2D, duration: float) -> void:
	if texture == null:
		return
	new_context.player_between_timer_set.call(maxf(duration, 0.0))
	new_context.player_anim_name_set.call(transition_name)
	new_context.player_anim_frame_set.call(0)
	new_context.player_anim_timer_set.call(0.0)
	_set_transition_grey(new_context, transition_name)
	new_context.set_actor_base_texture.call(new_context.player, texture)


func _store_palette(palette_name: String) -> void:
	frames_by_palette[palette_name] = {
		"idle": _baked_or_recolor(palette_name, "idle", base_idle_frames),
		"walk": _baked_or_recolor(palette_name, "walk", base_walk_frames),
		"run": _baked_or_recolor(palette_name, "run", base_run_frames),
		"backflip": _baked_or_recolor(palette_name, "backflip", base_backflip_frames),
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
	# Only the grey MP-reference set is baked; every other palette is applied by
	# the shared GPU palette-swap material, so grey is the sentinel for the
	# baked path.
	var path := "res://assets/baked/player/grey/idle.png"
	if not ResourceLoader.exists(path):
		return false
	return true


## Loads a palette's animation from the baked sprite sheet if present, otherwise
## falls back to the runtime recolor of the source frames.
func _baked_or_recolor(palette_name: String, anim: String, source_frames: Array[Texture2D]) -> Array[Texture2D]:
	if not using_baked:
		return recolor_frames(source_frames, palette_name)
	var sheet_path := "%s/%s/%s.png" % [baked_root, palette_name, anim]
	if not ResourceLoader.exists(sheet_path):
		return recolor_frames(source_frames, palette_name)
	var frame_size := _anim_frame_size(anim)
	var frames := context.sprite_frame_library.slice_frames(sheet_path, frame_size)
	if frames.is_empty():
		return recolor_frames(source_frames, palette_name)
	return frames


func _baked_or_recolor_texture(palette_name: String, anim: String, source_texture: Texture2D) -> Texture2D:
	if not using_baked:
		return recolor_texture(source_texture, palette_name)
	var texture_path := "%s/%s/%s.png" % [baked_root, palette_name, anim]
	if not ResourceLoader.exists(texture_path):
		return recolor_texture(source_texture, palette_name)
	var texture := load(texture_path) as Texture2D
	return texture if texture != null else recolor_texture(source_texture, palette_name)


func _anim_frame_size(anim: String) -> Vector2i:
	if anim == "attack" or anim == "attack2" or anim == "attack_left" or anim == "attack2_left" or anim == "spin" or anim == "spin_left":
		var attack_size: Vector2i = attack_frame_size_export
		if context != null and context.attack_frame_size != Vector2i.ZERO:
			attack_size = context.attack_frame_size
		return attack_size
	return base_frame_size


func recolor_frames(frames: Array[Texture2D], palette_name: String) -> Array[Texture2D]: return context.sprite_frame_library.recolor_frames(frames, palette_name)
func recolor_texture(source: Texture2D, palette_name: String) -> Texture2D: return context.sprite_frame_library.recolor_texture(source, palette_name)
func warm_texture_cache(texture: Texture2D) -> void: context.occlusion_renderer.warm_actor_texture(texture)
func warm_player_caches(new_context: PlayerAnimationContext) -> void:
	for texture in idle_frames: warm_texture_cache(texture)
	for texture in walk_frames: warm_texture_cache(texture)
	for texture in run_frames: warm_texture_cache(texture)
	for texture in backflip_frames: warm_texture_cache(texture)
	for texture in defend_frames: warm_texture_cache(texture)
	for texture in roll_frames: warm_texture_cache(texture)
	for texture in new_context.roll_dust_frames_get.call() as Array[Texture2D]: warm_texture_cache(texture)
	for texture in new_context.roll_dust_flipped_frames_get.call() as Array[Texture2D]: warm_texture_cache(texture)
	for texture in attack_frames: warm_texture_cache(texture)
	for texture in attack2_frames: warm_texture_cache(texture)
	for texture in attack2_left_frames: warm_texture_cache(texture)
	for texture in attack_left_frames: warm_texture_cache(texture)
	for texture in spin_frames: warm_texture_cache(texture)
	for texture in spin_left_frames: warm_texture_cache(texture)
	for texture in magic_frames: warm_texture_cache(texture)


func apply_palette_async(new_context: PlayerAnimationContext, palette_name: String) -> void:
	# Palettes are applied by the shared GPU material. Re-apply the active
	# animation state so a palette change while holding a charge refreshes the
	# pose instead of leaving the previous chroma frame on screen.
	if new_context.player != null:
		apply_frame(new_context)
	var health_texture := base_health_fill_texture as Texture2D
	if health_texture != null:
		var fill := new_context.player_health_fill_get.call() as Sprite2D; fill.texture = recolor_texture(health_texture, palette_name); var damage_fill := new_context.player_health_damage_fill_get.call() as Sprite2D
		if damage_fill != null: damage_fill.texture = new_context.hud_controller.brighter_bar_texture(fill.texture)


func tick_coordinator_animation(new_context: PlayerAnimationContext, delta: float) -> void:
	var attacking := bool(new_context.player_is_attacking_get.call())
	var rolling := bool(new_context.player_is_rolling_get.call())
	var backflipping := bool(new_context.player_is_backflipping_get.call())
	if bool(new_context.player_is_magic_casting_get.call()):
		apply_frame(new_context)
		return
	if attacking or rolling or backflipping:
		if rolling or backflipping:
			apply_frame(new_context)
			return
		if bool(new_context.orb_knockback_animation_lock_get.call()):
			if bool(new_context.orb_knockback_animation_grace_get.call()):
				# The hit callback has just displayed the attack frame. Leave it
				# visible for one animation tick before rewinding to frame 1.
				new_context.orb_knockback_animation_grace_set.call(false)
				return
			# Keep the first attack frame visible while the orb reaction owns the
			# player motion. The reaction releases this lock when knockback ends.
			new_context.player_anim_name_set.call("attack1")
			new_context.player_anim_frame_set.call(0)
			new_context.player_anim_timer_set.call(0.0)
			apply_frame(new_context)
			return
		var attack_component := new_context.player_attack_component
		var attack_name := String(new_context.player_anim_name_get.call())
		if attack_component != null and attack_component.is_charging() and attack_name != "charge":
			# The charge state owns a single authored pose. If another transition
			# briefly leaves the old attack name behind, normalize it before the
			# next draw so the last attack frame cannot remain stuck on screen.
			new_context.player_anim_name_set.call("charge")
			new_context.player_anim_frame_set.call(0)
			new_context.player_anim_timer_set.call(0.0)
			attack_name = "charge"
		if attack_name == "charge" or (attack_component != null and attack_component.is_charging()):
			apply_frame(new_context)
			return
		var attack_tuning := new_context.player_tuning
		var agi_value: Variant = new_context.player_agi_get.call()
		var effective_agi := float(agi_value) if agi_value != null else float(new_context.player_spd_get.call())
		var attack_multiplier := attack_tuning.attack_multiplier_for_agi(effective_agi)
		var is_spin := attack_name == "spin_attack"
		var is_attack2 := attack_name == "attack2" or attack_name == "attack2_charged"
		var active_frames: Array[Texture2D] = spin_frames if is_spin else attack2_frames if is_attack2 else attack_frames
		if active_frames.is_empty():
			return
		var current_frame := clampi(int(new_context.player_anim_frame_get.call()), 0, active_frames.size() - 1)
		var attack_frame_time := attack_tuning.attack_frame_time
		if is_spin:
			attack_frame_time = attack_tuning.spin_recovery_frame_time if current_frame >= attack_tuning.spin_recovery_start_frame else attack_tuning.spin_frame_time
		elif attack_name == "attack2_charged":
			attack_frame_time *= attack_tuning.charged_attack2_frame_time_multiplier
		attack_frame_time = maxf(attack_frame_time / attack_multiplier, 0.001)
		var attack_timer := float(new_context.player_anim_timer_get.call()) + delta
		if attack_timer < attack_frame_time:
			new_context.player_anim_timer_set.call(attack_timer)
			return
		attack_timer = fmod(attack_timer, attack_frame_time)
		var animation_frame := current_frame + 1
		var hit_frame := attack_tuning.attack2_hit_frame if is_attack2 else attack_tuning.attack_hit_frame
		if animation_frame >= active_frames.size():
			if is_spin:
				# Spin has no combo bridge or finisher recovery. Its final authored
				# frames are its complete recovery, then the player returns directly
				# to the normal movement/idle animation.
				new_context.player_between_timer_set.call(0.0)
				new_context.player_just_finished_attack_set.call(false)
				new_context.player_is_attacking_set.call(false)
				if attack_component != null:
					attack_component.release_spin_knockback(new_context.actor_root)
					attack_component.combo_buffered = false
					attack_component.combo_timer = 0.0
					attack_component.finish()
				new_context.player_attack_hit_done_set.call(false)
				new_context.restore_actor_base_visual_scale.call(new_context.player)
				new_context.player.visible = true
				new_context.player_attack_visual.visible = false
				new_context.player_anim_name_set.call(movement_anim_name(new_context))
				new_context.player_anim_frame_set.call(0)
				new_context.player_anim_timer_set.call(0.0)
				apply_frame(new_context)
				var equipment_visual := new_context.player_equipment_visual_component as PlayerEquipmentVisualComponent
				if equipment_visual != null:
					equipment_visual.finish_spin_attack_visual(new_context.equipment_visual_context.call())
				return
			if attack_name == "attack1" and attack_component != null and attack_component.should_enter_charge():
				attack_component.begin_charge(new_context.actor_root)
				return
			var combo := attack_name == "attack1" and attack_component != null and attack_component.combo_buffered and between_attack_texture != null
			var attack2_finished := is_attack2
			var transition_texture: Texture2D = after_attack2_texture if attack2_finished else between_attack_texture
			var attack2_recovery := attack_tuning.attack2_cooldown
			if attack2_finished and attack_component != null:
				attack2_recovery = attack_component.attack2_cooldown_duration(attack_tuning)
			var transition_time := attack2_recovery / attack_multiplier if attack2_finished else attack_tuning.between_attack_time / attack_multiplier
			if attack2_finished and attack_component != null:
				attack_component.start_attack2_cooldown(transition_time)
			new_context.player_just_finished_attack_set.call(attack2_finished)
			new_context.player_is_attacking_set.call(false)
			if attack_component != null: attack_component.finish()
			new_context.player_attack_hit_done_set.call(false)
			new_context.restore_actor_base_visual_scale.call(new_context.player)
			new_context.player.visible = true
			new_context.player_attack_visual.visible = false
			new_context.player_anim_frame_set.call(0)
			new_context.player_anim_timer_set.call(0.0)
			if (attack2_finished or combo) and transition_texture != null:
				begin_transition(new_context, "after" if attack2_finished else "between", transition_texture, transition_time)
			elif combo:
				begin_transition(new_context, "between", between_attack_texture, attack_tuning.between_attack_time / attack_multiplier)
			else:
				new_context.player_anim_name_set.call(movement_anim_name(new_context))
				apply_frame(new_context)
			return
		new_context.player_anim_timer_set.call(attack_timer)
		new_context.player_anim_frame_set.call(animation_frame)
		apply_frame(new_context)
		if attack_component != null and attack_component.frame_uses_hitbox(animation_frame, attack_tuning):
			new_context.apply_player_attack_hitbox.call()
		elif animation_frame == hit_frame and not bool(new_context.player_attack_hit_done_get.call()):
			new_context.apply_player_attack_hitbox.call()
			new_context.player_attack_hit_done_set.call(true)
		return
	if float(new_context.player_between_timer_get.call()) > 0.0:
		return
	var idle_name := "defend" if bool(new_context.player_is_defending_get.call()) else "run" if bool(new_context.player_is_running_get.call()) else "walk" if bool(new_context.player_is_moving_get.call()) else "idle"
	if String(new_context.player_anim_name_get.call()) != idle_name:
		new_context.player_anim_name_set.call(idle_name)
		new_context.player_anim_frame_set.call(0)
		new_context.player_anim_timer_set.call(0.0)
		apply_frame(new_context)
		return
	var idle_tuning := new_context.player_tuning
	var idle_timer := float(new_context.player_anim_timer_get.call()) + delta
	var idle_frame_time := idle_tuning.walk_frame_time if idle_name == "walk" or idle_name == "defend" else idle_tuning.run_frame_time if idle_name == "run" else idle_tuning.idle_frame_time
	if idle_timer < idle_frame_time:
		new_context.player_anim_timer_set.call(idle_timer)
		return
	new_context.player_anim_timer_set.call(fmod(idle_timer, idle_frame_time))
	var idle_frame_set := defend_frames if idle_name == "defend" else run_frames if idle_name == "run" else walk_frames if idle_name == "walk" else idle_frames
	if idle_frame_set.is_empty(): return
	new_context.player_anim_frame_set.call((int(new_context.player_anim_frame_get.call()) + 1) % idle_frame_set.size())
	if idle_name == "walk" or idle_name == "run":
		var step_frame := int(new_context.player_anim_frame_get.call())
		# Four-frame walk/run cycle: trigger on visual frames 2 and 4.
		if step_frame == 1 or step_frame == 3:
			new_context.on_player_walk_step.call(step_frame)
	apply_frame(new_context)


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
