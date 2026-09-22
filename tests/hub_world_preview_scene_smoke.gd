extends SceneTree

const PREVIEW_SCENE := "res://scenes/hub_world_preview.tscn"
const ACTOR_PALETTE_MATERIAL_SCRIPT = preload("res://scripts/actor_palette_material.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var packed := load(PREVIEW_SCENE) as PackedScene
	_assert(packed != null, "Hub world preview scene loads")
	if packed == null:
		_finish()
		return

	var preview := packed.instantiate()
	_assert(preview != null, "Hub world preview scene instantiates")
	if preview == null:
		_finish()
		return
	var main := preview.get_node_or_null("Main") as Node2D
	_assert(main != null, "Hub preview reuses the main world composition")
	if main != null:
		preview.call("_configure_preview")
		_assert(main.get_node_or_null("Map") != null, "Hub preview exposes the authored map")
		_assert(main.get_node_or_null("Actors") != null, "Hub preview exposes the authored actors")
		_assert(bool((main.get_node("Map") as CanvasItem).visible), "Hub map is visible in the preview")
		_assert(bool((main.get_node("Actors") as CanvasItem).visible), "Hub actors are visible in the preview")
		_assert(not bool((main.get_node("InterfaceCanvas") as CanvasLayer).visible), "Hub preview hides runtime HUD by default")
		_assert(not bool((main.get_node("Actors/SlimeBlue") as CanvasItem).visible), "Hub preview hides the pooled blue slime")
		_assert(not bool((main.get_node("Actors/SlimeGreen") as CanvasItem).visible), "Hub preview hides the pooled green slime")
		_assert(not bool((main.get_node("Actors/SlimeRed") as CanvasItem).visible), "Hub preview hides the pooled red slime")
		var accents := main.get_node_or_null("Map/HubStoneAccentLayer") as CanvasItem
		_assert(accents != null and accents.visible, "Hub preview shows the authored stone accents")
		var fire := main.get_node_or_null("Actors/RestFire") as Sprite2D
		_assert(fire != null and fire.texture != null and fire.hframes == 1, "Hub preview prepares the animated fire")
		var cloaked_demon := main.get_node_or_null("Actors/CloakedDemon") as Sprite2D
		_assert(cloaked_demon != null and cloaked_demon.texture != null and cloaked_demon.hframes == 1, "Hub preview prepares the animated NPC")
		var placement := main.get_node_or_null("Actors/PlayerPlacement") as PlacementRoot2D
		_assert(placement != null, "Hub preview exposes the player placement root")
		_assert(placement != null and placement.get("placement_id") == &"hub_player", "player placement has a stable authoring ID")
		_assert(placement != null and placement.get("authoring_layer") == "Actors", "player placement is categorized as an actor")
		var player := main.get_node_or_null("Actors/PlayerPlacement/TinyDemon") as Sprite2D
		_assert(player != null and player.texture != null and player.hframes == 1, "Hub preview prepares the animated player")
		_assert(int(preview.get("player_element")) == 2, "Hub preview defaults the player element to Water")
		var player_material := player.material as ShaderMaterial if player != null else null
		var eye_pairs := ACTOR_PALETTE_MATERIAL_SCRIPT.color_pairs("blue")
		var expected_eye_color := (eye_pairs["to"] as PackedColorArray)[3]
		var actual_eye_color := (player_material.get_shader_parameter("to_color") as PackedColorArray)[3] if player_material != null else Color.TRANSPARENT
		_assert(player_material != null and actual_eye_color.is_equal_approx(expected_eye_color), "Water preview applies the runtime eye highlight correction")
		_assert(player != null and player.offset.is_equal_approx(Vector2(-10.0, -10.0)), "Hub preview keeps the runtime player render offset")
		var player_attack := main.get_node_or_null("Actors/PlayerPlacement/TinyDemonAttack") as Sprite2D
		_assert(player_attack != null and player != null and player_attack.position.is_equal_approx(Vector2(-10.0, -10.0)), "player attack layer stays attached to the placement root")
		var player_shadow := main.get_node_or_null("Actors/PlayerPlacement/TinyDemonShadow") as Sprite2D
		_assert(player_shadow != null and player != null and player_shadow.position.is_equal_approx(player.position + Vector2(0.0, 6.0)), "Hub preview keeps the player shadow attached to the drag anchor")
		if placement != null and player != null and player_attack != null and player_shadow != null:
			var move_delta := Vector2(5.0, 3.0)
			var placement_before := placement.position
			var player_before := player.position
			var attack_before := player_attack.position
			var shadow_before := player_shadow.position
			placement.position += move_delta
			_assert(placement.position.is_equal_approx(placement_before + move_delta), "moving the player placement changes the authored anchor")
			_assert(player.get_parent() == placement and player.position.is_equal_approx(player_before), "moving the player placement keeps the player artwork grouped")
			_assert(player_attack.get_parent() == placement and player_attack.position.is_equal_approx(attack_before), "moving the player placement keeps the attack layer grouped")
			_assert(player_shadow.get_parent() == placement and player_shadow.position.is_equal_approx(shadow_before), "moving the player placement keeps the ground shadow grouped")
			placement.position = placement_before

	preview.free()
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("hub_world_preview_scene_smoke: " + message)


func _finish() -> void:
	if failures.is_empty():
		print("HUB_WORLD_PREVIEW_SCENE_SMOKE_OK")
		quit(0)
		return
	quit(1)
