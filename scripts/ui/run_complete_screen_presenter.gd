extends RefCounted
class_name RunCompleteScreenPresenter

const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")
const HUB_GOLD_TEXTURE: Texture2D = preload("res://assets/artwork/GoldFresh2.png")
const LINE_POSITIONS := [Vector2(19, 33), Vector2(19, 47), Vector2(19, 62), Vector2(123, 62), Vector2(19, 79), Vector2(123, 79), Vector2(19, 115), Vector2(19, 125), Vector2(86, 125)]

var overlay: ColorRect = null
var lines: Array[Sprite2D] = []
var grade_text: Sprite2D = null
var gold_icon: Sprite2D = null
var return_button: Button = null
var cursor: Sprite2D = null
var footer_text: Sprite2D = null


func build(parent: Node, view_size: Vector2, pixel_texture: Callable, return_to_hub: Callable, widget_factory: MenuWidgetFactory) -> void:
	overlay = widget_factory.create_overlay(parent, "RunCompleteOverlay", view_size, Color(0.015, 0.02, 0.035, 1.0), 6, false)
	overlay.set_meta("display_full_view", true)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	widget_factory.add_menu_frame(overlay, view_size)
	widget_factory.add_menu_title(overlay, "RunCompleteTitle", "RESULT", pixel_texture, view_size)
	var content_width := minf(220.0, maxf(view_size.x - 20.0, 100.0))
	var content_x := _content_x(view_size, content_width)
	widget_factory.make_menu_card(overlay, "RunCompleteMetrics", Vector2(content_x, 25), Vector2(content_width, 80))
	widget_factory.make_menu_card(overlay, "RunCompleteRewards", Vector2(content_x, 109), Vector2(content_width, 29))
	lines.clear()
	for index in LINE_POSITIONS.size():
		lines.append(widget_factory.create_sprite(overlay, "RunCompleteLine%d" % index, null, _line_position(index, content_x), false))
	grade_text = widget_factory.create_sprite(overlay, "RunCompleteGrade", null, Vector2(content_x + content_width - 18.0, 29.0), false)
	grade_text.scale = Vector2(2.0, 2.0)
	gold_icon = widget_factory.create_sprite(overlay, "RunCompleteGoldIcon", HUB_GOLD_TEXTURE, Vector2(content_x + 40.0, 124.0), false)
	gold_icon.region_enabled = true
	gold_icon.region_rect = Rect2(0.0, 0.0, 5.0, 5.0)
	return_button = widget_factory.make_menu_command_button("RETURN TO HUB", Vector2(content_x + 4.0, 141), Vector2(86, 12), pixel_texture)
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.pressed.connect(return_to_hub)
	overlay.add_child(return_button)
	cursor = widget_factory.create_sprite(overlay, "RunCompleteCursor", MENU_CURSOR_TEXTURE, Vector2(content_x - 4.0, 144), false)
	footer_text = widget_factory.create_sprite(overlay, "RunCompleteFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(view_size.x - 64.0, view_size.y - 18.0), false)


func position_controls(view_size: Vector2, cursor_animator: MenuCursorAnimator, tween_owner: Node, cursor_left_gap: float) -> void:
	if overlay == null:
		return
	overlay.position = Vector2.ZERO
	overlay.size = view_size
	var content_width := minf(220.0, maxf(view_size.x - 20.0, 100.0))
	var content_x := _content_x(view_size, content_width)
	var metrics := overlay.get_node_or_null("RunCompleteMetrics") as Panel
	if metrics != null:
		metrics.position = Vector2(content_x, 25)
		metrics.size = Vector2(content_width, 80)
	var rewards := overlay.get_node_or_null("RunCompleteRewards") as Panel
	if rewards != null:
		rewards.position = Vector2(content_x, 109)
		rewards.size = Vector2(content_width, 29)
	for index in mini(lines.size(), LINE_POSITIONS.size()):
		if lines[index] != null:
			lines[index].position = _line_position(index, content_x)
	if grade_text != null:
		grade_text.position = Vector2(content_x + content_width - 18.0, 29.0)
	if gold_icon != null:
		gold_icon.position = Vector2(content_x + 40.0, 124.0)
	if return_button != null:
		return_button.position = Vector2(content_x + 4.0, 141)
	if cursor != null:
		var cursor_x := (return_button.position.x if return_button != null else content_x) - cursor_left_gap
		cursor_animator.move_menu_cursor(cursor, Vector2(cursor_x, 144), true, tween_owner)
	var title_rule := overlay.get_node_or_null("RunCompleteTitleRule") as ColorRect
	if title_rule != null:
		title_rule.size = Vector2(maxf(view_size.x - 16.0, 16.0), 1.0)
	if footer_text != null:
		footer_text.position = Vector2(view_size.x - 64.0, view_size.y - 18.0)


func _content_x(view_size: Vector2, content_width: float) -> float:
	return floorf(maxf((view_size.x - content_width) * 0.5, 10.0))


func _line_position(index: int, content_x: float) -> Vector2:
	var base_position: Vector2 = LINE_POSITIONS[index]
	return Vector2(content_x + base_position.x - 10.0, base_position.y)
