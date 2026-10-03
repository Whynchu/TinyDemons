extends RefCounted
class_name StatusRecord

enum Origin { APPLIED, INNATE }

var definition: StatusEffectDefinition
var origin: int = Origin.APPLIED
var remaining := 0.0
var stacks := 1
var source_element := 0
var tick_timer := 0.0
var cadence_timer := 0.0
var cadence_interval := 0.0
var initial_stun_pulse_pending := false
var suppressed_by: StringName = &""
var arrived_by_transmission := false


func configure(
	new_definition: StatusEffectDefinition,
	new_origin: int,
	new_remaining: float,
	new_stacks: int,
	new_source_element: int,
	new_arrived_by_transmission := false
) -> void:
	definition = new_definition
	origin = new_origin
	remaining = new_remaining
	stacks = maxi(new_stacks, 1)
	source_element = new_source_element
	arrived_by_transmission = new_arrived_by_transmission
	tick_timer = definition.tick_interval_for(stacks) if definition.family == StatusEffectDefinition.Family.DAMAGE_OVER_TIME else 0.0
	cadence_timer = 0.0 if definition.family == StatusEffectDefinition.Family.PERIODIC_STUN else definition.stun_interval_for(stacks)
	cadence_interval = definition.stun_interval_for(stacks) if definition.family == StatusEffectDefinition.Family.PERIODIC_STUN else 0.0
	initial_stun_pulse_pending = new_origin == Origin.APPLIED and definition.family == StatusEffectDefinition.Family.PERIODIC_STUN
