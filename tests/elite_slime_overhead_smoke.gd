extends SceneTree

const HUD_CONTROLLER = preload("res://scripts/ui/hud_controller.gd")
const ACTOR_GEOMETRY = preload("res://scripts/algorithms/actor_geometry.gd")
const ELEMENT_CATALOG = preload("res://scripts/content/element_catalog.gd")

var current_health := 10.0


func _initialize() -> void:
	var failures: Array[String] = []
	var hud := HUD_CONTROLLER.new()
	var slime := Sprite2D.new()
	slime.name = "EliteSlime"
	slime.global_position = Vector2(40, 30)
	slime.z_index = 12
	slime.set_meta("is_elite", true)
	get_root().add_child(slime)
	var status := StatusComponent.new()
	status.name = "Status"
	slime.add_child(status)
	status.apply_effect(ELEMENT_CATALOG.status_effect_for_id(&"wet"), ELEMENT_CATALOG.Element.WATER)

	var frame := Sprite2D.new()
	frame.name = "HpOverhead"
	frame.texture = load("res://assets/artwork/HpOverhead.png") as Texture2D
	var fill := Sprite2D.new()
	fill.name = "HpOverheadFill"
	fill.texture = load("res://assets/artwork/HpOverheadGreenBar.png") as Texture2D
	slime.add_child(frame)
	slime.add_child(fill)
	hud.register_overhead_bar(slime, frame, fill, Vector2(3, 0), Callable(hud, "duplicate_fill_sprite"), Callable())

	hud.update_overhead_bars([slime], Callable(self, "_max_health"), Callable(self, "_health"), Callable(self, "_health"), Callable(self, "_is_dead"), Callable(self, "_is_aggroed"), Callable(self, "_set_values"), 10, Callable(), Callable(self, "_pixel_text"))
	var symbol := slime.get_node_or_null("EliteOverheadSymbol") as Sprite2D
	var status_markers: Array = hud.target_overhead_status_markers.get(slime, [])
	var status_marker := status_markers[0] as Sprite2D if not status_markers.is_empty() else null
	_expect(status_marker != null and status_marker.top_level and not status_marker.z_as_relative, "enemy status badges use a world draw layer", failures)
	_expect(status_marker != null and status_marker.z_index < slime.z_index, "enemy health-bar status badges draw underneath the enemy sprite", failures)
	_expect(symbol != null and symbol.visible, "elite symbol is visible before the health bar appears", failures)
	if symbol != null:
		var head_origin := ACTOR_GEOMETRY.slime_head_overhead_origin(slime, symbol.texture.get_size() if symbol.texture != null else Vector2.ZERO)
		_expect(symbol.global_position.is_equal_approx(head_origin), "elite symbol floats above the slime head", failures)

	current_health = 8.0
	hud.update_overhead_bars([slime], Callable(self, "_max_health"), Callable(self, "_health"), Callable(self, "_health"), Callable(self, "_is_dead"), Callable(self, "_is_aggroed"), Callable(self, "_set_values"), 10, Callable(), Callable(self, "_pixel_text"))
	_expect(frame.visible, "elite health bar appears after damage", failures)
	if symbol != null and fill.texture != null:
		var bar_origin := slime.global_position + Vector2(1, -2)
		var expected_bar_symbol := bar_origin + Vector2((fill.texture.get_size().x - symbol.texture.get_size().x) * 0.5, -symbol.texture.get_size().y - ACTOR_GEOMETRY.ELITE_OVERHEAD_SYMBOL_GAP)
		_expect(symbol.global_position.is_equal_approx(expected_bar_symbol), "elite symbol moves above the visible health bar", failures)

	slime.set_meta("is_elite", false)
	current_health = 10.0
	hud.update_overhead_bars([slime], Callable(self, "_max_health"), Callable(self, "_health"), Callable(self, "_health"), Callable(self, "_is_dead"), Callable(self, "_is_aggroed"), Callable(self, "_set_values"), 10, Callable(), Callable(self, "_pixel_text"))
	_expect(symbol == null or not symbol.visible, "ordinary slimes do not show the elite symbol", failures)
	slime.free()
	if failures.is_empty():
		print("ELITE_SLIME_OVERHEAD_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _max_health(_slime: Sprite2D) -> float:
	return 10.0


func _health(_slime: Sprite2D) -> float:
	return current_health


func _is_dead(_slime: Sprite2D) -> bool:
	return false


func _is_aggroed(_slime: Sprite2D) -> bool:
	return false


func _set_values(_fill: Sprite2D, _damage_fill: Sprite2D, _fill_size: Vector2, _health: float, _display_health: float, _max_health: float) -> void:
	pass


func _pixel_text(_text: String, _color: Color) -> Texture2D:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
