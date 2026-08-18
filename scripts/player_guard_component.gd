extends Node
class_name PlayerGuardComponent

signal successful_block(shield_damage: float, health_damage: float)

const MAX_DURABILITY := 8.0
const DAMAGE_REDUCTION := 0.80
const REGEN_DELAY := 4.0
const REGEN_RATE := MAX_DURABILITY / 5.0
const BREAK_COOLDOWN := 5.0
const DAMAGE_HANG_TIME := 0.28
const DAMAGE_DRAIN_RATE := 18.0
const BAR_OFFSET := Vector2(1, 19)
const BAR_HIDE_DELAY := 1.0
const BAR_FADE_TIME := 0.24
const NORMAL_BLOCK_STUN := 0.12
const PERFECT_BLOCK_STUN := 0.45
const PERFECT_WINDOW := 0.14

var durability := MAX_DURABILITY
var maximum_durability := MAX_DURABILITY
var regen_delay_timer := 0.0
var cooldown_timer := 0.0
var facing_left := false
var facing_locked := false
var guard_active_timer := 0.0
var display_durability := MAX_DURABILITY
var damage_hold_timer := 0.0
var bar_hide_timer := 0.0
var bar_alpha := 0.0
var shield_broken_recovery := false
var frame: Sprite2D
var damage_fill: Sprite2D
var fill: Sprite2D
var fill_size := Vector2.ZERO


func initialize(root: Object) -> void:
	frame = Sprite2D.new()
	frame.name = "PlayerShieldBar"
	frame.texture = load("res://assets/artwork/HpOverhead.png") as Texture2D
	frame.centered = false
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.z_as_relative = false
	root.add_child(frame)
	fill = Sprite2D.new()
	fill.name = "PlayerShieldBarFill"
	fill.texture = _colored_texture(load("res://assets/artwork/HpOverheadBlueBar.png") as Texture2D, Color8(65, 166, 246))
	fill.centered = false
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fill.z_as_relative = false
	root.add_child(fill)
	damage_fill = Sprite2D.new()
	damage_fill.name = "PlayerShieldBarDamageFill"
	damage_fill.texture = _colored_texture(fill.texture, Color8(148, 220, 255))
	damage_fill.centered = false
	damage_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	damage_fill.z_as_relative = false
	root.add_child(damage_fill)
	fill_size = fill.texture.get_size() if fill.texture != null else Vector2(13, 3)
	_update_meter(root)


func tick(root: Object, delta: float, guard_held: bool) -> void:
	var equipment := root.get("player_equipment") as EquipmentComponent
	var shield_equipped := equipment != null and equipment.has_shield
	if not shield_equipped:
		root.set("player_is_defending", false)
		facing_locked = false
		guard_active_timer = 0.0
		bar_alpha = 0.0
		_update_meter(root)
		return
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)
		root.set("player_is_defending", false)
		guard_active_timer = 0.0
		# A broken shield rebuilds over the full lockout. It stays unusable until
		# this recovery reaches 100%, rather than becoming available early while
		# the presentation bar is still catching up.
		durability = maximum_durability * (1.0 - cooldown_timer / BREAK_COOLDOWN)
		display_durability = durability
		if cooldown_timer <= 0.0:
			durability = maximum_durability
			display_durability = maximum_durability
	else:
		var can_guard := not bool(root.get("player_dead")) and not bool(root.get("player_death_pending")) and not bool(root.get("player_is_attacking")) and not bool(root.get("player_is_rolling")) and float(root.get("player_hitstun_timer")) <= 0.0
		var should_defend := guard_held and can_guard and durability > 0.0
		if should_defend and not facing_locked:
			facing_left = bool((root.get("player") as Sprite2D).flip_h)
			facing_locked = true
		if not should_defend:
			facing_locked = false
		root.set("player_is_defending", should_defend)
		guard_active_timer = guard_active_timer + delta if should_defend else 0.0
		if should_defend:
			(root.get("player") as Sprite2D).flip_h = facing_left
		if regen_delay_timer > 0.0:
			regen_delay_timer = maxf(regen_delay_timer - delta, 0.0)
		elif durability < maximum_durability:
			durability = minf(durability + maximum_durability / 5.0 * delta, maximum_durability)
	if damage_hold_timer > 0.0:
		damage_hold_timer = maxf(damage_hold_timer - delta, 0.0)
	elif not shield_broken_recovery and display_durability > durability:
		display_durability = move_toward(display_durability, durability, DAMAGE_DRAIN_RATE * delta)
	elif not shield_broken_recovery and display_durability < durability:
		display_durability = move_toward(display_durability, durability, maximum_durability / 5.0 * delta)
	var bar_should_stay_visible := bool(root.get("player_is_defending")) or durability < maximum_durability or cooldown_timer > 0.0 or not is_equal_approx(display_durability, durability)
	if bar_should_stay_visible:
		bar_hide_timer = BAR_HIDE_DELAY
		bar_alpha = 1.0
	else:
		bar_hide_timer = maxf(bar_hide_timer - delta, 0.0)
		if bar_hide_timer <= 0.0:
			# Use discrete alpha steps so the fade keeps the chunky pixel feel.
			bar_alpha = maxf(bar_alpha - delta / BAR_FADE_TIME, 0.0)
			bar_alpha = floor(bar_alpha * 4.0) / 4.0
	_update_meter(root)


