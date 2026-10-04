@tool
extends Node2D

## Presentation-only authoring preview for one currently playable ItemCatalog
## definition. Catalog-owned live entries are read-only; standalone
## ItemDefinition resources may be edited or saved from this workbench.

enum PreviewMode { CARD, DROP, INSTANCE, EFFECTS }

const PREVIEW_CANVAS_SIZE := Vector2(240.0, 160.0)
const ITEM_RESOURCE_ROOT: String = ItemCatalogData.AUTHORED_ITEM_ROOT
const PREVIEW_RARITIES: Array[StringName] = [&"common", &"rare", &"epic", &"legendary", &"mythic"]
const TIER_STAT_IDS: Array[StringName] = [&"", &"vitality", &"strength", &"defense", &"agi", &"intelligence", &"mnd"]
const EDITABLE_PROPERTIES: Array[StringName] = [
	&"display_name", &"slot", &"gear_tier", &"tier_stat", &"tier_stats", &"description", &"price",
	&"source_tags", &"minimum_run_rank", &"minimum_player_level", &"rarity_floor",
	&"rarity_ceiling", &"shop_eligible", &"starter_only", &"live", &"family", &"role",
	&"role_tags", &"effects", &"shield", &"fusion_group", &"visual_id", &"set_id",
	&"set_name", &"passive_id", &"designer_notes", &"vitality_bonus", &"strength_bonus",
	&"defense_bonus", &"agility_bonus", &"intelligence_bonus", &"mind_bonus",
]
const READ_ONLY_PROPERTIES: Array[StringName] = [
	&"selected_item_name", &"selected_source_path", &"selected_source", &"authoring_status", &"visual_status",
]
const STAT_ALIASES: Dictionary = {
	"vitality": ["vitality", "vit"],
	"strength": ["strength", "str"],
	"defense": ["defense", "def"],
	"agi": ["agi", "agility", "speed"],
	"intelligence": ["intelligence", "int"],
	"mnd": ["mnd", "mind"],
}

var _catalog: ItemCatalog = null
var _item_id: StringName = &"cinder_blade"
var _selected_definition: ItemDefinition = null
var _selected_record: Dictionary = {}
var _observed_definition_record: Dictionary = {}
var _saved_definition_record: Dictionary = {}
var _workbench_notice := ""
var _error_message := ""
var _preview_mode := PreviewMode.CARD
var _preview_rarity := 0
var _preview_enhancement := 0
var _preview_seed := 1
var _preview_transmutation_id: StringName = &""


@export_group("Item Selection")
@export var item_id: StringName:
	get:
		return _item_id
	set(value):
		_select_item(value)

@export var selected_item_name: String:
	get:
		return str(_read_field(&"display_name", _read_field(&"name", String(_item_id))))
	set(_value):
		pass

@export var selected_source_path: String:
	get:
		return _catalog.definition_source_path(_item_id) if _catalog != null else ""
	set(_value):
		pass

@export_subgroup("Create Item")
@export var new_item_id := ""
@export_tool_button("Create Item from Selected") var create_item_button: Callable

@export_group("Identity & Availability")
@export var display_name: String:
	get:
		return str(_read_field(&"display_name", _read_field(&"name", "")))
	set(value):
		_write_field(&"display_name", value)

@export_enum("Weapon", "Head", "Body", "Arm", "Shield", "Accessory") var slot: int:
	get:
		var selected_slot := ItemCatalog.canonical_slot(_read_field(&"slot", &"weapon"))
		return maxi(ItemCatalog.SLOTS.find(selected_slot), 0)
	set(value):
		var index := clampi(value, 0, ItemCatalog.SLOTS.size() - 1)
		_write_field(&"slot", ItemCatalog.SLOTS[index])

@export_enum("Plain", "Basic", "Set", "Legacy", "Expansion") var gear_tier: int:
	get:
		return _enum_index([&"plain", &"basic", &"set", &"legacy", &"expansion"], _read_field(&"gear_tier", &"basic"))
	set(value):
		var values: Array[StringName] = [&"plain", &"basic", &"set", &"legacy", &"expansion"]
		_write_field(&"gear_tier", values[clampi(value, 0, values.size() - 1)])

