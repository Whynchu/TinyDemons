@tool
extends Control

## Direct editor preview for the authored Demon Hub shop. This is intentionally
## a scene preview, not a second shop implementation: it instances the shared
## hub shell and switches the real ShopMenu presenter in place.

const EFFECTS_SPAWNER_SCRIPT = preload("res://scripts/effects_spawner.gd")
const GOLD_TEXTURE: Texture2D = preload("res://assets/artwork/GoldFresh2.png")
const SOUL_TEXTURE: Texture2D = preload("res://assets/artwork/Souls.png")

@export_enum("BUY Browse", "SELL Browse", "SELL Amount") var preview := 0
@export_range(0, 7, 1) var selected_row := 1
@export_range(1, 9, 1) var quantity := 2
@export var show_buy_reference := false
@export var show_sell_reference := false

var _last_preview := -1
var _last_selected_row := -1
var _last_quantity := -1
var _last_buy_reference := false
var _last_sell_reference := false


func _ready() -> void:
	call_deferred("_apply_preview")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if preview != _last_preview or selected_row != _last_selected_row or quantity != _last_quantity or show_buy_reference != _last_buy_reference or show_sell_reference != _last_sell_reference:
		_apply_preview()


func _apply_preview() -> void:
	if not is_inside_tree():
		return
	_last_preview = preview
	_last_selected_row = selected_row
	_last_quantity = quantity
	_last_buy_reference = show_buy_reference
	_last_sell_reference = show_sell_reference

	var hub := get_node_or_null("DemonHubOverlay") as Control
	if hub == null:
		return
	hub.visible = true
	hub.position = Vector2.ZERO
	hub.size = size if size.x > 0.0 else Vector2(240.0, 160.0)

	# The shared preview scene contains useful examples for every hub route. A
	# shop preview keeps only the title/command shell and the actual shop child.
	for child in hub.get_children():
		if child is CanvasItem and String(child.name).begins_with("HubPreview"):
			var keep_command := String(child.name).begins_with("HubPreviewCommand")
			(child as CanvasItem).visible = keep_command
	var root_page := hub.get_node_or_null("HubRootPage") as Control
	if root_page != null:
		root_page.visible = true
		for child in root_page.get_children():
			(child as CanvasItem).visible = child.name == "Title" if child is CanvasItem else false
	var items_page := hub.get_node_or_null("HubItemsPage") as Control
	if items_page == null:
		return
	items_page.visible = true
	for chrome_name in ["Background", "TitleTab", "Title", "TitleRule", "EquipmentMenu"]:
		var chrome := items_page.get_node_or_null(chrome_name) as CanvasItem
		if chrome != null:
			chrome.visible = false
	var shop := items_page.get_node_or_null("ShopMenu") as ShopMenuLayout
	if shop == null:
		return
	shop.visible = true
	shop.set_meta("standalone_preview", true)
	# The preview enum describes authored reference states, not the presenter's
	# internal depth enum: both BUY Browse and SELL Browse are item browse. Keep
	# the mapping explicit so the exported mockup state cannot regress.
	shop.editor_preview_state = ShopMenuLayout.SELL_AMOUNT if preview == 2 else ShopMenuLayout.ITEM_BROWSE
	shop.editor_preview_sell = preview != 0
	shop.editor_preview_row = clampi(selected_row, 0, ShopMenuLayout.VISIBLE_ROWS - 1)
	shop.editor_preview_quantity = clampi(quantity, 1, 9)
	shop.call("_apply_editor_preview")
	# This scene is standalone: there is no live hub command cursor to supply
	# SHOP's breadcrumb. Pin the authored reference hand after the shared
	# presenter renders so the editor preview stays complete even if the child
	# tool script is reloaded independently. Keep this anchor reload-stable.
	var shop_top_cursor := shop.get_node_or_null("ShopTopCursor") as Sprite2D
	if shop_top_cursor != null:
		shop_top_cursor.position = Vector2(122.0, 5.0)
		shop_top_cursor.modulate = Color(0.5, 0.5, 0.5, 1.0)
		shop_top_cursor.visible = true

	# Runtime creates the resource rail from profile values. Add the same two
	# authored rows here so the direct preview is a complete 240x160 composition.
	var renderer := EFFECTS_SPAWNER_SCRIPT.new()
	var gold_icon := hub.get_node_or_null("ShopPreviewGoldIcon") as Sprite2D
	if gold_icon == null:
		gold_icon = Sprite2D.new()
		gold_icon.name = "ShopPreviewGoldIcon"
		hub.add_child(gold_icon)
	gold_icon.texture = GOLD_TEXTURE
	gold_icon.region_enabled = true
	gold_icon.region_rect = Rect2(0.0, 0.0, 5.0, 5.0)
	gold_icon.position = Vector2(182, 142)
	gold_icon.centered = false
	gold_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var soul_icon := hub.get_node_or_null("ShopPreviewSoulIcon") as Sprite2D
	if soul_icon == null:
		soul_icon = Sprite2D.new()
		soul_icon.name = "ShopPreviewSoulIcon"
		hub.add_child(soul_icon)
	soul_icon.texture = SOUL_TEXTURE
	soul_icon.position = Vector2(182, 149)
	soul_icon.centered = false
	soul_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var gold_text := hub.get_node_or_null("ShopPreviewGoldText") as Sprite2D
	if gold_text == null:
		gold_text = Sprite2D.new()
		gold_text.name = "ShopPreviewGoldText"
		hub.add_child(gold_text)
	gold_text.texture = renderer.number_texture("1413", Color8(255, 205, 117))
	gold_text.position = Vector2(218, 142)
	gold_text.centered = false
	gold_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var soul_text := hub.get_node_or_null("ShopPreviewSoulText") as Sprite2D
	if soul_text == null:
		soul_text = Sprite2D.new()
		soul_text.name = "ShopPreviewSoulText"
		hub.add_child(soul_text)
	soul_text.texture = renderer.number_texture("59", Color8(234, 122, 197))
	soul_text.position = Vector2(227, 149)
	soul_text.centered = false
	soul_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	renderer.free()

	var buy_reference := get_node_or_null("BuyReference") as CanvasItem
	if buy_reference != null: buy_reference.visible = show_buy_reference
	var sell_reference := get_node_or_null("SellReference") as CanvasItem
	if sell_reference != null: sell_reference.visible = show_sell_reference
