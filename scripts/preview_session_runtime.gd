extends Node
class_name PreviewSessionRuntime

const HEARTBEAT_INTERVAL := 2.0
const SESSION_ROOT_NAME := "TinyDemonsPreviewSessions"

var _payload_directory := ""
var _heartbeat_timer: Timer


func configure(payload_path_value: String, session_id: StringName) -> void:
	if payload_path_value.is_empty():
		return
	var payload_path := payload_path_value.simplify_path()
	var session_directory := payload_path.get_base_dir()
	if not payload_path.is_absolute_path() \
		or payload_path.get_file() != "session.json" \
		or session_directory.get_file() != String(session_id) \
		or not String(session_id).begins_with("preview_") \
		or session_directory.get_base_dir().get_file() != SESSION_ROOT_NAME:
		push_warning("Preview session runtime refused an unexpected payload location.")
		return
	_payload_directory = session_directory


func _ready() -> void:
	if _payload_directory.is_empty():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	_heartbeat_timer.timeout.connect(_write_heartbeat)
	add_child(_heartbeat_timer)
	_heartbeat_timer.start()
	_write_heartbeat()


func _exit_tree() -> void:
	if _payload_directory.is_empty():
		return
	var closed_file := FileAccess.open(_payload_directory.path_join("closed"), FileAccess.WRITE)
	if closed_file != null:
		closed_file.store_string(str(Time.get_unix_time_from_system()))
		closed_file.close()


func _write_heartbeat() -> void:
	var heartbeat_file := FileAccess.open(_payload_directory.path_join("heartbeat"), FileAccess.WRITE)
	if heartbeat_file == null:
		return
	heartbeat_file.store_string("%d %d" % [OS.get_process_id(), int(Time.get_unix_time_from_system())])
	heartbeat_file.close()