@export_enum("None", "VIT", "STR", "DEF", "AGI", "INT", "MND") var tier_stat: int:
	get:
		return maxi(TIER_STAT_IDS.find(StringName(str(_read_field(&"tier_stat", &"")))), 0)
	set(value):
		_write_field(&"tier_stat", TIER_STAT_IDS[clampi(value, 0, TIER_STAT_IDS.size() - 1)])

@export var tier_stats: Array[String]:
	get:
		return _string_array(_read_field(&"tier_stats", []))
	set(value):
		_write_field(&"tier_stats", value.duplicate())

@export_multiline var description: String:
	get:
		return str(_read_field(&"description", ""))
	set(value):
		_write_field(&"description", value)

@export_range(0, 999999, 1) var price: int:
	get:
		return int(_read_field(&"price", 0))
	set(value):
		_write_field(&"price", maxi(value, 0))

@export_enum("Common", "Rare", "Epic", "Legendary", "Mythic") var rarity_floor: int:
	get:
		return _enum_index(PREVIEW_RARITIES, _read_field(&"rarity_floor", &"common"))
	set(value):
		_write_field(&"rarity_floor", PREVIEW_RARITIES[clampi(value, 0, PREVIEW_RARITIES.size() - 1)])

@export_enum("Common", "Rare", "Epic", "Legendary", "Mythic") var rarity_ceiling: int:
	get:
		return _enum_index(PREVIEW_RARITIES, _read_field(&"rarity_ceiling", &"mythic"))
	set(value):
		_write_field(&"rarity_ceiling", PREVIEW_RARITIES[clampi(value, 0, PREVIEW_RARITIES.size() - 1)])

@export var source_tags: Array[String]:
	get:
		return _string_array(_read_field(&"source_tags", []))
	set(value):
		_write_field(&"source_tags", value.duplicate())

@export_range(1, 99, 1) var minimum_run_rank: int:
	get:
		return int(_read_field(&"minimum_run_rank", 1))
	set(value):
		_write_field(&"minimum_run_rank", maxi(value, 1))

@export_range(1, 99, 1) var minimum_player_level: int:
	get:
		return int(_read_field(&"minimum_player_level", 1))
	set(value):
		_write_field(&"minimum_player_level", maxi(value, 1))

@export var shop_eligible: bool:
	get:
		return bool(_read_field(&"shop_eligible", false))
	set(value):
		_write_field(&"shop_eligible", value)

@export var starter_only: bool:
	get:
		return bool(_read_field(&"starter_only", false))
	set(value):
		_write_field(&"starter_only", value)

@export var live: bool:
	get:
		return bool(_read_field(&"live", false))
	set(value):
		_write_field(&"live", value)

@export var family: StringName:
	get:
		return StringName(str(_read_field(&"family", &"authored")))
	set(value):
		_write_field(&"family", value)

@export var role: StringName:
	get:
		return StringName(str(_read_field(&"role", &"stat")))
	set(value):
		_write_field(&"role", value)

@export var role_tags: Array[String]:
	get:
		return _string_array(_read_field(&"role_tags", []))
	set(value):
		_write_field(&"role_tags", value.duplicate())

@export_group("Stats & Tradeoffs")
@export_range(-999.0, 999.0, 0.1) var vitality_bonus: float:
	get:
		return _bonus_value("vitality")
	set(value):
		_set_bonus_value("vitality", value)

@export_range(-999.0, 999.0, 0.1) var strength_bonus: float:
	get:
		return _bonus_value("strength")
	set(value):
		_set_bonus_value("strength", value)

@export_range(-999.0, 999.0, 0.1) var defense_bonus: float:
	get:
		return _bonus_value("defense")
	set(value):
		_set_bonus_value("defense", value)

@export_range(-999.0, 999.0, 0.1) var agility_bonus: float:
	get:
		return _bonus_value("agi")
	set(value):
		_set_bonus_value("agi", value)

@export_range(-999.0, 999.0, 0.1) var intelligence_bonus: float:
	get:
		return _bonus_value("intelligence")
	set(value):
		_set_bonus_value("intelligence", value)

@export_range(-999.0, 999.0, 0.1) var mind_bonus: float:
	get:
		return _bonus_value("mnd")
	set(value):
		_set_bonus_value("mnd", value)

@export_group("Effects & Equipment")
@export var effects: Dictionary:
	get:
		return _dictionary_value(_read_field(&"effects", {}))
	set(value):
		_write_field(&"effects", value.duplicate(true))

