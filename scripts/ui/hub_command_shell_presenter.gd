extends RefCounted
class_name HubCommandShellPresenter

const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")
const MenuCursorAnimatorScript = preload("res://scripts/ui/menu_cursor_animator.gd")
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")
const HUB_COMMAND_BUTTON_Y := 5.0
const HUB_COMMAND_CURSOR_TEXT_OFFSET := Vector2(28.0, 3.5)
const HUB_COMMAND_CURSOR_X_CORRECTIONS: Array[float] = [3.0, 0.0, 5.0, 2.0]
const HUB_COMMAND_DIMMED_BOB_OFFSET := Vector2(3.0, 0.0)
const DIM_CURSOR_MODULATE := Color(0.5, 0.5, 0.5, 1.0)
const ACTIVE_CURSOR_MODULATE := Color.WHITE

var page_buttons: Array[Button] = []
var back_button: Button = null
var cursor: Sprite2D = null


func build_navigation(
	root_page: Control,
	overlay: Control,
	view_size: Vector2,
	pixel_texture: Callable,
	actions: HubScreenActions,
	widget_factory: MenuWidgetFactory
) -> void:
	page_buttons.clear()
	var page_labels := ["STATS", "SHOP", "FUSION", "BIND"]
	for command_index in page_labels.size():
		# The four command labels live in the 150px right-hand top cell. Their
		# native positions are spread by label width rather than using a vertical rail.
		var command_x: float = [99.0, 132.0, 166.0, 202.0][command_index]
		var command_width: float = [27.0, 28.0, 31.0, 31.0][command_index]
		var page_button := widget_factory.make_menu_command_button(
			page_labels[command_index],
			Vector2(command_x, HUB_COMMAND_BUTTON_Y),
			Vector2(command_width, 12),
			pixel_texture
		)
		page_button.name = "HubCommand%s" % page_labels[command_index].capitalize()
		page_button.focus_mode = Control.FOCUS_NONE
		page_button.set_meta("hub_command_index", command_index)
		page_button.set_meta("hub_page_target", HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS[command_index])
		# Keep painted glyphs on the shared baseline without changing the wider
		# touch target that surrounds each command.
		var command_text := page_button.get_child(0) as Sprite2D
		if command_text != null and command_text.texture != null:
			command_text.centered = false
			var command_label_x: Array[float] = [106.0, 139.0, 168.0, 206.0]
			command_text.position = Vector2(command_label_x[command_index] - command_x, 3.0)
		page_button.pressed.connect(actions.set_page.bind(HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS[command_index]))
		root_page.add_child(page_button)
		page_buttons.append(page_button)
	back_button = widget_factory.make_menu_command_button(
		"BACK",
		PauseMenuLayoutScript.back_button_position(view_size),
		PauseMenuLayoutScript.BACK_BUTTON_SIZE,
		pixel_texture
	)
	back_button.name = "HubBack"
	back_button.focus_mode = Control.FOCUS_NONE
	if actions.hub_back.is_valid():
		back_button.pressed.connect(actions.hub_back)
	elif actions.pause_resume.is_valid():
		back_button.pressed.connect(actions.pause_resume)
	overlay.add_child(back_button)


func build_cursor(root_page: Control, widget_factory: MenuWidgetFactory) -> void:
	cursor = widget_factory.create_sprite(root_page, "HubCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)
	cursor.visible = false


func position_cursor(
	menu_row: int,
	is_root: bool,
	animate: bool,
	preserve_motion: bool,
	cursor_animator: MenuCursorAnimator,
	tween_owner: Node
) -> void:
	if cursor == null or page_buttons.is_empty():
		return
	var cursor_index := clampi(menu_row, 0, page_buttons.size() - 1)
	var command_target := _command_cursor_target(cursor_index)
	if not is_root:
		# The nested presenter owns the active cursor. Hold this one at the
		# dimmed command's rightmost resting point as a breadcrumb.
		var breadcrumb_target := command_target + HUB_COMMAND_DIMMED_BOB_OFFSET - Vector2(0.0, MenuCursorAnimatorScript.CURSOR_VERTICAL_RAISE)
		if cursor.has_method("lock_at"):
			cursor.call("lock_at", breadcrumb_target)
		else:
			cursor_animator.position_menu_cursor(cursor, command_target, false, preserve_motion, tween_owner)
	else:
		cursor_animator.position_menu_cursor(cursor, command_target, animate, preserve_motion, tween_owner)


func update_cursor_for_page(
	page: int,
	menu_row: int,
	is_root: bool,
	cursor_animator: MenuCursorAnimator,
	tween_owner: Node
) -> void:
	if cursor == null or page_buttons.is_empty():
		return
	var page_command_index := HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS.find(page)
	var cursor_index := clampi(page_command_index if page_command_index >= 0 else menu_row, 0, page_buttons.size() - 1)
	cursor.texture = MENU_CURSOR_TEXTURE
	cursor.visible = true
	var command_target := _command_cursor_target(cursor_index)
	var command_inactive := not is_root
	cursor.modulate = DIM_CURSOR_MODULATE if command_inactive else ACTIVE_CURSOR_MODULATE
	if command_inactive:
		cursor_animator.kill_cursor_tween(cursor)
		var locked_target := command_target + HUB_COMMAND_DIMMED_BOB_OFFSET - Vector2(0.0, MenuCursorAnimatorScript.CURSOR_VERTICAL_RAISE)
		if cursor.has_method("lock_at"):
			cursor.call("lock_at", locked_target)
		elif cursor.has_method("stop_motion"):
			cursor.position = locked_target
			cursor.call("stop_motion")
	else:
		cursor_animator.move_menu_cursor(cursor, command_target, true, tween_owner)


func _command_cursor_target(command_index: int) -> Vector2:
	if page_buttons.is_empty():
		return Vector2.ZERO
	var button := page_buttons[clampi(command_index, 0, page_buttons.size() - 1)] as Button
	if button == null:
		return Vector2.ZERO
	var text_origin := button.position
	if button.get_child_count() > 0:
		var command_text := button.get_child(0) as Sprite2D
		if command_text != null:
			text_origin += command_text.position
	# Keep the half-pixel vertical alignment authored against the painted glyph.
	var command_correction := HUB_COMMAND_CURSOR_X_CORRECTIONS[clampi(command_index, 0, HUB_COMMAND_CURSOR_X_CORRECTIONS.size() - 1)]
	var target := text_origin - HUB_COMMAND_CURSOR_TEXT_OFFSET - Vector2(command_correction, 0.0)
	return Vector2(roundf(target.x), target.y)
