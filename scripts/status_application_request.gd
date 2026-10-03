extends RefCounted
class_name StatusApplicationRequest

enum SourceKind {
	ELEMENTAL_HIT,
	STATUS_TICK,
	CONTACT_TRANSMISSION,
}

var target: Node
var element := 0
var effectiveness := 0.0
var source_kind: int = SourceKind.ELEMENTAL_HIT
var guaranteed_proc := false
var rng: RandomNumberGenerator
var definition_override: StatusEffectDefinition
var transmission_source: Node


func configure(
	target_actor: Node,
	attack_element: int,
	resolved_effectiveness: float,
	request_source: int,
	random_source: RandomNumberGenerator,
	guaranteed: bool = false
) -> void:
	target = target_actor
	element = attack_element
	effectiveness = resolved_effectiveness
	source_kind = request_source
	guaranteed_proc = guaranteed
	rng = random_source
	definition_override = null
	transmission_source = null


func configure_transmission(
	target_actor: Node,
	status_definition: StatusEffectDefinition,
	source_element: int,
	source_actor: Node,
	random_source: RandomNumberGenerator
) -> void:
	target = target_actor
	element = source_element
	effectiveness = 1.0
	source_kind = SourceKind.CONTACT_TRANSMISSION
	# Contact is the delivery condition; a carried status does not roll again.
	guaranteed_proc = true
	rng = random_source
	definition_override = status_definition
	transmission_source = source_actor
