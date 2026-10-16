extends RefCounted
class_name MenuWorldVisibilityController

## Saves and restores the world layers hidden behind full-screen menus.
## Repeated requests are idempotent so nested menu routes retain the first
## captured visibility values until the world is shown again.
var _hidden := false
var _background_visible := true
var _map_visible := true
var _actors_visible := true


func set_hidden(gameplay: GameplayState, hidden: bool) -> void:
	if gameplay == null:
		return
	var background: CanvasItem = gameplay.background_environment
	var map: CanvasItem = gameplay.map_root
	var actors := gameplay.get_node_or_null("Actors") as CanvasItem
	if hidden:
		if _hidden:
			return
		_hidden = true
		if background != null:
			_background_visible = background.visible
			background.visible = false
		if map != null:
			_map_visible = map.visible
			map.visible = false
		if actors != null:
			_actors_visible = actors.visible
			actors.visible = false
		return
	if not _hidden:
		return
	_hidden = false
	if background != null:
		background.visible = _background_visible
	if map != null:
		map.visible = _map_visible
	if actors != null:
		actors.visible = _actors_visible
