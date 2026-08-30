extends RefCounted
class_name PlayerProfile

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")

const CURRENT_SCHEMA_VERSION := 11
const LEGACY_DEMON_CLOAK_SCHEMA_VERSION := 10
const LEGACY_SIX_STAT_SCHEMA_VERSION := 9
const LEGACY_SPEED_SCHEMA_VERSION := 8
const MAX_LEVEL := 99
const MAX_FAMILY_MASTERY := 3
const MAX_ITEM_ENHANCEMENT := 10
const FUSION_START_COST := 1
const FUSION_RARITY_STEP_COST := 10
const ELEMENTAL_FLAME_COST := 5
const ELEMENT_BIND_SOUL_COST := 50
const MAX_PLAYER_NAME_LENGTH := 8
const DEFAULT_PLAYER_NAME := "DEMON"
const CLEAR_REWARD_SLOT_HISTORY_LIMIT := 3
const DEMON_CLOAK_BASE_PRICE := 500
const DEMON_CLOAK_PRICE_STEP := 100

var schema_version := CURRENT_SCHEMA_VERSION
var has_started := false
var open_hub_on_load := false
var pending_route := "title"
var player_name := DEFAULT_PLAYER_NAME
var starter_flame: StringName = &"fire"
var palette_name := "blue"
var bound_element: StringName = &""
var has_bound_element := false
var allocation_profile := 0
var level := 1
var xp := 0
var unspent_stat_points := 0
var base_vit := 3
var base_str := 2
var base_def := 2
var base_agi := 1
var base_int := 1
var base_mnd := 1
## Temporary compatibility alias for schema-8 callers.
var base_spd:
	get:
		return base_agi
	set(value):
		base_agi = maxi(int(value), 0)
var allocated_vit := 0
var allocated_str := 0
var allocated_def := 0
var allocated_agi := 0
var allocated_int := 0
var allocated_mnd := 0
## Temporary compatibility alias for schema-8 callers.
var allocated_spd:
	get:
		return allocated_agi
	set(value):
		allocated_agi = maxi(int(value), 0)
var gold := 0
var souls := 0
var starter_soul_gift_claimed := false
var demon_cloak_purchases := 0
var inventory: Array[Dictionary] = []
## Canonical state has six slots. The `armor` key is retained as a synchronized
## load/save alias so older menu/test callers do not lose the Body item during
## migration.
var equipped_instance_ids := {"weapon": "", "head": "", "body": "", "armor": "", "arm": "", "shield": "", "accessory": ""}
var family_mastery: Dictionary = {}
var next_item_sequence := 1
var completed_runs := 0
var last_clear_score := 0
var difficulty_rank := 1
var last_run_grade := "D"
var clear_reward_slot_history: Array[String] = []


static func normalize_player_name(value: String) -> String:
	var normalized := ""
	for character in value.strip_edges().to_upper():
		if character == " " or character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-'.":
			normalized += character
		if normalized.length() >= MAX_PLAYER_NAME_LENGTH:
			break
	return normalized if not normalized.is_empty() else DEFAULT_PLAYER_NAME


func ensure_starter_items(catalog: ItemCatalog = null) -> void:
	var items := catalog if catalog != null else ItemCatalog.new()
	for slot: StringName in ItemCatalog.SLOTS:
		var starter := items.starter_item(slot)
		# Existing four-slot files may already own `starter-armor`; retain that
		# stable instance ID as Body instead of duplicating it as `starter-body`.
		if slot == &"body" and find_item("starter-armor") != null and find_item(starter.instance_id) == null:
			if get_equipped_instance_id(slot).is_empty():
				equipped_instance_ids["body"] = "starter-armor"
			_sync_body_alias()
			continue
		grant_item(starter)
		if get_equipped_instance_id(slot).is_empty():
			equipped_instance_ids[String(slot)] = starter.instance_id
	_sync_body_alias()


func grant_item(item: ItemInstance) -> bool:
	if item == null or item.instance_id.is_empty() or find_item(item.instance_id) != null:
		return false
	inventory.append(item.to_dictionary())
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
	_sync_body_alias()
	return true


