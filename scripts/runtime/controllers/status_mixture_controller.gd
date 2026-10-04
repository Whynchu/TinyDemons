extends RefCounted
class_name StatusMixtureController


static func capture_innate_suppression(target: Node, applied_element: int) -> Dictionary:
	var captured: Dictionary = {}
	if target == null or not is_instance_valid(target):
		return captured
	var component := target.get_node_or_null("Status") as StatusComponent
	if component == null:
		return captured
	for resource in ElementCatalog.DATA.status_mixtures:
		var mixture := resource as StatusMixtureDefinition
		if mixture == null or not (mixture.first_element == applied_element or mixture.second_element == applied_element):
			continue
		for element in [mixture.first_element, mixture.second_element]:
			var ingredient := ElementCatalog.status_effect_for_element(element)
			if ingredient == null:
				continue
			var record := component.record_for(ingredient.id)
			if record != null and record.origin == StatusRecord.Origin.INNATE:
				captured[ingredient.id] = record.suppressed_by
	return captured


static func resolve_after_application(target: Node, applied_element: int, prior_innate_suppression: Dictionary = {}) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var component := target.get_node_or_null("Status") as StatusComponent
	if component == null:
		return false
	var reaction := _matching_reaction(component, applied_element, prior_innate_suppression)
	if reaction == null:
		return false
	var mixture := reaction.get("mixture") as StatusMixtureDefinition
	var result := reaction.get("result") as StatusEffectDefinition
	if mixture == null or result == null or component.status_immunities.has(result.id):
		return false
	if not component.apply_effect(result, result.element):
		return false
	if mixture.consumes_ingredients:
		var first_status := ElementCatalog.status_effect_for_element(mixture.first_element)
		var second_status := ElementCatalog.status_effect_for_element(mixture.second_element)
		var ingredient_ids: Array[StringName] = []
		if first_status != null:
			ingredient_ids.append(first_status.id)
		if second_status != null:
			ingredient_ids.append(second_status.id)
		component.strip_statuses(ingredient_ids)
	return true


static func _matching_reaction(component: StatusComponent, applied_element: int, prior_innate_suppression: Dictionary) -> Dictionary:
	for resource in ElementCatalog.DATA.status_mixtures:
		var mixture := resource as StatusMixtureDefinition
		if mixture == null or not (mixture.first_element == applied_element or mixture.second_element == applied_element):
			continue
		var first_status := ElementCatalog.status_effect_for_element(mixture.first_element)
		var second_status := ElementCatalog.status_effect_for_element(mixture.second_element)
		if first_status == null or second_status == null:
			continue
		var first_record := component.record_for(first_status.id)
		var second_record := component.record_for(second_status.id)
		if first_record == null or second_record == null:
			continue
		# Applying the counterpart ingredient suppresses an innate status before
		# mixture resolution runs. That suppression must not hide the ingredient
		# needed for this reaction. A status suppressed by an already-active
		# mixture (for example Wet under Freeze) still cannot trigger for free.
		var applied_status := ElementCatalog.status_effect_for_element(applied_element)
		var applied_status_id: StringName = applied_status.id if applied_status != null else &""
		var first_was_suppressed := not StringName(prior_innate_suppression.get(first_status.id, &"")).is_empty()
		var second_was_suppressed := not StringName(prior_innate_suppression.get(second_status.id, &"")).is_empty()
		var first_is_blocked := first_record.origin == StatusRecord.Origin.INNATE and (first_was_suppressed or (not first_record.suppressed_by.is_empty() and first_record.suppressed_by != applied_status_id))
		var second_is_blocked := second_record.origin == StatusRecord.Origin.INNATE and (second_was_suppressed or (not second_record.suppressed_by.is_empty() and second_record.suppressed_by != applied_status_id))
		if first_is_blocked or second_is_blocked:
			continue
		var result := ElementCatalog.status_effect_for_id(mixture.result_status_id)
		if result != null:
			return {"mixture": mixture, "result": result}
	return {}
