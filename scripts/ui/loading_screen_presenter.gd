extends RefCounted
class_name LoadingScreenPresenter


func build_loading_screen(parent: Node, view_size: Vector2, pixel_texture: Callable, widget_factory: MenuWidgetFactory) -> Dictionary:
	var overlay := widget_factory.create_overlay(parent, "LoadingScreen", view_size, Color.BLACK, 4090, false)
	overlay.set_meta("display_full_view", true)
	var text := widget_factory.create_sprite(overlay, "LoadingText", pixel_texture.call("LOADING", Color.WHITE) as Texture2D, Vector2.ZERO, false, Vector2.ONE, 4091)
	text.position = _loading_text_position(text, view_size)
	return {"overlay": overlay, "text": text}


func update_loading_visuals(overlay: ColorRect, text: Sprite2D, fading: bool, timer: float, delta: float, pixel_texture: Callable, view_size: Vector2) -> Dictionary:
	if fading:
		timer += delta
		overlay.modulate.a = clampf(1.0 - timer / 0.35, 0.0, 1.0)
		var finished := timer >= 0.35
		if finished:
			fading = false
			overlay.visible = false
		return {"fading": fading, "timer": timer, "finished": finished}
	timer += delta
	var labels := ["LOADING", "LOADING.", "LOADING..", "LOADING..."]
	text.texture = pixel_texture.call(labels[mini(int(timer / 0.28) % 4, 3)], Color.WHITE) as Texture2D
	text.position = _loading_text_position(text, view_size)
	return {"fading": fading, "timer": timer, "finished": false}


func _loading_text_position(text: Sprite2D, view_size: Vector2) -> Vector2:
	return view_size - text.texture.get_size() - Vector2(4, 4)
