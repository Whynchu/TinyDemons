extends Node
class_name ScreenStateController

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const HubProgressionDraftScript = preload("res://scripts/hub_progression_draft.gd")
const SoulVisualsScript = preload("res://scripts/soul_visuals.gd")
const PauseMenuLayoutScript = preload("res://scripts/pause_menu_layout.gd")
const MENU_CIRCLE_TEXTURE: Texture2D = preload("res://assets/artwork/circle55.png")
const MENU_X_TEXTURE: Texture2D = preload("res://assets/artwork/x55.png")
const MENU_TRIANGLE_TEXTURE: Texture2D = preload("res://assets/artwork/triangle55.png")
const MENU_SQUARE_TEXTURE: Texture2D = preload("res://assets/artwork/square55.png")
const GAME_VERSION := "0.1.39"
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/pause_menu.tscn")
const DEMON_HUB_MENU_SCENE: PackedScene = preload("res://scenes/demon_hub_menu.tscn")
## Shared left gutter for the hand cursor sprite. Menu buttons, slots, and
## prompts are targeted with their left edge this many pixels from the cursor's
## sprite origin, so the 16x16 hand's fingertip points at the item instead of
## floating far away from it.
const CURSOR_LEFT_GAP := 10.0
## Shifts the cursor sprite up this many pixels from the anchor callers pass,
## so the hand's fingertip sits 2px higher on the item.
const CURSOR_VERTICAL_RAISE := 2.0
## Horizontal idle bob for the hand cursor: it glides this many pixels to the
## right of its resting spot, then flicks back left, looping.
const CURSOR_BOB_AMOUNT := 3.0
const CURSOR_BOB_SLIDE_TIME := 0.36
const CURSOR_BOB_SNAP_TIME := 0.07
const RUN_COMPLETE_LINE_POSITIONS := [Vector2(19, 33), Vector2(19, 47), Vector2(19, 62), Vector2(123, 62), Vector2(19, 79), Vector2(123, 79), Vector2(19, 115), Vector2(19, 125), Vector2(86, 125)]
const HUB_ITEM_DETAIL_TOP := 105.0
const HUB_ITEM_DETAIL_PITCH := 7.0
const HUB_ITEM_DETAIL_PANEL_TOP := 103.0
const HUB_ITEM_DETAIL_PANEL_HEIGHT := 42.0
const HUB_GEAR_BROWSE_DETAIL_TOP := 136.0
const HUB_ITEM_TEXT_WRAP_LENGTH := 34
const STATUS_LEFT_ROW_COUNT := 10

## Hub content pages retain the old numeric values for transaction callers. The
## visible command column maps STATUS to page 5 and ALLOCATE/EQUIPMENT/SHOP/
## FUSION/BIND to pages 0..4. Keeping this translation local lets old save/menu
## probes continue to address a transaction page while the player sees the new
## FFIII-inspired command order.
const HUB_PAGE_ALLOCATE := 0
const HUB_PAGE_EQUIPMENT := 1
const HUB_PAGE_SHOP := 2
const HUB_PAGE_FUSION := 3
const HUB_PAGE_BIND := 4
const HUB_PAGE_STATUS := 5
const HUB_COMMAND_PAGE_TARGETS := [HUB_PAGE_STATUS, HUB_PAGE_ALLOCATE, HUB_PAGE_EQUIPMENT, HUB_PAGE_SHOP, HUB_PAGE_FUSION, HUB_PAGE_BIND]

signal state_changed(state: StringName)
var state: StringName = &"gameplay"
var title_particles: Array[Dictionary] = []
var _prompt_texture_cache: Dictionary = {}
var hub_overlay: ColorRect = null
var hub_summary_text: Sprite2D = null
var hub_points_text: Sprite2D = null
var hub_stat_texts: Array[Sprite2D] = []
var hub_stat_buttons: Array[Button] = []
var hub_stat_left_buttons: Array[Button] = []
var hub_stat_right_buttons: Array[Button] = []
var hub_stat_row_buttons: Array[Button] = []
var hub_respec_button: Button = null
var hub_start_button: Button = null
var hub_title_button: Button = null
var hub_derived_texts: Array[Sprite2D] = []
var hub_apply_button: Button = null
var hub_cancel_button: Button = null
var hub_auto_button: Button = null
var hub_progression_draft = HubProgressionDraftScript.new()
var hub_pending_vit: int:
	get: return hub_progression_draft.vit
	set(value): hub_progression_draft.vit = maxi(int(value), 0)
var hub_pending_str: int:
	get: return hub_progression_draft.strength
	set(value): hub_progression_draft.strength = maxi(int(value), 0)
var hub_pending_def: int:
	get: return hub_progression_draft.def
	set(value): hub_progression_draft.def = maxi(int(value), 0)
var hub_pending_spd: int:
	get: return hub_progression_draft.spd
	set(value): hub_progression_draft.spd = maxi(int(value), 0)
var hub_pending_agi: int:
	get: return hub_progression_draft.agi
	set(value): hub_progression_draft.agi = maxi(int(value), 0)
var hub_pending_int: int:
	get: return hub_progression_draft.intelligence
	set(value): hub_progression_draft.intelligence = maxi(int(value), 0)
var hub_pending_mnd: int:
	get: return hub_progression_draft.mnd
	set(value): hub_progression_draft.mnd = maxi(int(value), 0)
var hub_opened_from_npc := false
var hub_pause_mode := false
var hub_is_root := true
var hub_menu_row := 0
var hub_stat_row := 0
var hub_action_column := 0
var hub_content_focus := false
var hub_equipment_action_focus := false
var hub_interact_input_was_down := false
var hub_cancel_input_was_down := false
var menu_input_release_lock := false
var hub_page_previous_input_was_down := false
var hub_page_next_input_was_down := false
var pause_input_was_down := false
var pause_interact_input_was_down := false
var pause_cancel_input_was_down := false
var hub_page := 0
var hub_root_page: Control = null
var hub_page_roots: Dictionary = {}
var hub_item_index := 0
var hub_list_scroll := 0.0
var hub_choice_scroll := 0.0
var hub_list_cursor: Sprite2D = null
var hub_slot_cursor: Sprite2D = null
var hub_choice_cursor: Sprite2D = null
var hub_gear_candidate_indices := {"weapon": 0, "head": 0, "body": 0, "arm": 0, "shield": 0, "accessory": 0}
var hub_gear_browsing := false
var hub_fusion_candidates: Array[ItemInstance] = []
var hub_fusion_candidates_dirty := true
var hub_fusion_count := 1
var hub_fusion_message := ""
var hub_gear_choice_texts: Array[Sprite2D] = []
var hub_gear_choice_buttons: Array[Button] = []
var hub_gear_slot_buttons: Array[Button] = []
var hub_gear_stat_texts: Array[Sprite2D] = []
var hub_gear_stat_panel: Panel = null
var hub_allocate_panel: Panel = null
var hub_allocate_preview_panel: Panel = null
var hub_allocate_preview_title: Sprite2D = null
var hub_allocate_preview_texts: Array[Sprite2D] = []
var hub_item_list_panel: Panel = null
var hub_item_content_clip: Control = null
var hub_gear_choice_panel: Panel = null
var hub_gear_choice_content_clip: Control = null
var hub_cursor_text: Sprite2D = null
var hub_page_buttons: Array[Button] = []
var hub_back_button: Button = null
var hub_player_card_panel: Panel = null
var hub_player_card_texts: Array[Sprite2D] = []
var hub_status_texts: Array[Sprite2D] = []
var hub_context_text: Sprite2D = null
var hub_currency_text: Sprite2D = null
var hub_currency_icon: Sprite2D = null
var hub_binding_panel: Panel = null
var hub_binding_texts: Array[Sprite2D] = []
var hub_binding_action_button: Button = null
var hub_binding_message := ""
var pause_resume_button: Button = null
var pause_settings_button: Button = null
var pause_quit_button: Button = null
var pause_cursor_text: Sprite2D = null
var pause_menu_buttons: Array[Button] = []
var pause_overlay: ColorRect = null
var pause_title_text: Sprite2D = null
var pause_page := 0
var pause_root_page: Control = null
var pause_page_roots: Dictionary = {}
var pause_menu_row := 0
var pause_player_card_panel: Panel = null
var pause_player_card_texts: Array[Sprite2D] = []
var pause_player_portrait: Sprite2D = null
var pause_gold_icon: Sprite2D = null
var pause_gold_text: Sprite2D = null
var pause_soul_text: Sprite2D = null
var pause_resource_icon: Sprite2D = null
var pause_status_texts: Array[Sprite2D] = []
var pause_equipment_texts: Array[Sprite2D] = []
var pause_description_text: Sprite2D = null
var pause_back_button: Button = null
var pause_status_button: Button = null
var pause_equipment_button: Button = null
var hub_item_name_text: Sprite2D = null
var hub_item_list_texts: Array[Sprite2D] = []
var hub_item_row_buttons: Array[Button] = []
var hub_shop_price_texts: Array[Sprite2D] = []
var hub_item_detail_texts: Array[Sprite2D] = []
var hub_item_detail_panel: Panel = null
var hub_item_action_button: Button = null
var hub_equipment_action_buttons: Array[Button] = []
var hub_fusion_decrease_button: Button = null
var hub_fusion_increase_button: Button = null
var title_overlay: ColorRect = null
var title_start_button: Button = null
var title_continue_button: Button = null
var title_settings_button: Button = null
var title_cloud_button: Button = null
var title_frame_timer := 0.0
var title_screen_text: Sprite2D = null
var title_start_text: Sprite2D = null
var title_settings_text: Sprite2D = null
var title_cursor_text: Sprite2D = null
var title_menu_row := 0
var title_transition_active := false
var title_transition_timer := 0.0
var title_particle_layer: Node2D = null
var pending_title_destination := ""
var archetype_overlay: ColorRect = null
var archetype_hold_cover: ColorRect = null
var archetype_preview: Sprite2D = null
var archetype_name_text: Sprite2D = null
var archetype_preview_frames: Array[Texture2D] = []
var archetype_preview_palette := ""
var archetype_start_button: Button = null
var archetype_left_buttons: Array[Button] = []
var archetype_right_buttons: Array[Button] = []
var archetype_type_left_button: Button = null
var archetype_type_right_button: Button = null
var archetype_frame_timer := 0.0
var archetype_index := 0
var archetype_color_index := 0
var archetype_menu_row := 0
var archetype_transition_active := false
var archetype_transition_timer := 0.0
var archetype_fade_out := false
var archetype_arrow_anim_timer := 0.0
var archetype_arrow_anim_direction := 0
var selected_archetype := StatsComponent.AllocationProfile.BALANCED
var starter_flame_index := 0
var save_select_overlay: ColorRect = null
var save_select_mode := "continue"
var save_select_index := 0
var save_overwrite_slot := 0
var save_overwrite_prompt_active := false
var save_overwrite_choice := 0
const NAME_ENTRY_COLUMNS := 8
const NAME_ENTRY_ROWS := 4
var name_entry_overlay: ColorRect = null
var name_entry_prompt_text: Sprite2D = null
var name_entry_name_text: Sprite2D = null
var name_entry_page_text: Sprite2D = null
var name_entry_message_text: Sprite2D = null
var name_entry_confirm_text: Sprite2D = null
var name_entry_back_text: Sprite2D = null
var name_entry_actions_text: Sprite2D = null
var name_entry_cursor_text: Sprite2D = null
var name_entry_preview: Sprite2D = null
var name_entry_field_panel: Panel = null
var name_entry_cell_buttons: Array[Button] = []
var name_entry_cell_texts: Array[Sprite2D] = []
var name_entry_name := ""
var name_entry_page := 0
var name_entry_row := 0
var name_entry_column := 0
var name_entry_pending_slot := -1
var name_entry_finish_callback := Callable()
var name_entry_cancel_callback := Callable()
var name_entry_owner: Object = null
var run_complete_overlay: ColorRect = null
var run_complete_texts: Array[Sprite2D] = []
var run_complete_button: Button = null
var run_complete_cursor: Sprite2D = null
var run_complete_footer_text: Sprite2D = null
var save_select_footer_text: Sprite2D = null
var archetype_footer_text: Sprite2D = null
var game_over_cursor_text: Sprite2D = null
var game_over_footer_text: Sprite2D = null
var game_over_row := 0
var player_palette_name := "blue"
var settings_overlay: ColorRect = null
var settings_title_text: Sprite2D = null
var settings_row_labels: Array[Sprite2D] = []
var settings_value_buttons: Array[Button] = []
var settings_left_buttons: Array[Button] = []
var settings_right_buttons: Array[Button] = []
var settings_option_buttons: Array[Array] = []
var settings_option_labels: Array[Array] = []
var settings_description_text: Sprite2D = null
var settings_back_button: Button = null
var settings_cursor_text: Sprite2D = null
var settings_row := 0
var settings_origin := &"title"
var settings_interact_input_was_down := false
var display_view_size := Vector2(DisplayLayout.NATIVE_SIZE)


func apply_display_layout(root: Object) -> void:
	var display := root.get("display_controller") as DisplayController
	# FULL keeps the authored 160px height but can expose additional logical
	# width when the browser viewport is wider than the configured content size.
	# Menus are full-view overlays, so their frame and responsive anchors must
	# use that visible width instead of the narrower content-scale width.
	display_view_size = display.visible_view_size_value() if display != null and DisplayLayout.is_full_aspect(display.aspect_mode()) else (Vector2(display.view_size_value()) if display != null else Vector2(DisplayLayout.NATIVE_SIZE))
	var game_over := root.get("game_over_overlay") as ColorRect
	for overlay in [title_overlay, save_select_overlay, name_entry_overlay, archetype_overlay, run_complete_overlay, game_over] as Array:
		if overlay != null and bool(overlay.get_meta("display_full_view", false)):
			overlay.size = display_view_size
			_resize_menu_frame(overlay, display_view_size)
	if title_overlay != null:
		var title := title_overlay.get_node_or_null("TitleText") as Sprite2D
		if title != null and title.texture != null: title.position.x = (display_view_size.x - title.texture.get_width() * title.scale.x) * 0.5
		var version := title_overlay.get_node_or_null("TitleVersion") as Sprite2D
		if version != null: version.position = Vector2(4.0, display_view_size.y - 8.0)
		var title_x := (display_view_size.x - 64.0) * 0.5
		if title_start_button != null: title_start_button.position.x = title_x
		if title_continue_button != null: title_continue_button.position.x = title_x
		if title_settings_button != null: title_settings_button.position.x = title_x
		if title_cloud_button != null: title_cloud_button.position.x = title_x
	if hub_overlay != null:
		hub_overlay.position = (display_view_size - hub_overlay.size) * 0.5
	if pause_overlay != null:
		pause_overlay.position = (display_view_size - pause_overlay.size) * 0.5
	if run_complete_overlay != null:
		run_complete_overlay.position = Vector2.ZERO
		run_complete_overlay.size = display_view_size
		_position_run_complete_controls()
	if title_overlay != null and title_cursor_text != null and title_start_button != null:
		# Title buttons never take Control focus (retro-styled), so drive the
		# cursor from the active row's static base y instead of the focus owner.
		var row_buttons: Array[Button] = [title_start_button, title_continue_button, title_cloud_button, title_settings_button]
		var row_selected := row_buttons[clampi(title_menu_row, 0, row_buttons.size() - 1)] if not row_buttons.is_empty() else null
		if row_selected != null:
			var base_y: float = row_selected.get_meta("title_base_y") as float if row_selected.has_meta("title_base_y") else row_selected.position.y
			move_menu_cursor(title_cursor_text, Vector2(row_selected.position.x - CURSOR_LEFT_GAP, base_y + 4.0), false)
	if archetype_overlay != null:
		var cover := archetype_overlay.get_node_or_null("ArchetypeHoldCover") as ColorRect
		if cover != null: cover.size = display_view_size
		if archetype_type_left_button != null: archetype_type_left_button.position = Vector2(display_view_size.x * 0.5 - 45.0, 33.0)
		if archetype_type_right_button != null: archetype_type_right_button.position = Vector2(display_view_size.x * 0.5 + 35.0, 33.0)
		if archetype_start_button != null: archetype_start_button.position.x = (display_view_size.x - archetype_start_button.size.x) * 0.5
		for button in archetype_left_buttons: button.position = Vector2(display_view_size.x * 0.5 - 45.0, 69.0)
		for button in archetype_right_buttons: button.position = Vector2(display_view_size.x * 0.5 + 35.0, 69.0)
	if hub_overlay != null:
		hub_overlay.position = Vector2.ZERO
		hub_overlay.size = display_view_size
		_position_hub_controls()
	if settings_overlay != null:
		settings_overlay.size = display_view_size
		_position_settings_controls()
	var cloud_panel := root.get("cloud_save_panel") as CloudSavePanel
	if cloud_panel != null: cloud_panel.apply_layout(display_view_size)
	if name_entry_overlay != null:
		name_entry_overlay.size = display_view_size
		_position_name_entry_controls()
	if pause_overlay != null:
		pause_overlay.position = Vector2.ZERO
		pause_overlay.size = display_view_size
		_resize_menu_frame(pause_overlay, display_view_size)
		_position_pause_controls()
	var game_over_button := root.get("game_over_button") as Button
	var game_over_title_button := root.get("game_over_title_button") as Button
	if game_over_button != null:
		game_over_button.position.x = (display_view_size.x - game_over_button.size.x) * 0.5
	if game_over_title_button != null:
		game_over_title_button.position.x = (display_view_size.x - game_over_title_button.size.x) * 0.5
	if game_over_footer_text != null:
		game_over_footer_text.position = Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0)
	if game_over_cursor_text != null:
		var selected_game_over := game_over_title_button if game_over_row == 1 else game_over_button
		if selected_game_over != null:
			move_menu_cursor(game_over_cursor_text, Vector2(selected_game_over.position.x - CURSOR_LEFT_GAP, selected_game_over.position.y + 3.0), false)
	if run_complete_footer_text != null:
		run_complete_footer_text.position = Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0)
	if save_select_footer_text != null:
		save_select_footer_text.position = Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0)
	if archetype_footer_text != null:
		archetype_footer_text.position = Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0)


func _view_size_for_parent(parent: Node) -> Vector2:
	var current: Node = parent
	while current != null:
		var display := current.get("display_controller") as DisplayController
		if display != null:
			return Vector2(display.view_size_value())
		current = current.get_parent()
	return display_view_size


func layout_view_size() -> Vector2:
	return display_view_size


func create_view_overlay(parent: Node, overlay_name: String, color: Color, z_index: int, visible: bool = true) -> ColorRect:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_overlay(parent, overlay_name, display_view_size, color, z_index, visible)
	overlay.set_meta("display_full_view", true)
	return overlay

func retro_button_alpha(timer: float) -> float:
	var phase := fmod(timer, 2.4); var pulse := lerpf(1.0, 0.45, (phase - 0.6) / 0.9) if phase >= 0.6 and phase < 1.5 else lerpf(0.45, 1.0, (phase - 1.5) / 0.6) if phase >= 1.5 and phase < 2.1 else 1.0; return snappedf(snappedf(pulse, 0.08), 0.125)

func retro_button_bob(timer: float) -> float: return snappedf(sin(timer / 3.6 * TAU) * 1.5, 0.5)

func set_archetype_button_state(button: Button, active: bool, color: Color) -> void:
	if button == null: return
	if bool(button.get_meta("archetype_arrow", false)):
		button.modulate = color if active else Color.WHITE
		return
	var normal := StyleBoxFlat.new(); normal.bg_color = Color(0, 0, 0, 0); normal.border_color = Color(color if active else Color.WHITE, 0.95 if active else 0.0); normal.set_border_width_all(1 if active else 0); var focus := StyleBoxFlat.new(); focus.bg_color = Color(color, 0.18 if active else 0.0); focus.border_color = color if active else Color.WHITE; focus.set_border_width_all(1 if active else 0)
	button.add_theme_color_override("font_color", color if active else Color.WHITE); button.add_theme_color_override("font_hover_color", color if active else Color.WHITE); button.add_theme_color_override("font_focus_color", color if active else Color.WHITE); button.add_theme_color_override("font_disabled_color", color if active else Color(0.65, 0.65, 0.65)); button.add_theme_stylebox_override("normal", normal); button.add_theme_stylebox_override("hover", focus); button.add_theme_stylebox_override("focus", focus); button.add_theme_stylebox_override("pressed", focus); button.add_theme_stylebox_override("disabled", focus if active else normal)
	for child in button.get_children():
		if child is Sprite2D: (child as Sprite2D).modulate = color if active else Color(0.65, 0.65, 0.65) if button.disabled else Color.WHITE


func set_state(new_state: StringName) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func update_title_flow(root: Object, delta: float) -> void:
	var cloud_panel := root.get("cloud_save_panel") as CloudSavePanel
	if cloud_panel != null and cloud_panel.overlay != null and cloud_panel.overlay.visible:
		cloud_panel.update_input()
		return
	if settings_overlay != null and settings_overlay.visible:
		root.call("_update_settings_input")
		return
	if menu_input_release_lock:
		# A confirm used to close title Settings must be released before the title
		# screen can dispatch its focused button. Otherwise BACK immediately falls
		# through to New Game on the next frame.
		var released := not bool(root.call("_is_menu_confirm_pressed")) and not bool(root.call("_is_menu_back_pressed"))
		if released:
			menu_input_release_lock = false
		else:
			return
	if archetype_overlay != null and archetype_overlay.visible and not title_transition_active:
		root.call("_update_archetype_input", delta)
		return
	if title_transition_active:
		update_particles(delta, Callable(root, "_snap_half_pixel"))
		title_transition_timer += delta
		var overlay := title_overlay
		var fade_start := 0.72
		var fade_duration := 0.42
		# Save selection is still a title-screen state. Keep the black cover
		# opaque while the fizzle runs; fading it out here exposes the live game
		# scene before the save menu has been opened.
		var opening_save_select := pending_title_destination == "save_select"
		overlay.modulate.a = 1.0 if opening_save_select or title_transition_timer < fade_start else clampf(1.0 - (title_transition_timer - fade_start) / fade_duration, 0.0, 1.0)
		if title_transition_timer >= fade_start + fade_duration:
			title_transition_active = false
			if pending_title_destination == "save_select":
				pending_title_destination = ""
				overlay.visible = true
				overlay.modulate.a = 1.0
				root.call("_open_save_select_after_title_transition")
			else:
				overlay.visible = false
				archetype_transition_timer = -0.35
				root.call("_select_archetype_menu_row", 0)
		return
	title_frame_timer += delta
	var frame_timer := title_frame_timer
	var new_game := title_start_button
	var continue_button := title_continue_button
	var settings_button := title_settings_button
	var cloud_button := title_cloud_button
	if new_game != null: new_game.modulate.a = retro_button_alpha(frame_timer); new_game.position.y = 93.0 + retro_button_bob(frame_timer)
	if continue_button != null: continue_button.modulate.a = retro_button_alpha(frame_timer + 0.3); continue_button.position.y = 109.0 + retro_button_bob(frame_timer + 0.3)
	if cloud_button != null: cloud_button.modulate.a = retro_button_alpha(frame_timer + 0.6); cloud_button.position.y = 125.0 + retro_button_bob(frame_timer + 0.6)
	if settings_button != null: settings_button.modulate.a = retro_button_alpha(frame_timer + 0.9); settings_button.position.y = 141.0 + retro_button_bob(frame_timer + 0.9)
	var title_buttons: Array[Button] = [new_game, continue_button, cloud_button, settings_button]
	var available_rows: Array[int] = []
	for index in title_buttons.size():
		if title_buttons[index] != null and not title_buttons[index].disabled: available_rows.append(index)
	if available_rows.is_empty(): return
	if not available_rows.has(title_menu_row): title_menu_row = available_rows[0]
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
		var current_index := available_rows.find(title_menu_row)
		title_menu_row = available_rows[posmod(current_index - 1, available_rows.size())]
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		var current_index := available_rows.find(title_menu_row)
		title_menu_row = available_rows[posmod(current_index + 1, available_rows.size())]
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	var selected := title_buttons[title_menu_row]
	var cursor := title_cursor_text
	if cursor != null and selected != null:
		cursor.visible = true
		# The title buttons float up/down every frame (retro bob); anchor the
		# cursor to the button's static base row so it stays put and bobs like the
		# other menus instead of chasing the animated position.
		var base_y: float = selected.get_meta("title_base_y") as float if selected.has_meta("title_base_y") else selected.position.y
		move_menu_cursor(cursor, Vector2(selected.position.x - CURSOR_LEFT_GAP, base_y + 4.0))
		cursor.texture = MENU_CURSOR_TEXTURE
	if bool(root.call("_is_menu_confirm_just_pressed")) and selected != null and not selected.disabled:
		root.call("_play_sound", "enemy_death", -6.0, 0.95)
		selected.pressed.emit()


