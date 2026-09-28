extends RefCounted
class_name StatusTickResult

enum Kind {
	DAMAGE,
	STUN_PULSE,
}

var kind: int = Kind.DAMAGE
var status_id: StringName = &""
var element := 0
var stacks := 0
var amount := 0.0
var lock_duration := 0.0


func configure(
	result_kind: int,
	result_status_id: StringName,
	result_element: int,
	result_stacks: int,
	result_amount: float = 0.0,
	result_lock_duration: float = 0.0
) -> void:
	kind = result_kind
	status_id = result_status_id
	element = result_element
	stacks = result_stacks
	amount = result_amount
	lock_duration = result_lock_duration
