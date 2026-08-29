extends SceneTree

## One-time asset baker. Run headless:
##   godot --headless --path TinyDemons -s res://tools/bake_palettes.gd
##
## Generates every palette-recolored player frame and packs them into per-animation
## sprite sheets under res://assets/baked/player/{palette}/{anim}.png.  The game
## loads these at boot instead of recoloring at runtime, removing the runtime
## recolor cost.  Run it whenever the palette set or player art changes.

const OUT_ROOT := "res://assets/baked/player"
const FULL_SHEET_PATH := "res://assets/artwork/TinyDemon_fullsheet.png"
const PLAYER_FRAME := Vector2i(36, 36)
const ATTACK_FRAME := Vector2i(36, 36)

const FULL_SHEET_ROWS := {
	"idle": 0,
	"walk": 1,
	"run": 2,
	"attack": 3,
	"between": 4,
	"attack2": 5,
	"after": 6,
	"roll": 7,
	"backflip": 8,
	"magic": 9,
	"spin": 10,
}

# [animation key, source path, frame size]
const ANIMATIONS := [
	["idle", "res://assets/artwork/TinyDemon-idle.png", PLAYER_FRAME],
	["walk", "res://assets/artwork/TinyDemon-walk.png", PLAYER_FRAME],
	["run", "res://assets/artwork/TinyDemon-run.png", PLAYER_FRAME],
	["backflip", "res://assets/artwork/TinyDemon-backflip.png", PLAYER_FRAME],
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

	# Slice the base (blue-palette source) frames from the authored master sheet.
	var base: Dictionary = {}
	var full_sheet := load(FULL_SHEET_PATH) as Texture2D
	if full_sheet == null:
		failures.append("missing source: %s" % FULL_SHEET_PATH)
	else:
		for key: String in FULL_SHEET_ROWS:
			base[key] = _slice_sheet_row(full_sheet, int(FULL_SHEET_ROWS[key]))
	# Left-facing variants are horizontal flips of the attack frames.
	base["attack_left"] = library.flip_frames(base.get("attack", []))
	base["attack2_left"] = library.flip_frames(base.get("attack2", []))
	base["spin_left"] = library.flip_frames(base.get("spin", []))
	var between_frames := base.get("between", []) as Array[Texture2D]
	var after_frames := base.get("after", []) as Array[Texture2D]
	base["between"] = [between_frames[0]] as Array[Texture2D] if not between_frames.is_empty() else []
	base["after"] = [after_frames[0]] as Array[Texture2D] if not after_frames.is_empty() else []

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


func _slice_sheet_row(sheet: Texture2D, row: int) -> Array[Texture2D]:
	var source := sheet.get_image()
	var frames: Array[Texture2D] = []
	var frame_count := source.get_width() / PLAYER_FRAME.x
	for index in frame_count:
		var frame := Image.create(PLAYER_FRAME.x, PLAYER_FRAME.y, false, Image.FORMAT_RGBA8)
		frame.blit_rect(source, Rect2i(index * PLAYER_FRAME.x, row * PLAYER_FRAME.y, PLAYER_FRAME.x, PLAYER_FRAME.y), Vector2i.ZERO)
		if _has_visible_pixels(frame):
			frames.append(ImageTexture.create_from_image(frame))
	return frames


func _has_visible_pixels(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false


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
