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
var visited_rooms: Dictionary = {}
var explorable_room_count := 0
var clear_summary: Dictionary = {}


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
	visited_rooms.clear()
	explorable_room_count = 0
	clear_summary.clear()


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


func record_room_visited(room_id: StringName) -> void:
	if not room_id.is_empty():
		visited_rooms[room_id] = true


func set_explorable_room_count(count: int) -> void:
	explorable_room_count = maxi(count, visited_rooms.size())


func total_wasted_inputs() -> int:
	return wasted_attack_inputs + wasted_roll_inputs


func total_action_inputs() -> int:
	return attack_input_count + roll_input_count


func record_enemy_attack_attempt() -> void:
	enemy_attack_attempts += 1


func record_dodge() -> void:
	dodge_count += 1


func ensure_shop_stock(level: int) -> void:
	if not shop_stock.is_empty():
		return
	var catalog := ItemCatalog.new()
	for slot_index in ItemCatalog.SLOTS.size():
		var slot := ItemCatalog.SLOTS[slot_index]
		var item := catalog.generate_item(slot, dungeon_seed + slot_index * 7919, level, &"common")
		item.instance_id = "shop-%s-basic-%s" % [run_id, String(slot)]
		shop_stock.append({"item": item.to_dictionary(), "price": roundi(catalog.price(item) * 2.5), "sold": false})
	var premium_slot := ItemCatalog.SLOTS[posmod(dungeon_seed, ItemCatalog.SLOTS.size())]
	var premium := catalog.generate_item(premium_slot, dungeon_seed ^ 0x5A17, level, &"rare")
	premium.instance_id = "shop-%s-premium" % run_id
	shop_stock.append({"item": premium.to_dictionary(), "price": roundi(catalog.price(premium) * 2.5), "sold": false})


func mark_settled(run_result: StringName) -> bool:
	if settled:
		return false
	settled = true
	active = false
	result = run_result
	return true
