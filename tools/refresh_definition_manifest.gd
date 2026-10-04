extends SceneTree

const MANIFEST_SERVICE := preload("res://scripts/content/content_definition_manifest_service.gd")


func _initialize() -> void:
	var result: Error = MANIFEST_SERVICE.refresh_manifest()
	if result != OK:
		push_error("CONTENT_MANIFEST_REFRESH_FAILED error=%d" % result)
		quit(1)
		return
	print("CONTENT_MANIFEST_REFRESH_OK entries=%d" % MANIFEST_SERVICE.discover_resource_paths().size())
	quit(0)
