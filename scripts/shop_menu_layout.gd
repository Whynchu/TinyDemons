@tool
extends Control
class_name ShopMenuLayout

## Authored 240x160 shop presentation.
##
## The hub owns route state and transactions. This scene owns the pixel layout,
## touch hit boxes, comparison columns, and the four cursor levels. Keeping the
## scene data-driven makes the mockup editable in Godot and keeps a resize from
## becoming a route transition.

const NATIVE_SIZE := Vector2(240.0, 160.0)
const VISIBLE_ROWS := 8
const STAT_COUNT := 6
const ITEM_ROW_PITCH := 10.0
const STAT_ROW_PITCH := 13.0
const STAT_BEFORE_RIGHT := 202.0
const STAT_ARROW_X := 205.0
const STAT_AFTER_RIGHT := 229.0
const SELL_SOUL_VALUE_RIGHT := 127.0

const MODE_SELECT := 0
const ITEM_BROWSE := 1
const SELL_AMOUNT := 2

const DIM_CURSOR_MODULATE := Color(0.5, 0.5, 0.5, 1.0)
const ACTIVE_CURSOR_MODULATE := Color.WHITE
const MUTED_TEXT_COLOR := Color8(148, 176, 194)
const DISABLED_TEXT_COLOR := Color8(122, 122, 122)
const PRICE_TEXT_COLOR := Color8(255, 205, 117)
const STAT_TEXT_COLOR := Color8(244, 244, 244)
const STAT_UP_COLOR := Color8(56, 183, 100)
const STAT_DOWN_COLOR := Color8(177, 62, 83)
const PROMPT_TEXT_COLOR := Color8(244, 244, 244)

const EFFECTS_SPAWNER_SCRIPT = preload("res://scripts/effects_spawner.gd")
const RESPONSIVE_LAYOUT_SCRIPT = preload("res://scripts/menu_responsive_layout.gd")
const SOUL_VISUALS_SCRIPT = preload("res://scripts/soul_visuals.gd")
const GOLD_TEXTURE: Texture2D = preload("res://assets/artwork/GoldFresh2.png")
const MENU_CIRCLE_TEXTURE: Texture2D = preload("res://assets/artwork/circle55.png")
const MENU_X_TEXTURE: Texture2D = preload("res://assets/artwork/x55.png")

signal mode_pressed(index: int)
signal item_pressed(index: int)
signal item_action_pressed
signal sell_amount_changed(direction: int)
signal sell_amount_confirmed
signal sell_amount_cancelled
signal shop_back_pressed

## Editor-only controls. Open scenes/shop_preview.tscn to inspect the full
## hub shell with this scene in place; these properties switch the exact same
## runtime presenter between its authored reference states.
@export_enum("Mode Select", "Item Browse", "Sell Amount") var editor_preview_state := ITEM_BROWSE
@export var editor_preview_sell := false
@export_range(0, 7, 1) var editor_preview_row := 1
@export_range(1, 9, 1) var editor_preview_quantity := 2

var _pixel_texture: Callable = Callable()
var _cached := false
var _buttons_bound := false
var _has_render_state := false
var _last_state := ITEM_BROWSE
var _last_sell_mode := false
var _last_selected_row := 0
var _last_row_count := 0
var _last_scroll_fraction := 0.0
var _last_quantity := 1
var _last_max_quantity := 1
var _last_editor_state := -1
var _last_editor_sell := false
var _last_editor_row := -1
var _last_editor_quantity := -1
var _root_preview_mode := false

var mode_buttons: Array[Button] = []
var item_buttons: Array[Button] = []
var _responsive_buttons: Array[Button] = []
var _responsive_sprites: Array[Sprite2D] = []

var item_texts: Array[Sprite2D] = []
var price_texts: Array[Sprite2D] = []
var sell_row_gold_icons: Array[Sprite2D] = []
var sell_row_soul_amounts: Array[Sprite2D] = []
var sell_row_soul_icons: Array[Sprite2D] = []
var stat_labels: Array[Sprite2D] = []
var stat_before_texts: Array[Sprite2D] = []
var stat_arrow_texts: Array[Sprite2D] = []
var stat_after_texts: Array[Sprite2D] = []

var top_cursor: Sprite2D = null
var mode_cursor: Sprite2D = null
var item_cursor: Sprite2D = null
var amount_cursor: Sprite2D = null

func _list_clip() -> Control:
	return get_node_or_null("ListClip") as Control


