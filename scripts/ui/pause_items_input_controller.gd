extends RefCounted
class_name PauseItemsInputController

## Owns navigation within the read-only Pause Items page.


func update(root: GameplayState, presenter: PauseItemsPresenter, refresh_pause_ui: Callable) -> void:
	var handled := false
	var confirmed := false
	var touch_scroll := root._input_touch_scroll_y() as float
	if not is_zero_approx(touch_scroll):
		handled = presenter.move_selection(-1 if touch_scroll > 0.0 else 1)
	elif bool(root._is_menu_direction_just_pressed(&"ui_up")):
		handled = presenter.move_selection(-1)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
		handled = presenter.move_selection(1)
	elif bool(root._is_menu_direction_just_pressed(&"ui_left")):
		handled = presenter.move_filter(-1)
	elif bool(root._is_menu_direction_just_pressed(&"ui_right")):
		handled = presenter.move_filter(1)
	elif bool(root._is_menu_confirm_just_pressed()):
		presenter.toggle_sort()
		handled = true
		confirmed = true
		root._play_sound("ui_confirm", 0.0, 1.0)
	if handled:
		refresh_pause_ui.call(root, Callable(root, "_pixel_text_texture"))
		if not confirmed:
			root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_up")) or bool(root._is_menu_direction_just_pressed(&"ui_down")) or bool(root._is_menu_direction_just_pressed(&"ui_left")) or bool(root._is_menu_direction_just_pressed(&"ui_right")):
		root._play_sound("ui_no_input", 0.0, 1.0)