func unequip_slot(slot: StringName, _catalog: ItemCatalog = null) -> bool:
	var canonical := ItemCatalog.canonical_slot(slot)
	if canonical not in ItemCatalog.SLOTS or get_equipped_instance_id(canonical).is_empty():
		return false
	equipped_instance_ids[String(canonical)] = ""
	# Body keeps `armor` as a synchronized legacy alias. Clear both sides for
	# an intentional unequip; otherwise the compatibility sync would immediately
	# restore the old Armor value into Body.
	if canonical == &"body":
		equipped_instance_ids["armor"] = ""
	_sync_body_alias()
	return true


func get_equipped_instance_id(slot: Variant) -> String:
	var canonical := ItemCatalog.canonical_slot(slot)
	if canonical == &"body":
		var body_id := str(equipped_instance_ids.get("body", ""))
		return body_id if not body_id.is_empty() else str(equipped_instance_ids.get("armor", ""))
	return str(equipped_instance_ids.get(String(canonical), ""))


func record_clear_reward_slot(slot: Variant) -> void:
	var canonical := ItemCatalog.canonical_slot(slot)
	if canonical.is_empty():
		return
	clear_reward_slot_history.append(String(canonical))
	if clear_reward_slot_history.size() > CLEAR_REWARD_SLOT_HISTORY_LIMIT:
		clear_reward_slot_history = clear_reward_slot_history.slice(-CLEAR_REWARD_SLOT_HISTORY_LIMIT)


func _sync_body_alias() -> void:
	var body_id := str(equipped_instance_ids.get("body", ""))
	if body_id.is_empty():
		body_id = str(equipped_instance_ids.get("armor", ""))
		equipped_instance_ids["body"] = body_id
	equipped_instance_ids["armor"] = body_id


func purchase_item(item: ItemInstance, cost: int) -> bool:
	if item == null or cost < 0 or gold < cost or find_item(item.instance_id) != null:
		return false
	gold -= cost
	inventory.append(item.to_dictionary())
	return true


func demon_cloak_price() -> int:
	return DEMON_CLOAK_BASE_PRICE + DEMON_CLOAK_PRICE_STEP * demon_cloak_purchases


func purchase_demon_cloak() -> ItemInstance:
	var price := demon_cloak_price()
	if gold < price:
		return null
	var item := ItemInstance.new()
	item.instance_id = "demon-cloak-%d" % (demon_cloak_purchases + 1)
	item.definition_id = &"demon_cloak"
	item.rarity = &"common"
	item.quality = 1.0
	if not purchase_item(item, price):
		return null
	demon_cloak_purchases += 1
	return item


func add_souls(amount: int) -> void:
	souls = maxi(souls + maxi(amount, 0), 0)


func can_spend_souls(amount: int) -> bool:
	return amount > 0 and souls >= amount


func spend_souls(amount: int) -> bool:
	if not can_spend_souls(amount):
		return false
	souls -= amount
	return true


## The hub flame is the file's starter choice until the player pays for an
## explicit permanent Bind. Temporary run attunements and fusions must not
## replace this identity.
func hub_flame() -> StringName:
	return bound_element if has_bound_element and AspectCatalogScript.is_elemental_flame(bound_element) else starter_flame


func hub_palette() -> String:
	return AspectCatalogScript.palette_for_flame(hub_flame())


func persistent_flame() -> StringName:
	return hub_flame()


func can_bind_element(element: StringName) -> bool:
	return AspectCatalogScript.is_elemental_flame(element)


func bind_element(element: StringName) -> bool:
	if not can_bind_element(element):
		return false
	if has_bound_element and bound_element == element:
		return true
	if not spend_souls(ELEMENT_BIND_SOUL_COST):
		return false
	bound_element = element
	has_bound_element = true
	# palette_name is the durable file-facing identity used by the title/hub
	# presentation. Temporary flame actions never touch it.
	palette_name = AspectCatalogScript.palette_for_flame(element)
	return true


