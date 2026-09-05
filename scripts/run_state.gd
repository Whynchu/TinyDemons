extends RefCounted
class_name RunState

var run_id := ""
var dungeon_seed := 0
var active := false
var settled := false
var result: StringName = &""
var shop_stock: Array[Dictionary] = []
var difficulty_bonus := 0
var timer_started := false
var elapsed_time := 0.0
var starting_health := 1.0
var damage_taken := 0.0
var movement_time := 0.0
var combat_time := 0.0
var combat_movement_time := 0.0
var attack_count := 0
var attack2_count := 0
var attack_hit_count := 0
var attack2_hit_count := 0
var attack_swing_hit_count := 0
var roll_count := 0
var block_count := 0
var chests_opened := 0
var encountered_enemy_count := 0
var enemies_killed := 0
var total_enemies := 0
var registered_enemy_rooms: Dictionary = {}
var enemy_attack_attempts := 0
var dodge_count := 0
var attack_input_count := 0
var roll_input_count := 0
var wasted_attack_inputs := 0
var wasted_roll_inputs := 0
## Map discovery is based on physically entering rooms. It is deliberately
## separate from room objective completion: a player may discover every room
## without clearing every encounter or solving every room objective.
var map_discovered_rooms: Dictionary = {}
var map_room_count := 0
## Snapshot of rooms whose local objective has been completed. The graph owns
## the full room set; this dictionary only records the completed members of it.
var completed_run_rooms: Dictionary = {}
var run_room_count := 0
## Successful style events are retained as backend telemetry. The evaluator
## turns these into capped, flexible style points rather than rewarding raw
## button presses or attack spam.
var style_actions: Dictionary = {}
var max_combo_count := 0
var combo_hit_count := 0
var clear_summary: Dictionary = {}
## Reward-source telemetry is intentionally run-scoped. It gives balance work a
## stable record of what was offered and why without adding persistence fields
## to ItemInstance or changing the player-facing result card.
var gear_reward_telemetry: Array[Dictionary] = []


func to_dictionary() -> Dictionary:
	return {
		"run_id": run_id, "dungeon_seed": dungeon_seed, "active": active,
		"settled": settled, "result": String(result), "shop_stock": shop_stock.duplicate(true),
		"difficulty_bonus": difficulty_bonus, "timer_started": timer_started,
		"elapsed_time": elapsed_time, "starting_health": starting_health,
		"damage_taken": damage_taken, "movement_time": movement_time,
		"combat_time": combat_time, "combat_movement_time": combat_movement_time,
		"attack_count": attack_count, "attack2_count": attack2_count,
		"attack_hit_count": attack_hit_count, "attack2_hit_count": attack2_hit_count,
		"attack_swing_hit_count": attack_swing_hit_count, "roll_count": roll_count,
		"block_count": block_count, "chests_opened": chests_opened,
		"encountered_enemy_count": encountered_enemy_count, "enemies_killed": enemies_killed,
		"total_enemies": total_enemies, "registered_enemy_rooms": registered_enemy_rooms.duplicate(true),
		"enemy_attack_attempts": enemy_attack_attempts, "dodge_count": dodge_count,
		"attack_input_count": attack_input_count, "roll_input_count": roll_input_count,
		"wasted_attack_inputs": wasted_attack_inputs, "wasted_roll_inputs": wasted_roll_inputs,
		"map_discovered_rooms": map_discovered_rooms.duplicate(true), "map_room_count": map_room_count,
		"completed_run_rooms": completed_run_rooms.duplicate(true), "run_room_count": run_room_count,
		"style_actions": style_actions.duplicate(true), "max_combo_count": max_combo_count,
		"combo_hit_count": combo_hit_count, "clear_summary": clear_summary.duplicate(true),
		"gear_reward_telemetry": gear_reward_telemetry.duplicate(true),
	}


