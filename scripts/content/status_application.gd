extends RefCounted
class_name StatusApplication

const StatusApplicationRequestScript = preload("res://scripts/content/status_application_request.gd")
const StatusMixtureControllerScript = preload("res://scripts/runtime/controllers/status_mixture_controller.gd")


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
	if component == null:
		return false
	var combat := request.target.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null and combat.boss_jump_phase_invulnerable:
		return false
	if definition.family == StatusEffectDefinition.Family.PERIODIC_STUN:
		if combat != null and combat.boss_jump_phase_stun_resistant:
			return false
	if request.source_kind == StatusApplicationRequestScript.SourceKind.ELEMENTAL_HIT:
		if StatusMixtureControllerScript.resolve_thermal_reaction(request.target, request.element):
			return true
	if component.status_immunities.has(definition.id) or component.innate_status_id == definition.id:
		return false
	if not request.guaranteed_proc and request.rng.randf() >= clampf(definition.proc_chance, 0.0, 1.0):
		return false
	var prior_innate_suppression := StatusMixtureControllerScript.capture_innate_suppression(request.target, definition.element)
	var applied := component.apply_effect(
		definition,
		request.element,
		request.source_kind == StatusApplicationRequestScript.SourceKind.CONTACT_TRANSMISSION,
		request.transmission_source
	)
	if applied:
		StatusMixtureControllerScript.resolve_after_application(request.target, definition.element, prior_innate_suppression)
	return applied
