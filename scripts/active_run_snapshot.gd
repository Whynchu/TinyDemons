extends RefCounted
class_name ActiveRunSnapshot

## JSON-safe boundary for a recoverable in-progress run. The snapshot is
## intentionally separate from PlayerProfile: profile saves are permanent
## progression, while this record is disposable runtime recovery state.
const SCHEMA_VERSION := 1
const FORMAT := "tiny-demons-active-run"


static func create(root: Object) -> Dictionary:
	var profile := root.get("player_profile") as PlayerProfile
	var run := root.get("run_state") as RunState
	var map_controller := root.get("dungeon_map_controller") as Node
	var map_state: Variant = map_controller.get("state") if map_controller != null else null
	var room_controller := root.get("room_controller") as RoomController
	var health := root.get("player_health_component") as HealthComponent
	var chroma := root.get("player_chroma_component") as Node
	if profile == null or run == null or not run.active or run.settled:
		return {}
	var room_states: Dictionary = room_controller.room_states.duplicate(true) if room_controller != null else {}
	var map_dictionary: Dictionary = map_state.call("to_dictionary") as Dictionary if map_state != null and map_state.has_method("to_dictionary") else {}
	var snapshot := {
		"format": FORMAT,
		"schema_version": SCHEMA_VERSION,
		"profile_slot": ProfileSaveService.current_slot(),
		"profile_identity": {
			"player_name": profile.player_name,
			"profile_schema": profile.schema_version,
			"has_started": profile.has_started,
		},
		"created_at": Time.get_unix_time_from_system(),
		"run_state": run.to_dictionary(),
		"dungeon_seed": int(root.get("current_dungeon_seed")),
		"run_rank": maxi(profile.difficulty_rank, 1),
		"current_room_id": String(root.get("current_room_id")),
		"current_room_type": String(root.get("current_room_type")),
		"current_room_depth": int(root.get("current_room_depth")),
		"arrival_socket_id": String(room_controller.arrival_socket_id) if room_controller != null else "",
		"room_states": room_states,
		"map_state": map_dictionary,
		"player_health": float(health.current_health) if health != null else 1.0,
		"player_chroma_state": {
			"current_aspect": int(chroma.get("current_aspect")) if chroma != null else 0,
			"current_chroma": int(chroma.get("current_chroma")) if chroma != null else 0,
			"bound_aspect": int(chroma.get("bound_aspect")) if chroma != null else 0,
		},
		"player_facing_left": bool(root.get("last_player_facing_left")),
		"starter_flame_attuned_this_run": bool(root.get("starter_flame_attuned_this_run")),
	}
	return normalize(snapshot)


static func validate(data: Dictionary, expected_slot: int = -1) -> bool:
	if str(data.get("format", "")) != FORMAT or int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	var slot := int(data.get("profile_slot", -1))
	if slot < 0 or slot >= ProfileSaveService.SLOT_COUNT or (expected_slot >= 0 and slot != expected_slot):
		return false
	var identity: Variant = data.get("profile_identity", {})
	var run_data: Variant = data.get("run_state", {})
	var room_states: Variant = data.get("room_states", {})
	var map_state: Variant = data.get("map_state", {})
	if not identity is Dictionary or not run_data is Dictionary or not room_states is Dictionary or not map_state is Dictionary:
		return false
	var run_dictionary := run_data as Dictionary
	var map_dictionary := map_state as Dictionary
	var current_room_id := str(data.get("current_room_id", ""))
	if str(run_dictionary.get("run_id", "")).is_empty() or not bool(run_dictionary.get("active", false)) or bool(run_dictionary.get("settled", false)):
		return false
	if int(run_dictionary.get("dungeon_seed", data.get("dungeon_seed", 0))) != int(data.get("dungeon_seed", 0)):
		return false
	if current_room_id.is_empty() or str(data.get("current_room_type", "")).is_empty() or int(data.get("current_room_depth", -1)) < 0:
		return false
	if not (identity as Dictionary).has("player_name") or not (identity as Dictionary).has("profile_schema") or not bool((identity as Dictionary).get("has_started", false)):
		return false
	var map_room_id := str(map_dictionary.get("current_room_id", ""))
	if not map_room_id.is_empty() and map_room_id != current_room_id:
		return false
	for room_state in (room_states as Dictionary).values():
		if not room_state is Dictionary:
			return false
	if not map_dictionary.has("discovered_rooms") or not map_dictionary.has("completed_rooms"):
		return false
	return true


static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value.keys():
			result[str(key)] = normalize(value[key])
		return result
	if value is Array:
		var result_array: Array = []
		for entry in value:
			result_array.append(normalize(entry))
		return result_array
	if value is Vector2:
		return {"__td_type": "Vector2", "x": value.x, "y": value.y}
	if value is Vector2i:
		return {"__td_type": "Vector2i", "x": value.x, "y": value.y}
	if value is StringName:
		return String(value)
	return value


static func denormalize(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary := value as Dictionary
		var type_name := str(dictionary.get("__td_type", ""))
		if type_name == "Vector2":
			return Vector2(float(dictionary.get("x", 0.0)), float(dictionary.get("y", 0.0)))
		if type_name == "Vector2i":
			return Vector2i(int(dictionary.get("x", 0)), int(dictionary.get("y", 0)))
		var result := {}
		for key in dictionary.keys():
			result[key] = denormalize(dictionary[key])
		return result
	if value is Array:
		var result_array: Array = []
		for entry in value:
			result_array.append(denormalize(entry))
		return result_array
	return value


static func room_states_from_snapshot(value: Variant) -> Dictionary:
	var decoded: Variant = denormalize(value)
	var result := {}
	if not decoded is Dictionary:
		return result
	for key in (decoded as Dictionary).keys():
		result[StringName(str(key))] = (decoded as Dictionary)[key]
	return result