func _ready() -> void:
	_cache_nodes()
	_apply_button_style()
	_apply_layout()
	if Engine.is_editor_hint():
		call_deferred("_apply_editor_preview")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if editor_preview_state != _last_editor_state or editor_preview_sell != _last_editor_sell or editor_preview_row != _last_editor_row or editor_preview_quantity != _last_editor_quantity:
		_apply_editor_preview()


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	_apply_layout()
	if _has_render_state:
		# Responsive reflow follows the current cursor anchor and never re-enters
		# the state machine. This preserves the active bob phase on rotation.
		render_cursors(_last_state, _last_sell_mode, _last_selected_row, _last_row_count, true)


func _cache_nodes() -> void:
	if _cached:
		return
	_cached = true
	for path in ["ModeBuyButton", "ModeSellButton"]:
		var mode_button := get_node_or_null(path) as Button
		if mode_button != null:
			mode_buttons.append(mode_button)
	for index in VISIBLE_ROWS:
		var item_button := get_node_or_null("ListClip/ItemButton%d" % index) as Button
		var item_text := get_node_or_null("ListClip/ItemText%d" % index) as Sprite2D
		var price_text := get_node_or_null("ListClip/PriceText%d" % index) as Sprite2D
		var sell_gold_icon := get_node_or_null("ListClip/SellRowGoldIcon%d" % index) as Sprite2D
		var sell_soul_amount := get_node_or_null("ListClip/SellRowSoulAmount%d" % index) as Sprite2D
		var sell_soul_icon := get_node_or_null("ListClip/SellRowSoulIcon%d" % index) as Sprite2D
		if item_button != null:
			item_buttons.append(item_button)
		if item_text != null:
			item_texts.append(item_text)
		if price_text != null:
			price_texts.append(price_text)
		if sell_gold_icon != null:
			sell_row_gold_icons.append(sell_gold_icon)
		if sell_soul_amount != null:
			sell_row_soul_amounts.append(sell_soul_amount)
		if sell_soul_icon != null:
			sell_row_soul_icons.append(sell_soul_icon)
	for index in STAT_COUNT:
		var label := get_node_or_null("StatLabel%d" % index) as Sprite2D
		var before := get_node_or_null("StatBefore%d" % index) as Sprite2D
		var arrow := get_node_or_null("StatArrow%d" % index) as Sprite2D
		var after := get_node_or_null("StatAfter%d" % index) as Sprite2D
		if label != null: stat_labels.append(label)
		if before != null: stat_before_texts.append(before)
		if arrow != null: stat_arrow_texts.append(arrow)
		if after != null: stat_after_texts.append(after)
	top_cursor = get_node_or_null("ShopTopCursor") as Sprite2D
	mode_cursor = get_node_or_null("ShopModeCursor") as Sprite2D
	item_cursor = get_node_or_null("ShopItemCursor") as Sprite2D
	amount_cursor = get_node_or_null("ShopAmountCursor") as Sprite2D

	for path in [
		"ModeBuyText", "ModeSellText", "OwnedText", "FooterSelectText", "FooterBackText",
		"SellQuestionText", "SellQuantityX", "SellQuantityValue", "SellConfirmText", "SellCancelText",
	]:
		var sprite := get_node_or_null(path) as Sprite2D
		if sprite != null:
			_responsive_sprites.append(sprite)
	_responsive_sprites.append_array(item_texts)
	_responsive_sprites.append_array(price_texts)
	_responsive_sprites.append_array(sell_row_gold_icons)
	_responsive_sprites.append_array(sell_row_soul_amounts)
	_responsive_sprites.append_array(sell_row_soul_icons)
	_responsive_sprites.append_array(stat_labels)
	_responsive_sprites.append_array(stat_before_texts)
	_responsive_sprites.append_array(stat_arrow_texts)
	_responsive_sprites.append_array(stat_after_texts)
	for sprite in [get_node_or_null("SellSubtractIcon") as Sprite2D, get_node_or_null("SellAddIcon") as Sprite2D, get_node_or_null("FooterSelectGlyph") as Sprite2D, get_node_or_null("FooterBackGlyph") as Sprite2D, get_node_or_null("SellConfirmGlyph") as Sprite2D, get_node_or_null("SellCancelGlyph") as Sprite2D, top_cursor, mode_cursor, item_cursor, amount_cursor]:
		if sprite != null and not _responsive_sprites.has(sprite):
			_responsive_sprites.append(sprite)

	for button in mode_buttons + item_buttons:
		if button != null:
			_responsive_buttons.append(button)
	for path in ["ItemActionButton", "ShopBackButton", "SellMinusButton", "SellPlusButton", "SellConfirmButton", "SellCancelButton"]:
		var button := get_node_or_null(path) as Button
		if button != null:
			_responsive_buttons.append(button)

	if not _buttons_bound:
		for index in mode_buttons.size():
			mode_buttons[index].pressed.connect(mode_pressed.emit.bind(index))
		for index in item_buttons.size():
			item_buttons[index].pressed.connect(item_pressed.emit.bind(index))
		var action := get_node_or_null("ItemActionButton") as Button
		if action != null:
			action.pressed.connect(item_action_pressed.emit)
		var decrease := get_node_or_null("SellMinusButton") as Button
		if decrease != null:
			decrease.pressed.connect(sell_amount_changed.emit.bind(-1))
		var increase := get_node_or_null("SellPlusButton") as Button
		if increase != null:
			increase.pressed.connect(sell_amount_changed.emit.bind(1))
		var confirm := get_node_or_null("SellConfirmButton") as Button
		if confirm != null:
			confirm.pressed.connect(sell_amount_confirmed.emit)
		var cancel := get_node_or_null("SellCancelButton") as Button
		if cancel != null:
			cancel.pressed.connect(sell_amount_cancelled.emit)
		var back := get_node_or_null("ShopBackButton") as Button
		if back != null:
			back.pressed.connect(shop_back_pressed.emit)
		_buttons_bound = true

	# Save native authored origins once. All later layout passes derive from these
	# values, so a portrait/landscape switch cannot compound an old offset.
	for sprite in _responsive_sprites:
		if sprite != null and not sprite.has_meta("shop_native_position"):
			sprite.set_meta("shop_native_position", sprite.position)
	for button in _responsive_buttons:
		if button != null and not button.has_meta("shop_native_rect"):
			button.set_meta("shop_native_rect", Rect2(button.position, button.size))


