extends RefCounted
class_name ChestRewardResult

## Typed outcome for a chest's deterministic item-reward decision. The reward
## owner performs generation and persistence; interaction code only consumes
## this report to mark the room state and drive presentation.

enum Status {
	INVALID_CONTEXT,
	ALREADY_RESOLVED,
	RESOLVED_NO_DROP,
	ITEMS_GRANTED,
}

var status := Status.INVALID_CONTEXT
var room_id: StringName = &""
var reward_tier: StringName = DungeonGraph.REWARD_STANDARD
var drop_roll := -1.0
var requested_item_count := 0
var items: Array[ItemInstance] = []
var presentation_required := false


func is_resolved() -> bool:
	return status != Status.INVALID_CONTEXT


func granted_items() -> bool:
	return status == Status.ITEMS_GRANTED and not items.is_empty()


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
