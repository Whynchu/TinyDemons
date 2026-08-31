extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	_expect(load("res://scripts/web_save_crypto.gd") != null, "Web save crypto adapter loads", failures)
	_expect(load("res://scripts/cloud_save_service.gd") != null, "cloud transport owner loads", failures)
	_expect(load("res://scripts/cloud_save_panel.gd") != null, "cloud management panel loads", failures)
	_expect(not ProfileSaveService.import_cloud_envelope({}), "empty cloud envelope is rejected", failures)
	_expect(not ProfileSaveService.import_cloud_envelope({"format":"tiny-demons-cloud-save", "format_version":2, "slots":[]}), "future envelope version is rejected", failures)
	var migration := FileAccess.get_file_as_string("res://supabase/migrations/20260830_create_recovery_vaults.sql")
	_expect(migration.contains("private.recovery_vaults"), "vault migration uses a private schema", failures)
	_expect(migration.contains("revoke all") and migration.contains("anon, authenticated"), "vault migration revokes public client roles", failures)
	var edge_function := FileAccess.get_file_as_string("res://supabase/functions/recovery-vault/index.ts")
	_expect(edge_function.contains("SUPABASE_SERVICE_ROLE_KEY"), "Edge Function owns privileged database access", failures)
	_expect(edge_function.contains("write_verifier") and edge_function.contains("revision_conflict"), "Edge Function verifies writes and rejects stale revisions", failures)
	var crypto_source := FileAccess.get_file_as_string("res://scripts/web_save_crypto.gd")
	_expect(crypto_source.contains("AES-GCM") and crypto_source.contains("HKDF") and crypto_source.contains("crypto.getRandomValues"), "Web adapter uses platform cryptography", failures)
	var service_source := FileAccess.get_file_as_string("res://scripts/cloud_save_service.gd")
	_expect(service_source.contains("if _pending_action == \"decrypt_read\"") and service_source.contains("_on_decrypt_completed([result])"), "decrypt results route to the restore handler", failures)
	var panel_source := FileAccess.get_file_as_string("res://scripts/cloud_save_panel.gd")
	_expect(panel_source.contains("Vector2(106, 22)") and panel_source.contains("virtual_keyboard_enabled = true"), "cloud panel exposes mobile-sized controls", failures)
	if failures.is_empty(): print("CLOUD_SAVE_CONTRACT_SMOKE_OK"); quit(0); return
	for failure in failures: push_error("FAILED: %s" % failure)
	quit(1)

func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition: failures.append(label)
