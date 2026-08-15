extends RefCounted
class_name PlayerProfile

const CURRENT_SCHEMA_VERSION := 5
const MAX_LEVEL := 99
const MAX_FAMILY_MASTERY := 3
const MAX_ITEM_ENHANCEMENT := 10
const FUSION_BASE_COST := 20
const FUSION_COST_PER_ENHANCEMENT := 15

var schema_version := CURRENT_SCHEMA_VERSION
var has_started := false
var open_hub_on_load := false
var pending_route := "title"
var palette_name := "blue"
var allocation_profile := 0
var level := 1
var xp := 0
var unspent_stat_points := 0
var base_vit := 4
var base_str := 3
var base_def := 3
var allocated_vit := 0
var allocated_str := 0
var allocated_def := 0
var gold := 0
var inventory: Array[Dictionary] = []
var equipped_instance_ids := {"weapon": "", "armor": "", "shield": "", "accessory": ""}
var family_mastery: Dictionary = {}
var next_item_sequence := 1
var completed_runs := 0
var last_clear_score := 0
var difficulty_rank := 1
var last_run_grade := "D"


func ensure_starter_items(catalog: ItemCatalog = null) -> void:
	var items := catalog if catalog != null else ItemCatalog.new()
	for slot: StringName in ItemCatalog.SLOTS:
		var starter := items.starter_item(slot)
		grant_item(starter, false)
		if str(equipped_instance_ids.get(String(slot), "")).is_empty():
			equipped_instance_ids[String(slot)] = starter.instance_id
	changed.emit()


func grant_item(item: ItemInstance, notify := true) -> bool:
	if item == null or item.instance_id.is_empty() or find_item(item.instance_id) != null:
		return false
	inventory.append(item.to_dictionary())
	if notify:
		changed.emit()
	return true


func find_item(instance_id: String) -> ItemInstance:
	for data: Dictionary in inventory:
		if str(data.get("instance_id", "")) == instance_id:
			return ItemInstance.from_dictionary(data)
	return null


func equip_item(instance_id: String, catalog: ItemCatalog = null) -> bool:
	var item := find_item(instance_id)
	if item == null:
		return false
	var items := catalog if catalog != null else ItemCatalog.new()
	var slot := items.definition_slot(item.definition_id)
	if slot not in ItemCatalog.SLOTS:
		return false
	equipped_instance_ids[String(slot)] = instance_id
	changed.emit()
	return true


func purchase_item(item: ItemInstance, cost: int) -> bool:
	if item == null or cost < 0 or gold < cost or find_item(item.instance_id) != null:
		return false
	gold -= cost
	inventory.append(item.to_dictionary())
	changed.emit()
	return true


func mastery_level(definition_id: StringName) -> int:
	return clampi(int(family_mastery.get(String(definition_id), 0)), 0, MAX_FAMILY_MASTERY)


func can_fuse_duplicate(instance_id: String, catalog: ItemCatalog = null) -> bool:
	var duplicate := find_item(instance_id)
	if duplicate == null:
		return false
	if instance_id in equipped_instance_ids.values():
		return false
	var items := catalog if catalog != null else ItemCatalog.new()
	if items.definition_slot(duplicate.definition_id) not in ItemCatalog.SLOTS:
		return false
	var has_upgrade_target := false
	for data: Dictionary in inventory:
		var candidate := ItemInstance.from_dictionary(data)
		if candidate.instance_id != duplicate.instance_id and candidate.definition_id == duplicate.definition_id and candidate.rarity == duplicate.rarity and (candidate.enhancement_level < MAX_ITEM_ENHANCEMENT or ItemCatalog.next_rarity(candidate.rarity) != &""):
			has_upgrade_target = true
	return has_upgrade_target


func fusion_cost(item: ItemInstance) -> int:
	if item == null:
		return 0
	return FUSION_BASE_COST + maxi(item.enhancement_level, 0) * FUSION_COST_PER_ENHANCEMENT


