extends Node
class_name HudController

signal target_changed(target: Node)

var current_target: Node = null
var target_health_fill_textures: Dictionary = {}
var target_health_damage_fill_textures: Dictionary = {}
var target_overhead_fill_textures: Dictionary = {}
var target_overhead_damage_fill_textures: Dictionary = {}
var target_overhead_frames: Dictionary = {}
var target_overhead_damage_fills: Dictionary = {}
var target_overhead_fills: Dictionary = {}
var target_overhead_offsets: Dictionary = {}
var target_overhead_fill_sizes: Dictionary = {}
var target_overhead_aggro_markers: Dictionary = {}
var bright_bar_cache: Dictionary = {}


func set_target(target: Node) -> void:
	if current_target == target:
		return
	current_target = target
	target_changed.emit(target)


func set_visible(target_name: CanvasItem, target_bar: CanvasItem, target_damage_fill: CanvasItem, target_fill: CanvasItem, target_health_text: CanvasItem, visible: bool) -> void:
	target_name.visible = visible
	target_bar.visible = visible
	if target_damage_fill != null:
		target_damage_fill.visible = visible
	target_fill.visible = visible
	if target_health_text != null:
		target_health_text.visible = visible


func update_target_ui(target: Sprite2D, target_name: Sprite2D, target_bar: Sprite2D, target_damage_fill: Sprite2D, target_fill: Sprite2D, target_health_text: Sprite2D, bar_size: Vector2, display_name: Callable, max_health_for: Callable, health_for: Callable, display_health_for: Callable, pixel_name: Callable, pixel_number: Callable, set_values: Callable) -> Vector2:
	if target == null: return bar_size
	target_name.texture = pixel_name.call(display_name.call(target), Color.WHITE); target_name.centered = true; target_name.position = Vector2(120, 148)
	var fill_texture := target_health_fill_textures.get(target, target_fill.texture) as Texture2D
	if fill_texture != null:
		target_fill.texture = fill_texture
		bar_size = fill_texture.get_size()
	var damage_fill_texture := target_health_damage_fill_textures.get(target, target_fill.texture) as Texture2D
	if target_damage_fill != null and damage_fill_texture != null:
		target_damage_fill.texture = damage_fill_texture
	var max_health := float(max_health_for.call(target)); var health := float(health_for.call(target)); var display_health := float(display_health_for.call(target))
	target_health_text.texture = pixel_number.call("%d/%d" % [ceili(health), ceili(max_health)], Color.WHITE)
	set_values.call(target_fill, target_damage_fill, bar_size, health, display_health, max_health)
	return bar_size


func update_player_health_ui(health: float, display_health: float, damage_hold: float, delta: float, regen_speed: float, drain_speed: float, max_health: float, fill: Sprite2D, damage_fill: Sprite2D, fill_size: Vector2, health_text: Sprite2D, pixel_number: Callable, set_values: Callable) -> Dictionary:
	if health > display_health: display_health = move_toward(display_health, health, regen_speed * delta)
	if damage_hold > 0.0: damage_hold = maxf(damage_hold - delta, 0.0)
	elif display_health > health: display_health = move_toward(display_health, health, drain_speed * delta)
	set_values.call(fill, damage_fill, fill_size, health, display_health, max_health)
	if health_text != null: health_text.texture = pixel_number.call("%d/%d" % [ceili(health), ceili(max_health)], Color.WHITE)
	return {"display_health": display_health, "damage_hold": damage_hold}


func set_fill_ratio(fill: Sprite2D, fill_size: Vector2, ratio: float) -> void:
	if fill == null:
		return
	fill.region_enabled = true
	fill.region_rect = Rect2(Vector2.ZERO, Vector2(fill_size.x * clampf(ratio, 0.0, 1.0), fill_size.y))