func update_archetype_input(root: Object, delta: float) -> void:
	if archetype_footer_text != null:
		archetype_footer_text.texture = _pixel_prompt_texture(Callable(root, "_pixel_text_texture"), _menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
	if archetype_transition_active:
		archetype_transition_timer += delta
		var transition_timer := archetype_transition_timer
		if transition_timer < 0.0:
			return
		if not archetype_fade_out:
			archetype_hold_cover.visible = false
			archetype_transition_active = false
			return
		archetype_overlay.modulate.a = clampf(1.0 - transition_timer / 0.42, 0.0, 1.0)
		if transition_timer >= 0.42:
			archetype_transition_active = false
			if archetype_fade_out:
				archetype_overlay.visible = false
		return
	if menu_input_release_lock:
		var released := not bool(root.call("_is_menu_confirm_pressed")) and not bool(root.call("_is_menu_back_pressed"))
		if released: menu_input_release_lock = false
		else: return
	if bool(root.call("_is_menu_back_just_pressed")):
		root.call("_cancel_character_creation")
		return
	archetype_frame_timer += delta
	archetype_arrow_anim_timer = maxf(archetype_arrow_anim_timer - delta, 0.0)
	root.call("_update_archetype_preview_animation")
	root.call("_update_archetype_arrow_animation")
	var button := archetype_start_button
	button.modulate.a = retro_button_alpha(archetype_frame_timer)
	button.position.y = 104.0 + retro_button_bob(archetype_frame_timer)
	var row := archetype_menu_row
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
		root.call("_select_archetype_menu_row", row - 1)
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		root.call("_select_archetype_menu_row", row + 1)
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) or bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
		var direction := -1 if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) else 1
		if row == 0: root.call("_shift_archetype", direction)
		else: root.call("_select_archetype_menu_row", 1)
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	if bool(root.call("_is_menu_confirm_just_pressed")):
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		if row == 1: root.call("_start_selected_archetype")
		else: root.call("_select_archetype_menu_row", 1)


func start_selected_archetype(root: Object) -> void:
	if archetype_overlay == null or not archetype_overlay.visible or bool(root.get("loading_screen_active")):
		return
	var profile := root.get("player_profile") as PlayerProfile
	if profile != null and not profile.has_started:
		var stats := root.get("player_stats") as StatsComponent
		stats.manual_allocation_enabled = false
		# Flame owns the small class identity package. Exact flame bonuses are
		# intentionally deferred; the initial profile uses the balanced baseline.
		stats.allocation_profile = StatsComponent.AllocationProfile.BALANCED
		var initial_stats := stats.get_stats()
		profile.base_vit = int(initial_stats["VIT"])
		profile.base_str = int(initial_stats["STR"])
		profile.base_def = int(initial_stats["DEF"])
		profile.base_agi = int(initial_stats.get("AGI", initial_stats.get("SPD", 1)))
		profile.base_int = int(initial_stats.get("INT", 1))
		profile.base_mnd = int(initial_stats.get("MND", 1))
		var starter_flame: StringName = ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[starter_flame_index]
		profile.starter_flame = starter_flame
		profile.allocation_profile = int(StatsComponent.AllocationProfile.BALANCED)
		profile.palette_name = ASPECT_CATALOG_SCRIPT.palette_for_flame(starter_flame)
		profile.has_started = true
		profile.ensure_starter_items()
		root.call("_apply_profile_to_runtime")
		root.call("_save_player_profile")
	archetype_overlay.visible = false
	archetype_hold_cover.visible = false
	root.set("has_persistent_profile", true)
	root.call("_enter_starting_room_from_menu")


func start_new_game(root: Object) -> void:
	if title_overlay == null or not title_overlay.visible:
		return
	root.call("_spawn_title_pixel_breakup", title_screen_text)
	root.call("_spawn_title_pixel_breakup", title_start_text)
	root.call("_spawn_title_button_frame_breakup")
	title_overlay.visible = true; title_overlay.modulate.a = 1.0
	title_transition_active = true; title_transition_timer = 0.0
	if title_screen_text != null: title_screen_text.visible = false
	if title_start_text != null: title_start_text.visible = false
	if title_start_button != null: title_start_button.visible = false; title_start_button.release_focus()
	if title_continue_button != null: title_continue_button.visible = false; title_continue_button.release_focus()
	if title_settings_button != null: title_settings_button.visible = false; title_settings_button.release_focus()
	if title_cloud_button != null: title_cloud_button.visible = false; title_cloud_button.release_focus()
	if title_cursor_text != null: title_cursor_text.visible = false
	archetype_overlay.visible = true; set_state(&"archetype")
	archetype_overlay.modulate.a = 1.0
	archetype_hold_cover.visible = true
	archetype_transition_active = true; archetype_transition_timer = -1.0; archetype_fade_out = false


func start_save_select(root: Object, mode: String) -> void:
	if title_overlay == null or not title_overlay.visible:
		return
	save_select_mode = mode
	pending_title_destination = "save_select"
	root.call("_spawn_title_pixel_breakup", title_screen_text)
	root.call("_spawn_title_pixel_breakup", title_start_text)
	root.call("_spawn_title_button_frame_breakup")
	title_overlay.visible = true
	title_overlay.modulate.a = 1.0
	title_transition_active = true
	title_transition_timer = 0.0
	if title_screen_text != null: title_screen_text.visible = false
	if title_start_text != null: title_start_text.visible = false
	if title_start_button != null: title_start_button.visible = false; title_start_button.release_focus()
	if title_continue_button != null: title_continue_button.visible = false; title_continue_button.release_focus()
	if title_settings_button != null: title_settings_button.visible = false; title_settings_button.release_focus()
	if title_cloud_button != null: title_cloud_button.visible = false; title_cloud_button.release_focus()
	if title_cursor_text != null: title_cursor_text.visible = false


func show_character_creation(root: Object) -> void:
	if title_overlay == null or archetype_overlay == null:
		return
	title_overlay.visible = false
	title_transition_active = false
	pending_title_destination = ""
	archetype_overlay.visible = true
	archetype_overlay.modulate.a = 1.0
	archetype_overlay.z_index = 3
	set_state(&"archetype")
	if archetype_hold_cover != null: archetype_hold_cover.visible = false
	archetype_transition_active = false
	menu_input_release_lock = true
	root.call("_select_archetype_menu_row", 0)


func update_player_death(root: Object, delta: float, game_over_fade_time: float) -> void:
	var death_timer := float(root.get("player_death_timer")) + delta
	root.set("player_death_timer", death_timer)
	var overlay := root.get("player_death_overlay") as Sprite2D
	var tuning := root.get("player_tuning") as PlayerTuning
	if overlay != null:
		if death_timer < tuning.death_particle_delay:
			overlay.modulate.a = clampf(death_timer / tuning.death_fade_time, 0.0, 1.0)
		elif not bool(root.get("player_death_particles_started")):
			root.set("player_death_particles_started", true); root.call("_spawn_player_death_pixels"); overlay.queue_free(); root.set("player_death_overlay", null)
			root.call("_play_sound", "enemy_death", -4.0, 0.90 + RandomNumberGenerator.new().randf_range(-0.06, 0.06))
	if not bool(root.get("player_death_particles_started")):
		return
	var death_effect_end := tuning.death_particle_delay + tuning.death_particle_lifetime
	var game_over := root.get("game_over_overlay") as ColorRect
	if game_over != null and game_over.visible:
		var fade_timer := float(root.get("game_over_fade_timer")) + delta
		root.set("game_over_fade_timer", fade_timer); game_over.modulate.a = clampf(fade_timer / game_over_fade_time, 0.0, 1.0)
		var restart := root.get("game_over_button") as Button
		var title := root.get("game_over_title_button") as Button
		if restart != null: restart.modulate.a = retro_button_alpha(fade_timer); restart.position.y = 105.0 + retro_button_bob(fade_timer)
		if title != null: title.modulate.a = retro_button_alpha(fade_timer + 0.6); title.position.y = 121.0 + retro_button_bob(fade_timer + 0.4)
		var selected := title if game_over_row == 1 and title != null and not title.disabled else restart
		if selected != null:
			game_over_row = 1 if selected == title else 0
		if game_over_cursor_text != null:
			game_over_cursor_text.visible = selected != null
			if selected != null: move_menu_cursor(game_over_cursor_text, Vector2(selected.position.x - CURSOR_LEFT_GAP, selected.position.y + 3.0), false)
			game_over_cursor_text.texture = MENU_CURSOR_TEXTURE
		if game_over_footer_text != null:
			game_over_footer_text.visible = true
			game_over_footer_text.texture = _pixel_prompt_texture(Callable(root, "_pixel_text_texture"), _menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
	elif death_timer >= death_effect_end + float(root.get("player_tuning").death_observe_time):
		root.call("_show_game_over")


func update_game_over_input(root: Object) -> void:
	var overlay := root.get("game_over_overlay") as ColorRect
	if overlay == null or not overlay.visible:
		return
	if menu_input_release_lock:
		if not bool(root.call("_is_menu_confirm_pressed")) and not bool(root.call("_is_menu_back_pressed")):
			menu_input_release_lock = false
		else:
			return
	var restart := root.get("game_over_button") as Button
	var title := root.get("game_over_title_button") as Button
	if bool(root.call("_is_menu_back_just_pressed")):
		if title != null and not title.disabled:
			root.call("_play_sound", "ui_decline", 0.0, 1.0)
			title.pressed.emit()
		return
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")) or bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		game_over_row = 1 - game_over_row
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	var selected := title if game_over_row == 1 else restart
	if selected == null or selected.disabled:
		selected = restart if restart != null and not restart.disabled else title
	if selected != null:
		game_over_row = 1 if selected == title else 0
		if game_over_cursor_text != null:
			game_over_cursor_text.visible = true
			move_menu_cursor(game_over_cursor_text, Vector2(selected.position.x - CURSOR_LEFT_GAP, selected.position.y + 3.0))
	if game_over_footer_text != null:
		game_over_footer_text.visible = true
		game_over_footer_text.texture = _pixel_prompt_texture(Callable(root, "_pixel_text_texture"), _menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
	if bool(root.call("_is_menu_confirm_just_pressed")) and selected != null and not selected.disabled:
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		selected.pressed.emit()


func update_archetype_button_styles(_root: Object) -> void:
	var flame: StringName = ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[starter_flame_index]
	var color := PaletteLibrary.normal(ASPECT_CATALOG_SCRIPT.palette_for_flame(flame)); var row := archetype_menu_row
	var type_active := row == 0; var sprite_active := false; var start_active := row == 1
	var type_left := archetype_type_left_button; var type_right := archetype_type_right_button; var start := archetype_start_button
	set_archetype_button_state(type_left, type_active, color); set_archetype_button_state(type_right, type_active, color)
	for button in archetype_left_buttons: set_archetype_button_state(button, sprite_active, color)
	for button in archetype_right_buttons: set_archetype_button_state(button, sprite_active, color)
	set_archetype_button_state(start, start_active, color)


func add_particle(particle_data: Dictionary) -> void:
	title_particles.append(particle_data)


func update_particles(delta: float, snap_position: Callable) -> void:
	for index in range(title_particles.size() - 1, -1, -1):
		var particle_data := title_particles[index]
		var particle := particle_data["sprite"] as Sprite2D
		var timer := float(particle_data["timer"]) - delta
		if particle == null or timer <= 0.0:
			if particle != null:
				particle.queue_free()
			title_particles.remove_at(index)
			continue
		var logical_position := particle_data.get("logical_position", particle.position) as Vector2
		logical_position += particle_data["velocity"] as Vector2 * delta
		particle_data["logical_position"] = logical_position
		particle.position = snap_position.call(logical_position)
		particle.modulate.a = clampf(timer / float(particle_data.get("lifetime", 1.14)), 0.0, 1.0)
		particle_data["timer"] = timer


func spawn_pixel_breakup(source_sprite: Sprite2D, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	if source_sprite == null or source_sprite.texture == null:
		return
	var image := source_sprite.texture.get_image()
	if image == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.28
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var pixel_position := source_sprite.global_position
			var pixel_size := source_sprite.scale
			if source_sprite.centered:
				pixel_position -= Vector2(image.get_width(), image.get_height()) * pixel_size * 0.5
			pixel_position += Vector2(x, y) * pixel_size
			var particle := Sprite2D.new()
			particle.texture = pixel_texture.call(color) as Texture2D
			particle.centered = false
			particle.scale = pixel_size
			particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			particle.z_as_relative = true
			particle.z_index = 3
			particle.position = pixel_position
			particle_parent.add_child(particle)
			add_particle({"sprite": particle, "velocity": Vector2(0.0, -(8.0 + (noise.get_noise_2d(float(x), float(y)) + 1.0) * 14.0)), "timer": 1.14, "lifetime": 1.14, "gravity": 0.0})


func spawn_button_frame_breakup(button: Button, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	if button == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.28
	var origin := button.position
	if particle_parent is Node2D:
		origin = (particle_parent as Node2D).to_local(button.global_position)
	var width := int(button.size.x)
	var height := int(button.size.y)
	for x in range(width):
		_spawn_frame_particle(origin + Vector2(x, 0), particle_parent, pixel_texture, noise.get_noise_2d(float(x), 0.0))
		_spawn_frame_particle(origin + Vector2(x, height - 1), particle_parent, pixel_texture, noise.get_noise_2d(float(x), float(height - 1)))
	for y in range(1, height - 1):
		_spawn_frame_particle(origin + Vector2(0, y), particle_parent, pixel_texture, noise.get_noise_2d(0.0, float(y)))
		_spawn_frame_particle(origin + Vector2(width - 1, y), particle_parent, pixel_texture, noise.get_noise_2d(float(width - 1), float(y)))


func _spawn_frame_particle(frame_position: Vector2, particle_parent: Node, pixel_texture: Callable, noise_value: float) -> void:
	var particle := Sprite2D.new()
	particle.texture = pixel_texture.call(Color.WHITE) as Texture2D
	particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = true
	particle.z_index = 3
	particle.position = frame_position
	particle_parent.add_child(particle)
	var rise_speed := 8.0 + (noise_value + 1.0) * 14.0
	add_particle({"sprite": particle, "velocity": Vector2(0.0, -rise_speed), "timer": 1.14, "lifetime": 1.14, "gravity": 0.0})


func style_archetype_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(1, 1, 1, 0.12)
	focus.border_color = Color.WHITE
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)


func make_retro_button(label: String, button_position: Vector2, size: Vector2, pixel_texture: Callable) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = size
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color.WHITE
	normal.set_border_width_all(1)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(1, 1, 1, 0.12)
	focus.border_color = Color.WHITE
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	var text := Sprite2D.new()
	text.texture = pixel_texture.call(label, Color.WHITE) as Texture2D
	text.centered = true
	text.position = size * 0.5
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(text)
	return button


func make_menu_command_button(label: String, button_position: Vector2, size: Vector2, pixel_texture: Callable) -> Button:
	var button := make_retro_button(label, button_position, size, pixel_texture)
	button.focus_mode = Control.FOCUS_NONE
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	transparent.set_border_width_all(0)
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_state, transparent)
	return button


func build_game_over(parent: Node, pixel_texture: Callable, restart: Callable, return_title: Callable) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "GameOverOverlay", Color(0.015, 0.02, 0.035, 1.0), 8, false)
	overlay.modulate.a = 0.0
	var title_texture := pixel_texture.call("GAME OVER", Color.WHITE) as Texture2D
	create_sprite(overlay, "GameOverTitle", title_texture, Vector2((display_view_size.x - title_texture.get_width() * 3.0) * 0.5, 50), false, Vector2(3, 3))
	var saved_texture := pixel_texture.call("PROGRESS SAVED", Color8(167, 240, 112)) as Texture2D
	create_sprite(overlay, "GameOverSaved", saved_texture, Vector2((display_view_size.x - saved_texture.get_width()) * 0.5, 88), false)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0)
	normal_style.border_color = Color(0.72, 0.72, 0.72, 0.9)
	normal_style.set_border_width_all(1)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1, 1, 1, 0.12)
	focus_style.border_color = Color.WHITE
	focus_style.set_border_width_all(1)
	var restart_button := _make_text_button("HUB", Vector2((display_view_size.x - 42.0) * 0.5, 105), normal_style, focus_style, pixel_texture, restart)
	var title_button := _make_text_button("TITLE", Vector2((display_view_size.x - 42.0) * 0.5, 121), normal_style, focus_style, pixel_texture, return_title)
	restart_button.name = "GameOverHub"
	title_button.name = "GameOverTitle"
	overlay.add_child(restart_button)
	overlay.add_child(title_button)
	var cursor := create_sprite(overlay, "GameOverCursor", MENU_CURSOR_TEXTURE, Vector2((display_view_size.x - 42.0) * 0.5 - 8.0, 108), false)
	var footer := create_sprite(overlay, "GameOverFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0), false)
	game_over_footer_text = footer
	return {"overlay": overlay, "restart": restart_button, "title": title_button, "cursor": cursor, "footer": footer}


func build_run_complete(parent: Node, pixel_texture: Callable, return_to_hub: Callable) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "RunCompleteOverlay", Color(0.015, 0.02, 0.035, 1.0), 6, false)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_menu_frame(overlay, display_view_size)
	_add_menu_title(overlay, "RunCompleteTitle", "RESULT", pixel_texture)
	var content_width := minf(220.0, maxf(display_view_size.x - 20.0, 100.0))
	var content_x := _run_complete_content_x(content_width)
	_make_menu_card(overlay, "RunCompleteMetrics", Vector2(content_x, 25), Vector2(content_width, 80))
	_make_menu_card(overlay, "RunCompleteRewards", Vector2(content_x, 109), Vector2(content_width, 29))
	var lines: Array[Sprite2D] = []
	for index in RUN_COMPLETE_LINE_POSITIONS.size():
		lines.append(create_sprite(overlay, "RunCompleteLine%d" % index, null, _run_complete_line_position(index, content_x), false))
	var return_button := make_menu_command_button("RETURN TO HUB", Vector2(content_x + 4.0, 141), Vector2(86, 12), pixel_texture)
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.pressed.connect(return_to_hub)
	overlay.add_child(return_button)
	var cursor := create_sprite(overlay, "RunCompleteCursor", MENU_CURSOR_TEXTURE, Vector2(content_x - 4.0, 144), false)
	var footer := create_sprite(overlay, "RunCompleteFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0), false)
	run_complete_footer_text = footer
	return {"overlay": overlay, "lines": lines, "return": return_button, "cursor": cursor, "footer": footer}


func _add_menu_frame(overlay: ColorRect, panel_size: Vector2) -> void:
	var outer := Panel.new()
	outer.name = "FrameOuter"
	outer.position = Vector2.ZERO
	outer.size = panel_size
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color.TRANSPARENT
	outer_style.border_color = Color(0.78, 0.82, 0.92, 0.95)
	outer_style.set_border_width_all(1)
	outer.add_theme_stylebox_override("panel", outer_style)
	overlay.add_child(outer)
	var inner := Panel.new()
	inner.name = "FrameInner"
	inner.position = Vector2(3, 3)
	inner.size = panel_size - Vector2(6, 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color.TRANSPARENT
	inner_style.border_color = Color(0.30, 0.34, 0.44, 0.92)
	inner_style.set_border_width_all(1)
	inner.add_theme_stylebox_override("panel", inner_style)
	overlay.add_child(inner)


func _resize_menu_frame(overlay: ColorRect, panel_size: Vector2) -> void:
	if overlay == null:
		return
	var outer := overlay.get_node_or_null("FrameOuter") as Panel
	if outer != null:
		outer.size = panel_size
	var inner := overlay.get_node_or_null("FrameInner") as Panel
	if inner != null:
		inner.size = panel_size - Vector2(6, 6)
	var title_rule := overlay.get_node_or_null("RunCompleteTitleRule") as ColorRect
	if title_rule != null:
		title_rule.size = Vector2(maxf(panel_size.x - 16.0, 16.0), 1.0)


func _position_run_complete_controls() -> void:
	if run_complete_overlay == null:
		return
	var content_width := minf(220.0, maxf(display_view_size.x - 20.0, 100.0))
	var content_x := _run_complete_content_x(content_width)
	var metrics := run_complete_overlay.get_node_or_null("RunCompleteMetrics") as Panel
	if metrics != null:
		metrics.position = Vector2(content_x, 25)
		metrics.size = Vector2(content_width, 80)
	var rewards := run_complete_overlay.get_node_or_null("RunCompleteRewards") as Panel
	if rewards != null:
		rewards.position = Vector2(content_x, 109)
		rewards.size = Vector2(content_width, 29)
	for index in mini(run_complete_texts.size(), RUN_COMPLETE_LINE_POSITIONS.size()):
		if run_complete_texts[index] != null:
			run_complete_texts[index].position = _run_complete_line_position(index, content_x)
	if run_complete_button != null:
		run_complete_button.position = Vector2(content_x + 4.0, 141)
	if run_complete_cursor != null:
		move_menu_cursor(run_complete_cursor, Vector2((run_complete_button.position.x if run_complete_button != null else content_x) - CURSOR_LEFT_GAP, 144))
	var title_rule := run_complete_overlay.get_node_or_null("RunCompleteTitleRule") as ColorRect
	if title_rule != null:
		title_rule.size = Vector2(maxf(display_view_size.x - 16.0, 16.0), 1.0)
	if run_complete_footer_text != null:
		run_complete_footer_text.position = Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0)


func _run_complete_content_x(content_width: float) -> float:
	return floorf(maxf((display_view_size.x - content_width) * 0.5, 10.0))


func _run_complete_line_position(index: int, content_x: float) -> Vector2:
	var base_position: Vector2 = RUN_COMPLETE_LINE_POSITIONS[index]
	return Vector2(content_x + base_position.x - 10.0, base_position.y)


func _menu_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.075, 0.90)
	style.border_color = Color(0.42, 0.48, 0.62, 0.9)
	style.set_border_width_all(1)
	return style


func _make_menu_card(parent: Node, card_name: String, card_position: Vector2, card_size: Vector2) -> Panel:
	var card := Panel.new()
	card.name = card_name
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _menu_card_style())
	parent.add_child(card)
	return card


func _make_transparent_touch_button(parent: Node, button_name: String, button_position: Vector2, button_size: Vector2, callback: Callable = Callable(), callback_arg: Variant = null) -> Button:
	var button := Button.new()
	button.name = button_name
	button.position = button_position
	button.size = button_size
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	transparent.set_border_width_all(0)
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_state, transparent)
	if callback.is_valid():
		if callback_arg == null: button.pressed.connect(callback)
		else: button.pressed.connect(callback.bind(callback_arg))
	parent.add_child(button)
	return button


