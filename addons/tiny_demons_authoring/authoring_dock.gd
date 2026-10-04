@tool
extends VBoxContainer

const AuthoringPlacementCatalogScript := preload("res://scripts/content/authoring_placement_catalog.gd")
const ContentDefinitionManifestServiceScript := preload("res://scripts/content/content_definition_manifest_service.gd")
const ItemCatalogDataScript := preload("res://scripts/content/item_catalog_data.gd")
const HUB_PREVIEW_SCENE := "res://scenes/authoring/previews/hub_world_preview.tscn"

signal design_preview_requested(enemy_id: StringName)
signal interactive_preview_requested(enemy_id: StringName, seed_value: int)
signal stop_preview_requested

var _plugin: EditorPlugin = null
var _scene_root: Node = null
var _filter: LineEdit = null
var _tree: Tree = null
var _status: Label = null
var _preview_status: Label = null
var _enemy_validation_status: Label = null
var _manifest_status: Label = null
var _prefab_picker: OptionButton = null
var _enemy_picker: OptionButton = null
var _preview_seed: SpinBox = null
var _stop_preview_button: Button = null
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
	refresh_button.pressed.connect(_refresh_authoring_content)
	actions.add_child(refresh_button)
	add_child(actions)

	var enemy_preview_title := Label.new()
	enemy_preview_title.text = "Enemy Preview"
	enemy_preview_title.add_theme_font_size_override("font_size", 14)
	enemy_preview_title.tooltip_text = "Preview registered enemies using the same factory and runtime encounter path."
	add_child(enemy_preview_title)
	var enemy_row := HBoxContainer.new()
	_enemy_picker = OptionButton.new()
	_enemy_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_enemy_picker()
	enemy_row.add_child(_enemy_picker)
	var design_button := Button.new()
	design_button.text = "Design"
	design_button.tooltip_text = "Open the pixel-art enemy design preview for the selected definition."
	design_button.pressed.connect(_request_design_preview)
	enemy_row.add_child(design_button)
	var play_button := Button.new()
	play_button.text = "Play"
	play_button.tooltip_text = "Launch a separate game process with an isolated temporary profile."
	play_button.pressed.connect(_request_interactive_preview)
	enemy_row.add_child(play_button)
	_stop_preview_button = Button.new()
	_stop_preview_button.text = "Stop"
	_stop_preview_button.tooltip_text = "Stop only the isolated interactive preview process."
	_stop_preview_button.disabled = true
	_stop_preview_button.pressed.connect(func() -> void: stop_preview_requested.emit())
	enemy_row.add_child(_stop_preview_button)
	add_child(enemy_row)
	var enemy_validation_row := HBoxContainer.new()
	var validate_enemies_button := Button.new()
	validate_enemies_button.text = "Validate Enemies"
	validate_enemies_button.tooltip_text = "Run the shared EnemyDefinition and registry checks used by the definition preflight."
	validate_enemies_button.pressed.connect(_validate_enemy_catalog)
	enemy_validation_row.add_child(validate_enemies_button)
	add_child(enemy_validation_row)
	_enemy_validation_status = Label.new()
	_enemy_validation_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemy_validation_status.text = "Enemy registry has not been validated."
	add_child(_enemy_validation_status)
	_manifest_status = Label.new()
	_manifest_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_manifest_status()
	add_child(_manifest_status)
	var seed_row := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = "Seed (-1 = new):"
	seed_row.add_child(seed_label)
	_preview_seed = SpinBox.new()
	_preview_seed.min_value = -1
	_preview_seed.max_value = 2147483647
	_preview_seed.step = 1
	_preview_seed.value = -1
	_preview_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_seed.tooltip_text = "Use a fixed seed to reproduce this interactive enemy session, or -1 to generate a new seed."
	seed_row.add_child(_preview_seed)
	add_child(seed_row)
	_preview_status = Label.new()
	_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status.text = "Select an enemy to open its design view or isolated playtest."
	add_child(_preview_status)

	var prefab_row := HBoxContainer.new()
	var prefab_label := Label.new()
	prefab_label.text = "Create:"
	prefab_row.add_child(prefab_label)
	_prefab_picker = OptionButton.new()
	_prefab_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prefab_picker.add_item("Empty Placement")
	_prefab_picker.set_item_metadata(0, "")
	_prefab_picker.add_item("Player Placement Prefab")
	_prefab_picker.set_item_metadata(1, "res://scenes/authoring/templates/player_placement.tscn")
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
	validate_button.text = "Validate Scene"
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


