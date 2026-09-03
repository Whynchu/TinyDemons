extends RefCounted
class_name DungeonMapReviewExporter

## Export complete dungeon topology diagrams for design review.
##
## This intentionally does not use DungeonMinimapController's discovered-room
## renderer. Review exports show the whole authored/generated layout, including
## gated doors, route roles, and treasure-room markers.

const RUN1_SCRIPT = preload("res://scripts/dungeon_layout_run1.gd")
const RUN2_SCRIPT = preload("res://scripts/dungeon_layout_run2.gd")
const GENERATOR_SCRIPT = preload("res://scripts/dungeon_layout_generator.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")

const OUTPUT_DIRECTORY := "res://screenshots/dungeon_maps"
const EXPORT_SEED := 24681357
const CELL_SIZE := 96.0
const HEADER_HEIGHT := 112.0
const LEGEND_HEIGHT := 132.0
const PADDING := 56.0
const ROOM_WIDTH := 78.0
const ROOM_HEIGHT := 58.0

const COLOR_BACKGROUND := Color8(17, 19, 24)
const COLOR_PANEL := Color8(25, 29, 39)
const COLOR_TEXT := Color8(239, 242, 247)
const COLOR_MUTED := Color8(159, 169, 187)
const COLOR_DOOR := Color8(112, 126, 157)
const COLOR_PUZZLE := Color8(86, 128, 235)
const COLOR_ELEMENT := Color8(241, 160, 83)
const COLOR_ORB_GATE := Color8(115, 239, 247)
const COLOR_HUB := Color8(244, 244, 244)
const COLOR_ENEMY := Color8(86, 108, 134)
const COLOR_SPECIAL := Color8(148, 176, 194)
const COLOR_TREASURE := Color8(255, 205, 117)
const COLOR_FIRE := Color8(239, 125, 87)
const COLOR_CLOAKED := Color8(143, 91, 173)
const COLOR_BOSS := Color8(177, 62, 83)
const COLOR_ORB := Color8(115, 239, 247)


func export_all(output_directory: String = OUTPUT_DIRECTORY) -> Dictionary:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return {"success": false, "error": "Could not create dungeon map export directory: %s" % directory_error}

	var exports: Array[Dictionary] = [
		{"file": "run1-authored", "title": "Run 1 — Authored Teaching Map", "layout": RUN1_SCRIPT.build()},
		{"file": "run2-authored", "title": "Run 2 — Authored Expansion", "layout": RUN2_SCRIPT.build(&"fire")},
	]
	for completed_runs in range(2, 8):
		var run_number := completed_runs + 1
		exports.append({
			"file": "run%d-generated" % run_number,
			"title": "Run %d — Generated Layout (seed %d)" % [run_number, EXPORT_SEED],
			"layout": GENERATOR_SCRIPT.build(EXPORT_SEED, completed_runs, &"fire", &""),
		})

	var index_lines := PackedStringArray([
		"# Dungeon Map Exports",
		"",
		"Generated from the current layout definitions on 2026-09-03.",
		"Generated maps use deterministic seed `%d` and starter flame `fire`." % EXPORT_SEED,
		"",
		"Each SVG is a complete topology view. The companion JSON preserves the raw layout contract.",
		"",
		"| Map | Rooms | Connections | Layout | Data |",
		"| --- | ---: | ---: | --- | --- |",
	])

	var failed := false
	var output_files: Array[String] = []
	for export_entry in exports:
		var file_stem: String = export_entry["file"]
		var title: String = export_entry["title"]
		var layout = export_entry["layout"]
		if layout == null:
			push_error("Could not build layout for %s" % file_stem)
			failed = true
			continue
		var svg_path := "%s/%s.svg" % [output_directory, file_stem]
		var json_path := "%s/%s.json" % [output_directory, file_stem]
		if not _write_text(svg_path, _build_svg(layout, title)):
			failed = true
		else:
			output_files.append(svg_path)
		if not _write_text(json_path, JSON.stringify(layout.to_dictionary(), "\t")):
			failed = true
		else:
			output_files.append(json_path)
		index_lines.append("| %s | %d | %d | [%s](%s) | [%s](%s) |" % [
			title,
			layout.rooms.size(),
			layout.connections.size(),
			file_stem + ".svg",
			file_stem + ".svg",
			file_stem + ".json",
			file_stem + ".json",
		])

	if not _write_text("%s/README.md" % output_directory, "\n".join(index_lines) + "\n"):
		failed = true
	else:
		output_files.append("%s/README.md" % output_directory)
	return {"success": not failed, "files": output_files}


