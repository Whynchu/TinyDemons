extends Sprite2D

const BOB_AMOUNT := 3.0
const BOB_SLIDE_TIME := 0.36
const BOB_SNAP_TIME := 0.07
const MOVE_TIME := 0.10

var _motion_tween: Tween = null
var _target := Vector2.INF


func _ready() -> void:
	centered = false
	z_index = 4095
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func move_to(target: Vector2, animate: bool = true) -> void:
	if _target.is_equal_approx(target):
		return
	_target = target
	_kill_motion()
	if not animate:
		position = target
		_start_bob()
		return
	var tween := create_tween()
	_motion_tween = tween
	tween.tween_property(self, "position", target, MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_on_arrived)


func _on_arrived() -> void:
	_motion_tween = null
	_start_bob()


func _start_bob() -> void:
	if not is_inside_tree():
		return
	_kill_motion()
	position = _target
	var bob := create_tween()
	_motion_tween = bob
	bob.set_loops()
	bob.tween_property(self, "position", _target + Vector2(BOB_AMOUNT, 0.0), BOB_SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bob.tween_property(self, "position", _target, BOB_SNAP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _kill_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _exit_tree() -> void:
	_kill_motion()
