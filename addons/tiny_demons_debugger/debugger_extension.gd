@tool
class_name TinyDemonsDebuggerExtension
extends MCPToolkitExtension
## Read retained Godot debugger entries without selecting, clearing, or replaying.
## The editor has no public Errors API. Identify its Tree by the native signal
## connection, rather than translated labels or Control ordering (Godot 4.7).

const Untrusted = preload("res://addons/godot_mcp_toolkit/security/untrusted.gd")
const MAX_TEXT := 2048
const MAX_PAGE_BYTES := 196608
const MAX_DETAILS := 32

func register(registry: MCPToolkitCommandRegistry, _server: Node) -> void:
	registry.add("tiny_demons_debugger_read_errors", read_errors,
		MCPToolkitExtensionOptions.new("Read retained Godot debugger errors and warnings, source locations and stack details. Does not start, stop, select or clear anything.")
		.with_input_schema({"type": "object", "properties": {
			"offset": {"type": "integer", "minimum": 0, "default": 0},
			"limit": {"type": "integer", "minimum": 1, "maximum": 50, "default": 20}
		}, "additionalProperties": false})
		.mark_read_only().mark_idempotent().mark_scene_independent())

func read_errors(parameters: Dictionary) -> Dictionary:
	var offset := int(parameters.get("offset", 0))
	var limit := int(parameters.get("limit", 20))
	if offset < 0 or limit < 1 or limit > 50:
		return MCPToolkitError.fail("INVALID_PARAMS", "offset must be nonnegative; limit must be 1..50")
	var trees: Array[Tree] = []
	_find_error_trees(EditorInterface.get_base_control(), trees)
	if trees.is_empty():
		return MCPToolkitError.fail("UNSUPPORTED", "Godot debugger Errors tree was not found", "This reader depends on the editor UI internals. Check compatibility after a Godot upgrade.")
	var entries: Array[Dictionary] = []
	var page_bytes := 0
	var page_full := false
	var total := 0
	var errors := 0
	var warnings := 0
	for session in trees.size():
		var tree_root := trees[session].get_root()
		if tree_root == null:
			continue
		var item := tree_root.get_first_child()
		while item != null:
			if item.has_meta("_is_error") or item.has_meta("_is_warning"):
				var warning := item.has_meta("_is_warning")
				if warning:
					warnings += 1
				else:
					errors += 1
				if total >= offset and entries.size() < limit and not page_full:
					var entry := _row(item)
					entry["index"] = total
					entry["session"] = session
					entry["severity"] = "warning" if warning else "error"
					var details: Array[Dictionary] = []
					var child := item.get_first_child()
					while child != null and details.size() < MAX_DETAILS:
						details.append(_row(child))
						child = child.get_next()
					entry["details"] = details
					entry["details_truncated"] = child != null
					var entry_bytes := JSON.stringify(entry).to_utf8_buffer().size()
					if page_bytes + entry_bytes <= MAX_PAGE_BYTES:
						entries.append(entry)
						page_bytes += entry_bytes
					else:
						page_full = true
				total += 1
			item = item.get_next()
	var result := {"total_entries": total, "error_count": errors,
		"warning_count": warnings, "sessions": trees.size(), "offset": offset,
		"returned": entries.size(), "has_more": offset + entries.size() < total,
		"entries": Untrusted.wrap("debugger_errors", "editor", JSON.stringify(entries))}
	if result["has_more"]:
		result["next_offset"] = offset + entries.size()
	return MCPToolkitSuccess.ok(result)

func _find_error_trees(node: Node, trees: Array[Tree]) -> void:
	# Godot 4.7's native debugger keeps each session's Errors tab at page index 1
	# in its first TabContainer. This identifies an empty panel without translated
	# labels, while entry metadata below confirms populated trees.
	if node.get_class() == "ScriptEditorDebugger" and node.get_child_count() > 0:
		var session_tabs := node.get_child(0) as TabContainer
		if session_tabs != null and session_tabs.get_tab_count() > 1:
			var errors_page := session_tabs.get_child(1)
			for candidate in errors_page.find_children("*", "Tree", true, false):
				if candidate is Tree:
					trees.append(candidate as Tree)
					return
	if node is Tree:
		var tree_root := (node as Tree).get_root()
		var first := tree_root.get_first_child() if tree_root != null else null
		if first != null and (first.has_meta("_is_error") or first.has_meta("_is_warning")):
			trees.append(node as Tree)
			return
	for child in node.get_children():
		_find_error_trees(child, trees)

func _row(item: TreeItem) -> Dictionary:
	var label := item.get_text(0)
	var message := item.get_text(1)
	var result := {"label": label.left(MAX_TEXT), "message": message.left(MAX_TEXT),
		"text_truncated": label.length() > MAX_TEXT or message.length() > MAX_TEXT}
	var location: Variant = item.get_metadata(0)
	if location is Array and location.size() >= 2:
		result["file"] = str(location[0]).left(MAX_TEXT)
		result["line"] = int(location[1])
	return result