func absorb_damage(root: Object, incoming_damage: float, source_position: Vector2) -> Dictionary:
	if not bool(root.get("player_is_defending")) or cooldown_timer > 0.0 or durability <= 0.0:
		return {"health_damage": incoming_damage, "shield_damage": 0.0, "blocked": false, "perfect": false, "stun": 0.0}
	var player := root.get("player") as Sprite2D
	if player == null:
		return {"health_damage": incoming_damage, "shield_damage": 0.0, "blocked": false, "perfect": false, "stun": 0.0}
	var player_position: Vector2 = root.call("_actor_foot", player)
	var source_offset_x := source_position.x - player_position.x
	var source_is_in_front := source_offset_x <= 0.0 if facing_left else source_offset_x >= 0.0
	if not source_is_in_front:
		return {"health_damage": incoming_damage, "shield_damage": 0.0, "blocked": false, "perfect": false, "stun": 0.0}
	var equipment := root.get("player_equipment") as EquipmentComponent
	var reduction := clampf(DAMAGE_REDUCTION + (equipment.guard_damage_reduction_bonus if equipment != null else 0.0), 0.0, 0.95)
	var perfect := guard_active_timer <= PERFECT_WINDOW
	var prevented := incoming_damage * reduction
	var shield_damage := minf(prevented, durability)
	var health_damage := incoming_damage - shield_damage
	durability -= shield_damage
	regen_delay_timer = REGEN_DELAY
	damage_hold_timer = DAMAGE_HANG_TIME
	var visuals: PlayerEquipmentVisualComponent = root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if durability <= 0.001:
		durability = 0.0
		display_durability = 0.0
		cooldown_timer = BREAK_COOLDOWN
		shield_broken_recovery = true
		root.set("player_is_defending", false)
		facing_locked = false
		if visuals != null:
			visuals.break_guard(root)
	else:
		if visuals != null:
			visuals.flash_guard(root)
	_update_meter(root)
	successful_block.emit(shield_damage, health_damage)
	return {"health_damage": health_damage, "shield_damage": shield_damage, "blocked": true, "perfect": perfect, "stun": PERFECT_BLOCK_STUN if perfect else NORMAL_BLOCK_STUN}


func set_maximum_durability(value: float, preserve_ratio := true) -> void:
	var old_maximum := maxf(maximum_durability, 0.001)
	var durability_ratio := clampf(durability / old_maximum, 0.0, 1.0)
	var display_ratio := clampf(display_durability / old_maximum, 0.0, 1.0)
	maximum_durability = maxf(value, 1.0)
	durability = maximum_durability * durability_ratio if preserve_ratio else maximum_durability
	display_durability = maximum_durability * display_ratio if preserve_ratio else maximum_durability


func _update_meter(root: Object) -> void:
	if frame == null or fill == null or damage_fill == null:
		return
	var player := root.get("player") as Sprite2D
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
	var position := player.global_position + BAR_OFFSET
	frame.global_position = position
	fill.global_position = position
	damage_fill.global_position = position
	frame.z_index = int(root.get("OVERWORLD_UI_Z"))
	fill.z_index = int(root.get("OVERWORLD_UI_Z")) + 1
	damage_fill.z_index = int(root.get("OVERWORLD_UI_Z")) + 2
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
