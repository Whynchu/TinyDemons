extends RefCounted
class_name PreviewSession

const SCHEMA_VERSION := 1
const COMMAND_PREFIX := "--td-preview-session="
const MAX_SEED := 2147483647

static var _stable_id_regex: RegEx

var session_id: StringName = &""
var content_kind: StringName = &""
var content_id: StringName = &""
var seed := 0
var loadout: Dictionary = {}
var arrival_socket_id: StringName = &""
var requested_mode: StringName = &""


static func create_enemy(content_id_value: StringName, seed_value := -1) -> RefCounted:
	var session := load("res://scripts/editor/preview_session.gd").new() as RefCounted
	var unique_suffix := str(Time.get_ticks_usec())
	session.set("session_id", StringName("preview_%d_%s" % [OS.get_process_id(), unique_suffix]))
	session.set("content_kind", &"enemy")
	session.set("content_id", content_id_value)
	session.set("seed", seed_value if seed_value >= 0 else _new_seed())
	session.set("loadout", {"preset": "starter"})
	session.set("arrival_socket_id", &"auto")
	session.set("requested_mode", &"enemy_boss_encounter")
	return session


static func from_user_args(user_args: PackedStringArray) -> Dictionary:
	var payload_path := ""
	var payload_argument_seen := false
	for argument in user_args:
		if not argument.begins_with(COMMAND_PREFIX):
			continue
		if payload_argument_seen:
			return {"present": true, "session": null, "errors": ["Only one preview-session payload may be supplied."]}
		payload_argument_seen = true
		payload_path = argument.substr(COMMAND_PREFIX.length())
	if not payload_argument_seen:
		return {"present": false, "session": null, "errors": []}
	if payload_path.strip_edges().is_empty():
		return {"present": true, "session": null, "errors": ["Preview-session payload path cannot be empty."]}
	var file := FileAccess.open(payload_path, FileAccess.READ)
	if file == null:
		return {"present": true, "session": null, "errors": ["Could not open preview-session payload (error %d)." % FileAccess.get_open_error()]}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	var result := from_record(parsed)
	return {
		"present": true,
		"session": result.get("session"),
		"payload_path": payload_path,
		"errors": result.get("errors", []),
	}


static func from_record(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"session": null, "errors": ["Preview-session payload must be a JSON object."]}
	var record := value as Dictionary
	var schema_value: Variant = record.get("schema_version", -1)
	if not _is_integer_number(schema_value) or float(schema_value) != float(SCHEMA_VERSION):
		return {"session": null, "errors": ["Unsupported preview-session schema version."]}
	var loadout_value: Variant = record.get("loadout", {})
	if not loadout_value is Dictionary:
		return {"session": null, "errors": ["Preview-session loadout must be an object."]}
	var seed_value: Variant = record.get("seed", -1)
	if not _is_integer_number(seed_value) or float(seed_value) < 0.0 or float(seed_value) > MAX_SEED:
		return {"session": null, "errors": ["Preview-session seed must be an integer between 0 and %d." % MAX_SEED]}
	var session := load("res://scripts/editor/preview_session.gd").new() as RefCounted
	session.set("session_id", StringName(str(record.get("session_id", ""))))
	session.set("content_kind", StringName(str(record.get("content_kind", ""))))
	session.set("content_id", StringName(str(record.get("content_id", ""))))
	session.set("seed", int(seed_value))
	session.set("loadout", (loadout_value as Dictionary).duplicate(true))
	session.set("arrival_socket_id", StringName(str(record.get("arrival_socket_id", ""))))
	session.set("requested_mode", StringName(str(record.get("requested_mode", ""))))
	var errors: Array[String] = session.call("validation_errors")
	return {"session": session if errors.is_empty() else null, "errors": errors}


func to_record() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": String(session_id),
		"content_kind": String(content_kind),
		"content_id": String(content_id),
		"seed": seed,
		"loadout": loadout.duplicate(true),
		"arrival_socket_id": String(arrival_socket_id),
		"requested_mode": String(requested_mode),
	}


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if not _is_stable_id(String(session_id)):
		errors.append("Session ID must be a lowercase stable ID.")
	if not _is_stable_id(String(content_kind)):
		errors.append("Content kind must be a lowercase stable ID.")
	if not _is_stable_id(String(content_id)):
		errors.append("Content ID must be a lowercase stable ID.")
	if seed < 0 or seed > MAX_SEED:
		errors.append("Session seed must be between 0 and %d." % MAX_SEED)
	if not _is_stable_id(String(requested_mode)):
		errors.append("Requested mode must be a lowercase stable ID.")
	var arrival_socket := String(arrival_socket_id)
	if arrival_socket != "auto" and not _is_stable_id(arrival_socket):
		errors.append("Arrival socket must be auto or a lowercase stable ID.")
	return errors


static func _is_integer_number(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	return is_finite(float(value)) and float(value) == floor(float(value))


static func _is_stable_id(value: String) -> bool:
	if _stable_id_regex == null:
		_stable_id_regex = RegEx.new()
		_stable_id_regex.compile("^[a-z][a-z0-9_]{0,63}$")
	return _stable_id_regex.search(value) != null


static func _new_seed() -> int:
	var candidate := int((Time.get_ticks_usec() + OS.get_process_id()) % 2147483647)
	return maxi(candidate, 1)
