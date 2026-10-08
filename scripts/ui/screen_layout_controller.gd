extends RefCounted
class_name ScreenLayoutController

## Owns display-driven screen reflow and Hub/Pause cursor geometry.
var screen: ScreenStateController

func bind(owner: Variant) -> void:
	screen = owner

# --- Display sizing and menu layout reflow ---
func apply_display_layout(root: GameplayState) -> void:
	var display := root.display_controller
	# FULL keeps the authored 160px height but can expose additional logical
	# width when the browser viewport is wider than the configured content size.
	# Menus are full-view overlays, so their frame and responsive anchors must
	# use that visible width instead of the narrower content-scale width.
	# Every full-view menu shares one coordinate space: the visible logical
	# presentation surface. Fixed aspect presets can letterbox in portrait, so
	# sizing those overlays from their preset width leaves controls laid out for
	# a different viewport than the one the player sees.
	screen.display_view_size = display.visible_view_size_value() if display != null else Vector2(DisplayLayout.NATIVE_SIZE)
	var game_over: Variant = root.get("game_over_overlay")
	for overlay in [screen.title_presenter.overlay, screen.save_select_presenter.overlay, screen.name_entry_controller.widgets.overlay, screen.archetype_presenter.overlay, screen.run_complete_presenter.overlay, game_over] as Array:
		if overlay != null and bool(overlay.get_meta("display_full_view", false)):
			overlay.size = screen.display_view_size
			screen._menu_widget_factory.resize_menu_frame(overlay, screen.display_view_size)
	screen._title_screen_presenter.position_controls(screen.display_view_size, screen.CURSOR_LEFT_GAP, screen._menu_cursor_animator, screen)
	if screen.hub_overlay != null:
		screen.hub_overlay.position = (screen.display_view_size - screen.hub_overlay.size) * 0.5
	if screen.pause_overlay != null:
		screen.pause_overlay.position = (screen.display_view_size - screen.pause_overlay.size) * 0.5
	screen._run_complete_screen_presenter.position_controls(screen.display_view_size, screen._menu_cursor_animator, screen, screen.CURSOR_LEFT_GAP)
	screen._archetype_screen_presenter.position_controls(screen.display_view_size)
	if screen.hub_overlay != null:
		screen.hub_overlay.position = Vector2.ZERO
		screen.hub_overlay.size = screen.display_view_size
		# Orientation changes are geometry reflows, not route transitions. Keep
		# active cursor/glove motion alive while the anchors move.
		screen._screen_layout_controller._position_hub_controls(false, true)
	if screen.settings_presenter.overlay != null:
		screen.settings_presenter.overlay.size = screen.display_view_size
	screen._screen_route_controller._position_settings_controls()
	var cloud_panel := root.cloud_save_panel
	if cloud_panel != null: cloud_panel.apply_layout(screen.display_view_size)
	if screen.name_entry_controller.widgets.overlay != null:
		screen.name_entry_controller.widgets.overlay.size = screen.display_view_size
		screen.name_entry_controller.position_controls(
			screen.display_view_size, screen._menu_cursor_animator, screen
		)
	if screen.pause_overlay != null:
		screen.pause_overlay.position = Vector2.ZERO
		screen.pause_overlay.size = screen.display_view_size
		screen._screen_layout_controller._position_pause_controls(false, true)
	_refresh_active_menu_layout(root)
	screen._game_over_screen_presenter.position_controls(screen.display_view_size, screen._menu_cursor_animator, screen, screen.CURSOR_LEFT_GAP)
	screen._save_select_screen_presenter.position_controls(screen.display_view_size)


func _view_size_for_parent(parent: Node) -> Vector2:
	var current: Node = parent
	while current != null:
		var display := current.get("display_controller") as DisplayController
		if display != null:
			return Vector2(display.view_size_value())
		current = current.get_parent()
	return screen.display_view_size


func layout_view_size() -> Vector2:
	return screen.display_view_size


func _hub_left_field_x(native_x: float) -> float:
	return screen.PauseMenuLayoutScript.left_field_x(native_x, screen.display_view_size.x)