func _write_text(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s (error %s)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(contents)
	file.close()
	return true


func _build_svg(layout, title: String) -> String:
	var bounds := _layout_bounds(layout)
	var minimum: Vector2i = bounds["minimum"]
	var maximum: Vector2i = bounds["maximum"]
	var grid_width := maximum.x - minimum.x + 1
	var grid_height := maximum.y - minimum.y + 1
	var width := PADDING * 2.0 + float(grid_width) * CELL_SIZE
	var height := HEADER_HEIGHT + float(grid_height) * CELL_SIZE + LEGEND_HEIGHT + PADDING
	var parts := PackedStringArray()
	parts.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	parts.append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">" % [int(width), int(height), int(width), int(height)])
	parts.append("<title>%s</title>" % _svg_escape(title))
	parts.append("<rect width=\"100%%\" height=\"100%%\" fill=\"%s\"/>" % _svg_color(COLOR_BACKGROUND))
	parts.append("<style>text{font-family:Arial,Helvetica,sans-serif} .title{font-size:26px;font-weight:700;fill:%s} .subtitle{font-size:13px;fill:%s} .room-id{font-size:11px;font-weight:700;fill:%s;text-anchor:middle} .room-type{font-size:10px;fill:%s;text-anchor:middle} .edge-label{font-size:10px;fill:%s;text-anchor:middle;paint-order:stroke;stroke:%s;stroke-width:4px;stroke-linejoin:round} .legend{font-size:11px;fill:%s}</style>" % [
		_svg_color(COLOR_TEXT),
		_svg_color(COLOR_MUTED),
		_svg_color(COLOR_TEXT),
		_svg_color(COLOR_TEXT),
		_svg_color(COLOR_TEXT),
		_svg_color(COLOR_BACKGROUND),
		_svg_color(COLOR_TEXT),
	])
	parts.append("<text x=\"%d\" y=\"42\" class=\"title\">%s</text>" % [int(PADDING), _svg_escape(title)])
	parts.append("<text x=\"%d\" y=\"68\" class=\"subtitle\">%d rooms · %d connections · coordinates follow the minimap contract</text>" % [int(PADDING), layout.rooms.size(), layout.connections.size()])
	parts.append("<text x=\"%d\" y=\"91\" class=\"subtitle\">Solid lines are normal routes; dashed lines are optional, detour, or dig routes. Door dots show gate type.</text>" % int(PADDING))

	# A faint grid keeps disconnected lower branches and authored offsets easy to
	# compare without making the grid compete with the topology.
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var point := _point(Vector2i(x, y), minimum)
			parts.append("<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"none\" stroke=\"%s\" stroke-width=\"1\" opacity=\"0.16\"/>" % [
				int(point.x - CELL_SIZE * 0.5),
				int(point.y - CELL_SIZE * 0.5),
				int(CELL_SIZE),
				int(CELL_SIZE),
				_svg_color(COLOR_MUTED),
			])

	for connection in layout.connections:
		var source = layout.room_by_id(connection.source_room_id)
		var destination = layout.room_by_id(connection.destination_room_id)
		if source == null or destination == null:
			continue
		var source_point := _point(source.minimap_coordinate, minimum)
		var destination_point := _point(destination.minimap_coordinate, minimum)
		var edge_color := _connection_color(connection)
		var edge_dash := _edge_dash(connection.route_role)
		parts.append("<line x1=\"%.1f\" y1=\"%.1f\" x2=\"%.1f\" y2=\"%.1f\" stroke=\"%s\" stroke-width=\"7\" stroke-linecap=\"round\" opacity=\"0.82\"%s/>" % [
			source_point.x,
			source_point.y,
			destination_point.x,
			destination_point.y,
			edge_color,
			edge_dash,
		])
		var door_point := _point(connection.minimap_coordinate, minimum)
		parts.append("<circle cx=\"%.1f\" cy=\"%.1f\" r=\"8\" fill=\"%s\" stroke=\"%s\" stroke-width=\"2\"/>" % [
			door_point.x,
			door_point.y,
			edge_color,
			_svg_color(COLOR_BACKGROUND),
		])
		var edge_label := _connection_label(connection)
		if not edge_label.is_empty():
			parts.append("<text x=\"%.1f\" y=\"%.1f\" dy=\"-12\" class=\"edge-label\">%s</text>" % [door_point.x, door_point.y, _svg_escape(edge_label)])

	for room in layout.rooms:
		var room_point := _point(room.minimap_coordinate, minimum)
		var room_color := _room_color(room.room_type)
		var room_text_color := COLOR_BACKGROUND if room.room_type == GRAPH_SCRIPT.ROOM_START else COLOR_TEXT
		var room_label := _room_type_label(room.room_type)
		var room_id := "(%d,%d)" % [room.coordinate.x, room.coordinate.y]
		var chest_label := ""
		if room.chest_count > 0:
			chest_label = " · CHEST"
		parts.append("<g><title>%s — %s%s</title><rect x=\"%.1f\" y=\"%.1f\" width=\"%.1f\" height=\"%.1f\" rx=\"10\" fill=\"%s\" stroke=\"%s\" stroke-width=\"3\"/>" % [
			_svg_escape(str(room.id)),
			_svg_escape(room_label),
			_svg_escape(chest_label),
			room_point.x - ROOM_WIDTH * 0.5,
			room_point.y - ROOM_HEIGHT * 0.5,
			ROOM_WIDTH,
			ROOM_HEIGHT,
			_svg_color(room_color),
			_svg_color(COLOR_TEXT),
		])
		parts.append("<text x=\"%.1f\" y=\"%.1f\" class=\"room-id\" style=\"fill:%s\">%s</text>" % [room_point.x, room_point.y - 5.0, _svg_color(room_text_color), _svg_escape(room_id)])
		parts.append("<text x=\"%.1f\" y=\"%.1f\" class=\"room-type\" style=\"fill:%s\">%s%s</text></g>" % [room_point.x, room_point.y + 13.0, _svg_color(room_text_color), _svg_escape(room_label), _svg_escape(chest_label)])

	_append_legend(parts, HEADER_HEIGHT + float(grid_height) * CELL_SIZE + 24.0)
	parts.append("</svg>")
	return "\n".join(parts) + "\n"


