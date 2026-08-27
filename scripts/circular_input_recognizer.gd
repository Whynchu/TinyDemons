extends RefCounted
class_name CircularInputRecognizer

## Recognizes a quick, continuous circular movement from the same normalized
## movement stream used by the player. Both clockwise and counter-clockwise
## circles are valid; the signed turn keeps a back-and-forth wiggle from
## satisfying the gesture just by accumulating absolute angles.

var minimum_magnitude := 0.55
var max_duration := 0.50
var required_turn := TAU * 0.80
var arm_duration := 0.28

var _tracking := false
var _armed := false
var _elapsed := 0.0
var _signed_turn := 0.0
var _last_direction := Vector2.ZERO
var _arm_remaining := 0.0
var _sample_count := 0


func configure(min_magnitude: float, duration: float, turn: float, arm_time: float) -> void:
	minimum_magnitude = maxf(min_magnitude, 0.01)
	max_duration = maxf(duration, 0.01)
	required_turn = clampf(turn, 0.1, TAU * 1.5)
	arm_duration = maxf(arm_time, 0.01)
	reset()


func reset() -> void:
	_tracking = false
	_armed = false
	_elapsed = 0.0
	_signed_turn = 0.0
	_last_direction = Vector2.ZERO
	_arm_remaining = 0.0
	_sample_count = 0


func update(movement: Vector2, delta: float) -> bool:
	var step := maxf(delta, 0.0)
	if _armed:
		_arm_remaining = maxf(_arm_remaining - step, 0.0)
		if _arm_remaining <= 0.0:
			reset()
		return false
	var magnitude := movement.length()
	if magnitude < minimum_magnitude:
		if _tracking:
			_elapsed += step
			if _elapsed > max_duration:
				reset()
		return false
	var direction := movement / magnitude
	if not _tracking:
		_tracking = true
		_elapsed = 0.0
		_signed_turn = 0.0
		_last_direction = direction
		_sample_count = 1
		return false
	_elapsed += step
	if _elapsed > max_duration:
		reset()
		_tracking = true
		_last_direction = direction
		_sample_count = 1
		return false
	_signed_turn += atan2(_last_direction.cross(direction), _last_direction.dot(direction))
	_last_direction = direction
	_sample_count += 1
	if _sample_count >= 4 and absf(_signed_turn) >= required_turn:
		_armed = true
		_arm_remaining = arm_duration
		return true
	return false


func is_armed() -> bool:
	return _armed


func consume() -> bool:
	if not _armed:
		return false
	reset()
	return true


func elapsed() -> float:
	return _elapsed


func signed_turn() -> float:
	return _signed_turn


func sample_count() -> int:
	return _sample_count
