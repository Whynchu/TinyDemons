extends Node

## Owns the short first-entry spawn animation state. While active, the parent
## slime is intentionally non-interactive; the runtime controller advances the
## frames in the explicit gameplay schedule.

var active := false
var frame_index := 0
var frame_timer := 0.0
var frame_time := 0.08
var frames: Array[Texture2D] = []


func begin(spawn_frames: Array[Texture2D], frame_duration: float) -> void:
	frames = spawn_frames.duplicate()
	frame_time = maxf(frame_duration, 0.01)
	frame_index = 0
	frame_timer = 0.0
	active = not frames.is_empty()


func tick(delta: float, set_frame: Callable, finish: Callable) -> bool:
	if not active:
		return false
	frame_timer += maxf(delta, 0.0)
	while active and frame_timer >= frame_time:
		frame_timer -= frame_time
		frame_index += 1
		if frame_index >= frames.size():
			active = false
			finish.call()
			break
		set_frame.call(frame_index)
	return true


func cancel() -> void:
	active = false
	frame_index = 0
	frame_timer = 0.0
	frames.clear()


func is_active() -> bool:
	return active
