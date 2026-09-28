extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")


class StatusTickTestRoot:
	extends Node
	var damage_number_count := 0
	var hitstop_timer := 0.0

	func _is_slime_dead(actor: Sprite2D) -> bool:
		var health := actor.get_node_or_null("Health") as HealthComponent
		return health == null or health.is_dead()

	func _spawn_damage_number(_actor: Sprite2D, _amount: float, _critical: bool, _element: int, _immune: bool) -> void:
		damage_number_count += 1


var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var root_node := StatusTickTestRoot.new()
	root.add_child(root_node)
	var actor := Sprite2D.new()
	root_node.add_child(actor)
	var health := HealthComponent.new()
	health.maximum_health = 10.0
	actor.add_child(health)
	health.reset(10.0)
	var status := StatusComponent.new()
	actor.add_child(status)
	status.apply_effect(ElementCatalogScript.status_effect_for_id(&"burn"), ElementCatalogScript.Element.FIRE)
	var controller := CombatRuntimeController.new()
	controller.tick_actor_statuses(root_node, actor, 1.01, false)
	_expect(is_equal_approx(health.current_health, 9.0), "Burn tick damages through the actor health owner", failures)
	_expect(root_node.damage_number_count == 1, "Burn tick uses the existing floating damage feedback", failures)
	_expect(is_equal_approx(root_node.hitstop_timer, 0.0), "status tick damage does not add hitstop", failures)
	_expect(status.stacks_for(&"burn") == 1, "status tick damage does not recursively proc another stack", failures)
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