func mastery_level(definition_id: StringName) -> int:
	return clampi(int(family_mastery.get(String(definition_id), 0)), 0, MAX_FAMILY_MASTERY)


func max_fusion_steps(item: ItemInstance) -> int:
	if item == null:
		return 0
	var rarity := item.rarity
	var enhancement := item.enhancement_level
	var steps := 0
	while true:
		if enhancement < MAX_ITEM_ENHANCEMENT:
			enhancement += 1
			steps += 1
		else:
			var next_rarity := ItemCatalog.next_rarity(rarity)
			if next_rarity == &"":
				break
			rarity = next_rarity
			enhancement = 0
			steps += 1
	return steps


func fusion_material_count(target_instance_id: String, catalog: ItemCatalog = null) -> int:
	var target := find_item(target_instance_id)
	if target == null:
		return 0
	var items := catalog if catalog != null else ItemCatalog.new()
	if items.definition_slot(target.definition_id) not in ItemCatalog.SLOTS:
		return 0
	var max_steps := max_fusion_steps(target)
	if max_steps <= 0:
		return 0
	var matches := 0
	for data: Dictionary in inventory:
		var candidate := ItemInstance.from_dictionary(data)
		if candidate.instance_id == target_instance_id:
			continue
		if candidate.definition_id != target.definition_id or candidate.rarity != target.rarity:
			continue
		if candidate.instance_id in equipped_instance_ids.values():
			continue
		matches += 1
	return mini(matches, max_steps)


func fusion_step_cost(rarity: StringName, enhancement_level: int) -> int:
	var rarity_rank: int = int({&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 4}.get(rarity, 0))
	var enhancement := clampi(enhancement_level, 0, MAX_ITEM_ENHANCEMENT)
	# Enhancement steps rise one Soul at a time. The +10 rarity transition is
	# priced at the final cost of that rarity, then the next rarity's +0 step
	# starts ten Souls higher (common +10 -> rare costs 10; rare +0 -> +1 costs 11).
	if enhancement >= MAX_ITEM_ENHANCEMENT:
		return FUSION_START_COST + rarity_rank * FUSION_RARITY_STEP_COST + MAX_ITEM_ENHANCEMENT - 1
	return FUSION_START_COST + rarity_rank * FUSION_RARITY_STEP_COST + enhancement


func fusion_batch_cost(item: ItemInstance, count: int) -> int:
	if item == null or count <= 0:
		return 0
	var total := 0
	var rarity := item.rarity
	var enhancement := item.enhancement_level
	for step in count:
		total += fusion_step_cost(rarity, enhancement)
		if enhancement >= MAX_ITEM_ENHANCEMENT:
			rarity = ItemCatalog.next_rarity(rarity)
			enhancement = 0
		else:
			enhancement += 1
	return total


func fuse_duplicates(target_instance_id: String, count: int, catalog: ItemCatalog = null) -> bool:
	var target := find_item(target_instance_id)
	if target == null or count <= 0:
		return false
	var items := catalog if catalog != null else ItemCatalog.new()
	var amount := mini(count, fusion_material_count(target_instance_id, items))
	if amount <= 0:
		return false
	var cost := fusion_batch_cost(target, amount)
	if souls < cost:
		return false
	var material_indices: Array[int] = []
	for index in inventory.size():
		var candidate := ItemInstance.from_dictionary(inventory[index])
		if candidate.instance_id == target_instance_id:
			continue
		if candidate.definition_id != target.definition_id or candidate.rarity != target.rarity:
			continue
		if candidate.instance_id in equipped_instance_ids.values():
			continue
		material_indices.append(index)
		if material_indices.size() >= amount:
			break
	if material_indices.size() < amount:
		return false
	var working := target
	for step in amount:
		if working.enhancement_level >= MAX_ITEM_ENHANCEMENT:
			working.rarity = ItemCatalog.next_rarity(working.rarity)
			working.enhancement_level = 0
		else:
			working.enhancement_level += 1
	material_indices.sort()
	for index in range(material_indices.size() - 1, -1, -1):
		inventory.remove_at(material_indices[index])
	var target_index := -1
	for index in inventory.size():
		if str(inventory[index].get("instance_id", "")) == target_instance_id:
			target_index = index
			break
	if target_index < 0:
		return false
	inventory[target_index] = working.to_dictionary()
	souls -= cost
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
	return {"xp": gained, "levels": levels_gained, "points": points_gained, "level": level}


