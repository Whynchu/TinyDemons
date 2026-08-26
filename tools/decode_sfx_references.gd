extends SceneTree

## Decodes a small, curated reference subset through Godot's audio mixer so it
## can be inspected with the same PCM assumptions as the generated candidates.

const TARGETS := [
	"SYS-CLICK", "SYS-CLICK102", "SYS-CLICK104", "SYS-CLICK104B", "SYS-CANSEL", "SYS-CLOSE",
	"SYS-CHAGEF1", "SYS-SAVELOAD", "SYS-ITEMGET", "SYS-MONEY-GET",
	"SYS-TRESURE",
]

var _player: AudioStreamPlayer
var _recorder: AudioEffectRecord


func _initialize() -> void:
	var project_dir := ProjectSettings.globalize_path("res://")
	var workspace_dir := project_dir.path_join("..").simplify_path()
	var source_root := workspace_dir.path_join("sfx examples")
	var output_root := workspace_dir.path_join("sfx analysis")
	DirAccess.make_dir_recursive_absolute(output_root)
	var found := _find_targets(source_root)
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, "ReferenceDecode")
	_recorder = AudioEffectRecord.new()
	_recorder.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus_index, _recorder)
	_player = AudioStreamPlayer.new()
	_player.bus = "ReferenceDecode"
	root.add_child(_player)
	_decode_all.call_deferred(found, output_root)


func _decode_all(found: Dictionary, output_root: String) -> void:
	for target in TARGETS:
		var path: String = found.get(target, "")
		if path.is_empty():
			push_warning("Reference not found: %s" % target)
			continue
		var mp3 := AudioStreamMP3.new()
		mp3.data = FileAccess.get_file_as_bytes(path)
		_player.stream = mp3
		_recorder.set_recording_active(true)
		_player.play()
		await create_timer(mp3.get_length() + 0.08).timeout
		_recorder.set_recording_active(false)
		var recording := _recorder.get_recording()
		if recording != null:
			var error := recording.save_to_wav(output_root.path_join(target))
			if error != OK:
				push_error("Could not decode %s: %s" % [target, error_string(error)])
			else:
				print("Decoded %s" % target)
	quit()


func _find_targets(root_path: String) -> Dictionary:
	var wanted := {}
	for target in TARGETS:
		wanted[target] = true
	var found := {}
	var directories: Array[String] = [root_path]
	while not directories.is_empty():
		var current: String = directories.pop_back()
		var directory := DirAccess.open(current)
		if directory == null:
			continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			var path: String = current.path_join(entry)
			if directory.current_is_dir():
				if entry != "." and entry != "..":
					directories.push_back(path)
			elif entry.get_extension().to_lower() == "mp3" and wanted.has(entry.get_basename()):
				found[entry.get_basename()] = path
			entry = directory.get_next()
		directory.list_dir_end()
	return found
