@tool
extends ShopMenuLayout
class_name FusionMenuLayout

const FUSION_TARGET := ShopMenuLayout.ITEM_BROWSE
const FUSION_AMOUNT := ShopMenuLayout.SELL_AMOUNT
const FUSION_VISIBLE_ROWS := 10

func visible_row_capacity() -> int:
	return FUSION_VISIBLE_ROWS

func _ready() -> void:
	super._ready()
	# Shop's transparent sell-confirm hitbox occupies the shared footer action
	# slot. Reuse it for Fusion without exposing Shop's YES/NO presentation.
	sell_amount_confirmed.connect(item_action_pressed.emit)
	# The shared sell-cancel hitbox is the Fusion quantity state's BACK action.
	# Keep it on the same route signal so touch and controller back use one path.
	sell_amount_cancelled.connect(shop_back_pressed.emit)
	_hide_shop_mode()
	_apply_fusion_geometry()

func _hide_shop_mode() -> void:
	for path in ["ShopModePanel", "ModeBuyText", "ModeSellText", "ModeBuyButton", "ModeSellButton", "ShopTopCursor", "ShopModeCursor"]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = false
			if node is Control:
				(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func render_fusion(model: FusionMenuModel) -> void:
	_cache_nodes()
	set_root_preview_mode(model.state == 0)
	var labels: Array[String] = []
	var colors: Array[Color] = []
	var prices: Array[String] = []
	var soul_values: Array[String] = []
	var slots: Array[String] = []
	for row_index in model.rows.size():
		var row: Dictionary = model.rows[row_index]
		labels.append(str(row.get("label", "")))
		colors.append(row.get("color", Color.WHITE) as Color)
		prices.append("")
		var row_cost := model.soul_cost if model.state == 2 and row_index == model.selected_row else int(row.get("soul_cost", 0))
		soul_values.append(str(row_cost))
		slots.append(str(row.get("slot", "")))
	while labels.size() < FUSION_VISIBLE_ROWS:
		labels.append("")
		colors.append(MUTED_TEXT_COLOR)
		prices.append("")
		soul_values.append("0")
		slots.append("")
	render_shop(FUSION_TARGET if model.state != 2 else FUSION_AMOUNT, true, model.selected_row, labels, colors, prices, soul_values, slots, model.stat_comparison, model.owned_count, model.fusion_count, model.fusion_count_max, _pixel_texture, model.scroll_fraction)
	_hide_shop_mode()
	_apply_fusion_geometry()
	_set_text(get_node_or_null("FooterSelectText") as Sprite2D, "SELECT" if model.state == 0 or not model.item_selected else "FUSE", PROMPT_TEXT_COLOR)
	_set_text(get_node_or_null("FooterBackText") as Sprite2D, "BACK", PROMPT_TEXT_COLOR)
	for path in ["SellConfirmGlyph", "SellConfirmText", "SellCancelGlyph", "SellCancelText"]:
		var node := get_node_or_null(path) as CanvasItem
		if node != null: node.visible = false
	var question := get_node_or_null("SellQuestionText") as Sprite2D
	if question != null:
		_set_text(question, "FUSE?", STAT_TEXT_COLOR)
		question.visible = model.state == FUSION_AMOUNT
	var owned := get_node_or_null("OwnedText") as Sprite2D
	if owned != null:
		# The inherited Shop renderer owns this visibility decision, but make the
		# Fusion state contract explicit so a stale browse render can never leave
		# OWNED underneath the amount prompt.
		owned.visible = model.state != FUSION_AMOUNT
	var action := get_node_or_null("ItemActionButton") as Control
	if action != null:
		action.visible = false
		action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The shared Shop confirm hitbox is aligned with the visible SELECT/FUSE
	# footer. In Fusion browse it enters quantity selection; in amount state it
	# performs the transaction through the same action signal.
	var fusion_action := get_node_or_null("SellConfirmButton") as Button
	var fusion_action_available := model.state != 0 and not model.rows.is_empty()
	_set_button_active(fusion_action, fusion_action_available, fusion_action_available)
	_last_fusion_model = model

func _apply_fusion_geometry() -> void:
	var width := maxf(size.x, NATIVE_SIZE.x)
	var list_right := _responsive_x(146.0, width)
	var list_panel := get_node_or_null("ShopListPanel") as Control
	if list_panel != null:
		list_panel.position = Vector2(0.0, 21.0)
		list_panel.size = Vector2(maxf(list_right, 1.0), 115.0)
	var stats_panel := get_node_or_null("ShopStatsPanel") as Control
	if stats_panel != null:
		stats_panel.position = Vector2(_responsive_x(148.0, width), 21.0)
		stats_panel.size = Vector2(maxf(width - _responsive_x(148.0, width), 1.0), 115.0)
	var list_clip := get_node_or_null("ListClip") as Control
	if list_clip != null:
		list_clip.position = Vector2(0.0, 25.0)
		list_clip.size = Vector2(maxf(list_right, 1.0), 108.0)
	for index in stat_labels.size():
		var y := 41.0 + index * STAT_ROW_PITCH
		_set_native_position(stat_labels[index], Vector2(162.0, y))
		_set_native_position(stat_before_texts[index], Vector2(STAT_BEFORE_RIGHT - _texture_width(stat_before_texts[index]), y))
		_set_native_position(stat_arrow_texts[index], Vector2(STAT_ARROW_X, y))
		_set_native_position(stat_after_texts[index], Vector2(STAT_AFTER_RIGHT - _texture_width(stat_after_texts[index]), y))

func refresh_layout_preserving_state() -> void:
	_apply_layout()
	if _last_fusion_model != null:
		render_fusion(_last_fusion_model)

var _last_fusion_model: FusionMenuModel