func fuse_duplicate(instance_id: String, catalog: ItemCatalog = null) -> bool:
	var duplicate := find_item(instance_id)
	if duplicate == null or not can_fuse_duplicate(instance_id, catalog):
		return false
	var cost := fusion_cost(duplicate)
	if gold < cost:
		return false
	var items := catalog if catalog != null else ItemCatalog.new()
	var remove_index := -1
	for index in inventory.size():
		if str(inventory[index].get("instance_id", "")) == instance_id:
			remove_index = index
			break
	if remove_index < 0:
		return false
	var target_index := -1
	var equipped_id := str(equipped_instance_ids.get(String(items.definition_slot(duplicate.definition_id)), ""))
	for index in inventory.size():
		var candidate := ItemInstance.from_dictionary(inventory[index])
		if candidate.instance_id != duplicate.instance_id and candidate.definition_id == duplicate.definition_id and candidate.rarity == duplicate.rarity and (candidate.enhancement_level < MAX_ITEM_ENHANCEMENT or ItemCatalog.next_rarity(candidate.rarity) != &"") and candidate.instance_id == equipped_id:
			target_index = index
			break
	if target_index < 0:
		for index in inventory.size():
			var candidate := ItemInstance.from_dictionary(inventory[index])
			if candidate.instance_id != duplicate.instance_id and candidate.definition_id == duplicate.definition_id and candidate.rarity == duplicate.rarity and (candidate.enhancement_level < MAX_ITEM_ENHANCEMENT or ItemCatalog.next_rarity(candidate.rarity) != &""):
				target_index = index
				break
	if target_index < 0:
		return false
	var target := ItemInstance.from_dictionary(inventory[target_index])
	if target.enhancement_level >= MAX_ITEM_ENHANCEMENT:
		target.rarity = ItemCatalog.next_rarity(target.rarity)
		target.enhancement_level = 0
	else:
		target.enhancement_level += 1
	inventory.remove_at(remove_index)
	if remove_index < target_index:
		target_index -= 1
	inventory[target_index] = target.to_dictionary()
	gold -= cost
	changed.emit()
	return true


func can_salvage_overflow(instance_id: String, catalog: ItemCatalog = null) -> bool:
	var item := find_item(instance_id)
	if item == null or instance_id in equipped_instance_ids.values():
		return false
	var items := catalog if catalog != null else ItemCatalog.new()
	return items.definition_slot(item.definition_id) in ItemCatalog.SLOTS and item.rarity == &"mythic" and item.enhancement_level >= MAX_ITEM_ENHANCEMENT


func salvage_overflow(instance_id: String, catalog: ItemCatalog = null) -> int:
	var items := catalog if catalog != null else ItemCatalog.new()
	if not can_salvage_overflow(instance_id, items):
		return 0
	var item := find_item(instance_id)
	if item == null:
		return 0
	for index in inventory.size():
		if str(inventory[index].get("instance_id", "")) == instance_id:
			inventory.remove_at(index)
			var value := items.overflow_salvage_value(item)
			gold += value
			changed.emit()
			return value
	return 0


func create_item_id(prefix := "item") -> String:
	var result := "%s-%08d" % [prefix, next_item_sequence]
	next_item_sequence += 1
	return result


static func xp_required_for_level(current_level: int, tuning: ProgressionTuning = null) -> int:
	return (tuning if tuning != null else ProgressionTuning.new()).xp_required_for_level(current_level)


static func stat_points_for_level(new_level: int, tuning: ProgressionTuning = null) -> int:
	return (tuning if tuning != null else ProgressionTuning.new()).stat_points_for_level(new_level)


func award_xp(amount: int, tuning: ProgressionTuning = null) -> Dictionary:
	var gained := maxi(amount, 0)
	xp += gained
	var levels_gained := 0
	var points_gained := 0
	while level < MAX_LEVEL:
		var required := xp_required_for_level(level, tuning)
		if xp < required:
			break
		xp -= required
		level += 1
		var level_points := stat_points_for_level(level, tuning)
		unspent_stat_points += level_points
		points_gained += level_points
		levels_gained += 1
	changed.emit()
	return {"xp": gained, "levels": levels_gained, "points": points_gained, "level": level}


