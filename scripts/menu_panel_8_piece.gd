@tool
extends Control

const PauseMenuLayoutScript = preload("res://scripts/pause_menu_layout.gd")

## Reusable authored menu panel. The source exports are 240x160 canvases; the
## three atlas regions retain their original pixel coordinates at native size.

@export var native_left_width: float = PauseMenuLayoutScript.LEFT_PANEL_WIDTH
@export var fixed_rail_width: float = PauseMenuLayoutScript.FIXED_RAIL_WIDTH
@export var resource_panel_height: float = PauseMenuLayoutScript.RESOURCE_PANEL_HEIGHT


func _ready() -> void:
	_apply_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()


func _apply_layout() -> void:
	var divider_x := maxf(size.x - fixed_rail_width, native_left_width)
	var rail_width := maxf(size.x - divider_x, 1.0)
	var upper_rail_height := maxf(size.y - resource_panel_height, 1.0)

	var left_panel: NinePatchRect = get_node_or_null("LeftPanel") as NinePatchRect
	if left_panel != null:
		left_panel.position = Vector2.ZERO
		left_panel.size = Vector2(divider_x, size.y)

	var right_panel: NinePatchRect = get_node_or_null("RightPanel") as NinePatchRect
	if right_panel != null:
		right_panel.position = Vector2(divider_x, 0.0)
		right_panel.size = Vector2(rail_width, upper_rail_height)

	var resources_panel: NinePatchRect = get_node_or_null("GoldSoulsPanel") as NinePatchRect
	if resources_panel != null:
		resources_panel.position = Vector2(divider_x, maxf(size.y - resource_panel_height, 0.0))
		resources_panel.size = Vector2(rail_width, resource_panel_height)
