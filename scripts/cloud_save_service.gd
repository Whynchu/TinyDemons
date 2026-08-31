extends Node
class_name CloudSaveService

signal operation_completed(result: Dictionary)

const LOCAL_CONFIG_PATH := "res://config/supabase.local.cfg"
const PUBLIC_CONFIG_PATH := "res://config/supabase.cfg"
const STATE_PATH := "user://tiny_demons_cloud_state.cfg"
const PUBLIC_PROJECT_URL := "https://pzmrtzypkkxpoimwbgcs.supabase.co"
const PUBLIC_PUBLISHABLE_KEY := "sb_publishable_LAJZcaVHAtSRZe8BQ4YpcA_hz8g_OY8"
var project_url := ""
var publishable_key := ""
var recovery_key := ""
var vault_id := ""
var write_proof := ""
var revision := 0
var _crypto_callback: JavaScriptObject = null
var _pending_action := ""
var _http: HTTPRequest = null
var _crypto_request_serial := 0
var _crypto_poll_timer: Timer

func _ready() -> void:
	_http = HTTPRequest.new(); add_child(_http)
	_crypto_poll_timer = Timer.new(); _crypto_poll_timer.wait_time = 0.1; _crypto_poll_timer.timeout.connect(_poll_crypto_result); add_child(_crypto_poll_timer)
	_http.request_completed.connect(_on_request_completed)
	_load_config(); _load_state(); WebSaveCrypto.install()

func configured() -> bool:
	return OS.has_feature("web") and not project_url.is_empty() and not publishable_key.is_empty()

func create_backup(envelope: Dictionary) -> void:
	if not configured(): operation_completed.emit({"ok": false, "error": "Cloud backup is available in the Web build."}); return
	_pending_action = "create_crypto"
	_crypto_request_serial += 1
	_start_crypto_timeout(_crypto_request_serial)
	_crypto_callback = JavaScriptBridge.create_callback(_on_crypto_completed)
	_start_crypto_bridge("window.__tdVaultCrypto.create(%s)" % JSON.stringify(JSON.stringify(envelope)))

func restore_backup(key: String) -> void:
	if not configured(): operation_completed.emit({"ok": false, "error": "Cloud backup is available in the Web build."}); return
	recovery_key = _normalize_recovery_key(key)
	_pending_action = "derive_for_read"
	_crypto_request_serial += 1
	_start_crypto_timeout(_crypto_request_serial)
	_crypto_callback = JavaScriptBridge.create_callback(_on_crypto_completed)
	_start_crypto_bridge("window.__tdVaultCrypto.encrypt(%s,%s)" % [JSON.stringify(recovery_key), JSON.stringify("{}")])

func sync_backup(envelope: Dictionary) -> void:
	if not configured(): operation_completed.emit({"ok": false, "error": "Cloud backup is available in the Web build."}); return
	if recovery_key.is_empty(): operation_completed.emit({"ok": false, "error": "Enter or create a recovery key first."}); return
	_pending_action = "update_crypto"
	_crypto_request_serial += 1
	_start_crypto_timeout(_crypto_request_serial)
	_crypto_callback = JavaScriptBridge.create_callback(_on_crypto_completed)
	_start_crypto_bridge("window.__tdVaultCrypto.encrypt(%s,%s)" % [JSON.stringify(recovery_key), JSON.stringify(JSON.stringify(envelope))])

func delete_backup() -> void:
	if not configured(): operation_completed.emit({"ok": false, "error": "Cloud backup is available in the Web build."}); return
	if vault_id.is_empty() or write_proof.is_empty(): operation_completed.emit({"ok": false, "error": "Restore the recovery key before deleting."}); return
	_request({"action":"delete", "vault_id":vault_id, "write_proof":write_proof}, "delete")

func _on_crypto_completed(args: Array) -> void:
	_crypto_request_serial = 0
	var raw_variant: Variant = args[0] if not args.is_empty() else ""
	if raw_variant is Array and not (raw_variant as Array).is_empty(): raw_variant = (raw_variant as Array)[0]
	var raw := str(raw_variant)
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary or not bool(parsed.get("ok", false)):
		operation_completed.emit({"ok":false, "error":str(parsed.get("error", "Cryptography failed.")) if parsed is Dictionary else "Cryptography failed."}); return
	vault_id = str(parsed.get("vault_id", "")); write_proof = str(parsed.get("write_proof", ""))
	match _pending_action:
		"create_crypto":
			recovery_key = str(parsed.get("recovery", "")); _request({"action":"create", "vault_id":vault_id, "write_proof":write_proof, "ciphertext":parsed.get("ciphertext", "")}, "create")
		"derive_for_read": _request({"action":"read", "vault_id":vault_id}, "read")
		"update_crypto": _request({"action":"update", "vault_id":vault_id, "write_proof":write_proof, "expected_revision":revision, "ciphertext":parsed.get("ciphertext", "")}, "update")

