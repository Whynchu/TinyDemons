extends SceneTree

const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")
const SpellFormCatalogScript = preload("res://scripts/content/spell_form_catalog.gd")
const SpellFormDefinitionScript = preload("res://scripts/content/spell_form_definition.gd")
const StatusTransmissionControllerScript = preload("res://scripts/runtime/controllers/status_transmission_controller.gd")
const StatusContactPairScript = preload("res://scripts/content/status_contact_pair.gd")
const GameplayStateScript = preload("res://scripts/runtime/state/gameplay_state.gd")
const SlimeRuntimeControllerScript = preload("res://scripts/runtime/controllers/slime_runtime_controller.gd")
const ActorCollisionSystemScript = preload("res://scripts/actors/actor_collision_system.gd")

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
	await process_frame
	(source.get_node("Status") as StatusComponent).apply_effect(burn, ElementCatalogScript.Element.FIRE)
	var chain_contacts: Array[StatusContactPair] = [
		_contact(source, middle),
		_contact(middle, end_actor),
	]
	controller.process_contacts(chain_contacts, 0.016, &"room_a", rng)
	var middle_status := middle.get_node("Status") as StatusComponent
	var end_status := end_actor.get_node("Status") as StatusComponent
	_expect(middle_status.stacks_for(&"burn") == 1, "eligible contact transmits one normal Burn application", failures)
	var received_burn := middle_status.record_for(&"burn")
	_expect(received_burn != null and received_burn.arrived_by_transmission, "received status records transmission provenance", failures)
	_expect(end_status.stacks_for(&"burn") == 0, "a newly received status cannot cascade through another contact in the same frame", failures)
	controller.process_contacts(chain_contacts, 0.016, &"room_a", rng)
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
	controller.process_contacts(zero_proc_pair, 0.016, &"room_a", rng)
	_expect(immune_status.stacks_for(&"burn") == 1, "contact transmission does not reroll the status proc chance", failures)
	controller.process_contacts(zero_proc_pair, 0.016, &"room_a", rng)
	_expect(immune_status.stacks_for(&"burn") == 1, "the pair cooldown prevents repeated contact application", failures)
	controller.process_contacts(zero_proc_pair, 0.016, &"room_b", rng)
	_expect(immune_status.stacks_for(&"burn") == 2, "changing rooms clears contact-pair cooldowns", failures)
	immune_status.clear_all()
	immune_status.status_immunities = [&"burn"]
	var immune_source := _new_actor("AuthoredImmuneSource")
	root.add_child(immune_source)
	(immune_source.get_node("Status") as StatusComponent).apply_effect(burn, ElementCatalogScript.Element.FIRE)
	var immune_pair: Array[StatusContactPair] = [_contact(immune_source, immune_target)]
	controller.process_contacts(immune_pair, 0.016, &"room_c", rng)
	_expect(immune_status.stacks_for(&"burn") == 0, "authored immunity rejects contact transmission", failures)

	var generation_source := _new_actor("GenerationSource")
	var generation_target := _new_actor("GenerationTarget")
	root.add_child(generation_source)
	root.add_child(generation_target)
	(generation_source.get_node("Status") as StatusComponent).apply_effect(burn, ElementCatalogScript.Element.FIRE)
	var generation_pair: Array[StatusContactPair] = [_contact(generation_source, generation_target)]
	controller.process_contacts(generation_pair, 0.016, &"room_d", rng)
	var generation_target_status := generation_target.get_node("Status") as StatusComponent
	_expect(generation_target_status.stacks_for(&"burn") == 1, "a fresh pair transmits before its cooldown", failures)
	generation_target_status.clear_all()
	generation_source.set_meta("status_spawn_generation", 1)
	controller.process_contacts(generation_pair, 0.016, &"room_d", rng)
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
	controller.process_contacts(suppressed_pair, 0.016, &"room_c", rng)
	var suppressed_target_status := suppressed_target.get_node("Status") as StatusComponent
	_expect(suppressed_target_status.stacks_for(&"burn") == 0, "suppressed innate affinity does not transmit", failures)
	_expect(suppressed_target_status.stacks_for(&"chill") == 0, "non-transmissible applied status does not transmit", failures)

	var shadow_source := _new_actor("ShadowSource")
	var shadow_target := _new_actor("ShadowTarget")
	root.add_child(shadow_source)
	root.add_child(shadow_target)
	var shadow_poison := ElementCatalogScript.status_effect_for_element(ElementCatalogScript.Element.SHADOW)
	_expect(shadow_poison != null and shadow_poison.id == &"poison", "Shadow resolves to its single Poison status", failures)
	_expect(shadow_poison != null and not shadow_poison.can_transmit_by_contact(), "Shadow Poison follows its authored non-transmissible contact policy", failures)
	var shadow_form := SpellFormCatalogScript.form_for_element(ElementCatalogScript.Element.SHADOW)
	_expect(int(shadow_form.get("projectile_shape")) == SpellFormDefinitionScript.ProjectileShape.HEX, "Shadow keeps the Hex projectile shape", failures)
	(shadow_source.get_node("Status") as StatusComponent).apply_effect(shadow_poison, ElementCatalogScript.Element.SHADOW)
	var shadow_pair: Array[StatusContactPair] = [_contact(shadow_source, shadow_target)]
	controller.process_contacts(shadow_pair, 0.016, &"room_d", rng)
	var shadow_target_status := shadow_target.get_node("Status") as StatusComponent
	_expect(shadow_target_status.stacks_for(&"poison") == 0, "Shadow Poison does not transmit through contact", failures)
	_assert_contact_snapshot_reuse(failures)

	for actor in [source, middle, end_actor, zero_proc_source, immune_target, immune_source, generation_source, generation_target, suppressed_source, suppressed_target, shadow_source, shadow_target]:
		actor.queue_free()
	await process_frame
	_finish(failures)