func _apply_layout() -> void:
	_cache_nodes()
	var width := maxf(size.x, NATIVE_SIZE.x)
	var height := maxf(size.y, NATIVE_SIZE.y)
	var mode_panel := get_node_or_null("ShopModePanel") as Control
	if mode_panel != null:
		mode_panel.position = Vector2(0.0, 21.0)
		mode_panel.size = Vector2(width, 21.0)
	var list_panel := get_node_or_null("ShopListPanel") as Control
	var list_right := _responsive_x(146.0, width)
	if list_panel != null:
		list_panel.position = Vector2(0.0, 42.0)
		list_panel.size = Vector2(maxf(list_right, 1.0), 94.0)
	var stats_panel := get_node_or_null("ShopStatsPanel") as Control
	var stats_left := _responsive_x(148.0, width)
	if stats_panel != null:
		stats_panel.position = Vector2(stats_left, 42.0)
		stats_panel.size = Vector2(maxf(width - stats_left, 1.0), 94.0)
	var list_clip := get_node_or_null("ListClip") as Control
	if list_clip != null:
		list_clip.position = Vector2(0.0, 46.0)
		list_clip.size = Vector2(maxf(list_right, 1.0), 87.0)
	var fill := get_node_or_null("Fill") as ColorRect
	if fill != null:
		fill.size = Vector2(width, height)

	for sprite in _responsive_sprites:
		if sprite == null:
			continue
		var native_position := sprite.get_meta("shop_native_position", sprite.position) as Vector2
		sprite.position = _responsive_position(native_position, width)
	for button in _responsive_buttons:
		if button == null:
			continue
		var native_rect := button.get_meta("shop_native_rect", Rect2(button.position, button.size)) as Rect2
		var resolved := RESPONSIVE_LAYOUT_SCRIPT.map_rect(native_rect, width, NATIVE_SIZE.x)
		button.position = resolved.position
		button.size = resolved.size
	_apply_row_scroll()


func _responsive_x(native_x: float, width: float) -> float:
	return RESPONSIVE_LAYOUT_SCRIPT.proportional_x(native_x, width, NATIVE_SIZE.x)


func _responsive_position(native_position: Vector2, width: float) -> Vector2:
	return Vector2(_responsive_x(native_position.x, width), native_position.y)


func _responsive_rect(native_rect: Rect2, width: float) -> Rect2:
	return RESPONSIVE_LAYOUT_SCRIPT.map_rect(native_rect, width, NATIVE_SIZE.x)


func _apply_row_scroll() -> void:
	# SHOP keeps the logical window start in ScreenStateController, but touch
	# dragging also carries a fractional row offset. Move every visible row
	# element together so the list follows a finger continuously instead of
	# jumping one row per ten pixels. The active cursor uses the same offset.
	var offset_y := _last_scroll_fraction * ITEM_ROW_PITCH
	if is_zero_approx(offset_y):
		return
	var width := maxf(size.x, NATIVE_SIZE.x)
	var row_sprites: Array[Sprite2D] = []
	row_sprites.append_array(item_texts)
	row_sprites.append_array(price_texts)
	row_sprites.append_array(sell_row_gold_icons)
	row_sprites.append_array(sell_row_soul_amounts)
	row_sprites.append_array(sell_row_soul_icons)
	for sprite: Sprite2D in row_sprites:
		if sprite == null:
			continue
		var native_position := _native_sprite_position(sprite)
		sprite.position = _responsive_position(native_position, width)
		sprite.position.y -= offset_y
	for button: Button in item_buttons:
		if button == null:
			continue
		var native_rect := button.get_meta("shop_native_rect", Rect2(button.position, button.size)) as Rect2
		var resolved := _responsive_rect(native_rect, width)
		resolved.position.y -= offset_y
		button.position = resolved.position
		button.size = resolved.size


