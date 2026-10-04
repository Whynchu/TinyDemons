extends RefCounted
class_name MenuCursorAnimator

const CURSOR_VERTICAL_RAISE := 2.0
const CURSOR_BOB_AMOUNT := 3.0
const CURSOR_BOB_SLIDE_TIME := 0.36
const CURSOR_BOB_SNAP_TIME := 0.07


func position_menu_cursor(cursor: Sprite2D, target: Vector2, animate: bool, preserve_motion: bool, tween_owner: Node) -> void:
	if cursor == null:
		return
	if preserve_motion and cursor.has_method("reanchor_preserving_motion"):
		cursor.call("reanchor_preserving_motion", Vector2(target.x, target.y - CURSOR_VERTICAL_RAISE))
	else:
		move_menu_cursor(cursor, target, animate, tween_owner)


func move_menu_cursor(cursor: Sprite2D, target: Vector2, animate: bool, tween_owner: Node) -> void:
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
	kill_cursor_tween(cursor)
	if not animate:
		cursor.position = target
		start_cursor_bob(cursor, tween_owner)
		return
	var tween := tween_owner.create_tween()
	cursor.set_meta("cursor_tween", tween)
	tween.tween_property(cursor, "position", target, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(start_cursor_bob.bind(cursor, tween_owner))


func start_cursor_bob(cursor: Sprite2D, tween_owner: Node) -> void:
	if cursor == null:
		return
	kill_cursor_tween(cursor)
	var rest: Vector2 = cursor.get_meta("cursor_target") as Vector2 if cursor.has_meta("cursor_target") else cursor.position
	cursor.position = rest
	var bob := tween_owner.create_tween()
	cursor.set_meta("cursor_tween", bob)
	bob.set_loops()
	bob.tween_property(cursor, "position", rest + Vector2(CURSOR_BOB_AMOUNT, 0.0), CURSOR_BOB_SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bob.tween_property(cursor, "position", rest, CURSOR_BOB_SNAP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func kill_cursor_tween(cursor: Sprite2D) -> void:
	if cursor == null:
		return
	var previous_tween: Tween = cursor.get_meta("cursor_tween") as Tween if cursor.has_meta("cursor_tween") else null
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