func build_hub(parent: Node, pixel_texture: Callable, adjust_stat: Callable, apply_stats: Callable, cancel_stats: Callable, auto_allocate: Callable, respec: Callable, _start_run: Callable, _return_title: Callable, set_page: Callable, item_action: Callable, select_gear_slot: Callable, bind_element: Callable = Callable(), select_gear_candidate: Callable = Callable(), select_stat_row: Callable = Callable(), select_item_row: Callable = Callable(), adjust_fusion_count: Callable = Callable(), pause_resume: Callable = Callable(), pause_settings: Callable = Callable(), pause_quit: Callable = Callable(), pause_status: Callable = Callable(), pause_equipment: Callable = Callable(), pause_back_callback: Callable = Callable(), equipment_remove: Callable = Callable(), equipment_remove_all: Callable = Callable(), hub_back: Callable = Callable()) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := DEMON_HUB_MENU_SCENE.instantiate() as ColorRect
	if overlay == null:
		return {}
	overlay.name = "HubOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = display_view_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 3
	overlay.visible = false
	overlay.set_meta("display_full_view", true)
	parent.add_child(overlay)

	var root_page := overlay.get_node_or_null("HubRootPage") as Control
	hub_root_page = root_page
	var status_page := overlay.get_node_or_null("HubStatusPage") as Control
	var allocate_page := overlay.get_node_or_null("HubAllocatePage") as Control
	var items_page := overlay.get_node_or_null("HubItemsPage") as Control
	var bind_page := overlay.get_node_or_null("HubBindPage") as Control
	var root_title := root_page.get_node_or_null("Title") as Sprite2D
	var status_title := status_page.get_node_or_null("Title") as Sprite2D
	var allocate_title := allocate_page.get_node_or_null("Title") as Sprite2D
	var items_title := items_page.get_node_or_null("Title") as Sprite2D
	var bind_title := bind_page.get_node_or_null("Title") as Sprite2D
	if root_title != null: root_title.texture = pixel_texture.call("DEMON HUB", Color.WHITE) as Texture2D
	if status_title != null: status_title.texture = pixel_texture.call("STATUS", Color.WHITE) as Texture2D
	if allocate_title != null: allocate_title.texture = pixel_texture.call("ALLOCATE", Color.WHITE) as Texture2D
	if items_title != null: items_title.texture = pixel_texture.call("EQUIPMENT", Color.WHITE) as Texture2D
	if bind_title != null: bind_title.texture = pixel_texture.call("BIND", Color.WHITE) as Texture2D
	hub_page_roots = {
		HUB_PAGE_STATUS: status_page,
		HUB_PAGE_ALLOCATE: allocate_page,
		HUB_PAGE_EQUIPMENT: items_page,
		HUB_PAGE_SHOP: items_page,
		HUB_PAGE_FUSION: items_page,
		HUB_PAGE_BIND: bind_page,
	}
	for page_root: Control in [status_page, allocate_page, items_page, bind_page]:
		page_root.visible = false
	var allocate_panel := _make_menu_card(allocate_page, "HubAllocatePanel", Vector2(14, 35), Vector2(108, 72))
	hub_allocate_panel = allocate_panel
	var allocate_preview_panel := _make_menu_card(allocate_page, "HubAllocatePreviewPanel", Vector2(132, 35), Vector2(94, 72))
	hub_allocate_preview_panel = allocate_preview_panel
	hub_allocate_preview_title = create_sprite(allocate_page, "HubAllocatePreviewTitle", null, Vector2(138, 40), false)
	for preview_index in 7:
		hub_allocate_preview_texts.append(create_sprite(allocate_page, "HubAllocatePreview%d" % preview_index, null, Vector2(138, 48 + preview_index * 9), false))

	var card := _make_menu_card(root_page, "HubPlayerCard", Vector2(10, 27), Vector2(136, 72))
	hub_player_card_panel = card
	var card_texts: Array[Sprite2D] = []
	for index in 7:
		card_texts.append(create_sprite(root_page, "HubCardText%d" % index, null, Vector2(16, 33 + index * 10), false))
	hub_player_card_texts = card_texts
	var summary := create_sprite(root_page, "HubSummary", null, Vector2(16, 106), false)
	var points := create_sprite(overlay, "HubPoints", null, Vector2(14, 23), false)
	points.visible = false
	var context := create_sprite(overlay, "HubContext", null, Vector2(14, display_view_size.y - 14.0), false)
	hub_context_text = context
	var currency := create_sprite(overlay, "HubCurrency", null, Vector2(display_view_size.x - 76.0, 23), false)
	hub_currency_text = currency
	var currency_icon := Sprite2D.new()
	currency_icon.name = "HubCurrencyIcon"
	currency_icon.centered = false
	currency_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	currency_icon.texture = SoulVisualsScript.texture()
	currency_icon.position = Vector2(display_view_size.x - 82.0, 23)
	currency_icon.z_index = 2
	currency_icon.visible = false
	overlay.add_child(currency_icon)
	hub_currency_icon = currency_icon

	var pages: Array[Button] = []
	var page_labels := ["STATUS", "ALLOCATE", "EQUIPMENT", "SHOP", "FUSION", "BIND"]
	for command_index in page_labels.size():
		var page_button := make_menu_command_button(page_labels[command_index], PauseMenuLayoutScript.command_button_position(display_view_size, command_index), PauseMenuLayoutScript.COMMAND_BUTTON_SIZE, pixel_texture)
		page_button.name = "HubCommand%s" % page_labels[command_index].capitalize()
		page_button.focus_mode = Control.FOCUS_NONE
		page_button.set_meta("hub_command_index", command_index)
		page_button.set_meta("hub_page_target", HUB_COMMAND_PAGE_TARGETS[command_index])
		page_button.pressed.connect(set_page.bind(HUB_COMMAND_PAGE_TARGETS[command_index]))
		root_page.add_child(page_button)
		pages.append(page_button)
	var back_button := make_menu_command_button("BACK", PauseMenuLayoutScript.back_button_position(display_view_size), PauseMenuLayoutScript.BACK_BUTTON_SIZE, pixel_texture)
	back_button.name = "HubBack"
	back_button.focus_mode = Control.FOCUS_NONE
	if hub_back.is_valid(): back_button.pressed.connect(hub_back)
	elif pause_resume.is_valid(): back_button.pressed.connect(pause_resume)
	overlay.add_child(back_button)

	var stats: Array[Sprite2D] = []
	var stat_buttons: Array[Button] = []
	var stat_left: Array[Button] = []
	var stat_right: Array[Button] = []
	var stat_rows: Array[Button] = []
	var stat_names := [&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"]
	# Keep the touch targets at the established row size. Disabled arrows use an
	# explicit transparent style below, so the full 12px target remains usable
	# without creating the stacked dark blocks seen in the old layout.
	var stat_arrow_size := Vector2(18, 12)
	for index in stat_names.size():
		var y := 39.0 + index * 11.0
		var stat_text := create_sprite(allocate_page, "HubStat%d" % index, null, Vector2(51, y + 5), true)
		stats.append(stat_text)
		var row_button := _make_transparent_touch_button(allocate_page, "HubStatRow%d" % index, Vector2(33, y), Vector2(80, 12), select_stat_row, index)
		stat_rows.append(row_button)
		var left := make_archetype_arrow(allocate_page, -1, Vector2(20, y), adjust_stat.bind(stat_names[index], -1), pixel_texture, stat_arrow_size)
		var right := make_archetype_arrow(allocate_page, 104, Vector2(104, y), adjust_stat.bind(stat_names[index], 1), pixel_texture, stat_arrow_size)
		left.set_meta("hub_stat_direction", -1); right.set_meta("hub_stat_direction", 1)
		left.set_meta("hub_stat_index", index); right.set_meta("hub_stat_index", index)
		stat_left.append(left); stat_right.append(right); stat_buttons.append(left); stat_buttons.append(right)
	var derived: Array[Sprite2D] = []
	for index in 6:
		derived.append(create_sprite(allocate_page, "HubDerived%d" % index, null, Vector2(14, 39 + index * 11), false))
	var status_texts: Array[Sprite2D] = []
	for index in 16:
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		status_texts.append(create_sprite(status_page, "HubStatus%d" % index, null, Vector2(14 + column * (display_view_size.x * 0.5), 42 + row * 10), false))
	var apply_button := make_retro_button("APPLY", Vector2(37, 113), Vector2(32, 12), pixel_texture)
	apply_button.focus_mode = Control.FOCUS_NONE; apply_button.pressed.connect(apply_stats); allocate_page.add_child(apply_button)
	var cancel_button := make_retro_button("CLEAR", Vector2(73, 113), Vector2(32, 12), pixel_texture)
	cancel_button.focus_mode = Control.FOCUS_NONE; cancel_button.pressed.connect(cancel_stats); allocate_page.add_child(cancel_button)
	var auto_button := make_retro_button("AUTO", Vector2(109, 113), Vector2(32, 12), pixel_texture)
	auto_button.focus_mode = Control.FOCUS_NONE; auto_button.pressed.connect(auto_allocate); allocate_page.add_child(auto_button)
	var respec_button := make_retro_button("RESPEC", Vector2(145, 113), Vector2(46, 12), pixel_texture)
	respec_button.focus_mode = Control.FOCUS_NONE; respec_button.pressed.connect(respec); allocate_page.add_child(respec_button)

	var item_name := create_sprite(items_page, "HubItemName", null, Vector2(14, 25), false)
	var item_list_panel := _make_menu_card(items_page, "HubItemListPanel", Vector2(14, 35), Vector2(150, 66))
	var item_content_clip := Control.new()
	item_content_clip.name = "HubItemContentClip"
	item_content_clip.position = Vector2(14, 35)
	item_content_clip.size = Vector2(150, 66)
	item_content_clip.clip_contents = true
	item_content_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_page.add_child(item_content_clip)
	var item_list: Array[Sprite2D] = []
	for list_index in 6:
		item_list.append(create_sprite(item_content_clip, "HubItemList%d" % list_index, null, Vector2(6, 4 + list_index * 10), false))
	var item_row_buttons: Array[Button] = []
	for list_index in 6:
		item_row_buttons.append(_make_transparent_touch_button(item_content_clip, "HubItemRow%d" % list_index, Vector2(0, list_index * 10), Vector2(150, 10), select_item_row, list_index))
	var shop_prices: Array[Sprite2D] = []
	for list_index in 6:
		shop_prices.append(create_sprite(items_page, "HubShopPrice%d" % list_index, null, Vector2(174, 39 + list_index * 10), false))
	var gear_slot_buttons: Array[Button] = []
	for slot_index in 6:
		gear_slot_buttons.append(_make_transparent_touch_button(item_content_clip, "HubGearSlot%d" % slot_index, Vector2(0, slot_index * 12), Vector2(150, 12), select_gear_slot, slot_index))
	# Equipment has two distinct levels of information: the upper window always
	# remains the six equipped slots, while the lower window is the temporary
	# inventory picker for the selected slot. Keeping a separate clip prevents
	# candidate labels and slot labels from ever sharing the same pixels or hit
	# regions when the picker is open.
	var gear_choice_panel := _make_menu_card(items_page, "HubGearChoicePanel", Vector2(14, 91), Vector2(150, 42))
	gear_choice_panel.visible = false
	var gear_choice_content_clip := Control.new()
	gear_choice_content_clip.name = "HubGearChoiceContentClip"
	gear_choice_content_clip.position = Vector2(14, 91)
	gear_choice_content_clip.size = Vector2(150, 42)
	gear_choice_content_clip.clip_contents = true
	gear_choice_content_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_choice_content_clip.visible = false
	items_page.add_child(gear_choice_content_clip)
	var gear_choices: Array[Sprite2D] = []
	var gear_choice_buttons: Array[Button] = []
	for choice_index in 4:
		gear_choices.append(create_sprite(gear_choice_content_clip, "HubGearChoice%d" % choice_index, null, Vector2(6, 4 + choice_index * 10), false))
		var choice_button := _make_transparent_touch_button(gear_choice_content_clip, "HubGearChoiceButton%d" % choice_index, Vector2(0, choice_index * 10), Vector2(150, 10), select_gear_candidate, choice_index)
		gear_choice_buttons.append(choice_button)
	var gear_stat_panel := Panel.new()
	gear_stat_panel.name = "HubGearStatPanel"; gear_stat_panel.position = Vector2(174, 35); gear_stat_panel.size = Vector2(maxf(display_view_size.x - 188.0, 48.0), 66); gear_stat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_stat_panel.add_theme_stylebox_override("panel", _menu_card_style()); items_page.add_child(gear_stat_panel)
	var gear_stats: Array[Sprite2D] = []
	for stat_index in 6:
		gear_stats.append(create_sprite(items_page, "HubGearStat%d" % stat_index, null, Vector2(180, 41 + stat_index * 9), false))
	var item_detail_panel := _make_menu_card(items_page, "HubItemDetailPanel", Vector2(14, HUB_ITEM_DETAIL_PANEL_TOP), Vector2(maxf(display_view_size.x - 28.0, 80.0), HUB_ITEM_DETAIL_PANEL_HEIGHT))
	item_detail_panel.visible = false
	var item_details: Array[Sprite2D] = []
	for detail_index in 6:
		item_details.append(create_sprite(items_page, "HubItemDetail%d" % detail_index, null, Vector2(20, HUB_ITEM_DETAIL_TOP + detail_index * HUB_ITEM_DETAIL_PITCH), false))
	var item_action_button := make_retro_button("BUY", Vector2(maxf(96.0, display_view_size.x - 144.0), 21), Vector2(52, 13), pixel_texture)
	item_action_button.focus_mode = Control.FOCUS_NONE; item_action_button.pressed.connect(item_action); items_page.add_child(item_action_button)
	var equipment_actions: Array[Button] = []
	var equip_action := make_retro_button("EQUIP", Vector2(14, 22), Vector2(42, 12), pixel_texture)
	equip_action.name = "HubEquipmentEquip"; equip_action.focus_mode = Control.FOCUS_NONE; equip_action.pressed.connect(item_action); items_page.add_child(equip_action); equipment_actions.append(equip_action)
	var remove_action := make_retro_button("REMOVE", Vector2(64, 22), Vector2(50, 12), pixel_texture)
	remove_action.name = "HubEquipmentRemove"; remove_action.focus_mode = Control.FOCUS_NONE
	if equipment_remove.is_valid(): remove_action.pressed.connect(equipment_remove)
	items_page.add_child(remove_action); equipment_actions.append(remove_action)
	var remove_all_action := make_retro_button("REMOVE ALL", Vector2(122, 22), Vector2(62, 12), pixel_texture)
	remove_all_action.name = "HubEquipmentRemoveAll"; remove_all_action.focus_mode = Control.FOCUS_NONE
	if equipment_remove_all.is_valid(): remove_all_action.pressed.connect(equipment_remove_all)
	items_page.add_child(remove_all_action); equipment_actions.append(remove_all_action)
	var fusion_decrease_button := make_retro_button("<", Vector2(14, 119), Vector2(22, 13), pixel_texture)
	fusion_decrease_button.name = "HubFusionDecrease"; fusion_decrease_button.focus_mode = Control.FOCUS_NONE
	if adjust_fusion_count.is_valid(): fusion_decrease_button.pressed.connect(adjust_fusion_count.bind(-1))
	items_page.add_child(fusion_decrease_button)
	var fusion_increase_button := make_retro_button(">", Vector2(39, 119), Vector2(22, 13), pixel_texture)
	fusion_increase_button.name = "HubFusionIncrease"; fusion_increase_button.focus_mode = Control.FOCUS_NONE
	if adjust_fusion_count.is_valid(): fusion_increase_button.pressed.connect(adjust_fusion_count.bind(1))
	items_page.add_child(fusion_increase_button)
	var binding_panel := Panel.new()
	binding_panel.name = "HubBindingPanel"; binding_panel.position = Vector2(14, 33); binding_panel.size = Vector2(maxf(display_view_size.x - 28.0, 80.0), 72); binding_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	binding_panel.add_theme_stylebox_override("panel", _menu_card_style()); bind_page.add_child(binding_panel)
	var binding_texts: Array[Sprite2D] = []
	binding_texts.append(create_sprite(bind_page, "HubBindingCurrent", null, Vector2(22, 41), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingBound", null, Vector2(22, 53), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingSouls", null, Vector2(22, 65), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingCost", null, Vector2(22, 77), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingMessage", null, Vector2(22, 91), false))
	var binding_action_button := make_retro_button("BIND", Vector2(display_view_size.x - 78.0, 119), Vector2(64, 13), pixel_texture)
	binding_action_button.focus_mode = Control.FOCUS_NONE
	if bind_element.is_valid(): binding_action_button.pressed.connect(bind_element)
	bind_page.add_child(binding_action_button)
	var cursor := create_sprite(root_page, "HubCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); cursor.visible = false
	var list_cursor := create_sprite(items_page, "HubListCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); list_cursor.visible = false
	var slot_cursor := create_sprite(items_page, "HubSlotCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); slot_cursor.visible = false
	var choice_cursor := create_sprite(items_page, "HubChoiceCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); choice_cursor.visible = false
	hub_item_list_panel = item_list_panel
	hub_item_content_clip = item_content_clip
	hub_gear_choice_panel = gear_choice_panel
	hub_gear_choice_content_clip = gear_choice_content_clip
	hub_item_detail_panel = item_detail_panel

	var pause_controls := _build_pause_overlay(parent, pixel_texture, pause_resume, pause_settings, pause_quit, pause_status, pause_equipment, pause_back_callback)
	return {"overlay": overlay, "summary": summary, "points": points, "stats": stats, "stat_buttons": stat_buttons, "stat_left": stat_left, "stat_right": stat_right, "stat_rows": stat_rows, "derived": derived, "status": status_texts, "apply": apply_button, "cancel": cancel_button, "auto": auto_button, "respec": respec_button, "start": null, "title": null, "pages": pages, "back": back_button, "card": card_texts, "context": context, "currency_icon": currency_icon, "item_name": item_name, "item_list": item_list, "item_rows": item_row_buttons, "shop_prices": shop_prices, "gear_choices": gear_choices, "gear_choice_buttons": gear_choice_buttons, "gear_slot_buttons": gear_slot_buttons, "gear_stats": gear_stats, "gear_stat_panel": gear_stat_panel, "item_list_panel": item_list_panel, "item_content_clip": item_content_clip, "gear_choice_panel": gear_choice_panel, "gear_choice_content_clip": gear_choice_content_clip, "item_details": item_details, "item_action": item_action_button, "equipment_actions": equipment_actions, "fusion_decrease": fusion_decrease_button, "fusion_increase": fusion_increase_button, "binding_panel": binding_panel, "binding_texts": binding_texts, "binding_action": binding_action_button, "cursor": cursor, "list_cursor": list_cursor, "slot_cursor": slot_cursor, "choice_cursor": choice_cursor, "allocate_preview_panel": allocate_preview_panel, "allocate_preview_title": hub_allocate_preview_title, "allocate_preview": hub_allocate_preview_texts, "pause_overlay": pause_controls["overlay"], "pause_title": pause_controls["title"], "pause_buttons": pause_controls["buttons"], "pause_cursor": pause_controls["cursor"], "pause_card": pause_controls["card"], "pause_status": pause_controls["status"], "pause_equipment": pause_controls["equipment"], "pause_description": pause_controls["description"], "pause_back": pause_controls["back"], "pause_status_button": pause_controls["status_button"], "pause_equipment_button": pause_controls["equipment_button"]}


func _make_menu_page(parent: Node, page_name: String) -> Control:
	var page := Control.new()
	page.name = page_name
	page.position = Vector2.ZERO
	page.size = display_view_size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(page)
	return page


func _add_menu_title(overlay: ColorRect, title_name: String, label: String, pixel_texture: Callable) -> Sprite2D:
	var tab := Panel.new()
	tab.name = "%sTab" % title_name
	tab.position = Vector2(8, 0)
	tab.size = Vector2(82, 16)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = Color(0.035, 0.045, 0.075, 1.0)
	tab_style.border_color = Color(0.78, 0.82, 0.92, 0.95)
	tab_style.set_border_width_all(1)
	tab.add_theme_stylebox_override("panel", tab_style)
	overlay.add_child(tab)
	var title := create_sprite(overlay, title_name, pixel_texture.call(label, Color.WHITE) as Texture2D, Vector2(13, 4), false)
	var rule := ColorRect.new()
	rule.name = "%sRule" % title_name
	rule.position = Vector2(8, 17)
	rule.size = Vector2(maxf(display_view_size.x - 16.0, 16.0), 1)
	rule.color = Color(0.36, 0.40, 0.52, 0.85)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rule)
	return title


func _build_pause_overlay(parent: Node, pixel_texture: Callable, _pause_resume: Callable, pause_settings: Callable, pause_quit: Callable, pause_status: Callable, pause_equipment: Callable, pause_back_callback: Callable) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := PAUSE_MENU_SCENE.instantiate() as ColorRect
	if overlay == null:
		return {}
	overlay.name = "PauseOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = display_view_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 4
	overlay.visible = false
	overlay.set_meta("display_full_view", true)
	parent.add_child(overlay)
	var title := overlay.get_node_or_null("PauseTitle") as Sprite2D
	pause_root_page = overlay.get_node_or_null("PauseRootPage") as Control
	var status_page := overlay.get_node_or_null("PauseStatusPage") as Control
	var equipment_page := overlay.get_node_or_null("PauseEquipmentPage") as Control
	var status_title := status_page.get_node_or_null("Title") as Sprite2D
	var equipment_title := equipment_page.get_node_or_null("Title") as Sprite2D
	if status_title != null: status_title.texture = pixel_texture.call("STATUS", Color.WHITE) as Texture2D
	if equipment_title != null: equipment_title.texture = pixel_texture.call("EQUIPMENT", Color.WHITE) as Texture2D
	pause_page_roots = {0: pause_root_page, 1: status_page, 2: equipment_page}
	pause_player_card_panel = null
	pause_player_portrait = overlay.get_node_or_null("PauseRootPage/PausePlayerPortrait") as Sprite2D
	pause_gold_icon = overlay.get_node_or_null("PauseGoldIcon") as Sprite2D
	pause_resource_icon = overlay.get_node_or_null("PauseResourceIcon") as Sprite2D
	var card_texts: Array[Sprite2D] = []
	for index in PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.size():
		card_texts.append(create_sprite(pause_root_page, "PauseCardText%d" % index, null, PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[index], false))
	var status_texts: Array[Sprite2D] = []
	for index in 16:
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		status_texts.append(create_sprite(status_page, "PauseStatus%d" % index, null, Vector2(14 + column * 108, 28 + row * 10), false))
	var equipment_texts: Array[Sprite2D] = []
	for index in 8:
		equipment_texts.append(create_sprite(equipment_page, "PauseEquipment%d" % index, null, Vector2(14, 28 + index * 12), false))
	var description := create_sprite(overlay, "PauseDescription", null, PauseMenuLayoutScript.select_prompt_position(display_view_size), false)
	pause_gold_text = create_sprite(overlay, "PauseGoldText", null, PauseMenuLayoutScript.resource_text_position(display_view_size, 0.0, false), false)
	pause_soul_text = create_sprite(overlay, "PauseSoulText", null, PauseMenuLayoutScript.resource_text_position(display_view_size, 0.0, true), false)
	var buttons: Array[Button] = []
	var labels := ["STATUS", "EQUIPMENT", "SETTINGS", "QUIT TITLE"]
	for index in labels.size():
		var button := make_menu_command_button(labels[index], PauseMenuLayoutScript.command_button_position(display_view_size, index), PauseMenuLayoutScript.COMMAND_BUTTON_SIZE, pixel_texture)
		button.name = "Pause%s" % labels[index].replace(" ", "").capitalize()
		button.focus_mode = Control.FOCUS_NONE
		if index == 0:
			if pause_status.is_valid(): button.pressed.connect(pause_status)
			else: button.pressed.connect(set_pause_page.bind(1))
		elif index == 1:
			if pause_equipment.is_valid(): button.pressed.connect(pause_equipment)
			else: button.pressed.connect(set_pause_page.bind(2))
		elif index == 2 and pause_settings.is_valid(): button.pressed.connect(pause_settings)
		elif index == 3 and pause_quit.is_valid(): button.pressed.connect(pause_quit)
		pause_root_page.add_child(button); buttons.append(button)
	var back := make_menu_command_button("BACK", PauseMenuLayoutScript.back_button_position(display_view_size), PauseMenuLayoutScript.BACK_BUTTON_SIZE, pixel_texture)
	back.name = "PauseBack"
	back.focus_mode = Control.FOCUS_NONE
	if pause_back_callback.is_valid(): back.pressed.connect(pause_back_callback)
	overlay.add_child(back)
	var cursor := create_sprite(pause_root_page, "PauseCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); cursor.visible = false
	return {"overlay": overlay, "title": title, "buttons": buttons, "cursor": cursor, "card": card_texts, "status": status_texts, "equipment": equipment_texts, "description": description, "back": back, "status_button": buttons[0], "equipment_button": buttons[1]}


func _position_hub_controls() -> void:
	if hub_overlay == null:
		return
	var width := display_view_size.x
	hub_overlay.position = Vector2.ZERO
	hub_overlay.size = display_view_size
	var root_panel := hub_overlay.get_node_or_null("HubPanel8Piece") as Control
	if root_panel != null:
		root_panel.position = Vector2.ZERO
		root_panel.size = display_view_size
	if hub_currency_text != null:
		hub_currency_text.position = Vector2(maxf(14.0, width - 76.0), 23)
	if hub_currency_icon != null:
		hub_currency_icon.position = Vector2(maxf(8.0, width - 82.0), 23)
	for page_root: Control in hub_page_roots.values():
		page_root.position = Vector2.ZERO
		page_root.size = display_view_size
		var page_background := page_root.get_node_or_null("Background") as NinePatchRect
		if page_background != null: page_background.size = display_view_size
		var page_title_rule := page_root.get_node_or_null("TitleRule") as ColorRect
		if page_title_rule != null: page_title_rule.size.x = maxf(width - 16.0, 16.0)
	var root_title_rule := hub_root_page.get_node_or_null("TitleRule") as ColorRect if hub_root_page != null else null
	if root_title_rule != null: root_title_rule.size.x = maxf(PauseMenuLayoutScript.divider_x(width) - 16.0, 16.0)
	for index in hub_page_buttons.size():
		hub_page_buttons[index].position = PauseMenuLayoutScript.command_button_position(display_view_size, index)
	if hub_back_button != null: hub_back_button.position = PauseMenuLayoutScript.back_button_position(display_view_size)
	if hub_player_card_panel != null:
		hub_player_card_panel.position = Vector2(10, 27)
		hub_player_card_panel.size = Vector2(minf(150.0, maxf(136.0, width - 100.0)), 72)
	for index in hub_player_card_texts.size():
		hub_player_card_texts[index].position = Vector2(16, 33 + index * 10)
	var summary := hub_overlay.get_node_or_null("HubRootPage/HubSummary") as Sprite2D
	if summary != null:
		summary.position = Vector2(16, 106)
		summary.texture = null
		summary.visible = false
	if hub_points_text != null: hub_points_text.position = Vector2(14, 23)
	if hub_context_text != null: hub_context_text.position = Vector2(14, display_view_size.y - 14.0)
	var allocation_preview_x := maxf(132.0, width - 108.0)
	var allocation_left_width := maxf(108.0, allocation_preview_x - 24.0)
	if hub_allocate_panel != null:
		hub_allocate_panel.position = Vector2(14, 35)
		hub_allocate_panel.size = Vector2(allocation_left_width, 72)
	if hub_allocate_preview_panel != null:
		hub_allocate_preview_panel.position = Vector2(allocation_preview_x, 35)
		hub_allocate_preview_panel.size = Vector2(maxf(82.0, width - allocation_preview_x - 14.0), 72)
	if hub_allocate_preview_title != null: hub_allocate_preview_title.position = Vector2(allocation_preview_x + 6.0, 40)
	for index in hub_allocate_preview_texts.size(): hub_allocate_preview_texts[index].position = Vector2(allocation_preview_x + 6.0, 47 + index * 8)
	var stat_right_x := allocation_preview_x - 28.0
	for index in hub_stat_texts.size():
		var y := 44.0 + index * 11.0
		hub_stat_texts[index].position = Vector2(64, y)
		if index < hub_stat_row_buttons.size():
			hub_stat_row_buttons[index].position = Vector2(34, y - 5.0)
			hub_stat_row_buttons[index].size = Vector2(maxf(80.0, stat_right_x - 34.0), 12)
		if index < hub_stat_left_buttons.size(): hub_stat_left_buttons[index].position = Vector2(20, y - 5.0)
		if index < hub_stat_right_buttons.size(): hub_stat_right_buttons[index].position = Vector2(stat_right_x, y - 5.0)
	var utility_x := [37.0, 73.0, 109.0, 145.0]
	var utility_buttons: Array[Button] = [hub_apply_button, hub_cancel_button, hub_auto_button, hub_respec_button]
	for index in utility_buttons.size():
		if utility_buttons[index] != null: utility_buttons[index].position = Vector2(utility_x[index], 113)
	for index in hub_status_texts.size():
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		hub_status_texts[index].position = Vector2(14 + column * width * 0.5, 42 + row * 10)
	# The item labels and their touch rows share a bounded left column. The
	# previous width calculation grew from the viewport width independently of
	# the stat card, so a wide display could let item text/buttons enter the
	# card's space. Keep a ten-pixel gutter between the two regions.
	var gear_x := maxf(174.0, width * 0.58)
	var list_width := maxf(120.0, gear_x - 24.0)
	var equipment_page := hub_page == HUB_PAGE_EQUIPMENT
	var list_height := 54.0 if equipment_page else 62.0
	var item_row_pitch := 9.0 if equipment_page else 10.0
	if hub_item_list_panel != null:
		hub_item_list_panel.position = Vector2(14, 35)
		hub_item_list_panel.size = Vector2(list_width, list_height)
	if hub_item_content_clip != null:
		hub_item_content_clip.position = Vector2(14, 35)
		hub_item_content_clip.size = Vector2(list_width, list_height)
	for index in hub_item_list_texts.size():
		hub_item_list_texts[index].position = Vector2(6, 4 + index * item_row_pitch)
		if index < hub_item_row_buttons.size():
			hub_item_row_buttons[index].position = Vector2(0, index * item_row_pitch)
			hub_item_row_buttons[index].size = Vector2(list_width, item_row_pitch)
		if index < hub_shop_price_texts.size(): hub_shop_price_texts[index].position = Vector2(maxf(gear_x, width - 62.0), 39 + index * item_row_pitch)
	var gear_row_pitch := 9.0
	for index in hub_gear_slot_buttons.size():
		hub_gear_slot_buttons[index].position = Vector2(0, index * gear_row_pitch)
		hub_gear_slot_buttons[index].size = Vector2(list_width, gear_row_pitch)
	for index in hub_gear_choice_texts.size():
		hub_gear_choice_texts[index].position = Vector2(6, 4 + index * 10)
		if index < hub_gear_choice_buttons.size():
			hub_gear_choice_buttons[index].position = Vector2(0, index * 10)
			hub_gear_choice_buttons[index].size = Vector2(list_width, 10)
	if hub_gear_choice_panel != null:
		hub_gear_choice_panel.position = Vector2(14, 91)
		hub_gear_choice_panel.size = Vector2(list_width, 42)
	if hub_gear_choice_content_clip != null:
		hub_gear_choice_content_clip.position = Vector2(14, 91)
		hub_gear_choice_content_clip.size = Vector2(list_width, 42)
	if hub_gear_stat_panel != null:
		hub_gear_stat_panel.position = Vector2(gear_x, 35)
		hub_gear_stat_panel.size = Vector2(maxf(48.0, width - gear_x - 10.0), 66)
	var gear_stat_y := 40.0 if equipment_page else 41.0
	var gear_stat_pitch := 8.0 if equipment_page else 9.0
	for index in hub_gear_stat_texts.size(): hub_gear_stat_texts[index].position = Vector2(gear_x + 6.0, gear_stat_y + index * gear_stat_pitch)
	var gear_browse_details := equipment_page and hub_gear_browsing
	if hub_item_detail_panel != null:
		hub_item_detail_panel.position = Vector2(14, HUB_GEAR_BROWSE_DETAIL_TOP - 2.0 if gear_browse_details else HUB_ITEM_DETAIL_PANEL_TOP)
		hub_item_detail_panel.size = Vector2(maxf(width - 28.0, 80.0), 11.0 if gear_browse_details else HUB_ITEM_DETAIL_PANEL_HEIGHT)
	var detail_top := HUB_GEAR_BROWSE_DETAIL_TOP if gear_browse_details else HUB_ITEM_DETAIL_TOP
	for index in hub_item_detail_texts.size(): hub_item_detail_texts[index].position = Vector2(20, detail_top + index * HUB_ITEM_DETAIL_PITCH)
	if hub_item_name_text != null: hub_item_name_text.position = Vector2(14, 25)
	if hub_item_action_button != null: hub_item_action_button.position = Vector2(maxf(96.0, width - 144.0), 21)
	for index in hub_equipment_action_buttons.size():
		hub_equipment_action_buttons[index].position = Vector2([14.0, 64.0, 122.0][mini(index, 2)], 22)
	if hub_fusion_decrease_button != null: hub_fusion_decrease_button.position = Vector2(14, 119)
	if hub_fusion_increase_button != null: hub_fusion_increase_button.position = Vector2(39, 119)
	if hub_binding_panel != null:
		hub_binding_panel.position = Vector2(14, 33)
		hub_binding_panel.size = Vector2(maxf(width - 28.0, 80.0), 72)
	for index in hub_binding_texts.size(): hub_binding_texts[index].position = Vector2(22, 41 + index * (12 if index < 4 else 14))
	if hub_binding_action_button != null: hub_binding_action_button.position = Vector2(width - 78.0, 119)
	if hub_cursor_text != null and not hub_page_buttons.is_empty():
		var cursor_index := clampi(hub_menu_row, 0, hub_page_buttons.size() - 1)
		move_menu_cursor(hub_cursor_text, Vector2(hub_page_buttons[cursor_index].position.x - CURSOR_LEFT_GAP, hub_page_buttons[cursor_index].position.y + 3.0), false)


func _position_pause_controls() -> void:
	if pause_overlay == null:
		return
	var width := display_view_size.x
	var height := display_view_size.y
	pause_overlay.position = Vector2.ZERO
	pause_overlay.size = display_view_size
	_resize_menu_frame(pause_overlay, display_view_size)
	for page_root: Control in pause_page_roots.values():
		page_root.position = Vector2.ZERO
		page_root.size = display_view_size
		var page_background := page_root.get_node_or_null("Background") as NinePatchRect
		if page_background != null: page_background.size = display_view_size
		var page_title_rule := page_root.get_node_or_null("TitleRule") as ColorRect
		if page_title_rule != null: page_title_rule.size.x = maxf(width - 16.0, 16.0)
	var divider_x := PauseMenuLayoutScript.divider_x(width)
	var panel_root := pause_overlay.get_node_or_null("PausePanel8Piece") as Control
	if panel_root != null:
		panel_root.position = Vector2.ZERO
		panel_root.size = display_view_size
	var command_divider := pause_overlay.get_node_or_null("CommandDivider") as ColorRect
	if command_divider != null:
		command_divider.position = Vector2(divider_x - 1.0, 2.0)
		command_divider.size = Vector2(1.0, maxf(PauseMenuLayoutScript.upper_rail_height(height) - 2.0, 1.0))
	var resource_divider := pause_overlay.get_node_or_null("ResourceDivider") as ColorRect
	if resource_divider != null:
		resource_divider.position = Vector2(divider_x, height - PauseMenuLayoutScript.RESOURCE_PANEL_HEIGHT)
		resource_divider.size = Vector2(maxf(width - divider_x - 1.0, 1.0), 1.0)
	for index in pause_menu_buttons.size(): pause_menu_buttons[index].position = PauseMenuLayoutScript.command_button_position(display_view_size, index)
	if pause_back_button != null: pause_back_button.position = PauseMenuLayoutScript.back_button_position(display_view_size)
	if pause_player_portrait != null: pause_player_portrait.position = PauseMenuLayoutScript.PLAYER_PORTRAIT_POSITION
	for index in pause_player_card_texts.size():
		pause_player_card_texts[index].position = PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[index] if index < PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.size() else PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.back()
	for index in pause_status_texts.size():
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		pause_status_texts[index].position = Vector2(14 + column * maxf((width - 28.0) * 0.5, 108.0), 28 + row * 10)
	for index in pause_equipment_texts.size(): pause_equipment_texts[index].position = Vector2(14, 28 + index * 12)
	if pause_description_text != null: pause_description_text.position = PauseMenuLayoutScript.select_prompt_position(display_view_size)
	if pause_gold_icon != null: pause_gold_icon.position = PauseMenuLayoutScript.resource_icon_position(display_view_size, false)
	if pause_resource_icon != null: pause_resource_icon.position = PauseMenuLayoutScript.resource_icon_position(display_view_size, true)
	_position_pause_resource_texts()
	if pause_cursor_text != null and not pause_menu_buttons.is_empty():
		var cursor_index := clampi(pause_menu_row, 0, pause_menu_buttons.size() - 1)
		move_menu_cursor(pause_cursor_text, Vector2(pause_menu_buttons[cursor_index].position.x - CURSOR_LEFT_GAP, pause_menu_buttons[cursor_index].position.y + 3.0), false)


func _position_pause_resource_texts() -> void:
	if pause_gold_text != null and pause_gold_text.texture != null:
		pause_gold_text.position = PauseMenuLayoutScript.resource_text_position(display_view_size, pause_gold_text.texture.get_width(), false)
	if pause_soul_text != null and pause_soul_text.texture != null:
		pause_soul_text.position = PauseMenuLayoutScript.resource_text_position(display_view_size, pause_soul_text.texture.get_width(), true)


func update_hub_ui(root: Object, pixel_texture: Callable) -> void:
	var profile := root.get("player_profile") as PlayerProfile
	if profile == null: return
	# Focused legacy render tests may replace the overlay with a minimal double.
	# Only a real routed overlay contains HubRootPage, so do not let a stale
	# controller flag force the root-only path for those callers.
	var showing_root := hub_is_root and hub_overlay != null and hub_overlay.get_node_or_null("HubRootPage") != null
	if hub_root_page != null: hub_root_page.visible = false
	for page_root: Control in hub_page_roots.values(): page_root.visible = false
	if showing_root:
		if hub_root_page != null: hub_root_page.visible = true
	else:
		var active_page := hub_page_roots.get(hub_page) as Control
		if active_page != null: active_page.visible = true
	var root_panel := hub_overlay.get_node_or_null("HubPanel8Piece") as Control
	if root_panel != null: root_panel.visible = showing_root
	var points := hub_points_text
	_update_player_card(root, pixel_texture, hub_player_card_texts)
	var page := hub_page
	# Page changes alter the height of the shared inventory card (Equipment uses
	# six compact slot rows; Shop/Fusion use the larger inventory rows).
	_position_hub_controls()
	var page_buttons := hub_page_buttons
	var highlight_color := PaletteLibrary.accent(player_palette_name)
	if root.has_method("_health_feedback_color"):
		highlight_color = root.call("_health_feedback_color", player_palette_name)
	for page_index in page_buttons.size():
		page_buttons[page_index].visible = showing_root
		# The command rail is pure navigation: the arrow cursor marks the
		# selected command. No page box or text highlight may linger around the
		# last-visited menu after backing out to the hub root, and the command
		# stays text-only (no Circle box).
		set_archetype_button_state(page_buttons[page_index], false, highlight_color)
		_set_menu_button_icon(page_buttons[page_index], null, false)
	if hub_cursor_text != null and not page_buttons.is_empty():
		var cursor_index := clampi(hub_menu_row, 0, page_buttons.size() - 1)
		hub_cursor_text.texture = MENU_CURSOR_TEXTURE
		hub_cursor_text.visible = showing_root
		move_menu_cursor(hub_cursor_text, Vector2(page_buttons[cursor_index].position.x - CURSOR_LEFT_GAP, page_buttons[cursor_index].position.y + 3.0))
	var title_page := hub_root_page if showing_root else hub_page_roots.get(page) as Control
	var title := title_page.get_node_or_null("Title") as Sprite2D if title_page != null else null
	if title != null:
		var title_label: String = "DEMON HUB" if showing_root else ["ALLOCATE", "EQUIPMENT", "SHOP", "FUSION", "BIND", "STATUS"][clampi(page, 0, 5)]
		var title_texture := pixel_texture.call(title_label, Color.WHITE) as Texture2D
		title.texture = title_texture
	if hub_points_text != null: hub_points_text.visible = false
	var confirm_prompt := _menu_confirm_prompt_for(root)
	if page == HUB_PAGE_EQUIPMENT:
		confirm_prompt = confirm_prompt.replace("SELECT", "EQUIP")
	var back_prompt := _menu_back_prompt_for(root)
	if hub_context_text != null:
		hub_context_text.visible = true
		hub_context_text.texture = _pixel_prompt_texture(pixel_texture, confirm_prompt, Color8(148, 220, 255)) as Texture2D
	_set_button_text(hub_back_button, back_prompt, pixel_texture, highlight_color)
	if hub_currency_text != null:
		var currency_visible := not showing_root and (page == HUB_PAGE_SHOP or page == HUB_PAGE_FUSION or page == HUB_PAGE_BIND)
		var currency_label := "GOLD %d" % profile.gold if page == HUB_PAGE_SHOP else "SOULS %d" % profile.souls
		var is_soul_currency := page == HUB_PAGE_FUSION or page == HUB_PAGE_BIND
		hub_currency_text.visible = currency_visible
		hub_currency_text.texture = pixel_texture.call(currency_label, Color8(255, 205, 117) if page == HUB_PAGE_SHOP else SoulVisualsScript.SOUL_HIGHLIGHT_COLOR) as Texture2D if currency_visible else null
		if hub_currency_icon != null:
			hub_currency_icon.visible = currency_visible and is_soul_currency
			hub_currency_icon.texture = SoulVisualsScript.texture() if hub_currency_icon.visible else null
	elif hub_currency_icon != null:
		hub_currency_icon.visible = false
	if showing_root:
		return
	var stat_nodes: Array[CanvasItem] = []
	stat_nodes.append(hub_allocate_panel); stat_nodes.append(hub_allocate_preview_panel); stat_nodes.append(hub_allocate_preview_title); stat_nodes.append_array(hub_allocate_preview_texts); stat_nodes.append(hub_points_text); stat_nodes.append_array(hub_stat_texts); stat_nodes.append_array(hub_stat_row_buttons); stat_nodes.append_array(hub_stat_buttons); stat_nodes.append_array(hub_derived_texts); stat_nodes.append(hub_apply_button); stat_nodes.append(hub_cancel_button); stat_nodes.append(hub_auto_button); stat_nodes.append(hub_respec_button)
	for node in stat_nodes:
		if node != null: node.visible = page == HUB_PAGE_ALLOCATE
	for node in hub_status_texts:
		node.visible = page == HUB_PAGE_STATUS
	var item_name := hub_item_name_text
	var item_list := hub_item_list_texts
	var shop_prices := hub_shop_price_texts
	var gear_choices := hub_gear_choice_texts
	var gear_browsing := page == HUB_PAGE_EQUIPMENT and hub_gear_browsing
	var equipment_action_state := page == HUB_PAGE_EQUIPMENT and hub_equipment_action_focus and not gear_browsing
	var equipment_content_state := page == HUB_PAGE_EQUIPMENT and not equipment_action_state
	for button in hub_gear_choice_buttons:
		button.visible = gear_browsing
	var gear_stats := hub_gear_stat_texts
	var item_details := hub_item_detail_texts
	var item_action := hub_item_action_button
	for equipment_action_index in hub_equipment_action_buttons.size():
		var equipment_action := hub_equipment_action_buttons[equipment_action_index]
		# Equipment is a real nested route: the command row, slot list, and item
		# picker replace one another. Hiding inactive controls prevents a stale
		# button or a hidden row from stealing controller/touch input.
		equipment_action.visible = equipment_action_state
		equipment_action.mouse_filter = Control.MOUSE_FILTER_STOP if equipment_action_state else Control.MOUSE_FILTER_IGNORE
		var action_active := page == HUB_PAGE_EQUIPMENT and hub_content_focus and hub_equipment_action_focus and equipment_action_index == hub_action_column
		set_archetype_button_state(equipment_action, action_active, highlight_color)
		_set_menu_button_icon(equipment_action, null, false)
	if page == HUB_PAGE_EQUIPMENT and hub_equipment_action_buttons.size() >= 3:
		var selected_slot: StringName = ItemCatalog.SLOTS[clampi(hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var equipped_item := profile.find_item(profile.get_equipped_instance_id(selected_slot))
		hub_equipment_action_buttons[1].disabled = equipped_item == null
		hub_equipment_action_buttons[2].disabled = profile.equipped_instance_ids.values().all(func(id: String) -> bool: return str(id).is_empty())
	for button in hub_item_row_buttons: button.visible = false
	if hub_fusion_decrease_button != null:
		hub_fusion_decrease_button.visible = page == HUB_PAGE_FUSION
		hub_fusion_decrease_button.disabled = true
	if hub_fusion_increase_button != null:
		hub_fusion_increase_button.visible = page == HUB_PAGE_FUSION
		hub_fusion_increase_button.disabled = true
	var item_page := page >= HUB_PAGE_EQUIPMENT and page <= HUB_PAGE_FUSION
	if item_name != null: item_name.visible = item_page and not equipment_action_state
	for node in item_list: node.visible = item_page and not equipment_action_state
	for node in shop_prices: node.visible = page == HUB_PAGE_SHOP
	for node in gear_choices: node.visible = gear_browsing
	for button in hub_gear_slot_buttons:
		button.visible = equipment_content_state
		button.mouse_filter = Control.MOUSE_FILTER_STOP if page == HUB_PAGE_EQUIPMENT and not hub_equipment_action_focus and not gear_browsing else Control.MOUSE_FILTER_IGNORE
	if hub_item_list_panel != null: hub_item_list_panel.visible = (page == HUB_PAGE_EQUIPMENT and not equipment_action_state) or page == HUB_PAGE_SHOP or page == HUB_PAGE_FUSION
	if hub_item_content_clip != null: hub_item_content_clip.visible = (page == HUB_PAGE_EQUIPMENT and not equipment_action_state) or page == HUB_PAGE_SHOP or page == HUB_PAGE_FUSION
	if hub_gear_choice_panel != null: hub_gear_choice_panel.visible = gear_browsing
	if hub_gear_choice_content_clip != null: hub_gear_choice_content_clip.visible = gear_browsing
	for node in gear_stats: node.visible = (page == HUB_PAGE_EQUIPMENT and not equipment_action_state) or page == HUB_PAGE_FUSION
	var gear_stat_panel := hub_gear_stat_panel
	# Equipment and Fusion share the same right-hand six-stat comparison card.
	# The equipment slot list is kept to the left of it, so long item names can
	# never draw through the stat column.
	if gear_stat_panel != null: gear_stat_panel.visible = (page == HUB_PAGE_EQUIPMENT and not equipment_action_state) or page == HUB_PAGE_FUSION
	if hub_item_detail_panel != null: hub_item_detail_panel.visible = item_page and not equipment_action_state
	for node in item_details: node.visible = item_page and not equipment_action_state
	if item_action != null: item_action.visible = item_page and page != HUB_PAGE_EQUIPMENT
	if hub_binding_panel != null: hub_binding_panel.visible = page == HUB_PAGE_BIND
	for node in hub_binding_texts: node.visible = page == HUB_PAGE_BIND
	if hub_binding_action_button != null: hub_binding_action_button.visible = page == HUB_PAGE_BIND
	if page == HUB_PAGE_BIND:
		_update_hub_binding_page(root, pixel_texture, profile, highlight_color)
		return
	if page == HUB_PAGE_STATUS:
		_update_hub_status_page(root, pixel_texture, profile, highlight_color)
		return
	if page != HUB_PAGE_ALLOCATE:
		_update_hub_item_page(root, pixel_texture, profile, page, item_list, item_details, item_action, highlight_color)
		return
	var pending := [hub_pending_vit, hub_pending_str, hub_pending_def, hub_pending_agi, hub_pending_int, hub_pending_mnd]
	var remaining := int(root.call("_hub_points_remaining"))
	if points != null: points.texture = pixel_texture.call("POINTS %d" % remaining, Color8(255, 205, 117)) as Texture2D
	var stat_texts := hub_stat_texts
	var selected_row := hub_stat_row
	# The allocate page shows BASE stats (level + allocated points), not the
	# equipment-modified effective values, so the player reads the stat they are
	# actually spending points on rather than a gear-inflated number.
	var player_stats := root.get("player_stats") as StatsComponent
	var effective_values: Array[float] = []
	if player_stats != null:
		effective_values = [float(player_stats.vit) + pending[0], float(player_stats.strength) + pending[1], float(player_stats.def) + pending[2], float(player_stats.agi) + pending[3], float(player_stats.intelligence) + pending[4], float(player_stats.mnd) + pending[5]]
	for index in stat_texts.size():
		var effective := effective_values[index] if index < effective_values.size() else 0.0
		var before_pending := effective - float(pending[index])
		var value_text := "%s %.1f" % [["VIT", "STR", "DEF", "AGI", "INT", "MND"][index], before_pending]
		if int(pending[index]) != 0:
			value_text += " > %0.1f" % effective
		var stat_color := highlight_color if selected_row == index else Color8(167, 240, 112) if int(pending[index]) != 0 else Color.WHITE
		stat_texts[index].texture = pixel_texture.call(value_text, stat_color) as Texture2D
	var stat_buttons := hub_stat_buttons
	for button in stat_buttons:
		var direction := int(button.get_meta("hub_stat_direction", 1))
		var stat_index := int(button.get_meta("hub_stat_index", 0))
		button.disabled = remaining <= 0 if direction > 0 else int(pending[stat_index]) <= 0
		set_archetype_button_state(button, selected_row == stat_index, highlight_color)
	for derived_text in hub_derived_texts:
		derived_text.visible = false
	var current_snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot if root.has_method("_player_stat_snapshot") else null
	var preview_snapshot := _allocation_preview_snapshot(root, pending)
	_update_hub_allocation_preview(root, pixel_texture, current_snapshot, preview_snapshot)
	var pending_total: int = int(pending[0]) + int(pending[1]) + int(pending[2]) + int(pending[3]) + int(pending[4]) + int(pending[5])
	var apply_button := hub_apply_button
	var cancel_button := hub_cancel_button
	if apply_button != null: apply_button.disabled = pending_total <= 0
	if cancel_button != null: cancel_button.disabled = pending_total <= 0
	var auto_button := hub_auto_button
	if auto_button != null: auto_button.disabled = remaining <= 0
	var respec_button := hub_respec_button
	if respec_button != null:
		var cost := profile.respec_cost()
		respec_button.disabled = profile.allocated_vit + profile.allocated_str + profile.allocated_def + profile.allocated_agi + profile.allocated_int + profile.allocated_mnd <= 0 or profile.gold < cost
		var label := respec_button.get_child(0) as Sprite2D
		if label != null: label.texture = pixel_texture.call("RESPEC" if cost <= 0 else "RESPEC %d" % cost, Color.WHITE) as Texture2D
	var utility_buttons: Array[Button] = [apply_button, cancel_button, auto_button, respec_button]
	for index in utility_buttons.size():
		var utility_active := hub_content_focus and selected_row == 6 and hub_action_column == index
		set_archetype_button_state(utility_buttons[index], utility_active, highlight_color)
		_set_menu_button_icon(utility_buttons[index], MENU_CIRCLE_TEXTURE, _menu_uses_face_art(root) and utility_active)
	if hub_context_text != null:
		hub_context_text.texture = pixel_texture.call("LEFT/RIGHT ADJUST", Color8(148, 220, 255)) as Texture2D


func _update_player_card(root: Object, pixel_texture: Callable, texts: Array[Sprite2D], summary: Sprite2D = null) -> void:
	if texts.is_empty():
		return
	var profile := root.get("player_profile") as PlayerProfile
	var snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot if root.has_method("_player_stat_snapshot") else null
	var element := "NORMAL"
	var chroma_component := root.get("player_chroma_component") as Node
	if chroma_component != null and chroma_component.has_method("aspect_name"):
		element = ASPECT_CATALOG_SCRIPT.display_name(chroma_component.call("aspect_name") as StringName)
	var max_health := CombatCalculator.max_health_for_snapshot(snapshot, root.get("combat_tuning") as CombatTuning)
	var health := max_health
	var health_component := root.get("player_health_component") as Node
	if health_component != null:
		health = float(health_component.get("current_health"))
	var chroma := 0
	if chroma_component != null:
		chroma = int(chroma_component.get("current_chroma"))
	var display_name := PlayerProfile.normalize_player_name(profile.player_name)
	var progression := root.get("progression_tuning") as ProgressionTuning
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, progression)
	var values := [display_name, element, "LV %d" % profile.level, "XP %d/%d" % [profile.xp, xp_required], "HP %d/%d" % [roundi(health), roundi(max_health)], "CHR %d/%d" % [chroma, PlayerChromaComponent.MAX_CHROMA], "READY"]
	for index in texts.size():
		var label: String = str(values[index]) if index < values.size() else ""
		var label_color := Color8(255, 205, 117) if index == 3 else Color.WHITE
		if index == 1:
			var palette_value: Variant = root.get("current_player_palette_name")
			var palette_name: StringName = StringName(str(palette_value)) if palette_value != null else &"blue"
			label_color = PaletteLibrary.accent(palette_name)
		texts[index].texture = pixel_texture.call(label, label_color) as Texture2D
	if summary != null:
		summary.visible = true


func _update_hub_status_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, _highlight_color: Color) -> void:
	var snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot
	if snapshot == null:
		return
	var tuning := root.get("combat_tuning") as CombatTuning
	var player_tuning := root.get("player_tuning") as PlayerTuning
	var max_hp := roundi(CombatCalculator.max_health_for_snapshot(snapshot, tuning))
	var hp := max_hp
	var health_component := root.get("player_health_component") as Node
	if health_component != null:
		hp = roundi(float(health_component.get("current_health")))
	var chroma_component := root.get("player_chroma_component") as Node
	var chroma := int(chroma_component.get("current_chroma")) if chroma_component != null else 0
	var progression := root.get("progression_tuning") as ProgressionTuning
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, progression)
	var left := ["LV ....... %d" % profile.level, "XP ....... %d/%d" % [profile.xp, xp_required], "HP ....... %d/%d" % [hp, max_hp], "CHROMA ... %d/%d" % [chroma, PlayerChromaComponent.MAX_CHROMA], "STR ...... %d" % roundi(snapshot.strength), "AGI ...... %d" % roundi(snapshot.agi), "VIT ...... %d" % roundi(snapshot.vit), "INT ...... %d" % roundi(snapshot.intelligence), "MND ...... %d" % roundi(snapshot.mnd), "DEF ...... %d" % roundi(snapshot.def)]
	var right := ["P.ATK .... %d" % roundi(CombatCalculator.attack_power_for_snapshot(snapshot, tuning)), "P.DEF .... %d" % roundi(CombatCalculator.physical_defense_for_snapshot(snapshot)), "M.ATK .... %d" % roundi(CombatCalculator.magic_power_for_snapshot(snapshot, tuning)), "M.DEF .... %d" % roundi(CombatCalculator.magic_defense_for_snapshot(snapshot)), "MOV ...... %.2fx" % (player_tuning.agi_multiplier(snapshot.agi) if player_tuning != null else 1.0), "RECOVERY . %.2fx" % (player_tuning.attack_multiplier_for_agi(snapshot.agi) if player_tuning != null else 1.0)]
	for index in left.size():
		hub_status_texts[index].texture = pixel_texture.call(left[index], Color8(255, 205, 117) if index == 1 else Color.WHITE) as Texture2D
	for index in 6:
		hub_status_texts[index + STATUS_LEFT_ROW_COUNT].texture = pixel_texture.call(right[index], Color.WHITE) as Texture2D
	if hub_points_text != null:
		hub_points_text.texture = null
		hub_points_text.visible = false
	if hub_context_text != null: hub_context_text.texture = null


func _allocation_preview_snapshot(root: Object, pending: Array) -> CombatStatSnapshot:
	var stats := root.get("player_stats") as StatsComponent
	if stats == null:
		return root.call("_player_stat_snapshot") as CombatStatSnapshot if root.has_method("_player_stat_snapshot") else null
	var preview_stats := StatsComponent.new()
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
	preview_stats.configure_manual_growth(base_vit, base_str, base_def, base_agi, allocated_vit + int(pending[0]), allocated_str + int(pending[1]), allocated_def + int(pending[2]), allocated_agi + int(pending[3]), base_int, base_mnd, allocated_int + int(pending[4]), allocated_mnd + int(pending[5]))
	preview_stats.level = stats.level
	var snapshot := CombatStatSnapshot.from_components(preview_stats, root.get("player_equipment") as EquipmentComponent)
	preview_stats.free()
	return snapshot


func _allocation_preview_value_text(label: String, value: float) -> String:
	if label == "MOVE" or label == "REC":
		return "%.2f" % value
	return str(roundi(value))


func _update_hub_allocation_preview(root: Object, pixel_texture: Callable, current: CombatStatSnapshot, preview: CombatStatSnapshot) -> void:
	if hub_allocate_preview_title != null:
		hub_allocate_preview_title.texture = pixel_texture.call("EFFECTIVE", Color8(148, 220, 255)) as Texture2D
	if current == null or preview == null:
		for text in hub_allocate_preview_texts: text.texture = null
		return
	var tuning := root.get("combat_tuning") as CombatTuning
	var player_tuning := root.get("player_tuning") as PlayerTuning
	var current_values := [
		CombatCalculator.max_health_for_snapshot(current, tuning),
		CombatCalculator.attack_power_for_snapshot(current, tuning),
		CombatCalculator.magic_power_for_snapshot(current, tuning),
		CombatCalculator.physical_defense_for_snapshot(current),
		CombatCalculator.magic_defense_for_snapshot(current),
		player_tuning.agi_multiplier(current.agi) if player_tuning != null else 1.0,
		player_tuning.attack_multiplier_for_agi(current.agi) if player_tuning != null else 1.0,
	]
	var preview_values := [
		CombatCalculator.max_health_for_snapshot(preview, tuning),
		CombatCalculator.attack_power_for_snapshot(preview, tuning),
		CombatCalculator.magic_power_for_snapshot(preview, tuning),
		CombatCalculator.physical_defense_for_snapshot(preview),
		CombatCalculator.magic_defense_for_snapshot(preview),
		player_tuning.agi_multiplier(preview.agi) if player_tuning != null else 1.0,
		player_tuning.attack_multiplier_for_agi(preview.agi) if player_tuning != null else 1.0,
	]
	var labels := ["HP", "P ATK", "M ATK", "P DEF", "M DEF", "MOVE", "REC"]
	for index in mini(hub_allocate_preview_texts.size(), labels.size()):
		var before := float(current_values[index])
		var after := float(preview_values[index])
		var changed := not is_equal_approx(before, after)
		var value_text := "%s %s" % [labels[index], _allocation_preview_value_text(labels[index], before)]
		if changed: value_text += ">%s" % _allocation_preview_value_text(labels[index], after)
		var value_color := Color8(167, 240, 112) if after > before else Color8(239, 125, 87) if after < before else Color.WHITE
		hub_allocate_preview_texts[index].texture = pixel_texture.call(value_text, value_color) as Texture2D


func _update_pause_player_info(root: Object, pixel_texture: Callable) -> void:
	if pause_player_card_texts.is_empty():
		return
	var profile := root.get("player_profile") as PlayerProfile
	if profile == null:
		return
	var snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot if root.has_method("_player_stat_snapshot") else null
	if snapshot == null:
		return
	var tuning := root.get("combat_tuning") as CombatTuning
	var max_health := roundi(CombatCalculator.max_health_for_snapshot(snapshot, tuning))
	var health := max_health
	var health_component := root.get("player_health_component") as Node
	if health_component != null:
		health = roundi(float(health_component.get("current_health")))
	var chroma_component := root.get("player_chroma_component") as Node
	var chroma := int(chroma_component.get("current_chroma")) if chroma_component != null else 0
	var element := "NORMAL"
	if chroma_component != null and chroma_component.has_method("aspect_name"):
		element = ASPECT_CATALOG_SCRIPT.display_name(chroma_component.call("aspect_name") as StringName)
	var palette_value: Variant = root.get("current_player_palette_name")
	var palette_name: StringName = StringName(str(palette_value)) if palette_value != null else &"blue"
	var values := [
		PlayerProfile.normalize_player_name(profile.player_name),
		element,
		"HP",
		"%d/%d" % [health, max_health],
		"CHR",
		"%d/%d" % [chroma, PlayerChromaComponent.MAX_CHROMA],
		"LV %d" % profile.level,
	]
	for index in pause_player_card_texts.size():
		var text := pause_player_card_texts[index]
		text.visible = true
		var label: String = str(values[index]) if index < values.size() else ""
		var label_color := PauseMenuLayoutScript.MUTED_TEXT_COLOR if index == 1 else Color.WHITE
		text.texture = pixel_texture.call(label, label_color) as Texture2D
	if pause_player_portrait != null and root.has_method("_save_portrait_texture"):
		var portrait_texture := root.call("_save_portrait_texture", String(palette_name)) as Texture2D
		if portrait_texture != null:
			pause_player_portrait.texture = portrait_texture
	_update_pause_resources(root, pixel_texture)


func _update_pause_resources(root: Object, pixel_texture: Callable) -> void:
	var profile := root.get("player_profile") as PlayerProfile
	if profile == null:
		return
	if pause_gold_icon != null:
		pause_gold_icon.visible = true
	if pause_resource_icon != null:
		pause_resource_icon.visible = true
		pause_resource_icon.texture = SoulVisualsScript.texture()
	if pause_gold_text != null:
		var gold_texture := pixel_texture.call(str(profile.gold), PauseMenuLayoutScript.GOLD_TEXT_COLOR) as Texture2D
		pause_gold_text.texture = gold_texture
	if pause_soul_text != null:
		var soul_texture := pixel_texture.call(str(profile.souls), SoulVisualsScript.SOUL_HIGHLIGHT_COLOR) as Texture2D
		pause_soul_text.texture = soul_texture
	_position_pause_resource_texts()


func update_pause_ui(root: Object, pixel_texture: Callable) -> void:
	if pause_overlay == null or not pause_overlay.visible:
		return
	var highlight := PaletteLibrary.accent(player_palette_name)
	for page_root: Control in pause_page_roots.values(): page_root.visible = false
	var active_page := pause_page_roots.get(pause_page) as Control
	if active_page != null: active_page.visible = true
	var showing_root := pause_page == 0
	var root_panel := pause_overlay.get_node_or_null("PausePanel8Piece") as Control
	if root_panel != null: root_panel.visible = showing_root
	_update_pause_player_info(root, pixel_texture)
	for index in pause_menu_buttons.size():
		var button := pause_menu_buttons[index]
		button.visible = pause_page == 0
		# The command rail is intentionally text-only. The cursor is the sole
		# selected-state treatment, matching the Demon Hub and FFIII reference.
		set_archetype_button_state(button, false, highlight)
		_set_menu_button_icon(button, null, false)
	if pause_back_button != null:
		pause_back_button.visible = true
		set_archetype_button_state(pause_back_button, false, highlight)
	var back_prompt := _menu_back_prompt_for(root)
	var confirm_prompt := _menu_confirm_prompt_for(root)
	_set_button_text(pause_back_button, back_prompt, pixel_texture, PauseMenuLayoutScript.MUTED_TEXT_COLOR)
	for node in pause_status_texts: node.visible = pause_page == 1
	for node in pause_equipment_texts: node.visible = pause_page == 2
	if pause_description_text != null:
		pause_description_text.visible = true
		pause_description_text.texture = _pixel_prompt_texture(pixel_texture, confirm_prompt, PauseMenuLayoutScript.MUTED_TEXT_COLOR) as Texture2D
	if pause_gold_icon != null: pause_gold_icon.visible = showing_root
	if pause_resource_icon != null: pause_resource_icon.visible = showing_root
	if pause_gold_text != null: pause_gold_text.visible = showing_root
	if pause_soul_text != null: pause_soul_text.visible = showing_root
	if pause_page == 1:
		_update_pause_status(root, pixel_texture)
	elif pause_page == 2:
		_update_pause_equipment(root, pixel_texture)
	if pause_cursor_text != null and not pause_menu_buttons.is_empty():
		var cursor_index := clampi(pause_menu_row, 0, pause_menu_buttons.size() - 1)
		pause_cursor_text.visible = pause_page == 0
		move_menu_cursor(pause_cursor_text, Vector2(pause_menu_buttons[cursor_index].position.x - CURSOR_LEFT_GAP, pause_menu_buttons[cursor_index].position.y + 3.0))


func _update_pause_status(root: Object, pixel_texture: Callable) -> void:
	var snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot
	if snapshot == null:
		return
	var tuning := root.get("combat_tuning") as CombatTuning
	var player_tuning := root.get("player_tuning") as PlayerTuning
	var health := CombatCalculator.max_health_for_snapshot(snapshot, tuning)
	var health_component := root.get("player_health_component") as Node
	if health_component != null:
		health = float(health_component.get("current_health"))
	var max_health := CombatCalculator.max_health_for_snapshot(snapshot, tuning)
	var chroma_component := root.get("player_chroma_component") as Node
	var chroma := int(chroma_component.get("current_chroma")) if chroma_component != null else 0
	var profile := root.get("player_profile") as PlayerProfile
	var progression := root.get("progression_tuning") as ProgressionTuning
	var xp := profile.xp if profile != null else 0
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, progression) if profile != null else 0
	var values := [
		"LV ...... %d" % (profile.level if profile != null else 0), "XP ...... %d/%d" % [xp, xp_required], "HP ...... %d/%d" % [roundi(health), roundi(max_health)], "CHROMA .. %d/%d" % [chroma, PlayerChromaComponent.MAX_CHROMA], "STR .... %d" % roundi(snapshot.strength), "AGI .... %d" % roundi(snapshot.agi), "VIT .... %d" % roundi(snapshot.vit), "INT .... %d" % roundi(snapshot.intelligence), "MND .... %d" % roundi(snapshot.mnd), "DEF .... %d" % roundi(snapshot.def),
		"P.ATK .. %d" % roundi(CombatCalculator.attack_power_for_snapshot(snapshot, tuning)), "P.DEF .. %d" % roundi(CombatCalculator.physical_defense_for_snapshot(snapshot)), "M.ATK .. %d" % roundi(CombatCalculator.magic_power_for_snapshot(snapshot, tuning)), "M.DEF .. %d" % roundi(CombatCalculator.magic_defense_for_snapshot(snapshot)), "MOV .... %.2fx" % (player_tuning.agi_multiplier(snapshot.agi) if player_tuning != null else 1.0), "REC .... %.2fx" % (player_tuning.attack_multiplier_for_agi(snapshot.agi) if player_tuning != null else 1.0),
	]
	for index in mini(values.size(), pause_status_texts.size()):
		pause_status_texts[index].texture = pixel_texture.call(values[index], Color8(255, 205, 117) if index == 1 else Color.WHITE) as Texture2D
	if pause_description_text != null: pause_description_text.texture = null


func _update_pause_equipment(root: Object, pixel_texture: Callable) -> void:
	var profile := root.get("player_profile") as PlayerProfile
	if profile == null:
		return
	var catalog := ItemCatalog.new()
	var slot_labels := ["WEAPON", "HEAD", "BODY", "ARM", "SHIELD", "ACCESSORY"]
	for index in mini(slot_labels.size(), pause_equipment_texts.size()):
		var slot: StringName = ItemCatalog.SLOTS[index]
		var item := profile.find_item(profile.get_equipped_instance_id(slot))
		var item_name := "EMPTY"
		if item != null:
			item_name = str(ItemCatalog.DEFINITIONS.get(item.definition_id, {}).get("name", "ITEM"))
			if item.enhancement_level > 0: item_name += " +%d" % item.enhancement_level
		pause_equipment_texts[index].texture = pixel_texture.call("%s .... %s" % [slot_labels[index], item_name], catalog.rarity_color(item.rarity) if item != null else Color8(140, 145, 160)) as Texture2D
	for index in range(slot_labels.size(), pause_equipment_texts.size()):
		pause_equipment_texts[index].texture = null
	if pause_description_text != null: pause_description_text.texture = null


func set_pause_page(root: Object, page: int) -> void:
	pause_page = clampi(page, 0, 2)
	update_pause_ui(root, Callable(root, "_pixel_text_texture"))


func pause_back(root: Object) -> void:
	if pause_page != 0:
		set_pause_page(root, 0)
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
		return
	root.call("_close_hub_to_run")


func _update_hub_binding_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, highlight_color: Color) -> void:
	if hub_binding_texts.size() < 5 or profile == null:
		return
	var chroma := root.get("player_chroma_component") as Node
	var current_aspect := &"gray"
	var current_is_bound := false
	if chroma != null:
		current_aspect = chroma.call("aspect_name") as StringName
		current_is_bound = bool(chroma.call("current_is_bound"))
	var current := ASPECT_CATALOG_SCRIPT.display_name(current_aspect)
	var bound := "NONE"
	if profile.has_bound_element:
		bound = String(profile.bound_element).to_upper()
	var cost := PlayerProfile.ELEMENT_BIND_SOUL_COST
	var can_bind := bool(root.call("_can_bind_current_element"))
	var enough_souls := profile.souls >= cost
	var action_enabled := can_bind and enough_souls
	var action_color := highlight_color if action_enabled else Color8(102, 108, 122) if not can_bind or not enough_souls else Color.WHITE
	hub_binding_texts[0].texture = pixel_texture.call("CURRENT %s%s" % [current, " BOUND" if current_is_bound else ""], highlight_color if can_bind else Color.WHITE) as Texture2D
	hub_binding_texts[1].texture = pixel_texture.call("BOUND %s" % bound, Color.WHITE) as Texture2D
	hub_binding_texts[2].texture = pixel_texture.call("SOULS %d" % profile.souls, Color8(211, 167, 255)) as Texture2D
	hub_binding_texts[3].texture = pixel_texture.call("COST %d SOULS" % cost, Color8(255, 205, 117)) as Texture2D
	var status := hub_binding_message
	if status.is_empty():
		if current_aspect == &"gray":
			status = "ATTUNE FIRST"
		elif current_is_bound:
			status = "ALREADY BOUND"
		elif not enough_souls:
			status = "NEED %d SOULS" % cost
		else:
			status = "READY TO BIND"
	hub_binding_texts[4].texture = pixel_texture.call(status, Color8(255, 105, 105) if not action_enabled and current_aspect != &"gray" and not current_is_bound else Color8(167, 240, 112)) as Texture2D
	if hub_binding_action_button != null:
		hub_binding_action_button.disabled = not action_enabled
		var action_label := hub_binding_action_button.get_child(0) as Sprite2D
		if action_label != null:
			var label := "BIND" if action_enabled else "BOUND" if current_is_bound else "NONE" if current_aspect == &"gray" else "NEED 50S"
			action_label.texture = pixel_texture.call(label, action_color) as Texture2D
		set_archetype_button_state(hub_binding_action_button, action_enabled, highlight_color)


func _update_hub_item_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, page: int, item_list: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	var catalog := ItemCatalog.new()
	var shop_prices := hub_shop_price_texts
	for detail in details:
		detail.texture = null
		detail.visible = false
	if page == 1:
		_update_hub_gear_slots(root, pixel_texture, profile, catalog, item_list, hub_gear_choice_texts, details, action, highlight_color)
		return
	var item: ItemInstance = null
	var price := 0
	var sold := false
	var index := hub_item_index
	var count := 0
	if page == 1:
		count = profile.inventory.size()
		if count > 0: item = ItemInstance.from_dictionary(profile.inventory[clampi(index, 0, count - 1)])
	elif page == 2:
		var run_state := root.get("run_state") as RunState
		if run_state != null:
			run_state.ensure_shop_stock(profile); count = run_state.shop_stock.size()
			if count > 0:
				var entry: Dictionary = run_state.shop_stock[clampi(index, 0, count - 1)]
				item = ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary); price = int(entry.get("price", 0)); sold = bool(entry.get("sold", false))
	else:
		var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
		count = fusion_items.size()
		if count > 0:
			item = fusion_items[clampi(index, 0, count - 1)]
	var selected := clampi(index, 0, maxi(count - 1, 0))
	if hub_item_name_text != null:
		if item != null:
			var header_name := str(catalog.definition_data(item.definition_id).get("name", "ITEM"))
			if item.enhancement_level > 0: header_name += " +%d" % item.enhancement_level
			hub_item_name_text.texture = pixel_texture.call("%d/%d %s" % [selected + 1, count, header_name], catalog.rarity_color(item.rarity)) as Texture2D
		else:
			hub_item_name_text.texture = pixel_texture.call("0/0 NO ITEMS", Color8(140, 145, 160)) as Texture2D
		hub_item_name_text.visible = true
	var item_pitch := 10.0
	var visible_rows := item_list.size()
	hub_list_scroll = clampf(hub_list_scroll, 0.0, maxf(0.0, float(count - visible_rows)))
	_apply_hub_item_scroll(item_pitch)
	var window_start := int(hub_list_scroll)
	var scroll_frac: float = hub_list_scroll - float(window_start)
	for row in item_list.size():
		var source_index := window_start + row
		if source_index >= count:
			item_list[row].texture = null
			if row < shop_prices.size(): shop_prices[row].texture = null
			continue
		if row < hub_item_row_buttons.size(): hub_item_row_buttons[row].visible = page == 2 or page == 3
		var row_item: ItemInstance
		var row_sold := false
		var row_price := 0
		if page == 1:
			row_item = ItemInstance.from_dictionary(profile.inventory[source_index])
		elif page == 2:
			var row_state := root.get("run_state") as RunState
			var row_entry: Dictionary = row_state.shop_stock[source_index]
			row_item = ItemInstance.from_dictionary(row_entry.get("item", {}) as Dictionary); row_sold = bool(row_entry.get("sold", false)); row_price = int(row_entry.get("price", 0))
		else:
			var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
			if source_index >= fusion_items.size():
				item_list[row].texture = null; continue
			row_item = fusion_items[source_index]
		var definition: Dictionary = catalog.definition_data(row_item.definition_id)
		var rarity_mark := catalog.rarity_letter_grade(row_item.rarity)
		var row_label := "%s %s" % [rarity_mark, str(definition.get("name", "ITEM"))]
		var row_mastery := row_item.enhancement_level
		if row_mastery > 0 and page != 3: row_label += " +%d" % row_mastery
		if page == 2 and row_sold: row_label += " SOLD"
		elif page == 3: row_label += "  +%d" % row_mastery
		if page == 3:
			var row_slot := catalog.definition_slot(row_item.definition_id)
			if profile.get_equipped_instance_id(row_slot) == row_item.instance_id:
				row_label += " E"
		var row_color := highlight_color if source_index == selected else Color8(120, 120, 130) if row_sold else catalog.rarity_color(row_item.rarity)
		item_list[row].texture = pixel_texture.call(row_label, row_color) as Texture2D
		if page == 2 and row < shop_prices.size():
			shop_prices[row].texture = pixel_texture.call("SOLD" if row_sold else "%dG" % row_price, highlight_color if source_index == selected else Color8(120, 120, 130) if row_sold else Color8(255, 205, 117)) as Texture2D
	# The hand cursor marks the selected row and moves with the scrolled content.
	if hub_list_cursor != null:
		var selected_visible_slot := selected - window_start
		if selected_visible_slot >= 0 and selected_visible_slot < item_list.size() and item != null:
			hub_list_cursor.visible = true
			var cursor_row_y := 35.0 + 4.0 + float(selected_visible_slot) * item_pitch - scroll_frac * item_pitch
			move_menu_cursor(hub_list_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, cursor_row_y + 3.0), false)
		else:
			hub_list_cursor.visible = false
	if item == null:
		if not item_list.is_empty():
			var empty_text := hub_fusion_message if page == 3 and not hub_fusion_message.is_empty() else ("NO FUSE / SALVAGE" if page == 3 else "NO ITEMS")
			item_list[0].texture = pixel_texture.call(empty_text, Color8(255, 205, 117) if page == 3 else Color.WHITE) as Texture2D
		for detail in details: detail.texture = null
		for stale_stat in hub_gear_stat_texts: stale_stat.texture = null
		if hub_item_detail_panel != null: hub_item_detail_panel.visible = true
		action.disabled = true
		return
	var mastery := item.enhancement_level
	var bonuses := catalog.bonuses(item, mastery); var bonus_parts: Array[String] = []
	if page != 3:
		for stat: String in bonuses:
			var bonus_label: String = str({"health_rate": "HP", "damage_rate": "DMG"}.get(stat, stat.to_upper()))
			var value := float(bonuses[stat])
			bonus_parts.append("%s %s%.1f" % [bonus_label, "+" if value > 0 else "", value])
		if not bonus_parts.is_empty():
			details[0].texture = pixel_texture.call("  ".join(bonus_parts), Color.WHITE) as Texture2D
			details[0].visible = not bonus_parts.is_empty()
	var selected_transmutation_name := catalog.transmutation_name(item.transmutation_id)
	if page == 3 and not selected_transmutation_name.is_empty():
		details[0].texture = pixel_texture.call("SPECIAL: %s" % selected_transmutation_name, Color8(148, 220, 255)) as Texture2D
		details[0].visible = true
	elif page == 3:
		details[0].texture = null
	var slot := catalog.definition_slot(item.definition_id)
	var equipped := profile.get_equipped_instance_id(slot) == item.instance_id
	var overflow := profile.can_salvage_overflow(item.instance_id, catalog)
	var material_count := profile.fusion_material_count(item.instance_id, catalog)
	var can_fuse := material_count > 0
	var fusion_count := clampi(hub_fusion_count, 1, maxi(material_count, 1))
	if page == 3 and overflow:
		details[1].texture = pixel_texture.call("MYTHIC +10  SALVAGE %dG" % catalog.overflow_salvage_value(item), Color8(255, 205, 117)) as Texture2D
		details[1].visible = true
		for stale_stat in hub_gear_stat_texts: stale_stat.texture = null
	elif page == 3:
		var batch_cost := profile.fusion_batch_cost(item, fusion_count)
		var fusion_color := Color8(211, 167, 255) if profile.souls >= batch_cost else Color8(255, 105, 105)
		var final_rarity := item.rarity
		var final_enhancement := mastery
		for step in fusion_count:
			if final_enhancement >= PlayerProfile.MAX_ITEM_ENHANCEMENT:
				final_rarity = ItemCatalog.next_rarity(final_rarity)
				final_enhancement = 0
			else:
				final_enhancement += 1
		var next_text := "%s -> %s +0" % [String(final_rarity).to_upper(), String(ItemCatalog.next_rarity(final_rarity)).to_upper()] if final_rarity != item.rarity else "+%d -> +%d" % [mastery, final_enhancement]
		details[1].texture = pixel_texture.call("FUSE x%d  %dS  S%d  MAT%d  %s" % [fusion_count, batch_cost, profile.souls, material_count, next_text], fusion_color) as Texture2D
		details[1].visible = true
		var projected := ItemInstance.from_dictionary(item.to_dictionary())
		projected.enhancement_level = final_enhancement
		projected.rarity = final_rarity
		var next_bonuses := catalog.bonuses(projected, 0)
		var preview_stats := hub_gear_stat_texts
		var preview_rows: Array[String] = []
		var preview_order := ["strength", "defense", "vitality", "agi", "intelligence", "mnd"]
		for stat: String in preview_order:
			var before := float(bonuses.get(stat, 0.0))
			var after := float(next_bonuses.get(stat, 0.0))
			if is_equal_approx(before, 0.0) and is_equal_approx(after, 0.0):
				continue
			var preview_label: String = str({"health_rate": "HP", "damage_rate": "DMG", "strength": "STR", "defense": "DEF", "vitality": "VIT", "speed": "AGI", "agi": "AGI", "intelligence": "INT", "mnd": "MND"}.get(stat, stat.to_upper()))
			preview_rows.append("%s %.1f>%.1f" % [preview_label, before, after])
		for row_index in preview_stats.size():
			if row_index < preview_rows.size():
				preview_stats[row_index].texture = pixel_texture.call(preview_rows[row_index], Color8(167, 240, 112)) as Texture2D
				preview_stats[row_index].visible = true
			else:
				preview_stats[row_index].texture = null
				preview_stats[row_index].visible = false
	else:
		var item_info: Array[String] = []
		var player_rate_text := catalog.player_stat_rate_text(item)
		if not player_rate_text.is_empty(): item_info.append(player_rate_text)
		if not selected_transmutation_name.is_empty(): item_info.append("SPECIAL: %s" % selected_transmutation_name)
		if not item_info.is_empty():
			details[1].texture = pixel_texture.call("  ".join(item_info), Color8(148, 220, 255)) as Texture2D
		details[1].visible = not item_info.is_empty()
		var item_detail_lines := catalog.effect_display_lines(item)
		item_detail_lines.append_array(_wrap_gear_text(catalog.player_description(item), HUB_ITEM_TEXT_WRAP_LENGTH))
		_set_gear_detail_lines(details, pixel_texture, item_detail_lines, Color8(210, 220, 235))
	action.disabled = sold or (page == 2 and profile.gold < price) or (page == 1 and equipped) or (page == 3 and (not can_fuse and not overflow or (can_fuse and profile.souls < profile.fusion_batch_cost(item, fusion_count))))
	if hub_fusion_decrease_button != null:
		hub_fusion_decrease_button.disabled = page != 3 or not can_fuse or fusion_count <= 1
		set_archetype_button_state(hub_fusion_decrease_button, not hub_fusion_decrease_button.disabled, highlight_color)
	if hub_fusion_increase_button != null:
		hub_fusion_increase_button.disabled = page != 3 or not can_fuse or fusion_count >= material_count
		set_archetype_button_state(hub_fusion_increase_button, not hub_fusion_increase_button.disabled, highlight_color)
	var label := action.get_child(0) as Sprite2D
	if label != null: label.texture = pixel_texture.call("BUY" if page == 2 else ("SALVAGE" if page == 3 and overflow else ("FUSE x%d" % fusion_count if page == 3 else "EQUIP")), Color.WHITE) as Texture2D
	set_archetype_button_state(action, true, highlight_color)
	_set_menu_button_icon(action, MENU_CIRCLE_TEXTURE, _menu_uses_face_art(root) and not action.disabled)