func _request(body: Dictionary, action: String) -> void:
	_pending_action = action
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: %s" % publishable_key])
	var error := _http.request(project_url + "/functions/v1/recovery-vault", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK: operation_completed.emit({"ok":false, "error":"Could not start cloud request."})

func _on_request_completed(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if code < 200 or code >= 300 or not parsed is Dictionary:
		operation_completed.emit({"ok":false, "error":str(parsed.get("error", "Cloud request failed.")) if parsed is Dictionary else "Cloud request failed."}); return
	if _pending_action == "read":
		revision = int(parsed.get("revision", 0)); _pending_action = "decrypt_read"
		_crypto_callback = JavaScriptBridge.create_callback(_on_decrypt_completed)
		_start_crypto_bridge("window.__tdVaultCrypto.decrypt(%s,%s)" % [JSON.stringify(recovery_key), JSON.stringify(str(parsed.get("ciphertext", "")))]); return
	revision = int(parsed.get("revision", revision))
	if _pending_action == "delete":
		recovery_key = ""; vault_id = ""; write_proof = ""; revision = 0
		if FileAccess.file_exists(STATE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	else:
		_persist_state()
	operation_completed.emit({"ok":true, "action":_pending_action, "recovery_key":recovery_key, "revision":revision})

func _on_decrypt_completed(args: Array) -> void:
	var raw_variant: Variant = args[0] if not args.is_empty() else ""
	if raw_variant is Array and not (raw_variant as Array).is_empty(): raw_variant = (raw_variant as Array)[0]
	var parsed: Variant = JSON.parse_string(str(raw_variant))
	if not parsed is Dictionary or not bool(parsed.get("ok", false)):
		operation_completed.emit({"ok":false, "error":"Recovery key is invalid or the backup was damaged."}); return
	var envelope: Variant = JSON.parse_string(str(parsed.get("plaintext", "")))
	if not envelope is Dictionary:
		operation_completed.emit({"ok":false, "error":"Cloud backup has an invalid format."}); return
	_persist_state()
	operation_completed.emit({"ok":true, "action":"restore", "envelope":envelope, "revision":revision})

func _load_config() -> void:
	# The identifiers are client-public. Keep a code fallback because some Godot
	# Web export templates omit standalone .cfg files despite all_resources.
	project_url = PUBLIC_PROJECT_URL
	publishable_key = PUBLIC_PUBLISHABLE_KEY
	var config := ConfigFile.new()
	var path := LOCAL_CONFIG_PATH if FileAccess.file_exists(LOCAL_CONFIG_PATH) else PUBLIC_CONFIG_PATH
	if config.load(path) == OK:
		project_url = str(config.get_value("supabase", "project_url", "")).trim_suffix("/")
		publishable_key = str(config.get_value("supabase", "publishable_key", ""))

func _start_crypto_timeout(serial: int) -> void:
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if _crypto_request_serial == serial:
			_crypto_request_serial = 0
			operation_completed.emit({"ok": false, "error": "Browser encryption did not respond. Refresh the page and try again."})
	)

func _start_crypto_bridge(expression: String) -> void:
	JavaScriptBridge.eval("window.__tdGodotCryptoResult=null; window.__tdGodotCryptoCallback=%s; %s" % [_crypto_callback, expression])
	_crypto_poll_timer.start()

func _poll_crypto_result() -> void:
	if _crypto_request_serial == 0: _crypto_poll_timer.stop(); return
	var result := str(JavaScriptBridge.eval("window.__tdGodotCryptoResult || ''"))
	if not result.is_empty():
		_crypto_poll_timer.stop(); _on_crypto_completed([result])

func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(STATE_PATH) == OK:
		recovery_key = str(config.get_value("vault", "recovery_key", ""))
		vault_id = str(config.get_value("vault", "vault_id", ""))
		write_proof = str(config.get_value("vault", "write_proof", ""))
		revision = int(config.get_value("vault", "revision", 0))

func _persist_state() -> void:
	var config := ConfigFile.new()
	config.set_value("vault", "recovery_key", recovery_key)
	config.set_value("vault", "vault_id", vault_id)
	config.set_value("vault", "write_proof", write_proof)
	config.set_value("vault", "revision", revision)
	config.save(STATE_PATH)

func _normalize_recovery_key(raw: String) -> String:
	var key := raw.strip_edges()
	var marker := key.find("TD1-")
	if marker >= 0:
		key = key.substr(marker).split(" ")[0].split("\n")[0].split("\r")[0]
	return key
