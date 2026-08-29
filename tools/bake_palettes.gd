extends SceneTree

## One-time asset baker. Run headless:
##   godot --headless --path TinyDemons -s res://tools/bake_palettes.gd
##
## Generates every palette-recolored player frame and packs them into per-animation
## sprite sheets under res://assets/baked/player/{palette}/{anim}.png.  The game
## loads these at boot instead of recoloring at runtime, removing the runtime
## recolor cost.  Run it whenever the palette set or player art changes.

const OUT_ROOT := "res://assets/baked/player"
const PLAYER_FRAME := Vector2i(36, 36)
const ATTACK_FRAME := Vector2i(36, 36)

# [animation key, source path, frame size]
const ANIMATIONS := [
	["idle", "res://assets/artwork/TinyDemon-idle.png", PLAYER_FRAME],
	["walk", "res://assets/artwork/TinyDemon-walk.png", PLAYER_FRAME],
	["run", "res://assets/artwork/TinyDemon-run.png", PLAYER_FRAME],
	["defend", "res://assets/artwork/TinyDemon-Defend.png", PLAYER_FRAME],
	["roll", "res://assets/artwork/TinyDemon-roll.png", PLAYER_FRAME],
	["attack", "res://assets/artwork/TinyDemon-attack1.png", ATTACK_FRAME],
	["attack2", "res://assets/artwork/TinyDemon-attack2.png", ATTACK_FRAME],
	["spin", "res://assets/artwork/TinyDemon-Spin_Attack.png", ATTACK_FRAME],
]


var _finished := false

func _initialize() -> void:
	call_deferred("_bake")
	call_deferred("_watchdog")


func _watchdog() -> void:
	for i in 300:
		await process_frame
		if _finished:
			return
	quit(2)


func _bake() -> void:
	var failures: Array[String] = []
	var library := SpriteFrameLibrary.new()

	# Slice the base (blue-palette source) frames for each animation.
	var base: Dictionary = {}
	for entry in ANIMATIONS:
		var key: String = entry[0]
		var path: String = entry[1]
		var size: Vector2i = entry[2]
		if not ResourceLoader.exists(path):
			failures.append("missing source: %s" % path)
			continue
		base[key] = library.slice_frames(path, size)
	# Left-facing variants are horizontal flips of the attack frames.
	base["attack_left"] = library.flip_frames(base.get("attack", []))
	base["attack2_left"] = library.flip_frames(base.get("attack2", []))
	base["spin_left"] = library.flip_frames(base.get("spin", []))
	base["between"] = [load("res://assets/artwork/TinyDemon-attack-between.png") as Texture2D] as Array[Texture2D]
	base["after"] = [load("res://assets/artwork/TinyDemon-after-attack2.png") as Texture2D] as Array[Texture2D]

	for palette_name: String in PaletteLibrary.PALETTE_NAMES:
		var dir := OUT_ROOT + "/" + palette_name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for key: String in base:
			var frames: Array[Texture2D] = base[key] as Array[Texture2D]
			if frames.is_empty() or frames[0] == null:
				continue
			var recolored: Array[Texture2D] = []
			if key == "between" or key == "after":
				recolored.append(library.recolor_texture(frames[0], palette_name))
			else:
				recolored = library.recolor_frames(frames, palette_name)
			var out_path := "%s/%s.png" % [dir, key]
			if not _pack_sheet(recolored, out_path, failures):
				continue
	print("Baked player palettes: %d" % PaletteLibrary.PALETTE_NAMES.size())
	_finished = true
	if failures.is_empty():
		print("BAKE_OK")
		quit(0)
	else:
		for f: String in failures:
			push_error(f)
		print("BAKE_FAILED")
		quit(1)


func _pack_sheet(frames: Array[Texture2D], out_path: String, failures: Array[String]) -> bool:
	if frames.is_empty():
		return false
	var width := frames[0].get_width()
	var height := frames[0].get_height()
	var sheet := Image.create(width * frames.size(), height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	for i in frames.size():
		var frame_image := frames[i].get_image()
		sheet.blit_rect(frame_image, Rect2i(0, 0, width, height), Vector2i(i * width, 0))
	var global_path := ProjectSettings.globalize_path(out_path)
	var err := sheet.save_png(global_path)
	if err != OK:
		failures.append("save failed (%s): %s" % [err, out_path])
		return false
	return true