func _populate_enemy_picker() -> void:
	if _enemy_picker == null:
		return
	var previous_id := _selected_enemy_id()
	_enemy_picker.clear()
	var enemy_ids: Array[StringName] = SlimeVariantCatalog.variants().duplicate()
	enemy_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		var left_definition := EnemyFactory.definition(left)
		var right_definition := EnemyFactory.definition(right)
		var left_name := left_definition.display_name if left_definition != null else String(left)
		var right_name := right_definition.display_name if right_definition != null else String(right)
		if left_name.to_lower() == right_name.to_lower():
			return String(left) < String(right)
		return left_name.to_lower() < right_name.to_lower()
	)
	var selected_index := -1
	for enemy_id in enemy_ids:
		var definition := EnemyFactory.definition(enemy_id)
		var display_name := definition.display_name if definition != null else String(enemy_id)
		var index := _enemy_picker.item_count
		_enemy_picker.add_item("%s  [%s]" % [display_name, enemy_id])
		_enemy_picker.set_item_metadata(index, enemy_id)
		if enemy_id == previous_id:
			selected_index = index
	if _enemy_picker.item_count > 0:
		_enemy_picker.select(selected_index if selected_index >= 0 else 0)


func _refresh_authoring_content() -> void:
	var manifest_was_current := ContentDefinitionManifestServiceScript.check_freshness().is_empty()
	var manifest_error: Error = ContentDefinitionManifestServiceScript.refresh_manifest()
	if _manifest_status != null:
		if manifest_error == OK:
			_manifest_status.text = "Definition manifest is current." if manifest_was_current else "Definition manifest refreshed."
		else:
			_manifest_status.text = "Definition manifest refresh failed (error %d)." % manifest_error
	SlimeVariantCatalog.invalidate_cache()
	ItemCatalogDataScript.invalidate_default_cache()
	if _scene_root != null and _scene_root.has_method("refresh_preview"):
		_scene_root.call("refresh_preview")
	_refresh()


func _update_manifest_status() -> void:
	if _manifest_status == null:
		return
	var problems: Array[String] = ContentDefinitionManifestServiceScript.check_freshness()
	if problems.is_empty():
		_manifest_status.text = "Definition manifest is current (%d resources)." % ContentDefinitionManifestServiceScript.discover_resource_paths().size()
	else:
		_manifest_status.text = "Definition manifest needs refresh. Use Refresh after authoring changes."


func selected_enemy_id() -> StringName:
	return _selected_enemy_id()


func _selected_enemy_id() -> StringName:
	if _enemy_picker == null or _enemy_picker.item_count == 0 or _enemy_picker.selected < 0:
		return &""
	var value: Variant = _enemy_picker.get_item_metadata(_enemy_picker.selected)
	return value as StringName if value is StringName else StringName(str(value))


func _request_design_preview() -> void:
	var enemy_id := _selected_enemy_id()
	if not enemy_id.is_empty():
		design_preview_requested.emit(enemy_id)


func _request_interactive_preview() -> void:
	var enemy_id := _selected_enemy_id()
	if not enemy_id.is_empty():
		interactive_preview_requested.emit(enemy_id, int(_preview_seed.value) if _preview_seed != null else -1)


func _validate_enemy_catalog() -> void:
	var errors := SlimeVariantCatalog.validate()
	if errors.is_empty():
		_enemy_validation_status.text = "VALID: %d enemy definitions." % SlimeVariantCatalog.variants().size()
		return
	var visible_errors := errors.slice(0, mini(errors.size(), 3))
	var remaining_count := errors.size() - visible_errors.size()
	var suffix := " (+%d more)" % remaining_count if remaining_count > 0 else ""
	_enemy_validation_status.text = "INVALID: %s%s" % ["; ".join(visible_errors), suffix]


func set_preview_status(value: String, preview_running: bool) -> void:
	if _preview_status != null:
		_preview_status.text = value
	if _stop_preview_button != null:
		_stop_preview_button.disabled = not preview_running


func _refresh() -> void:
	if _tree == null:
		return
	_populate_enemy_picker()
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
