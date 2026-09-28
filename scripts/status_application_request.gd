extends RefCounted
class_name StatusApplicationRequest

enum SourceKind {
	ELEMENTAL_HIT,
	STATUS_TICK,
}

var target: Node
var element := 0
var effectiveness := 0.0
var source_kind: int = SourceKind.ELEMENTAL_HIT
var rng: RandomNumberGenerator


func configure(
	target_actor: Node,
	attack_element: int,
	resolved_effectiveness: float,
	request_source: int,
	random_source: RandomNumberGenerator
) -> void:
	target = target_actor
	element = attack_element
	effectiveness = resolved_effectiveness
	source_kind = request_source
	rng = random_source
