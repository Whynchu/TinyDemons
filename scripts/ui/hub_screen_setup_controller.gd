extends RefCounted
class_name HubScreenSetupController

## Owns Hub screen construction and its local assembly callbacks.
var screen: ScreenStateController

func bind(owner: Variant) -> void:
	screen = owner

# --- Hub and pause screen construction ---
func build_hub(parent: Node, pixel_texture: Callable, actions: HubScreenActions) -> void:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	var overlay: Variant = screen.DEMON_HUB_MENU_SCENE.instantiate() as ColorRect
	if overlay == null:
		return
	overlay.name = "HubOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = screen.display_view_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 3
	overlay.visible = false
	overlay.set_meta("display_full_view", true)
	parent.add_child(overlay)
	# HubPreview* nodes are persistent editor-authoring guides. They make every
	# visible piece selectable in demon_hub_menu.tscn, while runtime presenters
	# own the live profile-dependent copies.
	for preview_node in overlay.get_children():
		if preview_node is CanvasItem and String(preview_node.name).begins_with("HubPreview"):
			(preview_node as CanvasItem).visible = false

	screen._hub_page_visibility_presenter.build_pages(overlay, pixel_texture)
	var root_page: Variant = screen.hub_root_page
	var status_page: Variant = screen._hub_page_visibility_presenter.status_page
	var allocate_page: Variant = screen._hub_page_visibility_presenter.allocate_page
	var items_page: Variant = screen._hub_page_visibility_presenter.items_page
	var equipment_menu_node := items_page.get_node_or_null("EquipmentMenu") as EquipmentMenuLayout if items_page != null else null
	var shop_menu := items_page.get_node_or_null("ShopMenu") as ShopMenuLayout if items_page != null else null
	var fusion_menu := items_page.get_node_or_null("FusionMenu") as FusionMenuLayout if items_page != null else null
	screen.hub_equipment_menu = equipment_menu_node
	screen.equipment_menu = equipment_menu_node
	screen.hub_shop_menu = shop_menu
	screen.hub_fusion_menu = fusion_menu
	if equipment_menu_node != null:
		equipment_menu_node.visible = false
		if equipment_menu_node.has_method("set_pixel_texture"):
			equipment_menu_node.call("set_pixel_texture", pixel_texture)
		if equipment_menu_node.has_method("set_read_only"):
			equipment_menu_node.call("set_read_only", false)
	var bind_page: Variant = screen._hub_page_visibility_presenter.bind_page
	var bind_menu := bind_page.get_node_or_null("BindMenu") as BindMenuLayout if bind_page != null else null
	screen.hub_bind_menu = bind_menu
	screen._hub_stats_presenter.build(
		allocate_page,
		status_page,
		overlay,
		screen.display_view_size,
		pixel_texture,
		actions,
		screen._menu_widget_factory,
		Callable(screen, "make_archetype_arrow")
	)

	screen.hub_summary_text = screen._hub_responsive_layout_presenter.build_shell_chrome(
		root_page,
		overlay,
		screen._menu_widget_factory,
		screen.HUB_GOLD_TEXTURE,
		screen.SoulVisualsScript.texture()
	)
	screen.hub_currency_text = screen._hub_responsive_layout_presenter.hub_gold_text
	screen.hub_currency_icon = screen._hub_responsive_layout_presenter.hub_soul_icon
	screen._hub_command_shell_presenter.build_navigation(root_page, overlay, screen.display_view_size, pixel_texture, actions, screen._menu_widget_factory)

	screen._hub_legacy_widget_builder.build_item_and_equipment_widgets(
		items_page,
		pixel_texture,
		actions,
		screen._hub_responsive_layout_presenter,
		screen._menu_widget_factory,
		screen.display_view_size,
		screen.MENU_CURSOR_TEXTURE,
		Callable(screen, "_select_hub_shop_mode")
	)
	screen._hub_legacy_widget_builder.build_bind_widgets(
		bind_page,
		pixel_texture,
		actions,
		screen._hub_responsive_layout_presenter,
		screen._menu_widget_factory,
		screen.display_view_size
	)
	screen._hub_command_shell_presenter.build_cursor(root_page, screen._menu_widget_factory)
	if shop_menu != null:
		shop_menu.set_pixel_texture(pixel_texture)
	if fusion_menu != null:
		fusion_menu.set_pixel_texture(pixel_texture)
	if bind_menu != null:
		bind_menu.set_pixel_texture(pixel_texture)
	screen._hub_menu_signal_binder.bind(
		screen.equipment_menu,
		shop_menu,
		fusion_menu,
		bind_menu,
		actions,
		Callable(screen, "_set_hub_action_column")
	)

	# Keep the overlay handle here; typed presenters retain their view references.
	screen.hub_overlay = overlay
	screen.hub_start_button = null
	screen.hub_title_button = null
	screen._hub_item_visibility_presenter.bind(
		screen._hub_responsive_layout_presenter,
		screen.hub_shop_cursor,
		screen._menu_widget_factory,
		screen._menu_prompt_texture_factory,
		screen._menu_cursor_animator,
		screen
	)
	screen._hub_input_controller.bind(screen._hub_stats_presenter, screen._hub_responsive_layout_presenter)
	screen._pause_screen_presenter.build(
		parent,
		screen.display_view_size,
		pixel_texture,
		actions,
		screen._menu_widget_factory,
		screen._menu_prompt_texture_factory,
		screen._menu_cursor_animator,
		Callable(screen, "_set_hub_action_column")
	)
	var pause_debug_page_handler := Callable(screen, "_forward_pause_debug_page_requested")
	if not screen._pause_screen_presenter.debug_page_requested.is_connected(pause_debug_page_handler):
		screen._pause_screen_presenter.debug_page_requested.connect(pause_debug_page_handler)
	var pause_debug_action_handler := Callable(screen, "_forward_pause_debug_action_requested")
	if not screen._pause_screen_presenter.debug_action_requested.is_connected(pause_debug_action_handler):
		screen._pause_screen_presenter.debug_action_requested.connect(pause_debug_action_handler)
	screen.pause_resume_button = null
	screen.pause_player_card_panel = null


