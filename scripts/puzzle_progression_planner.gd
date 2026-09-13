extends RefCounted
class_name PuzzleProgressionPlanner

## Generated progression policy: gate metadata is checked as a route contract,
## not inferred from presentation pixels.

static func validate(plan) -> Array[String]:
	var errors: Array[String] = []
	if plan == null:
		errors.append("R7 progression plan is missing")
		return errors
	var orb_count := 0
	var fire_count := 0
	var special_count := 0
	var boss_id: StringName = &""
	for room in plan.rooms:
		orb_count += 1 if room.room_type == DungeonGraph.ROOM_ORB else 0
		fire_count += 1 if room.room_type == DungeonGraph.ROOM_FIRE else 0
		special_count += 1 if room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY else 0
		if room.room_type == DungeonGraph.ROOM_BOSS:
			boss_id = room.id
	if orb_count < 2:
		errors.append("R7 progression requires two Orb Rooms")
	if fire_count < 2:
		errors.append("R7 progression requires two ingredient Fire Rooms")
	if special_count < 2:
		errors.append("R7 progression requires two Special Rooms")
	if boss_id.is_empty():
		errors.append("R7 progression requires a Boss continuation")
	var fusion_gate_count := 0
	for gate in plan.gates:
		if gate.source_region == "unknown" or gate.destination_region == "unknown":
			errors.append("R7 gate %s:%s has an unclassified route region" % [gate.connection.source_room_id, gate.connection.exit_socket])
		if gate.mandatory and _region_rank(gate.destination_region) < _region_rank(gate.source_region):
			errors.append("R7 mandatory gate %s:%s moves backward from %s to %s" % [gate.connection.source_room_id, gate.connection.exit_socket, gate.source_region, gate.destination_region])
		if gate.connection.resolved_gate_type() == DungeonGraph.GATE_ENTRANCE_ORB and gate.mandatory:
			fusion_gate_count += 1
		if not gate.mandatory or gate.connection.resolved_gate_type() != DungeonGraph.GATE_ENTRANCE_ORB:
			continue
		if gate.prerequisite_room_ids.is_empty():
			errors.append("mandatory entrance-Orb gate %s:%s has no curriculum prerequisite" % [gate.connection.source_room_id, gate.connection.exit_socket])
	if fusion_gate_count != 1:
		errors.append("R7 progression requires exactly one mandatory fusion gate, got %d" % fusion_gate_count)
	return errors


static func validate_risk_reward(plan) -> Array[String]:
	var errors: Array[String] = []
	if plan == null:
		errors.append("R6+ risk/reward progression plan is missing")
		return errors
	var primary_flames: Dictionary = {}
	var boss_found := false
	var vault_count := 0
	var safe_found := false
	var risk_found := false
	for room in plan.rooms:
		if room.route_role == DungeonGraph.ROUTE_PRIMARY_FLAME and room.fire_flame in [&"fire", &"water", &"electric"]:
			primary_flames[room.fire_flame] = true
		if room.room_type == DungeonGraph.ROOM_BOSS:
			boss_found = true
		if room.route_role == DungeonGraph.ROUTE_ELITE_REWARD:
			vault_count += 1
			if room.encounter_tier != DungeonGraph.ENCOUNTER_ELITE or room.reward_tier != DungeonGraph.REWARD_VAULT:
				errors.append("R6+ elite reward room has mismatched policy: %s" % room.id)
	for flame in [&"fire", &"water", &"electric"]:
		if not primary_flames.has(flame):
			errors.append("R6+ progression plan is missing %s" % flame)
	for connection in plan.connections:
		if connection.route_role == DungeonGraph.ROUTE_SAFE:
			safe_found = true
		elif connection.route_role == DungeonGraph.ROUTE_RISK_SHORTCUT:
			risk_found = true
		if connection.route_role == &"main" or connection.route_role == &"key_progression":
			if connection.resolved_gate_type() != DungeonGraph.GATE_NONE:
				errors.append("R6+ critical connection remains gated: %s:%s" % [connection.source_room_id, connection.exit_socket])
		if connection.route_role == DungeonGraph.ROUTE_ELEMENTAL_VAULT and connection.resolved_gate_type() != DungeonGraph.GATE_ENTRANCE_ORB:
			errors.append("R6+ elemental vault is missing its Orb door: %s:%s" % [connection.source_room_id, connection.exit_socket])
	if not boss_found:
		errors.append("R6+ progression plan is missing a Boss")
	if vault_count < 1 or vault_count > 2:
		errors.append("R6+ progression plan expects one or two vault rooms, got %d" % vault_count)
	if not safe_found or not risk_found or plan.route_choice_source_room_id.is_empty() or plan.route_choice_rejoin_room_id.is_empty():
		errors.append("R6+ progression plan is missing a safe/risk route choice")
	if plan.safe_route_length <= plan.risk_route_length + 1:
		errors.append("R6+ risk route is not at least two transitions shorter")
	return errors


static func _region_rank(region: String) -> int:
	match region:
		"opening": return 0
		"first_state": return 1
		"alternate_flame": return 2
		"boss_approach": return 3
	return -1
