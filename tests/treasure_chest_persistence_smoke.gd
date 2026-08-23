extends SceneTree

const ROOM_CONTROLLER_SCRIPT = preload("res://scripts/room_controller.gd")
const ROOM_PUZZLE_CONTROLLER_SCRIPT = preload("res://scripts/room_puzzle_controller.gd")

class FakeMap extends Node:
	var palette := "red"

	func is_authored_run1() -> bool:
		return true

	func active_environment_palette() -> String:
		return palette

class FakeRoot extends Node:
	var current_room_id: StringName = &"treasure_test"
	var chest_claimed := false
	var chest_evaporated := false
	var chest: Sprite2D = Sprite2D.new()
	var chest_gray_texture: Texture2D = preload("res://assets/artwork/ChestGrey.png")
	var chest_normal_texture: Texture2D = preload("res://assets/artwork/Chest.png")
	var chest_unlock_overlay: Sprite2D = Sprite2D.new()
	var dungeon_map_controller: Node = null


func _initialize() -> void:
	var failures: Array[String] = []
	var controller = ROOM_CONTROLLER_SCRIPT.new()
	var fake := FakeRoot.new()
	var room_id: StringName = fake.current_room_id
	controller.room_states[room_id] = {"finished": false}
	fake.chest_claimed = true
	fake.chest_evaporated = true
	controller.save_treasure_chest_state(fake)
	var saved: Dictionary = controller.room_states[room_id]
	_expect(bool(saved.get("chest_claimed", false)), "claimed chest state is saved per treasure room", failures)
	_expect(bool(saved.get("chest_evaporated", false)), "evaporated chest state is saved per treasure room", failures)
	_expect(not bool(saved.get("finished", false)), "saving a chest does not complete an uncleared treasure room", failures)
	_expect(controller._treasure_chest_claimed_from_state({"finished": true, "item_rewarded": false}), "legacy opened-chest state is treated as claimed", failures)
	_expect(not controller._treasure_chest_claimed_from_state({"finished": true}), "an unopened cleared treasure room still shows its optional chest", failures)
	var tint_controller = ROOM_PUZZLE_CONTROLLER_SCRIPT.new()
	var fake_map := FakeMap.new()
	fake.dungeon_map_controller = fake_map
	fake.chest.texture = fake.chest_gray_texture
	tint_controller.apply_chest_map_tint(fake)
	var red_tint := tint_controller._map_palette_tint("red", 0.50)
	_expect(red_tint.is_equal_approx(Color.WHITE.lerp(PaletteLibrary.normal("red"), 0.50)), "active map tint keeps its original color tone", failures)
	var lightened_red_tint := tint_controller._lightened_artwork_tint(red_tint)
	_expect(fake.chest.self_modulate.is_equal_approx(lightened_red_tint), "grey treasure chest applies its tint to a lightened artwork surface", failures)
	_expect(_luminance(lightened_red_tint) > _luminance(red_tint), "lightened artwork surface is brighter before tinting", failures)
	_expect(fake.chest_unlock_overlay.self_modulate.is_equal_approx(Color.WHITE), "saturated unlock artwork stays untinted", failures)
	fake.chest.texture = fake.chest_normal_texture
	tint_controller.apply_chest_map_tint(fake)
	_expect(fake.chest.self_modulate.is_equal_approx(Color.WHITE), "saturated treasure chest keeps its native colors", failures)
	(fake.dungeon_map_controller as FakeMap).palette = "grey"
	_expect(tint_controller._environment_tint(fake).is_equal_approx(Color.WHITE), "grey Orb and room artwork stays at its authored colors", failures)
	fake.chest.texture = fake.chest_gray_texture
	tint_controller.apply_chest_map_tint(fake)
	var grey_tint := tint_controller._lightened_artwork_tint(tint_controller._map_palette_tint("grey", 0.50))
	_expect(fake.chest.self_modulate.is_equal_approx(grey_tint), "grey treasure chest updates when the map returns to grey", failures)
	tint_controller.free()
	fake_map.free()
	fake.chest_unlock_overlay.free()
	fake.chest.free()
	fake.free()
	controller.free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _luminance(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TREASURE_CHEST_PERSISTENCE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
