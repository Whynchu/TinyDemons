extends RefCounted
class_name HubStatsInteractionPresenter

const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")


func update_cursor_for_page(
	stats: HubStatsScreenPresenter,
	page: int,
	content_focus: bool,
	selected_row: int,
	action_column: int,
	view_size: Vector2,
	cursor_animator: MenuCursorAnimator,
	tween_owner: Node
) -> void:
	if stats.stat_cursor_text == null:
		return
	stats.stat_cursor_text.texture = MENU_CURSOR_TEXTURE
	stats.stat_cursor_text.visible = page == HubMenuStateScript.HUB_PAGE_ALLOCATE and content_focus
	stats.stat_cursor_text.modulate = Color.WHITE
	if stats.stat_cursor_text.visible:
		stats.position_cursor(selected_row, action_column, view_size, true, false, cursor_animator, tween_owner)


func update_page_visibility(
	stats: HubStatsScreenPresenter,
	page: int,
	is_root: bool,
	content_focus: bool,
	selected_row: int
) -> void:
	var stat_nodes: Array[CanvasItem] = []
	stat_nodes.append(stats.allocate_panel)
	stat_nodes.append(stats.allocate_preview_panel)
	stat_nodes.append(stats.allocate_preview_title)
	stat_nodes.append_array(stats.allocate_preview_texts)
	stat_nodes.append(stats.points_text)
	stat_nodes.append_array(stats.stat_texts)
	stat_nodes.append_array(stats.stat_value_texts)
	stat_nodes.append_array(stats.allocation_bars)
	stat_nodes.append(stats.allocation_policy_text)
	stat_nodes.append_array(stats.stat_row_buttons)
	stat_nodes.append_array(stats.stat_buttons)
	stat_nodes.append_array(stats.derived_texts)
	stat_nodes.append_array(stats.derived_value_texts)
	stat_nodes.append(stats.apply_button)
	stat_nodes.append(stats.cancel_button)
	stat_nodes.append(stats.auto_button)
	stat_nodes.append(stats.respec_button)
	var root_preview_stat_ids: Dictionary = {}
	for preview_stat: Sprite2D in stats.stat_texts:
		root_preview_stat_ids[preview_stat.get_instance_id()] = true
	for preview_stat: Sprite2D in stats.stat_value_texts:
		root_preview_stat_ids[preview_stat.get_instance_id()] = true
	for preview_stat: Sprite2D in stats.derived_texts:
		root_preview_stat_ids[preview_stat.get_instance_id()] = true
	for preview_stat: Sprite2D in stats.derived_value_texts:
		root_preview_stat_ids[preview_stat.get_instance_id()] = true
	for node in stat_nodes:
		if node == null:
			continue
		var root_preview_stat: bool = root_preview_stat_ids.has(node.get_instance_id())
		node.visible = page == HubMenuStateScript.HUB_PAGE_ALLOCATE and (not is_root or root_preview_stat or node == stats.points_text)
	# The shared Hub content frame replaces the authored allocation cards while
	# keeping stat labels visible as the root command preview.
	if stats.allocate_panel != null: stats.allocate_panel.visible = false
	if stats.allocate_preview_panel != null: stats.allocate_preview_panel.visible = false
	if stats.allocate_preview_title != null: stats.allocate_preview_title.visible = false
	for preview_text in stats.allocate_preview_texts: preview_text.visible = false
	stats.set_adjustment_targets(selected_row, page == HubMenuStateScript.HUB_PAGE_ALLOCATE and content_focus)
	for row_button in stats.stat_row_buttons:
		row_button.visible = page == HubMenuStateScript.HUB_PAGE_ALLOCATE and content_focus
		row_button.mouse_filter = Control.MOUSE_FILTER_STOP if row_button.visible else Control.MOUSE_FILTER_IGNORE
	if stats.stat_add_marker != null: stats.stat_add_marker.visible = page == HubMenuStateScript.HUB_PAGE_ALLOCATE and not is_root
	if stats.stat_subtract_marker != null: stats.stat_subtract_marker.visible = page == HubMenuStateScript.HUB_PAGE_ALLOCATE and not is_root
	for utility_button in [stats.apply_button, stats.cancel_button, stats.auto_button, stats.respec_button]:
		if utility_button == null:
			continue
		utility_button.visible = page == HubMenuStateScript.HUB_PAGE_ALLOCATE and not is_root
		utility_button.mouse_filter = Control.MOUSE_FILTER_STOP if content_focus else Control.MOUSE_FILTER_IGNORE
	for node in stats.status_texts:
		node.visible = page == HubMenuStateScript.HUB_PAGE_STATUS
