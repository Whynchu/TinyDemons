extends SceneTree

const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")


class StatusTickTestRoot:
	extends GameplayState
	var damage_number_count := 0

	func _is_slime_dead(actor: Sprite2D) -> bool:
		var health := actor.get_node_or_null("Health") as HealthComponent
		return health == null or health.is_dead()

	func _spawn_damage_number(_actor: Sprite2D, _amount: float, _critical: bool = false, _element: int = 0, _immune: bool = false) -> void:
		damage_number_count += 1


var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var root_node := StatusTickTestRoot.new()
	var actor := Sprite2D.new()
	root_node.add_child(actor)
	var health := HealthComponent.new()
	health.maximum_health = 100.0
	actor.add_child(health)
	health.reset(100.0)
	var status := StatusComponent.new()
	status.health_component = health
	actor.add_child(status)
	status.apply_effect(ElementCatalogScript.status_effect_for_id(&"burn"), ElementCatalogScript.Element.FIRE)
	var controller := CombatRuntimeController.new()
	controller.tick_actor_statuses(root_node, actor, 1.01, false)
	_expect(is_equal_approx(health.current_health, 97.0), "Burn tick deals three percent of max health through the actor health owner", failures)
	_expect(root_node.damage_number_count == 1, "Burn tick uses the existing floating damage feedback", failures)
	_expect(is_equal_approx(root_node.hitstop_timer, 0.0), "status tick damage does not add hitstop", failures)
	_expect(status.stacks_for(&"burn") == 1, "status tick damage does not recursively proc another stack", failures)
	status.clear_all()
	status.apply_effect(ElementCatalogScript.status_effect_for_id(&"poison"), ElementCatalogScript.Element.SHADOW)
	controller.tick_actor_statuses(root_node, actor, 2.01, false)
	_expect(is_equal_approx(health.current_health, 95.0), "Poison deals two percent of max health every two seconds", failures)
	_expect(root_node.damage_number_count == 2, "Poison tick uses floating Shadow damage feedback", failures)
	status.clear_all()
	status.apply_effect(ElementCatalogScript.status_effect_for_id(&"wet"), ElementCatalogScript.Element.WATER)
	status.apply_effect(ElementCatalogScript.status_effect_for_id(&"shocked"), ElementCatalogScript.Element.ELECTRIC)
	controller.tick_actor_statuses(root_node, actor, 3.01, false)
	_expect(is_equal_approx(health.current_health, 93.0), "Shocked deals two percent of max health without Wet amplifying the tick", failures)
	_expect(root_node.damage_number_count == 3, "Shocked tick uses floating Electric damage feedback", failures)
	_expect(status.stacks_for(&"shocked") == 1, "Shocked tick does not recursively apply status", failures)
	_expect(is_equal_approx(root_node.hitstop_timer, 0.0), "Shocked tick damage does not add hitstop", failures)
	controller.free()
	root_node.free()
	_finish(failures)


func _watchdog() -> void:
	if not _finished:
		push_error("TEST_ABORTED: status combat smoke timed out")
		quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("STATUS_COMBAT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
