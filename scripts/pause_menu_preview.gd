@tool
extends ColorRect

const EffectsSpawnerScript = preload("res://scripts/effects_spawner.gd")
const PauseMenuLayoutScript = preload("res://scripts/pause_menu_layout.gd")
const SoulVisualsScript = preload("res://scripts/soul_visuals.gd")
const MENU_CIRCLE_TEXTURE: Texture2D = preload("res://assets/artwork/circle55.png")
const MENU_X_TEXTURE: Texture2D = preload("res://assets/artwork/x55.png")
const GOLD_TEXTURE: Texture2D = preload("res://assets/artwork/GoldFresh2.png")

var _preview_root: Node2D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_preview()
	else:
		set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and Engine.is_editor_hint():
		_rebuild_preview()


func _rebuild_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if _preview_root != null and is_instance_valid(_preview_root):
		_preview_root.free()
	_preview_root = Node2D.new()
	_preview_root.name = "PauseEditorPreview"
	_preview_root.z_index = 3
	add_child(_preview_root)

	var renderer := EffectsSpawnerScript.new()
	_set_page_title(renderer, "PauseStatusPage/Title", "STATUS")
	_set_page_title(renderer, "PauseEquipmentPage/Title", "EQUIPMENT")
	_add_pixel_text(renderer, "PreviewName", "SAM", PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[0], Color.WHITE)
	_add_pixel_text(renderer, "PreviewElement", "GRAV", PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[1], PauseMenuLayoutScript.MUTED_TEXT_COLOR)
	_add_pixel_text(renderer, "PreviewHpLabel", "HP", PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[2], Color.WHITE)
	_add_pixel_text(renderer, "PreviewHpValue", "47/47", PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[3], Color.WHITE)
	_add_pixel_text(renderer, "PreviewChromaLabel", "CHR", PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[4], Color.WHITE)
	_add_pixel_text(renderer, "PreviewChromaValue", "0/100", PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[5], Color.WHITE)
	_add_pixel_text(renderer, "PreviewLevel", "LV 1", PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[6], Color.WHITE)

	var command_labels := ["RESUME", "STATUS", "EQUIPMENT", "SETTINGS", "QUIT TITLE"]
	for index in command_labels.size():
		var texture := renderer.call("number_texture", command_labels[index], Color.WHITE) as Texture2D
		if texture == null:
			continue
		var command := _add_texture("PreviewCommand%d" % index, texture, PauseMenuLayoutScript.command_label_position(size, index, texture.get_width()))
		command.z_index = 0

	_add_texture("PreviewSelectIcon", MENU_CIRCLE_TEXTURE, Vector2(PauseMenuLayoutScript.SELECT_PROMPT_X, size.y - PauseMenuLayoutScript.FOOTER_TEXT_BOTTOM_INSET))
	_add_pixel_text(renderer, "PreviewSelect", "SELECT", Vector2(PauseMenuLayoutScript.SELECT_PROMPT_X + 6.0, size.y - PauseMenuLayoutScript.FOOTER_TEXT_BOTTOM_INSET), PauseMenuLayoutScript.MUTED_TEXT_COLOR)
	_add_texture("PreviewBackIcon", MENU_X_TEXTURE, Vector2(PauseMenuLayoutScript.BACK_BUTTON_POSITION_X + 13.0, size.y - PauseMenuLayoutScript.BACK_BUTTON_BOTTOM_INSET + 4.0))
	_add_pixel_text(renderer, "PreviewBack", "BACK", Vector2(PauseMenuLayoutScript.BACK_BUTTON_POSITION_X + 21.0, size.y - PauseMenuLayoutScript.BACK_BUTTON_BOTTOM_INSET + 4.0), PauseMenuLayoutScript.MUTED_TEXT_COLOR)

	var gold_icon := _add_texture("PreviewGoldIcon", GOLD_TEXTURE, PauseMenuLayoutScript.resource_icon_position(size, false))
	gold_icon.region_enabled = true
	gold_icon.region_rect = Rect2(0, 0, 5, 5)
	var soul_icon := _add_texture("PreviewSoulIcon", SoulVisualsScript.texture(), PauseMenuLayoutScript.resource_icon_position(size, true))
	soul_icon.z_index = 1
	_add_pixel_text(renderer, "PreviewGold", "1112", PauseMenuLayoutScript.resource_text_position(size, 15.0, false), PauseMenuLayoutScript.GOLD_TEXT_COLOR)
	_add_pixel_text(renderer, "PreviewSouls", "59", PauseMenuLayoutScript.resource_text_position(size, 7.0, true), SoulVisualsScript.SOUL_HIGHLIGHT_COLOR)

	# The preview renderer is only used to build editor textures. The sprites keep
	# their ImageTextures after this helper object is released.
	renderer.free()


func _set_page_title(renderer: Object, node_path: String, value: String) -> void:
	var title := get_node_or_null(node_path) as Sprite2D
	if title != null:
		title.texture = renderer.call("number_texture", value, Color.WHITE) as Texture2D


func _add_pixel_text(renderer: Object, sprite_name: String, value: String, sprite_position: Vector2, color: Color) -> void:
	var texture := renderer.call("number_texture", value, color) as Texture2D
	if texture != null:
		_add_texture(sprite_name, texture, sprite_position)


func _add_texture(sprite_name: String, texture: Texture2D, sprite_position: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.position = sprite_position
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_root.add_child(sprite)
	return sprite
