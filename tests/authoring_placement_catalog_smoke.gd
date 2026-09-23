extends SceneTree

const CATALOG_SCRIPT := preload("res://scripts/authoring_placement_catalog.gd")
const EXPECTED_IDS := [
	&"hub_actor_layer",
	&"hub_characters",
	&"hub_chest",
	&"hub_environment",
	&"hub_npc",
	&"hub_player",
	&"hub_props",
	&"hub_rest_fire",
]


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for authoring catalog discovery", failures)
	if packed == null:
		_finish(failures)
		return
	var main := packed.instantiate()
	var entries: Array[Dictionary] = CATALOG_SCRIPT.scan(main)
	_expect(entries.size() == EXPECTED_IDS.size(), "catalog discovers every Hub placement root exactly once", failures)
	var discovered: Array[StringName] = []
	for entry in entries:
		discovered.append(entry["placement_id"] as StringName)
		_expect(not String(entry["path_text"]).is_empty(), "catalog records a scene path for every placement", failures)
		_expect(entry["node"] is Node, "catalog retains the placement node for editor selection", failures)
	discovered.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	var expected := EXPECTED_IDS.duplicate()
	expected.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	_expect(discovered == expected, "catalog exposes stable placement IDs", failures)
	_expect(CATALOG_SCRIPT.duplicate_ids(entries).is_empty(), "Hub placement IDs are unique", failures)
	_expect(CATALOG_SCRIPT.validate(entries).is_empty(), "Hub placement metadata validates", failures)
	var duplicate_entries := entries.duplicate()
	duplicate_entries.append(entries[0])
	_expect(not CATALOG_SCRIPT.validate(duplicate_entries).is_empty(), "catalog reports duplicate placement IDs", failures)
	var invalid_entry := entries[0].duplicate()
	invalid_entry["placement_id"] = &"Bad-ID"
	invalid_entry["authoring_layer"] = "Unsupported"
	var invalid_entries := entries.duplicate()
	invalid_entries[0] = invalid_entry
	var invalid_errors: Array[String] = CATALOG_SCRIPT.validate(invalid_entries)
	_expect(invalid_errors.size() >= 2, "catalog reports malformed IDs and unsupported layers", failures)
	_expect(CATALOG_SCRIPT.next_stable_id(entries, &"hub_player") == &"hub_player_2", "catalog allocates the next stable ID", failures)
	var empty_placement := CATALOG_SCRIPT.create_empty_placement(&"test_placement", "Props")
	_expect(CATALOG_SCRIPT.is_placement_root(empty_placement), "catalog creates a PlacementRoot2D empty placement", failures)
	_expect(empty_placement.get("placement_id") == &"test_placement", "empty placement receives its stable ID", failures)
	_expect(String(empty_placement.get("authoring_layer")) == "Props", "empty placement receives its authoring layer", failures)
	empty_placement.free()
	var player_prefab := CATALOG_SCRIPT.instantiate_prefab("res://scenes/player_placement.tscn")
	_expect(player_prefab != null, "catalog instantiates the PlayerPlacement prefab", failures)
	_expect(CATALOG_SCRIPT.is_placement_root(player_prefab), "PlayerPlacement prefab exposes a placement root", failures)
	if player_prefab != null:
		player_prefab.free()
	var props_source := main.get_node("Actors/Props") as Node
	var props_copy := props_source.duplicate()
	props_copy.name = "PropsCopy"
	var used_entries: Array[Dictionary] = CATALOG_SCRIPT.scan(main)
	_expect(CATALOG_SCRIPT.rekey_placement_tree(props_copy, used_entries), "catalog rekeys every placement in a duplicated layer", failures)
	main.get_node("Actors").add_child(props_copy)
	_expect(CATALOG_SCRIPT.validate(CATALOG_SCRIPT.scan(main)).is_empty(), "duplicated layers keep all placement IDs unique", failures)
	main.get_node("Actors").remove_child(props_copy)
	props_copy.free()
	main.free()
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("AUTHORING_PLACEMENT_CATALOG_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