@export var shield: Dictionary:
	get:
		return _dictionary_value(_read_field(&"shield", {}))
	set(value):
		_write_field(&"shield", value.duplicate(true))

@export var fusion_group: StringName:
	get:
		return StringName(str(_read_field(&"fusion_group", &"")))
	set(value):
		_write_field(&"fusion_group", value)

@export var visual_id: StringName:
	get:
		return StringName(str(_read_field(&"visual_id", _item_id)))
	set(value):
		_write_field(&"visual_id", value)

@export var set_id: StringName:
	get:
		return StringName(str(_read_field(&"set_id", &"")))
	set(value):
		_write_field(&"set_id", value)

@export var set_name: String:
	get:
		return str(_read_field(&"set_name", ""))
	set(value):
		_write_field(&"set_name", value)

@export var passive_id: StringName:
	get:
		return StringName(str(_read_field(&"passive_id", &"")))
	set(value):
		_write_field(&"passive_id", value)

@export_multiline var designer_notes: String:
	get:
		return str(_read_field(&"designer_notes", ""))
	set(value):
		_write_field(&"designer_notes", value)

@export_group("Preview")
@export_enum("Card", "Drop", "Instance", "Effects") var preview_mode: int:
	get:
		return _preview_mode
	set(value):
		_preview_mode = clampi(value, PreviewMode.CARD, PreviewMode.EFFECTS)
		queue_redraw()

@export_enum("Common", "Rare", "Epic", "Legendary", "Mythic") var preview_rarity: int:
	get:
		return _preview_rarity
	set(value):
		_preview_rarity = clampi(value, 0, PREVIEW_RARITIES.size() - 1)
		queue_redraw()

@export_range(0, 10, 1) var preview_enhancement: int:
	get:
		return _preview_enhancement
	set(value):
		_preview_enhancement = clampi(value, 0, 10)
		queue_redraw()

@export_range(0, 999999, 1) var preview_seed: int:
	get:
		return _preview_seed
	set(value):
		_preview_seed = value
		queue_redraw()

@export var preview_transmutation_id: StringName:
	get:
		return _preview_transmutation_id
	set(value):
		_preview_transmutation_id = value
		queue_redraw()

@export var selected_source: String:
	get:
		return "ItemDefinition" if _selected_definition != null else "ItemCatalogData (read-only)"
	set(_value):
		pass

@export var authoring_status: String:
	get:
		return _status_text()
	set(_value):
		pass

@export var visual_status: String:
	get:
		return "Shared slot-level pickup art; visual_id is not yet resolved to per-item art."
	set(_value):
		pass

@export_tool_button("Save Item Changes") var save_item_button: Callable
@export_tool_button("Refresh Catalog & Preview") var refresh_button: Callable


func _enter_tree() -> void:
	if create_item_button.is_null():
		create_item_button = Callable(self, "create_authored_item")
	if save_item_button.is_null():
		save_item_button = Callable(self, "save_selected_definition")
	if refresh_button.is_null():
		refresh_button = Callable(self, "refresh_catalog")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(Engine.is_editor_hint())
	create_item_button = Callable(self, "create_authored_item")
	save_item_button = Callable(self, "save_selected_definition")
	refresh_button = Callable(self, "refresh_catalog")
	_ensure_catalog()
	var command_line_id := _item_id_from_command_line()
	var requested_id := command_line_id if not command_line_id.is_empty() else _item_id
	var playable_ids: Array[StringName] = _catalog.playable_definition_ids()
	if command_line_id.is_empty() and requested_id not in playable_ids:
		requested_id = playable_ids[0] if not playable_ids.is_empty() else &""
	_select_item(requested_id, true)


func _ensure_catalog() -> void:
	if _catalog == null:
		_catalog = ItemCatalog.new()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or _selected_definition == null:
		return
	var current_record := _selected_definition.to_record()
	if current_record == _observed_definition_record:
		return
	_observed_definition_record = current_record.duplicate(true)
	_catalog.definitions[_item_id] = current_record.duplicate(true)
	_selected_record = _catalog.definition_data(_item_id)
	queue_redraw()


func _validate_property(property: Dictionary) -> void:
	if property.name == "item_id":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_item_picker_options())
		return
	if property.name == "preview_transmutation_id":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_transmutation_picker_options())
		return
	if property.name in READ_ONLY_PROPERTIES:
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		return
	if property.name in [&"new_item_id", &"create_item_button", &"save_item_button", &"refresh_button"]:
		return
	if property.name in EDITABLE_PROPERTIES:
		if _selected_definition == null:
			property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		else:
			# These are proxy controls for the selected Resource, not saved fields
			# on the workbench scene itself.
			property.usage = PROPERTY_USAGE_EDITOR


