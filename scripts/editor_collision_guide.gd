@tool
extends Node2D

@export var rect_position := Vector2.ZERO:
	set(value):
		rect_position = value
		queue_redraw()

@export var rect_size := Vector2(8, 4):
	set(value):
		rect_size = value
		queue_redraw()

@export var fill_color := Color(1.0, 0.15, 0.1, 0.22):
	set(value):
		fill_color = value
		queue_redraw()

@export var outline_color := Color(1.0, 0.05, 0.0, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

@export var draw_in_editor := true:
	set(value):
		draw_in_editor = value
		queue_redraw()

@export var draw_in_game := false


func _process(_delta: float) -> void:
	if draw_in_game:
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = draw_in_game


func _draw() -> void:
	if (not Engine.is_editor_hint() and not draw_in_game) or (Engine.is_editor_hint() and not draw_in_editor):
		return

	var rect := Rect2(rect_position, rect_size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, outline_color, false, 1.0)
