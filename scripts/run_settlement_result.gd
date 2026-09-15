extends RefCounted
class_name RunSettlementResult

## Typed outcome for the durable run-settlement boundary.

enum Status {
	INVALID_CONTEXT,
	ALREADY_SETTLED,
	SAVE_FAILED,
	NOT_SETTLEABLE,
	SETTLED,
}

var status := Status.INVALID_CONTEXT
var result: StringName = &""


func succeeded() -> bool:
	return status == Status.SETTLED


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