func _item_picker_options() -> Array[String]:
	_ensure_catalog()
	var options: Array[String] = []
	if _catalog == null:
		return options
	for definition_id: StringName in _catalog.playable_definition_ids():
		var record := _catalog.definition_data(definition_id)
		var label := str(record.get("display_name", record.get("name", definition_id)))
		options.append("%s (%s):%s" % [label, definition_id, definition_id])
	return options


func _transmutation_picker_options() -> Array[String]:
	_ensure_catalog()
	var options: Array[String] = ["None:"]
	if _catalog == null or _item_id.is_empty():
		return options
	for transmutation_id: StringName in _catalog.transmutations_for_definition(_item_id):
		options.append("%s:%s" % [String(transmutation_id), String(transmutation_id)])
	return options


func _item_id_from_command_line() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--item-id="):
			return StringName(argument.trim_prefix("--item-id="))
	return &""


func _select_item(requested_id: StringName, force := false) -> void:
	_ensure_catalog()
	if _catalog == null:
		_item_id = requested_id
		return
	if requested_id not in _catalog.playable_definition_ids():
		_set_workbench_error("Item ID is not in the current playable catalog: %s" % requested_id)
		return
	if not force and requested_id == _item_id:
		return
	if not force and _definition_is_dirty():
		_set_workbench_notice("Save item changes before selecting another entry.")
		return
	var record := _catalog.definition_data(requested_id)
	if record.is_empty():
		_item_id = requested_id
		_selected_definition = null
		_selected_record.clear()
		_saved_definition_record.clear()
		_observed_definition_record.clear()
		_set_workbench_error("Unknown item ID: %s" % requested_id)
		return
	_item_id = requested_id
	_selected_definition = _catalog.definition_resource(requested_id)
	if _selected_definition != null:
		record = _selected_definition.to_record()
		_catalog.definitions[requested_id] = record.duplicate(true)
		_saved_definition_record = record.duplicate(true)
		_observed_definition_record = record.duplicate(true)
	else:
		_saved_definition_record.clear()
		_observed_definition_record.clear()
	_selected_record = _catalog.definition_data(requested_id)
	_workbench_notice = "" if _selected_definition != null else "Catalog-owned live item is preview-only."
	_error_message = ""
	notify_property_list_changed()
	queue_redraw()


func _read_field(field: StringName, fallback: Variant) -> Variant:
	if _selected_definition != null:
		var value: Variant = _selected_definition.get(String(field))
		if value != null:
			return value
	return _selected_record.get(String(field), fallback)


func _write_field(field: StringName, value: Variant) -> void:
	if _selected_definition == null:
		return
	var previous: Variant = _selected_definition.get(String(field))
	if previous == value:
		return
	_selected_definition.set(String(field), value)
	_definition_changed()


func _definition_changed() -> void:
	if _selected_definition == null or _catalog == null:
		return
	_observed_definition_record = _selected_definition.to_record().duplicate(true)
	_catalog.definitions[_item_id] = _observed_definition_record.duplicate(true)
	_selected_record = _catalog.definition_data(_item_id)
	if _definition_is_dirty():
		_workbench_notice = ""
	_error_message = ""
	notify_property_list_changed()
	queue_redraw()


func _bonus_value(stat_key: String) -> float:
	var raw: Variant = _read_field(&"bonuses", {})
	if not raw is Dictionary:
		return 0.0
	var bonuses: Dictionary = raw
	var aliases: Array = STAT_ALIASES.get(stat_key, [stat_key])
	for alias: String in aliases:
		if bonuses.has(alias):
			return float(bonuses[alias])
	return 0.0


func _set_bonus_value(stat_key: String, value: float) -> void:
	if _selected_definition == null:
		return
	var bonuses := _selected_definition.bonuses.duplicate(true)
	var aliases: Array = STAT_ALIASES.get(stat_key, [stat_key])
	for alias: String in aliases:
		bonuses.erase(alias)
	if not is_zero_approx(value):
		bonuses[stat_key] = value
	_selected_definition.bonuses = bonuses
	_definition_changed()


