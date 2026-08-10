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


func set_fill_ratio(fill: Sprite2D, fill_size: Vector2, ratio: float) -> void:
	if fill == null:
		return
	fill.region_enabled = true
	fill.region_rect = Rect2(Vector2.ZERO, Vector2(fill_size.x * clampf(ratio, 0.0, 1.0), fill_size.y))


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
