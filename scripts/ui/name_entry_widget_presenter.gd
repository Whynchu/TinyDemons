extends RefCounted
class_name NameEntryWidgetPresenter

const NAME_ENTRY_COLUMNS := 8
const NAME_ENTRY_ROWS := 4
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")

var overlay: ColorRect = null
var prompt_text: Sprite2D = null
var name_text: Sprite2D = null
var page_text: Sprite2D = null
var message_text: Sprite2D = null
var confirm_text: Sprite2D = null
var back_text: Sprite2D = null
var actions_text: Sprite2D = null
var cursor_text: Sprite2D = null
var preview: Sprite2D = null
var field_panel: Panel = null
var cell_buttons: Array[Button] = []
var cell_texts: Array[Sprite2D] = []


func build(parent: Node, view_size: Vector2, pixel_texture: Callable, preview_texture: Callable, activate_cell: Callable, widget_factory: MenuWidgetFactory) -> Dictionary:
	overlay = widget_factory.create_overlay(parent, "NameEntryOverlay", view_size, Color(0.015, 0.02, 0.035, 1.0), 5, false)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_meta("display_full_view", true)
	widget_factory.add_menu_frame(overlay, view_size)
	widget_factory.add_menu_title(overlay, "NameEntryTitle", "NAME ENTRY", pixel_texture, view_size)
	prompt_text = widget_factory.create_sprite(overlay, "NameEntryPrompt", pixel_texture.call("PLEASE ENTER A NAME.", Color.WHITE) as Texture2D, Vector2(14, 22), false)
	field_panel = widget_factory.make_menu_card(overlay, "NameEntryField", Vector2(32, 29), Vector2(176, 20))
	name_text = widget_factory.create_sprite(overlay, "NameEntryName", null, Vector2(120, 36), true)
	page_text = widget_factory.create_sprite(overlay, "NameEntryPage", null, Vector2(14, 55), false)
	message_text = widget_factory.create_sprite(overlay, "NameEntryMessage", null, Vector2(14, 125), false)
	actions_text = widget_factory.create_sprite(overlay, "NameEntryActions", null, Vector2(14, 134), false)
	confirm_text = widget_factory.create_sprite(overlay, "NameEntryConfirm", null, Vector2(14, 145), false)
	back_text = widget_factory.create_sprite(overlay, "NameEntryBack", null, Vector2(78, 145), false)
	cursor_text = widget_factory.create_sprite(overlay, "NameEntryCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)

	var preview_panel := widget_factory.make_menu_card(overlay, "NameEntryPreviewPanel", Vector2(166, 62), Vector2(62, 54))
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview = widget_factory.create_sprite(overlay, "NameEntryPreview", null, Vector2(197, 82), true)
	if preview_texture.is_valid():
		preview.texture = preview_texture.call("blue") as Texture2D
		preview.scale = Vector2(0.75, 0.75)

	cell_buttons.clear()
	cell_texts.clear()
	for index in NAME_ENTRY_COLUMNS * NAME_ENTRY_ROWS:
		var cell := widget_factory.make_transparent_touch_button(overlay, "NameEntryCell%d" % index, Vector2.ZERO, Vector2(17, 12), activate_cell, index)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cell_text := widget_factory.create_sprite(cell, "NameEntryCellText%d" % index, null, cell.size * 0.5, true)
		cell_buttons.append(cell)
		cell_texts.append(cell_text)

	return {
		"overlay": overlay,
		"prompt": prompt_text,
		"name": name_text,
		"page": page_text,
		"message": message_text,
		"actions": actions_text,
		"confirm": confirm_text,
		"back": back_text,
		"cursor": cursor_text,
		"preview": preview,
		"cells": cell_buttons,
	}


func position_controls(view_size: Vector2, row: int, column: int, columns: int, cursor_left_gap: float, cursor_animator: MenuCursorAnimator, tween_owner: Node) -> void:
	if overlay == null:
		return
	var origin_x := maxf((view_size.x - 240.0) * 0.5, 0.0)
	if prompt_text != null: prompt_text.position = Vector2(origin_x + 14.0, 22.0)
	if field_panel != null: field_panel.position = Vector2(origin_x + 32.0, 29.0)
	if name_text != null: name_text.position = Vector2(origin_x + 120.0, 36.0)
	if page_text != null: page_text.position = Vector2(origin_x + 14.0, 55.0)
	if message_text != null: message_text.position = Vector2(origin_x + 14.0, 125.0)
	if actions_text != null: actions_text.position = Vector2(origin_x + 14.0, 134.0)
	if confirm_text != null: confirm_text.position = Vector2(origin_x + 14.0, 145.0)
	if back_text != null: back_text.position = Vector2(origin_x + 78.0, 145.0)
	var grid_origin := Vector2(origin_x + 12.0, 66.0)
	for index in cell_buttons.size():
		var button := cell_buttons[index]
		button.position = grid_origin + Vector2((index % columns) * 17.0, int(float(index) / float(columns)) * 12.0)
		var label := cell_texts[index]
		label.position = button.size * 0.5
	if preview != null: preview.position = Vector2(origin_x + 197.0, 82.0)
	var preview_panel := overlay.get_node_or_null("NameEntryPreviewPanel") as Panel
	if preview_panel != null: preview_panel.position = Vector2(origin_x + 166.0, 62.0)
	if cursor_text != null:
		var current_index := row * columns + column
		var target := grid_origin + Vector2((current_index % columns) * 17.0 - cursor_left_gap, int(float(current_index) / float(columns)) * 12.0 + 4.0)
		cursor_animator.move_menu_cursor(cursor_text, target, true, tween_owner)