func _enum_index(values: Array, value: Variant) -> int:
	var index := values.find(StringName(str(value)))
	return maxi(index, 0)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			result.append(str(entry))
	return result


func _dictionary_value(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


func _preview_item() -> ItemInstance:
	_ensure_catalog()
	if _catalog == null or _item_id.is_empty():
		return null
	return _catalog.create_preview_instance(
		_item_id,
		_preview_seed,
		PREVIEW_RARITIES[clampi(_preview_rarity, 0, PREVIEW_RARITIES.size() - 1)],
		_preview_enhancement,
		_preview_transmutation_id
	)


func _definition_is_dirty() -> bool:
	return _selected_definition != null \
		and not _saved_definition_record.is_empty() \
		and _selected_definition.to_record() != _saved_definition_record


func save_selected_definition() -> void:
	if _selected_definition == null:
		_set_workbench_notice("Catalog-owned live items are preview-only; create a standalone ItemDefinition to edit one.")
		return
	var problems := _selected_definition.validate()
	if not problems.is_empty():
		_set_workbench_error("Cannot save: %s" % "; ".join(problems))
		return
	var save_error := _catalog.save_authored_definition(_selected_definition)
	if save_error != OK:
		_set_workbench_error("Could not save item definition (error %d)." % save_error)
		return
	_selected_definition.emit_changed()
	_catalog.invalidate_authored_definition_cache()
	_catalog = ItemCatalog.new()
	_select_item(_item_id, true)
	_workbench_notice = "Saved item definition"
	print("Item preview workbench saved %s" % _catalog.definition_source_path(_item_id))
	queue_redraw()


func create_authored_item() -> void:
	if _definition_is_dirty():
		_set_workbench_notice("Save item changes before creating another item.")
		return
	if _selected_definition == null:
		_set_workbench_notice("Select a standalone ItemDefinition to use as the starting point.")
		return
	var candidate_id := new_item_id.strip_edges()
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z][a-z0-9_]*$")
	if id_pattern.search(candidate_id) == null:
		_set_workbench_error("Item ID must match ^[a-z][a-z0-9_]*$")
		return
	var authored_id := StringName(candidate_id)
	if _catalog.definition_exists(authored_id):
		_set_workbench_error("An item definition already uses id '%s'" % candidate_id)
		return
	var source_name := _selected_definition.display_name
	var resource_path := "%s/%s.tres" % [ITEM_RESOURCE_ROOT, candidate_id]
	if FileAccess.file_exists(resource_path):
		_set_workbench_error("Definition already exists: %s" % resource_path)
		return
	var new_definition := _selected_definition.duplicate(true) as ItemDefinition
	if new_definition == null:
		_set_workbench_error("Could not copy the selected item definition.")
		return
	new_definition.id = authored_id
	new_definition.display_name = _new_item_display_name(candidate_id)
	new_definition.resource_name = new_definition.display_name
	var save_error := ResourceSaver.save(new_definition, resource_path)
	if save_error != OK:
		_set_workbench_error("Could not create %s (error %d)" % [resource_path, save_error])
		return
	_catalog.invalidate_authored_definition_cache()
	_catalog = ItemCatalog.new()
	new_item_id = ""
	_select_item(authored_id, true)
	_workbench_notice = "Created item %s from %s" % [candidate_id, source_name]
	print("Item preview workbench created %s" % resource_path)
	notify_property_list_changed()
	queue_redraw()


func _new_item_display_name(item_id_value: String) -> String:
	var words := item_id_value.split("_", false)
	for index: int in words.size():
		words[index] = String(words[index]).to_upper()
	return " ".join(words)


func refresh_catalog() -> void:
	_ensure_catalog()
	if _catalog == null:
		return
	if _definition_is_dirty():
		_set_workbench_notice("Save item changes before refreshing the catalogue.")
		return
	var requested_id := _item_id
	_catalog.invalidate_authored_definition_cache()
	_catalog = ItemCatalog.new()
	if not _catalog.definition_exists(requested_id):
		var ids: Array[StringName] = _catalog.playable_definition_ids()
		requested_id = ids[0] if not ids.is_empty() else &""
	_select_item(requested_id, true)


