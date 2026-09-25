extends Node
class_name PlayerGuardComponent

signal successful_block(shield_damage: float, health_damage: float)

const PERFECT_BLOCK_STUN_MULTIPLIER := 2.0

## Editor-facing guard tuning.
@export var max_durability := 8.0
@export var damage_reduction := 0.80
@export var regen_delay := 4.0
@export var regen_rate := 1.6
@export var break_cooldown := 5.0
@export var damage_hang_time := 0.28
@export var damage_drain_rate := 18.0
@export var bar_offset := Vector2(1, 19)
@export var bar_hide_delay := 1.0
@export var bar_fade_time := 0.24
@export var normal_block_stun := 0.12
@export var perfect_window := 0.14
@export_range(0.0, 1.0, 0.05) var blocked_player_knockback_multiplier := 0.25
@export_range(0.0, 1.5, 0.05) var block_counter_knockback_multiplier := 1.0
@export_range(0.0, 1.5, 0.05) var perfect_block_counter_knockback_multiplier := 1.5

var durability := max_durability
var maximum_durability := max_durability
var regen_delay_timer := 0.0
var cooldown_timer := 0.0
var facing_left := false
var facing_locked := false
var guard_active_timer := 0.0
var display_durability := max_durability
var damage_hold_timer := 0.0
var bar_hide_timer := 0.0
var bar_alpha := 0.0
var shield_broken_recovery := false
var frame: Sprite2D
var damage_fill: Sprite2D
var fill: Sprite2D
var fill_size := Vector2.ZERO


func initialize(context: PlayerGuardContext) -> void:
	frame = Sprite2D.new()
	frame.name = "PlayerShieldBar"
	frame.texture = load("res://assets/artwork/HpOverhead.png") as Texture2D
	frame.centered = false
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.z_as_relative = false
	context.ui_parent.add_child(frame)
	fill = Sprite2D.new()
	fill.name = "PlayerShieldBarFill"
	fill.texture = _colored_texture(load("res://assets/artwork/HpOverheadBlueBar.png") as Texture2D, PaletteLibrary.ACCENT["blue"])
	fill.centered = false
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fill.z_as_relative = false
	context.ui_parent.add_child(fill)
	damage_fill = Sprite2D.new()
	damage_fill.name = "PlayerShieldBarDamageFill"
	damage_fill.texture = _colored_texture(fill.texture, Color8(148, 220, 255))
	damage_fill.centered = false
	damage_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	damage_fill.z_as_relative = false
	context.ui_parent.add_child(damage_fill)
	fill_size = fill.texture.get_size() if fill.texture != null else Vector2(13, 3)
	_update_meter(context)


func tick(context: PlayerGuardContext, delta: float, guard_held: bool) -> void:
	var equipment := context.equipment
	var shield_equipped := equipment != null and equipment.has_shield
	if not shield_equipped:
		context.is_defending_set.call(false)
		facing_locked = false
		guard_active_timer = 0.0
		bar_alpha = 0.0
		_update_meter(context)
		return
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)
		context.is_defending_set.call(false)
		guard_active_timer = 0.0
		# A broken shield rebuilds over the full lockout. It stays unusable until
		# this recovery reaches 100%, rather than becoming available early while
		# the presentation bar is still catching up.
		durability = maximum_durability * (1.0 - cooldown_timer / break_cooldown)
		display_durability = durability
		if cooldown_timer <= 0.0:
			durability = maximum_durability
			display_durability = maximum_durability
	else:
		var can_guard := not bool(context.player_dead_get.call()) and not bool(context.player_death_pending_get.call()) and not bool(context.player_is_attacking_get.call()) and not bool(context.player_is_rolling_get.call()) and not bool(context.player_is_backflipping_get.call()) and float(context.player_hitstun_timer_get.call()) <= 0.0
		var should_defend := guard_held and can_guard and durability > 0.0
		# Lock-on owns the complete kit's facing: while targeting is held, the
		# target direction wins over the guard's remembered defend facing, so the
		# equipment and the player turn toward the locked target even mid-block.
		var targeting_holds_facing := context.player_is_targeting_get.is_valid() and bool(context.player_is_targeting_get.call())
		if should_defend and not facing_locked:
			facing_left = bool(context.player.flip_h)
			facing_locked = true
		if targeting_holds_facing:
			facing_locked = false
		if not should_defend:
			facing_locked = false
		context.is_defending_set.call(should_defend)
		guard_active_timer = guard_active_timer + delta if should_defend else 0.0
		if should_defend and not targeting_holds_facing:
			context.player.flip_h = facing_left
		if regen_delay_timer > 0.0:
			regen_delay_timer = maxf(regen_delay_timer - delta, 0.0)
		elif durability < maximum_durability:
			durability = minf(durability + regen_rate * delta, maximum_durability)
	if damage_hold_timer > 0.0:
		damage_hold_timer = maxf(damage_hold_timer - delta, 0.0)
	elif not shield_broken_recovery and display_durability > durability:
		display_durability = move_toward(display_durability, durability, damage_drain_rate * delta)
	elif not shield_broken_recovery and display_durability < durability:
		display_durability = move_toward(display_durability, durability, regen_rate * delta)
	var bar_should_stay_visible := bool(context.is_defending_get.call()) or durability < maximum_durability or cooldown_timer > 0.0 or not is_equal_approx(display_durability, durability)
	if bar_should_stay_visible:
		bar_hide_timer = bar_hide_delay
		bar_alpha = 1.0
	else:
		bar_hide_timer = maxf(bar_hide_timer - delta, 0.0)
		if bar_hide_timer <= 0.0:
			# Use discrete alpha steps so the fade keeps the chunky pixel feel.
			bar_alpha = maxf(bar_alpha - delta / bar_fade_time, 0.0)
			bar_alpha = floor(bar_alpha * 4.0) / 4.0
	_update_meter(context)


