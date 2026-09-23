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

	var preview := packed.instantiate() as HubWorldPreview
	_assert(preview != null, "Hub world preview scene instantiates")
	if preview == null:
		_finish()
		return
	get_root().add_child(preview)
	await process_frame
	var main := preview.get_node_or_null("Main") as Node2D
	_assert(main != null, "Hub preview reuses the main world composition")
	if main != null:
		preview.call("_configure_preview")
		_assert(preview.is_inside_tree(), "Hub preview test places the node in a live scene tree")
		_assert(preview.process_mode == Node.PROCESS_MODE_ALWAYS, "Hub preview keeps its editor animation process active")
		_assert(main.get_node_or_null("Map") != null, "Hub preview exposes the authored map")
		_assert(main.get_node_or_null("Actors") != null, "Hub preview exposes the authored actors")
		var environment := main.get_node_or_null("Map") as PlacementRoot2D
		var actor_layer := main.get_node_or_null("Actors") as PlacementRoot2D
		var props := main.get_node_or_null("Actors/Props") as PlacementRoot2D
		var characters := main.get_node_or_null("Actors/Characters") as PlacementRoot2D
		_assert(environment != null and environment.get("placement_id") == &"hub_environment", "Hub map has a stable Environment authoring root")
		_assert(environment != null and environment.get("authoring_layer") == "Environment", "Hub map is categorized as Environment")
		_assert(actor_layer != null and actor_layer.get("placement_id") == &"hub_actor_layer", "Hub actor layer has a stable authoring ID")
		_assert(props != null and props.get("placement_id") == &"hub_props" and props.get("authoring_layer") == "Props", "Hub props have a grouped authoring root")
		_assert(characters != null and characters.get("placement_id") == &"hub_characters" and characters.get("authoring_layer") == "Actors", "Hub characters have a grouped authoring root")
		_assert(bool((main.get_node("Map") as CanvasItem).visible), "Hub map is visible in the preview")
		_assert(bool((main.get_node("Actors") as CanvasItem).visible), "Hub actors are visible in the preview")
		_assert(not bool((main.get_node("InterfaceCanvas") as CanvasLayer).visible), "Hub preview hides runtime HUD by default")
		_assert(not bool((main.get_node("Actors/SlimeBlue") as CanvasItem).visible), "Hub preview hides the pooled blue slime")
		_assert(not bool((main.get_node("Actors/SlimeGreen") as CanvasItem).visible), "Hub preview hides the pooled green slime")
		_assert(not bool((main.get_node("Actors/SlimeRed") as CanvasItem).visible), "Hub preview hides the pooled red slime")
		var accents := main.get_node_or_null("Map/HubStoneAccentLayer") as CanvasItem
		_assert(accents != null and accents.visible, "Hub preview shows the authored stone accents")
		var fire := main.get_node_or_null("Actors/Props/RestFire") as Sprite2D
		_assert(fire != null and fire.texture != null and fire.hframes == 1, "Hub preview prepares the animated fire")
		var fire_texture_before := fire.texture if fire != null else null
		var fire_light := fire.get_node_or_null("FireLight") as PointLight2D if fire != null else null
		var water_fire_color := fire_light.color if fire_light != null else Color.TRANSPARENT
		var chest := main.get_node_or_null("Actors/Props/Chest") as PlacementRoot2D
		_assert(chest != null and chest.get("placement_id") == &"hub_chest" and chest.get("authoring_layer") == "Collectables", "Hub chest is an authored collectable placement")
		var cloaked_demon := main.get_node_or_null("Actors/Characters/CloakedDemon") as Sprite2D
		_assert(cloaked_demon != null and cloaked_demon.texture != null and cloaked_demon.hframes == 1, "Hub preview prepares the animated NPC")
		var cloaked_texture_before := cloaked_demon.texture if cloaked_demon != null else null
		var cloaked_shadow := main.get_node_or_null("Actors/Characters/CloakedDemon/CloakedDemonShadow") as Sprite2D
		_assert(cloaked_shadow != null and cloaked_shadow.get_parent() == cloaked_demon and cloaked_shadow.position.is_equal_approx(Vector2(-8.0, -2.0)), "NPC shadow stays attached to the NPC placement root")
		var placement := main.get_node_or_null("Actors/Characters/PlayerPlacement") as PlacementRoot2D
		_assert(placement != null, "Hub preview exposes the player placement root")
		_assert(placement != null and placement.get("placement_id") == &"hub_player", "player placement has a stable authoring ID")
		_assert(placement != null and placement.get("authoring_layer") == "Actors", "player placement is categorized as an actor")
		var player := main.get_node_or_null("Actors/Characters/PlayerPlacement/TinyDemon") as Sprite2D
		_assert(player != null and player.texture != null and player.hframes == 1, "Hub preview prepares the animated player")
		var player_texture_before := player.texture if player != null else null
		preview.call("_process", 0.2)
		_assert(fire != null and fire.texture != fire_texture_before, "Hub preview advances the fire animation")
		_assert(cloaked_demon != null and cloaked_demon.texture != cloaked_texture_before, "Hub preview advances the NPC animation")
		_assert(player != null and player.texture != player_texture_before, "Hub preview advances the player animation")
		_assert(int(preview.get("player_element")) == 2, "Hub preview defaults the player element to Water")
		var water_fire_frame := fire.texture if fire != null else null
		var player_material := player.material as ShaderMaterial if player != null else null
		var eye_pairs := ACTOR_PALETTE_MATERIAL_SCRIPT.color_pairs("blue")
		var expected_eye_color := (eye_pairs["to"] as PackedColorArray)[3]
		var actual_eye_color := (player_material.get_shader_parameter("to_color") as PackedColorArray)[3] if player_material != null else Color.TRANSPARENT
		_assert(player_material != null and actual_eye_color.is_equal_approx(expected_eye_color), "Water preview applies the runtime eye highlight correction")
		preview.player_element = 1
		_assert(preview.player_element == 1, "Inspector player element setter stores Fire")
		var fire_palette_after := fire_light.color if fire_light != null else Color.TRANSPARENT
		var fire_palette_expected := PaletteLibrary.fire_triple("red")[2]
		var red_fire_frame := fire.texture if fire != null else null
		_assert(fire_light != null and not fire_palette_after.is_equal_approx(water_fire_color), "changing the player element changes the preview flame light")
		_assert(fire_light != null and fire_palette_after.is_equal_approx(fire_palette_expected), "preview flame light follows the selected element palette")
		_assert(water_fire_frame != null and red_fire_frame != null and _texture_contains_color(water_fire_frame, PaletteLibrary.normal("blue")), "Water preview recolors the flame texture")
		_assert(water_fire_frame != null and red_fire_frame != null and _texture_contains_color(red_fire_frame, PaletteLibrary.normal("red")), "Fire preview recolors the flame texture")
		_assert(water_fire_frame != null and red_fire_frame != null and water_fire_frame.get_image().get_data() != red_fire_frame.get_image().get_data(), "changing the player element changes the flame texture pixels")
		var red_player_material := player.material as ShaderMaterial if player != null else null
		var red_eye_color := (red_player_material.get_shader_parameter("to_color") as PackedColorArray)[3] if red_player_material != null else Color.TRANSPARENT
		var red_eye_expected := (ACTOR_PALETTE_MATERIAL_SCRIPT.color_pairs("red")["to"] as PackedColorArray)[3]
		_assert(red_player_material != null and red_eye_color.is_equal_approx(red_eye_expected), "changing the player element changes the player palette material")
		preview.show_hud = true
		_assert(bool((main.get_node("InterfaceCanvas") as CanvasLayer).visible), "Inspector HUD toggle immediately updates the preview")
		preview.show_hud = false
		_assert(not bool((main.get_node("InterfaceCanvas") as CanvasLayer).visible), "Inspector HUD toggle can hide the preview HUD again")
		preview.show_collision_guides = true
		_assert(bool((main.get_node("Actors/Characters/PlayerPlacement/TinyDemon/Attack1HitboxShape") as CanvasItem).visible), "Inspector collision-guide toggle immediately updates the preview")
		preview.show_collision_guides = false
		_assert(player != null and player.offset.is_equal_approx(Vector2(-10.0, -10.0)), "Hub preview keeps the runtime player render offset")
		var player_attack := main.get_node_or_null("Actors/Characters/PlayerPlacement/TinyDemonAttack") as Sprite2D
		_assert(player_attack != null and player != null and player_attack.position.is_equal_approx(Vector2(-10.0, -10.0)), "player attack layer stays attached to the placement root")
		var player_shadow := main.get_node_or_null("Actors/Characters/PlayerPlacement/TinyDemonShadow") as Sprite2D
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
		if props != null and fire != null and chest != null:
			var props_before := props.position
			var fire_before := fire.position
			var chest_before := chest.position
			props.position += Vector2(4.0, -2.0)
			_assert(fire.get_parent() == props and fire.position.is_equal_approx(fire_before), "moving the Props layer keeps the fire placement grouped")
			_assert(chest.get_parent() == props and chest.position.is_equal_approx(chest_before), "moving the Props layer keeps the chest placement grouped")
			props.position = props_before
		if characters != null and placement != null and cloaked_demon != null and cloaked_shadow != null:
			var characters_before := characters.position
			var player_placement_before := placement.position
			var npc_before := cloaked_demon.position
			var npc_shadow_before := cloaked_shadow.position
			characters.position += Vector2(-3.0, 2.0)
			_assert(placement.get_parent() == characters and placement.position.is_equal_approx(player_placement_before), "moving the Characters layer keeps the player placement grouped")
			_assert(cloaked_demon.get_parent() == characters and cloaked_demon.position.is_equal_approx(npc_before), "moving the Characters layer keeps the NPC placement grouped")
			_assert(cloaked_shadow.get_parent() == cloaked_demon and cloaked_shadow.position.is_equal_approx(npc_shadow_before), "moving the Characters layer keeps the NPC shadow grouped")
			characters.position = characters_before

	preview.free()
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("hub_world_preview_scene_smoke: " + message)


func _texture_contains_color(texture: Texture2D, expected: Color) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0 and color.is_equal_approx(expected):
				return true
	return false


func _finish() -> void:
	if failures.is_empty():
		print("HUB_WORLD_PREVIEW_SCENE_SMOKE_OK")
		quit(0)
		return
	quit(1)
