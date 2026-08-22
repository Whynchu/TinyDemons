extends RefCounted
class_name ProfileSaveService

const SAVE_PATH := "user://tiny_demons_profile.json"
const TEMP_PATH := "user://tiny_demons_profile.tmp"
const BACKUP_PATH := "user://tiny_demons_profile.backup.json"
const ACTIVE_SLOT_PATH := "user://tiny_demons_active_slot.txt"
const SLOT_COUNT := 3
static var active_slot := -1

static func select_slot(slot: int) -> void:
	active_slot = clampi(slot, 0, SLOT_COUNT - 1)
	var file := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(str(active_slot))
		file.close()

static func current_slot() -> int:
	if active_slot >= 0:
		return active_slot
	active_slot = 0
	if FileAccess.file_exists(ACTIVE_SLOT_PATH):
		var file := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.READ)
		if file != null:
			active_slot = clampi(int(file.get_as_text()), 0, SLOT_COUNT - 1)
			file.close()
	return active_slot

static func slot_has_profile(slot: int) -> bool:
	return _read_profile(_save_path(slot)) != null or _read_profile(_backup_path(slot)) != null

static func has_any_profile_save() -> bool:
	for slot in SLOT_COUNT:
		if slot_has_profile(slot):
			return true
	return false

static func load_profile_for_slot(slot: int) -> PlayerProfile:
	var profile := _read_profile(_save_path(slot))
	if profile != null:
		return profile
	return _read_profile(_backup_path(slot))


static func has_profile_save() -> bool:
	return slot_has_profile(current_slot())


static func load_profile() -> PlayerProfile:
	var profile := load_profile_for_slot(current_slot())
	return profile if profile != null else PlayerProfile.new()


static func save_profile(profile: PlayerProfile) -> bool:
	if profile == null:
		return false
	var slot := current_slot()
	var temp_path := _temp_path(slot)
	var save_path := _save_path(slot)
	var backup_path := _backup_path(slot)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile.to_dictionary()))
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

static func _save_path(slot: int) -> String:
	return SAVE_PATH if slot == 0 else "user://tiny_demons_profile_%d.json" % (slot + 1)

static func _backup_path(slot: int) -> String:
	return BACKUP_PATH if slot == 0 else "user://tiny_demons_profile_%d.backup.json" % (slot + 1)

static func _temp_path(slot: int) -> String:
	return TEMP_PATH if slot == 0 else "user://tiny_demons_profile_%d.tmp" % (slot + 1)


static func _read_profile(path: String) -> PlayerProfile:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return null
	var data := parsed as Dictionary
	var schema_version := int(data.get("schema_version", 0))
	if schema_version != PlayerProfile.CURRENT_SCHEMA_VERSION:
		return null
	var profile := PlayerProfile.new()
	profile.load_dictionary(data)
	return profile
