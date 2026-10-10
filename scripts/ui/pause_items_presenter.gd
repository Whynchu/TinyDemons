extends RefCounted
class_name PauseItemsPresenter

## Presents the profile's current gear collection on the Pause Items page.
## Inventory grouping, filtering, and sort order belong to PauseItemsModel.

const PauseItemsModelScript = preload("res://scripts/ui/pause_items_model.gd")
const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")
const ITEMS_DETAIL_LINE_COUNT := 10

var model: PauseItemsModel = null
var filter_buttons: Array[Button] = []
var sort_button: Button = null
var position_text: Sprite2D = null
var row_buttons: Array[Button] = []
var detail_texts: Array[Sprite2D] = []
var empty_text: Sprite2D = null
var divider: ColorRect = null
var _catalog: ItemCatalog = null
var _widget_factory: MenuWidgetFactory = null


func build(page: Control, view_size: Vector2, pixel_texture: Callable, widget_factory: MenuWidgetFactory) -> void:
	if page == null:
		return
	_widget_factory = widget_factory
	model = PauseItemsModelScript.new() as PauseItemsModel
	_catalog = ItemCatalog.new()
	filter_buttons.clear()
	for index in PauseItemsModel.FILTER_COUNT:
		var button := widget_factory.make_retro_button(model.filter_label(index), Vector2(8.0 + index * 54.0, 22.0), Vector2(52.0, 12.0), pixel_texture)
		button.name = "PauseItemsFilter%d" % index
		button.focus_mode = Control.FOCUS_NONE
		page.add_child(button)
		button.pressed.connect(_set_filter.bind(index))
		filter_buttons.append(button)
	sort_button = widget_factory.make_retro_button(model.sort_label(), Vector2(8.0, 35.0), Vector2(108.0, 11.0), pixel_texture)
	sort_button.name = "PauseItemsSort"
	sort_button.focus_mode = Control.FOCUS_NONE
	sort_button.pressed.connect(toggle_sort)
	page.add_child(sort_button)
	position_text = widget_factory.create_sprite(page, "PauseItemsPosition", null, Vector2(122.0, 37.0), false)
	divider = ColorRect.new()
	divider.name = "PauseItemsDivider"
	divider.position = Vector2(115.0, 34.0)
	divider.size = Vector2(1.0, 99.0)
	divider.color = Color(0.36, 0.4, 0.52, 0.85)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(divider)
	row_buttons.clear()
	for index in PauseItemsModel.VISIBLE_ROW_COUNT:
		var button := widget_factory.make_retro_button("", Vector2(8.0, 47.0 + index * 12.0), Vector2(103.0, 11.0), pixel_texture)
		button.name = "PauseItemsRow%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_select_visible_row.bind(index))
		page.add_child(button)
		var label := button.get_child(0) as Sprite2D
		if label != null:
			label.centered = false
			label.position = Vector2(3.0, 3.0)
		row_buttons.append(button)
	detail_texts.clear()
	for index in ITEMS_DETAIL_LINE_COUNT:
		detail_texts.append(widget_factory.create_sprite(page, "PauseItemsDetail%d" % index, null, Vector2(122.0, 46.0 + index * 10.0), false))
	empty_text = widget_factory.create_sprite(page, "PauseItemsEmpty", null, Vector2(13.0, 50.0), false)
	empty_text.texture = pixel_texture.call("NO ITEMS", PauseMenuLayoutScript.MUTED_TEXT_COLOR) as Texture2D
	empty_text.visible = false
	position_controls(view_size)


func position_controls(view_size: Vector2) -> void:
	for index in filter_buttons.size():
		filter_buttons[index].position = Vector2(8.0 + index * 54.0, 22.0)
	if sort_button != null:
		sort_button.position = Vector2(8.0, 35.0)
	if position_text != null:
		position_text.position = Vector2(122.0, 37.0)
	if divider != null:
		divider.position = Vector2(115.0, 34.0)
		divider.size = Vector2(1.0, maxf(minf(view_size.y - 27.0, 99.0), 1.0))
	for index in row_buttons.size():
		row_buttons[index].position = Vector2(8.0, 47.0 + index * 12.0)
	for index in detail_texts.size():
		detail_texts[index].position = Vector2(122.0, 46.0 + index * 10.0)
	if empty_text != null:
		empty_text.position = Vector2(13.0, 50.0)


