extends SceneTree

const CatalogScript = preload("res://scripts/slime_variant_catalog.gd")

## Slice B acceptance: definition-derived enemy runtime state round-trips
## through the persisted form (the stable variant id stored in room
## enemy_variants) and re-assembles to identical stats via EnemyFactory. Saves
## never store live nodes or stat dumps; they store the definition id, which the
## factory expands back to element + stats.

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []

	for variant: StringName in CatalogScript.variants():
		var definition := EnemyFactory.definition(variant)
		_expect(definition != null and definition.id == variant, "%s resolves to a definition" % variant, failures)

		var before_actor := EnemyFactory.assemble(definition)
		root.add_child(before_actor)
		var before_stats := before_actor.get_node_or_null("Stats") as StatsComponent
		_expect(before_stats != null, "%s factory actor carries stats" % variant, failures)

		# The persisted form is the stable variant id (mirrors how room state
		# stores enemy_variants as string ids, not live nodes or stat dumps).
		var persisted_id := StringName(String(before_actor.get_meta("enemy_definition_id", before_actor.variant)))
		before_actor.queue_free()

		var restored := EnemyFactory.assemble(EnemyFactory.definition(persisted_id))
		root.add_child(restored)
		var restored_stats := restored.get_node_or_null("Stats") as StatsComponent
		_expect(restored.variant == String(variant), "%s restored actor keeps the same variant" % variant, failures)
		_expect(restored.combat_element == definition.element, "%s restored actor keeps the same element" % variant, failures)
		_expect(String(restored.get_meta("damage_contract", "")) == String(definition.damage_contract), "%s restored actor keeps the damage contract" % variant, failures)
		if before_stats != null and restored_stats != null:
			_expect(restored_stats.vit == before_stats.vit and restored_stats.strength == before_stats.strength and restored_stats.def == before_stats.def and restored_stats.agi == before_stats.agi and restored_stats.intelligence == before_stats.intelligence and restored_stats.mnd == before_stats.mnd, "%s restored stats match the pre-save profile exactly" % variant, failures)
		restored.queue_free()

	_finished = true
	await process_frame
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: enemy definition save/load round-trip failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_DEFINITION_ROUNDTRIP_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
