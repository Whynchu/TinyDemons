extends Sprite2D

const BOB_AMOUNT := 3.0
const BOB_SLIDE_TIME := 0.36
const BOB_SNAP_TIME := 0.07
const MOVE_TIME := 0.10

var _motion_tween: Tween = null
var _target := Vector2.INF
var _locked := false
var _bobbing := false
var _bob_offset_value := Vector2.ZERO
var _bob_offset: Vector2:
	get:
		return _bob_offset_value
	set(value):
		_bob_offset_value = value
		if not _locked and _target.is_finite():
			position = _target + value


func _ready() -> void:
	centered = false
	z_index = 4095
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func move_to(target: Vector2, animate: bool = true) -> void:
	_locked = false
	if _target.is_equal_approx(target):
		if animate and not _bobbing:
			_start_bob()
		return
	_target = target
	_kill_motion()
	# A normal route move starts from the cursor's current position. Reset the
	# bob offset without invoking its position-following setter so an animated
	# move does not snap to the new target before its glide begins.
	_bob_offset_value = Vector2.ZERO
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
	if not is_inside_tree() or _locked:
		return
	if not _target.is_finite():
		return
	_kill_motion()
	_bob_offset = Vector2.ZERO
	var bob := create_tween()
	_motion_tween = bob
	_bobbing = true
	bob.set_loops()
	# Animate an offset rather than an absolute position. A responsive reflow can
	# then change _target while this tween keeps its current phase and bobbing
	# continues from the same point on the glove's motion cycle.
	bob.tween_property(self, "_bob_offset", Vector2(BOB_AMOUNT, 0.0), BOB_SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bob.tween_property(self, "_bob_offset", Vector2.ZERO, BOB_SNAP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _kill_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	_bobbing = false


## Leave a previous cursor visible as a static, dimmed breadcrumb while a
## nested equipment state owns the active cursor.  This intentionally kills
## the bob tween, preventing duplicate motion callbacks when routes change.
func lock_at(target: Vector2) -> void:
	_locked = true
	_target = target
	_kill_motion()
	_bob_offset_value = Vector2.ZERO
	position = target


func unlock() -> void:
	_locked = false
	_start_bob()


func reanchor_preserving_motion(target: Vector2) -> void:
	"""Move a cursor's anchor during responsive reflow without restarting its bob."""
	if not _target.is_finite():
		move_to(target, false)
		return
	if _target.is_equal_approx(target):
		return
	var previous_target := _target
	_target = target
	if _locked:
		_kill_motion()
		_bob_offset_value = Vector2.ZERO
		position = target
		return
	if _bobbing:
		# The bob tween animates _bob_offset, so only the anchor changes here.
		position = _target + _bob_offset_value
		return
	if _motion_tween != null and _motion_tween.is_valid():
		# A resize can arrive during a short route glide. Preserve the current
		# relative point, then finish the glide at the new anchor.
		var relative_position := position + target - previous_target
		_kill_motion()
		_bob_offset_value = Vector2.ZERO
		position = relative_position
		var tween := create_tween()
		_motion_tween = tween
		tween.tween_property(self, "position", target, MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_on_arrived)
		return
	_bob_offset_value = Vector2.ZERO
	position = target
	_start_bob()


func stop_motion() -> void:
	_locked = true
	_kill_motion()


func is_locked() -> bool:
	return _locked


func is_bobbing() -> bool:
	return _bobbing


func _exit_tree() -> void:
	_kill_motion()
