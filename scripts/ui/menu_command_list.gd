extends RefCounted
class_name MenuCommandList

## Shared menu command-list primitive (Phase 0.30). Owns the ordered command
## buttons plus their static anchor rows, and answers the navigation questions a
## menu screen asks every frame: which row is selected, how to move over only the
## available (enabled/visible) commands, where the cursor should rest, and which
## command confirms. Both the title and pause screens delegate their command-list
## row/cursor/confirm handling here so the behavior is shared and testable.

const CURSOR_LEFT_GAP := 10.0

var _buttons: Array[Button] = []
var _base_ys: Array[float] = []
var row := 0


func configure(buttons: Array[Button], base_ys: Array[float]) -> void:
	_buttons = buttons
	_base_ys = base_ys
	if not available_rows().is_empty():
		row = available_rows()[0]


func buttons() -> Array[Button]:
	return _buttons


func available_rows() -> Array[int]:
	var rows: Array[int] = []
	for index in _buttons.size():
		if _buttons[index] != null and not _buttons[index].disabled:
			rows.append(index)
	return rows


func move_up() -> void:
	var rows := available_rows()
	if rows.is_empty():
		return
	var current := rows.find(row)
	row = rows[posmod(current - 1, rows.size())]


func move_down() -> void:
	var rows := available_rows()
	if rows.is_empty():
		return
	var current := rows.find(row)
	row = rows[posmod(current + 1, rows.size())]


func selected() -> Button:
	if _buttons.is_empty() or row < 0 or row >= _buttons.size():
		return null
	return _buttons[row]


func selected_base_y() -> float:
	if _base_ys.size() <= row or row < 0:
		return 0.0
	return _base_ys[row]


func cursor_target() -> Vector2:
	var button := selected()
	if button == null:
		return Vector2.ZERO
	return Vector2(button.position.x - CURSOR_LEFT_GAP, selected_base_y() + 4.0)


func confirm() -> bool:
	var button := selected()
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true