extends SceneTree


class FakeRoot extends Node:
	var current_room_type: StringName = DungeonGraph.ROOM_COMBAT
	var player_profile := PlayerProfile.new()
	var last_pixel_text := ""

	func _pixel_text_texture(text: String, _color: Color) -> Texture2D:
		last_pixel_text = text
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		return ImageTexture.create_from_image(image)


func _initialize() -> void:
	var failures: Array[String] = []
	var fake := FakeRoot.new()
	root.add_child(fake)
	var hud := HudController.new()
	fake.add_child(hud)
	hud.room_number_indicator = Sprite2D.new()
	hud.dungeon_run_indicator = Sprite2D.new()
	fake.add_child(hud.room_number_indicator)
	fake.add_child(hud.dungeon_run_indicator)
	var profile := fake.player_profile
	profile.difficulty_rank = 3
	hud.update_room_number(fake)
	_expect(fake.last_pixel_text == "SLIMEY DEPTHS R1", "a new profile displays R1", failures)
	profile.completed_runs = 1
	profile.difficulty_rank = 1
	hud.update_room_number(fake)
	_expect(fake.last_pixel_text == "SLIMEY DEPTHS R2", "a failed R2 still displays R2", failures)
	profile.difficulty_rank = 5
	hud.update_room_number(fake)
	_expect(fake.last_pixel_text == "SLIMEY DEPTHS R2", "difficulty rank does not change the displayed run number", failures)
	profile.completed_runs = 2
	hud.update_room_number(fake)
	_expect(fake.last_pixel_text == "SLIMEY DEPTHS R3", "a successful R2 advances the display to R3", failures)
	fake.queue_free()
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN_LABEL_PROGRESSION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
