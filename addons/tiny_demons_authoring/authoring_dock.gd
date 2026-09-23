@tool
extends VBoxContainer

const AuthoringPlacementCatalogScript := preload("res://scripts/authoring_placement_catalog.gd")
const HUB_PREVIEW_SCENE := "res://scenes/hub_world_preview.tscn"

var _plugin: EditorPlugin = null
var _scene_root: Node = null
var _filter: LineEdit = null
var _tree: Tree = null
var _status: Label = null
var _prefab_picker: OptionButton = null
var _selected_path: NodePath = NodePath("")


func configure(plugin: EditorPlugin) -> void:
	_plugin = plugin
	name = "TinyDemonsAuthoringDock"
	custom_minimum_size = Vector2(300.0, 0.0)
	_build_ui()


func set_scene_root(scene_root: Node) -> void:
	_scene_root = scene_root
	_refresh()


func _build_ui() -> void:
	if _tree != null:
		return
	var title := Label.new()
	title.text = "Tiny Demons Authoring"
	title.tooltip_text = "Browse authored placement roots in the open scene."
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)

	var actions := HBoxContainer.new()
	var open_hub := Button.new()
	open_hub.text = "Open Hub Preview"
	open_hub.tooltip_text = "Open the animated, editor-safe Hub design view."
	open_hub.pressed.connect(_open_hub_preview)
	actions.add_child(open_hub)
	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh)
	actions.add_child(refresh_button)
	add_child(actions)

	var prefab_row := HBoxContainer.new()
	var prefab_label := Label.new()
	prefab_label.text = "Create:"
	prefab_row.add_child(prefab_label)
	_prefab_picker = OptionButton.new()
	_prefab_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prefab_picker.add_item("Empty Placement")
	_prefab_picker.set_item_metadata(0, "")
	_prefab_picker.add_item("Player Placement Prefab")
	_prefab_picker.set_item_metadata(1, "res://scenes/player_placement.tscn")
	prefab_row.add_child(_prefab_picker)
	var create_button := Button.new()
	create_button.text = "Create"
	create_button.tooltip_text = "Create the selected prefab under the selected authoring layer."
	create_button.pressed.connect(_create_placement)
	prefab_row.add_child(create_button)
	add_child(prefab_row)

	var edit_actions := HBoxContainer.new()
	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.tooltip_text = "Duplicate the selected placement with a new stable ID."
	duplicate_button.pressed.connect(_duplicate_placement)
	edit_actions.add_child(duplicate_button)
	var validate_button := Button.new()
	validate_button.text = "Validate"
	validate_button.tooltip_text = "Check placement IDs and authoring categories in the open scene."
	validate_button.pressed.connect(_validate_current_scene)
	edit_actions.add_child(validate_button)
	add_child(edit_actions)

	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter ID, layer, node, or path"
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_value: String) -> void: _refresh())
	add_child(_filter)

	_tree = Tree.new()
	_tree.columns = 2
	_tree.hide_root = true
	_tree.set_column_titles_visible(true)
	_tree.set_column_title(0, "Placement")
	_tree.set_column_title(1, "Scene Path")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, true)
	_tree.item_activated.connect(_on_item_activated)
	_tree.cell_selected.connect(_on_cell_selected)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tree)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Open an authored scene to browse placement roots."
	add_child(_status)


func _refresh() -> void:
	if _tree == null:
		return
	_tree.clear()
	if _scene_root == null:
		_selected_path = NodePath("")
		_status.text = "Open an authored scene to browse placement roots."
		return
	if not _selected_path.is_empty() and _scene_root.get_node_or_null(_selected_path) == null:
		_selected_path = NodePath("")

	var entries: Array[Dictionary] = AuthoringPlacementCatalogScript.scan(_scene_root)
	var filter_text := _filter.text.strip_edges().to_lower() if _filter != null else ""
	var groups: Dictionary = {}
	for entry in entries:
		var searchable := "%s %s %s %s" % [
			entry["authoring_layer"], entry["placement_id"], entry["node_name"], entry["path_text"]
		]
		if not filter_text.is_empty() and not searchable.to_lower().contains(filter_text):
			continue
		var layer := String(entry["authoring_layer"])
		if not groups.has(layer):
			groups[layer] = []
		(groups[layer] as Array).append(entry)

	var visible_count := 0
	var root_item := _tree.create_item()
	var layers: Array[String] = []
	for layer in groups.keys():
		layers.append(String(layer))
	layers.sort()
	for layer in layers:
		var layer_entries := groups[layer] as Array
		var layer_item := root_item.create_child()
		layer_item.set_text(0, String(layer))
		layer_item.set_text(1, "%d placement(s)" % layer_entries.size())
		layer_item.set_selectable(0, false)
		layer_item.set_selectable(1, false)
		for entry in layer_entries:
			var item := layer_item.create_child()
			var id_text := String(entry["placement_id"])
			if id_text.is_empty():
				id_text = "<missing id>"
			item.set_text(0, "%s  [%s]" % [entry["node_name"], id_text])
			item.set_text(1, entry["path_text"])
			item.set_metadata(0, entry["path"])
			visible_count += 1

	var duplicates: Array[StringName] = AuthoringPlacementCatalogScript.duplicate_ids(entries)
	var duplicate_note := ""
	if not duplicates.is_empty():
		duplicate_note = " Duplicate IDs: %s." % ", ".join(duplicates.map(func(value: StringName) -> String: return String(value)))
	var validation_errors: Array[String] = AuthoringPlacementCatalogScript.validate(entries)
	var validation_note := " Valid."
	if not validation_errors.is_empty():
		validation_note = " Invalid: %s." % validation_errors[0]
	_status.text = "%d/%d placement root(s) shown.%s%s" % [visible_count, entries.size(), duplicate_note, validation_note]