func _update_hub_gear_slots(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, item_list: Array[Sprite2D], choices: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	# Equipment owns its top Equip/Remove action row. The old lower action
	# button belongs to Shop/Fusion and must never become a second, hidden focus
	# target while the slot picker is being navigated.
	action.visible = false
	action.disabled = true
	for button in hub_gear_choice_buttons: button.visible = false
	for stat in hub_gear_stat_texts:
		stat.texture = null
		stat.visible = false
	var selected_slot_index := clampi(hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var selected_slot: StringName = ItemCatalog.SLOTS[selected_slot_index]
	var candidate_indices := hub_gear_candidate_indices
	var browsing := hub_gear_browsing
	var action_state := hub_equipment_action_focus and not browsing
	var selected_candidate: ItemInstance = null
	var slot_candidates := root.call("_hub_gear_candidates", selected_slot) as Array[ItemInstance]
	var slot_labels := ["WEAPON", "HEAD", "BODY", "ARM", "SHIELD", "ACCESSORY"]
	if hub_item_name_text != null:
		var header := "%s GEAR" % slot_labels[selected_slot_index] if browsing else "SELECT SLOT"
		hub_item_name_text.texture = pixel_texture.call(header, highlight_color if browsing else Color.WHITE) as Texture2D
		hub_item_name_text.visible = not action_state
	for detail in details:
		detail.texture = null
		detail.visible = false
	if action_state:
		# The action row is the complete Equipment screen at this depth. Clear
		# descendants so no slot header, stat card, or old picker label can sit
		# underneath it and look like a second active menu.
		for row in item_list:
			row.texture = null
		for choice in choices:
			choice.texture = null
		if hub_item_detail_panel != null:
			hub_item_detail_panel.visible = false
		if hub_gear_stat_panel != null:
			hub_gear_stat_panel.visible = false
		return
	var head_locked := profile._head_locked_by_body(catalog) if profile != null else false
	for row in item_list.size():
		if row >= ItemCatalog.SLOTS.size():
			item_list[row].texture = null
			continue
		var slot := ItemCatalog.SLOTS[row]
		var shown_item := profile.find_item(profile.get_equipped_instance_id(slot))
		if row == selected_slot_index:
			selected_candidate = shown_item
		var slot_name: String = slot_labels[row]
		var shown_name := "EMPTY"
		var shown_color := Color8(140, 145, 160)
		if shown_item != null:
			shown_name = str(catalog.definition_data(shown_item.definition_id).get("name", "ITEM"))
			var shown_mastery := shown_item.enhancement_level
			if shown_mastery > 0: shown_name += " +%d" % shown_mastery
			shown_color = catalog.rarity_color(shown_item.rarity)
		var row_color := highlight_color if row == selected_slot_index else shown_color
		var slot_locked := slot == &"head" and head_locked
		if slot_locked:
			# The Demon Cloak occupies Body + Head; the Head slot is greyed out.
			item_list[row].texture = pixel_texture.call("%s: LOCKED" % slot_name, Color8(88, 92, 102)) as Texture2D
		else:
			item_list[row].texture = pixel_texture.call("%s: %s" % [slot_name, shown_name], row_color) as Texture2D
		if row < hub_gear_slot_buttons.size():
			hub_gear_slot_buttons[row].disabled = slot_locked
			hub_gear_slot_buttons[row].visible = not action_state
	if hub_slot_cursor != null:
		hub_slot_cursor.visible = not action_state and selected_slot_index >= 0 and selected_slot_index < item_list.size()
		if hub_slot_cursor.visible:
			move_menu_cursor(hub_slot_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, 35.0 + 4.0 + float(selected_slot_index) * 10.0 + 3.0), false)
	for choice in choices: choice.texture = null
	if browsing:
		var current_index := posmod(int(candidate_indices.get(String(selected_slot), 0)), maxi(slot_candidates.size(), 1))
		if not slot_candidates.is_empty(): selected_candidate = slot_candidates[current_index]
		var choice_pitch := 10.0
		var visible_choices := choices.size()
		hub_choice_scroll = clampf(hub_choice_scroll, 0.0, maxf(0.0, float(slot_candidates.size() - visible_choices)))
		_apply_hub_choice_scroll(choice_pitch)
		var window_start := int(hub_choice_scroll)
		var choice_frac: float = hub_choice_scroll - float(window_start)
		for choice_row in choices.size():
			var choice_index := window_start + choice_row
			if choice_index >= slot_candidates.size(): break
			if choice_row < hub_gear_choice_buttons.size(): hub_gear_choice_buttons[choice_row].visible = true
			var choice_item := slot_candidates[choice_index]
			var is_unequip := choice_item.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID
			var choice_label := "%s" % ("UNEQUIP SHIELD" if is_unequip else "%s %s" % [String(choice_item.rarity).substr(0, 1).to_upper(), str(catalog.definition_data(choice_item.definition_id).get("name", "ITEM"))])
			var choice_mastery := choice_item.enhancement_level
			if choice_mastery > 0: choice_label += " +%d" % choice_mastery
			var choice_color := highlight_color if choice_index == current_index else Color8(140, 145, 160) if is_unequip else catalog.rarity_color(choice_item.rarity)
			choices[choice_row].texture = pixel_texture.call(choice_label, choice_color) as Texture2D
		if hub_choice_cursor != null:
			var choice_visible_slot := current_index - window_start
			hub_choice_cursor.visible = choice_visible_slot >= 0 and choice_visible_slot < choices.size()
			if hub_choice_cursor.visible:
				var choice_cursor_y := 91.0 + 4.0 + float(choice_visible_slot) * choice_pitch - choice_frac * choice_pitch
				move_menu_cursor(hub_choice_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, choice_cursor_y + 3.0), false)
		action.visible = false
		if hub_item_detail_panel != null: hub_item_detail_panel.visible = true
		if not details.is_empty():
			details[0].position = Vector2(20, HUB_GEAR_BROWSE_DETAIL_TOP)
			details[0].texture = pixel_texture.call("SELECT %s" % catalog.display_name(selected_candidate) if selected_candidate != null else "NO GEAR", highlight_color) as Texture2D
			details[0].visible = true
		if selected_candidate != null:
			_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, true)
		return
	else:
		for choice in choices: choice.visible = false
	if hub_item_detail_panel != null: hub_item_detail_panel.visible = true
	for detail_index in details.size(): details[detail_index].position = Vector2(20, HUB_ITEM_DETAIL_TOP + detail_index * HUB_ITEM_DETAIL_PITCH)
	if selected_candidate == null:
		var available_candidates := slot_candidates
		if selected_slot_index == ItemCatalog.SLOTS.find(&"shield") and not available_candidates.is_empty():
			details[0].texture = pixel_texture.call("NO SHIELD EQUIPPED", Color8(255, 205, 117)) as Texture2D
			details[1].texture = pixel_texture.call("SELECT FROM INVENTORY", Color8(148, 220, 255)) as Texture2D
			details[0].visible = true; details[1].visible = true
		else:
			details[0].texture = pixel_texture.call("NO GEAR FOR THIS SLOT", Color8(255, 205, 117)) as Texture2D
			details[0].visible = true
		return
	_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, browsing)
	details[0].texture = pixel_texture.call(catalog.display_name(selected_candidate), catalog.rarity_color(selected_candidate.rarity)) as Texture2D
	details[0].visible = true
	var transmutation_name := catalog.transmutation_name(selected_candidate.transmutation_id)
	var item_info: Array[String] = []
	var player_rate_text := catalog.player_stat_rate_text(selected_candidate)
	if not player_rate_text.is_empty(): item_info.append(player_rate_text)
	if not transmutation_name.is_empty(): item_info.append("SPECIAL: %s" % transmutation_name)
	if selected_slot_index == ItemCatalog.SLOTS.find(&"shield"):
		var shield_values := catalog.shield_bonuses(selected_candidate)
		item_info.append("BLOCK +%d ARM +%d%%" % [roundi(float(shield_values.get("guard_durability", 0.0))), roundi(float(shield_values.get("guard_reduction", 0.0)))])
	if not item_info.is_empty():
		details[1].texture = pixel_texture.call("  ".join(item_info), Color8(148, 220, 255)) as Texture2D
		details[1].visible = true
	var description_lines := catalog.effect_display_lines(selected_candidate)
	description_lines.append_array(_wrap_gear_text(catalog.player_description(selected_candidate), HUB_ITEM_TEXT_WRAP_LENGTH))
	if not transmutation_name.is_empty():
		description_lines.append_array(_wrap_gear_text(catalog.transmutation_description(selected_candidate.transmutation_id), HUB_ITEM_TEXT_WRAP_LENGTH))
	_set_gear_detail_lines(details, pixel_texture, description_lines, Color8(210, 220, 235))
	action.disabled = true
	action.visible = false