func _apply_button_style() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	transparent.set_border_width_all(0)
	for button in _responsive_buttons:
		if button == null:
			continue
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = ""
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, transparent)


func set_pixel_texture(pixel_texture: Callable) -> void:
	_pixel_texture = pixel_texture


func _set_text(sprite: Sprite2D, value: String, color: Color = Color.WHITE) -> void:
	if sprite == null:
		return
	if _pixel_texture.is_valid() and not value.is_empty():
		sprite.texture = _pixel_texture.call(value, color) as Texture2D
	else:
		sprite.texture = null
	sprite.visible = not value.is_empty()


func _set_button_active(button: Button, active: bool, visible := true) -> void:
	if button == null:
		return
	button.visible = visible
	button.mouse_filter = Control.MOUSE_FILTER_STOP if active and visible else Control.MOUSE_FILTER_IGNORE
	button.disabled = not active


func _set_native_position(sprite: Sprite2D, native_position: Vector2) -> void:
	if sprite == null:
		return
	sprite.set_meta("shop_native_position", native_position)
	sprite.position = _responsive_position(native_position, maxf(size.x, NATIVE_SIZE.x))


func _format_stat(value: Variant) -> String:
	return "%d" % roundi(float(value))


func _texture_width(sprite: Sprite2D) -> float:
	if sprite == null or sprite.texture == null:
		return 0.0
	return float(sprite.texture.get_width())


func _native_sprite_position(sprite: Sprite2D) -> Vector2:
	if sprite == null:
		return Vector2.ZERO
	return sprite.get_meta("shop_native_position", sprite.position) as Vector2


func _native_button_position(button: Button) -> Vector2:
	if button == null:
		return Vector2.ZERO
	var native_rect := button.get_meta("shop_native_rect", Rect2(button.position, button.size)) as Rect2
	return native_rect.position


func _position_cursor(cursor: Sprite2D, target: Vector2, active: bool, visible: bool, preserve_motion: bool) -> void:
	if cursor == null:
		return
	cursor.visible = visible
	if visible:
		cursor.modulate = ACTIVE_CURSOR_MODULATE if active else DIM_CURSOR_MODULATE
	var bob_endpoint := Vector2(3.0, 0.0) if not active else Vector2.ZERO
	var resolved_target := _responsive_position(target + bob_endpoint, maxf(size.x, NATIVE_SIZE.x))
	# menu_cursor.gd is intentionally runtime-only. In the editor these nodes are
	# placeholders, so never call lock/stop/tween methods from the @tool preview;
	# visual visibility and dimming still apply in both contexts.
	if Engine.is_editor_hint():
		if visible:
			cursor.position = resolved_target
		return
	if not visible:
		if cursor.has_method("stop_motion"):
			cursor.call("stop_motion")
		return
	# Cursor anchors are authored in the 240px reference space just like every
	# other sprite. Resolve them only at the last moment so a resize cannot
	# restore a native x-coordinate over the responsive text/button layout.
	if not active:
		# Dim ancestors are static breadcrumbs. They must never retain a bob tween.
		if cursor.has_method("lock_at"):
			cursor.call("lock_at", resolved_target)
		else:
			cursor.position = resolved_target
		return
	if preserve_motion and cursor.has_method("reanchor_preserving_motion"):
		cursor.call("reanchor_preserving_motion", resolved_target)
	elif cursor.has_method("move_to"):
		cursor.call("move_to", resolved_target, true)
	else:
		cursor.position = resolved_target


