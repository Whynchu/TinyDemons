extends Resource
class_name RoomPrefabDefinition

## Stable, reusable spatial room content. Room state and route identity belong
## to the graph/runtime; this resource only describes the scene and its marker
## contract.

@export var prefab_id: StringName = &""
@export var room_scene: PackedScene
@export var map_root_path: NodePath = ^"Map"
@export var required_socket_ids: Array[StringName] = [
	&"WALL_LEFT",
	&"WALL_RIGHT",
	&"BOTTOM_LEFT",
	&"BOTTOM_RIGHT",
]


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
	return problems
