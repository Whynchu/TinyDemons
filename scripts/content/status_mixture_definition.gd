@tool
extends Resource
class_name StatusMixtureDefinition

@export_range(1, 7, 1) var first_element := 2
@export_range(1, 7, 1) var second_element := 7
@export var result_status_id: StringName = &"freeze"
@export var guaranteed := true
@export var consumes_ingredients := true


func validate(registered_status_ids: Array[StringName]) -> Array[String]:
	var problems: Array[String] = []
	if first_element <= ElementCatalog.Element.NEUTRAL or first_element >= ElementCatalog.element_count():
		problems.append("first_element must be a registered non-neutral element")
	if second_element <= ElementCatalog.Element.NEUTRAL or second_element >= ElementCatalog.element_count():
		problems.append("second_element must be a registered non-neutral element")
	if first_element == second_element:
		problems.append("status mixture ingredients must be different elements")
	if result_status_id.is_empty() or not registered_status_ids.has(result_status_id):
		problems.append("result_status_id must reference a registered status")
	return problems


func matches_pair(first: int, second: int) -> bool:
	return (first_element == first and second_element == second) or (first_element == second and second_element == first)
