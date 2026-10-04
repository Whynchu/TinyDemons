extends RefCounted
class_name PauseMenuInputController

## Owns command-row navigation and Debug-page selection for the Pause menu.
## Equipment interaction remains in the shared Hub transaction owner.
const PauseMenuStateScript = preload("res://scripts/ui/pause_menu_state.gd")


func update(
	root: GameplayState,
	state: PauseMenuState,
	presenter: PauseScreenPresenter,
	refresh_pause_ui: Callable,
	refresh_debug_menu: Callable
) -> void:
	if bool(root._is_menu_back_just_pressed()):
		root._pause_back()
		return
	if state.pause_page == PauseMenuStateScript.LAST_PAGE:
		_update_debug_page_input(root, state, presenter, refresh_debug_menu)
		return
	if state.pause_page != PauseMenuStateScript.COMMAND_PAGE:
		return
	if bool(root._is_menu_direction_just_pressed(&"ui_up")) or bool(root._is_menu_direction_just_pressed(&"ui_down")):
		var command_list := _pause_command_list(state, presenter.menu_buttons)
		if command_list != null:
			if bool(root._is_menu_direction_just_pressed(&"ui_up")): command_list.move_up()
			else: command_list.move_down()
			state.pause_menu_row = command_list.row
		else:
			if bool(root._is_menu_direction_just_pressed(&"ui_up")): state.pause_menu_row = posmod(state.pause_menu_row - 1, presenter.menu_buttons.size())
			else: state.pause_menu_row = posmod(state.pause_menu_row + 1, presenter.menu_buttons.size())
		refresh_pause_ui.call(root, Callable(root, "_pixel_text_texture"))
		root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_confirm_just_pressed()):
		if state.pause_menu_row >= 0 and state.pause_menu_row < presenter.menu_buttons.size():
			var action := presenter.menu_buttons[state.pause_menu_row]
			if action != null and not action.disabled:
				action.pressed.emit()
			else:
				root._play_sound("ui_no_input", 0.0, 1.0)
		else:
			root._play_sound("ui_no_input", 0.0, 1.0)


func _pause_command_list(state: PauseMenuState, buttons: Array[Button]) -> MenuCommandList:
	if state.command_list == null:
		state.command_list = MenuCommandList.new()
	var base_ys: Array[float] = []
	for index in buttons.size():
		base_ys.append(buttons[index].position.y if buttons[index] != null else 0.0)
	state.command_list.configure(buttons, base_ys)
	state.command_list.row = state.pause_menu_row
	return state.command_list


func _update_debug_page_input(
	root: GameplayState,
	state: PauseMenuState,
	presenter: PauseScreenPresenter,
	refresh_debug_menu: Callable
) -> void:
	if presenter.debug_menu_buttons.is_empty():
		return
	if bool(root._is_menu_direction_just_pressed(&"ui_up")):
		state.debug_menu_row = posmod(state.debug_menu_row - 1, presenter.debug_menu_buttons.size())
		refresh_debug_menu.call(root)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
		state.debug_menu_row = posmod(state.debug_menu_row + 1, presenter.debug_menu_buttons.size())
		refresh_debug_menu.call(root)
	elif bool(root._is_menu_confirm_just_pressed()):
		presenter.debug_menu_buttons[state.debug_menu_row].pressed.emit()
		root._play_sound("ui_confirm", 0.0, 1.0)
