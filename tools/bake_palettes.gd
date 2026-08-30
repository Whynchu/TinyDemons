extends SceneTree

## One-time asset baker. Run headless:
##   godot --headless --path TinyDemons -s res://tools/bake_palettes.gd
##
## Generates every palette-recolored player frame and packs them into per-animation
## sprite sheets under res://assets/baked/player/{palette}/{anim}.png, plus the
## cloaked Demon Cloak variant under res://assets/baked/player_cloaked/{palette}/{anim}.png.
## The game loads these at boot instead of recoloring at runtime, removing the runtime
## recolor cost.  Run it whenever the palette set or player art changes.

const OUT_ROOT := "res://assets/baked/player"
const CLOAKED_OUT_ROOT := "res://assets/baked/player_cloaked"
const FULL_SHEET_PATH := "res://assets/artwork/TinyDemon_fullsheet.png"
const CLOAKED_FULL_SHEET_PATH := "res://assets/artwork/TinyDemon_fullsheet_cloaked.png"
const DEFEND_SHEET_PATH := "res://assets/artwork/TinyDemon-Defend.png"
const DEFEND_CLOAKED_SHEET_PATH := "res://assets/artwork/TinyDemon-Defend-Cloaked.png"
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
	_bake_sheet(library, FULL_SHEET_PATH, OUT_ROOT, DEFEND_SHEET_PATH, failures)
	_bake_sheet(library, CLOAKED_FULL_SHEET_PATH, CLOAKED_OUT_ROOT, DEFEND_CLOAKED_SHEET_PATH, failures)
	_finished = true
	if failures.is_empty():
		print("BAKE_OK")
		quit(0)
	else:
		for f: String in failures:
			push_error(f)
		print("BAKE_FAILED")
		quit(1)


func _bake_sheet(library: SpriteFrameLibrary, full_sheet_path: String, out_root: String, defend_sheet_path: String, failures: Array[String]) -> void:
	var base: Dictionary = {}
	var full_sheet := load(full_sheet_path) as Texture2D
	if full_sheet == null:
		failures.append("missing source: %s" % full_sheet_path)
		return
	for key: String in FULL_SHEET_ROWS:
		base[key] = _slice_sheet_row(full_sheet, int(FULL_SHEET_ROWS[key]))
	if not defend_sheet_path.is_empty():
		base["defend"] = _slice_file(defend_sheet_path, PLAYER_FRAME)
	# Left-facing variants are horizontal flips of the attack frames.
	base["attack_left"] = library.flip_frames(base.get("attack", []))
	base["attack2_left"] = library.flip_frames(base.get("attack2", []))
	base["spin_left"] = library.flip_frames(base.get("spin", []))
	var between_frames := base.get("between", []) as Array[Texture2D]
	var after_frames := base.get("after", []) as Array[Texture2D]
	base["between"] = [between_frames[0]] as Array[Texture2D] if not between_frames.is_empty() else []
	base["after"] = [after_frames[0]] as Array[Texture2D] if not after_frames.is_empty() else []

	for palette_name: String in PaletteLibrary.PALETTE_NAMES:
		var dir := out_root + "/" + palette_name
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
	print("Baked palettes under %s" % out_root)


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


func _slice_file(path: String, frame_size: Vector2i) -> Array[Texture2D]:
	var library := SpriteFrameLibrary.new()
	return library.slice_frames(path, frame_size)


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