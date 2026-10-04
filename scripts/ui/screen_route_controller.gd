extends RefCounted
class_name ScreenRouteController

## Owns Pause route/input and Settings route/input while the screen facade
## keeps its stable public calls and shared widget helpers.
var screen: ScreenStateController

func bind(owner: Variant) -> void:
	screen = owner

# --- Hub sub-screen rendering: fusion, binding, and shop ---












func update_pause_ui(root: Object, pixel_texture: Callable) -> void:
	if screen.pause_overlay == null or not screen.pause_overlay.visible:
		return
	var highlight := PaletteLibrary.accent(screen.player_palette_name)
	var menu_player_context: MenuPlayerContext = (root as GameplayState)._menu_player_context() if root is GameplayState else null
	screen._pause_screen_presenter.update_player_info(menu_player_context, pixel_texture, screen.display_view_size)
	var settings := root.get("settings_service") as SettingsService
	var debug_menu_enabled := settings != null and bool(settings.get_setting(&"debug_menu_enabled", false))
	var pause_equipment_view_active: Variant = screen._pause_screen_presenter.update_page_visibility(screen.pause_page, debug_menu_enabled, pixel_texture)
	var back_prompt: Variant = screen._menu_back_prompt_for(root)
	var confirm_prompt: Variant = screen._menu_confirm_prompt_for(root)
	screen._pause_screen_presenter.update_navigation_prompts(
		highlight,
		pause_equipment_view_active,
		back_prompt,
		confirm_prompt,
		pixel_texture
	)
	if screen.pause_page == 1:
		screen._pause_screen_presenter.update_status(menu_player_context, pixel_texture)
	elif screen.pause_page == 2:
		var pause_profile: PlayerProfile = menu_player_context.profile if menu_player_context != null else root.get("player_profile") as PlayerProfile
		if pause_equipment_view_active:
			screen._render_equipment_menu(root, pixel_texture, pause_profile, highlight, screen.pause_equipment_menu, false)
			return
		screen._pause_screen_presenter.update_equipment(pause_profile, pixel_texture)
	elif screen.pause_page == 3:
		screen.refresh_debug_menu(root)
	screen._pause_screen_presenter.update_selected_cursor(
		screen.pause_page,
		screen.pause_menu_row,
		screen.CURSOR_LEFT_GAP,
		screen
	)


func set_pause_page(root: Object, page: int) -> void:
	screen._pause_menu_state.set_page(page)
	# A pause page transition is a fresh route entry. Never carry a touch
	# candidate arm from Hub Equipment (or an earlier pause page) into it.
	screen.hub_touch_candidate_slot = ""
	screen.hub_touch_candidate_index = -1
	if screen.pause_page == 2:
		# Pause Equipment shares the live equipment flow, but always enters at its
		# top command row just like the Demon Hub route.
		screen.hub_equipment_mode = EquipmentMenuLayout.MODE_COMMAND
		screen.hub_equipment_action_focus = true
		screen.hub_gear_browsing = false
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	elif screen.pause_page == 1:
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	elif screen.pause_page == 3:
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	screen.update_pause_ui(root, Callable(root, "_pixel_text_texture"))


func is_pause_equipment_active() -> bool:
	return screen.pause_overlay != null and screen.pause_overlay.visible and screen.pause_page == 2


func refresh_equipment_menu(root: Object) -> void:
	if screen.is_pause_equipment_active():
		screen.update_pause_ui(root, Callable(root, "_pixel_text_texture"))
	else:
		screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func pause_back(root: Object) -> void:
	if screen.pause_page != 0:
		screen.set_pause_page(root, 0)
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
		return
	root.call("_close_hub_to_run")


func pause_equipment_back(root: Object) -> void:
	if screen.hub_equipment_mode == EquipmentMenuLayout.MODE_REMOVE_ALL_CONFIRM:
		root.call("_cancel_hub_remove_all")
	elif screen.hub_gear_browsing:
		root.call("_close_hub_gear_browse")
	elif not screen.hub_equipment_action_focus:
		screen.hub_equipment_action_focus = true
		screen.hub_equipment_mode = EquipmentMenuLayout.MODE_COMMAND
		screen.hub_touch_candidate_slot = ""
		screen.hub_touch_candidate_index = -1
		screen.refresh_equipment_menu(root)
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
	else:
		screen.pause_back(root)



