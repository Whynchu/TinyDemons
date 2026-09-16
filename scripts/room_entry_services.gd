extends RefCounted
class_name RoomEntryServices

## Execution boundary for one room entry. The context owns the transition data;
## the composition root supplies this typed operation without being stored by
## the context itself.

var execute_entry: Callable = Callable()


func is_valid() -> bool:
	return execute_entry.is_valid()
