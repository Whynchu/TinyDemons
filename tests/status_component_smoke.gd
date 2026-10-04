extends SceneTree

const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var burn := ElementCatalogScript.status_effect_for_id(&"burn")
	var chill := ElementCatalogScript.status_effect_for_id(&"chill")
	var shocked := ElementCatalogScript.status_effect_for_id(&"shocked")
	var wet := ElementCatalogScript.status_effect_for_id(&"wet")
	_expect(ElementCatalogScript.DATA.validate().is_empty(), "element catalog validates its registered statuses", failures)
	_expect(burn != null and chill != null and shocked != null and wet != null, "catalog resolves Burn, Chill, Shocked, and Wet by stable id", failures)
	if burn == null or chill == null or shocked == null or wet == null:
		_finish(failures)
		return

	var status := StatusComponent.new()
	_expect(status.apply_effect(burn, ElementCatalogScript.Element.FIRE), "first Burn applies", failures)
	status.advance(0.4)
	_expect(status.apply_effect(burn, ElementCatalogScript.Element.FIRE), "reapplying Burn succeeds", failures)
	_expect(status.stacks_for(&"burn") == 2, "reapplication adds one stack", failures)
	_expect(status.advance(0.59).is_empty(), "reapplication preserves the in-progress tick phase", failures)
	var tick_results := status.advance(0.02)
	_expect(tick_results.size() == 1, "Burn ticks once at its preserved phase", failures)
	if tick_results.size() == 1:
		_expect(tick_results[0].kind == StatusTickResult.Kind.DAMAGE and is_equal_approx(tick_results[0].amount, 2.0), "Burn tick magnitude scales with active stacks", failures)
	status.apply_effect(burn, ElementCatalogScript.Element.FIRE)
	status.apply_effect(burn, ElementCatalogScript.Element.FIRE)
	_expect(status.stacks_for(&"burn") == burn.maximum_stacks, "reapplication respects the stack cap", failures)
	status.clear_all()
	status.apply_effect(burn, ElementCatalogScript.Element.FIRE)
	var expiry_ticks := status.advance(2.49)
	_expect(expiry_ticks.size() == 2, "DoT can tick only during the active duration", failures)
	_expect(status.active_definitions().size() == 1, "status remains active until its duration expires", failures)
	status.advance(0.02)
	_expect(status.active_definitions().is_empty(), "status expires cleanly", failures)

	status.apply_effect(chill, ElementCatalogScript.Element.ICE)
	status.apply_effect(chill, ElementCatalogScript.Element.ICE)
	status.apply_effect(chill, ElementCatalogScript.Element.ICE)
	_expect(is_equal_approx(status.movement_speed_multiplier(), chill.movement_multiplier_floor), "stacked Chill respects its movement floor", failures)
	_expect(is_equal_approx(status.attack_speed_multiplier(), chill.movement_multiplier_floor), "Chill slows attack timing as well as movement", failures)
	status.status_immunities = [&"chill"]
	_expect(not status.apply_effect(chill, ElementCatalogScript.Element.ICE), "actor immunity rejects the matching status", failures)
	status.clear_all()
	_expect(is_equal_approx(status.movement_speed_multiplier(), 1.0), "clearing statuses restores normal movement", failures)
	status.free()

	var wet_status := StatusComponent.new()
	wet_status.apply_effect(wet, ElementCatalogScript.Element.WATER)
	_expect(is_equal_approx(wet_status.incoming_damage_multiplier_for(ElementCatalogScript.Element.ELECTRIC), 1.35), "one applied Wet stack amplifies Electric damage", failures)
	wet_status.apply_effect(wet, ElementCatalogScript.Element.WATER)
	_expect(is_equal_approx(wet_status.incoming_damage_multiplier_for(ElementCatalogScript.Element.ELECTRIC), 1.7), "two Wet stacks add their configured Electric damage amplification", failures)
	wet_status.free()

	var shocked_without_wet := StatusComponent.new()
	shocked_without_wet.apply_effect(shocked, ElementCatalogScript.Element.ELECTRIC)
	var dry_pulses := shocked_without_wet.advance(0.68)
	_expect(dry_pulses.size() == 1, "Shocked uses its normal cadence without Wet", failures)
	shocked_without_wet.free()

	var conductive_target := StatusComponent.new()
	conductive_target.apply_effect(wet, ElementCatalogScript.Element.WATER)
	conductive_target.apply_effect(shocked, ElementCatalogScript.Element.ELECTRIC)
	var conductive_pulses := conductive_target.advance(0.68)
	_expect(conductive_pulses.size() == 2, "Wet accelerates Shocked cadence", failures)
	conductive_target.free()

	var changing_conductivity := StatusComponent.new()
	changing_conductivity.apply_effect(shocked, ElementCatalogScript.Element.ELECTRIC)
	_expect(changing_conductivity.advance(0.5).size() == 1, "Shocked applies its immediate interruption pulse", failures)
	var short_wet := wet.duplicate(true) as StatusEffectDefinition
	short_wet.duration = 0.1
	changing_conductivity.apply_effect(short_wet, ElementCatalogScript.Element.WATER)
	_expect(changing_conductivity.advance(0.32).is_empty(), "Wet expiry rescales a pending Shocked pulse without an early stun", failures)
	_expect(changing_conductivity.advance(0.03).size() == 1, "Shocked uses the dry cadence again after Wet expires", failures)
	changing_conductivity.free()

	var burning_target := StatusComponent.new()
	for _stack in burn.maximum_stacks:
		burning_target.apply_effect(burn, ElementCatalogScript.Element.FIRE)
	_expect(burning_target.stacks_for(&"burn") == burn.maximum_stacks, "Burn reaches its configured stack cap before Wet", failures)
	burning_target.apply_effect(wet, ElementCatalogScript.Element.WATER)
	_expect(burning_target.stacks_for(&"burn") == 0, "Wet strips its configured applied Burn stacks", failures)
	_expect(burning_target.stacks_for(&"wet") == 1, "Wet remains applied after extinguishing Burn", failures)
	burning_target.free()

	var innate_fire := StatusComponent.new()
	innate_fire.configure_innate(&"burn")
	var innate_burn_pulses := innate_fire.advance(10.0)
	_expect(innate_fire.stacks_for(&"burn") == 1 and innate_burn_pulses.is_empty(), "innate Burn persists without ticking damage", failures)
	_expect(not innate_fire.apply_effect(burn, ElementCatalogScript.Element.FIRE), "an actor rejects application of its own innate status", failures)
	innate_fire.apply_effect(chill, ElementCatalogScript.Element.ICE)
	innate_fire.apply_effect(wet, ElementCatalogScript.Element.WATER)
	_expect(innate_fire.is_suppressed(&"burn"), "applied ailments suppress innate affinity", failures)
	innate_fire.advance(chill.duration + 0.01)
	_expect(innate_fire.is_suppressed(&"burn") and innate_fire.stacks_for(&"burn") == 1, "one expired ailment does not reveal affinity while another remains", failures)
	innate_fire.advance(wet.duration - chill.duration + 0.01)
	_expect(not innate_fire.is_suppressed(&"burn") and innate_fire.stacks_for(&"burn") == 1, "innate affinity returns after every suppressing ailment expires", failures)
	innate_fire.clear_all()
	_expect(innate_fire.record_for(&"burn") == null and innate_fire.innate_status_id == &"burn", "death cleanup clears the live aura but retains its configured affinity", failures)
	innate_fire.reset_for_spawn()
	_expect(innate_fire.record_for(&"burn") != null, "spawn reset restores affinity for a reused enemy slot", failures)
	innate_fire.free()

	var immune_innate := StatusComponent.new()
	immune_innate.status_immunities = [&"burn"]
	immune_innate.configure_innate(&"burn")
	_expect(immune_innate.record_for(&"burn") == null, "authored immunity prevents installation of the matching innate status", failures)
	immune_innate.free()

	var innate_water := StatusComponent.new()
	innate_water.configure_innate(&"wet")
	_expect(is_equal_approx(innate_water.incoming_damage_multiplier_for(ElementCatalogScript.Element.ELECTRIC), 1.0), "innate Wet does not grant its owner conductivity", failures)
	innate_water.free()
	_finish(failures)


func _watchdog() -> void:
	if not _finished:
		push_error("TEST_ABORTED: status component smoke timed out")
		quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("STATUS_COMPONENT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
