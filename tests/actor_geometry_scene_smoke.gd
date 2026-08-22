extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for geometry characterization", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 30:
		await process_frame
	var drawer := gameplay.get_node_or_null("ActorGeometryDebugDrawer") as Node
	_expect(drawer != null, "runtime geometry debug drawer is installed", failures)
	if drawer != null:
		_expect(not bool(drawer.get("enabled")), "geometry debug drawer is opt-in", failures)
		_expect((drawer.get("foot_callable") as Callable).is_valid(), "geometry drawer receives shared foot callable", failures)
		_expect((drawer.get("collision_rect_callable") as Callable).is_valid(), "geometry drawer receives shared collision callable", failures)
		_expect((drawer.get("body_polygon_callable") as Callable).is_valid(), "geometry drawer receives shared body callable", failures)
		_expect((drawer.get("actors") as Array[Sprite2D]).size() >= 1, "geometry drawer tracks runtime actors", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ACTOR_GEOMETRY_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
