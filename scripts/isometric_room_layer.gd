@tool
extends TileMapLayer

enum LayoutKind {
	FLOOR,
	LEFT_WALL,
	RIGHT_WALL,
	LEFT_FACE,
	RIGHT_FACE,
}

@export var tile_texture: Texture2D:
	set(value):
		tile_texture = value
		_rebuild_if_ready()
@export var layout_kind := LayoutKind.FLOOR:
	set(value):
		layout_kind = value
		_rebuild_if_ready()
@export_range(1, 64, 1) var layout_width := 8:
	set(value):
		layout_width = value
		_rebuild_if_ready()
@export_range(1, 64, 1) var layout_height := 8:
	set(value):
		layout_height = value
		_rebuild_if_ready()


func _ready() -> void:
	_ensure_layout()


func _ensure_layout() -> void:
	if tile_texture == null:
		return
	if tile_set == null:
		_build_tile_set()
	if get_used_cells().is_empty():
		_build_default_layout()


func _rebuild_if_ready() -> void:
	if not is_inside_tree() or tile_texture == null:
		return
	_build_tile_set()
	_build_default_layout()


func rebuild_layout(width: int, height: int, kind: LayoutKind = layout_kind) -> void:
	layout_width = clampi(width, 1, 64)
	layout_height = clampi(height, 1, 64)
	layout_kind = kind
	_build_tile_set()
	_build_default_layout()


func _build_tile_set() -> void:
	var generated_tile_set := TileSet.new()
	generated_tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	generated_tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	generated_tile_set.tile_size = Vector2i(16, 8)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = tile_texture
	atlas.texture_region_size = Vector2i(tile_texture.get_width(), tile_texture.get_height())
	atlas.create_tile(Vector2i.ZERO)
	generated_tile_set.add_source(atlas, 0)
	tile_set = generated_tile_set


func _build_default_layout() -> void:
	clear()
	match layout_kind:
		LayoutKind.FLOOR:
			for row in layout_height:
				for column in layout_width:
					set_cell(Vector2i(column - 1, row), 0, Vector2i.ZERO)
		LayoutKind.LEFT_WALL:
			for index in layout_width:
				set_cell(Vector2i(-1, -index), 0, Vector2i.ZERO)
		LayoutKind.RIGHT_WALL:
			for index in layout_width:
				set_cell(Vector2i(index - 1, 0), 0, Vector2i.ZERO)
		LayoutKind.LEFT_FACE:
			for index in layout_width:
				set_cell(Vector2i(index - 1, layout_height - 1), 0, Vector2i.ZERO)
		LayoutKind.RIGHT_FACE:
			for index in layout_height:
				set_cell(Vector2i(layout_width - 2, index), 0, Vector2i.ZERO)
	update_internals()
