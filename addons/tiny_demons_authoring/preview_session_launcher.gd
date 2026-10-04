@tool
extends RefCounted

const PreviewSessionScript := preload("res://scripts/editor/preview_session.gd")
const SESSION_ROOT_NAME := "TinyDemonsPreviewSessions"
const HEARTBEAT_STALE_SECONDS := 60
const STARTUP_GRACE_SECONDS := 20
const STOP_WAIT_MSEC := 1000

var process_id := -1
var session_directory := ""
var user_data_directory := ""
var status := "No interactive preview running."
var _started_unix := 0
var _stale_status_reported := false


func is_running() -> bool:
	return process_id > 0


func launch_enemy(enemy_id: StringName, seed_value: int = -1) -> bool:
	if is_running():
		status = "Stop the current interactive preview before starting another."
		return false
	var definition := EnemyFactory.definition(enemy_id)
	if definition == null or definition.variant_id != enemy_id:
		status = "Cannot preview unknown enemy ID '%s'." % enemy_id
		return false
	var session := PreviewSessionScript.create_enemy(enemy_id, seed_value) as RefCounted
	var errors: Array[String] = session.call("validation_errors")
	if not errors.is_empty():
		status = "Invalid preview session: %s" % "; ".join(errors)
		return false
	var temp_root := _temporary_session_root()
	var session_id := String(session.get("session_id"))
	session_directory = temp_root.path_join(session_id).simplify_path()
	if session_directory.get_base_dir() != temp_root or not session_id.begins_with("preview_"):
		status = "Refusing to create a preview directory outside the session root."
		session_directory = ""
		return false
	if DirAccess.dir_exists_absolute(session_directory):
		status = "Preview session directory already exists; retry to create a fresh session."
		session_directory = ""
		return false
	user_data_directory = session_directory.path_join("user_data")
	var make_dir_error := DirAccess.make_dir_recursive_absolute(user_data_directory)
	if make_dir_error != OK and not DirAccess.dir_exists_absolute(user_data_directory):
		status = "Cannot create isolated preview data directory (error %d)." % make_dir_error
		_cleanup_session_directory()
		return false
	var payload_path := session_directory.path_join("session.json")
	var payload_file := FileAccess.open(payload_path, FileAccess.WRITE)
	if payload_file == null:
		status = "Cannot write preview-session payload (error %d)." % FileAccess.get_open_error()
		_cleanup_session_directory()
		return false
	payload_file.store_string(JSON.stringify(session.call("to_record"), "\t"))
	payload_file.close()
	var project_path := ProjectSettings.globalize_path("res://")
	var arguments := PackedStringArray([
		"--path", project_path,
		"--user-data-dir", user_data_directory,
		"--", PreviewSessionScript.COMMAND_PREFIX + payload_path,
	])
	process_id = OS.create_process(OS.get_executable_path(), arguments, false)
	if process_id <= 0:
		status = "Godot could not launch the isolated preview process."
		_cleanup_session_directory()
		return false
	_started_unix = int(Time.get_unix_time_from_system())
	_stale_status_reported = false
	status = "Launching %s preview (seed %d, %s)." % [definition.display_name, int(session.get("seed")), session_id]
	return true


func tick() -> void:
	if not is_running():
		if not session_directory.is_empty() and _cleanup_session_directory():
			status = "Temporary preview data cleanup completed."
		return
	if not OS.is_process_running(process_id):
		_finish_session("Interactive preview ended; temporary data removed.")
		return
	var closed_path := session_directory.path_join("closed")
	if FileAccess.file_exists(closed_path):
		status = "Interactive preview is closing; waiting for its process to exit."
		return
	var current_unix := int(Time.get_unix_time_from_system())
	var heartbeat_path := session_directory.path_join("heartbeat")
	if FileAccess.file_exists(heartbeat_path):
		var heartbeat_age := current_unix - int(FileAccess.get_modified_time(heartbeat_path))
		if heartbeat_age > HEARTBEAT_STALE_SECONDS and not _stale_status_reported:
			status = "Interactive preview has stopped responding; stop it here to close it."
			_stale_status_reported = true
		elif heartbeat_age <= HEARTBEAT_STALE_SECONDS and _stale_status_reported:
			status = "Interactive preview running."
			_stale_status_reported = false
	elif current_unix - _started_unix > STARTUP_GRACE_SECONDS and not _stale_status_reported:
		status = "Interactive preview has not reported startup; stop it here to close it."
		_stale_status_reported = true


func stop() -> void:
	if not is_running():
		status = "No interactive preview running." if _cleanup_session_directory() else "Preview data cleanup failed at %s." % session_directory
		return
	if OS.is_process_running(process_id):
		OS.kill(process_id)
		status = "Stopping interactive preview; temporary data will be removed after exit."
		return
	_finish_session("Interactive preview stopped; temporary data removed.")


func stop_and_cleanup() -> void:
	if is_running() and OS.is_process_running(process_id):
		OS.kill(process_id)
		var waited_msec := 0
		while OS.is_process_running(process_id) and waited_msec < STOP_WAIT_MSEC:
			OS.delay_msec(50)
			waited_msec += 50
	if not is_running() or not OS.is_process_running(process_id):
		_finish_session("Interactive preview stopped; temporary data removed.")
	else:
		# The editor is exiting, so no future tick can safely confirm child exit.
		# Keep the isolated directory as evidence instead of deleting live data.
		status = "The child process did not stop; isolated preview data was retained."
		process_id = -1


func _finish_session(message: String) -> void:
	process_id = -1
	status = message if _cleanup_session_directory() else "Preview process exited, but temporary data remains at %s." % session_directory
	_stale_status_reported = false


func _cleanup_session_directory() -> bool:
	if session_directory.is_empty():
		return true
	var expected_root := _temporary_session_root()
	var target := session_directory.simplify_path()
	if target.get_base_dir() != expected_root or not target.get_file().begins_with("preview_"):
		return false
	if not _remove_directory_recursive(target):
		return false
	session_directory = ""
	user_data_directory = ""
	return true


func _temporary_session_root() -> String:
	var temp_path := OS.get_environment("TEMP") if OS.get_name() == "Windows" else OS.get_environment("TMPDIR")
	if temp_path.is_empty() or not temp_path.is_absolute_path():
		temp_path = OS.get_user_data_dir().get_base_dir()
	return temp_path.path_join(SESSION_ROOT_NAME).simplify_path()


func _remove_directory_recursive(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return not DirAccess.dir_exists_absolute(path)
	directory.list_dir_begin()
	var child_name := directory.get_next()
	while not child_name.is_empty():
		if child_name != "." and child_name != "..":
			var child_path := path.path_join(child_name)
			if directory.current_is_dir():
				if not _remove_directory_recursive(child_path):
					directory.list_dir_end()
					return false
			else:
				var remove_error := DirAccess.remove_absolute(child_path)
				if remove_error != OK and FileAccess.file_exists(child_path):
					directory.list_dir_end()
					return false
		child_name = directory.get_next()
	directory.list_dir_end()
	directory = null
	var remove_error := DirAccess.remove_absolute(path)
	return remove_error == OK or not DirAccess.dir_exists_absolute(path)
