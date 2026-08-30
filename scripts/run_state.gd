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
	if not shop_stock.is_empty():
		return
	var level := profile.level if profile != null else 1
	var catalog := ItemCatalog.new()
	for slot_index in ItemCatalog.SLOTS.size():
		var slot := ItemCatalog.SLOTS[slot_index]
		var item := catalog.generate_item(slot, dungeon_seed + slot_index * 7919, level, &"common", false, &"shop", level)
		if item.definition_id.is_empty():
			continue
		item.instance_id = "shop-%s-basic-%s" % [run_id, String(slot)]
		shop_stock.append(_shop_entry(catalog, item, slot, roundi(catalog.price(item) * 2.5)))
	var premium_slot := ItemCatalog.SLOTS[posmod(dungeon_seed, ItemCatalog.SLOTS.size())]
	var premium := catalog.generate_item(premium_slot, dungeon_seed ^ 0x5A17, level, &"rare", true, &"shop", level)
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