func update_pause_input(root: GameplayState) -> void:
	if screen.pause_overlay == null or not screen.pause_overlay.visible:
		return
	if screen.pause_page == 2 and screen.is_pause_equipment_active():
		var touch_scroll := root._input_touch_scroll_y() as float
		if not is_zero_approx(touch_scroll):
			screen.scroll_hub_content(root, touch_scroll)
			screen.refresh_equipment_menu(root)
		screen._update_pause_equipment_input(root)
		return
	screen._pause_menu_input_controller.update(
		root,
		screen._pause_menu_state,
		screen._pause_screen_presenter,
		Callable(screen, "update_pause_ui"),
		Callable(screen, "refresh_debug_menu")
	)



# --- Debug-page and pause-equipment input ---
func refresh_debug_menu(root: GameplayState) -> void:
	var session := root.get_node_or_null("DebugSessionController") as DebugSessionController
	if session == null:
		return
	var stats: StatsComponent = root.player_stats
	var debug_level := session.player_level_override
	var level := debug_level if debug_level > 0 else (stats.level if stats != null else 1)
	var geometry: ActorGeometryDebugDrawer = root.actor_geometry_debug_drawer
	var context: Variant = screen.PauseDebugMenuContextScript.new() as PauseDebugMenuContext
	context.run_number = session.selected_run_number
	context.player_level = level
	context.unspent_stat_points = session.debug_unassigned_stat_points
	context.reset_confirmation_armed = session.reset_confirmation_armed
	context.invulnerable = session.invulnerable
	context.unlimited_chroma = session.unlimited_chroma
	context.enemies_paused = session.enemies_paused
	context.geometry_guides = geometry.enabled if geometry != null else false
	context.selected_row = screen.debug_menu_row
	screen._pause_screen_presenter.refresh_debug_menu(context, Callable(root, "_pixel_text_texture"))


func _update_pause_equipment_input(root: GameplayState) -> void:
	if bool(root._is_menu_back_just_pressed()):
		if screen.hub_equipment_mode == EquipmentMenuLayout.MODE_REMOVE_ALL_CONFIRM:
			root._cancel_hub_remove_all()
		elif screen.hub_gear_browsing:
			root._close_hub_gear_browse()
		elif not screen.hub_equipment_action_focus:
			screen.hub_equipment_action_focus = true
			screen.hub_equipment_mode = EquipmentMenuLayout.MODE_COMMAND
			screen.refresh_equipment_menu(root)
			root._play_sound("ui_decline", 0.0, 1.0)
		else:
			root._pause_back()
		return
	if screen.hub_equipment_mode == EquipmentMenuLayout.MODE_REMOVE_ALL_CONFIRM:
		if bool(root._is_menu_confirm_just_pressed()):
			root._remove_all_hub_gear()
		return
	if screen.hub_gear_browsing:
		if bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_gear_candidate_grid(0, -1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_gear_candidate_grid(0, 1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_gear_candidate_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_gear_candidate_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()): root._hub_item_action()
		return
	if screen.hub_equipment_action_focus:
		if bool(root._is_menu_direction_just_pressed(&"ui_left")) or bool(root._is_menu_direction_just_pressed(&"ui_right")):
			root._shift_hub_action_column(-1 if bool(root._is_menu_direction_just_pressed(&"ui_left")) else 1)
			root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()):
			match screen.hub_action_column:
				0: root._hub_item_action()
				1: root._remove_hub_gear()
				2: root._remove_all_hub_gear()
				_: root._play_sound("ui_no_input", 0.0, 1.0)
		return
	if screen.hub_equipment_mode == EquipmentMenuLayout.MODE_SLOT_REMOVE:
		if bool(root._is_menu_confirm_just_pressed()): root._remove_hub_gear()
		elif bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_slot_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_slot_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		return
	if bool(root._is_menu_confirm_just_pressed()): root._select_hub_gear_slot(screen.hub_item_index)
	elif bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_slot_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_slot_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)



# --- Settings construction, navigation, and value presentation ---
func build_settings(parent: Node, pixel_texture: Callable, adjust_callback: Callable, close_callback: Callable, select_option_callback: Callable = Callable()) -> Dictionary:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	var root_node: Variant = screen.get_parent()
	var settings_service: SettingsService = root_node.get("settings_service") as SettingsService if root_node != null else null
	return screen._settings_screen_presenter.build(parent, screen.display_view_size, pixel_texture, adjust_callback, close_callback, select_option_callback, screen._menu_widget_factory, screen._menu_prompt_texture_factory, screen._menu_cursor_animator, screen.CURSOR_LEFT_GAP, screen, settings_service)


func _position_settings_controls() -> void:
	screen._settings_screen_presenter.position_controls(screen.display_view_size)