func set_health_bar_values(main_fill: Sprite2D, transition_fill: Sprite2D, fill_size: Vector2, health: float, display_health: float, max_health: float) -> void:
	if main_fill == null or max_health <= 0.0: return
	var health_ratio := clampf(health / max_health, 0.0, 1.0); var display_ratio := clampf(display_health / max_health, 0.0, 1.0)
	set_fill_ratio(main_fill, fill_size, health_ratio)
	if transition_fill != null:
		var difference_ratio := absf(display_ratio - health_ratio)
		transition_fill.visible = difference_ratio > 0.0001
		transition_fill.position = main_fill.position + Vector2(minf(health_ratio, display_ratio) * fill_size.x, 0.0)
		set_fill_ratio(transition_fill, fill_size, difference_ratio)


func update_overhead_bars(
	slimes: Array[Sprite2D],
	max_health_for: Callable,
	health_for: Callable,
	display_health_for: Callable,
	is_dead_for: Callable,
	is_aggroed_for: Callable,
	set_health_bar_values: Callable,
	overwold_ui_z: int
) -> void:
	for slime in slimes:
		var frame := target_overhead_frames.get(slime) as Sprite2D
		var damage_fill := target_overhead_damage_fills.get(slime) as Sprite2D
		var fill := target_overhead_fills.get(slime) as Sprite2D
		var aggro_marker := target_overhead_aggro_markers.get(slime) as Sprite2D
		if frame == null or damage_fill == null or fill == null or aggro_marker == null:
			continue
		if is_dead_for.call(slime):
			frame.visible = false
			damage_fill.visible = false
			fill.visible = false
			aggro_marker.visible = false
			continue
		var max_health := float(max_health_for.call(slime))
		var health := float(health_for.call(slime))
		var is_aggroed := bool(is_aggroed_for.call(slime))
		var should_show := health < max_health or is_aggroed
		frame.visible = should_show
		damage_fill.visible = should_show
		fill.visible = should_show
		aggro_marker.visible = is_aggroed
		if not should_show:
			continue
		var overhead_position := slime.global_position + (target_overhead_offsets.get(slime, Vector2.ZERO) as Vector2)
		frame.global_position = overhead_position
		frame.global_scale = Vector2.ONE
		frame.z_index = overwold_ui_z
		damage_fill.global_position = overhead_position
		damage_fill.global_scale = Vector2.ONE
		damage_fill.z_index = overwold_ui_z + 1
		fill.global_position = overhead_position
		fill.global_scale = Vector2.ONE
		fill.z_index = overwold_ui_z + 2
		aggro_marker.global_position = overhead_position
		aggro_marker.global_scale = Vector2.ONE
		aggro_marker.z_index = overwold_ui_z + 3
		var fill_size := target_overhead_fill_sizes.get(slime, Vector2.ZERO) as Vector2
		set_health_bar_values.call(fill, damage_fill, fill_size, health, float(display_health_for.call(slime)), max_health)


func update_button_hud(buttons: Array[Sprite2D], devices: Array[int]) -> void:
	if buttons.size() < 4:
		return
	var pressed := [false, false, false, false]
	for device in devices:
		pressed[0] = pressed[0] or Input.is_joy_button_pressed(device, JOY_BUTTON_Y)
		pressed[1] = pressed[1] or Input.is_joy_button_pressed(device, JOY_BUTTON_X)
		pressed[2] = pressed[2] or Input.is_joy_button_pressed(device, JOY_BUTTON_A)
		pressed[3] = pressed[3] or Input.is_joy_button_pressed(device, JOY_BUTTON_B)
	for index in buttons.size():
		buttons[index].modulate = Color(1.7, 1.7, 1.7, 1.0) if pressed[index] else Color.WHITE


func update_gold_indicator(indicator: Sprite2D, frames: Array[Texture2D], delta: float) -> float:
	if indicator == null or frames.is_empty():
		return 0.0
	var timer := fmod(delta, 0.48)
	var frame_index := mini(int(timer / 0.12), frames.size() - 1)
	indicator.texture = frames[frame_index]
	return timer