func _set_transmutation_description(details: Array[Sprite2D], pixel_texture: Callable, description: String) -> void:
	for detail_index in range(2, details.size()):
		details[detail_index].texture = null
		details[detail_index].visible = false
	if description.is_empty():
		return
	var words := description.split(" ")
	var lines: Array[String] = []
	var line := ""
	for word in words:
		if word.length() > HUB_ITEM_TEXT_WRAP_LENGTH:
			if not line.is_empty():
				lines.append(line)
				line = ""
			while word.length() > HUB_ITEM_TEXT_WRAP_LENGTH:
				lines.append(word.left(HUB_ITEM_TEXT_WRAP_LENGTH))
				word = word.substr(HUB_ITEM_TEXT_WRAP_LENGTH)
		var candidate := word if line.is_empty() else "%s %s" % [line, word]
		if candidate.length() > HUB_ITEM_TEXT_WRAP_LENGTH and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty(): lines.append(line)
	for line_index in mini(lines.size(), details.size() - 2):
		details[line_index + 2].texture = pixel_texture.call(lines[line_index], Color8(210, 220, 235)) as Texture2D
		details[line_index + 2].visible = true


func _wrap_gear_text(text: String, line_length: int) -> Array[String]:
	var lines: Array[String] = []
	if text.is_empty():
		return lines
	var line := ""
	for word in text.split(" "):
		if word.length() > line_length:
			if not line.is_empty():
				lines.append(line)
				line = ""
			while word.length() > line_length:
				lines.append(word.left(line_length))
				word = word.substr(line_length)
		var candidate := word if line.is_empty() else "%s %s" % [line, word]
		if candidate.length() > line_length and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return lines