func render_cursors(state: int, sell_mode: bool, selected_row: int, row_count: int, preserve_motion := false) -> void:
	_has_render_state = true
	_last_state = state
	_last_sell_mode = sell_mode
	_last_selected_row = selected_row
	_last_row_count = row_count
	var has_item := row_count > 0 and selected_row >= 0 and selected_row < VISIBLE_ROWS
	var mode_target := Vector2(75.0 + (40.0 if sell_mode else 0.0), 26.0)
	var mode_text := get_node_or_null("ModeSellText" if sell_mode else "ModeBuyText") as Sprite2D
	if mode_text != null:
		# Use the same glyph-relative anchor as the item list. In the authored Buy
		# mockup the BUY glyph starts at (93, 29) and its cursor starts at (75, 26).
		mode_target = _native_sprite_position(mode_text) + Vector2(-20.0, -3.0)
	var item_target := Vector2(3.0, 49.0 + float(maxi(selected_row, 0)) * ITEM_ROW_PITCH)
	var list_clip := _list_clip()
	var selected_item_text := item_texts[clampi(selected_row, 0, item_texts.size() - 1)] if not item_texts.is_empty() else null
	if list_clip != null and selected_item_text != null:
		# Use the rendered item name rather than the row hitbox. This keeps the
		# cursor immediately left of both BUY and SELL name columns and removes the
		# half-pixel vertical drift caused by the old button-relative offset.
		item_target = Vector2(0.0, 46.0) + _native_sprite_position(selected_item_text) + Vector2(-20.0, -3.0)
		item_target.y -= _last_scroll_fraction * ITEM_ROW_PITCH
	var amount_target := Vector2(36.0, 142.0)
	var decrease := get_node_or_null("SellMinusButton") as Button
	if decrease != null:
		amount_target = _native_button_position(decrease) + Vector2(-14.0, 4.0)
	# SHOP is the parent route, BUY/SELL is the current route selector, and the
	# item/amount cursor is the active depth. Only that active depth bobs.
	# The live hub owns the top breadcrumb; the standalone preview has no live
	# ScreenStateController, so it opts into the authored SHOP breadcrumb node.
	var standalone_preview := bool(get_meta("standalone_preview", false))
	_position_cursor(top_cursor, Vector2(122.0, 5.0), false, standalone_preview, preserve_motion)
	if standalone_preview and top_cursor != null:
		top_cursor.modulate = DIM_CURSOR_MODULATE
	# At the hub root the contents remain visible as a preview, but the command
	# rail owns the only cursor. Never leave a nested SHOP cursor behind there.
	var nested_focus := not _root_preview_mode
	_position_cursor(mode_cursor, mode_target, nested_focus and state == MODE_SELECT, nested_focus, preserve_motion)
	# A mode preview may still show the item/stat contents, but it does not own
	# the item cursor. The item cursor returns only after entering item browse.
	var item_cursor_visible := nested_focus and has_item and (state == ITEM_BROWSE or (state == SELL_AMOUNT and sell_mode))
	_position_cursor(item_cursor, item_target, nested_focus and state == ITEM_BROWSE and has_item, item_cursor_visible, preserve_motion)
	_position_cursor(amount_cursor, amount_target, nested_focus and state == SELL_AMOUNT and sell_mode, nested_focus and state == SELL_AMOUNT and sell_mode, preserve_motion)


