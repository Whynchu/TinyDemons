@tool
extends Node2D
class_name PlacementRoot2D

## Shared editor-facing root for authored world placements.
##
## The root is the stable world/ground anchor. Visual offsets, shadows,
## collision guides, interaction anchors, and depth markers belong below it so
## a producer can move one placement without breaking its presentation.

@export_category("Authoring Placement")
@export var placement_id: StringName = &"":
	set(value):
		placement_id = value
		queue_redraw()

@export_enum("Environment", "Props", "Collectables", "Actors", "Effects", "Guides") var authoring_layer := "Actors":
	set(value):
		authoring_layer = value
		queue_redraw()

@export_enum("Origin", "Foot", "Socket") var anchor_mode := "Foot":
	set(value):
		anchor_mode = value
		queue_redraw()

@export var editor_locked := false:
	set(value):
		editor_locked = value
		queue_redraw()

@export var show_anchor := true:
	set(value):
		show_anchor = value
		queue_redraw()

@export var anchor_offset := Vector2.ZERO:
	set(value):
		anchor_offset = value
		queue_redraw()


func authored_anchor_position() -> Vector2:
	return global_position + anchor_offset


func _draw() -> void:
	if not Engine.is_editor_hint() or not show_anchor:
		return
	var color := Color(0.35, 0.85, 1.0, 0.85) if not editor_locked else Color(0.55, 0.55, 0.62, 0.7)
	draw_circle(anchor_offset, 1.5, color)
	draw_line(anchor_offset - Vector2(4.0, 0.0), anchor_offset + Vector2(4.0, 0.0), color, 0.5)
	draw_line(anchor_offset - Vector2(0.0, 4.0), anchor_offset + Vector2(0.0, 4.0), color, 0.5)
