extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var router := InputRouter.new()
	get_root().add_child(router)
	Input.action_release(&"attack")
	Input.action_release(&"move_right")
	Input.action_release(&"ui_accept")

	Input.action_press(&"attack")
	Input.action_press(&"move_right")
	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.context == InputRouter.Context.GAMEPLAY, "gameplay context is recorded", failures)
	_expect(router.pressed(&"attack") and router.just_pressed(&"attack"), "first action press produces held and edge state", failures)
	_expect(router.movement(0.25).x > 0.9, "movement action is captured by the snapshot", failures)

	router.poll(InputRouter.Context.GAMEPLAY)
	_expect(router.pressed(&"attack") and not router.just_pressed(&"attack"), "held action does not repeat just-pressed", failures)
	Input.action_release(&"attack")
	Input.action_release(&"move_right")
	router.poll(InputRouter.Context.DIALOGUE)
	_expect(router.context == InputRouter.Context.DIALOGUE, "dialogue context transition is recorded", failures)
	_expect(router.just_released(&"attack"), "release edge is captured once", failures)

	Input.action_press(&"ui_accept")
	router.poll(InputRouter.Context.MENU)
	_expect(router.context == InputRouter.Context.MENU, "menu context transition is recorded", failures)
	_expect(router.ui_accept_just_pressed(), "UI accept edge is available to menu consumers", failures)

	Input.action_release(&"ui_accept")
	router.free()
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("INPUT_ROUTER_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