func restore_from_dictionary(data: Dictionary) -> bool:
	if str(data.get("run_id", "")).is_empty() or not bool(data.get("active", false)):
		return false
	run_id = str(data.get("run_id", ""))
	dungeon_seed = int(data.get("dungeon_seed", 0))
	active = true
	settled = bool(data.get("settled", false))
	result = StringName(str(data.get("result", "")))
	shop_stock = _dictionary_array(data.get("shop_stock", []))
	difficulty_bonus = maxi(int(data.get("difficulty_bonus", 0)), 0)
	timer_started = bool(data.get("timer_started", false))
	elapsed_time = maxf(float(data.get("elapsed_time", 0.0)), 0.0)
	starting_health = maxf(float(data.get("starting_health", 1.0)), 1.0)
	damage_taken = maxf(float(data.get("damage_taken", 0.0)), 0.0)
	movement_time = maxf(float(data.get("movement_time", 0.0)), 0.0)
	combat_time = maxf(float(data.get("combat_time", 0.0)), 0.0)
	combat_movement_time = maxf(float(data.get("combat_movement_time", 0.0)), 0.0)
	attack_count = maxi(int(data.get("attack_count", 0)), 0)
	attack2_count = maxi(int(data.get("attack2_count", 0)), 0)
	attack_hit_count = maxi(int(data.get("attack_hit_count", 0)), 0)
	attack2_hit_count = maxi(int(data.get("attack2_hit_count", 0)), 0)
	attack_swing_hit_count = maxi(int(data.get("attack_swing_hit_count", 0)), 0)
	roll_count = maxi(int(data.get("roll_count", 0)), 0)
	block_count = maxi(int(data.get("block_count", 0)), 0)
	chests_opened = maxi(int(data.get("chests_opened", 0)), 0)
	encountered_enemy_count = maxi(int(data.get("encountered_enemy_count", 0)), 0)
	enemies_killed = maxi(int(data.get("enemies_killed", 0)), 0)
	total_enemies = maxi(int(data.get("total_enemies", 0)), enemies_killed)
	registered_enemy_rooms = _string_name_dictionary(data.get("registered_enemy_rooms", {}))
	enemy_attack_attempts = maxi(int(data.get("enemy_attack_attempts", 0)), 0)
	dodge_count = maxi(int(data.get("dodge_count", 0)), 0)
	attack_input_count = maxi(int(data.get("attack_input_count", 0)), 0)
	roll_input_count = maxi(int(data.get("roll_input_count", 0)), 0)
	wasted_attack_inputs = maxi(int(data.get("wasted_attack_inputs", 0)), 0)
	wasted_roll_inputs = maxi(int(data.get("wasted_roll_inputs", 0)), 0)
	map_discovered_rooms = _string_name_dictionary(data.get("map_discovered_rooms", {}))
	map_room_count = maxi(int(data.get("map_room_count", 0)), map_discovered_rooms.size())
	completed_run_rooms = _string_name_dictionary(data.get("completed_run_rooms", {}))
	run_room_count = maxi(int(data.get("run_room_count", 0)), completed_run_rooms.size())
	style_actions = _string_name_dictionary(data.get("style_actions", {}))
	max_combo_count = maxi(int(data.get("max_combo_count", 0)), 0)
	combo_hit_count = maxi(int(data.get("combo_hit_count", 0)), 0)
	clear_summary = _dictionary(data.get("clear_summary", {}))
	gear_reward_telemetry = _dictionary_array(data.get("gear_reward_telemetry", []))
	return not settled


static func _dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}


static func _string_name_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			result[StringName(str(key))] = (value as Dictionary)[key]
	return result


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result


func begin(generation_seed: int, new_difficulty_bonus: int = 0, maximum_health: float = 1.0) -> void:
	dungeon_seed = generation_seed
	run_id = "%d-%d" % [Time.get_unix_time_from_system(), generation_seed]
	active = true
	settled = false
	result = &""
	shop_stock.clear()
	difficulty_bonus = maxi(new_difficulty_bonus, 0)
	timer_started = false
	elapsed_time = 0.0
	starting_health = maxf(maximum_health, 1.0)
	damage_taken = 0.0
	movement_time = 0.0
	combat_time = 0.0
	combat_movement_time = 0.0
	attack_count = 0
	attack2_count = 0
	attack_hit_count = 0
	attack2_hit_count = 0
	attack_swing_hit_count = 0
	roll_count = 0
	block_count = 0
	chests_opened = 0
	encountered_enemy_count = 0
	enemies_killed = 0
	total_enemies = 0
	registered_enemy_rooms.clear()
	enemy_attack_attempts = 0
	dodge_count = 0
	attack_input_count = 0
	roll_input_count = 0
	wasted_attack_inputs = 0
	wasted_roll_inputs = 0
	map_discovered_rooms.clear()
	map_room_count = 0
	completed_run_rooms.clear()
	run_room_count = 0
	style_actions.clear()
	max_combo_count = 0
	combo_hit_count = 0
	clear_summary.clear()
	gear_reward_telemetry.clear()


