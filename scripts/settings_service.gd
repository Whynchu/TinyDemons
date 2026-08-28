extends Node
class_name SettingsService

## Device-wide settings store. Run/profile data belongs to PlayerProfile; these
## preferences deliberately live in their own ConfigFile so every save slot
## shares the same display and audio choices.

signal setting_changed(key: StringName, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULTS := {
	"fullscreen": false,
	"aspect": "FULL",
	"pixel_perfect": true,
	"music_volume": 100,
	"sfx_volume": 100,
}
const VALID_ASPECTS := ["FULL", "3:2", "16:10", "16:9"]

var file_path := SETTINGS_PATH
var _values: Dictionary = DEFAULTS.duplicate(true)
var _loaded := false


func _init(custom_path: String = "") -> void:
	if not custom_path.is_empty():
		file_path = custom_path


func load_settings() -> Dictionary:
	_values = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	var error := config.load(file_path)
	if error == OK:
		for key in DEFAULTS.keys():
			if config.has_section_key(SECTION, key):
				_values[key] = _normalize_value(StringName(key), config.get_value(SECTION, key))
	else:
		# A missing or malformed file should never block boot. Replacing it with
		# known-good defaults also makes the next write deterministic.
		save_settings()
	_loaded = true
	return _values.duplicate(true)


func save_settings() -> bool:
	var config := ConfigFile.new()
	for key in DEFAULTS.keys():
		config.set_value(SECTION, key, _values.get(key, DEFAULTS[key]))
	return config.save(file_path) == OK


func get_setting(key: StringName, fallback: Variant = null) -> Variant:
	_ensure_loaded()
	var string_key := String(key)
	if _values.has(string_key):
		return _values[string_key]
	return fallback


func set_setting(key: StringName, value: Variant) -> Variant:
	_ensure_loaded()
	var string_key := String(key)
	if not DEFAULTS.has(string_key):
		return value
	var normalized: Variant = _normalize_value(key, value)
	if _values.get(string_key) == normalized:
		return normalized
	_values[string_key] = normalized
	save_settings()
	setting_changed.emit(key, normalized)
	return normalized


func values() -> Dictionary:
	_ensure_loaded()
	return _values.duplicate(true)


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	_loaded = true
	save_settings()
	for key in DEFAULTS.keys():
		setting_changed.emit(StringName(key), _values[key])


func _ensure_loaded() -> void:
	if not _loaded:
		load_settings()


func _normalize_value(key: StringName, value: Variant) -> Variant:
	match key:
		&"fullscreen", &"pixel_perfect":
			if value is String:
				return String(value).to_lower() in ["true", "1", "on", "yes"]
			return bool(value)
		&"aspect":
			var aspect := str(value)
			return aspect if aspect in VALID_ASPECTS else DEFAULTS["aspect"]
		&"music_volume", &"sfx_volume":
			var volume := clampi(int(value), 0, 100)
			return clampi(snappedi(volume, 10), 0, 100)
	return DEFAULTS.get(String(key), value)
