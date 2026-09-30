extends Resource
class_name RoomPrefabDefinition

## Stable, reusable spatial room content. Room state and route identity belong
## to the graph/runtime; this resource only describes the scene and its marker
## contract. Marker2D children declare their stable IDs with room_marker_id
## metadata; runtime bindings resolve those IDs through RoomPrefabHost.

@export var prefab_id: StringName = &""
@export var room_scene: PackedScene
@export var map_root_path: NodePath = ^"Map"
@export var capability_ids: Array[StringName] = []
@export var required_marker_ids: Array[StringName] = []
@export var required_socket_ids: Array[StringName] = [
	&"WALL_LEFT",
	&"WALL_RIGHT",
	&"BOTTOM_LEFT",
	&"BOTTOM_RIGHT",
]


func supports_capability(capability_id: StringName) -> bool:
	return not capability_id.is_empty() and capability_ids.has(capability_id)


func resolve_marker(room_instance: Node, marker_id: StringName) -> Marker2D:
	if room_instance == null or marker_id.is_empty():
		return null
	return _find_marker(room_instance, marker_id)


func validate_instance(room_instance: Node) -> Array[String]:
	var problems: Array[String] = []
	if prefab_id.is_empty():
		problems.append("prefab_id must not be empty")
	if room_scene == null:
		problems.append("room_scene is required")
	if room_instance == null:
		problems.append("room scene did not instantiate")
		return problems
	var map_root := room_instance.get_node_or_null(map_root_path) as Node2D
	if map_root == null:
		problems.append("room scene is missing its Node2D map root at '%s'" % map_root_path)
		return problems
	for child_name in [&"FloorTiles", &"Walls", &"Sockets"]:
		if not map_root.get_node_or_null(NodePath(String(child_name))) is Node2D:
			problems.append("room map is missing Node2D '%s'" % child_name)
	var sockets_root := map_root.get_node_or_null("Sockets") as Node2D
	if sockets_root == null:
		return problems
	var socket_ids: Dictionary = {}
	for child in sockets_root.get_children():
		var socket := child as DungeonSocket
		if socket == null:
			continue
		var socket_id := socket.socket_id()
		if socket_ids.has(socket_id):
			problems.append("room scene has duplicate socket ID '%s'" % socket_id)
		else:
			socket_ids[socket_id] = true
		if socket.visual() == null or socket.trigger() == null or socket.spawn_marker() == null:
			problems.append("socket '%s' is missing its visual, trigger, or spawn marker" % socket_id)
	for required_socket_id in required_socket_ids:
		if not socket_ids.has(required_socket_id):
			problems.append("room scene is missing required socket '%s'" % required_socket_id)
	var marker_nodes: Dictionary = {}
	_collect_markers(room_instance, marker_nodes, problems)
	var seen_required_markers: Dictionary = {}
	for required_marker_id in required_marker_ids:
		if required_marker_id.is_empty() or seen_required_markers.has(required_marker_id):
			problems.append("room prefab has an empty or duplicate required marker ID '%s'" % required_marker_id)
		elif not marker_nodes.has(required_marker_id):
			problems.append("room scene is missing required marker '%s'" % required_marker_id)
		else:
			seen_required_markers[required_marker_id] = true
	var seen_capabilities: Dictionary = {}
	for capability_id in capability_ids:
		if capability_id.is_empty() or seen_capabilities.has(capability_id):
			problems.append("room prefab has an empty or duplicate capability ID '%s'" % capability_id)
		else:
			seen_capabilities[capability_id] = true
	return problems


func _collect_markers(node: Node, marker_nodes: Dictionary, problems: Array[String]) -> void:
	if node.has_meta("room_marker_id"):
		var marker_id := StringName(str(node.get_meta("room_marker_id")))
		if marker_id.is_empty():
			problems.append("room scene has a marker with an empty room_marker_id")
		elif not node is Marker2D:
			problems.append("room marker '%s' must be a Marker2D" % marker_id)
		elif marker_nodes.has(marker_id):
			problems.append("room scene has duplicate marker ID '%s'" % marker_id)
		else:
			marker_nodes[marker_id] = node
	for child in node.get_children():
		_collect_markers(child, marker_nodes, problems)


func _find_marker(node: Node, marker_id: StringName) -> Marker2D:
	if node.has_meta("room_marker_id") and StringName(str(node.get_meta("room_marker_id"))) == marker_id:
		return node as Marker2D
	for child in node.get_children():
		var marker := _find_marker(child, marker_id)
		if marker != null:
			return marker
	return null
