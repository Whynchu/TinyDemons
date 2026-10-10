extends RefCounted
class_name PauseMenuState

## Mutable Pause routing and input state. ScreenStateController exposes typed
## compatibility properties while Pause routing moves behind dedicated owners.
const COMMAND_PAGE := 0
const STATUS_PAGE := 1
const EQUIPMENT_PAGE := 2
const ITEMS_PAGE := 3
const DEBUG_PAGE := 4
const LAST_PAGE := DEBUG_PAGE

var pause_input_was_down := false
var pause_interact_input_was_down := false
var pause_cancel_input_was_down := false
var pause_page := COMMAND_PAGE
var pause_menu_row := 0
var command_list: MenuCommandList = null
var debug_menu_row := 0


func set_page(page: int) -> void:
	pause_page = clampi(page, COMMAND_PAGE, LAST_PAGE)
	if pause_page == DEBUG_PAGE:
		debug_menu_row = 0