func render_shop(state: int, sell_mode: bool, selected_row: int, row_labels: Array, row_colors: Array, row_prices: Array, row_soul_values: Array, stat_comparison: Array, owned_count: int, quantity: int, max_quantity: int, pixel_texture: Callable, scroll_fraction: float = 0.0, preserve_motion := false) -> void:
	_cache_nodes()
	if pixel_texture.is_valid():
		_pixel_texture = pixel_texture
	_last_state = state
	_last_sell_mode = sell_mode
	_last_selected_row = selected_row
	_last_quantity = maxi(quantity, 1)
	_last_max_quantity = maxi(max_quantity, 1)
	_last_scroll_fraction = clampf(scroll_fraction, 0.0, 0.999999)
	var visible_item_count := 0
	for label: Variant in row_labels:
		if not str(label).is_empty():
			visible_item_count += 1
	_last_row_count = visible_item_count
	_has_render_state = true

	var buy_mode_color := MUTED_TEXT_COLOR if _root_preview_mode and sell_mode else STAT_TEXT_COLOR
	var sell_mode_color := MUTED_TEXT_COLOR if _root_preview_mode and not sell_mode else STAT_TEXT_COLOR
	_set_text(get_node_or_null("ModeBuyText") as Sprite2D, "BUY", buy_mode_color)
	_set_text(get_node_or_null("ModeSellText") as Sprite2D, "SELL", sell_mode_color)
	for mode_button in mode_buttons:
		# Mode tabs remain touch-reachable at every SHOP depth. Controller input
		# still uses state to decide which cursor is active.
		_set_button_active(mode_button, true, true)

	# BUY includes the rarity grade. SELL intentionally omits it, matching the
	# authored sell reference and leaving more room for the owned item name.
	var item_x := 21.0 if sell_mode else 27.0
	for index in item_texts.size():
		var label := str(row_labels[index]) if index < row_labels.size() else ""
		var color := row_colors[index] as Color if index < row_colors.size() else MUTED_TEXT_COLOR
		_set_native_position(item_texts[index], Vector2(item_x, 5.0 + index * ITEM_ROW_PITCH))
		_set_text(item_texts[index], label, color)
		var has_label := not label.is_empty()
		if index < item_buttons.size():
			# A visible row is a direct touch route into item browse, even from the
			# mode selector or sell amount view. It never auto-confirms a sale.
			_set_button_active(item_buttons[index], has_label, has_label)
	for index in price_texts.size():
		var price := str(row_prices[index]) if index < row_prices.size() else ""
		_set_native_position(price_texts[index], Vector2(102.0, 5.0 + index * ITEM_ROW_PITCH))
		var price_color := DISABLED_TEXT_COLOR if price == "SOLD" else PRICE_TEXT_COLOR
		_set_text(price_texts[index], price, price_color)
		var row_has_label := index < row_labels.size() and not str(row_labels[index]).is_empty()
		var gold_icon_visible := not price.is_empty() and price != "SOLD"
		if index < sell_row_gold_icons.size():
			var gold_x := 110.0 if sell_mode else 115.0
			_set_native_position(sell_row_gold_icons[index], Vector2(gold_x, 5.0 + index * ITEM_ROW_PITCH))
			sell_row_gold_icons[index].texture = GOLD_TEXTURE
			sell_row_gold_icons[index].region_enabled = true
			sell_row_gold_icons[index].region_rect = Rect2(0.0, 0.0, 5.0, 5.0)
			sell_row_gold_icons[index].visible = gold_icon_visible
			if gold_icon_visible:
				var price_gap := 1.0 if sell_mode else 2.0
				_set_native_position(price_texts[index], Vector2(gold_x - price_gap - _texture_width(price_texts[index]), 5.0 + index * ITEM_ROW_PITCH))
		if index < sell_row_soul_amounts.size():
			_set_native_position(sell_row_soul_amounts[index], Vector2(124.0, 5.0 + index * ITEM_ROW_PITCH))
			var soul_value := str(row_soul_values[index]) if index < row_soul_values.size() else "0"
			_set_text(sell_row_soul_amounts[index], soul_value, Color8(234, 122, 197))
			_set_native_position(sell_row_soul_amounts[index], Vector2(SELL_SOUL_VALUE_RIGHT - _texture_width(sell_row_soul_amounts[index]), 5.0 + index * ITEM_ROW_PITCH))
			sell_row_soul_amounts[index].visible = sell_mode and row_has_label
		if index < sell_row_soul_icons.size():
			_set_native_position(sell_row_soul_icons[index], Vector2(130.0, 5.0 + index * ITEM_ROW_PITCH))
			sell_row_soul_icons[index].texture = SOUL_VISUALS_SCRIPT.texture()
			sell_row_soul_icons[index].visible = sell_mode and row_has_label

	for index in STAT_COUNT:
		var data: Dictionary = stat_comparison[index] if index < stat_comparison.size() and stat_comparison[index] is Dictionary else {}
		var label := str(data.get("label", ["VIT", "STR", "DEF", "AGI", "INT", "MND"][index]))
		var before := _format_stat(data.get("before", 0.0))
		var after := _format_stat(data.get("after", data.get("before", 0.0)))
		var before_color := data.get("before_color", STAT_TEXT_COLOR) as Color
		var after_color := data.get("after_color", STAT_TEXT_COLOR) as Color
		_set_text(stat_labels[index], label, STAT_TEXT_COLOR)
		_set_text(stat_before_texts[index], before, before_color)
		_set_text(stat_arrow_texts[index], ">", STAT_TEXT_COLOR)
		_set_text(stat_after_texts[index], after, after_color)
		_set_native_position(stat_labels[index], Vector2(162.0, 54.0 + index * STAT_ROW_PITCH))
		_set_native_position(stat_before_texts[index], Vector2(STAT_BEFORE_RIGHT - _texture_width(stat_before_texts[index]), 54.0 + index * STAT_ROW_PITCH))
		_set_native_position(stat_arrow_texts[index], Vector2(STAT_ARROW_X, 54.0 + index * STAT_ROW_PITCH))
		_set_native_position(stat_after_texts[index], Vector2(STAT_AFTER_RIGHT - _texture_width(stat_after_texts[index]), 54.0 + index * STAT_ROW_PITCH))

	var amount_footer_visible := state == SELL_AMOUNT and sell_mode
	var browsing_footer := not amount_footer_visible
	var owned_text := get_node_or_null("OwnedText") as Sprite2D
	_set_text(owned_text, "OWNED: %d" % maxi(owned_count, 0), STAT_TEXT_COLOR)
	if owned_text != null:
		owned_text.visible = browsing_footer
	for path in ["FooterSelectGlyph", "FooterSelectText", "FooterBackGlyph", "FooterBackText"]:
		var footer_node := get_node_or_null(path) as CanvasItem
		if footer_node != null:
			footer_node.visible = true
	var footer_select_glyph := get_node_or_null("FooterSelectGlyph") as Sprite2D
	var footer_back_glyph := get_node_or_null("FooterBackGlyph") as Sprite2D
	if footer_select_glyph != null: footer_select_glyph.texture = MENU_CIRCLE_TEXTURE
	if footer_back_glyph != null: footer_back_glyph.texture = MENU_X_TEXTURE
	_set_text(get_node_or_null("FooterSelectText") as Sprite2D, "YES" if amount_footer_visible else "SELECT", PROMPT_TEXT_COLOR)
	_set_text(get_node_or_null("FooterBackText") as Sprite2D, "NO" if amount_footer_visible else "BACK", PROMPT_TEXT_COLOR)

	var item_action := get_node_or_null("ItemActionButton") as Button
	_set_button_active(item_action, not _root_preview_mode and state == ITEM_BROWSE and visible_item_count > 0, true)
	var shop_back := get_node_or_null("ShopBackButton") as Button
	_set_button_active(shop_back, state != SELL_AMOUNT, true)

	for path in ["SellQuestionText", "SellSubtractIcon", "SellQuantityX", "SellQuantityValue", "SellAddIcon", "SellConfirmGlyph", "SellConfirmText", "SellCancelGlyph", "SellCancelText"]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = amount_footer_visible and not path in ["SellConfirmGlyph", "SellConfirmText", "SellCancelGlyph", "SellCancelText"]
	var confirm_glyph := get_node_or_null("SellConfirmGlyph") as Sprite2D
	var cancel_glyph := get_node_or_null("SellCancelGlyph") as Sprite2D
	if confirm_glyph != null: confirm_glyph.texture = MENU_CIRCLE_TEXTURE
	if cancel_glyph != null: cancel_glyph.texture = MENU_X_TEXTURE
	if amount_footer_visible:
		_set_text(get_node_or_null("SellQuestionText") as Sprite2D, "SELL?", STAT_TEXT_COLOR)
		_set_text(get_node_or_null("SellQuantityX") as Sprite2D, "x", STAT_TEXT_COLOR)
		_set_text(get_node_or_null("SellQuantityValue") as Sprite2D, str(maxi(quantity, 1)), STAT_TEXT_COLOR)
		_set_text(get_node_or_null("SellConfirmText") as Sprite2D, "YES", PROMPT_TEXT_COLOR)
		_set_text(get_node_or_null("SellCancelText") as Sprite2D, "NO", PROMPT_TEXT_COLOR)
	var decrease := get_node_or_null("SellMinusButton") as Button
	var increase := get_node_or_null("SellPlusButton") as Button
	var confirm := get_node_or_null("SellConfirmButton") as Button
	var cancel := get_node_or_null("SellCancelButton") as Button
	_set_button_active(decrease, amount_footer_visible and quantity > 1, amount_footer_visible)
	_set_button_active(increase, amount_footer_visible and quantity < max_quantity, amount_footer_visible)
	_set_button_active(confirm, amount_footer_visible, amount_footer_visible)
	_set_button_active(cancel, amount_footer_visible, amount_footer_visible)
	var subtract_icon := get_node_or_null("SellSubtractIcon") as Sprite2D
	var add_icon := get_node_or_null("SellAddIcon") as Sprite2D
	if subtract_icon != null: subtract_icon.modulate = Color.WHITE if quantity > 1 else DIM_CURSOR_MODULATE
	if add_icon != null: add_icon.modulate = Color.WHITE if quantity < max_quantity else DIM_CURSOR_MODULATE
	_apply_row_scroll()

	# Keep the authored icon origins explicit after the text setter changes any
	# texture width. Their positions are fixed lanes in the reference.
	_set_native_position(owned_text, Vector2(8.0, 145.0))
	var footer_y := 145.0 if amount_footer_visible else 146.0
	_set_native_position(get_node_or_null("FooterSelectGlyph") as Sprite2D, Vector2(107.0, footer_y))
	_set_native_position(get_node_or_null("FooterSelectText") as Sprite2D, Vector2(114.0, footer_y))
	_set_native_position(get_node_or_null("FooterBackGlyph") as Sprite2D, Vector2(146.0, footer_y))
	_set_native_position(get_node_or_null("FooterBackText") as Sprite2D, Vector2(153.0, footer_y))
	_set_native_position(get_node_or_null("SellQuestionText") as Sprite2D, Vector2(8.0, 145.0))
	_set_native_position(subtract_icon, Vector2(52.0, 145.0))
	_set_native_position(get_node_or_null("SellQuantityX") as Sprite2D, Vector2(64.0, 145.0))
	_set_native_position(get_node_or_null("SellQuantityValue") as Sprite2D, Vector2(74.0, 145.0))
	_set_native_position(add_icon, Vector2(85.0, 145.0))
	_set_native_position(confirm_glyph, Vector2(107.0, 145.0))
	_set_native_position(get_node_or_null("SellConfirmText") as Sprite2D, Vector2(114.0, 145.0))
	_set_native_position(cancel_glyph, Vector2(146.0, 145.0))
	_set_native_position(get_node_or_null("SellCancelText") as Sprite2D, Vector2(153.0, 145.0))
	render_cursors(state, sell_mode, selected_row, visible_item_count, preserve_motion)