func absorb_damage(context: PlayerGuardContext, incoming_damage: float, source_position: Vector2) -> Dictionary:
	if not bool(context.is_defending_get.call()) or cooldown_timer > 0.0 or durability <= 0.0:
		return {"health_damage": incoming_damage, "shield_damage": 0.0, "blocked": false, "perfect": false, "stun": 0.0}
	var player := context.player
	if player == null:
		return {"health_damage": incoming_damage, "shield_damage": 0.0, "blocked": false, "perfect": false, "stun": 0.0}
	var player_position: Vector2 = context.actor_foot.call(player)
	var source_offset_x := source_position.x - player_position.x
	var source_is_in_front := source_offset_x <= 0.0 if facing_left else source_offset_x >= 0.0
	if not source_is_in_front:
		return {"health_damage": incoming_damage, "shield_damage": 0.0, "blocked": false, "perfect": false, "stun": 0.0}
	var equipment := context.equipment
	var reduction := clampf(damage_reduction + (equipment.guard_damage_reduction_bonus if equipment != null else 0.0), 0.0, 0.95)
	var perfect := guard_active_timer <= perfect_window
	var prevented := incoming_damage * reduction
	var shield_damage := minf(prevented, durability)
	var health_damage := incoming_damage - shield_damage
	durability -= shield_damage
	regen_delay_timer = regen_delay
	damage_hold_timer = damage_hang_time
	var visuals := context.visuals
	if durability <= 0.001:
		durability = 0.0
		display_durability = 0.0
		cooldown_timer = break_cooldown
		shield_broken_recovery = true
		context.is_defending_set.call(false)
		facing_locked = false
		if visuals != null:
			visuals.break_guard(context.build_equipment_visual_context.call() if context.build_equipment_visual_context.is_valid() else null)
	else:
		if visuals != null:
			visuals.flash_guard(context.build_equipment_visual_context.call() if context.build_equipment_visual_context.is_valid() else null)
	_update_meter(context)
	successful_block.emit(shield_damage, health_damage)
	var block_stun := normal_block_stun * PERFECT_BLOCK_STUN_MULTIPLIER if perfect else normal_block_stun
	var counter_knockback := perfect_block_counter_knockback_multiplier if perfect else block_counter_knockback_multiplier
	return {
		"health_damage": health_damage,
		"shield_damage": shield_damage,
		"blocked": true,
		"perfect": perfect,
		"stun": block_stun,
		"player_knockback_multiplier": clampf(blocked_player_knockback_multiplier, 0.0, 1.0),
		"counter_knockback_multiplier": clampf(counter_knockback, 0.0, 1.5),
	}


func set_maximum_durability(value: float, preserve_ratio := true) -> void:
	var old_maximum := maxf(maximum_durability, 0.001)
	var durability_ratio := clampf(durability / old_maximum, 0.0, 1.0)
	var display_ratio := clampf(display_durability / old_maximum, 0.0, 1.0)
	maximum_durability = maxf(value, 1.0)
	durability = maximum_durability * durability_ratio if preserve_ratio else maximum_durability
	display_durability = maximum_durability * display_ratio if preserve_ratio else maximum_durability


func _update_meter(context: PlayerGuardContext) -> void:
	if frame == null or fill == null or damage_fill == null:
		return
	var player := context.player
	if player == null:
		return
	var show := bar_alpha > 0.01
	frame.visible = show
	fill.visible = show
	damage_fill.visible = show
	frame.modulate.a = bar_alpha
	var fully_restored := is_equal_approx(display_durability, maximum_durability)
	if shield_broken_recovery and cooldown_timer <= 0.0 and fully_restored:
		shield_broken_recovery = false
	# Normal shield damage uses only the regular shield fill. The light-blue
	# layer is reserved for a broken shield's recovery cycle.
	fill.modulate.a = bar_alpha if not shield_broken_recovery or fully_restored else 0.0
	damage_fill.modulate.a = bar_alpha if shield_broken_recovery else 0.0
	var bar_position := player.global_position + bar_offset
	frame.global_position = bar_position
	fill.global_position = bar_position
	damage_fill.global_position = bar_position
	frame.z_index = context.overworld_ui_z
	fill.z_index = context.overworld_ui_z + 1
	damage_fill.z_index = context.overworld_ui_z + 2
	fill.region_enabled = true
	fill.region_rect = Rect2(Vector2.ZERO, Vector2(fill_size.x * clampf(durability / maximum_durability, 0.0, 1.0), fill_size.y))
	damage_fill.region_enabled = true
	damage_fill.region_rect = Rect2(Vector2.ZERO, Vector2(fill_size.x * clampf(display_durability / maximum_durability, 0.0, 1.0), fill_size.y))


func _colored_texture(source: Texture2D, color: Color) -> Texture2D:
	if source == null:
		return null
	var image := source.get_image().duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, pixel.a))
	return ImageTexture.create_from_image(image)
