extends RefCounted
class_name ScreenAssemblyController

## Composes screen presenters and their shared widget/layout dependencies.
var screen: ScreenStateController

func bind(owner: Variant) -> void:
	screen = owner


func build_title(parent: Node, pixel_texture: Callable, new_game_callback: Callable, continue_callback: Callable, has_profile: bool, settings_callback: Callable, cloud_callback: Callable) -> Dictionary:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	return screen._title_screen_presenter.build(parent, screen.display_view_size, screen.GAME_VERSION, pixel_texture, new_game_callback, continue_callback, has_profile, settings_callback, cloud_callback, screen._menu_widget_factory)


func build_game_over(parent: Node, pixel_texture: Callable, restart: Callable, return_title: Callable) -> void:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	screen._game_over_screen_presenter.build(parent, screen.display_view_size, pixel_texture, restart, return_title, screen._menu_widget_factory)


func build_run_complete(parent: Node, pixel_texture: Callable, return_to_hub: Callable) -> void:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	screen._run_complete_screen_presenter.build(parent, screen.display_view_size, pixel_texture, return_to_hub, screen._menu_widget_factory)


func build_save_select(parent: Node, pixel_texture: Callable, select_callback: Callable, overwrite_yes: Callable, overwrite_no: Callable, portrait_texture: Callable, back_callback: Callable) -> ColorRect:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	return screen._save_select_screen_presenter.build(parent, screen.display_view_size, pixel_texture, select_callback, overwrite_yes, overwrite_no, portrait_texture, back_callback, screen._menu_widget_factory)


func build_name_entry(parent: Node, pixel_texture: Callable, finish_callback: Callable, cancel_callback: Callable, preview_texture: Callable) -> Dictionary:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	return screen._name_entry_screen_controller.build(parent, screen.display_view_size, pixel_texture, finish_callback, cancel_callback, preview_texture, screen._menu_widget_factory, screen._menu_prompt_texture_factory, screen._menu_cursor_animator, screen.CURSOR_LEFT_GAP, screen)


func build_archetype(parent: Node, shift_type: Callable, shift_color: Callable, start_callback: Callable, pixel_texture: Callable) -> Dictionary:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	return screen._archetype_screen_presenter.build(parent, screen.display_view_size, shift_type, shift_color, start_callback, pixel_texture, screen._menu_widget_factory)


func build_loading(parent: Node, pixel_texture: Callable) -> Dictionary:
	screen.display_view_size = screen.layout_controller._view_size_for_parent(parent)
	return screen._loading_screen_presenter.build_loading_screen(parent, screen.display_view_size, pixel_texture, screen._menu_widget_factory)


func update_loading(overlay: ColorRect, text: Sprite2D, fading: bool, timer: float, delta: float, pixel_texture: Callable) -> Dictionary:
	var result := screen._loading_screen_presenter.update_loading_visuals(overlay, text, fading, timer, delta, pixel_texture, screen.display_view_size)
	if bool(result["finished"]):
		_complete_loading_transition()
	return result


func _complete_loading_transition() -> void:
	if screen.title_presenter.overlay != null: screen.title_presenter.overlay.visible = false
	if screen.archetype_presenter.overlay != null: screen.archetype_presenter.overlay.visible = false
	if screen.hub_overlay != null: screen.hub_overlay.visible = false
	screen.set_state(&"gameplay")
