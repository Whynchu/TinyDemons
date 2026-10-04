extends RefCounted
class_name PauseMenuState

## Mutable Pause routing and input state. ScreenStateController exposes typed
## compatibility properties while Pause routing moves behind dedicated owners.
const COMMAND_PAGE := 0
const LAST_PAGE := 3

var pause_input_was_down := false
var pause_interact_input_was_down := false
var pause_cancel_input_was_down := false
var pause_page := COMMAND_PAGE
var pause_menu_row := 0
var command_list: MenuCommandList = null
var debug_menu_row := 0


func set_page(page: int) -> void:
	pause_page = clampi(page, COMMAND_PAGE, LAST_PAGE)
	if pause_page == LAST_PAGE:
		debug_menu_row = 0
