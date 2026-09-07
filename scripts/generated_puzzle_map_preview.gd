extends Node2D

## Designer preview for generated R7 routes using the same minimap renderer as
## gameplay. Each panel is a complete discovered-layout snapshot.

const GENERATOR_SCRIPT = preload("res://scripts/puzzle_route_generator.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const MINIMAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_minimap_controller.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")

@export var completed_runs: int = 6
@export var preview_seed: int = 7100
@export var iteration_count: int = 6
@export var starter_flame: StringName = &"fire"

const PANEL_SIZE := Vector2(230.0, 190.0)
const PANEL_GAP := Vector2(6.0, 6.0)
const COLUMNS := 4

var generated_layouts: Array[Dictionary] = []


func _ready() -> void:
	_build_iterations()
	queue_redraw()


func _build_iterations() -> void:
	generated_layouts.clear()
	for index in range(maxi(iteration_count, 1)):
		var seed := preview_seed + index * 104729
		var graph := GRAPH_SCRIPT.new()
		var map_controller := MAP_CONTROLLER_SCRIPT.new()
		add_child(map_controller)
		var minimap := MINIMAP_CONTROLLER_SCRIPT.new()
		add_child(minimap)
		map_controller.begin_run(graph, seed, completed_runs, starter_flame)
		minimap.configure(map_controller)
		var active_layout = map_controller.get("layout")
		var errors: Array[String] = GENERATOR_SCRIPT.validate(active_layout, completed_runs, starter_flame)
		for room in active_layout.rooms:
			map_controller.on_room_entered(room.id)
		var image: Image = minimap.snapshot_full_image()
		generated_layouts.append({
			"seed": seed,
			"layout": active_layout,
			"errors": errors,
			"image": image,
		})
		map_controller.queue_free()
		minimap.queue_free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _canvas_size()), Color8(17, 19, 24), true)
	draw_string(ThemeDB.fallback_font, Vector2(8.0, 12.0), "GENERATED R7 PUZZLE ROUTES", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color8(239, 242, 247))
	for index in generated_layouts.size():
		var column := index % COLUMNS
		var row := index / COLUMNS
		var origin := Vector2(8.0, 20.0) + Vector2(column, row) * (PANEL_SIZE + PANEL_GAP)
		_draw_iteration(origin, generated_layouts[index], index)


func _draw_iteration(origin: Vector2, record: Dictionary, index: int) -> void:
	draw_rect(Rect2(origin, PANEL_SIZE), Color8(27, 30, 42), true)
	draw_rect(Rect2(origin, PANEL_SIZE), Color8(70, 76, 98), false, 1.0)
	var layout = record["layout"]
	var errors: Array[String] = record["errors"] as Array[String]
	var status := "VALID" if errors.is_empty() else "INVALID %d" % errors.size()
	var status_color := Color8(120, 240, 150) if errors.is_empty() else Color8(255, 105, 105)
	draw_string(ThemeDB.fallback_font, origin + Vector2(4.0, 9.0), "#%d S%d %s" % [index + 1, int(record["seed"]), status], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, status_color)
	var image: Image = record["image"] as Image
	if image != null:
		var texture := ImageTexture.create_from_image(image)
		var available := Vector2(PANEL_SIZE.x - 12.0, PANEL_SIZE.y - 42.0)
		var scale := minf(available.x / float(image.get_width()), available.y / float(image.get_height()))
		var image_size := Vector2(image.get_size()) * scale
		var image_origin := origin + Vector2((PANEL_SIZE.x - image_size.x) * 0.5, 16.0 + (available.y - image_size.y) * 0.5)
		draw_texture_rect(texture, Rect2(image_origin, image_size), false)
	var footer := "%d rooms / %d gates" % [layout.rooms.size(), layout.connections.size()]
	draw_string(ThemeDB.fallback_font, origin + Vector2(4.0, PANEL_SIZE.y - 15.0), footer, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5, Color8(180, 188, 205))
	if not errors.is_empty():
		draw_string(ThemeDB.fallback_font, origin + Vector2(4.0, PANEL_SIZE.y - 7.0), str(errors[0]).left(35), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4, Color8(255, 150, 150))


func _canvas_size() -> Vector2:
	var rows := ceili(float(maxi(generated_layouts.size(), 1)) / float(COLUMNS))
	return Vector2(8.0 + COLUMNS * PANEL_SIZE.x + (COLUMNS - 1) * PANEL_GAP.x + 8.0, 20.0 + rows * PANEL_SIZE.y + (rows - 1) * PANEL_GAP.y + 8.0)