func _editor_stat_data() -> Array[Dictionary]:
	return [
		{"label": "VIT", "before": 8, "after": 8},
		{"label": "STR", "before": 15, "after": 12, "after_color": STAT_DOWN_COLOR},
		{"label": "DEF", "before": 5, "after": 5},
		{"label": "AGI", "before": 5, "after": 5},
		{"label": "INT", "before": 6, "after": 6},
		{"label": "MND", "before": 5, "after": 5},
	]


func _apply_editor_preview() -> void:
	if not is_inside_tree():
		return
	_cache_nodes()
	_last_editor_state = editor_preview_state
	_last_editor_sell = editor_preview_sell
	_last_editor_row = editor_preview_row
	_last_editor_quantity = editor_preview_quantity
	var renderer := EFFECTS_SPAWNER_SCRIPT.new()
	var previous_texture := _pixel_texture
	_pixel_texture = Callable(renderer, "number_texture")
	var state := clampi(editor_preview_state, MODE_SELECT, SELL_AMOUNT)
	var row := clampi(editor_preview_row, 0, VISIBLE_ROWS - 1)
	var labels: Array[String]
	var colors: Array[Color]
	var prices: Array[String]
	if editor_preview_sell:
		labels = ["THORN GUARD", "SOLDIER HELM", "SOLDIER HELM", "SOLDIER HELM", "BLOOD WRAPS", "ARCANE SHIELD", "SWIFT BOOTS", "BASIC TUNIC"]
		colors = [Color.WHITE, Color.WHITE, Color.WHITE, Color8(190, 190, 205), Color8(190, 190, 205), Color8(190, 190, 205), Color8(190, 190, 205), Color8(190, 190, 205)]
		prices = ["90", "90", "90", "90", "55", "78", "70", "70"]
	else:
		labels = ["C SOLDIER HELM", "C SOLDIER HELM", "R SOLDIER HELM", "C CLOAK", "C BLOOD WRAPS", "C ARCANE SHIELD", "C SWIFT BOOTS", "C SWIFT TUNIC"]
		colors = [Color.WHITE, Color8(190, 190, 205), Color.WHITE, Color8(190, 190, 205), Color8(190, 190, 205), Color8(190, 190, 205), Color8(190, 190, 205), Color8(190, 190, 205)]
		prices = ["190", "190", "210", "143", "153", "188", "178", "187"]
	var preview_quantity := clampi(editor_preview_quantity, 1, 9)
	var soul_values: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	render_shop(state, editor_preview_sell, row, labels, colors, prices, soul_values, _editor_stat_data(), 1, preview_quantity, 3, _pixel_texture)
	_pixel_texture = previous_texture
	renderer.free()