func open_settings(root: Object, origin: StringName) -> void:
	if screen.settings_presenter.overlay == null:
		return
	screen.settings_presenter.origin = origin
	screen.settings_presenter.row = 0
	screen.settings_presenter.interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	# Settings replaces its source screen. Leaving the pause panel visible under
	# it makes focus and touch hit-testing ambiguous, especially on the web port.
	if origin == &"pause":
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		if screen.pause_overlay != null:
			screen.pause_overlay.visible = false
		screen.set_menu_world_hidden(root, true)
	elif origin == &"title":
		if screen.title_presenter.overlay != null:
			screen.title_presenter.overlay.visible = false
	screen.settings_presenter.overlay.visible = true
	screen.settings_presenter.overlay.modulate.a = 1.0
	screen.set_state(&"settings")
	screen.update_settings_ui(root, Callable(root, "_pixel_text_texture"))
	screen._focus_settings_selection()


func close_settings(root: Object) -> void:
	if screen.settings_presenter.overlay != null:
		screen.settings_presenter.overlay.visible = false
	screen.settings_presenter.interact_input_was_down = false
	if screen.settings_presenter.origin == &"pause":
		if screen.pause_overlay != null:
			screen.pause_overlay.visible = true
		screen.hub_pause_mode = true
		screen.pause_page = 0
		screen.pause_menu_row = 2
		screen.set_state(&"pause")
		screen.update_pause_ui(root, Callable(root, "_pixel_text_texture"))
	else:
		screen.set_menu_world_hidden(root, false)
		if screen.title_presenter.overlay != null: screen.title_presenter.overlay.visible = true
		screen.menu_input_release_lock = true
		screen.set_state(&"title")
		screen.title_presenter.menu_row = 2
		if screen.title_presenter.settings_button != null: screen.title_presenter.settings_button.visible = true
		if screen.title_presenter.cloud_button != null: screen.title_presenter.cloud_button.visible = true
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func update_settings_ui(root: Object, pixel_texture: Callable) -> void:
	var service := root.get("settings_service") as SettingsService
	var highlight := PaletteLibrary.accent(String(root.get("current_player_palette_name")))
	screen._settings_screen_presenter.update_visuals(service, pixel_texture, highlight, screen._menu_back_prompt_for(root), screen._menu_uses_face_art(root))


func _settings_option_index(row: int, values: Dictionary) -> int:
	return screen._settings_screen_presenter.option_index(row, values)


func _settings_option_index_for_cursor(row: int) -> int:
	return screen._settings_screen_presenter.option_index_for_cursor(row)


func select_setting_option(root: Object, row: int, option_index: int) -> void:
	var service := root.get("settings_service") as SettingsService
	if service == null:
		return
	screen._settings_screen_presenter.select_option(service, row, option_index)
	screen.update_settings_ui(root, Callable(root, "_pixel_text_texture"))


func adjust_setting(root: Object, row: int, direction: int) -> void:
	var service := root.get("settings_service") as SettingsService
	if service == null:
		return
	screen._settings_screen_presenter.adjust_option(service, row, direction)
	screen.update_settings_ui(root, Callable(root, "_pixel_text_texture"))


func _update_settings_cursor() -> void:
	screen._settings_screen_presenter.update_cursor()



func update_settings_input(root: Object) -> void:
	if screen.settings_presenter.overlay == null or not screen.settings_presenter.overlay.visible:
		return
	if bool(root.call("_is_menu_back_just_pressed")):
		screen.close_settings(root)
		return
	var row_count: Variant = screen.settings_presenter.value_buttons.size() + (1 if screen.settings_presenter.back_button != null else 0)
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
		screen.settings_presenter.row = posmod(screen.settings_presenter.row - 1, row_count)
		screen.update_settings_ui(root, Callable(root, "_pixel_text_texture"))
		screen._focus_settings_selection()
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		screen.settings_presenter.row = posmod(screen.settings_presenter.row + 1, row_count)
		screen.update_settings_ui(root, Callable(root, "_pixel_text_texture"))
		screen._focus_settings_selection()
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif screen.settings_presenter.row < screen.settings_presenter.value_buttons.size() and bool(root.call("_is_menu_direction_just_pressed", &"ui_left")):
		screen.adjust_setting(root, screen.settings_presenter.row, -1)
	elif screen.settings_presenter.row < screen.settings_presenter.value_buttons.size() and bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
		screen.adjust_setting(root, screen.settings_presenter.row, 1)
	elif bool(root.call("_is_menu_confirm_just_pressed")):
		if screen.settings_presenter.row == screen.settings_presenter.value_buttons.size() and screen.settings_presenter.back_button != null:
			screen.settings_presenter.back_button.pressed.emit()
		elif screen.settings_presenter.row >= 0 and screen.settings_presenter.row < screen.settings_presenter.value_buttons.size():
			screen.adjust_setting(root, screen.settings_presenter.row, 1)