func _set_hub_action_column(index: int) -> void:
	screen.hub_action_column = index


func _select_hub_shop_mode(index: int) -> void:
	screen.hub_shop_sell_mode = index == 1
	screen.hub_shop_sell_confirm_pending = false
	screen.hub_action_column = index
	screen.hub_content_focus = true
	screen.hub_shop_command_focus = false
	screen.hub_item_index = 0
	screen.hub_list_scroll = 0.0


func _forward_pause_debug_page_requested() -> void:
	screen.debug_page_requested.emit()


func _forward_pause_debug_action_requested(action: StringName, amount: int) -> void:
	screen.debug_action_requested.emit(action, amount)


func _make_menu_page(parent: Node, page_name: String) -> Control:
	var page := Control.new()
	page.name = page_name
	page.position = Vector2.ZERO
	page.size = screen.display_view_size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(page)
	return page


func _add_menu_title(overlay: ColorRect, title_name: String, label: String, pixel_texture: Callable) -> Sprite2D:
	return screen._menu_widget_factory.add_menu_title(overlay, title_name, label, pixel_texture, screen.display_view_size)


func _position_menu_cursor(cursor: Sprite2D, target: Vector2, animate: bool = false, preserve_motion: bool = false) -> void:
	screen._screen_layout_controller._position_menu_cursor(cursor, target, animate, preserve_motion)

func _position_hub_stat_markers(selected_row: int, marker_visible: bool) -> void:
	screen._screen_layout_controller._position_hub_stat_markers(selected_row, marker_visible)

func _set_hub_stat_adjustment_targets(selected_row: int, enabled: bool) -> void:
	screen._screen_layout_controller._set_hub_stat_adjustment_targets(selected_row, enabled)

func _position_hub_controls(animate_cursor: bool = false, preserve_cursor_motion: bool = false) -> void:
	screen._screen_layout_controller._position_hub_controls(animate_cursor, preserve_cursor_motion)

func _position_pause_controls(animate_cursor: bool = false, preserve_cursor_motion: bool = false) -> void:
	screen._screen_layout_controller._position_pause_controls(animate_cursor, preserve_cursor_motion)

func _reset_hub_cursor_layer() -> void:
	screen._screen_layout_controller._reset_hub_cursor_layer()