func _layout_bounds(layout) -> Dictionary:
	var has_coordinate := false
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	for room in layout.rooms:
		var coordinate: Vector2i = room.minimap_coordinate
		if not has_coordinate:
			minimum = coordinate
			maximum = coordinate
			has_coordinate = true
		else:
			minimum = minimum.min(coordinate)
			maximum = maximum.max(coordinate)
	for connection in layout.connections:
		var coordinate: Vector2i = connection.minimap_coordinate
		if not has_coordinate:
			minimum = coordinate
			maximum = coordinate
			has_coordinate = true
		else:
			minimum = minimum.min(coordinate)
			maximum = maximum.max(coordinate)
	if not has_coordinate:
		return {"minimum": Vector2i.ZERO, "maximum": Vector2i.ZERO}
	return {"minimum": minimum, "maximum": maximum}


func _point(coordinate: Vector2i, minimum: Vector2i) -> Vector2:
	return Vector2(
		PADDING + float(coordinate.x - minimum.x) * CELL_SIZE + CELL_SIZE * 0.5,
		HEADER_HEIGHT + float(coordinate.y - minimum.y) * CELL_SIZE + CELL_SIZE * 0.5
	)


func _connection_color(connection) -> String:
	var gate_type: StringName = connection.resolved_gate_type()
	if gate_type == GRAPH_SCRIPT.GATE_PUZZLE_COLOR:
		return _svg_color(COLOR_PUZZLE)
	if gate_type == GRAPH_SCRIPT.GATE_ELEMENT:
		return _svg_color(COLOR_ELEMENT)
	if gate_type == GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
		return _svg_color(COLOR_ORB_GATE)
	return _svg_color(COLOR_DOOR)


func _connection_label(connection) -> String:
	var labels := PackedStringArray()
	var gate_type: StringName = connection.resolved_gate_type()
	if gate_type != GRAPH_SCRIPT.GATE_NONE:
		labels.append(_gate_type_label(gate_type))
	if not connection.color_requirement.is_empty():
		labels.append(str(connection.color_requirement))
	if not connection.element_requirement.is_empty():
		labels.append(str(connection.element_requirement))
	if not connection.orb_element_requirement.is_empty():
		labels.append("ORB:%s" % connection.orb_element_requirement)
	if connection.route_role != &"main":
		labels.append(str(connection.route_role))
	if not connection.requires_source_room_clear:
		labels.append("open-before-clear")
	return " / ".join(labels)


func _gate_type_label(gate_type: StringName) -> String:
	if gate_type == GRAPH_SCRIPT.GATE_PUZZLE_COLOR:
		return "PUZZLE"
	if gate_type == GRAPH_SCRIPT.GATE_ELEMENT:
		return "ELEMENT"
	if gate_type == GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
		return "ORB"
	return "CLEAR"


func _edge_dash(route_role: StringName) -> String:
	if route_role == &"main" or route_role == &"fork" or route_role == &"key_progression":
		return ""
	return " stroke-dasharray=\"11 8\""


func _room_color(room_type: StringName) -> Color:
	if room_type == GRAPH_SCRIPT.ROOM_START:
		return COLOR_HUB
	if room_type == GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY:
		return COLOR_SPECIAL
	if room_type == GRAPH_SCRIPT.ROOM_TREASURE:
		return COLOR_TREASURE
	if room_type == GRAPH_SCRIPT.ROOM_FIRE or room_type == GRAPH_SCRIPT.ROOM_REST:
		return COLOR_FIRE
	if room_type == GRAPH_SCRIPT.ROOM_CLOAKED or room_type == GRAPH_SCRIPT.ROOM_NPC:
		return COLOR_CLOAKED
	if room_type == GRAPH_SCRIPT.ROOM_BOSS or room_type == GRAPH_SCRIPT.ROOM_DOWNSTAIRS:
		return COLOR_BOSS
	if room_type == GRAPH_SCRIPT.ROOM_ORB:
		return COLOR_ORB
	return COLOR_ENEMY


