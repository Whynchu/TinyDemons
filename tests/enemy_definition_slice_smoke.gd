extends SceneTree

## Slice B proof (Phase 0.60): an EnemyDefinition contract + EnemyFactory
## assemble a slime actor from authored content. A second variant ("crimson")
## is added through one catalog row and a definition — no GameplayState edit —
## and its factory output is genuinely distinct from the migrated variant.

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []

	var red_definition := EnemyFactory.definition(&"red")
	_expect(red_definition != null and red_definition.id == &"red", "red resolves to a typed EnemyDefinition", failures)
	_expect(red_definition.element == ElementCatalogScript.Element.FIRE, "red keeps its Fire element in the typed contract", failures)
	_expect(red_definition.damage_contract == &"elemental_slime", "red keeps its elemental damage contract in the typed contract", failures)

	var crimson_definition := EnemyFactory.definition(&"crimson")
	_expect(crimson_definition != null and crimson_definition.id == &"crimson", "crimson resolves to a typed EnemyDefinition", failures)
	_expect(EnemyFactory.is_variant(&"crimson"), "crimson is registered in the variant catalog", failures)
	_expect(crimson_definition.element == ElementCatalogScript.Element.FIRE, "crimson is a Fire-aspect variant", failures)
	_expect(crimson_definition.damage_contract == &"elemental_slime", "crimson uses the elemental slime damage contract", failures)
	_expect(crimson_definition.visual_source == "red", "crimson reuses the fire artwork sheet via its definition", failures)
	_expect(int(crimson_definition.base_stats.get("VIT", 0)) > int(red_definition.base_stats.get("VIT", 0)), "crimson is a tankier variant than red (higher VIT)", failures)
	_expect(int(crimson_definition.base_stats.get("AGI", 0)) < int(red_definition.base_stats.get("AGI", 0)), "crimson trades mobility for bulk (lower AGI)", failures)

	var recolor_sources: Array[StringName] = [&"grey", &"purple", &"yellow", &"orange", &"aquamarine"]
	for variant: StringName in recolor_sources:
		_expect(EnemyDefinition.from_variant(variant).visual_source == "green", "%s recolor-only variant shares the green base art sheet" % variant, failures)
	for variant: StringName in [&"red", &"blue", &"green"]:
		_expect(EnemyDefinition.from_variant(variant).visual_source == String(variant), "%s art-sheet variant names its own source" % variant, failures)

	var crimson_actor := EnemyFactory.assemble(crimson_definition)
	root.add_child(crimson_actor)
	_expect(crimson_actor.variant == "crimson", "factory assembles an actor with the crimson variant", failures)
	_expect(crimson_actor.combat_element == ElementCatalogScript.Element.FIRE, "factory sets the actor's combat element from the definition", failures)
	_expect(String(crimson_actor.get_meta("damage_contract", "")) == "elemental_slime", "factory sets the actor's damage contract from the definition", failures)
	_expect(String(crimson_actor.get_meta("enemy_definition_id", "")) == "crimson", "factory records the definition id on the actor", failures)
	_expect(bool(crimson_actor.get_meta("content_materialized", false)), "factory marks the actor as content-materialized", failures)
	_expect(crimson_actor.get_node_or_null("CollisionGuide") != null and crimson_actor.get_node_or_null("CollisionPolygon") != null and crimson_actor.get_node_or_null("BodyHitbox") != null, "factory owns regular enemy collision geometry", failures)
	_expect(crimson_actor.get_node_or_null("AttackGuideL") != null and crimson_actor.get_node_or_null("AttackGuideR") != null, "factory owns regular enemy attack geometry", failures)
	var crimson_stats := crimson_actor.get_node_or_null("Stats") as StatsComponent
	_expect(crimson_stats != null and crimson_stats.vit >= int(crimson_definition.base_stats.get("VIT", 0)), "factory applies the variant stats profile", failures)

	crimson_actor.queue_free()
	_finished = true
	await process_frame
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: enemy definition slice failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_DEFINITION_SLICE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
