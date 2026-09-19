extends Resource
class_name TouchControlsLayoutProfile

## Logical 240x160 touch layout authored relative to the Roll center.
## Offsets are scaled with the active logical viewport so the same profile
## drives both the visual controls and their circular hit regions.

@export var attack_offset := Vector2(-27.8, 10.1)
@export var magic_offset := Vector2(-49.161603, -8.668517)
@export var guard_offset := Vector2(-38.24094, -32.08796)
@export var target_offset := Vector2(-17.07365, -46.90946)

func offsets() -> Dictionary:
	return {
		&"attack": attack_offset,
		&"magic": magic_offset,
		&"guard": guard_offset,
		&"target": target_offset,
	}
