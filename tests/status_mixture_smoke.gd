extends SceneTree

const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")
const ElementAuraComponentScript = preload("res://scripts/components/element_aura_component.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	_expect(ElementCatalogScript.DATA.validate().is_empty(), "status and mixture registry validates", failures)
	var wet := ElementCatalogScript.status_effect_for_id(&"wet")
	var chill := ElementCatalogScript.status_effect_for_id(&"chill")
	var freeze := ElementCatalogScript.status_effect_for_id(&"freeze")
	_expect(wet != null and wet.badge_glyph == "W", "Wet uses its W badge", failures)
	_expect(freeze != null and freeze.badge_glyph == "F", "Freeze uses its F badge", failures)
	if wet == null or chill == null or freeze == null:
		_finish(failures)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 1207
	var wet_then_chill := _new_target()
	_expect(_apply(wet_then_chill, ElementCatalogScript.Element.WATER, rng), "Wet applies first", failures)
	_expect(_apply(wet_then_chill, ElementCatalogScript.Element.ICE, rng), "Chill applies after Wet", failures)
	_assert_frozen(wet_then_chill, failures)
	wet_then_chill.queue_free()

	var chill_then_wet := _new_target()
	_expect(_apply(chill_then_wet, ElementCatalogScript.Element.ICE, rng), "Chill applies first", failures)
	_expect(_apply(chill_then_wet, ElementCatalogScript.Element.WATER, rng), "Wet applies after Chill", failures)
	_assert_frozen(chill_then_wet, failures)
	chill_then_wet.queue_free()

	var innate_water := _new_target()
	var innate_status := innate_water.get_node(^"Status") as StatusComponent
	innate_status.configure_innate(&"wet")
	_expect(_apply(innate_water, ElementCatalogScript.Element.ICE, rng), "Chill applies to an innately Wet actor", failures)
	_expect(innate_status.record_for(&"freeze") != null, "innate Wet plus applied Chill triggers Freeze", failures)
	_expect(innate_status.record_for(&"wet") != null and innate_status.is_suppressed(&"wet"), "innate Wet is hidden under Freeze without deleting the affinity", failures)
	_expect(innate_status.stacks_for(&"chill") == 0, "applied Chill is consumed by the reaction", failures)
	var freeze_remaining := innate_status.record_for(&"freeze").remaining
	_expect(_apply(innate_water, ElementCatalogScript.Element.ICE, rng), "a later Chill hit still applies while Freeze is active", failures)
	_expect(is_equal_approx(innate_status.record_for(&"freeze").remaining, freeze_remaining), "suppressed innate Wet cannot refresh Freeze for free", failures)
	innate_water.queue_free()

	var freeze_status := _new_target().get_node(^"Status") as StatusComponent
	freeze_status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	_expect(is_zero_approx(freeze_status.movement_speed_multiplier()), "Freeze locks movement completely", failures)
	_expect(is_equal_approx(freeze_status.attack_speed_multiplier(), 1.0), "Freeze leaves attacking legal", failures)
	_expect(is_equal_approx(freeze_status.incoming_damage_multiplier_for(ElementCatalogScript.Element.FIRE), 1.25), "Freeze increases direct incoming damage by 25 percent", failures)
	_expect(is_equal_approx(freeze_status.incoming_damage_multiplier_for(ElementCatalogScript.Element.FIRE, false), 1.0), "Freeze vulnerability is excluded from status damage ticks", failures)
	_expect(is_equal_approx(freeze_status.damage_taken_multiplier(), 1.0), "Freeze does not alter the DoT damage multiplier", failures)
	freeze_status.advance(freeze.duration + 0.01)
	_expect(freeze_status.record_for(&"freeze") == null, "Freeze expires cleanly", failures)
	freeze_status.get_parent().queue_free()
	_assert_boss_resistance(freeze, failures)
	_assert_status_marker_draw_order(freeze, failures)
	_finish(failures)


func _new_target() -> Node2D:
	var target := Node2D.new()
	get_root().add_child(target)
	var status := StatusComponent.new()
	status.name = "Status"
	target.add_child(status)
	return target


func _apply(target: Node2D, element: int, rng: RandomNumberGenerator) -> bool:
	var request := StatusApplicationRequest.new()
	request.configure(target, element, 1.0, StatusApplicationRequest.SourceKind.ELEMENTAL_HIT, rng, true)
	return StatusApplication.apply(request)


func _assert_frozen(target: Node2D, failures: Array[String]) -> void:
	var status := target.get_node(^"Status") as StatusComponent
	_expect(status.record_for(&"freeze") != null, "Water and Ice produce Freeze", failures)
	_expect(status.stacks_for(&"wet") == 0 and status.stacks_for(&"chill") == 0, "Freeze consumes applied Wet and Chill", failures)
	_expect(is_zero_approx(status.movement_speed_multiplier()), "Frozen actor cannot move", failures)
	_expect(is_equal_approx(status.attack_speed_multiplier(), 1.0), "Frozen actor keeps its attack speed", failures)
	status.advance(3.1)
	_expect(status.record_for(&"freeze") == null, "Freeze expires after its authored duration", failures)


func _assert_status_marker_draw_order(freeze: StatusEffectDefinition, failures: Array[String]) -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var actor := Sprite2D.new()
	actor.z_index = 4
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	actor.texture = ImageTexture.create_from_image(image)
	world.add_child(actor)
	var status := StatusComponent.new()
	status.name = "Status"
	actor.add_child(status)
	var aura := ElementAuraComponentScript.new() as ElementAuraComponent
	aura.name = "ElementAura"
	actor.add_child(aura)
	aura.configure(actor, world, status)
	status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	var marker := aura._status_outline as Sprite2D
	_expect(marker != null and marker.top_level and not marker.z_as_relative, "status marker uses an absolute world-space draw layer", failures)
	_expect(marker != null and marker.z_index < actor.z_index, "status marker renders underneath its character sprite", failures)
	world.queue_free()


func _assert_boss_resistance(freeze: StatusEffectDefinition, failures: Array[String]) -> void:
	var actor := Node2D.new()
	get_root().add_child(actor)
	var status := StatusComponent.new()
	status.name = "Status"
	actor.add_child(status)
	var combat := SlimeCombatComponent.new()
	combat.name = "Combat"
	combat.boss_jump_phase_stun_resistant = true
	actor.add_child(combat)
	status.set_movement_lock_resistance_check(Callable(combat, "movement_lock_is_resisted"))
	status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	_expect(status.record_for(&"freeze") != null, "boss-resisted actors still receive Freeze", failures)
	_expect(is_equal_approx(status.incoming_damage_multiplier_for(ElementCatalogScript.Element.FIRE), 1.25), "Freeze vulnerability applies during a boss resistance phase", failures)
	_expect(is_equal_approx(status.movement_speed_multiplier(), 1.0), "boss resistance prevents Freeze movement lock during its protected phase", failures)
	combat.boss_jump_phase_stun_resistant = false
	_expect(is_zero_approx(status.movement_speed_multiplier()), "Freeze movement lock resumes when boss resistance ends", failures)
	actor.queue_free()


func _watchdog() -> void:
	if not _finished:
		push_error("TEST_ABORTED: status mixture smoke timed out")
		quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("STATUS_MIXTURE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
