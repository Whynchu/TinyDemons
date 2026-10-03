extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const StatusTransmissionControllerScript = preload("res://scripts/status_transmission_controller.gd")
const StatusContactPairScript = preload("res://scripts/status_contact_pair.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 45231
	var burn := ElementCatalogScript.status_effect_for_id(&"burn").duplicate(true) as StatusEffectDefinition
	burn.proc_chance = 1.0
	var controller := StatusTransmissionControllerScript.new() as StatusTransmissionController
	var source := _new_actor("Source")
	var middle := _new_actor("Middle")
	var end_actor := _new_actor("End")
	root.add_child(source)
	root.add_child(middle)
	root.add_child(end_actor)
	(source.get_node("Status") as StatusComponent).apply_effect(burn, ElementCatalogScript.Element.FIRE)
	var chain_contacts: Array[StatusContactPair] = [
		_contact(source, middle),
		_contact(middle, end_actor),
	]
	controller.process_contacts(chain_contacts, 0.016, &"room_a", true, rng)
	var middle_status := middle.get_node("Status") as StatusComponent
	var end_status := end_actor.get_node("Status") as StatusComponent
	_expect(middle_status.stacks_for(&"burn") == 1, "eligible contact transmits one normal Burn application", failures)
	var received_burn := middle_status.record_for(&"burn")
	_expect(received_burn != null and received_burn.arrived_by_transmission, "received status records transmission provenance", failures)
	_expect(end_status.stacks_for(&"burn") == 0, "a newly received status cannot cascade through another contact in the same frame", failures)
	controller.process_contacts(chain_contacts, 0.016, &"room_a", true, rng)
	_expect(middle_status.stacks_for(&"burn") == 1, "the unordered pair cooldown prevents another application", failures)

	var zero_proc_source := _new_actor("ZeroProcSource")
	var immune_target := _new_actor("ImmuneTarget")
	root.add_child(zero_proc_source)
	root.add_child(immune_target)
	var zero_proc_burn := burn.duplicate(true) as StatusEffectDefinition
	zero_proc_burn.proc_chance = 0.0
	(zero_proc_source.get_node("Status") as StatusComponent).apply_effect(zero_proc_burn, ElementCatalogScript.Element.FIRE)
	var immune_status := immune_target.get_node("Status") as StatusComponent
	immune_status.status_immunities.clear()
	var zero_proc_pair: Array[StatusContactPair] = [_contact(zero_proc_source, immune_target)]
	controller.process_contacts(zero_proc_pair, 0.016, &"room_a", true, rng)
	_expect(immune_status.stacks_for(&"burn") == 1, "contact transmission does not reroll the status proc chance", failures)
	controller.process_contacts(zero_proc_pair, 0.016, &"room_a", true, rng)
	_expect(immune_status.stacks_for(&"burn") == 1, "the pair cooldown prevents repeated contact application", failures)
	controller.process_contacts(zero_proc_pair, 0.016, &"room_b", true, rng)
	_expect(immune_status.stacks_for(&"burn") == 2, "changing rooms clears contact-pair cooldowns", failures)
	immune_status.clear_all()
	immune_status.status_immunities = [&"burn"]
	var immune_source := _new_actor("AuthoredImmuneSource")
	root.add_child(immune_source)
	(immune_source.get_node("Status") as StatusComponent).apply_effect(burn, ElementCatalogScript.Element.FIRE)
	var immune_pair: Array[StatusContactPair] = [_contact(immune_source, immune_target)]
	controller.process_contacts(immune_pair, 0.016, &"room_c", true, rng)
	_expect(immune_status.stacks_for(&"burn") == 0, "authored immunity rejects contact transmission", failures)

	var generation_source := _new_actor("GenerationSource")
	var generation_target := _new_actor("GenerationTarget")
	root.add_child(generation_source)
	root.add_child(generation_target)
	(generation_source.get_node("Status") as StatusComponent).apply_effect(burn, ElementCatalogScript.Element.FIRE)
	var generation_pair: Array[StatusContactPair] = [_contact(generation_source, generation_target)]
	controller.process_contacts(generation_pair, 0.016, &"room_d", true, rng)
	var generation_target_status := generation_target.get_node("Status") as StatusComponent
	_expect(generation_target_status.stacks_for(&"burn") == 1, "a fresh pair transmits before its cooldown", failures)
	generation_target_status.clear_all()
	generation_source.set_meta("status_spawn_generation", 1)
	controller.process_contacts(generation_pair, 0.016, &"room_d", true, rng)
	_expect(generation_target_status.stacks_for(&"burn") == 1, "a reused actor generation does not inherit the previous pair cooldown", failures)

	var suppressed_source := _new_actor("SuppressedSource")
	var suppressed_target := _new_actor("SuppressedTarget")
	root.add_child(suppressed_source)
	root.add_child(suppressed_target)
	var suppressed_status := suppressed_source.get_node("Status") as StatusComponent
	suppressed_status.configure_innate(&"burn")
	var nontransmissible_chill := ElementCatalogScript.status_effect_for_id(&"chill").duplicate(true) as StatusEffectDefinition
	nontransmissible_chill.transmissible = false
	suppressed_status.apply_effect(nontransmissible_chill, ElementCatalogScript.Element.ICE)
	var suppressed_pair: Array[StatusContactPair] = [_contact(suppressed_source, suppressed_target)]
	controller.process_contacts(suppressed_pair, 0.016, &"room_c", true, rng)
	var suppressed_target_status := suppressed_target.get_node("Status") as StatusComponent
	_expect(suppressed_target_status.stacks_for(&"burn") == 0, "suppressed innate affinity does not transmit", failures)
	_expect(suppressed_target_status.stacks_for(&"chill") == 0, "non-transmissible applied status does not transmit", failures)

	var hex_source := _new_actor("HexSource")
	var hex_target := _new_actor("HexTarget")
	root.add_child(hex_source)
	root.add_child(hex_target)
	(hex_source.get_node("Status") as StatusComponent).apply_damage_mark(1.0, 1.25, ElementCatalogScript.Element.SHADOW)
	var hex_pair: Array[StatusContactPair] = [_contact(hex_source, hex_target)]
	controller.process_contacts(hex_pair, 0.016, &"room_d", true, rng)
	var hex_target_status := hex_target.get_node("Status") as StatusComponent
	_expect(hex_target_status.stacks_for(&"hex_mark") == 0 and is_equal_approx(hex_target_status.damage_taken_multiplier(), 1.0), "auxiliary Hex damage marks do not transmit", failures)

	for actor in [source, middle, end_actor, zero_proc_source, immune_target, immune_source, generation_source, generation_target, suppressed_source, suppressed_target, hex_source, hex_target]:
		actor.queue_free()
	await process_frame
	_finish(failures)


func _new_actor(actor_name: String) -> Sprite2D:
	var actor := Sprite2D.new()
	actor.name = actor_name
	var status := StatusComponent.new()
	status.name = "Status"
	actor.add_child(status)
	return actor


func _contact(first: Sprite2D, second: Sprite2D) -> StatusContactPair:
	var pair := StatusContactPairScript.new() as StatusContactPair
	pair.configure(first, second)
	return pair


func _watchdog() -> void:
	await create_timer(45.0).timeout
	if not _finished:
		push_error("TEST_ABORTED: status transmission smoke timed out")
		quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("STATUS_TRANSMISSION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
