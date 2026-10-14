extends SceneTree

const ScriptCommands := preload("res://addons/godot_mcp_toolkit/commands/script_commands.gd")


func _initialize() -> void:
	var uri := "gdscript://-9223107576961341288.gd"
	var valid_message := 'ERROR: Parse Error: Invalid argument for "animation_context()" function: argument 1 should be "GameplayState" but is "%s".\n   at: GDScript::reload (%s:391)' % [uri, uri]
	var valid_entries: Array[Dictionary] = [{"level": "error", "message": valid_message}]
	_expect(ScriptCommands._only_self_identity_errors(valid_entries, "GameplayState"), "own class and same synthetic reload URI is recognized")
	_expect(not ScriptCommands._only_self_identity_errors(valid_entries, "EnemyActor"), "a different declared class is not ignored")

	var other_uri := "gdscript://different-script.gd"
	var mismatched_uri_message := valid_message.replace('but is "%s".' % uri, 'but is "%s".' % other_uri)
	var mismatched_uri_entries: Array[Dictionary] = [{"level": "error", "message": mismatched_uri_message}]
	_expect(not ScriptCommands._only_self_identity_errors(mismatched_uri_entries, "GameplayState"), "an error from a different reload URI is not ignored")
	var mixed_uri_entries: Array[Dictionary] = valid_entries.duplicate()
	mixed_uri_entries.append({"level": "error", "message": valid_message.replace(uri, other_uri)})
	_expect(not ScriptCommands._only_self_identity_errors(mixed_uri_entries, "GameplayState"), "errors from different synthetic reloads are not combined")

	var genuine_message := "ERROR: Parse Error: Identifier not found: player_animation_component"
	var genuine_entries: Array[Dictionary] = [{"level": "error", "message": genuine_message}]
	_expect(not ScriptCommands._only_self_identity_errors(genuine_entries, "GameplayState"), "a genuine compile error remains a failure")
	var assignment_message := 'ERROR: Parse Error: cannot assign type "gdscript://-1.gd" to "GameplayState".\n   at: GDScript::reload (gdscript://-1.gd:391)'
	var assignment_entries: Array[Dictionary] = [{"level": "error", "message": assignment_message}]
	_expect(not ScriptCommands._only_self_identity_errors(assignment_entries, "GameplayState"), "a non-argument type error remains a failure")
	var mixed_entries: Array[Dictionary] = valid_entries.duplicate()
	mixed_entries.append({"level": "error", "message": genuine_message})
	_expect(not ScriptCommands._only_self_identity_errors(mixed_entries, "GameplayState"), "a genuine error alongside the false positive remains a failure")

	if failures.is_empty():
		print("SCRIPT_CHECK_IDENTITY_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


var failures: Array[String] = []


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
