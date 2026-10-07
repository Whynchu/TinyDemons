extends Control
class_name StatAllocationBar

const MAX_TICKS := 15
const TICK_SIZE := Vector2(3.0, 6.0)

var _anchor := 0
var _committed_value := 0
var _pending_value := 0
var _ceiling := 0
var _stat_color := Color.WHITE
var _has_overflow := false


func _init() -> void:
	custom_minimum_size = Vector2(MAX_TICKS * TICK_SIZE.x, TICK_SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func configure(anchor: int, committed_value: int, pending_value: int, ceiling: int, stat_color: Color) -> void:
	_anchor = anchor
	_committed_value = committed_value
	_pending_value = pending_value
	_ceiling = ceiling
	_stat_color = stat_color
	_has_overflow = maxi(committed_value, pending_value) > ceiling
	queue_redraw()


func _draw() -> void:
	var capacity := clampi(_ceiling - _anchor, 0, MAX_TICKS)
	var committed_ticks := clampi(_committed_value - _anchor, 0, MAX_TICKS)
	var pending_ticks := clampi(_pending_value - maxi(_committed_value, _anchor), 0, MAX_TICKS)
	for index in MAX_TICKS:
		var rect := Rect2(Vector2(index * TICK_SIZE.x, 0.0), TICK_SIZE)
		draw_rect(rect, Color8(56, 61, 78))
		draw_rect(rect.grow(-1.0), Color.BLACK)
		if index >= capacity:
			continue
		if index < committed_ticks:
			draw_rect(rect.grow(-1.0), _stat_color)
		elif index < committed_ticks + pending_ticks:
			draw_rect(rect.grow(-1.0), _stat_color.lightened(0.48))
	if _has_overflow:
		var marker_x := float(MAX_TICKS) * TICK_SIZE.x - 2.0
		draw_rect(Rect2(Vector2(marker_x, 0.0), Vector2(2.0, TICK_SIZE.y)), Color8(255, 105, 105))
