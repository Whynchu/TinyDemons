extends RefCounted

const SpellFormDefinitionScript = preload("res://scripts/spell_form_definition.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const ChromaComponentScript = preload("res://scripts/player_chroma_component.gd")

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


static func cast_form_for(chroma: Node, ability_mode: int) -> Resource:
	if ability_mode != ChromaComponentScript.AbilityMode.ELEMENTAL:
		return form_for_element(ElementCatalogScript.Element.NEUTRAL)
	return selected_form_for(chroma)


static func delivery_of(form: Resource) -> int:
	return int(form.delivery) if form != null else SpellFormDefinitionScript.Delivery.PROJECTILE


static func _ensure_forms() -> void:
	if not _forms.is_empty():
		return
	var stub := _make(&"stub", ElementCatalogScript.Element.NEUTRAL, 2.5, 1.10, SpellFormDefinitionScript.Delivery.PROJECTILE)
	stub.chroma_cost = 0
	_forms[ElementCatalogScript.Element.NEUTRAL] = stub

	var fire := _make(&"fire", ElementCatalogScript.Element.FIRE, 3.0, 1.35, SpellFormDefinitionScript.Delivery.CONE)
	fire.chroma_cost = 15
	fire.delivery_radius = 40.0
	fire.delivery_angle_degrees = 90.0
	fire.knockback_multiplier = 0.4
	_forms[ElementCatalogScript.Element.FIRE] = fire

	var water := _make(&"water", ElementCatalogScript.Element.WATER, 2.0, 0.85, SpellFormDefinitionScript.Delivery.PROJECTILE_SPLASH)
	water.chroma_cost = 10
	water.delivery_radius = 24.0
	water.knockback_multiplier = 0.65
	_forms[ElementCatalogScript.Element.WATER] = water

	var electric := _make(&"electric", ElementCatalogScript.Element.ELECTRIC, 1.2, 1.15, SpellFormDefinitionScript.Delivery.INSTANT_TARGET)
	electric.chroma_cost = 10
	_forms[ElementCatalogScript.Element.ELECTRIC] = electric

	var grass := _make(&"grass", ElementCatalogScript.Element.GRASS, 2.5, 0.40, SpellFormDefinitionScript.Delivery.BEAM)
	grass.chroma_cost = 10
	grass.delivery_range = 64.0
	grass.delivery_duration = 1.8
	grass.tick_interval = 0.45
	grass.lifesteal_ratio = 0.4
	grass.knockback_multiplier = 0.0
	_forms[ElementCatalogScript.Element.GRASS] = grass

	var shadow := _make(&"shadow", ElementCatalogScript.Element.SHADOW, 2.5, 1.10, SpellFormDefinitionScript.Delivery.PROJECTILE)
	shadow.chroma_cost = 12
	shadow.mark_duration = 3.0
	shadow.mark_damage_multiplier = 1.25
	_forms[ElementCatalogScript.Element.SHADOW] = shadow

	var ground := _make(&"ground", ElementCatalogScript.Element.GROUND, 2.5, 0.75, SpellFormDefinitionScript.Delivery.RADIAL_SELF)
	ground.chroma_cost = 12
	ground.delivery_radius = 24.0
	ground.knockback_multiplier = 0.7
	_forms[ElementCatalogScript.Element.GROUND] = ground

	var ice := _make(&"ice", ElementCatalogScript.Element.ICE, 2.2, 1.0, SpellFormDefinitionScript.Delivery.PROJECTILE)
	ice.chroma_cost = 10
	ice.projectile_shape = SpellFormDefinitionScript.ProjectileShape.SHARD
	ice.projectile_size = 5
	ice.projectile_speed = 90.0
	_forms[ElementCatalogScript.Element.ICE] = ice


static func _make(id: StringName, element: int, cooldown: float, damage_multiplier: float, delivery: int) -> Resource:
	var form := SpellFormDefinitionScript.new()
	form.id = id
	form.native_element = element
	form.delivery = delivery
	form.cooldown = cooldown
	form.damage_multiplier = damage_multiplier
	return form