func _set_gear_detail_lines(details: Array[Sprite2D], pixel_texture: Callable, lines: Array[String], color: Color) -> void:
	for detail_index in range(2, details.size()):
		details[detail_index].texture = null
		details[detail_index].visible = false
	for line_index in mini(lines.size(), details.size() - 2):
		details[line_index + 2].texture = pixel_texture.call(lines[line_index], color) as Texture2D
		details[line_index + 2].visible = true


func _update_gear_comparison_stats(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, candidate: ItemInstance, slot_index: int, comparing: bool) -> void:
	var stats := hub_gear_stat_texts
	var slot := ItemCatalog.SLOTS[clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var live_snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot if root.has_method("_player_stat_snapshot") else null
	var player_stats := root.get("player_stats") as StatsComponent
	if live_snapshot != null and player_stats != null:
		# Preview through the same equipment component and shared snapshot used by
		# combat. This keeps rarity rates, transmutation health effects, and the
		# flat-before-rate ordering identical between the menu and runtime.
		var preview_equipment := EquipmentComponent.new()
		var preview_item := candidate
		if candidate != null and candidate.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID:
			preview_item = null
		preview_equipment.configure_preview_from_profile(profile, catalog, slot, preview_item)
		var preview_snapshot := CombatStatSnapshot.from_components(player_stats, preview_equipment)
		var comparison_fields := [
			{"key": "vit", "label": "VIT"}, {"key": "strength", "label": "STR"},
			{"key": "def", "label": "DEF"}, {"key": "agi", "label": "AGI"},
			{"key": "intelligence", "label": "INT"}, {"key": "mnd", "label": "MND"},
		]
		for index in mini(stats.size(), comparison_fields.size()):
			var field: Dictionary = comparison_fields[index]
			var key := str(field["key"])
			var before := float(live_snapshot.get(key))
			var after := float(preview_snapshot.get(key))
			var delta := after - before
			var shown := delta if comparing else after
			var prefix := "+" if shown > 0.0 and comparing else "-" if shown < 0.0 and comparing else ""
			var color := Color8(148, 220, 255) if delta > 0.0 else Color8(239, 125, 87) if delta < 0.0 else Color8(167, 240, 112) if not comparing else Color8(150, 156, 170)
			stats[index].visible = true
			stats[index].texture = pixel_texture.call("%s %s%.1f" % [str(field["label"]), prefix, absf(shown) if comparing else shown], color) as Texture2D
		var tuning := root.get("combat_tuning") as CombatTuning
		var current_attack := CombatCalculator.attack_power_for_snapshot(live_snapshot, tuning)
		var preview_attack := CombatCalculator.attack_power_for_snapshot(preview_snapshot, tuning)
		var current_magic := CombatCalculator.magic_power_for_snapshot(live_snapshot, tuning)
		var preview_magic := CombatCalculator.magic_power_for_snapshot(preview_snapshot, tuning)
		if hub_context_text != null:
			var context := "P%.0f>%.0f M%.0f>%.0f" % [current_attack, preview_attack, current_magic, preview_magic] if comparing else "P%.0f M%.0f" % [preview_attack, preview_magic]
			var confirm_prompt := _menu_confirm_prompt_for(root).replace("SELECT", "EQUIP")
			hub_context_text.texture = pixel_texture.call("%s  %s" % [context, confirm_prompt], Color8(148, 220, 255)) as Texture2D
		preview_equipment.free()
		return
	# Lightweight test doubles and legacy callers may not expose a player
	# snapshot. Keep their package-only comparison readable while using the
	# canonical six-stat names.
	var equipped := profile.find_item(profile.get_equipped_instance_id(slot))
	var candidate_bonuses := _effective_item_bonuses(catalog, candidate, profile.mastery_level(candidate.definition_id))
	var equipped_bonuses := _effective_item_bonuses(catalog, equipped, profile.mastery_level(equipped.definition_id)) if equipped != null else {}
	var fallback_fields := [{"key": "vitality", "label": "VIT", "rate": false}, {"key": "strength", "label": "STR", "rate": false}, {"key": "defense", "label": "DEF", "rate": false}, {"key": "agi", "label": "AGI", "rate": false}, {"key": "intelligence", "label": "INT", "rate": false}, {"key": "mnd", "label": "MND", "rate": false}]
	for index in mini(stats.size(), fallback_fields.size()):
		var field: Dictionary = fallback_fields[index]
		var key := str(field["key"])
		var value := float(candidate_bonuses.get(key, 0.0)) - float(equipped_bonuses.get(key, 0.0)) if comparing else float(candidate_bonuses.get(key, 0.0))
		var prefix := "+" if value > 0 else "-" if value < 0 else ""
		var color := Color8(148, 220, 255) if value > 0 else Color8(239, 125, 87) if value < 0 else Color8(150, 156, 170)
		if is_zero_approx(value) and (key == "intelligence" or key == "mnd"):
			stats[index].texture = null
			stats[index].visible = false
		else:
			stats[index].visible = true
			stats[index].texture = pixel_texture.call("%s %s%.1f%s" % [str(field["label"]), prefix, absf(value), "%" if bool(field["rate"]) else ""], color) as Texture2D
	for index in range(fallback_fields.size(), stats.size()):
		stats[index].texture = null
		stats[index].visible = false


func _effective_item_bonuses(catalog: ItemCatalog, item: ItemInstance, mastery_level: int = 0) -> Dictionary:
	if item == null:
		return {}
	return catalog.bonuses(item, mastery_level)

func update_pause_input(root: Object) -> void:
	if pause_overlay == null or not pause_overlay.visible:
		return
	if bool(root.call("_is_menu_back_just_pressed")):
		root.call("_pause_back")
		return
	if pause_page != 0:
		return
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
		pause_menu_row = posmod(pause_menu_row - 1, pause_menu_buttons.size()); update_pause_ui(root, Callable(root, "_pixel_text_texture")); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		pause_menu_row = posmod(pause_menu_row + 1, pause_menu_buttons.size()); update_pause_ui(root, Callable(root, "_pixel_text_texture")); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_confirm_just_pressed")):
		if pause_menu_row >= 0 and pause_menu_row < pause_menu_buttons.size():
			var action := pause_menu_buttons[pause_menu_row]
			if action != null and not action.disabled: action.pressed.emit()


func update_hub_input(root: Object) -> void:
	var page := hub_page
	var touch_scroll := root.call("_input_touch_scroll_y") as float
	if not is_zero_approx(touch_scroll):
		scroll_hub_content(root, touch_scroll)
		update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	if bool(root.call("_is_menu_back_just_pressed")):
		if page == HUB_PAGE_EQUIPMENT and hub_gear_browsing:
			# Item picker -> slot list.
			root.call("_close_hub_gear_browse")
		elif page == HUB_PAGE_EQUIPMENT and not hub_equipment_action_focus:
			# Slot list -> Equipment command row.
			hub_equipment_action_focus = true
			hub_content_focus = true
			update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		else:
			# Command row -> Demon Hub root (or the normal back route for other
			# pages).
			root.call("_hub_back_or_close")
		return
	if hub_is_root:
		if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
			root.call("_select_hub_menu_row", hub_menu_row - 1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
			root.call("_select_hub_menu_row", hub_menu_row + 1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_confirm_just_pressed")):
			if hub_menu_row >= 0 and hub_menu_row < HUB_COMMAND_PAGE_TARGETS.size(): root.call("_set_hub_page", HUB_COMMAND_PAGE_TARGETS[hub_menu_row])
		return
	hub_content_focus = true
	if page == HUB_PAGE_STATUS:
		return
	if page == HUB_PAGE_BIND:
		if bool(root.call("_is_menu_confirm_just_pressed")):
			var binding_action := hub_binding_action_button
			if binding_action != null and not binding_action.disabled: binding_action.pressed.emit()
		return
	if page == HUB_PAGE_ALLOCATE:
		if hub_stat_row == 6:
			if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
				hub_stat_row = 5; update_hub_ui(root, Callable(root, "_pixel_text_texture"))
			elif bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) or bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
				var utility_direction := -1 if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) else 1
				root.call("_shift_hub_action_column", utility_direction); root.call("_play_sound", "ui_hover", -6.0, 1.0)
			elif bool(root.call("_is_menu_confirm_just_pressed")):
				if hub_action_column < 4:
					var utility_button := [hub_apply_button, hub_cancel_button, hub_auto_button, hub_respec_button][hub_action_column] as Button
					if utility_button != null and not utility_button.disabled: utility_button.pressed.emit()
			return
		if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
			hub_stat_row = maxi(hub_stat_row - 1, 0); update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
			hub_stat_row = mini(hub_stat_row + 1, 6); update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		elif bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) or bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
			var direction := -1 if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) else 1
			root.call("_hub_adjust_stat", [&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"][hub_stat_row], direction); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_confirm_just_pressed")):
			if hub_action_column < 4:
				var utility_button := [hub_apply_button, hub_cancel_button, hub_auto_button, hub_respec_button][hub_action_column] as Button
				if utility_button != null and not utility_button.disabled: utility_button.pressed.emit()
		return
	if page == HUB_PAGE_EQUIPMENT and hub_gear_browsing:
		if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")): root.call("_shift_hub_gear_candidate", -1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")): root.call("_shift_hub_gear_candidate", 1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) or bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
			var slot_direction := -1 if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) else 1
			var next_slot := posmod(hub_item_index + slot_direction, ItemCatalog.SLOTS.size())
			root.call("_select_hub_gear_slot", next_slot); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_confirm_just_pressed")): root.call("_hub_item_action")
		return
	if page == HUB_PAGE_EQUIPMENT:
		if hub_equipment_action_focus:
			if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) or bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
				var action_direction := -1 if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")) else 1
				root.call("_shift_hub_action_column", action_direction); root.call("_play_sound", "ui_hover", -6.0, 1.0)
			elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
				# Command row -> slot list.
				hub_equipment_action_focus = false; hub_gear_browsing = false; update_hub_ui(root, Callable(root, "_pixel_text_texture"))
			elif bool(root.call("_is_menu_confirm_just_pressed")):
				if hub_action_column >= 0 and hub_action_column < hub_equipment_action_buttons.size():
					var equipment_action := hub_equipment_action_buttons[hub_action_column]
					if equipment_action != null and not equipment_action.disabled: equipment_action.pressed.emit()
			return
		if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
			root.call("_shift_hub_item", -1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
			root.call("_shift_hub_item", 1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_menu_confirm_just_pressed")):
			# Slot confirm descends into the candidate item menu. The candidate
			# confirm is handled by the separate browsing branch above.
			root.call("_select_hub_gear_slot", hub_item_index)
		return
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")): root.call("_shift_hub_item", -1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")): root.call("_shift_hub_item", 1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif page == HUB_PAGE_FUSION and bool(root.call("_is_menu_direction_just_pressed", &"ui_left")): root.call("_shift_hub_fusion_count", -1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif page == HUB_PAGE_FUSION and bool(root.call("_is_menu_direction_just_pressed", &"ui_right")): root.call("_shift_hub_fusion_count", 1); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_confirm_just_pressed")):
		var action := hub_item_action_button
		if action != null and not action.disabled: action.pressed.emit()


func build_title(parent: Node, pixel_texture: Callable, new_game_callback: Callable, continue_callback: Callable, has_profile: bool, settings_callback: Callable = Callable(), cloud_callback: Callable = Callable()) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "TitleOverlay", Color.BLACK, 2)
	var title_texture := pixel_texture.call("TINY DEMONS", Color.WHITE) as Texture2D
	var title_text := create_sprite(overlay, "TitleText", title_texture, Vector2((display_view_size.x - title_texture.get_width() * 3.0) * 0.5, 48), false, Vector2(3, 3))
	var version_text := create_sprite(overlay, "TitleVersion", pixel_texture.call(GAME_VERSION, Color8(148, 220, 255)) as Texture2D, Vector2(4, display_view_size.y - 8.0), false)
	var new_game_button := make_retro_button("NEW GAME", Vector2((display_view_size.x - 64.0) * 0.5, 93), Vector2(64, 14), pixel_texture)
	new_game_button.set_meta("title_base_y", 93.0)
	new_game_button.focus_mode = Control.FOCUS_NONE
	new_game_button.pressed.connect(new_game_callback)
	overlay.add_child(new_game_button)
	var continue_button := make_retro_button("CONTINUE", Vector2((display_view_size.x - 64.0) * 0.5, 109), Vector2(64, 14), pixel_texture)
	continue_button.set_meta("title_base_y", 109.0)
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.pressed.connect(continue_callback)
	continue_button.disabled = not has_profile
	overlay.add_child(continue_button)
	var cloud_button := make_retro_button("CLOUD SAVE", Vector2((display_view_size.x - 64.0) * 0.5, 125), Vector2(64, 14), pixel_texture)
	cloud_button.set_meta("title_base_y", 125.0); cloud_button.focus_mode = Control.FOCUS_NONE
	if cloud_callback.is_valid(): cloud_button.pressed.connect(cloud_callback)
	overlay.add_child(cloud_button)
	var settings_button := make_retro_button("SETTINGS", Vector2((display_view_size.x - 64.0) * 0.5, 141), Vector2(64, 14), pixel_texture)
	settings_button.set_meta("title_base_y", 141.0)
	settings_button.focus_mode = Control.FOCUS_NONE
	if settings_callback.is_valid(): settings_button.pressed.connect(settings_callback)
	overlay.add_child(settings_button)
	var cursor := create_sprite(overlay, "TitleCursor", MENU_CURSOR_TEXTURE, Vector2((display_view_size.x - 64.0) * 0.5 - 8.0, 97 if not has_profile else 113), false)
	title_menu_row = 1 if has_profile else 0
	return {"overlay": overlay, "text": title_text, "version": version_text, "new_game": new_game_button, "continue": continue_button, "cloud": cloud_button, "settings": settings_button, "start_text": new_game_button.get_child(0) as Sprite2D, "settings_text": settings_button.get_child(0) as Sprite2D, "cursor": cursor}


func build_settings(parent: Node, pixel_texture: Callable, adjust_callback: Callable, close_callback: Callable, select_option_callback: Callable = Callable()) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "SettingsOverlay", Color(0.015, 0.02, 0.035, 1.0), 8, false)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_menu_frame(overlay, display_view_size)
	var title := _add_menu_title(overlay, "SettingsTitle", "SETTINGS", pixel_texture)
	settings_title_text = title
	settings_option_buttons.clear()
	settings_option_labels.clear()
	var labels: Array[Sprite2D] = []
	var values: Array[Button] = []
	var left_buttons: Array[Button] = []
	var right_buttons: Array[Button] = []
	var row_labels := ["FULLSCREEN", "ASPECT", "PIXEL PERFECT", "MUSIC", "SFX"]
	var option_labels: Array[Array] = [["OFF", "ON"], ["FULL", "3:2", "16:10", "16:9"], ["OFF", "ON"], ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"], ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"]]
	var row_y := 31.0
	var option_start := maxf(90.0, display_view_size.x * 0.38)
	for index in row_labels.size():
		var label := create_sprite(overlay, "SettingsLabel%d" % index, pixel_texture.call(row_labels[index], Color.WHITE) as Texture2D, Vector2(14, row_y + index * 18.0 + 3.0), false)
		labels.append(label)
		var options_for_row: Array[Button] = []
		for option_index in option_labels[index].size():
			var option_text: String = str(option_labels[index][option_index])
			var option_button := make_retro_button(option_text, Vector2(option_start + option_index * 14.0, row_y + index * 18.0), Vector2(12, 12), pixel_texture)
			option_button.name = "SettingsOption%d_%d" % [index, option_index]
			option_button.focus_mode = Control.FOCUS_NONE
			if select_option_callback.is_valid(): option_button.pressed.connect(select_option_callback.bind(index, option_index))
			overlay.add_child(option_button)
			options_for_row.append(option_button)
		settings_option_buttons.append(options_for_row)
		settings_option_labels.append(option_labels[index])
		var left := make_retro_button("<", Vector2(option_start - 20.0, row_y + index * 18.0), Vector2(16, 12), pixel_texture)
		left.name = "SettingsLeft%d" % index
		left.focus_mode = Control.FOCUS_NONE
		if adjust_callback.is_valid(): left.pressed.connect(adjust_callback.bind(index, -1))
		overlay.add_child(left)
		left_buttons.append(left)
		var value := make_retro_button("", Vector2(option_start, row_y + index * 18.0), Vector2(65, 12), pixel_texture)
		value.name = "SettingsValue%d" % index
		if adjust_callback.is_valid(): value.pressed.connect(adjust_callback.bind(index, 1))
		overlay.add_child(value)
		values.append(value)
		var right := make_retro_button(">", Vector2(option_start + 68.0, row_y + index * 18.0), Vector2(16, 12), pixel_texture)
		right.name = "SettingsRight%d" % index
		right.focus_mode = Control.FOCUS_NONE
		if adjust_callback.is_valid(): right.pressed.connect(adjust_callback.bind(index, 1))
		overlay.add_child(right)
		right_buttons.append(right)
		# The old single-value/arrow controls remain as non-interactive compatibility
		# handles for existing callers; the horizontal options above own the UI.
		left.visible = false
		value.visible = false
		right.visible = false
	var description := create_sprite(overlay, "SettingsDescription", null, Vector2(14, 128), false)
	settings_description_text = description
	var back := make_retro_button("BACK", Vector2(display_view_size.x - 68.0, display_view_size.y - 19.0), Vector2(60, 13), pixel_texture)
	back.name = "SettingsBack"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close_callback)
	overlay.add_child(back)
	var cursor := create_sprite(overlay, "SettingsCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)
	settings_row_labels = labels
	settings_value_buttons = values
	settings_left_buttons = left_buttons
	settings_right_buttons = right_buttons
	settings_back_button = back
	settings_cursor_text = cursor
	_position_settings_controls()
	return {"overlay": overlay, "title": title, "labels": labels, "values": values, "left": left_buttons, "right": right_buttons, "options": settings_option_buttons, "back": back, "description": description, "cursor": cursor}


func _position_settings_controls() -> void:
	if settings_overlay == null:
		return
	var option_start := maxf(90.0, display_view_size.x * 0.38)
	if settings_title_text != null and settings_title_text.texture != null:
		settings_title_text.position = Vector2(13, 4)
	var rule := settings_overlay.get_node_or_null("SettingsTitleRule") as ColorRect
	if rule != null: rule.size = Vector2(maxf(display_view_size.x - 16.0, 16.0), 1.0)
	for index in settings_row_labels.size():
		var y := 31.0 + index * 18.0
		settings_row_labels[index].position = Vector2(14, y + 3.0)
		settings_left_buttons[index].position = Vector2(option_start - 20.0, y)
		settings_value_buttons[index].position = Vector2(option_start, y)
		settings_right_buttons[index].position = Vector2(option_start + 68.0, y)
		if index < settings_option_buttons.size():
			var option_x := option_start
			var option_gap := 1.0 if index >= 3 else 2.0
			for option_index in settings_option_buttons[index].size():
				var option_button := settings_option_buttons[index][option_index] as Button
				# Compact the ten-point volume ticks enough for the native 240px
				# frame; their labels remain centered and readable while the wider
				# frames retain the same left-aligned option column.
				var option_width := 12.0 if index >= 3 else maxf(26.0, str(settings_option_labels[index][option_index]).length() * 6.0 + 8.0)
				option_button.position = Vector2(option_x, y)
				option_button.size = Vector2(option_width, 12)
				var option_text := option_button.get_child(0) as Sprite2D
				if option_text != null: option_text.position = option_button.size * 0.5
				option_x += option_width + option_gap
	if settings_back_button != null:
		settings_back_button.position = Vector2(display_view_size.x - 68.0, display_view_size.y - 19.0)
	if settings_description_text != null: settings_description_text.position = Vector2(14, display_view_size.y - 32.0)
	_update_settings_cursor()


func open_settings(root: Object, origin: StringName) -> void:
	if settings_overlay == null:
		return
	settings_origin = origin
	settings_row = 0
	settings_interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	# Settings replaces its source screen. Leaving the pause panel visible under
	# it makes focus and touch hit-testing ambiguous, especially on the web port.
	if origin == &"pause":
		if pause_overlay != null:
			pause_overlay.visible = false
	elif origin == &"title":
		if title_overlay != null:
			title_overlay.visible = false
	settings_overlay.visible = true
	settings_overlay.modulate.a = 1.0
	set_state(&"settings")
	update_settings_ui(root, Callable(root, "_pixel_text_texture"))
	_focus_settings_selection()


func close_settings(root: Object) -> void:
	if settings_overlay != null:
		settings_overlay.visible = false
	settings_interact_input_was_down = false
	if settings_origin == &"pause":
		if pause_overlay != null:
			pause_overlay.visible = true
		hub_pause_mode = true
		pause_page = 0
		pause_menu_row = 3
		set_state(&"pause")
		update_pause_ui(root, Callable(root, "_pixel_text_texture"))
	else:
		if title_overlay != null: title_overlay.visible = true
		menu_input_release_lock = true
		set_state(&"title")
		title_menu_row = 2
		if title_settings_button != null: title_settings_button.visible = true
		if title_cloud_button != null: title_cloud_button.visible = true
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func update_settings_ui(root: Object, pixel_texture: Callable) -> void:
	var service := root.get("settings_service") as SettingsService
	if service == null or settings_value_buttons.is_empty():
		return
	var values := service.values()
	var value_labels := ["ON" if bool(values.get("fullscreen", false)) else "OFF", str(values.get("aspect", "FULL")), "ON" if bool(values.get("pixel_perfect", true)) else "OFF", str(values.get("music_volume", 100)), str(values.get("sfx_volume", 100))]
	var highlight := PaletteLibrary.accent(String(root.get("current_player_palette_name")))
	_set_button_text(settings_back_button, _menu_back_prompt_for(root), pixel_texture, highlight)
	for index in settings_value_buttons.size():
		var value_button := settings_value_buttons[index]
		var value_text := value_button.get_child(0) as Sprite2D
		if value_text != null: value_text.texture = pixel_texture.call(value_labels[index], Color.WHITE) as Texture2D
		set_archetype_button_state(value_button, false, highlight)
		set_archetype_button_state(settings_left_buttons[index], false, highlight)
		set_archetype_button_state(settings_right_buttons[index], false, highlight)
		if index < settings_option_buttons.size():
			var active_option := _settings_option_index(index, values)
			for option_index in settings_option_buttons[index].size():
				var option_button := settings_option_buttons[index][option_index] as Button
				option_button.visible = true
				option_button.focus_mode = Control.FOCUS_NONE
				var option_active := option_index == active_option and settings_row == index
				set_archetype_button_state(option_button, option_active, highlight)
				_set_menu_button_icon(option_button, MENU_CIRCLE_TEXTURE, _menu_uses_face_art(root) and option_active and option_button.size.x >= 24.0)
	if settings_back_button != null:
		set_archetype_button_state(settings_back_button, settings_row == settings_value_buttons.size(), highlight)
	if settings_description_text != null:
		var descriptions := ["DISPLAY MODE", "LOGICAL ASPECT", "PIXEL FILTER", "MUSIC VOLUME", "SFX VOLUME", "RETURN"]
		var description_index := clampi(settings_row, 0, descriptions.size() - 1)
		settings_description_text.texture = pixel_texture.call(descriptions[description_index], Color8(148, 220, 255)) as Texture2D
	_update_settings_cursor()


func _settings_option_index(row: int, values: Dictionary) -> int:
	match row:
		0: return 1 if bool(values.get("fullscreen", false)) else 0
		1:
			return maxi(["FULL", "3:2", "16:10", "16:9"].find(str(values.get("aspect", "FULL"))), 0)
		2: return 1 if bool(values.get("pixel_perfect", true)) else 0
		3: return clampi(roundi(float(values.get("music_volume", 100)) / 10.0), 0, 10)
		4: return clampi(roundi(float(values.get("sfx_volume", 100)) / 10.0), 0, 10)
	return 0


func _settings_option_index_for_cursor(row: int) -> int:
	var service := get_parent().get("settings_service") as SettingsService if get_parent() != null else null
	if service == null:
		return 0
	return _settings_option_index(row, service.values())


func select_setting_option(root: Object, row: int, option_index: int) -> void:
	var service := root.get("settings_service") as SettingsService
	if service == null:
		return
	settings_row = clampi(row, 0, 4)
	match settings_row:
		0: service.set_setting(&"fullscreen", option_index == 1)
		1:
			var aspects := ["FULL", "3:2", "16:10", "16:9"]
			service.set_setting(&"aspect", aspects[clampi(option_index, 0, aspects.size() - 1)])
		2: service.set_setting(&"pixel_perfect", option_index == 1)
		3: service.set_setting(&"music_volume", clampi(option_index, 0, 10) * 10)
		4: service.set_setting(&"sfx_volume", clampi(option_index, 0, 10) * 10)
	update_settings_ui(root, Callable(root, "_pixel_text_texture"))


func adjust_setting(root: Object, row: int, direction: int) -> void:
	var service := root.get("settings_service") as SettingsService
	if service == null:
		return
	settings_row = clampi(row, 0, 4)
	var current: Variant
	match settings_row:
		0:
			current = not bool(service.get_setting(&"fullscreen", false))
			service.set_setting(&"fullscreen", current)
		1:
			var aspects := ["FULL", "3:2", "16:10", "16:9"]
			var current_index := maxi(aspects.find(str(service.get_setting(&"aspect", "FULL"))), 0)
			service.set_setting(&"aspect", aspects[posmod(current_index + (1 if direction >= 0 else -1), aspects.size())])
		2:
			current = not bool(service.get_setting(&"pixel_perfect", true))
			service.set_setting(&"pixel_perfect", current)
		3:
			service.set_setting(&"music_volume", int(service.get_setting(&"music_volume", 100)) + (10 if direction >= 0 else -10))
		4:
			service.set_setting(&"sfx_volume", int(service.get_setting(&"sfx_volume", 100)) + (10 if direction >= 0 else -10))
	update_settings_ui(root, Callable(root, "_pixel_text_texture"))


func _update_settings_cursor() -> void:
	if settings_cursor_text == null or settings_value_buttons.is_empty():
		return
	var back_row := settings_value_buttons.size()
	var row := clampi(settings_row, 0, back_row)
	var selected: Control = settings_back_button
	if row != back_row and row >= 0 and row < settings_option_buttons.size():
		var service_row_values: int = _settings_option_index_for_cursor(row)
		selected = settings_option_buttons[row][service_row_values] as Button
	if selected == null:
		return
	settings_cursor_text.visible = true
	move_menu_cursor(settings_cursor_text, Vector2(selected.position.x - CURSOR_LEFT_GAP, selected.position.y + 4.0))


func _set_button_text(button: Button, label: String, pixel_texture: Callable, color: Color = Color.WHITE) -> void:
	if button == null:
		return
	var text := button.get_child(0) as Sprite2D
	if text == null:
		return
	var icon_texture: Texture2D = _menu_face_texture_for_prompt(label)
	var shown_label: String = _menu_face_label_without_icon(label) if icon_texture != null else label
	text.texture = pixel_texture.call(shown_label, color) as Texture2D
	_set_menu_button_icon(button, icon_texture, icon_texture != null)


func _menu_face_texture_for_prompt(label: String) -> Texture2D:
	if label.begins_with("O "):
		return MENU_CIRCLE_TEXTURE
	if label.begins_with("X "):
		return MENU_X_TEXTURE
	if label.begins_with("TRIANGLE "):
		return MENU_TRIANGLE_TEXTURE
	if label.begins_with("SQUARE "):
		return MENU_SQUARE_TEXTURE
	return null


## Composes a face-button glyph (PlayStation circle/X/triangle/square) with its
## action label into one texture so plain Sprite2D prompts such as the hub
## context text match the glyph treatment that menu buttons already use.
func _pixel_prompt_texture(pixel_texture: Callable, label: String, color: Color) -> Texture2D:
	var glyph := _menu_face_texture_for_prompt(label)
	if glyph == null:
		return pixel_texture.call(label, color) as Texture2D
	var cache_key := "%s:%s" % [label, color.to_html(false)]
	if _prompt_texture_cache.has(cache_key):
		return _prompt_texture_cache[cache_key] as Texture2D
	var text_texture := pixel_texture.call(_menu_face_label_without_icon(label), color) as Texture2D
	var glyph_image := glyph.get_image()
	var text_image := text_texture.get_image()
	var gap := 1
	var image := Image.create(glyph_image.get_width() + gap + text_image.get_width(), maxi(glyph_image.get_height(), text_image.get_height()), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.blit_rect(glyph_image, Rect2i(Vector2i.ZERO, glyph_image.get_size()), Vector2i.ZERO)
	image.blit_rect(text_image, Rect2i(Vector2i.ZERO, text_image.get_size()), Vector2i(glyph_image.get_width() + gap, 0))
	var texture := ImageTexture.create_from_image(image)
	_prompt_texture_cache[cache_key] = texture
	return texture


func _pixel_prompt_sequence_texture(pixel_texture: Callable, labels: Array[String], color: Color, gap: int = 5) -> Texture2D:
	if labels.is_empty():
		return null
	var cache_key := "sequence:%s:%s" % ["|".join(labels), color.to_html(false)]
	if _prompt_texture_cache.has(cache_key):
		return _prompt_texture_cache[cache_key] as Texture2D
	var parts: Array[Dictionary] = []
	var total_width := 0
	var max_height := 1
	for label in labels:
		var glyph := _menu_face_texture_for_prompt(label)
		var text_label := _menu_face_label_without_icon(label) if glyph != null else label
		var text_texture := pixel_texture.call(text_label, color) as Texture2D
		if text_texture == null:
			continue
		var glyph_image: Image = glyph.get_image() if glyph != null else null
		var text_image := text_texture.get_image()
		var part_width := text_image.get_width()
		var part_height := text_image.get_height()
		if glyph_image != null:
			part_width += 1 + glyph_image.get_width()
			part_height = maxi(part_height, glyph_image.get_height())
		parts.append({"glyph": glyph_image, "text": text_image, "width": part_width, "height": part_height})
		total_width += part_width
		max_height = maxi(max_height, part_height)
	if parts.is_empty():
		return null
	total_width += maxi(parts.size() - 1, 0) * gap
	var image := Image.create(total_width, max_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for part: Dictionary in parts:
		var glyph_image := part["glyph"] as Image
		var text_image := part["text"] as Image
		var part_height := int(part["height"])
		var y_offset := int(float(max_height - part_height) / 2.0)
		var text_x := x_offset
		if glyph_image != null:
			image.blit_rect(glyph_image, Rect2i(Vector2i.ZERO, glyph_image.get_size()), Vector2i(x_offset, y_offset))
			text_x += glyph_image.get_width() + 1
		image.blit_rect(text_image, Rect2i(Vector2i.ZERO, text_image.get_size()), Vector2i(text_x, y_offset))
		x_offset += int(part["width"]) + gap
	var texture := ImageTexture.create_from_image(image)
	_prompt_texture_cache[cache_key] = texture
	return texture


func _menu_face_label_without_icon(label: String) -> String:
	if label.begins_with("O ") or label.begins_with("X "):
		return label.substr(2)
	if label.begins_with("TRIANGLE "):
		return label.substr(9)
	if label.begins_with("SQUARE "):
		return label.substr(7)
	return label


func _menu_uses_face_art(root: Object) -> bool:
	if root == null or not root.has_method("_menu_confirm_prompt"):
		return false
	return str(root.call("_menu_confirm_prompt")).begins_with("O ")


func _set_menu_button_icon(button: Button, icon_texture: Texture2D, visible: bool) -> void:
	if button == null:
		return
	var text := button.get_child(0) as Sprite2D
	if text == null:
		return
	var icon: Sprite2D = button.get_node_or_null("MenuFaceIcon") as Sprite2D
	if icon == null:
		icon = Sprite2D.new()
		icon.name = "MenuFaceIcon"
		icon.centered = false
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_child(icon)
	icon.texture = icon_texture
	icon.visible = visible and icon_texture != null
	# Button state colors belong to the control label/border. Face-button art
	# keeps its authored color even while the surrounding action is selected.
	icon.modulate = Color.WHITE
	if icon.visible:
		var text_width: float = float(text.texture.get_width()) if text.texture != null else 0.0
		var group_width: float = 5.0 + 3.0 + text_width
		var start_x: float = floorf((button.size.x - group_width) * 0.5)
		icon.position = Vector2(start_x, floor((button.size.y - 5.0) * 0.5))
		text.centered = false
		text.position = Vector2(start_x + 8.0, floor((button.size.y - float(text.texture.get_height())) * 0.5))
	else:
		text.centered = true
		text.position = button.size * 0.5


func _menu_confirm_prompt_for(root: Object) -> String:
	if root != null and root.has_method("_menu_confirm_prompt"):
		return str(root.call("_menu_confirm_prompt"))
	return "B SELECT"


func _menu_back_prompt_for(root: Object) -> String:
	if root != null and root.has_method("_menu_back_prompt"):
		return str(root.call("_menu_back_prompt"))
	return "A BACK"


func _focus_settings_selection() -> void:
	# Menu focus is rendered by our pixel cursor and owned by InputRouter. Native
	# Control focus must not remain on a hidden source page or steal a controller
	# edge from the active settings route.
	_update_settings_cursor()


func update_settings_input(root: Object) -> void:
	if settings_overlay == null or not settings_overlay.visible:
		return
	if bool(root.call("_is_menu_back_just_pressed")):
		close_settings(root)
		return
	var row_count := settings_value_buttons.size() + (1 if settings_back_button != null else 0)
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
		settings_row = posmod(settings_row - 1, row_count)
		update_settings_ui(root, Callable(root, "_pixel_text_texture"))
		_focus_settings_selection()
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		settings_row = posmod(settings_row + 1, row_count)
		update_settings_ui(root, Callable(root, "_pixel_text_texture"))
		_focus_settings_selection()
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif settings_row < settings_value_buttons.size() and bool(root.call("_is_menu_direction_just_pressed", &"ui_left")):
		adjust_setting(root, settings_row, -1)
	elif settings_row < settings_value_buttons.size() and bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
		adjust_setting(root, settings_row, 1)
	elif bool(root.call("_is_menu_confirm_just_pressed")):
		if settings_row == settings_value_buttons.size() and settings_back_button != null:
			settings_back_button.pressed.emit()
		elif settings_row >= 0 and settings_row < settings_value_buttons.size():
			settings_value_buttons[settings_row].pressed.emit()

func build_save_select(parent: Node, pixel_texture: Callable, select_callback: Callable, overwrite_yes: Callable = Callable(), overwrite_no: Callable = Callable(), portrait_texture: Callable = Callable(), back_callback: Callable = Callable()) -> ColorRect:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "SaveSelectOverlay", Color.BLACK, 4, false)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var _title := create_sprite(overlay, "SaveSelectTitle", pixel_texture.call("CHOOSE SAVE", Color.WHITE) as Texture2D, Vector2((display_view_size.x - 64.0) * 0.5, 42), false)
	var _cursor := create_sprite(overlay, "SaveSelectCursor", MENU_CURSOR_TEXTURE, Vector2((display_view_size.x - 130.0) * 0.5, 70), false)
	var prompt := create_sprite(overlay, "OverwritePrompt", pixel_texture.call("OVERWRITE?  YES / NO", Color.WHITE) as Texture2D, Vector2((display_view_size.x - 100.0) * 0.5, 126), false)
	prompt.visible = false
	var prompt_cursor := create_sprite(overlay, "OverwriteCursor", MENU_CURSOR_TEXTURE, Vector2((display_view_size.x - 42.0) * 0.5, 140), false); prompt_cursor.visible = false
	var yes := make_retro_button("YES", Vector2((display_view_size.x - 30.0) * 0.5, 137), Vector2(24, 12), pixel_texture); yes.name = "OverwriteYes"; yes.visible = false; yes.pressed.connect(overwrite_yes); overlay.add_child(yes)
	var no := make_retro_button("NO", Vector2((display_view_size.x + 30.0) * 0.5, 137), Vector2(20, 12), pixel_texture); no.name = "OverwriteNo"; no.visible = false; no.pressed.connect(overwrite_no); overlay.add_child(no)
	for slot in ProfileSaveService.SLOT_COUNT:
		var profile := ProfileSaveService.load_profile_for_slot(slot)
		var label := "SAVE %d  EMPTY" % (slot + 1)
		var palette_name := "blue"
		if profile != null and profile.has_started:
			label = "SAVE %d  %s" % [slot + 1, PlayerProfile.normalize_player_name(profile.player_name)]
			var flame := profile.starter_flame
			palette_name = AspectCatalog.palette_for_flame(flame)
			if palette_name == "grey" and not profile.palette_name.is_empty():
				palette_name = profile.palette_name
		var button := make_retro_button(label, Vector2((display_view_size.x - 112.0) * 0.5, 66 + slot * 20), Vector2(112, 18), pixel_texture)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = false
		button.set_meta("save_slot", slot)
		button.pressed.connect(select_callback.bind(slot))
		overlay.add_child(button)
		var label_sprite := button.get_child(0) as Sprite2D
		if label_sprite != null:
			label_sprite.position = Vector2(67, 9)
		if profile != null and profile.has_started and portrait_texture.is_valid():
			var portrait := Sprite2D.new()
			portrait.name = "Save%dPortrait" % slot
			portrait.texture = portrait_texture.call(palette_name) as Texture2D
			portrait.position = Vector2(1, 1)
			portrait.centered = false
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.z_index = 1
			button.add_child(portrait)
	var nav_back := make_retro_button("BACK", Vector2(12, display_view_size.y - 23.0), Vector2(42, 18), pixel_texture)
	nav_back.name = "SaveNavBack"; nav_back.focus_mode = Control.FOCUS_NONE
	if back_callback.is_valid(): nav_back.pressed.connect(back_callback)
	overlay.add_child(nav_back)
	save_select_footer_text = create_sprite(overlay, "SaveSelectFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0), false)
	for child in overlay.get_children():
		if child is Button and (child as Button).name in [&"OverwriteYes", &"OverwriteNo"]:
			(child as Button).focus_mode = Control.FOCUS_NONE
	return overlay


func build_name_entry(parent: Node, pixel_texture: Callable, finish_callback: Callable = Callable(), cancel_callback: Callable = Callable(), preview_texture: Callable = Callable()) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "NameEntryOverlay", Color(0.015, 0.02, 0.035, 1.0), 5, false)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_menu_frame(overlay, display_view_size)
	_add_menu_title(overlay, "NameEntryTitle", "NAME ENTRY", pixel_texture)
	name_entry_prompt_text = create_sprite(overlay, "NameEntryPrompt", pixel_texture.call("PLEASE ENTER A NAME.", Color.WHITE) as Texture2D, Vector2(14, 22), false)
	name_entry_field_panel = _make_menu_card(overlay, "NameEntryField", Vector2(32, 29), Vector2(176, 20))
	name_entry_name_text = create_sprite(overlay, "NameEntryName", null, Vector2(120, 36), true)
	name_entry_page_text = create_sprite(overlay, "NameEntryPage", null, Vector2(14, 55), false)
	name_entry_message_text = create_sprite(overlay, "NameEntryMessage", null, Vector2(14, 125), false)
	name_entry_actions_text = create_sprite(overlay, "NameEntryActions", null, Vector2(14, 134), false)
	name_entry_confirm_text = create_sprite(overlay, "NameEntryConfirm", null, Vector2(14, 145), false)
	name_entry_back_text = create_sprite(overlay, "NameEntryBack", null, Vector2(78, 145), false)
	name_entry_cursor_text = create_sprite(overlay, "NameEntryCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)

	var preview_panel := _make_menu_card(overlay, "NameEntryPreviewPanel", Vector2(166, 62), Vector2(62, 54))
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_entry_preview = create_sprite(overlay, "NameEntryPreview", null, Vector2(197, 82), true)
	if preview_texture.is_valid():
		name_entry_preview.texture = preview_texture.call("blue") as Texture2D
		name_entry_preview.scale = Vector2(0.75, 0.75)

	name_entry_cell_buttons.clear()
	name_entry_cell_texts.clear()
	for index in NAME_ENTRY_COLUMNS * NAME_ENTRY_ROWS:
		var cell := _make_transparent_touch_button(overlay, "NameEntryCell%d" % index, Vector2.ZERO, Vector2(17, 12), Callable(self, "_activate_name_entry_cell").bind(index))
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cell_text := create_sprite(cell, "NameEntryCellText%d" % index, null, cell.size * 0.5, true)
		name_entry_cell_buttons.append(cell)
		name_entry_cell_texts.append(cell_text)
	name_entry_finish_callback = finish_callback
	name_entry_cancel_callback = cancel_callback
	_position_name_entry_controls()
	return {
		"overlay": overlay,
		"prompt": name_entry_prompt_text,
		"name": name_entry_name_text,
		"page": name_entry_page_text,
		"message": name_entry_message_text,
		"actions": name_entry_actions_text,
		"confirm": name_entry_confirm_text,
		"back": name_entry_back_text,
		"cursor": name_entry_cursor_text,
		"preview": name_entry_preview,
		"cells": name_entry_cell_buttons,
	}


func _name_entry_page_characters(page: int = name_entry_page) -> Array[String]:
	var characters: Array[String] = []
	if page == 0:
		# The case toggle intentionally changes the same page so the controller
		# cursor never jumps away from the letter grid.
		var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ" if name_entry_page_case_upper() else "abcdefghijklmnopqrstuvwxyz"
		for character in letters:
			characters.append(character)
		characters.append(" ")
		characters.append("DELETE")
		characters.append("DONE")
	else:
		for character in "0123456789-'.!?/":
			characters.append(character)
		characters.append(" ")
		characters.append("DELETE")
		characters.append("DONE")
	return characters


func name_entry_page_case_upper() -> bool:
	return not bool(get_meta("name_entry_lower_case", false))


func _name_entry_cell_label(token: String) -> String:
	match token:
		" ": return "SPC"
		"DELETE": return "DEL"
		"DONE": return "DONE"
	return token


func _position_name_entry_controls() -> void:
	if name_entry_overlay == null:
		return
	var origin_x := maxf((display_view_size.x - 240.0) * 0.5, 0.0)
	if name_entry_prompt_text != null: name_entry_prompt_text.position = Vector2(origin_x + 14.0, 22.0)
	if name_entry_field_panel != null: name_entry_field_panel.position = Vector2(origin_x + 32.0, 29.0)
	if name_entry_name_text != null: name_entry_name_text.position = Vector2(origin_x + 120.0, 36.0)
	if name_entry_page_text != null: name_entry_page_text.position = Vector2(origin_x + 14.0, 55.0)
	if name_entry_message_text != null: name_entry_message_text.position = Vector2(origin_x + 14.0, 125.0)
	if name_entry_actions_text != null: name_entry_actions_text.position = Vector2(origin_x + 14.0, 134.0)
	if name_entry_confirm_text != null: name_entry_confirm_text.position = Vector2(origin_x + 14.0, 145.0)
	if name_entry_back_text != null: name_entry_back_text.position = Vector2(origin_x + 78.0, 145.0)
	var grid_origin := Vector2(origin_x + 12.0, 66.0)
	for index in name_entry_cell_buttons.size():
		var button := name_entry_cell_buttons[index]
		button.position = grid_origin + Vector2((index % NAME_ENTRY_COLUMNS) * 17.0, int(float(index) / float(NAME_ENTRY_COLUMNS)) * 12.0)
		var label := name_entry_cell_texts[index]
		label.position = button.size * 0.5
	if name_entry_preview != null: name_entry_preview.position = Vector2(origin_x + 197.0, 82.0)
	if name_entry_cursor_text != null:
		var current_index := name_entry_row * NAME_ENTRY_COLUMNS + name_entry_column
		move_menu_cursor(name_entry_cursor_text, grid_origin + Vector2((current_index % NAME_ENTRY_COLUMNS) * 17.0 - CURSOR_LEFT_GAP, int(float(current_index) / float(NAME_ENTRY_COLUMNS)) * 12.0 + 4.0))


func show_name_entry(root: Object, pending_slot: int) -> void:
	if name_entry_overlay == null:
		return
	name_entry_owner = root
	name_entry_pending_slot = clampi(pending_slot, 0, ProfileSaveService.SLOT_COUNT - 1)
	name_entry_name = ""
	name_entry_page = 0
	name_entry_row = 0
	name_entry_column = 0
	set_meta("name_entry_lower_case", false)
	set_meta("name_entry_error", false)
	if title_overlay != null: title_overlay.visible = false
	if save_select_overlay != null: save_select_overlay.visible = false
	if archetype_overlay != null: archetype_overlay.visible = false
	name_entry_overlay.visible = true
	name_entry_overlay.modulate.a = 1.0
	menu_input_release_lock = true
	set_state(&"name_entry")
	update_name_entry_ui(root, Callable(root, "_pixel_text_texture"))


func cancel_name_entry(root: Object) -> void:
	if name_entry_overlay != null: name_entry_overlay.visible = false
	name_entry_owner = null
	name_entry_pending_slot = -1
	menu_input_release_lock = true
	if save_select_overlay != null:
		save_select_overlay.visible = true
		if title_overlay != null: title_overlay.visible = true
		set_state(&"title")
		root.call("_update_save_select_cursor")
	else:
		if title_overlay != null: title_overlay.visible = true
		set_state(&"title")
	if root.has_method("_play_sound"): root.call("_play_sound", "ui_decline", 0.0, 1.0)


func update_name_entry_ui(root: Object, pixel_texture: Callable) -> void:
	if name_entry_overlay == null:
		return
	var highlight := PaletteLibrary.accent(player_palette_name)
	var characters := _name_entry_page_characters()
	if name_entry_name_text != null:
		var shown_name := name_entry_name + "_"
		name_entry_name_text.texture = pixel_texture.call(shown_name, Color.WHITE) as Texture2D
	if name_entry_page_text != null:
		name_entry_page_text.texture = pixel_texture.call("UPPER CASE" if name_entry_page == 0 and name_entry_page_case_upper() else "LOWER CASE" if name_entry_page == 0 else "NUMBERS / SYMBOLS", Color8(148, 220, 255)) as Texture2D
	if name_entry_message_text != null:
		name_entry_message_text.texture = pixel_texture.call("NAME REQUIRED" if name_entry_name.is_empty() and bool(get_meta("name_entry_error", false)) else "MAX 8 CHARACTERS", Color8(255, 105, 105) if bool(get_meta("name_entry_error", false)) else Color8(148, 220, 255)) as Texture2D
	if name_entry_actions_text != null: name_entry_actions_text.texture = _pixel_prompt_sequence_texture(pixel_texture, ["L/R PAGE", "TRIANGLE CASE", "SQUARE DEFAULT"], Color8(148, 220, 255)) as Texture2D
	if name_entry_confirm_text != null: name_entry_confirm_text.texture = _pixel_prompt_texture(pixel_texture, _menu_confirm_prompt_for(root), highlight) as Texture2D
	if name_entry_back_text != null: name_entry_back_text.texture = _pixel_prompt_texture(pixel_texture, _menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
	var selected_index := clampi(name_entry_row * NAME_ENTRY_COLUMNS + name_entry_column, 0, maxi(characters.size() - 1, 0))
	name_entry_row = int(float(selected_index) / float(NAME_ENTRY_COLUMNS))
	name_entry_column = selected_index % NAME_ENTRY_COLUMNS
	for index in name_entry_cell_buttons.size():
		var active := index < characters.size()
		var button := name_entry_cell_buttons[index]
		var label := name_entry_cell_texts[index]
		button.visible = active
		button.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
		label.visible = active
		if active:
			var cell_color := highlight if index == selected_index else Color.WHITE
			label.texture = pixel_texture.call(_name_entry_cell_label(characters[index]), cell_color) as Texture2D
	if name_entry_cursor_text != null:
		name_entry_cursor_text.texture = MENU_CURSOR_TEXTURE
		name_entry_cursor_text.visible = not characters.is_empty()
	_position_name_entry_controls()


func _activate_name_entry_cell(index: int) -> void:
	var characters := _name_entry_page_characters()
	if index < 0 or index >= characters.size():
		return
	var token := characters[index]
	if token == "DELETE":
		if not name_entry_name.is_empty(): name_entry_name = name_entry_name.left(name_entry_name.length() - 1)
		set_meta("name_entry_error", false)
	elif token == "DONE":
		if name_entry_name.strip_edges().is_empty():
			set_meta("name_entry_error", true)
			_update_name_entry_visuals()
			return
		if name_entry_finish_callback.is_valid():
			name_entry_finish_callback.call(PlayerProfile.normalize_player_name(name_entry_name))
		return
	else:
		if token == " " and name_entry_name.is_empty():
			set_meta("name_entry_error", true)
		else:
			if name_entry_name.length() < PlayerProfile.MAX_PLAYER_NAME_LENGTH: name_entry_name += token
			set_meta("name_entry_error", false)
	_update_name_entry_visuals()


func _update_name_entry_visuals() -> void:
	if name_entry_owner != null:
		update_name_entry_ui(name_entry_owner, Callable(name_entry_owner, "_pixel_text_texture"))


func _move_name_entry_cursor(delta: Vector2i) -> void:
	var characters := _name_entry_page_characters()
	if characters.is_empty(): return
	var current := name_entry_row * NAME_ENTRY_COLUMNS + name_entry_column
	var next := current
	if delta.x != 0:
		next = posmod(current + delta.x, characters.size())
	else:
		next = clampi(current + delta.y * NAME_ENTRY_COLUMNS, 0, characters.size() - 1)
	name_entry_row = int(float(next) / float(NAME_ENTRY_COLUMNS))
	name_entry_column = next % NAME_ENTRY_COLUMNS
	_update_name_entry_visuals()


func _name_entry_change_page(direction: int) -> void:
	name_entry_page = posmod(name_entry_page + direction, 2)
	name_entry_row = 0
	name_entry_column = 0
	_update_name_entry_visuals()


func _name_entry_toggle_case() -> void:
	set_meta("name_entry_lower_case", not name_entry_page_case_upper())
	_update_name_entry_visuals()


func update_name_entry_input(root: Object) -> void:
	if name_entry_overlay == null or not name_entry_overlay.visible:
		return
	if menu_input_release_lock:
		var released := not bool(root.call("_is_menu_confirm_pressed")) and not bool(root.call("_is_menu_back_pressed"))
		if released: menu_input_release_lock = false
		else: return
	if bool(root.call("_is_menu_back_just_pressed")):
		if name_entry_cancel_callback.is_valid(): name_entry_cancel_callback.call()
		return
	var input_router := root.get("input_router") as InputRouter
	if input_router != null:
		if input_router.just_pressed(&"magic"):
			_name_entry_toggle_case(); root.call("_play_sound", "ui_hover", -6.0, 1.0); return
		if input_router.just_pressed(&"attack"):
			name_entry_name = PlayerProfile.DEFAULT_PLAYER_NAME
			set_meta("name_entry_error", false)
			_update_name_entry_visuals(); root.call("_play_sound", "ui_confirm", 0.0, 1.0); return
		if input_router.just_pressed(&"guard"):
			_name_entry_change_page(-1); root.call("_play_sound", "ui_hover", -6.0, 1.0); return
		if input_router.just_pressed(&"target"):
			_name_entry_change_page(1); root.call("_play_sound", "ui_hover", -6.0, 1.0); return
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")): _move_name_entry_cursor(Vector2i(0, -1)); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")): _move_name_entry_cursor(Vector2i(0, 1)); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_left")): _move_name_entry_cursor(Vector2i(-1, 0)); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_right")): _move_name_entry_cursor(Vector2i(1, 0)); root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_confirm_just_pressed")):
		_activate_name_entry_cell(name_entry_row * NAME_ENTRY_COLUMNS + name_entry_column)
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)


