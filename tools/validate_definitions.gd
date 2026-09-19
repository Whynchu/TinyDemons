extends SceneTree

## Definition validator (Slice F, T2). Loads every authored definition resource
## and runs its validate() contract. Fails nonzero with a report when any
## definition is malformed, so CI preflight catches broken content before
## runtime. Run via tools/validate_definitions.ps1.

var _definition_jobs: Array[Dictionary] = []


func _initialize() -> void:
	_definition_jobs = [
		{"path": "res://resources/definitions/item_catalog.tres", "kind": "ItemCatalogData"},
		{"path": "res://resources/definitions/slime_variant_catalog.tres", "kind": "SlimeVariantCatalogData"},
		{"path": "res://resources/definitions/encounter_definition.tres", "kind": "EncounterDefinition"},
		{"path": "res://resources/definitions/room_definition.tres", "kind": "RoomDefinition"},
		{"path": "res://resources/definitions/dungeon_generation_policy.tres", "kind": "DungeonGenerationPolicy"},
		{"path": "res://resources/definitions/reward_definition.tres", "kind": "RewardDefinition"},
		{"path": "res://resources/definitions/dungeon_layout_run1.tres", "kind": "DungeonRunDefinition"},
		{"path": "res://resources/definitions/dungeon_layout_run2.tres", "kind": "DungeonRunDefinition"},
		{"path": "res://resources/definitions/puzzle_map_r3.tres", "kind": "PuzzlePlanData"},
		{"path": "res://resources/definitions/puzzle_map_r4.tres", "kind": "PuzzlePlanData"},
		{"path": "res://resources/definitions/puzzle_map_r5.tres", "kind": "PuzzlePlanData"},
		{"path": "res://resources/definitions/puzzle_map_r3_new.tres", "kind": "PuzzlePlanData"},
	]
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var loaded := 0
	for job in _definition_jobs:
		var path := String(job["path"])
		var resource := load(path)
		if resource == null:
			failures.append("DEFINITION_LOAD_FAILED: %s" % path)
			continue
		loaded += 1
		if resource.has_method("validate"):
			var problems := resource.call("validate") as Array
			for problem in problems:
				failures.append("%s: %s" % [path, str(problem)])
		else:
			failures.append_array(_structural_checks(path, resource, String(job["kind"])))
	print("DEFINITION_VALIDATOR loaded=%d/%d" % [loaded, _definition_jobs.size()])
	if failures.is_empty():
		print("DEFINITION_VALIDATOR_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _structural_checks(path: String, resource: Resource, kind: String) -> Array[String]:
	var problems: Array[String] = []
	match kind:
		"ItemCatalogData":
			if (resource.get("definitions") as Dictionary).is_empty():
				problems.append("%s: item definitions are empty" % path)
			if (resource.get("live_base_definitions") as Dictionary).is_empty():
				problems.append("%s: live base definitions are empty" % path)
		"SlimeVariantCatalogData":
			if (resource.get("definitions") as Dictionary).is_empty():
				problems.append("%s: slime variant definitions are empty" % path)
			var order := resource.get("order") as Array
			if order.is_empty():
				problems.append("%s: slime variant order is empty" % path)
		"DungeonRunDefinition":
			if (resource.get("rooms") as Array).is_empty():
				problems.append("%s: run has no rooms" % path)
			if (resource.get("layout_id") as StringName) == &"":
				problems.append("%s: run layout id is empty" % path)
		"PuzzlePlanData":
			if (resource.get("plan_id") as StringName) == &"":
				problems.append("%s: puzzle plan id is empty" % path)
			if (resource.get("markers") as Array).is_empty():
				problems.append("%s: puzzle plan has no markers" % path)
	return problems