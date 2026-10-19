@tool
extends ColorRect
class_name MenuScreen

## Common menu composition surface. Presenters own actions, selection, and data.
## Additional windows can be authored as children or added through add_window().
const WINDOW_SCENE: PackedScene = preload("res://scenes/ui/components/menu_window.tscn")
const PixelTextTextureFactoryScript = preload("res://scripts/runtime/services/pixel_text_texture_factory.gd")
const STANDARD_TITLE_WIDTH := 90.0
const TITLE_TEXT_RIGHT_INSET := 4.0

@export var heading := "MENU":
	set(value):
		heading = value
		_update_heading()
@export var show_header_window := false:
	set(value):
		show_header_window = value
		apply_layout()
@export_range(32.0, 160.0, 1.0) var title_width := STANDARD_TITLE_WIDTH:
	set(value):
		title_width = value
		apply_layout()
@export_range(16.0, 32.0, 1.0) var header_height := 21.0:
	set(value):
		header_height = value
		apply_layout()
		_update_heading()
@export_range(0.0, 40.0, 1.0) var footer_height := 24.0:
	set(value):
		footer_height = value
		apply_layout()

var _pixel_texture: Callable
var _preview_text_factory: PixelTextTextureFactory
var _heading_sprite: Sprite2D


func _ready() -> void:
	apply_layout()
	_update_heading()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		apply_layout()


func set_heading(sprite_name: String, label: String, pixel_texture: Callable) -> Sprite2D:
	_pixel_texture = pixel_texture
	if _heading_sprite == null:
		_heading_sprite = get_node_or_null("Heading") as Sprite2D
	if _heading_sprite != null:
		_heading_sprite.name = sprite_name
	heading = label
	return _heading_sprite


func add_window(window_name: String, rect: Rect2) -> NinePatchRect:
	var window := WINDOW_SCENE.instantiate() as NinePatchRect
	window.name = window_name
	window.position = rect.position
	window.size = rect.size
	add_child(window)
	return window


func apply_layout() -> void:
	if not is_node_ready():
		return
	var title_size := minf(title_width, size.x)
	var footer_size := minf(footer_height, maxf(size.y - header_height, 0.0))
	_layout_window("TitleWindow", Rect2(0, 0, title_size, header_height))
	_layout_window("HeaderWindow", Rect2(title_size, 0, maxf(size.x - title_size, 0.0), header_height))
	var header := get_node_or_null("HeaderWindow") as Control
	if header != null:
		header.visible = show_header_window
	_layout_window("ContentWindow", Rect2(0, header_height, size.x, maxf(size.y - header_height - footer_size, 0.0)))
	_layout_window("FooterWindow", Rect2(0, size.y - footer_size, size.x, footer_size))
	var footer := get_node_or_null("FooterWindow") as Control
	if footer != null:
		footer.visible = footer_size > 0.0
	_position_heading()


func _layout_window(window_name: String, rect: Rect2) -> void:
	var window := get_node_or_null(NodePath(window_name)) as Control
	if window != null:
		window.position = rect.position
		window.size = rect.size


func _update_heading() -> void:
	if not is_node_ready():
		return
	if _heading_sprite == null:
		_heading_sprite = get_node_or_null("Heading") as Sprite2D
	if _heading_sprite == null:
		return
	if _pixel_texture.is_valid():
		_heading_sprite.texture = _pixel_texture.call(heading, Color.WHITE) as Texture2D
	else:
		if _preview_text_factory == null:
			_preview_text_factory = PixelTextTextureFactoryScript.new()
		_heading_sprite.texture = _preview_text_factory.number_texture(heading, Color.WHITE)
	_position_heading()


func _position_heading() -> void:
	if _heading_sprite == null:
		_heading_sprite = get_node_or_null("Heading") as Sprite2D
	if _heading_sprite == null:
		return
	var title_size := minf(title_width, size.x)
	var text_width := float(_heading_sprite.texture.get_width()) if _heading_sprite.texture != null else 0.0
	_heading_sprite.position = Vector2(floorf(title_size - TITLE_TEXT_RIGHT_INSET - text_width), floorf((header_height - 5.0) * 0.5))