func build_archetype(parent: Node, shift_type: Callable, shift_color: Callable, start_callback: Callable, pixel_texture: Callable) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "ArchetypeOverlay", Color.BLACK, 1, false)
	var preview := create_sprite(overlay, "ArchetypePreview", null, Vector2(0, 43), false, Vector2(1.5, 1.5))
	var name_text := create_sprite(overlay, "ArchetypeName", null, Vector2.ZERO, false)
	var left_buttons: Array[Button] = []
	var right_buttons: Array[Button] = []
	for side in [-1, 1]:
		var button := make_archetype_arrow(overlay, side, Vector2(75 if side < 0 else 155, 69), shift_color.bind(side), pixel_texture)
		(left_buttons if side < 0 else right_buttons).append(button)
	# The old second row was independent palette selection. Flame now owns the
	# identity choice, so retain the controls for scene/layout compatibility but
	# keep that obsolete row hidden.
	for button in left_buttons: button.visible = false
	for button in right_buttons: button.visible = false
	var left_type := make_archetype_arrow(overlay, -1, Vector2(display_view_size.x * 0.5 - 45.0, 33), shift_type.bind(-1), pixel_texture)
	var right_type := make_archetype_arrow(overlay, 1, Vector2(display_view_size.x * 0.5 + 35.0, 33), shift_type.bind(1), pixel_texture)
	var start_button := make_retro_button("START", Vector2((display_view_size.x - 42.0) * 0.5, 104), Vector2(42, 14), pixel_texture)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(start_callback)
	overlay.add_child(start_button)
	archetype_footer_text = create_sprite(overlay, "ArchetypeFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(display_view_size.x - 64.0, display_view_size.y - 18.0), false)
	var hold_cover := create_view_overlay(overlay, "ArchetypeHoldCover", Color.BLACK, 10)
	return {"overlay": overlay, "preview": preview, "name": name_text, "left": left_buttons, "right": right_buttons, "type_left": left_type, "type_right": right_type, "start": start_button, "cover": hold_cover}


func make_archetype_arrow(parent: Node, side: int, button_position: Vector2, pressed_callback: Callable, pixel_texture: Callable, hit_size: Vector2 = Vector2(10, 10)) -> Button:
	var button := Button.new(); button.position = button_position; button.size = hit_size; button.text = ""; button.focus_mode = Control.FOCUS_NONE; button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; button.set_meta("archetype_arrow", true)
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new(); style.bg_color = Color.TRANSPARENT; style.border_width_left = 0; style.border_width_top = 0; style.border_width_right = 0; style.border_width_bottom = 0; button.add_theme_stylebox_override(style_state, style)
	var glyph := Sprite2D.new(); glyph.texture = pixel_texture.call("<" if side < 0 else ">", Color.WHITE) as Texture2D; glyph.centered = true; glyph.position = button.size * 0.5; glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; button.add_child(glyph)
	button.pressed.connect(pressed_callback); parent.add_child(button); return button


func build_loading(parent: Node, pixel_texture: Callable) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_view_overlay(parent, "LoadingScreen", Color.BLACK, 4090, false)
	var text := create_sprite(overlay, "LoadingText", pixel_texture.call("LOADING", Color.WHITE) as Texture2D, Vector2.ZERO, false, Vector2.ONE, 4091)
	text.position = display_view_size - text.texture.get_size() - Vector2(4, 4)
	return {"overlay": overlay, "text": text}


func update_loading(overlay: ColorRect, text: Sprite2D, fading: bool, timer: float, delta: float, pixel_texture: Callable) -> Dictionary:
	if fading:
		timer += delta
		overlay.modulate.a = clampf(1.0 - timer / 0.35, 0.0, 1.0)
		if timer >= 0.35:
			fading = false
			overlay.visible = false
			set_state(&"gameplay")
		return {"fading": fading, "timer": timer, "finished": timer >= 0.35}
	timer += delta
	var labels := ["LOADING", "LOADING.", "LOADING..", "LOADING..."]
	text.texture = pixel_texture.call(labels[mini(int(timer / 0.28) % 4, 3)], Color.WHITE) as Texture2D
	text.position = display_view_size - text.texture.get_size() - Vector2(4, 4)
	return {"fading": fading, "timer": timer, "finished": false}


func _make_text_button(label: String, button_position: Vector2, normal_style: StyleBoxFlat, focus_style: StyleBoxFlat, pixel_texture: Callable, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = Vector2(42, 12)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", focus_style)
	button.add_theme_stylebox_override("focus", focus_style)
	var text := Sprite2D.new()
	text.texture = pixel_texture.call(label, Color.WHITE) as Texture2D
	text.centered = true
	text.position = button.size * 0.5
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(text)
	button.pressed.connect(pressed_callback)
	return button


func create_overlay(parent: Node, overlay_name: String, size: Vector2, color: Color, z_index: int, visible: bool = true) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = overlay_name
	overlay.position = Vector2.ZERO
	overlay.size = size
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = z_index
	overlay.visible = visible
	parent.add_child(overlay)
	return overlay


func create_sprite(parent: Node, sprite_name: String, texture: Texture2D, sprite_position: Vector2, centered: bool, scale: Vector2 = Vector2.ONE, z_index: int = 0) -> Sprite2D:
	var sprite := Sprite2D.new()
	if sprite_name.contains("Cursor"):
		var cursor_script := load("res://scripts/menu_cursor.gd") as Script
		if cursor_script != null:
			sprite.set_script(cursor_script)
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = centered
	sprite.position = sprite_position
	sprite.scale = scale
	sprite.z_index = 4095 if sprite_name.contains("Cursor") else z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite


func move_menu_cursor(cursor: Sprite2D, target: Vector2, animate: bool = true) -> void:
	if cursor == null:
		return
	target = Vector2(target.x, target.y - CURSOR_VERTICAL_RAISE)
	if cursor.has_method("move_to"):
		cursor.call("move_to", target, animate)
		return
	var previous_target := Vector2.INF
	if cursor.has_meta("cursor_target"):
		previous_target = cursor.get_meta("cursor_target") as Vector2
	if previous_target.is_equal_approx(target):
		return
	cursor.set_meta("cursor_target", target)
	_kill_cursor_tween(cursor)
	if not animate:
		cursor.position = target
		_start_cursor_bob(cursor)
		return
	var tween := create_tween()
	cursor.set_meta("cursor_tween", tween)
	tween.tween_property(cursor, "position", target, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_cursor_bob.bind(cursor))


## Browser-style list scrolling: a touch drag moves the list CONTENT, never the
## cursor. Positive delta is finger movement downward (content follows the
## finger, revealing earlier rows).
func scroll_hub_content(root: Object, delta_px: float) -> void:
	if is_zero_approx(delta_px) or hub_page < 0:
		return
	var pitch := 10.0
	var count := _hub_active_list_count(root)
	if count <= 0:
		return
	if hub_page == HUB_PAGE_EQUIPMENT and hub_gear_browsing:
		var visible := maxi(hub_gear_choice_texts.size(), 1)
		hub_choice_scroll = clampf(hub_choice_scroll - delta_px / pitch, 0.0, maxf(0.0, float(count - visible)))
	else:
		var visible := maxi(hub_item_list_texts.size(), 1)
		hub_list_scroll = clampf(hub_list_scroll - delta_px / pitch, 0.0, maxf(0.0, float(count - visible)))


func _hub_active_list_count(root: Object) -> int:
	if hub_page == HUB_PAGE_SHOP:
		var run_state := root.get("run_state") as RunState
		if run_state == null:
			return 0
		run_state.ensure_shop_stock(root.get("player_profile"))
		return run_state.shop_stock.size()
	if hub_page == HUB_PAGE_FUSION:
		return (root.call("_hub_fusion_candidates") as Array).size()
	if hub_page == HUB_PAGE_EQUIPMENT and hub_gear_browsing:
		var selected_slot := ItemCatalog.SLOTS[clampi(hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		return (root.call("_hub_gear_candidates", selected_slot) as Array).size()
	return 0


## Controller/confirm selection changes re-center the content so the selected
## row stays visible; touch drags leave the cursor where it is.
func snap_hub_list_scroll_to_selection(root: Object) -> void:
	if hub_page == HUB_PAGE_EQUIPMENT and hub_gear_browsing:
		var selected_slot := ItemCatalog.SLOTS[clampi(hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var candidates := root.call("_hub_gear_candidates", selected_slot) as Array
		var current_index := int(hub_gear_candidate_indices.get(String(selected_slot), 0))
		var visible := maxi(hub_gear_choice_texts.size(), 1)
		hub_choice_scroll = clampf(float(current_index - 1), 0.0, maxf(0.0, float(candidates.size() - visible)))
		return
	var count := _hub_active_list_count(root)
	if count <= 0:
		return
	var visible := maxi(hub_item_list_texts.size(), 1)
	hub_list_scroll = clampf(float(hub_item_index - 2), 0.0, maxf(0.0, float(count - visible)))


## Applies the fractional item-list scroll to the row/button/price y positions.
func _apply_hub_item_scroll(pitch: float) -> void:
	var frac: float = hub_list_scroll - floor(hub_list_scroll)
	for index in hub_item_list_texts.size():
		hub_item_list_texts[index].position.y = 4 + index * pitch - frac * pitch
		if index < hub_item_row_buttons.size():
			hub_item_row_buttons[index].position.y = index * pitch - frac * pitch
		if index < hub_shop_price_texts.size():
			hub_shop_price_texts[index].position.y = 39 + index * pitch - frac * pitch


## Applies the fractional gear-choice scroll to the picker row positions.
func _apply_hub_choice_scroll(pitch: float) -> void:
	var frac: float = hub_choice_scroll - floor(hub_choice_scroll)
	for index in hub_gear_choice_texts.size():
		hub_gear_choice_texts[index].position.y = 4 + index * pitch - frac * pitch
		if index < hub_gear_choice_buttons.size():
			hub_gear_choice_buttons[index].position.y = index * pitch - frac * pitch


## Resting idle for the hand cursor: it glides a few pixels to the right, then
## quickly flicks back left, looping forever. Horizontal only.
func _start_cursor_bob(cursor: Sprite2D) -> void:
	if cursor == null:
		return
	_kill_cursor_tween(cursor)
	var rest: Vector2 = cursor.get_meta("cursor_target") as Vector2 if cursor.has_meta("cursor_target") else cursor.position
	cursor.position = rest
	var bob := create_tween()
	cursor.set_meta("cursor_tween", bob)
	bob.set_loops()
	bob.tween_property(cursor, "position", rest + Vector2(CURSOR_BOB_AMOUNT, 0.0), CURSOR_BOB_SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bob.tween_property(cursor, "position", rest, CURSOR_BOB_SNAP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _kill_cursor_tween(cursor: Sprite2D) -> void:
	var previous_tween: Tween = cursor.get_meta("cursor_tween") as Tween if cursor.has_meta("cursor_tween") else null
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
