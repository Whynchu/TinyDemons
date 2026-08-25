extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Soul pickup coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var pickup_runtime := gameplay.get("pickup_runtime_controller") as Node
	var soul_controller := gameplay.get("soul_pickup_controller") as Node
	var profile := gameplay.get("player_profile") as PlayerProfile
	var hud_controller := gameplay.get("hud_controller") as Node
	var texture := pickup_runtime.call("soul_pickup_texture") as Texture2D if pickup_runtime != null else null
	_expect(texture != null and texture.get_width() == 9 and texture.get_height() == 9, "Soul stand-in is exactly 9x9", failures)
	_expect(soul_controller != null, "Soul pickup controller is composed", failures)
	if hud_controller != null:
		var player_hud := (gameplay.get("ui") as Node).get_node("PlayerHud") as Node2D
		var gold_display := player_hud.get_node("GoldDisplay") as Node2D
		var soul_display := player_hud.get_node("SoulDisplay") as Node2D
		var soul_icon := hud_controller.get("soul_icon_indicator") as Sprite2D
		_expect(is_equal_approx(gold_display.position.y, 4.0) and is_equal_approx(soul_display.position.y, 11.0), "currency displays sit inside the top black bar", failures)
		_expect(soul_icon != null and soul_icon.texture != null and soul_icon.texture.get_width() == 5 and soul_icon.texture.get_height() == 5, "Soul HUD uses a 5x5 coin icon", failures)
		var soul_image := soul_icon.texture.get_image() if soul_icon != null and soul_icon.texture != null else null
		var has_purple_pixel := false
		if soul_image != null:
			for y in soul_image.get_height():
				for x in soul_image.get_width():
					var pixel := soul_image.get_pixel(x, y)
					if pixel.a > 0.0 and pixel.b > pixel.r and pixel.b > pixel.g:
						has_purple_pixel = true
		_expect(has_purple_pixel, "Soul coin pixels are dyed purple", failures)
	if soul_controller != null and profile != null:
		var before := profile.souls
		var player := gameplay.get("player") as Sprite2D
		var player_foot: Vector2 = gameplay.call("_actor_foot", player) as Vector2
		gameplay.call("_spawn_soul_pickup", player_foot, 2, 777, Vector2.ZERO)
		if soul_controller.get("air_times").size() > 0:
			soul_controller.get("air_times")[0] = 0.0
			var pickup := soul_controller.get("sprites")[0] as Sprite2D
			pickup.global_position = player_foot
			gameplay.call("_update_soul_pickups", 0.01)
		_expect(profile.souls == before + 2, "Soul pickup adds its value to the persistent profile currency", failures)
		_expect(soul_controller.get("sprites").is_empty(), "Soul pickup is removed after collection", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Soul pickup smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("SOUL_PICKUP_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
