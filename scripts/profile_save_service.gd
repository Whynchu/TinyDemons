extends RefCounted
class_name ProfileSaveService

const SAVE_PATH := "user://tiny_demons_profile.json"
const TEMP_PATH := "user://tiny_demons_profile.tmp"
const BACKUP_PATH := "user://tiny_demons_profile.backup.json"
const ACTIVE_SLOT_PATH := "user://tiny_demons_active_slot.txt"
const SLOT_COUNT := 3
const WEB_ACTIVE_SLOT_KEY := "td_active_slot"
const WEB_SLOT_KEY_PREFIX := "td_profile_"
static var active_slot := -1

static func select_slot(slot: int) -> void:
	active_slot = clampi(slot, 0, SLOT_COUNT - 1)
	var file := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(str(active_slot))
		file.close()
	_web_set_item(WEB_ACTIVE_SLOT_KEY, str(active_slot))

static func current_slot() -> int:
	if active_slot >= 0:
		return active_slot
	active_slot = 0
	if FileAccess.file_exists(ACTIVE_SLOT_PATH):
		var file := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.READ)
		if file != null:
			active_slot = clampi(int(file.get_as_text()), 0, SLOT_COUNT - 1)
			file.close()
	elif _is_web():
		active_slot = clampi(int(_web_get_item(WEB_ACTIVE_SLOT_KEY)), 0, SLOT_COUNT - 1)
	return active_slot

static func slot_has_profile(slot: int) -> bool:
	return _read_profile(_save_path(slot)) != null or _read_profile(_backup_path(slot)) != null or _web_has_profile(slot)

static func has_any_profile_save() -> bool:
	for slot in SLOT_COUNT:
		if slot_has_profile(slot):
			return true
	return false

static func load_profile_for_slot(slot: int) -> PlayerProfile:
	if _is_web():
		var web_profile := _parse_profile_json(_web_get_item(_web_slot_key(slot)))
		if web_profile != null:
			return web_profile
	var profile := _read_profile(_save_path(slot))
	if profile != null:
		return profile
	return _read_profile(_backup_path(slot))


static func has_profile_save() -> bool:
	return slot_has_profile(current_slot())


static func load_profile() -> PlayerProfile:
	var profile := load_profile_for_slot(current_slot())
	return profile if profile != null else PlayerProfile.new()


static func export_cloud_envelope() -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot in SLOT_COUNT:
		var profile := load_profile_for_slot(slot)
		if profile != null:
			slots.append({"slot": slot, "profile": profile.to_dictionary()})
	return {"format": "tiny-demons-cloud-save", "format_version": 1, "profile_schema": PlayerProfile.CURRENT_SCHEMA_VERSION, "slots": slots}


static func import_cloud_envelope(envelope: Dictionary) -> bool:
	if str(envelope.get("format", "")) != "tiny-demons-cloud-save" or int(envelope.get("format_version", 0)) != 1:
		return false
	var values: Variant = envelope.get("slots", [])
	if not values is Array:
		return false
	var validated: Array[Dictionary] = []
	var used_slots: Dictionary = {}
	for value: Variant in values:
		if not value is Dictionary:
			return false
		var entry := value as Dictionary
		var slot := int(entry.get("slot", -1))
		var data: Variant = entry.get("profile", {})
		if slot < 0 or slot >= SLOT_COUNT or used_slots.has(slot) or not data is Dictionary:
			return false
		if not PlayerProfile.supports_schema_version(int(data.get("schema_version", 0))):
			return false
		var profile := PlayerProfile.new()
		profile.load_dictionary(data as Dictionary)
		validated.append({"slot": slot, "profile": profile})
		used_slots[slot] = true
	var original_slot := current_slot()
	for entry in validated:
		select_slot(int(entry["slot"]))
		if not save_profile(entry["profile"] as PlayerProfile):
			select_slot(original_slot)
			return false
	select_slot(original_slot)
	return true


static func save_profile(profile: PlayerProfile) -> bool:
	if profile == null:
		return false
	var slot := current_slot()
	var json := JSON.stringify(profile.to_dictionary())
	_web_set_item(_web_slot_key(slot), json)
	var temp_path := _temp_path(slot)
	var save_path := _save_path(slot)
	var backup_path := _backup_path(slot)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json)
	file.close()
	if _read_profile(temp_path) == null:
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

static func clear_slot(slot: int) -> void:
	var safe_slot := clampi(slot, 0, SLOT_COUNT - 1)
	for path in [_save_path(safe_slot), _backup_path(safe_slot), _temp_path(safe_slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _is_web():
		_web_remove_item(_web_slot_key(safe_slot))

static func _save_path(slot: int) -> String:
	return SAVE_PATH if slot == 0 else "user://tiny_demons_profile_%d.json" % (slot + 1)

static func _backup_path(slot: int) -> String:
	return BACKUP_PATH if slot == 0 else "user://tiny_demons_profile_%d.backup.json" % (slot + 1)

static func _temp_path(slot: int) -> String:
	return TEMP_PATH if slot == 0 else "user://tiny_demons_profile_%d.tmp" % (slot + 1)


static func _is_web() -> bool:
	return OS.has_feature("web")


static func _web_slot_key(slot: int) -> String:
	return WEB_SLOT_KEY_PREFIX + str(slot)


static func _web_set_item(key: String, value: String) -> void:
	if not _is_web():
		return
	JavaScriptBridge.eval("localStorage.setItem(%s, %s)" % [JSON.stringify(key), JSON.stringify(value)])


static func _web_get_item(key: String) -> String:
	if not _is_web():
		return ""
	var result: Variant = JavaScriptBridge.eval("localStorage.getItem(%s)" % JSON.stringify(key))
	return str(result) if result != null else ""


static func _web_remove_item(key: String) -> void:
	if not _is_web():
		return
	JavaScriptBridge.eval("localStorage.removeItem(%s)" % JSON.stringify(key))


static func _web_has_profile(slot: int) -> bool:
	return _parse_profile_json(_web_get_item(_web_slot_key(slot))) != null


static func _read_profile(path: String) -> PlayerProfile:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed := _parse_profile_json(file.get_as_text())
	file.close()
	return parsed


static func _parse_profile_json(json: String) -> PlayerProfile:
	var parsed: Variant = JSON.parse_string(json)
	if not parsed is Dictionary:
		return null
	var data := parsed as Dictionary
	var schema_version := int(data.get("schema_version", 0))
	if not PlayerProfile.supports_schema_version(schema_version):
		return null
	var profile := PlayerProfile.new()
	profile.load_dictionary(data)
	return profile
