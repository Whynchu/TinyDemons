@tool
extends Node2D

@export var show_guides := true:
	set(value):
		show_guides = value
		queue_redraw()
@export var title_rect := Rect2(0, 0, 240, 160):
	set(value):
		title_rect = value
		queue_redraw()
@export var game_over_rect := Rect2(0, 0, 240, 160):
	set(value):
		game_over_rect = value
		queue_redraw()
@export var top_hud_rect := Rect2(0, 0, 240, 14):
	set(value):
		top_hud_rect = value
		queue_redraw()
@export var target_hud_rect := Rect2(72, 140, 96, 20):
	set(value):
		target_hud_rect = value
		queue_redraw()
@export var action_buttons_rect := Rect2(210, 56, 28, 32):
	set(value):
		action_buttons_rect = value
		queue_redraw()

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
	queue_redraw()

func _draw() -> void:
	if not show_guides:
		return
	_draw_region(title_rect, Color(0.4, 0.7, 1.0, 0.35), "TITLE / ARCHETYPE")
	_draw_region(game_over_rect, Color(1.0, 0.35, 0.35, 0.35), "GAME OVER")
	_draw_region(top_hud_rect, Color(1.0, 0.8, 0.25, 0.35), "TOP HUD")
	_draw_region(target_hud_rect, Color(0.35, 1.0, 0.45, 0.35), "TARGET HUD")
	_draw_region(action_buttons_rect, Color(0.8, 0.45, 1.0, 0.45), "ACTION BUTTONS")

func _draw_region(rect: Rect2, color: Color, label: String) -> void:
	draw_rect(rect, color, false, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(1, 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, color)
