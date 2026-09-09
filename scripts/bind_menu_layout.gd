@tool
extends Control
class_name BindMenuLayout

const NATIVE_SIZE := Vector2(240.0, 160.0)
const CURSOR: Texture2D = preload("res://assets/artwork/cursor.png")
const FRAME: Texture2D = preload("res://assets/artwork/frame 16x16.png")
const EffectsSpawnerScript = preload("res://scripts/effects_spawner.gd")
const BindMenuModelScript = preload("res://scripts/bind_menu_model.gd")
const RESPONSIVE_LAYOUT_SCRIPT = preload("res://scripts/menu_responsive_layout.gd")

signal action_pressed
signal back_pressed

@export_enum("Preview", "Action") var editor_preview_state := 0

var _pixel_texture: Callable = Callable()
var _texts: Array[Sprite2D] = []
var _action: Button
var _back: Button
var _command_cursor: Sprite2D
var _action_cursor: Sprite2D
var _last_model: RefCounted

func _ready() -> void:
	_build_nodes()
	_apply_layout()
	if Engine.is_editor_hint(): call_deferred("_editor_preview")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: _apply_layout()

func _build_nodes() -> void:
	if _action != null: return
	var panel := NinePatchRect.new(); panel.name = "BindPanel"; panel.position = Vector2(14, 33); panel.size = Vector2(212, 72); panel.texture = FRAME; panel.patch_margin_left = 3; panel.patch_margin_top = 3; panel.patch_margin_right = 3; panel.patch_margin_bottom = 3; panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(panel)
	for index in 5:
		var text := Sprite2D.new(); text.name = "BindText%d" % index; text.centered = false; text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; text.position = Vector2(22, 41 + index * (12 if index < 4 else 14)); add_child(text); _texts.append(text)
	_action = _make_button("BindActionButton", Vector2(156, 119), Vector2(64, 13)); _action.pressed.connect(action_pressed.emit)
	_back = _make_button("BindBackButton", Vector2(128, 145), Vector2(48, 13)); _back.pressed.connect(back_pressed.emit)
	_command_cursor = _make_cursor("BindCommandCursor")
	_action_cursor = _make_cursor("BindActionCursor")

func _make_button(node_name: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new(); button.name = node_name; button.position = button_position; button.size = button_size; button.focus_mode = Control.FOCUS_NONE; button.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(button)
	var label := Sprite2D.new(); label.centered = true; label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; label.position = button_size * 0.5; button.add_child(label)
	return button

func _make_cursor(node_name: String) -> Sprite2D:
	var cursor := Sprite2D.new(); cursor.name = node_name; cursor.centered = false; cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; cursor.texture = CURSOR; cursor.visible = false
	var cursor_script := load("res://scripts/menu_cursor.gd") as Script
	if cursor_script != null: cursor.set_script(cursor_script)
	add_child(cursor); return cursor

func set_pixel_texture(pixel_texture: Callable) -> void: _pixel_texture = pixel_texture

func _text(sprite: Sprite2D, value: String, color: Color = Color.WHITE) -> void:
	if sprite == null: return
	sprite.visible = not value.is_empty()
	sprite.texture = _pixel_texture.call(value, color) as Texture2D if _pixel_texture.is_valid() and not value.is_empty() else null

func render(model: RefCounted) -> void:
	_build_nodes(); _last_model = model
	_text(_texts[0], "CURRENT %s%s" % [model.current_element, " BOUND" if model.current_is_bound else ""], Color.WHITE)
	_text(_texts[1], "BOUND %s" % model.bound_element, Color.WHITE)
	_text(_texts[2], "SOULS %d" % model.soul_count, Color8(211, 167, 255))
	_text(_texts[3], "COST %d SOULS" % model.bind_cost, Color8(255, 205, 117))
	_text(_texts[4], model.status_message, Color8(167, 240, 112) if model.can_bind else Color8(255, 105, 105))
	_text(_action.get_child(0) as Sprite2D, model.action_label, model.action_color)
	_action.disabled = not model.can_bind
	_action.mouse_filter = Control.MOUSE_FILTER_STOP if model.state == 1 and model.can_bind else Control.MOUSE_FILTER_IGNORE
	_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_command_cursor.visible = model.state == 0
	_action_cursor.visible = model.state == 1
	_command_cursor.modulate = Color(0.5, 0.5, 0.5, 1.0) if model.state == 1 else Color.WHITE
	_action_cursor.position = Vector2(_action.position.x - 8.0, _action.position.y + 3.0)
	_command_cursor.position = Vector2(148, 116)

func _apply_layout() -> void:
	var width := maxf(size.x, NATIVE_SIZE.x)
	# Bind uses the same expandable left field as the shared Hub footer. The
	# previous centering shift moved its back target away from the canonical
	# SELECT/BACK lane on wide displays.
	var left_field_width := maxf(width - 64.0, 176.0)
	if _action != null: _action.position.x = _responsive_x(156.0, left_field_width)
	if _back != null: _back.position.x = _responsive_x(128.0, left_field_width)
	for text in _texts: text.position.x = _responsive_x(22.0, left_field_width)
	if _action_cursor != null: _action_cursor.position.x = (_action.position.x if _action != null else 156.0) - 8.0


func _responsive_x(native_x: float, left_field_width: float) -> float:
	return RESPONSIVE_LAYOUT_SCRIPT.proportional_x(native_x, left_field_width, 176.0)

func refresh_layout_preserving_state() -> void:
	_apply_layout()
	if _last_model != null: render(_last_model)

func stop_cursor_motion() -> void:
	if _command_cursor != null: _command_cursor.visible = false
	if _action_cursor != null: _action_cursor.visible = false

func _editor_preview() -> void:
	if not Engine.is_editor_hint(): return
	var renderer := EffectsSpawnerScript.new(); _pixel_texture = Callable(renderer, "number_texture")
	var model := BindMenuModelScript.new(); model.state = editor_preview_state; model.current_element = "FIRE"; model.bound_element = "NONE"; model.soul_count = 80; model.bind_cost = 50; model.can_bind = true; model.status_message = "READY TO BIND"; model.action_color = Color.WHITE
	render(model); renderer.free()
