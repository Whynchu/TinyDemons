extends RefCounted
class_name HubStatsScreenPresenter

const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")
const MenuPromptTextureFactoryScript = preload("res://scripts/ui/menu_prompt_texture_factory.gd")
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")
const HUB_STAT_ADD_TEXTURE: Texture2D = preload("res://assets/artwork/DEMON HUB REWORK_STATSALLOCATEaddition.png")
const HUB_STAT_SUBTRACT_TEXTURE: Texture2D = preload("res://assets/artwork/DEMON HUB REWORK_STATSALLOCATEsubtract.png")
const STATUS_LEFT_ROW_COUNT := 10
const STAT_VALUE_RIGHT_ANCHOR := 93.0
const STAT_LABEL_X := 63.0
const STAT_LABEL_TOP := 44.0
const STAT_ROW_PITCH := 10.0
const STAT_ROW_LEFT_ARROW_X := 42.5
const STAT_ROW_RIGHT_ARROW_X := 90.5
const STAT_SUBTRACT_MARKER_X := 51.5
const STAT_ADD_MARKER_X := 104.5
const DERIVED_LABEL_X := 143.0
const DERIVED_LABEL_TOP := 47.0
const DERIVED_ROW_PITCH := 8.0
const DERIVED_VALUE_RIGHT_ANCHOR := 195.0
const STAT_CURSOR_X := 30.0
const STAT_UTILITY_Y := 116.0

var points_text: Sprite2D = null
var stat_texts: Array[Sprite2D] = []
var stat_value_texts: Array[Sprite2D] = []
var derived_texts: Array[Sprite2D] = []
var derived_value_texts: Array[Sprite2D] = []
var stat_add_marker: Sprite2D = null
var stat_subtract_marker: Sprite2D = null
var stat_buttons: Array[Button] = []
var stat_left_buttons: Array[Button] = []
var stat_right_buttons: Array[Button] = []
var stat_row_buttons: Array[Button] = []
var respec_button: Button = null
var apply_button: Button = null
var cancel_button: Button = null
var auto_button: Button = null
var allocate_panel: Panel = null
var allocate_preview_panel: Panel = null
var allocate_preview_title: Sprite2D = null
var allocate_preview_texts: Array[Sprite2D] = []
var stat_cursor_text: Sprite2D = null
var status_texts: Array[Sprite2D] = []


