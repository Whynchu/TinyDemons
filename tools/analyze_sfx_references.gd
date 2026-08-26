extends SceneTree

## Prints a CSV inventory for external MP3 reference files. The source material
## remains outside res:// and is never imported into the shipping game.

const TARGETS := [
	"SYS-ALART", "SYS-BEEP", "SYS-CANSEL", "SYS-CHAGE", "SYS-CHAGEF1",
	"SYS-CHAGEF2", "SYS-CLICK", "SYS-CLICK102", "SYS-CLICK104",
	"SYS-CLICK104B", "SYS-CLOSE", "SYS-DECKSET", "SYS-DROW", "SYS-ITEMGET",
	"SYS-LVUP", "SYS-MONEY-GET", "SYS-POWER-GET", "SYS-SAVELOAD", "SYS-START",
	"SYS-TRESURE", "SYS-WORLDSELECT", "SYS-WORLDSTART",
]


func _initialize() -> void:
	var project_dir := ProjectSettings.globalize_path("res://")
	var workspace_dir := project_dir.path_join("..").simplify_path()
	var reference_root := workspace_dir.path_join("sfx examples")
	var found := _find_targets(reference_root)
	print("name,duration_seconds,file_bytes,bitrate_kbps")
	for target in TARGETS:
		var path: String = found.get(target, "")
		if path.is_empty():
			push_warning("Reference not found: %s" % target)
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		var stream := AudioStreamMP3.new()
		stream.data = bytes
		var duration := stream.get_length()
		var bitrate := 0.0
		if duration > 0.0:
			bitrate = float(bytes.size() * 8) / duration / 1000.0
		print("%s,%.4f,%d,%.1f" % [target, duration, bytes.size(), bitrate])
	quit()


func _find_targets(root: String) -> Dictionary:
	var wanted := {}
	for target in TARGETS:
		wanted[target] = true
	var found := {}
	var directories: Array[String] = [root]
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
			elif entry.get_extension().to_lower() == "mp3":
				var base := entry.get_basename()
				if wanted.has(base):
					found[base] = path
			entry = directory.get_next()
		directory.list_dir_end()
	return found