func allocate_stat(stat_name: StringName, amount: int = 1) -> bool:
	var points := mini(maxi(amount, 0), unspent_stat_points)
	if points <= 0:
		return false
	match stat_name:
		&"VIT": allocated_vit += points
		&"STR": allocated_str += points
		&"DEF": allocated_def += points
		&"AGI", &"SPD": allocated_agi += points
		&"INT": allocated_int += points
		&"MND": allocated_mnd += points
		_:
			return false
	unspent_stat_points -= points
	return true


func respec_cost() -> int:
	return 0 if level <= 5 else 50 + (level - 5) * 10


func reset_allocated_stats() -> int:
	var refunded := allocated_vit + allocated_str + allocated_def + allocated_agi + allocated_int + allocated_mnd
	var cost := respec_cost()
	if refunded <= 0 or gold < cost:
		return 0
	gold -= cost
	allocated_vit = 0
	allocated_str = 0
	allocated_def = 0
	allocated_agi = 0
	allocated_int = 0
	allocated_mnd = 0
	unspent_stat_points += refunded
	return refunded


func to_dictionary() -> Dictionary:
	_sync_body_alias()
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"has_started": has_started,
		"open_hub_on_load": open_hub_on_load,
		"pending_route": pending_route,
		"player_name": normalize_player_name(player_name),
		"starter_flame": String(starter_flame),
		"palette_name": palette_name,
		"bound_element": String(bound_element),
		"has_bound_element": has_bound_element,
		"allocation_profile": allocation_profile,
		"level": level,
		"xp": xp,
		"unspent_stat_points": unspent_stat_points,
		"base_vit": base_vit,
		"base_str": base_str,
		"base_def": base_def,
		"base_agi": base_agi,
		"base_int": base_int,
		"base_mnd": base_mnd,
		"base_spd": base_agi,
		"allocated_vit": allocated_vit,
		"allocated_str": allocated_str,
		"allocated_def": allocated_def,
		"allocated_agi": allocated_agi,
		"allocated_int": allocated_int,
		"allocated_mnd": allocated_mnd,
		"allocated_spd": allocated_agi,
		"gold": gold,
		"souls": souls,
		"starter_soul_gift_claimed": starter_soul_gift_claimed,
		"demon_cloak_purchases": demon_cloak_purchases,
		"inventory": inventory.duplicate(true),
		"equipped_instance_ids": equipped_instance_ids.duplicate(true),
		"family_mastery": family_mastery.duplicate(true),
		"next_item_sequence": next_item_sequence,
		"completed_runs": completed_runs,
		"last_clear_score": last_clear_score,
		"difficulty_rank": difficulty_rank,
		"last_run_grade": last_run_grade,
		"clear_reward_slot_history": clear_reward_slot_history.duplicate(),
	}


