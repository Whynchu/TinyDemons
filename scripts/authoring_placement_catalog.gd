extends RefCounted
class_name AuthoringPlacementCatalog

## Editor/runtime-neutral discovery for authored placement roots.
##
## The editor dock consumes this catalog, while focused smoke tests can inspect
## the same scene contract without loading EditorPlugin APIs. Keeping discovery
## here prevents the dock from becoming a second source of authoring truth.

const PLACEMENT_ROOT_SCRIPT := preload("res://scripts/placement_root_2d.gd")
const VALID_LAYERS: Array[String] = ["Environment", "Props", "Collectables", "Actors", "Effects", "Guides"]


static func scan(root: Node) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if root == null:
		return entries
	_collect(root, root, entries)
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["sort_key"]) < String(right["sort_key"])
	)
	return entries


static func is_placement_root(node: Node) -> bool:
	return node != null and node.get_script() == PLACEMENT_ROOT_SCRIPT


static func duplicate_ids(entries: Array[Dictionary]) -> Array[StringName]:
	var counts: Dictionary = {}
	for entry in entries:
		var placement_id := entry["placement_id"] as StringName
		if placement_id == &"":
			continue
		counts[placement_id] = int(counts.get(placement_id, 0)) + 1
	var duplicates: Array[StringName] = []
	for placement_id in counts:
		if int(counts[placement_id]) > 1:
			duplicates.append(placement_id as StringName)
	duplicates.sort_custom(func(left: StringName, right: StringName) -> bool:
		return String(left) < String(right)
	)
	return duplicates


static func validate(entries: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var duplicates := duplicate_ids(entries)
	for placement_id in duplicates:
		errors.append("duplicate placement_id '%s'" % String(placement_id))
	for entry in entries:
		var placement_id := entry["placement_id"] as StringName
		var id_text := String(placement_id)
		var path_text := String(entry["path_text"])
		if placement_id == &"":
			errors.append("%s is missing placement_id" % path_text)
		elif not _is_stable_id(id_text):
			errors.append("%s has invalid placement_id '%s'" % [path_text, id_text])
		var authoring_layer := String(entry["authoring_layer"])
		if authoring_layer not in VALID_LAYERS:
			errors.append("%s uses unsupported authoring layer '%s'" % [path_text, authoring_layer])
	return errors


static func next_stable_id(entries: Array[Dictionary], base_id: StringName) -> StringName:
	var used: Dictionary = {}
	for entry in entries:
		used[entry["placement_id"] as StringName] = true
	var base_text := String(base_id)
	if base_text.is_empty():
		base_text = "placement"
	var candidate := base_text
	var suffix := 2
	while used.has(StringName(candidate)):
		candidate = "%s_%d" % [base_text, suffix]
		suffix += 1
	return StringName(candidate)


static func create_empty_placement(placement_id: StringName, authoring_layer: String) -> Node2D:
	var placement := Node2D.new()
	placement.name = "Placement"
	placement.set_script(PLACEMENT_ROOT_SCRIPT)
	placement.set("placement_id", placement_id)
	placement.set("authoring_layer", authoring_layer if authoring_layer in VALID_LAYERS else "Actors")
	placement.set("anchor_mode", "Foot")
	return placement


static func instantiate_prefab(scene_path: String) -> Node:
	if scene_path.is_empty():
		return null
	var packed := ResourceLoader.load(scene_path) as PackedScene
	return packed.instantiate() if packed != null else null


static func configure_placement(node: Node, placement_id: StringName, authoring_layer: String) -> bool:
	if not is_placement_root(node):
		return false
	node.set("placement_id", placement_id)
	node.set("authoring_layer", authoring_layer if authoring_layer in VALID_LAYERS else "Actors")
	return true


static func rekey_placement_tree(root: Node, used_entries: Array[Dictionary]) -> bool:
	## Assign fresh IDs to every placement root in a newly-created subtree.
	##
	## Layer roots can contain child placement roots (for example Props contains
	## both the fire and chest). Re-keying only the selected root would make the
	## duplicated subtree invalid as soon as it is added to the scene.
	if root == null:
		return false
	var placement_entries := scan(root)
	if placement_entries.is_empty():
		return false
	for entry in placement_entries:
		var placement := entry["node"] as Node
		var source_id := entry["placement_id"] as StringName
		var new_id := next_stable_id(used_entries, source_id)
		if not configure_placement(placement, new_id, String(entry["authoring_layer"])):
			return false
		used_entries.append({"placement_id": new_id})
	return true


static func _collect(root: Node, node: Node, entries: Array[Dictionary]) -> void:
	if node.get_script() == PLACEMENT_ROOT_SCRIPT:
		var placement_id := node.get("placement_id") as StringName
		var authoring_layer := String(node.get("authoring_layer"))
		var path := root.get_path_to(node)
		var path_text := String(path)
		entries.append({
			"node": node,
			"node_name": String(node.name),
			"path": path,
			"path_text": path_text,
			"placement_id": placement_id,
			"authoring_layer": authoring_layer,
			"sort_key": "%s|%s|%s" % [authoring_layer, String(placement_id), path_text],
		})
	for child in node.get_children():
		_collect(root, child as Node, entries)


static func _is_stable_id(value: String) -> bool:
	if value.is_empty():
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower_alpha := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if index == 0 and not is_lower_alpha:
			return false
		if index > 0 and not (is_lower_alpha or is_digit or code == 95):
			return false
	return true