func allocate_stat(stat_name: StringName, amount: int = 1) -> bool:
	var points := mini(maxi(amount, 0), unspent_stat_points)
	if points <= 0:
		return false
	match stat_name:
		&"VIT": allocated_vit += points
		&"STR": allocated_str += points
		&"DEF": allocated_def += points
		_:
			return false
	unspent_stat_points -= points
	changed.emit()
	return true


func respec_cost() -> int:
	return 0 if level <= 5 else 50 + (level - 5) * 10


func reset_allocated_stats() -> int:
	var refunded := allocated_vit + allocated_str + allocated_def
	var cost := respec_cost()
	if refunded <= 0 or gold < cost:
		return 0
	gold -= cost
	allocated_vit = 0
	allocated_str = 0
	allocated_def = 0
	unspent_stat_points += refunded
	changed.emit()
	return refunded


func to_dictionary() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"has_started": has_started,
		"open_hub_on_load": open_hub_on_load,
		"pending_route": pending_route,
		"palette_name": palette_name,
		"allocation_profile": allocation_profile,
		"level": level,
		"xp": xp,
		"unspent_stat_points": unspent_stat_points,
		"base_vit": base_vit,
		"base_str": base_str,
		"base_def": base_def,
		"allocated_vit": allocated_vit,
		"allocated_str": allocated_str,
		"allocated_def": allocated_def,
		"gold": gold,
		"inventory": inventory.duplicate(true),
		"equipped_instance_ids": equipped_instance_ids.duplicate(true),
		"family_mastery": family_mastery.duplicate(true),
		"next_item_sequence": next_item_sequence,
		"completed_runs": completed_runs,
		"last_clear_score": last_clear_score,
		"difficulty_rank": difficulty_rank,
		"last_run_grade": last_run_grade,
	}


func load_dictionary(data: Dictionary) -> void:
	schema_version = int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	has_started = bool(data.get("has_started", false))
	open_hub_on_load = bool(data.get("open_hub_on_load", false))
	pending_route = str(data.get("pending_route", "hub" if open_hub_on_load else "title"))
	if pending_route not in ["title", "hub", "run"]:
		pending_route = "title"
	palette_name = str(data.get("palette_name", "blue"))
	allocation_profile = int(data.get("allocation_profile", 0))
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(data.get("xp", 0)), 0)
	unspent_stat_points = maxi(int(data.get("unspent_stat_points", 0)), 0)
	base_vit = maxi(int(data.get("base_vit", 4)), 0)
	base_str = maxi(int(data.get("base_str", 3)), 0)
	base_def = maxi(int(data.get("base_def", 3)), 0)
	allocated_vit = maxi(int(data.get("allocated_vit", 0)), 0)
	allocated_str = maxi(int(data.get("allocated_str", 0)), 0)
	allocated_def = maxi(int(data.get("allocated_def", 0)), 0)
	gold = maxi(int(data.get("gold", 0)), 0)
	var saved_inventory: Variant = data.get("inventory", [])
	inventory.assign(saved_inventory if saved_inventory is Array else [])
	var saved_equipment: Variant = data.get("equipped_instance_ids", {})
	if saved_equipment is Dictionary:
		for slot: StringName in ItemCatalog.SLOTS:
			equipped_instance_ids[String(slot)] = str(saved_equipment.get(String(slot), ""))
	var saved_mastery: Variant = data.get("family_mastery", {})
	family_mastery.clear()
	if saved_mastery is Dictionary:
		for family_key: Variant in saved_mastery:
			var definition_id := StringName(str(family_key))
			if ItemCatalog.DEFINITIONS.has(definition_id):
				family_mastery[String(definition_id)] = clampi(int(saved_mastery[family_key]), 0, MAX_FAMILY_MASTERY)
	next_item_sequence = maxi(int(data.get("next_item_sequence", 1)), 1)
	completed_runs = maxi(int(data.get("completed_runs", 0)), 0)
	last_clear_score = clampi(int(data.get("last_clear_score", 0)), 0, 100)
	difficulty_rank = clampi(int(data.get("difficulty_rank", 1)), 1, 20)
	last_run_grade = str(data.get("last_run_grade", "D")).to_upper()
	if last_run_grade not in ["S", "A", "B", "C", "D", "F"]:
		last_run_grade = "D"
	ensure_starter_items()
	changed.emit()


signal changed