func start_timer() -> void:
	timer_started = true


func tick(delta: float) -> void:
	if active and timer_started:
		elapsed_time += maxf(delta, 0.0)


func record_damage(amount: float) -> void:
	damage_taken += maxf(amount, 0.0)


func record_movement(delta: float) -> void:
	movement_time += maxf(delta, 0.0)


func record_combat_time(delta: float, moving: bool) -> void:
	combat_time += maxf(delta, 0.0)
	if moving:
		combat_movement_time += maxf(delta, 0.0)


func record_attack(variant: int, in_combat: bool) -> void:
	if not in_combat:
		return
	attack_count += 1
	if variant == 2:
		attack2_count += 1


func record_attack_hits(variant: int, target_count: int) -> void:
	attack_hit_count += maxi(target_count, 0)
	if target_count > 0:
		attack_swing_hit_count += 1
	if variant == 2:
		attack2_hit_count += maxi(target_count, 0)


func record_roll(in_combat: bool) -> void:
	if not in_combat:
		return
	roll_count += 1


func record_block() -> void:
	block_count += 1


func record_chest_open() -> void:
	chests_opened += 1


func record_enemy_encounter() -> void:
	encountered_enemy_count += 1


func record_enemy_kill() -> void:
	enemies_killed += 1


func register_room_enemies(room_id: StringName, count: int) -> void:
	if room_id.is_empty() or registered_enemy_rooms.has(room_id):
		return
	registered_enemy_rooms[room_id] = true
	total_enemies += maxi(count, 0)


func set_total_enemies(count: int) -> void:
	total_enemies = maxi(count, enemies_killed)


func record_action_input(action: StringName, accepted: bool) -> void:
	if action == &"attack":
		attack_input_count += 1
		if not accepted:
			wasted_attack_inputs += 1
	elif action == &"roll":
		roll_input_count += 1
		if not accepted:
			wasted_roll_inputs += 1


func record_map_room_entry(room_id: StringName) -> void:
	if not room_id.is_empty():
		map_discovered_rooms[room_id] = true


func record_room_completion(room_id: StringName) -> void:
	if not room_id.is_empty():
		completed_run_rooms[room_id] = true


func set_map_room_count(count: int) -> void:
	map_room_count = maxi(count, map_discovered_rooms.size())


func set_run_room_count(count: int) -> void:
	run_room_count = maxi(count, completed_run_rooms.size())


func record_style_action(action: StringName) -> void:
	if action.is_empty():
		return
	style_actions[action] = int(style_actions.get(action, 0)) + 1


func record_combo_hit(combo_count: int) -> void:
	combo_hit_count += 1
	max_combo_count = maxi(max_combo_count, combo_count)


func map_completion_ratio() -> float:
	if map_room_count <= 0:
		return 1.0
	return clampf(float(map_discovered_rooms.size()) / float(map_room_count), 0.0, 1.0)


func room_completion_ratio() -> float:
	if run_room_count <= 0:
		return 1.0
	return clampf(float(completed_run_rooms.size()) / float(run_room_count), 0.0, 1.0)


func total_wasted_inputs() -> int:
	return wasted_attack_inputs + wasted_roll_inputs


func total_action_inputs() -> int:
	return attack_input_count + roll_input_count


func record_enemy_attack_attempt() -> void:
	enemy_attack_attempts += 1


func record_dodge() -> void:
	dodge_count += 1


func record_gear_reward(source: StringName, item: ItemInstance, run_rank: int, player_level: int, score: int = -1, grade: String = "", slot_was_empty: bool = false, was_equipped: bool = false, action: StringName = &"generated") -> void:
	if item == null or item.definition_id.is_empty():
		return
	var catalog := ItemCatalog.new()
	var slot := catalog.definition_slot(item.definition_id)
	gear_reward_telemetry.append({
		"source": String(source),
		"slot": String(slot),
		"definition_id": String(item.definition_id),
		"rarity": String(item.rarity),
		"run_rank": maxi(run_rank, 1),
		"player_level": maxi(player_level, 1),
		"score": score,
		"grade": grade.to_upper(),
		"slot_was_empty": slot_was_empty,
		"was_equipped": was_equipped,
		"action": String(action),
	})


