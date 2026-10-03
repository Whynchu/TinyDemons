extends RefCounted
class_name StatusApplication

const StatusApplicationRequestScript = preload("res://scripts/status_application_request.gd")


static func apply(request: StatusApplicationRequest) -> bool:
	if request == null or request.source_kind == StatusApplicationRequestScript.SourceKind.STATUS_TICK:
		return false
	if request.target == null or not is_instance_valid(request.target):
		return false
	if request.element == ElementCatalog.Element.NEUTRAL or request.effectiveness <= 0.0 or request.rng == null:
		return false
	var definition := request.definition_override if request.definition_override != null else ElementCatalog.status_effect_for_element(request.element)
	if definition == null:
		return false
	var component := request.target.get_node_or_null("Status") as StatusComponent
	if component == null or component.status_immunities.has(definition.id) or component.innate_status_id == definition.id:
		return false
	var combat := request.target.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null and combat.boss_jump_phase_invulnerable:
		return false
	if definition.family == StatusEffectDefinition.Family.PERIODIC_STUN:
		if combat != null and combat.boss_jump_phase_stun_resistant:
			return false
	if not request.guaranteed_proc and request.rng.randf() >= clampf(definition.proc_chance, 0.0, 1.0):
		return false
	return component.apply_effect(
		definition,
		request.element,
		request.source_kind == StatusApplicationRequestScript.SourceKind.CONTACT_TRANSMISSION,
		request.transmission_source
	)