func update(profile: PlayerProfile, pixel_texture: Callable, highlight: Color) -> void:
	if model == null or profile == null:
		return
	model.refresh(profile, _catalog)
	for index in filter_buttons.size():
		var button := filter_buttons[index]
		_set_button_pixel_label(button, model.filter_label(index), pixel_texture, Color.WHITE, true)
		_widget_factory.set_archetype_button_state(button, index == model.filter_index, highlight)
	if sort_button != null:
		_set_button_pixel_label(sort_button, model.sort_label(), pixel_texture, PauseMenuLayoutScript.MUTED_TEXT_COLOR, true)
		_widget_factory.set_archetype_button_state(sort_button, false, highlight)
	var visible_rows := model.visible_rows()
	if position_text != null:
		var range_start := model.scroll_offset + 1 if not visible_rows.is_empty() else 0
		var range_end := model.scroll_offset + visible_rows.size()
		position_text.texture = pixel_texture.call("%d-%d/%d" % [range_start, range_end, model.row_count()], PauseMenuLayoutScript.MUTED_TEXT_COLOR) as Texture2D
	for index in row_buttons.size():
		var button := row_buttons[index]
		var has_row := index < visible_rows.size()
		button.visible = has_row
		if not has_row:
			continue
		var row: Dictionary = visible_rows[index]
		var item := row.get("item") as ItemInstance
		var item_name := _truncate_text(_catalog.gear_name(item), 12)
		var row_label := "%s x%d" % [item_name, int(row.get("quantity", 1))]
		if bool(row.get("equipped", false)):
			row_label += " EQ"
		_set_button_pixel_label(button, row_label, pixel_texture, _catalog.rarity_color(item.rarity), false)
		_widget_factory.set_archetype_button_state(button, model.selected_index == model.scroll_offset + index, highlight)
	_render_details(model.selected_row(), pixel_texture)
	if empty_text != null:
		empty_text.visible = model.row_count() == 0


func move_selection(direction: int) -> bool:
	return model != null and model.move_selection(direction)


func move_filter(direction: int) -> bool:
	return model != null and model.move_filter(direction)


func toggle_sort() -> void:
	if model != null:
		model.toggle_sort()


func _set_filter(index: int) -> void:
	if model != null:
		model.set_filter(index)


func _select_visible_row(index: int) -> void:
	if model != null:
		model.select_visible_row(index)


func _set_button_pixel_label(button: Button, label: String, pixel_texture: Callable, color: Color, centered: bool) -> void:
	if button == null:
		return
	var sprite := button.get_child(0) as Sprite2D
	if sprite == null:
		return
	sprite.texture = pixel_texture.call(label, color) as Texture2D
	sprite.centered = centered
	if centered:
		sprite.position = button.size * 0.5
	else:
		sprite.position = Vector2(3.0, floorf((button.size.y - float(sprite.texture.get_height())) * 0.5)) if sprite.texture != null else Vector2(3.0, 3.0)


func _render_details(row: Dictionary, pixel_texture: Callable) -> void:
	if detail_texts.is_empty():
		return
	var lines: Array[String] = []
	var colors: Array[Color] = []
	var item := row.get("item") as ItemInstance
	if item != null:
		var slot := StringName(str(row.get("slot", &"")))
		lines.append(_catalog.gear_name(item))
		lines.append(_catalog.slot_label(slot))
		lines.append("RARITY %s" % String(item.rarity).to_upper())
		lines.append("OWNED x%d" % int(row.get("quantity", 1)))
		lines.append("ENHANCE +%d" % item.enhancement_level)
		lines.append("EQUIPPED" if bool(row.get("equipped", false)) else "UNEQUIPPED")
		var bonus_parts: Array[String] = []
		var bonus_labels := {"strength": "STR", "vitality": "VIT", "defense": "DEF", "agi": "AGI", "intelligence": "INT", "mnd": "MND"}
		var bonuses := _catalog.bonuses(item)
		for stat in ItemCatalog.RANDOM_STAT_KEYS:
			if not bonuses.has(stat):
				continue
			var value := float(bonuses[stat])
			if is_zero_approx(value):
				continue
			bonus_parts.append("%s %s%s" % [bonus_labels.get(stat, stat.to_upper()), "+" if value > 0.0 else "", String.num(value, 1)])
		if slot == &"shield":
			var guard_values := _catalog.shield_bonuses(item)
			for guard_key in ["guard_durability", "guard_reduction"]:
				if guard_values.has(guard_key):
					bonus_parts.append("%s %s%%" % ["DUR" if guard_key == "guard_durability" else "RED", String.num(float(guard_values[guard_key]) * 100.0, 0)])
		for start in range(0, bonus_parts.size(), 2):
			var chunk := " ".join(bonus_parts.slice(start, mini(start + 2, bonus_parts.size())))
			lines.append("BONUS %s" % chunk if start == 0 else chunk)
		for effect_line: String in _catalog.effect_display_lines(item):
			lines.append("EFFECT %s" % effect_line)
	colors.append(_catalog.rarity_color(item.rarity))
	for index in range(1, lines.size()):
		colors.append(PauseMenuLayoutScript.MUTED_TEXT_COLOR if index == 1 else Color.WHITE)
	for index in detail_texts.size():
		var sprite := detail_texts[index]
		sprite.visible = item != null and index < lines.size()
		if not sprite.visible:
			sprite.texture = null
			continue
		var line_color := colors[index] if index < colors.size() else Color.WHITE
		sprite.texture = pixel_texture.call(_truncate_text(lines[index], 20), line_color) as Texture2D


func _truncate_text(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	if max_chars <= 3:
		return value.substr(0, max_chars)
	return value.substr(0, max_chars - 3) + "..."
