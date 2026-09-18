extends SceneTree

## Phase 0.30 characterization: the shared MenuCommandList primitive drives the
## title/pause command rail. It must navigate only over available (enabled)
## commands, keep the cursor anchored to the selected row, and dispatch confirm
## to the selected button.

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var list := MenuCommandList.new()
	var buttons: Array[Button] = []
	for index in 4:
		var button := Button.new()
		button.disabled = false
		buttons.append(button)
	list.configure(buttons, [10.0, 30.0, 50.0, 70.0])
	_expect(list.row == 0, "command list starts on the first command", failures)
	list.move_down()
	_expect(list.row == 1 and list.selected() == buttons[1], "down moves to the next command", failures)
	list.move_up()
	_expect(list.row == 0, "up returns to the previous command", failures)
	list.move_up()
	_expect(list.row == 3, "up wraps to the last available command", failures)

	buttons[1].disabled = true
	list.configure(buttons, [10.0, 30.0, 50.0, 70.0])
	list.row = 0
	list.move_down()
	_expect(list.row == 2, "down skips a disabled command", failures)

	var confirmed := [false]
	buttons[2].pressed.connect(func() -> void: confirmed[0] = true)
	list.row = 2
	_expect(list.confirm(), "confirm dispatches the selected command", failures)
	_expect(confirmed[0], "confirm reaches the selected button's pressed signal", failures)
	_expect(is_equal_approx(list.cursor_target().y, 54.0), "cursor anchors below the selected command row", failures)

	for button in buttons:
		button.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: menu command list failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("MENU_COMMAND_LIST_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)