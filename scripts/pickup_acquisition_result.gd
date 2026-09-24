extends RefCounted
class_name PickupAcquisitionResult

## Typed handoff from an authoritative pickup grant to presentation.
## The mutation is complete before the result reaches the feedback layer.

enum Status {
	INVALID,
	ACQUIRED,
}

enum Kind {
	ITEM,
	CHROMA,
	SOUL,
	GOLD,
}

var status := Status.INVALID
var kind := Kind.ITEM
var item: ItemInstance = null
var value := 0
var source_position := Vector2.ZERO
var presentation_texture: Texture2D = null
var display_text := ""
var accent_color := Color.WHITE
var target_key: StringName = &""


func succeeded() -> bool:
	return status == Status.ACQUIRED


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
