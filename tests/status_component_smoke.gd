extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var burn := ElementCatalogScript.status_effect_for_id(&"burn")
	var slow := ElementCatalogScript.status_effect_for_id(&"slow")
	_expect(ElementCatalogScript.DATA.validate().is_empty(), "element catalog validates its registered statuses", failures)
	_expect(burn != null and slow != null, "catalog resolves Burn and Slow by stable id", failures)
	if burn == null or slow == null:
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

	status.apply_effect(slow, ElementCatalogScript.Element.ICE)
	status.apply_effect(slow, ElementCatalogScript.Element.ICE)
	status.apply_effect(slow, ElementCatalogScript.Element.ICE)
	_expect(is_equal_approx(status.movement_speed_multiplier(), slow.movement_multiplier_floor), "stacked Slow respects its movement floor", failures)
	status.status_immunities = [&"slow"]
	_expect(not status.apply_effect(slow, ElementCatalogScript.Element.ICE), "actor immunity rejects the matching status", failures)
	status.clear_all()
	_expect(is_equal_approx(status.movement_speed_multiplier(), 1.0), "clearing statuses restores normal movement", failures)
	status.free()
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