func _refresh_active_menu_layout(_root: Object) -> void:
	if screen._display_layout_refreshing:
		return
	screen._display_layout_refreshing = true
	# screen.apply_display_layout has already moved every static hub/pause node. The
	# active Hub cursors are re-anchored by screen._position_hub_controls; no
	# presenter is rebuilt, so scroll offsets, selected rows, draft allocations,
	# and in-progress animations survive an orientation change.
	if screen.hub_overlay != null and screen.hub_overlay.visible and screen.hub_equipment_menu != null and screen.hub_equipment_menu.visible and screen.hub_equipment_menu.has_method("refresh_layout_preserving_state"):
		screen.hub_equipment_menu.call("refresh_layout_preserving_state")
	if screen.hub_overlay != null and screen.hub_overlay.visible and screen.hub_shop_menu != null and screen.hub_shop_menu.visible and screen.hub_shop_menu.has_method("refresh_layout_preserving_state"):
		screen.hub_shop_menu.call("refresh_layout_preserving_state")
	if screen.pause_overlay != null and screen.pause_overlay.visible and screen.pause_equipment_menu != null and screen.pause_equipment_menu.visible:
		screen.pause_equipment_menu.refresh_layout_preserving_state()
	screen._display_layout_refreshing = false



# --- Hub and pause control positioning ---
func _position_menu_cursor(cursor: Sprite2D, target: Vector2, animate: bool = false, preserve_motion: bool = false) -> void:
	screen._menu_cursor_animator.position_menu_cursor(cursor, target, animate, preserve_motion, screen)


func _position_hub_stat_markers(selected_row: int, marker_visible: bool) -> void:
	screen._hub_stats_presenter.position_markers(selected_row, marker_visible, screen.display_view_size)


func _set_hub_stat_adjustment_targets(selected_row: int, enabled: bool) -> void:
	screen._hub_stats_presenter.set_adjustment_targets(selected_row, enabled)


func _position_hub_controls(animate_cursor: bool = false, preserve_cursor_motion: bool = false) -> void:
	if screen.hub_overlay == null:
		return
	var context: Variant = screen._hub_responsive_layout_context
	context.overlay = screen.hub_overlay
	context.view_size = screen.display_view_size
	context.page = screen.hub_page
	context.content_focus = screen.hub_content_focus
	context.stat_row = screen.hub_stat_row
	context.action_column = screen.hub_action_column
	context.gear_browsing = screen.hub_gear_browsing
	context.menu_row = screen.hub_menu_row
	context.is_root = screen.hub_is_root
	context.animate_cursor = animate_cursor
	context.preserve_cursor_motion = preserve_cursor_motion
	context.pages = screen._hub_page_visibility_presenter
	context.stats = screen._hub_stats_presenter
	context.commands = screen._hub_command_shell_presenter
	context.cursor_animator = screen._menu_cursor_animator
	context.tween_owner = screen
	screen._hub_responsive_layout_presenter.position_controls(context)

func _position_pause_controls(animate_cursor: bool = false, preserve_cursor_motion: bool = false) -> void:
	if screen.pause_overlay == null:
		return
	screen._pause_screen_presenter.position_controls(screen.display_view_size)
	if screen.pause_cursor_text != null and not screen.pause_menu_buttons.is_empty():
		var cursor_index := clampi(screen.pause_menu_row, 0, screen.pause_menu_buttons.size() - 1)
		screen._screen_layout_controller._position_menu_cursor(screen.pause_cursor_text, Vector2(screen.pause_menu_buttons[cursor_index].position.x - screen.CURSOR_LEFT_GAP, screen.pause_menu_buttons[cursor_index].position.y + 3.0), animate_cursor, preserve_cursor_motion)
func _reset_hub_cursor_layer() -> void:
	# Every hub render starts from an empty legacy cursor layer.  Each presenter
	# branch then opts in exactly the cursor(s) it owns, so Shop/Fusion and the
	# nested Equipment route cannot accumulate visible or still-tweening hands.
	for cursor in [screen.hub_cursor_text, screen.hub_stat_cursor_text, screen.hub_list_cursor, screen.hub_slot_cursor, screen.hub_choice_cursor]:
		if cursor == null:
			continue
		cursor.visible = false
		cursor.modulate = screen.ACTIVE_CURSOR_MODULATE
		if cursor.has_method("stop_motion"):
			cursor.call("stop_motion")
