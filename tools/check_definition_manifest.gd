extends SceneTree

const MANIFEST_SERVICE := preload("res://scripts/content_definition_manifest_service.gd")


func _initialize() -> void:
	var problems: Array[String] = MANIFEST_SERVICE.check_freshness()
	if problems.is_empty():
		print("CONTENT_MANIFEST_FRESH entries=%d" % MANIFEST_SERVICE.discover_resource_paths().size())
		quit(0)
		return
	for problem in problems:
		push_error("CONTENT_MANIFEST_INVALID: %s" % problem)
	quit(1)