func update_aggro_markers(markers: Dictionary, palette_name: String, pixel_particle: Callable) -> void:
	var colors := {"blue": Color8(59, 93, 201), "orange": Color8(239, 125, 87), "green": Color8(56, 183, 100), "red": Color8(177, 62, 83), "yellow": Color8(255, 205, 117), "grey": Color8(86, 108, 134)}
	var color: Color = colors.get(palette_name, colors["blue"])
	for marker in markers.values():
		var aggro_marker := marker as Sprite2D
		if aggro_marker != null:
			aggro_marker.texture = pixel_particle.call(color) as Texture2D


func build_enemy_health_ui(
	slimes: Array[Sprite2D],
	target_health_fill: Sprite2D,
	target_health_bar: Sprite2D,
	player_health_fill: Sprite2D,
	player_health_damage_fill: Sprite2D,
	hp_overhead: Sprite2D,
	hp_overhead_fill: Sprite2D,
	slime_green: Sprite2D,
	load_texture: Callable,
	bright_texture: Callable,
	duplicate_fill: Callable,
	register_overhead: Callable,
	pixel_particle: Callable
) -> Texture2D:
	target_health_fill_textures = {slimes[0]: load_texture.call("res://assets/artwork/EnemyHpBlueBar.png"), slimes[1]: load_texture.call("res://assets/artwork/EnemyHpGreenBar.png"), slimes[2]: load_texture.call("res://assets/artwork/EnemyHpRedBar.png")}
	target_overhead_fill_textures = {slimes[0]: load_texture.call("res://assets/artwork/HpOverheadBlueBar.png"), slimes[1]: load_texture.call("res://assets/artwork/HpOverheadGreenBar.png"), slimes[2]: load_texture.call("res://assets/artwork/HpOverheadRedBar.png")}
	target_health_damage_fill_textures.clear(); target_overhead_damage_fill_textures.clear()
	for slime in slimes:
		target_health_damage_fill_textures[slime] = bright_texture.call(target_health_fill_textures.get(slime) as Texture2D)
		target_overhead_damage_fill_textures[slime] = bright_texture.call(target_overhead_fill_textures.get(slime) as Texture2D)
	target_overhead_frames.clear(); target_overhead_damage_fills.clear(); target_overhead_fills.clear(); target_overhead_offsets.clear(); target_overhead_fill_sizes.clear(); target_overhead_aggro_markers.clear()
	var target_damage_fill := duplicate_fill.call(target_health_fill, "EnemyHpDamageFill") as Sprite2D
	target_health_bar.z_index = 0; target_health_bar.z_as_relative = true; target_damage_fill.z_index = 1; target_health_fill.z_index = 2; target_damage_fill.z_as_relative = true; target_health_fill.z_as_relative = true; target_damage_fill.get_parent().move_child(target_damage_fill, target_damage_fill.get_index())
	var player_damage_fill := duplicate_fill.call(player_health_fill, "HpBarDamageFill") as Sprite2D
	player_damage_fill.texture = bright_texture.call(player_health_fill.texture); player_damage_fill.z_index = 1; player_health_fill.z_index = 2; player_damage_fill.z_as_relative = true; player_health_fill.z_as_relative = true; player_damage_fill.get_parent().move_child(player_damage_fill, player_damage_fill.get_index())
	var base_texture := player_health_fill.texture
	register_overhead.call(slime_green, hp_overhead, hp_overhead_fill, hp_overhead.global_position - slime_green.global_position, duplicate_fill, pixel_particle)
	for slime in slimes:
		if slime == slime_green: continue
		var frame := Sprite2D.new(); frame.name = "HpOverhead"; frame.texture = hp_overhead.texture; frame.centered = hp_overhead.centered; frame.position = hp_overhead.position; frame.z_index = 0; frame.z_as_relative = false; slime.add_child(frame)
		var damage_fill := Sprite2D.new(); damage_fill.name = "HpOverheadDamageFill"; damage_fill.texture = target_overhead_damage_fill_textures.get(slime, hp_overhead_fill.texture); damage_fill.centered = hp_overhead_fill.centered; damage_fill.position = hp_overhead_fill.position; damage_fill.z_index = 1; damage_fill.z_as_relative = false; slime.add_child(damage_fill)
		var fill := Sprite2D.new(); fill.name = "HpOverheadFill"; fill.texture = target_overhead_fill_textures.get(slime, hp_overhead_fill.texture); fill.centered = hp_overhead_fill.centered; fill.position = hp_overhead_fill.position; fill.z_index = 2; fill.z_as_relative = false; slime.add_child(fill)
		register_overhead.call(slime, frame, fill, hp_overhead.global_position - slime_green.global_position, duplicate_fill, pixel_particle)
	return base_texture