func build(
	allocate_page: Control,
	status_page: Control,
	overlay: Control,
	view_size: Vector2,
	pixel_texture: Callable,
	actions: HubScreenActions,
	widget_factory: MenuWidgetFactory,
	make_archetype_arrow: Callable
) -> void:
	allocate_panel = widget_factory.make_menu_card(allocate_page, "HubAllocatePanel", Vector2(14, 35), Vector2(108, 72))
	allocate_preview_panel = widget_factory.make_menu_card(allocate_page, "HubAllocatePreviewPanel", Vector2(132, 35), Vector2(94, 72))
	allocate_preview_title = widget_factory.create_sprite(allocate_page, "HubAllocatePreviewTitle", null, Vector2(138, 40), false)
	allocate_preview_texts.clear()
	for preview_index in 7:
		allocate_preview_texts.append(widget_factory.create_sprite(allocate_page, "HubAllocatePreview%d" % preview_index, null, Vector2(138, 48 + preview_index * 9), false))

	points_text = widget_factory.create_sprite(overlay, "HubPoints", null, Vector2(14, 27), false)
	points_text.visible = false
	stat_texts.clear()
	stat_value_texts.clear()
	stat_buttons.clear()
	stat_left_buttons.clear()
	stat_right_buttons.clear()
	stat_row_buttons.clear()
	var stat_names: Array[StringName] = [&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"]
	var stat_arrow_size := Vector2(18, 12)
	for index in stat_names.size():
		var y := STAT_LABEL_TOP - 5.0 + index * STAT_ROW_PITCH
		stat_texts.append(widget_factory.create_sprite(allocate_page, "HubStat%d" % index, null, Vector2(STAT_LABEL_X, y + 5), false))
		stat_value_texts.append(widget_factory.create_sprite(allocate_page, "HubStatValue%d" % index, null, Vector2(STAT_VALUE_RIGHT_ANCHOR - 4.0, y + 5), false))
		stat_row_buttons.append(widget_factory.make_transparent_touch_button(
			allocate_page,
			"HubStatRow%d" % index,
			Vector2(STAT_CURSOR_X, y),
			Vector2(STAT_ROW_RIGHT_ARROW_X + 9.0 - STAT_CURSOR_X, 12),
			actions.select_stat_row,
			index
		))
		var marker_y := STAT_LABEL_TOP + 2.5 + index * STAT_ROW_PITCH
		var left := make_archetype_arrow.call(
			allocate_page,
			-1,
			Vector2(STAT_SUBTRACT_MARKER_X - stat_arrow_size.x * 0.5, marker_y - stat_arrow_size.y * 0.5),
			actions.adjust_stat.bind(stat_names[index], -1),
			pixel_texture,
			stat_arrow_size
		) as Button
		var right := make_archetype_arrow.call(
			allocate_page,
			104,
			Vector2(STAT_ADD_MARKER_X - stat_arrow_size.x * 0.5, marker_y - stat_arrow_size.y * 0.5),
			actions.adjust_stat.bind(stat_names[index], 1),
			pixel_texture,
			stat_arrow_size
		) as Button
		left.set_meta("hub_stat_direction", -1)
		right.set_meta("hub_stat_direction", 1)
		left.set_meta("hub_stat_index", index)
		right.set_meta("hub_stat_index", index)
		stat_left_buttons.append(left)
		stat_right_buttons.append(right)
		stat_buttons.append(left)
		stat_buttons.append(right)
	stat_add_marker = widget_factory.create_sprite(allocate_page, "HubStatAddMarker", HUB_STAT_ADD_TEXTURE, Vector2(STAT_ADD_MARKER_X, STAT_LABEL_TOP + 2.5), false)
	stat_subtract_marker = widget_factory.create_sprite(allocate_page, "HubStatSubtractMarker", HUB_STAT_SUBTRACT_TEXTURE, Vector2(STAT_SUBTRACT_MARKER_X, STAT_LABEL_TOP + 2.5), false)
	stat_add_marker.visible = false
	stat_subtract_marker.visible = false
	derived_texts.clear()
	derived_value_texts.clear()
	for index in 7:
		derived_texts.append(widget_factory.create_sprite(allocate_page, "HubDerived%d" % index, null, Vector2(DERIVED_LABEL_X, DERIVED_LABEL_TOP + index * DERIVED_ROW_PITCH), false))
		derived_value_texts.append(widget_factory.create_sprite(allocate_page, "HubDerivedValue%d" % index, null, Vector2(DERIVED_VALUE_RIGHT_ANCHOR - 40.0, DERIVED_LABEL_TOP + index * DERIVED_ROW_PITCH), false))

	status_texts.clear()
	for index in 16:
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		status_texts.append(widget_factory.create_sprite(status_page, "HubStatus%d" % index, null, Vector2(14 + column * (view_size.x * 0.5), 42 + row * 10), false))
	apply_button = _make_utility_button(allocate_page, "APPLY", Vector2(44, STAT_UTILITY_Y), Vector2(32, 12), pixel_texture, actions.apply_stats, widget_factory)
	cancel_button = _make_utility_button(allocate_page, "CLEAR", Vector2(79, STAT_UTILITY_Y), Vector2(32, 12), pixel_texture, actions.cancel_stats, widget_factory)
	auto_button = _make_utility_button(allocate_page, "AUTO", Vector2(114, STAT_UTILITY_Y), Vector2(32, 12), pixel_texture, actions.auto_allocate, widget_factory)
	respec_button = _make_utility_button(allocate_page, "RESPEC", Vector2(149, STAT_UTILITY_Y), Vector2(50, 12), pixel_texture, actions.respec, widget_factory)
	stat_cursor_text = widget_factory.create_sprite(allocate_page, "HubStatCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)
	stat_cursor_text.visible = false


func _make_utility_button(
	parent: Control,
	label: String,
	position: Vector2,
	size: Vector2,
	pixel_texture: Callable,
	pressed: Callable,
	widget_factory: MenuWidgetFactory
) -> Button:
	var button := widget_factory.make_menu_command_button(label, position, size, pixel_texture)
	button.focus_mode = Control.FOCUS_NONE
	if pressed.is_valid():
		button.pressed.connect(pressed)
	parent.add_child(button)
	return button


func position_markers(selected_row: int, marker_visible: bool, view_size: Vector2) -> void:
	var valid_row := selected_row >= 0 and selected_row < 6
	var marker_center_y := STAT_LABEL_TOP + 2.5 + selected_row * STAT_ROW_PITCH if valid_row else 0.0
	if stat_subtract_marker != null:
		stat_subtract_marker.centered = true
		stat_subtract_marker.visible = marker_visible and valid_row
		stat_subtract_marker.position = Vector2(_left_field_x(STAT_SUBTRACT_MARKER_X, view_size), marker_center_y)
	if stat_add_marker != null:
		stat_add_marker.centered = true
		stat_add_marker.visible = marker_visible and valid_row
		stat_add_marker.position = Vector2(_left_field_x(STAT_ADD_MARKER_X, view_size), marker_center_y)


func set_adjustment_targets(selected_row: int, enabled: bool) -> void:
	for button in stat_buttons:
		var stat_index := int(button.get_meta("hub_stat_index", 0))
		var active := enabled and stat_index == selected_row
		button.visible = active
		button.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func position_cursor(
	selected_row: int,
	action_column: int,
	view_size: Vector2,
	animate: bool,
	preserve_motion: bool,
	cursor_animator: MenuCursorAnimator,
	tween_owner: Node
) -> void:
	if stat_cursor_text == null or not stat_cursor_text.visible:
		return
	var target: Vector2
	if selected_row < 6:
		target = Vector2(
			PauseMenuLayoutScript.left_field_x(STAT_CURSOR_X, view_size.x),
			STAT_LABEL_TOP - 1.0 + selected_row * STAT_ROW_PITCH
		)
	else:
		var utility_x: Array[float] = [44.0, 79.0, 114.0, 149.0]
		var utility_index: int = clampi(action_column, 0, utility_x.size() - 1)
		target = Vector2(
			PauseMenuLayoutScript.left_field_x(utility_x[utility_index], view_size.x) - 16.0,
			119.0
		)
	cursor_animator.position_menu_cursor(stat_cursor_text, target, animate, preserve_motion, tween_owner)


func update_status_page(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile) -> bool:
	var snapshot := root._player_stat_snapshot()
	if snapshot == null:
		return false
	var tuning := root.combat_tuning
	var player_tuning := root.player_tuning
	var max_hp := roundi(CombatCalculator.max_health_for_snapshot(snapshot, tuning))
	var hp := max_hp
	if root.player_health_component != null:
		hp = roundi(root.player_health_component.current_health)
	var chroma_component := root.player_chroma_component
	var chroma := chroma_component.current_chroma if chroma_component != null else 0
	var progression := root.progression_tuning
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, progression)
	var left := ["LV ....... %d" % profile.level, "XP ....... %d/%d" % [profile.xp, xp_required], "HP ....... %d/%d" % [hp, max_hp], "CHROMA ... %d/%d" % [chroma, chroma_component.max_chroma if chroma_component != null else 0], "STR ...... %d" % roundi(snapshot.strength), "AGI ...... %d" % roundi(snapshot.agi), "VIT ...... %d" % roundi(snapshot.vit), "INT ...... %d" % roundi(snapshot.intelligence), "MND ...... %d" % roundi(snapshot.mnd), "DEF ...... %d" % roundi(snapshot.def)]
	var right := ["P.ATK .... %d" % roundi(CombatCalculator.attack_power_for_snapshot(snapshot, tuning)), "P.DEF .... %d" % roundi(CombatCalculator.physical_defense_for_snapshot(snapshot)), "M.ATK .... %d" % roundi(CombatCalculator.magic_power_for_snapshot(snapshot, tuning)), "M.DEF .... %d" % roundi(CombatCalculator.magic_defense_for_snapshot(snapshot)), "MOV ...... %.2fx" % (player_tuning.agi_multiplier(snapshot.agi) if player_tuning != null else 1.0), "RECOVERY . %.2fx" % (player_tuning.attack_multiplier_for_agi(snapshot.agi) if player_tuning != null else 1.0)]
	for index in left.size():
		status_texts[index].texture = pixel_texture.call(left[index], Color8(255, 205, 117) if index == 1 else Color.WHITE) as Texture2D
	for index in 6:
		status_texts[index + STATUS_LEFT_ROW_COUNT].texture = pixel_texture.call(right[index], Color.WHITE) as Texture2D
	if points_text != null:
		points_text.texture = null
		points_text.visible = false
	return true


func update_allocation_page(
	root: GameplayState,
	pixel_texture: Callable,
	profile: PlayerProfile,
	pending: Array[int],
	selected_row: int,
	content_focused: bool,
	action_column: int,
	view_size: Vector2,
	highlight_color: Color,
	widget_factory: MenuWidgetFactory,
	prompt_factory: MenuPromptTextureFactory
) -> void:
	var pending_total: int = pending[0] + pending[1] + pending[2] + pending[3] + pending[4] + pending[5]
	var remaining := root._hub_points_remaining()
	if points_text != null:
		var unspent := remaining + pending_total
		var points_label := "POINTS %d" % unspent
		if pending_total > 0:
			points_label += " > %d" % remaining
		points_text.texture = pixel_texture.call(points_label, Color8(255, 205, 117)) as Texture2D
	var player_stats := root.player_stats
	var effective_values: Array[float] = []
	if player_stats != null:
		effective_values = [float(player_stats.vit) + pending[0], float(player_stats.strength) + pending[1], float(player_stats.def) + pending[2], float(player_stats.agi) + pending[3], float(player_stats.intelligence) + pending[4], float(player_stats.mnd) + pending[5]]
	for index in stat_texts.size():
		var effective := effective_values[index] if index < effective_values.size() else 0.0
		var before_pending := effective - float(pending[index])
		var value_text := "%d" % roundi(effective if pending[index] != 0 else before_pending)
		var stat_color := Color8(56, 183, 100) if pending[index] != 0 else Color.WHITE
		stat_texts[index].texture = pixel_texture.call(["VIT", "STR", "DEF", "AGI", "INT", "MND"][index], Color.WHITE) as Texture2D
		if index < stat_value_texts.size():
			var value_sprite := stat_value_texts[index]
			value_sprite.texture = pixel_texture.call(value_text, stat_color) as Texture2D
			if value_sprite.texture != null:
				value_sprite.position = Vector2(_left_field_x(STAT_VALUE_RIGHT_ANCHOR, view_size) - float(value_sprite.texture.get_width()), STAT_LABEL_TOP + index * STAT_ROW_PITCH)
	var marker_visible := content_focused and selected_row >= 0 and selected_row < stat_texts.size()
	position_markers(selected_row, marker_visible, view_size)
	set_adjustment_targets(selected_row, marker_visible)
	for button in stat_buttons:
		var direction := int(button.get_meta("hub_stat_direction", 1))
		var stat_index := int(button.get_meta("hub_stat_index", 0))
		button.disabled = remaining <= 0 if direction > 0 else pending[stat_index] <= 0
		widget_factory.set_archetype_button_state(button, false, highlight_color)
		button.modulate.a = 0.0
	for derived_text in derived_texts:
		derived_text.visible = true
	for derived_value in derived_value_texts:
		derived_value.visible = true
	var current_snapshot := root._player_stat_snapshot()
	var preview_snapshot := _allocation_preview_snapshot(root, pending)
	_update_allocation_preview(root, pixel_texture, current_snapshot, preview_snapshot, view_size)
	if apply_button != null:
		apply_button.disabled = pending_total <= 0
	if cancel_button != null:
		cancel_button.disabled = pending_total <= 0
	if auto_button != null:
		auto_button.disabled = remaining <= 0
	if respec_button != null:
		var cost := profile.respec_cost()
		respec_button.disabled = profile.allocated_vit + profile.allocated_str + profile.allocated_def + profile.allocated_agi + profile.allocated_int + profile.allocated_mnd <= 0 or profile.gold < cost
		var label := respec_button.get_child(0) as Sprite2D
		if label != null:
			label.texture = pixel_texture.call("RESPEC" if cost <= 0 else "RESPEC %d" % cost, Color.WHITE) as Texture2D
	var utility_buttons: Array[Button] = [apply_button, cancel_button, auto_button, respec_button]
	var uses_face_art := root._menu_confirm_prompt().begins_with("O ")
	for index in utility_buttons.size():
		var utility_active := content_focused and selected_row == 6 and action_column == index
		widget_factory.set_archetype_button_state(utility_buttons[index], utility_active, highlight_color)
		prompt_factory.set_menu_button_icon(utility_buttons[index], MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE, uses_face_art and utility_active)


func _allocation_preview_snapshot(root: GameplayState, pending: Array[int]) -> CombatStatSnapshot:
	var stats := root.player_stats
	if stats == null:
		return root._player_stat_snapshot()
	var preview_stats := StatsComponent.new() as StatsComponent
	var base_vit := stats.manual_base_vit if stats.manual_allocation_enabled else stats.vit
	var base_str := stats.manual_base_str if stats.manual_allocation_enabled else stats.strength
	var base_def := stats.manual_base_def if stats.manual_allocation_enabled else stats.def
	var base_agi := stats.manual_base_agi if stats.manual_allocation_enabled else stats.agi
	var base_int := stats.manual_base_int if stats.manual_allocation_enabled else stats.intelligence
	var base_mnd := stats.manual_base_mnd if stats.manual_allocation_enabled else stats.mnd
	var allocated_vit := stats.manual_vit if stats.manual_allocation_enabled else 0
	var allocated_str := stats.manual_str if stats.manual_allocation_enabled else 0
	var allocated_def := stats.manual_def if stats.manual_allocation_enabled else 0
	var allocated_agi := stats.manual_agi if stats.manual_allocation_enabled else 0
	var allocated_int := stats.manual_int if stats.manual_allocation_enabled else 0
	var allocated_mnd := stats.manual_mnd if stats.manual_allocation_enabled else 0
	preview_stats.configure_manual_growth(base_vit, base_str, base_def, base_agi, allocated_vit + pending[0], allocated_str + pending[1], allocated_def + pending[2], allocated_agi + pending[3], base_int, base_mnd, allocated_int + pending[4], allocated_mnd + pending[5])
	preview_stats.level = stats.level
	var snapshot := CombatStatSnapshot.from_components(preview_stats, root.player_equipment)
	preview_stats.free()
	return snapshot


func _update_allocation_preview(root: GameplayState, pixel_texture: Callable, current: CombatStatSnapshot, preview: CombatStatSnapshot, view_size: Vector2) -> void:
	if allocate_preview_title != null:
		allocate_preview_title.texture = pixel_texture.call("EFFECTIVE", Color8(148, 220, 255)) as Texture2D
	if current == null or preview == null:
		for text in allocate_preview_texts + derived_texts:
			text.texture = null
		return
	var tuning := root.combat_tuning
	var player_tuning := root.player_tuning
	var current_values := [
		CombatCalculator.max_health_for_snapshot(current, tuning),
		CombatCalculator.attack_power_for_snapshot(current, tuning),
		CombatCalculator.physical_defense_for_snapshot(current),
		CombatCalculator.magic_power_for_snapshot(current, tuning),
		CombatCalculator.magic_defense_for_snapshot(current),
		player_tuning.agi_multiplier(current.agi) if player_tuning != null else 1.0,
		player_tuning.attack_multiplier_for_agi(current.agi) if player_tuning != null else 1.0,
	]
	var preview_values := [
		CombatCalculator.max_health_for_snapshot(preview, tuning),
		CombatCalculator.attack_power_for_snapshot(preview, tuning),
		CombatCalculator.physical_defense_for_snapshot(preview),
		CombatCalculator.magic_power_for_snapshot(preview, tuning),
		CombatCalculator.magic_defense_for_snapshot(preview),
		player_tuning.agi_multiplier(preview.agi) if player_tuning != null else 1.0,
		player_tuning.attack_multiplier_for_agi(preview.agi) if player_tuning != null else 1.0,
	]
	var labels := ["HP", "P.ATK", "P.DEF", "M.ATK", "M.DEF", "MOVE", "REC"]
	var output_texts: Array[Sprite2D] = derived_texts if derived_texts.size() >= labels.size() else allocate_preview_texts
	for index in mini(output_texts.size(), labels.size()):
		var before := float(current_values[index])
		var after := float(preview_values[index])
		var changed := not is_equal_approx(before, after)
		var value_text := _allocation_preview_value_text(labels[index], after if changed else before)
		var value_color := Color8(167, 240, 112) if after > before else Color8(239, 125, 87) if after < before else Color.WHITE
		var value_texture := pixel_texture.call(value_text, value_color) as Texture2D
		output_texts[index].texture = pixel_texture.call(labels[index], Color.WHITE) as Texture2D
		if index < derived_value_texts.size():
			var derived_value := derived_value_texts[index]
			derived_value.texture = value_texture
			if value_texture != null:
				derived_value.position = Vector2(_left_field_x(DERIVED_VALUE_RIGHT_ANCHOR, view_size) - float(value_texture.get_width()), DERIVED_LABEL_TOP + index * DERIVED_ROW_PITCH)
		if index < allocate_preview_texts.size():
			allocate_preview_texts[index].texture = value_texture


func _allocation_preview_value_text(label: String, value: float) -> String:
	if label == "MOVE" or label == "REC":
		return "%.2f" % value
	return str(roundi(value))


func _left_field_x(native_x: float, view_size: Vector2) -> float:
	return PauseMenuLayoutScript.left_field_x(native_x, view_size.x)