func _on_item_activated(item: TreeItem, _column: int) -> void:
	_select_item(item)


func _on_cell_selected(_column: int) -> void:
	var item := _tree.get_selected()
	if item != null:
		_select_item(item)


func _select_item(item: TreeItem) -> void:
	if _scene_root == null or item == null:
		return
	var path_value: Variant = item.get_metadata(0)
	if not path_value is NodePath:
		return
	var node := _scene_root.get_node_or_null(path_value as NodePath)
	if node == null or _plugin == null:
		return
	_selected_path = path_value as NodePath
	var selection := _plugin.get_editor_interface().get_selection()
	selection.clear()
	selection.add_node(node)
	_plugin.get_editor_interface().edit_node(node)
	_status.text = "Selected %s (%s)." % [node.name, String(path_value)]


func _selected_node() -> Node:
	if _scene_root == null or _selected_path.is_empty():
		return null
	return _scene_root.get_node_or_null(_selected_path)


func _create_placement() -> void:
	if _scene_root == null or _plugin == null:
		return
	var entries: Array[Dictionary] = AuthoringPlacementCatalogScript.scan(_scene_root)
	var selected := _selected_node()
	var parent := _authoring_parent_for(selected)
	if parent == null:
		_status.text = "Create needs an open scene or selected authoring layer."
		return
	var prefab_path := ""
	if _prefab_picker != null and _prefab_picker.selected >= 0:
		prefab_path = String(_prefab_picker.get_item_metadata(_prefab_picker.selected))
	var placement := AuthoringPlacementCatalogScript.instantiate_prefab(prefab_path)
	var base_id: StringName = &"placement"
	if placement == null:
		var selected_layer := _authoring_layer_for(selected)
		var new_id := AuthoringPlacementCatalogScript.next_stable_id(entries, base_id)
		placement = AuthoringPlacementCatalogScript.create_empty_placement(new_id, selected_layer)
	else:
		if not AuthoringPlacementCatalogScript.rekey_placement_tree(placement, entries):
			placement.free()
			_status.text = "Selected prefab does not expose a PlacementRoot2D."
			return
		var placement_id := placement.get("placement_id") as StringName
		AuthoringPlacementCatalogScript.configure_placement(placement, placement_id, _authoring_layer_for(selected))
	placement.name = _unique_child_name(parent, String(placement.name))
	_add_with_undo(parent, placement, "Create authored placement")


func _duplicate_placement() -> void:
	if _scene_root == null or _plugin == null:
		return
	var source := _selected_node()
	if source == null or not AuthoringPlacementCatalogScript.is_placement_root(source):
		_status.text = "Select a placement root before duplicating."
		return
	var parent := source.get_parent()
	if parent == null:
		return
	var copy := source.duplicate()
	var entries: Array[Dictionary] = AuthoringPlacementCatalogScript.scan(_scene_root)
	if not AuthoringPlacementCatalogScript.rekey_placement_tree(copy, entries):
		copy.free()
		_status.text = "Selected placement could not be duplicated."
		return
	copy.name = _unique_child_name(parent, String(source.name))
	if copy is Node2D:
		(copy as Node2D).position += Vector2(8.0, 8.0)
	_add_with_undo(parent, copy, "Duplicate authored placement")


func _validate_current_scene() -> void:
	if _scene_root == null:
		_status.text = "Open an authored scene before validating."
		return
	var errors: Array[String] = AuthoringPlacementCatalogScript.validate(AuthoringPlacementCatalogScript.scan(_scene_root))
	if errors.is_empty():
		_status.text = "VALID: all authored placement roots have unique IDs and supported layers."
		return
	_status.text = "INVALID (%d): %s" % [errors.size(), "; ".join(errors)]


func _add_with_undo(parent: Node, child: Node, action_name: String) -> void:
	var undo_redo := _plugin.get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(parent, "add_child", child, true)
	undo_redo.add_do_method(self, "_set_owner_recursive", child, _scene_root)
	undo_redo.add_undo_method(parent, "remove_child", child)
	undo_redo.commit_action()
	_selected_path = _scene_root.get_path_to(child)
	_plugin.get_editor_interface().edit_node(child)
	_refresh()


func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node == null or owner == null:
		return
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child as Node, owner)


func _authoring_parent_for(selected: Node) -> Node:
	if selected == null:
		return _scene_root
	if not AuthoringPlacementCatalogScript.is_placement_root(selected):
		return selected
	var placement_id := selected.get("placement_id") as StringName
	if selected is Sprite2D or placement_id in [&"hub_player", &"hub_npc", &"hub_chest", &"hub_rest_fire"]:
		return selected.get_parent()
	return selected


func _authoring_layer_for(selected: Node) -> String:
	if selected != null and AuthoringPlacementCatalogScript.is_placement_root(selected):
		return String(selected.get("authoring_layer"))
	return "Actors"


func _unique_child_name(parent: Node, base_name: String) -> StringName:
	var safe_base := base_name if not base_name.is_empty() else "Placement"
	var candidate := safe_base
	var suffix := 2
	while parent.get_node_or_null(candidate) != null:
		candidate = "%s%d" % [safe_base, suffix]
		suffix += 1
	return StringName(candidate)


func _open_hub_preview() -> void:
	if _plugin == null:
		return
	_plugin.get_editor_interface().open_scene_from_path(HUB_PREVIEW_SCENE)