func _room_type_label(room_type: StringName) -> String:
	if room_type == GRAPH_SCRIPT.ROOM_START:
		return "HUB"
	if room_type == GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY:
		return "SPECIAL"
	if room_type == GRAPH_SCRIPT.ROOM_TREASURE:
		return "TREASURE"
	if room_type == GRAPH_SCRIPT.ROOM_FIRE or room_type == GRAPH_SCRIPT.ROOM_REST:
		return "FIRE"
	if room_type == GRAPH_SCRIPT.ROOM_CLOAKED or room_type == GRAPH_SCRIPT.ROOM_NPC:
		return "NPC"
	if room_type == GRAPH_SCRIPT.ROOM_BOSS or room_type == GRAPH_SCRIPT.ROOM_DOWNSTAIRS:
		return "BOSS"
	if room_type == GRAPH_SCRIPT.ROOM_ORB:
		return "ORB"
	if room_type == GRAPH_SCRIPT.ROOM_PUZZLE:
		return "PUZZLE"
	return "COMBAT"


func _append_legend(parts: PackedStringArray, top: float) -> void:
	parts.append("<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"12\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1\"/>" % [
		int(PADDING), int(top), int(980.0), int(LEGEND_HEIGHT - 16.0), _svg_color(COLOR_PANEL), _svg_color(COLOR_MUTED)
	])
	parts.append("<text x=\"%d\" y=\"%d\" class=\"legend\" font-weight=\"700\">ROOMS</text>" % [int(PADDING + 18.0), int(top + 25.0)])
	var rooms := [
		["HUB", COLOR_HUB], ["COMBAT", COLOR_ENEMY], ["SPECIAL", COLOR_SPECIAL], ["TREASURE", COLOR_TREASURE],
		["FIRE", COLOR_FIRE], ["NPC", COLOR_CLOAKED], ["ORB", COLOR_ORB], ["BOSS", COLOR_BOSS],
	]
	for index in rooms.size():
		var entry: Array = rooms[index]
		var x := PADDING + 18.0 + float(index % 4) * 132.0
		var y := top + 45.0 + float(index / 4) * 25.0
		parts.append("<rect x=\"%d\" y=\"%d\" width=\"12\" height=\"12\" rx=\"3\" fill=\"%s\"/>" % [int(x), int(y - 10.0), _svg_color(entry[1])])
		parts.append("<text x=\"%d\" y=\"%d\" class=\"legend\">%s</text>" % [int(x + 18.0), int(y), _svg_escape(entry[0])])
	parts.append("<text x=\"%d\" y=\"%d\" class=\"legend\" font-weight=\"700\">DOORS</text>" % [int(PADDING + 550.0), int(top + 25.0)])
	var doors := [["CLEAR", COLOR_DOOR], ["PUZZLE", COLOR_PUZZLE], ["ELEMENT", COLOR_ELEMENT], ["ORB", COLOR_ORB_GATE]]
	for index in doors.size():
		var entry: Array = doors[index]
		var x := PADDING + 550.0 + float(index % 2) * 150.0
		var y := top + 45.0 + float(index / 2) * 25.0
		parts.append("<circle cx=\"%d\" cy=\"%d\" r=\"6\" fill=\"%s\"/>" % [int(x + 6.0), int(y - 4.0), _svg_color(entry[1])])
		parts.append("<text x=\"%d\" y=\"%d\" class=\"legend\">%s</text>" % [int(x + 18.0), int(y), _svg_escape(entry[0])])
	parts.append("<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"%s\" stroke-width=\"4\"/>" % [int(PADDING + 550.0), int(top + 101.0), int(PADDING + 596.0), int(top + 101.0), _svg_color(COLOR_DOOR)])
	parts.append("<text x=\"%d\" y=\"%d\" class=\"legend\">main / fork</text>" % [int(PADDING + 608.0), int(top + 105.0)])
	parts.append("<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"%s\" stroke-width=\"4\" stroke-dasharray=\"8 6\"/>" % [int(PADDING + 730.0), int(top + 101.0), int(PADDING + 776.0), int(top + 101.0), _svg_color(COLOR_DOOR)])
	parts.append("<text x=\"%d\" y=\"%d\" class=\"legend\">optional / detour / dig</text>" % [int(PADDING + 788.0), int(top + 105.0)])


func _svg_color(color: Color) -> String:
	return "#%s" % color.to_html(false)


func _svg_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")