func ensure_shop_stock(profile: PlayerProfile) -> void:
	var level := profile.level if profile != null else 1
	var catalog := ItemCatalog.new()
	var had_stock := not shop_stock.is_empty()
	_ensure_basic_shop_stock(catalog)
	if had_stock:
		return
	for slot_index in ItemCatalog.SLOTS.size():
		var slot := ItemCatalog.SLOTS[slot_index]
		# Basic entries are guaranteed above; the variable common roll should not
		# duplicate them, so keep this additional stock on specialized alternatives.
		var item := catalog.generate_item(slot, dungeon_seed + slot_index * 7919, level, &"common", true, &"shop", level)
		if item.definition_id.is_empty():
			continue
		item.instance_id = "shop-%s-common-%d-%s" % [run_id, slot_index, String(slot)]
		shop_stock.append(_shop_entry(catalog, item, slot, roundi(catalog.price(item) * 2.5)))
	var premium_slot := ItemCatalog.SLOTS[posmod(dungeon_seed, ItemCatalog.SLOTS.size())]
	# The Cloaked Demon's premium slot favors its rare floor but keeps + gear
	# uncommon: a ++/+++ find here should be a memorable luxury, not a routine.
	var premium := catalog.generate_item(premium_slot, dungeon_seed ^ 0x5A17, level, &"rare", true, &"shop", level, 0.35)
	if not premium.definition_id.is_empty():
		premium.instance_id = "shop-%s-premium" % run_id
		shop_stock.append(_shop_entry(catalog, premium, premium_slot, roundi(catalog.price(premium) * 2.5)))
	if profile != null:
		var cloak := ItemInstance.new()
		cloak.definition_id = &"demon_cloak"
		cloak.rarity = &"common"
		cloak.quality = 1.0
		var cloak_entry := _shop_entry(catalog, cloak, &"body", profile.demon_cloak_price())
		cloak_entry["permanent"] = true
		shop_stock.append(cloak_entry)


func _ensure_basic_shop_stock(catalog: ItemCatalog) -> void:
	var basic_ids := {
		&"weapon": &"basic_sword",
		&"head": &"basic_hood",
		&"body": &"basic_tunic",
		&"arm": &"basic_wraps",
		&"shield": &"basic_shield",
		&"accessory": &"basic_charm",
	}
	var plain_ids := {
		&"weapon": &"plain_blade",
		&"head": &"plain_hood",
		&"body": &"plain_tunic",
		&"arm": &"plain_wraps",
		&"shield": &"plain_shield",
		&"accessory": &"plain_ring",
	}
	for slot: StringName in ItemCatalog.SLOTS:
		var definition_id: StringName = basic_ids[slot]
		var already_present := false
		for entry_index in shop_stock.size():
			var entry := shop_stock[entry_index]
			var existing := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
			if existing.definition_id == plain_ids[slot]:
				existing.definition_id = definition_id
				existing.rarity = &"common"
				existing.quality = 1.0
				entry["item"] = existing.to_dictionary()
				entry["price"] = maxi(1, roundi(catalog.price(existing) * 2.5))
				shop_stock[entry_index] = entry
				already_present = true
				break
			if existing.definition_id == definition_id:
				already_present = true
				break
		if already_present:
			continue
		var item := ItemInstance.new()
		item.definition_id = definition_id
		item.instance_id = "shop-%s-basic-%s" % [run_id, String(slot)]
		item.rarity = &"common"
		item.quality = 1.0
		var price := maxi(1, roundi(catalog.price(item) * 2.5))
		shop_stock.append(_shop_entry(catalog, item, slot, price))


func _shop_entry(catalog: ItemCatalog, item: ItemInstance, slot: StringName, shop_price: int) -> Dictionary:
	var definition := catalog.definition_data(item.definition_id)
	return {
		"item": item.to_dictionary(),
		"price": shop_price,
		"sold": false,
		"source": "shop",
		"slot": String(slot),
		"role": str(definition.get("role", "stat")),
		"primary_stat": str(definition.get("primary_stat", "")),
		"description": str(definition.get("player_description", "")),
	}


func mark_settled(run_result: StringName) -> bool:
	if settled:
		return false
	settled = true
	active = false
	result = run_result
	return true