func load_dictionary(data: Dictionary) -> void:
	var saved_schema := int(data.get("schema_version", 0))
	# Chroma changes the meaning of file identity. Older files are intentionally
	# allowed to die out instead of being guessed into the new model.
	if saved_schema not in [CURRENT_SCHEMA_VERSION, LEGACY_DEMON_CLOAK_SCHEMA_VERSION, LEGACY_SIX_STAT_SCHEMA_VERSION, LEGACY_SPEED_SCHEMA_VERSION]:
		schema_version = CURRENT_SCHEMA_VERSION
		return
	var is_schema_8 := saved_schema == LEGACY_SPEED_SCHEMA_VERSION
	schema_version = CURRENT_SCHEMA_VERSION
	has_started = bool(data.get("has_started", false))
	open_hub_on_load = bool(data.get("open_hub_on_load", false))
	pending_route = str(data.get("pending_route", "hub" if open_hub_on_load else "title"))
	if pending_route not in ["title", "hub", "run"]:
		pending_route = "title"
	player_name = normalize_player_name(str(data.get("player_name", DEFAULT_PLAYER_NAME)))
	var saved_flame := StringName(str(data.get("starter_flame", "fire")))
	starter_flame = saved_flame if AspectCatalogScript.is_starter_flame(saved_flame) else &"fire"
	palette_name = str(data.get("palette_name", "blue"))
	var saved_bound := StringName(str(data.get("bound_element", "")))
	has_bound_element = bool(data.get("has_bound_element", false)) and AspectCatalogScript.is_elemental_flame(saved_bound)
	bound_element = saved_bound if has_bound_element else &""
	if has_bound_element:
		palette_name = AspectCatalogScript.palette_for_flame(bound_element)
	allocation_profile = int(data.get("allocation_profile", 0))
	level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	xp = maxi(int(data.get("xp", 0)), 0)
	unspent_stat_points = maxi(int(data.get("unspent_stat_points", 0)), 0)
	base_vit = maxi(int(data.get("base_vit", 3)), 0)
	base_str = maxi(int(data.get("base_str", 2)), 0)
	base_def = maxi(int(data.get("base_def", 2)), 0)
	base_agi = maxi(int(data.get("base_spd", 1) if is_schema_8 else data.get("base_agi", data.get("base_spd", 1))), 0)
	base_int = maxi(int(data.get("base_int", 1)), 0)
	base_mnd = maxi(int(data.get("base_mnd", 1)), 0)
	allocated_vit = maxi(int(data.get("allocated_vit", 0)), 0)
	allocated_str = maxi(int(data.get("allocated_str", 0)), 0)
	allocated_def = maxi(int(data.get("allocated_def", 0)), 0)
	allocated_agi = maxi(int(data.get("allocated_spd", 0) if is_schema_8 else data.get("allocated_agi", data.get("allocated_spd", 0))), 0)
	allocated_int = maxi(int(data.get("allocated_int", 0)), 0)
	allocated_mnd = maxi(int(data.get("allocated_mnd", 0)), 0)
	gold = maxi(int(data.get("gold", 0)), 0)
	souls = maxi(int(data.get("souls", 0)), 0)
	starter_soul_gift_claimed = bool(data.get("starter_soul_gift_claimed", false))
	demon_cloak_purchases = maxi(int(data.get("demon_cloak_purchases", 0)), 0)
	var saved_inventory: Variant = data.get("inventory", [])
	inventory.assign(saved_inventory if saved_inventory is Array else [])
	equipped_instance_ids = {"weapon": "", "head": "", "body": "", "armor": "", "arm": "", "shield": "", "accessory": ""}
	var saved_equipment: Variant = data.get("equipped_instance_ids", {})
	if saved_equipment is Dictionary:
		for slot: StringName in ItemCatalog.SLOTS:
			if slot == &"body":
				continue
			equipped_instance_ids[String(slot)] = str(saved_equipment.get(String(slot), ""))
		var saved_body := str(saved_equipment.get("body", ""))
		if saved_body.is_empty():
			saved_body = str(saved_equipment.get("armor", ""))
		equipped_instance_ids["body"] = saved_body
	_sync_body_alias()
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
	clear_reward_slot_history.clear()
	var saved_reward_history: Variant = data.get("clear_reward_slot_history", [])
	if saved_reward_history is Array:
		for history_slot: Variant in saved_reward_history:
			var canonical_history_slot := ItemCatalog.canonical_slot(history_slot)
			if canonical_history_slot in ItemCatalog.SLOTS:
				clear_reward_slot_history.append(String(canonical_history_slot))
		if clear_reward_slot_history.size() > CLEAR_REWARD_SLOT_HISTORY_LIMIT:
			clear_reward_slot_history = clear_reward_slot_history.slice(-CLEAR_REWARD_SLOT_HISTORY_LIMIT)
	ensure_starter_items()