func get_preview_summary() -> Dictionary:
	_ensure_catalog()
	if _catalog == null or _item_id.is_empty():
		return {"id": String(_item_id), "ready": false, "error": "No item is selected."}
	var definition := _catalog.definition_data(_item_id)
	if definition.is_empty():
		return {"id": String(_item_id), "ready": false, "error": _error_message}
	var instance := _preview_item()
	if instance == null:
		return {"id": String(_item_id), "ready": false, "error": "Preview instance could not be created."}
	var drop_texture := ItemVisualResolver.item_drop_texture(instance, _catalog)
	var validation_errors: Array[String] = []
	if _selected_definition != null:
		validation_errors = _selected_definition.validate()
	return {
		"id": String(_item_id),
		"display_name": str(definition.get("display_name", definition.get("name", _item_id))),
		"slot": String(ItemCatalog.canonical_slot(definition.get("slot", &""))),
		"source_path": _catalog.definition_source_path(_item_id),
		"editable": _selected_definition != null,
		"dirty": _definition_is_dirty(),
		"rarity": String(instance.rarity),
		"enhancement_level": instance.enhancement_level,
		"random_stat_points": instance.random_stat_points.duplicate(true),
		"bonuses": _catalog.bonuses(instance),
		"shield_bonuses": _catalog.shield_bonuses(instance),
		"effect_lines": _catalog.effect_display_lines(instance, true),
		"description": _catalog.player_description(instance),
		"drop_texture_path": drop_texture.resource_path if drop_texture != null else "",
		"visual_source": "slot-level",
		"preview_mode": _preview_mode_label(),
		"validation_errors": validation_errors,
		"actions_ready": create_item_button.is_valid() and save_item_button.is_valid() and refresh_button.is_valid(),
		"ready": true,
	}


func _preview_mode_label() -> String:
	match _preview_mode:
		PreviewMode.CARD:
			return "card"
		PreviewMode.DROP:
			return "drop"
		PreviewMode.INSTANCE:
			return "instance"
		PreviewMode.EFFECTS:
			return "effects"
		_:
			return "card"


func _status_text() -> String:
	if not _error_message.is_empty():
		return _error_message
	if not _workbench_notice.is_empty():
		return _workbench_notice
	if _selected_definition == null:
		return "READ ONLY - catalog-owned live item"
	var problems := _selected_definition.validate()
	if not problems.is_empty():
		return "INVALID - %s" % "; ".join(problems)
	if _definition_is_dirty():
		return "UNSAVED - SAVE ITEM CHANGES"
	return "READY"


func _set_workbench_error(message: String) -> void:
	_error_message = message
	_workbench_notice = ""
	push_warning("Item preview workbench: %s" % message)
	notify_property_list_changed()
	queue_redraw()


func _set_workbench_notice(message: String) -> void:
	_workbench_notice = message
	notify_property_list_changed()
	queue_redraw()


func _draw() -> void:
	_ensure_catalog()
	draw_rect(Rect2(Vector2.ZERO, PREVIEW_CANVAS_SIZE), Color("101825"), true)
	draw_rect(Rect2(4.0, 4.0, 232.0, 152.0), Color("1b2a3d"), true)
	draw_rect(Rect2(4.0, 4.0, 232.0, 152.0), Color("5a7890"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 17.0), "ITEM DESIGN PREVIEW / %s" % _preview_mode_label().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 216.0, 9, Color("b9e9ff"))
	if _catalog == null or not _catalog.definition_exists(_item_id):
		draw_string(ThemeDB.fallback_font, Vector2(12.0, 42.0), _error_message if not _error_message.is_empty() else "No authored item definitions found.", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 8, Color("ff8f8f"))
		return
	var definition := _catalog.definition_data(_item_id)
	var instance := _preview_item()
	if instance == null:
		draw_string(ThemeDB.fallback_font, Vector2(12.0, 42.0), "Could not build preview instance.", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 8, Color("ff8f8f"))
		return
	var texture := ItemVisualResolver.item_drop_texture(instance, _catalog)
	if texture != null:
		draw_texture_rect(texture, Rect2(14.0, 43.0, 32.0, 32.0), false, _catalog.rarity_color(instance.rarity))
	else:
		draw_rect(Rect2(14.0, 43.0, 32.0, 32.0), Color("32465a"), true)
		draw_string(ThemeDB.fallback_font, Vector2(15.0, 60.0), "NO ART", HORIZONTAL_ALIGNMENT_LEFT, 30.0, 6, Color("b7c9d8"))
	var item_title := _catalog.display_name(instance)
	draw_string(ThemeDB.fallback_font, Vector2(56.0, 40.0), item_title, HORIZONTAL_ALIGNMENT_LEFT, 174.0, 9, _catalog.rarity_color(instance.rarity))
	draw_string(ThemeDB.fallback_font, Vector2(56.0, 52.0), "%s / %s" % [_catalog.slot_label(definition.get("slot", &"")), String(_item_id)], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("b7c9d8"))
	match _preview_mode:
		PreviewMode.CARD:
			_draw_card_preview(instance, definition)
		PreviewMode.DROP:
			_draw_drop_preview(instance)
		PreviewMode.INSTANCE:
			_draw_instance_preview(instance)
		PreviewMode.EFFECTS:
			_draw_effect_preview(instance)
	var status := _status_text()
	var status_color := Color("8dffb1") if status == "READY" else Color("ffcf7a")
	if not _error_message.is_empty():
		status_color = Color("ff8f8f")
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 151.0), status, HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, status_color)


