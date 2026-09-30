extends RefCounted

const SpellFormDefinitionScript = preload("res://scripts/spell_form_definition.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

static var _forms: Dictionary = {}


static func form_for_element(element: int) -> Resource:
	_ensure_forms()
	var normalized := ElementCatalogScript.normalize(element)
	return _forms.get(normalized, _forms[ElementCatalogScript.Element.NEUTRAL])


static func selected_form_for(chroma: Node) -> Resource:
	if chroma == null or not is_instance_valid(chroma):
		return form_for_element(ElementCatalogScript.Element.NEUTRAL)
	var bound := int(chroma.get("bound_aspect"))
	var chosen := bound if bound != ElementCatalogScript.Element.NEUTRAL else int(chroma.get("current_aspect"))
	return form_for_element(chosen)


static func delivery_of(form: Resource) -> int:
	return int(form.delivery) if form != null else SpellFormDefinitionScript.Delivery.PROJECTILE


static func _ensure_forms() -> void:
	if not _forms.is_empty():
		return
	_forms[ElementCatalogScript.Element.NEUTRAL] = _make(&"stub", ElementCatalogScript.Element.NEUTRAL, 2.5, 1.10)
	_forms[ElementCatalogScript.Element.FIRE] = _make(&"fire", ElementCatalogScript.Element.FIRE, 2.0, 1.15)
	_forms[ElementCatalogScript.Element.WATER] = _make(&"water", ElementCatalogScript.Element.WATER, 2.0, 1.15)
	_forms[ElementCatalogScript.Element.ELECTRIC] = _make(&"electric", ElementCatalogScript.Element.ELECTRIC, 2.0, 1.15)
	_forms[ElementCatalogScript.Element.GRASS] = _make(&"grass", ElementCatalogScript.Element.GRASS, 2.0, 1.15)
	_forms[ElementCatalogScript.Element.SHADOW] = _make(&"shadow", ElementCatalogScript.Element.SHADOW, 2.0, 1.15)
	_forms[ElementCatalogScript.Element.GROUND] = _make(&"ground", ElementCatalogScript.Element.GROUND, 2.0, 1.15)
	_forms[ElementCatalogScript.Element.ICE] = _make(&"ice", ElementCatalogScript.Element.ICE, 2.0, 1.15)


static func _make(id: StringName, element: int, cooldown: float, damage_multiplier: float) -> Resource:
	var form := SpellFormDefinitionScript.new()
	form.id = id
	form.native_element = element
	form.delivery = SpellFormDefinitionScript.Delivery.PROJECTILE
	form.cooldown = cooldown
	form.damage_multiplier = damage_multiplier
	return form
