extends Node2D

const FRAME_TEXTURE: Texture2D = preload("res://assets/artwork/HpOverhead.png")
const FILL_TEXTURE: Texture2D = preload("res://assets/artwork/HpOverheadGreenBar.png")

var progress := 0.0
var finishing := false
var finish_timer := 0.0
var finish_duration := 0.24
var finish_alpha := 1.0
var anchor_offset := Vector2.ZERO
var frame: Sprite2D
var fill: Sprite2D
var fill_size := Vector2.ZERO


func _ready() -> void:
	frame = _make_bar_sprite("Frame", FRAME_TEXTURE)
	fill = _make_bar_sprite("Fill", FILL_TEXTURE)
	fill_size = fill.texture.get_size()
	fill.region_enabled = true
	_update_fill_region()
	set_process(true)


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	_update_fill_region()


func finish(cancelled: bool = false) -> void:
	finishing = true
	finish_timer = 0.14 if cancelled else finish_duration
	finish_duration = maxf(finish_timer, 0.001)
	finish_alpha = 0.55 if cancelled else 1.0


func set_anchor_offset(value: Vector2) -> void:
	anchor_offset = value
	_update_anchor()


func _process(delta: float) -> void:
	_update_anchor()
	if not finishing:
		return
	finish_timer = maxf(finish_timer - maxf(delta, 0.0), 0.0)
	var elapsed := 1.0 - finish_timer / finish_duration
	if progress >= 1.0 and not cancelled_state():
		var pop := 1.0 + sin(minf(elapsed / 0.35, 1.0) * PI) * 0.20
		scale = Vector2.ONE * pop
	modulate.a = finish_alpha * (1.0 - elapsed)
	if finish_timer <= 0.0:
		queue_free()


func cancelled_state() -> bool:
	return finish_alpha < 1.0


func _make_bar_sprite(sprite_name: String, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = true
	sprite.z_index = 1 if sprite_name == "Fill" else 0
	add_child(sprite)
	return sprite


func _update_anchor() -> void:
	var actor := get_parent() as Node2D
	if actor != null:
		global_position = actor.global_position + anchor_offset


func _update_fill_region() -> void:
	if fill == null:
		return
	fill.region_rect = Rect2(Vector2.ZERO, Vector2(fill_size.x * progress, fill_size.y))