func _assert_contact_snapshot_reuse(failures: Array[String]) -> void:
	var gameplay := GameplayStateScript.new() as GameplayState
	gameplay.slime_runtime_controller = SlimeRuntimeControllerScript.new()
	var collision_system := ActorCollisionSystemScript.new() as ActorCollisionSystem
	var actor_a := Sprite2D.new()
	actor_a.name = "ContactReuseA"
	var actor_b := Sprite2D.new()
	actor_b.name = "ContactReuseB"
	actor_b.position = Vector2(1.0, 0.0)
	gameplay.slimes.append(actor_a)
	gameplay.slimes.append(actor_b)
	root.add_child(actor_a)
	root.add_child(actor_b)
	var actor_foot := Callable(gameplay, "_actor_foot")
	var snapshot := collision_system.capture_status_contact_pairs(gameplay.slimes, null, gameplay, actor_foot, Callable(), Callable())
	_expect(snapshot.size() == 1, "overlapping actors produce one status contact", failures)
	var pair_id := snapshot[0].get_instance_id() if not snapshot.is_empty() else 0
	var repeated_snapshot := collision_system.capture_status_contact_pairs(gameplay.slimes, null, gameplay, actor_foot, Callable(), Callable())
	_expect(repeated_snapshot.size() == 1, "repeated overlap remains in the contact snapshot", failures)
	if not repeated_snapshot.is_empty():
		_expect(repeated_snapshot[0].get_instance_id() == pair_id, "repeated contact reuses its pair object", failures)
	actor_b.position = Vector2(256.0, 0.0)
	var cleared_snapshot := collision_system.capture_status_contact_pairs(gameplay.slimes, null, gameplay, actor_foot, Callable(), Callable())
	_expect(cleared_snapshot.is_empty(), "separated actors clear the current contact snapshot", failures)
	_expect(snapshot.is_empty(), "the shared snapshot reference drops stale contacts", failures)
	actor_b.position = Vector2(1.0, 0.0)
	var restored_snapshot := collision_system.capture_status_contact_pairs(gameplay.slimes, null, gameplay, actor_foot, Callable(), Callable())
	_expect(restored_snapshot.size() == 1, "re-entering contact repopulates the snapshot", failures)
	if not restored_snapshot.is_empty():
		_expect(restored_snapshot[0].get_instance_id() == pair_id, "re-entering contact reuses the pooled pair", failures)
	actor_a.queue_free()
	actor_b.queue_free()
	collision_system.free()
	gameplay.slime_runtime_controller.free()
	gameplay.free()


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
