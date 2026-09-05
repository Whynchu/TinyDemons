extends RefCounted
class_name ActiveRunSaveService

## Disposable in-progress run storage. ProfileSaveService owns permanent
## progression; this service owns only the last safe recovery boundary.
const ACTIVE_RUN_SNAPSHOT_SCRIPT = preload("res://scripts/active_run_snapshot.gd")
const SLOT_COUNT := ProfileSaveService.SLOT_COUNT
const WEB_KEY_PREFIX := "td_active_run_"
const SAVE_PREFIX := "user://tiny_demons_active_run_"
const BACKUP_PREFIX := "user://tiny_demons_active_run_backup_"
const TEMP_PREFIX := "user://tiny_demons_active_run_tmp_"


static func save_snapshot(snapshot: Dictionary, slot: int = -1) -> bool:
	var safe_slot := _slot(slot)
	if not ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(snapshot, safe_slot):
		return false
	var json := JSON.stringify(snapshot)
	# The web mirror is synchronous and is written before the asynchronous
	# IndexedDB-backed user:// write, matching the profile durability strategy.
	_web_set(_web_key(safe_slot), json)
	var temp_path := _temp_path(safe_slot)
	var save_path := _save_path(safe_slot)
	var backup_path := _backup_path(safe_slot)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json)
	file.close()
	if not _read_valid_file(temp_path, safe_slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	var save_absolute := ProjectSettings.globalize_path(save_path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_absolute)
		if DirAccess.copy_absolute(save_absolute, backup_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			return false
		if DirAccess.remove_absolute(save_absolute) != OK:
			DirAccess.remove_absolute(temp_absolute)
			return false
	if DirAccess.rename_absolute(temp_absolute, save_absolute) == OK:
		return true
	if FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(backup_absolute, save_absolute)
	DirAccess.remove_absolute(temp_absolute)
	return false


static func load_snapshot(slot: int = -1) -> Dictionary:
	var safe_slot := _slot(slot)
	var candidates: Array[Dictionary] = []
	if _is_web():
		var web_snapshot := _parse(_web_get(_web_key(safe_slot)), safe_slot)
		if not web_snapshot.is_empty(): candidates.append(web_snapshot)
	var snapshot := _read_file(_save_path(safe_slot), safe_slot)
	if not snapshot.is_empty(): candidates.append(snapshot)
	var backup := _read_file(_backup_path(safe_slot), safe_slot)
	if not backup.is_empty(): candidates.append(backup)
	var newest: Dictionary = {}
	var newest_at := -INF
	for candidate in candidates:
		var candidate_at := float(candidate.get("created_at", 0.0))
		if newest.is_empty() or candidate_at >= newest_at:
			newest = candidate
			newest_at = candidate_at
	return newest


static func has_valid_snapshot(slot: int = -1) -> bool:
	return not load_snapshot(slot).is_empty()


static func clear_snapshot(slot: int = -1) -> void:
	var safe_slot := _slot(slot)
	for path in [_save_path(safe_slot), _backup_path(safe_slot), _temp_path(safe_slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _is_web():
		_web_remove(_web_key(safe_slot))


static func quarantine_invalid(slot: int = -1) -> bool:
	var safe_slot := _slot(slot)
	var path := _save_path(safe_slot)
	if not FileAccess.file_exists(path):
		return false
	var quarantine := "%s.invalid.%d" % [path, Time.get_unix_time_from_system()]
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(quarantine)) == OK


static func _slot(slot: int) -> int:
	return ProfileSaveService.current_slot() if slot < 0 else clampi(slot, 0, SLOT_COUNT - 1)


static func _save_path(slot: int) -> String:
	return "%s%d.json" % [SAVE_PREFIX, slot]


static func _backup_path(slot: int) -> String:
	return "%s%d.json" % [BACKUP_PREFIX, slot]


static func _temp_path(slot: int) -> String:
	return "%s%d.json" % [TEMP_PREFIX, slot]


static func _web_key(slot: int) -> String:
	return "%s%d" % [WEB_KEY_PREFIX, slot]


static func _read_valid_file(path: String, slot: int) -> bool:
	return not _read_file(path, slot).is_empty()


static func _read_file(path: String, slot: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var result := _parse(file.get_as_text(), slot)
	file.close()
	return result


static func _parse(json: String, slot: int) -> Dictionary:
	if json.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(json)
	if not parsed is Dictionary:
		return {}
	var snapshot := parsed as Dictionary
	return snapshot if ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(snapshot, slot) else {}


static func _is_web() -> bool:
	return OS.has_feature("web")


static func _web_set(key: String, value: String) -> void:
	if _is_web():
		JavaScriptBridge.eval("localStorage.setItem(%s, %s)" % [JSON.stringify(key), JSON.stringify(value)])


static func _web_get(key: String) -> String:
	if not _is_web():
		return ""
	var result: Variant = JavaScriptBridge.eval("localStorage.getItem(%s)" % JSON.stringify(key))
	return str(result) if result != null else ""


static func _web_remove(key: String) -> void:
	if _is_web():
		JavaScriptBridge.eval("localStorage.removeItem(%s)" % JSON.stringify(key))
