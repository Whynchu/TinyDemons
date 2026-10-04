extends RefCounted
class_name CombatFeedbackPresenter

const HEALING_NUMBER_COLOR := Color8(167, 240, 112)
const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")


func spawn_damage_number(root: GameplayState, slime: Sprite2D, amount: float, was_critical: bool = false, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false) -> void:
	var tuning := root.effects_tuning
	var color := ElementCatalogScript.damage_number_color(attack_element, was_critical and not immune)
	var value := int(round(amount))
	var display_text := "immune" if immune else str(maxi(value, 0))
	root._spawn_floating_number(slime.global_position + Vector2(5, -9), 0 if immune else maxi(value, 0), Vector2(0.0, -tuning.damage_number_float_speed), false if immune else was_critical, false, color, display_text)


func spawn_player_number(root: GameplayState, text: String, value: int, color: Color, is_healing: bool, display_text: String) -> void:
	var origin: Vector2 = root._player_floating_number_origin(text, color)
	var speed := root.effects_tuning.damage_number_float_speed
	# Player feedback starts below the actor foot and travels down from the sprite.
	root._spawn_floating_number(origin, value, Vector2.DOWN * speed, false, is_healing, color, display_text)


func spawn_player_damage_number(root: GameplayState, amount: float, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false) -> void:
	var value := int(round(amount))
	var display_text := "immune" if immune else str(maxi(value, 0))
	spawn_player_number(root, display_text, 0 if immune else value, ElementCatalogScript.damage_number_color(attack_element), false, display_text)


func spawn_player_shield_damage_number(root: GameplayState, amount: float) -> void:
	var value := int(round(amount))
	var color := Color8(148, 220, 255)
	var origin: Vector2 = root._player_floating_number_origin(str(maxi(value, 0)), color) + Vector2(8, 0)
	var speed := root.effects_tuning.damage_number_float_speed
	root._spawn_floating_number(origin, value, Vector2.DOWN * speed, false, false, color, str(maxi(value, 0)))


func spawn_player_healing_number(root: GameplayState, amount: float, color: Color) -> void:
	var value := int(round(amount))
	spawn_player_number(root, "+%d" % maxi(value, 0), value, color, true, "")


func player_floating_number_origin(root: GameplayState, text: String, color: Color) -> Vector2:
	var texture := root._pixel_text_texture(text, color)
	var width := texture.get_width() if texture != null else 0
	return root._actor_foot(root.player) + Vector2(-float(width) * 0.5, 2)


func spawn_slime_healing_number(root: GameplayState, slime: Sprite2D, amount: float, color: Color) -> void:
	var speed := root.effects_tuning.damage_number_float_speed
	root._spawn_floating_number(slime.global_position + Vector2(5, -9), int(round(amount)), Vector2(0.0, -speed), false, true, color)


func spawn_floating_number(root: GameplayState, world_position: Vector2, value: int, velocity: Vector2, was_critical: bool = false, is_healing: bool = false, healing_color: Color = Color.WHITE, display_text := "") -> void:
	var priority_offset := Vector2.ZERO
	if display_text.contains("lv!") or display_text.contains("xp"):
		priority_offset = Vector2(0.0, 6.0)
	world_position += priority_offset
	var tuning := root.effects_tuning
	var number_color := HEALING_NUMBER_COLOR if is_healing else healing_color
	root.effects_spawner.spawn_health_number(root, world_position, value, velocity, was_critical, is_healing, number_color, Callable(root, "_pixel_text_texture"), Callable(root, "_snap_half_pixel"), tuning.damage_number_lifetime, tuning.damage_number_pop_time, display_text)


func health_feedback_color(palette_name: String) -> Color:
	return PaletteLibrary.normal(palette_name)