func refresh_layout_preserving_state() -> void:
	_cache_nodes()
	_apply_layout()
	if _has_render_state:
		render_cursors(_last_state, _last_sell_mode, _last_selected_row, _last_row_count, true)


func set_root_preview_mode(preview_only: bool) -> void:
	_root_preview_mode = preview_only
	if preview_only:
		stop_cursor_motion()
	for button in _responsive_buttons:
		if button == null:
			continue
		# Root preview suppresses controller ownership, not touch reachability.
		# A direct tap on BUY/SELL or a visible item is allowed to enter the route.
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.disabled = false
	if _has_render_state:
		render_cursors(_last_state, _last_sell_mode, _last_selected_row, _last_row_count, false)
	if _has_render_state and _pixel_texture.is_valid():
		var buy_mode_color := MUTED_TEXT_COLOR if preview_only and _last_sell_mode else STAT_TEXT_COLOR
		var sell_mode_color := MUTED_TEXT_COLOR if preview_only and not _last_sell_mode else STAT_TEXT_COLOR
		_set_text(get_node_or_null("ModeBuyText") as Sprite2D, "BUY", buy_mode_color)
		_set_text(get_node_or_null("ModeSellText") as Sprite2D, "SELL", sell_mode_color)


func stop_cursor_motion() -> void:
	for cursor in [top_cursor, mode_cursor, item_cursor, amount_cursor]:
		if cursor == null:
			continue
		cursor.visible = false
		if cursor.has_method("stop_motion"):
			cursor.call("stop_motion")