func _draw_card_preview(instance: ItemInstance, definition: Dictionary) -> void:
	var bonuses := _catalog.bonuses(instance)
	var stats := _bonus_summary(bonuses)
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 91.0), "RARITY %s   +%02d" % [String(instance.rarity).to_upper(), instance.enhancement_level], HORIZONTAL_ALIGNMENT_LEFT, 216.0, 8, Color("d8e7f0"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 105.0), stats if not stats.is_empty() else "NO STAT BONUSES", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 8, Color("d8e7f0"))
	var description := str(definition.get("description", ""))
	if description.is_empty():
		description = "No player description authored."
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 122.0), description, HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 136.0), "ART: SHARED SLOT PICKUP", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("a8c1d5"))


func _draw_drop_preview(instance: ItemInstance) -> void:
	var type_label := ItemVisualResolver.item_type_label(instance, _catalog)
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 95.0), "%s DROP" % type_label, HORIZONTAL_ALIGNMENT_LEFT, 216.0, 9, Color("d8e7f0"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 112.0), "Uses the runtime slot-level pickup resolver.", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 126.0), "No physics or profile state is started.", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("b7c9d8"))


func _draw_instance_preview(instance: ItemInstance) -> void:
	var bonuses := _catalog.bonuses(instance)
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 92.0), "SEEDED INSTANCE  #%d" % _preview_seed, HORIZONTAL_ALIGNMENT_LEFT, 216.0, 8, Color("b9e9ff"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 106.0), _bonus_summary(bonuses), HORIZONTAL_ALIGNMENT_LEFT, 216.0, 8, Color("d8e7f0"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 120.0), "RANDOM %s" % _catalog.random_stat_text(instance) if not _catalog.random_stat_text(instance).is_empty() else "NO RANDOM ROLLS", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 134.0), "PRICE %d   QUALITY %.2f" % [_catalog.price(instance), instance.quality], HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("b7c9d8"))


func _draw_effect_preview(instance: ItemInstance) -> void:
	var lines := _catalog.effect_display_lines(instance, true)
	if lines.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12.0, 94.0), "NO AUTHORED EFFECTS", HORIZONTAL_ALIGNMENT_LEFT, 216.0, 8, Color("d8e7f0"))
		return
	for index: int in mini(lines.size(), 4):
		draw_string(ThemeDB.fallback_font, Vector2(12.0, 93.0 + float(index) * 13.0), lines[index], HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("d8e7f0"))
	if lines.size() > 4:
		draw_string(ThemeDB.fallback_font, Vector2(12.0, 143.0), "+%d MORE EFFECTS" % (lines.size() - 4), HORIZONTAL_ALIGNMENT_LEFT, 216.0, 7, Color("ffcf7a"))


func _bonus_summary(bonuses: Dictionary) -> String:
	var labels := {
		"vitality": "VIT", "strength": "STR", "defense": "DEF",
		"agi": "AGI", "intelligence": "INT", "mnd": "MND",
	}
	var parts: Array[String] = []
	for stat: String in ["vitality", "strength", "defense", "agi", "intelligence", "mnd"]:
		if not bonuses.has(stat):
			continue
		var value := float(bonuses[stat])
		if is_zero_approx(value):
			continue
		var sign := "+" if value > 0.0 else ""
		parts.append("%s %s%s" % [labels[stat], sign, str(value)])
	return "   ".join(parts)
