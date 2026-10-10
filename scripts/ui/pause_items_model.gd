extends RefCounted
class_name PauseItemsModel

## Read-only projection of the profile's owned gear for the Pause Items page.
## Profile inventory stores one ItemInstance per gear piece; this view groups
## functionally identical pieces and derives the count for display.

const FILTER_ALL := 0
const FILTER_WEAPONS := 1
const FILTER_ARMOR := 2
const FILTER_ACCESSORIES := 3
const FILTER_COUNT := 4

const SORT_NAME := 0
const SORT_RARITY := 1

const VISIBLE_ROW_COUNT := 7
const RARITY_ORDER := {&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 4}

var filter_index := FILTER_ALL
var sort_index := SORT_NAME
var selected_index := 0
var scroll_offset := 0

var _all_rows: Array[Dictionary] = []
var _filtered_rows: Array[Dictionary] = []
var _inventory_revision := -1
var _equipped_signature := ""
var _catalog: ItemCatalog = null


func refresh(profile: PlayerProfile, catalog: ItemCatalog = null) -> bool:
	if profile == null:
		return false
	_catalog = catalog if catalog != null else (_catalog if _catalog != null else ItemCatalog.new())
	var equipped_signature := _equipped_signature_for(profile)
	if profile.inventory_revision == _inventory_revision and equipped_signature == _equipped_signature:
		return false
	var selected_key := _selected_key()
	_all_rows.clear()
	var row_indices: Dictionary = {}
	var equipped_ids: Array = profile.equipped_instance_ids.values()
	for item_data: Dictionary in profile.inventory:
		var item := ItemInstance.from_dictionary(item_data)
		var slot := _catalog.definition_slot(item.definition_id)
		if slot not in ItemCatalog.SLOTS:
			continue
		var stack_key := item.inventory_stack_key()
		if row_indices.has(stack_key):
			var row_index := int(row_indices[stack_key])
			_all_rows[row_index]["quantity"] = int(_all_rows[row_index].get("quantity", 1)) + 1
			if item.instance_id in equipped_ids:
				_all_rows[row_index]["equipped"] = true
			continue
		row_indices[stack_key] = _all_rows.size()
		_all_rows.append({
			"stack_key": stack_key,
			"item": item,
			"slot": slot,
			"quantity": 1,
			"equipped": item.instance_id in equipped_ids,
		})
	_inventory_revision = profile.inventory_revision
	_equipped_signature = equipped_signature
	_sort_rows()
	_apply_filter(selected_key)
	return true


func set_filter(index: int) -> bool:
	var next_index := clampi(index, 0, FILTER_COUNT - 1)
	if next_index == filter_index:
		return false
	filter_index = next_index
	_apply_filter(_selected_key())
	return true


func move_filter(direction: int) -> bool:
	if direction == 0:
		return false
	return set_filter(posmod(filter_index + (1 if direction > 0 else -1), FILTER_COUNT))


func toggle_sort() -> void:
	sort_index = SORT_RARITY if sort_index == SORT_NAME else SORT_NAME
	var selected_key := _selected_key()
	_sort_rows()
	_apply_filter(selected_key)


func move_selection(direction: int) -> bool:
	if _filtered_rows.is_empty() or direction == 0:
		return false
	var next_index := clampi(selected_index + (1 if direction > 0 else -1), 0, _filtered_rows.size() - 1)
	if next_index == selected_index:
		return false
	selected_index = next_index
	_ensure_selection_visible()
	return true


func select_visible_row(row_index: int) -> bool:
	var absolute_index := scroll_offset + row_index
	if row_index < 0 or absolute_index >= _filtered_rows.size():
		return false
	if selected_index == absolute_index:
		return false
	selected_index = absolute_index
	_ensure_selection_visible()
	return true


func selected_row() -> Dictionary:
	if selected_index < 0 or selected_index >= _filtered_rows.size():
		return {}
	return _filtered_rows[selected_index]


func visible_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var end_index := mini(scroll_offset + VISIBLE_ROW_COUNT, _filtered_rows.size())
	for index in range(scroll_offset, end_index):
		result.append(_filtered_rows[index])
	return result


func row_count() -> int:
	return _filtered_rows.size()


func filter_label(index: int = -1) -> String:
	var labels := ["ALL", "WEAPONS", "ARMOR", "ACCESS."]
	var resolved_index := filter_index if index < 0 else index
	return str(labels[clampi(resolved_index, 0, labels.size() - 1)])


func sort_label() -> String:
	return "SORT: RARITY" if sort_index == SORT_RARITY else "SORT: NAME A-Z"


func _apply_filter(preserve_key: String) -> void:
	_filtered_rows.clear()
	for row: Dictionary in _all_rows:
		if _row_matches_filter(row):
			_filtered_rows.append(row)
	var restored_index := -1
	if not preserve_key.is_empty():
		for index in _filtered_rows.size():
			if str(_filtered_rows[index].get("stack_key", "")) == preserve_key:
				restored_index = index
				break
	selected_index = restored_index if restored_index >= 0 else clampi(selected_index, 0, maxi(_filtered_rows.size() - 1, 0))
	_ensure_selection_visible()


func _row_matches_filter(row: Dictionary) -> bool:
	var slot := StringName(str(row.get("slot", &"")))
	match filter_index:
		FILTER_WEAPONS:
			return slot == &"weapon"
		FILTER_ARMOR:
			return slot in [&"head", &"body", &"arm", &"shield"]
		FILTER_ACCESSORIES:
			return slot == &"accessory"
		_:
			return true


func _sort_rows() -> void:
	_all_rows.sort_custom(_row_precedes)


func _row_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_item := left.get("item") as ItemInstance
	var right_item := right.get("item") as ItemInstance
	var left_slot := ItemCatalog.SLOTS.find(StringName(str(left.get("slot", &""))))
	var right_slot := ItemCatalog.SLOTS.find(StringName(str(right.get("slot", &""))))
	if sort_index == SORT_RARITY:
		var left_rank := int(RARITY_ORDER.get(left_item.rarity, 0)) if left_item != null else 0
		var right_rank := int(RARITY_ORDER.get(right_item.rarity, 0)) if right_item != null else 0
		if left_rank != right_rank:
			return left_rank > right_rank
		if left_slot != right_slot:
			return left_slot < right_slot
	var left_name := _catalog.gear_name(left_item).to_lower() if _catalog != null else ""
	var right_name := _catalog.gear_name(right_item).to_lower() if _catalog != null else ""
	if left_name != right_name:
		return left_name < right_name
	if left_slot != right_slot:
		return left_slot < right_slot
	return str(left.get("stack_key", "")) < str(right.get("stack_key", ""))


func _selected_key() -> String:
	var row := selected_row()
	return str(row.get("stack_key", ""))


func _ensure_selection_visible() -> void:
	if _filtered_rows.is_empty():
		selected_index = 0
		scroll_offset = 0
		return
	selected_index = clampi(selected_index, 0, _filtered_rows.size() - 1)
	if selected_index < scroll_offset:
		scroll_offset = selected_index
	elif selected_index >= scroll_offset + VISIBLE_ROW_COUNT:
		scroll_offset = selected_index - VISIBLE_ROW_COUNT + 1
	scroll_offset = clampi(scroll_offset, 0, maxi(_filtered_rows.size() - VISIBLE_ROW_COUNT, 0))


func _equipped_signature_for(profile: PlayerProfile) -> String:
	var equipped: Array[String] = []
	for slot: StringName in ItemCatalog.SLOTS:
		equipped.append(profile.get_equipped_instance_id(slot))
	return "|".join(equipped)