func register_overhead_bar(slime: Sprite2D, frame: Sprite2D, fill: Sprite2D, offset: Vector2, duplicate_fill: Callable, pixel_particle: Callable) -> void:
	var fill_texture := target_overhead_fill_textures.get(slime, fill.texture) as Texture2D
	if fill_texture != null: fill.texture = fill_texture
	var damage_fill := fill.get_parent().get_node_or_null("HpOverheadDamageFill") as Sprite2D
	if damage_fill == null: damage_fill = duplicate_fill.call(fill, "HpOverheadDamageFill") as Sprite2D; damage_fill.z_index = 1
	fill.z_index = 2
	var damage_fill_texture := target_overhead_damage_fill_textures.get(slime, damage_fill.texture) as Texture2D
	if damage_fill_texture != null: damage_fill.texture = damage_fill_texture
	var aggro_marker := fill.get_parent().get_node_or_null("AggroMarker") as Sprite2D
	if aggro_marker == null:
		aggro_marker = Sprite2D.new(); aggro_marker.name = "AggroMarker"; aggro_marker.texture = pixel_particle.call(Color8(59, 93, 201)); aggro_marker.centered = false; aggro_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; aggro_marker.position = fill.position + Vector2((fill.texture.get_size().x if fill.texture != null else 0.0) + 1.0, 2.0); aggro_marker.z_index = 3; aggro_marker.z_as_relative = false; fill.get_parent().add_child(aggro_marker)
	target_overhead_frames[slime] = frame; target_overhead_damage_fills[slime] = damage_fill; target_overhead_fills[slime] = fill; target_overhead_offsets[slime] = offset; target_overhead_fill_sizes[slime] = fill.texture.get_size() if fill.texture != null else Vector2.ZERO; target_overhead_aggro_markers[slime] = aggro_marker
	frame.visible = false; damage_fill.visible = false; fill.visible = false; aggro_marker.visible = false


func duplicate_fill_sprite(source: Sprite2D, sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new(); sprite.name = sprite_name; sprite.texture = source.texture; sprite.centered = source.centered; sprite.position = source.position; sprite.offset = source.offset; sprite.scale = source.scale; sprite.region_enabled = source.region_enabled; sprite.region_rect = source.region_rect; sprite.texture_filter = source.texture_filter; sprite.z_as_relative = source.z_as_relative; sprite.z_index = source.z_index; source.get_parent().add_child(sprite); return sprite


func brighter_bar_texture(source: Texture2D) -> Texture2D:
	if source == null: return null
	var key := source.resource_path if not source.resource_path.is_empty() else str(source.get_instance_id())
	if bright_bar_cache.has(key): return bright_bar_cache[key]
	var image: Image = source.get_image().duplicate()
	if image == null: return source
	var palette_step := {"B13E53": Color8(239, 125, 87), "3B5DC9": Color8(65, 166, 246), "38B764": Color8(167, 240, 112)}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				var bright_color := palette_step.get("%02X%02X%02X" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0))], color) as Color
				image.set_pixel(x, y, Color(bright_color.r, bright_color.g, bright_color.b, color.a))
	var texture := ImageTexture.create_from_image(image); bright_bar_cache[key] = texture; return texture
